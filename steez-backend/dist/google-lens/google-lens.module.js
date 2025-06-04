"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.GoogleLensModule = void 0;
const common_1 = require("@nestjs/common");
const axios_1 = require("@nestjs/axios");
const google_lens_service_1 = require("./google-lens.service");
const google_lens_controller_1 = require("./google-lens.controller");
const config_1 = require("@nestjs/config");
let GoogleLensModule = class GoogleLensModule {
};
exports.GoogleLensModule = GoogleLensModule;
exports.GoogleLensModule = GoogleLensModule = __decorate([
    (0, common_1.Module)({
        imports: [
            axios_1.HttpModule,
            config_1.ConfigModule,
        ],
        providers: [google_lens_service_1.GoogleLensService],
        controllers: [google_lens_controller_1.GoogleLensController],
        exports: [google_lens_service_1.GoogleLensService],
    })
], GoogleLensModule);
//# sourceMappingURL=google-lens.module.js.map