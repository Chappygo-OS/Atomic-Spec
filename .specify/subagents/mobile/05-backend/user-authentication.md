---
name: Mobile User Authentication
platform: mobile
description: User authentication and session management for mobile backends including JWT handling, OAuth flows, biometric authentication support, device management, and secure token refresh patterns
model: opus
category: mobile/backend
---

# Mobile User Authentication Subagent

## Purpose

This subagent handles all aspects of user authentication specifically designed for mobile applications. Mobile authentication requires unique considerations including token refresh for long-lived sessions, device registration for push notifications, biometric authentication support, and handling multiple devices per user.

## Core Responsibilities

1. User registration and login flows
2. JWT access and refresh token management
3. OAuth/social authentication integration
4. Device registration and management
5. Session management across devices
6. Password reset and account recovery
7. Biometric authentication support
8. Token refresh and rotation

## Authentication Architecture

### JWT Token Structure

```typescript
// src/types/auth.ts
export interface AccessTokenPayload {
  sub: string;           // User ID
  email: string;
  type: 'access';
  deviceId: string;      // Device that issued the token
  sessionId: string;     // Session identifier for this device
  iat: number;
  exp: number;
}

export interface RefreshTokenPayload {
  sub: string;           // User ID
  type: 'refresh';
  deviceId: string;
  sessionId: string;
  familyId: string;      // Token family for rotation detection
  iat: number;
  exp: number;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: number;
  refreshTokenExpiresAt: number;
}

export interface AuthenticatedUser {
  id: string;
  email: string;
  deviceId: string;
  sessionId: string;
}
```

### Token Service Implementation

