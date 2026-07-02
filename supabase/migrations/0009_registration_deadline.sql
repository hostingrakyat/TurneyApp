-- ──────────────────────────────────────────────────────────────
-- ProTourney — optional registration deadline.
-- After this timestamp the app stops accepting new registrations
-- (enforced client-side; the create-invoice function still guards payment).
-- ──────────────────────────────────────────────────────────────

alter table competitions
  add column if not exists registration_deadline timestamptz;
