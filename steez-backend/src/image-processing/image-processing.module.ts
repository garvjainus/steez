import { Module } from '@nestjs/common';
import { ImageProcessingController } from './image-processing.controller';
import { ImageProcessingService } from './image-processing.service';
import { MulterModule } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { v4 as uuidv4 } from 'uuid';
import { ProductMatchModule } from '../product-match/product-match.module';

@Module({
  imports: [
    ProductMatchModule,
    MulterModule.register({
      storage: diskStorage({
        destination: './uploads',
        filename: (req, file, callback) => {
          const randomName = uuidv4();
          callback(null, `${randomName}${extname(file.originalname)}`);
        },
      }),
      limits: {
        fileSize: 10 * 1024 * 1024, // 10MB
      },
    }),
  ],
  controllers: [ImageProcessingController],
  providers: [ImageProcessingService],
  exports: [ImageProcessingService],
})
export class ImageProcessingModule {} 