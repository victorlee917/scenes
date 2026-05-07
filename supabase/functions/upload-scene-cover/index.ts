// upload-scene-cover
//
// Authenticated client posts JPEG bytes for a scene's cover image.
// Headers:
//   - Authorization: Bearer <user JWT>
//   - X-Scene-Id:    <scene UUID>
//   - Content-Type:  image/jpeg
//
// 1. Verify caller is a member of an active couple containing this scene.
// 2. Upload to scene_media/<pair_id>/<scene_id>/cover.jpg via service role
//    (bypasses publishable-key + storage RLS issue).
// 3. Update scenes.cover_storage_path.
// 4. Return { storage_path, signed_url } (1h signed URL).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }
  const sceneId = req.headers.get("X-Scene-Id");
  if (!sceneId) {
    return new Response("Missing X-Scene-Id", { status: 400 });
  }

  // 1) caller 검증 + scene 소속 pair_id 조회.
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

  // RLS 통한 scene 조회 — 내가 멤버가 아니면 row 안 나옴.
  const { data: sceneRow, error: sceneErr } = await userClient
    .from("scenes")
    .select("id, pair_id")
    .eq("id", sceneId)
    .maybeSingle();
  if (sceneErr || !sceneRow) {
    return new Response("Scene not found or no access", { status: 403 });
  }
  const pairId = sceneRow.pair_id as string;

  // 2) bytes.
  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.byteLength === 0) {
    return new Response("Empty body", { status: 400 });
  }

  // 3) service role로 upload + scenes UPDATE.
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) {
    return new Response("Server misconfigured", { status: 500 });
  }
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceKey,
  );

  const path = `${pairId}/${sceneId}/cover.jpg`;
  const { error: uploadError } = await adminClient.storage
    .from("scene_media")
    .upload(path, bytes, {
      contentType: "image/jpeg",
      upsert: true,
    });
  if (uploadError) {
    console.error("cover upload failed", uploadError);
    return new Response(`Upload failed: ${uploadError.message}`, {
      status: 500,
    });
  }

  await adminClient
    .from("scenes")
    .update({ cover_storage_path: path })
    .eq("id", sceneId);

  // 4) signed URL 1시간.
  const { data: signed, error: signErr } = await adminClient.storage
    .from("scene_media")
    .createSignedUrl(path, 3600);
  if (signErr || !signed) {
    return new Response(`Sign URL failed: ${signErr?.message ?? "unknown"}`, {
      status: 500,
    });
  }

  return new Response(
    JSON.stringify({
      storage_path: path,
      signed_url: signed.signedUrl,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
