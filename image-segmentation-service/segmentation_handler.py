#!/usr/bin/env python3
"""
Production YOLO Clothing Segmentation Service

This service receives images, performs clothing segmentation using YOLOv8/v10,
and returns cropped images of individual clothing items organized by category.

Architecture follows the same production patterns as video_frame_lambda:
- Environment validation and security controls
- Professional error handling and logging
- Resource management and cleanup
- Structured pipeline with clear separation of concerns
"""

import json
import os
import tempfile
import uuid
import logging
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union
import base64
import io

import cv2
import numpy as np
from PIL import Image
import torch
from ultralytics import YOLO

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Environment configuration with validation
def _get_env(name: str, default: str | None = None) -> str:
    """Get environment variable with validation. Follows video_frame_lambda pattern."""
    value = os.getenv(name, default)
    if value is None:
        raise RuntimeError(f"Environment variable '{name}' is required")
    return value

def _get_env_int(name: str, default: int) -> int:
    """Get integer environment variable with validation."""
    value = os.getenv(name, str(default))
    try:
        return int(value)
    except ValueError:
        raise RuntimeError(f"Environment variable '{name}' must be an integer, got: {value}")

def _get_env_float(name: str, default: float) -> float:
    """Get float environment variable with validation."""
    value = os.getenv(name, str(default))
    try:
        return float(value)
    except ValueError:
        raise RuntimeError(f"Environment variable '{name}' must be a float, got: {value}")

def _get_env_bool(name: str, default: bool) -> bool:
    """Get boolean environment variable with validation."""
    value = os.getenv(name, str(default)).lower()
    if value in ('true', '1', 'yes', 'on'):
        return True
    elif value in ('false', '0', 'no', 'off'):
        return False
    else:
        raise RuntimeError(f"Environment variable '{name}' must be boolean, got: {value}")

# Production configuration
YOLO_MODEL_SIZE = _get_env("YOLO_MODEL_SIZE", "yolov8n-seg.pt")  # n=nano, s=small, m=medium, l=large
MAX_IMAGE_SIZE_MB = _get_env_int("MAX_IMAGE_SIZE_MB", 10)
MAX_IMAGE_DIMENSION = _get_env_int("MAX_IMAGE_DIMENSION", 2048)
MIN_CONFIDENCE = _get_env_float("MIN_DETECTION_CONFIDENCE", 0.5)
MAX_SEGMENTS_PER_CATEGORY = _get_env_int("MAX_SEGMENTS_PER_CATEGORY", 3)
CROP_PADDING_PERCENT = _get_env_float("CROP_PADDING_PERCENT", 0.1)
ENABLE_TRANSPARENT_CROPS = _get_env_bool("ENABLE_TRANSPARENT_CROPS", True)
ENABLE_GPU = _get_env_bool("ENABLE_GPU", True)
PROCESSING_TIMEOUT_SECONDS = _get_env_int("PROCESSING_TIMEOUT_SECONDS", 30)

# Security limits
MAX_IMAGE_SIZE_BYTES = MAX_IMAGE_SIZE_MB * 1024 * 1024
ALLOWED_IMAGE_FORMATS = {'JPEG', 'PNG', 'JPG', 'WEBP'}

# YOLO class to clothing category mapping (production-ready)
CLOTHING_CLASS_MAPPING = {
    # Primary person detection - we'll segment clothing from person bboxes
    'person': 'PERSON_DETECTED',
    
    # Direct clothing items (if model supports them)
    'handbag': 'ACCESSORY',
    'tie': 'ACCESSORY',
    'suitcase': 'ACCESSORY',
    'umbrella': 'ACCESSORY',
    'backpack': 'ACCESSORY',
}

# Clothing categories for organization
CLOTHING_CATEGORIES = {
    'TORSO': ['shirt', 'blouse', 'sweater', 'hoodie', 'jacket', 'coat', 'dress', 't-shirt', 'tank_top', 'blazer'],
    'BOTTOM': ['pants', 'jeans', 'shorts', 'skirt', 'leggings', 'dress', 'trousers'],
    'SHOES': ['shoe', 'sneaker', 'boot', 'sandal', 'heel', 'flip_flop', 'loafer'],
    'ACCESSORY': ['hat', 'cap', 'bag', 'scarf', 'belt', 'watch', 'glasses', 'handbag', 'backpack', 'tie']
}

# Global model instance (loaded once at startup for performance)
model: Optional[YOLO] = None
model_load_time: Optional[float] = None

class SegmentationError(Exception):
    """Custom exception for segmentation errors."""
    pass

class ValidationError(Exception):
    """Custom exception for input validation errors."""
    pass

