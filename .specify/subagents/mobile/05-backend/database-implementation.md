---
name: Mobile Backend Database Implementation
platform: mobile
description: Database implementation and migrations for mobile backends including schema design, query optimization, connection pooling, data modeling for mobile sync, and migration strategies
model: opus
category: mobile/backend
---

# Mobile Backend Database Implementation Subagent

## Purpose

This subagent handles all database implementation aspects for mobile backends. Mobile applications have unique data requirements including offline sync support, efficient delta queries, soft delete patterns for data recovery, and optimized schemas for common mobile access patterns.

## Core Responsibilities

1. Database schema design and implementation
2. Migration management and versioning
3. Query optimization for mobile patterns
4. Connection pooling and performance tuning
5. Data modeling for offline sync
6. Index strategy for mobile queries
7. Backup and recovery procedures

## Database Schema Patterns

### Pattern 1: User and Authentication Schema

```sql
-- migrations/001_create_users.sql
-- Up Migration

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table with mobile-specific fields
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified_at TIMESTAMPTZ,
    phone VARCHAR(20) UNIQUE,
    phone_verified_at TIMESTAMPTZ,
    password_hash VARCHAR(255) NOT NULL,

    -- Profile
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    display_name VARCHAR(100),
    avatar_url TEXT,
    bio TEXT,

    -- Account status
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('pending', 'active', 'suspended', 'deleted')),

    -- Mobile-specific
    last_active_at TIMESTAMPTZ,
    timezone VARCHAR(50) DEFAULT 'UTC',
    locale VARCHAR(10) DEFAULT 'en',

    -- Sync support
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ -- Soft delete
);

-- Indexes for common queries
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_phone ON users(phone) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_status ON users(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_updated_at ON users(updated_at);
CREATE INDEX idx_users_sync ON users(updated_at, version) WHERE deleted_at IS NULL;

-- User devices for push notifications and session management
CREATE TABLE user_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Device identification
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255),
    device_model VARCHAR(100),
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    os_version VARCHAR(50),
    app_version VARCHAR(50) NOT NULL,

    -- Push notifications
    push_token TEXT,
    push_token_type VARCHAR(20) CHECK (push_token_type IN ('fcm', 'apns', 'web')),
    push_enabled BOOLEAN DEFAULT true,

    -- Session info
    last_ip INET,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id, device_id)
);

CREATE INDEX idx_user_devices_user ON user_devices(user_id);
CREATE INDEX idx_user_devices_push ON user_devices(push_token) WHERE push_enabled = true;
CREATE INDEX idx_user_devices_platform ON user_devices(platform, app_version);

-- Refresh tokens for mobile session management
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID REFERENCES user_devices(id) ON DELETE CASCADE,

    token_hash VARCHAR(255) NOT NULL UNIQUE,
    family_id UUID NOT NULL, -- Token rotation family

    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    revoked_reason VARCHAR(50),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- IP and location for security
    created_ip INET,
    created_user_agent TEXT
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_family ON refresh_tokens(family_id);
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens(expires_at) WHERE revoked_at IS NULL;

-- Down Migration
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS user_devices;
DROP TABLE IF EXISTS users;
```

### Pattern 2: Content Schema with Sync Support

