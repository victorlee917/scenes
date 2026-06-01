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
    // language-specific 번역(예: text_en, text_ko)이 함께 내려옴.
    [key: string]: string | undefined;
  }>;
  // language-specific field: 같은 feature에 대해 Mapbox가 자동으로 추가해 줌.
  // 예: language=en이면 text_en/place_name_en가 같이 옴.
  [key: string]: unknown;
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
  // 응답을 원하는 언어로 재해석. query가 ko/en/ja 등 어떤 script로 들어와도
  // language preference 첫 번째에 맞춘 text를 반환 — Mapbox v5는 query 언어
  // 매치를 우선해서 `text`에 그 언어를 그대로 박는 경향이 있어, language-
  // specific 필드(text_en, place_name_en 등)를 강제로 읽음.
  const primaryLang = language.split(",")[0]; // 'en' 또는 'ko'
  const results: Hit[] = (data.features ?? []).map((f) =>
    normalize(f, primaryLang)
  );

  return json({ results });
});

function normalize(f: MapboxFeature, lang: string): Hit {
  // language-specific 필드가 있으면 우선. 없으면 일반 text/place_name fallback.
  const textKey = `text_${lang}`;
  const placeNameKey = `place_name_${lang}`;
  const localizedText = (f as Record<string, unknown>)[textKey];
  const localizedPlaceName = (f as Record<string, unknown>)[placeNameKey];
  const name = typeof localizedText === "string" && localizedText.length > 0
    ? localizedText
    : f.text;
  const fullAddress =
    typeof localizedPlaceName === "string" && localizedPlaceName.length > 0
      ? localizedPlaceName
      : f.place_name;

  // context 배열에서 region (place/region) + country 추출.
  // Mapbox context id 포맷: '<type>.<id>' — type만 있음. context 각 항목도
  // text_<lang> 번역을 가질 수 있으므로 동일하게 우선.
  let region: string | null = null;
  let country: string | null = null;
  for (const c of f.context ?? []) {
    const type = c.id.split(".")[0];
    const localized = c[textKey];
    const ctxText = typeof localized === "string" && localized.length > 0
      ? localized
      : c.text;
    if (type === "country") {
      country = ctxText;
    } else if (
      type === "region" || type === "place" || type === "district"
    ) {
      // 가장 작은 단위(place > district > region)를 우선.
      // place가 먼저 들어왔으면 그걸 유지, 아니면 그 다음 단계로.
      if (region === null) region = ctxText;
    }
  }

  return {
    id: f.id,
    name,
    region,
    country,
    full_address: fullAddress,
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
