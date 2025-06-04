"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const core_1 = require("@nestjs/core");
const app_module_1 = require("./app.module");
const common_1 = require("@nestjs/common");
const express = require("express");
const path = require("path");
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule, {
        httpsOptions: undefined,
        forceCloseConnections: true,
        logger: ['error', 'warn', 'log', 'debug'],
    });
    app.enableCors();
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        transform: true,
    }));
    app.use(express.json({ limit: '50mb' }));
    app.use(express.urlencoded({ limit: '50mb', extended: true }));
    const uploadsPath = path.join(__dirname, '..', 'uploads');
    app.use('/uploads', express.static(uploadsPath));
    const port = process.env.PORT || 3000;
    const logger = new common_1.Logger('Bootstrap');
    logger.log('Starting application with debug logging enabled');
    logger.log(`Serving static files from: ${uploadsPath}`);
    await app.listen(port, '::');
    logger.log(`Application is running on: http://[::]:${port} (IPv6)`);
    logger.log(`Also accessible via: http://localhost:${port}`);
}
bootstrap();
//# sourceMappingURL=main.js.map