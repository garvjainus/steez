#!/bin/bash

# Build Lambda function with layers to stay under 50MB limit

set -e

echo "🔧 Building Lambda with layers..."

# Clean up
rm -rf layer_package function_package lambda_layer.zip lambda_function.zip

# Create directories
mkdir -p layer_package/python
mkdir -p function_package

echo "📦 Building dependencies layer..."
# Install heavy dependencies in layer
pip3 install --target layer_package/python -r requirements.txt

echo "📋 Building function package..."
# Only include your code in function
cp lambda_function.py function_package/

echo "🗜️ Creating layer zip..."
cd layer_package
zip -r ../lambda_layer.zip .
cd ..

echo "🗜️ Creating function zip..."
cd function_package
zip -r ../lambda_function.zip .
cd ..

echo "✅ Build complete!"
echo "📊 Package sizes:"
ls -lh lambda_layer.zip lambda_function.zip

echo ""
echo "🚀 Next steps:"
echo "1. Upload lambda_layer.zip as a Lambda Layer"
echo "2. Upload lambda_function.zip as your Lambda function"
echo "3. Attach the layer to your function" 