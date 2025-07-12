import {
  IsUrl,
  IsUUID,
  IsOptional,
  IsNumber,
  Min,
  Max,
} from 'class-validator';

export class ProcessVideoDto {
  @IsUUID()
  user_id: string;

  @IsUrl()
  video_url: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(10)
  frame_rate?: number = 1; // Default to 1 frame per second
} 