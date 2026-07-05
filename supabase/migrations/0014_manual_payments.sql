-- ── Manual payment confirmation ───────────────────────────────
-- Players can pay their entry fee by manual bank transfer / e-wallet (OVO,
-- DANA, GoPay) to the platform's own accounts, which an admin confirms by
-- hand. QRIS stays fully automatic (see qris-create-invoice / qris-callback).

-- The platform's receiving accounts, one per method, managed by admins.
create table if not exists platform_payment_accounts (
  id             uuid primary key default gen_random_uuid(),
  method         text not null unique,      -- 'bank' | 'ovo' | 'dana' | 'gopay'
  account_name   text not null default '',
  account_number text not null default '',
  bank_name      text,
  instructions   text,
  is_active      boolean not null default true,
  updated_at     timestamptz not null default now()
);

alter table platform_payment_accounts enable row level security;

-- Any signed-in user needs to see where to transfer; only admins may edit.
create policy ppa_select on platform_payment_accounts
  for select to authenticated using (true);
create policy ppa_write on platform_payment_accounts
  for all to authenticated using (is_admin()) with check (is_admin());

-- Start with an (empty) row per method so admins have something to fill in.
insert into platform_payment_accounts (method) values
  ('bank'), ('ovo'), ('dana'), ('gopay')
on conflict (method) do nothing;

-- Manual-transfer metadata on the shared payments table (null for QRIS rows).
alter table payments add column if not exists method    text;   -- 'bank'|'ovo'|'dana'|'gopay'
alter table payments add column if not exists reference text;   -- sender name / note
alter table payments add column if not exists proof_url text;   -- optional transfer proof
