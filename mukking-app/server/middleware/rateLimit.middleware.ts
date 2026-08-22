import type { NextFunction, Request, Response } from "express";
import type { AuthenticatedRequest } from "../models/http.types";
import { environment } from "../config/environment";

interface RateLimitConfig {
  name: string;
  windowMs: number;
  max: number;
}

interface RateLimitBucket {
  count: number;
  resetAt: number;
}

const buckets = new Map<string, RateLimitBucket>();

function getClientKey(request: Request, limiterName: string): string {
  const authenticatedRequest = request as Partial<AuthenticatedRequest>;
  const forwardedFor = request.header("x-forwarded-for")?.split(",")[0]?.trim();
  const ip = forwardedFor || request.ip || request.socket.remoteAddress || "unknown";
  const userId = authenticatedRequest.userId;

  return `${limiterName}:${userId ?? "anonymous"}:${ip}`;
}

export function createRateLimitMiddleware(config: RateLimitConfig) {
  return function rateLimitMiddleware(
    request: Request,
    response: Response,
    next: NextFunction
  ): void {
    const now = Date.now();
    const key = getClientKey(request, config.name);
    const existingBucket = buckets.get(key);
    const bucket =
      existingBucket && existingBucket.resetAt > now
        ? existingBucket
        : {
            count: 0,
            resetAt: now + config.windowMs
          };

    bucket.count += 1;
    buckets.set(key, bucket);

    const remaining = Math.max(config.max - bucket.count, 0);
    const resetSeconds = Math.ceil((bucket.resetAt - now) / 1000);

    response.setHeader("X-RateLimit-Limit", String(config.max));
    response.setHeader("X-RateLimit-Remaining", String(remaining));
    response.setHeader("X-RateLimit-Reset", String(Math.ceil(bucket.resetAt / 1000)));

    if (bucket.count > config.max) {
      response.setHeader("Retry-After", String(resetSeconds));
      response.status(429).json({
        message: "Too many requests. Please try again later.",
        code: "RATE_LIMIT_EXCEEDED",
        retryAfterSeconds: resetSeconds,
        limit: {
          name: config.name,
          max: config.max,
          windowMs: config.windowMs
        }
      });
      return;
    }

    next();
  };
}

export const authSignupRateLimit = createRateLimitMiddleware({
  name: "auth.signup",
  ...environment.rateLimits.authSignup
});

export const authLoginRateLimit = createRateLimitMiddleware({
  name: "auth.login",
  ...environment.rateLimits.authLogin
});

export const verificationRateLimit = createRateLimitMiddleware({
  name: "auth.verification",
  ...environment.rateLimits.verification
});

export const matchingRequestRateLimit = createRateLimitMiddleware({
  name: "matching.request",
  ...environment.rateLimits.matchingRequest
});

export const reportCreateRateLimit = createRateLimitMiddleware({
  name: "report.create",
  ...environment.rateLimits.reportCreate
});

export const blockCreateRateLimit = createRateLimitMiddleware({
  name: "block.create",
  ...environment.rateLimits.blockCreate
});

export const adminAuthRateLimit = createRateLimitMiddleware({
  name: "admin.auth",
  ...environment.rateLimits.adminAuth
});

export const adminSensitiveRateLimit = createRateLimitMiddleware({
  name: "admin.sensitive",
  ...environment.rateLimits.adminSensitive
});
