---
name: Mobile Backend Webhooks
platform: mobile
description: Webhooks and event-driven integrations for mobile backends including webhook management, event publishing, delivery guarantees, signature verification, and retry mechanisms
model: opus
category: mobile/backend
---

# Mobile Backend Webhooks Subagent

## Purpose

This subagent handles all aspects of webhook implementation for mobile backends. Webhooks enable real-time integration with external services and allow mobile apps to receive push-based updates rather than polling, which is crucial for efficient mobile data synchronization and third-party integrations.

## Core Responsibilities

1. Webhook registration and management
2. Event publishing and subscription
3. Secure webhook delivery with signatures
4. Delivery retry and exponential backoff
5. Webhook delivery logging and monitoring
6. Inbound webhook processing
7. Event filtering and transformation

## Webhook Architecture

### Database Schema

```sql
-- migrations/006_create_webhooks.sql
-- Up Migration

-- Webhook endpoints registered by users/integrations
CREATE TABLE webhooks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Webhook configuration
    name VARCHAR(255) NOT NULL,
    url TEXT NOT NULL,
    secret VARCHAR(255) NOT NULL,  -- For signing payloads

    -- Event subscriptions (array of event types)
    events TEXT[] NOT NULL DEFAULT '{}',

    -- Status
    enabled BOOLEAN NOT NULL DEFAULT true,
    verified BOOLEAN NOT NULL DEFAULT false,
    verified_at TIMESTAMPTZ,

    -- Delivery settings
    timeout_seconds INTEGER NOT NULL DEFAULT 30,
    max_retries INTEGER NOT NULL DEFAULT 5,

    -- Headers to include
    headers JSONB DEFAULT '{}',

    -- Stats
    last_triggered_at TIMESTAMPTZ,
    last_success_at TIMESTAMPTZ,
    last_failure_at TIMESTAMPTZ,
    failure_count INTEGER NOT NULL DEFAULT 0,
    success_count INTEGER NOT NULL DEFAULT 0,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhooks_user ON webhooks(user_id);
CREATE INDEX idx_webhooks_events ON webhooks USING GIN (events);
CREATE INDEX idx_webhooks_enabled ON webhooks(enabled) WHERE enabled = true;

-- Webhook delivery attempts
CREATE TABLE webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    webhook_id UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,

    -- Event info
    event_type VARCHAR(100) NOT NULL,
    event_id VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,

    -- Delivery attempt info
    attempt_number INTEGER NOT NULL DEFAULT 1,
    max_attempts INTEGER NOT NULL,

    -- Response info
    response_status INTEGER,
    response_body TEXT,
    response_time_ms INTEGER,

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'success', 'failed', 'retrying')),

    -- Error info
    error_message TEXT,
    error_code VARCHAR(50),

    -- Timestamps
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_deliveries_webhook ON webhook_deliveries(webhook_id);
CREATE INDEX idx_webhook_deliveries_status ON webhook_deliveries(status);
CREATE INDEX idx_webhook_deliveries_scheduled ON webhook_deliveries(scheduled_at)
    WHERE status IN ('pending', 'retrying');
CREATE INDEX idx_webhook_deliveries_event ON webhook_deliveries(event_id);

-- Event log for event sourcing / replay
CREATE TABLE webhook_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(100) NOT NULL,
    event_id VARCHAR(100) NOT NULL UNIQUE,
    payload JSONB NOT NULL,

    -- Source info
    source_type VARCHAR(50) NOT NULL,  -- 'user', 'system', 'external'
    source_id VARCHAR(100),

    -- Processing status
    processed BOOLEAN NOT NULL DEFAULT false,
    processed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_events_type ON webhook_events(event_type);
CREATE INDEX idx_webhook_events_created ON webhook_events(created_at);
CREATE INDEX idx_webhook_events_unprocessed ON webhook_events(created_at)
    WHERE processed = false;

-- Down Migration
DROP TABLE IF EXISTS webhook_events;
DROP TABLE IF EXISTS webhook_deliveries;
DROP TABLE IF EXISTS webhooks;
```

### Webhook Service

