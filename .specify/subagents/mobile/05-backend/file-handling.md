---
name: Mobile Backend File Handling
platform: mobile
description: File upload and download handling for mobile backends including image processing, video transcoding, cloud storage integration, resumable uploads, and CDN configuration
model: opus
category: mobile/backend
---

# Mobile Backend File Handling Subagent

## Purpose

This subagent handles all aspects of file management for mobile backends. Mobile applications have unique file handling requirements including efficient image uploads from cameras, video processing, resumable uploads for large files over unreliable connections, and optimized delivery through CDNs.

## Core Responsibilities

1. File upload processing (single and multipart)
2. Image resizing and optimization
3. Video transcoding and thumbnail generation
4. Cloud storage integration (S3, GCS, Azure Blob)
5. Resumable upload support for large files
6. CDN configuration and signed URLs
7. File metadata management
8. Storage quota enforcement

## File Upload Architecture

### Upload Endpoint Implementation

```typescript
// src/routes/uploads.ts
import { Router } from 'express';
import multer from 'multer';
import { authenticate } from '../middleware/authenticate';
import { requireFeature } from '../middleware/authorize';
import { uploadController } from '../controllers/uploadController';
import { config } from '../config';

const router = Router();

// Multer configuration for memory storage (process before uploading to cloud)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB max
    files: 10, // Max 10 files per request
  },
  fileFilter: (req, file, cb) => {
    const allowedMimeTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'image/heic',
      'image/heif',
      'video/mp4',
      'video/quicktime',
      'video/x-m4v',
      'application/pdf',
      'audio/mpeg',
      'audio/mp4',
      'audio/wav',
    ];

    if (allowedMimeTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`File type ${file.mimetype} not allowed`));
    }
  },
});

// Single file upload
router.post('/single',
  authenticate,
  upload.single('file'),
  uploadController.uploadSingle
);

// Multiple file upload
router.post('/multiple',
  authenticate,
  upload.array('files', 10),
  uploadController.uploadMultiple
);

// Get upload URL for direct client upload
router.post('/presigned-url',
  authenticate,
  uploadController.getPresignedUrl
);

// Complete multipart upload
router.post('/complete-multipart',
  authenticate,
  uploadController.completeMultipartUpload
);

// Resumable upload initiation
router.post('/resumable/init',
  authenticate,
  requireFeature('large_file_uploads'),
  uploadController.initResumableUpload
);

// Resumable upload chunk
router.put('/resumable/:uploadId/chunk',
  authenticate,
  uploadController.uploadChunk
);

// Complete resumable upload
router.post('/resumable/:uploadId/complete',
  authenticate,
  uploadController.completeResumableUpload
);

// Get file info
router.get('/:fileId',
  authenticate,
  uploadController.getFileInfo
);

// Delete file
router.delete('/:fileId',
  authenticate,
  uploadController.deleteFile
);

export { router as uploadRouter };
```

### Upload Controller

