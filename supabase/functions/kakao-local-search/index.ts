// kakao-local-search
//
// Authenticated client posts { query, locale?, limit? }.
// We call Kakao Local "keyword search" using a server-held REST API key,
// normalize results to the same shape as mapbox-geocode, and return them.
// Key never leaves the server.
//
// 국내(디바이스 region == KR) picker가 "국내" 모드일 때만 호출한다. Kakao는
// 한국 장소 데이터 품질이 Mapbox/Apple보다 월등하지만 데이터가 한국 한정이라
// "해외" 모드는 기존 mapbox-geocode 경로를 그대로 쓴다.
//
// Auth model:
//   verify_jwt is intentionally disabled (publishable key compatibility),
//   matching mapbox-geocode. Bearer header presence is the gate.
//
// Required env:
//   - KAKAO_REST_API_KEY   (Kakao Developers REST API key, NOT the native app key)

type Body = {
  query: string;
  locale?: string; // 'ko' / 'en' — country 라벨 표기에만 사용(검색 데이터는 한국어 고정)
  limit?: number; // default 10
};

type KakaoDoc = {
  id: string;
  place_name: string;
  address_name: string; // 지번 주소: "서울 강남구 역삼동 825"
  road_address_name: string; // 도로명 주소: "서울 강남구 강남대로 390"
  x: string; // longitude (문자열)
  y: string; // latitude (문자열)
};

type KakaoResp = { documents: KakaoDoc[] };

type Hit = {
  id: string;
  /// 장소명 (예: "스타벅스 강남R점").
  name: string;
  /// 시·도 + 시군구 (예: "서울 강남구"). 없으면 null.
  region: string | null;
  /// 국가. Kakao는 한국 데이터 한정이라 locale에 맞춰 고정 라벨.
  country: string | null;
  /// 도로명 주소 우선, 없으면 지번 주소.
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

  const key = Deno.env.get("KAKAO_REST_API_KEY");
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
  const size = Math.min(Math.max(body.limit ?? 10, 1), 15);

  const url =
    `https://dapi.kakao.com/v2/local/search/keyword.json` +
    `?query=${encodeURIComponent(query)}` +
    `&size=${size}`;

  const resp = await fetch(url, {
    headers: { Authorization: `KakaoAK ${key}` },
  });
  if (!resp.ok) {
    const detail = await resp.text();
    console.error("kakao local search failed", resp.status, detail);
    return new Response("Kakao error", { status: 502 });
  }

  const data = (await resp.json()) as KakaoResp;
  const country = locale.startsWith("ko") ? "대한민국" : "South Korea";
  const results: Hit[] = (data.documents ?? []).map((d) =>
    normalize(d, country)
  );

  return json({ results });
});

function normalize(d: KakaoDoc, country: string): Hit {
  const road = (d.road_address_name ?? "").trim();
  const jibun = (d.address_name ?? "").trim();
  const fullAddress = road.length > 0 ? road : jibun;

  // region: 지번 주소 앞 2토큰 "시/도 시군구" (예: "서울 강남구", "경기 성남시").
  // POI 타일 line2에 자연스럽게 들어가는 단위.
  let region: string | null = null;
  const parts = jibun.split(/\s+/).filter((p) => p.length > 0);
  if (parts.length >= 2) {
    region = `${parts[0]} ${parts[1]}`;
  } else if (parts.length === 1) {
    region = parts[0];
  }

  return {
    // mapbox 'poi.123' / apple 합성 id와 충돌 없게 소스 prefix.
    id: `kakao|${d.id}`,
    name: d.place_name,
    region,
    country,
    full_address: fullAddress.length > 0 ? fullAddress : d.place_name,
    lat: Number(d.y),
    lng: Number(d.x),
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
