import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MulterModule } from '@nestjs/platform-express';
import { UploadModule } from './upload/upload.module';
import { JobsModule } from './jobs/jobs.module';
import { HealthController } from './health.controller';
import { VideoProcessingController } from './services/video-processing.controller';
import { VideoProcessingService } from './services/video-processing.service';
// import { GoogleLensModule } from './google-lens/google-lens.module'; // 🔒 TEMP-DISABLED (Google Lens)
import { diskStorage } from 'multer';
import { v4 as uuidv4 } from 'uuid';
import * as path from 'path';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '../.env', // Load from root directory
    }),
    MulterModule.register({
      storage: diskStorage({
        destination: './uploads',
        filename: (req, file, callback) => {
          const filename = `${uuidv4()}${path.extname(file.originalname)}`;
          callback(null, filename);
        },
      }),
    }),
    UploadModule,
    JobsModule,
    // GoogleLensModule, // 🔒 TEMP-DISABLED (Google Lens)
  ],
  controllers: [HealthController, VideoProcessingController],
  providers: [VideoProcessingService],
})
export class AppModule {}
