---
name: Mobile Backend Notification Service
platform: mobile
description: Email and SMS notification service for mobile backends including push notification delivery, email templates, SMS integration, notification preferences, and multi-channel orchestration
model: opus
category: mobile/backend
---

# Mobile Backend Notification Service Subagent

## Purpose

This subagent handles all aspects of notification delivery for mobile backends. Mobile applications require robust multi-channel notification systems including push notifications (FCM/APNs), email, and SMS. The service must handle user preferences, delivery tracking, and graceful degradation.

## Core Responsibilities

1. Push notification delivery (FCM, APNs)
2. Email sending with templates
3. SMS delivery integration
4. Notification preference management
5. Multi-channel orchestration
6. Delivery tracking and analytics
7. Notification scheduling
8. In-app notification management

## Push Notification Service

### Firebase Cloud Messaging (Android) and APNs (iOS)

```typescript
// src/services/pushNotificationService.ts
import admin from 'firebase-admin';
import apn from '@parse/node-apn';
import { db } from '../database';
import { redis } from '../cache/redis';
import { logger } from '../utils/logger';
import { config } from '../config';

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: config.FIREBASE_PROJECT_ID,
    clientEmail: config.FIREBASE_CLIENT_EMAIL,
    privateKey: config.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  }),
});

// Initialize APNs
const apnProvider = new apn.Provider({
  token: {
    key: config.APNS_KEY_PATH,
    keyId: config.APNS_KEY_ID,
    teamId: config.APNS_TEAM_ID,
  },
  production: config.NODE_ENV === 'production',
});

interface PushNotification {
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
  badge?: number;
  sound?: string;
  channelId?: string;  // Android notification channel
  category?: string;   // iOS notification category
  threadId?: string;   // iOS thread identifier
  collapseKey?: string;
  priority?: 'high' | 'normal';
  ttl?: number;        // Time to live in seconds
}

interface DeliveryResult {
  success: boolean;
  messageId?: string;
  error?: string;
  errorCode?: string;
}

export class PushNotificationService {
  // Send to a specific device
  async sendToDevice(
    token: string,
    tokenType: 'fcm' | 'apns',
    notification: PushNotification,
    options?: { priority?: 'high' | 'normal'; ttl?: number }
  ): Promise<DeliveryResult> {
    try {
      if (tokenType === 'fcm') {
        return this.sendFCM(token, notification, options);
      } else {
        return this.sendAPNs(token, notification, options);
      }
    } catch (error) {
      logger.error('Push notification failed', {
        tokenType,
        error: error.message,
      });

      return {
        success: false,
        error: error.message,
        errorCode: this.categorizeError(error),
      };
    }
  }

  // Send to user (all their devices)
  async sendToUser(
    userId: string,
    notification: PushNotification,
    options?: { priority?: 'high' | 'normal'; ttl?: number }
  ): Promise<{ sent: number; failed: number }> {
    const devices = await db('user_devices')
      .where('user_id', userId)
      .where('push_enabled', true)
      .whereNotNull('push_token');

    let sent = 0;
    let failed = 0;

    for (const device of devices) {
      const result = await this.sendToDevice(
        device.push_token,
        device.push_token_type,
        notification,
        options
      );

      if (result.success) {
        sent++;
      } else {
        failed++;

        // Handle invalid tokens
        if (result.errorCode === 'InvalidToken') {
          await this.invalidateToken(device.id);
        }
      }
    }

    return { sent, failed };
  }

  // Send to multiple users
  async sendToUsers(
    userIds: string[],
    notification: PushNotification,
    options?: { priority?: 'high' | 'normal'; ttl?: number }
  ): Promise<{ totalSent: number; totalFailed: number }> {
    // Get all device tokens for these users
    const devices = await db('user_devices')
      .whereIn('user_id', userIds)
      .where('push_enabled', true)
      .whereNotNull('push_token');

    // Group by token type for batch sending
    const fcmTokens: string[] = [];
    const apnsTokens: string[] = [];
    const tokenToDevice: Record<string, string> = {};

    for (const device of devices) {
      if (device.push_token_type === 'fcm') {
        fcmTokens.push(device.push_token);
      } else {
        apnsTokens.push(device.push_token);
      }
      tokenToDevice[device.push_token] = device.id;
    }

    let totalSent = 0;
    let totalFailed = 0;

    // Send to FCM in batches
    if (fcmTokens.length > 0) {
      const fcmResults = await this.sendFCMBatch(fcmTokens, notification, options);
      totalSent += fcmResults.successCount;
      totalFailed += fcmResults.failureCount;

      // Handle invalid tokens
      for (const failedToken of fcmResults.invalidTokens) {
        await this.invalidateToken(tokenToDevice[failedToken]);
      }
    }

    // Send to APNs in batches
    if (apnsTokens.length > 0) {
      const apnsResults = await this.sendAPNsBatch(apnsTokens, notification, options);
      totalSent += apnsResults.successCount;
      totalFailed += apnsResults.failureCount;

      // Handle invalid tokens
      for (const failedToken of apnsResults.invalidTokens) {
        await this.invalidateToken(tokenToDevice[failedToken]);
      }
    }

    return { totalSent, totalFailed };
  }

  // Send silent push (for background data sync)
  async sendSilentPush(token: string): Promise<void> {
    // Determine token type (simplified - in production, lookup from DB)
    if (token.length > 100) {
      // Likely APNs
      const notification = new apn.Notification();
      notification.contentAvailable = true;
      notification.topic = config.APNS_BUNDLE_ID;
      await apnProvider.send(notification, token);
    } else {
      // Likely FCM
      await admin.messaging().send({
        token,
        data: { type: 'silent' },
        android: {
          priority: 'high',
        },
      });
    }
  }

  private async sendFCM(
    token: string,
    notification: PushNotification,
    options?: { priority?: 'high' | 'normal'; ttl?: number }
  ): Promise<DeliveryResult> {
    const message: admin.messaging.Message = {
      token,
      notification: {
        title: notification.title,
        body: notification.body,
        imageUrl: notification.imageUrl,
      },
      data: notification.data,
      android: {
        priority: options?.priority || 'high',
        ttl: (options?.ttl || 86400) * 1000, // Convert to ms
        notification: {
          channelId: notification.channelId || 'default',
          sound: notification.sound || 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        collapseKey: notification.collapseKey,
      },
      apns: {
        headers: {
          'apns-priority': options?.priority === 'high' ? '10' : '5',
          'apns-expiration': String(Math.floor(Date.now() / 1000) + (options?.ttl || 86400)),
        },
        payload: {
          aps: {
            alert: {
              title: notification.title,
              body: notification.body,
            },
            badge: notification.badge,
            sound: notification.sound || 'default',
            category: notification.category,
            threadId: notification.threadId,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);

    return {
      success: true,
      messageId: response,
    };
  }

  private async sendFCMBatch(
    tokens: string[],
    notification: PushNotification,
    options?: { priority?: 'high' | 'normal'; ttl?: number }
  ): Promise<{ successCount: number; failureCount: number; invalidTokens: string[] }> {
    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: notification.title,
        body: notification.body,
        imageUrl: notification.imageUrl,
      },
      data: notification.data,
      android: {
        priority: options?.priority || 'high',
        ttl: (options?.ttl || 86400) * 1000,
        notification: {
          channelId: notification.channelId || 'default',
          sound: notification.sound || 'default',
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    const invalidTokens: string[] = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success && this.isInvalidTokenError(resp.error)) {
        invalidTokens.push(tokens[idx]);
      }
    });

    return {
      successCount: response.successCount,
      failureCount: response.failureCount,
      invalidTokens,
    };
  }

  private async sendAPNs(
    token: string,
    notification: PushNotification,
    options?: { priority?: 'high' | 'normal'; ttl?: number }
  ): Promise<DeliveryResult> {
    const apnNotification = new apn.Notification();

    apnNotification.alert = {
      title: notification.title,
      body: notification.body,
    };
    apnNotification.badge = notification.badge;
    apnNotification.sound = notification.sound || 'default';
    apnNotification.topic = config.APNS_BUNDLE_ID;
    apnNotification.payload = notification.data || {};
    apnNotification.expiry = Math.floor(Date.now() / 1000) + (options?.ttl || 86400);
    apnNotification.priority = options?.priority === 'high' ? 10 : 5;

    if (notification.category) {
      apnNotification.category = notification.category;
    }
    if (notification.threadId) {
      apnNotification.threadId = notification.threadId;
    }
    if (notification.collapseKey) {
      apnNotification.collapseId = notification.collapseKey;
    }

    const result = await apnProvider.send(apnNotification, token);

    if (result.failed.length > 0) {
      return {
        success: false,
        error: result.failed[0].response?.reason,
        errorCode: this.categorizeAPNsError(result.failed[0].response?.reason),
      };
    }

    return {
      success: true,
      messageId: result.sent[0]?.device,
    };
  }

  private async sendAPNsBatch(
    tokens: string[],
    notification: PushNotification,
    options?: { priority?: 'high' | 'normal'; ttl?: number }
  ): Promise<{ successCount: number; failureCount: number; invalidTokens: string[] }> {
    const apnNotification = new apn.Notification();

    apnNotification.alert = {
      title: notification.title,
      body: notification.body,
    };
    apnNotification.badge = notification.badge;
    apnNotification.sound = notification.sound || 'default';
    apnNotification.topic = config.APNS_BUNDLE_ID;
    apnNotification.payload = notification.data || {};

    const result = await apnProvider.send(apnNotification, tokens);

    const invalidTokens = result.failed
      .filter(f => this.isInvalidAPNsToken(f.response?.reason))
      .map(f => f.device);

    return {
      successCount: result.sent.length,
      failureCount: result.failed.length,
      invalidTokens,
    };
  }

  private async invalidateToken(deviceId: string): Promise<void> {
    await db('user_devices')
      .where('id', deviceId)
      .update({
        push_enabled: false,
        push_token: null,
        updated_at: new Date(),
      });
  }

  private isInvalidTokenError(error?: admin.FirebaseError): boolean {
    return error?.code === 'messaging/invalid-registration-token' ||
           error?.code === 'messaging/registration-token-not-registered';
  }

  private isInvalidAPNsToken(reason?: string): boolean {
    return reason === 'BadDeviceToken' ||
           reason === 'Unregistered' ||
           reason === 'ExpiredProviderToken';
  }

  private categorizeError(error: any): string {
    if (this.isInvalidTokenError(error)) return 'InvalidToken';
    if (error.code?.includes('rate')) return 'RateLimited';
    return 'Unknown';
  }

  private categorizeAPNsError(reason?: string): string {
    if (this.isInvalidAPNsToken(reason)) return 'InvalidToken';
    if (reason === 'TooManyRequests') return 'RateLimited';
    return 'Unknown';
  }
}

export const pushNotificationService = new PushNotificationService();
```

