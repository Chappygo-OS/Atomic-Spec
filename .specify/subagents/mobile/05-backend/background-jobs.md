---
name: Mobile Backend Background Jobs
platform: mobile
description: Background jobs and task queue implementation for mobile backends including job scheduling, queue management, worker processes, retry strategies, and job monitoring
model: opus
category: mobile/backend
---

# Mobile Backend Background Jobs Subagent

## Purpose

This subagent handles all aspects of background job processing for mobile backends. Mobile applications require robust background processing for tasks like push notification delivery, email sending, image/video processing, data synchronization, and scheduled tasks that should not block API responses.

## Core Responsibilities

1. Job queue infrastructure setup
2. Worker process management
3. Job scheduling and delayed execution
4. Retry strategies and dead letter queues
5. Job prioritization
6. Monitoring and alerting
7. Rate limiting for external services
8. Idempotency handling

## Queue Infrastructure

### BullMQ Setup (Redis-based)

```typescript
// src/queue/index.ts
import { Queue, Worker, QueueScheduler, QueueEvents, Job } from 'bullmq';
import { config } from '../config';
import { logger } from '../utils/logger';

// Redis connection configuration
const redisConnection = {
  host: new URL(config.REDIS_URL).hostname,
  port: parseInt(new URL(config.REDIS_URL).port || '6379'),
  password: new URL(config.REDIS_URL).password || undefined,
  maxRetriesPerRequest: null,
};

// Queue definitions
export const QUEUES = {
  EMAIL: 'email',
  PUSH_NOTIFICATION: 'push-notification',
  SMS: 'sms',
  IMAGE_PROCESSING: 'image-processing',
  VIDEO_PROCESSING: 'video-processing',
  DATA_SYNC: 'data-sync',
  ANALYTICS: 'analytics',
  SCHEDULED: 'scheduled',
  WEBHOOKS: 'webhooks',
} as const;

type QueueName = typeof QUEUES[keyof typeof QUEUES];

// Queue instances cache
const queues = new Map<QueueName, Queue>();
const schedulers = new Map<QueueName, QueueScheduler>();
const events = new Map<QueueName, QueueEvents>();

// Default job options per queue
const DEFAULT_JOB_OPTIONS: Record<QueueName, Partial<JobsOptions>> = {
  [QUEUES.EMAIL]: {
    attempts: 5,
    backoff: { type: 'exponential', delay: 60000 },
    removeOnComplete: { count: 1000 },
    removeOnFail: { count: 5000 },
  },
  [QUEUES.PUSH_NOTIFICATION]: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 5000 },
    removeOnComplete: { count: 10000 },
    removeOnFail: { count: 5000 },
    priority: 1, // High priority
  },
  [QUEUES.SMS]: {
    attempts: 3,
    backoff: { type: 'fixed', delay: 30000 },
    removeOnComplete: { count: 1000 },
    removeOnFail: { count: 5000 },
  },
  [QUEUES.IMAGE_PROCESSING]: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 10000 },
    removeOnComplete: { count: 500 },
    removeOnFail: { count: 1000 },
  },
  [QUEUES.VIDEO_PROCESSING]: {
    attempts: 2,
    backoff: { type: 'exponential', delay: 60000 },
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 500 },
    timeout: 3600000, // 1 hour timeout
  },
  [QUEUES.DATA_SYNC]: {
    attempts: 5,
    backoff: { type: 'exponential', delay: 30000 },
    removeOnComplete: { count: 1000 },
    removeOnFail: { count: 2000 },
  },
  [QUEUES.ANALYTICS]: {
    attempts: 3,
    backoff: { type: 'fixed', delay: 60000 },
    removeOnComplete: { count: 5000 },
    removeOnFail: { count: 1000 },
    priority: 10, // Low priority
  },
  [QUEUES.SCHEDULED]: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 60000 },
    removeOnComplete: { count: 1000 },
    removeOnFail: { count: 1000 },
  },
  [QUEUES.WEBHOOKS]: {
    attempts: 5,
    backoff: { type: 'exponential', delay: 10000 },
    removeOnComplete: { count: 1000 },
    removeOnFail: { count: 5000 },
  },
};

// Get or create a queue
export function getQueue(name: QueueName): Queue {
  if (!queues.has(name)) {
    const queue = new Queue(name, {
      connection: redisConnection,
      defaultJobOptions: DEFAULT_JOB_OPTIONS[name],
    });

    // Create scheduler for delayed jobs
    const scheduler = new QueueScheduler(name, {
      connection: redisConnection,
    });

    // Create events listener
    const queueEvents = new QueueEvents(name, {
      connection: redisConnection,
    });

    // Set up event listeners
    setupQueueEvents(name, queueEvents);

    queues.set(name, queue);
    schedulers.set(name, scheduler);
    events.set(name, queueEvents);
  }

  return queues.get(name)!;
}

function setupQueueEvents(name: QueueName, queueEvents: QueueEvents): void {
  queueEvents.on('completed', ({ jobId }) => {
    logger.debug(`Job ${jobId} in queue ${name} completed`);
  });

  queueEvents.on('failed', ({ jobId, failedReason }) => {
    logger.error(`Job ${jobId} in queue ${name} failed: ${failedReason}`);
  });

  queueEvents.on('stalled', ({ jobId }) => {
    logger.warn(`Job ${jobId} in queue ${name} stalled`);
  });
}

// Graceful shutdown
export async function closeQueues(): Promise<void> {
  const closePromises: Promise<void>[] = [];

  for (const queue of queues.values()) {
    closePromises.push(queue.close());
  }
  for (const scheduler of schedulers.values()) {
    closePromises.push(scheduler.close());
  }
  for (const event of events.values()) {
    closePromises.push(event.close());
  }

  await Promise.all(closePromises);
}
```

