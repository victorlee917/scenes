// spotify-search
//
// Authenticated client posts { query, locale?, limit? }.
// We call Spotify /v1/search with type=track,album using a server-held
// client credentials token, normalize results, and return them.
// Spotify client_id/secret never leave the server.
//
// Auth model:
//   verify_jwt is intentionally disabled because the project uses the new
//   `sb_publishable_...` key format which is not a JWT. We require any
//   Bearer token (publishable key or user session JWT). Once user auth is
//   wired up, switch verify_jwt back to true.
//
// Required env (set via `supabase secrets set ...`):
//   - SPOTIFY_CLIENT_ID
//   - SPOTIFY_CLIENT_SECRET
//
// Caching policy:
//   Spotify TOS forbids storing album art / metadata. We return CDN URLs
//   and Spotify URIs / external URLs only. Clients must NOT save the
//   image bytes; render directly from CDN.

type Body = {
  query: string;
  locale?: string;     // 'en' / 'ko' — affects market parameter
  limit?: number;      // default 10 per type (so up to 20 total)
};

type SpotifyImage = { url: string; width: number; height: number };
type SpotifyArtist = { name: string };
type SpotifyAlbumLite = {
  id: string;
  name: string;
  release_date: string;
  images: SpotifyImage[];
  artists: SpotifyArtist[];
  external_urls: { spotify?: string };
  uri: string;
};
type SpotifyTrack = {
  id: string;
  name: string;
  artists: SpotifyArtist[];
  album: SpotifyAlbumLite;
  external_urls: { spotify?: string };
  uri: string;
};
type SpotifySearchResp = {
  tracks?: { items: SpotifyTrack[] };
  albums?: { items: SpotifyAlbumLite[] };
};

type Hit = {
  kind: "track" | "album";
  id: string;
  title: string;
  artist: string;
  /// track인 경우 앨범 이름, album인 경우 null.
  album: string | null;
  /// release_date에서 추출한 'YYYY'. 없으면 null.
  year: string | null;
  /// Spotify CDN의 커버 이미지. 캐싱 금지 (TOS).
  cover_url: string | null;
  /// 클라가 Spotify 앱/웹으로 바로 보낼 때 사용.
  spotify_uri: string;
  external_url: string | null;
};

// ── Token cache (function instance lifetime) ─────────────────
//
// Spotify access token은 1시간 유효. Edge Function 인스턴스가 살아있는
// 동안 메모리 캐시. cold start 시 새 토큰 발급.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt > now + 30_000) {
    return cachedToken.value;
  }

  const clientId = Deno.env.get("SPOTIFY_CLIENT_ID");
  const clientSecret = Deno.env.get("SPOTIFY_CLIENT_SECRET");
  if (!clientId || !clientSecret) {
    throw new Error("SPOTIFY_CLIENT_ID/SECRET not configured");
  }

  const basic = btoa(`${clientId}:${clientSecret}`);
  const resp = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      "Authorization": `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`Spotify token fetch failed: ${resp.status} ${detail}`);
  }
  const data = (await resp.json()) as {
    access_token: string;
    expires_in: number;
  };
  cachedToken = {
    value: data.access_token,
    expiresAt: now + data.expires_in * 1000,
  };
  return cachedToken.value;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return new Response("Bad Request", { status: 400 });
  }

  const query = (body.query ?? "").trim();
  if (!query) {
    return json({ results: [] });
  }
  const locale = body.locale ?? "en";
  const limit = Math.min(Math.max(body.limit ?? 10, 1), 20);

  let token: string;
  try {
    token = await getAccessToken();
  } catch (e) {
    console.error(e);
    return new Response("Server misconfigured", { status: 500 });
  }

  // market은 'KR' / 'US' 등 ISO 3166-1 코드. locale 첫 두 글자가
  // language code라서 나라 코드는 별도 매핑.
  const market = locale.startsWith("ko") ? "KR" : "US";

  const url = `https://api.spotify.com/v1/search` +
    `?q=${encodeURIComponent(query)}` +
    `&type=track,album` +
    `&market=${market}` +
    `&limit=${limit}`;

  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
  });

  if (!resp.ok) {
    const detail = await resp.text();
    console.error("spotify search failed", resp.status, detail);
    return new Response("Spotify error", { status: 502 });
  }

  const data = (await resp.json()) as SpotifySearchResp;

  const trackHits: Hit[] = (data.tracks?.items ?? []).map(normalizeTrack);
  const albumHits: Hit[] = (data.albums?.items ?? []).map(normalizeAlbum);

  // 단순 interleave: track ↔ album 번갈아 끼워 넣어 두 종류가 골고루 보이게.
  const results: Hit[] = [];
  const max = Math.max(trackHits.length, albumHits.length);
  for (let i = 0; i < max; i++) {
    if (i < trackHits.length) results.push(trackHits[i]);
    if (i < albumHits.length) results.push(albumHits[i]);
  }

  return json({ results });
});

function normalizeTrack(t: SpotifyTrack): Hit {
  return {
    kind: "track",
    id: t.id,
    title: t.name,
    artist: t.artists.map((a) => a.name).join(", "),
    album: t.album?.name ?? null,
    year: yearOf(t.album?.release_date),
    cover_url: pickImage(t.album?.images),
    spotify_uri: t.uri,
    external_url: t.external_urls?.spotify ?? null,
  };
}

function normalizeAlbum(a: SpotifyAlbumLite): Hit {
  return {
    kind: "album",
    id: a.id,
    title: a.name,
    artist: a.artists.map((ar) => ar.name).join(", "),
    album: null,
    year: yearOf(a.release_date),
    cover_url: pickImage(a.images),
    spotify_uri: a.uri,
    external_url: a.external_urls?.spotify ?? null,
  };
}

function yearOf(date?: string): string | null {
  if (!date || date.length < 4) return null;
  return date.substring(0, 4);
}

/// 가장 큰 이미지 URL을 고름. Spotify는 보통 640/300/64 세 사이즈를 줌.
/// 작은 썸네일에 600+ 다운받기 아까우니 300 근처(width 200~400)를 선호.
function pickImage(images?: SpotifyImage[]): string | null {
  if (!images || images.length === 0) return null;
  const mid = images.find((i) => i.width >= 200 && i.width <= 400);
  return mid?.url ?? images[0].url;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
