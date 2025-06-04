// DTO for individual visual match item from SerpApi
interface SerpApiVisualMatchPrice {
  value?: string;
  extracted_value?: number;
  currency?: string;
}

interface SerpApiVisualMatch {
  position?: number;
  title?: string;
  link?: string;
  source?: string;
  price?: SerpApiVisualMatchPrice;
  thumbnail?: string;
  // Add other fields from SerpApi documentation if needed, e.g., rating, reviews, in_stock
}

// DTO for the overall SerpApi Google Lens response
export interface SerpApiGoogleLensResponseDto {
  search_parameters?: {
    engine?: string;
    url?: string; // This might be the base64 image string we sent
  };
  search_information?: {
    // ... relevant search info fields
  };
  visual_matches?: SerpApiVisualMatch[];
  products?: SerpApiVisualMatch[]; // Structure seems similar to visual_matches
  // Add other top-level fields like related_content if you plan to use them
  error?: string; // SerpApi often includes an error message here on failure
} 