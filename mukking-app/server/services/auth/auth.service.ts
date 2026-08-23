import type {
  AuthSession,
  LoginInput,
  PublicUserProfile,
  SignupInput,
  UserAccount
} from "../../../shared/types";
import { environment } from "../../config/environment";
import type { VerifiedAuthClaims } from "../../repositories/interfaces/repository.types";
import { repositories } from "../../repositories";
import {
  assertMannerScoreCanMatch,
  assertNoPendingEvaluations,
  DEFAULT_MANNER_SCORE,
  getMannerGrade,
  getPendingEvaluationCount
} from "../rating/rating.service";
import { assertNoActiveRestriction } from "../sanction/sanction.service";

async function toPublicUser(user: UserAccount): Promise<PublicUserProfile> {
  const storedMannerProfile = await repositories.rating.getMannerProfile(user.id);
  const currentUser = storedMannerProfile
    ? await repositories.users.updateMannerProfile(
        user.id,
        storedMannerProfile.mannerScore,
        storedMannerProfile.mannerGrade
      )
    : user;
  return repositories.users.toPublicProfile(
    currentUser,
    await getPendingEvaluationCount(currentUser.id)
  );
}

function readClaimsMetadata(claims: VerifiedAuthClaims): Record<string, unknown> {
  const metadata = claims.rawClaims?.user_metadata;

  return metadata && typeof metadata === "object" && !Array.isArray(metadata)
    ? (metadata as Record<string, unknown>)
    : {};
}

function readString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function getProfileDefaultsFromClaims(
  claims: VerifiedAuthClaims,
  input?: Partial<SignupInput>
): Pick<SignupInput, "email" | "nickname" | "phoneNumber"> {
  const metadata = readClaimsMetadata(claims);
  const email =
    input?.email ??
    claims.email ??
    readString(claims.rawClaims?.email) ??
    `${claims.userId}@supabase.local`;
  const nickname =
    input?.nickname ??
    readString(metadata.nickname) ??
    readString(metadata.name) ??
    email.split("@")[0] ??
    "먹킹유저";
  const phoneNumber =
    input?.phoneNumber ??
    readString(metadata.phoneNumber) ??
    readString(metadata.phone) ??
    "";

  return {
    email,
    nickname,
    phoneNumber
  };
}

async function ensureUserProfileForClaims(
  claims: VerifiedAuthClaims,
  input?: Partial<SignupInput>
): Promise<UserAccount> {
  const existingUser = await repositories.users.findById(claims.userId);

  if (existingUser) {
    return existingUser;
  }

  const profileDefaults = getProfileDefaultsFromClaims(claims, input);
  const user = await repositories.users.create({
    id: claims.userId,
    ...profileDefaults,
    verificationStatus: "unverified",
    mannerScore: DEFAULT_MANNER_SCORE,
    mannerGrade: getMannerGrade(DEFAULT_MANNER_SCORE)
  });

  await repositories.verification.upsertClaim({
    userId: user.id,
    provider: "pass_mock",
    status: "unverified"
  });

  return user;
}

export interface AuthenticatedSession {
  user: PublicUserProfile;
  claims: Awaited<ReturnType<typeof repositories.auth.verifyAccessToken>>;
}

export async function signup(input: SignupInput): Promise<AuthSession> {
  if (environment.authProvider === "supabase") {
    const authSession = await repositories.auth.signup(input);
    const claims = await repositories.auth.verifyAccessToken(authSession.token);
    const user = await ensureUserProfileForClaims(claims, input);

    return {
      ...authSession,
      user: await toPublicUser(user)
    };
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
    const authSession = await repositories.auth.login(input);
    const claims = await repositories.auth.verifyAccessToken(authSession.token);
    const user = await ensureUserProfileForClaims(claims, input);

    return {
      ...authSession,
      user: await toPublicUser(user)
    };
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
  let user = await repositories.users.findById(claims.userId);

  if (!user && claims.authProvider === "supabase") {
    user = await ensureUserProfileForClaims(claims);
  }

  if (!user) {
    throw Object.assign(new Error("Authenticated user profile was not found."), {
      statusCode: 401
    });
  }

  await assertNoActiveRestriction(user.id, "login");

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
  await assertNoActiveRestriction(userId, "matching");
  await assertNoPendingEvaluations(userId);
  await assertMannerScoreCanMatch(userId);

  return user;
}

export async function assertCanUseChat(userId: string): Promise<UserAccount> {
  const user = await assertVerifiedUser(userId);
  await assertNoActiveRestriction(userId, "chat");

  return user;
}