```typescript
// src/services/webhookService.ts
import { v4 as uuidv4 } from 'uuid';
import crypto from 'crypto';
import { db } from '../database';
import { queueService, QUEUES } from '../queue';
import { AppError, ErrorCodes } from '../errors/AppError';

// Available webhook events
export const WEBHOOK_EVENTS = {
  // User events
  'user.created': 'User was created',
  'user.updated': 'User profile was updated',
  'user.deleted': 'User was deleted',

  // Post events
  'post.created': 'Post was created',
  'post.updated': 'Post was updated',
  'post.deleted': 'Post was deleted',
  'post.published': 'Post was published',

  // Comment events
  'comment.created': 'Comment was added',
  'comment.updated': 'Comment was updated',
  'comment.deleted': 'Comment was deleted',

  // Subscription events
  'subscription.created': 'Subscription was created',
  'subscription.updated': 'Subscription was updated',
  'subscription.canceled': 'Subscription was canceled',
  'subscription.renewed': 'Subscription was renewed',

  // Payment events
  'payment.succeeded': 'Payment succeeded',
  'payment.failed': 'Payment failed',
  'payment.refunded': 'Payment was refunded',

  // File events
  'file.uploaded': 'File was uploaded',
  'file.processed': 'File processing completed',
  'file.deleted': 'File was deleted',

  // Notification events
  'notification.created': 'Notification was created',
} as const;

export type WebhookEventType = keyof typeof WEBHOOK_EVENTS;

interface Webhook {
  id: string;
  user_id: string;
  name: string;
  url: string;
  secret: string;
  events: WebhookEventType[];
  enabled: boolean;
  verified: boolean;
  headers: Record<string, string>;
  timeout_seconds: number;
  max_retries: number;
}

interface WebhookEvent {
  type: WebhookEventType;
  id: string;
  timestamp: string;
  data: Record<string, unknown>;
}

export class WebhookService {
  // Register a new webhook
  async createWebhook(
    userId: string,
    data: {
      name: string;
      url: string;
      events: WebhookEventType[];
      headers?: Record<string, string>;
    }
  ): Promise<Webhook> {
    // Validate URL
    try {
      new URL(data.url);
    } catch {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Invalid webhook URL', 400);
    }

    // Validate events
    for (const event of data.events) {
      if (!WEBHOOK_EVENTS[event]) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          `Invalid event type: ${event}`,
          400
        );
      }
    }

    // Generate secret
    const secret = this.generateSecret();

    const [webhook] = await db('webhooks')
      .insert({
        user_id: userId,
        name: data.name,
        url: data.url,
        secret,
        events: data.events,
        headers: data.headers || {},
      })
      .returning('*');

    // Send verification webhook
    await this.sendVerificationWebhook(webhook);

    return webhook;
  }

  // Update webhook
  async updateWebhook(
    userId: string,
    webhookId: string,
    data: Partial<{
      name: string;
      url: string;
      events: WebhookEventType[];
      enabled: boolean;
      headers: Record<string, string>;
    }>
  ): Promise<Webhook> {
    const webhook = await db('webhooks')
      .where({ id: webhookId, user_id: userId })
      .first();

    if (!webhook) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Webhook not found', 404);
    }

    // If URL changed, require re-verification
    const needsReverification = data.url && data.url !== webhook.url;

    const [updated] = await db('webhooks')
      .where('id', webhookId)
      .update({
        ...data,
        verified: needsReverification ? false : webhook.verified,
        updated_at: new Date(),
      })
      .returning('*');

    if (needsReverification) {
      await this.sendVerificationWebhook(updated);
    }

    return updated;
  }

  // Delete webhook
  async deleteWebhook(userId: string, webhookId: string): Promise<void> {
    const result = await db('webhooks')
      .where({ id: webhookId, user_id: userId })
      .delete();

    if (result === 0) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Webhook not found', 404);
    }
  }

  // Get user's webhooks
  async getUserWebhooks(userId: string): Promise<Webhook[]> {
    return db('webhooks')
      .where('user_id', userId)
      .orderBy('created_at', 'desc');
  }

  // Regenerate webhook secret
  async regenerateSecret(userId: string, webhookId: string): Promise<string> {
    const webhook = await db('webhooks')
      .where({ id: webhookId, user_id: userId })
      .first();

    if (!webhook) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Webhook not found', 404);
    }

    const newSecret = this.generateSecret();

    await db('webhooks')
      .where('id', webhookId)
      .update({
        secret: newSecret,
        updated_at: new Date(),
      });

    return newSecret;
  }

  // Publish event to all subscribed webhooks
  async publishEvent(
    eventType: WebhookEventType,
    data: Record<string, unknown>,
    options?: {
      userId?: string;
      sourceType?: 'user' | 'system' | 'external';
      sourceId?: string;
    }
  ): Promise<void> {
    const eventId = uuidv4();
    const timestamp = new Date().toISOString();

    // Store event for replay capability
    await db('webhook_events').insert({
      event_type: eventType,
      event_id: eventId,
      payload: data,
      source_type: options?.sourceType || 'system',
      source_id: options?.sourceId,
    });

    // Find all webhooks subscribed to this event
    let query = db('webhooks')
      .where('enabled', true)
      .whereRaw("? = ANY(events)", [eventType]);

    // If user-specific, only that user's webhooks
    if (options?.userId) {
      query = query.where('user_id', options.userId);
    }

    const webhooks = await query;

    // Queue delivery for each webhook
    for (const webhook of webhooks) {
      await queueService.addJob(QUEUES.WEBHOOKS, {
        type: 'webhook',
        webhookId: webhook.id,
        url: webhook.url,
        event: eventType,
        payload: {
          type: eventType,
          id: eventId,
          timestamp,
          data,
        },
        secret: webhook.secret,
        headers: webhook.headers,
      });
    }

    // Mark event as processed
    await db('webhook_events')
      .where('event_id', eventId)
      .update({ processed: true, processed_at: new Date() });
  }

  // Send verification webhook
  private async sendVerificationWebhook(webhook: Webhook): Promise<void> {
    const verificationToken = crypto.randomBytes(32).toString('hex');

    // Store verification token
    await redis.set(
      `webhook:verify:${webhook.id}`,
      verificationToken,
      'EX',
      86400 // 24 hours
    );

    await queueService.addJob(QUEUES.WEBHOOKS, {
      type: 'webhook',
      webhookId: webhook.id,
      url: webhook.url,
      event: 'webhook.verification',
      payload: {
        type: 'webhook.verification',
        id: uuidv4(),
        timestamp: new Date().toISOString(),
        data: {
          webhookId: webhook.id,
          verificationToken,
        },
      },
      secret: webhook.secret,
      headers: webhook.headers,
    });
  }

  // Verify webhook (called when endpoint responds with token)
  async verifyWebhook(webhookId: string, token: string): Promise<boolean> {
    const storedToken = await redis.get(`webhook:verify:${webhookId}`);

    if (!storedToken || storedToken !== token) {
      return false;
    }

    await db('webhooks')
      .where('id', webhookId)
      .update({
        verified: true,
        verified_at: new Date(),
      });

    await redis.del(`webhook:verify:${webhookId}`);

    return true;
  }

  // Generate signature for payload
  generateSignature(payload: string, secret: string, timestamp: number): string {
    const signedPayload = `${timestamp}.${payload}`;
    return crypto
      .createHmac('sha256', secret)
      .update(signedPayload)
      .digest('hex');
  }

  // Verify incoming webhook signature
  verifySignature(
    payload: string,
    signature: string,
    secret: string,
    timestamp: number,
    tolerance: number = 300 // 5 minutes
  ): boolean {
    // Check timestamp tolerance
    const now = Math.floor(Date.now() / 1000);
    if (Math.abs(now - timestamp) > tolerance) {
      return false;
    }

    // Verify signature
    const expectedSignature = this.generateSignature(payload, secret, timestamp);
    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature)
    );
  }

  private generateSecret(): string {
    return `whsec_${crypto.randomBytes(32).toString('hex')}`;
  }

  // Get webhook delivery history
  async getDeliveryHistory(
    userId: string,
    webhookId: string,
    options: { limit?: number; offset?: number }
  ): Promise<any[]> {
    const webhook = await db('webhooks')
      .where({ id: webhookId, user_id: userId })
      .first();

    if (!webhook) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Webhook not found', 404);
    }

    return db('webhook_deliveries')
      .where('webhook_id', webhookId)
      .orderBy('created_at', 'desc')
      .limit(options.limit || 50)
      .offset(options.offset || 0);
  }

  // Retry failed delivery
  async retryDelivery(userId: string, deliveryId: string): Promise<void> {
    const delivery = await db('webhook_deliveries')
      .join('webhooks', 'webhooks.id', 'webhook_deliveries.webhook_id')
      .where('webhook_deliveries.id', deliveryId)
      .where('webhooks.user_id', userId)
      .select('webhook_deliveries.*', 'webhooks.url', 'webhooks.secret', 'webhooks.headers')
      .first();

    if (!delivery) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Delivery not found', 404);
    }

    // Queue retry
    await queueService.addJob(QUEUES.WEBHOOKS, {
      type: 'webhook',
      webhookId: delivery.webhook_id,
      url: delivery.url,
      event: delivery.event_type,
      payload: delivery.payload,
      secret: delivery.secret,
      headers: delivery.headers,
      deliveryId: delivery.id,
      isRetry: true,
    });
  }
}

export const webhookService = new WebhookService();
```

