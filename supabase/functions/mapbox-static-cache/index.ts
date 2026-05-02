// mapbox-static-cache
//
// Authenticated client posts { pair_id, scene_id, content_id, lat, lng, zoom? }.
// We:
//   1. Verify caller is in the active couple of pair_id (so they're allowed
//      to write to that scene_media path under 0018/0019 RLS).
//   2. Generate a MapBox Static Maps PNG using a server-held token.
//   3. Upload to scene_media/<pair_id>/<scene_id>/maps/<content_id>.png
//      with the caller's auth (so storage RLS approves the write).
//   4. Return the storage_path (client persists into contents.payload).
//
// MapBox token never leaves the server. The function honors active-couple
// gating by relying on the storage RLS for the uploadBinary call.
//
// Required env (set via `supabase secrets set ...`):
//   - MAPBOX_TOKEN              (secret token from MapBox account)
//   - SUPABASE_URL              (auto-injected)
//   - SUPABASE_ANON_KEY         (auto-injected, for caller-context client)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Body = {
  pair_id: string;
  scene_id: string;
  content_id: string;
  lat: number;
  lng: number;
  zoom?: number;     // default 14
  width?: number;    // default 600
  height?: number;   // default 400
  style?: string;    // default mapbox/streets-v12
};

const MAX_DIM = 1280;

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

  const {
    pair_id,
    scene_id,
    content_id,
    lat,
    lng,
    zoom = 14,
    width = 600,
    height = 400,
    style = "mapbox/streets-v12",
  } = body;

  if (
    !pair_id || !scene_id || !content_id ||
    typeof lat !== "number" || typeof lng !== "number"
  ) {
    return new Response("Missing fields", { status: 400 });
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return new Response("Invalid coords", { status: 400 });
  }
  if (width > MAX_DIM || height > MAX_DIM || width < 1 || height < 1) {
    return new Response("Invalid dimensions", { status: 400 });
  }

  // Build MapBox Static Maps URL: pin + center
  const overlay = `pin-l+555555(${lng},${lat})`;
  const mapboxUrl =
    `https://api.mapbox.com/styles/v1/${style}/static/` +
    `${overlay}/${lng},${lat},${zoom}/${width}x${height}@2x` +
    `?access_token=${token}`;

  const mapResp = await fetch(mapboxUrl);
  if (!mapResp.ok) {
    const detail = await mapResp.text();
    console.error("mapbox fetch failed", mapResp.status, detail);
    return new Response("MapBox error", { status: 502 });
  }
  const pngBytes = new Uint8Array(await mapResp.arrayBuffer());

  // Upload using the caller's JWT so storage RLS (active couple) applies.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      auth: { persistSession: false },
      global: { headers: { Authorization: authHeader } },
    },
  );

  const path = `${pair_id}/${scene_id}/maps/${content_id}.png`;

  const { error: uploadError } = await supabase.storage
    .from("scene_media")
    .uploadBinary(path, pngBytes, {
      contentType: "image/png",
      upsert: true,
    });

  if (uploadError) {
    console.error("storage upload failed", uploadError);
    return new Response(`Upload failed: ${uploadError.message}`, {
      status: 403,
    });
  }

  return new Response(
    JSON.stringify({ storage_path: path }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
