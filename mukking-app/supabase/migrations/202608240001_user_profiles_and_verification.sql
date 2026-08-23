create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  nickname text not null,
  phone_number text not null default '',
  verification_status text not null default 'unverified',
  account_status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_profiles_email_not_blank check (length(trim(email)) > 0),
  constraint user_profiles_nickname_not_blank check (length(trim(nickname)) > 0),
  constraint user_profiles_verification_status_check check (verification_status in ('unverified','pending','verified')),
  constraint user_profiles_account_status_check check (account_status in ('active','suspended','banned'))
);
create index if not exists idx_user_profiles_verification_status on public.user_profiles(verification_status);
create index if not exists idx_user_profiles_account_status on public.user_profiles(account_status);
drop trigger if exists set_user_profiles_updated_at on public.user_profiles;
create trigger set_user_profiles_updated_at before update on public.user_profiles
for each row execute function public.set_updated_at();

create table if not exists public.verification_claims (
  user_id uuid primary key references auth.users(id) on delete cascade,
  provider text not null default 'pass_mock',
  status text not null default 'unverified',
  requested_at timestamptz,
  verified_at timestamptz,
  provider_transaction_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint verification_claims_provider_check check (provider in ('pass_mock','pass')),
  constraint verification_claims_status_check check (status in ('unverified','pending','verified')),
  constraint verification_claims_verified_time_check check (status <> 'verified' or verified_at is not null)
);
create index if not exists idx_verification_claims_status on public.verification_claims(status);
drop trigger if exists set_verification_claims_updated_at on public.verification_claims;
create trigger set_verification_claims_updated_at before update on public.verification_claims
for each row execute function public.set_updated_at();

create table if not exists public.verification_failure_logs (
  id text primary key,
  user_id uuid references auth.users(id) on delete set null,
  provider text not null,
  reason_code text not null,
  message text,
  request_payload_hash text,
  ip_hash text,
  user_agent_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint verification_failure_logs_provider_check check (provider in ('pass_mock','pass'))
);
create index if not exists idx_verification_failure_logs_user on public.verification_failure_logs(user_id);
create index if not exists idx_verification_failure_logs_created on public.verification_failure_logs(created_at desc);

alter table public.user_profiles enable row level security;
alter table public.verification_claims enable row level security;
alter table public.verification_failure_logs enable row level security;
revoke all on table public.user_profiles, public.verification_claims, public.verification_failure_logs from anon, authenticated;
grant all on table public.user_profiles, public.verification_claims, public.verification_failure_logs to service_role;
-- No direct client policies. Identity payloads, legal name, birth date and gender are not stored.
