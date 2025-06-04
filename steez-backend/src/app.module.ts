import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MulterModule } from '@nestjs/platform-express';
import { UploadModule } from './upload/upload.module';
import { HealthController } from './health.controller';
import { GoogleLensModule } from './google-lens/google-lens.module';
import { diskStorage } from 'multer';
import { v4 as uuidv4 } from 'uuid';
import * as path from 'path';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
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
    GoogleLensModule,
  ],
  controllers: [HealthController],
  providers: [],
})
export class AppModule {}
