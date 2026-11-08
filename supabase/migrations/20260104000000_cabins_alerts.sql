-- 좌석 등급(일반/비즈니스/일등석), 가격 알림, 수집 노선 확대
-- 실행: npx supabase db push --remote  (또는 GitHub Actions "Deploy backend")

-- 1) 좌석 등급
alter table public.price_snapshots add column if not exists cabin smallint not null default 0; -- 0 일반, 1 비즈니스, 2 일등석
drop index if exists public.price_snapshots_dedup;
create unique index if not exists price_snapshots_dedup_cabin
  on public.price_snapshots (origin, destination, departure_date, airline, flight_number, price, fetched_on, cabin);

alter table public.route_attempts add column if not exists cabin smallint not null default 0;
alter table public.route_attempts drop constraint if exists route_attempts_pkey;
alter table public.route_attempts add primary key (origin, destination, cabin);

-- 2) 조회 함수에 좌석 등급 추가 (기존 함수 교체)
drop function if exists public.try_claim_route_fetch(text, text, int);
drop function if exists public.get_price_history(text, text, int, text[]);
drop function if exists public.get_price_calendar(text, text, date, text[]);
drop function if exists public.get_price_quotes(text, text, date, text[]);
drop function if exists public.get_price_flights(text, text, date, text[]);
drop function if exists public.get_deals(text, int);

create or replace function public.try_claim_route_fetch(p_origin text, p_destination text, p_cooldown_minutes int, p_cabin int default 0)
returns boolean
language plpgsql security definer set search_path = public as $$
declare claimed boolean;
begin
  insert into route_attempts (origin, destination, cabin, last_attempt_at)
  values (p_origin, p_destination, p_cabin, now())
  on conflict (origin, destination, cabin) do update set last_attempt_at = now()
    where route_attempts.last_attempt_at < now() - make_interval(mins => p_cooldown_minutes)
  returning true into claimed;
  return coalesce(claimed, false);
end;
$$;

create or replace function public.get_price_history(p_origin text, p_destination text, p_days int, p_airlines text[] default null, p_cabin int default 0)
returns table (day date, price integer)
language sql stable security definer set search_path = public as $$
  select fetched_on, min(price)::integer
  from price_snapshots
  where origin = p_origin and destination = p_destination and cabin = p_cabin
    and fetched_on >= ((now() at time zone 'Asia/Seoul')::date - greatest(p_days, 1))
    and (p_airlines is null or airline = any(p_airlines))
  group by fetched_on
  order by fetched_on;
$$;

create or replace function public.get_price_calendar(p_origin text, p_destination text, p_month date, p_airlines text[] default null, p_cabin int default 0)
returns table (day date, price integer)
language sql stable security definer set search_path = public as $$
  select distinct on (s.departure_date) s.departure_date, s.price
  from price_snapshots s
  where s.origin = p_origin and s.destination = p_destination and s.cabin = p_cabin
    and s.departure_date >= date_trunc('month', p_month)::date
    and s.departure_date <  (date_trunc('month', p_month) + interval '1 month')::date
    and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 7)
    and (p_airlines is null or s.airline = any(p_airlines))
  order by s.departure_date, s.fetched_on desc, s.price asc;
$$;

create or replace function public.get_price_quotes(p_origin text, p_destination text, p_month date, p_airlines text[] default null, p_cabin int default 0)
returns table (airline text, price integer, departure_date date, transfers smallint)
language sql stable security definer set search_path = public as $$
  select distinct on (s.airline) s.airline, s.price, s.departure_date, s.transfers
  from price_snapshots s
  where s.origin = p_origin and s.destination = p_destination and s.cabin = p_cabin
    and s.departure_date >= date_trunc('month', p_month)::date
    and s.departure_date <  (date_trunc('month', p_month) + interval '1 month')::date
    and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 7)
    and (p_airlines is null or s.airline = any(p_airlines))
  order by s.airline, s.fetched_on desc, s.price asc;
$$;

create or replace function public.get_price_flights(p_origin text, p_destination text, p_date date, p_airlines text[] default null, p_cabin int default 0)
returns table (airline text, flight_number text, departure_time text, duration_min integer, price integer, transfers smallint)
language sql stable security definer set search_path = public as $$
  select t.airline, t.flight_number, t.departure_time, t.duration_min, t.price, t.transfers
  from (
    select distinct on (s.airline, s.flight_number)
           s.airline, s.flight_number, s.departure_time, s.duration_min, s.price, s.transfers
    from price_snapshots s
    where s.origin = p_origin and s.destination = p_destination and s.cabin = p_cabin
      and s.departure_date = p_date
      and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 7)
      and (p_airlines is null or s.airline = any(p_airlines))
    order by s.airline, s.flight_number, s.fetched_on desc, s.price asc
  ) t
  order by t.price asc;
$$;

create or replace function public.get_deals(p_origin text, p_limit int default 12, p_cabin int default 0)
returns table (destination text, lowest integer, average integer, lowest_date date)
language sql stable security definer set search_path = public as $$
  with latest as (
    select distinct on (s.destination, s.departure_date)
           s.destination, s.departure_date, s.price
    from price_snapshots s
    where s.origin = p_origin and s.cabin = p_cabin
      and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 7)
      and s.departure_date >= ((now() at time zone 'Asia/Seoul')::date)
    order by s.destination, s.departure_date, s.fetched_on desc, s.price asc
  ), agg as (
    select l.destination, min(l.price) as lowest, avg(l.price)::integer as average
    from latest l
    group by l.destination
    having count(*) >= 3
  )
  select a.destination, a.lowest::integer, a.average,
         (select l.departure_date from latest l
           where l.destination = a.destination and l.price = a.lowest
           order by l.departure_date limit 1) as lowest_date
  from agg a
  order by (a.average - a.lowest)::float / nullif(a.average, 0) desc nulls last
  limit greatest(p_limit, 1);
