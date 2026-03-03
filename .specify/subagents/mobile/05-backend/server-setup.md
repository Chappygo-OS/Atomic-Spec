---
name: Mobile Backend Server Setup
platform: mobile
description: Server setup and configuration for mobile backends including infrastructure provisioning, environment configuration, deployment pipelines, and production-ready server architecture
model: opus
category: mobile/backend
---

# Mobile Backend Server Setup Subagent

## Purpose

This subagent handles all aspects of server setup and configuration specifically optimized for mobile backend services. Mobile backends have unique requirements including low-latency API responses, efficient connection handling for intermittent connectivity, and scalable architecture to handle variable load patterns from mobile clients.

## Core Responsibilities

1. Infrastructure provisioning and configuration
2. Environment setup (development, staging, production)
3. Deployment pipeline configuration
4. SSL/TLS certificate management
5. Load balancer configuration
6. Container orchestration setup
7. Monitoring and logging infrastructure
8. Auto-scaling configuration

## Server Architecture Patterns

### Pattern 1: Containerized Microservices (Recommended)

```yaml
# docker-compose.yml - Development Environment
version: '3.8'

services:
  api-gateway:
    build: ./gateway
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - redis
      - postgres
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  auth-service:
    build: ./services/auth
    ports:
      - "3001:3001"
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/auth_db
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis

  user-service:
    build: ./services/user
    ports:
      - "3002:3002"
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/user_db
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis

  notification-service:
    build: ./services/notification
    ports:
      - "3003:3003"
    environment:
      - REDIS_URL=redis://redis:6379
      - FCM_SERVER_KEY=${FCM_SERVER_KEY}
      - APNS_KEY_ID=${APNS_KEY_ID}
    depends_on:
      - redis

  postgres:
    image: postgres:15-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
      - POSTGRES_MULTIPLE_DATABASES=auth_db,user_db,main_db

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - api-gateway

volumes:
  postgres_data:
  redis_data:
```

### Pattern 2: Serverless Architecture

```typescript
// serverless.yml - AWS Lambda Configuration
service: mobile-backend-api

provider:
  name: aws
  runtime: nodejs18.x
  stage: ${opt:stage, 'dev'}
  region: ${opt:region, 'us-east-1'}
  memorySize: 512
  timeout: 29

  environment:
    STAGE: ${self:provider.stage}
    DATABASE_URL: ${ssm:/mobile-backend/${self:provider.stage}/database-url}
    JWT_SECRET: ${ssm:/mobile-backend/${self:provider.stage}/jwt-secret~true}
    REDIS_URL: ${ssm:/mobile-backend/${self:provider.stage}/redis-url}

  vpc:
    securityGroupIds:
      - ${ssm:/mobile-backend/${self:provider.stage}/security-group-id}
    subnetIds:
      - ${ssm:/mobile-backend/${self:provider.stage}/subnet-1}
      - ${ssm:/mobile-backend/${self:provider.stage}/subnet-2}

  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:Query
            - dynamodb:Scan
            - dynamodb:GetItem
            - dynamodb:PutItem
            - dynamodb:UpdateItem
            - dynamodb:DeleteItem
          Resource:
            - arn:aws:dynamodb:${self:provider.region}:*:table/${self:service}-${self:provider.stage}-*
        - Effect: Allow
          Action:
            - s3:GetObject
            - s3:PutObject
            - s3:DeleteObject
          Resource:
            - arn:aws:s3:::${self:service}-${self:provider.stage}-uploads/*
        - Effect: Allow
          Action:
            - sns:Publish
          Resource:
            - arn:aws:sns:${self:provider.region}:*:${self:service}-${self:provider.stage}-*

functions:
  api:
    handler: dist/handler.main
    events:
      - http:
          path: /{proxy+}
          method: ANY
          cors:
            origin: '*'
            headers:
              - Content-Type
              - Authorization
              - X-Api-Key
              - X-Device-Id
              - X-App-Version
            allowCredentials: true

  authorizer:
    handler: dist/authorizer.handler
    memorySize: 256

  warmup:
    handler: dist/warmup.handler
    events:
      - schedule: rate(5 minutes)
    memorySize: 128

plugins:
  - serverless-offline
  - serverless-plugin-warmup
  - serverless-domain-manager

custom:
  customDomain:
    domainName: api.${self:provider.stage}.example.com
    basePath: ''
    stage: ${self:provider.stage}
    certificateName: '*.example.com'
    createRoute53Record: true
```

