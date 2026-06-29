# Architecture

## Overview

```
┌──────────────────────────────┐        ┌───────────────────────────────┐
│  Flutter app (Android / Web)  │        │            Supabase            │
│  Riverpod · go_router         │  JWT   │  Postgres + RLS                │
│  features/{auth,competitions, │ ─────► │  Auth · Storage · Realtime     │
│   payments,organizer,admin}   │        │  Edge Functions · pg_cron      │
└──────────────┬───────────────┘        └───────────────┬───────────────┘
               │ create invoice / callbacks               │
               ▼                                           ▼
        InterActive QRIS (qris.id)                  Resend (email)
```

The Flutter client talks to Supabase directly for ordinary reads/writes
(gated by Row Level Security). Anything involving **money or trust** —
confirming a payment, splitting the 10% fee, resolving a match — goes through
**Edge Functions** and **`SECURITY DEFINER` SQL functions**, never trusted from
the client.

## Client layers (`app/lib`)

- `core/` — `env.dart` (compile-time config), `theme.dart` (brand Material 3),
  `router.dart` (go_router + auth redirect), `supabase.dart`, `formatters.dart`.
- `shared/` — `models/` (typed rows + enums) and reusable `widgets/`.
- `features/<area>/` — one folder per area; a Riverpod controller +
  screens/widgets. Controllers degrade to **in-memory demo data** when no
  backend is configured (`Env.hasBackend == false`), so the UI runs offline.

## Data model

See `supabase/migrations/0001_init.sql`. Core tables:
`profiles`, `payout_accounts`, `competitions`, `competition_images`,
`registrations`, `payments`, `matches`, `match_streams`, `match_reports`,
`disputes`, `payouts`, `platform_earnings`.

RLS (`0003_rls.sql`): players see their own rows; organizers manage their own
competitions and the registrations/matches within them; admins (via
`is_admin()`) see everything. Helper functions `is_admin()` and
`is_competition_organizer()` keep policies readable.

## Key flows

**Registration & payment.** Client calls `qris-create-invoice` → upserts a
`pending_payment` registration, creates a QRIS invoice (mock or live), stores a
`payments` row, returns the QR. The player pays; qris.id calls `qris-callback`
→ `confirm_registration_payment()` marks it paid and writes
`platform_fee = round(entry_fee × 0.10)`, `organizer_net`, and a
`platform_earnings` ledger row — atomically and idempotently.

**Match lifecycle (Phase 3).** Before a match, players add `match_streams`
(YouTube/TikTok/Twitch). After, each adds a `match_reports` row (screenshot +
claimed winner). `auto_resolve_at` is set 5 minutes out. The per-minute
`resolve_due_matches()` job: agreeing reports → winner + `completed`;
conflicting → `disputed` + a `disputes` row; the `resolve-matches` Edge
Function emails the organizer for un-notified disputes.

**Platform fee.** A flat 10% on every paid registration, recorded in
`platform_earnings` and surfaced on the admin console.

## Roadmap

Phase 1 (this foundation) → Phase 2 (live payments, bracket generation) →
Phase 3 (match reports + auto-resolve + disputes) → Phase 4 (admin + payouts +
notifications) → Phase 5 (automated disbursement, i18n, store signing). See the
approved plan for detail.
