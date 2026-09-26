-- Historique des repas choisis avec la roue, partagé entre Honey et Chrobáčik.
-- Même modèle de sécurité que wheel_lists : RLS sans policy, accès uniquement
-- via des fonctions SECURITY DEFINER qui vérifient le code secret.

create table if not exists public.wheel_history (
  id        bigint generated always as identity primary key,
  eaten_at  timestamptz not null default now(),
  mode      text not null check (mode in ('sortir','maison','resto')),
  lieu      text not null check (lieu in ('la','mtr')),
  name      text not null check (char_length(name) between 1 and 60),
  emoji     text not null default '' check (char_length(emoji) <= 8),
  resto     text check (char_length(resto) <= 80),
  who       text check (char_length(who) <= 20)
);
create index if not exists wheel_history_eaten_at_idx on public.wheel_history (eaten_at desc);

alter table public.wheel_history enable row level security;
revoke all on public.wheel_history from anon, authenticated;

create or replace function public.log_meal(
  p_code text, p_mode text, p_lieu text, p_name text,
  p_emoji text default '', p_resto text default null, p_who text default null
) returns jsonb
language plpgsql security definer set search_path to ''
as $$
declare v_row public.wheel_history;
begin
  if not public.wheel_check(p_code) then
    raise exception 'invalid code' using errcode = '28000';
  end if;
  insert into public.wheel_history (mode, lieu, name, emoji, resto, who)
  values (p_mode, p_lieu, left(trim(p_name), 60), left(coalesce(p_emoji, ''), 8),
          left(nullif(trim(p_resto), ''), 80), left(nullif(trim(p_who), ''), 20))
  returning * into v_row;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.get_history(p_code text, p_limit int default 500)
returns jsonb
language plpgsql stable security definer set search_path to ''
as $$
begin
  if not public.wheel_check(p_code) then
    raise exception 'invalid code' using errcode = '28000';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(h) order by h.eaten_at desc)
    from (select * from public.wheel_history
          order by eaten_at desc limit least(greatest(p_limit, 1), 2000)) h
  ), '[]'::jsonb);
end;
$$;

create or replace function public.delete_meal(p_code text, p_id bigint)
returns boolean
language plpgsql security definer set search_path to ''
as $$
begin
  if not public.wheel_check(p_code) then
    raise exception 'invalid code' using errcode = '28000';
  end if;
  delete from public.wheel_history where id = p_id;
  return found;
end;
$$;

revoke all on function public.log_meal(text,text,text,text,text,text,text) from public;
revoke all on function public.get_history(text,int) from public;
revoke all on function public.delete_meal(text,bigint) from public;
grant execute on function public.log_meal(text,text,text,text,text,text,text) to anon;
grant execute on function public.get_history(text,int) to anon;
grant execute on function public.delete_meal(text,bigint) to anon;

-- Pas de connexion utilisateur dans l'app : seul anon (avec le code) en a besoin.
revoke execute on function public.log_meal(text,text,text,text,text,text,text) from authenticated;
revoke execute on function public.get_history(text,int) from authenticated;
revoke execute on function public.delete_meal(text,bigint) from authenticated;
