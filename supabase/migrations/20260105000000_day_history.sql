-- 선택한 출발일 하루의 가격 변화, 그리고 항공사 정보가 없는 기록은 항공편 목록에서 제외
-- 실행: GitHub Actions "Deploy backend"

-- 특정 출발일의 수집일별 최저가
create or replace function public.get_day_history(p_origin text, p_destination text, p_date date, p_airlines text[] default null, p_cabin int default 0)
returns table (day date, price integer)
language sql stable security definer set search_path = public as $$
  select fetched_on, min(price)::integer
  from price_snapshots
  where origin = p_origin and destination = p_destination and cabin = p_cabin
    and departure_date = p_date
    and fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 90)
    and (p_airlines is null or airline = any(p_airlines))
  group by fetched_on
  order by fetched_on;
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
      and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 7)
      and (p_airlines is null or s.airline = any(p_airlines))
    order by s.airline, s.flight_number, s.fetched_on desc, s.price asc
  ) t
  order by t.price asc;
$$;

revoke all on function public.get_day_history(text, text, date, text[], int) from public, anon, authenticated;
grant execute on function public.get_day_history(text, text, date, text[], int) to service_role;
