---
name: Mobile Backend Rate Limiting
platform: mobile
description: Rate limiting and throttling implementation for mobile backends including request throttling, API quotas, burst handling, and distributed rate limiting with Redis
model: opus
category: mobile/backend
---

# Mobile Backend Rate Limiting Subagent

## Purpose

This subagent handles all aspects of rate limiting and throttling for mobile backends. Mobile applications require sophisticated rate limiting to prevent abuse, ensure fair usage, manage API costs, and protect against DDoS attacks while providing a good user experience for legitimate users.

## Core Responsibilities

1. Request rate limiting per user/device/IP
2. API quota management by subscription tier
3. Burst traffic handling
4. Distributed rate limiting with Redis
5. Endpoint-specific limits
6. Graceful degradation under load
7. Rate limit headers and client communication
8. Adaptive rate limiting

## Rate Limiting Architecture

### Redis-Based Rate Limiter

```typescript
// src/middleware/rateLimiter.ts
import { Request, Response, NextFunction } from 'express';
import { Redis } from 'ioredis';
import { redis } from '../cache/redis';
import { AppError, ErrorCodes } from '../errors/AppError';

interface RateLimitConfig {
  windowMs: number;          // Time window in milliseconds
  maxRequests: number;       // Max requests per window
  keyPrefix?: string;        // Redis key prefix
  keyGenerator?: (req: Request) => string;
  skipSuccessfulRequests?: boolean;
  skipFailedRequests?: boolean;
  handler?: (req: Request, res: Response, next: NextFunction) => void;
  skip?: (req: Request) => boolean;
  burst?: {
    maxBurst: number;        // Max burst requests
    burstWindow: number;     // Burst window in milliseconds
  };
}

interface RateLimitInfo {
  remaining: number;
  total: number;
  resetTime: number;
  retryAfter: number;
}

export class RateLimiter {
  private redis: Redis;
  private config: RateLimitConfig;

  constructor(config: RateLimitConfig) {
    this.redis = redis;
    this.config = {
      keyPrefix: 'ratelimit:',
      keyGenerator: (req) => req.user?.id || req.ip,
      ...config,
    };
  }

  middleware() {
    return async (req: Request, res: Response, next: NextFunction) => {
      try {
        // Check if request should be skipped
        if (this.config.skip && this.config.skip(req)) {
          return next();
        }

        const key = this.config.keyPrefix + this.config.keyGenerator!(req);

        // Check rate limit using sliding window
        const info = await this.checkRateLimit(key);

        // Set rate limit headers
        this.setHeaders(res, info);

        if (info.remaining < 0) {
          if (this.config.handler) {
            return this.config.handler(req, res, next);
          }

          throw new AppError(
            ErrorCodes.RATE_LIMIT_EXCEEDED,
            `Rate limit exceeded. Try again in ${Math.ceil(info.retryAfter / 1000)} seconds`,
            429,
            {
              retryAfter: Math.ceil(info.retryAfter / 1000),
              limit: info.total,
              resetTime: info.resetTime,
            }
          );
        }

        // Track successful/failed requests if configured
        res.on('finish', async () => {
          const shouldDecrement =
            (this.config.skipSuccessfulRequests && res.statusCode < 400) ||
            (this.config.skipFailedRequests && res.statusCode >= 400);

          if (shouldDecrement) {
            await this.decrementCount(key);
          }
        });

        next();
      } catch (error) {
        if (error instanceof AppError) {
          throw error;
        }
        // On Redis error, allow request (fail open)
        next();
      }
    };
  }

  // Sliding window rate limit using Redis
  private async checkRateLimit(key: string): Promise<RateLimitInfo> {
    const now = Date.now();
    const windowStart = now - this.config.windowMs;

    // Use Lua script for atomic operation
    const script = `
      local key = KEYS[1]
      local now = tonumber(ARGV[1])
      local windowStart = tonumber(ARGV[2])
      local windowMs = tonumber(ARGV[3])
      local maxRequests = tonumber(ARGV[4])

      -- Remove old entries
      redis.call('ZREMRANGEBYSCORE', key, '-inf', windowStart)

      -- Count current requests
      local count = redis.call('ZCARD', key)

      -- Check if under limit
      if count < maxRequests then
        -- Add current request
        redis.call('ZADD', key, now, now .. '-' .. math.random())
        redis.call('PEXPIRE', key, windowMs)
        return {count + 1, maxRequests, now + windowMs, 0}
      else
        -- Get oldest request to calculate retry time
        local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
        local retryAfter = oldest[2] and (tonumber(oldest[2]) + windowMs - now) or windowMs
        return {count + 1, maxRequests, now + windowMs, retryAfter}
      end
    `;

    const result = await this.redis.eval(
      script,
      1,
      key,
      now,
      windowStart,
      this.config.windowMs,
      this.config.maxRequests
    ) as number[];

    return {
      remaining: this.config.maxRequests - result[0],
      total: result[1],
      resetTime: result[2],
      retryAfter: result[3],
    };
  }

  private async decrementCount(key: string): Promise<void> {
    const now = Date.now();

    // Remove one recent entry
    await this.redis.eval(
      `
      local key = KEYS[1]
      local members = redis.call('ZREVRANGE', key, 0, 0)
      if #members > 0 then
        redis.call('ZREM', key, members[1])
      end
      `,
      1,
      key
    );
  }

  private setHeaders(res: Response, info: RateLimitInfo): void {
    res.setHeader('X-RateLimit-Limit', info.total);
    res.setHeader('X-RateLimit-Remaining', Math.max(0, info.remaining));
    res.setHeader('X-RateLimit-Reset', Math.ceil(info.resetTime / 1000));

    if (info.remaining < 0) {
      res.setHeader('Retry-After', Math.ceil(info.retryAfter / 1000));
    }
  }
}

// Create rate limiter middleware with config
export function createRateLimiter(config: RateLimitConfig) {
  return new RateLimiter(config).middleware();
}
```