### Queue Service

```typescript
// src/services/queueService.ts
import { Job, JobsOptions } from 'bullmq';
import { getQueue, QUEUES } from '../queue';
import { logger } from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

type QueueName = typeof QUEUES[keyof typeof QUEUES];

interface JobData {
  [key: string]: unknown;
}

export class QueueService {
  // Add a job to a queue
  async addJob<T extends JobData>(
    queueName: QueueName,
    data: T,
    options?: Partial<JobsOptions>
  ): Promise<Job<T>> {
    const queue = getQueue(queueName);

    const job = await queue.add(
      data.type as string || 'default',
      data,
      {
        ...options,
        jobId: options?.jobId || uuidv4(),
      }
    );

    logger.debug(`Added job ${job.id} to queue ${queueName}`, {
      jobId: job.id,
      queue: queueName,
      type: data.type,
    });

    return job as Job<T>;
  }

  // Add a delayed job
  async addDelayedJob<T extends JobData>(
    queueName: QueueName,
    data: T,
    delayMs: number,
    options?: Partial<JobsOptions>
  ): Promise<Job<T>> {
    return this.addJob(queueName, data, {
      ...options,
      delay: delayMs,
    });
  }

  // Add a scheduled job (run at specific time)
  async addScheduledJob<T extends JobData>(
    queueName: QueueName,
    data: T,
    runAt: Date,
    options?: Partial<JobsOptions>
  ): Promise<Job<T>> {
    const delay = Math.max(0, runAt.getTime() - Date.now());
    return this.addDelayedJob(queueName, data, delay, options);
  }

  // Add a repeating job
  async addRepeatingJob<T extends JobData>(
    queueName: QueueName,
    jobName: string,
    data: T,
    pattern: string, // Cron pattern
    options?: Partial<JobsOptions>
  ): Promise<Job<T>> {
    const queue = getQueue(queueName);

    const job = await queue.add(jobName, data, {
      ...options,
      repeat: {
        pattern,
        tz: 'UTC',
      },
    });

    return job as Job<T>;
  }

  // Add bulk jobs
  async addBulkJobs<T extends JobData>(
    queueName: QueueName,
    jobs: Array<{ data: T; options?: Partial<JobsOptions> }>
  ): Promise<Job<T>[]> {
    const queue = getQueue(queueName);

    const bulkJobs = jobs.map(({ data, options }) => ({
      name: data.type as string || 'default',
      data,
      opts: {
        ...options,
        jobId: options?.jobId || uuidv4(),
      },
    }));

    const addedJobs = await queue.addBulk(bulkJobs);

    logger.debug(`Added ${addedJobs.length} jobs to queue ${queueName}`);

    return addedJobs as Job<T>[];
  }

  // Get job status
  async getJobStatus(queueName: QueueName, jobId: string): Promise<{
    status: string;
    progress: number;
    data: unknown;
    result: unknown;
    failedReason?: string;
  } | null> {
    const queue = getQueue(queueName);
    const job = await queue.getJob(jobId);

    if (!job) {
      return null;
    }

    const state = await job.getState();

    return {
      status: state,
      progress: job.progress as number,
      data: job.data,
      result: job.returnvalue,
      failedReason: job.failedReason,
    };
  }

  // Cancel a job
  async cancelJob(queueName: QueueName, jobId: string): Promise<boolean> {
    const queue = getQueue(queueName);
    const job = await queue.getJob(jobId);

    if (!job) {
      return false;
    }

    const state = await job.getState();

    if (state === 'waiting' || state === 'delayed') {
      await job.remove();
      return true;
    }

    return false;
  }

  // Get queue metrics
  async getQueueMetrics(queueName: QueueName): Promise<{
    waiting: number;
    active: number;
    completed: number;
    failed: number;
    delayed: number;
  }> {
    const queue = getQueue(queueName);

    const [waiting, active, completed, failed, delayed] = await Promise.all([
      queue.getWaitingCount(),
      queue.getActiveCount(),
      queue.getCompletedCount(),
      queue.getFailedCount(),
      queue.getDelayedCount(),
    ]);

    return { waiting, active, completed, failed, delayed };
  }

  // Drain a queue (remove all jobs)
  async drainQueue(queueName: QueueName): Promise<void> {
    const queue = getQueue(queueName);
    await queue.drain();
  }

  // Pause a queue
  async pauseQueue(queueName: QueueName): Promise<void> {
    const queue = getQueue(queueName);
    await queue.pause();
  }

  // Resume a queue
  async resumeQueue(queueName: QueueName): Promise<void> {
    const queue = getQueue(queueName);
    await queue.resume();
  }
}

export const queueService = new QueueService();
```

