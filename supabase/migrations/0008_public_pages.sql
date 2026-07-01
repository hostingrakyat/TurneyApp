-- ──────────────────────────────────────────────────────────────
-- ProTourney — public tournament pages (share links / `/c/:slug`).
--
-- Grants ANONYMOUS read of competitions + matches only, so anyone with a
-- share link can follow the bracket without an account. Registrations,
-- payments, payout accounts and PROFILES stay private (profiles hold phone
-- numbers) — player display names are already denormalized onto `matches`,
-- so the public bracket needs no profile access.
-- ──────────────────────────────────────────────────────────────

grant usage on schema public to anon;
grant select on competitions to anon;
grant select on matches to anon;

-- Competitions: expose everything except unpublished drafts.
drop policy if exists comp_public_select on competitions;
create policy comp_public_select on competitions
  for select to anon using (status <> 'draft');

-- Matches (only exist once a bracket is generated).
drop policy if exists matches_public_select on matches;
create policy matches_public_select on matches
  for select to anon using (true);
