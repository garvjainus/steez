import { Injectable, Logger } from '@nestjs/common';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';

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

  constructor() {
    this.lambdaClient = new LambdaClient({
      region: process.env.AWS_REGION || 'us-east-1',
    });
    this.functionName = process.env.VIDEO_LAMBDA_FUNCTION_NAME || 'steez-video-processor';
  }

  async processVideo(request: VideoProcessingRequest): Promise<VideoProcessingResponse> {
    try {
      this.logger.log(`Processing video: ${request.url}`);

      const command = new InvokeCommand({
        FunctionName: this.functionName,
        Payload: JSON.stringify(request),
      });

      const response = await this.lambdaClient.send(command);
      
      if (response.StatusCode !== 200) {
        throw new Error(`Lambda invocation failed with status: ${response.StatusCode}`);
      }

      const payload = JSON.parse(new TextDecoder().decode(response.Payload));
      
      if (payload.statusCode !== 200) {
        throw new Error(`Lambda function failed: ${payload.body}`);
      }

      const result = JSON.parse(payload.body);
      this.logger.log(`Video processing completed. Job ID: ${result.jobId}, Frames: ${result.framesUploaded}`);
      
      return result;
    } catch (error) {
      this.logger.error(`Video processing failed: ${error.message}`, error.stack);
      throw error;
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