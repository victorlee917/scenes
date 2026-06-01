// RevenueCat webhook receiver
//
// RC sends a POST to this function on every subscription lifecycle event.
// We:
//   1. Verify Authorization header against REVENUECAT_WEBHOOK_SECRET.
//   2. Append the raw event to subscription_events.
//   3. Patch the user's profiles.subscription_* cache columns.
//
// RC dashboard config:
//   - Webhook URL: https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
//   - Authorization header: "Bearer <REVENUECAT_WEBHOOK_SECRET>"
//
// Required env (set via `supabase secrets set ...`):
//   - REVENUECAT_WEBHOOK_SECRET    (shared with RC dashboard)
//   - SUPABASE_URL                 (auto-injected by Supabase)
//   - SUPABASE_SERVICE_ROLE_KEY    (auto-injected by Supabase)
//
// app_user_id contract: when initializing the RC SDK on the client, set
// app_user_id = auth.uid() so events reference our profile id directly.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type RcStore =
  | "APP_STORE"
  | "PLAY_STORE"
  | "STRIPE"
  | "PROMOTIONAL"
  | "AMAZON"
  | "MAC_APP_STORE";

type RcEvent = {
  type: string;
  id: string;
  app_user_id: string;
  original_app_user_id?: string;
  product_id?: string;
  store?: RcStore;
  original_transaction_id?: string;
  event_timestamp_ms: number;
  expiration_at_ms?: number;
  // TRANSFER 이벤트 전용: 권한을 잃는/얻는 app_user_id 목록. 익명 id
  // ($RCAnonymousID:...)가 섞일 수 있어 처리 전 profile id만 필터한다.
  transferred_from?: string[];
  transferred_to?: string[];
};

type ProfileUpdate = {
  subscription_tier?: "free" | "scenes_hd";
  subscription_status?: "active" | "expired" | "canceled" | "trialing";
  subscription_expires_at?: string | null;
  subscription_provider?:
    | "app_store"
    | "play_store"
    | "promotional"
    | "manual";
};

const STORE_MAP: Record<RcStore, string> = {
  APP_STORE: "app_store",
  PLAY_STORE: "play_store",
  STRIPE: "stripe",
  PROMOTIONAL: "promotional",
  AMAZON: "amazon",
  MAC_APP_STORE: "mac_app_store",
};

function mapEventToProfileUpdate(rc: RcEvent): ProfileUpdate | null {
  const expiresAt = rc.expiration_at_ms
    ? new Date(rc.expiration_at_ms).toISOString()
    : null;
  const provider =
    rc.store && (STORE_MAP[rc.store] as ProfileUpdate["subscription_provider"]);

  switch (rc.type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
    case "PRODUCT_CHANGE":
    case "TEMPORARY_ENTITLEMENT_GRANT":
      return {
        subscription_tier: "scenes_hd",
        subscription_status: "active",
        subscription_expires_at: expiresAt,
        subscription_provider: provider,
      };

    case "CANCELLATION":
      // User canceled future renewal but still has access until expiration.
      return {
        subscription_status: "canceled",
        subscription_expires_at: expiresAt,
      };

    case "EXPIRATION":
    case "SUBSCRIPTION_PAUSED":
      return {
        subscription_tier: "free",
        subscription_status: "expired",
      };

    case "BILLING_ISSUE":
      // Grace state — keep tier, mark as expired so RLS denies new HD writes.
      return {
        subscription_status: "expired",
      };

    case "NON_RENEWING_PURCHASE":
      return {
        subscription_tier: "scenes_hd",
        subscription_status: "active",
        subscription_expires_at: expiresAt,
        subscription_provider: provider,
      };

    case "TRANSFER":
      // 다중 유저(from 다운그레이드 + to 업그레이드)라 단일 패치 모델에 안 맞음.
      // 핸들러에서 applyTransfer로 별도 처리.
      return null;

    case "SUBSCRIBER_ALIAS":
    case "TEST":
    default:
      return null; // log only
  }
}