```typescript
// src/services/tokenService.ts
import jwt, { SignOptions, JwtPayload } from 'jsonwebtoken';
import crypto from 'crypto';
import { config } from '../config';
import { redis } from '../cache/redis';
import { db } from '../database';
import {
  AccessTokenPayload,
  RefreshTokenPayload,
  TokenPair,
} from '../types/auth';
import { AppError, ErrorCodes } from '../errors/AppError';

export class TokenService {
  private readonly accessTokenExpiry = config.JWT_ACCESS_EXPIRY;  // e.g., '15m'
  private readonly refreshTokenExpiry = config.JWT_REFRESH_EXPIRY; // e.g., '7d'
  private readonly jwtSecret = config.JWT_SECRET;

  async generateTokenPair(
    userId: string,
    deviceId: string,
    sessionId?: string
  ): Promise<TokenPair> {
    const newSessionId = sessionId || this.generateSessionId();
    const familyId = this.generateFamilyId();

    const accessToken = await this.generateAccessToken(userId, deviceId, newSessionId);
    const refreshToken = await this.generateRefreshToken(userId, deviceId, newSessionId, familyId);

    // Store refresh token hash in database
    await this.storeRefreshToken(userId, deviceId, refreshToken, familyId);

    const accessPayload = jwt.decode(accessToken) as JwtPayload;
    const refreshPayload = jwt.decode(refreshToken) as JwtPayload;

    return {
      accessToken,
      refreshToken,
      accessTokenExpiresAt: accessPayload.exp! * 1000,
      refreshTokenExpiresAt: refreshPayload.exp! * 1000,
    };
  }

  private async generateAccessToken(
    userId: string,
    deviceId: string,
    sessionId: string
  ): Promise<string> {
    const user = await db('users').where('id', userId).first();

    const payload: Omit<AccessTokenPayload, 'iat' | 'exp'> = {
      sub: userId,
      email: user.email,
      type: 'access',
      deviceId,
      sessionId,
    };

    const options: SignOptions = {
      expiresIn: this.accessTokenExpiry,
      algorithm: 'HS256',
    };

    return jwt.sign(payload, this.jwtSecret, options);
  }

  private async generateRefreshToken(
    userId: string,
    deviceId: string,
    sessionId: string,
    familyId: string
  ): Promise<string> {
    const payload: Omit<RefreshTokenPayload, 'iat' | 'exp'> = {
      sub: userId,
      type: 'refresh',
      deviceId,
      sessionId,
      familyId,
    };

    const options: SignOptions = {
      expiresIn: this.refreshTokenExpiry,
      algorithm: 'HS256',
    };

    return jwt.sign(payload, this.jwtSecret, options);
  }

  async verifyAccessToken(token: string): Promise<AccessTokenPayload> {
    try {
      const payload = jwt.verify(token, this.jwtSecret) as AccessTokenPayload;

      if (payload.type !== 'access') {
        throw new AppError(ErrorCodes.AUTH_TOKEN_INVALID, 'Invalid token type', 401);
      }

      // Check if session is revoked
      const isRevoked = await this.isSessionRevoked(payload.sessionId);
      if (isRevoked) {
        throw new AppError(ErrorCodes.AUTH_SESSION_REVOKED, 'Session has been revoked', 401);
      }

      return payload;
    } catch (error) {
      if (error instanceof jwt.TokenExpiredError) {
        throw new AppError(ErrorCodes.AUTH_TOKEN_EXPIRED, 'Token has expired', 401);
      }
      if (error instanceof jwt.JsonWebTokenError) {
        throw new AppError(ErrorCodes.AUTH_TOKEN_INVALID, 'Invalid token', 401);
      }
      throw error;
    }
  }

  async refreshTokens(refreshToken: string): Promise<TokenPair> {
    let payload: RefreshTokenPayload;

    try {
      payload = jwt.verify(refreshToken, this.jwtSecret) as RefreshTokenPayload;
    } catch (error) {
      if (error instanceof jwt.TokenExpiredError) {
        throw new AppError(ErrorCodes.AUTH_REFRESH_REQUIRED, 'Refresh token expired', 401);
      }
      throw new AppError(ErrorCodes.AUTH_TOKEN_INVALID, 'Invalid refresh token', 401);
    }

    if (payload.type !== 'refresh') {
      throw new AppError(ErrorCodes.AUTH_TOKEN_INVALID, 'Invalid token type', 401);
    }

    // Check if token exists and is not revoked
    const tokenHash = this.hashToken(refreshToken);
    const storedToken = await db('refresh_tokens')
      .where('token_hash', tokenHash)
      .first();

    if (!storedToken) {
      // Token reuse detected - revoke entire family
      await this.revokeTokenFamily(payload.familyId, 'token_reuse');
      throw new AppError(ErrorCodes.AUTH_SESSION_REVOKED, 'Token reuse detected', 401);
    }

    if (storedToken.revoked_at) {
      throw new AppError(ErrorCodes.AUTH_SESSION_REVOKED, 'Token has been revoked', 401);
    }

    // Revoke old refresh token (rotation)
    await db('refresh_tokens')
      .where('id', storedToken.id)
      .update({ revoked_at: new Date(), revoked_reason: 'rotated' });

    // Generate new token pair with same family
    const newTokens = await this.generateTokenPair(
      payload.sub,
      payload.deviceId,
      payload.sessionId
    );

    // Store new refresh token with same family
    await this.storeRefreshToken(
      payload.sub,
      payload.deviceId,
      newTokens.refreshToken,
      payload.familyId
    );

    return newTokens;
  }

  private async storeRefreshToken(
    userId: string,
    deviceId: string,
    token: string,
    familyId: string
  ): Promise<void> {
    const tokenHash = this.hashToken(token);
    const decoded = jwt.decode(token) as JwtPayload;

    await db('refresh_tokens').insert({
      user_id: userId,
      token_hash: tokenHash,
      family_id: familyId,
      device_id: await this.getDeviceRecordId(userId, deviceId),
      expires_at: new Date(decoded.exp! * 1000),
    });
  }

  async revokeSession(sessionId: string): Promise<void> {
    // Add to revoked sessions cache
    await redis.set(
      `revoked:session:${sessionId}`,
      '1',
      'EX',
      86400 * 7 // 7 days
    );
  }

  async revokeAllUserSessions(userId: string): Promise<void> {
    // Revoke all refresh tokens
    await db('refresh_tokens')
      .where('user_id', userId)
      .whereNull('revoked_at')
      .update({ revoked_at: new Date(), revoked_reason: 'user_logout_all' });

    // Mark user sessions as revoked in cache
    await redis.set(
      `revoked:user:${userId}`,
      Date.now().toString(),
      'EX',
      86400 * 7
    );
  }

  async revokeDeviceSessions(userId: string, deviceId: string): Promise<void> {
    const device = await this.getDeviceRecordId(userId, deviceId);

    await db('refresh_tokens')
      .where('device_id', device)
      .whereNull('revoked_at')
      .update({ revoked_at: new Date(), revoked_reason: 'device_logout' });
  }

  private async revokeTokenFamily(familyId: string, reason: string): Promise<void> {
    await db('refresh_tokens')
      .where('family_id', familyId)
      .whereNull('revoked_at')
      .update({ revoked_at: new Date(), revoked_reason: reason });
  }

  private async isSessionRevoked(sessionId: string): Promise<boolean> {
    const revoked = await redis.get(`revoked:session:${sessionId}`);
    return revoked === '1';
  }

  private hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  private generateSessionId(): string {
    return crypto.randomBytes(16).toString('hex');
  }

  private generateFamilyId(): string {
    return crypto.randomBytes(16).toString('hex');
  }

  private async getDeviceRecordId(userId: string, deviceId: string): Promise<string> {
    const device = await db('user_devices')
      .where({ user_id: userId, device_id: deviceId })
      .first();
    return device?.id;
  }
}

export const tokenService = new TokenService();
```

