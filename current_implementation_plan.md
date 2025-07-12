Phase 1: The Asynchronous Core (Backend & Lambda)
This phase is about getting the video processed and handed off to the backend without involving frame selection yet.
1. Create a Jobs Table in Your Database
This is essential for tracking the status of each request.
job_id (Primary Key, UUID)
user_id (Foreign Key)
video_url (String)
status (Enum: PENDING, PROCESSING, SELECTING_FRAMES, COMPLETE, FAILED)
results (JSON, nullable)
created_at, updated_at
2. Create an API Gateway Endpoint
Endpoint: POST /process-video
Action: This endpoint will invoke your existing steez-video-frame-extractor Lambda.
Logic:
It should first create an entry in the Jobs table with status: PENDING.
Then, it invokes the Lambda function asynchronously, passing the job_id and video_url.
It immediately returns the job_id to the Swift app, so the app knows the job has started.
3. Modify the Frame Extraction Lambda (steez-video-frame-extractor)
Input: It will now receive { "url": "...", "job_id": "..." }.
Output: All frames are still saved to S3, but now under the job_id prefix (which it already does).
New Final Step: After uploading all frames, the Lambda must trigger the next step. The simplest way is to invoke the new "Frame Selection Lambda" directly.
Phase 2: Intelligent Frame Selection
This is the core new logic for finding the best frames.
1. Create a New "Frame Selection" Lambda
Name: steez-frame-selector
Trigger: Invoked by the steez-video-frame-extractor Lambda.
Input: { "job_id": "...", "bucket": "...", "frame_count": ... }
Permissions (IAM Role):
s3:ListObjectsV2 on the steez-video-frames bucket.
rekognition:DetectLabels and rekognition:DetectModerationLabels.
lambda:InvokeFunction to call the backend.
2. Implement the Frame Selection Logic
The goal is to find 5 frames that are high-quality and likely to contain clothing.
List all frames in S3 for the given job_id.
Update Job Status: Set the job status in the database to SELECTING_FRAMES.
Analyze each frame using AWS Rekognition:
Quality Check: Check for ImageQuality.Sharpness and ImageQuality.Brightness. Discard blurry or dark frames.
Content Check: Use DetectLabels to look for labels like Person, Clothing, Apparel, Fashion.
Score each frame: Create a simple scoring algorithm.
score = (sharpness_score * 0.5) + (is_person_present * 0.3) + (is_clothing_present * 0.2)
Select the Top 5: Pick the 5 frames with the highest scores.
3. Trigger the Backend
Once the top 5 frames are selected, this Lambda makes a POST request to your existing backend with the S3 URLs of those 5 frames.
Endpoint: POST /process-frames (You'll need to create this on your backend).
Payload: { "job_id": "...", "frame_urls": ["s3://...", "s3://...", ...] }
Phase 3: Swift App Integration
This focuses on the user experience, handling the asynchronous nature of the process.
1. Initial Request
The user pastes a URL and hits "Go".
The Swift app calls POST /process-video.
The app receives a job_id back immediately and stores it.
UI Change: Show a "Processing your video..." state.
2. Getting the Results (Two Options)
Option A: Polling (Simpler to implement)
After getting the job_id, the Swift app starts a timer.
Every 5-10 seconds, it calls a new endpoint: GET /job-status/{job_id}.
The backend returns the current status from the Jobs table.
If status is COMPLETE, the response includes the clothing items. The app stops polling and displays the results.
If status is FAILED, show an error message.
Option B: Push Notifications (Better UX)
When the backend finishes processing the clothes (after the /process-frames call), it updates the job status to COMPLETE.
It then triggers a push notification to the specific user_id associated with the job.
The user gets a notification: "Your Steez results are ready!"
Tapping the notification opens the app and fetches the results from the GET /job-status/{job_id} endpoint.
Summary of New API Endpoints Needed
POST /process-video
Request Body: { "url": "https://..." }
Response Body: { "job_id": "uuid-..." }
Action: Creates a job record, triggers the frame extraction Lambda.
POST /process-frames
Request Body: { "job_id": "...", "frame_urls": [...] }
Response Body: { "message": "Processing started" }
Action: Your existing backend logic for analyzing clothes from images. Updates the job to COMPLETE when done.
GET /job-status/{job_id}
Request Path: Contains the job_id.
Response Body: { "job_id": "...", "status": "PENDING|COMPLETE|FAILED", "results": [...] }
Action: Fetches the job status and results from the database.
