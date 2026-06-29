# Payouts & platform economics

## Money model

- **Entry fees** are collected via QRIS (see [`QRIS.md`](QRIS.md)).
- On every paid registration the platform keeps **10%**
  (`registrations.platform_fee`), the organizer keeps the rest
  (`registrations.organizer_net`), and the cut is logged to
  `platform_earnings`.
- **Rewards** owed to players/winners are tracked in the `payouts` table
  (`status` = `owed` → `paid`).

## Phase 1: manual payouts (current)

InterActive QRIS is primarily a **payment-acceptance** product. Sending money
out to arbitrary DANA/OVO/bank accounts is a separate **disbursement**
capability with its own KYC/escrow obligations, so the foundation does **not**
move money out automatically. Instead:

1. Users optionally save **payout accounts** (`payout_accounts`) — bank or
   e-wallet (DANA, OVO, GoPay, ShopeePay). This is optional; a user with none is
   fully supported and can add one before claiming a reward.
2. When a competition completes, reward `payouts` rows are created as `owed`.
3. An admin/organizer transfers the funds manually and marks the payout `paid`
   (admin console, Phase 4).

This keeps the platform compliant and shippable while volumes are low.

## Phase 5: automated disbursement (planned)

Integrate a disbursement provider (e.g. **Xendit** or **Flip**) to send rewards
programmatically to bank/e-wallet accounts, with proper escrow (hold entry fees
until completion), KYC, and an audit trail. The `payouts` schema is already
shaped for this — automation flips `owed → paid` via a provider call instead of
a human.

## Escrow & refunds

- Entry fees are conceptually **held** until a competition reaches `completed`;
  on `cancelled`, registrations move to `refunded` and a reversing payout/refund
  is issued.
- All money mutations run inside `SECURITY DEFINER` functions / Edge Functions
  with an append-only `platform_earnings` ledger, so balances are auditable.