```sql
-- migrations/002_create_content.sql
-- Up Migration

-- Posts/Content table optimized for mobile sync
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Content
    title VARCHAR(255),
    body TEXT NOT NULL,
    media_urls JSONB DEFAULT '[]',

    -- Metadata
    post_type VARCHAR(20) NOT NULL DEFAULT 'text'
        CHECK (post_type IN ('text', 'image', 'video', 'link')),
    visibility VARCHAR(20) NOT NULL DEFAULT 'public'
        CHECK (visibility IN ('public', 'private', 'followers')),

    -- Engagement counters (denormalized for performance)
    likes_count INTEGER NOT NULL DEFAULT 0,
    comments_count INTEGER NOT NULL DEFAULT 0,
    shares_count INTEGER NOT NULL DEFAULT 0,

    -- Location (optional)
    location_name VARCHAR(255),
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),

    -- Sync support
    version INTEGER NOT NULL DEFAULT 1,
    client_created_at TIMESTAMPTZ, -- Time from mobile device
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Optimized indexes for mobile access patterns
CREATE INDEX idx_posts_user ON posts(user_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_posts_feed ON posts(created_at DESC, id DESC) WHERE deleted_at IS NULL AND visibility = 'public';
CREATE INDEX idx_posts_sync ON posts(user_id, updated_at, version) WHERE deleted_at IS NULL;
CREATE INDEX idx_posts_location ON posts USING GIST (
    point(location_lng, location_lat)
) WHERE location_lat IS NOT NULL AND deleted_at IS NULL;

-- Deleted posts tracking for sync
CREATE TABLE posts_deleted (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL,
    user_id UUID NOT NULL,
    deleted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_posts_deleted_user ON posts_deleted(user_id, deleted_at);

-- Comments with nested support
CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,

    body TEXT NOT NULL,

    -- Engagement
    likes_count INTEGER NOT NULL DEFAULT 0,
    replies_count INTEGER NOT NULL DEFAULT 0,

    -- Nested set for efficient tree queries (optional)
    lft INTEGER,
    rgt INTEGER,
    depth INTEGER NOT NULL DEFAULT 0,

    -- Sync support
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_comments_post ON comments(post_id, created_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_comments_user ON comments(user_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_comments_parent ON comments(parent_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_comments_nested ON comments(post_id, lft, rgt) WHERE deleted_at IS NULL;

-- Likes (polymorphic)
CREATE TABLE likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Polymorphic relation
    likeable_type VARCHAR(20) NOT NULL CHECK (likeable_type IN ('post', 'comment')),
    likeable_id UUID NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id, likeable_type, likeable_id)
);

CREATE INDEX idx_likes_user ON likes(user_id);
CREATE INDEX idx_likes_target ON likes(likeable_type, likeable_id);

-- Down Migration
DROP TABLE IF EXISTS likes;
DROP TABLE IF EXISTS comments;
DROP TABLE IF EXISTS posts_deleted;
DROP TABLE IF EXISTS posts;
```

### Pattern 3: Notification Schema

```sql
-- migrations/003_create_notifications.sql
-- Up Migration

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Notification type and content
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT,
    data JSONB DEFAULT '{}',

    -- Deep linking
    action_url TEXT,
    action_type VARCHAR(50),

    -- Related entities (optional)
    actor_id UUID REFERENCES users(id),
    target_type VARCHAR(50),
    target_id UUID,

    -- Status
    read_at TIMESTAMPTZ,
    seen_at TIMESTAMPTZ,

    -- Push delivery status
    push_sent_at TIMESTAMPTZ,
    push_delivered_at TIMESTAMPTZ,
    push_error TEXT,

    -- Grouping
    group_key VARCHAR(100),

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- Indexes for notification queries
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, created_at DESC)
    WHERE read_at IS NULL;
CREATE INDEX idx_notifications_user_all ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_group ON notifications(user_id, group_key, created_at DESC);
CREATE INDEX idx_notifications_push_pending ON notifications(created_at)
    WHERE push_sent_at IS NULL;
CREATE INDEX idx_notifications_expires ON notifications(expires_at)
    WHERE expires_at IS NOT NULL;

-- Notification preferences per user
CREATE TABLE notification_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Channel preferences
    push_enabled BOOLEAN NOT NULL DEFAULT true,
    email_enabled BOOLEAN NOT NULL DEFAULT true,
    sms_enabled BOOLEAN NOT NULL DEFAULT false,

    -- Type preferences (JSONB for flexibility)
    type_preferences JSONB NOT NULL DEFAULT '{
        "likes": {"push": true, "email": false},
        "comments": {"push": true, "email": true},
        "follows": {"push": true, "email": true},
        "mentions": {"push": true, "email": true},
        "marketing": {"push": false, "email": false}
    }',

    -- Quiet hours
    quiet_hours_enabled BOOLEAN NOT NULL DEFAULT false,
    quiet_hours_start TIME,
    quiet_hours_end TIME,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id)
);

CREATE INDEX idx_notification_prefs_user ON notification_preferences(user_id);

-- Down Migration
DROP TABLE IF EXISTS notification_preferences;
DROP TABLE IF EXISTS notifications;
```