```typescript
// src/controllers/uploadController.ts
import { Request, Response } from 'express';
import { z } from 'zod';
import { fileService } from '../services/fileService';
import { storageService } from '../services/storageService';
import { imageProcessingService } from '../services/imageProcessingService';
import { authorizationService } from '../services/authorizationService';
import { ApiResponseBuilder } from '../utils/response';
import { AppError, ErrorCodes } from '../errors/AppError';

const PresignedUrlSchema = z.object({
  filename: z.string(),
  contentType: z.string(),
  size: z.number().positive(),
  category: z.enum(['avatar', 'post', 'document', 'video']).default('post'),
});

export const uploadController = {
  // Upload single file
  async uploadSingle(req: Request, res: Response) {
    const file = req.file;

    if (!file) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'No file provided', 400);
    }

    // Check storage quota
    await checkStorageQuota(req.user.id, file.size);

    // Process and upload file
    const result = await fileService.processAndUpload({
      buffer: file.buffer,
      originalName: file.originalname,
      mimeType: file.mimetype,
      userId: req.user.id,
      category: req.body.category || 'post',
    });

    ApiResponseBuilder.success({
      file: result,
    }).send(res, 201);
  },

  // Upload multiple files
  async uploadMultiple(req: Request, res: Response) {
    const files = req.files as Express.Multer.File[];

    if (!files || files.length === 0) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'No files provided', 400);
    }

    // Check total size
    const totalSize = files.reduce((sum, f) => sum + f.size, 0);
    await checkStorageQuota(req.user.id, totalSize);

    // Process all files in parallel
    const results = await Promise.all(
      files.map(file =>
        fileService.processAndUpload({
          buffer: file.buffer,
          originalName: file.originalname,
          mimeType: file.mimetype,
          userId: req.user.id,
          category: req.body.category || 'post',
        })
      )
    );

    ApiResponseBuilder.success({
      files: results,
    }).send(res, 201);
  },

  // Get presigned URL for direct upload
  async getPresignedUrl(req: Request, res: Response) {
    const { filename, contentType, size, category } = PresignedUrlSchema.parse(req.body);

    // Check storage quota
    await checkStorageQuota(req.user.id, size);

    // Generate presigned URL
    const { uploadUrl, fileId, fields } = await storageService.generatePresignedUpload({
      filename,
      contentType,
      size,
      userId: req.user.id,
      category,
    });

    ApiResponseBuilder.success({
      uploadUrl,
      fileId,
      fields,
      expiresIn: 3600, // 1 hour
    }).send(res);
  },

  // Initialize resumable upload
  async initResumableUpload(req: Request, res: Response) {
    const { filename, contentType, size } = req.body;

    await checkStorageQuota(req.user.id, size);

    const { uploadId, chunkSize, totalChunks } = await fileService.initResumableUpload({
      filename,
      contentType,
      size,
      userId: req.user.id,
    });

    ApiResponseBuilder.success({
      uploadId,
      chunkSize,
      totalChunks,
    }).send(res);
  },

  // Upload chunk for resumable upload
  async uploadChunk(req: Request, res: Response) {
    const { uploadId } = req.params;
    const chunkNumber = parseInt(req.headers['x-chunk-number'] as string);
    const totalChunks = parseInt(req.headers['x-total-chunks'] as string);

    const chunks: Buffer[] = [];

    req.on('data', (chunk: Buffer) => {
      chunks.push(chunk);
    });

    req.on('end', async () => {
      const buffer = Buffer.concat(chunks);

      await fileService.uploadChunk({
        uploadId,
        chunkNumber,
        totalChunks,
        buffer,
        userId: req.user.id,
      });

      ApiResponseBuilder.success({
        chunkNumber,
        received: buffer.length,
      }).send(res);
    });
  },

  // Complete resumable upload
  async completeResumableUpload(req: Request, res: Response) {
    const { uploadId } = req.params;

    const file = await fileService.completeResumableUpload({
      uploadId,
      userId: req.user.id,
    });

    ApiResponseBuilder.success({ file }).send(res);
  },

  // Get file info
  async getFileInfo(req: Request, res: Response) {
    const { fileId } = req.params;

    const file = await fileService.getFileById(fileId);

    if (!file) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'File not found', 404);
    }

    // Check access
    if (file.user_id !== req.user.id && !file.is_public) {
      throw new AppError(ErrorCodes.ACCESS_DENIED, 'Access denied', 403);
    }

    ApiResponseBuilder.success({ file }).send(res);
  },

  // Delete file
  async deleteFile(req: Request, res: Response) {
    const { fileId } = req.params;

    const file = await fileService.getFileById(fileId);

    if (!file) {
      throw new AppError(ErrorCodes.RESOURCE_NOT_FOUND, 'File not found', 404);
    }

    if (file.user_id !== req.user.id) {
      throw new AppError(ErrorCodes.ACCESS_DENIED, 'Access denied', 403);
    }

    await fileService.deleteFile(fileId);

    ApiResponseBuilder.success({ message: 'File deleted' }).send(res);
  },
};

async function checkStorageQuota(userId: string, additionalBytes: number) {
  const result = await authorizationService.checkLimit(
    userId,
    'storage_mb',
    await fileService.getUserStorageUsageMB(userId) + (additionalBytes / 1024 / 1024)
  );

  if (!result.allowed) {
    throw new AppError(
      ErrorCodes.SUBSCRIPTION_REQUIRED,
      `Storage limit exceeded. Current: ${Math.round(result.limit - result.remaining)}MB / ${result.limit}MB`,
      403,
      { currentUsage: result.limit - result.remaining, limit: result.limit }
    );
  }
}
```

