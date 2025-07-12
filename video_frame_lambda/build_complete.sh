#!/bin/bash

# Build complete Lambda package (keeps all necessary files)

set -e

echo "🔧 Building complete Lambda package..."

# Clean up
rm -rf package lambda_complete.zip

# Create package directory
mkdir package

echo "📦 Installing ALL dependencies (no optimization)..."
pip3 install --target package -r requirements.txt

echo "📋 Adding Lambda function and cookies (if present)..."
cp lambda_function.py package/
# Copy Instagram cookies if the file exists
if [ -f cookies.txt ]; then
  cp cookies.txt package/
  echo "🍪 Copied cookies.txt into package/"
else
  echo "⚠️  cookies.txt not found – Instagram reels may fail without auth"
fi

echo "🗜️ Creating complete zip..."
cd package
zip -r ../lambda_complete.zip .
cd ..

echo "✅ Complete build done!"
echo "📊 Package size:"
ls -lh lambda_complete.zip

echo ""
echo "🚀 Next steps:"
echo "1. Upload lambda_complete.zip to S3"
echo "2. Deploy from S3 to Lambda"
echo "3. This should work without import errors" 