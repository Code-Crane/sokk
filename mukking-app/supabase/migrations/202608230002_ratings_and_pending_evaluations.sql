-- Rating persistence. Direct client access stays closed; Node/Express uses service_role.

create table if not exists public.pending_evaluations (
  id text primary key,
  matching_post_id text not null references public.matching_posts(id) on delete restrict,
  reviewer_id uuid not null references auth.users(id) on delete restrict,
  reviewee_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint pending_evaluations_distinct_users check (reviewer_id <> reviewee_id),
  constraint pending_evaluations_unique_pair unique (matching_post_id, reviewer_id, reviewee_id)
);

create index if not exists idx_pending_evaluations_reviewer_order
  on public.pending_evaluations(reviewer_id, created_at desc, id desc);
create index if not exists idx_pending_evaluations_reviewee
  on public.pending_evaluations(reviewee_id);

create table if not exists public.user_manner_profiles (
  user_id uuid primary key references auth.users(id) on delete restrict,
  manner_score numeric(4,1) not null default 36.5,
  manner_grade text not null default 'regular',
  updated_at timestamptz not null default now(),
  constraint user_manner_profiles_score_check check (manner_score between 0 and 50),
  constraint user_manner_profiles_grade_check check (manner_grade in ('sprout', 'regular', 'foodie', 'mukking'))
);

create table if not exists public.manner_ratings (
  id text primary key,
  matching_post_id text not null references public.matching_posts(id) on delete restrict,
  reviewer_id uuid not null references auth.users(id) on delete restrict,
  reviewee_id uuid not null references auth.users(id) on delete restrict,
  score smallint not null,
  tags text[] not null default '{}',
  source text not null default 'meeting_review',
  previous_score numeric(4,1) not null,
  next_score numeric(4,1) not null,
  delta numeric(5,1) not null,
  created_at timestamptz not null default now(),
  constraint manner_ratings_score_check check (score between 1 and 5),
  constraint manner_ratings_distinct_users check (reviewer_id <> reviewee_id),
  constraint manner_ratings_source_check check (source in ('meeting_review', 'admin_adjustment', 'system_penalty')),
  constraint manner_ratings_scores_check check (previous_score between 0 and 50 and next_score between 0 and 50)
);

create unique index if not exists idx_manner_ratings_unique_meeting_review
  on public.manner_ratings(matching_post_id, reviewer_id, reviewee_id)
  where source = 'meeting_review';
create index if not exists idx_manner_ratings_reviewee_order
  on public.manner_ratings(reviewee_id, created_at desc, id desc);
create index if not exists idx_manner_ratings_reviewer_order
  on public.manner_ratings(reviewer_id, created_at desc, id desc);

create or replace function public.submit_manner_rating(
  p_rating_id text,
  p_pending_evaluation_id text,
  p_matching_post_id text,
  p_reviewer_id uuid,
  p_reviewee_id uuid,
  p_score smallint,
  p_tags text[],
  p_delta numeric,
  p_source text default 'meeting_review'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  pending_row public.pending_evaluations%rowtype;
  rating_row public.manner_ratings%rowtype;
  previous_value numeric(4,1);
  next_value numeric(4,1);
  next_grade text;
begin
  select * into pending_row from public.pending_evaluations
  where id = p_pending_evaluation_id for update;
  if not found or pending_row.matching_post_id <> p_matching_post_id
    or pending_row.reviewer_id <> p_reviewer_id or pending_row.reviewee_id <> p_reviewee_id then
    raise exception 'Pending evaluation not found' using errcode = 'P0002';
  end if;

  insert into public.user_manner_profiles(user_id) values (p_reviewee_id)
  on conflict (user_id) do nothing;
  select manner_score into previous_value from public.user_manner_profiles
  where user_id = p_reviewee_id for update;
  next_value := round(greatest(0, least(50, previous_value + p_delta)), 1);
  next_grade := case when next_value >= 45 then 'mukking' when next_value >= 40 then 'foodie'
    when next_value >= 35 then 'regular' else 'sprout' end;

  insert into public.manner_ratings(id, matching_post_id, reviewer_id, reviewee_id, score,
    tags, source, previous_score, next_score, delta)
  values (p_rating_id, p_matching_post_id, p_reviewer_id, p_reviewee_id, p_score,
    coalesce(p_tags, '{}'), p_source, previous_value, next_value, p_delta)
  returning * into rating_row;
  update public.user_manner_profiles set manner_score = next_value, manner_grade = next_grade,
    updated_at = now() where user_id = p_reviewee_id;
  delete from public.pending_evaluations where id = p_pending_evaluation_id;

  return jsonb_build_object('rating', to_jsonb(rating_row), 'previous_score', previous_value,
    'next_score', next_value, 'next_grade', next_grade);
end;
$$;

revoke all on function public.submit_manner_rating(text, text, text, uuid, uuid, smallint, text[], numeric, text) from public;
grant execute on function public.submit_manner_rating(text, text, text, uuid, uuid, smallint, text[], numeric, text) to service_role;

alter table public.pending_evaluations enable row level security;
alter table public.user_manner_profiles enable row level security;
alter table public.manner_ratings enable row level security;
revoke all on table public.pending_evaluations from anon, authenticated;
revoke all on table public.user_manner_profiles from anon, authenticated;
revoke all on table public.manner_ratings from anon, authenticated;
grant all on table public.pending_evaluations to service_role;
grant all on table public.user_manner_profiles to service_role;
grant all on table public.manner_ratings to service_role;

-- No anon/authenticated policies are created. Rating access is server API only.
