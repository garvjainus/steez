#!/bin/bash

# This script builds and tags the Docker container for the Lambda function.

set -e

# --- Configuration ---
# Your AWS Account ID. You MUST replace this with your actual account ID.
AWS_ACCOUNT_ID="222482127896"

# The AWS region where your ECR repository exists.
AWS_REGION="eu-north-1"

# The name of the ECR repository. This should match the one you create in AWS.
ECR_REPO_NAME="steez-video-frame-extractor"

# The name for the Docker image.
IMAGE_NAME="steez-lambda"

# --- Script Start ---

# Change to the directory where the Dockerfile is located
cd "$(dirname "$0")"

echo "Building the Docker image..."

# The build command uses the Dockerfile in the current directory.
docker build -t $IMAGE_NAME .

echo "✅ Docker image '$IMAGE_NAME' built successfully."
echo ""

# --- ECR Login and Push Instructions ---
echo "Next Steps to Push to ECR:"
echo "-------------------------------------"
echo "1. IMPORTANT: Make sure you have created the ECR repository named '$ECR_REPO_NAME' in the '$AWS_REGION' region."
echo ""
echo "2. Authenticate Docker to your Amazon ECR registry:"
echo "   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo ""
echo "3. Tag your local image with the ECR repository URI:"
echo "   docker tag $IMAGE_NAME:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:latest"
echo ""
echo "4. Push the image to ECR:"
echo "   docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:latest"
echo ""
echo "5. After pushing, you will have an Image URI. Use it to create your new Lambda function in the AWS Console."
echo "-------------------------------------" 