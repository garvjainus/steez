import { 
  Controller, 
  Post, 
  UseInterceptors, 
  UploadedFile,
  Body,
  HttpException,
  HttpStatus,
  Logger
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Express } from 'express';
import * as fs from 'fs';
import { UploadService } from './upload.service';
import { MulterOptions } from '@nestjs/platform-express/multer/interfaces/multer-options.interface';

@Controller('upload')
export class UploadController {
  private readonly logger = new Logger(UploadController.name);

  constructor(private readonly uploadService: UploadService) {}

  @Post('image')
  @UseInterceptors(FileInterceptor('image'))
  async uploadImage(
    @UploadedFile() file: Express.Multer.File,
    @Body('userId') userId: string,
  ) {
    this.logger.debug(`[uploadImage] File received: ${file ? 'Yes' : 'No'}`);
    
    if (!file) {
      this.logger.error('[uploadImage] No file received in request');
      throw new HttpException('Image file is required', HttpStatus.BAD_REQUEST);
    }

    this.logger.debug(`[uploadImage] File details:
      - originalname: ${file.originalname}
      - filename: ${file.filename || 'UNDEFINED'}
      - mimetype: ${file.mimetype}
      - size: ${file.size}
      - path: ${file.path || 'UNDEFINED'}
      - buffer: ${file.buffer ? 'Available' : 'Not Available'}
    `);

    if (file.path) {
      const fileExists = fs.existsSync(file.path);
      this.logger.debug(`[uploadImage] File exists on disk: ${fileExists}`);
    } else {
      this.logger.warn('[uploadImage] No file.path property available');
    }

    if (!userId) {
      this.logger.error('[uploadImage] No userId received in request');
      throw new HttpException('User ID is required', HttpStatus.BAD_REQUEST);
    }

    try {
      const result = await this.uploadService.processUploadedImage(file, userId);
      this.logger.debug(`[uploadImage] Image processed successfully: ${JSON.stringify(result)}`);
      return result;
    } catch (error) {
      this.logger.error(`[uploadImage] Error processing upload: ${error.message}`, error.stack);
      throw new HttpException(
        error.message || 'Failed to upload image',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('image-base64')
  async uploadBase64Image(
    @Body('image') base64Image: string,
    @Body('userId') userId: string,
  ) {
    if (!base64Image) {
      throw new HttpException('Base64 image is required', HttpStatus.BAD_REQUEST);
    }

    if (!userId) {
      throw new HttpException('User ID is required', HttpStatus.BAD_REQUEST);
    }

    try {
      // Just return basic information for now
      // Processing logic will be added later
      return {
        success: true,
        message: 'Base64 image received successfully',
        data: {
          userId: userId,
          imageSize: base64Image.length,
          uploadedAt: new Date().toISOString(),
        }
      };
    } catch (error) {
      throw new HttpException(
        error.message || 'Failed to process base64 image',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
} 