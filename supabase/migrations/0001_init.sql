-- ──────────────────────────────────────────────────────────────
-- TurneyApp — initial schema
-- ──────────────────────────────────────────────────────────────
create extension if not exists "pgcrypto";

-- ── Enums ─────────────────────────────────────────────────────
create type user_role            as enum ('player', 'organizer', 'admin');
create type payout_type          as enum ('bank', 'dana', 'ovo', 'gopay', 'shopeepay');
create type competition_format   as enum ('round_robin', 'single_elim');
create type competition_status   as enum ('draft', 'open', 'ongoing', 'completed', 'cancelled');
create type tech_meeting_type    as enum ('discord', 'whatsapp', 'other');
create type registration_status  as enum ('pending_payment', 'paid', 'refunded', 'cancelled');
create type payment_status       as enum ('pending', 'paid', 'expired', 'failed');
create type match_status         as enum ('scheduled', 'awaiting_reports', 'auto_resolving', 'completed', 'disputed');
create type stream_platform      as enum ('youtube', 'tiktok', 'twitch', 'other');
create type dispute_status       as enum ('open', 'resolved');
create type payout_status        as enum ('owed', 'paid');

-- ── Profiles (1:1 with auth.users) ────────────────────────────
create table profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'Player',
  avatar_url   text,
  role         user_role not null default 'player',
  created_at   timestamptz not null default now()
);

-- ── Reward payout accounts (optional, per user) ───────────────
create table payout_accounts (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  type           payout_type not null,
  account_name   text not null,
  account_number text not null,
  is_default     boolean not null default false,
  created_at     timestamptz not null default now()
);
create index payout_accounts_user_idx on payout_accounts (user_id);

-- ── Competitions ──────────────────────────────────────────────
create table competitions (
  id                uuid primary key default gen_random_uuid(),
  organizer_id      uuid not null references auth.users (id) on delete cascade,
  title             text not null,
  description       text not null default '',
  banner_url        text,
  format            competition_format not null default 'single_elim',
  max_participants  int not null default 16 check (max_participants >= 2),
  entry_fee         int not null default 0 check (entry_fee >= 0),
  prize_pool        int not null default 0 check (prize_pool >= 0),
  status            competition_status not null default 'draft',
  slug              text not null unique,
  tech_meeting_url  text,
  tech_meeting_type tech_meeting_type not null default 'other',
  starts_at         timestamptz,
  created_at        timestamptz not null default now()
);
create index competitions_organizer_idx on competitions (organizer_id);
create index competitions_status_idx on competitions (status);

create table competition_images (
  id             uuid primary key default gen_random_uuid(),
  competition_id uuid not null references competitions (id) on delete cascade,
  url            text not null,
  sort           int not null default 0
);

-- ── Registrations ─────────────────────────────────────────────
create table registrations (
  id             uuid primary key default gen_random_uuid(),
  competition_id uuid not null references competitions (id) on delete cascade,
  user_id        uuid not null references auth.users (id) on delete cascade,
  status         registration_status not null default 'pending_payment',
  entry_fee      int not null default 0,
  platform_fee   int not null default 0,
  organizer_net  int not null default 0,
  created_at     timestamptz not null default now(),
  unique (competition_id, user_id)
);
create index registrations_comp_idx on registrations (competition_id);
create index registrations_user_idx on registrations (user_id);

-- ── Payments (QRIS) ───────────────────────────────────────────
create table payments (
  id              uuid primary key default gen_random_uuid(),
  registration_id uuid not null references registrations (id) on delete cascade,
  provider        text not null default 'qris',
  invoice_id      text,
  qris_string     text,
  amount          int not null,
  status          payment_status not null default 'pending',
  paid_at         timestamptz,
  raw             jsonb,
  created_at      timestamptz not null default now()
);
create index payments_registration_idx on payments (registration_id);
create unique index payments_invoice_idx on payments (invoice_id) where invoice_id is not null;

-- ── Matches & reports ─────────────────────────────────────────
create table matches (
  id               uuid primary key default gen_random_uuid(),
  competition_id   uuid not null references competitions (id) on delete cascade,
  round            int not null default 1,
  bracket_position int not null default 0,
  player1_id       uuid references auth.users (id) on delete set null,
  player2_id       uuid references auth.users (id) on delete set null,
  status           match_status not null default 'scheduled',
  winner_id        uuid references auth.users (id) on delete set null,
  reports_open_at  timestamptz,
  auto_resolve_at  timestamptz,
  created_at       timestamptz not null default now()
);
create index matches_comp_idx on matches (competition_id);
create index matches_resolve_idx on matches (auto_resolve_at) where status in ('awaiting_reports', 'auto_resolving');

create table match_streams (
  id         uuid primary key default gen_random_uuid(),
  match_id   uuid not null references matches (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  platform   stream_platform not null default 'other',
  url        text not null,
  created_at timestamptz not null default now()
);
create index match_streams_match_idx on match_streams (match_id);

create table match_reports (
  id                uuid primary key default gen_random_uuid(),
  match_id          uuid not null references matches (id) on delete cascade,
  reporter_id       uuid not null references auth.users (id) on delete cascade,
  claimed_winner_id uuid references auth.users (id) on delete set null,
  screenshot_url    text,
  created_at        timestamptz not null default now(),
  unique (match_id, reporter_id)
);
create index match_reports_match_idx on match_reports (match_id);

-- ── Disputes ──────────────────────────────────────────────────
create table disputes (
  id              uuid primary key default gen_random_uuid(),
  match_id        uuid not null references matches (id) on delete cascade,
  status          dispute_status not null default 'open',
  resolved_by     uuid references auth.users (id) on delete set null,
  resolution_note text,
  notified_at     timestamptz,
  created_at      timestamptz not null default now(),
  unique (match_id)
);
create index disputes_status_idx on disputes (status);

-- ── Payout bookkeeping & platform ledger ──────────────────────
create table payouts (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  competition_id    uuid references competitions (id) on delete set null,
  amount            int not null,
  status            payout_status not null default 'owed',
  payout_account_id uuid references payout_accounts (id) on delete set null,
  paid_at           timestamptz,
  created_at        timestamptz not null default now()
);
create index payouts_user_idx on payouts (user_id);

create table platform_earnings (
  id              uuid primary key default gen_random_uuid(),
  registration_id uuid references registrations (id) on delete set null,
  competition_id  uuid references competitions (id) on delete set null,
  amount          int not null,
  created_at      timestamptz not null default now()
);
create index platform_earnings_comp_idx on platform_earnings (competition_id);
