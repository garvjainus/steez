import {
  Controller,
  Post,
  Body,
  UsePipes,
  ValidationPipe,
  Logger,
} from '@nestjs/common';
import { GoogleLensService } from './google-lens.service';
import { AnalyzeImageDto, ProductLinkDto } from './dto';

@Controller('google-lens')
export class GoogleLensController {
  private readonly logger = new Logger(GoogleLensController.name);

  constructor(private readonly googleLensService: GoogleLensService) {}

  @Post('analyze')
  @UsePipes(new ValidationPipe({ transform: true, whitelist: true }))
  async analyzeImage(
    @Body() analyzeImageDto: AnalyzeImageDto,
  ): Promise<ProductLinkDto[]> {
    this.logger.log(
      `Received request to analyze image: ${analyzeImageDto.filename}`,
    );
    return this.googleLensService.analyzeUploadedImage(
      analyzeImageDto.filename,
    );
  }
}
