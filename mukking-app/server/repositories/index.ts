import type { RepositoryRegistry } from "./interfaces/repository-registry";
import { environment } from "../config/environment";
import { memoryRepositories } from "./memory";
import { supabaseAdminRepository } from "./supabase/admin.supabase.repository";
import { supabaseAuthRepository } from "./supabase/auth.supabase.repository";
import { supabaseBlockRepository } from "./supabase/block.supabase.repository";
import { supabaseReportRepository } from "./supabase/report.supabase.repository";
import { supabaseSanctionRepository } from "./supabase/sanction.supabase.repository";

const useSupabaseRepositories = environment.repositoryProvider === "supabase";

export const repositories: RepositoryRegistry = {
  ...memoryRepositories,
  admin: useSupabaseRepositories
    ? supabaseAdminRepository
    : memoryRepositories.admin,
  auth:
    environment.authProvider === "supabase"
      ? supabaseAuthRepository
      : memoryRepositories.auth,
  blocks: useSupabaseRepositories
    ? supabaseBlockRepository
    : memoryRepositories.blocks,
  reports: useSupabaseRepositories
    ? supabaseReportRepository
    : memoryRepositories.reports,
  sanctions: useSupabaseRepositories
    ? supabaseSanctionRepository
    : memoryRepositories.sanctions
};

export type { RepositoryRegistry } from "./interfaces/repository-registry";
