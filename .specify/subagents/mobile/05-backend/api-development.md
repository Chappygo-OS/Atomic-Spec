---
name: Mobile API Development
platform: mobile
description: API endpoint development optimized for mobile clients including RESTful design, GraphQL considerations, response optimization, offline support patterns, and mobile-specific error handling
model: opus
category: mobile/backend
---

# Mobile API Development Subagent

## Purpose

This subagent handles the design and implementation of API endpoints specifically optimized for mobile clients. Mobile APIs require special consideration for bandwidth efficiency, battery consumption, offline support, and handling unreliable network conditions.

## Core Responsibilities

1. RESTful API endpoint design and implementation
2. Request/response payload optimization for mobile
3. API versioning strategy
4. Error handling and response standardization
5. Pagination and data fetching strategies
6. Offline-first API patterns
7. API documentation generation

## API Architecture Patterns

### Pattern 1: RESTful API with Mobile Optimizations

```typescript
// src/app.ts - Main Application Setup
import express, { Express, Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import compression from 'compression';
import cors from 'cors';
import { rateLimit } from 'express-rate-limit';
import { config } from './config';
import { errorHandler } from './middleware/errorHandler';
import { requestLogger } from './middleware/requestLogger';
import { mobileContextMiddleware } from './middleware/mobileContext';
import { apiRouter } from './routes';

export function createApp(): Express {
  const app = express();

  // Security middleware
  app.use(helmet({
    contentSecurityPolicy: false, // Disable for API
    crossOriginEmbedderPolicy: false,
  }));

  // CORS configuration for mobile apps
  app.use(cors({
    origin: config.CORS_ORIGINS,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'X-Device-Id',
      'X-App-Version',
      'X-Platform',
      'X-Request-Id',
      'X-Idempotency-Key',
      'If-None-Match',
      'If-Modified-Since',
    ],
    exposedHeaders: [
      'X-Request-Id',
      'X-RateLimit-Limit',
      'X-RateLimit-Remaining',
      'X-RateLimit-Reset',
      'ETag',
      'Last-Modified',
    ],
    credentials: true,
    maxAge: 86400, // 24 hours preflight cache
  }));

  // Compression for bandwidth optimization
  app.use(compression({
    filter: (req, res) => {
      if (req.headers['x-no-compression']) {
        return false;
      }
      return compression.filter(req, res);
    },
    level: 6,
    threshold: 1024, // Only compress if > 1KB
  }));

  // Body parsing with size limits
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request logging
  app.use(requestLogger());

  // Mobile context extraction
  app.use(mobileContextMiddleware());

  // API routes
  app.use('/api/v1', apiRouter);

  // Error handling
  app.use(errorHandler());

  return app;
}
```

### Pattern 2: API Router Structure

```typescript
// src/routes/index.ts
import { Router } from 'express';
import { authRouter } from './auth';
import { usersRouter } from './users';
import { postsRouter } from './posts';
import { notificationsRouter } from './notifications';
import { syncRouter } from './sync';
import { authenticate } from '../middleware/authenticate';
import { validateAppVersion } from '../middleware/validateAppVersion';

const router = Router();

// Version validation for all routes
router.use(validateAppVersion({
  minVersion: '1.0.0',
  deprecatedVersions: ['1.0.0', '1.1.0'],
  forceUpdateVersions: ['0.9.0'],
}));

// Public routes
router.use('/auth', authRouter);

// Protected routes
router.use('/users', authenticate, usersRouter);
router.use('/posts', authenticate, postsRouter);
router.use('/notifications', authenticate, notificationsRouter);
router.use('/sync', authenticate, syncRouter);

export { router as apiRouter };
```

## Mobile-Optimized Response Format

### Standard Response Structure

