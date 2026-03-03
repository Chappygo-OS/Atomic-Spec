---
name: Mobile Backend Admin Panel
platform: mobile
description: Admin panel and dashboard development for mobile backends including user management, content moderation, analytics dashboards, system configuration, and operational tools
model: opus
category: mobile/backend
---

# Mobile Backend Admin Panel Subagent

## Purpose

This subagent handles all aspects of admin panel and dashboard development for mobile backends. Admin panels provide essential operational capabilities for managing users, moderating content, viewing analytics, configuring system settings, and troubleshooting issues specific to mobile applications.

## Core Responsibilities

1. Admin authentication and authorization
2. User management (view, edit, ban, delete)
3. Content moderation tools
4. Analytics and reporting dashboards
5. System configuration management
6. Push notification management
7. App version management
8. Audit logging and activity tracking

## Admin API Architecture

### Admin Routes Structure

```typescript
// src/routes/admin/index.ts
import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { requireRole, requirePermission } from '../../middleware/authorize';
import { usersAdminRouter } from './users';
import { contentAdminRouter } from './content';
import { analyticsAdminRouter } from './analytics';
import { settingsAdminRouter } from './settings';
import { notificationsAdminRouter } from './notifications';
import { appVersionsAdminRouter } from './appVersions';
import { auditLogRouter } from './auditLog';
import { jobsAdminRouter } from './jobs';
import { webhooksAdminRouter } from './webhooks';

const router = Router();

// All admin routes require authentication and admin role
router.use(authenticate);
router.use(requireRole('admin', 'moderator'));

// Admin sub-routes
router.use('/users', usersAdminRouter);
router.use('/content', contentAdminRouter);
router.use('/analytics', analyticsAdminRouter);
router.use('/settings', requireRole('admin'), settingsAdminRouter);
router.use('/notifications', notificationsAdminRouter);
router.use('/app-versions', requireRole('admin'), appVersionsAdminRouter);
router.use('/audit-log', requireRole('admin'), auditLogRouter);
router.use('/jobs', requireRole('admin'), jobsAdminRouter);
router.use('/webhooks', webhooksAdminRouter);

// Admin dashboard summary
router.get('/dashboard', async (req, res) => {
  const [
    userStats,
    contentStats,
    revenueStats,
    systemHealth,
  ] = await Promise.all([
    getUserStats(),
    getContentStats(),
    getRevenueStats(),
    getSystemHealth(),
  ]);

  ApiResponseBuilder.success({
    users: userStats,
    content: contentStats,
    revenue: revenueStats,
    system: systemHealth,
  }).send(res);
});

export { router as adminRouter };
```

### User Management

