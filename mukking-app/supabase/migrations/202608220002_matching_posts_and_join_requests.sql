-- Matching persistence. Chat and ratings remain separate memory-backed domains
-- in this milestone, while matching_posts and join_requests become durable.

create table if not exists public.matching_posts (
  id text primary key,
  author_id uuid not null references auth.users(id) on delete restrict,
  restaurant_id text references public.restaurants(id) on delete restrict,
  restaurant_name text not null,
  address text not null,
  location jsonb,
  scheduled_at timestamptz not null,
  max_participants smallint not null,
  intro text not null,
  status text not null default 'open',
  participant_ids uuid[] not null default array[]::uuid[],
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint matching_posts_status_check check (
    status in ('open', 'closed', 'cancelled', 'completed')
  ),
  constraint matching_posts_max_participants_check check (
    max_participants between 1 and 8
  ),
  constraint matching_posts_capacity_check check (
    cardinality(participant_ids) <= max_participants
  ),
  constraint matching_posts_author_not_participant_check check (
    not (author_id = any(participant_ids))
  ),
  constraint matching_posts_completed_at_check check (
    status <> 'completed' or completed_at is not null
  ),
  constraint matching_posts_restaurant_name_not_blank check (length(trim(restaurant_name)) > 0),
  constraint matching_posts_address_not_blank check (length(trim(address)) > 0),
  constraint matching_posts_intro_not_blank check (length(trim(intro)) > 0)
);

create index if not exists idx_matching_posts_author_id
  on public.matching_posts(author_id);
create index if not exists idx_matching_posts_restaurant_id_status
  on public.matching_posts(restaurant_id, status)
  where restaurant_id is not null;
create index if not exists idx_matching_posts_status_scheduled_at
  on public.matching_posts(status, scheduled_at);
create index if not exists idx_matching_posts_created_at
  on public.matching_posts(created_at desc);

drop trigger if exists set_matching_posts_updated_at on public.matching_posts;
create trigger set_matching_posts_updated_at
before update on public.matching_posts
for each row execute function public.set_updated_at();

create table if not exists public.join_requests (
  id text primary key,
  post_id text not null references public.matching_posts(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint join_requests_status_check check (
    status in ('pending', 'accepted', 'rejected', 'cancelled')
  )
);

create unique index if not exists idx_join_requests_pending_unique
  on public.join_requests(post_id, requester_id)
  where status = 'pending';
create index if not exists idx_join_requests_post_created_at
  on public.join_requests(post_id, created_at desc);
create index if not exists idx_join_requests_requester_created_at
  on public.join_requests(requester_id, created_at desc);

drop trigger if exists set_join_requests_updated_at on public.join_requests;
create trigger set_join_requests_updated_at
before update on public.join_requests
for each row execute function public.set_updated_at();

-- Locks both rows to keep request acceptance and capacity updates consistent.
create or replace function public.accept_join_request(p_request_id text)
returns table(request jsonb, post jsonb)
language plpgsql
security definer
set search_path = public
as $$
declare
  request_row public.join_requests%rowtype;
  post_row public.matching_posts%rowtype;
begin
  select * into request_row
  from public.join_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Join request not found' using errcode = 'P0002';
  end if;

  if request_row.status <> 'pending' then
    raise exception 'This join request has already been handled' using errcode = '23514';
  end if;

  select * into post_row
  from public.matching_posts
  where id = request_row.post_id
  for update;

  if not found then
    raise exception 'Matching post not found' using errcode = 'P0002';
  end if;

  if post_row.status <> 'open' then
    raise exception 'This matching post is not open' using errcode = '23514';
  end if;

  if request_row.requester_id = post_row.author_id
    or request_row.requester_id = any(post_row.participant_ids) then
    raise exception 'Requester is already a participant' using errcode = '23514';
  end if;

  if cardinality(post_row.participant_ids) >= post_row.max_participants then
    raise exception 'This matching post is full' using errcode = '23514';
  end if;

  update public.join_requests
  set status = 'accepted', updated_at = now()
  where id = request_row.id
  returning * into request_row;

  update public.matching_posts
  set
    participant_ids = array_append(participant_ids, request_row.requester_id),
    status = case
      when cardinality(participant_ids) + 1 >= max_participants then 'closed'
      else status
    end,
    updated_at = now()
  where id = post_row.id
  returning * into post_row;

  return query select to_jsonb(request_row), to_jsonb(post_row);
end;
$$;

revoke all on function public.accept_join_request(text) from public;
grant execute on function public.accept_join_request(text) to service_role;

alter table public.matching_posts enable row level security;
alter table public.join_requests enable row level security;

revoke all on table public.matching_posts from anon, authenticated;
revoke all on table public.join_requests from anon, authenticated;

grant all on table public.matching_posts to service_role;
grant all on table public.join_requests to service_role;

-- Both tables are server API-only. No anon/authenticated policies are created.
