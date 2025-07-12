import { Module } from '@nestjs/common';
import { VideoProcessingController } from './video-processing.controller';
import { VideoProcessingService } from '../services/video-processing.service';

@Module({
  controllers: [VideoProcessingController],
  providers: [VideoProcessingService],
  exports: [VideoProcessingService],
})
export class VideoProcessingModule {} 