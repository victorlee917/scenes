// mapbox-geocode
//
// Authenticated client posts { query, locale?, limit? }.
// We call Mapbox Geocoding (forward) using a server-held token,
// normalize results, and return them. Token never leaves the server.
//
// Auth model:
//   verify_jwt is intentionally disabled (publishable key compatibility).
//   Bearer header presence is the gate. Tighten once user auth is wired.
//
// Required env:
//   - MAPBOX_TOKEN       (Mapbox access token)

type Body = {
  query: string;
  locale?: string;     // 'ko' / 'en' — geocoding language preference
  limit?: number;      // default 10
};

type MapboxFeature = {
  id: string;
  text: string;
  place_name: string;
  center: [number, number]; // [lng, lat]
  place_type?: string[];
  context?: Array<{
    id: string;        // e.g., 'place.123', 'region.456', 'country.789'
    text: string;
  }>;
};

type MapboxResp = { features: MapboxFeature[] };

type Hit = {
  id: string;
  /// 장소명. 보통 POI 이름 또는 도시명.
  name: string;
  /// 시·도 등 중간 단계 위치. 없으면 null.
  region: string | null;
  /// 국가. 없으면 null.
  country: string | null;
  /// Mapbox 원본 풀 주소 (여러 줄 합친 형태).
  full_address: string;
  lat: number;
  lng: number;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }

  const token = Deno.env.get("MAPBOX_TOKEN");
  if (!token) {
    return new Response("Server misconfigured", { status: 500 });
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
  const limit = Math.min(Math.max(body.limit ?? 10, 1), 10);

  // Mapbox supports comma-separated language preferences. ko 디바이스는
  // ko 우선, 못 찾으면 en 폴백. 그 외는 en만.
  const language = locale.startsWith("ko") ? "ko,en" : "en";

  const url =
    `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(query)}.json` +
    `?access_token=${token}` +
    `&limit=${limit}` +
    `&language=${encodeURIComponent(language)}`;

  const resp = await fetch(url);
  if (!resp.ok) {
    const detail = await resp.text();
    console.error("mapbox geocode failed", resp.status, detail);
    return new Response("Mapbox error", { status: 502 });
  }

  const data = (await resp.json()) as MapboxResp;
  const results: Hit[] = (data.features ?? []).map(normalize);

  return json({ results });
});

function normalize(f: MapboxFeature): Hit {
  // context 배열에서 region (place/region) + country 추출.
  // Mapbox context id 포맷: '<type>.<id>' — type만 있음.
  let region: string | null = null;
  let country: string | null = null;
  for (const c of f.context ?? []) {
    const type = c.id.split(".")[0];
    if (type === "country") {
      country = c.text;
    } else if (
      type === "region" || type === "place" || type === "district"
    ) {
      // 가장 작은 단위(place > district > region)를 우선.
      // place가 먼저 들어왔으면 그걸 유지, 아니면 그 다음 단계로.
      if (region === null) region = c.text;
    }
  }

  return {
    id: f.id,
    name: f.text,
    region,
    country,
    full_address: f.place_name,
    lat: f.center[1],
    lng: f.center[0],
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