### Webhook Delivery Handler

```typescript
// src/workers/handlers/webhookHandler.ts
import { Job } from 'bullmq';
import axios, { AxiosError } from 'axios';
import { db } from '../../database';
import { webhookService } from '../../services/webhookService';
import { logger } from '../../utils/logger';

interface WebhookJobData {
  type: 'webhook';
  webhookId: string;
  url: string;
  event: string;
  payload: Record<string, unknown>;
  secret: string;
  headers?: Record<string, string>;
  deliveryId?: string;
  isRetry?: boolean;
}

export async function webhookHandler(job: Job<WebhookJobData>): Promise<void> {
  const { webhookId, url, event, payload, secret, headers = {}, deliveryId, isRetry } = job.data;

  const startTime = Date.now();
  const timestamp = Math.floor(Date.now() / 1000);
  const body = JSON.stringify(payload);

  // Generate signature
  const signature = webhookService.generateSignature(body, secret, timestamp);

  // Create or update delivery record
  let delivery;
  if (deliveryId && isRetry) {
    delivery = await db('webhook_deliveries')
      .where('id', deliveryId)
      .first();

    await db('webhook_deliveries')
      .where('id', deliveryId)
      .update({
        attempt_number: delivery.attempt_number + 1,
        status: 'retrying',
        scheduled_at: new Date(),
      });
  } else {
    [delivery] = await db('webhook_deliveries')
      .insert({
        webhook_id: webhookId,
        event_type: event,
        event_id: payload.id as string,
        payload,
        max_attempts: job.opts.attempts || 5,
        status: 'pending',
      })
      .returning('*');
  }

  try {
    const response = await axios.post(url, body, {
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Event': event,
        'X-Webhook-ID': webhookId,
        'X-Webhook-Timestamp': timestamp.toString(),
        'X-Webhook-Signature': `v1=${signature}`,
        'User-Agent': 'MobileBackend-Webhooks/1.0',
        ...headers,
      },
      timeout: 30000, // 30 second timeout
      validateStatus: (status) => status < 500, // Don't retry on 4xx
    });

    const responseTime = Date.now() - startTime;

    // Update delivery record
    await db('webhook_deliveries')
      .where('id', delivery.id)
      .update({
        status: response.status < 400 ? 'success' : 'failed',
        response_status: response.status,
        response_body: JSON.stringify(response.data).substring(0, 5000),
        response_time_ms: responseTime,
        delivered_at: new Date(),
      });

    // Update webhook stats
    await db('webhooks')
      .where('id', webhookId)
      .update({
        last_triggered_at: new Date(),
        last_success_at: response.status < 400 ? new Date() : undefined,
        success_count: db.raw('success_count + 1'),
        // Reset failure count on success
        failure_count: response.status < 400 ? 0 : db.raw('failure_count'),
      });

    // If 4xx error, don't retry
    if (response.status >= 400) {
      throw new Error(`Webhook returned ${response.status}: ${JSON.stringify(response.data)}`);
    }

    logger.info('Webhook delivered successfully', {
      webhookId,
      event,
      url,
      responseTime,
      status: response.status,
    });
  } catch (error) {
    const responseTime = Date.now() - startTime;
    const axiosError = error as AxiosError;

    const errorInfo = {
      message: error.message,
      code: axiosError.code,
      status: axiosError.response?.status,
    };

    // Update delivery record
    await db('webhook_deliveries')
      .where('id', delivery.id)
      .update({
        status: job.attemptsMade + 1 >= (job.opts.attempts || 5) ? 'failed' : 'retrying',
        response_status: axiosError.response?.status,
        response_body: axiosError.response
          ? JSON.stringify(axiosError.response.data).substring(0, 5000)
          : null,
        response_time_ms: responseTime,
        error_message: errorInfo.message,
        error_code: errorInfo.code,
      });

    // Update webhook stats
    await db('webhooks')
      .where('id', webhookId)
      .update({
        last_triggered_at: new Date(),
        last_failure_at: new Date(),
        failure_count: db.raw('failure_count + 1'),
      });

    // Disable webhook if too many failures
    const webhook = await db('webhooks').where('id', webhookId).first();
    if (webhook.failure_count >= 10) {
      await db('webhooks')
        .where('id', webhookId)
        .update({ enabled: false });

      // Notify user
      await notifyWebhookDisabled(webhook);
    }

    logger.error('Webhook delivery failed', {
      webhookId,
      event,
      url,
      error: errorInfo,
      attempt: job.attemptsMade + 1,
    });

    throw error; // Let BullMQ handle retry
  }
}

async function notifyWebhookDisabled(webhook: any): Promise<void> {
  // Send notification to user
  await db('notifications').insert({
    user_id: webhook.user_id,
    type: 'webhook_disabled',
    title: 'Webhook Disabled',
    body: `Your webhook "${webhook.name}" has been disabled due to too many failures.`,
    data: { webhookId: webhook.id },
  });
}
```