## File Processing Service

```typescript
// src/services/fileService.ts
import { v4 as uuidv4 } from 'uuid';
import path from 'path';
import { db } from '../database';
import { redis } from '../cache/redis';
import { storageService } from './storageService';
import { imageProcessingService } from './imageProcessingService';
import { videoProcessingService } from './videoProcessingService';
import { queueService } from './queueService';

interface ProcessAndUploadOptions {
  buffer: Buffer;
  originalName: string;
  mimeType: string;
  userId: string;
  category: string;
}

interface FileRecord {
  id: string;
  user_id: string;
  original_name: string;
  storage_key: string;
  mime_type: string;
  size: number;
  category: string;
  variants: Record<string, string>;
  metadata: Record<string, unknown>;
  is_public: boolean;
  cdn_url: string;
  created_at: Date;
}

export class FileService {
  async processAndUpload(options: ProcessAndUploadOptions): Promise<FileRecord> {
    const { buffer, originalName, mimeType, userId, category } = options;

    const fileId = uuidv4();
    const extension = path.extname(originalName).toLowerCase();
    const storageKey = this.generateStorageKey(userId, fileId, extension);

    let processedBuffer = buffer;
    let variants: Record<string, string> = {};
    let metadata: Record<string, unknown> = {};

    // Process based on file type
    if (mimeType.startsWith('image/')) {
      const result = await imageProcessingService.processImage({
        buffer,
        fileId,
        userId,
        category,
      });
      processedBuffer = result.optimizedBuffer;
      variants = result.variants;
      metadata = result.metadata;
    } else if (mimeType.startsWith('video/')) {
      // Queue video processing (async)
      await queueService.addJob('video-processing', {
        fileId,
        userId,
        storageKey,
        mimeType,
      });
      metadata = { processing: true };
    }

    // Upload to cloud storage
    const uploadResult = await storageService.upload({
      key: storageKey,
      buffer: processedBuffer,
      contentType: mimeType,
      metadata: {
        userId,
        originalName,
        category,
      },
    });

    // Save to database
    const [file] = await db('files')
      .insert({
        id: fileId,
        user_id: userId,
        original_name: originalName,
        storage_key: storageKey,
        mime_type: mimeType,
        size: buffer.length,
        category,
        variants,
        metadata,
        is_public: category !== 'document',
        cdn_url: uploadResult.cdnUrl,
      })
      .returning('*');

    return file;
  }

  async initResumableUpload(options: {
    filename: string;
    contentType: string;
    size: number;
    userId: string;
  }) {
    const uploadId = uuidv4();
    const chunkSize = 5 * 1024 * 1024; // 5MB chunks
    const totalChunks = Math.ceil(options.size / chunkSize);

    // Store upload state in Redis
    await redis.hset(`upload:${uploadId}`, {
      filename: options.filename,
      contentType: options.contentType,
      size: options.size.toString(),
      userId: options.userId,
      totalChunks: totalChunks.toString(),
      uploadedChunks: '0',
      status: 'pending',
      createdAt: Date.now().toString(),
    });

    // Set expiry (24 hours)
    await redis.expire(`upload:${uploadId}`, 86400);

    return { uploadId, chunkSize, totalChunks };
  }

  async uploadChunk(options: {
    uploadId: string;
    chunkNumber: number;
    totalChunks: number;
    buffer: Buffer;
    userId: string;
  }) {
    const uploadKey = `upload:${options.uploadId}`;

    // Verify upload exists and belongs to user
    const uploadData = await redis.hgetall(uploadKey);

    if (!uploadData || Object.keys(uploadData).length === 0) {
      throw new Error('Upload not found');
    }

    if (uploadData.userId !== options.userId) {
      throw new Error('Unauthorized');
    }

    // Store chunk
    const chunkKey = `${uploadKey}:chunk:${options.chunkNumber}`;
    await redis.setex(chunkKey, 86400, options.buffer.toString('base64'));

    // Update progress
    await redis.hincrby(uploadKey, 'uploadedChunks', 1);
  }

  async completeResumableUpload(options: {
    uploadId: string;
    userId: string;
  }): Promise<FileRecord> {
    const uploadKey = `upload:${options.uploadId}`;
    const uploadData = await redis.hgetall(uploadKey);

    if (!uploadData || uploadData.userId !== options.userId) {
      throw new Error('Upload not found');
    }

    const totalChunks = parseInt(uploadData.totalChunks);
    const uploadedChunks = parseInt(uploadData.uploadedChunks);

    if (uploadedChunks < totalChunks) {
      throw new Error(`Missing chunks: ${uploadedChunks}/${totalChunks}`);
    }

    // Reassemble file
    const chunks: Buffer[] = [];
    for (let i = 0; i < totalChunks; i++) {
      const chunkKey = `${uploadKey}:chunk:${i}`;
      const chunkData = await redis.get(chunkKey);
      if (!chunkData) {
        throw new Error(`Chunk ${i} missing`);
      }
      chunks.push(Buffer.from(chunkData, 'base64'));
    }

    const fileBuffer = Buffer.concat(chunks);

    // Process and upload
    const file = await this.processAndUpload({
      buffer: fileBuffer,
      originalName: uploadData.filename,
      mimeType: uploadData.contentType,
      userId: options.userId,
      category: 'post',
    });

    // Cleanup Redis keys
    const keysToDelete = [`upload:${options.uploadId}`];
    for (let i = 0; i < totalChunks; i++) {
      keysToDelete.push(`${uploadKey}:chunk:${i}`);
    }
    await redis.del(...keysToDelete);

    return file;
  }

  async getFileById(fileId: string): Promise<FileRecord | null> {
    return db('files').where('id', fileId).first();
  }

  async deleteFile(fileId: string): Promise<void> {
    const file = await this.getFileById(fileId);

    if (!file) return;

    // Delete from storage
    await storageService.delete(file.storage_key);

    // Delete variants
    for (const variantKey of Object.values(file.variants)) {
      await storageService.delete(variantKey);
    }

    // Delete from database
    await db('files').where('id', fileId).delete();
  }

  async getUserStorageUsageMB(userId: string): Promise<number> {
    const result = await db('files')
      .where('user_id', userId)
      .sum('size as total');

    return (result[0]?.total || 0) / 1024 / 1024;
  }

  private generateStorageKey(userId: string, fileId: string, extension: string): string {
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');

    return `uploads/${userId}/${year}/${month}/${fileId}${extension}`;
  }
}

export const fileService = new FileService();
```