## Migration Management

### TypeScript Migration Runner

```typescript
// src/database/migrator.ts
import { Pool } from 'pg';
import * as fs from 'fs/promises';
import * as path from 'path';
import { logger } from '../utils/logger';

interface Migration {
  id: number;
  name: string;
  applied_at: Date;
}

export class Migrator {
  private pool: Pool;
  private migrationsDir: string;

  constructor(pool: Pool, migrationsDir: string = './migrations') {
    this.pool = pool;
    this.migrationsDir = migrationsDir;
  }

  async initialize(): Promise<void> {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL UNIQUE,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
  }

  async getAppliedMigrations(): Promise<string[]> {
    const result = await this.pool.query<Migration>(
      'SELECT name FROM schema_migrations ORDER BY id'
    );
    return result.rows.map(row => row.name);
  }

  async getPendingMigrations(): Promise<string[]> {
    const applied = await this.getAppliedMigrations();
    const files = await fs.readdir(this.migrationsDir);

    const migrations = files
      .filter(f => f.endsWith('.sql'))
      .sort()
      .filter(f => !applied.includes(f));

    return migrations;
  }

  async migrate(): Promise<void> {
    await this.initialize();
    const pending = await this.getPendingMigrations();

    if (pending.length === 0) {
      logger.info('No pending migrations');
      return;
    }

    logger.info(`Found ${pending.length} pending migrations`);

    for (const migration of pending) {
      await this.applyMigration(migration);
    }

    logger.info('All migrations applied successfully');
  }

  async applyMigration(name: string): Promise<void> {
    const client = await this.pool.connect();

    try {
      const filePath = path.join(this.migrationsDir, name);
      const content = await fs.readFile(filePath, 'utf-8');

      // Extract up migration (everything before "-- Down Migration")
      const upMigration = content.split('-- Down Migration')[0];

      logger.info(`Applying migration: ${name}`);

      await client.query('BEGIN');
      await client.query(upMigration);
      await client.query(
        'INSERT INTO schema_migrations (name) VALUES ($1)',
        [name]
      );
      await client.query('COMMIT');

      logger.info(`Migration applied: ${name}`);
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error(`Migration failed: ${name}`, error);
      throw error;
    } finally {
      client.release();
    }
  }

  async rollback(steps: number = 1): Promise<void> {
    const applied = await this.getAppliedMigrations();
    const toRollback = applied.slice(-steps);

    for (const name of toRollback.reverse()) {
      await this.rollbackMigration(name);
    }
  }

  async rollbackMigration(name: string): Promise<void> {
    const client = await this.pool.connect();

    try {
      const filePath = path.join(this.migrationsDir, name);
      const content = await fs.readFile(filePath, 'utf-8');

      // Extract down migration
      const parts = content.split('-- Down Migration');
      if (parts.length < 2) {
        throw new Error(`No down migration found in ${name}`);
      }
      const downMigration = parts[1];

      logger.info(`Rolling back migration: ${name}`);

      await client.query('BEGIN');
      await client.query(downMigration);
      await client.query(
        'DELETE FROM schema_migrations WHERE name = $1',
        [name]
      );
      await client.query('COMMIT');

      logger.info(`Migration rolled back: ${name}`);
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error(`Rollback failed: ${name}`, error);
      throw error;
    } finally {
      client.release();
    }
  }
}
```

### Migration CLI Commands

