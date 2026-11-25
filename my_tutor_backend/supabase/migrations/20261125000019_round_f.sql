-- Round F — money and booking rules.
-- Safe to run once (and harmless if run again). Deletes no data.
-- Owner decisions (24 Nov 2026): prices shown in Syrian pounds with dollars small (rate set in admin Settings;
-- amounts are still stored in dollars and converted for display / entry); a tutor with no working hours saved
-- is not bookable; earnings are held 48 hours.

-- ── Settings ──────────────────────────────────────────────────────────────────────────────────────────────────
insert into app_settings (key, value) values
  ('earnings_hold_hours', to_jsonb(48)),        -- hours after delivery / no-show before earnings can be withdrawn
  ('usd_to_syp', to_jsonb(0)),                  -- Syrian pounds per dollar for display and entry (0 = not set: dollars)
  ('display_currency', to_jsonb('SYP'::text)),  -- 'SYP' (pounds, dollars small) or 'USD'
  ('bookable_without_hours', to_jsonb(false))   -- false: a tutor with no working hours saved cannot be booked
on conflict (key) do nothing;

-- ── F1. Disputes on no-shows, and a hold on earnings ─────────────────────────────────────────────────────────
alter table lessons add column if not exists no_show_at timestamptz;

-- Earnings not yet withdrawable: lessons in dispute, and earnings younger than the hold.
-- A refunded (cancelled) lesson is not held: its earning was already reversed by an adjustment.
create or replace function held_earnings(p_user uuid) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce(sum(w.amount), 0) from wallet_transactions w join lessons l on l.id = w.lesson_id
  where w.user_id = p_user and w.kind = 'earning' and l.status <> 'cancelled'
    and (l.status = 'disputed'
         or w.created_at > now() - make_interval(hours => coalesce(setting_num('earnings_hold_hours'), 48)::int));
$$;
revoke execute on function held_earnings(uuid) from public, anon, authenticated;

-- The money a user can spend or withdraw: everything in the ledger minus held earnings. Payouts, and paying for
-- lessons and packages from the balance, all use this, so held earnings can be neither withdrawn nor spent.
create or replace function wallet_balance(p_user uuid) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce((select sum(amount) from wallet_transactions where user_id = p_user), 0) - held_earnings(p_user);
$$;

-- What the app shows in the wallet: total, held and available.
create or replace function my_wallet() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'total', coalesce((select sum(amount) from wallet_transactions where user_id = auth.uid()), 0),
    'held', held_earnings(auth.uid()),
    'available', wallet_balance(auth.uid()),
    'hold_hours', coalesce(setting_num('earnings_hold_hours'), 48))
  where auth.uid() is not null;
$$;
revoke execute on function my_wallet() from public, anon;
grant execute on function my_wallet() to authenticated;

create or replace function report_student_no_show(p_lesson uuid)
returns void language plpgsql security definer set search_path = public as $$
declare u uuid := me(); l lessons%rowtype;
begin
  select * into l from lessons where id = p_lesson for update;
  if l.id is null or l.tutor_id <> u then raise exception 'Lesson not found'; end if;
  if l.status <> 'confirmed' or now() < l.starts_at + interval '15 minutes' then
    raise exception 'You can report a no-show 15 minutes after the start time';
  end if;
  update lessons set status = 'no_show', no_show_at = now() where id = l.id;
  perform credit_tutor_internal(l.id);         -- held like every earning; the student can dispute for 48 hours
  perform push_notification(l.student_id, 'Missed lesson',
    'Lesson #' || l.number || ' was marked as no-show. If you attended, report it within 48 hours.',
    jsonb_build_object('lesson_id', l.id));
end $$;

-- A student may now also dispute a no-show, within 48 hours of it being marked.
create or replace function dispute_lesson(p_lesson uuid, p_reason text)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); l lessons%rowtype; rep uuid;
begin
  select * into l from lessons where id = p_lesson for update;
  if l.id is null or l.student_id <> u then raise exception 'Lesson not found'; end if;
  if coalesce(btrim(p_reason), '') = '' or length(p_reason) > 2000 then raise exception 'Write what happened (up to 2000 characters)'; end if;
  if l.status = 'no_show' then
    if coalesce(l.no_show_at, l.starts_at + make_interval(mins => l.duration_min)) < now() - interval '48 hours' then
      raise exception 'Reports must be made within 48 hours';
    end if;
  elsif l.status not in ('confirmed', 'delivered') or l.starts_at > now() then
    raise exception 'You can report a lesson after it starts';
  elsif l.delivered_at is not null and l.delivered_at < now() - interval '48 hours' then
    raise exception 'Reports must be made within 48 hours';
  end if;
  update lessons set status = 'disputed' where id = l.id;    -- the tutor's earning stays held until the admin decides
  insert into reports (reporter_id, target_type, target_id, reason) values (u, 'lesson', l.id::text, btrim(p_reason)) returning id into rep;
  perform push_notification(l.tutor_id, 'Lesson reported', 'The student reported lesson #' || l.number || '. Dars will review it.',
    jsonb_build_object('lesson_id', l.id));
  return rep;
