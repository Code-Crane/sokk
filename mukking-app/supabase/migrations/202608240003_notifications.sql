begin;

create table if not exists public.notifications (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  restaurant_id text references public.restaurants(id) on delete set null,
  matching_post_id text references public.matching_posts(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint notifications_type_check check (
    type in ('favorite_restaurant_party_created')
  ),
  constraint notifications_title_not_blank check (length(trim(title)) > 0),
  constraint notifications_body_not_blank check (length(trim(body)) > 0),
  constraint notifications_event_context_check check (
    type <> 'favorite_restaurant_party_created' or
    matching_post_id is not null
  ),
  constraint notifications_read_after_create check (
    read_at is null or read_at >= created_at
  ),
  constraint notifications_user_event_unique unique (
    user_id,
    type,
    matching_post_id
  )
);

create index if not exists idx_notifications_user_created_at
  on public.notifications(user_id, created_at desc, id desc);

create index if not exists idx_notifications_user_unread
  on public.notifications(user_id, created_at desc, id desc)
  where read_at is null;

create index if not exists idx_notifications_matching_post_id
  on public.notifications(matching_post_id);

create index if not exists idx_notifications_restaurant_id
  on public.notifications(restaurant_id);

alter table public.notifications enable row level security;

revoke all on table public.notifications from public, anon, authenticated;
grant all on table public.notifications to service_role;

comment on table public.notifications is
  'Server-managed in-app notifications. Client access must use Node/Express APIs.';

comment on column public.notifications.body is
  'Non-sensitive user-facing copy; do not store phone, verification, or location data.';

commit;
