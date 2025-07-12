#!/bin/bash

# Deploy script for video frame extraction Lambda function

FUNCTION_NAME="steez-video-frame-extractor"
ROLE_NAME="lambda-video-frame-role"
REGION="us-east-1"

echo "Creating IAM role for Lambda..."
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }'

echo "Attaching policies to role..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

echo "Waiting for role to be ready..."
sleep 10

echo "Creating Lambda function..."
aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime python3.13 \
    --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$ROLE_NAME \
    --handler lambda_function.handler \
    --zip-file fileb://lambda.zip \
    --timeout 900 \
    --memory-size 1024 \
    --environment Variables='{FRAME_BUCKET=steez-video-frames,FRAME_RATE=1}' \
    --ephemeral-storage Size=2048

echo "Lambda function created successfully!" 