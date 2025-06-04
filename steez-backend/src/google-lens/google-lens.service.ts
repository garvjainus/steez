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
    this.baseUrl = this.configService.get<string>('BASE_URL') || 'http://localhost:3000';
  }

  /**
   * Analyse an uploaded image with a single SerpApi call
   */
  async analyzeUploadedImage(filename: string): Promise<ProductLinkDto[]> {
    if (!this.serpApiKey) {
      throw new InternalServerErrorException('Google Lens API key is not configured.');
    }

    const imagePath = path.join(this.uploadsDir, filename);
    if (!fs.existsSync(imagePath)) {
      throw new NotFoundException(`Image file not found: ${filename}`);
    }

    const imageUrl = `${this.baseUrl}/uploads/${filename}`;
    this.logger.debug(`Image URL for Lens: ${imageUrl}`);

    try {
      /* Single Google Lens request - visual_matches contains everything we need */
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

      // Get visual matches - this contains all the product data
      const visualMatches = lensResponse.visual_matches ?? [];
      this.logger.debug(`Found ${visualMatches.length} visual matches`);
      
      if (!visualMatches.length) {
        this.logger.debug(`No visual matches found. Full response: ${JSON.stringify(lensResponse, null, 2)}`);
        return [];
      }

      // Filter and map the results
      const results = visualMatches
        .filter((item: any) => this.isApparelLike(item))
        .map((item: any) => this.mapToProductDto(item, filename, imageUrl));

      this.logger.debug(`Returning ${results.length} fashion-related products`);
      return results;
    } catch (err) {
      this.handleApiError(err);
    }
  }

  /** GET with exponential back-off retry **only** on 5xx (SerpApi won't bill 429-retries now) */
  private async makeRequestWithRetries(url: string, params: Record<string, any>, retry = 0): Promise<any> {
    try {
      const res = await firstValueFrom(this.httpService.get(url, { params }));
      return res.data;
    } catch (err) {
      const status = err.response?.status;
      if (status && status >= 500 && status < 600 && retry < this.maxRetries) {
        const delay = this.retryDelay * 2 ** retry;
        this.logger.warn(`SerpApi ${status}. Retrying in ${delay} ms (attempt ${retry + 1}/${this.maxRetries})`);
        await new Promise((r) => setTimeout(r, delay));
        return this.makeRequestWithRetries(url, params, retry + 1);
      }
      throw err;
    }
  }

  /** Clothing-ish heuristic */
  private isApparelLike(item: any): boolean {
    const haystack = `${item.title || ''} ${item.category || ''} ${item.source || ''}`.toLowerCase();
    
    // More inclusive pattern for fashion items
    const fashionKeywords = /(shirt|t[- ]?shirt|tee|jersey|jacket|hoodie|jeans|pants|skirt|dress|sweater|coat|blazer|suit|sock|hat|cap|shoe|sneaker|boot|sandal|shorts|scarf|glove|underwear|bra|lingerie|belt|apparel|clothing|fashion|wear|outfit|style|designer|luxury|brand|vuitton|gucci|prada|nike|adidas|supreme|vintage|streetwear)/;
    
    // Less restrictive - allow more items through
    const isLikelyFashion = fashionKeywords.test(haystack);
    
    // If it's from a known fashion retailer, include it
    const fashionSources = /(therealreal|stockx|grailed|vestiaire|poshmark|ebay|dhgate|alibaba|farfetch|ssense|end|mrporter|matchesfashion|net-a-porter|saks|nordstrom|barneys|bloomingdales)/i;
    const isFromFashionSource = fashionSources.test(item.source || '');
    
    const shouldInclude = isLikelyFashion || isFromFashionSource;
    
    if (!shouldInclude) {
      this.logger.debug(`Filtered out: "${item.title}" from ${item.source} - not fashion-related`);
    }
    
    return shouldInclude;
  }

  /** Map SerpApi item → DTO */
  private mapToProductDto(item: any, filename: string, imageUrl: string): ProductLinkDto {
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

    const symbolToCode: Record<string, string> = { '$': 'USD', '£': 'GBP', '€': 'EUR', '¥': 'JPY' };

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
    throw new InternalServerErrorException('Failed to analyse image with Google Lens.');
  }
}