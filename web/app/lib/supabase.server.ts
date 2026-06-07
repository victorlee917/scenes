import { createServerClient, parseCookieHeader, serializeCookieHeader } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";

export function createSupabaseServerClient(request: Request) {
  const headers = new Headers();

  const supabase = createServerClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return parseCookieHeader(request.headers.get("Cookie") ?? "").map(
            ({ name, value }) => ({ name, value: value ?? "" })
          );
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            headers.append("Set-Cookie", serializeCookieHeader(name, value, options))
          );
        },
      },
    }
  );

  return { supabase, headers };
}

/// Service-role 클라이언트. RLS를 우회하므로 **절대 브라우저로 노출하지 말고
/// 서버(loader/action)에서만** 사용한다. 공개 공유 페이지가 anon 방문자에게
/// "공유된" 데이터와 private 버킷의 signed URL을 제공할 때 사용.
export function createSupabaseAdminClient() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false, autoRefreshToken: false } }
  );
}
