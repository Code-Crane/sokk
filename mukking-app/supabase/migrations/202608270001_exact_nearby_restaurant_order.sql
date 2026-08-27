-- Make nearby restaurant pagination follow the exact distance returned by the RPC.
-- ST_DWithin remains the indexed radius filter; exact distance is calculated once
-- for the filtered candidates before deterministic ordering and pagination.

begin;

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
  with candidates as materialized (
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
      extensions.st_distance(
        restaurant.location,
        query_location
      )::double precision as distance_meters
    from public.restaurants as restaurant
    where extensions.st_dwithin(
        restaurant.location,
        query_location,
        p_radius_meters
      )
      and (p_category is null or restaurant.category = p_category)
      and (p_place_provider is null or restaurant.place_provider = p_place_provider)
      and (p_place_provider_id is null or restaurant.place_provider_id = p_place_provider_id)
  )
  select
    candidate.id,
    candidate.name,
    candidate.address,
    candidate.latitude,
    candidate.longitude,
    candidate.category,
    candidate.place_provider,
    candidate.place_provider_id,
    candidate.image_url,
    candidate.phone,
    candidate.road_address,
    candidate.metadata,
    candidate.created_at,
    candidate.updated_at,
    candidate.distance_meters
  from candidates as candidate
  order by
    candidate.distance_meters asc,
    candidate.id asc
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
  'Service-role-only restaurant radius search, exactly ordered by returned distance and restaurant id before pagination.';

commit;
