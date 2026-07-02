-- ──────────────────────────────────────────────────────────────
-- ProTourney — live brackets. Publishes `matches` on Supabase Realtime so
-- players and spectators (incl. the anonymous /c/:slug page) see results
-- update instantly. RLS still applies to realtime, and anon can already read
-- matches (migration 0008), so public viewers get live updates too.
-- ──────────────────────────────────────────────────────────────

-- Full row on updates/deletes so the competition_id filter matches.
alter table matches replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'matches'
  ) then
    alter publication supabase_realtime add table matches;
  end if;
end $$;
