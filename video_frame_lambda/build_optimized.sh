#!/bin/bash

# Build optimized Lambda package (remove unnecessary files to reduce size)

set -e

echo "🔧 Building optimized Lambda package..."

# Clean up
rm -rf package lambda_optimized.zip

# Create package directory
mkdir package

echo "📦 Installing dependencies..."
pip3 install --target package -r requirements.txt

echo "🗜️ Optimizing package size..."

# Remove unnecessary files to reduce size
find package -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
find package -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find package -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find package -name "*.pyc" -delete 2>/dev/null || true
find package -name "*.pyo" -delete 2>/dev/null || true

# Remove docs and examples
find package -type d -name "docs" -exec rm -rf {} + 2>/dev/null || true
find package -type d -name "examples" -exec rm -rf {} + 2>/dev/null || true
find package -name "*.md" -delete 2>/dev/null || true
find package -name "*.txt" -delete 2>/dev/null || true
find package -name "LICENSE*" -delete 2>/dev/null || true

echo "📋 Adding Lambda function..."
cp lambda_function.py package/

echo "🗜️ Creating optimized zip..."
cd package
zip -r ../lambda_optimized.zip . -x "*.DS_Store*" "*.git*"
cd ..

echo "✅ Optimization complete!"
echo "📊 Package size:"
ls -lh lambda_optimized.zip

# Check if still too big
SIZE=$(stat -f%z lambda_optimized.zip 2>/dev/null || stat -c%s lambda_optimized.zip)
if [ $SIZE -gt 52428800 ]; then
    echo "⚠️  Still over 50MB - use Lambda Layers or S3 deployment"
else
    echo "✅ Under 50MB - ready for console upload!"
fi 