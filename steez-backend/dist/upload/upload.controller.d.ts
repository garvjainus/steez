import { UploadService } from './upload.service';
export declare class UploadController {
    private readonly uploadService;
    private readonly logger;
    constructor(uploadService: UploadService);
    uploadImage(file: Express.Multer.File, userId: string): Promise<{
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
    uploadBase64Image(base64Image: string, userId: string): Promise<{
        success: boolean;
        message: string;
        data: {
            userId: string;
            imageSize: number;
            uploadedAt: string;
        };
    }>;
}
