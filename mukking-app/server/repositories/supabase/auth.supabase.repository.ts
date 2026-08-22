import type { Session, User } from "@supabase/supabase-js";
import type {
  AuthSession,
  LoginInput,
  PublicUserProfile,
  SignupInput
} from "../../../shared/types";
import {
  DEFAULT_MANNER_SCORE,
  getMannerGrade
} from "../../../shared/utils/rating";
import type { AuthRepository, AuthUserRecord } from "../interfaces/auth.repository";
import type {
  MfaAssuranceLevel,
  VerifiedAuthClaims
} from "../interfaces/repository.types";
import {
  getSupabaseAuthClient,
  getSupabaseServiceRoleClient
} from "../../config/supabase";
import { decodeJwtPayload } from "../../services/auth/jwt.service";

function readAalFromToken(token: string): MfaAssuranceLevel {
  try {
    const payload = decodeJwtPayload(token);
    return payload.aal === "aal2" ? "aal2" : "aal1";
  } catch {
    return "aal1";
  }
}

function readStringMetadata(
  metadata: Record<string, unknown> | undefined,
  key: string
): string | undefined {
  const value = metadata?.[key];
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function toAuthUserRecord(user: User): AuthUserRecord {
  return {
    id: user.id,
    email: user.email ?? "",
    phoneNumber: user.phone ?? undefined,
    createdAt: user.created_at
  };
}

function requirePassword(input: SignupInput | LoginInput): string {
  if (!input.password) {
    throw Object.assign(new Error("password is required for Supabase Auth."), {
      statusCode: 400
    });
  }

  return input.password;
}

function toPublicProfile(user: User, expiresAt?: number | null): PublicUserProfile {
  const metadata = user.user_metadata as Record<string, unknown> | undefined;
  const nickname =
    readStringMetadata(metadata, "nickname") ??
    user.email?.split("@")[0] ??
    "먹킹유저";

  return {
    id: user.id,
    nickname,
    email: user.email ?? "",
    verificationStatus: "unverified",
    mannerScore: DEFAULT_MANNER_SCORE,
    mannerGrade: getMannerGrade(DEFAULT_MANNER_SCORE),
    pendingEvaluationCount: 0,
    createdAt: user.created_at
      ? new Date(user.created_at).toISOString()
      : new Date().toISOString()
  };
}

function toAuthSession(user: User, session: Session): AuthSession {
  return {
    token: session.access_token,
    user: toPublicProfile(user, session.expires_at),
    expiresAt:
      typeof session.expires_at === "number"
        ? new Date(session.expires_at * 1000).toISOString()
        : undefined
  };
}

export const supabaseAuthRepository: AuthRepository = {
  async signup(input) {
    const supabase = getSupabaseAuthClient();
    const password = requirePassword(input);
    const { data, error } = await supabase.auth.signUp({
      email: input.email,
      password,
      options: {
        data: {
          nickname: input.nickname,
          phoneNumber: input.phoneNumber
        }
      }
    });

    if (error) {
      throw Object.assign(new Error(error.message), {
        statusCode: error.status ?? 400
      });
    }

    if (!data.user || !data.session?.access_token) {
      throw Object.assign(
        new Error(
          "Supabase signup did not return an active session. Disable email confirmation for local testing or confirm the email before logging in."
        ),
        { statusCode: 403 }
      );
    }

    return toAuthSession(data.user, data.session);
  },

  async login(input) {
    const supabase = getSupabaseAuthClient();
    const password = requirePassword(input);
    const { data, error } = await supabase.auth.signInWithPassword({
      email: input.email,
      password
    });

    if (error) {
      throw Object.assign(new Error(error.message), {
        statusCode: error.status ?? 401
      });
    }

    if (!data.user || !data.session?.access_token) {
      throw Object.assign(new Error("Supabase login did not return a session."), {
        statusCode: 401
      });
    }

    return toAuthSession(data.user, data.session);
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
    const supabase = getSupabaseServiceRoleClient();
    const { data, error } = await supabase.auth.admin.getUserById(userId);
    const user = data.user;

    if (error || !user) {
      return null;
    }

    return toAuthUserRecord(user);
  },

  async getMfaAssuranceLevel(token) {
    await this.verifyAccessToken(token);
    return readAalFromToken(token);
  }
};