```typescript
// src/types/api.ts
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: ApiError;
  meta?: ResponseMeta;
}

export interface ApiError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
  field?: string; // For validation errors
}

export interface ResponseMeta {
  requestId: string;
  timestamp: string;
  pagination?: PaginationMeta;
  sync?: SyncMeta;
}

export interface PaginationMeta {
  page: number;
  perPage: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
  nextCursor?: string;
}

export interface SyncMeta {
  serverTime: number;
  lastSyncToken?: string;
  hasMoreChanges?: boolean;
}

// src/utils/response.ts
import { Response } from 'express';
import { ApiResponse, ApiError, PaginationMeta, SyncMeta } from '../types/api';

export class ApiResponseBuilder<T> {
  private response: ApiResponse<T> = { success: true };

  static success<T>(data: T): ApiResponseBuilder<T> {
    const builder = new ApiResponseBuilder<T>();
    builder.response.data = data;
    return builder;
  }

  static error(error: ApiError): ApiResponseBuilder<never> {
    const builder = new ApiResponseBuilder<never>();
    builder.response.success = false;
    builder.response.error = error;
    return builder;
  }

  withPagination(pagination: PaginationMeta): this {
    this.response.meta = { ...this.response.meta, pagination } as any;
    return this;
  }

  withSync(sync: SyncMeta): this {
    this.response.meta = { ...this.response.meta, sync } as any;
    return this;
  }

  withMeta(meta: Partial<ResponseMeta>): this {
    this.response.meta = { ...this.response.meta, ...meta } as any;
    return this;
  }

  send(res: Response, statusCode: number = 200): void {
    this.response.meta = {
      ...this.response.meta,
      requestId: res.locals.requestId,
      timestamp: new Date().toISOString(),
    };

    res.status(statusCode).json(this.response);
  }
}

// Usage example in controller
export async function getUsers(req: Request, res: Response) {
  const { page = 1, limit = 20 } = req.query;

  const { users, total } = await userService.findAll({
    page: Number(page),
    limit: Math.min(Number(limit), 100),
  });

  ApiResponseBuilder.success(users)
    .withPagination({
      page: Number(page),
      perPage: Number(limit),
      total,
      totalPages: Math.ceil(total / Number(limit)),
      hasMore: Number(page) * Number(limit) < total,
    })
    .send(res);
}
```

## Error Handling for Mobile

```typescript
// src/errors/AppError.ts
export class AppError extends Error {
  constructor(
    public code: string,
    public message: string,
    public statusCode: number = 500,
    public details?: Record<string, unknown>,
    public isOperational: boolean = true,
  ) {
    super(message);
    Error.captureStackTrace(this, this.constructor);
  }
}

// Predefined error types for mobile
export const ErrorCodes = {
  // Authentication errors (401)
  AUTH_TOKEN_EXPIRED: 'AUTH_TOKEN_EXPIRED',
  AUTH_TOKEN_INVALID: 'AUTH_TOKEN_INVALID',
  AUTH_REFRESH_REQUIRED: 'AUTH_REFRESH_REQUIRED',
  AUTH_SESSION_REVOKED: 'AUTH_SESSION_REVOKED',

  // Authorization errors (403)
  ACCESS_DENIED: 'ACCESS_DENIED',
  SUBSCRIPTION_REQUIRED: 'SUBSCRIPTION_REQUIRED',
  FEATURE_LOCKED: 'FEATURE_LOCKED',

  // Validation errors (400)
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  INVALID_INPUT: 'INVALID_INPUT',
  MISSING_REQUIRED_FIELD: 'MISSING_REQUIRED_FIELD',

  // Resource errors (404, 409)
  RESOURCE_NOT_FOUND: 'RESOURCE_NOT_FOUND',
  RESOURCE_CONFLICT: 'RESOURCE_CONFLICT',
  RESOURCE_DELETED: 'RESOURCE_DELETED',

  // Rate limiting (429)
  RATE_LIMIT_EXCEEDED: 'RATE_LIMIT_EXCEEDED',

  // Server errors (500)
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE',
  DATABASE_ERROR: 'DATABASE_ERROR',

  // Mobile-specific errors
  APP_UPDATE_REQUIRED: 'APP_UPDATE_REQUIRED',
  APP_VERSION_DEPRECATED: 'APP_VERSION_DEPRECATED',
  DEVICE_NOT_REGISTERED: 'DEVICE_NOT_REGISTERED',
  SYNC_CONFLICT: 'SYNC_CONFLICT',
} as const;

// src/middleware/errorHandler.ts
import { Request, Response, NextFunction } from 'express';
import { AppError, ErrorCodes } from '../errors/AppError';
import { ZodError } from 'zod';
import { logger } from '../utils/logger';

export function errorHandler() {
  return (err: Error, req: Request, res: Response, next: NextFunction) => {
    // Log error
    logger.error({
      error: err.message,
      stack: err.stack,
      requestId: res.locals.requestId,
      path: req.path,
      method: req.method,
      deviceId: req.mobileContext?.deviceId,
    });

    // Handle known operational errors
    if (err instanceof AppError && err.isOperational) {
      return res.status(err.statusCode).json({
        success: false,
        error: {
          code: err.code,
          message: err.message,
          details: err.details,
        },
        meta: {
          requestId: res.locals.requestId,
          timestamp: new Date().toISOString(),
        },
      });
    }

    // Handle Zod validation errors
    if (err instanceof ZodError) {
      const validationErrors = err.errors.map(e => ({
        field: e.path.join('.'),
        message: e.message,
        code: e.code,
      }));

      return res.status(400).json({
        success: false,
        error: {
          code: ErrorCodes.VALIDATION_ERROR,
          message: 'Validation failed',
          details: { errors: validationErrors },
        },
        meta: {
          requestId: res.locals.requestId,
          timestamp: new Date().toISOString(),
        },
      });
    }

    // Handle unknown errors
    const isProduction = process.env.NODE_ENV === 'production';

    res.status(500).json({
      success: false,
      error: {
        code: ErrorCodes.INTERNAL_ERROR,
        message: isProduction ? 'An unexpected error occurred' : err.message,
        details: isProduction ? undefined : { stack: err.stack },
      },
      meta: {
        requestId: res.locals.requestId,
        timestamp: new Date().toISOString(),
      },
    });
  };
}
```