```typescript
// src/routes/admin/users.ts
import { Router } from 'express';
import { z } from 'zod';
import { db } from '../../database';
import { tokenService } from '../../services/tokenService';
import { auditService } from '../../services/auditService';
import { ApiResponseBuilder } from '../../utils/response';
import { requirePermission } from '../../middleware/authorize';
import { validateRequest } from '../../middleware/validateRequest';

const router = Router();

// List users with filtering and pagination
const ListUsersSchema = z.object({
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(100).default(20),
  search: z.string().optional(),
  status: z.enum(['all', 'active', 'suspended', 'pending', 'deleted']).default('all'),
  role: z.string().optional(),
  sortBy: z.enum(['created_at', 'last_active_at', 'email', 'display_name']).default('created_at'),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
  subscriptionTier: z.string().optional(),
  dateFrom: z.string().datetime().optional(),
  dateTo: z.string().datetime().optional(),
});

router.get('/',
  requirePermission('users.read'),
  validateRequest({ query: ListUsersSchema }),
  async (req, res) => {
    const {
      page, limit, search, status, role, sortBy, sortOrder,
      subscriptionTier, dateFrom, dateTo
    } = req.query as z.infer<typeof ListUsersSchema>;

    let query = db('users')
      .leftJoin('user_subscriptions', function() {
        this.on('users.id', 'user_subscriptions.user_id')
          .andOn('user_subscriptions.status', db.raw("'active'"));
      })
      .leftJoin('subscription_tiers', 'subscription_tiers.id', 'user_subscriptions.tier_id')
      .select(
        'users.*',
        'subscription_tiers.name as subscription_tier'
      );

    // Apply filters
    if (status !== 'all') {
      if (status === 'deleted') {
        query = query.whereNotNull('users.deleted_at');
      } else {
        query = query.where('users.status', status).whereNull('users.deleted_at');
      }
    } else {
      query = query.whereNull('users.deleted_at');
    }

    if (search) {
      query = query.where(function() {
        this.where('users.email', 'ilike', `%${search}%`)
          .orWhere('users.display_name', 'ilike', `%${search}%`)
          .orWhere('users.first_name', 'ilike', `%${search}%`)
          .orWhere('users.last_name', 'ilike', `%${search}%`);
      });
    }

    if (role) {
      query = query.whereExists(function() {
        this.select('*')
          .from('user_roles')
          .join('roles', 'roles.id', 'user_roles.role_id')
          .whereRaw('user_roles.user_id = users.id')
          .where('roles.name', role);
      });
    }

    if (subscriptionTier) {
      query = query.where('subscription_tiers.name', subscriptionTier);
    }

    if (dateFrom) {
      query = query.where('users.created_at', '>=', dateFrom);
    }

    if (dateTo) {
      query = query.where('users.created_at', '<=', dateTo);
    }

    // Get total count
    const countQuery = query.clone();
    const [{ count }] = await countQuery.count('users.id as count');

    // Apply pagination and sorting
    const users = await query
      .orderBy(`users.${sortBy}`, sortOrder)
      .limit(limit)
      .offset((page - 1) * limit);

    // Get roles for each user
    const userIds = users.map(u => u.id);
    const userRoles = await db('user_roles')
      .join('roles', 'roles.id', 'user_roles.role_id')
      .whereIn('user_roles.user_id', userIds)
      .select('user_roles.user_id', 'roles.name');

    const rolesByUser = userRoles.reduce((acc, ur) => {
      acc[ur.user_id] = acc[ur.user_id] || [];
      acc[ur.user_id].push(ur.name);
      return acc;
    }, {} as Record<string, string[]>);

    const usersWithRoles = users.map(user => ({
      ...user,
      roles: rolesByUser[user.id] || [],
      password_hash: undefined, // Never expose
    }));

    ApiResponseBuilder.success({ users: usersWithRoles })
      .withPagination({
        page,
        perPage: limit,
        total: Number(count),
        totalPages: Math.ceil(Number(count) / limit),
        hasMore: page * limit < Number(count),
      })
      .send(res);
  }
);

// Get user details
router.get('/:userId',
  requirePermission('users.read'),
  async (req, res) => {
    const { userId } = req.params;

    const user = await db('users')
      .where('id', userId)
      .first();

    if (!user) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'User not found', 404);
    }

    // Get additional details
    const [roles, devices, subscription, recentActivity] = await Promise.all([
      db('user_roles')
        .join('roles', 'roles.id', 'user_roles.role_id')
        .where('user_roles.user_id', userId)
        .select('roles.*'),
      db('user_devices')
        .where('user_id', userId)
        .orderBy('last_active_at', 'desc'),
      db('user_subscriptions')
        .join('subscription_tiers', 'subscription_tiers.id', 'user_subscriptions.tier_id')
        .where('user_subscriptions.user_id', userId)
        .where('user_subscriptions.status', 'active')
        .select('user_subscriptions.*', 'subscription_tiers.name as tier_name')
        .first(),
      db('audit_logs')
        .where('user_id', userId)
        .orderBy('created_at', 'desc')
        .limit(10),
    ]);

    ApiResponseBuilder.success({
      user: {
        ...user,
        password_hash: undefined,
        roles,
        devices,
        subscription,
        recentActivity,
      },
    }).send(res);
  }
);

// Update user
router.patch('/:userId',
  requirePermission('users.update'),
  async (req, res) => {
    const { userId } = req.params;
    const updates = req.body;

    // Prevent updating sensitive fields directly
    delete updates.password_hash;
    delete updates.id;

    const [user] = await db('users')
      .where('id', userId)
      .update({
        ...updates,
        updated_at: new Date(),
      })
      .returning('*');

    // Audit log
    await auditService.log({
      action: 'user.updated',
      userId: req.user.id,
      targetId: userId,
      targetType: 'user',
      changes: updates,
    });

    ApiResponseBuilder.success({
      user: { ...user, password_hash: undefined },
    }).send(res);
  }
);

// Suspend user
router.post('/:userId/suspend',
  requirePermission('users.suspend'),
  async (req, res) => {
    const { userId } = req.params;
    const { reason, duration } = req.body;

    await db('users')
      .where('id', userId)
      .update({
        status: 'suspended',
        suspended_at: new Date(),
        suspended_reason: reason,
        suspended_until: duration ? new Date(Date.now() + duration * 1000) : null,
      });

    // Revoke all sessions
    await tokenService.revokeAllUserSessions(userId);

    // Audit log
    await auditService.log({
      action: 'user.suspended',
      userId: req.user.id,
      targetId: userId,
      targetType: 'user',
      metadata: { reason, duration },
    });

    ApiResponseBuilder.success({ suspended: true }).send(res);
  }
);

// Unsuspend user
router.post('/:userId/unsuspend',
  requirePermission('users.suspend'),
  async (req, res) => {
    const { userId } = req.params;

    await db('users')
      .where('id', userId)
      .update({
        status: 'active',
        suspended_at: null,
        suspended_reason: null,
        suspended_until: null,
      });

    await auditService.log({
      action: 'user.unsuspended',
      userId: req.user.id,
      targetId: userId,
      targetType: 'user',
    });

    ApiResponseBuilder.success({ unsuspended: true }).send(res);
  }
);

// Delete user (soft delete)
router.delete('/:userId',
  requirePermission('users.delete'),
  async (req, res) => {
    const { userId } = req.params;

    await db('users')
      .where('id', userId)
      .update({
        deleted_at: new Date(),
        status: 'deleted',
        email: db.raw("email || '-deleted-' || id"),
      });

    // Revoke all sessions
    await tokenService.revokeAllUserSessions(userId);

    await auditService.log({
      action: 'user.deleted',
      userId: req.user.id,
      targetId: userId,
      targetType: 'user',
    });

    ApiResponseBuilder.success({ deleted: true }).send(res);
  }
);

// Assign role to user
router.post('/:userId/roles',
  requirePermission('users.manage_roles'),
  async (req, res) => {
    const { userId } = req.params;
    const { role } = req.body;

    await authorizationService.assignRole(userId, role, req.user.id);

    await auditService.log({
      action: 'user.role_assigned',
      userId: req.user.id,
      targetId: userId,
      targetType: 'user',
      metadata: { role },
    });

    ApiResponseBuilder.success({ assigned: true }).send(res);
  }
);

// Remove role from user
router.delete('/:userId/roles/:roleName',
  requirePermission('users.manage_roles'),
  async (req, res) => {
    const { userId, roleName } = req.params;

    await authorizationService.removeRole(userId, roleName);

    await auditService.log({
      action: 'user.role_removed',
      userId: req.user.id,
      targetId: userId,
      targetType: 'user',
      metadata: { role: roleName },
    });

    ApiResponseBuilder.success({ removed: true }).send(res);
  }
);

// Reset user password (sends reset email)
router.post('/:userId/reset-password',
  requirePermission('users.reset_password'),
  async (req, res) => {
    const { userId } = req.params;

    const user = await db('users').where('id', userId).first();

    if (!user) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'User not found', 404);
    }

    // Generate reset token and send email
    const resetToken = await tokenService.generatePasswordResetToken(userId);
    await emailService.sendPasswordResetEmail(user.email, resetToken);

    await auditService.log({
      action: 'user.password_reset_requested',
      userId: req.user.id,
      targetId: userId,
      targetType: 'user',
    });

    ApiResponseBuilder.success({ sent: true }).send(res);
  }
);

// Impersonate user (for debugging)
router.post('/:userId/impersonate',
  requireRole('admin'),
  async (req, res) => {
    const { userId } = req.params;

    const user = await db('users').where('id', userId).first();

    if (!user) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'User not found', 404);
    }

    // Generate impersonation token (short-lived)
    const tokens = await tokenService.generateTokenPair(userId, 'admin-impersonation');

    await auditService.log({
      action: 'user.impersonated',
      userId: req.user.id,
      targetId: userId,
      targetType: 'user',
    });

    ApiResponseBuilder.success({
      tokens,
      warning: 'This token is for debugging purposes only. All actions are logged.',
    }).send(res);
  }
);

export { router as usersAdminRouter };
```

