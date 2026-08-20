import type { User } from "@supabase/supabase-js";
import type { AuthRepository, AuthUserRecord } from "../interfaces/auth.repository";
import type {
  MfaAssuranceLevel,
  VerifiedAuthClaims
} from "../interfaces/repository.types";
import { getSupabaseAuthClient } from "../../config/supabase";
import { decodeJwtPayload } from "../../services/auth/jwt.service";

function readAalFromToken(token: string): MfaAssuranceLevel {
  try {
    const payload = decodeJwtPayload(token);
    return payload.aal === "aal2" ? "aal2" : "aal1";
  } catch {
    return "aal1";
  }
}

function toAuthUserRecord(user: User): AuthUserRecord {
  return {
    id: user.id,
    email: user.email ?? "",
    phoneNumber: user.phone ?? undefined,
    createdAt: user.created_at
  };
}

export const supabaseAuthRepository: AuthRepository = {
  async signup(_input) {
    throw Object.assign(
      new Error(
        "Supabase signup is handled by the Supabase client flow. Use the client access token with /api/auth/me."
      ),
      { statusCode: 501 }
    );
  },

  async login(_input) {
    throw Object.assign(
      new Error(
        "Supabase login is handled by the Supabase client flow. Use the client access token with /api/auth/me."
      ),
      { statusCode: 501 }
    );
  },

  async createSession(user) {
    throw Object.assign(
      new Error(
        `Cannot issue a Supabase access token from an existing profile session for ${user.email}. Use Supabase Auth client login.`
      ),
      { statusCode: 501 }
    );
  },

  async verifyAccessToken(token): Promise<VerifiedAuthClaims> {
    const supabase = getSupabaseAuthClient();
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data.user) {
      throw Object.assign(new Error("Invalid or expired Supabase JWT."), {
        statusCode: 401
      });
    }

    const aal = readAalFromToken(token);
    const payload = decodeJwtPayload(token);

    return {
      userId: data.user.id,
      email: data.user.email ?? undefined,
      aal,
      authProvider: "supabase",
      expiresAt:
        typeof payload.exp === "number"
          ? new Date(payload.exp * 1000).toISOString()
          : undefined,
      rawClaims: payload
    };
  },

  async getAuthUser(userId) {
    const supabase = getSupabaseAuthClient();
    const {
      data: { user },
      error
    } = await supabase.auth.getUser();

    if (error || !user || user.id !== userId) {
      return null;
    }

    return toAuthUserRecord(user);
  },

  async getMfaAssuranceLevel(token) {
    await this.verifyAccessToken(token);
    return readAalFromToken(token);
  }
};