## Mobile-Optimized Endpoints

### Batch Requests for Reducing Round Trips

```typescript
// src/routes/batch.ts
import { Router } from 'express';
import { z } from 'zod';
import { validateRequest } from '../middleware/validateRequest';

const router = Router();

const BatchRequestSchema = z.object({
  requests: z.array(z.object({
    id: z.string(),
    method: z.enum(['GET', 'POST', 'PUT', 'PATCH', 'DELETE']),
    path: z.string().startsWith('/'),
    body: z.record(z.unknown()).optional(),
    headers: z.record(z.string()).optional(),
  })).max(20), // Limit batch size
});

router.post('/batch', validateRequest(BatchRequestSchema), async (req, res) => {
  const { requests } = req.body;

  const results = await Promise.all(
    requests.map(async (request) => {
      try {
        const result = await executeBatchRequest(req, request);
        return {
          id: request.id,
          status: result.status,
          body: result.body,
          headers: result.headers,
        };
      } catch (error) {
        return {
          id: request.id,
          status: 500,
          body: { error: error.message },
        };
      }
    })
  );

  res.json({
    success: true,
    data: { results },
    meta: {
      requestId: res.locals.requestId,
      timestamp: new Date().toISOString(),
    },
  });
});

async function executeBatchRequest(parentReq: Request, batchReq: BatchRequest) {
  // Create a mock request/response for internal routing
  // This is a simplified version - consider using a proper internal routing solution
  const internalReq = createInternalRequest(parentReq, batchReq);
  const internalRes = createInternalResponse();

  await app._router.handle(internalReq, internalRes, () => {});

  return {
    status: internalRes.statusCode,
    body: internalRes.body,
    headers: internalRes.headers,
  };
}

export { router as batchRouter };
```

### Delta Sync for Offline Support

