// upload-photo-content
//
// Authenticated client uploads two JPEG variants for a single photo content
// row in one multipart-form-data request. Two files because grid views need
// a small thumbnail to render snappily while detail/play screens use the
// full-quality variant.
//
// Multipart fields:
//   - scene_id: <UUID>
//   - payload:  JSON string with width/height/taken_at/lat/lng/exif (any
//               subset; missing fields just omitted from contents.payload)
//   - full:     image/jpeg bytes (display variant; size capped per tier
//               by storage RLS — 5 MiB free pair / 50 MiB HD pair)
//   - thumb:    image/jpeg bytes (~600px short edge, used in grids/lists)
//
// Headers:
//   - Authorization: Bearer <user JWT>
//
// Pipeline:
//   1. Verify caller via JWT.
//   2. Resolve scene → pair_id via user-scoped client (RLS enforces
//      caller is a member of an active couple owning the scene).
//   3. Allocate content_id.
//   4. Upload both bytes via service-role to:
//        scene_media/<pair_id>/<scene_id>/<content_id>/full.jpg
//        scene_media/<pair_id>/<scene_id>/<content_id>/thumb.jpg
//   5. Insert contents row (type='photo', payload merged with storage paths,
//      occurred_at = payload.taken_at if present).
//   6. Return the inserted row + signed URLs (1h).
//
// Abort handling:
//   Client disconnects (user-cancel via http.Client.close, app force-quit,
//   network drop) all manifest as req.signal.aborted. We check between each
//   step and rollback any partial side effects so the DB/storage stay
//   consistent regardless of where the cancellation happened. The storage
//   SDK doesn't accept an AbortSignal, so the in-flight call itself can't be
//   cut — we let it finish and clean up after.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  // 클라이언트 연결이 끊겼는지 체크용. 끊긴 뒤에는 응답이 가지는 않지만
  // 499로 답해 로그/대조에 의도가 명시적으로 남게 한다.
  const aborted = () => req.signal.aborted;
  const abortedResponse = () =>
    new Response("Client Closed Request", { status: 499 });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Parse multipart.
  let form: FormData;
  try {
    form = await req.formData();
  } catch (e) {
    return new Response(`Invalid multipart body: ${e}`, { status: 400 });
  }

  const sceneId = form.get("scene_id");
  const payloadRaw = form.get("payload");
  const fullFile = form.get("full");
  const thumbFile = form.get("thumb");
  // 사용자가 picker에서 명시적으로 고른 모먼트 날짜. 있으면 EXIF taken_at
  // 보다 우선해서 occurred_at으로 사용.
  const occurredAtRaw = form.get("occurred_at");

  if (typeof sceneId !== "string" || !sceneId) {
    return new Response("Missing scene_id", { status: 400 });
  }
  if (!(fullFile instanceof File) || !(thumbFile instanceof File)) {
    return new Response("Missing full/thumb file part", { status: 400 });
  }

  let payloadMeta: Record<string, unknown> = {};
  if (typeof payloadRaw === "string" && payloadRaw.length > 0) {
    try {
      const parsed = JSON.parse(payloadRaw);
      if (parsed && typeof parsed === "object") {
        payloadMeta = parsed as Record<string, unknown>;
      }
    } catch (_) {
      return new Response("Invalid payload JSON", { status: 400 });
    }
  }

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

  // 2) Read bytes.
  const fullBytes = new Uint8Array(await fullFile.arrayBuffer());
  const thumbBytes = new Uint8Array(await thumbFile.arrayBuffer());
  if (fullBytes.byteLength === 0 || thumbBytes.byteLength === 0) {
    return new Response("Empty file part", { status: 400 });
  }

  // Magic-byte 체크 — JPEG SOI marker (FF D8 FF). 클라가 multipart의 file part
  // 이름을 'full'/'thumb'로 만들어 보내도 실제 바이트가 다른 포맷이면 거절.
  // 악의적/실수 업로드(svg+xss, html, etc.) 차단을 위한 server-side 검증.
  const isJpeg = (b: Uint8Array) =>
    b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;
  if (!isJpeg(fullBytes) || !isJpeg(thumbBytes)) {
    return new Response("Both file parts must be JPEG", { status: 400 });
  }

  // 3) Allocate content_id (we generate client-side via crypto.randomUUID
  //    so the storage path is known before insert and we don't need a
  //    separate "reserve id" round-trip).
  const contentId = crypto.randomUUID();

  // 4) Service-role upload of both variants. RLS on the storage bucket
  //    is pair-and-tier aware but service-role bypasses, so the size cap
  //    needs to be enforced here (or we trust the client; safer to
  //    re-check). 50 MiB hard ceiling regardless of tier — defense in
  //    depth against misuse.
  const HARD_CEILING = 52428800; // 50 MiB
  if (fullBytes.byteLength > HARD_CEILING) {
    return new Response("Full variant exceeds 50 MiB ceiling", { status: 413 });
  }

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) {
    return new Response("Server misconfigured", { status: 500 });
  }
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceKey,
  );

  const fullPath = `${pairId}/${sceneId}/${contentId}/full.jpg`;
  const thumbPath = `${pairId}/${sceneId}/${contentId}/thumb.jpg`;

  // rollback 헬퍼 — 어떤 단계에서든 이미 만든 객체가 있으면 best-effort로
  // 지움. 실패는 로그만 — 응답이 가는 케이스가 아니라 그냥 깨끗이 정리.
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

  const fullUp = await adminClient.storage
    .from("scene_media")
    .upload(fullPath, fullBytes, { contentType: "image/jpeg", upsert: true });
  if (fullUp.error) {
    console.error("full upload failed", fullUp.error);
    return new Response(`Full upload failed: ${fullUp.error.message}`, {
      status: 500,
    });
  }
  if (aborted()) {
    await removeStorage([fullPath]);
    return abortedResponse();
  }

  const thumbUp = await adminClient.storage
    .from("scene_media")
    .upload(thumbPath, thumbBytes, { contentType: "image/jpeg", upsert: true });
  if (thumbUp.error) {
    await removeStorage([fullPath]);
    console.error("thumb upload failed", thumbUp.error);
    return new Response(`Thumb upload failed: ${thumbUp.error.message}`, {
      status: 500,
    });
  }
  if (aborted()) {
    await removeStorage([fullPath, thumbPath]);
    return abortedResponse();
  }

  // 5) Insert contents row. Merge storage paths into payload; lift
  //    taken_at to occurred_at so scene_summary's earliest/latest reflect
  //    the actual capture date when EXIF was available.
  const fullPayload = {
    ...payloadMeta,
    storage_path: fullPath,
    thumb_path: thumbPath,
  };
  // 사용자 지정(occurred_at form field) 우선, 없으면 EXIF taken_at으로 fallback.
  const occurredAt = typeof occurredAtRaw === "string" && occurredAtRaw.length > 0
    ? occurredAtRaw
    : (typeof payloadMeta.taken_at === "string" ? payloadMeta.taken_at : null);

  const { data: inserted, error: insertErr } = await adminClient
    .from("contents")
    .insert({
      id: contentId,
      scene_id: sceneId,
      type: "photo",
      payload: fullPayload,
      occurred_at: occurredAt,
      created_by: userId,
    })
    .select()
    .single();
  if (insertErr || !inserted) {
    await removeStorage([fullPath, thumbPath]);
    console.error("contents insert failed", insertErr);
    return new Response(
      `Insert failed: ${insertErr?.message ?? "unknown"}`,
      { status: 500 },
    );
  }
  // insert가 성공했어도 그 사이에 클라가 끊겼으면 응답이 못 가므로 클라
  // 입장에서는 phantom row가 됨 — 깨끗하게 지우고 종료.
  if (aborted()) {
    await removeRow();
    await removeStorage([fullPath, thumbPath]);
    return abortedResponse();
  }

  // 6) Signed URLs (1h).
  const [{ data: fullSigned }, { data: thumbSigned }] = await Promise.all([
    adminClient.storage.from("scene_media").createSignedUrl(fullPath, 3600),
    adminClient.storage.from("scene_media").createSignedUrl(thumbPath, 3600),
  ]);

  return new Response(
    JSON.stringify({
      content: inserted,
      full_signed_url: fullSigned?.signedUrl ?? null,
      thumb_signed_url: thumbSigned?.signedUrl ?? null,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