### Token Bucket Rate Limiter

```typescript
// src/middleware/tokenBucketLimiter.ts
import { Request, Response, NextFunction } from 'express';
import { redis } from '../cache/redis';
import { AppError, ErrorCodes } from '../errors/AppError';

interface TokenBucketConfig {
  bucketSize: number;         // Max tokens in bucket
  refillRate: number;         // Tokens added per second
  keyPrefix?: string;
  keyGenerator?: (req: Request) => string;
  cost?: number | ((req: Request) => number);  // Tokens consumed per request
}

export class TokenBucketLimiter {
  private config: TokenBucketConfig;

  constructor(config: TokenBucketConfig) {
    this.config = {
      keyPrefix: 'tokenbucket:',
      keyGenerator: (req) => req.user?.id || req.ip,
      cost: 1,
      ...config,
    };
  }

  middleware() {
    return async (req: Request, res: Response, next: NextFunction) => {
      try {
        const key = this.config.keyPrefix + this.config.keyGenerator!(req);
        const cost = typeof this.config.cost === 'function'
          ? this.config.cost(req)
          : this.config.cost!;

        const result = await this.consumeTokens(key, cost);

        // Set headers
        res.setHeader('X-RateLimit-Limit', this.config.bucketSize);
        res.setHeader('X-RateLimit-Remaining', Math.floor(result.tokens));
        res.setHeader('X-RateLimit-Reset', Math.ceil(result.resetTime / 1000));

        if (!result.allowed) {
          res.setHeader('Retry-After', Math.ceil(result.retryAfter));

          throw new AppError(
            ErrorCodes.RATE_LIMIT_EXCEEDED,
            `Rate limit exceeded. Try again in ${Math.ceil(result.retryAfter)} seconds`,
            429,
            { retryAfter: Math.ceil(result.retryAfter) }
          );
        }

        next();
      } catch (error) {
        if (error instanceof AppError) {
          throw error;
        }
        next(); // Fail open on Redis error
      }
    };
  }

  private async consumeTokens(key: string, cost: number): Promise<{
    allowed: boolean;
    tokens: number;
    resetTime: number;
    retryAfter: number;
  }> {
    const script = `
      local key = KEYS[1]
      local bucketSize = tonumber(ARGV[1])
      local refillRate = tonumber(ARGV[2])
      local now = tonumber(ARGV[3])
      local cost = tonumber(ARGV[4])

      local data = redis.call('HMGET', key, 'tokens', 'lastRefill')
      local tokens = tonumber(data[1]) or bucketSize
      local lastRefill = tonumber(data[2]) or now

      -- Calculate tokens to add based on time elapsed
      local elapsed = (now - lastRefill) / 1000
      local tokensToAdd = elapsed * refillRate
      tokens = math.min(bucketSize, tokens + tokensToAdd)

      -- Check if we have enough tokens
      if tokens >= cost then
        tokens = tokens - cost
        redis.call('HMSET', key, 'tokens', tokens, 'lastRefill', now)
        redis.call('EXPIRE', key, math.ceil(bucketSize / refillRate) + 1)
        return {1, tokens, now + (bucketSize - tokens) / refillRate * 1000, 0}
      else
        -- Calculate time until enough tokens
        local neededTokens = cost - tokens
        local retryAfter = neededTokens / refillRate
        redis.call('HMSET', key, 'tokens', tokens, 'lastRefill', now)
        redis.call('EXPIRE', key, math.ceil(bucketSize / refillRate) + 1)
        return {0, tokens, now + (bucketSize - tokens) / refillRate * 1000, retryAfter}
      end
    `;

    const result = await redis.eval(
      script,
      1,
      key,
      this.config.bucketSize,
      this.config.refillRate,
      Date.now(),
      cost
    ) as number[];

    return {
      allowed: result[0] === 1,
      tokens: result[1],
      resetTime: result[2],
      retryAfter: result[3],
    };
  }
}

export function createTokenBucketLimiter(config: TokenBucketConfig) {
  return new TokenBucketLimiter(config).middleware();
}
```

