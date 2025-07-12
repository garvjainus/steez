import {
  Injectable,
  Logger,
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { JobsService } from '../jobs/jobs.service';
import { JobStatus } from '../jobs/entities/job.entity';
import { ProcessVideoDto } from './dto/process-video.dto';

export interface VideoProcessingRequest {
  url: string;
  frameRate?: string;
}

export interface VideoProcessingResponse {
  jobId: string;
  framesUploaded: number;
  bucket: string;
}

@Injectable()
export class VideoProcessingService {
  private readonly logger = new Logger(VideoProcessingService.name);
  private readonly lambdaClient: LambdaClient;
  private readonly functionName: string;

  constructor(
    private readonly jobsService: JobsService,
    private readonly configService: ConfigService,
  ) {
    // Initialize AWS Lambda client with enhanced configuration
    this.lambdaClient = new LambdaClient({
      region: this.configService.get<string>('AWS_REGION', 'us-east-1'),
      credentials: {
        accessKeyId: this.configService.get<string>('AWS_ACCESS_KEY_ID'),
        secretAccessKey: this.configService.get<string>('AWS_SECRET_ACCESS_KEY'),
      },
    });

    this.functionName = this.configService.get<string>(
      'LAMBDA_FUNCTION_NAME',
      'steez-video-frame-extractor',
    );
  }

  // Legacy method - kept for backwards compatibility
  async processVideo(
    request: VideoProcessingRequest,
  ): Promise<VideoProcessingResponse> {
    try {
      this.logger.log(`Processing video: ${request.url}`);

      const command = new InvokeCommand({
        FunctionName: this.functionName,
        Payload: JSON.stringify(request),
      });

      const response = await this.lambdaClient.send(command);

      if (response.StatusCode !== 200) {
        throw new Error(
          `Lambda invocation failed with status: ${response.StatusCode}`,
        );
      }

      const payload = JSON.parse(new TextDecoder().decode(response.Payload));

      if (payload.statusCode !== 200) {
        throw new Error(`Lambda function failed: ${payload.body}`);
      }

      const result = JSON.parse(payload.body);
      this.logger.log(
        `Video processing completed. Job ID: ${result.jobId}, Frames: ${result.framesUploaded}`,
      );

      return result;
    } catch (error) {
      this.logger.error(
        `Video processing failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  // New method - with job tracking for async processing
  async processVideoWithJobTracking(
    processVideoDto: ProcessVideoDto,
  ): Promise<{ job_id: string }> {
    const { user_id, video_url, frame_rate } = processVideoDto;

    try {
      // Step 1: Create job entry in database with PENDING status
      this.logger.log(
        `Creating job for user ${user_id} with video URL: ${video_url}`,
      );

      const job = await this.jobsService.create({
        user_id,
        video_url,
        frame_rate: frame_rate?.toString(),
      });

      const job_id = job.job_id;

      // Step 2: Prepare Lambda payload
      const lambdaPayload = {
        url: video_url,
        job_id,
        frame_rate: frame_rate || 1,
        user_id, // Include user_id for context
      };

      // Step 3: Invoke Lambda function asynchronously
      const command = new InvokeCommand({
        FunctionName: this.functionName,
        InvocationType: 'Event', // Asynchronous invocation
        Payload: JSON.stringify(lambdaPayload),
      });

      this.logger.log(
        `Invoking Lambda function ${this.functionName} with payload:`,
        lambdaPayload,
      );

      try {
        const response = await this.lambdaClient.send(command);

        if (response.StatusCode !== 202) {
          throw new Error(
            `Lambda invocation failed with status code: ${response.StatusCode}`,
          );
        }

        this.logger.log(
          `Lambda function invoked successfully for job ${job_id}`,
        );

        // Update job status to PROCESSING
        await this.jobsService.updateStatus(job_id, JobStatus.PROCESSING);

        return { job_id };
      } catch (lambdaError) {
        this.logger.error(
          `Lambda invocation failed for job ${job_id}:`,
          lambdaError,
        );

        // Update job status to FAILED
        await this.jobsService.updateStatus(
          job_id,
          JobStatus.FAILED,
          `Lambda invocation failed: ${lambdaError.message}`,
        );

        throw new InternalServerErrorException(
          'Failed to start video processing',
        );
      }
    } catch (error) {
      this.logger.error('Error processing video:', error);

      if (
        error instanceof BadRequestException ||
        error instanceof InternalServerErrorException
      ) {
        throw error;
      }

      throw new InternalServerErrorException(
        'An unexpected error occurred while processing video',
      );
    }
  }

  async getJobStatus(jobId: string): Promise<any> {
    try {
      const job = await this.jobsService.findOne(jobId);

      if (!job) {
        throw new BadRequestException(`Job ${jobId} not found`);
      }

      return {
        job_id: job.job_id,
        status: job.status,
        results: job.results || null,
        frame_count: job.frame_count || null,
        selected_frame_urls: job.selected_frame_urls || null,
        error_message: job.error_message || null,
        created_at: job.created_at,
        updated_at: job.updated_at,
      };
    } catch (error) {
      this.logger.error(`Error getting job status for ${jobId}:`, error);

      if (error instanceof BadRequestException) {
        throw error;
      }

      throw new InternalServerErrorException('Failed to retrieve job status');
    }
  }

  async getFrameUrl(jobId: string, frameName: string): Promise<string> {
    const bucket = process.env.FRAME_BUCKET || 'steez-video-frames';
    const key = `${jobId}/${frameName}`;

    // Return S3 URL (you might want to use presigned URLs for security)
    return `https://${bucket}.s3.amazonaws.com/${key}`;
  }

  async listFrames(jobId: string): Promise<string[]> {
    // This would require S3 client to list objects with prefix
    // Implementation depends on your specific needs
    const frameNames: string[] = [];

    // Assuming standard naming: frame_00001.jpg, frame_00002.jpg, etc.
    // You'd typically list S3 objects here

    return frameNames;
  }
}