### Content Moderation

```typescript
// src/routes/admin/content.ts
import { Router } from 'express';
import { db } from '../../database';
import { auditService } from '../../services/auditService';
import { queueService, QUEUES } from '../../queue';
import { ApiResponseBuilder } from '../../utils/response';
import { requirePermission } from '../../middleware/authorize';

const router = Router();

// Get reported content
router.get('/reports',
  requirePermission('content.moderate'),
  async (req, res) => {
    const { status = 'pending', page = 1, limit = 20 } = req.query;

    const reports = await db('content_reports')
      .leftJoin('posts', function() {
        this.on('content_reports.content_type', db.raw("'post'"))
          .andOn('content_reports.content_id', 'posts.id');
      })
      .leftJoin('comments', function() {
        this.on('content_reports.content_type', db.raw("'comment'"))
          .andOn('content_reports.content_id', 'comments.id');
      })
      .leftJoin('users as reporter', 'content_reports.reporter_id', 'reporter.id')
      .leftJoin('users as content_owner', function() {
        this.on(db.raw(`
          CASE content_reports.content_type
            WHEN 'post' THEN posts.user_id
            WHEN 'comment' THEN comments.user_id
          END = content_owner.id
        `));
      })
      .where('content_reports.status', status)
      .select(
        'content_reports.*',
        'reporter.email as reporter_email',
        'content_owner.email as owner_email',
        db.raw(`
          CASE content_reports.content_type
            WHEN 'post' THEN posts.body
            WHEN 'comment' THEN comments.body
          END as content_body
        `)
      )
      .orderBy('content_reports.created_at', 'desc')
      .limit(Number(limit))
      .offset((Number(page) - 1) * Number(limit));

    const [{ count }] = await db('content_reports')
      .where('status', status)
      .count('id as count');

    ApiResponseBuilder.success({ reports })
      .withPagination({
        page: Number(page),
        perPage: Number(limit),
        total: Number(count),
        totalPages: Math.ceil(Number(count) / Number(limit)),
        hasMore: Number(page) * Number(limit) < Number(count),
      })
      .send(res);
  }
);

// Review report
router.post('/reports/:reportId/review',
  requirePermission('content.moderate'),
  async (req, res) => {
    const { reportId } = req.params;
    const { action, reason } = req.body;

    const report = await db('content_reports').where('id', reportId).first();

    if (!report) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Report not found', 404);
    }

    // Handle different actions
    switch (action) {
      case 'remove':
        // Remove the content
        if (report.content_type === 'post') {
          await db('posts')
            .where('id', report.content_id)
            .update({ deleted_at: new Date() });
        } else if (report.content_type === 'comment') {
          await db('comments')
            .where('id', report.content_id)
            .update({ deleted_at: new Date() });
        }

        // Notify content owner
        await queueService.addJob(QUEUES.EMAIL, {
          type: 'email',
          to: report.owner_email,
          subject: 'Content Removed',
          template: 'content-removed',
          data: { reason },
        });
        break;

      case 'warn':
        // Warn the user
        await queueService.addJob(QUEUES.EMAIL, {
          type: 'email',
          to: report.owner_email,
          subject: 'Content Warning',
          template: 'content-warning',
          data: { reason },
        });
        break;

      case 'dismiss':
        // Just update the report status
        break;
    }

    // Update report
    await db('content_reports')
      .where('id', reportId)
      .update({
        status: 'reviewed',
        reviewed_by: req.user.id,
        reviewed_at: new Date(),
        action_taken: action,
        review_notes: reason,
      });

    await auditService.log({
      action: 'content.report_reviewed',
      userId: req.user.id,
      targetId: reportId,
      targetType: 'content_report',
      metadata: { action, reason },
    });

    ApiResponseBuilder.success({ reviewed: true }).send(res);
  }
);

// Bulk moderate content
router.post('/bulk-moderate',
  requirePermission('content.moderate'),
  async (req, res) => {
    const { contentIds, contentType, action, reason } = req.body;

    const tableName = contentType === 'post' ? 'posts' : 'comments';

    if (action === 'delete') {
      await db(tableName)
        .whereIn('id', contentIds)
        .update({ deleted_at: new Date() });
    } else if (action === 'hide') {
      await db(tableName)
        .whereIn('id', contentIds)
        .update({ visibility: 'hidden' });
    }

    await auditService.log({
      action: `content.bulk_${action}`,
      userId: req.user.id,
      metadata: { contentIds, contentType, reason },
    });

    ApiResponseBuilder.success({ moderated: contentIds.length }).send(res);
  }
);

// Search all content
router.get('/search',
  requirePermission('content.read'),
  async (req, res) => {
    const { q, type = 'all', page = 1, limit = 20 } = req.query;

    const results: any[] = [];

    if (type === 'all' || type === 'posts') {
      const posts = await db('posts')
        .join('users', 'posts.user_id', 'users.id')
        .where('posts.body', 'ilike', `%${q}%`)
        .select('posts.*', 'users.email', 'users.display_name')
        .limit(Number(limit));

      results.push(...posts.map(p => ({ ...p, type: 'post' })));
    }

    if (type === 'all' || type === 'comments') {
      const comments = await db('comments')
        .join('users', 'comments.user_id', 'users.id')
        .where('comments.body', 'ilike', `%${q}%`)
        .select('comments.*', 'users.email', 'users.display_name')
        .limit(Number(limit));

      results.push(...comments.map(c => ({ ...c, type: 'comment' })));
    }

    ApiResponseBuilder.success({ results }).send(res);
  }
);

export { router as contentAdminRouter };
```

