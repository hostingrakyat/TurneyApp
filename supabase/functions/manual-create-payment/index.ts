// Creates a registration (pending payment) plus a `manual` payment row so the
// player can transfer their entry fee by bank / e-wallet. The spot is held
// until an admin confirms the transfer (see admin-confirm-payment). Clients
// can't insert payments directly (RLS), so this runs with the service role.
//
//   deploy:  supabase functions deploy manual-create-payment
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

const METHODS = ["bank", "ovo", "dana", "gopay"];

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

    const { competition_id, method, reference } = await req.json().catch(
      () => ({}),
    );
    if (!competition_id) return json({ error: "competition_id required" }, 400);
    if (!METHODS.includes(method)) return json({ error: "invalid method" }, 400);

    const admin = createClient(supabaseUrl, serviceKey);

    const { data: comp, error: compErr } = await admin
      .from("competitions").select("*").eq("id", competition_id).single();
    if (compErr || !comp) return json({ error: "competition not found" }, 404);

    if (comp.status !== "open") {
      return json({ error: "registration closed" }, 400);
    }
    if (
      comp.registration_deadline &&
      new Date(comp.registration_deadline as string) < new Date()
    ) {
      return json({ error: "registration deadline passed" }, 400);
    }

    const entryFee: number = comp.entry_fee ?? 0;

    // Upsert the registration (idempotent per competition+user), left pending.
    const { data: reg, error: regErr } = await admin
      .from("registrations")
      .upsert(
        {
          competition_id,
          user_id: user.id,
          entry_fee: entryFee,
          status: "pending_payment",
        },
        { onConflict: "competition_id,user_id" },
      )
      .select().single();
    if (regErr) return json({ error: regErr.message }, 400);

    const { data: pay, error: payErr } = await admin
      .from("payments")
      .insert({
        registration_id: reg.id,
        provider: "manual",
        method,
        reference: reference ?? null,
        amount: entryFee,
        status: "pending",
      })
      .select().single();
    if (payErr) return json({ error: payErr.message }, 400);

    return json({ payment_id: pay.id, registration_id: reg.id });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
