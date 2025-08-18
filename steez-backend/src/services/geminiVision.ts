import {
  GoogleGenerativeAI,
  HarmCategory,
  HarmBlockThreshold,
  GenerationConfig,
  Content,
  Part,
  SchemaType,
  FunctionCallingMode,
} from '@google/generative-ai';
import { MatchResult, searchEbay } from './ebay';

// Helper to lazily initialize Gemini client after environment variables are loaded
function getGenAI(): GoogleGenerativeAI {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY environment variable is not set');
  }
  return new GoogleGenerativeAI(apiKey);
}

console.log(
  '🔑 Gemini API Key:',
  process.env.GEMINI_API_KEY
    ? 'Set (length: ' + process.env.GEMINI_API_KEY.length + ')'
    : 'NOT SET',
);

interface ExtractedItem {
  phrase: string;
  itemType: string;
  confidence?: number;
  category?: 'top' | 'bottom' | 'outerwear' | 'shoes' | 'accessories' | 'other';
}

interface ExtractionResult {
  items: ExtractedItem[];
}

export interface ClothingSegment {
  itemType: string; // e.g., "jacket", "jeans"
  phrase: string; // e.g., "black leather biker jacket"
  confidence: number;
  category: 'top' | 'bottom' | 'outerwear' | 'shoes' | 'accessories' | 'other';
  ebayResults: MatchResult[];
}

export interface SegmentedResults {
  segments: ClothingSegment[];
  totalItems: number;
}

const Preamble = `
You are an expert fashion stylist. Given an image, your task is to identify every individual article of clothing, provide a detailed description of each, and then generate highly specific search phrases for each item to find exact matches on platforms like eBay, StockX, or Vestiaire Collective.
`;

const FewShotExamples = `
For each identified clothing item, provide the following:
1.  **itemType**: A simple, one-word description of the clothing item (e.g., "jacket", "jeans", "sneakers").
2.  **phrase**: A detailed, 3-5 word search phrase. Include brand, model, color, and material if identifiable.
3.  **confidence**: Your confidence in the match, from 0.0 to 1.0.
4.  **category**: Classify the item into one of the following categories: 'top', 'bottom', 'outerwear', 'shoes', 'accessories', 'other'.

Here are some examples of the expected output format:
- For a black leather jacket: {"itemType": "jacket", "phrase": "black leather biker jacket", "confidence": 0.85, "category": "outerwear"}
- For blue jeans: {"itemType": "jeans", "phrase": "blue skinny denim jeans", "confidence": 0.9, "category": "bottom"}
- For an accessory: {"itemType": "bag", "phrase": "black leather shoulder bag", "confidence": 0.8, "category": "accessories"}
`;

const JsonSchema = {
  type: SchemaType.OBJECT,
  properties: {
    segmentedResults: {
      type: SchemaType.OBJECT,
      properties: {
        segments: {
          type: SchemaType.ARRAY,
          items: {
            type: SchemaType.OBJECT,
            properties: {
              itemType: { type: SchemaType.STRING },
              phrase: { type: SchemaType.STRING },
              confidence: { type: SchemaType.NUMBER },
              category: {
                type: SchemaType.STRING,
                enum: [
                  'top',
                  'bottom',
                  'outerwear',
                  'shoes',
                  'accessories',
                  'other',
                ],
              },
            },
            required: ['itemType', 'phrase', 'confidence', 'category'],
          },
        },
      },
      required: ['segments'],
    },
  },
  required: ['segmentedResults'],
};

export async function extractAndMatch(
  base64Image: string,
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
            description:
              'Extract clothing items and accessories from the image',
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
                        description:
                          'Descriptive phrase (color + item + distinctive features)',
                      },
                      itemType: {
                        type: SchemaType.STRING,
                        description:
                          'Item type/category (e.g., jacket, jeans, sneakers, hat, dress)',
                      },
                      confidence: {
                        type: SchemaType.NUMBER,
                        description: 'Confidence level between 0 and 1',
                      },
                      category: {
                        type: SchemaType.STRING,
                        description: 'Clothing category',
                        format: 'enum' as const,
                        enum: ['top', 'bottom', 'outerwear', 'shoes', 'accessories', 'other'],
                      },
                    },
                    required: ['phrase', 'itemType', 'confidence', 'category'],
                  },
                },
              },
              required: ['items'],
            },
          },
        ],
      },
    ],
    toolConfig: {
      functionCallingConfig: {
        mode: FunctionCallingMode.ANY,
        allowedFunctionNames: ['extract_garments'],
      },
    },
  });

  const prompt =
    Preamble +
    FewShotExamples +
    'Analyze this image and identify each distinct clothing item or accessory. ' +
    `The user is in ${country} and their size is ${userSize}. Please keep this in mind when generating search phrases. ` +
    'Present the output as a single, minified JSON object that adheres to the provided schema. Do not include any markdown formatting like ```json.';

  const image = {
    inlineData: {
      data: base64Image.replace(/^data:image\/[a-z]+;base64,/, ''),
      mimeType: 'image/jpeg',
    },
  };

  const parts: Part[] = [
    { text: prompt },
    image,
  ];

  // Rest of the function remains the same...
  const generationConfig: GenerationConfig = {
    temperature: 0.2,
    topK: 1,
    topP: 1,
    maxOutputTokens: 2048,
  };

  try {
    const result = await model.generateContent({
      contents: [{ role: 'user', parts }],
      generationConfig,
    });

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
      const { phrase, itemType, confidence = 0, category = 'other' } = item;

      // Skip items with low confidence
      if (confidence < 0.5) continue;

      // Search eBay for this specific item
      const ebayResults: MatchResult[] = [];

      try {
        // Try up to 3 eBay searches with slight variations
        const searchVariations = [phrase, `${phrase} ${userSize}`, itemType];

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
        category,
        ebayResults,
      });
    }

    return {
      segments,
      totalItems: segments.length,
    };
  } catch (error) {
    console.error('Error in extractAndMatch:', error);
    throw error;
  }
}

export type { MatchResult };