```typescript
// src/database/cli.ts
import { Command } from 'commander';
import { createPool } from './pool';
import { Migrator } from './migrator';
import { Seeder } from './seeder';

const program = new Command();

program
  .name('db')
  .description('Database management CLI');

program
  .command('migrate')
  .description('Run pending migrations')
  .action(async () => {
    const pool = createPool();
    const migrator = new Migrator(pool);
    await migrator.migrate();
    await pool.end();
  });

program
  .command('rollback')
  .description('Rollback migrations')
  .option('-s, --steps <number>', 'Number of migrations to rollback', '1')
  .action(async (options) => {
    const pool = createPool();
    const migrator = new Migrator(pool);
    await migrator.rollback(parseInt(options.steps));
    await pool.end();
  });

program
  .command('seed')
  .description('Seed the database')
  .option('-e, --env <environment>', 'Environment to seed', 'development')
  .action(async (options) => {
    const pool = createPool();
    const seeder = new Seeder(pool);
    await seeder.seed(options.env);
    await pool.end();
  });

program
  .command('reset')
  .description('Reset database (drop all tables and re-migrate)')
  .action(async () => {
    const pool = createPool();
    // Drop all tables
    await pool.query(`
      DROP SCHEMA public CASCADE;
      CREATE SCHEMA public;
      GRANT ALL ON SCHEMA public TO public;
    `);
    const migrator = new Migrator(pool);
    await migrator.migrate();
    await pool.end();
  });

program.parse();
```

## Connection Pool Configuration

```typescript
// src/database/pool.ts
import { Pool, PoolConfig, PoolClient } from 'pg';
import { config } from '../config';
import { logger } from '../utils/logger';

const poolConfig: PoolConfig = {
  connectionString: config.DATABASE_URL,

  // Pool size tuning for mobile backend
  min: config.DATABASE_POOL_MIN, // Minimum connections
  max: config.DATABASE_POOL_MAX, // Maximum connections

  // Connection timeouts
  idleTimeoutMillis: 30000, // Close idle connections after 30s
  connectionTimeoutMillis: 10000, // Timeout for new connections

  // SSL configuration
  ssl: config.DATABASE_SSL ? {
    rejectUnauthorized: config.NODE_ENV === 'production',
  } : false,

  // Statement timeout
  statement_timeout: 30000, // 30 second query timeout

  // Application name for monitoring
  application_name: `mobile-backend-${config.NODE_ENV}`,
};

let pool: Pool | null = null;

export function createPool(): Pool {
  if (pool) return pool;

  pool = new Pool(poolConfig);

  // Pool event handlers
  pool.on('connect', (client) => {
    logger.debug('New database connection established');

    // Set session-level configurations
    client.query("SET timezone = 'UTC'");
  });

  pool.on('error', (err) => {
    logger.error('Unexpected database pool error', err);
  });

  pool.on('remove', () => {
    logger.debug('Database connection removed from pool');
  });

  return pool;
}

export function getPool(): Pool {
  if (!pool) {
    throw new Error('Database pool not initialized');
  }
  return pool;
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}

// Transaction helper
export async function withTransaction<T>(
  callback: (client: PoolClient) => Promise<T>
): Promise<T> {
  const pool = getPool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

// Query with automatic connection management
export async function query<T extends Record<string, unknown>>(
  text: string,
  params?: unknown[]
): Promise<T[]> {
  const pool = getPool();
  const start = Date.now();

  try {
    const result = await pool.query<T>(text, params);
    const duration = Date.now() - start;

    // Log slow queries
    if (duration > 100) {
      logger.warn('Slow query detected', {
        query: text.substring(0, 200),
        duration,
        rows: result.rowCount,
      });
    }

    return result.rows;
  } catch (error) {
    logger.error('Query error', {
      query: text.substring(0, 200),
      error: error.message,
    });
    throw error;
  }
}
```

## Query Builder and Repository Pattern

