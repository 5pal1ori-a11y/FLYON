// 앱이 호출하는 읽기 전용 API
//   GET /prices/history?origin=ICN&destination=CJU&days=30
//   GET /prices/quotes?origin=ICN&destination=CJU&month=2026-12
// 배포: npx supabase functions deploy prices   (앱은 anon 키로 호출)
import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const IATA = /^[A-Z]{3}$/;

function bad(msg: string) {
  return Response.json({ error: msg }, { status: 400 });
}

Deno.serve(async (req) => {
  if (req.method !== "GET") return new Response("method not allowed", { status: 405 });

  const url = new URL(req.url);
  const origin = url.searchParams.get("origin") ?? "";
  const destination = url.searchParams.get("destination") ?? "";
  if (!IATA.test(origin) || !IATA.test(destination)) return bad("invalid route");

  if (url.pathname.endsWith("/history")) {
    const days = Math.min(Math.max(parseInt(url.searchParams.get("days") ?? "30", 10) || 30, 1), 90);
    const { data, error } = await supabase.rpc("get_price_history", {
      p_origin: origin, p_destination: destination, p_days: days,
    });
    if (error) return Response.json({ error: "server error" }, { status: 500 });
    return Response.json({
      points: (data ?? []).map((r: { day: string; price: number }) => ({ date: r.day, price: r.price })),
    });
  }

  if (url.pathname.endsWith("/quotes")) {
    const month = url.searchParams.get("month") ?? "";
    if (!/^\d{4}-\d{2}$/.test(month)) return bad("invalid month");
    const { data, error } = await supabase.rpc("get_price_quotes", {
      p_origin: origin, p_destination: destination, p_month: `${month}-01`,
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