```typescript
// src/routes/sync.ts
import { Router } from 'express';
import { z } from 'zod';
import { validateRequest } from '../middleware/validateRequest';
import { syncService } from '../services/syncService';

const router = Router();

const SyncRequestSchema = z.object({
  lastSyncToken: z.string().optional(),
  resources: z.array(z.enum(['users', 'posts', 'comments', 'settings'])),
  includeDeleted: z.boolean().default(true),
});

// Delta sync endpoint
router.post('/delta', validateRequest(SyncRequestSchema), async (req, res) => {
  const { lastSyncToken, resources, includeDeleted } = req.body;
  const userId = req.user.id;

  const syncResult = await syncService.getDeltaChanges({
    userId,
    lastSyncToken,
    resources,
    includeDeleted,
    limit: 500, // Limit changes per request
  });

  res.json({
    success: true,
    data: {
      changes: syncResult.changes,
      deletions: syncResult.deletions,
    },
    meta: {
      requestId: res.locals.requestId,
      timestamp: new Date().toISOString(),
      sync: {
        serverTime: Date.now(),
        lastSyncToken: syncResult.newSyncToken,
        hasMoreChanges: syncResult.hasMore,
      },
    },
  });
});

// Push local changes
router.post('/push', async (req, res) => {
  const { changes, clientSyncToken } = req.body;
  const userId = req.user.id;

  const result = await syncService.applyChanges({
    userId,
    changes,
    clientSyncToken,
  });

  if (result.conflicts.length > 0) {
    return res.status(409).json({
      success: false,
      error: {
        code: 'SYNC_CONFLICT',
        message: 'Sync conflicts detected',
        details: { conflicts: result.conflicts },
      },
      meta: {
        requestId: res.locals.requestId,
        timestamp: new Date().toISOString(),
      },
    });
  }

  res.json({
    success: true,
    data: {
      applied: result.applied,
      newSyncToken: result.newSyncToken,
    },
    meta: {
      requestId: res.locals.requestId,
      timestamp: new Date().toISOString(),
    },
  });
});

export { router as syncRouter };

// src/services/syncService.ts
import { db } from '../database';
import { generateSyncToken, parseSyncToken } from '../utils/sync';

interface SyncChange {
  id: string;
  resourceType: string;
  resourceId: string;
  operation: 'create' | 'update' | 'delete';
  data: Record<string, unknown>;
  timestamp: number;
  version: number;
}

export const syncService = {
  async getDeltaChanges(params: {
    userId: string;
    lastSyncToken?: string;
    resources: string[];
    includeDeleted: boolean;
    limit: number;
  }) {
    const { lastSyncTime, lastVersion } = params.lastSyncToken
      ? parseSyncToken(params.lastSyncToken)
      : { lastSyncTime: 0, lastVersion: 0 };

    const changes: SyncChange[] = [];
    const deletions: { resourceType: string; resourceId: string }[] = [];

    for (const resource of params.resources) {
      // Get modified records
      const modified = await db(resource)
        .where('user_id', params.userId)
        .where('updated_at', '>', new Date(lastSyncTime))
        .orderBy('updated_at', 'asc')
        .limit(params.limit);

      for (const record of modified) {
        changes.push({
          id: `${resource}:${record.id}`,
          resourceType: resource,
          resourceId: record.id,
          operation: record.created_at.getTime() === record.updated_at.getTime()
            ? 'create'
            : 'update',
          data: record,
          timestamp: record.updated_at.getTime(),
          version: record.version,
        });
      }

      // Get deleted records
      if (params.includeDeleted) {
        const deleted = await db(`${resource}_deleted`)
          .where('user_id', params.userId)
          .where('deleted_at', '>', new Date(lastSyncTime))
          .select('resource_id', 'deleted_at');

        for (const record of deleted) {
          deletions.push({
            resourceType: resource,
            resourceId: record.resource_id,
          });
        }
      }
    }

    // Sort by timestamp and limit
    changes.sort((a, b) => a.timestamp - b.timestamp);
    const limitedChanges = changes.slice(0, params.limit);
    const hasMore = changes.length > params.limit;

    const latestChange = limitedChanges[limitedChanges.length - 1];
    const newSyncToken = generateSyncToken(
      latestChange?.timestamp || Date.now(),
      latestChange?.version || 0
    );

    return {
      changes: limitedChanges,
      deletions,
      newSyncToken,
      hasMore,
    };
  },

  async applyChanges(params: {
    userId: string;
    changes: SyncChange[];
    clientSyncToken: string;
  }) {
    const conflicts: SyncChange[] = [];
    const applied: string[] = [];

    await db.transaction(async (trx) => {
      for (const change of params.changes) {
        const existing = await trx(change.resourceType)
          .where('id', change.resourceId)
          .first();

        // Check for conflicts
        if (existing && existing.version > change.version) {
          conflicts.push({
            ...change,
            data: existing, // Return server version
          });
          continue;
        }

        // Apply change
        if (change.operation === 'create') {
          await trx(change.resourceType).insert({
            ...change.data,
            user_id: params.userId,
            version: 1,
          });
        } else if (change.operation === 'update') {
          await trx(change.resourceType)
            .where('id', change.resourceId)
            .update({
              ...change.data,
              version: (existing?.version || 0) + 1,
              updated_at: new Date(),
            });
        } else if (change.operation === 'delete') {
          await trx(change.resourceType)
            .where('id', change.resourceId)
            .delete();

          // Track deletion for other devices
          await trx(`${change.resourceType}_deleted`).insert({
            resource_id: change.resourceId,
            user_id: params.userId,
            deleted_at: new Date(),
          });
        }

        applied.push(change.id);
      }
    });

    return {
      conflicts,
      applied,
      newSyncToken: generateSyncToken(Date.now(), 0),
    };
  },
};
```

