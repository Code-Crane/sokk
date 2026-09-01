import type { RepositoryRegistry } from "./interfaces/repository-registry";
import { environment } from "../config/environment";
import { memoryRepositories } from "./memory";
import { supabaseAuthRepository } from "./supabase/auth.supabase.repository";

export const repositories: RepositoryRegistry = {
  ...memoryRepositories,
  auth:
    environment.authProvider === "supabase"
      ? supabaseAuthRepository
      : memoryRepositories.auth
};

export type { RepositoryRegistry } from "./interfaces/repository-registry";