## Image Processing Service

```typescript
// src/services/imageProcessingService.ts
import sharp from 'sharp';
import { storageService } from './storageService';

interface ImageProcessingResult {
  optimizedBuffer: Buffer;
  variants: Record<string, string>;
  metadata: {
    width: number;
    height: number;
    format: string;
    hasAlpha: boolean;
  };
}

interface VariantConfig {
  name: string;
  width: number;
  height?: number;
  quality: number;
  fit: 'cover' | 'contain' | 'fill' | 'inside' | 'outside';
}

const VARIANT_CONFIGS: Record<string, VariantConfig[]> = {
  avatar: [
    { name: 'small', width: 50, height: 50, quality: 80, fit: 'cover' },
    { name: 'medium', width: 150, height: 150, quality: 85, fit: 'cover' },
    { name: 'large', width: 300, height: 300, quality: 90, fit: 'cover' },
  ],
  post: [
    { name: 'thumbnail', width: 200, height: 200, quality: 75, fit: 'cover' },
    { name: 'small', width: 400, quality: 80, fit: 'inside' },
    { name: 'medium', width: 800, quality: 85, fit: 'inside' },
    { name: 'large', width: 1200, quality: 90, fit: 'inside' },
  ],
  cover: [
    { name: 'small', width: 640, height: 360, quality: 80, fit: 'cover' },
    { name: 'large', width: 1920, height: 1080, quality: 90, fit: 'cover' },
  ],
};

export class ImageProcessingService {
  async processImage(options: {
    buffer: Buffer;
    fileId: string;
    userId: string;
    category: string;
  }): Promise<ImageProcessingResult> {
    const { buffer, fileId, userId, category } = options;

    // Get image metadata
    const image = sharp(buffer);
    const metadata = await image.metadata();

    // Convert HEIC/HEIF to JPEG
    let processedImage = image;
    let outputFormat: 'jpeg' | 'png' | 'webp' = 'jpeg';

    if (metadata.format === 'heif' || metadata.format === 'heic') {
      processedImage = image.toFormat('jpeg');
    } else if (metadata.hasAlpha) {
      outputFormat = 'png';
    }

    // Strip EXIF data (privacy) but preserve orientation
    processedImage = processedImage.rotate(); // Auto-rotate based on EXIF

    // Optimize original
    const optimizedBuffer = await processedImage
      .toFormat(outputFormat, {
        quality: 90,
        mozjpeg: outputFormat === 'jpeg',
      })
      .toBuffer();

    // Generate variants
    const variants: Record<string, string> = {};
    const variantConfigs = VARIANT_CONFIGS[category] || VARIANT_CONFIGS.post;

    await Promise.all(
      variantConfigs.map(async (config) => {
        const variantBuffer = await this.generateVariant(buffer, config, outputFormat);
        const variantKey = `uploads/${userId}/variants/${fileId}_${config.name}.${outputFormat}`;

        await storageService.upload({
          key: variantKey,
          buffer: variantBuffer,
          contentType: `image/${outputFormat}`,
          metadata: { variant: config.name },
        });

        variants[config.name] = variantKey;
      })
    );

    return {
      optimizedBuffer,
      variants,
      metadata: {
        width: metadata.width || 0,
        height: metadata.height || 0,
        format: outputFormat,
        hasAlpha: metadata.hasAlpha || false,
      },
    };
  }

  private async generateVariant(
    buffer: Buffer,
    config: VariantConfig,
    format: 'jpeg' | 'png' | 'webp'
  ): Promise<Buffer> {
    let image = sharp(buffer).rotate();

    image = image.resize(config.width, config.height, {
      fit: config.fit,
      withoutEnlargement: true,
    });

    return image
      .toFormat(format, {
        quality: config.quality,
        mozjpeg: format === 'jpeg',
      })
      .toBuffer();
  }

  // Generate blur placeholder for progressive loading
  async generateBlurPlaceholder(buffer: Buffer): Promise<string> {
    const placeholder = await sharp(buffer)
      .resize(10, 10, { fit: 'inside' })
      .blur(1)
      .toFormat('jpeg', { quality: 50 })
      .toBuffer();

    return `data:image/jpeg;base64,${placeholder.toString('base64')}`;
  }
}

export const imageProcessingService = new ImageProcessingService();
```

