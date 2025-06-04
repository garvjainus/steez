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
}
export interface SerpApiGoogleLensResponseDto {
    search_parameters?: {
        engine?: string;
        url?: string;
    };
    search_information?: {};
    visual_matches?: SerpApiVisualMatch[];
    products?: SerpApiVisualMatch[];
    error?: string;
}
export {};
