import { HttpService } from '@nestjs/axios';
import {
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import * as fs from 'fs';
import * as path from 'path';
import { ProductLinkDto } from './dto';
import {
  normalizeCandidates,
  scoreFashionRelevance,
} from './filters';

@Injectable()
export class GoogleLensService {
  private readonly logger = new Logger(GoogleLensService.name);
  private readonly serpApiKey: string;
  private readonly uploadsDir = path.join(__dirname, '..', '..', 'uploads');
  private readonly baseUrl: string;
  private readonly maxRetries = 3;
  private readonly retryDelay = 1000; // 1 second

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
  ) {
    this.serpApiKey = this.configService.get<string>('GOOGLE_LENS_API');
    if (!this.serpApiKey) {
      this.logger.error('GOOGLE_LENS_API key is not configured!');
    } else {
      this.logger.log('GOOGLE_LENS_API key loaded successfully.');
    }

    // Use configured BASE_URL or fall back to localhost
    this.baseUrl =
      this.configService.get<string>('BASE_URL') || 'http://localhost:3000';
  }

  /**
   * Analyse an uploaded image with a single SerpApi call
   */
  async analyzeUploadedImage(filename: string): Promise<ProductLinkDto[]> {
    if (!this.serpApiKey) {
      this.logger.warn('Google Lens API key is not configured - returning empty results');
      return [];
    }

    const imagePath = path.join(this.uploadsDir, filename);
    if (!fs.existsSync(imagePath)) {
      throw new NotFoundException(`Image file not found: ${filename}`);
    }

    const imageUrl = `${this.baseUrl}/uploads/${filename}`;
    this.logger.debug(`Image URL for Lens: ${imageUrl}`);

    try {
      // Single Google Lens request - visual_matches contains everything we need
      const lensResponse = await this.makeRequestWithRetries('https://serpapi.com/search.json', {
        api_key: this.serpApiKey,
        engine: 'google_lens',
        url: imageUrl,
        gl: 'us',
        hl: 'en',
      });

      // Log the response for debugging
      this.logger.debug(`Response keys: ${Object.keys(lensResponse || {}).join(', ')}`);
      if (lensResponse?.error) {
        this.logger.error(`SerpAPI error: ${lensResponse.error}`);
        return [];
      }

      // Gather both visual_matches and shopping_results for broader coverage
      const visualMatches = lensResponse.visual_matches ?? [];
      const shoppingResults = lensResponse.shopping_results ?? [];
      this.logger.debug(
        `Found ${visualMatches.length} visual matches, ${shoppingResults.length} shopping results`,
      );

      const candidates = normalizeCandidates(visualMatches, shoppingResults);
      if (!candidates.length) {
        this.logger.debug(
          `No candidates found. Full response: ${JSON.stringify(lensResponse, null, 2)}`,
        );
        return [];
      }

      // Score for apparel relevance, then combine with Serp 'position' to prefer top-ranked items
      const scored = candidates.map((item: any) => {
        const score = scoreFashionRelevance(item);
        const position = typeof item.position === 'number' ? item.position : 9999;
        return { item, score, position };
      });

      // Keep items with positive score; sort primarily by score desc, then by position asc
      const filtered = scored
        .filter((x) => x.score > 0)
        .sort((a, b) => (b.score - a.score) || (a.position - b.position))
        .map((x) => x.item);

      const top = filtered.slice(0, 5);
      const results = top.map((item: any) => this.mapToProductDto(item, filename, imageUrl));

      this.logger.debug(`Returning ${results.length} fashion-related products (limited to top 5)`);
      return results;
    } catch (err) {
      this.handleApiError(err);
    }
  }

  /** GET with exponential back-off retry **only** on 5xx (SerpApi won't bill 429-retries now) */
  private async makeRequestWithRetries(
    url: string,
    params: Record<string, any>,
    retry = 0,
  ): Promise<any> {
    try {
      const res = await firstValueFrom(this.httpService.get(url, { params }));
      return res.data;
    } catch (err) {
      const status = err.response?.status;
      if (status && status >= 500 && status < 600 && retry < this.maxRetries) {
        const delay = this.retryDelay * 2 ** retry;
        this.logger.warn(
          `SerpApi ${status}. Retrying in ${delay} ms (attempt ${retry + 1}/${this.maxRetries})`,
        );
        await new Promise((r) => setTimeout(r, delay));
        return this.makeRequestWithRetries(url, params, retry + 1);
      }
      throw err;
    }
  }

  // Deprecated: replaced by score-based filter in filters.ts

  /** Map SerpApi item → DTO */
  private mapToProductDto(
    item: any,
    filename: string,
    imageUrl: string,
  ): ProductLinkDto {
    // Handle price from visual_matches structure
    let priceText: string = '';
    let value: number | null = null;
    let currencySymbol = '$';

    if (item.price) {
      if (typeof item.price === 'object' && item.price.value) {
        // visual_matches format: { value: "$3,690*", extracted_value: 3690, currency: "$" }
        priceText = item.price.value;
        value = item.price.extracted_value || null;
        currencySymbol = item.price.currency || '$';
      } else if (typeof item.price === 'string') {
        // shopping_results format: "$3,690"
        priceText = item.price;
        const priceMatch = priceText.match(/([£$€¥])?([\d.,]+)/);
        currencySymbol = priceMatch?.[1] ?? '$';
        value = priceMatch ? parseFloat(priceMatch[2].replace(/,/g, '')) : null;
      }
    }

    const symbolToCode: Record<string, string> = {
      $: 'USD',
      '£': 'GBP',
      '€': 'EUR',
      '¥': 'JPY',
    };

    return {
      title: item.title || 'Unknown Product',
      link: item.link,
      source: item.source || 'Unknown',
      price: priceText,
      extractedPrice: value,
      currency: symbolToCode[currencySymbol] || 'USD',
      thumbnailUrl: item.thumbnail || item.image,
      filename,
      imageUrl,
      category: item.category ?? null,
    };
  }

  /** Translate errors to 500 that our controller understands */
  private handleApiError(err: any): never {
    if (err.response?.data?.error) {
      const msg = `Google Lens API error: ${err.response.data.error}`;
      this.logger.error(msg);
      throw new InternalServerErrorException(msg);
    }
    this.logger.error('Unhandled error in Google Lens flow', err.stack);
    throw new InternalServerErrorException(
      'Failed to analyse image with Google Lens.',
    );
  }
}
