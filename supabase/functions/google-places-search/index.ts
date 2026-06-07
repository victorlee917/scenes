// google-places-search
//
// Authenticated client posts { query, locale?, limit? }.
// We call Google Places API (New) "Text Search" using a server-held API key,
// normalize results to the same shape as mapbox-geocode / kakao-local-search,
// and return them. Key never leaves the server.
//
// 해외(글로벌) 검색에서 Android(비 iOS) picker가 호출한다. iOS는 Apple Maps
// (locale 불일치 시 mapbox-geocode 폴백)을 그대로 쓰고, 국내 모드는
// kakao-local-search를 쓴다. 검색 소스가 무엇이든 결과는 PlaceHit로 정규화돼
// 다운스트림(picker/저장)은 출처를 모른다.
//
// Auth model:
//   verify_jwt is intentionally disabled (publishable key compatibility),
//   matching mapbox-geocode / kakao-local-search. Bearer header presence is
//   the gate. Tighten once user auth is wired.
//
// Required env:
//   - GOOGLE_PLACES_API_KEY   (Google Cloud key with "Places API (New)"
//                              enabled + billing; restrict by API/referrer)

type Body = {
  query: string;
  locale?: string; // 'ko' / 'en' — 결과 표기 언어 선호
  limit?: number; // default 10, max 20 (Places API 상한)
};

type LatLng = { latitude: number; longitude: number };

type AddressComponent = {
  longText?: string;
  shortText?: string;
  types?: string[];
};

type GooglePlace = {
  id: string;
  displayName?: { text?: string; languageCode?: string };
  formattedAddress?: string;
  location?: LatLng;
  addressComponents?: AddressComponent[];
};

type GoogleResp = { places?: GooglePlace[] };

type Hit = {
  id: string;
  /// 장소명. 보통 POI 이름 또는 도시명.
  name: string;
  /// 시·도/도시 등 중간 단계 위치. 없으면 null.
  region: string | null;
  /// 국가. 없으면 null.
  country: string | null;
  /// Google 원본 풀 주소.
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

  const key = Deno.env.get("GOOGLE_PLACES_API_KEY");
  if (!key) {
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
  const limit = Math.min(Math.max(body.limit ?? 10, 1), 20);
  // Places API (New)는 단일 languageCode만 받는다 (Mapbox의 'ko,en' 폴백 없음).
  const languageCode = locale.toLowerCase().startsWith("ko") ? "ko" : "en";

  // Text Search (New): POI/도시 등을 단일 호출로 좌표·주소까지 한 번에 반환 —
  // PlaceHit가 lat/lng를 요구하므로 Autocomplete(2-step) 대신 채택.
  const resp = await fetch(
    "https://places.googleapis.com/v1/places:searchText",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": key,
        // 비용·페이로드 최소화를 위해 필요한 필드만 요청.
        "X-Goog-FieldMask": [
          "places.id",
          "places.displayName",
          "places.formattedAddress",
          "places.location",
          "places.addressComponents",
        ].join(","),
      },
      body: JSON.stringify({
        textQuery: query,
        languageCode,
        maxResultCount: limit,
      }),
    },
  );

  if (!resp.ok) {
    const detail = await resp.text();
    console.error("google places searchText failed", resp.status, detail);
    return new Response("Google Places error", { status: 502 });
  }

  const data = (await resp.json()) as GoogleResp;
  const results: Hit[] = (data.places ?? [])
    .filter((p) => p.location && typeof p.id === "string")
    .map(normalize);

  return json({ results });
});

function normalize(p: GooglePlace): Hit {
  const name = p.displayName?.text ?? p.formattedAddress ?? "";

  // addressComponents에서 country + region(가장 작은 행정 단위 우선) 추출.
  let country: string | null = null;
  let locality: string | null = null;
  let adminArea: string | null = null;
  for (const c of p.addressComponents ?? []) {
    const types = c.types ?? [];
    const label = c.longText ?? c.shortText ?? null;
    if (!label) continue;
    if (types.includes("country")) {
      country = label;
    } else if (types.includes("locality") && locality === null) {
      locality = label;
    } else if (
      types.includes("administrative_area_level_1") && adminArea === null
    ) {
      adminArea = label;
    }
  }
  // 도시(locality) > 시·도(administrative_area_level_1) 순으로 가장 구체적인 것.
  const region = locality ?? adminArea;

  return {
    id: p.id,
    name,
    region,
    country,
    full_address: p.formattedAddress ?? "",
    lat: p.location!.latitude,
    lng: p.location!.longitude,
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
