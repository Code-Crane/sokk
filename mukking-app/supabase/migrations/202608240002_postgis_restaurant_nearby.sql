-- PostGIS-backed restaurant radius search.
-- Numeric latitude/longitude remain the canonical compatibility fields.

begin;

create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

do $$
declare
  postgis_schema text;
begin
  select namespace.nspname
  into postgis_schema
  from pg_catalog.pg_extension as extension
  join pg_catalog.pg_namespace as namespace
    on namespace.oid = extension.extnamespace
  where extension.extname = 'postgis';

  if postgis_schema is distinct from 'extensions' then
    raise exception 'PostGIS must be installed in the extensions schema (found: %)',
      coalesce(postgis_schema, 'not installed');
  end if;
end;
$$;

alter table public.restaurants
  add column if not exists location extensions.geography(Point, 4326);

create or replace function public.sync_restaurant_location()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.location := extensions.st_setsrid(
    extensions.st_makepoint(
      new.longitude::double precision,
      new.latitude::double precision
    ),
    4326
  )::extensions.geography;
  return new;
end;
$$;

update public.restaurants
set location = extensions.st_setsrid(
  extensions.st_makepoint(
    longitude::double precision,
    latitude::double precision
  ),
  4326
)::extensions.geography
where location is null;

alter table public.restaurants
  alter column location set not null;

drop trigger if exists sync_restaurant_location on public.restaurants;
create trigger sync_restaurant_location
before insert or update of latitude, longitude on public.restaurants
for each row execute function public.sync_restaurant_location();

create index if not exists idx_restaurants_location_gist
  on public.restaurants using gist(location);

create or replace function public.nearby_restaurants(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_meters double precision,
  p_category text default null,
  p_place_provider text default null,
  p_place_provider_id text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns table (
  id text,
  name text,
  address text,
  latitude numeric,
  longitude numeric,
  category text,
  place_provider text,
  place_provider_id text,
  image_url text,
  phone text,
  road_address text,
  metadata jsonb,
  created_at timestamptz,
  updated_at timestamptz,
  distance_meters double precision
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  query_location extensions.geography;
begin
  if p_latitude is null
    or p_latitude = 'NaN'::double precision
    or p_latitude < -90
    or p_latitude > 90 then
    raise exception 'latitude must be between -90 and 90' using errcode = '22023';
  end if;

  if p_longitude is null
    or p_longitude = 'NaN'::double precision
    or p_longitude < -180
    or p_longitude > 180 then
    raise exception 'longitude must be between -180 and 180' using errcode = '22023';
  end if;

  if p_radius_meters is null
    or p_radius_meters = 'NaN'::double precision
    or p_radius_meters <= 0
    or p_radius_meters > 100000 then
    raise exception 'radius must be greater than 0 and at most 100000 meters'
      using errcode = '22023';
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'limit must be between 1 and 100' using errcode = '22023';
  end if;

  if p_offset is null or p_offset < 0 then
    raise exception 'offset must be non-negative' using errcode = '22023';
  end if;

  query_location := extensions.st_setsrid(
    extensions.st_makepoint(p_longitude, p_latitude),
    4326
  )::extensions.geography;

  return query
  select
    restaurant.id,
    restaurant.name,
    restaurant.address,
    restaurant.latitude,
    restaurant.longitude,
    restaurant.category,
    restaurant.place_provider,
    restaurant.place_provider_id,
    restaurant.image_url,
    restaurant.phone,
    restaurant.road_address,
    restaurant.metadata,
    restaurant.created_at,
    restaurant.updated_at,
    extensions.st_distance(restaurant.location, query_location)::double precision
  from public.restaurants as restaurant
  where extensions.st_dwithin(
      restaurant.location,
      query_location,
      p_radius_meters
    )
    and (p_category is null or restaurant.category = p_category)
    and (p_place_provider is null or restaurant.place_provider = p_place_provider)
    and (p_place_provider_id is null or restaurant.place_provider_id = p_place_provider_id)
  order by
    restaurant.location operator(extensions.<->) query_location,
    restaurant.id asc
  limit p_limit
  offset p_offset;
end;
$$;

revoke all on function public.nearby_restaurants(
  double precision,
  double precision,
  double precision,
  text,
  text,
  text,
  integer,
  integer
) from public, anon, authenticated;

grant execute on function public.nearby_restaurants(
  double precision,
  double precision,
  double precision,
  text,
  text,
  text,
  integer,
  integer
) to service_role;

comment on column public.restaurants.location is
  'Server-side spatial index derived from numeric longitude/latitude; do not expose in API responses.';

comment on function public.nearby_restaurants(
  double precision,
  double precision,
  double precision,
  text,
  text,
  text,
  integer,
  integer
) is
  'Service-role-only restaurant radius search. Distance is returned in meters.';

commit;
