import { ProductLinkDto } from '../../google-lens/dto';

/**
 * New segmented results structure that replaces the Gemini-based approach
 * Each segment represents a specific clothing item found via YOLO + Google Lens
 */
export class SegmentedClothingItem {
  id: string;
  category: string; // TORSO, BOTTOM, SHOES, ACCESSORY
  confidence: number;
  bbox: number[]; // [x1, y1, x2, y2] - bounding box in original image
  cropImageBase64?: string; // Optional - for debugging/display
  
  // Google Lens results for this specific item
  productLinks: ProductLinkDto[];
  
  // Metadata
  maskArea: number;
  className: string;
  processingTimeMs: number;
}

export class NewSegmentedResults {
  segments: SegmentedClothingItem[];
  totalItems: number;
  totalProcessingTimeMs: number;
  segmentationTimeMs: number;
  googleLensTimeMs: number;
  
  // Summary statistics
  categoryCounts: {
    TORSO: number;
    BOTTOM: number;
    SHOES: number;
    ACCESSORY: number;
  };
}

/**
 * Processing configuration for the new pipeline
 */
export interface SegmentationConfig {
  enableGoogleLens: boolean;
  maxSegmentsPerCategory: number;
  minConfidence: number;
  enableTransparentCrops: boolean;
  cropPaddingPercent: number;
}

export const DEFAULT_SEGMENTATION_CONFIG: SegmentationConfig = {
  enableGoogleLens: true,
  maxSegmentsPerCategory: 3, // Limit to avoid too many API calls
  minConfidence: 0.5,
  enableTransparentCrops: true,
  cropPaddingPercent: 0.1,
};
