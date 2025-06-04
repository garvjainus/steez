import { GoogleLensService } from './google-lens.service';
import { AnalyzeImageDto, ProductLinkDto } from './dto';
export declare class GoogleLensController {
    private readonly googleLensService;
    private readonly logger;
    constructor(googleLensService: GoogleLensService);
    analyzeImage(analyzeImageDto: AnalyzeImageDto): Promise<ProductLinkDto[]>;
}
