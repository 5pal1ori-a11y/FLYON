// 앱이 호출하는 읽기 API (처음 조회하는 노선은 즉시 수집한다)
//   GET /prices/history?origin=ICN&destination=CJU&days=90[&airlines=KE,OZ]
//   GET /prices/calendar?origin=ICN&destination=CJU&month=2026-12[&airlines=KE]
//   GET /prices/quotes?origin=ICN&destination=CJU&month=2026-12[&airlines=KE]
//   GET /prices/flights?origin=ICN&destination=CJU&date=2026-12-05[&airlines=KE]
//   GET /prices/deals?origin=ICN
// 배포: npx supabase functions deploy prices
import { createClient } from "npm:@supabase/supabase-js@2";
import { fetchMonth, MONTHS_AHEAD, monthString, SNAPSHOT_CONFLICT, toRows } from "../_shared/travelpayouts.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const IATA = /^[A-Z]{3}$/;
const AIRLINE = /^[A-Z0-9]{2}$/;
const MAX_AUTO_ROUTES = 120;   // 자동 추가되는 추적 노선 상한 (수집 시간 보호)
const COOLDOWN_MINUTES = 360;  // 같은 노선을 즉시 수집하는 최소 간격

function bad(msg: string) {
  return Response.json({ error: msg }, { status: 400 });
}

/** 이 노선의 데이터가 하나도 없으면 한 번 수집을 시도한다 (남용 방지: 쿨다운과 노선 수 상한) */
async function ensureData(origin: string, destination: string) {
  const { data: existing } = await supabase
    .from("price_snapshots").select("id")
    .eq("origin", origin).eq("destination", destination).limit(1);
  if (existing && existing.length > 0) return;

  const token = Deno.env.get("TRAVELPAYOUTS_TOKEN");
  if (!token) return;

  const { data: claimed } = await supabase.rpc("try_claim_route_fetch", {
    p_origin: origin, p_destination: destination, p_cooldown_minutes: COOLDOWN_MINUTES,
  });
  if (!claimed) return;

  const results = await Promise.allSettled(
    Array.from({ length: MONTHS_AHEAD }, (_, m) => fetchMonth(origin, destination, monthString(m), token)),
  );
  const rows = results.flatMap((r) => (r.status === "fulfilled" ? toRows(origin, destination, r.value) : []));
  if (rows.length === 0) return;

  await supabase.from("price_snapshots").upsert(rows, { onConflict: SNAPSHOT_CONFLICT });
  // 데이터가 실제로 있는 노선만 이후 정기 수집 대상에 넣는다
  await supabase.rpc("add_route_if_room", { p_origin: origin, p_destination: destination, p_max: MAX_AUTO_ROUTES });
}

Deno.serve(async (req) => {
  if (req.method !== "GET") return new Response("method not allowed", { status: 405 });

  const url = new URL(req.url);
  const origin = url.searchParams.get("origin") ?? "";

  // 출발지별 특가 목록 (도착지 파라미터 없음)
  if (url.pathname.endsWith("/deals")) {
    if (!IATA.test(origin)) return bad("invalid origin");
    const { data, error } = await supabase.rpc("get_deals", { p_origin: origin, p_limit: 12 });
    if (error) return Response.json({ error: "server error" }, { status: 500 });
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

  const path = url.pathname;

  if (path.endsWith("/history")) {
    const days = Math.min(Math.max(parseInt(url.searchParams.get("days") ?? "30", 10) || 30, 1), 90);
    await ensureData(origin, destination);
    const { data, error } = await supabase.rpc("get_price_history", {
      p_origin: origin, p_destination: destination, p_days: days, p_airlines: airlines,
    });
    if (error) return Response.json({ error: "server error" }, { status: 500 });
    return Response.json({
      points: (data ?? []).map((r: { day: string; price: number }) => ({ date: r.day, price: r.price })),
    });
  }

  if (path.endsWith("/flights")) {
    const date = url.searchParams.get("date") ?? "";
    if (!/^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/.test(date)) return bad("invalid date");
    await ensureData(origin, destination);
    const { data, error } = await supabase.rpc("get_price_flights", {
      p_origin: origin, p_destination: destination, p_date: date, p_airlines: airlines,
    });
    if (error) return Response.json({ error: "server error" }, { status: 500 });
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
    await ensureData(origin, destination);
    const { data, error } = await supabase.rpc("get_price_calendar", {
      p_origin: origin, p_destination: destination, p_month: `${month}-01`, p_airlines: airlines,
    });
    if (error) return Response.json({ error: "server error" }, { status: 500 });
    return Response.json({
      days: (data ?? []).map((r: { day: string; price: number }) => ({ date: r.day, price: r.price })),
    });
  }

  if (path.endsWith("/quotes")) {
    await ensureData(origin, destination);
    const { data, error } = await supabase.rpc("get_price_quotes", {
      p_origin: origin, p_destination: destination, p_month: `${month}-01`, p_airlines: airlines,
    });
    if (error) return Response.json({ error: "server error" }, { status: 500 });
    return Response.json({
      quotes: (data ?? []).map((r: { airline: string; price: number; departure_date: string; transfers: number }) => ({
        airline: r.airline, price: r.price, departure_date: r.departure_date, transfers: r.transfers,
      })),
    });
  }

  return new Response("not found", { status: 404 });
});
