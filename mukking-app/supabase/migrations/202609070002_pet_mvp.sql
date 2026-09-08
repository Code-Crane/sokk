-- Prepared only: requires explicit approval before live application.
create table public.user_pets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  pet_type text not null check (pet_type in ('healthy', 'night', 'hearty')),
  name text,
  xp bigint not null default 0 check (xp >= 0 and xp <= 9007199254740991),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.pet_xp_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_type text not null check (source_type in ('matching_completed', 'hosted_matching_completed', 'manner_rating_completed')),
  source_id text not null check (length(trim(source_id)) > 0),
  xp_amount integer not null check (xp_amount > 0),
  created_at timestamptz not null default now(),
  unique (user_id, source_type, source_id)
);
alter table public.user_pets enable row level security;
alter table public.pet_xp_events enable row level security;
-- Backend service-role repository is the only writer, including initial selection.
revoke all on public.user_pets, public.pet_xp_events from anon, authenticated;
grant select, insert, update, delete on public.user_pets, public.pet_xp_events to service_role;

create function public.award_pet_xp(p_user_id uuid, p_source_type text, p_source_id text, p_amount integer)
returns boolean language plpgsql security invoker set search_path = public
as $$
declare v_pet_id uuid; v_event_id uuid;
begin
  if p_amount is null or p_amount <= 0 or p_source_id is null or length(trim(p_source_id)) = 0 then
    raise exception 'Invalid XP event';
  end if;
  -- Serialize awards per pet before the unique-event check and total update.
  select id into v_pet_id from public.user_pets where user_id = p_user_id for update;
  if v_pet_id is null then return false; end if;
  insert into public.pet_xp_events(user_id, source_type, source_id, xp_amount)
    values (p_user_id, p_source_type, p_source_id, p_amount)
    on conflict (user_id, source_type, source_id) do nothing returning id into v_event_id;
  if v_event_id is null then return false; end if;
  update public.user_pets set xp = xp + p_amount, updated_at = now() where id = v_pet_id;
  return true;
end;
$$;
revoke all on function public.award_pet_xp(uuid, text, text, integer) from public, anon, authenticated;
grant execute on function public.award_pet_xp(uuid, text, text, integer) to service_role;
