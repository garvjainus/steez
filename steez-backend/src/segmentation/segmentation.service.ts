import { HttpService } from '@nestjs/axios';
import { Injectable, Logger, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import * as fs from 'fs';
import * as path from 'path';
import * as FormData from 'form-data';
import { v4 as uuidv4 } from 'uuid';

import { GoogleLensService } from '../google-lens/google-lens.service';
import { ProductLinkDto } from '../google-lens/dto';
import {
  ClothingSegmentDto,
  SegmentationResponseDto,
  SegmentedClothingItem,
  NewSegmentedResults,
  SegmentationConfig,
  DEFAULT_SEGMENTATION_CONFIG,
} from './dto';

@Injectable()
export class SegmentationService {
  private readonly logger = new Logger(SegmentationService.name);
  private readonly segmentationServiceUrl: string;
  private readonly uploadsDir = path.join(__dirname, '..', '..', 'uploads');

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
    private readonly googleLensService: GoogleLensService,
  ) {
    // Configure segmentation service URL
    this.segmentationServiceUrl = this.configService.get<string>(
      'SEGMENTATION_SERVICE_URL',
      'http://localhost:8001'
    );
    
    this.logger.log(`Segmentation service URL: ${this.segmentationServiceUrl}`);
  }

  /**
   * Get headers with API key for segmentation service calls
   */
  private getSegmentationServiceHeaders(): Record<string, string> {
    const apiKey = this.configService.get<string>('SEGMENTATION_API_KEY');
    if (apiKey) {
      return { 'X-API-Key': apiKey };
    }
    this.logger.warn('SEGMENTATION_API_KEY not configured - requests may fail');
    return {};
  }

  /**
   * Main method: Process image with new segmentation pipeline
   * This replaces the Gemini + eBay approach
   */
  async processImageWithSegmentation(
    filePath: string,
    userId: string,
    config: Partial<SegmentationConfig> = {},
  ): Promise<NewSegmentedResults> {
    const startTime = Date.now();
    const fullConfig = { ...DEFAULT_SEGMENTATION_CONFIG, ...config };
    
    this.logger.log(`Starting segmentation processing for file: ${filePath}`);
    
    try {
      // Step 1: Segment clothing items using YOLO
      const segmentationResult = await this.segmentClothingItems(filePath);
      const segmentationTime = Date.now() - startTime;
      
      this.logger.log(
        `YOLO segmentation completed in ${segmentationTime}ms. Found ${segmentationResult.total_items} items.`
      );

      // Step 2: Process each segment with Google Lens (if enabled)
      const googleLensStartTime = Date.now();
      const processedSegments = await this.processSegmentsWithGoogleLens(
        segmentationResult.segments,
        fullConfig,
      );
      const googleLensTime = Date.now() - googleLensStartTime;

      // Step 3: Compile results
      const totalTime = Date.now() - startTime;
      const results = this.compileSegmentationResults(
        processedSegments,
        totalTime,
        segmentationTime,
        googleLensTime,
      );

      this.logger.log(
        `Segmentation pipeline completed in ${totalTime}ms. ` +
        `Segmentation: ${segmentationTime}ms, Google Lens: ${googleLensTime}ms. ` +
        `Found ${results.totalItems} items with ${this.countProductLinks(results)} total product links.`
      );

      return results;

    } catch (error) {
      this.logger.error(
        `Error in segmentation pipeline: ${error.message}`,
        error.stack,
      );
      throw new InternalServerErrorException(
        `Segmentation processing failed: ${error.message}`,
      );
    }
  }

  /**
   * Step 1: Call YOLO segmentation service
   */
  private async segmentClothingItems(filePath: string): Promise<SegmentationResponseDto> {
    try {
      // Verify file exists
      if (!fs.existsSync(filePath)) {
        throw new Error(`File not found: ${filePath}`);
      }

      // Create form data with the image file
      const form = new FormData();
      form.append('file', fs.createReadStream(filePath));

      // Call segmentation service
      const response = await firstValueFrom(
        this.httpService.post<SegmentationResponseDto>(
          `${this.segmentationServiceUrl}/segment`,
          form,
          {
            headers: {
              ...form.getHeaders(),
              ...this.getSegmentationServiceHeaders(), // Add API key
            },
            timeout: 30000, // 30 second timeout
          },
        ),
      );

      if (!response.data.success) {
        throw new Error(`Segmentation failed: ${response.data.message}`);
      }

      return response.data;

    } catch (error) {
      if (error.code === 'ECONNREFUSED') {
        throw new Error(
          `Cannot connect to segmentation service at ${this.segmentationServiceUrl}. ` +
          'Make sure the YOLO segmentation service is running.',
        );
      }
      throw error;
    }
  }

  /**
   * Step 2: Process each clothing segment with Google Lens
   */
  private async processSegmentsWithGoogleLens(
    segments: ClothingSegmentDto[],
    config: SegmentationConfig,
  ): Promise<SegmentedClothingItem[]> {
    if (!config.enableGoogleLens) {
      this.logger.log('Google Lens processing disabled, returning segments without product links');
      return segments.map(segment => this.convertToSegmentedItem(segment, []));
    }

    const processedSegments: SegmentedClothingItem[] = [];
    
    // Group segments by category to respect limits
    const segmentsByCategory = this.groupSegmentsByCategory(segments, config);

    for (const [category, categorySegments] of Object.entries(segmentsByCategory)) {
      this.logger.debug(`Processing ${categorySegments.length} ${category} segments`);

      for (const segment of categorySegments) {
        const segmentStartTime = Date.now();
        
        try {
          // Save crop image temporarily for Google Lens
          const tempFilename = await this.saveCropImageTemporarily(segment.crop_image_base64);
          
          // Call Google Lens service
          const productLinks = await this.googleLensService.analyzeUploadedImage(tempFilename);
          
          // Clean up temp file
          this.cleanupTempFile(tempFilename);
          
          const processingTime = Date.now() - segmentStartTime;
          
          processedSegments.push(
            this.convertToSegmentedItem(segment, productLinks, processingTime),
          );

          this.logger.debug(
            `Google Lens found ${productLinks.length} products for ${category} segment in ${processingTime}ms`
          );

        } catch (error) {
          this.logger.warn(
            `Google Lens processing failed for segment ${segment.id}: ${error.message}`,
          );
          
          // Include segment without product links rather than failing completely
          processedSegments.push(
            this.convertToSegmentedItem(segment, []),
          );
        }
      }
    }

    return processedSegments;
  }

  /**
   * Group segments by category and apply limits
   */
  private groupSegmentsByCategory(
    segments: ClothingSegmentDto[],
    config: SegmentationConfig,
  ): Record<string, ClothingSegmentDto[]> {
    const grouped: Record<string, ClothingSegmentDto[]> = {
      TORSO: [],
      BOTTOM: [],
      SHOES: [],
      ACCESSORY: [],
    };

    // Sort by confidence first
    const sortedSegments = segments
      .filter(s => s.confidence >= config.minConfidence)
      .sort((a, b) => b.confidence - a.confidence);

    // Distribute segments across categories with limits
    for (const segment of sortedSegments) {
      const category = segment.category;
      if (grouped[category] && grouped[category].length < config.maxSegmentsPerCategory) {
        grouped[category].push(segment);
      }
    }

    return grouped;
  }

  /**
   * Save crop image temporarily for Google Lens processing
   */
  private async saveCropImageTemporarily(base64Data: string): Promise<string> {
    const filename = `temp_crop_${uuidv4()}.png`;
    const filePath = path.join(this.uploadsDir, filename);
    
    // Decode base64 and save
    const buffer = Buffer.from(base64Data, 'base64');
    fs.writeFileSync(filePath, buffer);
    
    return filename;
  }

  /**
   * Clean up temporary file
   */
  private cleanupTempFile(filename: string): void {
    try {
      const filePath = path.join(this.uploadsDir, filename);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    } catch (error) {
      this.logger.warn(`Failed to clean up temp file ${filename}: ${error.message}`);
    }
  }

  /**
   * Convert YOLO segment to our final format
   */
  private convertToSegmentedItem(
    segment: ClothingSegmentDto,
    productLinks: ProductLinkDto[],
    processingTimeMs: number = 0,
  ): SegmentedClothingItem {
    return {
      id: segment.id,
      category: segment.category,
      confidence: segment.confidence,
      bbox: segment.bbox,
      cropImageBase64: segment.crop_image_base64,
      productLinks,
      maskArea: segment.mask_area,
      className: segment.class_name,
      processingTimeMs,
    };
  }

  /**
   * Compile final results
   */
  private compileSegmentationResults(
    segments: SegmentedClothingItem[],
    totalTimeMs: number,
    segmentationTimeMs: number,
    googleLensTimeMs: number,
  ): NewSegmentedResults {
    const categoryCounts = {
      TORSO: 0,
      BOTTOM: 0,
      SHOES: 0,
      ACCESSORY: 0,
    };

    for (const segment of segments) {
      if (categoryCounts.hasOwnProperty(segment.category)) {
        categoryCounts[segment.category]++;
      }
    }

    return {
      segments,
      totalItems: segments.length,
      totalProcessingTimeMs: totalTimeMs,
      segmentationTimeMs,
      googleLensTimeMs,
      categoryCounts,
    };
  }

  /**
   * Utility: Count total product links across all segments
   */
  private countProductLinks(results: NewSegmentedResults): number {
    return results.segments.reduce((total, segment) => total + segment.productLinks.length, 0);
  }

  /**
   * Health check for segmentation service
   */
  async checkSegmentationServiceHealth(): Promise<boolean> {
    try {
      const response = await firstValueFrom(
        this.httpService.get(`${this.segmentationServiceUrl}/health`, {
          timeout: 5000,
        }),
      );
      return response.status === 200 && response.data?.status === 'healthy';
    } catch (error) {
      this.logger.warn(`Segmentation service health check failed: ${error.message}`);
      return false;
    }
  }
}
