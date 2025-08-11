# Use the official AWS Lambda Python 3.11 base image.
# This image includes the Lambda Runtime Interface Client (RIC), which is required.
FROM public.ecr.aws/lambda/python:3.11

# Set the working directory in the container
WORKDIR ${LAMBDA_TASK_ROOT}

# Copy the requirements file into the container
COPY requirements.txt .

# Install dependencies using pip.
# The --no-cache-dir option reduces the image size.
RUN pip install --no-cache-dir -r requirements.txt && \
    echo "Verifying ffmpeg availability..." && \
    python - <<'PY'
from imageio_ffmpeg import get_ffmpeg_exe
print('ffmpeg at', get_ffmpeg_exe())
PY

# Copy the rest of the function code and any assets into the container.
# This includes your handler file and the cookies.txt file.
COPY lambda_function.py .
COPY cookies.txt .

# Set the command to run when the container starts.
# AWS Lambda will invoke the 'handler' function in the 'lambda_function' module.
CMD [ "lambda_function.handler" ] 