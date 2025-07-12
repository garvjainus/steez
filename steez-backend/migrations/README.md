# Database Migrations

This directory contains SQL migration files for the Steez backend database.

## How to Apply Migrations in Supabase

### Option 1: Using Supabase Dashboard (Recommended)

1. **Login to Supabase Dashboard**
   - Go to [supabase.com](https://supabase.com)
   - Navigate to your project

2. **Open SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New query"

3. **Apply Migration**
   - Copy the entire contents of `001_create_jobs_table.sql`
   - Paste into the SQL Editor
   - Click "Run" to execute the migration

4. **Verify Migration**
   - Go to "Table Editor" in the left sidebar
   - You should see the new `jobs` table
   - Check that all columns and indexes are created

### Option 2: Using Supabase CLI

```bash
# Make sure you have Supabase CLI installed
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project (run this in your project root)
supabase link --project-ref YOUR_PROJECT_REF

# Apply the migration
supabase db push
```

### Option 3: Using MCP Supabase Tool

If you have the MCP Supabase tool available:

```bash
# Apply the migration directly
mcp_supabase_apply_migration --name "create_jobs_table" --query "$(cat migrations/001_create_jobs_table.sql)"
```

## Migration Files

- `001_create_jobs_table.sql` - Creates the jobs table for tracking video processing workflows

## Table Schema: jobs

| Column | Type | Description |
|--------|------|-------------|
| `job_id` | UUID | Primary key, auto-generated |
| `user_id` | UUID | Foreign key to user who submitted job |
| `video_url` | TEXT | URL of video to process |
| `status` | ENUM | Current job status (PENDING, PROCESSING, SELECTING_FRAMES, COMPLETE, FAILED) |
| `results` | JSONB | Final clothing analysis results |
| `error_message` | TEXT | Error message if job failed |
| `frame_count` | INTEGER | Total frames extracted from video |
| `selected_frame_urls` | TEXT[] | Array of S3 URLs for top 5 frames |
| `created_at` | TIMESTAMPTZ | When job was created |
| `updated_at` | TIMESTAMPTZ | When job was last updated |

## Row Level Security (RLS)

The migration includes RLS policies that ensure:
- Users can only see their own jobs
- Users can only create jobs for themselves
- Users can only update their own jobs

## Indexes

The migration creates several indexes for optimal performance:
- `idx_jobs_user_id` - For querying jobs by user
- `idx_jobs_status` - For querying jobs by status
- `idx_jobs_created_at` - For ordering jobs by creation time
- `idx_jobs_user_status` - Composite index for user + status queries 