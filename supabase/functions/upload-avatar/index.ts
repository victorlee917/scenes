// upload-avatar
//
// Authenticated client posts JPEG bytes (raw body, Content-Type: image/jpeg).
// 1. Verify caller JWT via auth.getUser() (user-context client).
// 2. Upload using service role client (bypasses RLS) to caller's path.
//
// Why service role: caller JWT works for auth.getUser() but Supabase storage
// gateway doesn't reliably pass it to RLS context (auth.uid() resolves null
// when client uses sb_publishable_... key — known compatibility issue). Since
// this EF validates the caller before uploading, bypassing RLS is safe.
//
// Required env (auto-injected by Supabase):
//   - SUPABASE_URL
//   - SUPABASE_ANON_KEY        (legacy anon JWT — used for auth.getUser)
//   - SUPABASE_SERVICE_ROLE_KEY (used to bypass storage RLS)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }

  // 1) caller 검증.
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

  // 2) bytes 읽기.
  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.byteLength === 0) {
    return new Response("Empty body", { status: 400 });
  }

  // 3) service role로 RLS 우회해 업로드.
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) {
    return new Response("Server misconfigured", { status: 500 });
  }
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceKey,
  );

  const ts = Date.now();
  const path = `${userId}/${ts}.jpg`;

  const { error: uploadError } = await adminClient.storage
    .from("avatars")
    .upload(path, bytes, {
      contentType: "image/jpeg",
      upsert: true,
    });

  if (uploadError) {
    console.error("avatar upload failed", uploadError);
    return new Response(`Upload failed: ${uploadError.message}`, {
      status: 500,
    });
  }

  const { data: { publicUrl } } = adminClient.storage
    .from("avatars")
    .getPublicUrl(path);

  return new Response(
    JSON.stringify({ public_url: publicUrl, path }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