### Inbound Webhook Processing

```typescript
// src/routes/webhooks/inbound.ts
import { Router } from 'express';
import { z } from 'zod';
import crypto from 'crypto';
import { webhookService } from '../../services/webhookService';
import { queueService, QUEUES } from '../../queue';
import { ApiResponseBuilder } from '../../utils/response';
import { AppError, ErrorCodes } from '../../errors/AppError';
import { logger } from '../../utils/logger';

const router = Router();

// Stripe webhooks
router.post('/stripe',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const sig = req.headers['stripe-signature'] as string;
    const endpointSecret = config.STRIPE_WEBHOOK_SECRET;

    let event;

    try {
      event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
    } catch (err) {
      logger.error('Stripe webhook signature verification failed', { error: err.message });
      throw new AppError(ErrorCodes.AUTH_TOKEN_INVALID, 'Invalid signature', 400);
    }

    // Process event
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
        await queueService.addJob(QUEUES.DATA_SYNC, {
          type: 'sync_subscription',
          stripeEvent: event,
        });
        break;

      case 'invoice.payment_succeeded':
        await queueService.addJob(QUEUES.DATA_SYNC, {
          type: 'payment_succeeded',
          stripeEvent: event,
        });
        // Also publish to our webhooks
        await webhookService.publishEvent('payment.succeeded', {
          customerId: event.data.object.customer,
          amount: event.data.object.amount_paid,
          currency: event.data.object.currency,
        });
        break;

      case 'invoice.payment_failed':
        await queueService.addJob(QUEUES.DATA_SYNC, {
          type: 'payment_failed',
          stripeEvent: event,
        });
        await webhookService.publishEvent('payment.failed', {
          customerId: event.data.object.customer,
          amount: event.data.object.amount_due,
        });
        break;
    }

    ApiResponseBuilder.success({ received: true }).send(res);
  }
);

// Apple App Store webhooks (Server Notifications V2)
router.post('/apple-app-store', async (req, res) => {
  const { signedPayload } = req.body;

  try {
    // Verify and decode the JWS
    const decoded = await verifyAppleNotification(signedPayload);

    switch (decoded.notificationType) {
      case 'SUBSCRIBED':
      case 'DID_RENEW':
        await queueService.addJob(QUEUES.DATA_SYNC, {
          type: 'apple_subscription_update',
          notification: decoded,
        });
        await webhookService.publishEvent('subscription.renewed', {
          originalTransactionId: decoded.data.transactionInfo.originalTransactionId,
          productId: decoded.data.transactionInfo.productId,
        });
        break;

      case 'EXPIRED':
      case 'DID_FAIL_TO_RENEW':
        await queueService.addJob(QUEUES.DATA_SYNC, {
          type: 'apple_subscription_expired',
          notification: decoded,
        });
        await webhookService.publishEvent('subscription.canceled', {
          originalTransactionId: decoded.data.transactionInfo.originalTransactionId,
        });
        break;

      case 'REFUND':
        await queueService.addJob(QUEUES.DATA_SYNC, {
          type: 'apple_refund',
          notification: decoded,
        });
        await webhookService.publishEvent('payment.refunded', {
          originalTransactionId: decoded.data.transactionInfo.originalTransactionId,
        });
        break;
    }

    ApiResponseBuilder.success({ received: true }).send(res);
  } catch (error) {
    logger.error('Apple webhook processing failed', { error: error.message });
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Invalid notification', 400);
  }
});

// Google Play webhooks (Real-time Developer Notifications)
router.post('/google-play', async (req, res) => {
  // Verify the message is from Google
  const message = req.body.message;

  if (!message) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Invalid notification', 400);
  }

  try {
    const data = JSON.parse(
      Buffer.from(message.data, 'base64').toString()
    );

    if (data.subscriptionNotification) {
      const notification = data.subscriptionNotification;

      switch (notification.notificationType) {
        case 1: // SUBSCRIPTION_RECOVERED
        case 2: // SUBSCRIPTION_RENEWED
        case 4: // SUBSCRIPTION_PURCHASED
          await queueService.addJob(QUEUES.DATA_SYNC, {
            type: 'google_subscription_update',
            notification: data,
          });
          await webhookService.publishEvent('subscription.renewed', {
            purchaseToken: notification.purchaseToken,
            subscriptionId: notification.subscriptionId,
          });
          break;

        case 3: // SUBSCRIPTION_CANCELED
        case 10: // SUBSCRIPTION_PAUSED
        case 13: // SUBSCRIPTION_EXPIRED
          await queueService.addJob(QUEUES.DATA_SYNC, {
            type: 'google_subscription_canceled',
            notification: data,
          });
          await webhookService.publishEvent('subscription.canceled', {
            purchaseToken: notification.purchaseToken,
          });
          break;
      }
    }

    ApiResponseBuilder.success({ received: true }).send(res);
  } catch (error) {
    logger.error('Google Play webhook processing failed', { error: error.message });
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Invalid notification', 400);
  }
});

// Generic webhook verification endpoint
router.post('/verify/:webhookId', async (req, res) => {
  const { webhookId } = req.params;
  const { verificationToken } = req.body;

  const verified = await webhookService.verifyWebhook(webhookId, verificationToken);

  if (!verified) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Invalid verification token', 400);
  }

  ApiResponseBuilder.success({ verified: true }).send(res);
});

export { router as inboundWebhooksRouter };
```

