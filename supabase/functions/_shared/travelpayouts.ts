// collect / prices 함수가 함께 쓰는 Travelpayouts 호출 로직

export const MONTHS_AHEAD = 3; // 이번 달부터 몇 개월치를 수집할지
export const SNAPSHOT_CONFLICT = "origin,destination,departure_date,airline,flight_number,price,fetched_on,cabin";

export function monthString(offset: number): string {
  const now = new Date();
  const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + offset, 1));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

type Item = Record<string, unknown>;

/** 한국 시장 데이터를 먼저 쓰고, 없으면 기본 시장 데이터를 쓴다.
 *  (기본 시장은 다른 나라 검색 기준이라 한국에서 보는 가격과 차이가 날 수 있다) */
const PREFERRED_MARKET = "kr";

/** 일반석: 월(YYYY-MM) 또는 날짜(YYYY-MM-DD) 단위 항공편 (출발 시각·항공사 포함) */
export async function fetchMonth(origin: string, destination: string, month: string, token: string): Promise<Item[]> {
  const local = await fetchMonthMarket(origin, destination, month, token, PREFERRED_MARKET).catch(() => []);
  if (local.length > 0) return local;
  return fetchMonthMarket(origin, destination, month, token, null);
}

async function fetchMonthMarket(origin: string, destination: string, month: string, token: string, market: string | null): Promise<Item[]> {
  const url = new URL("https://api.travelpayouts.com/aviasales/v3/prices_for_dates");
  if (market) url.searchParams.set("market", market);
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

/** 최근 발견된 가격 기록 (일반석 0, 비즈니스 1, 일등석 2). 항공사·시각 정보는 없지만
 *  found_at(발견 시각)이 있어 지난 며칠의 가격 이력을 채우는 데 쓴다. */
export async function fetchLatestByClass(origin: string, destination: string, tripClass: number, token: string): Promise<Item[]> {
  const local = await fetchLatestMarket(origin, destination, tripClass, token, PREFERRED_MARKET).catch(() => []);
  if (local.length > 0) return local;
  return fetchLatestMarket(origin, destination, tripClass, token, null);
}

async function fetchLatestMarket(origin: string, destination: string, tripClass: number, token: string, market: string | null): Promise<Item[]> {
  const url = new URL("https://api.travelpayouts.com/v2/prices/latest");
  if (market) url.searchParams.set("market", market);
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

/** found_at(UTC)을 한국 날짜로 바꾼다. 없으면 오늘. */
function seoulDate(foundAt: unknown): string {
  const t = typeof foundAt === "string" ? Date.parse(foundAt) : NaN;
  const ms = Number.isFinite(t) ? t : Date.now();
  return new Date(ms + 9 * 3600 * 1000).toISOString().slice(0, 10);
}

export function toRowsLatest(origin: string, destination: string, cabin: number, items: Item[]) {
  const today = new Date().toISOString().slice(0, 10);
  return items
    .filter((i) => typeof i.value === "number" && typeof i.depart_date === "string" && String(i.depart_date) >= today)
    .map((i) => ({
      fetched_on: seoulDate(i.found_at),
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
    const results = await Promise.allSettled([
      ...Array.from({ length: MONTHS_AHEAD }, (_, m) => fetchMonth(origin, destination, monthString(m), token)),
    ]);
    const rows = results.flatMap((r) => (r.status === "fulfilled" ? toRows(origin, destination, r.value) : []));
    // 지난 며칠의 기록으로 가격 이력을 채운다
    const history = await fetchLatestByClass(origin, destination, 0, token).catch(() => []);
    return [...rows, ...toRowsLatest(origin, destination, 0, history)];
  }
  return toRowsLatest(origin, destination, cabin, await fetchLatestByClass(origin, destination, cabin, token));
}
