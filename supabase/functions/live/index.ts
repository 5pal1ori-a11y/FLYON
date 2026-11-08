// 실시간 항공권 가격 (Duffel)
//   GET /live?origin=ICN&destination=CJU&date=2026-12-05[&cabin=0]
// 필요한 시크릿: DUFFEL_ACCESS_TOKEN (없으면 503)
// 비용 관리: 같은 조건은 30분 동안 캐시를 쓰고, 하루 실제 조회 수를 LIVE_DAILY_LIMIT(기본 50)로 제한한다.
import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const IATA = /^[A-Z]{3}$/;
const DATE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;
const CACHE_MINUTES = 30;
const CABINS = ["economy", "business", "first"];

const json = (body: unknown, status = 200) => Response.json(body, { status });

/** "PT1H10M" -> 70 */
function isoMinutes(d: unknown): number | null {
  if (typeof d !== "string") return null;
  const m = d.match(/P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?/);
  if (!m) return null;
  return (Number(m[1] ?? 0) * 24 + Number(m[2] ?? 0)) * 60 + Number(m[3] ?? 0);
}

type Flight = {
  airline: string; flight_number: string; departure_time: string | null; duration_min: number | null;
  price: number; currency: string; transfers: number;
};

function mapOffers(offers: Array<Record<string, any>>): Flight[] {
  const best = new Map<string, Flight>();
  for (const o of offers) {
    const slice = o.slices?.[0];
    const segs: Array<Record<string, any>> = slice?.segments ?? [];
    if (segs.length === 0) continue;
    const first = segs[0];
    const airline = String(first.marketing_carrier?.iata_code ?? o.owner?.iata_code ?? "");
    const flightNumber = `${airline}${first.marketing_carrier_flight_number ?? ""}`;
    const departure = typeof first.departing_at === "string" ? first.departing_at.slice(11, 16) : null;
    let duration = isoMinutes(slice?.duration);
    if (duration == null && typeof first.departing_at === "string" && typeof segs[segs.length - 1].arriving_at === "string") {
      // 현지 시각 문자열 차이 (시간대가 다르면 부정확할 수 있다)
      duration = Math.round((Date.parse(segs[segs.length - 1].arriving_at) - Date.parse(first.departing_at)) / 60000);
    }
    const f: Flight = {
      airline, flight_number: flightNumber, departure_time: departure, duration_min: duration,
      price: Math.round(Number(o.total_amount)), currency: String(o.total_currency ?? "KRW"),
      transfers: segs.length - 1,
    };
    if (!Number.isFinite(f.price) || f.price <= 0) continue;
    const key = `${f.flight_number}-${departure}-${f.transfers}`;
    const prev = best.get(key);
    if (!prev || f.price < prev.price) best.set(key, f);
  }
  return [...best.values()].sort((a, b) => a.price - b.price).slice(0, 60);
}

Deno.serve(async (req) => {
  if (req.method !== "GET") return new Response("method not allowed", { status: 405 });
  const url = new URL(req.url);
  const origin = url.searchParams.get("origin") ?? "";
  const destination = url.searchParams.get("destination") ?? "";
  const date = url.searchParams.get("date") ?? "";
  const cabin = Number(url.searchParams.get("cabin") ?? "0");
  if (!IATA.test(origin) || !IATA.test(destination) || origin === destination) return json({ error: "invalid route" }, 400);
  if (!DATE.test(date) || ![0, 1, 2].includes(cabin)) return json({ error: "invalid request" }, 400);

  const token = Deno.env.get("DUFFEL_ACCESS_TOKEN");
  if (!token) return json({ error: "live not configured" }, 503);

  const key = `${origin}-${destination}-${date}-${cabin}`;
  const { data: cached } = await supabase.from("live_cache").select("payload,fetched_at").eq("key", key).maybeSingle();
  if (cached && Date.now() - new Date(cached.fetched_at).getTime() < CACHE_MINUTES * 60 * 1000) {
    return json({ ...cached.payload, fetched_at: cached.fetched_at, cached: true });
  }

  // 하루 실제 조회 수 제한 (한국 시간 기준)
  const limit = Number(Deno.env.get("LIVE_DAILY_LIMIT") ?? "50");
  const kstMidnight = new Date(new Date(Date.now() + 9 * 3600e3).toISOString().slice(0, 10) + "T00:00:00+09:00");
  const { count } = await supabase.from("live_cache").select("key", { count: "exact", head: true })
    .gte("fetched_at", kstMidnight.toISOString());
  if ((count ?? 0) >= limit) {
    if (cached) return json({ ...cached.payload, fetched_at: cached.fetched_at, cached: true, stale: true });
    return json({ error: "daily limit" }, 429);
  }

  const res = await fetch("https://api.duffel.com/air/offer_requests?return_offers=true&supplier_timeout=15000", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Duffel-Version": "v2",
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      data: {
        slices: [{ origin, destination, departure_date: date }],
        passengers: [{ type: "adult" }],
        cabin_class: CABINS[cabin],
      },
    }),
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    console.error("duffel", res.status, detail.slice(0, 300));
    return json({ error: "provider error", status: res.status }, 502);
  }
  const body = await res.json();
  const payload = { flights: mapOffers(body?.data?.offers ?? []) };
  const fetchedAt = new Date().toISOString();
  await supabase.from("live_cache").upsert({ key, payload, fetched_at: fetchedAt });
  return json({ ...payload, fetched_at: fetchedAt, cached: false });
});
