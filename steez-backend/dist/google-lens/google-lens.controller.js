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
var GoogleLensController_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.GoogleLensController = void 0;
const common_1 = require("@nestjs/common");
const google_lens_service_1 = require("./google-lens.service");
const dto_1 = require("./dto");
let GoogleLensController = GoogleLensController_1 = class GoogleLensController {
    constructor(googleLensService) {
        this.googleLensService = googleLensService;
        this.logger = new common_1.Logger(GoogleLensController_1.name);
    }
    async analyzeImage(analyzeImageDto) {
        this.logger.log(`Received request to analyze image: ${analyzeImageDto.filename}`);
        return this.googleLensService.analyzeUploadedImage(analyzeImageDto.filename);
    }
};
exports.GoogleLensController = GoogleLensController;
__decorate([
    (0, common_1.Post)('analyze'),
    (0, common_1.UsePipes)(new common_1.ValidationPipe({ transform: true, whitelist: true })),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [dto_1.AnalyzeImageDto]),
    __metadata("design:returntype", Promise)
], GoogleLensController.prototype, "analyzeImage", null);
exports.GoogleLensController = GoogleLensController = GoogleLensController_1 = __decorate([
    (0, common_1.Controller)('google-lens'),
    __metadata("design:paramtypes", [google_lens_service_1.GoogleLensService])
], GoogleLensController);
//# sourceMappingURL=google-lens.controller.js.map