## Authentication Controller

```typescript
// src/controllers/authController.ts
import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { db } from '../database';
import { tokenService } from '../services/tokenService';
import { deviceService } from '../services/deviceService';
import { emailService } from '../services/emailService';
import { ApiResponseBuilder } from '../utils/response';
import { AppError, ErrorCodes } from '../errors/AppError';
import { validateRequest } from '../middleware/validateRequest';

// Validation schemas
const RegisterSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(100),
  firstName: z.string().min(1).max(100).optional(),
  lastName: z.string().min(1).max(100).optional(),
  device: z.object({
    deviceId: z.string().min(1),
    deviceName: z.string().optional(),
    deviceModel: z.string().optional(),
    platform: z.enum(['ios', 'android', 'web']),
    osVersion: z.string().optional(),
    appVersion: z.string(),
    pushToken: z.string().optional(),
  }),
});

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
  device: z.object({
    deviceId: z.string().min(1),
    deviceName: z.string().optional(),
    deviceModel: z.string().optional(),
    platform: z.enum(['ios', 'android', 'web']),
    osVersion: z.string().optional(),
    appVersion: z.string(),
    pushToken: z.string().optional(),
  }),
});

const RefreshSchema = z.object({
  refreshToken: z.string(),
});

export const authController = {
  // User Registration
  async register(req: Request, res: Response) {
    const { email, password, firstName, lastName, device } = req.body;

    // Check if user exists
    const existingUser = await db('users')
      .where('email', email.toLowerCase())
      .first();

    if (existingUser) {
      throw new AppError(
        ErrorCodes.RESOURCE_CONFLICT,
        'An account with this email already exists',
        409
      );
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 12);

    // Create user
    const [user] = await db('users')
      .insert({
        email: email.toLowerCase(),
        password_hash: passwordHash,
        first_name: firstName,
        last_name: lastName,
        display_name: firstName ? `${firstName} ${lastName || ''}`.trim() : null,
        status: 'pending',
      })
      .returning('*');

    // Register device
    await deviceService.registerDevice(user.id, device);

    // Generate tokens
    const tokens = await tokenService.generateTokenPair(user.id, device.deviceId);

    // Send verification email
    await emailService.sendVerificationEmail(user.id, user.email);

    ApiResponseBuilder.success({
      user: {
        id: user.id,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        displayName: user.display_name,
        emailVerified: false,
      },
      tokens,
    }).send(res, 201);
  },

  // User Login
  async login(req: Request, res: Response) {
    const { email, password, device } = req.body;

    // Find user
    const user = await db('users')
      .where('email', email.toLowerCase())
      .whereNull('deleted_at')
      .first();

    if (!user) {
      throw new AppError(
        ErrorCodes.AUTH_TOKEN_INVALID,
        'Invalid email or password',
        401
      );
    }

    // Verify password
    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      throw new AppError(
        ErrorCodes.AUTH_TOKEN_INVALID,
        'Invalid email or password',
        401
      );
    }

    // Check account status
    if (user.status === 'suspended') {
      throw new AppError(
        ErrorCodes.ACCESS_DENIED,
        'Your account has been suspended',
        403
      );
    }

    // Register/update device
    await deviceService.registerDevice(user.id, device);

    // Generate tokens
    const tokens = await tokenService.generateTokenPair(user.id, device.deviceId);

    // Update last active
    await db('users')
      .where('id', user.id)
      .update({ last_active_at: new Date() });

    ApiResponseBuilder.success({
      user: {
        id: user.id,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        displayName: user.display_name,
        avatarUrl: user.avatar_url,
        emailVerified: !!user.email_verified_at,
      },
      tokens,
    }).send(res);
  },

  // Refresh tokens
  async refresh(req: Request, res: Response) {
    const { refreshToken } = req.body;

    const tokens = await tokenService.refreshTokens(refreshToken);

    ApiResponseBuilder.success({ tokens }).send(res);
  },

  // Logout
  async logout(req: Request, res: Response) {
    const { sessionId, deviceId } = req.user;

    // Revoke current session
    await tokenService.revokeSession(sessionId);

    ApiResponseBuilder.success({ message: 'Logged out successfully' }).send(res);
  },

  // Logout from all devices
  async logoutAll(req: Request, res: Response) {
    const { id: userId } = req.user;

    await tokenService.revokeAllUserSessions(userId);

    ApiResponseBuilder.success({
      message: 'Logged out from all devices',
    }).send(res);
  },

  // Request password reset
  async forgotPassword(req: Request, res: Response) {
    const { email } = req.body;

    const user = await db('users')
      .where('email', email.toLowerCase())
      .whereNull('deleted_at')
      .first();

    // Always return success to prevent email enumeration
    if (!user) {
      ApiResponseBuilder.success({
        message: 'If an account exists, a password reset email has been sent',
      }).send(res);
      return;
    }

    // Generate reset token
    const resetToken = await tokenService.generatePasswordResetToken(user.id);

    // Send email
    await emailService.sendPasswordResetEmail(user.email, resetToken);

    ApiResponseBuilder.success({
      message: 'If an account exists, a password reset email has been sent',
    }).send(res);
  },

  // Reset password with token
  async resetPassword(req: Request, res: Response) {
    const { token, newPassword } = req.body;

    // Verify reset token
    const userId = await tokenService.verifyPasswordResetToken(token);

    // Hash new password
    const passwordHash = await bcrypt.hash(newPassword, 12);

    // Update password and revoke all sessions
    await db('users')
      .where('id', userId)
      .update({
        password_hash: passwordHash,
        updated_at: new Date(),
      });

    await tokenService.revokeAllUserSessions(userId);

    ApiResponseBuilder.success({
      message: 'Password reset successfully. Please log in with your new password.',
    }).send(res);
  },

  // Verify email
  async verifyEmail(req: Request, res: Response) {
    const { token } = req.params;

    const userId = await tokenService.verifyEmailToken(token);

    await db('users')
      .where('id', userId)
      .update({
        email_verified_at: new Date(),
        status: 'active',
      });

    ApiResponseBuilder.success({
      message: 'Email verified successfully',
    }).send(res);
  },
};
```

