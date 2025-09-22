# Production YOLO Clothing Segmentation Service
# Based on video_frame_lambda production patterns

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies for OpenCV and other requirements
RUN apt-get update && apt-get install -y \
    # Essential system packages
    curl \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libgtk-3-0 \
    libgl1-mesa-glx \
    libgthread-2.0-0 \
    # Cleanup to reduce image size
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy requirements and install Python dependencies
COPY requirements.txt .

# Install dependencies with optimizations for production
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    # Verify YOLO can import properly
    python -c "from ultralytics import YOLO; print('YOLO import successful')" && \
    python -c "import torch; print(f'PyTorch version: {torch.__version__}')" && \
    python -c "import cv2; print(f'OpenCV version: {cv2.__version__}')"

# Copy application code
COPY segmentation_handler.py .
COPY service.py .

# Create directories for model cache and temporary files
RUN mkdir -p /root/.cache/ultralytics && \
    mkdir -p /tmp/segmentation_temp && \
    chmod 755 /tmp/segmentation_temp

# Create non-root user for security (optional, comment out if root needed)
# RUN addgroup --gid 1001 appgroup && \
#     adduser --uid 1001 --gid 1001 --disabled-password --gecos "" appuser && \
#     chown -R appuser:appgroup /app /root/.cache /tmp/segmentation_temp
# USER appuser

# Environment variables
ENV HOST=0.0.0.0
ENV PORT=8001
ENV YOLO_MODEL_SIZE=yolov8n-seg.pt
ENV MAX_IMAGE_SIZE_MB=10
ENV ENABLE_GPU=true
ENV PROCESSING_TIMEOUT_SECONDS=30
ENV PYTHONUNBUFFERED=1

# Expose port
EXPOSE 8001

# Health check with proper timeout for model loading
HEALTHCHECK --interval=30s --timeout=45s --start-period=120s --retries=3 \
  CMD curl -f http://localhost:8001/health || exit 1

# Run the application
CMD ["python", "service.py"]
