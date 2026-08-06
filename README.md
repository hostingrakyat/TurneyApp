<p align="center">
  <img src="branding/logo-full.svg" alt="ProTourney" width="560"/>
</p>

<p align="center">
  An online esports / competition <b>tournament platform</b> — Flutter (mobile + web),
  Supabase backend, QRIS + manual entry-fee payments for Indonesia.
</p>

<p align="center">
  <img alt="CI" src="https://img.shields.io/badge/CI-analyze%20%2B%20test-brightgreen">
  <img alt="Build" src="https://img.shields.io/badge/build-Android%20%2B%20Web-brightgreen">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-mobile%20%2B%20web-9E1B32">
  <img alt="i18n" src="https://img.shields.io/badge/i18n-EN%20%2F%20ID-9E1B32">
</p>

---

## What it does

**Players**
- Browse competitions, register, and pay the **entry fee** two ways:
  - **QRIS** (InterActive / qris.id) — scan with any e-wallet or m-banking (GoPay, OVO, DANA, ShopeePay, …), settled automatically.
  - **Manual transfer** — bank / OVO / DANA / GoPay to the platform's accounts; an admin confirms it.
- Save **bank / e-wallet payout details** (optional) to receive rewards.
- A **Schedule** hub: matches ready to play, upcoming events (one-tap **add to calendar**), and recent results.

**Organizers** — anyone can run a competition; the platform takes a **10% commission** on paid entries.
- Three formats:
  - **Single-Elimination** — seeded bracket with byes.
  - **Round-Robin** — optional **groups of N**, top-N advance to an optional **single-elim playoff**, W/L/points standings with head-to-head tie-breaks.
  - **Free-for-All** — N players per **lobby**; organizer sets how many **advance per lobby** and how many **winners in the final** (podium).
- Rich pages: banner, max participants, **registration deadline**, auto-generated **share link**, and a technical-meeting link (Discord / WhatsApp). A **Participants** panel with phone numbers + one-tap WhatsApp.

**Matches**
- Pre-match **stream links** (YouTube / TikTok / Twitch); post-match **screenshot + winner reports**.
- Reports that agree **auto-confirm after 5 minutes**; conflicting reports open a **dispute** and email the organizer.
- **Realtime** live brackets, a visual **bracket tree**, and round-robin **standings** tables.

**Admins** (same app, web + mobile)
- **Manage competitions** — platform-wide moderation: cancel & refund, or delete.
- **Transactions** ledger — every payment; confirm / reject pending manual transfers (reuses the 10% fee split).
- **Payment accounts** — set the platform's bank / OVO / DANA / GoPay receiving accounts.
- **Users & roles**, **Payouts** (mark owed → paid), **Configuration** (domain, QRIS, email + a deployment-readiness checklist), **Branding** (upload logo), and a **Demo mode** toggle.

**Experience** — maroon Material 3 theme, an animated abstract backdrop, branded loaders + skeletons, staggered entrance animations and page/tab transitions, full **EN / ID** localization and **$ / Rp** currency, in-app notifications (+ optional FCM push), and anonymous **public share pages** at `/c/:slug`.

> Try it with **zero setup**: run in demo mode (below) — the whole loop works
> in-memory, no backend required.

## Tech stack

| Layer | Choice |
|-------|--------|
| Client | **Flutter** (Android + Web, iOS scaffolded) · Riverpod · go_router · flutter_svg · qr_flutter |
| Backend | **Supabase** — Postgres + RLS · Auth · Storage · Realtime · Edge Functions (Deno) · pg_cron |
| Payments | **InterActive QRIS** (qris.id) — dynamic invoices + callback · **manual transfer** with admin confirmation |
| Email / Push | Resend (Edge Function) · FCM HTTP v1 (optional, service-account gated) |
| Hosting | Flutter **web build on cPanel** + Supabase as the backend |
| CI/CD | GitHub Actions — Android APK/AAB + Web, **signing optional, defaults to unsigned** |

## Repository layout

```
app/                 Flutter application (mobile + web)
supabase/            migrations (0001–0014: schema + RLS + fee split), Edge Functions, seed
.github/workflows/   ci · build-android · build-web · build-ios
branding/            custom SVG logo (mark + banner) + palette
tool/                render_icon.sh (rasterize the launcher icon)
docs/                SETUP · DEPLOY_CPANEL · QRIS · MANUAL_PAYMENTS · PUSH · PAYOUTS · ARCHITECTURE
```

## Quick start (demo, no backend)

```bash
cd app
flutter create --org com.protourney --project-name turneyapp --platforms=android,web,ios .
flutter pub get
flutter run -d chrome        # fully interactive with sample data
```

Sign in with any email; an email starting with `admin@` (e.g.
`admin@protourney.test`) gets the **admin** role.

## Setup & deployment

| Guide | Covers |
|-------|--------|
| [`docs/SETUP.md`](docs/SETUP.md) | Local dev, Supabase stack, Edge Functions, GitHub Actions, signing, app icon |
| [`docs/DEPLOY_CPANEL.md`](docs/DEPLOY_CPANEL.md) | **Production**: migrations, functions, secrets, `flutter build web`, upload to cPanel, domain + HTTPS |
| [`docs/GOOGLE_PLAY.md`](docs/GOOGLE_PLAY.md) | **Publishing on Play** — why store builds ship with payments disabled, and how |
| [`docs/QRIS.md`](docs/QRIS.md) | QRIS payments API — invoice → callback → fee split, mock vs live, field mapping |
| [`docs/MANUAL_PAYMENTS.md`](docs/MANUAL_PAYMENTS.md) | Bank / e-wallet manual transfer + admin confirmation |
| [`docs/PUSH.md`](docs/PUSH.md) | FCM push notifications (optional) |
| [`docs/PAYOUTS.md`](docs/PAYOUTS.md) | Refunds & reward payouts |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System design, data model, RLS |

**Secrets never ship in the web bundle** — QRIS / Resend / Firebase keys live as
Supabase secrets and are read only by Edge Functions. The public Supabase anon
key is safe to ship (RLS protects the data). The admin **Configuration** screen
shows the exact `supabase secrets set …` commands to run.

## Distribution & Google Play

Google Play requires Play Billing for in-app purchases, and its real-money-games
policy does not cover paid-entry cash-prize contests in Indonesia. So the Play
build ships with **every payment surface disabled**:

```bash
flutter build appbundle --release --dart-define=STORE_BUILD=true
```

Free competitions still work end-to-end there; paid entry, prizes, checkout,
payouts and the admin money screens are compiled out. The **web build on your own
domain keeps the full QRIS + manual-transfer flow**. Details and a pre-submission
checklist: [`docs/GOOGLE_PLAY.md`](docs/GOOGLE_PLAY.md).

## Builds

Every push to the working branch (and manual `workflow_dispatch`) builds an
**unsigned** Android APK and a Web bundle as workflow artifacts — **no secrets
required**. Add the Android keystore secrets (see [`docs/SETUP.md`](docs/SETUP.md))
and the same pipeline produces **signed** release APK/AAB. iOS builds on tags /
manual dispatch (unsigned; distribution needs a paid Apple account).

## License

Proprietary — © 2026. All rights reserved.