// TRANSFER 처리: 같은 스토어 영수증이 다른 app_user_id로 이전될 때
// (예: A가 구독 후 같은 Apple ID로 로그인한 B가 "구매 복원"). RC 기본 동작은
// 새 유저로 이전 — transferred_from은 권한을 잃는 유저, transferred_to는 얻는
// 유저. from은 free/expired로, to는 scenes_hd/active로 갱신해 DB·클라
// (hasActiveSubscription)·서버(pair_has_active_hd)를 RC와 일치시킨다.
async function applyTransfer(
  supabase: ReturnType<typeof createClient>,
  from: string[],
  to: string[],
  rc: RcEvent,
): Promise<boolean> {
  if (from.length > 0) {
    const { error } = await supabase
      .from("profiles")
      .update({ subscription_tier: "free", subscription_status: "expired" })
      .in("id", from);
    if (error) {
      console.error("transfer downgrade failed", error);
      return false;
    }
  }

  if (to.length > 0) {
    const expiresAt = rc.expiration_at_ms
      ? new Date(rc.expiration_at_ms).toISOString()
      : null;
    const provider = rc.store
      ? (STORE_MAP[rc.store] as ProfileUpdate["subscription_provider"])
      : undefined;
    const up: ProfileUpdate = {
      subscription_tier: "scenes_hd",
      subscription_status: "active",
    };
    // TRANSFER 페이로드엔 만료/스토어가 없을 수 있으므로 있을 때만 덮어쓴다.
    // (pair_has_active_hd는 expires_at을 보지 않아 tier+status만으로 충분.)
    if (expiresAt) up.subscription_expires_at = expiresAt;
    if (provider) up.subscription_provider = provider;

    const { error } = await supabase.from("profiles").update(up).in("id", to);
    if (error) {
      console.error("transfer upgrade failed", error);
      return false;
    }
  }

  return true;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const expected = `Bearer ${Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? ""}`;
  const provided = req.headers.get("Authorization") ?? "";
  if (!Deno.env.get("REVENUECAT_WEBHOOK_SECRET") || provided !== expected) {
    return new Response("Unauthorized", { status: 401 });
  }

  let body: { event?: RcEvent };
  try {
    body = await req.json();
  } catch {
    return new Response("Bad Request", { status: 400 });
  }

  const rc = body.event;
  if (!rc || !rc.type) {
    return new Response("Malformed event", { status: 400 });
  }
  const isTransfer = rc.type === "TRANSFER";
  // TRANSFER는 app_user_id 없이 transferred_from/to 배열만 옴. 그 외 이벤트는
  // contract상 app_user_id(=auth.uid)가 반드시 있어야 한다.
  if (!isTransfer && !rc.app_user_id) {
    return new Response("Malformed event", { status: 400 });
  }

  const isProfileId = (id?: string | null): id is string =>
    !!id && !id.startsWith("$RCAnonymousID");
  const transferFrom = (rc.transferred_from ?? []).filter(isProfileId);
  const transferTo = (rc.transferred_to ?? []).filter(isProfileId);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { error: logError } = await supabase
    .from("subscription_events")
    .insert({
      // TRANSFER엔 app_user_id가 없으므로 배열의 유효 profile id로 대체.
      user_id: rc.app_user_id ?? transferTo[0] ?? transferFrom[0] ?? null,
      event_type: rc.type,
      source: "revenuecat",
      product_id: rc.product_id ?? null,
      store: rc.store ? STORE_MAP[rc.store] : null,
      original_transaction_id: rc.original_transaction_id ?? null,
      raw_payload: body,
      occurred_at: new Date(rc.event_timestamp_ms).toISOString(),
    });

  if (logError) {
    console.error("subscription_events insert failed", logError);
    return new Response("DB error", { status: 500 });
  }

  if (isTransfer) {
    const ok = await applyTransfer(supabase, transferFrom, transferTo, rc);
    if (!ok) return new Response("DB error", { status: 500 });
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const update = mapEventToProfileUpdate(rc);
  if (update) {
    const { error: updateError } = await supabase
      .from("profiles")
      .update(update)
      .eq("id", rc.app_user_id);

    if (updateError) {
      console.error("profile update failed", updateError);
      return new Response("DB error", { status: 500 });
    }
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