### Tiered Rate Limiting

```typescript
// src/middleware/tieredRateLimiter.ts
import { Request, Response, NextFunction } from 'express';
import { authorizationService } from '../services/authorizationService';
import { createRateLimiter } from './rateLimiter';

// Rate limits by subscription tier
const TIER_LIMITS = {
  free: {
    default: { windowMs: 60000, maxRequests: 60 },        // 60 req/min
    auth: { windowMs: 60000, maxRequests: 10 },           // 10 req/min
    uploads: { windowMs: 3600000, maxRequests: 10 },      // 10 uploads/hour
    search: { windowMs: 60000, maxRequests: 30 },         // 30 req/min
    ai: { windowMs: 86400000, maxRequests: 10 },          // 10 AI calls/day
  },
  pro: {
    default: { windowMs: 60000, maxRequests: 300 },       // 300 req/min
    auth: { windowMs: 60000, maxRequests: 30 },           // 30 req/min
    uploads: { windowMs: 3600000, maxRequests: 100 },     // 100 uploads/hour
    search: { windowMs: 60000, maxRequests: 120 },        // 120 req/min
    ai: { windowMs: 86400000, maxRequests: 100 },         // 100 AI calls/day
  },
  enterprise: {
    default: { windowMs: 60000, maxRequests: 1000 },      // 1000 req/min
    auth: { windowMs: 60000, maxRequests: 100 },          // 100 req/min
    uploads: { windowMs: 3600000, maxRequests: 1000 },    // 1000 uploads/hour
    search: { windowMs: 60000, maxRequests: 600 },        // 600 req/min
    ai: { windowMs: 86400000, maxRequests: 1000 },        // 1000 AI calls/day
  },
};

type RateLimitCategory = keyof typeof TIER_LIMITS.free;
type SubscriptionTier = keyof typeof TIER_LIMITS;

// Create tiered rate limiter middleware
export function tieredRateLimiter(category: RateLimitCategory = 'default') {
  // Cache limiters per tier to avoid recreation
  const limiters = new Map<string, ReturnType<typeof createRateLimiter>>();

  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Get user's subscription tier
      let tier: SubscriptionTier = 'free';

      if (req.user) {
        const permissions = await authorizationService.getUserPermissions(req.user.id);
        tier = permissions.subscription.tier as SubscriptionTier;
      }

      // Get or create limiter for this tier and category
      const key = `${tier}:${category}`;
      let limiter = limiters.get(key);

      if (!limiter) {
        const config = TIER_LIMITS[tier][category];
        limiter = createRateLimiter({
          ...config,
          keyPrefix: `ratelimit:${category}:`,
          keyGenerator: (req) => req.user?.id || `ip:${req.ip}`,
        });
        limiters.set(key, limiter);
      }

      // Apply rate limit
      await limiter(req, res, next);
    } catch (error) {
      next(error);
    }
  };
}

// Middleware to add rate limit info to response
export function rateLimitInfo() {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (req.user) {
      const permissions = await authorizationService.getUserPermissions(req.user.id);
      const tier = permissions.subscription.tier as SubscriptionTier;
      const limits = TIER_LIMITS[tier];

      // Add limits to response
      res.locals.rateLimits = limits;
    }

    next();
  };
}
```

