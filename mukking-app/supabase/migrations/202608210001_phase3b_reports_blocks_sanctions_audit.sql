create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.reports (
  id text primary key,
  reporter_id uuid not null references auth.users(id) on delete restrict,
  reported_user_id uuid not null references auth.users(id) on delete restrict,
  target_type text not null,
  target_id text not null,
  chat_room_id text,
  message_id text,
  reason text not null,
  description text,
  status text not null default 'pending',
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null,
  action_taken text,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reports_target_type_check check (
    target_type in ('user', 'post', 'chat_room', 'chat_message', 'join_request')
  ),
  constraint reports_reason_check check (
    reason in ('inappropriate_chat', 'no_show', 'safety_risk', 'spam', 'other')
  ),
  constraint reports_status_check check (
    status in ('pending', 'reviewing', 'resolved', 'dismissed')
  ),
  constraint reports_not_self_check check (reporter_id <> reported_user_id)
);

create index if not exists idx_reports_reporter_id on public.reports(reporter_id);
create index if not exists idx_reports_reported_user_id on public.reports(reported_user_id);
create index if not exists idx_reports_status on public.reports(status);
create index if not exists idx_reports_created_at on public.reports(created_at desc);
create index if not exists idx_reports_target on public.reports(target_type, target_id);
create index if not exists idx_reports_chat_room_id on public.reports(chat_room_id);
create index if not exists idx_reports_message_id on public.reports(message_id);

drop trigger if exists set_reports_updated_at on public.reports;
create trigger set_reports_updated_at
before update on public.reports
for each row execute function public.set_updated_at();

create table if not exists public.report_events (
  id text primary key,
  report_id text not null references public.reports(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  actor_role text not null,
  event_type text not null,
  previous_status text,
  next_status text,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint report_events_actor_role_check check (
    actor_role in ('user', 'admin', 'system')
  ),
  constraint report_events_event_type_check check (
    event_type in (
      'created',
      'status_changed',
      'admin_note',
      'sanction_created',
      'dismissed',
      'resolved'
    )
  ),
  constraint report_events_previous_status_check check (
    previous_status is null or previous_status in ('pending', 'reviewing', 'resolved', 'dismissed')
  ),
  constraint report_events_next_status_check check (
    next_status is null or next_status in ('pending', 'reviewing', 'resolved', 'dismissed')
  )
);

create index if not exists idx_report_events_report_id on public.report_events(report_id);
create index if not exists idx_report_events_created_at on public.report_events(created_at);
create index if not exists idx_report_events_actor_id on public.report_events(actor_id);

create table if not exists public.blocks (
  id text primary key,
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  scope text not null default 'all',
  reason text,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  constraint blocks_scope_check check (scope in ('all', 'matching', 'chat')),
  constraint blocks_not_self_check check (blocker_id <> blocked_id)
);

create unique index if not exists idx_blocks_active_unique
on public.blocks(blocker_id, blocked_id)
where revoked_at is null;

create index if not exists idx_blocks_blocker_id on public.blocks(blocker_id);
create index if not exists idx_blocks_blocked_id on public.blocks(blocked_id);
create index if not exists idx_blocks_created_at on public.blocks(created_at desc);

create table if not exists public.sanctions (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  report_id text references public.reports(id) on delete set null,
  type text not null,
  status text not null default 'active',
  reason text not null,
  started_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  revoked_by_admin_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sanctions_type_check check (
    type in (
      'warning',
      'matching_suspension',
      'chat_suspension',
      'temporary_suspension',
      'permanent_ban'
    )
  ),
  constraint sanctions_status_check check (status in ('active', 'expired', 'revoked')),
  constraint sanctions_expiry_check check (expires_at is null or expires_at > started_at)
);

create index if not exists idx_sanctions_user_id on public.sanctions(user_id);
create index if not exists idx_sanctions_report_id on public.sanctions(report_id);
create index if not exists idx_sanctions_status on public.sanctions(status);
create index if not exists idx_sanctions_type on public.sanctions(type);
create index if not exists idx_sanctions_expires_at on public.sanctions(expires_at);

drop trigger if exists set_sanctions_updated_at on public.sanctions;
create trigger set_sanctions_updated_at
before update on public.sanctions
for each row execute function public.set_updated_at();

create table if not exists public.admin_audit_logs (
  id text primary key,
  actor_admin_id uuid references auth.users(id) on delete set null,
  actor_email text not null default '',
  action text not null,
  target_type text,
  target_id text,
  aal text,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint admin_audit_logs_target_type_check check (
    target_type is null or target_type in ('user', 'report', 'sanction', 'post', 'chat_room')
  ),
  constraint admin_audit_logs_aal_check check (aal is null or aal in ('aal1', 'aal2'))
);

create index if not exists idx_admin_audit_logs_actor_admin_id
on public.admin_audit_logs(actor_admin_id);
create index if not exists idx_admin_audit_logs_action
on public.admin_audit_logs(action);
create index if not exists idx_admin_audit_logs_target
on public.admin_audit_logs(target_type, target_id);
create index if not exists idx_admin_audit_logs_created_at
on public.admin_audit_logs(created_at desc);

alter table public.reports enable row level security;
alter table public.report_events enable row level security;
alter table public.blocks enable row level security;
alter table public.sanctions enable row level security;
alter table public.admin_audit_logs enable row level security;

revoke all on table public.reports from anon, authenticated;
revoke all on table public.report_events from anon, authenticated;
revoke all on table public.blocks from anon, authenticated;
revoke all on table public.sanctions from anon, authenticated;
revoke all on table public.admin_audit_logs from anon, authenticated;

grant all on table public.reports to service_role;
grant all on table public.report_events to service_role;
grant all on table public.blocks to service_role;
grant all on table public.sanctions to service_role;
grant all on table public.admin_audit_logs to service_role;

grant select, insert, update on table public.blocks to authenticated;

drop policy if exists "Users can view their own blocks" on public.blocks;
create policy "Users can view their own blocks"
on public.blocks
for select
to authenticated
using ((select auth.uid()) = blocker_id);

drop policy if exists "Users can create their own blocks" on public.blocks;
create policy "Users can create their own blocks"
on public.blocks
for insert
to authenticated
with check ((select auth.uid()) = blocker_id and blocker_id <> blocked_id);

drop policy if exists "Users can revoke their own blocks" on public.blocks;
create policy "Users can revoke their own blocks"
on public.blocks
for update
to authenticated
using ((select auth.uid()) = blocker_id)
with check ((select auth.uid()) = blocker_id);