## Worker Implementation

### Worker Manager

```typescript
// src/workers/index.ts
import { Worker, Job } from 'bullmq';
import { QUEUES } from '../queue';
import { config } from '../config';
import { logger } from '../utils/logger';

// Import job handlers
import { emailHandler } from './handlers/emailHandler';
import { pushNotificationHandler } from './handlers/pushNotificationHandler';
import { smsHandler } from './handlers/smsHandler';
import { imageProcessingHandler } from './handlers/imageProcessingHandler';
import { videoProcessingHandler } from './handlers/videoProcessingHandler';
import { dataSyncHandler } from './handlers/dataSyncHandler';
import { analyticsHandler } from './handlers/analyticsHandler';
import { scheduledHandler } from './handlers/scheduledHandler';
import { webhookHandler } from './handlers/webhookHandler';

const redisConnection = {
  host: new URL(config.REDIS_URL).hostname,
  port: parseInt(new URL(config.REDIS_URL).port || '6379'),
  password: new URL(config.REDIS_URL).password || undefined,
  maxRetriesPerRequest: null,
};

// Worker configurations
const WORKER_CONFIGS: Record<string, {
  handler: (job: Job) => Promise<unknown>;
  concurrency: number;
  limiter?: { max: number; duration: number };
}> = {
  [QUEUES.EMAIL]: {
    handler: emailHandler,
    concurrency: 10,
    limiter: { max: 50, duration: 1000 }, // 50 emails per second
  },
  [QUEUES.PUSH_NOTIFICATION]: {
    handler: pushNotificationHandler,
    concurrency: 50,
    limiter: { max: 500, duration: 1000 }, // 500 per second
  },
  [QUEUES.SMS]: {
    handler: smsHandler,
    concurrency: 5,
    limiter: { max: 10, duration: 1000 }, // 10 SMS per second
  },
  [QUEUES.IMAGE_PROCESSING]: {
    handler: imageProcessingHandler,
    concurrency: 5,
  },
  [QUEUES.VIDEO_PROCESSING]: {
    handler: videoProcessingHandler,
    concurrency: 2, // Resource intensive
  },
  [QUEUES.DATA_SYNC]: {
    handler: dataSyncHandler,
    concurrency: 10,
  },
  [QUEUES.ANALYTICS]: {
    handler: analyticsHandler,
    concurrency: 20,
  },
  [QUEUES.SCHEDULED]: {
    handler: scheduledHandler,
    concurrency: 5,
  },
  [QUEUES.WEBHOOKS]: {
    handler: webhookHandler,
    concurrency: 10,
    limiter: { max: 100, duration: 1000 },
  },
};

const workers: Worker[] = [];

export function startWorkers(): void {
  for (const [queueName, workerConfig] of Object.entries(WORKER_CONFIGS)) {
    const worker = new Worker(
      queueName,
      async (job: Job) => {
        const startTime = Date.now();

        try {
          logger.info(`Processing job ${job.id} in queue ${queueName}`, {
            jobId: job.id,
            queue: queueName,
            type: job.name,
            attempt: job.attemptsMade + 1,
          });

          const result = await workerConfig.handler(job);

          logger.info(`Job ${job.id} completed`, {
            jobId: job.id,
            queue: queueName,
            duration: Date.now() - startTime,
          });

          return result;
        } catch (error) {
          logger.error(`Job ${job.id} failed`, {
            jobId: job.id,
            queue: queueName,
            error: error.message,
            attempt: job.attemptsMade + 1,
            maxAttempts: job.opts.attempts,
          });

          throw error;
        }
      },
      {
        connection: redisConnection,
        concurrency: workerConfig.concurrency,
        limiter: workerConfig.limiter,
      }
    );

    // Worker event handlers
    worker.on('completed', (job: Job) => {
      // Metrics tracking
    });

    worker.on('failed', (job: Job | undefined, error: Error) => {
      if (job && job.attemptsMade >= (job.opts.attempts || 1)) {
        // Job exhausted all retries - send to dead letter queue or alert
        handleFailedJob(job, error);
      }
    });

    worker.on('error', (error: Error) => {
      logger.error(`Worker error in queue ${queueName}`, { error: error.message });
    });

    workers.push(worker);
    logger.info(`Started worker for queue: ${queueName}`);
  }
}

export async function stopWorkers(): Promise<void> {
  await Promise.all(workers.map(worker => worker.close()));
  logger.info('All workers stopped');
}

async function handleFailedJob(job: Job, error: Error): Promise<void> {
  // Log to dead letter queue or database
  await db('failed_jobs').insert({
    queue: job.queueName,
    job_id: job.id,
    job_name: job.name,
    job_data: JSON.stringify(job.data),
    error_message: error.message,
    error_stack: error.stack,
    attempts: job.attemptsMade,
    failed_at: new Date(),
  });

  // Send alert for critical jobs
  if (['push-notification', 'email'].includes(job.queueName)) {
    await alertService.sendAlert({
      type: 'job_failed',
      severity: 'warning',
      message: `Job ${job.id} in ${job.queueName} failed after ${job.attemptsMade} attempts`,
      metadata: {
        jobId: job.id,
        queue: job.queueName,
        error: error.message,
      },
    });
  }
}
```