## Pagination Strategies

```typescript
// src/utils/pagination.ts
import { Request } from 'express';
import { z } from 'zod';

// Cursor-based pagination (recommended for mobile)
export const CursorPaginationSchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().min(1).max(100).default(20),
  direction: z.enum(['forward', 'backward']).default('forward'),
});

export interface CursorPaginationResult<T> {
  items: T[];
  nextCursor: string | null;
  prevCursor: string | null;
  hasMore: boolean;
}

export function encodeCursor(data: { id: string; timestamp: number }): string {
  return Buffer.from(JSON.stringify(data)).toString('base64url');
}

export function decodeCursor(cursor: string): { id: string; timestamp: number } | null {
  try {
    return JSON.parse(Buffer.from(cursor, 'base64url').toString());
  } catch {
    return null;
  }
}

// Usage in service
export async function getPaginatedPosts(params: {
  userId: string;
  cursor?: string;
  limit: number;
  direction: 'forward' | 'backward';
}): Promise<CursorPaginationResult<Post>> {
  const cursorData = params.cursor ? decodeCursor(params.cursor) : null;

  let query = db('posts')
    .where('user_id', params.userId)
    .orderBy('created_at', params.direction === 'forward' ? 'desc' : 'asc')
    .orderBy('id', params.direction === 'forward' ? 'desc' : 'asc')
    .limit(params.limit + 1);

  if (cursorData) {
    if (params.direction === 'forward') {
      query = query.where((builder) => {
        builder
          .where('created_at', '<', new Date(cursorData.timestamp))
          .orWhere((subBuilder) => {
            subBuilder
              .where('created_at', '=', new Date(cursorData.timestamp))
              .where('id', '<', cursorData.id);
          });
      });
    } else {
      query = query.where((builder) => {
        builder
          .where('created_at', '>', new Date(cursorData.timestamp))
          .orWhere((subBuilder) => {
            subBuilder
              .where('created_at', '=', new Date(cursorData.timestamp))
              .where('id', '>', cursorData.id);
          });
      });
    }
  }

  const items = await query;
  const hasMore = items.length > params.limit;

  if (hasMore) {
    items.pop();
  }

  if (params.direction === 'backward') {
    items.reverse();
  }

  const firstItem = items[0];
  const lastItem = items[items.length - 1];

  return {
    items,
    nextCursor: hasMore && lastItem
      ? encodeCursor({ id: lastItem.id, timestamp: lastItem.created_at.getTime() })
      : null,
    prevCursor: firstItem
      ? encodeCursor({ id: firstItem.id, timestamp: firstItem.created_at.getTime() })
      : null,
    hasMore,
  };
}
```

## API Versioning

