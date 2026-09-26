-- Restaurants à proximité (données publiques OpenStreetMap, licence ODbL), lus
-- directement par la page. Remplis par un scrape Overpass (amenity=restaurant,
-- fast_food, food_court) ; `dist` = distance en mètres depuis le point de départ.
create table if not exists public.restos (
  lieu     text not null check (lieu in ('la','mtr')),
  osm_id   text not null,
  name     text not null,
  cuisine  text not null default '',
  lat      double precision not null,
  lon      double precision not null,
  dist     integer not null,
  addr     text not null default '',
  primary key (lieu, osm_id)
);
create index if not exists restos_lieu_dist_idx on public.restos (lieu, dist);
alter table public.restos enable row level security;
revoke all on public.restos from anon, authenticated;
grant select on public.restos to anon;
drop policy if exists "restos lisibles par tous" on public.restos;
create policy "restos lisibles par tous" on public.restos for select to anon using (true);