## Environment Configuration

### Configuration Management

```typescript
// src/config/index.ts
import { z } from 'zod';
import dotenv from 'dotenv';

// Load environment-specific .env file
const envFile = `.env.${process.env.NODE_ENV || 'development'}`;
dotenv.config({ path: envFile });

// Configuration schema with validation
const ConfigSchema = z.object({
  // Server
  NODE_ENV: z.enum(['development', 'staging', 'production']).default('development'),
  PORT: z.string().transform(Number).default('3000'),
  HOST: z.string().default('0.0.0.0'),

  // Database
  DATABASE_URL: z.string().url(),
  DATABASE_POOL_MIN: z.string().transform(Number).default('2'),
  DATABASE_POOL_MAX: z.string().transform(Number).default('10'),
  DATABASE_SSL: z.string().transform(v => v === 'true').default('false'),

  // Redis
  REDIS_URL: z.string().url(),
  REDIS_CLUSTER_MODE: z.string().transform(v => v === 'true').default('false'),

  // Authentication
  JWT_SECRET: z.string().min(32),
  JWT_ACCESS_EXPIRY: z.string().default('15m'),
  JWT_REFRESH_EXPIRY: z.string().default('7d'),

  // Mobile Push Notifications
  FCM_SERVER_KEY: z.string().optional(),
  APNS_KEY_ID: z.string().optional(),
  APNS_TEAM_ID: z.string().optional(),
  APNS_KEY_PATH: z.string().optional(),
  APNS_BUNDLE_ID: z.string().optional(),

  // AWS (if using)
  AWS_REGION: z.string().default('us-east-1'),
  AWS_ACCESS_KEY_ID: z.string().optional(),
  AWS_SECRET_ACCESS_KEY: z.string().optional(),
  S3_BUCKET: z.string().optional(),

  // External Services
  SENTRY_DSN: z.string().optional(),
  DATADOG_API_KEY: z.string().optional(),

  // Rate Limiting
  RATE_LIMIT_WINDOW_MS: z.string().transform(Number).default('60000'),
  RATE_LIMIT_MAX_REQUESTS: z.string().transform(Number).default('100'),

  // CORS
  CORS_ORIGINS: z.string().transform(s => s.split(',')).default('*'),

  // Feature Flags
  ENABLE_API_DOCS: z.string().transform(v => v === 'true').default('true'),
  ENABLE_REQUEST_LOGGING: z.string().transform(v => v === 'true').default('true'),
});

// Validate and export configuration
function loadConfig() {
  try {
    const config = ConfigSchema.parse(process.env);
    return config;
  } catch (error) {
    if (error instanceof z.ZodError) {
      const missingVars = error.errors.map(e => e.path.join('.'));
      console.error('Configuration validation failed:');
      console.error('Missing or invalid environment variables:', missingVars);
      process.exit(1);
    }
    throw error;
  }
}

export const config = loadConfig();

// Type export for use throughout the application
export type Config = z.infer<typeof ConfigSchema>;
```

### Nginx Configuration for Mobile APIs

