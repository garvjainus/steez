"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var GoogleLensService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.GoogleLensService = void 0;
const axios_1 = require("@nestjs/axios");
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const rxjs_1 = require("rxjs");
const fs = require("fs");
const path = require("path");
let GoogleLensService = GoogleLensService_1 = class GoogleLensService {
    constructor(httpService, configService) {
        this.httpService = httpService;
        this.configService = configService;
        this.logger = new common_1.Logger(GoogleLensService_1.name);
        this.uploadsDir = path.join(__dirname, '..', '..', 'uploads');
        this.maxRetries = 3;
        this.retryDelay = 1000;
        this.serpApiKey = this.configService.get('GOOGLE_LENS_API');
        if (!this.serpApiKey) {
            this.logger.error('GOOGLE_LENS_API key is not configured!');
        }
        else {
            this.logger.log('GOOGLE_LENS_API key loaded successfully.');
        }
        this.baseUrl = this.configService.get('BASE_URL') || 'http://localhost:3000';
    }
    async analyzeUploadedImage(filename) {
        if (!this.serpApiKey) {
            throw new common_1.InternalServerErrorException('Google Lens API key is not configured.');
        }
        const imagePath = path.join(this.uploadsDir, filename);
        if (!fs.existsSync(imagePath)) {
            throw new common_1.NotFoundException(`Image file not found: ${filename}`);
        }
        const imageUrl = `${this.baseUrl}/uploads/${filename}`;
        this.logger.debug(`Image URL for Lens: ${imageUrl}`);
        try {
            const lensResponse = await this.makeRequestWithRetries('https://serpapi.com/search.json', {
                api_key: this.serpApiKey,
                engine: 'google_lens',
                url: imageUrl,
                gl: 'us',
                hl: 'en',
            });
            this.logger.debug(`Response keys: ${Object.keys(lensResponse || {}).join(', ')}`);
            if (lensResponse?.error) {
                this.logger.error(`SerpAPI error: ${lensResponse.error}`);
                return [];
            }
            const visualMatches = lensResponse.visual_matches ?? [];
            this.logger.debug(`Found ${visualMatches.length} visual matches`);
            if (!visualMatches.length) {
                this.logger.debug(`No visual matches found. Full response: ${JSON.stringify(lensResponse, null, 2)}`);
                return [];
            }
            const results = visualMatches
                .filter((item) => this.isApparelLike(item))
                .map((item) => this.mapToProductDto(item, filename, imageUrl));
            this.logger.debug(`Returning ${results.length} fashion-related products`);
            return results;
        }
        catch (err) {
            this.handleApiError(err);
        }
    }
    async makeRequestWithRetries(url, params, retry = 0) {
        try {
            const res = await (0, rxjs_1.firstValueFrom)(this.httpService.get(url, { params }));
            return res.data;
        }
        catch (err) {
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
    isApparelLike(item) {
        const haystack = `${item.title || ''} ${item.category || ''} ${item.source || ''}`.toLowerCase();
        const fashionKeywords = /(shirt|t[- ]?shirt|tee|jersey|jacket|hoodie|jeans|pants|skirt|dress|sweater|coat|blazer|suit|sock|hat|cap|shoe|sneaker|boot|sandal|shorts|scarf|glove|underwear|bra|lingerie|belt|apparel|clothing|fashion|wear|outfit|style|designer|luxury|brand|vuitton|gucci|prada|nike|adidas|supreme|vintage|streetwear)/;
        const isLikelyFashion = fashionKeywords.test(haystack);
        const fashionSources = /(therealreal|stockx|grailed|vestiaire|poshmark|ebay|dhgate|alibaba|farfetch|ssense|end|mrporter|matchesfashion|net-a-porter|saks|nordstrom|barneys|bloomingdales)/i;
        const isFromFashionSource = fashionSources.test(item.source || '');
        const shouldInclude = isLikelyFashion || isFromFashionSource;
        if (!shouldInclude) {
            this.logger.debug(`Filtered out: "${item.title}" from ${item.source} - not fashion-related`);
        }
        return shouldInclude;
    }
    mapToProductDto(item, filename, imageUrl) {
        let priceText = '';
        let value = null;
        let currencySymbol = '$';
        if (item.price) {
            if (typeof item.price === 'object' && item.price.value) {
                priceText = item.price.value;
                value = item.price.extracted_value || null;
                currencySymbol = item.price.currency || '$';
            }
            else if (typeof item.price === 'string') {
                priceText = item.price;
                const priceMatch = priceText.match(/([£$€¥])?([\d.,]+)/);
                currencySymbol = priceMatch?.[1] ?? '$';
                value = priceMatch ? parseFloat(priceMatch[2].replace(/,/g, '')) : null;
            }
        }
        const symbolToCode = { '$': 'USD', '£': 'GBP', '€': 'EUR', '¥': 'JPY' };
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
    handleApiError(err) {
        if (err.response?.data?.error) {
            const msg = `Google Lens API error: ${err.response.data.error}`;
            this.logger.error(msg);
            throw new common_1.InternalServerErrorException(msg);
        }
        this.logger.error('Unhandled error in Google Lens flow', err.stack);
        throw new common_1.InternalServerErrorException('Failed to analyse image with Google Lens.');
    }
};
exports.GoogleLensService = GoogleLensService;
exports.GoogleLensService = GoogleLensService = GoogleLensService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [axios_1.HttpService,
        config_1.ConfigService])
], GoogleLensService);
//# sourceMappingURL=google-lens.service.js.map