## Video Processing Service

```typescript
// src/services/videoProcessingService.ts
import ffmpeg from 'fluent-ffmpeg';
import { PassThrough } from 'stream';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import { v4 as uuidv4 } from 'uuid';
import { storageService } from './storageService';
import { db } from '../database';

interface VideoProcessingJob {
  fileId: string;
  userId: string;
  storageKey: string;
  mimeType: string;
}

interface VideoMetadata {
  duration: number;
  width: number;
  height: number;
  bitrate: number;
  codec: string;
  fps: number;
}

export class VideoProcessingService {
  private readonly tempDir = path.join(os.tmpdir(), 'video-processing');

  async processVideo(job: VideoProcessingJob): Promise<void> {
    const { fileId, userId, storageKey } = job;

    try {
      // Update status to processing
      await db('files')
        .where('id', fileId)
        .update({
          metadata: db.raw("metadata || ?::jsonb", [JSON.stringify({ processing: true })]),
        });

      // Download video to temp
      const tempInputPath = path.join(this.tempDir, `${fileId}_input`);
      await fs.mkdir(this.tempDir, { recursive: true });

      const videoBuffer = await storageService.download(storageKey);
      await fs.writeFile(tempInputPath, videoBuffer);

      // Get video metadata
      const metadata = await this.getVideoMetadata(tempInputPath);

      // Generate thumbnail
      const thumbnailPath = path.join(this.tempDir, `${fileId}_thumb.jpg`);
      await this.generateThumbnail(tempInputPath, thumbnailPath);

      const thumbnailBuffer = await fs.readFile(thumbnailPath);
      const thumbnailKey = `uploads/${userId}/thumbnails/${fileId}.jpg`;

      await storageService.upload({
        key: thumbnailKey,
        buffer: thumbnailBuffer,
        contentType: 'image/jpeg',
      });

      // Generate HLS variants for adaptive streaming (optional)
      const hlsVariants = await this.generateHLSVariants(tempInputPath, fileId, userId);

      // Update file record
      await db('files')
        .where('id', fileId)
        .update({
          variants: { thumbnail: thumbnailKey, ...hlsVariants },
          metadata: {
            processing: false,
            processed: true,
            duration: metadata.duration,
            width: metadata.width,
            height: metadata.height,
            fps: metadata.fps,
          },
        });

      // Cleanup temp files
      await this.cleanup(tempInputPath, thumbnailPath);
    } catch (error) {
      // Update status to failed
      await db('files')
        .where('id', fileId)
        .update({
          metadata: db.raw("metadata || ?::jsonb", [
            JSON.stringify({ processing: false, error: error.message }),
          ]),
        });

      throw error;
    }
  }

  private getVideoMetadata(filePath: string): Promise<VideoMetadata> {
    return new Promise((resolve, reject) => {
      ffmpeg.ffprobe(filePath, (err, data) => {
        if (err) {
          reject(err);
          return;
        }

        const videoStream = data.streams.find(s => s.codec_type === 'video');

        if (!videoStream) {
          reject(new Error('No video stream found'));
          return;
        }

        resolve({
          duration: data.format.duration || 0,
          width: videoStream.width || 0,
          height: videoStream.height || 0,
          bitrate: parseInt(data.format.bit_rate || '0'),
          codec: videoStream.codec_name || 'unknown',
          fps: eval(videoStream.r_frame_rate || '0') || 0,
        });
      });
    });
  }

  private generateThumbnail(inputPath: string, outputPath: string): Promise<void> {
    return new Promise((resolve, reject) => {
      ffmpeg(inputPath)
        .screenshots({
          timestamps: ['10%'], // Capture at 10% of video
          filename: path.basename(outputPath),
          folder: path.dirname(outputPath),
          size: '640x360',
        })
        .on('end', resolve)
        .on('error', reject);
    });
  }

  private async generateHLSVariants(
    inputPath: string,
    fileId: string,
    userId: string
  ): Promise<Record<string, string>> {
    const variants: Record<string, string> = {};
    const hlsDir = path.join(this.tempDir, `${fileId}_hls`);
    await fs.mkdir(hlsDir, { recursive: true });

    // Generate different quality levels
    const qualities = [
      { name: '360p', width: 640, height: 360, bitrate: '800k' },
      { name: '720p', width: 1280, height: 720, bitrate: '2500k' },
      { name: '1080p', width: 1920, height: 1080, bitrate: '5000k' },
    ];

    for (const quality of qualities) {
      const outputPath = path.join(hlsDir, `${quality.name}.m3u8`);

      await this.transcodeToHLS(inputPath, outputPath, quality);

      // Upload HLS files
      const hlsFiles = await fs.readdir(hlsDir);
      for (const file of hlsFiles.filter(f => f.startsWith(quality.name))) {
        const fileBuffer = await fs.readFile(path.join(hlsDir, file));
        const key = `uploads/${userId}/hls/${fileId}/${file}`;

        await storageService.upload({
          key,
          buffer: fileBuffer,
          contentType: file.endsWith('.m3u8') ? 'application/x-mpegURL' : 'video/MP2T',
        });

        if (file.endsWith('.m3u8')) {
          variants[quality.name] = key;
        }
      }
    }

    return variants;
  }

  private transcodeToHLS(
    inputPath: string,
    outputPath: string,
    quality: { width: number; height: number; bitrate: string }
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      ffmpeg(inputPath)
        .outputOptions([
          '-c:v h264',
          `-b:v ${quality.bitrate}`,
          '-c:a aac',
          '-b:a 128k',
          `-vf scale=${quality.width}:${quality.height}`,
          '-hls_time 10',
          '-hls_list_size 0',
          '-hls_segment_filename',
          path.join(path.dirname(outputPath), `${path.basename(outputPath, '.m3u8')}_%03d.ts`),
        ])
        .output(outputPath)
        .on('end', resolve)
        .on('error', reject)
        .run();
    });
  }

  private async cleanup(...paths: string[]): Promise<void> {
    for (const p of paths) {
      try {
        await fs.unlink(p);
      } catch {
        // Ignore cleanup errors
      }
    }
  }
}

export const videoProcessingService = new VideoProcessingService();
```