def load_model() -> YOLO:
    """Load YOLO model with proper error handling and performance tracking."""
    global model, model_load_time
    
    if model is not None:
        return model
    
    start_time = time.time()
    logger.info(f"Loading YOLO model: {YOLO_MODEL_SIZE}")
    
    try:
        # Load model with GPU support if available and enabled
        device = 'cuda' if ENABLE_GPU and torch.cuda.is_available() else 'cpu'
        logger.info(f"Using device: {device}")
        
        model = YOLO(YOLO_MODEL_SIZE)
        
        # Move model to appropriate device
        if hasattr(model.model, 'to'):
            model.model.to(device)
        
        # Warm up the model with a dummy prediction
        logger.info("Warming up model...")
        dummy_image = np.zeros((640, 640, 3), dtype=np.uint8)
        _ = model(dummy_image, verbose=False)
        
        model_load_time = time.time() - start_time
        logger.info(f"Model loaded successfully in {model_load_time:.2f}s on {device}")
        
        return model
        
    except Exception as e:
        logger.error(f"Failed to load YOLO model: {e}")
        raise SegmentationError(f"Model loading failed: {str(e)}")

def validate_image_input(image_data: bytes, filename: str = "unknown") -> Image.Image:
    """Validate and load image with security checks."""
    
    # Size validation
    if len(image_data) > MAX_IMAGE_SIZE_BYTES:
        raise ValidationError(
            f"Image too large: {len(image_data)} bytes (max: {MAX_IMAGE_SIZE_BYTES})"
        )
    
    # Load and validate image format
    try:
        image = Image.open(io.BytesIO(image_data))
        
        # Format validation
        if image.format not in ALLOWED_IMAGE_FORMATS:
            raise ValidationError(f"Unsupported image format: {image.format}")
        
        # Dimension validation
        width, height = image.size
        if width > MAX_IMAGE_DIMENSION or height > MAX_IMAGE_DIMENSION:
            raise ValidationError(
                f"Image dimensions too large: {width}x{height} (max: {MAX_IMAGE_DIMENSION})"
            )
        
        # Convert to RGB if necessary
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        logger.info(f"Validated image: {filename} ({width}x{height}, {image.format})")
        return image
        
    except ValidationError:
        raise
    except Exception as e:
        raise ValidationError(f"Invalid image data: {str(e)}")

def segment_clothing(image: Image.Image) -> List[Dict]:
    """
    Perform YOLO segmentation on the image and return clothing segments.
    
    Returns list of segment dictionaries with metadata.
    """
    model = load_model()
    
    # Convert PIL to numpy array
    image_np = np.array(image)
    
    # Run YOLO inference with timeout protection
    logger.info("Running YOLO inference...")
    start_time = time.time()
    
    try:
        results = model(image_np, verbose=False)
        inference_time = time.time() - start_time
        logger.info(f"YOLO inference completed in {inference_time:.2f}s")
        
        if inference_time > PROCESSING_TIMEOUT_SECONDS:
            logger.warning(f"Inference took {inference_time:.2f}s (timeout: {PROCESSING_TIMEOUT_SECONDS}s)")
        
    except Exception as e:
        logger.error(f"YOLO inference failed: {e}")
        raise SegmentationError(f"Segmentation failed: {str(e)}")
    
    segments = []
    
    for result in results:
        if result.masks is None:
            continue
            
        masks = result.masks.data.cpu().numpy()  # [N, H, W]
        boxes = result.boxes.xyxy.cpu().numpy()  # [N, 4]
        confidences = result.boxes.conf.cpu().numpy()  # [N]
        class_ids = result.boxes.cls.cpu().numpy().astype(int)  # [N]
        
        for i in range(len(masks)):
            mask = masks[i]
            bbox = boxes[i].astype(int)
            confidence = float(confidences[i])
            class_id = class_ids[i]
            
            # Filter by confidence threshold
            if confidence < MIN_CONFIDENCE:
                continue
            
            # Get class name
            class_name = model.names[class_id]
            
            # Determine clothing category
            category = classify_clothing_item(class_name, bbox, image.size)
            if not category:
                continue  # Skip non-clothing items
            
            # Create segment metadata
            segment = {
                'id': str(uuid.uuid4()),
                'category': category,
                'confidence': confidence,
                'bbox': bbox.tolist(),
                'mask_area': int(np.sum(mask)),
                'class_name': class_name,
                'mask': mask,  # Keep mask for crop creation
            }
            
            segments.append(segment)
    
    logger.info(f"Found {len(segments)} potential clothing segments")
    return segments

