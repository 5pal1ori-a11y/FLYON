-- FLYON 가격 수집 DB
-- 실행: npx supabase db push

-- 수집할 노선 (방향이 있는 노선: ICN->CJU 와 CJU->ICN 은 별개)
create table if not exists public.routes (
  origin      text not null check (origin ~ '^[A-Z]{3}$'),
  destination text not null check (destination ~ '^[A-Z]{3}$'),
  active      boolean not null default true,
  primary key (origin, destination)
);

-- 수집된 가격 스냅샷 (덮어쓰지 않고 쌓는다)
create table if not exists public.price_snapshots (
  id             bigserial primary key,
  origin         text not null,
  destination    text not null,
  departure_date date not null,
  airline        text not null default '',
  flight_number  text not null default '',
  price          integer not null check (price > 0),
  currency       text not null default 'KRW',
  transfers      smallint not null default 0,
  fetched_on     date not null default ((now() at time zone 'Asia/Seoul')::date),
  fetched_at     timestamptz not null default now(),
  source         text not null default 'travelpayouts'
);

-- 같은 날 같은 항공편·가격이 중복 저장되는 것을 막는다
create unique index if not exists price_snapshots_dedup
  on public.price_snapshots (origin, destination, departure_date, airline, flight_number, price, fetched_on);

create index if not exists price_snapshots_route_day
  on public.price_snapshots (origin, destination, fetched_on);

-- RLS: 정책을 하나도 만들지 않으므로 anon 키로는 테이블을 직접 읽거나 쓸 수 없다.
-- 앱은 Edge Function(prices)을 통해서만 읽고, 쓰기는 Edge Function(collect)만 service role로 한다.
alter table public.routes enable row level security;
alter table public.price_snapshots enable row level security;

-- 가격 흐름: 수집일별로 그 노선에서 발견된 최저가
create or replace function public.get_price_history(p_origin text, p_destination text, p_days int)
returns table (day date, price integer)
language sql stable security definer set search_path = public as $$
  select fetched_on, min(price)::integer
  from price_snapshots
  where origin = p_origin and destination = p_destination
    and fetched_on >= ((now() at time zone 'Asia/Seoul')::date - greatest(p_days, 1))
  group by fetched_on
  order by fetched_on;
$$;

-- 항공사별 최저가: 가장 최근 수집일 기준, 해당 월 출발편
create or replace function public.get_price_quotes(p_origin text, p_destination text, p_month date)
returns table (airline text, price integer, departure_date date, transfers smallint)
language sql stable security definer set search_path = public as $$
  select distinct on (s.airline) s.airline, s.price, s.departure_date, s.transfers
  from price_snapshots s
  where s.origin = p_origin and s.destination = p_destination
    and s.departure_date >= date_trunc('month', p_month)::date
    and s.departure_date <  (date_trunc('month', p_month) + interval '1 month')::date
    and s.fetched_on = (
      select max(fetched_on) from price_snapshots
      where origin = p_origin and destination = p_destination
    )
  order by s.airline, s.price;
$$;

-- 이 함수들은 서버(service role)만 호출한다
revoke all on function public.get_price_history(text, text, int) from public, anon, authenticated;
revoke all on function public.get_price_quotes(text, text, date) from public, anon, authenticated;
grant execute on function public.get_price_history(text, text, int) to service_role;
grant execute on function public.get_price_quotes(text, text, date) to service_role;

-- 초기 노선 (필요에 따라 수정)
insert into public.routes (origin, destination) values
  ('ICN','CJU'), ('GMP','CJU'), ('PUS','CJU'),
  ('ICN','NRT'), ('ICN','KIX'), ('ICN','FUK'),
  ('ICN','BKK'), ('ICN','DAD'), ('ICN','TPE')
on conflict do nothing;
