-- ──────────────────────────────────────────────────────────────
-- ProTourney — Iteration 3: round-robin groups + final playoff,
-- and the admin deployment Configuration (domain · QRIS · email).
-- ──────────────────────────────────────────────────────────────

-- ── Round-robin groups + playoff stage ────────────────────────
-- Competitions can split a round-robin into groups of N players and
-- optionally run a final single-elimination playoff from the top finishers.
alter table competitions
  add column if not exists group_size        int     not null default 0;
alter table competitions
  add column if not exists advance_per_group  int     not null default 2;
alter table competitions
  add column if not exists has_playoff        boolean not null default false;

-- Matches carry their group index and stage (`group` round-robin | `elim`
-- playoff). `group` is a reserved word, so the column is `group_no`.
alter table matches
  add column if not exists group_no int  not null default 0;
alter table matches
  add column if not exists stage    text not null default 'group';

-- ── Admin Configuration (non-secret deployment settings) ──────
-- Secret values (QRIS API key, callback secret, Resend key) are NOT stored
-- here — they live in Supabase secrets and are read only by Edge Functions.
alter table app_settings add column if not exists domain           text;
alter table app_settings add column if not exists qris_mock        boolean not null default true;
alter table app_settings add column if not exists qris_merchant_id text;
alter table app_settings add column if not exists qris_store_id    text;
alter table app_settings add column if not exists email_from       text;