```typescript
// src/database/repositories/BaseRepository.ts
import { Pool, PoolClient } from 'pg';
import { getPool } from '../pool';

export interface QueryOptions {
  client?: PoolClient;
  forUpdate?: boolean;
}

export interface PaginationOptions {
  cursor?: string;
  limit: number;
  orderBy?: string;
  orderDirection?: 'ASC' | 'DESC';
}

export interface SyncOptions {
  since?: Date;
  includeDeleted?: boolean;
  limit: number;
}

export abstract class BaseRepository<T extends { id: string }> {
  protected pool: Pool;
  protected tableName: string;

  constructor(tableName: string) {
    this.pool = getPool();
    this.tableName = tableName;
  }

  protected getClient(options?: QueryOptions): Pool | PoolClient {
    return options?.client || this.pool;
  }

  async findById(id: string, options?: QueryOptions): Promise<T | null> {
    const client = this.getClient(options);
    const forUpdate = options?.forUpdate ? 'FOR UPDATE' : '';

    const result = await client.query<T>(
      `SELECT * FROM ${this.tableName} WHERE id = $1 AND deleted_at IS NULL ${forUpdate}`,
      [id]
    );

    return result.rows[0] || null;
  }

  async findByIds(ids: string[], options?: QueryOptions): Promise<T[]> {
    if (ids.length === 0) return [];

    const client = this.getClient(options);
    const placeholders = ids.map((_, i) => `$${i + 1}`).join(', ');

    const result = await client.query<T>(
      `SELECT * FROM ${this.tableName} WHERE id IN (${placeholders}) AND deleted_at IS NULL`,
      ids
    );

    return result.rows;
  }

  async create(data: Omit<T, 'id' | 'created_at' | 'updated_at'>, options?: QueryOptions): Promise<T> {
    const client = this.getClient(options);
    const keys = Object.keys(data);
    const values = Object.values(data);
    const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');

    const result = await client.query<T>(
      `INSERT INTO ${this.tableName} (${keys.join(', ')})
       VALUES (${placeholders})
       RETURNING *`,
      values
    );

    return result.rows[0];
  }

  async update(id: string, data: Partial<T>, options?: QueryOptions): Promise<T | null> {
    const client = this.getClient(options);
    const keys = Object.keys(data);
    const values = Object.values(data);
    const setClause = keys.map((key, i) => `${key} = $${i + 2}`).join(', ');

    const result = await client.query<T>(
      `UPDATE ${this.tableName}
       SET ${setClause}, updated_at = NOW(), version = version + 1
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING *`,
      [id, ...values]
    );

    return result.rows[0] || null;
  }

  async softDelete(id: string, options?: QueryOptions): Promise<boolean> {
    const client = this.getClient(options);

    const result = await client.query(
      `UPDATE ${this.tableName} SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );

    // Track deletion for sync
    if (result.rowCount > 0) {
      await client.query(
        `INSERT INTO ${this.tableName}_deleted (${this.tableName.slice(0, -1)}_id, user_id)
         SELECT id, user_id FROM ${this.tableName} WHERE id = $1`,
        [id]
      );
    }

    return result.rowCount > 0;
  }

  async findWithCursor(options: PaginationOptions): Promise<{ items: T[]; nextCursor: string | null }> {
    const { cursor, limit, orderBy = 'created_at', orderDirection = 'DESC' } = options;
    const client = this.pool;

    let query = `SELECT * FROM ${this.tableName} WHERE deleted_at IS NULL`;
    const params: unknown[] = [];

    if (cursor) {
      const decodedCursor = this.decodeCursor(cursor);
      const operator = orderDirection === 'DESC' ? '<' : '>';
      query += ` AND (${orderBy}, id) ${operator} ($${params.length + 1}, $${params.length + 2})`;
      params.push(decodedCursor.value, decodedCursor.id);
    }

    query += ` ORDER BY ${orderBy} ${orderDirection}, id ${orderDirection} LIMIT $${params.length + 1}`;
    params.push(limit + 1);

    const result = await client.query<T>(query, params);
    const hasMore = result.rows.length > limit;
    const items = hasMore ? result.rows.slice(0, -1) : result.rows;

    const lastItem = items[items.length - 1];
    const nextCursor = hasMore && lastItem
      ? this.encodeCursor({ value: (lastItem as any)[orderBy], id: lastItem.id })
      : null;

    return { items, nextCursor };
  }

  async findChangedSince(userId: string, options: SyncOptions): Promise<{ items: T[]; hasMore: boolean }> {
    const { since, includeDeleted = true, limit } = options;
    const client = this.pool;

    let query = `
      SELECT * FROM ${this.tableName}
      WHERE user_id = $1
    `;
    const params: unknown[] = [userId];

    if (since) {
      query += ` AND updated_at > $${params.length + 1}`;
      params.push(since);
    }

    if (!includeDeleted) {
      query += ` AND deleted_at IS NULL`;
    }

    query += ` ORDER BY updated_at ASC LIMIT $${params.length + 1}`;
    params.push(limit + 1);

    const result = await client.query<T>(query, params);
    const hasMore = result.rows.length > limit;
    const items = hasMore ? result.rows.slice(0, -1) : result.rows;

    return { items, hasMore };
  }

  protected encodeCursor(data: { value: unknown; id: string }): string {
    return Buffer.from(JSON.stringify(data)).toString('base64url');
  }

  protected decodeCursor(cursor: string): { value: unknown; id: string } {
    return JSON.parse(Buffer.from(cursor, 'base64url').toString());
  }
}

