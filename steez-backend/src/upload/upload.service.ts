import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { GoogleLensService } from '../google-lens/google-lens.service';
import { ProductLinkDto } from '../google-lens/dto';
import * as fs from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { ConfigService } from '@nestjs/config';

export interface ProcessResult {
  success: boolean;
  message: string;
  error?: string;
  data: {
    filename: string;
    originalName: string;
    size: number;
    userId: string;
    uploadedAt: string;
    imageUrl: string;
    products?: ProductLinkDto[];
    processingPipeline?: 'lens';
  };
}

@Injectable()
export class UploadService {
  private readonly logger = new Logger(UploadService.name);
  private readonly uploadsDir = path.join(__dirname, '..', '..', 'uploads');
  private readonly baseUrl: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly googleLensService: GoogleLensService,
  ) {
    // Ensure uploads directory exists
    if (!fs.existsSync(this.uploadsDir)) {
      this.logger.log(`Creating uploads directory: ${this.uploadsDir}`);
      fs.mkdirSync(this.uploadsDir, { recursive: true });
    }

    // Get base URL from config or use default localhost URL
    this.baseUrl =
      this.configService.get<string>('BASE_URL') || 'http://localhost:3000';
  }

  async processUploadedImage(
    file: Express.Multer.File,
    userId: string,
    user?: { size: string; country: string },
  ): Promise<ProcessResult> {
    // Now process directly with Google Lens (no segmentation)
    // Handle case where file doesn't have filename or path (Multer didn't save it)
    let savedFilename: string;
    let filePath: string;

    if (file.filename && file.path) {
      savedFilename = file.filename;
      filePath = file.path;
    } else {
      savedFilename = `${uuidv4()}${path.extname(file.originalname)}`;
      filePath = path.join(this.uploadsDir, savedFilename);
      fs.writeFileSync(filePath, file.buffer);
    }

    if (!fs.existsSync(filePath)) {
      throw new NotFoundException(`File not found on disk`);
    }

    const imageUrl = `${this.baseUrl}/uploads/${savedFilename}`;

    try {
      const products = await this.googleLensService.analyzeUploadedImage(savedFilename);
      return {
        success: true,
        message: 'Image processed successfully with Google Lens',
        data: {
          filename: savedFilename,
          originalName: file.originalname,
          size: file.size,
          userId,
          uploadedAt: new Date().toISOString(),
          imageUrl,
          products,
          processingPipeline: 'lens',
        },
      };
    } catch (error: any) {
      this.logger.error(`Error processing image with Lens: ${error.message}`, error.stack);
      return {
        success: false,
        message: 'Image upload succeeded but Google Lens processing failed',
        error: error.message,
        data: {
          filename: savedFilename,
          originalName: file.originalname,
          size: file.size,
          userId,
          uploadedAt: new Date().toISOString(),
          imageUrl,
          processingPipeline: 'lens',
        },
      };
    }
  }

  /**
   * NEW SEGMENTATION PIPELINE: Process image using YOLO + Google Lens
   */
  // Segmentation path disabled for now - method removed

  /**
   * Legacy endpoint now delegates to segmentation to ensure a single pipeline
   */
  async processUploadedImageLegacy(
    file: Express.Multer.File,
    userId: string,
    user?: { size: string; country: string },
  ): Promise<ProcessResult> {
    // Delegate to direct Lens processing
    return this.processUploadedImage(file, userId, user);
  }

  /**
   * Health check for segmentation service
   */
  async checkSegmentationServiceHealth(): Promise<boolean> {
    // Segmentation disabled: report healthy=false without calling the service
    return false;
  }
}
