#!/bin/bash

# Deploy large Lambda package via S3 (bypasses 50MB console limit)

set -e

BUCKET_NAME="your-lambda-deployment-bucket"
FUNCTION_NAME="steez-video-frame-extractor"

echo "🔧 Deploying large Lambda package via S3..."

# Build the package (assuming you have lambda_deployment.zip)
if [ ! -f "lambda_deployment.zip" ]; then
    echo "Building package first..."
    ./build_lambda.sh
fi

echo "📤 Uploading to S3..."
aws s3 cp lambda_deployment.zip s3://$BUCKET_NAME/lambda_deployment.zip

echo "🚀 Updating Lambda function from S3..."
aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --s3-bucket $BUCKET_NAME \
    --s3-key lambda_deployment.zip

echo "✅ Deployment complete!"
echo "📊 Function updated from S3" 