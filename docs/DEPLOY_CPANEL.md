# Deploying ProTourney to cPanel (web) + Supabase (backend)

ProTourney's web build is a static Flutter bundle. You host that bundle on your
cPanel hosting under your own domain, while **Supabase stays the backend**
(database, auth, storage, Edge Functions). Secret keys never ship in the web
bundle — they live as Supabase secrets and are read only by Edge Functions.

This is the production counterpart to the local `flutter run` flow in
[`SETUP.md`](SETUP.md).

---

## 1. Prerequisites

- A cPanel hosting account with your domain pointed at it.
- A Supabase project (free tier is fine to start).
- The Supabase CLI installed locally (`supabase`) and logged in.
- Flutter SDK installed locally (`flutter --version`).
- (For live payments) a qris.id OPEN API merchant account.
- (For dispute emails) a Resend account + verified sending domain.

---

## 2. Apply the database migrations

From the repo root:

```bash
supabase link --project-ref <your-project-ref>
supabase db push        # applies supabase/migrations/0001 … 0007
```

This creates every table, RLS policy, function, and the `app_settings` row the
admin Configuration screen reads/writes.

---

## 3. Deploy the Edge Functions

```bash
supabase functions deploy qris-create-invoice
supabase functions deploy qris-callback
supabase functions deploy qris-mock-pay
supabase functions deploy resolve-matches
```

Schedule the auto-resolve job (already defined in `0004_cron.sql`) if you use
`pg_cron`, or call `resolve-matches` from an external scheduler every minute.

---

## 4. Set the server-side secrets

These are **never** stored in the web bundle or the `app_settings` row. Set them
as Supabase secrets so only the Edge Functions can read them:

```bash
# QRIS (only needed when you turn mock mode OFF)
supabase secrets set QRIS_API_KEY=…
supabase secrets set QRIS_CALLBACK_SECRET=…

# Transactional email (dispute notifications, receipts)
supabase secrets set RESEND_API_KEY=…
```

The admin **Configuration** screen shows these exact commands and lets you copy
them. The non-secret values (domain, QRIS merchant/store id, sender email, mock
toggle) are saved into `app_settings` from that same screen.

---

## 5. Configure the qris.id callback URL

In your qris.id merchant dashboard, point the payment callback at the deployed
function:

```
https://<your-project-ref>.functions.supabase.co/qris-callback
```

Keep **mock mode ON** in the admin Configuration screen until this is verified
end-to-end; mock mode simulates payments so nothing charges real money.

---

## 6. Build the Flutter web bundle

The app reads its Supabase URL + anon key from `--dart-define` at build time
(see `app/lib/core/env.dart`). The anon key is public by design (RLS protects the
data), so it is safe to ship in the bundle.

```bash
cd app
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

The output lands in `app/build/web/`.

> Leave the dart-defines off to build the **offline demo** bundle (no backend) —
> useful for a no-setup preview.

---

## 7. Upload to cPanel

1. In cPanel → **File Manager**, open `public_html` (or the subdomain's docroot).
2. Upload the **contents** of `app/build/web/` (not the folder itself) — i.e.
   `index.html`, `flutter_bootstrap.js`, `main.dart.js`, `assets/`, `canvaskit/`,
   etc.
3. Flutter web is a single-page app. Add an `.htaccess` in the same folder so
   deep links fall back to `index.html`:

```apache
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /
  RewriteRule ^index\.html$ - [L]
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule . /index.html [L]
</IfModule>
```

> If you serve the app from a sub-path (e.g. `https://domain/app/`), rebuild with
> `flutter build web --base-href /app/` and adjust `RewriteBase` accordingly.

---

## 8. Point the domain & enable HTTPS

- Ensure your domain's DNS points at the cPanel server.
- Enable **AutoSSL / Let's Encrypt** in cPanel so the site is served over HTTPS
  (QRIS callbacks and Supabase auth require it).

---

## 9. Finish in the admin Configuration screen

Open the deployed app, sign in as an admin, then **Admin → Configuration**:

- Set the **domain** (e.g. `protourney.id`) — this feeds competition share links.
- Enter the **QRIS merchant/store id** and turn **mock mode OFF** once the live
  keys (step 4) and callback (step 5) are verified.
- Set the **sender email**.
- Watch the **Deployment readiness** checklist reach 4/4.

---

## Checklist

- [ ] `supabase db push` applied (through `0007`).
- [ ] Edge Functions deployed.
- [ ] Secrets set (`QRIS_API_KEY`, `QRIS_CALLBACK_SECRET`, `RESEND_API_KEY`).
- [ ] qris.id callback URL configured.
- [ ] `flutter build web --release` with the right dart-defines.
- [ ] `build/web` contents uploaded to `public_html` + `.htaccess` added.
- [ ] Domain points at cPanel, HTTPS enabled.
- [ ] Admin Configuration filled in, readiness 4/4, mock mode off for live money.