### Analytics Dashboard

```typescript
// src/routes/admin/analytics.ts
import { Router } from 'express';
import { db } from '../../database';
import { redis } from '../../cache/redis';
import { ApiResponseBuilder } from '../../utils/response';
import { requirePermission } from '../../middleware/authorize';

const router = Router();

// Get overview analytics
router.get('/overview',
  requirePermission('analytics.read'),
  async (req, res) => {
    const { period = '7d' } = req.query;

    const periodDays = period === '30d' ? 30 : period === '90d' ? 90 : 7;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - periodDays);

    const [
      userMetrics,
      engagementMetrics,
      revenueMetrics,
      deviceMetrics,
    ] = await Promise.all([
      getUserMetrics(startDate),
      getEngagementMetrics(startDate),
      getRevenueMetrics(startDate),
      getDeviceMetrics(startDate),
    ]);

    ApiResponseBuilder.success({
      period,
      users: userMetrics,
      engagement: engagementMetrics,
      revenue: revenueMetrics,
      devices: deviceMetrics,
    }).send(res);
  }
);

// Get user growth over time
router.get('/users/growth',
  requirePermission('analytics.read'),
  async (req, res) => {
    const { period = '30d', granularity = 'day' } = req.query;

    const periodDays = period === '90d' ? 90 : period === '30d' ? 30 : 7;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - periodDays);

    let dateFormat;
    switch (granularity) {
      case 'hour':
        dateFormat = "YYYY-MM-DD HH24:00";
        break;
      case 'week':
        dateFormat = "IYYY-IW";
        break;
      default:
        dateFormat = "YYYY-MM-DD";
    }

    const growth = await db.raw(`
      SELECT
        to_char(created_at, '${dateFormat}') as period,
        COUNT(*) as new_users,
        COUNT(*) FILTER (WHERE status = 'active') as active_signups,
        SUM(COUNT(*)) OVER (ORDER BY to_char(created_at, '${dateFormat}')) as cumulative
      FROM users
      WHERE created_at >= ?
      AND deleted_at IS NULL
      GROUP BY to_char(created_at, '${dateFormat}')
      ORDER BY period
    `, [startDate]);

    ApiResponseBuilder.success({ growth: growth.rows }).send(res);
  }
);

// Get retention metrics
router.get('/users/retention',
  requirePermission('analytics.read'),
  async (req, res) => {
    const { cohortPeriod = 'week' } = req.query;

    const retention = await db.raw(`
      WITH cohorts AS (
        SELECT
          id as user_id,
          DATE_TRUNC('${cohortPeriod}', created_at) as cohort_date
        FROM users
        WHERE created_at >= NOW() - INTERVAL '12 weeks'
        AND deleted_at IS NULL
      ),
      activity AS (
        SELECT DISTINCT
          user_id,
          DATE_TRUNC('${cohortPeriod}', last_active_at) as active_period
        FROM users
        WHERE last_active_at IS NOT NULL
      )
      SELECT
        c.cohort_date,
        COUNT(DISTINCT c.user_id) as cohort_size,
        COUNT(DISTINCT CASE WHEN a.active_period = c.cohort_date THEN c.user_id END) as period_0,
        COUNT(DISTINCT CASE WHEN a.active_period = c.cohort_date + INTERVAL '1 ${cohortPeriod}' THEN c.user_id END) as period_1,
        COUNT(DISTINCT CASE WHEN a.active_period = c.cohort_date + INTERVAL '2 ${cohortPeriod}' THEN c.user_id END) as period_2,
        COUNT(DISTINCT CASE WHEN a.active_period = c.cohort_date + INTERVAL '3 ${cohortPeriod}' THEN c.user_id END) as period_3,
        COUNT(DISTINCT CASE WHEN a.active_period = c.cohort_date + INTERVAL '4 ${cohortPeriod}' THEN c.user_id END) as period_4
      FROM cohorts c
      LEFT JOIN activity a ON c.user_id = a.user_id
      GROUP BY c.cohort_date
      ORDER BY c.cohort_date
    `);

    ApiResponseBuilder.success({ retention: retention.rows }).send(res);
  }
);

// Get real-time active users
router.get('/realtime',
  requirePermission('analytics.read'),
  async (req, res) => {
    // Get users active in last 5 minutes
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);

    const activeUsers = await db('users')
      .where('last_active_at', '>=', fiveMinutesAgo)
      .count('id as count');

    // Get current requests per second from Redis
    const requestsPerSecond = await redis.get('metrics:requests_per_second') || '0';

    // Get current active sessions
    const activeSessions = await redis.scard('active_sessions');

    ApiResponseBuilder.success({
      activeUsers: Number(activeUsers[0].count),
      requestsPerSecond: Number(requestsPerSecond),
      activeSessions,
      timestamp: new Date().toISOString(),
    }).send(res);
  }
);

// Get subscription/revenue analytics
router.get('/revenue',
  requirePermission('analytics.read_financial'),
  async (req, res) => {
    const { period = '30d' } = req.query;

    const periodDays = period === '90d' ? 90 : period === '30d' ? 30 : 7;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - periodDays);

    const [
      mrr,
      subscriptionsByTier,
      churnRate,
      revenueByDay,
    ] = await Promise.all([
      calculateMRR(),
      getSubscriptionsByTier(),
      calculateChurnRate(startDate),
      getRevenueByDay(startDate),
    ]);

    ApiResponseBuilder.success({
      mrr,
      subscriptionsByTier,
      churnRate,
      revenueByDay,
    }).send(res);
  }
);

// Get device/platform analytics
router.get('/devices',
  requirePermission('analytics.read'),
  async (req, res) => {
    const devices = await db('user_devices')
      .select(
        'platform',
        db.raw('COUNT(DISTINCT user_id) as users'),
        db.raw('COUNT(*) as devices'),
        db.raw("ARRAY_AGG(DISTINCT app_version) as versions")
      )
      .groupBy('platform');

    const versionDistribution = await db('user_devices')
      .select('platform', 'app_version')
      .count('* as count')
      .groupBy('platform', 'app_version')
      .orderBy('count', 'desc');

    ApiResponseBuilder.success({
      byPlatform: devices,
      versionDistribution,
    }).send(res);
  }
);

// Helper functions
async function getUserMetrics(since: Date) {
  const [total, newUsers, activeUsers] = await Promise.all([
    db('users').whereNull('deleted_at').count('id as count'),
    db('users').where('created_at', '>=', since).whereNull('deleted_at').count('id as count'),
    db('users').where('last_active_at', '>=', since).whereNull('deleted_at').count('id as count'),
  ]);

  return {
    total: Number(total[0].count),
    new: Number(newUsers[0].count),
    active: Number(activeUsers[0].count),
  };
}

async function getEngagementMetrics(since: Date) {
  const [posts, comments, likes] = await Promise.all([
    db('posts').where('created_at', '>=', since).whereNull('deleted_at').count('id as count'),
    db('comments').where('created_at', '>=', since).whereNull('deleted_at').count('id as count'),
    db('likes').where('created_at', '>=', since).count('id as count'),
  ]);

  return {
    posts: Number(posts[0].count),
    comments: Number(comments[0].count),
    likes: Number(likes[0].count),
  };
}

async function getRevenueMetrics(since: Date) {
  const result = await db('payments')
    .where('created_at', '>=', since)
    .where('status', 'succeeded')
    .select(
      db.raw('SUM(amount) as total_revenue'),
      db.raw('COUNT(*) as transactions'),
      db.raw('AVG(amount) as average_transaction')
    );

  return {
    totalRevenue: Number(result[0].total_revenue) || 0,
    transactions: Number(result[0].transactions) || 0,
    averageTransaction: Number(result[0].average_transaction) || 0,
  };
}

async function getDeviceMetrics(since: Date) {
  const result = await db('user_devices')
    .where('last_active_at', '>=', since)
    .select('platform')
    .count('* as count')
    .groupBy('platform');

  return result.reduce((acc, r) => {
    acc[r.platform] = Number(r.count);
    return acc;
  }, {} as Record<string, number>);
}

async function calculateMRR() {
  const result = await db('user_subscriptions')
    .join('subscription_tiers', 'subscription_tiers.id', 'user_subscriptions.tier_id')
    .where('user_subscriptions.status', 'active')
    .select(db.raw('SUM(subscription_tiers.price_monthly) as mrr'));

  return Number(result[0].mrr) || 0;
}

async function getSubscriptionsByTier() {
  return db('user_subscriptions')
    .join('subscription_tiers', 'subscription_tiers.id', 'user_subscriptions.tier_id')
    .where('user_subscriptions.status', 'active')
    .select('subscription_tiers.name')
    .count('user_subscriptions.id as count')
    .groupBy('subscription_tiers.name');
}

async function calculateChurnRate(since: Date) {
  const [startingUsers, canceledUsers] = await Promise.all([
    db('user_subscriptions')
      .where('created_at', '<', since)
      .where('status', 'active')
      .count('id as count'),
    db('user_subscriptions')
      .where('status', 'canceled')
      .where('updated_at', '>=', since)
      .count('id as count'),
  ]);

  const starting = Number(startingUsers[0].count);
  const canceled = Number(canceledUsers[0].count);

  return starting > 0 ? (canceled / starting) * 100 : 0;
}

async function getRevenueByDay(since: Date) {
  return db('payments')
    .where('created_at', '>=', since)
    .where('status', 'succeeded')
    .select(
      db.raw("DATE(created_at) as date"),
      db.raw('SUM(amount) as revenue'),
      db.raw('COUNT(*) as transactions')
    )
    .groupBy(db.raw('DATE(created_at)'))
    .orderBy('date');
}

export { router as analyticsAdminRouter };
```