### Job Handlers

```typescript
// src/workers/handlers/pushNotificationHandler.ts
import { Job } from 'bullmq';
import { pushNotificationService } from '../../services/pushNotificationService';
import { db } from '../../database';

interface PushNotificationJobData {
  type: 'push_notification';
  userId: string;
  notification: {
    title: string;
    body: string;
    data?: Record<string, string>;
    imageUrl?: string;
    badge?: number;
    sound?: string;
  };
  options?: {
    priority?: 'high' | 'normal';
    ttl?: number;
    collapseKey?: string;
  };
}

export async function pushNotificationHandler(job: Job<PushNotificationJobData>): Promise<void> {
  const { userId, notification, options } = job.data;

  // Get user devices
  const devices = await db('user_devices')
    .where('user_id', userId)
    .where('push_enabled', true)
    .whereNotNull('push_token');

  if (devices.length === 0) {
    return; // No devices to notify
  }

  // Update progress
  await job.updateProgress(10);

  // Send to each device
  const results = await Promise.allSettled(
    devices.map(async (device, index) => {
      const result = await pushNotificationService.sendToDevice(
        device.push_token,
        device.push_token_type,
        notification,
        options
      );

      // Update progress
      await job.updateProgress(10 + ((index + 1) / devices.length) * 90);

      // Handle invalid tokens
      if (result.error === 'InvalidToken') {
        await db('user_devices')
          .where('id', device.id)
          .update({ push_enabled: false });
      }

      return result;
    })
  );

  // Log results
  const successful = results.filter(r => r.status === 'fulfilled').length;
  const failed = results.filter(r => r.status === 'rejected').length;

  if (failed > 0 && successful === 0) {
    throw new Error(`Failed to send to all ${failed} devices`);
  }
}

// src/workers/handlers/emailHandler.ts
import { Job } from 'bullmq';
import { emailService } from '../../services/emailService';

interface EmailJobData {
  type: 'email';
  to: string | string[];
  subject: string;
  template: string;
  data: Record<string, unknown>;
  attachments?: Array<{
    filename: string;
    content: string;
    encoding: 'base64';
  }>;
  options?: {
    replyTo?: string;
    priority?: 'high' | 'normal' | 'low';
  };
}

export async function emailHandler(job: Job<EmailJobData>): Promise<void> {
  const { to, subject, template, data, attachments, options } = job.data;

  await emailService.sendTemplatedEmail({
    to: Array.isArray(to) ? to : [to],
    subject,
    template,
    data,
    attachments,
    ...options,
  });
}

// src/workers/handlers/imageProcessingHandler.ts
import { Job } from 'bullmq';
import { imageProcessingService } from '../../services/imageProcessingService';
import { storageService } from '../../services/storageService';
import { db } from '../../database';

interface ImageProcessingJobData {
  type: 'image_processing';
  fileId: string;
  userId: string;
  storageKey: string;
  operations: Array<{
    type: 'resize' | 'crop' | 'rotate' | 'filter';
    params: Record<string, unknown>;
  }>;
}

export async function imageProcessingHandler(job: Job<ImageProcessingJobData>): Promise<void> {
  const { fileId, userId, storageKey, operations } = job.data;

  await job.updateProgress(10);

  // Download image
  const buffer = await storageService.download(storageKey);
  await job.updateProgress(30);

  // Process image
  let processedBuffer = buffer;
  for (const operation of operations) {
    processedBuffer = await imageProcessingService.applyOperation(
      processedBuffer,
      operation
    );
  }
  await job.updateProgress(70);

  // Upload processed image
  const newKey = storageKey.replace(/(\.[^.]+)$/, '_processed$1');
  await storageService.upload({
    key: newKey,
    buffer: processedBuffer,
    contentType: 'image/jpeg',
  });
  await job.updateProgress(90);

  // Update database
  await db('files')
    .where('id', fileId)
    .update({
      processed_storage_key: newKey,
      metadata: db.raw("metadata || ?::jsonb", [
        JSON.stringify({ processed: true, processedAt: new Date() }),
      ]),
    });

  await job.updateProgress(100);
}

// src/workers/handlers/webhookHandler.ts
import { Job } from 'bullmq';
import axios from 'axios';
import crypto from 'crypto';
import { db } from '../../database';

interface WebhookJobData {
  type: 'webhook';
  webhookId: string;
  url: string;
  event: string;
  payload: Record<string, unknown>;
  secret?: string;
  headers?: Record<string, string>;
}

export async function webhookHandler(job: Job<WebhookJobData>): Promise<void> {
  const { webhookId, url, event, payload, secret, headers = {} } = job.data;

  // Generate signature
  const timestamp = Date.now();
  const body = JSON.stringify(payload);
  let signature: string | undefined;

  if (secret) {
    const signaturePayload = `${timestamp}.${body}`;
    signature = crypto
      .createHmac('sha256', secret)
      .update(signaturePayload)
      .digest('hex');
  }

  // Send webhook
  try {
    const response = await axios.post(url, payload, {
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Event': event,
        'X-Webhook-Timestamp': timestamp.toString(),
        ...(signature && { 'X-Webhook-Signature': `v1=${signature}` }),
        ...headers,
      },
      timeout: 30000, // 30 second timeout
      validateStatus: (status) => status < 500, // Don't retry 4xx errors
    });

    // Log delivery
    await db('webhook_deliveries').insert({
      webhook_id: webhookId,
      event,
      payload: body,
      response_status: response.status,
      response_body: JSON.stringify(response.data).substring(0, 1000),
      delivered_at: new Date(),
    });

    if (response.status >= 400) {
      throw new Error(`Webhook returned ${response.status}`);
    }
  } catch (error) {
    // Log failed delivery
    await db('webhook_deliveries').insert({
      webhook_id: webhookId,
      event,
      payload: body,
      error_message: error.message,
      failed_at: new Date(),
    });

    throw error;
  }
}
```

