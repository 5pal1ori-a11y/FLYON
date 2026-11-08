// 가격 수집 + 가격 알림 발송
// 배포: supabase functions deploy collect --no-verify-jwt   (자체 비밀 헤더로 보호)
// 필요한 시크릿: TRAVELPAYOUTS_TOKEN, COLLECT_SECRET (+ 알림: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY)
import { createClient } from "npm:@supabase/supabase-js@2";
import { fetchLatestByClass, fetchMonth, MONTHS_AHEAD, monthString, SNAPSHOT_CONFLICT, toRows, toRowsLatest } from "../_shared/travelpayouts.ts";
import { apnsConfigured, sendPush } from "../_shared/apns.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const CONCURRENCY = 6;

type Job = { origin: string; destination: string; cabin: number; month?: string };

async function notifyAlerts() {
  if (!apnsConfigured()) return { notified: 0, skipped: "apns not configured" };
  await supabase.rpc("expire_alerts");
  const { data, error } = await supabase.rpc("alert_current_prices", { p_device_token: null });
  if (error) return { notified: 0, error: error.message };

  let notified = 0;
  for (const a of data ?? []) {
    if (!a.active || a.current_price == null || a.current_price > a.target_price) continue;
    const recent = a.last_notified_at && Date.now() - new Date(a.last_notified_at).getTime() < 24 * 3600 * 1000;
    if (recent && a.last_notified_price != null && a.current_price >= a.last_notified_price) continue;

    const price = Number(a.current_price).toLocaleString("ko-KR");
    const res = await sendPush(
      a.device_token,
      "원하던 가격이 나왔어요",
      `${a.origin} → ${a.destination} ₩${price} (${a.found_date} 출발)`,
      { origin: a.origin, destination: a.destination, date: String(a.found_date ?? "") },
    );
    if (res.ok) {
      notified++;
      await supabase.from("alerts")
        .update({ last_notified_at: new Date().toISOString(), last_notified_price: a.current_price })
        .eq("id", a.id);
    } else if (res.status === 410 || res.reason === "BadDeviceToken" || res.reason === "Unregistered") {
      await supabase.from("alerts").update({ active: false }).eq("id", a.id);
    } else {
      console.error("push failed", res.status, res.reason);
    }
  }
  return { notified };
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
    for (let m = 0; m < MONTHS_AHEAD; m++) jobs.push({ origin: r.origin, destination: r.destination, cabin: 0, month: monthString(m) });
    jobs.push({ origin: r.origin, destination: r.destination, cabin: 0 }); // 최근 기록(이력 채우기)
    jobs.push({ origin: r.origin, destination: r.destination, cabin: 1 });
    jobs.push({ origin: r.origin, destination: r.destination, cabin: 2 });
  }

  let inserted = 0, failed = 0, empty = 0;

  async function worker() {
    while (jobs.length > 0) {
      const job = jobs.shift()!;
      try {
        const rows = job.cabin === 0 && job.month
          ? toRows(job.origin, job.destination, await fetchMonth(job.origin, job.destination, job.month!, token!))
          : toRowsLatest(job.origin, job.destination, job.cabin, await fetchLatestByClass(job.origin, job.destination, job.cabin, token!));
        if (rows.length === 0) { empty++; continue; }
        const { error: insErr } = await supabase.from("price_snapshots").upsert(rows, { onConflict: SNAPSHOT_CONFLICT });
        if (insErr) throw new Error(insErr.message);
        inserted += rows.length;
      } catch (e) {
        failed++;
        console.error(`${job.origin}-${job.destination} c${job.cabin} ${job.month ?? ""}:`, (e as Error).message);
      }
      await new Promise((r) => setTimeout(r, 150));
    }
  }

  await Promise.all(Array.from({ length: CONCURRENCY }, worker));
  const alerts = await notifyAlerts();

  return Response.json({ routes: routes?.length ?? 0, inserted, empty, failed, alerts });
});
