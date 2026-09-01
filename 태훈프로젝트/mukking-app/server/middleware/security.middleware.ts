import cors, { type CorsOptions } from "cors";
import type { RequestHandler } from "express";
import helmet from "helmet";
import { environment } from "../config/environment";

function isOriginAllowed(origin: string): boolean {
  return environment.corsAllowedOrigins.includes(origin);
}

export function createCorsMiddleware(): RequestHandler {
  const options: CorsOptions = {
    credentials: true,
    origin(origin, callback) {
      if (!origin) {
        callback(null, true);
        return;
      }

      callback(null, isOriginAllowed(origin));
    }
  };

  return cors(options);
}

export function createHelmetMiddleware(): RequestHandler {
  return helmet({
    crossOriginResourcePolicy: {
      policy: environment.nodeEnv === "production" ? "same-site" : "cross-origin"
    }
  });
}
