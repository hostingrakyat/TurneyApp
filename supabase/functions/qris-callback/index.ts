// Payment notification webhook from qris.id. Marks the payment paid and
// splits the 10% platform fee (atomically, via confirm_registration_payment).
//
// Deploy WITHOUT JWT verification (qris.id won't send a Supabase token):
//   supabase functions deploy qris-callback --no-verify-jwt
//
// Protect it with QRIS_CALLBACK_SECRET — qris.id must include it (configure
// the callback URL as .../qris-callback?secret=YOUR_SECRET).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const url = new URL(req.url);
    const expected = Deno.env.get("QRIS_CALLBACK_SECRET");
    if (expected) {
      const provided = url.searchParams.get("secret") ??
        req.headers.get("x-callback-secret");
      if (provided !== expected) return json({ error: "forbidden" }, 403);
    }

    // qris.id may post JSON or form-encoded — accept both.
    let payload: Record<string, unknown> = {};
    const ct = req.headers.get("content-type") ?? "";
    if (ct.includes("application/json")) {
      payload = await req.json().catch(() => ({}));
    } else {
      const form = await req.formData().catch(() => null);
      if (form) for (const [k, v] of form.entries()) payload[k] = v;
    }

    const invoiceId = String(
      payload["qris_invoiceid"] ?? payload["invoice_id"] ??
        url.searchParams.get("invoice_id") ?? "",
    );
    const status = String(
      payload["qris_status"] ?? payload["status"] ?? "paid",
    ).toLowerCase();

    if (!invoiceId) return json({ error: "invoice_id missing" }, 400);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: payment, error: payErr } = await admin
      .from("payments").select("id, status")
      .eq("invoice_id", invoiceId).maybeSingle();
    if (payErr) return json({ error: payErr.message }, 500);
    if (!payment) return json({ error: "payment not found" }, 404);

    const success = ["paid", "success", "settlement", "1", "true"].includes(
      status,
    );
    if (!success) {
      await admin.from("payments").update({ status: "failed", raw: payload })
        .eq("id", payment.id);
      return json({ ok: true, applied: false });
    }

    // Atomic: mark paid + split the 10% platform fee. Idempotent.
    const { error: rpcErr } = await admin.rpc("confirm_registration_payment", {
      p_payment_id: payment.id,
      p_raw: payload,
    });
    if (rpcErr) return json({ error: rpcErr.message }, 500);

    return json({ ok: true, applied: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