## Scheduled Jobs

```typescript
// src/workers/handlers/scheduledHandler.ts
import { Job } from 'bullmq';
import { queueService } from '../../services/queueService';
import { QUEUES } from '../../queue';

interface ScheduledJobData {
  type: 'scheduled';
  task: string;
  params?: Record<string, unknown>;
}

// Task registry
const SCHEDULED_TASKS: Record<string, (params?: Record<string, unknown>) => Promise<void>> = {
  'cleanup-expired-tokens': cleanupExpiredTokens,
  'cleanup-old-notifications': cleanupOldNotifications,
  'generate-daily-analytics': generateDailyAnalytics,
  'sync-subscription-status': syncSubscriptionStatus,
  'send-scheduled-notifications': sendScheduledNotifications,
  'cleanup-temp-files': cleanupTempFiles,
};

export async function scheduledHandler(job: Job<ScheduledJobData>): Promise<void> {
  const { task, params } = job.data;

  const taskFn = SCHEDULED_TASKS[task];

  if (!taskFn) {
    throw new Error(`Unknown scheduled task: ${task}`);
  }

  await taskFn(params);
}

// Initialize scheduled jobs
export async function initScheduledJobs(): Promise<void> {
  // Cleanup expired tokens every hour
  await queueService.addRepeatingJob(
    QUEUES.SCHEDULED,
    'cleanup-expired-tokens',
    { type: 'scheduled', task: 'cleanup-expired-tokens' },
    '0 * * * *' // Every hour
  );

  // Cleanup old notifications daily
  await queueService.addRepeatingJob(
    QUEUES.SCHEDULED,
    'cleanup-old-notifications',
    { type: 'scheduled', task: 'cleanup-old-notifications' },
    '0 3 * * *' // 3 AM daily
  );

  // Generate analytics daily
  await queueService.addRepeatingJob(
    QUEUES.SCHEDULED,
    'generate-daily-analytics',
    { type: 'scheduled', task: 'generate-daily-analytics' },
    '0 1 * * *' // 1 AM daily
  );

  // Sync subscription status every 6 hours
  await queueService.addRepeatingJob(
    QUEUES.SCHEDULED,
    'sync-subscription-status',
    { type: 'scheduled', task: 'sync-subscription-status' },
    '0 */6 * * *' // Every 6 hours
  );

  // Send scheduled notifications every minute
  await queueService.addRepeatingJob(
    QUEUES.SCHEDULED,
    'send-scheduled-notifications',
    { type: 'scheduled', task: 'send-scheduled-notifications' },
    '* * * * *' // Every minute
  );

  // Cleanup temp files every hour
  await queueService.addRepeatingJob(
    QUEUES.SCHEDULED,
    'cleanup-temp-files',
    { type: 'scheduled', task: 'cleanup-temp-files' },
    '30 * * * *' // Every hour at :30
  );
}

// Task implementations
async function cleanupExpiredTokens(): Promise<void> {
  await db('refresh_tokens')
    .where('expires_at', '<', new Date())
    .delete();
}

async function cleanupOldNotifications(): Promise<void> {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  await db('notifications')
    .where('created_at', '<', thirtyDaysAgo)
    .whereNotNull('read_at')
    .delete();
}

async function generateDailyAnalytics(): Promise<void> {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  yesterday.setHours(0, 0, 0, 0);

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Generate various analytics
  const [newUsers, activeUsers, posts, engagement] = await Promise.all([
    db('users')
      .whereBetween('created_at', [yesterday, today])
      .count('id as count'),
    db('users')
      .whereBetween('last_active_at', [yesterday, today])
      .count('id as count'),
    db('posts')
      .whereBetween('created_at', [yesterday, today])
      .count('id as count'),
    db.raw(`
      SELECT
        SUM(likes_count) as likes,
        SUM(comments_count) as comments,
        SUM(shares_count) as shares
      FROM posts
      WHERE created_at BETWEEN ? AND ?
    `, [yesterday, today]),
  ]);

  await db('daily_analytics').insert({
    date: yesterday,
    new_users: newUsers[0].count,
    active_users: activeUsers[0].count,
    posts_created: posts[0].count,
    total_likes: engagement[0]?.likes || 0,
    total_comments: engagement[0]?.comments || 0,
    total_shares: engagement[0]?.shares || 0,
  });
}

async function syncSubscriptionStatus(): Promise<void> {
  // Get subscriptions that might have changed
  const subscriptions = await db('user_subscriptions')
    .where('status', 'active')
    .whereNotNull('external_id');

  // Check with payment provider (e.g., Stripe)
  for (const sub of subscriptions) {
    try {
      // Implementation depends on payment provider
      await paymentService.syncSubscription(sub.external_id);
    } catch (error) {
      logger.error(`Failed to sync subscription ${sub.id}`, { error });
    }
  }
}

async function sendScheduledNotifications(): Promise<void> {
  const now = new Date();

  const scheduled = await db('scheduled_notifications')
    .where('scheduled_for', '<=', now)
    .where('sent_at', null)
    .limit(100);

  for (const notification of scheduled) {
    await queueService.addJob(QUEUES.PUSH_NOTIFICATION, {
      type: 'push_notification',
      userId: notification.user_id,
      notification: notification.content,
    });

    await db('scheduled_notifications')
      .where('id', notification.id)
      .update({ sent_at: now });
  }
}

async function cleanupTempFiles(): Promise<void> {
  const oneHourAgo = new Date();
  oneHourAgo.setHours(oneHourAgo.getHours() - 1);

  // Cleanup incomplete uploads
  const incompleteUploads = await redis.keys('upload:*');

  for (const key of incompleteUploads) {
    const data = await redis.hgetall(key);
    if (data.createdAt && parseInt(data.createdAt) < oneHourAgo.getTime()) {
      // Delete upload data and chunks
      const uploadId = key.split(':')[1];
      const chunkKeys = await redis.keys(`upload:${uploadId}:chunk:*`);
      await redis.del(key, ...chunkKeys);
    }
  }
}
```

