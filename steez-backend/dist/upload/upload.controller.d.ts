import { UploadService } from './upload.service';
export declare class UploadController {
    private readonly uploadService;
    private readonly logger;
    constructor(uploadService: UploadService);
    uploadImage(file: Express.Multer.File, userId: string, userSize?: string, userCountry?: string): Promise<import("./upload.service").ProcessResult>;
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
