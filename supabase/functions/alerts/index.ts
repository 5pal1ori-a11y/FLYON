// 가격 알림 관리 (앱이 anon 키로 호출)
//   GET    /alerts?device_token=...            내 알림 목록 + 현재 최저가
//   POST   /alerts  { device_token, origin, destination, depart_date?, depart_month?, airlines?, cabin, target_price, baseline_price? }
//   DELETE /alerts?device_token=...&id=...      알림 하나 삭제
//   DELETE /alerts?device_token=...&all=1       이 기기의 알림 전부 삭제 (계정 삭제 시)
import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const TOKEN = /^[0-9a-f]{64,200}$/;
const IATA = /^[A-Z]{3}$/;
const AIRLINE = /^[A-Z0-9]{2}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const MAX_PER_DEVICE = 20;

const bad = (msg: string) => Response.json({ error: msg }, { status: 400 });

Deno.serve(async (req) => {
  const url = new URL(req.url);

  if (req.method === "GET") {
    const token = url.searchParams.get("device_token") ?? "";
    if (!TOKEN.test(token)) return bad("invalid token");
    const { data, error } = await supabase.rpc("alert_current_prices", { p_device_token: token });
    if (error) return Response.json({ error: "server error" }, { status: 500 });
    return Response.json({
      alerts: (data ?? []).map((a: Record<string, unknown>) => ({
        id: a.id, origin: a.origin, destination: a.destination,
        depart_date: a.depart_date, depart_month: a.depart_month, airlines: a.airlines,
        cabin: a.cabin, target_price: a.target_price, baseline_price: a.baseline_price,
        active: a.active, current_price: a.current_price, found_date: a.found_date,
      })),
    });
  }

  if (req.method === "POST") {
    let b: Record<string, unknown>;
    try { b = await req.json(); } catch { return bad("invalid json"); }
    const token = String(b.device_token ?? "");
    const origin = String(b.origin ?? "");
    const destination = String(b.destination ?? "");
    const cabin = Number(b.cabin ?? 0);
    const target = Number(b.target_price);
    const departDate = b.depart_date ? String(b.depart_date) : null;
    const departMonth = b.depart_month ? String(b.depart_month) : null;
    const airlines = Array.isArray(b.airlines) && b.airlines.length > 0 ? (b.airlines as unknown[]).map(String) : null;

    if (!TOKEN.test(token)) return bad("invalid token");
    if (!IATA.test(origin) || !IATA.test(destination) || origin === destination) return bad("invalid route");
    if (![0, 1, 2].includes(cabin)) return bad("invalid cabin");
    if (!Number.isInteger(target) || target <= 0 || target > 100_000_000) return bad("invalid target");
    if (departDate && !DATE.test(departDate)) return bad("invalid date");
    if (departMonth && !DATE.test(departMonth)) return bad("invalid month");
    if (airlines && (airlines.length > 20 || !airlines.every((a) => AIRLINE.test(a)))) return bad("invalid airlines");

    const { count } = await supabase.from("alerts").select("id", { count: "exact", head: true })
      .eq("device_token", token).eq("active", true);
    if ((count ?? 0) >= MAX_PER_DEVICE) return Response.json({ error: "too many alerts" }, { status: 429 });

    const { data, error } = await supabase.from("alerts").insert({
      device_token: token, origin, destination, depart_date: departDate, depart_month: departMonth,
      airlines, cabin, target_price: target,
      baseline_price: Number.isInteger(Number(b.baseline_price)) ? Number(b.baseline_price) : null,
    }).select("id").single();
    if (error) return Response.json({ error: "server error" }, { status: 500 });
    return Response.json({ id: data.id });
  }

  if (req.method === "DELETE") {
    const token = url.searchParams.get("device_token") ?? "";
    if (!TOKEN.test(token)) return bad("invalid token");
    let q = supabase.from("alerts").delete().eq("device_token", token);
    if (url.searchParams.get("all") !== "1") {
      const id = url.searchParams.get("id") ?? "";
      if (!/^[0-9a-f-]{36}$/.test(id)) return bad("invalid id");
      q = q.eq("id", id);
    }
    const { error } = await q;
    if (error) return Response.json({ error: "server error" }, { status: 500 });
    return Response.json({ ok: true });
  }

  return new Response("method not allowed", { status: 405 });
});
