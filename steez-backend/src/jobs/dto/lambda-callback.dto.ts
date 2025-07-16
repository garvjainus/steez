import {
  IsString,
  IsEnum,
  IsOptional,
  IsArray,
  IsUrl,
  IsNumber,
} from 'class-validator';
import { JobStatus } from '../entities/job.entity';

export class LambdaCallbackDto {
  @IsEnum(JobStatus)
  status: JobStatus;

  @IsOptional()
  @IsString()
  error_message?: string;

  @IsOptional()
  @IsNumber()
  frame_count?: number;

  @IsOptional()
  @IsArray()
  @IsUrl({}, { each: true })
  selected_frame_urls?: string[];
} 