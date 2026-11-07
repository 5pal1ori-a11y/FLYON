// 가격 수집 함수: Travelpayouts Data API -> price_snapshots
// 배포: npx supabase functions deploy collect --no-verify-jwt   (자체 비밀 헤더로 보호)
// 필요한 시크릿: TRAVELPAYOUTS_TOKEN, COLLECT_SECRET
import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const MONTHS_AHEAD = 3;     // 앞으로 몇 개월치를 수집할지
const CONCURRENCY = 3;      // 동시 호출 수 (호출 제한 보호)

type Job = { origin: string; destination: string; month: string };

function monthString(offset: number): string {
  const now = new Date();
  const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + offset, 1));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

async function fetchMonth(job: Job, token: string) {
  const url = new URL("https://api.travelpayouts.com/aviasales/v3/prices_for_dates");
  url.searchParams.set("origin", job.origin);
  url.searchParams.set("destination", job.destination);
  url.searchParams.set("departure_at", job.month);
  url.searchParams.set("one_way", "true");
  url.searchParams.set("currency", "krw");
  url.searchParams.set("sorting", "price");
  url.searchParams.set("limit", "100");
  url.searchParams.set("token", token);

  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`); // URL(토큰 포함)은 로그에 남기지 않는다
  const body = await res.json();
  return (body?.data ?? []) as Array<Record<string, unknown>>;
}

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
        const items = await fetchMonth(job, token!);
        const rows = items
          .filter((i) => typeof i.price === "number" && typeof i.departure_at === "string")
          .map((i) => ({
            origin: job.origin,
            destination: job.destination,
            departure_date: String(i.departure_at).slice(0, 10),
            airline: String(i.airline ?? ""),
            flight_number: String(i.flight_number ?? ""),
            price: Math.round(i.price as number),
            transfers: Number(i.transfers ?? 0),
          }));
        if (rows.length === 0) { empty++; continue; }
        const { error: insErr } = await supabase
          .from("price_snapshots")
          .upsert(rows, {
            onConflict: "origin,destination,departure_date,airline,flight_number,price,fetched_on",
            ignoreDuplicates: true,
          });
        if (insErr) throw new Error(insErr.message);
        inserted += rows.length;
      } catch (e) {
        failed++;
        console.error(`${job.origin}-${job.destination} ${job.month}:`, (e as Error).message);
      }
      await new Promise((r) => setTimeout(r, 250));
    }
  }

  await Promise.all(Array.from({ length: CONCURRENCY }, worker));

  return Response.json({ inserted, empty, failed });
});