```typescript
// src/middleware/apiVersion.ts
import { Request, Response, NextFunction } from 'express';
import semver from 'semver';

interface VersionConfig {
  minVersion: string;
  currentVersion: string;
  deprecatedVersions: string[];
  sunsetVersions: string[];
}

export function apiVersionMiddleware(config: VersionConfig) {
  return (req: Request, res: Response, next: NextFunction) => {
    const clientVersion = req.headers['x-api-version'] as string || config.currentVersion;

    // Add version info to response headers
    res.setHeader('X-API-Version', config.currentVersion);
    res.setHeader('X-API-Min-Version', config.minVersion);

    // Check if version is sunset (no longer supported)
    if (config.sunsetVersions.includes(clientVersion)) {
      return res.status(426).json({
        success: false,
        error: {
          code: 'API_VERSION_UNSUPPORTED',
          message: `API version ${clientVersion} is no longer supported. Please update to ${config.minVersion} or later.`,
          details: {
            clientVersion,
            minVersion: config.minVersion,
            currentVersion: config.currentVersion,
          },
        },
      });
    }

    // Check if version is below minimum
    if (semver.lt(clientVersion, config.minVersion)) {
      return res.status(426).json({
        success: false,
        error: {
          code: 'API_VERSION_TOO_OLD',
          message: `API version ${clientVersion} is below minimum supported version.`,
          details: {
            clientVersion,
            minVersion: config.minVersion,
          },
        },
      });
    }

    // Warn if version is deprecated
    if (config.deprecatedVersions.includes(clientVersion)) {
      res.setHeader('X-API-Deprecated', 'true');
      res.setHeader('X-API-Deprecation-Date', '2024-06-01');
      res.setHeader('Warning', `299 - "API version ${clientVersion} is deprecated"`);
    }

    req.apiVersion = clientVersion;
    next();
  };
}

// Version-specific route handlers
export function versionedHandler(handlers: Record<string, RequestHandler>) {
  return (req: Request, res: Response, next: NextFunction) => {
    const version = req.apiVersion;

    // Find the appropriate handler for the version
    const sortedVersions = Object.keys(handlers).sort(semver.rcompare);

    for (const handlerVersion of sortedVersions) {
      if (semver.gte(version, handlerVersion)) {
        return handlers[handlerVersion](req, res, next);
      }
    }

    // Default to latest version
    return handlers[sortedVersions[0]](req, res, next);
  };
}

// Usage
router.get('/users/:id', versionedHandler({
  '2.0.0': getUserV2,
  '1.0.0': getUserV1,
}));
```

## Request Validation

```typescript
// src/middleware/validateRequest.ts
import { Request, Response, NextFunction } from 'express';
import { z, ZodSchema } from 'zod';

interface ValidationSchemas {
  body?: ZodSchema;
  query?: ZodSchema;
  params?: ZodSchema;
}

export function validateRequest(schemas: ValidationSchemas | ZodSchema) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      // If a single schema is passed, assume it's for body
      if (schemas instanceof z.ZodType) {
        req.body = await schemas.parseAsync(req.body);
        return next();
      }

      // Validate each part
      if (schemas.body) {
        req.body = await schemas.body.parseAsync(req.body);
      }
      if (schemas.query) {
        req.query = await schemas.query.parseAsync(req.query);
      }
      if (schemas.params) {
        req.params = await schemas.params.parseAsync(req.params);
      }

      next();
    } catch (error) {
      next(error); // Let error handler format the response
    }
  };
}

// Common validation schemas for mobile
export const MobileSchemas = {
  pagination: z.object({
    cursor: z.string().optional(),
    limit: z.coerce.number().min(1).max(100).default(20),
  }),

  id: z.object({
    id: z.string().uuid(),
  }),

  search: z.object({
    q: z.string().min(1).max(100),
    filters: z.record(z.string()).optional(),
    sort: z.enum(['relevance', 'newest', 'oldest']).default('relevance'),
  }),

  deviceInfo: z.object({
    deviceId: z.string().min(1),
    deviceModel: z.string().optional(),
    osVersion: z.string().optional(),
    appVersion: z.string(),
    pushToken: z.string().optional(),
  }),
};

// Usage
router.get(
  '/posts',
  validateRequest({ query: MobileSchemas.pagination }),
  postsController.list
);
```

## Caching Headers for Mobile

```typescript
// src/middleware/caching.ts
import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';

interface CacheOptions {
  maxAge?: number;
  private?: boolean;
  mustRevalidate?: boolean;
  staleWhileRevalidate?: number;
  staleIfError?: number;
}

export function cacheControl(options: CacheOptions) {
  return (req: Request, res: Response, next: NextFunction) => {
    const directives: string[] = [];

    if (options.private) {
      directives.push('private');
    } else {
      directives.push('public');
    }

    if (options.maxAge !== undefined) {
      directives.push(`max-age=${options.maxAge}`);
    }

    if (options.mustRevalidate) {
      directives.push('must-revalidate');
    }

    if (options.staleWhileRevalidate !== undefined) {
      directives.push(`stale-while-revalidate=${options.staleWhileRevalidate}`);
    }

    if (options.staleIfError !== undefined) {
      directives.push(`stale-if-error=${options.staleIfError}`);
    }

    res.setHeader('Cache-Control', directives.join(', '));
    next();
  };
}

// ETag generation
export function generateETag(data: unknown): string {
  const hash = crypto
    .createHash('md5')
    .update(JSON.stringify(data))
    .digest('hex');
  return `"${hash}"`;
}

export function withETag() {
  return (req: Request, res: Response, next: NextFunction) => {
    const originalJson = res.json.bind(res);

    res.json = (body: unknown) => {
      // Generate ETag from response body
      const etag = generateETag(body);
      res.setHeader('ETag', etag);

      // Check If-None-Match header
      const ifNoneMatch = req.headers['if-none-match'];
      if (ifNoneMatch === etag) {
        res.status(304);
        return res.end();
      }

      return originalJson(body);
    };

    next();
  };
}

// Usage
router.get(
  '/users/:id',
  cacheControl({ maxAge: 60, private: true, mustRevalidate: true }),
  withETag(),
  usersController.get
);
```