## Device Management Service

```typescript
// src/services/deviceService.ts
import { db } from '../database';
import { pushNotificationService } from './pushNotificationService';

interface DeviceInfo {
  deviceId: string;
  deviceName?: string;
  deviceModel?: string;
  platform: 'ios' | 'android' | 'web';
  osVersion?: string;
  appVersion: string;
  pushToken?: string;
}

export class DeviceService {
  async registerDevice(userId: string, device: DeviceInfo): Promise<void> {
    const existingDevice = await db('user_devices')
      .where({ user_id: userId, device_id: device.deviceId })
      .first();

    if (existingDevice) {
      // Update existing device
      await db('user_devices')
        .where('id', existingDevice.id)
        .update({
          device_name: device.deviceName,
          device_model: device.deviceModel,
          os_version: device.osVersion,
          app_version: device.appVersion,
          push_token: device.pushToken,
          push_token_type: this.getPushTokenType(device.platform),
          last_active_at: new Date(),
          updated_at: new Date(),
        });
    } else {
      // Register new device
      await db('user_devices').insert({
        user_id: userId,
        device_id: device.deviceId,
        device_name: device.deviceName,
        device_model: device.deviceModel,
        platform: device.platform,
        os_version: device.osVersion,
        app_version: device.appVersion,
        push_token: device.pushToken,
        push_token_type: this.getPushTokenType(device.platform),
      });
    }

    // If push token changed, verify it
    if (device.pushToken) {
      await this.verifyPushToken(userId, device.deviceId, device.pushToken);
    }
  }

  async getUserDevices(userId: string): Promise<any[]> {
    return db('user_devices')
      .where('user_id', userId)
      .orderBy('last_active_at', 'desc');
  }

  async removeDevice(userId: string, deviceId: string): Promise<void> {
    await db('user_devices')
      .where({ user_id: userId, device_id: deviceId })
      .delete();

    // Also revoke any active sessions for this device
    await db('refresh_tokens')
      .whereIn('device_id', function() {
        this.select('id')
          .from('user_devices')
          .where({ user_id: userId, device_id: deviceId });
      })
      .update({ revoked_at: new Date(), revoked_reason: 'device_removed' });
  }

  async updatePushToken(
    userId: string,
    deviceId: string,
    pushToken: string
  ): Promise<void> {
    await db('user_devices')
      .where({ user_id: userId, device_id: deviceId })
      .update({
        push_token: pushToken,
        updated_at: new Date(),
      });

    await this.verifyPushToken(userId, deviceId, pushToken);
  }

  async disablePushNotifications(userId: string, deviceId: string): Promise<void> {
    await db('user_devices')
      .where({ user_id: userId, device_id: deviceId })
      .update({
        push_enabled: false,
        updated_at: new Date(),
      });
  }

  private getPushTokenType(platform: string): string {
    switch (platform) {
      case 'ios': return 'apns';
      case 'android': return 'fcm';
      case 'web': return 'web';
      default: return 'fcm';
    }
  }

  private async verifyPushToken(
    userId: string,
    deviceId: string,
    pushToken: string
  ): Promise<void> {
    // Send a silent push to verify token
    try {
      await pushNotificationService.sendSilentPush(pushToken);
    } catch (error) {
      // Mark token as invalid
      await db('user_devices')
        .where({ user_id: userId, device_id: deviceId })
        .update({
          push_enabled: false,
          updated_at: new Date(),
        });
    }
  }
}

export const deviceService = new DeviceService();
```

