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

# Restrict which domains videos can be downloaded from. Comma-separated list in env or default safe list.
ALLOWED_VIDEO_DOMAINS = set(
    (_get_env("ALLOWED_VIDEO_DOMAINS", "tiktok.com,instagram.com,instagramcdn.com,youtube.com,youtu.be").split(","))
)

# Maximum video file size yt-dlp may download (to avoid DoS / wallet burn). Example: "50M".
MAX_FILESIZE = _get_env("MAX_VIDEO_FILESIZE", "100M")


def _parse_size_to_bytes(value: str | int) -> int:
    """Convert '100M'/'2G'/int strings to bytes for yt-dlp 'max_filesize'."""
    if isinstance(value, int):
        return value
    s = str(value).strip().upper()
    try:
        return int(s)
    except ValueError:
        pass
    multipliers = {"K": 1024, "M": 1024**2, "G": 1024**3}
    if s[-1] in multipliers:
        return int(float(s[:-1]) * multipliers[s[-1]])
    # Default: best effort
    return int(float(s))


def _download_video(url: str, tmp_dir: Path) -> Path:
    """Download remote video with yt-dlp and return the actual file Path."""

    # --- Security: Domain allow-list -------------------------------------------------
    from urllib.parse import urlparse

    hostname = urlparse(url).hostname or ""
    if not any(hostname.endswith(d.strip()) for d in ALLOWED_VIDEO_DOMAINS):
        raise RuntimeError(f"Domain '{hostname}' is not in ALLOWED_VIDEO_DOMAINS")

    # Save as video.<ext> inside tmp_dir, letting yt-dlp choose correct extension
    outtmpl = str(tmp_dir / "video.%(ext)s")

    # Ensure yt-dlp can find ffmpeg if it needs to (merging, etc.)
    ffmpeg_exe = get_ffmpeg_exe()
    ffmpeg_dir = str(Path(ffmpeg_exe).parent)

    # Prepare cookie file in writable /tmp to avoid read-only filesystem errors
    cookie_src = Path(__file__).with_name("cookies.txt")
    cookie_dst = tmp_dir / "cookies.txt"
    if cookie_src.exists():
        try:
            shutil.copyfile(cookie_src, cookie_dst)
        except Exception as copy_err:
            print(f"Warning: failed to copy cookies.txt to tmp: {copy_err}")
            cookie_dst = None
    else:
        cookie_dst = None

    ydl_opts = {
        "outtmpl": outtmpl,
        "quiet": True,
        "no_warnings": True,
        # Prefer a single-file format to avoid merging when possible
        "format": "best",
        # Abort downloads larger than this (bytes)
        "max_filesize": _parse_size_to_bytes(MAX_FILESIZE),
        "socket_timeout": 15,
        # Tell yt-dlp where ffmpeg lives (in case merging is still required)
        "ffmpeg_location": ffmpeg_dir,
        # Ensure all yt-dlp writes go to the writable /tmp space in Lambda
        "paths": {"home": str(tmp_dir), "temp": str(tmp_dir)},
        "cachedir": str(tmp_dir),
        "no_cache_dir": True,
    }

    # Only set cookiefile if we have one in a writable tmp path
    if cookie_dst is not None:
        ydl_opts["cookiefile"] = str(cookie_dst)

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
    """Upload each frame to s3://BUCKET_NAME/{job_id}/filename and return their presigned URLs."""
    uploaded_urls = []
    for frame_path in frames:
        key = f"{job_id}/{frame_path.name}"
        s3.upload_file(str(frame_path), BUCKET_NAME, key)
        # Create a presigned URL
        presigned_url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": BUCKET_NAME, "Key": key},
            ExpiresIn=3600,  # URL expires in 1 hour
        )
        uploaded_urls.append(presigned_url)
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