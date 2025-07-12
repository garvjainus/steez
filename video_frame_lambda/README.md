# Video Frame Extraction Lambda Function

This AWS Lambda function extracts frames from videos at specified intervals and uploads them to S3.

## 📁 Essential Files

- `lambda_function.py` - Main Lambda handler code
- `requirements.txt` - Python dependencies  
- `build_lambda.sh` - Build script for Linux environments
- `test_basic.json` - Test event for Lambda
- `TESTING_GUIDE.md` - Detailed testing instructions

## 🚀 Quick Setup

### 1. Create S3 Bucket
Create a bucket named `steez-video-frames` in AWS S3 Console.

### 2. Build Lambda Package (Linux Required)

**Option A: GitHub Codespaces (FREE)**
1. Push this code to GitHub
2. Create Codespace from your repo  
3. Run: `./build_lambda.sh`
4. Download `lambda_deployment.zip`

**Option B: Google Colab (FREE)**
1. Upload files to Colab
2. Run: `!./build_lambda.sh`
3. Download the zip

### 3. Deploy to Lambda
1. Create Lambda function in AWS Console
2. Upload `lambda_deployment.zip`
3. Set handler: `lambda_function.handler`
4. Configure:
   - Timeout: 900 seconds
   - Memory: 1024 MB
   - Environment variables:
     - `FRAME_BUCKET`: `steez-video-frames`
     - `FRAME_RATE`: `1`

### 4. Test
Use the test event from `test_basic.json`:

```json
{
  "url": "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4"
}
```

Expected: Status 200, frames uploaded to S3.

## 🔧 How It Works

1. Downloads video using `yt-dlp`
2. Extracts frames using `ffmpeg` 
3. Uploads frames to S3 with unique job ID
4. Returns job metadata

## 📋 Input/Output

**Input:**
```json
{
  "url": "https://example.com/video.mp4",
  "frameRate": "2"  // optional
}
```

**Output:**
```json
{
  "statusCode": 200,
  "body": "{\"jobId\":\"uuid\",\"framesUploaded\":10,\"bucket\":\"steez-video-frames\"}"
}
```

## 🛠 Troubleshooting

- **Architecture errors**: Must build on Linux (use Codespaces/Colab)
- **Timeout**: Increase Lambda timeout for large videos
- **Memory**: Increase Lambda memory for HD videos
- **Permissions**: Ensure Lambda role has S3 access 