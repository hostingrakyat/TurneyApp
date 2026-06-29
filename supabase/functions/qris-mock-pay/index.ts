// DEV/MOCK ONLY: confirms a mock QRIS payment (the "Simulate payment" button)
// by running the same fee-split logic as the real callback. Refuses unless
// QRIS_MOCK=true, so it can never settle real payments.
//
//   deploy:  supabase functions deploy qris-mock-pay
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    if ((Deno.env.get("QRIS_MOCK") ?? "true") !== "true") {
      return json({ error: "mock pay disabled (QRIS_MOCK is false)" }, 403);
    }
    const { payment_id } = await req.json().catch(() => ({}));
    if (!payment_id) return json({ error: "payment_id required" }, 400);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { error } = await admin.rpc("confirm_registration_payment", {
      p_payment_id: payment_id,
      p_raw: { mock: true },
    });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
