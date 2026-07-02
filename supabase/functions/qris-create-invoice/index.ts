// Creates a registration (pending payment) and a dynamic QRIS invoice.
// Called by the authenticated Flutter client.
//
//   deploy:  supabase functions deploy qris-create-invoice
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";
import {
  createLiveQrisInvoice,
  isMock,
  mockQrisInvoice,
} from "../_shared/qris.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";

    // Identify the caller from their JWT.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const { competition_id } = await req.json().catch(() => ({}));
    if (!competition_id) return json({ error: "competition_id required" }, 400);

    const admin = createClient(supabaseUrl, serviceKey);

    const { data: comp, error: compErr } = await admin
      .from("competitions").select("*").eq("id", competition_id).single();
    if (compErr || !comp) return json({ error: "competition not found" }, 404);

    // Registration must still be open (status + optional deadline).
    if (comp.status !== "open") {
      return json({ error: "registration closed" }, 400);
    }
    if (
      comp.registration_deadline &&
      new Date(comp.registration_deadline as string) < new Date()
    ) {
      return json({ error: "registration deadline passed" }, 400);
    }

    // Admin-controlled mock toggle (app_settings.qris_mock). Falls back to env.
    const { data: settings } = await admin
      .from("app_settings").select("qris_mock").eq("id", 1).maybeSingle();
    const dbMock = settings?.qris_mock as boolean | undefined;

    const entryFee: number = comp.entry_fee ?? 0;
    const feeRate = Number(Deno.env.get("PLATFORM_FEE_RATE") ?? "0.10");
    const platformFee = Math.round(entryFee * feeRate);

    // Upsert the registration (idempotent per competition+user).
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

    // Free entry — confirm immediately, no QR needed.
    if (entryFee === 0) {
      await admin.from("registrations").update({ status: "paid" }).eq(
        "id",
        reg.id,
      );
      return json({ free: true, registration_id: reg.id });
    }

    // Create the QRIS invoice (mock or live).
    const mock = isMock(dbMock);
    const invoice = mock
      ? mockQrisInvoice(reg.id, entryFee)
      : await createLiveQrisInvoice(reg.id, entryFee);

    const { data: pay, error: payErr } = await admin
      .from("payments")
      .insert({
        registration_id: reg.id,
        provider: "qris",
        invoice_id: invoice.invoiceId,
        qris_string: invoice.qrisString,
        amount: entryFee,
        status: "pending",
      })
      .select().single();
    if (payErr) return json({ error: payErr.message }, 400);

    return json({
      invoice_id: invoice.invoiceId,
      qris_string: invoice.qrisString,
      amount: entryFee,
      platform_fee: platformFee,
      payment_id: pay.id,
      registration_id: reg.id,
      mock,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
