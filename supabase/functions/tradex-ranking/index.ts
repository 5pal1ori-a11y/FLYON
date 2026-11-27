// TRADEX 시즌 랭킹 (앱이 anon 키로 호출)
//   POST   /tradex-ranking/join         { identity_token, nickname, age_confirmed }  → { session, nickname }
//   POST   /tradex-ranking/score        { season, ap }        (헤더 x-tradex-session)  → { ap, rank }
//   GET    /tradex-ranking/leaderboard?season=2026-Q4         (세션 헤더가 있으면 내 순위 포함)
//   POST   /tradex-ranking/nickname     { nickname }          (세션)
//   DELETE /tradex-ranking/me                                 (세션) 랭킹 참가 정보 전부 삭제
//
// - Apple 로그인 identity token을 Apple 공개키로 검증하고, 계정 식별값(sub)은 해시로만 저장한다.
// - 하루 AP 상한(150)과 현재 시즌을 서버에서 다시 확인한다 (앱이 보낸 값을 그대로 믿지 않음).
// - 보상은 앱 안의 배지 등만. 현금·상품은 걸지 않는다.
import { createClient } from "npm:@supabase/supabase-js@2";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const APPLE_KEYS = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
const AUDIENCES = (Deno.env.get("TRADEX_BUNDLE_IDS") ?? "com.flight.flyon").split(",").map((s) => s.trim()).filter(Boolean);
const DAILY_CAP = 150;
const NICK = /^[가-힣A-Za-z0-9_]{2,12}$/u;
const SESSION = /^[0-9a-f]{64}$/;
const SEASON = /^[0-9]{4}-Q[1-4]$/;
const BANNED = ["admin", "관리자", "운영자", "tradex", "트레이덱스"];

const json = (body: unknown, status = 200) => Response.json(body, { status });
const bad = (msg: string, status = 400) => json({ error: msg }, status);

function kst() { return new Date(Date.now() + 9 * 3600 * 1000); }
function currentSeason() { const d = kst(); return `${d.getUTCFullYear()}-Q${Math.floor(d.getUTCMonth() / 3) + 1}`; }
function kstDay() { return kst().toISOString().slice(0, 10); }

async function sha256(text: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
function randomHex(bytes = 32) {
  const a = new Uint8Array(bytes); crypto.getRandomValues(a);
  return [...a].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function appleSub(token: string): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, APPLE_KEYS, { issuer: "https://appleid.apple.com", audience: AUDIENCES });
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch { return null; }
}

async function playerFromSession(req: Request): Promise<{ player_id: string; nickname: string } | null> {
  const s = req.headers.get("x-tradex-session") ?? "";
  if (!SESSION.test(s)) return null;
  const { data } = await supabase.from("tradex_players").select("player_id,nickname").eq("session_hash", await sha256(s)).maybeSingle();
  return data ?? null;
}

function validNickname(n: unknown): n is string {
  if (typeof n !== "string" || !NICK.test(n)) return false;
  const lower = n.toLowerCase();
  return !BANNED.some((w) => lower.includes(w));
}

