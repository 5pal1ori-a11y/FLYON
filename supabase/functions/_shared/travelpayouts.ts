// collect / prices 함수가 함께 쓰는 Travelpayouts 호출 로직

export const MONTHS_AHEAD = 3; // 이번 달부터 몇 개월치를 수집할지
export const SNAPSHOT_CONFLICT = "origin,destination,departure_date,airline,flight_number,price,fetched_on,cabin";

export function monthString(offset: number): string {
  const now = new Date();
  const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + offset, 1));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

type Item = Record<string, unknown>;

/** 일반석: 월 단위 항공편 (출발 시각·항공사 포함) */
export async function fetchMonth(origin: string, destination: string, month: string, token: string): Promise<Item[]> {
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
  return (body?.data ?? []) as Item[];
}

/** 비즈니스(1)·일등석(2): 최근 발견된 가격 (항공사·시각 정보는 없음) */
export async function fetchLatestByClass(origin: string, destination: string, tripClass: number, token: string): Promise<Item[]> {
  const url = new URL("https://api.travelpayouts.com/v2/prices/latest");
  url.searchParams.set("origin", origin);
  url.searchParams.set("destination", destination);
  url.searchParams.set("currency", "krw");
  url.searchParams.set("period_type", "year");
  url.searchParams.set("one_way", "true");
  url.searchParams.set("sorting", "price");
  url.searchParams.set("page", "1");
  url.searchParams.set("limit", "100");
  url.searchParams.set("trip_class", String(tripClass));
  url.searchParams.set("token", token);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const body = await res.json();
  return (body?.data ?? []) as Item[];
}

export function toRows(origin: string, destination: string, items: Item[]) {
  return items
    .filter((i) => typeof i.price === "number" && typeof i.departure_at === "string")
    .map((i) => ({
      origin,
      destination,
      cabin: 0,
      departure_date: String(i.departure_at).slice(0, 10),
      airline: String(i.airline ?? ""),
      flight_number: String(i.flight_number ?? ""),
      price: Math.round(i.price as number),
      transfers: Number(i.transfers ?? 0),
      // 출발지 현지 시각 "HH:mm" (시간대 변환 없이 문자열 그대로)
      departure_time: String(i.departure_at).slice(11, 16),
      duration_min: Number.isFinite(Number(i.duration_to ?? i.duration)) ? Math.round(Number(i.duration_to ?? i.duration)) : null,
    }));
}

export function toRowsLatest(origin: string, destination: string, cabin: number, items: Item[]) {
  const today = new Date().toISOString().slice(0, 10);
  return items
    .filter((i) => typeof i.value === "number" && typeof i.depart_date === "string" && String(i.depart_date) >= today)
    .map((i) => ({
      origin,
      destination,
      cabin,
      departure_date: String(i.depart_date).slice(0, 10),
      airline: "",
      flight_number: "",
      price: Math.round(i.value as number),
      transfers: Number(i.number_of_changes ?? 0),
      departure_time: null,
      duration_min: Number.isFinite(Number(i.duration)) ? Math.round(Number(i.duration)) : null,
    }));
}

/** 노선 하나를 좌석 등급에 맞게 수집한다 */
export async function fetchRoute(origin: string, destination: string, cabin: number, token: string) {
  if (cabin === 0) {
    const results = await Promise.allSettled(
      Array.from({ length: MONTHS_AHEAD }, (_, m) => fetchMonth(origin, destination, monthString(m), token)),
    );
    return results.flatMap((r) => (r.status === "fulfilled" ? toRows(origin, destination, r.value) : []));
  }
  return toRowsLatest(origin, destination, cabin, await fetchLatestByClass(origin, destination, cabin, token));
}