## Job Monitoring Dashboard

```typescript
// src/routes/admin/jobs.ts
import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { requireRole } from '../../middleware/authorize';
import { queueService } from '../../services/queueService';
import { QUEUES } from '../../queue';
import { ApiResponseBuilder } from '../../utils/response';

const router = Router();

// Get all queue metrics
router.get('/queues',
  authenticate,
  requireRole('admin'),
  async (req, res) => {
    const metrics: Record<string, any> = {};

    for (const queueName of Object.values(QUEUES)) {
      metrics[queueName] = await queueService.getQueueMetrics(queueName);
    }

    ApiResponseBuilder.success({ metrics }).send(res);
  }
);

// Get specific queue jobs
router.get('/queues/:queueName/jobs',
  authenticate,
  requireRole('admin'),
  async (req, res) => {
    const { queueName } = req.params;
    const { status = 'waiting', page = 1, limit = 20 } = req.query;

    const queue = getQueue(queueName as any);

    let jobs;
    switch (status) {
      case 'waiting':
        jobs = await queue.getWaiting(
          (Number(page) - 1) * Number(limit),
          Number(limit)
        );
        break;
      case 'active':
        jobs = await queue.getActive(
          (Number(page) - 1) * Number(limit),
          Number(limit)
        );
        break;
      case 'completed':
        jobs = await queue.getCompleted(
          (Number(page) - 1) * Number(limit),
          Number(limit)
        );
        break;
      case 'failed':
        jobs = await queue.getFailed(
          (Number(page) - 1) * Number(limit),
          Number(limit)
        );
        break;
      case 'delayed':
        jobs = await queue.getDelayed(
          (Number(page) - 1) * Number(limit),
          Number(limit)
        );
        break;
      default:
        jobs = [];
    }

    ApiResponseBuilder.success({
      jobs: jobs.map(job => ({
        id: job.id,
        name: job.name,
        data: job.data,
        progress: job.progress,
        attemptsMade: job.attemptsMade,
        createdAt: job.timestamp,
        processedAt: job.processedOn,
        finishedAt: job.finishedOn,
        failedReason: job.failedReason,
      })),
    }).send(res);
  }
);

// Retry failed job
router.post('/queues/:queueName/jobs/:jobId/retry',
  authenticate,
  requireRole('admin'),
  async (req, res) => {
    const { queueName, jobId } = req.params;

    const queue = getQueue(queueName as any);
    const job = await queue.getJob(jobId);

    if (!job) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Job not found', 404);
    }

    await job.retry();

    ApiResponseBuilder.success({ message: 'Job retried' }).send(res);
  }
);

// Delete job
router.delete('/queues/:queueName/jobs/:jobId',
  authenticate,
  requireRole('admin'),
  async (req, res) => {
    const { queueName, jobId } = req.params;

    const queue = getQueue(queueName as any);
    const job = await queue.getJob(jobId);

    if (job) {
      await job.remove();
    }

    ApiResponseBuilder.success({ message: 'Job deleted' }).send(res);
  }
);

// Pause/resume queue
router.post('/queues/:queueName/pause',
  authenticate,
  requireRole('admin'),
  async (req, res) => {
    await queueService.pauseQueue(req.params.queueName as any);
    ApiResponseBuilder.success({ message: 'Queue paused' }).send(res);
  }
);

router.post('/queues/:queueName/resume',
  authenticate,
  requireRole('admin'),
  async (req, res) => {
    await queueService.resumeQueue(req.params.queueName as any);
    ApiResponseBuilder.success({ message: 'Queue resumed' }).send(res);
  }
);

// Drain queue
router.post('/queues/:queueName/drain',
  authenticate,
  requireRole('admin'),
  async (req, res) => {
    await queueService.drainQueue(req.params.queueName as any);
    ApiResponseBuilder.success({ message: 'Queue drained' }).send(res);
  }
);

export { router as jobsAdminRouter };
```

