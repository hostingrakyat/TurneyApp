-- ──────────────────────────────────────────────────────────────
-- TurneyApp — schedule the match auto-resolve job (every minute)
--
-- Runs the pure DB transitions. Email notifications for new disputes
-- are sent by the `resolve-matches` Edge Function (schedule it via
-- Supabase Dashboard → Edge Functions → Cron, or pg_net). Running both
-- is safe: resolve_due_matches() only touches matches still due.
--
-- pg_cron must be available (it is on Supabase). Guarded so the
-- migration still succeeds on a stack without pg_cron.
-- ──────────────────────────────────────────────────────────────
do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule(
    'resolve-due-matches',
    '* * * * *',
    $cmd$ select public.resolve_due_matches(); $cmd$
  );
exception
  when others then
    raise notice 'pg_cron not scheduled (enable it and re-run): %', sqlerrm;
end;
$$;