### Webhook API Routes

```typescript
// src/routes/webhooks/index.ts
import { Router } from 'express';
import { z } from 'zod';
import { authenticate } from '../../middleware/authenticate';
import { webhookService, WEBHOOK_EVENTS } from '../../services/webhookService';
import { validateRequest } from '../../middleware/validateRequest';
import { ApiResponseBuilder } from '../../utils/response';

const router = Router();

const CreateWebhookSchema = z.object({
  name: z.string().min(1).max(255),
  url: z.string().url(),
  events: z.array(z.enum(Object.keys(WEBHOOK_EVENTS) as [string, ...string[]])).min(1),
  headers: z.record(z.string()).optional(),
});

const UpdateWebhookSchema = z.object({
  name: z.string().min(1).max(255).optional(),
  url: z.string().url().optional(),
  events: z.array(z.enum(Object.keys(WEBHOOK_EVENTS) as [string, ...string[]])).min(1).optional(),
  enabled: z.boolean().optional(),
  headers: z.record(z.string()).optional(),
});

// List available event types
router.get('/events', (req, res) => {
  ApiResponseBuilder.success({
    events: Object.entries(WEBHOOK_EVENTS).map(([type, description]) => ({
      type,
      description,
    })),
  }).send(res);
});

// List user's webhooks
router.get('/', authenticate, async (req, res) => {
  const webhooks = await webhookService.getUserWebhooks(req.user.id);

  // Hide secrets
  const sanitized = webhooks.map(w => ({
    ...w,
    secret: w.secret.substring(0, 12) + '...',
  }));

  ApiResponseBuilder.success({ webhooks: sanitized }).send(res);
});

// Create webhook
router.post('/',
  authenticate,
  validateRequest(CreateWebhookSchema),
  async (req, res) => {
    const webhook = await webhookService.createWebhook(req.user.id, req.body);

    ApiResponseBuilder.success({
      webhook: {
        ...webhook,
        // Show full secret only on creation
        secret: webhook.secret,
      },
    }).send(res, 201);
  }
);

// Get webhook details
router.get('/:webhookId', authenticate, async (req, res) => {
  const webhooks = await webhookService.getUserWebhooks(req.user.id);
  const webhook = webhooks.find(w => w.id === req.params.webhookId);

  if (!webhook) {
    throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Webhook not found', 404);
  }

  ApiResponseBuilder.success({
    webhook: {
      ...webhook,
      secret: webhook.secret.substring(0, 12) + '...',
    },
  }).send(res);
});

// Update webhook
router.patch('/:webhookId',
  authenticate,
  validateRequest(UpdateWebhookSchema),
  async (req, res) => {
    const webhook = await webhookService.updateWebhook(
      req.user.id,
      req.params.webhookId,
      req.body
    );

    ApiResponseBuilder.success({
      webhook: {
        ...webhook,
        secret: webhook.secret.substring(0, 12) + '...',
      },
    }).send(res);
  }
);

// Delete webhook
router.delete('/:webhookId', authenticate, async (req, res) => {
  await webhookService.deleteWebhook(req.user.id, req.params.webhookId);
  ApiResponseBuilder.success({ deleted: true }).send(res);
});

// Regenerate secret
router.post('/:webhookId/regenerate-secret', authenticate, async (req, res) => {
  const newSecret = await webhookService.regenerateSecret(
    req.user.id,
    req.params.webhookId
  );

  ApiResponseBuilder.success({ secret: newSecret }).send(res);
});

// Get delivery history
router.get('/:webhookId/deliveries', authenticate, async (req, res) => {
  const { limit = 50, offset = 0 } = req.query;

  const deliveries = await webhookService.getDeliveryHistory(
    req.user.id,
    req.params.webhookId,
    { limit: Number(limit), offset: Number(offset) }
  );

  ApiResponseBuilder.success({ deliveries }).send(res);
});

// Retry failed delivery
router.post('/deliveries/:deliveryId/retry', authenticate, async (req, res) => {
  await webhookService.retryDelivery(req.user.id, req.params.deliveryId);
  ApiResponseBuilder.success({ retried: true }).send(res);
});

// Test webhook
router.post('/:webhookId/test', authenticate, async (req, res) => {
  const webhooks = await webhookService.getUserWebhooks(req.user.id);
  const webhook = webhooks.find(w => w.id === req.params.webhookId);

  if (!webhook) {
    throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Webhook not found', 404);
  }

  // Send test event
  await webhookService.publishEvent(
    'test.event' as any,
    {
      message: 'This is a test webhook',
      timestamp: new Date().toISOString(),
    },
    { userId: req.user.id }
  );

  ApiResponseBuilder.success({ sent: true }).send(res);
});

export { router as webhooksRouter };
```