### Endpoint-Specific Rate Limiting

```typescript
// src/middleware/endpointRateLimiter.ts
import { Request, Response, NextFunction } from 'express';
import { createRateLimiter } from './rateLimiter';
import { createTokenBucketLimiter } from './tokenBucketLimiter';

// Pre-configured rate limiters for specific endpoints
export const rateLimiters = {
  // Authentication endpoints - strict limits
  login: createRateLimiter({
    windowMs: 15 * 60 * 1000,  // 15 minutes
    maxRequests: 10,           // 10 attempts
    keyPrefix: 'ratelimit:login:',
    keyGenerator: (req) => req.body.email || req.ip,
    skipSuccessfulRequests: true,  // Only count failed attempts
  }),

  // Password reset - very strict
  passwordReset: createRateLimiter({
    windowMs: 60 * 60 * 1000,  // 1 hour
    maxRequests: 3,            // 3 attempts
    keyPrefix: 'ratelimit:password-reset:',
    keyGenerator: (req) => req.body.email || req.ip,
  }),

  // OTP verification
  otpVerify: createRateLimiter({
    windowMs: 15 * 60 * 1000,  // 15 minutes
    maxRequests: 5,            // 5 attempts
    keyPrefix: 'ratelimit:otp:',
    keyGenerator: (req) => req.body.phone || req.body.email || req.ip,
    skipSuccessfulRequests: true,
  }),

  // Email sending
  sendEmail: createRateLimiter({
    windowMs: 60 * 60 * 1000,  // 1 hour
    maxRequests: 10,           // 10 emails
    keyPrefix: 'ratelimit:email:',
    keyGenerator: (req) => req.user?.id || req.ip,
  }),

  // File uploads - token bucket for burst handling
  uploads: createTokenBucketLimiter({
    bucketSize: 10,            // Max 10 uploads burst
    refillRate: 0.1,           // 1 upload per 10 seconds sustained
    keyPrefix: 'ratelimit:upload:',
    keyGenerator: (req) => req.user?.id || req.ip,
  }),

  // Search - higher limits but per user
  search: createRateLimiter({
    windowMs: 60 * 1000,       // 1 minute
    maxRequests: 60,           // 60 searches per minute
    keyPrefix: 'ratelimit:search:',
    keyGenerator: (req) => req.user?.id || req.ip,
  }),

  // AI/expensive operations
  aiOperations: createRateLimiter({
    windowMs: 24 * 60 * 60 * 1000,  // 24 hours
    maxRequests: 100,               // 100 per day
    keyPrefix: 'ratelimit:ai:',
    keyGenerator: (req) => req.user?.id || req.ip,
  }),

  // Webhook deliveries - per webhook
  webhooks: createTokenBucketLimiter({
    bucketSize: 100,           // 100 webhook burst
    refillRate: 10,            // 10 per second sustained
    keyPrefix: 'ratelimit:webhook:',
    keyGenerator: (req) => req.params.webhookId,
  }),

  // Public API - IP based
  publicApi: createRateLimiter({
    windowMs: 60 * 1000,       // 1 minute
    maxRequests: 30,           // 30 requests per minute
    keyPrefix: 'ratelimit:public:',
    keyGenerator: (req) => req.ip,
  }),

  // Global rate limit (fallback)
  global: createRateLimiter({
    windowMs: 60 * 1000,
    maxRequests: 1000,
    keyPrefix: 'ratelimit:global:',
    keyGenerator: (req) => req.user?.id || req.ip,
  }),
};

// Dynamic rate limiter based on endpoint pattern
export function dynamicRateLimiter(defaultCategory: string = 'global') {
  return (req: Request, res: Response, next: NextFunction) => {
    // Map routes to rate limiters
    const path = req.path;
    const method = req.method;

    let limiter = rateLimiters.global;

    // Auth endpoints
    if (path.includes('/auth/login')) {
      limiter = rateLimiters.login;
    } else if (path.includes('/auth/forgot-password') || path.includes('/auth/reset-password')) {
      limiter = rateLimiters.passwordReset;
    } else if (path.includes('/auth/verify')) {
      limiter = rateLimiters.otpVerify;
    }
    // Upload endpoints
    else if (path.includes('/upload') && method === 'POST') {
      limiter = rateLimiters.uploads;
    }
    // Search endpoints
    else if (path.includes('/search')) {
      limiter = rateLimiters.search;
    }
    // AI endpoints
    else if (path.includes('/ai/') || path.includes('/generate/')) {
      limiter = rateLimiters.aiOperations;
    }
    // Webhook endpoints
    else if (path.includes('/webhooks/')) {
      limiter = rateLimiters.webhooks;
    }

    return limiter(req, res, next);
  };
}
```

