import { Test, TestingModule } from '@nestjs/testing';
import { UploadService } from './upload.service';
import { ConfigService } from '@nestjs/config';
import * as fs from 'fs';

// Mock the Gemini Vision service
jest.mock('../services/geminiVision', () => ({
  extractAndMatch: jest.fn(),
}));

import { extractAndMatch } from '../services/geminiVision';
const mockExtractAndMatch = extractAndMatch as jest.MockedFunction<typeof extractAndMatch>;

describe('UploadService', () => {
  let service: UploadService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UploadService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) => {
              if (key === 'BASE_URL') return 'http://localhost:3000';
              return undefined;
            }),
          },
        },
      ],
    }).compile();

    service = module.get<UploadService>(UploadService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('processUploadedImage', () => {
    const mockFile = {
      originalname: 'test-image.jpg',
      filename: 'test-123.jpg',
      path: '/uploads/test-123.jpg',
      size: 1024,
      buffer: Buffer.from('fake-image-data'),
    } as Express.Multer.File;

    const mockUser = {
      size: 'M',
      country: 'US',
    };

    beforeEach(() => {
      // Mock fs.existsSync to return true
      jest.spyOn(fs, 'existsSync').mockReturnValue(true);
      // Mock fs.readFileSync to return a buffer
      jest.spyOn(fs, 'readFileSync').mockReturnValue(Buffer.from('fake-image-data'));
    });

    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('should process image with Gemini Vision and return segmented results', async () => {
      const expectedSegmentedResults = {
        segments: [
          {
            itemType: 'jacket',
            phrase: 'black leather biker jacket',
            confidence: 0.85,
            ebayResults: [{ phrase: 'black leather biker jacket', link: 'https://ebay.com/item1' }]
          },
          {
            itemType: 'jeans',
            phrase: 'blue skinny denim jeans',
            confidence: 0.90,
            ebayResults: [{ phrase: 'blue skinny denim jeans', link: 'https://ebay.com/item2' }]
          }
        ],
        totalItems: 2
      };

      mockExtractAndMatch.mockResolvedValue(expectedSegmentedResults);

      const result = await service.processUploadedImage(mockFile, 'user-123', mockUser);

      expect(result.success).toBe(true);
      expect(result.data.segmentedResults).toEqual(expectedSegmentedResults);
      expect(mockExtractAndMatch).toHaveBeenCalledWith(
        expect.any(String), // base64 image data
        'M',
        'US'
      );
    });

    it('should handle Gemini Vision errors gracefully', async () => {
      mockExtractAndMatch.mockRejectedValue(new Error('Gemini API error'));

      const result = await service.processUploadedImage(mockFile, 'user-123', mockUser);

      expect(result.success).toBe(false);
      expect(result.error).toContain('Gemini API error');
    });

    it('should return empty segments when no items are found', async () => {
      const emptyResults = {
        segments: [],
        totalItems: 0
      };

      mockExtractAndMatch.mockResolvedValue(emptyResults);

      const result = await service.processUploadedImage(mockFile, 'user-123', mockUser);

      expect(result.success).toBe(true);
      expect(result.data.segmentedResults).toEqual(emptyResults);
    });
  });
});
