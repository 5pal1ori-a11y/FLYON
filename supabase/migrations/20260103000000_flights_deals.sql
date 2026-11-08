-- 항공편 목록(출발 시각·소요시간)과 출발지별 특가 목록
-- 실행: npx supabase db push --remote

alter table public.price_snapshots add column if not exists departure_time text;  -- 출발지 현지 시각 "HH:mm"
alter table public.price_snapshots add column if not exists duration_min integer;

-- 특정 출발일의 항공편: 최근 7일 안에 수집된 값 중 편명별 가장 최근 수집분
create or replace function public.get_price_flights(p_origin text, p_destination text, p_date date, p_airlines text[] default null)
returns table (airline text, flight_number text, departure_time text, duration_min integer, price integer, transfers smallint)
language sql stable security definer set search_path = public as $$
  select t.airline, t.flight_number, t.departure_time, t.duration_min, t.price, t.transfers
  from (
    select distinct on (s.airline, s.flight_number)
           s.airline, s.flight_number, s.departure_time, s.duration_min, s.price, s.transfers
    from price_snapshots s
    where s.origin = p_origin and s.destination = p_destination
      and s.departure_date = p_date
      and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 7)
      and (p_airlines is null or s.airline = any(p_airlines))
    order by s.airline, s.flight_number, s.fetched_on desc, s.price asc
  ) t
  order by t.price asc;
$$;

-- 출발지별 특가: 앞으로의 출발일 중 최저가가 평균보다 얼마나 낮은지 (데이터가 5일 이상인 노선만)
create or replace function public.get_deals(p_origin text, p_limit int default 12)
returns table (destination text, lowest integer, average integer, lowest_date date)
language sql stable security definer set search_path = public as $$
  with latest as (
    select distinct on (s.destination, s.departure_date)
           s.destination, s.departure_date, s.price
    from price_snapshots s
    where s.origin = p_origin
      and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 7)
      and s.departure_date >= ((now() at time zone 'Asia/Seoul')::date)
    order by s.destination, s.departure_date, s.fetched_on desc, s.price asc
  ), agg as (
    select l.destination, min(l.price) as lowest, avg(l.price)::integer as average
    from latest l
    group by l.destination
    having count(*) >= 5
  )
  select a.destination, a.lowest::integer, a.average,
         (select l.departure_date from latest l
           where l.destination = a.destination and l.price = a.lowest
           order by l.departure_date limit 1) as lowest_date
  from agg a
  where a.average > a.lowest
  order by (a.average - a.lowest)::float / a.average desc
  limit greatest(p_limit, 1);
$$;

revoke all on function public.get_price_flights(text, text, date, text[]) from public, anon, authenticated;
revoke all on function public.get_deals(text, int) from public, anon, authenticated;
grant execute on function public.get_price_flights(text, text, date, text[]) to service_role;
grant execute on function public.get_deals(text, int) to service_role;
