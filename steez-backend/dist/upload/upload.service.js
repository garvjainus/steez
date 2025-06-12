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
var UploadService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.UploadService = void 0;
const common_1 = require("@nestjs/common");
const geminiVision_1 = require("../services/geminiVision");
const fs = require("fs");
const path = require("path");
const uuid_1 = require("uuid");
const config_1 = require("@nestjs/config");
let UploadService = UploadService_1 = class UploadService {
    constructor(configService) {
        this.configService = configService;
        this.logger = new common_1.Logger(UploadService_1.name);
        this.uploadsDir = path.join(__dirname, '..', '..', 'uploads');
        if (!fs.existsSync(this.uploadsDir)) {
            this.logger.log(`Creating uploads directory: ${this.uploadsDir}`);
            fs.mkdirSync(this.uploadsDir, { recursive: true });
        }
        this.baseUrl =
            this.configService.get('BASE_URL') || 'http://localhost:3000';
    }
    async processUploadedImage(file, userId, user) {
        this.logger.debug(`Processing uploaded image for user: ${userId}`);
        let savedFilename;
        let filePath;
        if (!file.filename || !file.path) {
            this.logger.warn('File was not saved by Multer, saving it manually');
            const fileExt = path.extname(file.originalname);
            savedFilename = `${(0, uuid_1.v4)()}${fileExt}`;
            filePath = path.join(this.uploadsDir, savedFilename);
            try {
                fs.writeFileSync(filePath, file.buffer);
                this.logger.debug(`Manually saved file to: ${filePath}`);
            }
            catch (error) {
                this.logger.error(`Failed to save file: ${error.message}`, error.stack);
                throw new Error(`Failed to save uploaded file: ${error.message}`);
            }
        }
        else {
            savedFilename = file.filename;
            filePath = file.path;
        }
        if (!fs.existsSync(filePath)) {
            this.logger.error(`File does not exist on disk: ${filePath}`);
            throw new common_1.NotFoundException(`File not found on disk`);
        }
        this.logger.debug(`File exists on disk at: ${filePath}`);
        const imageUrl = `${this.baseUrl}/uploads/${savedFilename}`;
        this.logger.debug(`Image URL: ${imageUrl}`);
        try {
            const imageBuffer = fs.readFileSync(filePath);
            const base64Image = imageBuffer.toString('base64');
            const userSize = user?.size || 'M';
            const userCountry = user?.country || 'US';
            const segmentedResults = await (0, geminiVision_1.extractAndMatch)(base64Image, userSize, userCountry);
            this.logger.log(`Successfully processed image. Found ${segmentedResults.totalItems} clothing segments.`);
            return {
                success: true,
                message: 'Image processed successfully',
                data: {
                    filename: savedFilename,
                    originalName: file.originalname,
                    size: file.size,
                    userId: userId,
                    uploadedAt: new Date().toISOString(),
                    imageUrl: imageUrl,
                    segmentedResults: segmentedResults,
                },
            };
        }
        catch (error) {
            this.logger.error(`Error processing image: ${error.message}`, error.stack);
            return {
                success: false,
                message: 'Image upload succeeded but processing failed',
                error: error.message,
                data: {
                    filename: savedFilename,
                    originalName: file.originalname,
                    size: file.size,
                    userId: userId,
                    uploadedAt: new Date().toISOString(),
                    imageUrl: imageUrl,
                },
            };
        }
    }
};
exports.UploadService = UploadService;
exports.UploadService = UploadService = UploadService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], UploadService);
//# sourceMappingURL=upload.service.js.map