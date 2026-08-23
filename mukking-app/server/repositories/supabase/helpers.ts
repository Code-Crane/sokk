import type { PostgrestError } from "@supabase/supabase-js";

export function throwSupabaseError(error: PostgrestError | Error | null): never {
  const code = "code" in (error ?? {}) ? (error as PostgrestError).code : undefined;
  const statusCode =
    code === "23505" || code === "23514" ? 409 : code === "P0002" ? 404 : 500;

  throw Object.assign(new Error(error?.message ?? "Supabase repository error."), {
    statusCode
  });
}

export function ensureRow<T>(row: T | null, message: string): T {
  if (!row) {
    throw Object.assign(new Error(message), { statusCode: 404 });
  }

  return row;
}
