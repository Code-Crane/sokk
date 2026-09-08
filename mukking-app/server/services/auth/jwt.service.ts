import crypto from "crypto";
import { environment } from "../../config/environment";
import type {
  MfaAssuranceLevel,
  VerifiedAuthClaims
} from "../../repositories/interfaces/repository.types";

interface SignedJwtPayload {
  sub: string;
  email?: string;
  aal?: MfaAssuranceLevel;
  iss: string;
  aud: string;
  iat: number;
  exp: number;
  [key: string]: unknown;
}

function toBase64Url(input: string | Buffer): string {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function fromBase64Url(input: string): Buffer {
  const padded = input.padEnd(input.length + ((4 - (input.length % 4)) % 4), "=");
  return Buffer.from(padded.replace(/-/g, "+").replace(/_/g, "/"), "base64");
}

function sign(input: string): string {
  if (environment.nodeEnv === "production") {
    throw Object.assign(new Error("Mock authentication is unavailable."), { statusCode: 403 });
  }
  if (!environment.authJwtSecret) {
    throw Object.assign(new Error("AUTH_JWT_SECRET is required."), {
      statusCode: 500
    });
  }

  return toBase64Url(
    crypto.createHmac("sha256", environment.authJwtSecret).update(input).digest()
  );
}

export function createSignedJwt(input: {
  userId: string;
  email?: string;
  aal?: MfaAssuranceLevel;
}): string {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const header = {
    alg: "HS256",
    typ: "JWT"
  };
  const payload: SignedJwtPayload = {
    sub: input.userId,
    email: input.email,
    aal: input.aal ?? "aal1",
    iss: "mukking-api",
    aud: "mukking-client",
    iat: nowSeconds,
    exp: nowSeconds + environment.authJwtExpiresInSeconds
  };
  const encodedHeader = toBase64Url(JSON.stringify(header));
  const encodedPayload = toBase64Url(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  return `${signingInput}.${sign(signingInput)}`;
}

export function decodeJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split(".");

  if (parts.length !== 3) {
    throw Object.assign(new Error("JWT must have three parts."), {
      statusCode: 401
    });
  }

  return JSON.parse(fromBase64Url(parts[1]).toString("utf8")) as Record<
    string,
    unknown
  >;
}

export function verifySignedJwt(token: string): VerifiedAuthClaims {
  const parts = token.split(".");

  if (parts.length !== 3) {
    throw Object.assign(new Error("Invalid authentication token."), {
      statusCode: 401
    });
  }

  const [encodedHeader, encodedPayload, signature] = parts;
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const expectedSignature = sign(signingInput);

  if (signature.length !== expectedSignature.length) {
    throw Object.assign(new Error("Invalid authentication token signature."), {
      statusCode: 401
    });
  }

  if (
    !crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature)
    )
  ) {
    throw Object.assign(new Error("Invalid authentication token signature."), {
      statusCode: 401
    });
  }

  const payload = decodeJwtPayload(token) as SignedJwtPayload;

  if (!payload.sub) {
    throw Object.assign(new Error("JWT subject is required."), {
      statusCode: 401
    });
  }

  if (payload.exp <= Math.floor(Date.now() / 1000)) {
    throw Object.assign(new Error("Authentication token has expired."), {
      statusCode: 401
    });
  }

  return {
    userId: payload.sub,
    email: payload.email,
    aal: payload.aal,
    authProvider: "signed_mock",
    expiresAt: new Date(payload.exp * 1000).toISOString(),
    rawClaims: payload
  };
}
