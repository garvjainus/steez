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
    await app.listen(port, '0.0.0.0');
    logger.log(`Application is running on: http://0.0.0.0:${port}`);
    logger.log(`Find your local network IP (e.g., 192.168.1.X) and connect from your phone via http://<YOUR_IP>:${port}`);
}
bootstrap();
//# sourceMappingURL=main.js.map