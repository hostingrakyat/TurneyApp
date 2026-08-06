# Publishing on Google Play (payments policy)

**Short version:** the Play build must ship with **no payment surfaces at all**.
Build it with `--dart-define=STORE_BUILD=true`. The web build (cPanel) keeps the
full QRIS + manual-transfer flow.

## Why

Two separate Google Play policies bite here, and both can get an app removed:

1. **Payments policy.** Purchases of in-app content must use **Google Play
   Billing**. Collecting entry fees through QRIS or a bank/e-wallet transfer
   inside a Play-distributed app is exactly what that policy prohibits, and
   "link out to our website to pay" has historically been treated as steering.
2. **Real-Money Games, Games of Skill & Contests policy.** Paid-entry contests
   that award **cash prizes** are only permitted in the specific countries
   Google has opened for real-money gaming, under licence and after a separate
   RMG application. **Indonesia is not one of them** — and Indonesian law
   (and Kominfo enforcement) treats paid-entry cash-prize contests as gambling.

Even if you switched entry fees to Play Billing (paying Google 15–30% on top of
your own 10% commission), policy 2 would still block the cash-prize model. So
the practical answer is: **don't take money in the Android app.**

> This is a summary of our reading of the policies, not legal advice. Verify the
> current text of both policies — and Indonesian rules on paid-entry contests —
> before you publish.

## What `STORE_BUILD=true` changes

`Env.storeBuild` (in `app/lib/core/env.dart`) flips `Env.paymentsEnabled` off,
and every monetary surface disappears at build time:

| Surface | Store build |
|---|---|
| Entry fee on competition cards & detail | hidden |
| Prize-pool amounts | hidden |
| **Register** on a paid competition | replaced with "Paid entry is not available in this app" (no link out) |
| QRIS checkout / manual transfer | unreachable |
| Entry-fee & prize fields when creating a competition | hidden; both forced to `0` |
| Profile → payout details | hidden |
| Admin → Transactions, Payment accounts, Payouts | hidden |
| Admin → platform earnings + gross volume | hidden |

**Free competitions still work end-to-end** — browse, register, brackets, match
reporting, disputes, standings, notifications. That is a legitimate, publishable
tournament-organizer app.

## Recommended distribution split

| Channel | Build | Payments |
|---|---|---|
| **Google Play** | `--dart-define=STORE_BUILD=true` | none — free competitions only |
| **Web (cPanel, your domain)** | normal build | full QRIS + manual transfer |
| **Direct APK** (your site) | normal build | full — sideloaded, outside Play's rules |

The web app is installable as a PWA, so Indonesian users can add it to their home
screen and get an app-like experience with payments intact.

## Build commands

```bash
# Google Play — no payment UI
flutter build appbundle --release \
  --dart-define=STORE_BUILD=true \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

# Web (cPanel) — full payments
flutter build web --release \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

# Direct-download APK — full payments
flutter build apk --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

To wire this into CI, add `STORE_BUILD=true` to the `--dart-define`s in
`.github/workflows/build-android.yml` (or add a separate Play-release workflow)
once you start shipping to Play.

## Before you submit

- [ ] Built with `STORE_BUILD=true`; confirm no fee, prize, checkout, payout, or
      transaction UI appears anywhere in the running app.
- [ ] Store listing does not advertise cash prizes or paid entry.
- [ ] Data safety form filled in (the app collects email, display name, phone).
- [ ] Privacy policy + terms hosted on your domain and linked in the listing.
- [ ] If you ever want paid entry on Play, apply to Google's real-money gaming
      programme first and confirm Indonesia is eligible — do not just switch the
      flag off.
