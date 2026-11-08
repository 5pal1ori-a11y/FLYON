-- 항공권(편명) 단위 가격 기록과 알림
-- 실행: GitHub Actions "Deploy backend"

alter table public.alerts add column if not exists flight_number text;

-- 특정 날짜·특정 항공편의 수집일별 가격
create or replace function public.get_flight_history(p_origin text, p_destination text, p_date date,
                                                     p_airline text, p_flight_number text, p_cabin int default 0)
returns table (day date, price integer)
language sql stable security definer set search_path = public as $$
  select fetched_on, min(price)::integer
  from price_snapshots
  where origin = p_origin and destination = p_destination and cabin = p_cabin
    and departure_date = p_date
    and airline = p_airline
    and (coalesce(p_flight_number, '') = '' or flight_number = p_flight_number)
  group by fetched_on
  order by fetched_on;
$$;

-- 알림 조건의 현재 최저가 (편명 조건 추가)
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
      and (coalesce(a.flight_number, '') = '' or s.flight_number = a.flight_number)
    order by s.fetched_on desc, s.price asc
    limit 1
  ) m on true
  where p_device_token is null or a.device_token = p_device_token
  order by a.created_at desc;
$$;

-- 알림이 걸린 출발일 목록 (정기 수집 때 그 날짜를 따로 새로 조회한다)
create or replace function public.alert_dates()
returns table (origin text, destination text, depart_date date, cabin smallint)
language sql stable security definer set search_path = public as $$
  select distinct a.origin, a.destination, a.depart_date, a.cabin
  from alerts a
  where a.active and a.depart_date is not null
    and a.depart_date >= (now() at time zone 'Asia/Seoul')::date;
$$;

revoke all on function public.get_flight_history(text, text, date, text, text, int) from public, anon, authenticated;
revoke all on function public.alert_current_prices(text) from public, anon, authenticated;
revoke all on function public.alert_dates() from public, anon, authenticated;
grant execute on function public.get_flight_history(text, text, date, text, text, int) to service_role;
grant execute on function public.alert_current_prices(text) to service_role;
grant execute on function public.alert_dates() to service_role;
