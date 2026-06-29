/// Minimal transactional email helper. Uses Resend when RESEND_API_KEY is set,
/// otherwise logs (so dispute flows work end-to-end without email configured).
export async function sendEmail(opts: {
  to: string;
  subject: string;
  html: string;
}): Promise<void> {
  const key = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("EMAIL_FROM") ??
    "TurneyApp <no-reply@turneyapp.example>";

  if (!key) {
    console.log(`[email:mock] to=${opts.to} subject="${opts.subject}"`);
    return;
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: opts.to,
      subject: opts.subject,
      html: opts.html,
    }),
  });

  if (!res.ok) {
    console.error("[email] send failed:", res.status, await res.text());
  }
}
