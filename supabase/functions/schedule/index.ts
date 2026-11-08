// 노선의 그날 운항편 전체 (가격 없음)
//   GET /schedule?origin=GMP&destination=CJU&date=2026-12-05
// 필요한 시크릿: AIRLABS_API_KEY (없으면 503)
// 노선별 스케줄을 3일 동안 캐시하고, 요청한 날짜의 요일에 운항하는 편만 돌려준다.
import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const IATA = /^[A-Z]{3}$/;
const DATE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;
const CACHE_HOURS = 72;
const WEEKDAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];

const json = (body: unknown, status = 200) => Response.json(body, { status });

type Route = {
  airline: string; flight_number: string; departure_time: string | null; arrival_time: string | null;
  duration_min: number | null; days: string[];
};

function mapRoutes(items: Array<Record<string, any>>): Route[] {
  const seen = new Set<string>();
  const out: Route[] = [];
  for (const r of items) {
    const airline = String(r.airline_iata ?? "").toUpperCase();
    const number = String(r.flight_number ?? "").replace(/\D/g, "");
    if (!airline || !number) continue;
    // 공동운항(코드셰어) 편은 실제 운항편과 겹치므로 뺀다
    if (r.cs_airline_iata || r.cs_flight_iata) continue;
    const key = `${airline}${number}-${r.dep_time ?? ""}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({
      airline,
      flight_number: number,
      departure_time: typeof r.dep_time === "string" ? r.dep_time.slice(0, 5) : null,
      arrival_time: typeof r.arr_time === "string" ? r.arr_time.slice(0, 5) : null,
      duration_min: Number.isFinite(Number(r.duration)) ? Number(r.duration) : null,
      days: Array.isArray(r.days) ? r.days.map((d: unknown) => String(d).toLowerCase().slice(0, 3)) : [],
    });
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method !== "GET") return new Response("method not allowed", { status: 405 });
  const url = new URL(req.url);
  const origin = url.searchParams.get("origin") ?? "";
  const destination = url.searchParams.get("destination") ?? "";
  const date = url.searchParams.get("date") ?? "";
  if (!IATA.test(origin) || !IATA.test(destination) || origin === destination || !DATE.test(date)) {
    return json({ error: "invalid request" }, 400);
  }

  const key = Deno.env.get("AIRLABS_API_KEY");
  if (!key) return json({ error: "schedule not configured" }, 503);

  let routes: Route[] | null = null;
  const { data: cached } = await supabase.from("route_schedules").select("payload,fetched_at")
    .eq("origin", origin).eq("destination", destination).maybeSingle();
  if (cached && Date.now() - new Date(cached.fetched_at).getTime() < CACHE_HOURS * 3600 * 1000) {
    routes = cached.payload as Route[];
  } else {
    const api = new URL("https://airlabs.co/api/v9/routes");
    api.searchParams.set("dep_iata", origin);
    api.searchParams.set("arr_iata", destination);
    api.searchParams.set("api_key", key);
    const res = await fetch(api);
    if (!res.ok) {
      console.error("airlabs", res.status);
      if (cached) routes = cached.payload as Route[];
      else return json({ error: "provider error", status: res.status }, 502);
    } else {
      const body = await res.json();
      if (body?.error) {
        console.error("airlabs error", JSON.stringify(body.error).slice(0, 200));
        if (cached) routes = cached.payload as Route[];
        else return json({ error: "provider error" }, 502);
      } else {
        routes = mapRoutes(body?.response ?? []);
        await supabase.from("route_schedules").upsert({ origin, destination, payload: routes, fetched_at: new Date().toISOString() });
      }
    }
  }

  const weekday = WEEKDAYS[new Date(`${date}T12:00:00Z`).getUTCDay()];
  const flights = (routes ?? [])
    .filter((r) => r.days.length === 0 || r.days.includes(weekday))
    .sort((a, b) => (a.departure_time ?? "").localeCompare(b.departure_time ?? ""));
  return json({ flights });
});
