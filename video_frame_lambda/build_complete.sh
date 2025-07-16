#!/bin/bash

# This script prepares the Lambda function code for deployment,
# assuming that large libraries like OpenCV are in a Lambda Layer.

set -e

# --- Configuration ---
PACKAGE_NAME="steez-video-frame-extractor"
REQUIREMENTS_FILE="requirements.txt"
OUTPUT_DIR="build"
OUTPUT_ZIP="${PACKAGE_NAME}.zip"

# --- Script Start ---
echo "Creating build directory..."
rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

echo "Copying function code and assets..."
cp lambda_function.py $OUTPUT_DIR/
cp cookies.txt $OUTPUT_DIR/

echo "Installing remaining dependencies..."
# This installs packages listed in requirements.txt into the build directory.
# The dependencies should NOT include libraries provided by the layer.
if [ -f "$REQUIREMENTS_FILE" ]; then
    pip install -r $REQUIREMENTS_FILE -t $OUTPUT_DIR/
else
    echo "No requirements.txt file found, skipping package installation."
fi

echo "Creating final zip package..."
# Change to the build directory to create the zip with the correct structure
(cd $OUTPUT_DIR && zip -r ../${OUTPUT_ZIP} .)

# --- Cleanup ---
echo "Cleaning up build directory..."
rm -rf $OUTPUT_DIR

# --- Finished ---
echo "✅ Success! Lambda package created: ./${OUTPUT_ZIP}"
echo ""
echo "Next Steps:"
echo "1. Upload '${OUTPUT_ZIP}' to your Lambda function in the AWS Console."
echo "2. Ensure you have created and attached the OpenCV Lambda Layer to your function." 