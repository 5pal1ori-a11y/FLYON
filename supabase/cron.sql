-- Supabase 대시보드 > SQL Editor 에서 한 번 실행한다. (마이그레이션에 넣지 않는 이유: 비밀값이 들어 있음)
-- 실행 전에 <PROJECT_REF> 와 <COLLECT_SECRET> 을 실제 값으로 바꾼다.
-- 이 파일을 GitHub 등에 올릴 때는 실제 값을 채우지 않은 상태로 둔다.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 6시간마다 수집 (KST 기준 02, 08, 14, 20시 = UTC 17, 23, 5, 11시)
select cron.schedule(
  'flyon-collect-prices',
  '0 5,11,17,23 * * *',
  $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/collect',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-collect-secret', '<COLLECT_SECRET>'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);

-- 180일이 지난 데이터 정리 (매일 UTC 20시)
select cron.schedule(
  'flyon-prune-snapshots',
  '0 20 * * *',
  $$ delete from public.price_snapshots where fetched_on < current_date - 180; $$
);
