#!/bin/bash

# Production build script for YOLO Segmentation Service
# Based on video_frame_lambda build patterns

set -e

# --- Configuration ---
# Docker image configuration
IMAGE_NAME="yolo-segmentation-service"
VERSION=${1:-"latest"}
REGISTRY=${REGISTRY:-""}  # Set to your registry URL if pushing to remote

# Build configuration
BUILD_CONTEXT="."
DOCKERFILE_PATH="Dockerfile"

# Optional: Multi-architecture builds
PLATFORMS="linux/amd64,linux/arm64"
ENABLE_MULTI_ARCH=${ENABLE_MULTI_ARCH:-false}

# --- Script Start ---

# Change to the directory where the Dockerfile is located
cd "$(dirname "$0")"

echo "🏗️  Building YOLO Segmentation Service"
echo "================================================"
echo "Image: $IMAGE_NAME:$VERSION"
echo "Context: $BUILD_CONTEXT"
echo "Dockerfile: $DOCKERFILE_PATH"
echo ""

# Validate requirements
echo "📋 Validating build requirements..."

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running"
    exit 1
fi

# Check if required files exist
required_files=("requirements.txt" "segmentation_handler.py" "service.py" "Dockerfile")
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ Required file missing: $file"
        exit 1
    fi
done

echo "✅ Build requirements validated"
echo ""

# Pre-build verification
echo "🔍 Pre-build verification..."
echo "Python files syntax check:"

# Check Python syntax
python3 -m py_compile segmentation_handler.py || {
    echo "❌ Syntax error in segmentation_handler.py"
    exit 1
}

python3 -m py_compile service.py || {
    echo "❌ Syntax error in service.py"
    exit 1
}

echo "✅ Python syntax check passed"
echo ""

# Build the Docker image
echo "🔨 Building Docker image..."
build_start_time=$(date +%s)

if [[ "$ENABLE_MULTI_ARCH" == "true" ]]; then
    echo "Building multi-architecture image..."
    docker buildx build \
        --platform $PLATFORMS \
        --tag $IMAGE_NAME:$VERSION \
        --file $DOCKERFILE_PATH \
        $BUILD_CONTEXT \
        ${REGISTRY:+--push}
else
    echo "Building single-architecture image..."
    docker build \
        --tag $IMAGE_NAME:$VERSION \
        --file $DOCKERFILE_PATH \
        $BUILD_CONTEXT
fi

build_end_time=$(date +%s)
build_duration=$((build_end_time - build_start_time))

echo "✅ Docker image built successfully in ${build_duration}s"
echo ""

# Post-build verification
echo "🧪 Post-build verification..."

# Test that the container can start and respond to health checks
echo "Testing container startup..."
container_id=$(docker run -d -p 8001:8001 $IMAGE_NAME:$VERSION)

# Wait for startup with timeout
echo "Waiting for service to start (timeout: 60s)..."
timeout=60
elapsed=0
while [[ $elapsed -lt $timeout ]]; do
    if curl -f http://localhost:8001/health &> /dev/null; then
        echo "✅ Service started successfully and health check passed"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done

if [[ $elapsed -ge $timeout ]]; then
    echo "❌ Service failed to start within timeout"
    docker logs $container_id
    docker stop $container_id
    docker rm $container_id
    exit 1
fi

# Test basic functionality
echo "Testing segmentation endpoint..."
if curl -f http://localhost:8001/ &> /dev/null; then
    echo "✅ Service endpoints are responding"
else
    echo "⚠️  Service started but endpoints may not be fully ready"
fi

# Cleanup test container
docker stop $container_id
docker rm $container_id

echo "✅ Post-build verification completed"
echo ""

# Image information
echo "📊 Build Information"
echo "================================================"
echo "Image: $IMAGE_NAME:$VERSION"
echo "Size: $(docker images $IMAGE_NAME:$VERSION --format "table {{.Size}}" | tail -n 1)"
echo "Created: $(docker images $IMAGE_NAME:$VERSION --format "table {{.CreatedAt}}" | tail -n 1)"
echo "Build time: ${build_duration}s"
echo ""

# Show image layers (for optimization insights)
echo "🔍 Image layers:"
docker history $IMAGE_NAME:$VERSION --format "table {{.CreatedBy}}\t{{.Size}}" | head -10
echo ""

# Registry push instructions
if [[ -n "$REGISTRY" ]]; then
    echo "📤 Registry Push Commands"
    echo "================================================"
    echo "Tag for registry:"
    echo "  docker tag $IMAGE_NAME:$VERSION $REGISTRY/$IMAGE_NAME:$VERSION"
    echo ""
    echo "Push to registry:"
    echo "  docker push $REGISTRY/$IMAGE_NAME:$VERSION"
    echo ""
else
    echo "📤 To push to a registry:"
    echo "================================================"
    echo "1. Tag the image:"
    echo "   docker tag $IMAGE_NAME:$VERSION your-registry.com/$IMAGE_NAME:$VERSION"
    echo ""
    echo "2. Push to registry:"
    echo "   docker push your-registry.com/$IMAGE_NAME:$VERSION"
    echo ""
fi

# Deployment instructions
echo "🚀 Deployment Commands"
echo "================================================"
echo "Local deployment:"
echo "  docker run -d \\"
echo "    --name yolo-segmentation \\"
echo "    -p 8001:8001 \\"
echo "    -e YOLO_MODEL_SIZE=yolov8n-seg.pt \\"
echo "    -e MAX_IMAGE_SIZE_MB=10 \\"
echo "    -e ENABLE_GPU=false \\"
echo "    $IMAGE_NAME:$VERSION"
echo ""
echo "GPU deployment (if NVIDIA Docker runtime available):"
echo "  docker run -d \\"
echo "    --name yolo-segmentation \\"
echo "    --gpus all \\"
echo "    -p 8001:8001 \\"
echo "    -e ENABLE_GPU=true \\"
echo "    $IMAGE_NAME:$VERSION"
echo ""
echo "Health check:"
echo "  curl http://localhost:8001/health"
echo ""
echo "API docs:"
echo "  http://localhost:8001/docs"
echo ""

# Production deployment notes
echo "📝 Production Deployment Notes"
echo "================================================"
echo "• Set appropriate resource limits (CPU/Memory)"
echo "• Configure proper logging and monitoring"
echo "• Use environment variables for configuration"
echo "• Consider using GPU for better performance"
echo "• Set up load balancing for high availability"
echo "• Monitor model download and cache directories"
echo "• Configure proper network security groups"
echo ""

echo "🎉 Build completed successfully!"
echo "Image: $IMAGE_NAME:$VERSION is ready for deployment"
