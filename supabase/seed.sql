-- ──────────────────────────────────────────────────────────────
-- TurneyApp — local demo seed (best-effort).
-- Creates a demo organizer + a few competitions so the app has data
-- after `supabase db reset`. Wrapped defensively: if the auth.users
-- shape differs on your CLI version, the seed is skipped rather than
-- aborting the reset — just sign up in the app and create from there.
--
-- Demo login:  organizer@turneyapp.test  /  password123
-- ──────────────────────────────────────────────────────────────
do $$
declare
  v_uid uuid := '11111111-1111-1111-1111-111111111111';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  )
  values (
    '00000000-0000-0000-0000-000000000000', v_uid, 'authenticated',
    'authenticated', 'organizer@turneyapp.test',
    crypt('password123', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Demo Organizer"}',
    false, '', '', '', ''
  )
  on conflict (id) do nothing;

  -- handle_new_user() created the profile; promote to organizer.
  update profiles set role = 'organizer', display_name = 'Demo Organizer'
   where id = v_uid;

  insert into competitions (
    organizer_id, title, description, format, max_participants,
    entry_fee, prize_pool, status, slug, tech_meeting_url,
    tech_meeting_type, starts_at
  )
  values
    (v_uid, 'Mobile Legends Weekend Cup',
     'Open 1v1 bracket. Best of 3 per match. Join Discord for the technical meeting.',
     'single_elim', 16, 25000, 300000, 'open', 'ml-weekend-cup-demo01',
     'https://discord.gg/example', 'discord', now() + interval '3 days'),
    (v_uid, 'FC Mobile League — Round Robin',
     'Everyone plays everyone. Standings by wins, then goal difference.',
     'round_robin', 8, 15000, 100000, 'open', 'fc-mobile-league-demo02',
     'https://chat.whatsapp.com/example', 'whatsapp', now() + interval '7 days'),
    (v_uid, 'Free Community Scrims',
     'No entry fee — practice bracket to warm up for the season.',
     'single_elim', 32, 0, 0, 'open', 'community-scrims-demo03',
     null, 'other', now() + interval '1 day')
  on conflict (slug) do nothing;
exception
  when others then
    raise notice 'Seed skipped (%): create data via the app instead.', sqlerrm;
end;
$$;
