---
name: Mobile Backend Access Control
platform: mobile
description: Role-based access control (RBAC) implementation for mobile backends including permission systems, resource-level authorization, feature flags, and subscription-based access patterns
model: opus
category: mobile/backend
---

# Mobile Backend Access Control Subagent

## Purpose

This subagent handles all aspects of access control and authorization for mobile backends. Mobile applications often require complex permission models including role-based access, resource ownership, feature flags tied to subscription tiers, and granular permissions for team/organization scenarios.

## Core Responsibilities

1. Role-based access control (RBAC) implementation
2. Resource-level authorization (ownership checks)
3. Permission definition and management
4. Feature flag integration with access control
5. Subscription/tier-based feature access
6. Organization/team permission hierarchies
7. API endpoint authorization

## Access Control Architecture

### Permission and Role Schema

```sql
-- migrations/005_create_rbac.sql
-- Up Migration

-- Roles table
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT false, -- System roles can't be deleted
    priority INTEGER NOT NULL DEFAULT 0, -- Higher = more privileges

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Permissions table
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,    -- e.g., 'posts.create', 'users.delete'
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    resource VARCHAR(50) NOT NULL,         -- e.g., 'posts', 'users', 'settings'
    action VARCHAR(50) NOT NULL,           -- e.g., 'create', 'read', 'update', 'delete'

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_permissions_resource ON permissions(resource);

-- Role-Permission junction
CREATE TABLE role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (role_id, permission_id)
);

-- User-Role junction
CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,

    assigned_by UUID REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (user_id, role_id)
);

CREATE INDEX idx_user_roles_user ON user_roles(user_id);

-- Direct user permissions (for specific overrides)
CREATE TABLE user_permissions (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,

    granted BOOLEAN NOT NULL DEFAULT true, -- false = explicitly denied
    assigned_by UUID REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (user_id, permission_id)
);

-- Subscription tiers (for mobile app monetization)
CREATE TABLE subscription_tiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE,      -- e.g., 'free', 'pro', 'enterprise'
    display_name VARCHAR(100) NOT NULL,
    price_monthly DECIMAL(10, 2),
    price_yearly DECIMAL(10, 2),
    priority INTEGER NOT NULL DEFAULT 0,   -- Higher = more features

    -- Limits
    limits JSONB NOT NULL DEFAULT '{}',    -- e.g., {"posts_per_month": 10, "storage_mb": 100}

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tier-Feature junction
CREATE TABLE tier_features (
    tier_id UUID NOT NULL REFERENCES subscription_tiers(id) ON DELETE CASCADE,
    feature_name VARCHAR(100) NOT NULL,    -- e.g., 'advanced_analytics', 'export_pdf'
    enabled BOOLEAN NOT NULL DEFAULT true,

    PRIMARY KEY (tier_id, feature_name)
);

-- User subscriptions
CREATE TABLE user_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tier_id UUID NOT NULL REFERENCES subscription_tiers(id),

    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'canceled', 'past_due', 'expired', 'trialing')),

    -- Subscription details
    external_id VARCHAR(255),              -- Stripe subscription ID, etc.
    current_period_start TIMESTAMPTZ NOT NULL,
    current_period_end TIMESTAMPTZ NOT NULL,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_subscriptions_user ON user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_status ON user_subscriptions(status);

-- Seed default roles
INSERT INTO roles (name, display_name, description, is_system, priority) VALUES
    ('admin', 'Administrator', 'Full system access', true, 100),
    ('moderator', 'Moderator', 'Content moderation access', true, 50),
    ('user', 'User', 'Standard user access', true, 10);

-- Seed default subscription tiers
INSERT INTO subscription_tiers (name, display_name, price_monthly, price_yearly, priority, limits) VALUES
    ('free', 'Free', 0, 0, 0, '{"posts_per_month": 10, "storage_mb": 100, "api_calls_per_day": 1000}'),
    ('pro', 'Pro', 9.99, 99.99, 50, '{"posts_per_month": -1, "storage_mb": 10000, "api_calls_per_day": 50000}'),
    ('enterprise', 'Enterprise', 49.99, 499.99, 100, '{"posts_per_month": -1, "storage_mb": -1, "api_calls_per_day": -1}');

-- Down Migration
DROP TABLE IF EXISTS user_subscriptions;
DROP TABLE IF EXISTS tier_features;
DROP TABLE IF EXISTS subscription_tiers;
DROP TABLE IF EXISTS user_permissions;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS roles;
```

