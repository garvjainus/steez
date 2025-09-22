import { SegmentedResults } from '../services/geminiVision';
import { SegmentationService } from '../segmentation/segmentation.service';
import { NewSegmentedResults } from '../segmentation/dto';
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
        newSegmentedResults?: NewSegmentedResults;
        processingPipeline?: 'legacy' | 'segmentation';
    };
}
export declare class UploadService {
    private readonly configService;
    private readonly segmentationService;
    private readonly logger;
    private readonly uploadsDir;
    private readonly baseUrl;
    constructor(configService: ConfigService, segmentationService: SegmentationService);
    processUploadedImage(file: Express.Multer.File, userId: string, user?: {
        size: string;
        country: string;
    }): Promise<ProcessResult>;
    processUploadedImageWithSegmentation(file: Express.Multer.File, userId: string, user?: {
        size: string;
        country: string;
    }): Promise<ProcessResult>;
    processUploadedImageLegacy(file: Express.Multer.File, userId: string, user?: {
        size: string;
        country: string;
    }): Promise<ProcessResult>;
    checkSegmentationServiceHealth(): Promise<boolean>;
}