```nginx
# nginx/nginx.conf
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 65535;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format mobile_json escape=json
    '{'
        '"time_local":"$time_local",'
        '"remote_addr":"$remote_addr",'
        '"request":"$request",'
        '"status": "$status",'
        '"body_bytes_sent":"$body_bytes_sent",'
        '"request_time":"$request_time",'
        '"upstream_response_time":"$upstream_response_time",'
        '"http_referrer":"$http_referer",'
        '"http_user_agent":"$http_user_agent",'
        '"http_x_device_id":"$http_x_device_id",'
        '"http_x_app_version":"$http_x_app_version",'
        '"http_x_platform":"$http_x_platform"'
    '}';

    access_log /var/log/nginx/access.log mobile_json;
    error_log /var/log/nginx/error.log;

    # Gzip Settings - Optimize for mobile
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 256;
    gzip_types
        application/json
        application/javascript
        application/xml
        application/xml+rss
        text/css
        text/javascript
        text/plain
        text/xml;

    # Rate Limiting Zones
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/s;
    limit_req_zone $http_x_device_id zone=device_limit:10m rate=50r/s;
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

    # Connection limits
    limit_conn conn_limit 20;

    # Upstream API servers
    upstream api_servers {
        least_conn;
        server api-gateway:3000 weight=5;
        keepalive 32;
    }

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;

    server {
        listen 80;
        server_name api.example.com;

        # Redirect HTTP to HTTPS
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name api.example.com;

        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;

        # Security Headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # API versioning via path
        location /api/v1/ {
            limit_req zone=api_limit burst=50 nodelay;
            limit_req zone=device_limit burst=20 nodelay;

            proxy_pass http://api_servers/;
            proxy_http_version 1.1;

            # Connection handling for mobile
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Pass mobile-specific headers
            proxy_set_header X-Device-Id $http_x_device_id;
            proxy_set_header X-App-Version $http_x_app_version;
            proxy_set_header X-Platform $http_x_platform;

            # Timeouts optimized for mobile
            proxy_connect_timeout 10s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;

            # Buffering
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
        }

        # Health check endpoint (no rate limiting)
        location /health {
            proxy_pass http://api_servers/health;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        # Static files (if any)
        location /static/ {
            alias /var/www/static/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

## Deployment Pipeline

### GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy Mobile Backend

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: mobile-backend
  ECS_SERVICE: mobile-backend-service
  ECS_CLUSTER: mobile-backend-cluster

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_db
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linting
        run: npm run lint

      - name: Run type checking
        run: npm run typecheck

      - name: Run unit tests
        run: npm run test:unit
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/test_db
          REDIS_URL: redis://localhost:6379
          JWT_SECRET: test-secret-minimum-32-characters-long

      - name: Run integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/test_db
          REDIS_URL: redis://localhost:6379
          JWT_SECRET: test-secret-minimum-32-characters-long

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          token: ${{ secrets.CODECOV_TOKEN }}

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push'

    outputs:
      image_tag: ${{ steps.build-image.outputs.image_tag }}

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:latest .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
          echo "image_tag=$IMAGE_TAG" >> $GITHUB_OUTPUT

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/staging'
    environment: staging

    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Deploy to ECS Staging
        run: |
          aws ecs update-service \
            --cluster ${{ env.ECS_CLUSTER }}-staging \
            --service ${{ env.ECS_SERVICE }} \
            --force-new-deployment

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster ${{ env.ECS_CLUSTER }}-staging \
            --services ${{ env.ECS_SERVICE }}

      - name: Run smoke tests
        run: |
          curl -f https://api.staging.example.com/health || exit 1

  deploy-production:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production

    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Deploy to ECS Production (Blue/Green)
        run: |
          aws deploy create-deployment \
            --application-name mobile-backend \
            --deployment-group-name production \
            --revision '{"revisionType":"AppSpecContent","appSpecContent":{"content":"{\"version\":1,\"Resources\":[{\"TargetService\":{\"Type\":\"AWS::ECS::Service\",\"Properties\":{\"TaskDefinition\":\"arn:aws:ecs:${{ env.AWS_REGION }}:${{ secrets.AWS_ACCOUNT_ID }}:task-definition/mobile-backend:${{ needs.build.outputs.image_tag }}\",\"LoadBalancerInfo\":{\"ContainerName\":\"api\",\"ContainerPort\":3000}}}}]}"}}'

      - name: Notify deployment
        uses: slackapi/slack-github-action@v1.24.0
        with:
          payload: |
            {
              "text": "Production deployment completed for mobile-backend",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Production Deployment Successful*\nImage: `${{ needs.build.outputs.image_tag }}`"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Infrastructure as Code (Terraform)

```hcl
# infrastructure/main.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "mobile-backend-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "mobile-backend"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Variables
variable "environment" {
  type        = string
  description = "Environment name (staging, production)"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "app_name" {
  type    = string
  default = "mobile-backend"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.app_name}-${var.environment}"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = var.environment == "staging"
  enable_dns_hostnames   = true
  enable_dns_support     = true

  tags = {
    Environment = var.environment
  }
}

