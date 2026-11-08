-- 선택한 날짜 앞뒤 며칠의 날짜별 최저가
create or replace function public.get_price_range(p_origin text, p_destination text, p_start date, p_end date,
                                                  p_airlines text[] default null, p_cabin int default 0)
returns table (day date, price integer)
language sql stable security definer set search_path = public as $$
  select distinct on (s.departure_date) s.departure_date, s.price
  from price_snapshots s
  where s.origin = p_origin and s.destination = p_destination and s.cabin = p_cabin
    and s.departure_date between p_start and p_end
    and s.fetched_on >= ((now() at time zone 'Asia/Seoul')::date - 7)
    and (p_airlines is null or s.airline = any(p_airlines))
  order by s.departure_date, s.fetched_on desc, s.price asc;
$$;

revoke all on function public.get_price_range(text, text, date, date, text[], int) from public, anon, authenticated;
grant execute on function public.get_price_range(text, text, date, date, text[], int) to service_role;