## OAuth/Social Authentication

```typescript
// src/services/oauthService.ts
import { OAuth2Client } from 'google-auth-library';
import AppleSignIn from 'apple-signin-auth';
import { db } from '../database';
import { tokenService } from './tokenService';
import { deviceService } from './deviceService';
import { config } from '../config';

interface OAuthUserInfo {
  provider: 'google' | 'apple' | 'facebook';
  providerId: string;
  email: string;
  firstName?: string;
  lastName?: string;
  avatarUrl?: string;
}

export class OAuthService {
  private googleClient: OAuth2Client;

  constructor() {
    this.googleClient = new OAuth2Client(config.GOOGLE_CLIENT_ID);
  }

  async authenticateWithGoogle(
    idToken: string,
    device: DeviceInfo
  ): Promise<AuthResult> {
    // Verify Google ID token
    const ticket = await this.googleClient.verifyIdToken({
      idToken,
      audience: [
        config.GOOGLE_CLIENT_ID,
        config.GOOGLE_IOS_CLIENT_ID,
        config.GOOGLE_ANDROID_CLIENT_ID,
      ],
    });

    const payload = ticket.getPayload();
    if (!payload || !payload.email) {
      throw new AppError(ErrorCodes.AUTH_TOKEN_INVALID, 'Invalid Google token', 401);
    }

    const userInfo: OAuthUserInfo = {
      provider: 'google',
      providerId: payload.sub,
      email: payload.email,
      firstName: payload.given_name,
      lastName: payload.family_name,
      avatarUrl: payload.picture,
    };

    return this.handleOAuthUser(userInfo, device);
  }

  async authenticateWithApple(
    identityToken: string,
    authorizationCode: string,
    user: { firstName?: string; lastName?: string } | null,
    device: DeviceInfo
  ): Promise<AuthResult> {
    // Verify Apple identity token
    const appleUser = await AppleSignIn.verifyIdToken(identityToken, {
      audience: config.APPLE_CLIENT_ID,
      ignoreExpiration: false,
    });

    if (!appleUser.email) {
      throw new AppError(ErrorCodes.AUTH_TOKEN_INVALID, 'Invalid Apple token', 401);
    }

    const userInfo: OAuthUserInfo = {
      provider: 'apple',
      providerId: appleUser.sub,
      email: appleUser.email,
      firstName: user?.firstName,
      lastName: user?.lastName,
    };

    return this.handleOAuthUser(userInfo, device);
  }

  private async handleOAuthUser(
    userInfo: OAuthUserInfo,
    device: DeviceInfo
  ): Promise<AuthResult> {
    // Check if OAuth connection exists
    const existingConnection = await db('user_oauth_connections')
      .where({
        provider: userInfo.provider,
        provider_id: userInfo.providerId,
      })
      .first();

    let user;
    let isNewUser = false;

    if (existingConnection) {
      // Existing OAuth user
      user = await db('users')
        .where('id', existingConnection.user_id)
        .first();
    } else {
      // Check if user exists with same email
      user = await db('users')
        .where('email', userInfo.email.toLowerCase())
        .first();

      if (user) {
        // Link OAuth to existing account
        await db('user_oauth_connections').insert({
          user_id: user.id,
          provider: userInfo.provider,
          provider_id: userInfo.providerId,
          email: userInfo.email,
        });
      } else {
        // Create new user
        [user] = await db('users')
          .insert({
            email: userInfo.email.toLowerCase(),
            password_hash: '', // No password for OAuth users
            first_name: userInfo.firstName,
            last_name: userInfo.lastName,
            display_name: userInfo.firstName
              ? `${userInfo.firstName} ${userInfo.lastName || ''}`.trim()
              : userInfo.email.split('@')[0],
            avatar_url: userInfo.avatarUrl,
            email_verified_at: new Date(), // OAuth emails are pre-verified
            status: 'active',
          })
          .returning('*');

        // Create OAuth connection
        await db('user_oauth_connections').insert({
          user_id: user.id,
          provider: userInfo.provider,
          provider_id: userInfo.providerId,
          email: userInfo.email,
        });

        isNewUser = true;
      }
    }

    // Register device
    await deviceService.registerDevice(user.id, device);

    // Generate tokens
    const tokens = await tokenService.generateTokenPair(user.id, device.deviceId);

    return {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        displayName: user.display_name,
        avatarUrl: user.avatar_url,
        emailVerified: true,
      },
      tokens,
      isNewUser,
    };
  }
}

export const oauthService = new OAuthService();
```