## Gate Criteria

Before marking background jobs complete, verify:

### Infrastructure Gates
- [ ] Redis configured for queue storage
- [ ] Worker processes can be scaled independently
- [ ] Queue scheduler running for delayed jobs
- [ ] Graceful shutdown implemented
- [ ] Queue health monitoring in place

### Job Processing Gates
- [ ] Jobs processed in FIFO order
- [ ] Concurrent job processing configured
- [ ] Job timeout handling implemented
- [ ] Progress tracking available
- [ ] Job results stored appropriately

### Retry Strategy Gates
- [ ] Exponential backoff configured
- [ ] Maximum retry attempts defined
- [ ] Dead letter queue for failed jobs
- [ ] Failed job alerting implemented
- [ ] Manual retry capability available

### Scheduled Jobs Gates
- [ ] Cron-based scheduling working
- [ ] Delayed job execution working
- [ ] Repeating jobs configured
- [ ] Timezone handling correct
- [ ] Duplicate job prevention

### Monitoring Gates
- [ ] Queue metrics exposed
- [ ] Job processing duration tracked
- [ ] Error rates monitored
- [ ] Queue depth alerting configured
- [ ] Admin dashboard available

### Mobile-Specific Gates
- [ ] Push notification jobs prioritized
- [ ] Rate limiting for external APIs
- [ ] Idempotency for critical jobs
- [ ] Job status queryable via API
- [ ] Webhook delivery tracking
