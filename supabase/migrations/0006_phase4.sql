-- ──────────────────────────────────────────────────────────────
-- ProTourney — Phase 4: phone/payout at registration, admin app
-- settings (logo + demo toggle), notifications, and champion payouts.
-- ──────────────────────────────────────────────────────────────

-- Contact phone (for organizer outreach to WhatsApp/Telegram groups).
alter table profiles add column if not exists phone text;
alter table registrations add column if not exists phone text;

-- ── Admin-managed app settings (single row) ───────────────────
create table if not exists app_settings (
  id           int primary key default 1,
  app_logo_url text,
  demo_mode    boolean not null default true,
  updated_at   timestamptz not null default now(),
  constraint app_settings_singleton check (id = 1)
);
insert into app_settings (id) values (1) on conflict (id) do nothing;

alter table app_settings enable row level security;
grant select, insert, update on app_settings to authenticated;
drop policy if exists settings_read on app_settings;
create policy settings_read on app_settings
  for select to authenticated using (true);
drop policy if exists settings_write on app_settings;
create policy settings_write on app_settings
  for all to authenticated using (is_admin()) with check (is_admin());

-- Branding storage bucket (admin-writable, public read).
insert into storage.buckets (id, name, public)
values ('branding', 'branding', true)
on conflict (id) do nothing;
drop policy if exists "branding read" on storage.objects;
create policy "branding read" on storage.objects
  for select using (bucket_id = 'branding');
drop policy if exists "branding admin write" on storage.objects;
create policy "branding admin write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'branding' and is_admin());
drop policy if exists "branding admin update" on storage.objects;
create policy "branding admin update" on storage.objects
  for update to authenticated using (bucket_id = 'branding' and is_admin());

-- ── In-app notifications ──────────────────────────────────────
do $$ begin
  create type notification_kind as enum
    ('payment', 'match', 'dispute', 'payout', 'system');
exception when duplicate_object then null; end $$;

create table if not exists notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       notification_kind not null default 'system',
  title      text not null,
  body       text,
  read       boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx
  on notifications (user_id, created_at desc);

alter table notifications enable row level security;
grant select, insert, update, delete on notifications to authenticated;
drop policy if exists notif_select on notifications;
create policy notif_select on notifications
  for select to authenticated using (user_id = auth.uid() or is_admin());
drop policy if exists notif_modify on notifications;
create policy notif_modify on notifications
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists notif_insert on notifications;
create policy notif_insert on notifications
  for insert to authenticated with check (true);

-- ── Champion payout on single-elim completion ─────────────────
-- Re-define resolve_due_matches so that completing the FINAL match also
-- records a payout (owed) for the champion when there is a prize pool.
create or replace function resolve_due_matches()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  m               record;
  v_report_count  int;
  v_distinct_wins int;
  v_sole_winner   uuid;
  v_winner_name   text;
  v_prize         int;
  v_resolved      int := 0;
begin
  for m in
    select * from matches
     where status in ('awaiting_reports', 'auto_resolving')
       and auto_resolve_at is not null
       and auto_resolve_at <= now()
     for update
  loop
    select count(*), count(distinct claimed_winner_id)
      into v_report_count, v_distinct_wins
      from match_reports where match_id = m.id;

    if v_report_count = 0 then
      continue;
    elsif v_distinct_wins = 1 then
      select claimed_winner_id into v_sole_winner
        from match_reports where match_id = m.id limit 1;
      v_winner_name := case
        when v_sole_winner = m.player1_id then m.player1_name
        when v_sole_winner = m.player2_id then m.player2_name
        else null end;

      update matches
         set status = 'completed', winner_id = v_sole_winner
       where id = m.id;

      if m.next_match_id is not null and m.next_slot is not null then
        if m.next_slot = 1 then
          update matches set player1_id = v_sole_winner,
                             player1_name = v_winner_name
           where id = m.next_match_id;
        else
          update matches set player2_id = v_sole_winner,
                             player2_name = v_winner_name
           where id = m.next_match_id;
        end if;
      else
        -- Final match → competition complete + champion payout.
        update competitions set status = 'completed'
         where id = m.competition_id;
        select prize_pool into v_prize
          from competitions where id = m.competition_id;
        if coalesce(v_prize, 0) > 0 and v_sole_winner is not null then
          insert into payouts (user_id, competition_id, amount, status)
          values (v_sole_winner, m.competition_id, v_prize, 'owed');
        end if;
        if v_sole_winner is not null then
          insert into notifications (user_id, kind, title, body)
          values (v_sole_winner, 'payout', 'You won! 🏆',
                  'Congratulations — your reward is being processed.');
        end if;
      end if;
      v_resolved := v_resolved + 1;
    else
      update matches set status = 'disputed' where id = m.id;
      insert into disputes (match_id) values (m.id)
        on conflict (match_id) do nothing;
      v_resolved := v_resolved + 1;
    end if;
  end loop;

  return v_resolved;
end;
$$;

revoke execute on function resolve_due_matches() from public;
