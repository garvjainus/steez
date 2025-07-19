import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Logger,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import { VideoProcessingService } from './video-processing.service';
import { ProcessVideoDto } from './dto/process-video.dto';
import { ApiKeyAuthGuard } from '../auth/guards/api-key-auth.guard';

@Controller('video-processing')
export class VideoProcessingController {
  private readonly logger = new Logger(VideoProcessingController.name);

  constructor(
    private readonly videoProcessingService: VideoProcessingService,
  ) {}

  @Post('process-video')
  @UseGuards(ApiKeyAuthGuard)
  @HttpCode(HttpStatus.OK)
  async processVideo(@Body() processVideoDto: ProcessVideoDto) {
    this.logger.log(
      `Processing video request for user ${processVideoDto.user_id}`,
    );

    try {
      const result = await this.videoProcessingService.processVideoWithJobTracking(
        processVideoDto,
      );

      this.logger.log(`Video processing job created: ${result.job_id}`);
      return result;
    } catch (error) {
      this.logger.error('Error processing video:', error);
      throw error;
    }
  }

  @Get('job-status/:jobId')
  @UseGuards(ApiKeyAuthGuard)
  async getJobStatus(@Param('jobId') jobId: string) {
    this.logger.log(`Getting job status for: ${jobId}`);

    try {
      const result = await this.videoProcessingService.getJobStatus(jobId);

      this.logger.log(
        `Job status retrieved for: ${jobId}, status: ${result.status}`,
      );
      return result;
    } catch (error) {
      this.logger.error(`Error getting job status for ${jobId}:`, error);
      throw error;
    }
  }
} 