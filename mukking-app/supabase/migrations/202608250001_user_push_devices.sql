begin;

create table if not exists public.user_push_devices (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null default 'fcm',
  platform text not null,
  push_token text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint user_push_devices_provider_check check (provider in ('fcm')),
  constraint user_push_devices_platform_check check (
    platform in ('android', 'ios', 'web')
  ),
  constraint user_push_devices_token_not_blank check (
    length(trim(push_token)) between 1 and 4096
  )
);

create unique index if not exists uq_user_push_devices_provider_token
  on public.user_push_devices(provider, push_token);

create index if not exists idx_user_push_devices_user_active
  on public.user_push_devices(user_id, updated_at desc)
  where enabled = true;

drop trigger if exists set_user_push_devices_updated_at
  on public.user_push_devices;
create trigger set_user_push_devices_updated_at
before update on public.user_push_devices
for each row execute function public.set_updated_at();

alter table public.user_push_devices enable row level security;

revoke all on table public.user_push_devices from public, anon, authenticated;
grant all on table public.user_push_devices to service_role;

comment on table public.user_push_devices is
  'Server-managed push delivery devices. Clients must use the authenticated Node/Express API.';

comment on column public.user_push_devices.push_token is
  'Sensitive delivery credential. Never expose through API responses or logs.';

commit;
