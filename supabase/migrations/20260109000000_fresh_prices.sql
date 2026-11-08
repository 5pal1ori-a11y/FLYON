-- 오래된 가격 걸러내기: 날짜별·항공편·특가 화면은 최근 이틀(오늘·어제, 한국 시간) 안에 확인된 가격만 쓴다.
-- 가격 기록(그래프)은 그대로 전체를 쓴다.

create or replace function public.get_price_calendar(p_origin text, p_destination text, p_month date, p_airlines text[] default null, p_cabin int default 0)
returns table (day date, price integer)
language sql stable security definer set search_path = public as $$
  select distinct on (s.departure_date) s.departure_date, s.price
  from price_snapshots s
  where s.origin = p_origin and s.destination = p_destination and s.cabin = p_cabin
    and s.departure_date >= date_trunc('month', p_month)::date
    and s.departure_date <  (date_trunc('month', p_month) + interval '1 month')::date
    and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 1)
    and (p_airlines is null or s.airline = any(p_airlines))
  order by s.departure_date, s.fetched_on desc, s.price asc;
$$;

create or replace function public.get_price_range(p_origin text, p_destination text, p_start date, p_end date,
                                                  p_airlines text[] default null, p_cabin int default 0)
returns table (day date, price integer)
language sql stable security definer set search_path = public as $$
  select distinct on (s.departure_date) s.departure_date, s.price
  from price_snapshots s
  where s.origin = p_origin and s.destination = p_destination and s.cabin = p_cabin
    and s.departure_date between p_start and p_end
    and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 1)
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
    and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 1)
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
      and (p_cabin <> 0 or s.airline <> '')
      and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 1)
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
      and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 1)
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