end $$;

-- ── F2. Package discounts: the tutor's own four numbers, charged exactly ─────────────────────────────────────
alter table tutor_profiles add column if not exists package_discounts jsonb;

-- Discount for a package of p_hours: the tutor's saved number for that size (4 / 8 / 12 / 20 h); tutors who never
-- saved numbers keep the old rule (a share of max_package_discount). New tutors start at 0 %.
create or replace function package_discount(p_tutor uuid, p_hours int) returns int
language sql stable security definer set search_path = public as $$
  select case
    when p_hours is null or p_hours < 4 then 0
    when package_discounts is not null then greatest(0, least(50, coalesce((package_discounts ->>
         case when p_hours >= 20 then '20' when p_hours >= 12 then '12' when p_hours >= 8 then '8' else '4' end)::int, 0)))
    when max_package_discount = 0 then 0
    else greatest(1, round(max_package_discount *
         case when p_hours >= 20 then 1 when p_hours >= 12 then .75 when p_hours >= 8 then .5 else .25 end)::int)
  end
  from tutor_profiles where user_id = p_tutor;
$$;

create or replace function set_package_discounts(p_discounts jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u uuid := me(); k text; v jsonb; d jsonb := '{}';
begin
  if not exists (select 1 from tutor_profiles where user_id = u) then raise exception 'Tutors only'; end if;
  if p_discounts is null or jsonb_typeof(p_discounts) <> 'object' then raise exception 'Invalid discounts'; end if;
  foreach k in array array['4', '8', '12', '20'] loop
    v := p_discounts -> k;
    if v is null or jsonb_typeof(v) <> 'number' or (v #>> '{}')::numeric <> floor((v #>> '{}')::numeric)
       or (v #>> '{}')::int < 0 or (v #>> '{}')::int > 50 then
      raise exception 'Each discount must be a whole number from 0 to 50';
    end if;
    d := d || jsonb_build_object(k, (v #>> '{}')::int);
  end loop;
  update tutor_profiles set package_discounts = d,
         max_package_discount = greatest((d->>'4')::int, (d->>'8')::int, (d->>'12')::int, (d->>'20')::int)
  where user_id = u;
  return d;
end $$;
revoke execute on function set_package_discounts(jsonb) from public, anon;
grant execute on function set_package_discounts(jsonb) to authenticated;

-- ── F6. The price level is the student's own (no choosing the cheapest level) ────────────────────────────────
-- A student with a level in the profile is quoted and charged at that level; visitors and students without a
-- level may still pass one.
create or replace function price_quote(p_tutor uuid, p_level text default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'level', lvl,
    'hourly', tutor_price(p_tutor, lvl),
    'discounts', jsonb_build_object('4', package_discount(p_tutor, 4), '8', package_discount(p_tutor, 8),
                                    '12', package_discount(p_tutor, 12), '20', package_discount(p_tutor, 20)))
  from (select coalesce((select level_id from profiles where id = auth.uid()),
                        (select id from study_levels where id = p_level), 'high') as lvl) x
  where exists (select 1 from tutor_profiles where user_id = p_tutor and verification = 'approved');
$$;

create or replace function guard_booking_level() returns trigger
language plpgsql set search_path = public as $$
declare own text;
begin
  if tg_table_name = 'lessons' then
    if to_jsonb(new) ->> 'package_id' is not null or to_jsonb(new) ->> 'child_id' is not null then return new; end if;
  end if;
  -- a parent booking for a child: the child's level counts (set by book_lesson_for_child for this booking)
  own := nullif(current_setting('dars.child_level', true), '');
  if own is null then select level_id into own from profiles where id = new.student_id; end if;
  if own is not null and new.level_id is not null and new.level_id <> own then
    raise exception 'Lessons are priced at your own study level. Change it in your profile if it is wrong';
  end if;
  return new;
end $$;
-- Booking for a child: priced at the child's level when the child profile has one.
create or replace function book_lesson_for_child(
  p_child uuid, p_tutor uuid, p_starts_at timestamptz, p_duration int,
  p_subject text default null, p_level text default null,
  p_mode lesson_mode default 'online', p_notes text default null,
  p_use_wallet boolean default true, p_method payment_method default 'card')
returns jsonb language plpgsql security definer set search_path = public as $$
declare c child_profiles%rowtype; r jsonb; lvl text;
begin
  select * into c from child_profiles where id = p_child and parent_id = me();
  if not found then raise exception 'Not your child'; end if;
  lvl := coalesce(c.level_id, (select id from study_levels where id = p_level), 'high');
  perform set_config('dars.child_level', lvl, true);
  r := book_lesson(p_tutor, p_starts_at, p_duration, p_subject, lvl, p_mode, p_notes, p_use_wallet, p_method);
  perform set_config('dars.child_level', '', true);
  update lessons set child_id = c.id, child_name = c.full_name where id = (r->>'lesson_id')::uuid;
  return r || jsonb_build_object('child_name', c.full_name);
end $$;

drop trigger if exists lessons_booking_level on lessons;
create trigger lessons_booking_level before insert on lessons for each row execute function guard_booking_level();
drop trigger if exists packages_booking_level on packages;
create trigger packages_booking_level before insert on packages for each row execute function guard_booking_level();

-- ── F3. Working hours: touching periods joined, lessons across midnight, no hours = not bookable ─────────────
create or replace function assert_slot_free(p_tutor uuid, p_start timestamptz, p_minutes int) returns void
language plpgsql security definer set search_path = public as $$
declare off int; loc timestamp; loc_end timestamp; covered boolean;
begin
  perform pg_advisory_xact_lock(2, hashtext(p_tutor::text));
  if p_start is null or p_minutes is null or p_minutes <= 0 then raise exception 'Choose a time and a length'; end if;
  if p_start < now() then raise exception 'Choose a time in the future'; end if;
  if exists (select 1 from lessons
             where tutor_id = p_tutor and status in ('pending_payment', 'confirmed')
               and tstzrange(starts_at, starts_at + make_interval(mins => duration_min))
                && tstzrange(p_start, p_start + make_interval(mins => p_minutes))) then
    raise exception 'The tutor already has a lesson at this time';
  end if;
  if not exists (select 1 from availability_slots where tutor_id = p_tutor) then
    if coalesce((select (value #>> '{}')::boolean from app_settings where key = 'bookable_without_hours'), false) then return; end if;
    raise exception 'This tutor is not taking bookings yet';
  end if;
  select tz_offset_min into off from tutor_profiles where user_id = p_tutor;
  loc := (p_start at time zone 'UTC') + make_interval(mins => coalesce(off, 180));
  loc_end := loc + make_interval(mins => p_minutes);
  -- All the tutor's periods on the days the lesson touches, joined where they meet (09–12 + 12–15 = 09–15,
  -- 22–24 on one day + 00–02 on the next = 22–02); the lesson must lie inside one joined stretch.
  select coalesce(range_agg(tsrange(g.d + s.start_time, g.d + s.end_time)) @> tsrange(loc, loc_end), false) into covered
  from generate_series((loc::date - 1)::timestamp, loc_end::date::timestamp, interval '1 day') as g(d)
  join availability_slots s on s.tutor_id = p_tutor and s.weekday = extract(dow from g.d)::int;
  if not covered then raise exception 'This time is outside the tutor''s working hours'; end if;
end $$;

-- ── F6. Admin-set passwords: at least 10 characters, and the user is signed out everywhere ───────────────────
create or replace function admin_set_user_password(p_user uuid, p_password text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform require_admin();
  if p_password is null or char_length(p_password) < 10 then
    raise exception 'Password must be at least 10 characters';
  end if;
  update auth.users
     set encrypted_password = crypt(p_password, gen_salt('bf')), updated_at = now()
   where id = p_user;
  if not found then raise exception 'User not found'; end if;
  delete from auth.refresh_tokens where user_id::text = p_user::text;   -- signed out on every phone and browser
  delete from auth.sessions where user_id = p_user;
  perform audit('user_password_reset', p_user::text);   -- the password itself is never logged
end $$;
