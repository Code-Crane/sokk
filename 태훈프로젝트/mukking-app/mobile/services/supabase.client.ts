import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.EXPO_PUBLIC_SUPABASE_URL ?? "";
const SUPABASE_ANON_KEY = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? "";

let supabaseClient: SupabaseClient | null = null;

export function isSupabaseClientConfigured(): boolean {
  return Boolean(SUPABASE_URL && SUPABASE_ANON_KEY);
}

export function getSupabaseClient(): SupabaseClient {
  if (!isSupabaseClientConfigured()) {
    throw new Error(
      "Supabase client is not configured. Set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY."
    );
  }

  supabaseClient ??= createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  return supabaseClient;
}
