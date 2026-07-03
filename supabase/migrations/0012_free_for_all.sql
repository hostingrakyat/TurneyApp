-- ──────────────────────────────────────────────────────────────
-- ProTourney — free-for-all (lobby) format. Each match holds N players
-- (a lobby) instead of two; the organizer sets N. The lobby roster lives in
-- matches.players (jsonb: [{id,name}]) and the winner is match.winner_id.
-- ──────────────────────────────────────────────────────────────

alter table competitions
  add column if not exists lobby_size int not null default 8;

alter table matches
  add column if not exists players jsonb;