## Authorization Service

```typescript
// src/services/authorizationService.ts
import { db } from '../database';
import { redis } from '../cache/redis';
import { AppError, ErrorCodes } from '../errors/AppError';

interface UserPermissions {
  roles: string[];
  permissions: Set<string>;
  subscription: {
    tier: string;
    features: Set<string>;
    limits: Record<string, number>;
    status: string;
  };
}

export class AuthorizationService {
  private readonly CACHE_TTL = 300; // 5 minutes

  // Get all permissions for a user (cached)
  async getUserPermissions(userId: string): Promise<UserPermissions> {
    const cacheKey = `user:permissions:${userId}`;

    // Check cache first
    const cached = await redis.get(cacheKey);
    if (cached) {
      const parsed = JSON.parse(cached);
      return {
        ...parsed,
        permissions: new Set(parsed.permissions),
        subscription: {
          ...parsed.subscription,
          features: new Set(parsed.subscription.features),
        },
      };
    }

    // Fetch from database
    const permissions = await this.fetchUserPermissions(userId);

    // Cache the result (convert Sets to arrays for JSON)
    await redis.set(
      cacheKey,
      JSON.stringify({
        ...permissions,
        permissions: Array.from(permissions.permissions),
        subscription: {
          ...permissions.subscription,
          features: Array.from(permissions.subscription.features),
        },
      }),
      'EX',
      this.CACHE_TTL
    );

    return permissions;
  }

  private async fetchUserPermissions(userId: string): Promise<UserPermissions> {
    // Get user roles
    const roles = await db('user_roles')
      .join('roles', 'roles.id', 'user_roles.role_id')
      .where('user_roles.user_id', userId)
      .select('roles.name');

    const roleNames = roles.map(r => r.name);

    // Get permissions from roles
    const rolePermissions = await db('role_permissions')
      .join('permissions', 'permissions.id', 'role_permissions.permission_id')
      .join('user_roles', 'user_roles.role_id', 'role_permissions.role_id')
      .where('user_roles.user_id', userId)
      .select('permissions.name');

    // Get direct user permissions
    const userPerms = await db('user_permissions')
      .join('permissions', 'permissions.id', 'user_permissions.permission_id')
      .where('user_permissions.user_id', userId)
      .select('permissions.name', 'user_permissions.granted');

    // Build permission set (direct permissions override role permissions)
    const permissions = new Set<string>(rolePermissions.map(p => p.name));

    for (const perm of userPerms) {
      if (perm.granted) {
        permissions.add(perm.name);
      } else {
        permissions.delete(perm.name);
      }
    }

    // Get subscription info
    const subscription = await this.getUserSubscription(userId);

    return {
      roles: roleNames,
      permissions,
      subscription,
    };
  }

  private async getUserSubscription(userId: string) {
    const sub = await db('user_subscriptions')
      .join('subscription_tiers', 'subscription_tiers.id', 'user_subscriptions.tier_id')
      .where('user_subscriptions.user_id', userId)
      .where('user_subscriptions.status', 'active')
      .select(
        'subscription_tiers.name as tier',
        'subscription_tiers.limits',
        'user_subscriptions.status'
      )
      .first();

    if (!sub) {
      // Default to free tier
      const freeTier = await db('subscription_tiers')
        .where('name', 'free')
        .first();

      return {
        tier: 'free',
        features: new Set<string>(),
        limits: freeTier?.limits || {},
        status: 'active',
      };
    }

    // Get tier features
    const features = await db('tier_features')
      .join('subscription_tiers', 'subscription_tiers.id', 'tier_features.tier_id')
      .where('subscription_tiers.name', sub.tier)
      .where('tier_features.enabled', true)
      .select('tier_features.feature_name');

    return {
      tier: sub.tier,
      features: new Set(features.map(f => f.feature_name)),
      limits: sub.limits,
      status: sub.status,
    };
  }

  // Check if user has a specific permission
  async hasPermission(userId: string, permission: string): Promise<boolean> {
    const userPerms = await this.getUserPermissions(userId);

    // Admin has all permissions
    if (userPerms.roles.includes('admin')) {
      return true;
    }

    return userPerms.permissions.has(permission);
  }

  // Check if user has any of the specified permissions
  async hasAnyPermission(userId: string, permissions: string[]): Promise<boolean> {
    const userPerms = await this.getUserPermissions(userId);

    if (userPerms.roles.includes('admin')) {
      return true;
    }

    return permissions.some(p => userPerms.permissions.has(p));
  }

  // Check if user has all of the specified permissions
  async hasAllPermissions(userId: string, permissions: string[]): Promise<boolean> {
    const userPerms = await this.getUserPermissions(userId);

    if (userPerms.roles.includes('admin')) {
      return true;
    }

    return permissions.every(p => userPerms.permissions.has(p));
  }

  // Check if user has a specific role
  async hasRole(userId: string, role: string): Promise<boolean> {
    const userPerms = await this.getUserPermissions(userId);
    return userPerms.roles.includes(role);
  }

  // Check if user has access to a feature (subscription-based)
  async hasFeature(userId: string, feature: string): Promise<boolean> {
    const userPerms = await this.getUserPermissions(userId);

    // Admin always has access
    if (userPerms.roles.includes('admin')) {
      return true;
    }

    return userPerms.subscription.features.has(feature);
  }

  // Check usage limit
  async checkLimit(
    userId: string,
    limitKey: string,
    currentUsage: number
  ): Promise<{ allowed: boolean; limit: number; remaining: number }> {
    const userPerms = await this.getUserPermissions(userId);
    const limit = userPerms.subscription.limits[limitKey];

    // -1 means unlimited
    if (limit === -1) {
      return { allowed: true, limit: -1, remaining: -1 };
    }

    const remaining = Math.max(0, limit - currentUsage);
    return {
      allowed: currentUsage < limit,
      limit,
      remaining,
    };
  }

  // Invalidate cache when permissions change
  async invalidateUserPermissions(userId: string): Promise<void> {
    await redis.del(`user:permissions:${userId}`);
  }

  // Assign role to user
  async assignRole(
    userId: string,
    roleName: string,
    assignedBy: string
  ): Promise<void> {
    const role = await db('roles').where('name', roleName).first();

    if (!role) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Role not found', 404);
    }

    await db('user_roles')
      .insert({
        user_id: userId,
        role_id: role.id,
        assigned_by: assignedBy,
      })
      .onConflict(['user_id', 'role_id'])
      .ignore();

    await this.invalidateUserPermissions(userId);
  }

  // Remove role from user
  async removeRole(userId: string, roleName: string): Promise<void> {
    await db('user_roles')
      .join('roles', 'roles.id', 'user_roles.role_id')
      .where('user_roles.user_id', userId)
      .where('roles.name', roleName)
      .delete();

    await this.invalidateUserPermissions(userId);
  }

  // Grant direct permission
  async grantPermission(
    userId: string,
    permissionName: string,
    grantedBy: string
  ): Promise<void> {
    const permission = await db('permissions')
      .where('name', permissionName)
      .first();

    if (!permission) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'Permission not found', 404);
    }

    await db('user_permissions')
      .insert({
        user_id: userId,
        permission_id: permission.id,
        granted: true,
        assigned_by: grantedBy,
      })
      .onConflict(['user_id', 'permission_id'])
      .merge({ granted: true, assigned_by: grantedBy });

    await this.invalidateUserPermissions(userId);
  }

  // Revoke direct permission
  async revokePermission(
    userId: string,
    permissionName: string,
    revokedBy: string
  ): Promise<void> {
    const permission = await db('permissions')
      .where('name', permissionName)
      .first();

    if (!permission) {
      return;
    }

    await db('user_permissions')
      .insert({
        user_id: userId,
        permission_id: permission.id,
        granted: false,
        assigned_by: revokedBy,
      })
      .onConflict(['user_id', 'permission_id'])
      .merge({ granted: false, assigned_by: revokedBy });

    await this.invalidateUserPermissions(userId);
  }
}

export const authorizationService = new AuthorizationService();
```