## Biometric Authentication Support

```typescript
// src/services/biometricService.ts
import crypto from 'crypto';
import { db } from '../database';
import { tokenService } from './tokenService';
import { AppError, ErrorCodes } from '../errors/AppError';

export class BiometricService {
  // Enable biometric authentication for a device
  async enableBiometric(
    userId: string,
    deviceId: string,
    publicKey: string
  ): Promise<{ biometricToken: string }> {
    // Generate a biometric token
    const biometricToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto
      .createHash('sha256')
      .update(biometricToken)
      .digest('hex');

    // Store biometric credentials
    await db('user_biometric_credentials').insert({
      user_id: userId,
      device_id: deviceId,
      public_key: publicKey,
      token_hash: tokenHash,
      enabled: true,
    }).onConflict(['user_id', 'device_id'])
      .merge({
        public_key: publicKey,
        token_hash: tokenHash,
        enabled: true,
        updated_at: new Date(),
      });

    return { biometricToken };
  }

  // Authenticate using biometrics
  async authenticateWithBiometric(
    deviceId: string,
    biometricToken: string,
    signature: string,
    challenge: string
  ): Promise<TokenPair> {
    const tokenHash = crypto
      .createHash('sha256')
      .update(biometricToken)
      .digest('hex');

    // Find biometric credential
    const credential = await db('user_biometric_credentials')
      .where({
        device_id: deviceId,
        token_hash: tokenHash,
        enabled: true,
      })
      .first();

    if (!credential) {
      throw new AppError(
        ErrorCodes.AUTH_TOKEN_INVALID,
        'Invalid biometric credential',
        401
      );
    }

    // Verify signature using stored public key
    const isValid = this.verifySignature(
      credential.public_key,
      challenge,
      signature
    );

    if (!isValid) {
      throw new AppError(
        ErrorCodes.AUTH_TOKEN_INVALID,
        'Invalid biometric signature',
        401
      );
    }

    // Update last used
    await db('user_biometric_credentials')
      .where('id', credential.id)
      .update({ last_used_at: new Date() });

    // Generate new tokens
    return tokenService.generateTokenPair(credential.user_id, deviceId);
  }

  // Generate challenge for biometric auth
  async generateChallenge(deviceId: string): Promise<string> {
    const challenge = crypto.randomBytes(32).toString('hex');

    // Store challenge temporarily (expires in 5 minutes)
    await redis.set(
      `biometric:challenge:${deviceId}`,
      challenge,
      'EX',
      300
    );

    return challenge;
  }

  // Disable biometric for a device
  async disableBiometric(userId: string, deviceId: string): Promise<void> {
    await db('user_biometric_credentials')
      .where({ user_id: userId, device_id: deviceId })
      .update({ enabled: false, updated_at: new Date() });
  }

  private verifySignature(
    publicKey: string,
    challenge: string,
    signature: string
  ): boolean {
    try {
      const verify = crypto.createVerify('SHA256');
      verify.update(challenge);
      return verify.verify(publicKey, Buffer.from(signature, 'base64'));
    } catch {
      return false;
    }
  }
}

export const biometricService = new BiometricService();
```

