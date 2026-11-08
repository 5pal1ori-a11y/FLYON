// 앱이 호출하는 읽기 API (처음 조회하는 노선은 즉시 수집한다)
//   GET /prices/history?origin=ICN&destination=CJU&days=90[&airlines=KE,OZ][&cabin=0]
//   GET /prices/calendar?origin=ICN&destination=CJU&month=2026-12[&airlines=KE][&cabin=0]
//   GET /prices/quotes?origin=ICN&destination=CJU&month=2026-12[&airlines=KE][&cabin=0]
//   GET /prices/flights?origin=ICN&destination=CJU&date=2026-12-05[&airlines=KE][&cabin=0]
//   GET /prices/deals?origin=ICN[&cabin=0]
//   GET /prices/day?origin=ICN&destination=CJU&date=2026-12-05[&airlines=KE][&cabin=0]  선택한 출발일의 가격 변화
// cabin: 0 일반석, 1 비즈니스, 2 일등석
import { createClient } from "npm:@supabase/supabase-js@2";
import { fetchRoute, SNAPSHOT_CONFLICT } from "../_shared/travelpayouts.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const IATA = /^[A-Z]{3}$/;
const AIRLINE = /^[A-Z0-9]{2}$/;
const MAX_AUTO_ROUTES = 150;   // 자동 추가되는 추적 노선 상한 (수집 시간 보호)
const COOLDOWN_MINUTES = 360;  // 같은 노선을 즉시 수집하는 최소 간격

const bad = (msg: string) => Response.json({ error: msg }, { status: 400 });
const fail = () => Response.json({ error: "server error" }, { status: 500 });

/** 이 노선·좌석의 데이터가 하나도 없으면 한 번 수집을 시도한다 (쿨다운과 노선 수 상한으로 남용 방지) */
async function ensureData(origin: string, destination: string, cabin: number) {
  const { data: existing } = await supabase
    .from("price_snapshots").select("id")
    .eq("origin", origin).eq("destination", destination).eq("cabin", cabin).limit(1);
  if (existing && existing.length > 0) return;

  const token = Deno.env.get("TRAVELPAYOUTS_TOKEN");
  if (!token) return;

  const { data: claimed } = await supabase.rpc("try_claim_route_fetch", {
    p_origin: origin, p_destination: destination, p_cooldown_minutes: COOLDOWN_MINUTES, p_cabin: cabin,
  });
  if (!claimed) return;

  try {
    const rows = await fetchRoute(origin, destination, cabin, token);
    if (rows.length === 0) return;
    await supabase.from("price_snapshots").upsert(rows, { onConflict: SNAPSHOT_CONFLICT });
    if (cabin === 0) {
      // 데이터가 실제로 있는 노선만 정기 수집 대상에 넣는다
      await supabase.rpc("add_route_if_room", { p_origin: origin, p_destination: destination, p_max: MAX_AUTO_ROUTES });
    }
  } catch (e) {
    console.error("ensureData", origin, destination, cabin, (e as Error).message);
  }
}

Deno.serve(async (req) => {
  if (req.method !== "GET") return new Response("method not allowed", { status: 405 });

  const url = new URL(req.url);
  const path = url.pathname;
  const origin = url.searchParams.get("origin") ?? "";
  const cabin = Number(url.searchParams.get("cabin") ?? "0");
  if (![0, 1, 2].includes(cabin)) return bad("invalid cabin");

  // 출발지별 특가 목록
  if (path.endsWith("/deals")) {
    if (!IATA.test(origin)) return bad("invalid origin");
    const { data, error } = await supabase.rpc("get_deals", { p_origin: origin, p_limit: 12, p_cabin: cabin });
    if (error) return fail();
    return Response.json({
      deals: (data ?? []).map((r: { destination: string; lowest: number; average: number; lowest_date: string }) => ({
        destination: r.destination, lowest: r.lowest, average: r.average, lowest_date: r.lowest_date,
      })),
    });
  }

  const destination = url.searchParams.get("destination") ?? "";
  if (!IATA.test(origin) || !IATA.test(destination) || origin === destination) return bad("invalid route");

  const airlineParam = url.searchParams.get("airlines");
  let airlines: string[] | null = null;
  if (airlineParam) {
    airlines = airlineParam.split(",").map((a) => a.trim().toUpperCase()).filter(Boolean);
    if (airlines.length === 0 || airlines.length > 40 || !airlines.every((a) => AIRLINE.test(a))) {
      return bad("invalid airlines");
    }
  }

  const base = { p_origin: origin, p_destination: destination, p_airlines: airlines, p_cabin: cabin };

  if (path.endsWith("/history")) {
    const days = Math.min(Math.max(parseInt(url.searchParams.get("days") ?? "30", 10) || 30, 1), 90);
    await ensureData(origin, destination, cabin);
    const { data, error } = await supabase.rpc("get_price_history", { ...base, p_days: days });
    if (error) return fail();
    return Response.json({
      points: (data ?? []).map((r: { day: string; price: number }) => ({ date: r.day, price: r.price })),
    });
  }

  if (path.endsWith("/day")) {
    const date = url.searchParams.get("date") ?? "";
    if (!/^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/.test(date)) return bad("invalid date");
    await ensureData(origin, destination, cabin);
    const { data, error } = await supabase.rpc("get_day_history", { ...base, p_date: date });
    if (error) return fail();
    return Response.json({
      points: (data ?? []).map((r: { day: string; price: number }) => ({ date: r.day, price: r.price })),
    });
  }

  if (path.endsWith("/flights")) {
    const date = url.searchParams.get("date") ?? "";
    if (!/^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/.test(date)) return bad("invalid date");
    await ensureData(origin, destination, cabin);
    const { data, error } = await supabase.rpc("get_price_flights", { ...base, p_date: date });
    if (error) return fail();
    return Response.json({
      flights: (data ?? []).map((r: { airline: string; flight_number: string; departure_time: string | null; duration_min: number | null; price: number; transfers: number }) => ({
        airline: r.airline, flight_number: r.flight_number, departure_time: r.departure_time,
        duration_min: r.duration_min, price: r.price, transfers: r.transfers,
      })),
    });
  }

  const month = url.searchParams.get("month") ?? "";
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) return bad("invalid month");

  if (path.endsWith("/calendar")) {
    await ensureData(origin, destination, cabin);
    const { data, error } = await supabase.rpc("get_price_calendar", { ...base, p_month: `${month}-01` });
    if (error) return fail();
    return Response.json({
      days: (data ?? []).map((r: { day: string; price: number }) => ({ date: r.day, price: r.price })),
    });
  }

  if (path.endsWith("/quotes")) {
    await ensureData(origin, destination, cabin);
    const { data, error } = await supabase.rpc("get_price_quotes", { ...base, p_month: `${month}-01` });
    if (error) return fail();
    return Response.json({
      quotes: (data ?? []).map((r: { airline: string; price: number; departure_date: string; transfers: number }) => ({
        airline: r.airline, price: r.price, departure_date: r.departure_date, transfers: r.transfers,
      })),
    });
  }

  return new Response("not found", { status: 404 });
});
