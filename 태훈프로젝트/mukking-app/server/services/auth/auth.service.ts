import type {
  AuthSession,
  LoginInput,
  PublicUserProfile,
  SignupInput,
  UserAccount
} from "../../../shared/types";
import { environment } from "../../config/environment";
import { repositories } from "../../repositories";
import {
  assertMannerScoreCanMatch,
  assertNoPendingEvaluations,
  DEFAULT_MANNER_SCORE,
  getMannerGrade,
  getPendingEvaluationCount
} from "../rating/rating.service";

async function toPublicUser(user: UserAccount): Promise<PublicUserProfile> {
  return repositories.users.toPublicProfile(
    user,
    await getPendingEvaluationCount(user.id)
  );
}

export interface AuthenticatedSession {
  user: PublicUserProfile;
  claims: Awaited<ReturnType<typeof repositories.auth.verifyAccessToken>>;
}

export async function signup(input: SignupInput): Promise<AuthSession> {
  if (environment.authProvider === "supabase") {
    return repositories.auth.signup(input);
  }

  if (!input.email || !input.nickname || !input.phoneNumber) {
    throw Object.assign(new Error("email, nickname, and phoneNumber are required."), {
      statusCode: 400
    });
  }

  if (await repositories.users.findByEmail(input.email)) {
    throw Object.assign(new Error("A user with this email already exists."), {
      statusCode: 409
    });
  }

  const user = await repositories.users.create({
    ...input,
    verificationStatus: "unverified",
    mannerScore: DEFAULT_MANNER_SCORE,
    mannerGrade: getMannerGrade(DEFAULT_MANNER_SCORE)
  });

  await repositories.verification.upsertClaim({
    userId: user.id,
    provider: "pass_mock",
    status: "unverified"
  });

  return repositories.auth.createSession(await toPublicUser(user));
}

export async function login(input: LoginInput): Promise<AuthSession> {
  if (environment.authProvider === "supabase") {
    return repositories.auth.login(input);
  }

  const user = await repositories.users.findByEmail(input.email);

  if (!user) {
    throw Object.assign(new Error("No mock account exists for this email."), {
      statusCode: 404
    });
  }

  return repositories.auth.createSession(await toPublicUser(user));
}

export async function authenticateToken(token: string): Promise<AuthenticatedSession> {
  const claims = await repositories.auth.verifyAccessToken(token);
  const user = await repositories.users.findById(claims.userId);

  if (!user) {
    throw Object.assign(new Error("Invalid or expired mock token."), {
      statusCode: 401
    });
  }

  return {
    claims,
    user: await toPublicUser(user)
  };
}

export async function getSessionUser(token: string): Promise<PublicUserProfile> {
  return (await authenticateToken(token)).user;
}

export async function assertVerifiedUser(userId: string): Promise<UserAccount> {
  const user = await repositories.users.findById(userId);

  if (!user) {
    throw Object.assign(new Error("User not found."), { statusCode: 404 });
  }

  if (user.verificationStatus !== "verified") {
    throw Object.assign(new Error("Verification is required for this action."), {
      statusCode: 403
    });
  }

  return user;
}

export async function assertCanUseMatching(userId: string): Promise<UserAccount> {
  const user = await assertVerifiedUser(userId);
  await assertNoPendingEvaluations(userId);
  await assertMannerScoreCanMatch(userId);

  return user;
}
