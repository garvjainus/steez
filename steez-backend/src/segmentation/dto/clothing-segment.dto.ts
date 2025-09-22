export class ClothingSegmentDto {
  id: string;
  category: string; // TORSO, BOTTOM, SHOES, ACCESSORY
  confidence: number;
  bbox: number[]; // [x1, y1, x2, y2]
  crop_image_base64: string;
  mask_area: number;
  class_name: string;
}

export class SegmentationResponseDto {
  success: boolean;
  message: string;
  segments: ClothingSegmentDto[];
  total_items: number;
  processing_time_ms: number;
}
