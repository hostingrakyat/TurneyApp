# Manual payment confirmation

Alongside automatic QRIS, players can pay their entry fee by **manual transfer**
to the platform's own accounts (bank transfer, OVO, DANA, GoPay). An admin
confirms each transfer by hand. QRIS stays fully automatic.

## How it works

1. **Admin sets the receiving accounts** — Admin console → *Payment accounts*.
   Fill in the account holder name + number (and bank name for bank transfer)
   for any of bank / OVO / DANA / GoPay, and toggle it **Active**. Only active,
   filled-in accounts are offered to players.
2. **Player picks a method at checkout** — after entering their phone, the
   checkout shows *Choose a payment method*: **QRIS** or any active manual
   account. Picking a manual account shows the destination number (with a copy
   button) and the exact amount, plus an optional *sender name* field.
3. **Player transfers and taps "I've transferred"** — this holds their spot as
   **pending**. They are registered but not yet counted as a paid participant,
   so a pending entry is never seeded into a bracket.
4. **Admin confirms** — Admin console → *Transactions*. Pending manual transfers
   surface at the top with **Confirm** / **Reject**. Confirming runs the same
   10% fee split as the QRIS callback (`confirm_registration_payment`) and marks
   the registration paid; rejecting releases the held spot.

## Backend (Supabase)

- Migration `0014_manual_payments.sql` adds the `platform_payment_accounts`
  table (RLS: any signed-in user can read; only admins can write) and the
  `method` / `reference` / `proof_url` columns on `payments`.
- Edge function `manual-create-payment` creates the pending registration +
  `provider = 'manual'` payment row (clients can't insert payments directly).
- Edge function `admin-confirm-payment` verifies the caller is an admin, then
  either confirms (fee split via the existing RPC) or rejects (marks the payment
  failed and releases the registration).

Deploy the functions with:

```
supabase functions deploy manual-create-payment
supabase functions deploy admin-confirm-payment
```

## Offline demo

Everything above works with **zero setup** in demo mode (no Supabase): the
platform accounts are seeded with placeholders you can edit, and the whole
submit → confirm/reject loop runs against the in-memory store.
