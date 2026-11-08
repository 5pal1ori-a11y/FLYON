-- 모든 노선 조회 지원: 처음 조회하는 노선을 즉시 수집하고, 달력/항공사 필터를 지원한다.
-- 실행: npx supabase db push --remote

-- 같은 노선을 너무 자주 즉시 수집하지 않도록 시도 기록을 남긴다
create table if not exists public.route_attempts (
  origin          text not null,
  destination     text not null,
  last_attempt_at timestamptz not null default now(),
  primary key (origin, destination)
);
alter table public.route_attempts enable row level security;

-- 쿨다운이 지났을 때만 true (원자적)
create or replace function public.try_claim_route_fetch(p_origin text, p_destination text, p_cooldown_minutes int)
returns boolean
language plpgsql security definer set search_path = public as $$
declare claimed boolean;
begin
  insert into route_attempts (origin, destination, last_attempt_at)
  values (p_origin, p_destination, now())
  on conflict (origin, destination) do update set last_attempt_at = now()
    where route_attempts.last_attempt_at < now() - make_interval(mins => p_cooldown_minutes)
  returning true into claimed;
  return coalesce(claimed, false);
end;
$$;

-- 추적 노선이 상한 미만일 때만 추가
create or replace function public.add_route_if_room(p_origin text, p_destination text, p_max int)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from routes) < p_max then
    insert into routes (origin, destination) values (p_origin, p_destination) on conflict do nothing;
  end if;
end;
$$;

-- 항공사 필터가 추가된 조회 함수들 (기존 함수는 교체)
drop function if exists public.get_price_history(text, text, int);
drop function if exists public.get_price_quotes(text, text, date);

create or replace function public.get_price_history(p_origin text, p_destination text, p_days int, p_airlines text[] default null)
returns table (day date, price integer)
language sql stable security definer set search_path = public as $$
  select fetched_on, min(price)::integer
  from price_snapshots
  where origin = p_origin and destination = p_destination
    and fetched_on >= ((now() at time zone 'Asia/Seoul')::date - greatest(p_days, 1))
    and (p_airlines is null or airline = any(p_airlines))
  group by fetched_on
  order by fetched_on;
$$;

-- 출발일별 최저가: 최근 7일 안에 수집된 값 중 날짜별로 가장 최근 수집분
create or replace function public.get_price_calendar(p_origin text, p_destination text, p_month date, p_airlines text[] default null)
returns table (day date, price integer)
language sql stable security definer set search_path = public as $$
  select distinct on (s.departure_date) s.departure_date, s.price
  from price_snapshots s
  where s.origin = p_origin and s.destination = p_destination
    and s.departure_date >= date_trunc('month', p_month)::date
    and s.departure_date <  (date_trunc('month', p_month) + interval '1 month')::date
    and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 7)
    and (p_airlines is null or s.airline = any(p_airlines))
  order by s.departure_date, s.fetched_on desc, s.price asc;
$$;

-- 항공사별 최저가: 최근 7일 안의 가장 최근 수집분
create or replace function public.get_price_quotes(p_origin text, p_destination text, p_month date, p_airlines text[] default null)
returns table (airline text, price integer, departure_date date, transfers smallint)
language sql stable security definer set search_path = public as $$
  select distinct on (s.airline) s.airline, s.price, s.departure_date, s.transfers
  from price_snapshots s
  where s.origin = p_origin and s.destination = p_destination
    and s.departure_date >= date_trunc('month', p_month)::date
    and s.departure_date <  (date_trunc('month', p_month) + interval '1 month')::date
    and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 7)
    and (p_airlines is null or s.airline = any(p_airlines))
  order by s.airline, s.fetched_on desc, s.price asc;
$$;

-- 서버(service role)만 호출한다
revoke all on function public.try_claim_route_fetch(text, text, int) from public, anon, authenticated;
revoke all on function public.add_route_if_room(text, text, int) from public, anon, authenticated;
revoke all on function public.get_price_history(text, text, int, text[]) from public, anon, authenticated;
revoke all on function public.get_price_calendar(text, text, date, text[]) from public, anon, authenticated;
revoke all on function public.get_price_quotes(text, text, date, text[]) from public, anon, authenticated;
grant execute on function public.try_claim_route_fetch(text, text, int) to service_role;
grant execute on function public.add_route_if_room(text, text, int) to service_role;
grant execute on function public.get_price_history(text, text, int, text[]) to service_role;
grant execute on function public.get_price_calendar(text, text, date, text[]) to service_role;
grant execute on function public.get_price_quotes(text, text, date, text[]) to service_role;