### Email Service

```typescript
// src/services/emailService.ts
import nodemailer from 'nodemailer';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';
import Handlebars from 'handlebars';
import mjml2html from 'mjml';
import * as fs from 'fs/promises';
import * as path from 'path';
import { config } from '../config';
import { logger } from '../utils/logger';

interface EmailOptions {
  to: string | string[];
  subject: string;
  template: string;
  data: Record<string, unknown>;
  attachments?: Array<{
    filename: string;
    content: Buffer | string;
    contentType?: string;
  }>;
  replyTo?: string;
  cc?: string[];
  bcc?: string[];
}

interface CompiledTemplate {
  subject: Handlebars.TemplateDelegate;
  html: Handlebars.TemplateDelegate;
  text: Handlebars.TemplateDelegate;
}

export class EmailService {
  private sesClient: SESClient;
  private smtpTransporter: nodemailer.Transporter | null = null;
  private templateCache: Map<string, CompiledTemplate> = new Map();
  private templateDir: string;

  constructor() {
    this.sesClient = new SESClient({
      region: config.AWS_REGION,
      credentials: {
        accessKeyId: config.AWS_ACCESS_KEY_ID!,
        secretAccessKey: config.AWS_SECRET_ACCESS_KEY!,
      },
    });

    // Fallback SMTP for development
    if (config.SMTP_HOST) {
      this.smtpTransporter = nodemailer.createTransport({
        host: config.SMTP_HOST,
        port: config.SMTP_PORT,
        secure: config.SMTP_SECURE,
        auth: {
          user: config.SMTP_USER,
          pass: config.SMTP_PASS,
        },
      });
    }

    this.templateDir = path.join(__dirname, '../templates/email');

    // Register Handlebars helpers
    this.registerHelpers();
  }

  async sendTemplatedEmail(options: EmailOptions): Promise<void> {
    const template = await this.getTemplate(options.template);

    const subject = template.subject(options.data);
    const html = template.html(options.data);
    const text = template.text(options.data);

    await this.sendEmail({
      to: options.to,
      subject,
      html,
      text,
      attachments: options.attachments,
      replyTo: options.replyTo,
      cc: options.cc,
      bcc: options.bcc,
    });
  }

  async sendEmail(options: {
    to: string | string[];
    subject: string;
    html: string;
    text: string;
    attachments?: any[];
    replyTo?: string;
    cc?: string[];
    bcc?: string[];
  }): Promise<void> {
    const recipients = Array.isArray(options.to) ? options.to : [options.to];

    try {
      if (config.NODE_ENV === 'production') {
        // Use AWS SES in production
        await this.sendWithSES(options);
      } else if (this.smtpTransporter) {
        // Use SMTP in development
        await this.sendWithSMTP(options);
      } else {
        // Log email in development without sending
        logger.info('Email would be sent', {
          to: recipients,
          subject: options.subject,
        });
      }

      logger.info('Email sent successfully', {
        to: recipients,
        subject: options.subject,
      });
    } catch (error) {
      logger.error('Failed to send email', {
        to: recipients,
        subject: options.subject,
        error: error.message,
      });
      throw error;
    }
  }

  private async sendWithSES(options: any): Promise<void> {
    const command = new SendEmailCommand({
      Source: config.EMAIL_FROM,
      Destination: {
        ToAddresses: Array.isArray(options.to) ? options.to : [options.to],
        CcAddresses: options.cc,
        BccAddresses: options.bcc,
      },
      Message: {
        Subject: { Data: options.subject },
        Body: {
          Html: { Data: options.html },
          Text: { Data: options.text },
        },
      },
      ReplyToAddresses: options.replyTo ? [options.replyTo] : undefined,
    });

    await this.sesClient.send(command);
  }

  private async sendWithSMTP(options: any): Promise<void> {
    await this.smtpTransporter!.sendMail({
      from: config.EMAIL_FROM,
      to: options.to,
      cc: options.cc,
      bcc: options.bcc,
      subject: options.subject,
      html: options.html,
      text: options.text,
      attachments: options.attachments,
      replyTo: options.replyTo,
    });
  }

  private async getTemplate(templateName: string): Promise<CompiledTemplate> {
    if (this.templateCache.has(templateName)) {
      return this.templateCache.get(templateName)!;
    }

    const templatePath = path.join(this.templateDir, templateName);

    // Load template files
    const [subjectTemplate, mjmlTemplate, textTemplate] = await Promise.all([
      fs.readFile(`${templatePath}/subject.txt`, 'utf-8'),
      fs.readFile(`${templatePath}/template.mjml`, 'utf-8'),
      fs.readFile(`${templatePath}/template.txt`, 'utf-8'),
    ]);

    // Compile MJML to HTML
    const { html: htmlTemplate } = mjml2html(mjmlTemplate);

    const compiled: CompiledTemplate = {
      subject: Handlebars.compile(subjectTemplate.trim()),
      html: Handlebars.compile(htmlTemplate),
      text: Handlebars.compile(textTemplate),
    };

    this.templateCache.set(templateName, compiled);

    return compiled;
  }

  private registerHelpers(): void {
    Handlebars.registerHelper('formatDate', (date: Date | string) => {
      return new Date(date).toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      });
    });

    Handlebars.registerHelper('formatCurrency', (amount: number, currency: string = 'USD') => {
      return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency,
      }).format(amount);
    });

    Handlebars.registerHelper('truncate', (text: string, length: number) => {
      if (text.length <= length) return text;
      return text.substring(0, length) + '...';
    });
  }

  // Convenience methods for common emails
  async sendVerificationEmail(userId: string, email: string): Promise<void> {
    const verificationToken = await tokenService.generateEmailVerificationToken(userId);
    const verificationUrl = `${config.APP_URL}/verify-email?token=${verificationToken}`;

    await this.sendTemplatedEmail({
      to: email,
      subject: 'Verify your email',
      template: 'verification',
      data: {
        verificationUrl,
        appName: config.APP_NAME,
      },
    });
  }

  async sendPasswordResetEmail(email: string, resetToken: string): Promise<void> {
    const resetUrl = `${config.APP_URL}/reset-password?token=${resetToken}`;

    await this.sendTemplatedEmail({
      to: email,
      subject: 'Reset your password',
      template: 'password-reset',
      data: {
        resetUrl,
        appName: config.APP_NAME,
        expiresIn: '1 hour',
      },
    });
  }

  async sendWelcomeEmail(email: string, name: string): Promise<void> {
    await this.sendTemplatedEmail({
      to: email,
      subject: `Welcome to ${config.APP_NAME}!`,
      template: 'welcome',
      data: {
        name,
        appName: config.APP_NAME,
        appUrl: config.APP_URL,
      },
    });
  }
}

export const emailService = new EmailService();
```

