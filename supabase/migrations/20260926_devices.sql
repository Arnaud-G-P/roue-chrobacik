-- Appareils qui utilisent la roue partagée (identifiant anonyme généré par la page).
create table if not exists public.wheel_devices (
  device_id  text primary key check (char_length(device_id) between 8 and 64),
  platform   text not null default '' check (char_length(platform) <= 30),
  first_seen timestamptz not null default now(),
  last_seen  timestamptz not null default now(),
  visits     integer not null default 1
);
alter table public.wheel_devices enable row level security;
revoke all on public.wheel_devices from anon, authenticated;

create or replace function public.ping_device(p_code text, p_device text, p_platform text default '')
returns void
language plpgsql security definer set search_path to ''
as $$
begin
  if not public.wheel_check(p_code) then
    raise exception 'invalid code' using errcode = '28000';
  end if;
  insert into public.wheel_devices (device_id, platform)
  values (left(p_device, 64), left(coalesce(p_platform, ''), 30))
  on conflict (device_id) do update
    set last_seen = now(), platform = excluded.platform,
        visits = public.wheel_devices.visits + 1;
end;
$$;

create or replace function public.get_devices(p_code text)
returns jsonb
language plpgsql stable security definer set search_path to ''
as $$
begin
  if not public.wheel_check(p_code) then
    raise exception 'invalid code' using errcode = '28000';
  end if;
  return coalesce((select jsonb_agg(to_jsonb(d) order by d.last_seen desc) from public.wheel_devices d), '[]'::jsonb);
end;
$$;

revoke all on function public.ping_device(text,text,text) from public, authenticated;
revoke all on function public.get_devices(text) from public, authenticated;
grant execute on function public.ping_device(text,text,text) to anon;
grant execute on function public.get_devices(text) to anon;
