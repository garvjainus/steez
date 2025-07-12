# Lambda Function Testing Guide

This guide shows you how to test your video frame extraction Lambda function using different test events.

## How to Test in AWS Lambda Console

1. **Navigate to your Lambda function** in the AWS Console
2. **Click the "Test" tab** (next to "Code")
3. **Click "Create new event"**
4. **Give your test event a name** (e.g., "BasicVideoTest")
5. **Copy and paste** one of the test events below
6. **Click "Test"** to run the function
7. **Check the results** in the execution results section

## Test Events

### 1. Basic Test (Uses Default Frame Rate)
**Purpose**: Test basic functionality with environment variable frame rate
**Expected Result**: Should extract frames at 1 FPS (default)

```json
{
  "url": "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4"
}
```

**Expected Response**:
```json
{
  "statusCode": 200,
  "body": "{\"jobId\":\"uuid-here\",\"framesUploaded\":5,\"bucket\":\"steez-video-frames\"}"
}
```

### 2. Custom Frame Rate Test
**Purpose**: Test with custom frame rate override
**Expected Result**: Should extract frames at 2 FPS

```json
{
  "url": "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
  "frameRate": "2"
}
```

**Expected Response**:
```json
{
  "statusCode": 200,
  "body": "{\"jobId\":\"uuid-here\",\"framesUploaded\":10,\"bucket\":\"steez-video-frames\"}"
}
```

### 3. Error Handling Test
**Purpose**: Test error handling when URL is missing
**Expected Result**: Should return 400 error

```json
{
  "frameRate": "1"
}
```

**Expected Response**:
```json
{
  "statusCode": 400,
  "body": "'url' is required"
}
```

### 4. High Frame Rate Test
**Purpose**: Test with higher frame rate (more intensive processing)
**Expected Result**: Should extract more frames

```json
{
  "url": "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4",
  "frameRate": "5"
}
```

### 5. YouTube Video Test
**Purpose**: Test with YouTube URL (tests yt-dlp functionality)
**Expected Result**: Should download and process YouTube video

```json
{
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "frameRate": "1"
}
```

**Note**: This might take longer due to YouTube's download restrictions.

## What to Check After Testing

### 1. Function Execution
- ✅ Function completes without timeout
- ✅ No memory or storage errors
- ✅ Proper status code returned

### 2. S3 Bucket
Check your S3 bucket (`steez-video-frames`) for:
- ✅ New folder with the job ID
- ✅ Frame images (frame_00001.jpg, frame_00002.jpg, etc.)
- ✅ Correct number of frames based on video length and frame rate

### 3. CloudWatch Logs
Check CloudWatch logs for:
- ✅ No error messages
- ✅ Successful download messages
- ✅ ffmpeg execution logs
- ✅ S3 upload confirmations

## Troubleshooting Common Issues

### Timeout Errors
- **Symptom**: Function times out before completion
- **Solution**: Increase timeout in Lambda configuration
- **Typical cause**: Large video files or slow network

### Memory Errors
- **Symptom**: Out of memory errors in logs
- **Solution**: Increase memory allocation in Lambda configuration
- **Typical cause**: High-resolution videos or high frame rates

### S3 Permissions Errors
- **Symptom**: Access denied errors when uploading to S3
- **Solution**: Check IAM role has S3 permissions
- **Fix**: Ensure Lambda execution role has `AmazonS3FullAccess` policy

### Download Errors
- **Symptom**: yt-dlp fails to download video
- **Solution**: Test with different video URLs
- **Typical cause**: Video platform restrictions or invalid URLs

## Sample Expected Outputs

### Successful Execution Log:
```
[INFO] Starting video processing for job: abc-123-def
[INFO] Downloading video from: https://sample-videos.com/...
[INFO] Video downloaded successfully: 1.2MB
[INFO] Extracting frames at 2 FPS...
[INFO] Extracted 10 frames
[INFO] Uploading frames to S3...
[INFO] Successfully uploaded 10 frames to bucket: steez-video-frames
[INFO] Job completed successfully
```

### S3 Structure After Test:
```
steez-video-frames/
└── abc-123-def-456-789/
    ├── frame_00001.jpg
    ├── frame_00002.jpg
    ├── frame_00003.jpg
    └── ...
```

## Performance Expectations

| Video Duration | Frame Rate | Expected Frames | Estimated Time |
|---------------|------------|----------------|----------------|
| 5 seconds     | 1 FPS      | 5 frames       | 10-30 seconds  |
| 5 seconds     | 2 FPS      | 10 frames      | 15-40 seconds  |
| 30 seconds    | 1 FPS      | 30 frames      | 30-90 seconds  |
| 60 seconds    | 2 FPS      | 120 frames     | 60-180 seconds |

**Note**: Processing time depends on video resolution, network speed, and Lambda performance tier. 