### SMS Service

```typescript
// src/services/smsService.ts
import twilio from 'twilio';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { config } from '../config';
import { logger } from '../utils/logger';

interface SMSOptions {
  to: string;
  message: string;
  sender?: string;
}

export class SMSService {
  private twilioClient: twilio.Twilio | null = null;
  private snsClient: SNSClient;
  private provider: 'twilio' | 'sns';

  constructor() {
    // Initialize based on config
    if (config.TWILIO_ACCOUNT_SID) {
      this.twilioClient = twilio(
        config.TWILIO_ACCOUNT_SID,
        config.TWILIO_AUTH_TOKEN
      );
      this.provider = 'twilio';
    } else {
      this.snsClient = new SNSClient({
        region: config.AWS_REGION,
        credentials: {
          accessKeyId: config.AWS_ACCESS_KEY_ID!,
          secretAccessKey: config.AWS_SECRET_ACCESS_KEY!,
        },
      });
      this.provider = 'sns';
    }
  }

  async send(options: SMSOptions): Promise<{ success: boolean; messageId?: string }> {
    const formattedPhone = this.formatPhoneNumber(options.to);

    try {
      if (this.provider === 'twilio' && this.twilioClient) {
        return this.sendWithTwilio(formattedPhone, options.message, options.sender);
      } else {
        return this.sendWithSNS(formattedPhone, options.message, options.sender);
      }
    } catch (error) {
      logger.error('SMS send failed', {
        to: formattedPhone,
        error: error.message,
      });

      return { success: false };
    }
  }

  async sendOTP(phoneNumber: string, otp: string): Promise<{ success: boolean }> {
    const message = `Your verification code is: ${otp}. This code expires in 10 minutes.`;
    return this.send({ to: phoneNumber, message });
  }

  private async sendWithTwilio(
    to: string,
    message: string,
    sender?: string
  ): Promise<{ success: boolean; messageId?: string }> {
    const result = await this.twilioClient!.messages.create({
      body: message,
      to,
      from: sender || config.TWILIO_PHONE_NUMBER,
    });

    logger.info('SMS sent via Twilio', {
      to,
      messageId: result.sid,
      status: result.status,
    });

    return {
      success: true,
      messageId: result.sid,
    };
  }

  private async sendWithSNS(
    to: string,
    message: string,
    sender?: string
  ): Promise<{ success: boolean; messageId?: string }> {
    const command = new PublishCommand({
      PhoneNumber: to,
      Message: message,
      MessageAttributes: {
        'AWS.SNS.SMS.SenderID': {
          DataType: 'String',
          StringValue: sender || config.SMS_SENDER_ID || 'App',
        },
        'AWS.SNS.SMS.SMSType': {
          DataType: 'String',
          StringValue: 'Transactional',
        },
      },
    });

    const result = await this.snsClient.send(command);

    logger.info('SMS sent via SNS', {
      to,
      messageId: result.MessageId,
    });

    return {
      success: true,
      messageId: result.MessageId,
    };
  }

  private formatPhoneNumber(phone: string): string {
    // Remove all non-numeric characters
    let cleaned = phone.replace(/\D/g, '');

    // Add + prefix if not present
    if (!phone.startsWith('+')) {
      // Assume US if 10 digits
      if (cleaned.length === 10) {
        cleaned = '1' + cleaned;
      }
      cleaned = '+' + cleaned;
    } else {
      cleaned = '+' + cleaned;
    }

    return cleaned;
  }
}

export const smsService = new SMSService();
```