// src/database/repositories/UserRepository.ts
import { BaseRepository } from './BaseRepository';

interface User {
  id: string;
  email: string;
  phone: string | null;
  first_name: string | null;
  last_name: string | null;
  display_name: string | null;
  avatar_url: string | null;
  status: 'pending' | 'active' | 'suspended' | 'deleted';
  version: number;
  created_at: Date;
  updated_at: Date;
  deleted_at: Date | null;
}

export class UserRepository extends BaseRepository<User> {
  constructor() {
    super('users');
  }

  async findByEmail(email: string): Promise<User | null> {
    const result = await this.pool.query<User>(
      'SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL',
      [email.toLowerCase()]
    );
    return result.rows[0] || null;
  }

  async findByPhone(phone: string): Promise<User | null> {
    const result = await this.pool.query<User>(
      'SELECT * FROM users WHERE phone = $1 AND deleted_at IS NULL',
      [phone]
    );
    return result.rows[0] || null;
  }

  async updateLastActive(userId: string): Promise<void> {
    await this.pool.query(
      'UPDATE users SET last_active_at = NOW() WHERE id = $1',
      [userId]
    );
  }

  async searchUsers(query: string, limit: number = 20): Promise<User[]> {
    const result = await this.pool.query<User>(
      `SELECT * FROM users
       WHERE deleted_at IS NULL
       AND (
         display_name ILIKE $1
         OR first_name ILIKE $1
         OR last_name ILIKE $1
         OR email ILIKE $1
       )
       ORDER BY
         CASE WHEN display_name ILIKE $2 THEN 0 ELSE 1 END,
         display_name
       LIMIT $3`,
      [`%${query}%`, `${query}%`, limit]
    );
    return result.rows;
  }
}
```

## Query Optimization for Mobile

```typescript
// src/database/queries/optimized.ts
import { getPool } from '../pool';

// Batch loading to prevent N+1 queries
export async function loadPostsWithAuthors(postIds: string[]) {
  if (postIds.length === 0) return [];

  const pool = getPool();
  const placeholders = postIds.map((_, i) => `$${i + 1}`).join(', ');

  const result = await pool.query(`
    SELECT
      p.*,
      json_build_object(
        'id', u.id,
        'display_name', u.display_name,
        'avatar_url', u.avatar_url
      ) as author
    FROM posts p
    JOIN users u ON p.user_id = u.id
    WHERE p.id IN (${placeholders})
    AND p.deleted_at IS NULL
  `, postIds);

  return result.rows;
}