## API Documentation

```typescript
// src/docs/swagger.ts
import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';
import { Express } from 'express';

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Mobile Backend API',
      version: '1.0.0',
      description: 'API documentation for mobile application backend',
    },
    servers: [
      { url: 'https://api.example.com/v1', description: 'Production' },
      { url: 'https://api.staging.example.com/v1', description: 'Staging' },
      { url: 'http://localhost:3000/api/v1', description: 'Development' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        Error: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: false },
            error: {
              type: 'object',
              properties: {
                code: { type: 'string', example: 'VALIDATION_ERROR' },
                message: { type: 'string', example: 'Validation failed' },
                details: { type: 'object' },
              },
            },
          },
        },
        Pagination: {
          type: 'object',
          properties: {
            page: { type: 'integer' },
            perPage: { type: 'integer' },
            total: { type: 'integer' },
            totalPages: { type: 'integer' },
            hasMore: { type: 'boolean' },
          },
        },
      },
      parameters: {
        DeviceId: {
          in: 'header',
          name: 'X-Device-Id',
          schema: { type: 'string' },
          required: true,
          description: 'Unique device identifier',
        },
        AppVersion: {
          in: 'header',
          name: 'X-App-Version',
          schema: { type: 'string' },
          required: true,
          description: 'Mobile app version',
        },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  apis: ['./src/routes/**/*.ts'],
};

const specs = swaggerJsdoc(options);

export function setupSwagger(app: Express) {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(specs, {
    explorer: true,
    customCss: '.swagger-ui .topbar { display: none }',
  }));

  // Serve raw OpenAPI spec
  app.get('/api-docs.json', (req, res) => {
    res.json(specs);
  });
}

// Example route documentation
/**
 * @swagger
 * /users/{id}:
 *   get:
 *     summary: Get user by ID
 *     tags: [Users]
 *     parameters:
 *       - $ref: '#/components/parameters/DeviceId'
 *       - $ref: '#/components/parameters/AppVersion'
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: User details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/User'
 *       404:
 *         description: User not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
```

## Gate Criteria

Before marking API development complete, verify:

### Design Gates
- [ ] All endpoints follow RESTful conventions
- [ ] Response format is consistent across all endpoints
- [ ] Error codes and messages are standardized
- [ ] API versioning strategy is implemented
- [ ] Pagination is implemented for list endpoints

### Mobile Optimization Gates
- [ ] Response payloads are minimized (no unnecessary fields)
- [ ] Batch endpoints available for reducing round trips
- [ ] Delta sync endpoints implemented for offline support
- [ ] Appropriate cache headers set for each endpoint
- [ ] ETag support implemented for conditional requests

### Validation Gates
- [ ] All inputs are validated with appropriate schemas
- [ ] Validation errors return field-specific messages
- [ ] Request size limits are enforced
- [ ] Content-Type validation is implemented

### Documentation Gates
- [ ] OpenAPI/Swagger documentation generated
- [ ] All endpoints documented with examples
- [ ] Error codes documented with resolution steps
- [ ] Rate limits documented per endpoint
- [ ] Mobile-specific headers documented

### Security Gates
- [ ] Authentication required for protected endpoints
- [ ] Authorization checks implemented
- [ ] Sensitive data filtered from responses
- [ ] Request logging excludes sensitive data
- [ ] CORS configured appropriately

### Testing Gates
- [ ] Unit tests for all controllers
- [ ] Integration tests for API flows
- [ ] Contract tests for response schemas
- [ ] Performance tests for response times
- [ ] Load tests completed
