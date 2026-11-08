// collect / prices 함수가 함께 쓰는 Travelpayouts 호출 로직

export const MONTHS_AHEAD = 3; // 이번 달부터 몇 개월치를 수집할지
export const SNAPSHOT_CONFLICT = "origin,destination,departure_date,airline,flight_number,price,fetched_on";

export function monthString(offset: number): string {
  const now = new Date();
  const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + offset, 1));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

export async function fetchMonth(
  origin: string,
  destination: string,
  month: string,
  token: string,
): Promise<Array<Record<string, unknown>>> {
  const url = new URL("https://api.travelpayouts.com/aviasales/v3/prices_for_dates");
  url.searchParams.set("origin", origin);
  url.searchParams.set("destination", destination);
  url.searchParams.set("departure_at", month);
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

export function toRows(origin: string, destination: string, items: Array<Record<string, unknown>>) {
  return items
    .filter((i) => typeof i.price === "number" && typeof i.departure_at === "string")
    .map((i) => ({
      origin,
      destination,
      departure_date: String(i.departure_at).slice(0, 10),
      airline: String(i.airline ?? ""),
      flight_number: String(i.flight_number ?? ""),
      price: Math.round(i.price as number),
      transfers: Number(i.transfers ?? 0),
    }));
}
