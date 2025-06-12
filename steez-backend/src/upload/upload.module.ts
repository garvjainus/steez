import { Module } from '@nestjs/common';
import { UploadController } from './upload.controller';
import { UploadService } from './upload.service';
// import { GoogleLensModule } from '../google-lens/google-lens.module'; // 🔒 TEMP-DISABLED (Google Lens)

@Module({
  imports: [
    /* GoogleLensModule */
  ], // 🔒 TEMP-DISABLED (Google Lens)
  controllers: [UploadController],
  providers: [UploadService],
})
export class UploadModule {}
