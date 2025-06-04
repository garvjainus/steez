import { GoogleLensService } from '../google-lens/google-lens.service';
import { ConfigService } from '@nestjs/config';
export declare class UploadService {
    private readonly googleLensService;
    private readonly configService;
    private readonly logger;
    private readonly uploadsDir;
    private readonly baseUrl;
    constructor(googleLensService: GoogleLensService, configService: ConfigService);
    processUploadedImage(file: Express.Multer.File, userId: string): Promise<{
        success: boolean;
        message: string;
        data: {
            filename: string;
            originalName: string;
            size: number;
            userId: string;
            uploadedAt: string;
            imageUrl: string;
            products: import("../google-lens/dto").ProductLinkDto[];
        };
        error?: undefined;
    } | {
        success: boolean;
        message: string;
        error: any;
        data: {
            filename: string;
            originalName: string;
            size: number;
            userId: string;
            uploadedAt: string;
            imageUrl: string;
            products?: undefined;
        };
    }>;
}
