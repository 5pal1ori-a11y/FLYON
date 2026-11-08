-- 노선 운항 스케줄 캐시 (AirLabs routes). 스케줄은 자주 바뀌지 않아 며칠씩 재사용한다.
create table if not exists public.route_schedules (
  origin      text not null,
  destination text not null,
  payload     jsonb not null,
  fetched_at  timestamptz not null default now(),
  primary key (origin, destination)
);
alter table public.route_schedules enable row level security;