### App Version Management

```typescript
// src/routes/admin/appVersions.ts
import { Router } from 'express';
import { db } from '../../database';
import { auditService } from '../../services/auditService';
import { ApiResponseBuilder } from '../../utils/response';

const router = Router();

// Get app versions
router.get('/', async (req, res) => {
  const versions = await db('app_versions')
    .orderBy('created_at', 'desc');

  ApiResponseBuilder.success({ versions }).send(res);
});

// Create app version
router.post('/', async (req, res) => {
  const { platform, version, minRequiredVersion, releaseNotes, forceUpdate } = req.body;

  const [appVersion] = await db('app_versions')
    .insert({
      platform,
      version,
      min_required_version: minRequiredVersion,
      release_notes: releaseNotes,
      force_update: forceUpdate || false,
    })
    .returning('*');

  await auditService.log({
    action: 'app_version.created',
    userId: req.user.id,
    targetId: appVersion.id,
    targetType: 'app_version',
    metadata: { platform, version },
  });

  ApiResponseBuilder.success({ appVersion }).send(res, 201);
});

// Update app version
router.patch('/:versionId', async (req, res) => {
  const { versionId } = req.params;
  const updates = req.body;

  const [appVersion] = await db('app_versions')
    .where('id', versionId)
    .update(updates)
    .returning('*');

  await auditService.log({
    action: 'app_version.updated',
    userId: req.user.id,
    targetId: versionId,
    targetType: 'app_version',
    changes: updates,
  });

  ApiResponseBuilder.success({ appVersion }).send(res);
});

// Set minimum required version (triggers force update)
router.post('/force-update', async (req, res) => {
  const { platform, minVersion } = req.body;

  await db('app_versions')
    .where('platform', platform)
    .update({ force_update: false });

  await db('app_versions')
    .where('platform', platform)
    .where('version', '>=', minVersion)
    .update({
      min_required_version: minVersion,
      force_update: true,
    });

  await auditService.log({
    action: 'app_version.force_update_set',
    userId: req.user.id,
    metadata: { platform, minVersion },
  });

  ApiResponseBuilder.success({ set: true }).send(res);
});

// Get version compatibility check endpoint (for mobile apps)
router.get('/check', async (req, res) => {
  const { platform, version } = req.query;

  const latestVersion = await db('app_versions')
    .where('platform', platform)
    .orderBy('created_at', 'desc')
    .first();

  if (!latestVersion) {
    ApiResponseBuilder.success({
      updateRequired: false,
      forceUpdate: false,
    }).send(res);
    return;
  }

  const isOutdated = semver.lt(version as string, latestVersion.version);
  const forceUpdate = latestVersion.min_required_version &&
    semver.lt(version as string, latestVersion.min_required_version);

  ApiResponseBuilder.success({
    currentVersion: version,
    latestVersion: latestVersion.version,
    updateRequired: isOutdated,
    forceUpdate: !!forceUpdate,
    minRequiredVersion: latestVersion.min_required_version,
    releaseNotes: isOutdated ? latestVersion.release_notes : null,
  }).send(res);
});

export { router as appVersionsAdminRouter };
```

