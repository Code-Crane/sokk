import dotenv from "dotenv";
import crypto from "crypto";

dotenv.config();

const isProduction = process.env.NODE_ENV === "production";
const localDevJwtSecret = crypto.randomBytes(32).toString("hex");

function readNumber(name: string, fallback: number): number {
  const value = process.env[name];

  if (!value) {
    return fallback;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function readCsv(name: string, fallback: string[] = []): string[] {
  const value = process.env[name];

  if (!value) {
    return fallback;
  }

  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

const defaultCorsOrigins = isProduction
  ? []
  : [
      "http://localhost:3000",
      "http://localhost:3001",
      "http://localhost:4000",
      "http://localhost:8081",
      "http://localhost:19006",
      "http://127.0.0.1:3000",
      "http://127.0.0.1:3001",
      "http://127.0.0.1:8081",
      "http://127.0.0.1:19006"
    ];

const defaultRateLimitWindowMs = readNumber("RATE_LIMIT_WINDOW_MS", 60_000);

export const environment = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: Number(process.env.PORT ?? 4000),
  authProvider: process.env.AUTH_PROVIDER ?? "signed_mock",
  authJwtSecret:
    process.env.AUTH_JWT_SECRET ?? (isProduction ? "" : localDevJwtSecret),
  authJwtExpiresInSeconds: Number(
    process.env.AUTH_JWT_EXPIRES_IN_SECONDS ?? 60 * 60 * 24 * 7
  ),
  supabaseUrl: process.env.SUPABASE_URL ?? "",
  supabaseAnonKey: process.env.SUPABASE_ANON_KEY ?? "",
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? "",
  adminUidWhitelist: readCsv("ADMIN_UID_WHITELIST"),
  adminEmailWhitelist: readCsv("ADMIN_EMAIL_WHITELIST"),
  requireAdminMfa: process.env.ADMIN_REQUIRE_MFA !== "false",
  corsAllowedOrigins: readCsv("CORS_ALLOWED_ORIGINS", defaultCorsOrigins),
  rateLimits: {
    authSignup: {
      windowMs: readNumber("RATE_LIMIT_AUTH_SIGNUP_WINDOW_MS", defaultRateLimitWindowMs),
      max: readNumber("RATE_LIMIT_AUTH_SIGNUP_MAX", 30)
    },
    authLogin: {
      windowMs: readNumber("RATE_LIMIT_AUTH_LOGIN_WINDOW_MS", defaultRateLimitWindowMs),
      max: readNumber("RATE_LIMIT_AUTH_LOGIN_MAX", 30)
    },
    verification: {
      windowMs: readNumber("RATE_LIMIT_VERIFICATION_WINDOW_MS", defaultRateLimitWindowMs),
      max: readNumber("RATE_LIMIT_VERIFICATION_MAX", 60)
    },
    matchingRequest: {
      windowMs: readNumber("RATE_LIMIT_MATCHING_REQUEST_WINDOW_MS", defaultRateLimitWindowMs),
      max: readNumber("RATE_LIMIT_MATCHING_REQUEST_MAX", 20)
    },
    reportCreate: {
      windowMs: readNumber("RATE_LIMIT_REPORT_CREATE_WINDOW_MS", defaultRateLimitWindowMs),
      max: readNumber("RATE_LIMIT_REPORT_CREATE_MAX", 10)
    },
    adminAuth: {
      windowMs: readNumber("RATE_LIMIT_ADMIN_AUTH_WINDOW_MS", defaultRateLimitWindowMs),
      max: readNumber("RATE_LIMIT_ADMIN_AUTH_MAX", 60)
    },
    adminSensitive: {
      windowMs: readNumber("RATE_LIMIT_ADMIN_SENSITIVE_WINDOW_MS", defaultRateLimitWindowMs),
      max: readNumber("RATE_LIMIT_ADMIN_SENSITIVE_MAX", 20)
    }
  }
};
