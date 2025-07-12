export enum JobStatus {
  PENDING = 'PENDING',
  PROCESSING = 'PROCESSING',
  SELECTING_FRAMES = 'SELECTING_FRAMES',
  COMPLETE = 'COMPLETE',
  FAILED = 'FAILED',
}

export interface Job {
  job_id: string;
  user_id: string;
  video_url: string;
  status: JobStatus;
  results?: any; // JSON object containing clothing analysis results
  error_message?: string;
  frame_count?: number;
  selected_frame_urls?: string[];
  created_at: Date;
  updated_at: Date;
}
