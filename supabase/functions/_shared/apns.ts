// Apple Push Notification service (APNs) 전송
// 필요한 시크릿: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY(.p8 내용)

let cached: { token: string; at: number } | null = null;

function b64url(data: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function apnsConfigured(): boolean {
  return Boolean(Deno.env.get("APNS_KEY_ID") && Deno.env.get("APNS_TEAM_ID") && Deno.env.get("APNS_PRIVATE_KEY"));
}

async function providerToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && now - cached.at < 40 * 60) return cached.token; // Apple 권장: 20~60분마다 갱신
  const pem = Deno.env.get("APNS_PRIVATE_KEY")!.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const header = b64url(JSON.stringify({ alg: "ES256", kid: Deno.env.get("APNS_KEY_ID") }));
  const claims = b64url(JSON.stringify({ iss: Deno.env.get("APNS_TEAM_ID"), iat: now }));
  const input = `${header}.${claims}`;
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input));
  const token = `${input}.${b64url(sig)}`;
  cached = { token, at: now };
  return token;
}

export async function sendPush(deviceToken: string, title: string, body: string, data: Record<string, string>) {
  const topic = Deno.env.get("APNS_BUNDLE_ID") ?? "com.flight.flyon";
  const host = Deno.env.get("APNS_HOST") ?? "api.push.apple.com"; // TestFlight/App Store = 운영 서버
  const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerToken()}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: JSON.stringify({ aps: { alert: { title, body }, sound: "default" }, ...data }),
  });
  let reason = "";
  if (!res.ok) {
    try { reason = (await res.json())?.reason ?? ""; } catch { /* ignore */ }
  }
  return { ok: res.ok, status: res.status, reason };
}
