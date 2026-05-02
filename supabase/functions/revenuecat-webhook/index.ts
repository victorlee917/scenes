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
    case "SUBSCRIBER_ALIAS":
    case "TEST":
    default:
      return null; // log only
  }
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
  if (!rc || !rc.type || !rc.app_user_id) {
    return new Response("Malformed event", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { error: logError } = await supabase
    .from("subscription_events")
    .insert({
      user_id: rc.app_user_id,
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