## Gate Criteria

Before marking webhooks complete, verify:

### Webhook Management Gates
- [ ] Webhook registration working
- [ ] Webhook update working
- [ ] Webhook deletion working
- [ ] Secret generation and regeneration working
- [ ] Event subscription filtering working

### Delivery Gates
- [ ] Webhook delivery working reliably
- [ ] Signature generation correct
- [ ] Retry mechanism with exponential backoff
- [ ] Dead webhook detection and disabling
- [ ] Delivery logging complete

### Security Gates
- [ ] Webhook signatures verified
- [ ] Secrets stored securely
- [ ] URL validation implemented
- [ ] Timeout protection in place
- [ ] No SSRF vulnerabilities

### Inbound Webhook Gates
- [ ] Stripe webhooks processed correctly
- [ ] Apple App Store webhooks handled
- [ ] Google Play webhooks handled
- [ ] Signature verification working
- [ ] Idempotency handled

### Monitoring Gates
- [ ] Delivery success/failure tracked
- [ ] Webhook health visible to users
- [ ] Failed deliveries alertable
- [ ] Delivery latency tracked
- [ ] Event replay capability

### Mobile Integration Gates
- [ ] Events published for mobile-relevant actions
- [ ] Real-time sync events available
- [ ] Push notification triggers working
- [ ] Subscription events published
- [ ] User-specific event filtering
