// tmdb-search
//
// Authenticated client posts { query, locale? }.
// We call TMDB /search/multi with a server-held key, filter to movie/tv,
// and return a normalized list. TMDB key never leaves the server.
//
// Auth model:
//   verify_jwt is intentionally disabled because the project uses the new
//   `sb_publishable_...` key format which is not a JWT. Instead, we require
//   any Bearer token (publishable key or user session JWT). Once user auth
//   is wired up, switch verify_jwt back to true.
//
// Required env (set via `supabase secrets set ...`):
//   - TMDB_READ_ACCESS_TOKEN    (v4 read access token; see https://www.themoviedb.org/settings/api)

type Body = {
  query: string;
  locale?: string;     // default 'en-US'
  page?: number;       // default 1
};

type TmdbMultiResult = {
  id: number;
  media_type: "movie" | "tv" | "person";
  title?: string;          // movie
  name?: string;           // tv
  release_date?: string;   // movie
  first_air_date?: string; // tv
  poster_path?: string | null;
  overview?: string;
  popularity?: number;
};

type TmdbMultiResponse = {
  results: TmdbMultiResult[];
};

type FilmHit = {
  tmdb_id: number;
  media_type: "movie" | "tv";
  title: string;
  year: string | null;
  /// 검색 화면에서 즉시 표시할 작은 포스터 URL (w342). null이면 포스터 없음.
  poster_url: string | null;
  /// TMDB raw path. 사용자가 영화를 선택해 캐싱할 때 원하는 사이즈(w780 등)
  /// 로 다시 빌드하기 위함. null이면 포스터 자체 없음.
  poster_path: string | null;
  /// 영화는 Director, TV는 Creator. 여러 명이면 `, `로 join. 없으면 null.
  director: string | null;
  /// 장르명 배열 (예: ["Drama", "Romance"]). 비어있으면 [].
  genres: string[];
  /// 러닝타임(분). 영화는 단편 길이, TV는 평균 에피소드 길이. null이면 미정.
  runtime: number | null;
  overview: string;
  popularity: number;
};

type TmdbGenre = { id: number; name: string };
type TmdbCrewMember = { job: string; name: string };
type TmdbMovieDetail = {
  genres?: TmdbGenre[];
  runtime?: number | null;
  credits?: { crew?: TmdbCrewMember[] };
};
type TmdbCreator = { name: string };
type TmdbTvDetail = {
  genres?: TmdbGenre[];
  episode_run_time?: number[];
  created_by?: TmdbCreator[];
};

/// 검색 결과 picker에서 보여주는 포스터 사이즈. 작은 썸네일이라 w342면 충분.
/// 영구 캐싱은 별도 Edge Function(`tmdb-poster-cache`)에서 w780으로 저장 예정.
const POSTER_BASE = "https://image.tmdb.org/t/p/w342";

/// 검색당 director/creator 추가 조회할 최대 결과 개수.
/// TMDB 호출 비용 통제 + 사용자가 보통 상위 결과만 보는 패턴 고려.
const DIRECTOR_FETCH_LIMIT = 20;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }

  const apiKey = Deno.env.get("TMDB_READ_ACCESS_TOKEN");
  if (!apiKey) {
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
  const locale = body.locale ?? "en-US";
  const page = body.page ?? 1;

  const tmdbUrl =
    `https://api.themoviedb.org/3/search/multi` +
    `?query=${encodeURIComponent(query)}` +
    `&language=${encodeURIComponent(locale)}` +
    `&include_adult=false&page=${page}`;

  const tmdbResp = await fetch(tmdbUrl, {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      Accept: "application/json",
    },
  });

  if (!tmdbResp.ok) {
    const detail = await tmdbResp.text();
    console.error("tmdb fetch failed", tmdbResp.status, detail);
    return new Response("TMDB error", { status: 502 });
  }

  const data = (await tmdbResp.json()) as TmdbMultiResponse;

  const baseResults: FilmHit[] = (data.results ?? [])
    .filter((r) => r.media_type === "movie" || r.media_type === "tv")
    .map((r) => normalize(r))
    .filter((r): r is FilmHit => r !== null)
    // popularity desc — TMDB usually returns this order, but normalize defensively.
    .sort((a, b) => b.popularity - a.popularity);

  // 상위 N개에 한해 director/creator 정보 병렬 조회.
  const toEnrich = baseResults.slice(0, DIRECTOR_FETCH_LIMIT);
  const enriched = await Promise.all(
    toEnrich.map((hit) => attachDetails(hit, apiKey, locale)),
  );
  const results: FilmHit[] = [
    ...enriched,
    ...baseResults.slice(DIRECTOR_FETCH_LIMIT),
  ];

  return json({ results });
});

/// detail + credits를 한 번에 가져와 director/genres/runtime 채움.
/// `append_to_response=credits`로 호출 한 번에 합침.
async function attachDetails(
  hit: FilmHit,
  apiKey: string,
  locale: string,
): Promise<FilmHit> {
  try {
    if (hit.media_type === "movie") {
      const url =
        `https://api.themoviedb.org/3/movie/${hit.tmdb_id}` +
        `?language=${encodeURIComponent(locale)}` +
        `&append_to_response=credits`;
      const resp = await fetch(url, {
        headers: { Authorization: `Bearer ${apiKey}`, Accept: "application/json" },
      });
      if (!resp.ok) return hit;
      const detail = (await resp.json()) as TmdbMovieDetail;
      const directors = (detail.credits?.crew ?? [])
        .filter((c) => c.job === "Director")
        .map((c) => c.name);
      return {
        ...hit,
        director: directors.length > 0 ? directors.join(", ") : null,
        genres: (detail.genres ?? []).map((g) => g.name),
        runtime: detail.runtime ?? null,
      };
    } else {
      // TV: detail에 genres/episode_run_time/created_by가 모두 있음. credits 불필요.
      const url =
        `https://api.themoviedb.org/3/tv/${hit.tmdb_id}` +
        `?language=${encodeURIComponent(locale)}`;
      const resp = await fetch(url, {
        headers: { Authorization: `Bearer ${apiKey}`, Accept: "application/json" },
      });
      if (!resp.ok) return hit;
      const detail = (await resp.json()) as TmdbTvDetail;
      const creators = (detail.created_by ?? []).map((c) => c.name);
      // episode_run_time은 배열인데 보통 첫 값(typical episode length) 사용.
      const runtime = detail.episode_run_time && detail.episode_run_time.length > 0
        ? detail.episode_run_time[0]
        : null;
      return {
        ...hit,
        director: creators.length > 0 ? creators.join(", ") : null,
        genres: (detail.genres ?? []).map((g) => g.name),
        runtime,
      };
    }
  } catch (e) {
    console.error("attachDetails failed", hit.tmdb_id, e);
    return hit;
  }
}

function normalize(r: TmdbMultiResult): FilmHit | null {
  const isMovie = r.media_type === "movie";
  const title = isMovie ? r.title : r.name;
  if (!title) return null;
  const date = isMovie ? r.release_date : r.first_air_date;
  const year = date && date.length >= 4 ? date.substring(0, 4) : null;
  const posterUrl = r.poster_path ? `${POSTER_BASE}${r.poster_path}` : null;

  return {
    tmdb_id: r.id,
    media_type: isMovie ? "movie" : "tv",
    title,
    year,
    poster_url: posterUrl,
    poster_path: r.poster_path ?? null,
    director: null, // attachDetails에서 채움
    genres: [],
    runtime: null,
    overview: r.overview ?? "",
    popularity: r.popularity ?? 0,
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