### Notification Orchestration Service

```typescript
// src/services/notificationOrchestrationService.ts
import { db } from '../database';
import { pushNotificationService } from './pushNotificationService';
import { emailService } from './emailService';
import { smsService } from './smsService';
import { queueService, QUEUES } from '../queue';
import { logger } from '../utils/logger';

type NotificationChannel = 'push' | 'email' | 'sms' | 'in_app';

interface NotificationPayload {
  userId: string;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  channels?: NotificationChannel[];
  priority?: 'high' | 'normal' | 'low';
  scheduledFor?: Date;
  actionUrl?: string;
  imageUrl?: string;
}

interface UserNotificationPreferences {
  push_enabled: boolean;
  email_enabled: boolean;
  sms_enabled: boolean;
  type_preferences: Record<string, { push: boolean; email: boolean; sms: boolean }>;
  quiet_hours_enabled: boolean;
  quiet_hours_start: string;
  quiet_hours_end: string;
}

export class NotificationOrchestrationService {
  async send(payload: NotificationPayload): Promise<void> {
    // Check if scheduled for later
    if (payload.scheduledFor && payload.scheduledFor > new Date()) {
      await this.scheduleNotification(payload);
      return;
    }

    // Get user preferences
    const preferences = await this.getUserPreferences(payload.userId);

    // Check quiet hours
    if (this.isInQuietHours(preferences)) {
      // Delay until quiet hours end
      const resumeTime = this.getQuietHoursEndTime(preferences);
      await this.scheduleNotification({ ...payload, scheduledFor: resumeTime });
      return;
    }

    // Get user details
    const user = await db('users').where('id', payload.userId).first();

    if (!user) {
      logger.warn('User not found for notification', { userId: payload.userId });
      return;
    }

    // Determine channels
    const channels = payload.channels || this.getDefaultChannels(payload.type, preferences);

    // Create in-app notification
    if (channels.includes('in_app')) {
      await this.createInAppNotification(payload);
    }

    // Send to each channel
    const sendPromises: Promise<void>[] = [];

    if (channels.includes('push') && preferences.push_enabled) {
      sendPromises.push(this.sendPush(payload));
    }

    if (channels.includes('email') && preferences.email_enabled) {
      sendPromises.push(this.sendEmail(payload, user.email));
    }

    if (channels.includes('sms') && preferences.sms_enabled && user.phone) {
      sendPromises.push(this.sendSMS(payload, user.phone));
    }

    await Promise.allSettled(sendPromises);
  }

  async sendBatch(payloads: NotificationPayload[]): Promise<void> {
    // Group by type for batch processing
    const pushPayloads = payloads.filter(p =>
      !p.channels || p.channels.includes('push')
    );

    if (pushPayloads.length > 0) {
      await this.sendBatchPush(pushPayloads);
    }

    // Queue individual email/SMS
    for (const payload of payloads) {
      if (payload.channels?.includes('email')) {
        await queueService.addJob(QUEUES.EMAIL, {
          type: 'notification_email',
          payload,
        });
      }
      if (payload.channels?.includes('sms')) {
        await queueService.addJob(QUEUES.SMS, {
          type: 'notification_sms',
          payload,
        });
      }
    }
  }

  private async getUserPreferences(userId: string): Promise<UserNotificationPreferences> {
    let prefs = await db('notification_preferences')
      .where('user_id', userId)
      .first();

    if (!prefs) {
      // Return defaults
      return {
        push_enabled: true,
        email_enabled: true,
        sms_enabled: false,
        type_preferences: {},
        quiet_hours_enabled: false,
        quiet_hours_start: '22:00',
        quiet_hours_end: '08:00',
      };
    }

    return prefs;
  }

  private getDefaultChannels(
    type: string,
    preferences: UserNotificationPreferences
  ): NotificationChannel[] {
    const channels: NotificationChannel[] = ['in_app'];
    const typePrefs = preferences.type_preferences[type];

    if (typePrefs) {
      if (typePrefs.push && preferences.push_enabled) channels.push('push');
      if (typePrefs.email && preferences.email_enabled) channels.push('email');
      if (typePrefs.sms && preferences.sms_enabled) channels.push('sms');
    } else {
      // Default to push for all types
      if (preferences.push_enabled) channels.push('push');
    }

    return channels;
  }

  private isInQuietHours(preferences: UserNotificationPreferences): boolean {
    if (!preferences.quiet_hours_enabled) return false;

    const now = new Date();
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

    const start = preferences.quiet_hours_start;
    const end = preferences.quiet_hours_end;

    // Handle overnight quiet hours (e.g., 22:00 - 08:00)
    if (start > end) {
      return currentTime >= start || currentTime < end;
    }

    return currentTime >= start && currentTime < end;
  }

  private getQuietHoursEndTime(preferences: UserNotificationPreferences): Date {
    const now = new Date();
    const [hours, minutes] = preferences.quiet_hours_end.split(':').map(Number);

    const endTime = new Date(now);
    endTime.setHours(hours, minutes, 0, 0);

    // If end time is in the past, it's tomorrow
    if (endTime <= now) {
      endTime.setDate(endTime.getDate() + 1);
    }

    return endTime;
  }

  private async createInAppNotification(payload: NotificationPayload): Promise<void> {
    await db('notifications').insert({
      user_id: payload.userId,
      type: payload.type,
      title: payload.title,
      body: payload.body,
      data: payload.data || {},
      action_url: payload.actionUrl,
    });
  }

  private async sendPush(payload: NotificationPayload): Promise<void> {
    await queueService.addJob(QUEUES.PUSH_NOTIFICATION, {
      type: 'push_notification',
      userId: payload.userId,
      notification: {
        title: payload.title,
        body: payload.body,
        data: {
          type: payload.type,
          actionUrl: payload.actionUrl,
          ...(payload.data as Record<string, string>),
        },
        imageUrl: payload.imageUrl,
      },
      options: {
        priority: payload.priority === 'high' ? 'high' : 'normal',
      },
    });
  }

  private async sendBatchPush(payloads: NotificationPayload[]): Promise<void> {
    const userIds = payloads.map(p => p.userId);

    await pushNotificationService.sendToUsers(
      userIds,
      {
        title: payloads[0].title,
        body: payloads[0].body,
        data: payloads[0].data as Record<string, string>,
      },
      { priority: payloads[0].priority === 'high' ? 'high' : 'normal' }
    );
  }

  private async sendEmail(payload: NotificationPayload, email: string): Promise<void> {
    await queueService.addJob(QUEUES.EMAIL, {
      type: 'email',
      to: email,
      subject: payload.title,
      template: `notification-${payload.type}`,
      data: {
        title: payload.title,
        body: payload.body,
        actionUrl: payload.actionUrl,
        ...payload.data,
      },
    });
  }

  private async sendSMS(payload: NotificationPayload, phone: string): Promise<void> {
    await queueService.addJob(QUEUES.SMS, {
      type: 'sms',
      to: phone,
      message: `${payload.title}: ${payload.body}`,
    });
  }

  private async scheduleNotification(payload: NotificationPayload): Promise<void> {
    await db('scheduled_notifications').insert({
      user_id: payload.userId,
      type: payload.type,
      content: {
        title: payload.title,
        body: payload.body,
        data: payload.data,
        actionUrl: payload.actionUrl,
        channels: payload.channels,
      },
      scheduled_for: payload.scheduledFor,
    });
  }
}

export const notificationOrchestrationService = new NotificationOrchestrationService();
```

## Gate Criteria

Before marking notification service complete, verify:

### Push Notification Gates
- [ ] FCM delivery working (Android)
- [ ] APNs delivery working (iOS)
- [ ] Silent push working
- [ ] Batch sending implemented
- [ ] Invalid token handling working
- [ ] Delivery tracking implemented

### Email Gates
- [ ] Email templates rendering correctly
- [ ] SES/SMTP integration working
- [ ] Attachments supported
- [ ] Template variables working
- [ ] Bounce/complaint handling

### SMS Gates
- [ ] SMS delivery working
- [ ] Phone number formatting correct
- [ ] OTP sending working
- [ ] International numbers supported

### Preference Gates
- [ ] User preferences respected
- [ ] Per-type preferences working
- [ ] Quiet hours honored
- [ ] Channel preferences applied

### Orchestration Gates
- [ ] Multi-channel delivery working
- [ ] Scheduled notifications working
- [ ] In-app notifications created
- [ ] Priority levels respected
- [ ] Batch notifications efficient

### Monitoring Gates
- [ ] Delivery success/failure tracked
- [ ] Notification analytics available
- [ ] Failed delivery alerting
- [ ] Performance metrics captured