async function rankOf(season: string, ap: number, updatedAt: string) {
  const { count } = await supabase.from("tradex_season_scores").select("player_id", { count: "exact", head: true })
    .eq("season", season).or(`ap.gt.${ap},and(ap.eq.${ap},updated_at.lt."${updatedAt}")`);
  return (count ?? 0) + 1;
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const path = url.pathname.replace(/^.*\/tradex-ranking/, "") || "/";

  // 랭킹 참가 (닉네임 등록) — Apple identity token 필요
  if (req.method === "POST" && path === "/join") {
    const body = await req.json().catch(() => ({}));
    if (body.age_confirmed !== true) return bad("만 14세 이상만 참가할 수 있어요.");
    if (!validNickname(body.nickname)) return bad("닉네임은 한글·영문·숫자 2~12자로 정해 주세요.");
    const sub = typeof body.identity_token === "string" ? await appleSub(body.identity_token) : null;
    if (!sub) return bad("Apple 로그인 확인에 실패했어요.", 401);
    const playerId = await sha256(`tradex:${sub}`);
    const { data: taken } = await supabase.from("tradex_players").select("player_id").eq("nickname", body.nickname).maybeSingle();
    if (taken && taken.player_id !== playerId) return bad("이미 쓰고 있는 닉네임이에요.", 409);
    const session = randomHex();
    const { error } = await supabase.from("tradex_players").upsert({
      player_id: playerId, nickname: body.nickname, session_hash: await sha256(session),
      age_confirmed: true, updated_at: new Date().toISOString(),
    });
    if (error) return bad("server error", 500);
    return json({ session, nickname: body.nickname });
  }

  // 순위표 (누구나), 세션이 있으면 내 순위 포함
  if (req.method === "GET" && path === "/leaderboard") {
    const season = url.searchParams.get("season") ?? currentSeason();
    if (!SEASON.test(season)) return bad("invalid season");
    const { data, error } = await supabase.from("tradex_season_scores")
      .select("ap,updated_at,tradex_players(nickname)")
      .eq("season", season).gt("ap", 0)
      .order("ap", { ascending: false }).order("updated_at", { ascending: true }).limit(100);
    if (error) return bad("server error", 500);
    const { count } = await supabase.from("tradex_season_scores").select("player_id", { count: "exact", head: true })
      .eq("season", season).gt("ap", 0);
    const top = (data ?? []).map((r: any, i: number) => ({ rank: i + 1, nickname: r.tradex_players?.nickname ?? "?", ap: r.ap }));
    let me = null;
    const player = await playerFromSession(req);
    if (player) {
      const { data: row } = await supabase.from("tradex_season_scores").select("ap,updated_at")
        .eq("season", season).eq("player_id", player.player_id).maybeSingle();
      me = { nickname: player.nickname, ap: row?.ap ?? 0, rank: row && row.ap > 0 ? await rankOf(season, row.ap, row.updated_at) : null };
    }
    return json({ season, current_season: currentSeason(), total: count ?? 0, top, me });
  }

  const player = await playerFromSession(req);
  if (!player) return bad("랭킹 참가 정보가 없어요.", 401);

  // AP 반영: 현재 시즌만, 늘어난 만큼만, 하루 상한까지만
  if (req.method === "POST" && path === "/score") {
    const body = await req.json().catch(() => ({}));
    const season = currentSeason();
    if (body.season !== season) return bad("지난 시즌 점수는 반영할 수 없어요.");
    const ap = Number.isInteger(body.ap) && body.ap >= 0 ? body.ap as number : -1;
    if (ap < 0) return bad("invalid ap");
    const { data: row } = await supabase.from("tradex_season_scores").select("ap,updated_at")
      .eq("season", season).eq("player_id", player.player_id).maybeSingle();
    const day = kstDay();
    const { data: daily } = await supabase.from("tradex_ap_daily").select("gained")
      .eq("season", season).eq("player_id", player.player_id).eq("day", day).maybeSingle();
    const current = row?.ap ?? 0;
    const gained = daily?.gained ?? 0;
    const add = Math.max(0, Math.min(ap - current, DAILY_CAP - gained));
    const now = new Date().toISOString();
    if (add > 0 || !row) {
      const { error: e1 } = await supabase.from("tradex_season_scores").upsert({ season, player_id: player.player_id, ap: current + add, updated_at: now });
      const { error: e2 } = await supabase.from("tradex_ap_daily").upsert({ season, player_id: player.player_id, day, gained: gained + add });
      if (e1 || e2) return bad("server error", 500);
    }
    const newAP = current + add;
    const stamp = add > 0 || !row ? now : row.updated_at;
    return json({ ap: newAP, rank: newAP > 0 ? await rankOf(season, newAP, stamp) : null });
  }

  if (req.method === "POST" && path === "/nickname") {
    const body = await req.json().catch(() => ({}));
    if (!validNickname(body.nickname)) return bad("닉네임은 한글·영문·숫자 2~12자로 정해 주세요.");
    const { data: taken } = await supabase.from("tradex_players").select("player_id").eq("nickname", body.nickname).maybeSingle();
    if (taken && taken.player_id !== player.player_id) return bad("이미 쓰고 있는 닉네임이에요.", 409);
    const { error } = await supabase.from("tradex_players").update({ nickname: body.nickname, updated_at: new Date().toISOString() })
      .eq("player_id", player.player_id);
    if (error) return bad("server error", 500);
    return json({ nickname: body.nickname });
  }

  // 랭킹 참가 해제 / 계정 삭제: 참가자·점수·일일 기록 모두 삭제 (cascade)
  if (req.method === "DELETE" && path === "/me") {
    const { error } = await supabase.from("tradex_players").delete().eq("player_id", player.player_id);
    if (error) return bad("server error", 500);
    return json({ deleted: true });
  }

  return bad("not found", 404);
});