## Resource Authorization

```typescript
// src/services/resourceAuthorizationService.ts
import { db } from '../database';
import { authorizationService } from './authorizationService';
import { AppError, ErrorCodes } from '../errors/AppError';

type ResourceType = 'post' | 'comment' | 'user' | 'organization' | 'team';
type Action = 'read' | 'update' | 'delete' | 'manage';

interface AuthorizationContext {
  userId: string;
  resourceType: ResourceType;
  resourceId: string;
  action: Action;
}

export class ResourceAuthorizationService {
  // Check if user can perform action on resource
  async authorize(context: AuthorizationContext): Promise<boolean> {
    const { userId, resourceType, resourceId, action } = context;

    // Check ownership first
    const isOwner = await this.isResourceOwner(userId, resourceType, resourceId);
    if (isOwner) {
      return true;
    }

    // Check permission
    const permission = `${resourceType}s.${action}`;
    const hasPermission = await authorizationService.hasPermission(userId, permission);
    if (hasPermission) {
      return true;
    }

    // Check resource-specific rules
    return this.checkResourceSpecificRules(context);
  }

  // Authorize or throw
  async authorizeOrFail(context: AuthorizationContext): Promise<void> {
    const authorized = await this.authorize(context);

    if (!authorized) {
      throw new AppError(
        ErrorCodes.ACCESS_DENIED,
        `You do not have permission to ${context.action} this ${context.resourceType}`,
        403
      );
    }
  }

  // Check resource ownership
  async isResourceOwner(
    userId: string,
    resourceType: ResourceType,
    resourceId: string
  ): Promise<boolean> {
    const ownerField = this.getOwnerField(resourceType);
    const tableName = this.getTableName(resourceType);

    const resource = await db(tableName)
      .where('id', resourceId)
      .select(ownerField)
      .first();

    if (!resource) {
      return false;
    }

    return resource[ownerField] === userId;
  }

  // Resource-specific authorization rules
  private async checkResourceSpecificRules(
    context: AuthorizationContext
  ): Promise<boolean> {
    switch (context.resourceType) {
      case 'post':
        return this.checkPostAccess(context);
      case 'comment':
        return this.checkCommentAccess(context);
      case 'organization':
        return this.checkOrganizationAccess(context);
      case 'team':
        return this.checkTeamAccess(context);
      default:
        return false;
    }
  }

  private async checkPostAccess(context: AuthorizationContext): Promise<boolean> {
    const post = await db('posts')
      .where('id', context.resourceId)
      .first();

    if (!post) {
      return false;
    }

    // Public posts can be read by anyone
    if (context.action === 'read' && post.visibility === 'public') {
      return true;
    }

    // Followers can read follower-only posts
    if (context.action === 'read' && post.visibility === 'followers') {
      const isFollowing = await db('follows')
        .where({
          follower_id: context.userId,
          following_id: post.user_id,
        })
        .first();

      return !!isFollowing;
    }

    return false;
  }

  private async checkCommentAccess(context: AuthorizationContext): Promise<boolean> {
    const comment = await db('comments')
      .where('id', context.resourceId)
      .first();

    if (!comment) {
      return false;
    }

    // Check if user can access the parent post
    const canAccessPost = await this.authorize({
      userId: context.userId,
      resourceType: 'post',
      resourceId: comment.post_id,
      action: 'read',
    });

    if (context.action === 'read') {
      return canAccessPost;
    }

    return false;
  }

  private async checkOrganizationAccess(
    context: AuthorizationContext
  ): Promise<boolean> {
    const membership = await db('organization_members')
      .where({
        organization_id: context.resourceId,
        user_id: context.userId,
      })
      .first();

    if (!membership) {
      return false;
    }

    // Check role-based access within organization
    switch (context.action) {
      case 'read':
        return true;
      case 'update':
        return ['admin', 'owner'].includes(membership.role);
      case 'delete':
        return membership.role === 'owner';
      case 'manage':
        return ['admin', 'owner'].includes(membership.role);
      default:
        return false;
    }
  }

  private async checkTeamAccess(context: AuthorizationContext): Promise<boolean> {
    const team = await db('teams')
      .where('id', context.resourceId)
      .first();

    if (!team) {
      return false;
    }

    // Check organization membership
    const orgAccess = await this.checkOrganizationAccess({
      ...context,
      resourceType: 'organization',
      resourceId: team.organization_id,
    });

    if (orgAccess) {
      return true;
    }

    // Check direct team membership
    const membership = await db('team_members')
      .where({
        team_id: context.resourceId,
        user_id: context.userId,
      })
      .first();

    if (!membership) {
      return false;
    }

    switch (context.action) {
      case 'read':
        return true;
      case 'update':
        return ['admin', 'owner'].includes(membership.role);
      case 'delete':
        return membership.role === 'owner';
      default:
        return false;
    }
  }

  private getOwnerField(resourceType: ResourceType): string {
    const ownerFields: Record<ResourceType, string> = {
      post: 'user_id',
      comment: 'user_id',
      user: 'id',
      organization: 'owner_id',
      team: 'owner_id',
    };
    return ownerFields[resourceType];
  }

  private getTableName(resourceType: ResourceType): string {
    const tableNames: Record<ResourceType, string> = {
      post: 'posts',
      comment: 'comments',
      user: 'users',
      organization: 'organizations',
      team: 'teams',
    };
    return tableNames[resourceType];
  }
}

export const resourceAuthorizationService = new ResourceAuthorizationService();
```

