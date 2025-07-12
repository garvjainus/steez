-- Migration: Create jobs table for video processing workflow
-- This table tracks video processing jobs from URL submission to completion

-- Create jobs status enum
CREATE TYPE job_status AS ENUM (
  'PENDING',
  'PROCESSING', 
  'SELECTING_FRAMES',
  'COMPLETE',
  'FAILED'
);

-- Create jobs table
CREATE TABLE jobs (
  job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  video_url TEXT NOT NULL,
  status job_status NOT NULL DEFAULT 'PENDING',
  results JSONB,
  error_message TEXT,
  frame_count INTEGER,
  selected_frame_urls TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_jobs_user_id ON jobs(user_id);
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_created_at ON jobs(created_at DESC);
CREATE INDEX idx_jobs_user_status ON jobs(user_id, status);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at on row updates
CREATE TRIGGER update_jobs_updated_at 
  BEFORE UPDATE ON jobs 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Add comments for documentation
COMMENT ON TABLE jobs IS 'Tracks video processing jobs from URL submission to completion';
COMMENT ON COLUMN jobs.job_id IS 'Unique identifier for the job';
COMMENT ON COLUMN jobs.user_id IS 'ID of the user who submitted the job';
COMMENT ON COLUMN jobs.video_url IS 'URL of the video to process (TikTok, Instagram Reel, etc.)';
COMMENT ON COLUMN jobs.status IS 'Current status of the job processing';
COMMENT ON COLUMN jobs.results IS 'Final clothing analysis results in JSON format';
COMMENT ON COLUMN jobs.error_message IS 'Error message if job failed';
COMMENT ON COLUMN jobs.frame_count IS 'Total number of frames extracted from video';
COMMENT ON COLUMN jobs.selected_frame_urls IS 'Array of S3 URLs for the top 5 selected frames';

-- Grant permissions (adjust based on your Supabase setup)
-- These would typically be handled by Supabase Row Level Security (RLS)
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;

-- Example RLS policy (users can only see their own jobs)
CREATE POLICY "Users can view their own jobs" ON jobs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own jobs" ON jobs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own jobs" ON jobs
  FOR UPDATE USING (auth.uid() = user_id); 