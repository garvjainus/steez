import importlib
import types


def test_missing_url(monkeypatch):
    # Lazy import because lambda_function expects boto3 (available in test env)
    lf = importlib.import_module("video_frame_lambda.lambda_function")
    result = lf.handler({}, None)
    assert result["statusCode"] == 400


def test_valid_event(monkeypatch):
    # Mock heavy ops to keep tests fast and offline
    lf = importlib.import_module("video_frame_lambda.lambda_function")

    # Patch _download_video to create dummy file
    def fake_download(url, dest):
        dest.write_bytes(b"fake video content")

    # Patch _extract_frames to simulate 3 frames
    def fake_extract(video, frames_dir, fps):
        frames_dir.mkdir(parents=True, exist_ok=True)
        frames = []
        for i in range(3):
            frame_path = frames_dir / f"frame_{i:05d}.jpg"
            frame_path.write_bytes(b"fakeframe")
            frames.append(frame_path)
        return frames

    # Patch S3 upload
    class DummyS3:
        def upload_file(self, src, bucket, key):
            pass

    monkeypatch.setattr(lf, "_download_video", fake_download, raising=False)
    monkeypatch.setattr(lf, "_extract_frames", fake_extract, raising=False)
    monkeypatch.setattr(lf, "s3", DummyS3())

    event = {"url": "https://example.com/video"}
    result = lf.handler(event, None)
    assert result["statusCode"] == 200
    body = result["body"]
    assert "jobId" in body 