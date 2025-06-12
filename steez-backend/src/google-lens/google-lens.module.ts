import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { GoogleLensService } from './google-lens.service';
import { GoogleLensController } from './google-lens.controller';
import { ConfigModule } from '@nestjs/config'; // ConfigModule is already global, but good practice to list if service directly uses ConfigService

@Module({
  imports: [
    HttpModule, // For making external API calls
    ConfigModule, // To access environment variables like API keys
  ],
  providers: [GoogleLensService],
  controllers: [GoogleLensController],
  exports: [GoogleLensService], // Export the service so it can be used in other modules
})
export class GoogleLensModule {}
