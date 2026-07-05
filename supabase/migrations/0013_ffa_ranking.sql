-- ──────────────────────────────────────────────────────────────
-- ProTourney — free-for-all: top-N advancement + final podium.
-- The organizer decides how many advance per lobby (reuses
-- competitions.advance_per_group) and how many winners the final has.
-- Lobby results are an ordered ranking (podium) in matches.rankings.
-- ──────────────────────────────────────────────────────────────

alter table competitions
  add column if not exists final_winners int not null default 1;

-- Ordered finish list for a lobby: jsonb [{id,name}] (1st, 2nd, …).
alter table matches
  add column if not exists rankings jsonb;
