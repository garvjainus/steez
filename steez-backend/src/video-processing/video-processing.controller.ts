import { Controller, Post, Body, Logger, BadRequestException } from '@nestjs/common';
import { VideoProcessingService, VideoProcessingRequest, VideoProcessingResponse } from '../services/video-processing.service';
import { IsUrl, IsOptional, IsString } from 'class-validator';

class ProcessVideoDto {
  @IsUrl()
  url: string;

  @IsOptional()
  @IsString()
  frameRate?: string;
}

@Controller('video-processing')
export class VideoProcessingController {
  private readonly logger = new Logger(VideoProcessingController.name);

  constructor(private readonly videoProcessingService: VideoProcessingService) {}

  @Post('process')
  async processVideo(@Body() processVideoDto: ProcessVideoDto): Promise<VideoProcessingResponse> {
    try {
      this.logger.log(`Received video processing request: ${processVideoDto.url}`);
      
      const request: VideoProcessingRequest = {
        url: processVideoDto.url,
        frameRate: processVideoDto.frameRate || '2',
      };

      const result = await this.videoProcessingService.processVideo(request);
      
      this.logger.log(`Video processing completed successfully. Job ID: ${result.jobId}`);
      return result;
    } catch (error) {
      this.logger.error(`Video processing failed: ${error.message}`, error.stack);
      throw new BadRequestException(`Video processing failed: ${error.message}`);
    }
  }
} 