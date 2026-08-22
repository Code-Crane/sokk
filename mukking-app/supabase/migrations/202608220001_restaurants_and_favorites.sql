-- Restaurant discovery foundation. Matching posts remain memory-backed for now,
-- so restaurant_id is an application-level optional link until posts migrate.

create table if not exists public.restaurants (
  id text primary key,
  name text not null,
  address text not null,
  latitude numeric(9, 6) not null,
  longitude numeric(9, 6) not null,
  category text not null,
  place_provider text not null,
  place_provider_id text not null,
  image_url text,
  phone text,
  road_address text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint restaurants_name_not_blank check (length(trim(name)) > 0),
  constraint restaurants_address_not_blank check (length(trim(address)) > 0),
  constraint restaurants_category_not_blank check (length(trim(category)) > 0),
  constraint restaurants_provider_not_blank check (length(trim(place_provider)) > 0),
  constraint restaurants_provider_id_not_blank check (length(trim(place_provider_id)) > 0),
  constraint restaurants_latitude_range check (latitude between -90 and 90),
  constraint restaurants_longitude_range check (longitude between -180 and 180),
  constraint restaurants_provider_place_unique unique (place_provider, place_provider_id)
);

create index if not exists idx_restaurants_category on public.restaurants(category);
create index if not exists idx_restaurants_created_at on public.restaurants(created_at desc);
create index if not exists idx_restaurants_latitude_longitude
  on public.restaurants(latitude, longitude);

drop trigger if exists set_restaurants_updated_at on public.restaurants;
create trigger set_restaurants_updated_at
before update on public.restaurants
for each row execute function public.set_updated_at();

create table if not exists public.restaurant_favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  restaurant_id text not null references public.restaurants(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, restaurant_id)
);

create index if not exists idx_restaurant_favorites_restaurant_id
  on public.restaurant_favorites(restaurant_id);
create index if not exists idx_restaurant_favorites_user_created_at
  on public.restaurant_favorites(user_id, created_at desc);

alter table public.restaurants enable row level security;
alter table public.restaurant_favorites enable row level security;

revoke all on table public.restaurants from anon, authenticated;
revoke all on table public.restaurant_favorites from anon, authenticated;

grant all on table public.restaurants to service_role;
grant all on table public.restaurant_favorites to service_role;
grant select on table public.restaurants to authenticated;
grant select, insert, delete on table public.restaurant_favorites to authenticated;

drop policy if exists "Authenticated users can view restaurants" on public.restaurants;
create policy "Authenticated users can view restaurants"
on public.restaurants
for select
to authenticated
using (true);

drop policy if exists "Users can view their own restaurant favorites" on public.restaurant_favorites;
create policy "Users can view their own restaurant favorites"
on public.restaurant_favorites
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can favorite restaurants for themselves" on public.restaurant_favorites;
create policy "Users can favorite restaurants for themselves"
on public.restaurant_favorites
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can remove their own restaurant favorites" on public.restaurant_favorites;
create policy "Users can remove their own restaurant favorites"
on public.restaurant_favorites
for delete
to authenticated
using ((select auth.uid()) = user_id);

-- Future PostGIS migration (kept separate for safe rollout):
-- add geography(Point, 4326), backfill from numeric coordinates, and add a GiST index.
-- Current radius filtering uses server-side Haversine distance and the numeric index above.