## Cloud Storage Service

```typescript
// src/services/storageService.ts
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  CreateMultipartUploadCommand,
  UploadPartCommand,
  CompleteMultipartUploadCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { getSignedUrl as getCloudfrontSignedUrl } from '@aws-sdk/cloudfront-signer';
import { config } from '../config';

interface UploadOptions {
  key: string;
  buffer: Buffer;
  contentType: string;
  metadata?: Record<string, string>;
  isPublic?: boolean;
}

interface PresignedUploadOptions {
  filename: string;
  contentType: string;
  size: number;
  userId: string;
  category: string;
}

export class StorageService {
  private s3Client: S3Client;
  private bucket: string;
  private cdnDomain: string;

  constructor() {
    this.s3Client = new S3Client({
      region: config.AWS_REGION,
      credentials: {
        accessKeyId: config.AWS_ACCESS_KEY_ID!,
        secretAccessKey: config.AWS_SECRET_ACCESS_KEY!,
      },
    });

    this.bucket = config.S3_BUCKET!;
    this.cdnDomain = config.CDN_DOMAIN!;
  }

  async upload(options: UploadOptions): Promise<{ key: string; cdnUrl: string }> {
    const { key, buffer, contentType, metadata, isPublic = true } = options;

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      Body: buffer,
      ContentType: contentType,
      Metadata: metadata,
      CacheControl: 'public, max-age=31536000', // 1 year
    });

    await this.s3Client.send(command);

    return {
      key,
      cdnUrl: `https://${this.cdnDomain}/${key}`,
    };
  }

  async download(key: string): Promise<Buffer> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });

    const response = await this.s3Client.send(command);
    const chunks: Uint8Array[] = [];

    for await (const chunk of response.Body as any) {
      chunks.push(chunk);
    }

    return Buffer.concat(chunks);
  }

  async delete(key: string): Promise<void> {
    const command = new DeleteObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });

    await this.s3Client.send(command);
  }

  async generatePresignedUpload(options: PresignedUploadOptions): Promise<{
    uploadUrl: string;
    fileId: string;
    fields: Record<string, string>;
  }> {
    const fileId = uuidv4();
    const extension = path.extname(options.filename);
    const key = `uploads/${options.userId}/${fileId}${extension}`;

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: options.contentType,
      Metadata: {
        userId: options.userId,
        originalName: options.filename,
        category: options.category,
      },
    });

    const uploadUrl = await getSignedUrl(this.s3Client, command, {
      expiresIn: 3600, // 1 hour
    });

    return {
      uploadUrl,
      fileId,
      fields: {
        key,
        'Content-Type': options.contentType,
      },
    };
  }

  // Generate signed URL for private files
  async getSignedDownloadUrl(key: string, expiresIn: number = 3600): Promise<string> {
    // Use CloudFront signed URL for better caching
    if (config.CLOUDFRONT_KEY_PAIR_ID) {
      return getCloudfrontSignedUrl({
        url: `https://${this.cdnDomain}/${key}`,
        keyPairId: config.CLOUDFRONT_KEY_PAIR_ID,
        privateKey: config.CLOUDFRONT_PRIVATE_KEY!,
        dateLessThan: new Date(Date.now() + expiresIn * 1000).toISOString(),
      });
    }

    // Fallback to S3 presigned URL
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });

    return getSignedUrl(this.s3Client, command, { expiresIn });
  }

  // Multipart upload for large files
  async initiateMultipartUpload(
    key: string,
    contentType: string
  ): Promise<string> {
    const command = new CreateMultipartUploadCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });

    const response = await this.s3Client.send(command);
    return response.UploadId!;
  }

  async uploadPart(
    key: string,
    uploadId: string,
    partNumber: number,
    buffer: Buffer
  ): Promise<{ ETag: string; PartNumber: number }> {
    const command = new UploadPartCommand({
      Bucket: this.bucket,
      Key: key,
      UploadId: uploadId,
      PartNumber: partNumber,
      Body: buffer,
    });

    const response = await this.s3Client.send(command);

    return {
      ETag: response.ETag!,
      PartNumber: partNumber,
    };
  }

  async completeMultipartUpload(
    key: string,
    uploadId: string,
    parts: { ETag: string; PartNumber: number }[]
  ): Promise<void> {
    const command = new CompleteMultipartUploadCommand({
      Bucket: this.bucket,
      Key: key,
      UploadId: uploadId,
      MultipartUpload: { Parts: parts },
    });

    await this.s3Client.send(command);
  }
}

