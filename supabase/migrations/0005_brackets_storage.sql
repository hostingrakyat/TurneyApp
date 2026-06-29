-- ──────────────────────────────────────────────────────────────
-- TurneyApp — bracket linkage, denormalized player names, storage
-- buckets, and single-elim advancement in the auto-resolve job.
-- ──────────────────────────────────────────────────────────────

-- Bracket advancement linkage + denormalized names (no joins needed in UI).
alter table matches add column if not exists next_match_id uuid;
alter table matches add column if not exists next_slot int;
alter table matches add column if not exists player1_name text;
alter table matches add column if not exists player2_name text;

-- ── Storage buckets (public read) ─────────────────────────────
insert into storage.buckets (id, name, public)
values ('banners', 'banners', true), ('screenshots', 'screenshots', true)
on conflict (id) do nothing;

drop policy if exists "turney public read" on storage.objects;
create policy "turney public read" on storage.objects
  for select using (bucket_id in ('banners', 'screenshots'));

drop policy if exists "turney auth upload" on storage.objects;
create policy "turney auth upload" on storage.objects
  for insert to authenticated
  with check (bucket_id in ('banners', 'screenshots'));

drop policy if exists "turney auth update" on storage.objects;
create policy "turney auth update" on storage.objects
  for update to authenticated
  using (bucket_id in ('banners', 'screenshots'));

-- ── Auto-resolve with single-elim advancement ────────────────
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

      -- Advance the winner into the next bracket match (single-elim).
      if m.next_match_id is not null and m.next_slot is not null then
        if m.next_slot = 1 then
          update matches
             set player1_id = v_sole_winner, player1_name = v_winner_name
           where id = m.next_match_id;
        else
          update matches
             set player2_id = v_sole_winner, player2_name = v_winner_name
           where id = m.next_match_id;
        end if;
      else
        update competitions set status = 'completed'
         where id = m.competition_id;
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
