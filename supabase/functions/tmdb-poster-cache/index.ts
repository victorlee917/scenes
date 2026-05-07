// tmdb-poster-cache
//
// Authenticated client posts film metadata + TMDB raw poster_path. We fetch
// the w780 poster from TMDB ourselves, cache it in scene_media, and insert
// a contents row of type='film'. TMDB read token never leaves the server,
// and the bytes are committed via service-role (matches photo upload pattern).
//
// JSON body:
//   {
//     scene_id:     "<UUID>",
//     tmdb_id:      27205,
//     media_type:   "movie" | "tv",
//     title:        "Inception",
//     release_year: 2010 | null,
//     director:     "Christopher Nolan" | null,   // 영화 Director / TV Creator
//     genres:       ["Action", "Sci-Fi"],         // [] OK
//     runtime:      148 | null,                    // 분
//     overview:     "..." (optional),
//     poster_path:  "/abc.jpg" | null              // TMDB raw path; null이면 캐싱 skip
//   }
//
// Headers:
//   - Authorization: Bearer <user JWT>
//
// Pipeline:
//   1. Verify caller (JWT) and resolve scene → pair_id under user RLS.
//   2. Allocate content_id.
//   3. If poster_path 존재: TMDB CDN에서 w780 다운로드 → magic-byte 검증.
//      실패하면 row는 만들되 poster_storage_path는 null로 둠 (poster_source_url
//      fallback로 표시 가능).
//   4. Service-role로 scene_media/<pair>/<scene>/<content_id>/poster.jpg 업로드.
//   5. Insert contents row (type='film', payload merged with paths).
//   6. Return inserted row + signed poster URL.
//
// Abort handling: photo EF와 동일 — req.signal.aborted 단계별 가드 + rollback.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TMDB_POSTER_BASE = "https://image.tmdb.org/t/p/w780";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const aborted = () => req.signal.aborted;
  const abortedResponse = () =>
    new Response("Client Closed Request", { status: 499 });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  // Validate required fields.
  const sceneId = body["scene_id"];
  const tmdbId = body["tmdb_id"];
  const mediaType = body["media_type"];
  const title = body["title"];
  if (typeof sceneId !== "string" || !sceneId) {
    return new Response("Missing scene_id", { status: 400 });
  }
  if (typeof tmdbId !== "number" || !Number.isFinite(tmdbId)) {
    return new Response("Missing tmdb_id", { status: 400 });
  }
  if (mediaType !== "movie" && mediaType !== "tv") {
    return new Response("Invalid media_type", { status: 400 });
  }
  if (typeof title !== "string" || !title) {
    return new Response("Missing title", { status: 400 });
  }

  const releaseYear = typeof body["release_year"] === "number"
    ? body["release_year"]
    : null;
  const director = typeof body["director"] === "string" ? body["director"] : null;
  const genresRaw = body["genres"];
  const genres = Array.isArray(genresRaw)
    ? genresRaw.filter((g): g is string => typeof g === "string")
    : [];
  const runtime = typeof body["runtime"] === "number" ? body["runtime"] : null;
  const overview = typeof body["overview"] === "string" ? body["overview"] : "";
  const posterPath = typeof body["poster_path"] === "string"
    ? body["poster_path"]
    : null;
  // 사용자가 picker에서 고른 모먼트 날짜. ISO string. 미지정이면 null로 둠.
  const occurredAt = typeof body["occurred_at"] === "string"
    ? body["occurred_at"]
    : null;

  // 1) Verify caller + resolve scene's pair_id under their RLS.
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      auth: { persistSession: false },
      global: { headers: { Authorization: authHeader } },
    },
  );
  const { data: userRes, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userRes?.user) {
    return new Response("Unauthorized", { status: 401 });
  }
  const userId = userRes.user.id;

  const { data: sceneRow, error: sceneErr } = await userClient
    .from("scenes")
    .select("id, pair_id")
    .eq("id", sceneId)
    .maybeSingle();
  if (sceneErr || !sceneRow) {
    return new Response("Scene not found or no access", { status: 403 });
  }
  const pairId = sceneRow.pair_id as string;

  if (aborted()) return abortedResponse();

  // 2) Allocate content_id, build storage path.
  const contentId = crypto.randomUUID();
  const posterStoragePath = `${pairId}/${sceneId}/${contentId}/poster.jpg`;
  const posterSourceUrl = posterPath ? `${TMDB_POSTER_BASE}${posterPath}` : null;

  // 3) Download poster from TMDB (best-effort). 실패해도 row는 만들고 source_url로 fallback 가능.
  let posterBytes: Uint8Array | null = null;
  if (posterSourceUrl) {
    try {
      const resp = await fetch(posterSourceUrl);
      if (resp.ok) {
        const buf = new Uint8Array(await resp.arrayBuffer());
        // JPEG magic-byte 검증 (TMDB는 기본 jpg).
        if (
          buf.byteLength >= 3 &&
          buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff
        ) {
          posterBytes = buf;
        } else {
          console.warn("tmdb poster magic byte mismatch", posterSourceUrl);
        }
      } else {
        console.warn("tmdb poster fetch non-200", resp.status, posterSourceUrl);
      }
    } catch (e) {
      console.warn("tmdb poster fetch failed", posterSourceUrl, e);
    }
  }

  if (aborted()) return abortedResponse();

  // 4) Service-role storage upload (only if we got bytes).
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) {
    return new Response("Server misconfigured", { status: 500 });
  }
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceKey,
  );

  const removeStorage = async (paths: string[]) => {
    try {
      await adminClient.storage.from("scene_media").remove(paths);
    } catch (e) {
      console.warn("rollback storage remove failed", paths, e);
    }
  };
  const removeRow = async () => {
    try {
      await adminClient.from("contents").delete().eq("id", contentId);
    } catch (e) {
      console.warn("rollback contents delete failed", contentId, e);
    }
  };

  let cachedStoragePath: string | null = null;
  if (posterBytes) {
    const up = await adminClient.storage
      .from("scene_media")
      .upload(posterStoragePath, posterBytes, {
        contentType: "image/jpeg",
        upsert: true,
      });
    if (up.error) {
      // 캐싱 실패해도 row는 만든다 — poster_source_url fallback이 있어서 표시 가능.
      console.warn("poster cache upload failed", up.error);
    } else {
      cachedStoragePath = posterStoragePath;
    }
    if (aborted()) {
      if (cachedStoragePath) await removeStorage([cachedStoragePath]);
      return abortedResponse();
    }
  }

  // 5) Insert contents row.
  const payload: Record<string, unknown> = {
    tmdb_id: tmdbId,
    media_type: mediaType,
    title,
    release_year: releaseYear,
    director,
    genres,
    runtime,
    overview,
    poster_storage_path: cachedStoragePath,
    poster_source_url: posterSourceUrl,
  };

  const { data: inserted, error: insertErr } = await adminClient
    .from("contents")
    .insert({
      id: contentId,
      scene_id: sceneId,
      type: "film",
      payload,
      occurred_at: occurredAt,
      created_by: userId,
    })
    .select()
    .single();
  if (insertErr || !inserted) {
    if (cachedStoragePath) await removeStorage([cachedStoragePath]);
    console.error("contents insert failed", insertErr);
    return new Response(
      `Insert failed: ${insertErr?.message ?? "unknown"}`,
      { status: 500 },
    );
  }
  if (aborted()) {
    await removeRow();
    if (cachedStoragePath) await removeStorage([cachedStoragePath]);
    return abortedResponse();
  }

  // 6) Sign URL (poster 캐싱 성공한 경우만).
  let posterSignedUrl: string | null = null;
  if (cachedStoragePath) {
    const { data: signed } = await adminClient.storage
      .from("scene_media")
      .createSignedUrl(cachedStoragePath, 3600);
    posterSignedUrl = signed?.signedUrl ?? null;
  }

  return new Response(
    JSON.stringify({
      content: inserted,
      poster_signed_url: posterSignedUrl,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
