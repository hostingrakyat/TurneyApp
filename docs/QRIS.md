# QRIS payments (InterActive QRIS / qris.id)

ProTourney uses **InterActive QRIS** for entry-fee payments. One QR is payable by
any QRIS-enabled app (GoPay, OVO, DANA, ShopeePay, m-banking, …).

> QRIS is the **automatic** path. Players can also pay by **manual bank / e-wallet
> transfer** to platform accounts that an admin confirms by hand — see
> [`MANUAL_PAYMENTS.md`](MANUAL_PAYMENTS.md).

- Product / register for OPEN API: https://qris.interactive.co.id/homepage/open-api.php
- API docs: https://qris.id/api-doc/

> Access requires an Indonesian legal entity (SIUP/NIB, company deed, NPWP) per
> qris.id. Until you have an `APIKEY`, keep `QRIS_MOCK=true` — the full flow
> (invoice → QR → callback → fee split) works end-to-end against a mock payload.

## Flow

1. **Create invoice** — the client calls the `qris-create-invoice` Edge
   Function with `competition_id`. It upserts a `pending_payment` registration,
   creates a QRIS invoice, stores a `payments` row, and returns
   `{ invoice_id, qris_string, amount, platform_fee, payment_id, mock }`.
2. **Pay** — the app renders `qris_string` with `qr_flutter`; the user scans
   and pays.
3. **Callback** — qris.id calls `qris-callback`, which verifies
   `QRIS_CALLBACK_SECRET`, looks up the payment by `invoice_id`, and calls
   `confirm_registration_payment()` to mark it paid and split the 10% fee
   (idempotent — repeat callbacks are no-ops).
4. **Confirm in-app** — for a real (non-mock) invoice the checkout screen polls
   `payments.status` every few seconds (and offers an "I've paid — check now"
   button); when it reads `paid` it records the player's phone and shows the
   success screen. Mock invoices skip polling and use the "Simulate payment"
   button instead.

## Mock vs live — who decides

`isMock()` (in `_shared/qris.ts`) resolves the mode in this order:

1. **No `QRIS_API_KEY` → always mock** (safety: never attempt a live call
   without a key).
2. Otherwise the **admin Configuration** toggle wins: `qris-create-invoice`
   reads `app_settings.qris_mock` and passes it in. Set it from the in-app
   admin **Configuration** screen (Admin → Configuration → QRIS → Mock mode).
3. If the DB value is unset, the env default `QRIS_MOCK` (default `true`)
   applies.

So to go fully live you need **both** the live keys set as secrets **and**
`app_settings.qris_mock = false` (mock toggle off in the admin screen).

## Going live

Set the secrets (Edge Function env), then flip mock off:

```bash
supabase secrets set QRIS_MOCK=false \
  QRIS_API_KEY=...        \
  QRIS_MERCHANT_ID=...    \
  QRIS_BASE_URL=https://qris.interactive.co.id/restapi/qris/show_qris.php \
  QRIS_CALLBACK_SECRET=$(openssl rand -hex 16)
```

Configure your qris.id callback URL to:

```
https://<project-ref>.functions.supabase.co/qris-callback?secret=<QRIS_CALLBACK_SECRET>
```

## Field mapping (adjust to your account)

The live call lives in `supabase/functions/_shared/qris.ts`
(`createLiveQrisInvoice`). It POSTs `application/x-www-form-urlencoded`:

| Request field | Source |
|---------------|--------|
| `do` | `create-invoice` |
| `apikey` | `QRIS_API_KEY` |
| `mID` | `QRIS_MERCHANT_ID` |
| `cliTrxNumber` | our `registration.id` (used to reconcile) |
| `cliTrxAmount` | entry fee (Rupiah, integer) |

Response is read as `data.qris_content` (the EMVCo string) and
`data.qris_invoiceid`. **Verify these names against your live response** and
tweak the parser if needed — the function throws if the payload is missing so
mismatches surface immediately.

The callback parser (`qris-callback/index.ts`) accepts JSON or form bodies and
reads `qris_invoiceid`/`invoice_id` and `qris_status`/`status`; statuses in
`{paid, success, settlement, 1, true}` are treated as success.

## Refunds & payouts

Refunds (on cancellation) and reward payouts are tracked in the `payouts` table
and processed manually for now — see [`PAYOUTS.md`](PAYOUTS.md).
