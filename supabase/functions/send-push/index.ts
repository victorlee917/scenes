// send-push
//
// Server-only entry point that sends FCM push notifications to a target user.
// Service-role authenticated (verify_jwt: false) — only invoked from
// Postgres triggers (pg_net) or other EFs, never directly from the client.
// `X-Internal-Token` 헤더로 간단한 shared-secret 가드.
//
// Body:
//   {
//     user_id: "<UUID>",          // 알림 수신자
//     title: "...",
//     body: "...",
//     data?: { ... }              // optional payload (e.g., scene_id)
//   }
//
// Pipeline:
//   1) device_tokens에서 user_id에 등록된 모든 token + platform 조회
//   2) FCM_SERVICE_ACCOUNT(JSON) 시크릿으로 Google OAuth2 access token 발급
//      (https://www.googleapis.com/auth/firebase.messaging scope, JWT 서명)
//   3) 각 token에 대해 FCM HTTP v1 endpoint로 POST. 실패한 token(404 등)은
//      device_tokens에서 즉시 정리 — 만료/무효 토큰 누적 방지.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create as createJwt, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const FCM_HOST = "https://fcm.googleapis.com";

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri: string;
}

let _cachedAccessToken: { token: string; exp: number } | null = null;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  // 내부 호출만 허용. INTERNAL_PUSH_TOKEN 시크릿을 호출자(트리거/EF)와 공유.
  const internalToken = Deno.env.get("INTERNAL_PUSH_TOKEN");
  if (internalToken) {
    const provided = req.headers.get("X-Internal-Token");
    if (provided !== internalToken) {
      return new Response("Forbidden", { status: 403 });
    }
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const userId = body["user_id"];
  const title = body["title"];
  const text = body["body"];
  const data = body["data"];
  if (typeof userId !== "string" || !userId) {
    return new Response("Missing user_id", { status: 400 });
  }
  if (typeof title !== "string" || typeof text !== "string") {
    return new Response("Missing title/body", { status: 400 });
  }

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) {
    return new Response("Server misconfigured (service key)", { status: 500 });
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(supabaseUrl, serviceKey);

  // 1) tokens
  const { data: rows, error } = await admin
    .from("device_tokens")
    .select("token, platform")
    .eq("user_id", userId);
  if (error) {
    console.error("device_tokens query failed", error);
    return new Response(`db error: ${error.message}`, { status: 500 });
  }
  if (!rows || rows.length === 0) {
    return new Response(JSON.stringify({ sent: 0, removed: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 2) access token
  const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!saRaw) {
    return new Response("FCM_SERVICE_ACCOUNT not set", { status: 500 });
  }
  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(saRaw);
  } catch {
    return new Response("FCM_SERVICE_ACCOUNT not valid JSON", { status: 500 });
  }
  let accessToken: string;
  try {
    accessToken = await getAccessToken(serviceAccount);
  } catch (e) {
    console.error("oauth token failed", e);
    return new Response(`oauth: ${(e as Error).message}`, { status: 500 });
  }

  // 3) send
  const fcmUrl =
    `${FCM_HOST}/v1/projects/${serviceAccount.project_id}/messages:send`;
  const dataPayload = data && typeof data === "object"
    ? Object.fromEntries(
      Object.entries(data as Record<string, unknown>).map(
        ([k, v]) => [k, typeof v === "string" ? v : JSON.stringify(v)],
      ),
    )
    : undefined;

  const deadTokens: string[] = [];
  let sent = 0;
  for (const row of rows) {
    const tokenStr = (row as { token: string }).token;
    const message = {
      message: {
        token: tokenStr,
        notification: { title, body: text },
        ...(dataPayload ? { data: dataPayload } : {}),
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "default" } },
        },
        android: {
          priority: "high",
          notification: { sound: "default" },
        },
      },
    };
    const resp = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    });
    if (resp.ok) {
      sent += 1;
      continue;
    }
    const respText = await resp.text();
    // FCM의 invalid/unregistered token 응답: 404 + "UNREGISTERED" 또는
    // "INVALID_ARGUMENT"+errorCode INVALID_REGISTRATION. 보수적으로 404/400
    // + "UNREGISTERED|INVALID" 패턴이면 정리.
    if (
      resp.status === 404 ||
      respText.includes("UNREGISTERED") ||
      respText.includes("Requested entity was not found")
    ) {
      deadTokens.push(tokenStr);
    } else {
      console.warn("fcm send failed", resp.status, respText);
    }
  }

  if (deadTokens.length > 0) {
    await admin.from("device_tokens").delete().in("token", deadTokens);
  }

  return new Response(
    JSON.stringify({ sent, removed: deadTokens.length }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (_cachedAccessToken && _cachedAccessToken.exp - 60 > now) {
    return _cachedAccessToken.token;
  }

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri,
    iat: getNumericDate(0),
    exp: getNumericDate(60 * 60), // 1h
  };

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const jwt = await createJwt(header as Parameters<typeof createJwt>[0], payload, key);

  const tokenResp = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!tokenResp.ok) {
    throw new Error(`token endpoint ${tokenResp.status}: ${await tokenResp.text()}`);
  }
  const tokenJson = await tokenResp.json() as {
    access_token: string;
    expires_in: number;
  };
  _cachedAccessToken = {
    token: tokenJson.access_token,
    exp: now + tokenJson.expires_in,
  };
  return tokenJson.access_token;
}

function pemToBytes(pem: string): ArrayBuffer {
  // service account JSON의 private_key는 BEGIN/END 줄 + base64 라인들. 헤더
  // 풋터 제거 + 줄바꿈 제거 후 base64 디코딩.
  const cleaned = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}