## Authorization Middleware

```typescript
// src/middleware/authorize.ts
import { Request, Response, NextFunction } from 'express';
import { authorizationService } from '../services/authorizationService';
import { resourceAuthorizationService } from '../services/resourceAuthorizationService';
import { AppError, ErrorCodes } from '../errors/AppError';

// Check specific permission
export function requirePermission(...permissions: string[]) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user.id;

      const hasPermission = await authorizationService.hasAnyPermission(
        userId,
        permissions
      );

      if (!hasPermission) {
        throw new AppError(
          ErrorCodes.ACCESS_DENIED,
          'You do not have permission to perform this action',
          403
        );
      }

      next();
    } catch (error) {
      next(error);
    }
  };
}

// Check specific role
export function requireRole(...roles: string[]) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user.id;
      const userPerms = await authorizationService.getUserPermissions(userId);

      const hasRole = roles.some(role => userPerms.roles.includes(role));

      if (!hasRole) {
        throw new AppError(
          ErrorCodes.ACCESS_DENIED,
          'You do not have the required role',
          403
        );
      }

      next();
    } catch (error) {
      next(error);
    }
  };
}

// Check subscription feature
export function requireFeature(feature: string) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user.id;

      const hasFeature = await authorizationService.hasFeature(userId, feature);

      if (!hasFeature) {
        throw new AppError(
          ErrorCodes.SUBSCRIPTION_REQUIRED,
          `This feature requires an upgraded subscription`,
          403,
          { feature, requiredTier: await getRequiredTier(feature) }
        );
      }

      next();
    } catch (error) {
      next(error);
    }
  };
}

// Check resource authorization
export function authorizeResource(
  resourceType: string,
  action: string,
  resourceIdParam: string = 'id'
) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user.id;
      const resourceId = req.params[resourceIdParam];

      await resourceAuthorizationService.authorizeOrFail({
        userId,
        resourceType: resourceType as any,
        resourceId,
        action: action as any,
      });

      next();
    } catch (error) {
      next(error);
    }
  };
}

// Check ownership
export function requireOwnership(
  resourceType: string,
  resourceIdParam: string = 'id'
) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user.id;
      const resourceId = req.params[resourceIdParam];

      const isOwner = await resourceAuthorizationService.isResourceOwner(
        userId,
        resourceType as any,
        resourceId
      );

      if (!isOwner) {
        throw new AppError(
          ErrorCodes.ACCESS_DENIED,
          'You do not own this resource',
          403
        );
      }

      next();
    } catch (error) {
      next(error);
    }
  };
}

// Helper to get required tier for a feature
async function getRequiredTier(feature: string): Promise<string> {
  const tier = await db('tier_features')
    .join('subscription_tiers', 'subscription_tiers.id', 'tier_features.tier_id')
    .where('tier_features.feature_name', feature)
    .where('tier_features.enabled', true)
    .orderBy('subscription_tiers.priority', 'asc')
    .select('subscription_tiers.name')
    .first();

  return tier?.name || 'pro';
}
```

