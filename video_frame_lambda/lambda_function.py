import json
import os
import tempfile
import uuid
import subprocess
import shutil
from pathlib import Path

import yt_dlp
from imageio_ffmpeg import get_ffmpeg_exe
import boto3

# AWS clients
s3 = boto3.client("s3")

# Environment configuration
def _get_env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None:
        raise RuntimeError(f"Environment variable '{name}' is required")
    return value

BUCKET_NAME = _get_env("FRAME_BUCKET", "steez-video-frames")
FRAME_RATE = _get_env("FRAME_RATE", "1")  # frames per second


def _download_video(url: str, dest_path: Path) -> None:
    """Download a remote video to dest_path using yt-dlp."""
    ydl_opts = {
        "outtmpl": str(dest_path),
        "quiet": True,
        "no_warnings": True,
        "format": "bestvideo+bestaudio/best",
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])


def _extract_frames(video_path: Path, frames_dir: Path, fps: str) -> list[Path]:
    """Run ffmpeg to extract frames from the video at the desired fps."""
    ffmpeg_exe = get_ffmpeg_exe()  # Downloads static binary if necessary

    frames_dir.mkdir(parents=True, exist_ok=True)
    frame_template = frames_dir / "frame_%05d.jpg"

    cmd = [
        ffmpeg_exe,
        "-i",
        str(video_path),
        "-vf",
        f"fps={fps}",
        str(frame_template),
    ]

    # Capture stderr to surface ffmpeg errors if any
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"ffmpeg exited with status {result.returncode}: {result.stderr}"
        )

    # Gather frame paths
    return sorted(frames_dir.glob("frame_*.jpg"))


def _upload_frames(frames: list[Path], job_id: str) -> int:
    """Upload each frame to s3://BUCKET_NAME/{job_id}/filename"""
    uploaded = 0
    for frame_path in frames:
        key = f"{job_id}/{frame_path.name}"
        s3.upload_file(str(frame_path), BUCKET_NAME, key)
        uploaded += 1
    return uploaded


def handler(event, context):
    """AWS Lambda entrypoint.

    Expected event shape:
    {
        "url": "https://..."  # Video URL
        "frameRate": "2"       # Optional override fps
    }
    """
    try:
        url = event.get("url")
        if not url:
            return {"statusCode": 400, "body": "'url' is required"}

        fps = str(event.get("frameRate") or FRAME_RATE)
        job_id = str(uuid.uuid4())

        # Use /tmp for Lambda ephemeral storage
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            video_path = tmpdir_path / "video.mp4"
            frames_dir = tmpdir_path / "frames"

            # 1. Download video
            _download_video(url, video_path)

            # 2. Extract frames
            frames = _extract_frames(video_path, frames_dir, fps)

            # 3. Upload frames to S3
            uploaded_count = _upload_frames(frames, job_id)

        body = {
            "jobId": job_id,
            "framesUploaded": uploaded_count,
            "bucket": BUCKET_NAME,
        }
        return {"statusCode": 200, "body": json.dumps(body)}

    except Exception as exc:
        # Log error
        print("Error in Lambda:", exc)
        return {"statusCode": 500, "body": str(exc)} 