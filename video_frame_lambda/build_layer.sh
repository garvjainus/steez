#!/bin/bash

# This script creates a .zip file suitable for an AWS Lambda Layer
# that contains the opencv-python-headless library.

# --- Configuration ---
# The runtime you are using on your Lambda function.
# Must match one of the supported runtimes.
# Example: python3.8, python3.9, python3.10, python3.11, python3.12
PYTHON_VERSION="python3.11"
LAYER_NAME="opencv_layer"
REQUIREMENTS_FILE="layer_requirements.txt"
OUTPUT_DIR="build"

# --- Script Start ---
set -e # Exit immediately if a command exits with a non-zero status.

echo "Creating requirements file for the layer..."
echo "opencv-python-headless" > $REQUIREMENTS_FILE

echo "Creating build directory..."
rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

# AWS Lambda Layers require a specific folder structure.
# For Python, it's python/lib/<python_version>/site-packages
INSTALL_PATH="$OUTPUT_DIR/python/lib/$PYTHON_VERSION/site-packages"
echo "Creating installation path: $INSTALL_PATH"
mkdir -p $INSTALL_PATH

echo "Installing opencv-python-headless into '$INSTALL_PATH'..."
# Use pip to install the package into our target directory
python3 -m pip install --platform manylinux2014_x86_64 --implementation cp --python-version 3.11 --only-binary=:all: --upgrade -r $REQUIREMENTS_FILE -t $INSTALL_PATH

echo "Creating zip file for the layer..."
# The zip file should contain the 'python' directory.
# We change directory into the build dir to get the correct zip structure.
(cd $OUTPUT_DIR && zip -r ../${LAYER_NAME}.zip .)

# --- Cleanup ---
echo "Cleaning up build artifacts..."
rm -rf $OUTPUT_DIR
rm $REQUIREMENTS_FILE

# --- Finished ---
echo "✅ Success! Layer package created: ./${LAYER_NAME}.zip"
echo ""
echo "Next Steps:"
echo "1. Go to the AWS Lambda Console."
echo "2. Navigate to 'Layers' in the left-hand menu."
echo "3. Click 'Create layer'."
echo "4. Name your layer (e.g., 'OpenCV-for-Python-3-11')."
echo "5. Upload '${LAYER_NAME}.zip'."
echo "6. Select 'x86_64' architecture."
echo "7. Select 'Python 3.11' as a compatible runtime."
echo "8. Click 'Create'."
echo "After creating the layer, I will guide you on how to attach it to your Lambda function." 