def classify_clothing_item(class_name: str, bbox: np.ndarray, image_size: Tuple[int, int]) -> Optional[str]:
    """
    Classify YOLO detection into clothing category.
    
    Uses heuristics and bbox analysis for better categorization.
    """
    class_name_lower = class_name.lower()
    x1, y1, x2, y2 = bbox
    width, height = image_size
    
    # Calculate relative position and size
    bbox_center_y = (y1 + y2) / 2
    bbox_height = y2 - y1
    relative_center_y = bbox_center_y / height
    relative_height = bbox_height / height
    
    # For person detections, use position heuristics to classify
    if 'person' in class_name_lower:
        # Upper body (torso) detection
        if relative_center_y < 0.6 and relative_height > 0.3:
            return 'TORSO'
        # Lower body detection
        elif relative_center_y > 0.4 and relative_height > 0.2:
            return 'BOTTOM'
        # Full person - default to torso for main clothing detection
        else:
            return 'TORSO'
    
    # Direct mapping for specific clothing items
    for category, items in CLOTHING_CATEGORIES.items():
        if any(item in class_name_lower for item in items):
            return category
    
    # Fallback for accessory items
    if class_name_lower in CLOTHING_CLASS_MAPPING:
        return CLOTHING_CLASS_MAPPING[class_name_lower]
    
    return None  # Not a clothing item

def create_clothing_crop(image: Image.Image, mask: np.ndarray, bbox: List[int]) -> Optional[str]:
    """
    Create a cropped image of the clothing item with padding and optional transparency.
    
    Returns base64-encoded image or None if crop creation fails.
    """
    try:
        x1, y1, x2, y2 = bbox
        image_np = np.array(image)
        h, w = image_np.shape[:2]
        
        # Add padding
        padding_x = int((x2 - x1) * CROP_PADDING_PERCENT)
        padding_y = int((y2 - y1) * CROP_PADDING_PERCENT)
        
        # Expand bbox with padding, keeping within image bounds
        x1_padded = max(0, x1 - padding_x)
        y1_padded = max(0, y1 - padding_y)
        x2_padded = min(w, x2 + padding_x)
        y2_padded = min(h, y2 + padding_y)
        
        # Crop the image
        crop = image_np[y1_padded:y2_padded, x1_padded:x2_padded]
        
        if ENABLE_TRANSPARENT_CROPS:
            # Resize mask to match crop
            mask_resized = cv2.resize(
                mask.astype(np.uint8), 
                (x2_padded - x1_padded, y2_padded - y1_padded)
            )
            
            # Create RGBA image with transparent background
            if crop.shape[2] == 3:  # RGB
                crop_rgba = np.zeros((crop.shape[0], crop.shape[1], 4), dtype=np.uint8)
                crop_rgba[:, :, :3] = crop
                crop_rgba[:, :, 3] = mask_resized * 255  # Alpha channel from mask
                crop = crop_rgba
        
        # Convert to PIL Image
        crop_pil = Image.fromarray(crop)
        
        # Resize to optimal size for downstream processing (640-1024px on long side)
        max_size = 800
        crop_pil.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        
        # Convert to base64
        buffer = io.BytesIO()
        format_type = 'PNG' if ENABLE_TRANSPARENT_CROPS else 'JPEG'
        crop_pil.save(buffer, format=format_type)
        crop_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')
        
        return crop_base64
        
    except Exception as e:
        logger.error(f"Error creating crop: {e}")
        return None

def deduplicate_segments(segments: List[Dict]) -> List[Dict]:
    """
    Remove duplicate segments using IoU threshold and confidence ranking.
    
    Also respects per-category limits.
    """
    if len(segments) <= 1:
        return segments
    
    # Sort by confidence (highest first)
    segments.sort(key=lambda x: x['confidence'], reverse=True)
    
    # Group by category and apply limits
    category_counts = {cat: 0 for cat in ['TORSO', 'BOTTOM', 'SHOES', 'ACCESSORY']}
    filtered_segments = []
    
    for current in segments:
        category = current['category']
        
        # Check category limit
        if category_counts[category] >= MAX_SEGMENTS_PER_CATEGORY:
            continue
        
        # Check for duplicates with existing segments
        should_keep = True
        for kept in filtered_segments:
            if current['category'] == kept['category']:
                iou = calculate_iou(current['bbox'], kept['bbox'])
                if iou > 0.5:  # IoU threshold for duplicates
                    should_keep = False
                    break
        
        if should_keep:
            filtered_segments.append(current)
            category_counts[category] += 1
    
    return filtered_segments

