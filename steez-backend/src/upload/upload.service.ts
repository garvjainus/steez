import { Injectable, Logger, NotFoundException } from '@nestjs/common';
// import { GoogleLensService } from '../google-lens/google-lens.service'; // 🔒 TEMP-DISABLED (Google Lens)
import { extractAndMatch, SegmentedResults } from '../services/geminiVision';
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
    segmentedResults?: SegmentedResults;
  };
}

@Injectable()
export class UploadService {
  private readonly logger = new Logger(UploadService.name);
  private readonly uploadsDir = path.join(__dirname, '..', '..', 'uploads');
  private readonly baseUrl: string;

  constructor(
    // private readonly googleLensService: GoogleLensService, // 🔒 TEMP-DISABLED (Google Lens)
    private readonly configService: ConfigService,
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
    this.logger.debug(`Processing uploaded image for user: ${userId}`);

    // Handle case where file doesn't have filename or path (Multer didn't save it)
    let savedFilename: string;
    let filePath: string;

    if (!file.filename || !file.path) {
      this.logger.warn('File was not saved by Multer, saving it manually');

      // Generate a filename using UUID
      const fileExt = path.extname(file.originalname);
      savedFilename = `${uuidv4()}${fileExt}`;
      filePath = path.join(this.uploadsDir, savedFilename);

      // Save the file manually
      try {
        fs.writeFileSync(filePath, file.buffer);
        this.logger.debug(`Manually saved file to: ${filePath}`);
      } catch (error: any) {
        this.logger.error(`Failed to save file: ${error.message}`, error.stack);
        throw new Error(`Failed to save uploaded file: ${error.message}`);
      }
    } else {
      savedFilename = file.filename;
      filePath = file.path;
    }

    // Verify file exists on disk
    if (!fs.existsSync(filePath)) {
      this.logger.error(`File does not exist on disk: ${filePath}`);
      throw new NotFoundException(`File not found on disk`);
    }

    this.logger.debug(`File exists on disk at: ${filePath}`);

    // Create image URL that points to the static file
    const imageUrl = `${this.baseUrl}/uploads/${savedFilename}`;
    this.logger.debug(`Image URL: ${imageUrl}`);

    // Process the image with Gemini Vision and eBay
    try {
      // Convert image file to base64
      const imageBuffer = fs.readFileSync(filePath);
      const base64Image = imageBuffer.toString('base64');

      const userSize = user?.size || 'M';
      const userCountry = user?.country || 'US';

      const segmentedResults = await extractAndMatch(base64Image, userSize, userCountry);
      this.logger.log(
        `Successfully processed image. Found ${segmentedResults.totalItems} clothing segments.`,
      );

      return {
        success: true,
        message: 'Image processed successfully',
        data: {
          filename: savedFilename,
          originalName: file.originalname,
          size: file.size,
          userId: userId,
          uploadedAt: new Date().toISOString(),
          imageUrl: imageUrl,
          segmentedResults: segmentedResults,
        },
      };
    } catch (error: any) {
      this.logger.error(
        `Error processing image: ${error.message}`,
        error.stack,
      );
      return {
        success: false,
        message: 'Image upload succeeded but processing failed',
        error: error.message,
        data: {
          filename: savedFilename,
          originalName: file.originalname,
          size: file.size,
          userId: userId,
          uploadedAt: new Date().toISOString(),
          imageUrl: imageUrl,
        },
      };
    }
  }
}