### Adaptive Rate Limiting

```typescript
// src/middleware/adaptiveRateLimiter.ts
import { Request, Response, NextFunction } from 'express';
import { redis } from '../cache/redis';
import { AppError, ErrorCodes } from '../errors/AppError';

interface AdaptiveRateLimitConfig {
  baseLimit: number;            // Normal rate limit
  minLimit: number;             // Minimum limit under load
  maxLimit: number;             // Maximum limit for trusted users
  windowMs: number;
  loadThresholds: {
    low: number;                // Below this = increase limits
    high: number;               // Above this = decrease limits
  };
  trustScoreKey: string;        // Redis key for trust score
}

export class AdaptiveRateLimiter {
  private config: AdaptiveRateLimitConfig;

  constructor(config: AdaptiveRateLimitConfig) {
    this.config = config;
  }

  middleware() {
    return async (req: Request, res: Response, next: NextFunction) => {
      try {
        const userId = req.user?.id || `ip:${req.ip}`;

        // Get current system load
        const load = await this.getSystemLoad();

        // Get user trust score
        const trustScore = await this.getUserTrustScore(userId);

        // Calculate adaptive limit
        const limit = this.calculateAdaptiveLimit(load, trustScore);

        // Apply rate limit
        const key = `adaptive:${userId}`;
        const info = await this.checkLimit(key, limit);

        // Update trust score based on behavior
        await this.updateTrustScore(userId, res);

        // Set headers
        res.setHeader('X-RateLimit-Limit', limit);
        res.setHeader('X-RateLimit-Remaining', Math.max(0, info.remaining));
        res.setHeader('X-RateLimit-Reset', Math.ceil(info.resetTime / 1000));

        if (info.remaining < 0) {
          res.setHeader('Retry-After', Math.ceil(info.retryAfter / 1000));

          throw new AppError(
            ErrorCodes.RATE_LIMIT_EXCEEDED,
            'Rate limit exceeded',
            429,
            { retryAfter: Math.ceil(info.retryAfter / 1000) }
          );
        }

        next();
      } catch (error) {
        if (error instanceof AppError) {
          throw error;
        }
        next();
      }
    };
  }

  private async getSystemLoad(): Promise<number> {
    // Get current request rate across all users
    const now = Date.now();
    const windowStart = now - 60000; // Last minute

    const count = await redis.zcount('global:requests', windowStart, now);
    await redis.zadd('global:requests', now, `${now}-${Math.random()}`);
    await redis.zremrangebyscore('global:requests', '-inf', windowStart);

    // Normalize to 0-1 scale based on expected capacity
    const expectedCapacity = 10000; // Requests per minute
    return Math.min(1, count / expectedCapacity);
  }

  private async getUserTrustScore(userId: string): Promise<number> {
    const score = await redis.get(`trust:${userId}`);
    return score ? parseFloat(score) : 0.5; // Default neutral trust
  }

  private calculateAdaptiveLimit(load: number, trustScore: number): number {
    let limit = this.config.baseLimit;

    // Adjust based on load
    if (load > this.config.loadThresholds.high) {
      // High load - reduce limits
      const loadFactor = 1 - ((load - this.config.loadThresholds.high) /
                              (1 - this.config.loadThresholds.high));
      limit = this.config.baseLimit * Math.max(0.5, loadFactor);
    } else if (load < this.config.loadThresholds.low) {
      // Low load - can increase limits
      limit = this.config.baseLimit * 1.5;
    }

    // Adjust based on trust score (0-1)
    // High trust users get up to 2x, low trust users get 0.5x
    const trustMultiplier = 0.5 + trustScore;
    limit = limit * trustMultiplier;

    // Clamp to min/max
    return Math.max(
      this.config.minLimit,
      Math.min(this.config.maxLimit, Math.floor(limit))
    );
  }

  private async updateTrustScore(userId: string, res: Response): Promise<void> {
    res.on('finish', async () => {
      const currentScore = await this.getUserTrustScore(userId);
      let newScore = currentScore;

      // Successful requests increase trust
      if (res.statusCode >= 200 && res.statusCode < 400) {
        newScore = Math.min(1, currentScore + 0.001);
      }
      // Bad requests decrease trust
      else if (res.statusCode === 400 || res.statusCode === 401) {
        newScore = Math.max(0, currentScore - 0.01);
      }
      // Rate limited decreases trust more
      else if (res.statusCode === 429) {
        newScore = Math.max(0, currentScore - 0.05);
      }

      if (newScore !== currentScore) {
        await redis.set(`trust:${userId}`, newScore.toString(), 'EX', 86400 * 30); // 30 days
      }
    });
  }

  private async checkLimit(key: string, limit: number): Promise<{
    remaining: number;
    resetTime: number;
    retryAfter: number;
  }> {
    const now = Date.now();
    const windowStart = now - this.config.windowMs;

    const script = `
      local key = KEYS[1]
      local now = tonumber(ARGV[1])
      local windowStart = tonumber(ARGV[2])
      local windowMs = tonumber(ARGV[3])
      local limit = tonumber(ARGV[4])

      redis.call('ZREMRANGEBYSCORE', key, '-inf', windowStart)
      local count = redis.call('ZCARD', key)

      if count < limit then
        redis.call('ZADD', key, now, now .. '-' .. math.random())
        redis.call('PEXPIRE', key, windowMs)
        return {limit - count - 1, now + windowMs, 0}
      else
        local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
        local retryAfter = oldest[2] and (tonumber(oldest[2]) + windowMs - now) or windowMs
        return {-1, now + windowMs, retryAfter}
      end
    `;

    const result = await redis.eval(
      script,
      1,
      key,
      now,
      windowStart,
      this.config.windowMs,
      limit
    ) as number[];

    return {
      remaining: result[0],
      resetTime: result[1],
      retryAfter: result[2],
    };
  }
}

export function createAdaptiveRateLimiter(config: Partial<AdaptiveRateLimitConfig> = {}) {
  return new AdaptiveRateLimiter({
    baseLimit: 100,
    minLimit: 20,
    maxLimit: 500,
    windowMs: 60000,
    loadThresholds: {
      low: 0.3,
      high: 0.7,
    },
    trustScoreKey: 'trust:',
    ...config,
  }).middleware();
}
```

