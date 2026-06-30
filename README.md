<p align="center">
  <img src="branding/logo-full.svg" alt="ProTourney" width="420"/>
</p>

<h1 align="center">ProTourney</h1>

<p align="center">
  An online esports / competition <b>tournament platform</b> — Flutter (mobile + web),
  powered by Supabase, with QRIS entry-fee payments for Indonesia.
</p>

---

## What it does

- **Players** browse competitions, register, and pay an **entry fee** via **InterActive QRIS**
  (qris.id) — pay with any e-wallet or m-banking (GoPay, OVO, DANA, ShopeePay, …).
- Anyone can become a **Competition Organizer**. The platform takes a **10% commission**
  on every paid registration; organizers keep the rest.
- Organizers run **Round-Robin** or **Single-Elimination** competitions with rich pages:
  banner + gallery, max participants, an auto-generated share link, and a technical-meeting
  link (Discord / WhatsApp).
- Each **player-vs-player match** supports pre-match **stream links** (YouTube / TikTok /
  Twitch) and post-match **screenshot + winner reports**. Matching reports auto-confirm
  after **5 minutes**; conflicting reports open a **dispute** and email the organizer.
- Users save **bank / e-wallet payout details** (optional) to receive rewards.
- **Admins** manage everything from the same app on **web and mobile**.

> See the full design in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and the approved
> plan for the phased roadmap.

## Tech stack

| Layer | Choice |
|-------|--------|
| Client | **Flutter** (Android + Web, iOS scaffolded) · Riverpod · go_router · flutter_svg · qr_flutter |
| Backend | **Supabase** — Postgres + RLS · Auth · Storage · Realtime · Edge Functions · pg_cron |
| Payments | **InterActive QRIS** OPEN API (qris.id) — dynamic QRIS invoices + payment callbacks |
| Email | Resend (or SMTP) via Edge Function |
| CI/CD | GitHub Actions — Android APK/AAB + Web, **signing optional, defaults to unsigned** |

## Repository layout

```
app/                 Flutter application (mobile + web)
supabase/            migrations (schema + RLS + fee-split), Edge Functions, seed
.github/workflows/   build-android · build-web · build-ios · ci
branding/            custom SVG logo + palette
docs/                ARCHITECTURE · SETUP · QRIS · PAYOUTS
.env.example         all configuration knobs (copy to .env)
```

## Quick start

```bash
# 1. Configure
cp .env.example .env          # fill in Supabase + QRIS values (QRIS_MOCK=true to start)

# 2. Run the app (web)
cd app
flutter pub get
flutter run -d chrome --dart-define-from-file=../.env

# 3. (Optional) Backend
supabase start                # local stack
supabase db reset             # apply migrations + seed
```

Full setup — including Supabase project creation, QRIS registration, and signing — is in
[`docs/SETUP.md`](docs/SETUP.md).

## Builds

Every push to `claude/online-tournament-app-04fj47` (and manual `workflow_dispatch`) builds
an **unsigned** Android APK and a Web bundle as workflow artifacts — **no secrets required**.
Add the Android keystore secrets (see `docs/SETUP.md`) and the same pipeline produces
**signed** release APK/AAB. Tag pushes attach the artifacts to a GitHub Release.

## Status

Phase 1 (this foundation) is in place: scaffold, theme + logo, auth + payout form,
competition browse/create, full DB schema with RLS, QRIS in **mock mode**, and the build
pipeline. Phases 2–5 (live payments, brackets, match lifecycle + disputes, admin + payouts,
automated disbursement) follow the roadmap in the plan.

## License

Proprietary — © 2026. All rights reserved.