export const storageService = new StorageService();
```

## CDN Configuration

```typescript
// infrastructure/cloudfront.tf
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = ""
  price_class         = "PriceClass_100"

  aliases = [var.cdn_domain]

  origin {
    domain_name = aws_s3_bucket.uploads.bucket_regional_domain_name
    origin_id   = "S3-uploads"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-uploads"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  # Cache behavior for images
  ordered_cache_behavior {
    path_pattern     = "uploads/*/variants/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-uploads"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 31536000
    default_ttl            = 31536000
    max_ttl                = 31536000
    compress               = true
  }

  # Cache behavior for video HLS
  ordered_cache_behavior {
    path_pattern     = "uploads/*/hls/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-uploads"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
      headers = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 86400
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.cdn_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "mobile-backend-cdn"
  }
}
```

## Gate Criteria

Before marking file handling complete, verify:

### Upload Gates
- [ ] Single file upload working
- [ ] Multiple file upload working
- [ ] File size limits enforced
- [ ] File type validation working
- [ ] Resumable upload implemented
- [ ] Presigned URL generation working

### Processing Gates
- [ ] Image resizing working
- [ ] HEIC/HEIF conversion working
- [ ] EXIF data stripped (privacy)
- [ ] Image variants generated
- [ ] Video thumbnail generation working
- [ ] Video transcoding working (if applicable)

### Storage Gates
- [ ] Files uploaded to cloud storage
- [ ] File metadata stored in database
- [ ] Storage quota enforced
- [ ] File deletion removes all variants
- [ ] Temp files cleaned up

### CDN Gates
- [ ] CDN configured for public files
- [ ] Signed URLs for private files
- [ ] Appropriate cache headers set
- [ ] Compression enabled
- [ ] CORS configured for video

### Security Gates
- [ ] Authentication required for uploads
- [ ] File ownership verified
- [ ] Malware scanning (if applicable)
- [ ] No directory traversal vulnerabilities
- [ ] Content-Type validated server-side

### Mobile Optimization Gates
- [ ] Multiple image sizes available
- [ ] Blur placeholder for progressive loading
- [ ] Efficient upload for slow connections
- [ ] Upload progress trackable
- [ ] Offline queue support documented