### Rate Limit API Endpoints

```typescript
// src/routes/rateLimit.ts
import { Router } from 'express';
import { authenticate } from '../middleware/authenticate';
import { redis } from '../cache/redis';
import { authorizationService } from '../services/authorizationService';
import { ApiResponseBuilder } from '../utils/response';

const router = Router();

// Get current rate limit status
router.get('/status', authenticate, async (req, res) => {
  const userId = req.user.id;
  const permissions = await authorizationService.getUserPermissions(userId);
  const tier = permissions.subscription.tier;

  // Get current usage for different categories
  const categories = ['default', 'auth', 'uploads', 'search', 'ai'];
  const status: Record<string, any> = {};

  for (const category of categories) {
    const key = `ratelimit:${category}:${userId}`;
    const count = await redis.zcard(key);
    const ttl = await redis.pttl(key);

    const limits = TIER_LIMITS[tier as keyof typeof TIER_LIMITS][category as RateLimitCategory];

    status[category] = {
      used: count,
      limit: limits.maxRequests,
      remaining: Math.max(0, limits.maxRequests - count),
      resetIn: Math.max(0, ttl),
      windowMs: limits.windowMs,
    };
  }

  // Get daily API quota
  const dailyKey = `quota:daily:${userId}`;
  const dailyUsage = parseInt(await redis.get(dailyKey) || '0');
  const dailyLimit = permissions.subscription.limits.api_calls_per_day;

  status.daily = {
    used: dailyUsage,
    limit: dailyLimit === -1 ? 'unlimited' : dailyLimit,
    remaining: dailyLimit === -1 ? 'unlimited' : Math.max(0, dailyLimit - dailyUsage),
  };

  ApiResponseBuilder.success({
    tier,
    status,
  }).send(res);
});

// Get rate limit headers helper (for clients to check before making requests)
router.head('/check/:category', authenticate, async (req, res) => {
  const { category } = req.params;
  const userId = req.user.id;
  const permissions = await authorizationService.getUserPermissions(userId);
  const tier = permissions.subscription.tier;

  const key = `ratelimit:${category}:${userId}`;
  const count = await redis.zcard(key);

  const limits = TIER_LIMITS[tier as keyof typeof TIER_LIMITS][category as RateLimitCategory] ||
                 TIER_LIMITS[tier as keyof typeof TIER_LIMITS].default;

  res.setHeader('X-RateLimit-Limit', limits.maxRequests);
  res.setHeader('X-RateLimit-Remaining', Math.max(0, limits.maxRequests - count));
  res.setHeader('X-RateLimit-Reset', Math.ceil((Date.now() + limits.windowMs) / 1000));

  res.status(204).end();
});

export { router as rateLimitRouter };
```

