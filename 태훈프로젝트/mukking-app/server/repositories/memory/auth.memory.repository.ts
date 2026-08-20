import type { AuthRepository, AuthUserRecord } from "../interfaces/auth.repository";
import type { MfaAssuranceLevel } from "../interfaces/repository.types";
import {
  createSignedJwt,
  verifySignedJwt
} from "../../services/auth/jwt.service";
import { memoryUserRepository } from "./user.memory.repository";

export const memoryAuthRepository: AuthRepository = {
  async signup(input) {
    const existingUser = await memoryUserRepository.findByEmail(input.email);

    if (existingUser) {
      throw Object.assign(new Error("A user with this email already exists."), {
        statusCode: 409
      });
    }

    const user = await memoryUserRepository.create(input);
    const publicUser = memoryUserRepository.toPublicProfile(user, 0);

    return {
      token: createSignedJwt({
        userId: publicUser.id,
        email: publicUser.email,
        aal: "aal1"
      }),
      user: publicUser
    };
  },

  async login(input) {
    const user = await memoryUserRepository.findByEmail(input.email);

    if (!user) {
      throw Object.assign(new Error("No mock account exists for this email."), {
        statusCode: 404
      });
    }

    const publicUser = memoryUserRepository.toPublicProfile(user, 0);

    return {
      token: createSignedJwt({
        userId: publicUser.id,
        email: publicUser.email,
        aal: "aal1"
      }),
      user: publicUser
    };
  },

  async createSession(user) {
    return {
      token: createSignedJwt({
        userId: user.id,
        email: user.email,
        aal: "aal1"
      }),
      user
    };
  },

  async verifyAccessToken(token) {
    const claims = verifySignedJwt(token);
    const user = await memoryUserRepository.findById(claims.userId);

    if (!user) {
      throw Object.assign(new Error("Invalid or expired mock token."), {
        statusCode: 401
      });
    }

    return {
      ...claims,
      userId: user.id,
      email: claims.email ?? user.email
    };
  },

  async getAuthUser(userId) {
    const user = await memoryUserRepository.findById(userId);

    if (!user) {
      return null;
    }

    const record: AuthUserRecord = {
      id: user.id,
      email: user.email,
      phoneNumber: user.phoneNumber,
      createdAt: user.createdAt
    };

    return record;
  },

  async getMfaAssuranceLevel(token): Promise<MfaAssuranceLevel> {
    return verifySignedJwt(token).aal ?? "aal1";
  }
};
