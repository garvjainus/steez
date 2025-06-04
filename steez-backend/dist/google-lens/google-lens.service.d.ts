import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { ProductLinkDto } from './dto';
export declare class GoogleLensService {
    private readonly httpService;
    private readonly configService;
    private readonly logger;
    private readonly serpApiKey;
    private readonly uploadsDir;
    private readonly baseUrl;
    private readonly maxRetries;
    private readonly retryDelay;
    constructor(httpService: HttpService, configService: ConfigService);
    analyzeUploadedImage(filename: string): Promise<ProductLinkDto[]>;
    private makeRequestWithRetries;
    private isApparelLike;
    private mapToProductDto;
    private handleApiError;
}