# RDS PostgreSQL
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.app_name}-${var.environment}"

  engine               = "postgres"
  engine_version       = "15.4"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = var.environment == "production" ? "db.r6g.large" : "db.t3.medium"

  allocated_storage     = 100
  max_allocated_storage = 500

  db_name  = "mobile_backend"
  username = "admin"
  port     = 5432

  multi_az               = var.environment == "production"
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = var.environment == "production" ? 30 : 7

  performance_insights_enabled = true
  deletion_protection          = var.environment == "production"

  parameters = [
    {
      name  = "log_statement"
      value = "all"
    },
    {
      name  = "log_min_duration_statement"
      value = "1000"
    }
  ]
}

# ElastiCache Redis
module "elasticache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.0"

  cluster_id           = "${var.app_name}-${var.environment}"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.environment == "production" ? "cache.r6g.large" : "cache.t3.medium"
  num_cache_nodes      = var.environment == "production" ? 3 : 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  snapshot_retention_limit = var.environment == "production" ? 7 : 1
  snapshot_window          = "05:00-09:00"
  maintenance_window       = "mon:10:00-mon:14:00"

  automatic_failover_enabled = var.environment == "production"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs.name
      }
    }
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.app_name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.environment == "production" ? 1024 : 512
  memory                   = var.environment == "production" ? 2048 : 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "api"
      image = "${aws_ecr_repository.main.repository_url}:latest"

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "NODE_ENV", value = var.environment },
        { name = "PORT", value = "3000" }
      ]

      secrets = [
        { name = "DATABASE_URL", valueFrom = aws_ssm_parameter.database_url.arn },
        { name = "REDIS_URL", valueFrom = aws_ssm_parameter.redis_url.arn },
        { name = "JWT_SECRET", valueFrom = aws_ssm_parameter.jwt_secret.arn }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "api"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.app_name}-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = var.environment == "production"

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }
}

# Auto Scaling
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.environment == "production" ? 20 : 5
  min_capacity       = var.environment == "production" ? 2 : 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.app_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${var.app_name}-${var.environment}-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "API 5XX errors exceed threshold"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.api.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

## Mobile-Specific Server Considerations

### Connection Handling for Intermittent Connectivity

```typescript
// src/middleware/connectionHandler.ts
import { Request, Response, NextFunction } from 'express';

export interface MobileRequestContext {
  deviceId: string;
  appVersion: string;
  platform: 'ios' | 'android' | 'unknown';
  connectionType: string;
  requestId: string;
}

export function mobileConnectionHandler() {
  return (req: Request, res: Response, next: NextFunction) => {
    // Extract mobile-specific headers
    const context: MobileRequestContext = {
      deviceId: req.headers['x-device-id'] as string || 'unknown',
      appVersion: req.headers['x-app-version'] as string || 'unknown',
      platform: parsePlatform(req.headers['x-platform'] as string),
      connectionType: req.headers['x-connection-type'] as string || 'unknown',
      requestId: req.headers['x-request-id'] as string || generateRequestId(),
    };

    // Attach to request
    req.mobileContext = context;

    // Set response headers for mobile clients
    res.setHeader('X-Request-Id', context.requestId);
    res.setHeader('X-Server-Time', Date.now().toString());

    // Handle slow connections gracefully
    if (context.connectionType === '2g' || context.connectionType === 'slow-2g') {
      req.setTimeout(120000); // Extend timeout for slow connections
      res.setHeader('X-Slow-Connection', 'true');
    }

    // Set cache headers optimized for mobile
    res.setHeader('Cache-Control', 'private, max-age=0, must-revalidate');
    res.setHeader('Vary', 'Accept-Encoding, X-App-Version');

    next();
  };
}

function parsePlatform(platform: string): 'ios' | 'android' | 'unknown' {
  if (platform?.toLowerCase() === 'ios') return 'ios';
  if (platform?.toLowerCase() === 'android') return 'android';
  return 'unknown';
}

function generateRequestId(): string {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}
```

### Health Check Endpoint

