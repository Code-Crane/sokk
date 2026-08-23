-- Chat persistence. Direct client access remains closed; Node/Express uses
-- service_role repositories. Realtime is intentionally not enabled here.

create table if not exists public.chat_rooms (
  id text primary key,
  matching_post_id text not null references public.matching_posts(id) on delete restrict,
  title text not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chat_rooms_status_check check (status in ('active', 'closed', 'reported')),
  constraint chat_rooms_title_not_blank check (length(trim(title)) > 0)
);

create unique index if not exists idx_chat_rooms_one_active_per_matching_post
  on public.chat_rooms(matching_post_id)
  where status = 'active';
create index if not exists idx_chat_rooms_matching_post_id
  on public.chat_rooms(matching_post_id);
create index if not exists idx_chat_rooms_updated_at
  on public.chat_rooms(updated_at desc, id desc);

drop trigger if exists set_chat_rooms_updated_at on public.chat_rooms;
create trigger set_chat_rooms_updated_at
before update on public.chat_rooms
for each row execute function public.set_updated_at();

create table if not exists public.chat_room_participants (
  room_id text not null references public.chat_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete restrict,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id),
  constraint chat_room_participants_role_check check (role in ('owner', 'member'))
);

create index if not exists idx_chat_room_participants_user_room
  on public.chat_room_participants(user_id, room_id);
create index if not exists idx_chat_room_participants_room_joined
  on public.chat_room_participants(room_id, joined_at, user_id);

create table if not exists public.chat_messages (
  id text primary key,
  room_id text not null references public.chat_rooms(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete set null,
  message_type text not null default 'user',
  text text not null,
  created_at timestamptz not null default now(),
  constraint chat_messages_type_check check (
    message_type in ('user', 'system', 'admin_notice')
  ),
  constraint chat_messages_text_not_blank check (length(trim(text)) > 0),
  constraint chat_messages_user_sender_check check (
    message_type <> 'user' or sender_id is not null
  )
);

create index if not exists idx_chat_messages_room_order
  on public.chat_messages(room_id, created_at, id);
create index if not exists idx_chat_messages_sender_id
  on public.chat_messages(sender_id)
  where sender_id is not null;

-- Creates the room and its initial membership together. If a concurrent accept
-- already created the active room, the existing room is reused and membership
-- is merged without duplicating rows.
create or replace function public.create_or_reuse_chat_room(
  p_room_id text,
  p_matching_post_id text,
  p_title text,
  p_participant_ids uuid[],
  p_status text default 'active'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  room_row public.chat_rooms%rowtype;
begin
  if p_participant_ids is null or cardinality(p_participant_ids) = 0 then
    raise exception 'At least one participant is required' using errcode = '23514';
  end if;

  insert into public.chat_rooms (
    id,
    matching_post_id,
    title,
    status,
    created_at,
    updated_at
  ) values (
    p_room_id,
    p_matching_post_id,
    p_title,
    p_status,
    now(),
    now()
  )
  on conflict do nothing;

  select * into room_row
  from public.chat_rooms
  where id = p_room_id
     or (matching_post_id = p_matching_post_id and status = 'active')
  order by case when id = p_room_id then 0 else 1 end
  limit 1;

  if not found then
    raise exception 'Chat room could not be created' using errcode = 'P0002';
  end if;

  insert into public.chat_room_participants (room_id, user_id, role, joined_at)
  select
    room_row.id,
    participant.user_id,
    case when participant.ordinality = 1 then 'owner' else 'member' end,
    now()
  from unnest(p_participant_ids) with ordinality as participant(user_id, ordinality)
  on conflict (room_id, user_id) do nothing;

  return to_jsonb(room_row);
end;
$$;

revoke all on function public.create_or_reuse_chat_room(text, text, text, uuid[], text)
  from public;
grant execute on function public.create_or_reuse_chat_room(text, text, text, uuid[], text)
  to service_role;

alter table public.chat_rooms enable row level security;
alter table public.chat_room_participants enable row level security;
alter table public.chat_messages enable row level security;

revoke all on table public.chat_rooms from anon, authenticated;
revoke all on table public.chat_room_participants from anon, authenticated;
revoke all on table public.chat_messages from anon, authenticated;

grant all on table public.chat_rooms to service_role;
grant all on table public.chat_room_participants to service_role;
grant all on table public.chat_messages to service_role;

-- No anon/authenticated policies are created. All access is via server APIs.
