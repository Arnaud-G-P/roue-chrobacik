-- Restaurants Uber Eats proches, avec lien direct vers leur page.
-- Source : pages publiques https://www.ubereats.com/<fr/>category/<ville>/<cuisine>
-- (autorisées par robots.txt), filtrées sur les codes postaux proches.
create table if not exists public.ue_stores (
  lieu     text not null check (lieu in ('la','mtr')),
  uuid     uuid not null,
  slug     text not null,
  name     text not null,
  addr     text not null default '',
  cats     text[] not null default '{}',   -- pages catégorie où le resto apparaît
  labels   text not null default '',       -- catégories affichées par Uber
  url      text not null,
  dist     integer,                        -- distance si retrouvé dans restos (OSM)
  primary key (lieu, uuid)
);
alter table public.ue_stores enable row level security;
revoke all on public.ue_stores from anon, authenticated;
grant select on public.ue_stores to anon;
drop policy if exists "ue lisibles par tous" on public.ue_stores;
create policy "ue lisibles par tous" on public.ue_stores for select to anon using (true);

-- Outils de scrape (schéma privé). Nécessite l'extension pg_net pendant le scrape :
--   create extension pg_net;
--   select scrape.launch('montrouge-idf', 'mtr');   -- 31 pages, attendre ~20 s
--   select * from scrape.ingest('{"la":["90024",...],"mtr":["92120",...]}');
--   delete from net._http_response; delete from scrape.req;   -- puis ville suivante
--   drop extension pg_net;
create schema if not exists scrape;
revoke all on schema scrape from public, anon, authenticated;
create table if not exists scrape.req (rid bigint primary key, lieu text not null, cat text not null, city text not null);

create or replace function scrape.launch(p_city text, p_lieu text) returns int
language plpgsql as $$
declare c text; n int := 0; rid bigint;
begin
  foreach c in array array['mexican','tex-mex','pizza','sushi','japanese','ramen','burger','poke','healthy','thai','korean-bbq','korean','mediterranean','lebanese','middle-eastern','shawarma','greek','turkish','kebabs','breakfast-and-brunch','persian','dim-sum','chinese','indian','pho','vietnamese','italian','pasta','wings','pollo','hotpot'] loop
    select net.http_get('https://www.ubereats.com/' || case when p_lieu = 'mtr' then 'fr/' else '' end || 'category/' || p_city || '/' || c,
      headers => '{"User-Agent":"Mozilla/5.0 (compatible; roue-chrobacik/1.0)"}'::jsonb, timeout_milliseconds => 60000) into rid;
    insert into scrape.req values (rid, p_lieu, c, p_city);
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function scrape.ingest(p_zips jsonb) returns table(o_lieu text, o_n bigint)
language plpgsql as $$
#variable_conflict use_column
begin
  with pages as (
    select q.lieu, q.cat, replace(replace(replace(r.content, E'\\u0022', '"'), E'\\u0026', '&'), E'\\u0027', '''') c
    from net._http_response r join scrape.req q on q.rid = r.id
    where r.status_code = 200
  ), chunks as (
    select p.lieu, p.cat, ch from pages p, regexp_split_to_table(p.c, '"slug":"') ch
  ), stores as (
    select lieu, cat,
      substring(ch from '^([a-z0-9\-]+)"') slug,
      substring(ch from '"title":"([^"]*)"') title,
      substring(ch from '"uuid":"([0-9a-f\-]{36})"') uid,
      substring(ch from '"categories":\[([^\]]*)\]') labels,
      substring(ch from '"formattedAddress":"([^"]*)"') addr
    from chunks
  ), near as (
    select s.* from stores s
    where coalesce(s.labels, '') !~* '(convenience|grocery|épicerie|supermarché)'
      and s.slug is not null and s.uid is not null and s.addr is not null and s.title is not null
      and exists (select 1 from jsonb_array_elements_text(p_zips -> s.lieu) z where s.addr ~ ('(^|[^0-9])' || z))
  )
  insert into public.ue_stores as u (lieu, uuid, slug, name, addr, cats, labels, url)
  select lieu, uid::uuid, slug, left(trim(title), 100), left(addr, 160), array_agg(distinct cat),
    left(replace(min(labels), '"', ''), 200),
    'https://www.ubereats.com/' || case when lieu = 'mtr' then 'fr/' else '' end || 'store/' || slug || '/' ||
      rtrim(translate(encode(decode(replace(uid, '-', ''), 'hex'), 'base64'), '+/', '-_'), '=')
  from near group by lieu, uid, slug, title, addr
  on conflict on constraint ue_stores_pkey do update
    set cats = (select array_agg(distinct x) from unnest(u.cats || excluded.cats) x),
        name = excluded.name, addr = excluded.addr, url = excluded.url;
  return query select s.lieu, count(*) from public.ue_stores s group by s.lieu;
end $$;
revoke all on function scrape.launch(text,text) from public, anon, authenticated;
revoke all on function scrape.ingest(jsonb) from public, anon, authenticated;
