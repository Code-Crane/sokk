import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { environment } from "./environment";

let authClient: SupabaseClient | null = null;
let serviceRoleClient: SupabaseClient | null = null;

export function isSupabaseAuthConfigured(): boolean {
  return Boolean(environment.supabaseUrl && environment.supabaseAnonKey);
}

export function isSupabaseServiceRoleConfigured(): boolean {
  return Boolean(
    environment.supabaseUrl && environment.supabaseServiceRoleKey
  );
}

export function getSupabaseAuthClient(): SupabaseClient {
  if (!isSupabaseAuthConfigured()) {
    throw Object.assign(
      new Error("Supabase Auth is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY."),
      { statusCode: 500 }
    );
  }

  authClient ??= createClient(environment.supabaseUrl, environment.supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });

  return authClient;
}

export function getSupabaseServiceRoleClient(): SupabaseClient {
  if (!isSupabaseServiceRoleConfigured()) {
    throw Object.assign(
      new Error(
        "Supabase service role is not configured. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY on the server only."
      ),
      { statusCode: 500 }
    );
  }

  serviceRoleClient ??= createClient(
    environment.supabaseUrl,
    environment.supabaseServiceRoleKey,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    }
  );

  return serviceRoleClient;
}
