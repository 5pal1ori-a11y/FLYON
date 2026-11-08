-- Duffel 실시간 조회 결과 캐시 (같은 노선·날짜는 잠시 재사용해 비용을 줄인다)
create table if not exists public.live_cache (
  key        text primary key,          -- ORIGIN-DEST-YYYY-MM-DD-cabin
  payload    jsonb not null,
  fetched_at timestamptz not null default now()
);
create index if not exists live_cache_fetched on public.live_cache (fetched_at);
alter table public.live_cache enable row level security;
