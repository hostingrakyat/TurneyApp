// Runs the match auto-resolve transitions and emails organizers about any
// newly created disputes. Schedule every minute (Supabase Dashboard → Edge
// Functions → Cron, or pg_net). Safe to run alongside the SQL pg_cron job.
//
//   deploy:  supabase functions deploy resolve-matches --no-verify-jwt
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { json } from "../_shared/cors.ts";
import { sendEmail } from "../_shared/email.ts";

Deno.serve(async (req) => {
  try {
    // Optional shared-secret guard for the scheduler.
    const secret = Deno.env.get("CRON_SECRET");
    if (secret) {
      const provided = new URL(req.url).searchParams.get("secret") ??
        req.headers.get("x-cron-secret");
      if (provided !== secret) return json({ error: "forbidden" }, 403);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1) State transitions (agree → completed, conflict → disputed).
    const { data: resolved, error: rpcErr } = await admin.rpc(
      "resolve_due_matches",
    );
    if (rpcErr) return json({ error: rpcErr.message }, 500);

    // 2) Notify organizers of disputes we haven't emailed about yet.
    const { data: disputes, error: dErr } = await admin
      .from("disputes")
      .select(
        "id, match_id, matches(competition_id, competitions(title, organizer_id))",
      )
      .is("notified_at", null)
      .eq("status", "open");
    if (dErr) return json({ error: dErr.message }, 500);

    let notified = 0;
    for (const d of disputes ?? []) {
      // deno-lint-ignore no-explicit-any
      const comp = (d as any).matches?.competitions;
      if (!comp?.organizer_id) continue;
      const { data: u } = await admin.auth.admin.getUserById(
        comp.organizer_id,
      );
      const email = u?.user?.email;
      if (email) {
        await sendEmail({
          to: email,
          subject: `Action needed: result dispute in "${comp.title}"`,
          html:
            `<p>Two players reported different winners for a match in ` +
            `<b>${comp.title}</b>.</p>` +
            `<p>Open TurneyApp → your competition → the match to review both ` +
            `screenshots and set the winner.</p>`,
        });
      }
      await admin.from("disputes").update({
        notified_at: new Date().toISOString(),
      }).eq("id", d.id);
      notified++;
    }

    return json({ ok: true, resolved: resolved ?? 0, notified });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