## Authentication Middleware

```typescript
// src/middleware/authenticate.ts
import { Request, Response, NextFunction } from 'express';
import { tokenService } from '../services/tokenService';
import { AppError, ErrorCodes } from '../errors/AppError';

declare global {
  namespace Express {
    interface Request {
      user: AuthenticatedUser;
      mobileContext?: MobileRequestContext;
    }
  }
}

export async function authenticate(
  req: Request,
  res: Response,
  next: NextFunction
) {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      throw new AppError(
        ErrorCodes.AUTH_TOKEN_INVALID,
        'No authorization header',
        401
      );
    }

    const [scheme, token] = authHeader.split(' ');

    if (scheme !== 'Bearer' || !token) {
      throw new AppError(
        ErrorCodes.AUTH_TOKEN_INVALID,
        'Invalid authorization format',
        401
      );
    }

    const payload = await tokenService.verifyAccessToken(token);

    req.user = {
      id: payload.sub,
      email: payload.email,
      deviceId: payload.deviceId,
      sessionId: payload.sessionId,
    };

    next();
  } catch (error) {
    next(error);
  }
}

// Optional authentication (doesn't fail if no token)
export async function optionalAuthenticate(
  req: Request,
  res: Response,
  next: NextFunction
) {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      return next();
    }

    const [scheme, token] = authHeader.split(' ');

    if (scheme !== 'Bearer' || !token) {
      return next();
    }

    try {
      const payload = await tokenService.verifyAccessToken(token);
      req.user = {
        id: payload.sub,
        email: payload.email,
        deviceId: payload.deviceId,
        sessionId: payload.sessionId,
      };
    } catch {
      // Ignore token errors in optional auth
    }

    next();
  } catch (error) {
    next(error);
  }
}
```

