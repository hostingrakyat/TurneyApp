// Admin-only: confirm or reject a pending manual payment. Confirming runs the
// same fee-split as the QRIS callback (confirm_registration_payment); rejecting
// marks the payment failed and releases the held registration. Verifies the
// caller is an admin before doing anything privileged.
//
//   deploy:  supabase functions deploy admin-confirm-payment
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const admin = createClient(supabaseUrl, serviceKey);

    // Gate on the admin role.
    const { data: prof } = await admin
      .from("profiles").select("role").eq("id", user.id).single();
    if (!prof || prof.role !== "admin") {
      return json({ error: "forbidden" }, 403);
    }

    const { payment_id, action } = await req.json().catch(() => ({}));
    if (!payment_id) return json({ error: "payment_id required" }, 400);

    if (action === "reject") {
      const { data: pay } = await admin
        .from("payments").select("registration_id, status").eq("id", payment_id)
        .single();
      if (pay && pay.status !== "paid") {
        await admin.from("payments").update({ status: "failed" }).eq(
          "id",
          payment_id,
        );
        // Release the held spot only if it hasn't been paid another way.
        await admin.from("registrations").delete()
          .eq("id", pay.registration_id).eq("status", "pending_payment");
      }
      return json({ ok: true, action: "reject" });
    }

    // Default: confirm → fee split + registration marked paid (idempotent).
    const { error } = await admin.rpc("confirm_registration_payment", {
      p_payment_id: payment_id,
      p_raw: { manual: true, confirmed_by: user.id },
    });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true, action: "confirm" });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
