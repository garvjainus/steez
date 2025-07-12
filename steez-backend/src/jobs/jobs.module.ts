import { Module } from '@nestjs/common';
import { JobsService } from './jobs.service';
import { JobsController } from './jobs.controller';

@Module({
  controllers: [JobsController],
  providers: [JobsService],
  exports: [JobsService], // Export service so other modules can use it
})
export class JobsModule {}
