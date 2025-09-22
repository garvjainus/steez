import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { SegmentationService } from './segmentation.service';
import { GoogleLensModule } from '../google-lens/google-lens.module';

@Module({
  imports: [
    HttpModule,
    ConfigModule,
    GoogleLensModule, // Import Google Lens module for product identification
  ],
  providers: [SegmentationService],
  exports: [SegmentationService],
})
export class SegmentationModule {}
