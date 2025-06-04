import { IsNotEmpty, IsString } from 'class-validator';
 
export class AnalyzeImageDto {
  @IsString()
  @IsNotEmpty()
  filename: string;
} 