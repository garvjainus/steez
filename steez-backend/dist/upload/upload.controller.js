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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var UploadController_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.UploadController = void 0;
const common_1 = require("@nestjs/common");
const platform_express_1 = require("@nestjs/platform-express");
const fs = require("fs");
const upload_service_1 = require("./upload.service");
let UploadController = UploadController_1 = class UploadController {
    constructor(uploadService) {
        this.uploadService = uploadService;
        this.logger = new common_1.Logger(UploadController_1.name);
    }
    async uploadImage(file, userId, userSize, userCountry) {
        this.logger.debug(`[uploadImage] File received: ${file ? 'Yes' : 'No'}`);
        if (!file) {
            this.logger.error('[uploadImage] No file received in request');
            throw new common_1.HttpException('Image file is required', common_1.HttpStatus.BAD_REQUEST);
        }
        this.logger.debug(`[uploadImage] File details:
      - originalname: ${file.originalname}
      - filename: ${file.filename || 'UNDEFINED'}
      - mimetype: ${file.mimetype}
      - size: ${file.size}
      - path: ${file.path || 'UNDEFINED'}
      - buffer: ${file.buffer ? 'Available' : 'Not Available'}
    `);
        if (file.path) {
            const fileExists = fs.existsSync(file.path);
            this.logger.debug(`[uploadImage] File exists on disk: ${fileExists}`);
        }
        else {
            this.logger.warn('[uploadImage] No file.path property available');
        }
        if (!userId) {
            this.logger.error('[uploadImage] No userId received in request');
            throw new common_1.HttpException('User ID is required', common_1.HttpStatus.BAD_REQUEST);
        }
        try {
            const user = userSize || userCountry
                ? { size: userSize || 'M', country: userCountry || 'US' }
                : undefined;
            const result = await this.uploadService.processUploadedImage(file, userId, user);
            this.logger.debug(`[uploadImage] Image processed successfully: ${JSON.stringify(result)}`);
            return result;
        }
        catch (error) {
            this.logger.error(`[uploadImage] Error processing upload: ${error.message}`, error.stack);
            throw new common_1.HttpException(error.message || 'Failed to upload image', common_1.HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    async uploadBase64Image(base64Image, userId) {
        if (!base64Image) {
            throw new common_1.HttpException('Base64 image is required', common_1.HttpStatus.BAD_REQUEST);
        }
        if (!userId) {
            throw new common_1.HttpException('User ID is required', common_1.HttpStatus.BAD_REQUEST);
        }
        try {
            return {
                success: true,
                message: 'Base64 image received successfully',
                data: {
                    userId: userId,
                    imageSize: base64Image.length,
                    uploadedAt: new Date().toISOString(),
                },
            };
        }
        catch (error) {
            throw new common_1.HttpException(error.message || 'Failed to process base64 image', common_1.HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
};
exports.UploadController = UploadController;
__decorate([
    (0, common_1.Post)('image'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('image')),
    __param(0, (0, common_1.UploadedFile)()),
    __param(1, (0, common_1.Body)('userId')),
    __param(2, (0, common_1.Body)('userSize')),
    __param(3, (0, common_1.Body)('userCountry')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String, String]),
    __metadata("design:returntype", Promise)
], UploadController.prototype, "uploadImage", null);
__decorate([
    (0, common_1.Post)('image-base64'),
    __param(0, (0, common_1.Body)('image')),
    __param(1, (0, common_1.Body)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], UploadController.prototype, "uploadBase64Image", null);
exports.UploadController = UploadController = UploadController_1 = __decorate([
    (0, common_1.Controller)('upload'),
    __metadata("design:paramtypes", [upload_service_1.UploadService])
], UploadController);
//# sourceMappingURL=upload.controller.js.map