// Efficient feed query with denormalized data
export async function getFeedPosts(
  userId: string,
  cursor: { timestamp: Date; id: string } | null,
  limit: number
) {
  const pool = getPool();

  let query = `
    WITH followed_users AS (
      SELECT following_id FROM follows WHERE follower_id = $1
    )
    SELECT
      p.id,
      p.title,
      p.body,
      p.media_urls,
      p.likes_count,
      p.comments_count,
      p.created_at,
      json_build_object(
        'id', u.id,
        'display_name', u.display_name,
        'avatar_url', u.avatar_url
      ) as author,
      EXISTS(
        SELECT 1 FROM likes l
        WHERE l.likeable_type = 'post'
        AND l.likeable_id = p.id
        AND l.user_id = $1
      ) as is_liked
    FROM posts p
    JOIN users u ON p.user_id = u.id
    WHERE p.deleted_at IS NULL
    AND (p.user_id = $1 OR p.user_id IN (SELECT following_id FROM followed_users))
  `;

  const params: unknown[] = [userId];

  if (cursor) {
    query += ` AND (p.created_at, p.id) < ($${params.length + 1}, $${params.length + 2})`;
    params.push(cursor.timestamp, cursor.id);
  }

  query += ` ORDER BY p.created_at DESC, p.id DESC LIMIT $${params.length + 1}`;
  params.push(limit + 1);

  const result = await pool.query(query, params);

  const hasMore = result.rows.length > limit;
  const posts = hasMore ? result.rows.slice(0, -1) : result.rows;

  return { posts, hasMore };
}

// Optimized sync query
export async function getChangesForSync(
  userId: string,
  resources: string[],
  since: Date,
  limit: number
) {
  const pool = getPool();
  const changes: Record<string, unknown[]> = {};
  const deletions: Record<string, string[]> = {};

  for (const resource of resources) {
    // Get changes
    const changesResult = await pool.query(`
      SELECT * FROM ${resource}
      WHERE user_id = $1
      AND updated_at > $2
      ORDER BY updated_at ASC
      LIMIT $3
    `, [userId, since, limit]);

    changes[resource] = changesResult.rows;

    // Get deletions
    const deletionsResult = await pool.query(`
      SELECT resource_id FROM ${resource}_deleted
      WHERE user_id = $1
      AND deleted_at > $2
    `, [userId, since]);

    deletions[resource] = deletionsResult.rows.map(r => r.resource_id);
  }

  return { changes, deletions };
}
```

## Database Indexing Strategy

```sql
-- migrations/004_add_performance_indexes.sql
-- Up Migration

-- Partial indexes for common filters
CREATE INDEX CONCURRENTLY idx_posts_public_feed
ON posts(created_at DESC, id DESC)
WHERE deleted_at IS NULL AND visibility = 'public';

-- Covering indexes to avoid table lookups
CREATE INDEX CONCURRENTLY idx_posts_user_feed_covering
ON posts(user_id, created_at DESC)
INCLUDE (id, title, likes_count, comments_count)
WHERE deleted_at IS NULL;

-- Expression index for case-insensitive search
CREATE INDEX CONCURRENTLY idx_users_email_lower
ON users(LOWER(email));

-- GIN index for JSONB queries
CREATE INDEX CONCURRENTLY idx_posts_media_urls
ON posts USING GIN (media_urls);

-- BRIN index for time-series data (very efficient for append-only tables)
CREATE INDEX CONCURRENTLY idx_notifications_created_brin
ON notifications USING BRIN (created_at);

-- Index for sync queries
CREATE INDEX CONCURRENTLY idx_posts_sync_compound
ON posts(user_id, updated_at, version)
WHERE deleted_at IS NULL;

-- Analyze tables to update statistics
ANALYZE users;
ANALYZE posts;
ANALYZE comments;
ANALYZE notifications;