## Auth Routes

```typescript
// src/routes/auth.ts
import { Router } from 'express';
import { authController } from '../controllers/authController';
import { authenticate } from '../middleware/authenticate';
import { validateRequest } from '../middleware/validateRequest';
import { rateLimit } from 'express-rate-limit';

const router = Router();

// Rate limiters for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 attempts
  message: {
    success: false,
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many authentication attempts, please try again later',
    },
  },
  keyGenerator: (req) => req.body.email || req.ip,
});

const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3, // 3 attempts
  message: {
    success: false,
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many password reset attempts, please try again later',
    },
  },
});

// Public routes
router.post('/register', authLimiter, authController.register);
router.post('/login', authLimiter, authController.login);
router.post('/refresh', authController.refresh);
router.post('/forgot-password', passwordResetLimiter, authController.forgotPassword);
router.post('/reset-password', authController.resetPassword);
router.get('/verify-email/:token', authController.verifyEmail);

// OAuth routes
router.post('/oauth/google', authController.googleAuth);
router.post('/oauth/apple', authController.appleAuth);

// Biometric routes
router.post('/biometric/challenge', authController.getBiometricChallenge);
router.post('/biometric/authenticate', authController.authenticateBiometric);

// Protected routes
router.post('/logout', authenticate, authController.logout);
router.post('/logout-all', authenticate, authController.logoutAll);

// Device management
router.get('/devices', authenticate, authController.getDevices);
router.delete('/devices/:deviceId', authenticate, authController.removeDevice);
router.post('/devices/:deviceId/push-token', authenticate, authController.updatePushToken);

// Biometric management (protected)
router.post('/biometric/enable', authenticate, authController.enableBiometric);
router.post('/biometric/disable', authenticate, authController.disableBiometric);

export { router as authRouter };
```

## Gate Criteria

Before marking user authentication complete, verify:

### Security Gates
- [ ] Passwords hashed with bcrypt (cost factor >= 12)
- [ ] JWT tokens signed with strong secret (>= 256 bits)
- [ ] Refresh token rotation implemented
- [ ] Token reuse detection implemented
- [ ] Rate limiting on all auth endpoints
- [ ] Password reset tokens single-use and time-limited
- [ ] No sensitive data in JWT payload

### Token Management Gates
- [ ] Access tokens short-lived (15 minutes or less)
- [ ] Refresh tokens properly stored in database
- [ ] Token revocation working correctly
- [ ] Session revocation propagates to all devices
- [ ] Token family tracking for rotation detection

### Device Management Gates
- [ ] Device registration on login
- [ ] Push token storage and validation
- [ ] Device listing available to users
- [ ] Device removal revokes associated sessions
- [ ] Multiple devices per user supported

### OAuth Gates
- [ ] Google Sign-In implemented (if required)
- [ ] Apple Sign-In implemented (required for iOS)
- [ ] OAuth tokens properly verified
- [ ] Account linking for existing users
- [ ] OAuth user info properly stored

### Biometric Gates (if applicable)
- [ ] Biometric enrollment secure
- [ ] Challenge-response properly implemented
- [ ] Public key cryptography used
- [ ] Biometric can be disabled per device
- [ ] Falls back to password auth

### API Gates
- [ ] Login returns appropriate error codes
- [ ] Token refresh handles all error cases
- [ ] Logout properly invalidates session
- [ ] Password reset email sent securely
- [ ] Email verification working

### Testing Gates
- [ ] Unit tests for token generation/verification
- [ ] Integration tests for auth flows
- [ ] Security tests for token manipulation
- [ ] Load tests for auth endpoints
- [ ] Penetration testing completed
