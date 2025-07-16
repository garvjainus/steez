import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Observable } from 'rxjs';

@Injectable()
export class LambdaAuthGuard implements CanActivate {
  private readonly lambdaSecret: string;

  constructor(private readonly configService: ConfigService) {
    this.lambdaSecret = this.configService.get<string>('LAMBDA_SECRET');
    if (!this.lambdaSecret) {
      throw new Error('LAMBDA_SECRET environment variable is not set');
    }
  }

  canActivate(
    context: ExecutionContext,
  ): boolean | Promise<boolean> | Observable<boolean> {
    const request = context.switchToHttp().getRequest();
    const secretFromHeader = request.headers['x-lambda-secret'];

    if (secretFromHeader !== this.lambdaSecret) {
      throw new UnauthorizedException('Invalid Lambda secret');
    }

    return true;
  }
} 