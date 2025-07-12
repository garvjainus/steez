#!/bin/bash

# Simple Lambda build script for Linux environments
# Use this in GitHub Codespaces, Google Colab, or any Linux VM

set -e

echo "🔧 Building Lambda deployment package..."

# Clean up any previous builds
rm -rf package lambda_deployment.zip

# Create package directory
mkdir package

echo "📦 Installing Python dependencies..."
pip3 install --target package -r requirements.txt

echo "📋 Copying Lambda function..."
cp lambda_function.py package/

echo "🗜️ Creating deployment zip..."
cd package
zip -r ../lambda_deployment.zip .
cd ..

echo "✅ Build complete!"
echo "📊 Package size:"
ls -lh lambda_deployment.zip

echo ""
echo "🚀 Next steps:"
echo "1. Download lambda_deployment.zip"
echo "2. Upload to your Lambda function in AWS Console"
echo "3. Test with the provided test event" 