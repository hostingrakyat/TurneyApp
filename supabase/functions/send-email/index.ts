// Generic transactional email endpoint (receipts, custom notifications).
// Guard with EMAIL_FUNCTION_SECRET so it can't be abused as an open relay.
//
//   deploy:  supabase functions deploy send-email
import { corsHeaders, json } from "../_shared/cors.ts";
import { sendEmail } from "../_shared/email.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const secret = Deno.env.get("EMAIL_FUNCTION_SECRET");
    if (secret && req.headers.get("x-email-secret") !== secret) {
      return json({ error: "forbidden" }, 403);
    }

    const { to, subject, html } = await req.json().catch(() => ({}));
    if (!to || !subject || !html) {
      return json({ error: "to, subject, html required" }, 400);
    }

    await sendEmail({ to, subject, html });
    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