$$;

-- 3) 가격 알림 (기기 푸시 토큰 기준, 개인 식별 정보는 저장하지 않는다)
create table if not exists public.alerts (
  id                  uuid primary key default gen_random_uuid(),
  device_token        text not null check (device_token ~ '^[0-9a-f]{64,200}$'),
  origin              text not null check (origin ~ '^[A-Z]{3}$'),
  destination         text not null check (destination ~ '^[A-Z]{3}$'),
  depart_date         date,
  depart_month        date,
  airlines            text[],
  cabin               smallint not null default 0,
  target_price        integer not null check (target_price > 0),
  baseline_price      integer,
  active              boolean not null default true,
  last_notified_at    timestamptz,
  last_notified_price integer,
  created_at          timestamptz not null default now()
);
create index if not exists alerts_device on public.alerts (device_token);
create index if not exists alerts_active on public.alerts (active);
alter table public.alerts enable row level security;

-- 지난 날짜의 알림은 끈다
create or replace function public.expire_alerts()
returns void
language sql security definer set search_path = public as $$
  update alerts set active = false
  where active and (
    (depart_date is not null and depart_date < (now() at time zone 'Asia/Seoul')::date)
    or (depart_month is not null and (depart_month + interval '1 month')::date <= (now() at time zone 'Asia/Seoul')::date)
  );
$$;

-- 알림 조건의 현재 최저가 (최근 2일 수집분 기준)
create or replace function public.alert_current_prices(p_device_token text default null)
returns table (id uuid, device_token text, origin text, destination text, depart_date date, depart_month date,
               airlines text[], cabin smallint, target_price integer, baseline_price integer, active boolean,
               last_notified_at timestamptz, last_notified_price integer, current_price integer, found_date date)
language sql stable security definer set search_path = public as $$
  select a.id, a.device_token, a.origin, a.destination, a.depart_date, a.depart_month, a.airlines, a.cabin,
         a.target_price, a.baseline_price, a.active, a.last_notified_at, a.last_notified_price,
         m.price, m.departure_date
  from alerts a
  left join lateral (
    select s.price, s.departure_date
    from price_snapshots s
    where s.origin = a.origin and s.destination = a.destination and s.cabin = a.cabin
      and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 1)
      and s.departure_date >= ((now() at time zone 'Asia/Seoul')::date)
      and (a.depart_date is null or s.departure_date = a.depart_date)
      and (a.depart_month is null or (s.departure_date >= a.depart_month
                                      and s.departure_date < (a.depart_month + interval '1 month')::date))
      and (a.airlines is null or s.airline = any(a.airlines))
    order by s.price asc
    limit 1
  ) m on true
  where p_device_token is null or a.device_token = p_device_token
  order by a.created_at desc;
$$;

revoke all on function public.try_claim_route_fetch(text, text, int, int) from public, anon, authenticated;
revoke all on function public.get_price_history(text, text, int, text[], int) from public, anon, authenticated;
revoke all on function public.get_price_calendar(text, text, date, text[], int) from public, anon, authenticated;
revoke all on function public.get_price_quotes(text, text, date, text[], int) from public, anon, authenticated;
revoke all on function public.get_price_flights(text, text, date, text[], int) from public, anon, authenticated;
revoke all on function public.get_deals(text, int, int) from public, anon, authenticated;
revoke all on function public.expire_alerts() from public, anon, authenticated;
revoke all on function public.alert_current_prices(text) from public, anon, authenticated;
grant execute on function public.try_claim_route_fetch(text, text, int, int) to service_role;
grant execute on function public.get_price_history(text, text, int, text[], int) to service_role;
grant execute on function public.get_price_calendar(text, text, date, text[], int) to service_role;
grant execute on function public.get_price_quotes(text, text, date, text[], int) to service_role;
grant execute on function public.get_price_flights(text, text, date, text[], int) to service_role;
grant execute on function public.get_deals(text, int, int) to service_role;
grant execute on function public.expire_alerts() to service_role;
grant execute on function public.alert_current_prices(text) to service_role;

-- 4) 기본 수집 노선 확대
insert into public.routes (origin, destination) values
  ('ICN','HND'), ('ICN','CTS'), ('ICN','OKA'), ('ICN','NGO'), ('ICN','KMJ'),
  ('ICN','HKG'), ('ICN','MFM'), ('ICN','SIN'), ('ICN','KUL'), ('ICN','SGN'), ('ICN','HAN'),
  ('ICN','CXR'), ('ICN','PQC'), ('ICN','MNL'), ('ICN','CEB'), ('ICN','BKI'), ('ICN','DPS'),
  ('ICN','HKT'), ('ICN','CNX'), ('ICN','PVG'), ('ICN','PEK'), ('ICN','TAO'),
  ('ICN','GUM'), ('ICN','SPN'), ('ICN','HNL'), ('ICN','LAX'), ('ICN','SFO'), ('ICN','JFK'),
  ('ICN','CDG'), ('ICN','LHR'), ('ICN','FRA'), ('ICN','FCO'), ('ICN','BCN'), ('ICN','IST'),
  ('ICN','SYD'), ('ICN','DXB'), ('ICN','ULN'),
  ('GMP','HND'), ('GMP','KIX'), ('GMP','TSA'), ('PUS','NRT'), ('PUS','KIX'), ('PUS','FUK'),
  ('PUS','BKK'), ('PUS','DAD'), ('TAE','CJU'), ('CJJ','CJU'), ('KWJ','CJU'),
  ('CJU','GMP'), ('CJU','ICN'), ('CJU','PUS')
on conflict do nothing;
