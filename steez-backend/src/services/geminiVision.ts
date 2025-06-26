import { GoogleGenerativeAI, SchemaType, FunctionCallingMode } from '@google/generative-ai';
import { searchEbay, MatchResult } from './ebay';

// Helper to lazily initialize Gemini client after environment variables are loaded
function getGenAI(): GoogleGenerativeAI {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY environment variable is not set');
  }
  return new GoogleGenerativeAI(apiKey);
}

console.log('🔑 Gemini API Key:', process.env.GEMINI_API_KEY ? 'Set (length: ' + process.env.GEMINI_API_KEY.length + ')' : 'NOT SET');

interface ExtractedItem {
  phrase: string;
  itemType: string;
  confidence?: number;
}

interface ExtractionResult {
  items: ExtractedItem[];
}

export interface ClothingSegment {
  itemType: string;
  phrase: string;
  confidence: number;
  ebayResults: MatchResult[];
}

export interface SegmentedResults {
  segments: ClothingSegment[];
  totalItems: number;
}

export async function extractAndMatch(
  base64: string,
  userSize: string,
  country: string,
): Promise<SegmentedResults> {
  const genAI = getGenAI();
  const model = genAI.getGenerativeModel({
    model: 'gemini-2.0-flash',
    tools: [
      {
        functionDeclarations: [
          {
            name: 'extract_garments',
            description: 'Extract clothing items and accessories from the image',
            parameters: {
              type: SchemaType.OBJECT,
              properties: {
                items: {
                  type: SchemaType.ARRAY,
                  items: {
                    type: SchemaType.OBJECT,
                    properties: {
                      phrase: { 
                        type: SchemaType.STRING,
                        description: 'Descriptive phrase (color + item + distinctive features)'
                      },
                      itemType: { 
                        type: SchemaType.STRING,
                        description: 'Item type/category (e.g., jacket, jeans, sneakers, hat, dress)'
                      },
                      confidence: { 
                        type: SchemaType.NUMBER,
                        description: 'Confidence level between 0 and 1'
                      }
                    },
                    required: ['phrase', 'itemType', 'confidence']
                  }
                }
              },
              required: ['items']
            }
          }
        ]
      }
    ],
    toolConfig: {
      functionCallingConfig: {
        mode: FunctionCallingMode.ANY,
        allowedFunctionNames: ['extract_garments']
      }
    }
  });

  const prompt = 
    'Analyze this image and identify each distinct clothing item or accessory. For each item, provide:\n' +
    '1. A descriptive phrase (color + item + distinctive features)\n' +
    '2. The item type/category (e.g., \'jacket\', \'jeans\', \'sneakers\', \'hat\', \'dress\', etc.)\n' +
    '3. Your confidence level (0-1)\n\n' +
    'Examples:\n' +
    '- phrase: \'black leather biker jacket\', itemType: \'jacket\', confidence: 0.9\n' +
    '- phrase: \'blue skinny denim jeans\', itemType: \'jeans\', confidence: 0.85\n' +
    '- phrase: \'white canvas sneakers\', itemType: \'sneakers\', confidence: 0.8';

  const imageData = {
    inlineData: {
      data: base64,
      mimeType: 'image/jpeg'
    }
  };

  const result = await model.generateContent([prompt, imageData]);
  
  // Debug: Log the full response to see what Gemini actually returned
  console.log('🔍 Gemini Response Debug:');
  console.dir(result.response, { depth: null });
  
  // Get function call from the correct location in the response
  const candidate = result.response.candidates?.[0];
  const functionCall = candidate?.content?.parts?.[0]?.functionCall;
  
  if (!functionCall) {
    throw new Error('No function call received from Gemini');
  }

  if (functionCall.name !== 'extract_garments') {
    throw new Error('Unexpected function call from Gemini');
  }

  const payload: ExtractionResult = functionCall.args as ExtractionResult;
  const segments: ClothingSegment[] = [];
  
  // Process each identified clothing item
  for (const item of payload.items) {
    const { phrase, itemType, confidence = 0 } = item;
    
    // Skip items with low confidence
    if (confidence < 0.5) continue;
    
    // Search eBay for this specific item
    const ebayResults: MatchResult[] = [];
    
    try {
      // Try up to 3 eBay searches with slight variations
      const searchVariations = [
        phrase,
        `${phrase} ${userSize}`,
        itemType
      ];
      
      for (const searchTerm of searchVariations) {
        const results = await searchEbay(searchTerm, userSize, country);
        if (results.length > 0) {
          ebayResults.push(...results);
          break; // Found results, stop trying other variations
        }
      }
    } catch (error) {
      console.error(`Error searching eBay for "${phrase}":`, error);
    }
    
    segments.push({
      itemType,
      phrase,
      confidence,
      ebayResults
    });
  }
  
  return {
    segments,
    totalItems: segments.length
  };
} 

export type { MatchResult }; 