### Global Rate Limiting Middleware Setup

```typescript
// src/app.ts - Rate limiting setup
import express from 'express';
import { createRateLimiter } from './middleware/rateLimiter';
import { tieredRateLimiter } from './middleware/tieredRateLimiter';
import { dynamicRateLimiter } from './middleware/endpointRateLimiter';

const app = express();

// Global rate limit - applies to all requests
app.use(createRateLimiter({
  windowMs: 60 * 1000,     // 1 minute
  maxRequests: 1000,       // 1000 requests per minute per IP
  keyPrefix: 'ratelimit:global:',
  keyGenerator: (req) => req.ip,
  skip: (req) => {
    // Skip health checks and internal requests
    return req.path === '/health' || req.path === '/health/ready';
  },
}));

// Apply tiered rate limiting after authentication
app.use('/api/v1', tieredRateLimiter('default'));

// Apply endpoint-specific rate limiting
app.use('/api/v1', dynamicRateLimiter());

// Routes
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/users', usersRouter);
// ... other routes
```

## Gate Criteria

Before marking rate limiting complete, verify:

### Implementation Gates
- [ ] Sliding window rate limiting implemented
- [ ] Token bucket for burst handling implemented
- [ ] Redis-based distributed rate limiting working
- [ ] Rate limit headers set on all responses
- [ ] Retry-After header set on 429 responses

### Configuration Gates
- [ ] Per-endpoint rate limits configured
- [ ] Tier-based limits defined
- [ ] IP-based limits for unauthenticated requests
- [ ] User-based limits for authenticated requests
- [ ] Burst limits configured appropriately

### Mobile-Specific Gates
- [ ] Device-based rate limiting option available
- [ ] Offline queue-friendly limits documented
- [ ] Rate limit status API available
- [ ] Client SDKs can check limits before requests
- [ ] Graceful handling of intermittent connectivity

### Security Gates
- [ ] Login attempts strictly limited
- [ ] Password reset strictly limited
- [ ] No rate limit bypass possible
- [ ] DDoS protection in place
- [ ] IP reputation considered

### Monitoring Gates
- [ ] Rate limit hits logged
- [ ] Alert on unusual patterns
- [ ] Dashboard for rate limit metrics
- [ ] Per-user usage visible to admins
- [ ] System load monitored

### Testing Gates
- [ ] Unit tests for rate limiters
- [ ] Load tests verify limits work under stress
- [ ] Redis failure handled gracefully (fail open)
- [ ] Rate limit reset tested
- [ ] Concurrent request handling verified
