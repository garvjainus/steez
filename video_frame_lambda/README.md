### Video Frame Extraction Lambda

This Lambda downloads a remote video (TikTok / Instagram etc.) using `yt-dlp` and extracts frames with **ffmpeg**.

* Runtime: Python 3.12
* Entry: `lambda_function.handler`

#### Environment variables

| Variable | Purpose | Default |
| -------- | ------- | ------- |
| `FRAME_BUCKET` | S3 bucket where frames will be saved | `steez-video-frames` |
| `FRAME_RATE` | How many frames per second to capture | `1` |

#### Local development

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest      # run tests
```

#### Deploy with AWS SAM (one option)

```bash
sam build --use-container
sam deploy --guided
```

Or simply zip the code and dependencies (including the `imageio_ffmpeg` binary) and upload via the AWS console.

#### Notes on ffmpeg

We rely on the `imageio-ffmpeg` package which downloads a static ffmpeg binary at import time and thus works inside the Lambda / AWS Linux environment. 