import { SegmentedResults } from '../services/geminiVision';
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
export declare class UploadService {
    private readonly configService;
    private readonly logger;
    private readonly uploadsDir;
    private readonly baseUrl;
    constructor(configService: ConfigService);
    processUploadedImage(file: Express.Multer.File, userId: string, user?: {
        size: string;
        country: string;
    }): Promise<ProcessResult>;
}
