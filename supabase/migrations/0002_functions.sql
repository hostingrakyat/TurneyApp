-- ──────────────────────────────────────────────────────────────
-- TurneyApp — triggers, helpers, and money/match logic
-- ──────────────────────────────────────────────────────────────

-- New auth user → profile row.
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name',
             split_part(new.email, '@', 1),
             'Player')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Auto-generate a URL slug from the title when not provided.
create or replace function set_competition_slug()
returns trigger
language plpgsql
as $$
begin
  if new.slug is null or new.slug = '' then
    new.slug := regexp_replace(lower(new.title), '[^a-z0-9]+', '-', 'g');
    new.slug := regexp_replace(new.slug, '(^-+|-+$)', '', 'g');
    new.slug := new.slug || '-' ||
                substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);
  end if;
  return new;
end;
$$;

drop trigger if exists competitions_set_slug on competitions;
create trigger competitions_set_slug
  before insert on competitions
  for each row execute function set_competition_slug();

-- ── Authorization helpers (used by RLS) ───────────────────────
create or replace function is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from profiles where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function is_competition_organizer(p_comp uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from competitions
    where id = p_comp and organizer_id = auth.uid()
  );
$$;

-- ── Money: confirm a QRIS payment and split the 10% platform fee ─
-- Single source of truth for the fee split. Idempotent: a repeated
-- callback for an already-paid payment is a no-op.
create or replace function confirm_registration_payment(
  p_payment_id uuid,
  p_raw jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment payments%rowtype;
  v_reg     registrations%rowtype;
  v_rate    numeric := 0.10;          -- platform commission (10%)
  v_fee     int;
  v_net     int;
begin
  select * into v_payment from payments where id = p_payment_id for update;
  if not found then
    raise exception 'payment % not found', p_payment_id;
  end if;
  if v_payment.status = 'paid' then
    return;                            -- already processed
  end if;

  update payments
     set status = 'paid', paid_at = now(), raw = coalesce(p_raw, raw)
   where id = p_payment_id;

  select * into v_reg
    from registrations where id = v_payment.registration_id for update;

  v_fee := round(v_reg.entry_fee * v_rate);
  v_net := v_reg.entry_fee - v_fee;

  update registrations
     set status = 'paid', platform_fee = v_fee, organizer_net = v_net
   where id = v_reg.id;

  insert into platform_earnings (registration_id, competition_id, amount)
  values (v_reg.id, v_reg.competition_id, v_fee);
end;
$$;

-- ── Matches: auto-resolve results after the report window ──────
-- Agreeing reports (incl. a single report) → winner + completed.
-- Conflicting reports → match disputed + a dispute row (notified
-- by the resolve-matches Edge Function). Returns rows touched.
create or replace function resolve_due_matches()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  m                record;
  v_report_count   int;
  v_distinct_wins  int;
  v_sole_winner    uuid;
  v_resolved       int := 0;
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
      continue;                                  -- nobody reported yet
    elsif v_distinct_wins = 1 then
      select claimed_winner_id into v_sole_winner
        from match_reports where match_id = m.id limit 1;
      update matches
         set status = 'completed', winner_id = v_sole_winner
       where id = m.id;
      -- TODO(Phase 2/3): advance winner into the next bracket match.
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
