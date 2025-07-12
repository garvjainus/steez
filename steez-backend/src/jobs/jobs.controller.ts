import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { JobsService } from './jobs.service';
import { CreateJobDto } from './dto/create-job.dto';

@Controller('jobs')
export class JobsController {
  private readonly logger = new Logger(JobsController.name);

  constructor(private readonly jobsService: JobsService) {}

  @Post()
  async create(@Body() createJobDto: CreateJobDto) {
    try {
      this.logger.log(`Creating job for user: ${createJobDto.user_id}`);
      const job = await this.jobsService.create(createJobDto);
      this.logger.log(`Job created successfully: ${job.job_id}`);

      return {
        success: true,
        message: 'Job created successfully',
        job_id: job.job_id,
        status: job.status,
      };
    } catch (error) {
      this.logger.error(`Failed to create job: ${error.message}`, error.stack);
      throw new HttpException(
        'Failed to create job',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    try {
      const job = await this.jobsService.findOne(id);
      if (!job) {
        throw new HttpException('Job not found', HttpStatus.NOT_FOUND);
      }

      return {
        success: true,
        job_id: job.job_id,
        status: job.status,
        video_url: job.video_url,
        results: job.results,
        frame_count: job.frame_count,
        selected_frame_urls: job.selected_frame_urls,
        error_message: job.error_message,
        created_at: job.created_at,
        updated_at: job.updated_at,
      };
    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }
      this.logger.error(`Failed to find job: ${error.message}`, error.stack);
      throw new HttpException(
        'Failed to find job',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('user/:userId')
  async findByUserId(@Param('userId') userId: string) {
    try {
      const jobs = await this.jobsService.findByUserId(userId);
      return {
        success: true,
        jobs: jobs.map((job) => ({
          job_id: job.job_id,
          status: job.status,
          video_url: job.video_url,
          results: job.results,
          frame_count: job.frame_count,
          error_message: job.error_message,
          created_at: job.created_at,
          updated_at: job.updated_at,
        })),
      };
    } catch (error) {
      this.logger.error(
        `Failed to find jobs for user: ${error.message}`,
        error.stack,
      );
      throw new HttpException(
        'Failed to find jobs for user',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}
