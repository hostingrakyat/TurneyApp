-- ──────────────────────────────────────────────────────────────
-- TurneyApp — Row Level Security
-- Money & match-state mutations go through SECURITY DEFINER
-- functions (0002); these policies gate ordinary client access.
-- ──────────────────────────────────────────────────────────────

-- Lock down the privileged functions: only the service role / cron runs them.
revoke execute on function confirm_registration_payment(uuid, jsonb) from public;
revoke execute on function resolve_due_matches() from public;

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

alter table profiles            enable row level security;
alter table payout_accounts     enable row level security;
alter table competitions        enable row level security;
alter table competition_images  enable row level security;
alter table registrations       enable row level security;
alter table payments            enable row level security;
alter table matches             enable row level security;
alter table match_streams       enable row level security;
alter table match_reports       enable row level security;
alter table disputes            enable row level security;
alter table payouts             enable row level security;
alter table platform_earnings   enable row level security;

-- ── profiles ──────────────────────────────────────────────────
create policy profiles_select on profiles
  for select to authenticated using (true);
create policy profiles_insert on profiles
  for insert to authenticated with check (id = auth.uid());
create policy profiles_update on profiles
  for update to authenticated
  using (id = auth.uid() or is_admin())
  with check (id = auth.uid() or is_admin());

-- ── payout_accounts (owner-only) ──────────────────────────────
create policy payout_select on payout_accounts
  for select to authenticated using (user_id = auth.uid() or is_admin());
create policy payout_insert on payout_accounts
  for insert to authenticated with check (user_id = auth.uid());
create policy payout_update on payout_accounts
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy payout_delete on payout_accounts
  for delete to authenticated using (user_id = auth.uid() or is_admin());

-- ── competitions ──────────────────────────────────────────────
create policy comp_select on competitions
  for select to authenticated
  using (status <> 'draft' or organizer_id = auth.uid() or is_admin());
create policy comp_insert on competitions
  for insert to authenticated with check (organizer_id = auth.uid());
create policy comp_update on competitions
  for update to authenticated
  using (organizer_id = auth.uid() or is_admin())
  with check (organizer_id = auth.uid() or is_admin());
create policy comp_delete on competitions
  for delete to authenticated
  using (organizer_id = auth.uid() or is_admin());

-- ── competition_images ────────────────────────────────────────
create policy compimg_select on competition_images
  for select to authenticated using (true);
create policy compimg_write on competition_images
  for all to authenticated
  using (is_competition_organizer(competition_id) or is_admin())
  with check (is_competition_organizer(competition_id) or is_admin());

-- ── registrations ─────────────────────────────────────────────
create policy reg_select on registrations
  for select to authenticated
  using (user_id = auth.uid()
         or is_competition_organizer(competition_id)
         or is_admin());
create policy reg_insert on registrations
  for insert to authenticated with check (user_id = auth.uid());
create policy reg_update on registrations
  for update to authenticated
  using (is_competition_organizer(competition_id) or is_admin())
  with check (is_competition_organizer(competition_id) or is_admin());
create policy reg_delete on registrations
  for delete to authenticated using (user_id = auth.uid() or is_admin());

-- ── payments ──────────────────────────────────────────────────
create policy pay_select on payments
  for select to authenticated
  using (
    is_admin()
    or exists (
      select 1 from registrations r
      where r.id = registration_id
        and (r.user_id = auth.uid()
             or is_competition_organizer(r.competition_id))
    )
  );
create policy pay_write on payments
  for all to authenticated
  using (is_admin()) with check (is_admin());

-- ── matches (brackets are public) ─────────────────────────────
create policy match_select on matches
  for select to authenticated using (true);
create policy match_write on matches
  for all to authenticated
  using (is_competition_organizer(competition_id) or is_admin())
  with check (is_competition_organizer(competition_id) or is_admin());

-- ── match_streams (pre-match) ─────────────────────────────────
create policy stream_select on match_streams
  for select to authenticated using (true);
create policy stream_insert on match_streams
  for insert to authenticated with check (user_id = auth.uid());
create policy stream_modify on match_streams
  for update to authenticated
  using (user_id = auth.uid() or is_admin())
  with check (user_id = auth.uid() or is_admin());
create policy stream_delete on match_streams
  for delete to authenticated using (user_id = auth.uid() or is_admin());

-- ── match_reports (post-match) ────────────────────────────────
create policy report_select on match_reports
  for select to authenticated
  using (
    is_admin()
    or exists (
      select 1 from matches mt
      where mt.id = match_id
        and (mt.player1_id = auth.uid()
             or mt.player2_id = auth.uid()
             or is_competition_organizer(mt.competition_id))
    )
  );
create policy report_insert on match_reports
  for insert to authenticated with check (reporter_id = auth.uid());

-- ── disputes ──────────────────────────────────────────────────
create policy dispute_select on disputes
  for select to authenticated
  using (
    is_admin()
    or exists (
      select 1 from matches mt
      where mt.id = match_id and is_competition_organizer(mt.competition_id)
    )
  );
create policy dispute_update on disputes
  for update to authenticated
  using (
    is_admin()
    or exists (
      select 1 from matches mt
      where mt.id = match_id and is_competition_organizer(mt.competition_id)
    )
  )
  with check (true);

-- ── payouts ───────────────────────────────────────────────────
create policy payout_row_select on payouts
  for select to authenticated using (user_id = auth.uid() or is_admin());
create policy payout_row_write on payouts
  for all to authenticated using (is_admin()) with check (is_admin());

-- ── platform_earnings (admin only) ────────────────────────────
create policy earnings_select on platform_earnings
  for select to authenticated using (is_admin());
