-- ──────────────────────────────────────────────────────────────
-- ProTourney — push notifications (FCM).
-- Stores per-user device tokens and marks which notifications have been
-- pushed, so the resolve-matches cron can fan out new ones exactly once.
-- ──────────────────────────────────────────────────────────────

create table if not exists device_tokens (
  user_id    uuid not null references auth.users (id) on delete cascade,
  token      text not null,
  platform   text,
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

alter table device_tokens enable row level security;
grant select, insert, update, delete on device_tokens to authenticated;
drop policy if exists dt_owner on device_tokens;
create policy dt_owner on device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Fan-out marker: null = not yet delivered to push.
alter table notifications add column if not exists pushed_at timestamptz;