## Usage in Routes

```typescript
// src/routes/posts.ts
import { Router } from 'express';
import { authenticate } from '../middleware/authenticate';
import {
  requirePermission,
  requireFeature,
  authorizeResource,
  requireOwnership,
} from '../middleware/authorize';
import { postsController } from '../controllers/postsController';

const router = Router();

// List posts (public, no auth required)
router.get('/', postsController.list);

// Get single post (checks visibility)
router.get('/:id', postsController.get);

// Create post (requires auth)
router.post('/',
  authenticate,
  postsController.create
);

// Update post (requires ownership or permission)
router.put('/:id',
  authenticate,
  authorizeResource('post', 'update'),
  postsController.update
);

// Delete post (requires ownership or permission)
router.delete('/:id',
  authenticate,
  authorizeResource('post', 'delete'),
  postsController.delete
);

// Schedule post (requires premium feature)
router.post('/:id/schedule',
  authenticate,
  requireOwnership('post'),
  requireFeature('scheduled_posts'),
  postsController.schedule
);

// Analytics (requires premium feature)
router.get('/:id/analytics',
  authenticate,
  requireOwnership('post'),
  requireFeature('post_analytics'),
  postsController.analytics
);

// Admin routes
router.get('/admin/all',
  authenticate,
  requirePermission('posts.admin'),
  postsController.adminList
);

router.post('/:id/moderate',
  authenticate,
  requirePermission('posts.moderate'),
  postsController.moderate
);

export { router as postsRouter };
```

