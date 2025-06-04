import { Module } from '@nestjs/common';
import { UploadController } from './upload.controller';
import { UploadService } from './upload.service';
import { GoogleLensModule } from '../google-lens/google-lens.module';

@Module({
  imports: [GoogleLensModule],
  controllers: [UploadController],
  providers: [UploadService],
})
export class UploadModule {} 