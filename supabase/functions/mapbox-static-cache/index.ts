// mapbox-static-cache
//
// Authenticated client posts place metadata. We:
//   1. Verify caller (JWT) + resolve scene → pair_id under user RLS.
//   2. Allocate content_id, generate a MapBox Static Maps PNG (1200×1200,
//      @2x retina, zoom 14, streets style + center pin).
//   3. Service-role upload to scene_media/<pair>/<scene>/<content_id>/map.png.
//   4. Insert contents row (type='place', payload merged with storage path).
//   5. Return inserted row + signed URL.
//
// Aborts: req.signal handled stage-by-stage with rollback so client/network
// drops don't leave orphan storage objects or DB rows (photo/film pattern).
//
// Attribution: we keep MapBox's default `attribution=true` so © Mapbox / © OSM
// stays baked into the image. Scene detail grid covers that area with our own
// place-name label overlay; content viewer (full map) shows it naturally.
//
// JSON body:
//   {
//     scene_id:    "<UUID>",
//     external_id: "poi.123" | null,
//     name:        "Tokyo Tower",
//     region:      "Tokyo" | null,
//     country:     "Japan" | null,
//     address:     "4-2-8 Shibakoen..." | null,
//     lat:         35.6586,
//     lng:         139.7454
//   }
//
// Required env: MAPBOX_TOKEN, SUPABASE_URL, SUPABASE_ANON_KEY,
//               SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ZOOM = 14;
const SIZE = 600; // 600×600 @2x → 1200×1200 PNG (~150 KiB typical)
const STYLE = "mapbox/streets-v12";

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

  const mapboxToken = Deno.env.get("MAPBOX_TOKEN");
  if (!mapboxToken) {
    return new Response("Server misconfigured (mapbox)", { status: 500 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const sceneId = body["scene_id"];
  const name = body["name"];
  const lat = body["lat"];
  const lng = body["lng"];
  if (typeof sceneId !== "string" || !sceneId) {
    return new Response("Missing scene_id", { status: 400 });
  }
  if (typeof name !== "string" || !name) {
    return new Response("Missing name", { status: 400 });
  }
  if (typeof lat !== "number" || typeof lng !== "number") {
    return new Response("Missing lat/lng", { status: 400 });
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return new Response("Invalid coords", { status: 400 });
  }

  const externalId = typeof body["external_id"] === "string"
    ? body["external_id"]
    : null;
  const region = typeof body["region"] === "string" ? body["region"] : null;
  const country = typeof body["country"] === "string" ? body["country"] : null;
  const address = typeof body["address"] === "string" ? body["address"] : null;
  // 사용자가 picker에서 고른 모먼트 날짜. ISO string.
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
  const storagePath = `${pairId}/${sceneId}/${contentId}/map.png`;

  // 3) Generate MapBox static map. pin-l in muted gray so attribution doesn't
  // dominate; @2x retina for crisp display on any iPhone tile size.
  const overlay = `pin-l+555555(${lng},${lat})`;
  const mapboxUrl =
    `https://api.mapbox.com/styles/v1/${STYLE}/static/` +
    `${overlay}/${lng},${lat},${ZOOM}/${SIZE}x${SIZE}@2x` +
    `?access_token=${mapboxToken}`;

  const mapResp = await fetch(mapboxUrl);
  if (!mapResp.ok) {
    const detail = await mapResp.text();
    console.error("mapbox fetch failed", mapResp.status, detail);
    return new Response("MapBox error", { status: 502 });
  }
  const pngBytes = new Uint8Array(await mapResp.arrayBuffer());
  // PNG magic — 0x89 0x50 0x4E 0x47.
  if (
    pngBytes.length < 4 ||
    pngBytes[0] !== 0x89 || pngBytes[1] !== 0x50 ||
    pngBytes[2] !== 0x4e || pngBytes[3] !== 0x47
  ) {
    console.error("mapbox response not PNG", pngBytes.length);
    return new Response("MapBox returned non-PNG", { status: 502 });
  }

  if (aborted()) return abortedResponse();

  // 4) Service-role storage upload + rollback helpers.
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) {
    return new Response("Server misconfigured (service key)", { status: 500 });
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

  const up = await adminClient.storage
    .from("scene_media")
    .upload(storagePath, pngBytes, {
      contentType: "image/png",
      upsert: true,
    });
  if (up.error) {
    console.error("storage upload failed", up.error);
    return new Response(`Upload failed: ${up.error.message}`, { status: 500 });
  }
  if (aborted()) {
    await removeStorage([storagePath]);
    return abortedResponse();
  }

  // 5) Insert contents row.
  const payload: Record<string, unknown> = {
    service: "mapbox",
    external_id: externalId,
    name,
    region,
    country,
    address,
    lat,
    lng,
    mapbox_static_storage_path: storagePath,
  };

  const { data: inserted, error: insertErr } = await adminClient
    .from("contents")
    .insert({
      id: contentId,
      scene_id: sceneId,
      type: "place",
      payload,
      occurred_at: occurredAt,
      created_by: userId,
    })
    .select()
    .single();
  if (insertErr || !inserted) {
    await removeStorage([storagePath]);
    console.error("contents insert failed", insertErr);
    return new Response(
      `Insert failed: ${insertErr?.message ?? "unknown"}`,
      { status: 500 },
    );
  }
  if (aborted()) {
    await removeRow();
    await removeStorage([storagePath]);
    return abortedResponse();
  }

  // 6) Sign URL (1h).
  const { data: signed } = await adminClient.storage
    .from("scene_media")
    .createSignedUrl(storagePath, 3600);

  return new Response(
    JSON.stringify({
      content: inserted,
      map_signed_url: signed?.signedUrl ?? null,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
