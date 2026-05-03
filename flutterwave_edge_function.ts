// supabase/functions/flutterwave/index.ts
// ─────────────────────────────────────────────────────────────────────────────
// Flutterwave V4 Edge Function — handles ALL server-side Flutterwave calls.
// The FLW_SECRET_KEY is NEVER in the Flutter app — only here in Supabase Secrets.
//
// Deploy:
//   supabase functions deploy flutterwave --no-verify-jwt
//
// Supabase Dashboard → Edge Functions → flutterwave → Secrets:
//   FLW_SECRET_KEY     = Cjan8PMoiD7LsjyKdFpGBlcVqbioIYWc
//   FLW_ENCRYPTION_KEY = Jb6I2/3b5wTyrRVAxp+24MXo46LRHt3GiNak475tHbw=
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const FLW_SECRET_KEY = Deno.env.get("FLW_SECRET_KEY") ?? "";
const FLW_BASE_URL = "https://api.flutterwave.com/v3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-edge-path",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

// ── helpers ──────────────────────────────────────────────────────────────────

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function flwGet(endpoint: string): Promise<Response> {
  const res = await fetch(`${FLW_BASE_URL}${endpoint}`, {
    headers: {
      Authorization: `Bearer ${FLW_SECRET_KEY}`,
      "Content-Type": "application/json",
    },
  });
  return res;
}

async function flwPost(endpoint: string, body: unknown): Promise<Response> {
  const res = await fetch(`${FLW_BASE_URL}${endpoint}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${FLW_SECRET_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  return res;
}

// ── router ───────────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!FLW_SECRET_KEY) {
    return json(
      { status: "error", message: "FLW_SECRET_KEY not configured in Supabase Secrets" },
      500
    );
  }

  // Read the path from the custom header OR from the body's _path field
  const headerPath = req.headers.get("x-edge-path") ?? "";

  let body: Record<string, unknown> = {};
  try {
    if (req.method === "POST") {
      body = await req.json();
    }
  } catch (_) {
    // body might be empty for GET requests
  }

  // Determine actual path — header takes priority, body _path is fallback
  const path: string = (headerPath || (body["_path"] as string) || "").replace(
    /^\//,
    ""
  );

  console.log(`[FLW Edge] path=${path} method=${req.method}`);

  // ── 1. Verify payment ────────────────────────────────────────────────────
  // Called by Flutter after WebView intercepts the callback URL.
  // Flutter sends the tx_ref (our reference) — we verify via Flutterwave API.
  if (path === "verify" || path === "/verify") {
    // tx_ref can come from body (POST) or query params (GET)
    const url = new URL(req.url);
    const txRef: string =
      (body["tx_ref"] as string) ??
      url.searchParams.get("tx_ref") ??
      "";

    if (!txRef) {
      return json({ status: "error", message: "tx_ref is required" }, 400);
    }

    try {
      // Flutterwave V3 verify by tx_ref
      const res = await flwGet(
        `/transactions/verify_by_reference?tx_ref=${encodeURIComponent(txRef)}`
      );
      const data = await res.json();
      console.log(`[FLW Edge] verify result for ${txRef}:`, JSON.stringify(data));
      return json(data);
    } catch (err) {
      console.error("[FLW Edge] verify error:", err);
      return json({ status: "error", message: String(err) }, 500);
    }
  }

  // ── 2. Create subaccount ─────────────────────────────────────────────────
  if (path === "create-subaccount") {
    try {
      const res = await flwPost("/subaccounts", {
        account_bank: body["account_bank"],
        account_number: body["account_number"],
        business_name: body["business_name"],
        split_type: body["split_type"] ?? "percentage",
        split_value: body["split_value"],
        country: "NG",
        business_mobile: body["business_mobile"] ?? "",
        business_email: body["business_email"] ?? "",
      });
      const data = await res.json();
      return json(data);
    } catch (err) {
      return json({ status: "error", message: String(err) }, 500);
    }
  }

  // ── 3. Get bank list ─────────────────────────────────────────────────────
  if (path === "banks") {
    try {
      const res = await flwGet("/banks/NG");
      const data = await res.json();
      return json(data);
    } catch (err) {
      return json({ status: "error", message: String(err) }, 500);
    }
  }

  // ── 4. Resolve account number ────────────────────────────────────────────
  if (path === "resolve-account") {
    const url = new URL(req.url);
    const accountNumber =
      (body["account_number"] as string) ??
      url.searchParams.get("account_number") ??
      "";
    const accountBank =
      (body["account_bank"] as string) ??
      url.searchParams.get("account_bank") ??
      "";

    try {
      const res = await flwGet(
        `/accounts/resolve?account_number=${accountNumber}&account_bank=${accountBank}`
      );
      const data = await res.json();
      return json(data);
    } catch (err) {
      return json({ status: "error", message: String(err) }, 500);
    }
  }

  // ── 5. Initiate transfer (payout to seller) ──────────────────────────────
  if (path === "transfer") {
    try {
      const res = await flwPost("/transfers", {
        account_bank: body["account_bank"],
        account_number: body["account_number"],
        amount: body["amount"],
        currency: body["currency"] ?? "NGN",
        narration: body["narration"] ?? "Seller payout from Maximus",
        reference: body["reference"],
      });
      const data = await res.json();
      return json(data);
    } catch (err) {
      return json({ status: "error", message: String(err) }, 500);
    }
  }

  // ── 6. Get transaction by ID ─────────────────────────────────────────────
  if (path === "transaction") {
    const url = new URL(req.url);
    const transactionId =
      (body["transaction_id"] as string) ??
      url.searchParams.get("transaction_id") ??
      "";
    try {
      const res = await flwGet(`/transactions/${transactionId}/verify`);
      const data = await res.json();
      return json(data);
    } catch (err) {
      return json({ status: "error", message: String(err) }, 500);
    }
  }

  // ── health check ─────────────────────────────────────────────────────────
  if (path === "" || path === "health") {
    return json({
      status: "ok",
      message: "Flutterwave Edge Function is running",
      keyConfigured: FLW_SECRET_KEY.length > 0,
    });
  }

  return json({ status: "error", message: `Unknown path: ${path}` }, 404);
});