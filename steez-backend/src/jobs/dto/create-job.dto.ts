import { IsString, IsUUID, IsUrl, IsOptional } from 'class-validator';

export class CreateJobDto {
  @IsUUID()
  user_id: string;

  @IsUrl()
  video_url: string;

  @IsOptional()
  @IsString()
  frame_rate?: string;
}
