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
import cv2
import numpy as np
import requests

# AWS clients
s3 = boto3.client("s3")

# Environment configuration
def _get_env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None:
        raise RuntimeError(f"Environment variable '{name}' is required")
    return value

BUCKET_NAME = _get_env("FRAME_BUCKET", "steez-video-frames")
LAMBDA_SECRET = _get_env("LAMBDA_SECRET")


def _download_video(url: str, tmp_dir: Path) -> Path:
    """Download remote video with yt-dlp and return the actual file Path."""

    # Save as video.<ext> inside tmp_dir, letting yt-dlp choose correct extension
    outtmpl = str(tmp_dir / "video.%(ext)s")

    ydl_opts = {
        "outtmpl": outtmpl,
        "quiet": True,
        "no_warnings": True,
        "format": "bestvideo+bestaudio/best",
        # optional cookies support
        "cookies": str(Path(__file__).with_name("cookies.txt")),
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        downloaded_path = Path(ydl.prepare_filename(info))

    return downloaded_path


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


def _analyze_and_select_frames(frames: list[Path], top_n: int = 5) -> list[Path]:
    """Analyze frames for sharpness and return the top N sharpest frames."""
    if not frames:
        return []

    sharpness_scores = []
    for frame_path in frames:
        # Read image in grayscale
        img = cv2.imread(str(frame_path), cv2.IMREAD_GRAYSCALE)
        if img is None:
            continue
        # Calculate Laplacian variance
        variance = cv2.Laplacian(img, cv2.CV_64F).var()
        sharpness_scores.append((variance, frame_path))

    # Sort frames by sharpness score in descending order
    sharpness_scores.sort(key=lambda x: x[0], reverse=True)

    # Return the paths of the top N sharpest frames
    return [frame_path for _, frame_path in sharpness_scores[:top_n]]


def _upload_frames(frames: list[Path], job_id: str) -> list[str]:
    """Upload each frame to s3://BUCKET_NAME/{job_id}/filename and return their URLs."""
    uploaded_urls = []
    for frame_path in frames:
        key = f"{job_id}/{frame_path.name}"
        s3.upload_file(str(frame_path), BUCKET_NAME, key)
        # Construct the S3 URL
        url = f"https://{BUCKET_NAME}.s3.amazonaws.com/{key}"
        uploaded_urls.append(url)
    return uploaded_urls


def _send_callback(url: str, payload: dict):
    """Send a POST request to the backend with the results."""
    try:
        headers = {
            "Content-Type": "application/json",
            "x-lambda-secret": LAMBDA_SECRET,
        }
        response = requests.patch(url, headers=headers, json=payload, timeout=5)
        response.raise_for_status()  # Raise an exception for bad status codes
        print(f"Successfully sent callback to {url}")
    except requests.RequestException as e:
        print(f"Error sending callback to {url}: {e}")
        # Depending on the use case, you might want to raise this exception
        # to have the Lambda function fail and possibly be retried.
        raise


def handler(event, context):
    """AWS Lambda entrypoint.

    Expected event shape:
    {
        "job_id": "...",      # Job ID from the database
        "video_url": "https://...", # Video URL
        "callback_url": "https://...", # URL to notify upon completion
        "frame_rate": "1"      # Optional override fps
    }
    """
    job_id = event.get("job_id")
    video_url = event.get("video_url")
    callback_url = event.get("callback_url")

    if not all([job_id, video_url, callback_url]):
        # No callback possible, so just fail
        raise ValueError("'job_id', 'video_url', and 'callback_url' are required")

    try:
        fps = str(event.get("frame_rate") or "1")

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            video_path = _download_video(video_url, tmpdir_path)
            frames_dir = tmpdir_path / "frames"

            all_frames = _extract_frames(video_path, frames_dir, fps)
            if not all_frames:
                raise RuntimeError("No frames were extracted from the video.")

            selected_frames = _analyze_and_select_frames(all_frames, top_n=5)
            if not selected_frames:
                raise RuntimeError("Could not select any sharp frames.")

            uploaded_urls = _upload_frames(selected_frames, job_id)

        # Prepare and send the callback
        callback_payload = {
            "status": "SELECTING_FRAMES",
            "frame_count": len(all_frames),
            "selected_frame_urls": uploaded_urls,
        }
        _send_callback(callback_url, callback_payload)

        # The primary return of the Lambda is for invocation logs, not the backend.
        return {"statusCode": 200, "body": json.dumps(callback_payload)}

    except Exception as exc:
        # Log error and send a failure callback
        print(f"Error processing job {job_id}: {exc}")
        failure_payload = {
            "status": "FAILED",
            "error_message": str(exc),
        }
        _send_callback(callback_url, failure_payload)
        
        # Re-raise the exception to mark the Lambda execution as failed
        raise 