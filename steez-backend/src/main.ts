import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe, Logger } from '@nestjs/common';
import * as express from 'express';
import * as path from 'path';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    httpsOptions: undefined,
    // Enable both IPv4 and IPv6 stacks
    forceCloseConnections: true,
    logger: ['error', 'warn', 'log', 'debug'], // Enable debug logging
  });

  // Enable CORS
  app.enableCors();

  // Set up global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );

  // Set up file upload limits
  app.use(express.json({ limit: '50mb' }));
  app.use(express.urlencoded({ limit: '50mb', extended: true }));

  // Set up static file serving for uploads directory
  const uploadsPath = path.join(__dirname, '..', 'uploads');
  app.use('/uploads', express.static(uploadsPath));

  // Start the server
  const port = process.env.PORT || 3000;

  const logger = new Logger('Bootstrap');
  logger.log('Starting application with debug logging enabled');
  logger.log(`Serving static files from: ${uploadsPath}`);

  // Listen on all network interfaces
  await app.listen(port, '0.0.0.0');
  logger.log(`Application is running on: http://0.0.0.0:${port}`);
  logger.log(`Find your local network IP (e.g., 192.168.1.X) and connect from your phone via http://<YOUR_IP>:${port}`);
}
bootstrap();
