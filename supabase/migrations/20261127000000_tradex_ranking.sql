-- TRADEX 시즌 랭킹 (FLYON과 같은 프로젝트를 쓰되 tradex_ 접두사로 분리)
-- 앱은 직접 접근하지 않고 Edge Function(tradex-ranking, service role)만 읽고 쓴다 → RLS 켜고 정책 없음

-- 랭킹 참가자: Apple 계정 식별값(sub)은 저장하지 않고 해시만 저장
create table if not exists public.tradex_players (
  player_id     text primary key,                 -- sha256("tradex:" || apple sub)
  nickname      text not null unique check (char_length(nickname) between 2 and 12),
  session_hash  text not null,                    -- 앱이 가진 세션 토큰의 sha256
  age_confirmed boolean not null default false,   -- 만 14세 이상 확인
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- 시즌별 AP (한 분기 = 한 시즌, 예: 2026-Q4)
create table if not exists public.tradex_season_scores (
  season     text not null check (season ~ '^[0-9]{4}-Q[1-4]$'),
  player_id  text not null references public.tradex_players(player_id) on delete cascade,
  ap         integer not null default 0 check (ap >= 0),
  updated_at timestamptz not null default now(),
  primary key (season, player_id)
);
create index if not exists tradex_season_scores_rank on public.tradex_season_scores (season, ap desc, updated_at asc);

-- 하루 AP 상한(150) 확인용
create table if not exists public.tradex_ap_daily (
  season    text not null,
  player_id text not null references public.tradex_players(player_id) on delete cascade,
  day       date not null,
  gained    integer not null default 0 check (gained >= 0),
  primary key (season, player_id, day)
);

alter table public.tradex_players enable row level security;
alter table public.tradex_season_scores enable row level security;
alter table public.tradex_ap_daily enable row level security;