-- Down Migration
DROP INDEX CONCURRENTLY IF EXISTS idx_posts_public_feed;
DROP INDEX CONCURRENTLY IF EXISTS idx_posts_user_feed_covering;
DROP INDEX CONCURRENTLY IF EXISTS idx_users_email_lower;
DROP INDEX CONCURRENTLY IF EXISTS idx_posts_media_urls;
DROP INDEX CONCURRENTLY IF EXISTS idx_notifications_created_brin;
DROP INDEX CONCURRENTLY IF EXISTS idx_posts_sync_compound;
```

## Database Health Monitoring

```typescript
// src/database/health.ts
import { getPool } from './pool';

interface DatabaseHealth {
  status: 'healthy' | 'degraded' | 'unhealthy';
  latency: number;
  connections: {
    total: number;
    idle: number;
    waiting: number;
  };
  replication?: {
    lag: number;
    status: string;
  };
}

export async function checkDatabaseHealth(): Promise<DatabaseHealth> {
  const pool = getPool();
  const start = Date.now();

  try {
    // Basic connectivity check
    await pool.query('SELECT 1');
    const latency = Date.now() - start;

    // Get connection stats
    const poolStats = {
      total: pool.totalCount,
      idle: pool.idleCount,
      waiting: pool.waitingCount,
    };

    // Check replication lag (if applicable)
    let replication;
    try {
      const replicationResult = await pool.query(`
        SELECT
          CASE
            WHEN pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn() THEN 0
            ELSE EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp())
          END AS lag_seconds
      `);

      if (replicationResult.rows[0]) {
        replication = {
          lag: replicationResult.rows[0].lag_seconds || 0,
          status: replicationResult.rows[0].lag_seconds > 10 ? 'lagging' : 'ok',
        };
      }
    } catch {
      // Not a replica or replication not configured
    }

    // Determine overall status
    let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';

    if (latency > 100) status = 'degraded';
    if (poolStats.waiting > 5) status = 'degraded';
    if (replication && replication.lag > 30) status = 'degraded';
    if (latency > 1000) status = 'unhealthy';

    return {
      status,
      latency,
      connections: poolStats,
      replication,
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      latency: Date.now() - start,
      connections: {
        total: pool.totalCount,
        idle: pool.idleCount,
        waiting: pool.waitingCount,
      },
    };
  }
}
```

## Gate Criteria

Before marking database implementation complete, verify:

### Schema Gates
- [ ] All tables have appropriate primary keys
- [ ] Foreign key relationships are properly defined
- [ ] Soft delete columns added for sync-required tables
- [ ] Version columns added for optimistic locking
- [ ] Timestamps (created_at, updated_at) on all tables

### Migration Gates
- [ ] All migrations have up and down scripts
- [ ] Migrations are idempotent (can run multiple times safely)
- [ ] Migration naming follows convention (001_description.sql)
- [ ] Rollback tested for all migrations
- [ ] Production migration tested on staging first

### Performance Gates
- [ ] Indexes created for all foreign keys
- [ ] Indexes created for common query patterns
- [ ] Query execution plans reviewed for critical queries
- [ ] Connection pool sized appropriately
- [ ] Slow query logging enabled

### Mobile-Specific Gates
- [ ] Delta sync queries optimized
- [ ] Deleted records tracked for sync
- [ ] Cursor-based pagination implemented
- [ ] Batch loading patterns implemented
- [ ] Denormalized counters where appropriate

### Security Gates
- [ ] Sensitive data encrypted at rest
- [ ] Database user has minimal required permissions
- [ ] SSL connections enforced in production
- [ ] PII columns identified and documented
- [ ] Audit logging implemented for sensitive tables

### Operational Gates
- [ ] Backup strategy documented and tested
- [ ] Point-in-time recovery tested
- [ ] Monitoring queries configured
- [ ] Alert thresholds defined
- [ ] Database documentation complete
