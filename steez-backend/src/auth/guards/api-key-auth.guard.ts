import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Simple header-based API-key guard.
 * Requires the request to include `x-api-key: <API_KEY>` where
 * <API_KEY> is stored in the environment variable `PUBLIC_API_KEY`.
 *
 * Keep this key secret and rotate it regularly.
 */
@Injectable()
export class ApiKeyAuthGuard implements CanActivate {
  private readonly expectedApiKey: string;

  constructor(private readonly configService: ConfigService) {
    const key = this.configService.get<string>('PUBLIC_API_KEY');
    if (!key) {
      throw new Error('PUBLIC_API_KEY environment variable is not set');
    }
    this.expectedApiKey = key;
  }

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const apiKey = request.headers['x-api-key'];

    if (apiKey !== this.expectedApiKey) {
      throw new UnauthorizedException('Invalid API key');
    }
    return true;
  }
} 