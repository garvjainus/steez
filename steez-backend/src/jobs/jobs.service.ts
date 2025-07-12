import { Injectable, Logger } from '@nestjs/common';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { CreateJobDto } from './dto/create-job.dto';
import { Job, JobStatus } from './entities/job.entity';

@Injectable()
export class JobsService {
  private readonly logger = new Logger(JobsService.name);
  private supabase: SupabaseClient;

  constructor() {
    // Initialize Supabase client
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_ANON_KEY;

    if (!supabaseUrl || !supabaseKey) {
      throw new Error(
        'Supabase URL and ANON_KEY must be set in environment variables',
      );
    }

    this.supabase = createClient(supabaseUrl, supabaseKey);
  }

  async create(createJobDto: CreateJobDto): Promise<Job> {
    try {
      const { data, error } = await this.supabase
        .from('jobs')
        .insert({
          user_id: createJobDto.user_id,
          video_url: createJobDto.video_url,
          status: JobStatus.PENDING,
        })
        .select()
        .single();

      if (error) {
        this.logger.error('Error creating job:', error);
        throw new Error(`Failed to create job: ${error.message}`);
      }

      this.logger.log(`Job created successfully: ${data.job_id}`);
      return data as Job;
    } catch (error) {
      this.logger.error('Failed to create job:', error);
      throw error;
    }
  }

  async findOne(id: string): Promise<Job | null> {
    try {
      const { data, error } = await this.supabase
        .from('jobs')
        .select('*')
        .eq('job_id', id)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          // No rows returned
          return null;
        }
        this.logger.error('Error finding job:', error);
        throw new Error(`Failed to find job: ${error.message}`);
      }

      return data as Job;
    } catch (error) {
      this.logger.error('Failed to find job:', error);
      throw error;
    }
  }

  async findByUserId(userId: string): Promise<Job[]> {
    try {
      const { data, error } = await this.supabase
        .from('jobs')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (error) {
        this.logger.error('Error finding jobs by user ID:', error);
        throw new Error(`Failed to find jobs: ${error.message}`);
      }

      return data as Job[];
    } catch (error) {
      this.logger.error('Failed to find jobs by user ID:', error);
      throw error;
    }
  }

  async updateStatus(
    jobId: string,
    status: JobStatus,
    errorMessage?: string,
  ): Promise<Job> {
    try {
      const updateData: any = { status };

      if (errorMessage) {
        updateData.error_message = errorMessage;
      }

      const { data, error } = await this.supabase
        .from('jobs')
        .update(updateData)
        .eq('job_id', jobId)
        .select()
        .single();

      if (error) {
        this.logger.error('Error updating job status:', error);
        throw new Error(`Failed to update job status: ${error.message}`);
      }

      this.logger.log(`Job ${jobId} status updated to ${status}`);
      return data as Job;
    } catch (error) {
      this.logger.error('Failed to update job status:', error);
      throw error;
    }
  }

  async updateResults(
    jobId: string,
    results: any,
    frameCount?: number,
    selectedFrameUrls?: string[],
  ): Promise<Job> {
    try {
      const updateData: any = {
        status: JobStatus.COMPLETE,
        results,
      };

      if (frameCount !== undefined) {
        updateData.frame_count = frameCount;
      }

      if (selectedFrameUrls) {
        updateData.selected_frame_urls = selectedFrameUrls;
      }

      const { data, error } = await this.supabase
        .from('jobs')
        .update(updateData)
        .eq('job_id', jobId)
        .select()
        .single();

      if (error) {
        this.logger.error('Error updating job results:', error);
        throw new Error(`Failed to update job results: ${error.message}`);
      }

      this.logger.log(`Job ${jobId} completed with results`);
      return data as Job;
    } catch (error) {
      this.logger.error('Failed to update job results:', error);
      throw error;
    }
  }

  async updateFrameInfo(
    jobId: string,
    frameCount: number,
    selectedFrameUrls: string[],
  ): Promise<Job> {
    try {
      const { data, error } = await this.supabase
        .from('jobs')
        .update({
          status: JobStatus.SELECTING_FRAMES,
          frame_count: frameCount,
          selected_frame_urls: selectedFrameUrls,
        })
        .eq('job_id', jobId)
        .select()
        .single();

      if (error) {
        this.logger.error('Error updating job frame info:', error);
        throw new Error(`Failed to update job frame info: ${error.message}`);
      }

      this.logger.log(
        `Job ${jobId} frame info updated: ${frameCount} frames, ${selectedFrameUrls.length} selected`,
      );
      return data as Job;
    } catch (error) {
      this.logger.error('Failed to update job frame info:', error);
      throw error;
    }
  }
}