## Feature Flag Integration

```typescript
// src/services/featureFlagService.ts
import { redis } from '../cache/redis';
import { db } from '../database';
import { authorizationService } from './authorizationService';

interface FeatureFlag {
  name: string;
  enabled: boolean;
  rolloutPercentage: number;
  allowedTiers: string[];
  allowedRoles: string[];
  metadata: Record<string, unknown>;
}

export class FeatureFlagService {
  // Check if feature is enabled for user
  async isEnabled(userId: string, featureName: string): Promise<boolean> {
    const flag = await this.getFeatureFlag(featureName);

    if (!flag || !flag.enabled) {
      return false;
    }

    // Check tier-based access
    const userPerms = await authorizationService.getUserPermissions(userId);

    if (flag.allowedTiers.length > 0) {
      if (!flag.allowedTiers.includes(userPerms.subscription.tier)) {
        return false;
      }
    }

    // Check role-based access
    if (flag.allowedRoles.length > 0) {
      const hasRole = userPerms.roles.some(role =>
        flag.allowedRoles.includes(role)
      );
      if (!hasRole) {
        return false;
      }
    }

    // Check rollout percentage
    if (flag.rolloutPercentage < 100) {
      const userHash = this.hashUserId(userId, featureName);
      const percentile = userHash % 100;
      if (percentile >= flag.rolloutPercentage) {
        return false;
      }
    }

    return true;
  }

  // Get feature flag configuration
  private async getFeatureFlag(name: string): Promise<FeatureFlag | null> {
    const cacheKey = `feature:${name}`;

    // Check cache
    const cached = await redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    // Fetch from database
    const flag = await db('feature_flags')
      .where('name', name)
      .first();

    if (!flag) {
      return null;
    }

    const featureFlag: FeatureFlag = {
      name: flag.name,
      enabled: flag.enabled,
      rolloutPercentage: flag.rollout_percentage,
      allowedTiers: flag.allowed_tiers || [],
      allowedRoles: flag.allowed_roles || [],
      metadata: flag.metadata || {},
    };

    // Cache for 1 minute
    await redis.set(cacheKey, JSON.stringify(featureFlag), 'EX', 60);

    return featureFlag;
  }

  // Consistent hash for rollout
  private hashUserId(userId: string, feature: string): number {
    const combined = `${userId}:${feature}`;
    let hash = 0;
    for (let i = 0; i < combined.length; i++) {
      const char = combined.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash);
  }

  // Get all enabled features for user
  async getEnabledFeatures(userId: string): Promise<string[]> {
    const allFlags = await db('feature_flags')
      .where('enabled', true)
      .select('name');

    const enabledFeatures: string[] = [];

    for (const flag of allFlags) {
      if (await this.isEnabled(userId, flag.name)) {
        enabledFeatures.push(flag.name);
      }
    }

    return enabledFeatures;
  }
}

export const featureFlagService = new FeatureFlagService();
```

