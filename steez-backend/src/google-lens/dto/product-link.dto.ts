export class ProductLinkDto {
  title: string;
  link: string;
  source: string;
  price?: string; // e.g., "$19.99" or "¥170,280*", as a string because format varies
  extractedPrice?: number;
  currency?: string;
  thumbnailUrl?: string;
  filename?: string;
  imageUrl?: string; // URL to the locally stored image
  category?: string; // Added for filtering by category
  // Add any other fields you deem important from SerpApi's visual_matches
}