```typescript
// src/routes/health.ts
import { Router } from 'express';
import { Pool } from 'pg';
import Redis from 'ioredis';

const router = Router();

interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: string;
  version: string;
  uptime: number;
  checks: {
    database: ComponentHealth;
    redis: ComponentHealth;
    memory: ComponentHealth;
  };
}

interface ComponentHealth {
  status: 'up' | 'down';
  latency?: number;
  message?: string;
}

export function createHealthRouter(db: Pool, redis: Redis) {
  // Simple health check (for load balancers)
  router.get('/health', async (req, res) => {
    res.status(200).json({ status: 'ok' });
  });

  // Detailed health check
  router.get('/health/detailed', async (req, res) => {
    const checks = await Promise.all([
      checkDatabase(db),
      checkRedis(redis),
      checkMemory(),
    ]);

    const [database, redisCheck, memory] = checks;

    const overallStatus = determineOverallStatus(checks);

    const health: HealthStatus = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || 'unknown',
      uptime: process.uptime(),
      checks: {
        database,
        redis: redisCheck,
        memory,
      },
    };

    const statusCode = overallStatus === 'healthy' ? 200 :
                       overallStatus === 'degraded' ? 200 : 503;

    res.status(statusCode).json(health);
  });

  // Readiness probe (for Kubernetes)
  router.get('/health/ready', async (req, res) => {
    try {
      await db.query('SELECT 1');
      await redis.ping();
      res.status(200).json({ ready: true });
    } catch (error) {
      res.status(503).json({ ready: false, error: error.message });
    }
  });

  // Liveness probe (for Kubernetes)
  router.get('/health/live', (req, res) => {
    res.status(200).json({ alive: true });
  });

  return router;
}

async function checkDatabase(db: Pool): Promise<ComponentHealth> {
  const start = Date.now();
  try {
    await db.query('SELECT 1');
    return { status: 'up', latency: Date.now() - start };
  } catch (error) {
    return { status: 'down', message: error.message };
  }
}

async function checkRedis(redis: Redis): Promise<ComponentHealth> {
  const start = Date.now();
  try {
    await redis.ping();
    return { status: 'up', latency: Date.now() - start };
  } catch (error) {
    return { status: 'down', message: error.message };
  }
}

function checkMemory(): ComponentHealth {
  const used = process.memoryUsage();
  const heapUsedPercent = (used.heapUsed / used.heapTotal) * 100;

  if (heapUsedPercent > 90) {
    return { status: 'down', message: `High memory usage: ${heapUsedPercent.toFixed(1)}%` };
  }

  return { status: 'up', message: `Memory usage: ${heapUsedPercent.toFixed(1)}%` };
}

function determineOverallStatus(checks: ComponentHealth[]): 'healthy' | 'degraded' | 'unhealthy' {
  const downCount = checks.filter(c => c.status === 'down').length;
  if (downCount === 0) return 'healthy';
  if (downCount < checks.length) return 'degraded';
  return 'unhealthy';
}
```

## Gate Criteria

Before marking server setup complete, verify:

### Infrastructure Gates
- [ ] All environments (dev, staging, production) are provisioned
- [ ] SSL/TLS certificates are installed and auto-renewing
- [ ] Load balancer is configured with health checks
- [ ] Auto-scaling policies are in place
- [ ] Database backups are configured and tested
- [ ] Redis/cache layer is operational

### Security Gates
- [ ] All secrets are stored in secure parameter store (not in code)
- [ ] Security groups restrict access appropriately
- [ ] WAF rules are configured (if applicable)
- [ ] SSL/TLS configuration passes security scan
- [ ] No default credentials in use

### Deployment Gates
- [ ] CI/CD pipeline runs tests before deployment
- [ ] Blue/green or rolling deployment strategy in place
- [ ] Rollback procedure documented and tested
- [ ] Deployment notifications configured

### Monitoring Gates
- [ ] Health check endpoints respond correctly
- [ ] CloudWatch/monitoring dashboards configured
- [ ] Alert thresholds defined for critical metrics
- [ ] Log aggregation configured
- [ ] APM tool integrated (DataDog, New Relic, etc.)

### Performance Gates
- [ ] Response time under load < 200ms p95
- [ ] Server can handle expected concurrent connections
- [ ] Database connection pooling configured
- [ ] Gzip compression enabled
- [ ] Keep-alive connections configured

### Documentation Gates
- [ ] Infrastructure diagram documented
- [ ] Environment variables documented
- [ ] Deployment process documented
- [ ] Incident response runbook created
- [ ] On-call rotation established (production)