## Mobile Client Permission Response

```typescript
// src/controllers/permissionsController.ts
import { Request, Response } from 'express';
import { authorizationService } from '../services/authorizationService';
import { featureFlagService } from '../services/featureFlagService';
import { ApiResponseBuilder } from '../utils/response';

export const permissionsController = {
  // Get current user's permissions (for mobile client to cache)
  async getCurrentPermissions(req: Request, res: Response) {
    const userId = req.user.id;

    const [permissions, features] = await Promise.all([
      authorizationService.getUserPermissions(userId),
      featureFlagService.getEnabledFeatures(userId),
    ]);

    ApiResponseBuilder.success({
      roles: permissions.roles,
      permissions: Array.from(permissions.permissions),
      subscription: {
        tier: permissions.subscription.tier,
        features: Array.from(permissions.subscription.features),
        limits: permissions.subscription.limits,
        status: permissions.subscription.status,
      },
      featureFlags: features,
    }).send(res);
  },

  // Check specific permission (for real-time checks)
  async checkPermission(req: Request, res: Response) {
    const userId = req.user.id;
    const { permission } = req.query;

    const hasPermission = await authorizationService.hasPermission(
      userId,
      permission as string
    );

    ApiResponseBuilder.success({ hasPermission }).send(res);
  },

  // Check feature access
  async checkFeature(req: Request, res: Response) {
    const userId = req.user.id;
    const { feature } = req.query;

    const [hasFeature, hasTierFeature] = await Promise.all([
      featureFlagService.isEnabled(userId, feature as string),
      authorizationService.hasFeature(userId, feature as string),
    ]);

    ApiResponseBuilder.success({
      enabled: hasFeature && hasTierFeature,
      featureFlag: hasFeature,
      subscriptionFeature: hasTierFeature,
    }).send(res);
  },

  // Check usage limit
  async checkLimit(req: Request, res: Response) {
    const userId = req.user.id;
    const { limitKey, currentUsage } = req.query;

    const result = await authorizationService.checkLimit(
      userId,
      limitKey as string,
      parseInt(currentUsage as string) || 0
    );

    ApiResponseBuilder.success(result).send(res);
  },
};
```

## Gate Criteria

Before marking access control complete, verify:

### RBAC Gates
- [ ] Role hierarchy properly defined
- [ ] Default roles created (admin, user, etc.)
- [ ] Permissions follow resource.action naming
- [ ] Role-permission assignments complete
- [ ] Direct user permissions override role permissions

### Authorization Gates
- [ ] All endpoints have appropriate authorization
- [ ] Resource ownership checks implemented
- [ ] Admin override works correctly
- [ ] Unauthorized access returns 403
- [ ] Authorization cached appropriately

### Subscription Gates
- [ ] Subscription tiers defined
- [ ] Feature-tier mapping complete
- [ ] Usage limits enforced
- [ ] Limit exceeded returns appropriate error
- [ ] Subscription status checked

### Feature Flag Gates
- [ ] Feature flags can enable/disable features
- [ ] Rollout percentage working
- [ ] Tier-based feature access working
- [ ] Feature flags cached and invalidated properly
- [ ] Mobile client can fetch all permissions

### Security Gates
- [ ] Permission cache invalidation works
- [ ] No privilege escalation possible
- [ ] Authorization checks server-side (not client-only)
- [ ] Sensitive operations logged
- [ ] Role assignment requires admin permission

### Testing Gates
- [ ] Unit tests for authorization service
- [ ] Integration tests for protected routes
- [ ] Tests for subscription tier access
- [ ] Tests for feature flags
- [ ] Tests for cache invalidation
