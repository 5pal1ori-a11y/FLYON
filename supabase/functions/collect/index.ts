// 가격 수집 함수: Travelpayouts Data API -> price_snapshots
// 배포: npx supabase functions deploy collect --no-verify-jwt   (자체 비밀 헤더로 보호)
// 필요한 시크릿: TRAVELPAYOUTS_TOKEN, COLLECT_SECRET
import { createClient } from "npm:@supabase/supabase-js@2";
import { fetchMonth, MONTHS_AHEAD, monthString, SNAPSHOT_CONFLICT, toRows } from "../_shared/travelpayouts.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const CONCURRENCY = 5; // 동시 호출 수 (호출 제한 보호)

type Job = { origin: string; destination: string; month: string };

Deno.serve(async (req) => {
  if (req.headers.get("x-collect-secret") !== Deno.env.get("COLLECT_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const token = Deno.env.get("TRAVELPAYOUTS_TOKEN");
  if (!token) return new Response("missing token", { status: 500 });

  const { data: routes, error } = await supabase
    .from("routes").select("origin,destination").eq("active", true);
  if (error) return new Response(error.message, { status: 500 });

  const jobs: Job[] = [];
  for (const r of routes ?? []) {
    for (let m = 0; m < MONTHS_AHEAD; m++) {
      jobs.push({ origin: r.origin, destination: r.destination, month: monthString(m) });
    }
  }

  let inserted = 0;
  let failed = 0;
  let empty = 0;

  async function worker() {
    while (jobs.length > 0) {
      const job = jobs.shift()!;
      try {
        const rows = toRows(job.origin, job.destination, await fetchMonth(job.origin, job.destination, job.month, token!));
        if (rows.length === 0) { empty++; continue; }
        const { error: insErr } = await supabase
          .from("price_snapshots")
          .upsert(rows, { onConflict: SNAPSHOT_CONFLICT, ignoreDuplicates: true });
        if (insErr) throw new Error(insErr.message);
        inserted += rows.length;
      } catch (e) {
        failed++;
        console.error(`${job.origin}-${job.destination} ${job.month}:`, (e as Error).message);
      }
      await new Promise((r) => setTimeout(r, 200));
    }
  }

  await Promise.all(Array.from({ length: CONCURRENCY }, worker));

  return Response.json({ inserted, empty, failed });
});