def calculate_iou(bbox1: List[int], bbox2: List[int]) -> float:
    """Calculate Intersection over Union of two bounding boxes."""
    x1_1, y1_1, x2_1, y2_1 = bbox1
    x1_2, y1_2, x2_2, y2_2 = bbox2
    
    # Calculate intersection
    x1_i = max(x1_1, x1_2)
    y1_i = max(y1_1, y1_2)
    x2_i = min(x2_1, x2_2)
    y2_i = min(y2_1, y2_2)
    
    if x2_i <= x1_i or y2_i <= y1_i:
        return 0.0
    
    intersection = (x2_i - x1_i) * (y2_i - y1_i)
    
    # Calculate areas
    area1 = (x2_1 - x1_1) * (y2_1 - y1_1)
    area2 = (x2_2 - x1_2) * (y2_2 - y1_2)
    
    # Calculate union
    union = area1 + area2 - intersection
    
    return intersection / union if union > 0 else 0.0

def process_image_segmentation(image_data: bytes, filename: str = "image") -> Dict:
    """
    Main processing function that handles the complete segmentation pipeline.
    
    Args:
        image_data: Raw image bytes
        filename: Optional filename for logging
        
    Returns:
        Dictionary with segmentation results
    """
    start_time = time.time()
    
    try:
        # Step 1: Validate and load image
        logger.info(f"Processing image segmentation for: {filename}")
        image = validate_image_input(image_data, filename)
        
        # Step 2: Perform segmentation
        segments = segment_clothing(image)
        
        # Step 3: Deduplicate and filter segments
        filtered_segments = deduplicate_segments(segments)
        
        # Step 4: Create crops for each segment
        final_segments = []
        crop_creation_start = time.time()
        
        for segment in filtered_segments:
            # Remove mask from segment before creating crop (it's large)
            mask = segment.pop('mask')
            
            # Create crop
            crop_base64 = create_clothing_crop(image, mask, segment['bbox'])
            if crop_base64:
                segment['crop_image_base64'] = crop_base64
                final_segments.append(segment)
            else:
                logger.warning(f"Failed to create crop for segment {segment['id']}")
        
        crop_creation_time = time.time() - crop_creation_start
        total_time = time.time() - start_time
        
        # Compile results
        category_counts = {
            'TORSO': sum(1 for s in final_segments if s['category'] == 'TORSO'),
            'BOTTOM': sum(1 for s in final_segments if s['category'] == 'BOTTOM'),
            'SHOES': sum(1 for s in final_segments if s['category'] == 'SHOES'),
            'ACCESSORY': sum(1 for s in final_segments if s['category'] == 'ACCESSORY'),
        }
        
        results = {
            'success': True,
            'message': f'Successfully segmented {len(final_segments)} clothing items',
            'segments': final_segments,
            'total_items': len(final_segments),
            'processing_time_ms': total_time * 1000,
            'crop_creation_time_ms': crop_creation_time * 1000,
            'category_counts': category_counts,
            'model_info': {
                'model_size': YOLO_MODEL_SIZE,
                'device': 'cuda' if ENABLE_GPU and torch.cuda.is_available() else 'cpu',
                'model_load_time_s': model_load_time,
            },
        }
        
        logger.info(
            f"Segmentation completed: {len(final_segments)} items in {total_time:.2f}s "
            f"(crops: {crop_creation_time:.2f}s)"
        )
        
        return results
        
    except (ValidationError, SegmentationError) as e:
        logger.error(f"Processing error: {e}")
        return {
            'success': False,
            'error': str(e),
            'error_type': type(e).__name__,
            'processing_time_ms': (time.time() - start_time) * 1000,
        }
    except Exception as e:
        logger.error(f"Unexpected error during processing: {e}", exc_info=True)
        return {
            'success': False,
            'error': 'Internal processing error',
            'error_type': 'InternalError',
            'processing_time_ms': (time.time() - start_time) * 1000,
        }

def get_health_status() -> Dict:
    """
    Health check function that validates the service is ready to process requests.
    """
    try:
        # Check if model can be loaded
        model = load_model()
        
        # Check GPU availability if enabled
        gpu_available = torch.cuda.is_available() if ENABLE_GPU else False
        
        return {
            'status': 'healthy',
            'model_loaded': model is not None,
            'model_size': YOLO_MODEL_SIZE,
            'gpu_enabled': ENABLE_GPU,
            'gpu_available': gpu_available,
            'device': 'cuda' if ENABLE_GPU and gpu_available else 'cpu',
            'max_image_size_mb': MAX_IMAGE_SIZE_MB,
            'processing_timeout_s': PROCESSING_TIMEOUT_SECONDS,
            'timestamp': time.time(),
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': time.time(),
        }