## Gate Criteria

Before marking admin panel complete, verify:

### Authentication/Authorization Gates
- [ ] Admin-only access enforced
- [ ] Role-based permissions working
- [ ] Permission checks on all endpoints
- [ ] Session management working
- [ ] Impersonation properly logged

### User Management Gates
- [ ] User listing with filters working
- [ ] User detail view complete
- [ ] User suspension/ban working
- [ ] User deletion (soft delete) working
- [ ] Role assignment working
- [ ] Password reset available

### Content Moderation Gates
- [ ] Content reports viewable
- [ ] Report review workflow complete
- [ ] Content removal working
- [ ] User warning system working
- [ ] Bulk moderation available
- [ ] Content search available

### Analytics Gates
- [ ] User growth metrics accurate
- [ ] Engagement metrics displayed
- [ ] Revenue metrics available
- [ ] Real-time stats working
- [ ] Device/platform breakdown available
- [ ] Retention cohorts calculated

### System Management Gates
- [ ] App version management working
- [ ] Force update capability working
- [ ] System settings configurable
- [ ] Background job monitoring available
- [ ] Webhook management available

### Audit/Logging Gates
- [ ] All admin actions logged
- [ ] Audit log searchable
- [ ] User activity viewable
- [ ] Export functionality available
- [ ] Sensitive actions require confirmation
