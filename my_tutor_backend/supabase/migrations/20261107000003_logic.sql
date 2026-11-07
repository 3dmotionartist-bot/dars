-- =====================================================================
-- Dars — business logic (RPC). Call from the apps with supabase.rpc('name', {...}).
-- Every function is SECURITY DEFINER, checks who is calling, and keeps money
-- consistent (wallet ledger = source of truth for balances).
-- =====================================================================

-- ---------- internal helpers ----------
create or replace function setting_num(p_key text) returns numeric
language sql stable security definer set search_path = public as $$
  select (value #>> '{}')::numeric from app_settings where key = p_key;
$$;

create or replace function is_service() returns boolean
language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') = 'service_role';
$$;

create or replace function wallet_balance(p_user uuid) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce(sum(amount), 0) from wallet_transactions where user_id = p_user;
$$;

create or replace function me() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Sign in first' using errcode = '28000'; end if;
  if exists (select 1 from profiles where id = u and status <> 'active') then
    raise exception 'This account is not active' using errcode = '28000';
  end if;
  return u;
end $$;

create or replace function require_admin() returns uuid
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  return auth.uid();
end $$;

create or replace function push_notification(p_user uuid, p_title text, p_body text, p_data jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into notifications (user_id, title, body, data) values (p_user, p_title, p_body, p_data);
$$;

create or replace function audit(p_action text, p_target text, p_data jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into audit_log (actor_id, action, target, data) values (auth.uid(), p_action, p_target, p_data);
$$;

-- Hourly price for a level: explicit override, else base × level factor
create or replace function tutor_price(p_tutor uuid, p_level text) returns numeric
language sql stable security definer set search_path = public as $$
  select round(coalesce(
    (select price from tutor_level_prices where tutor_id = p_tutor and level_id = p_level),
    t.hourly_price * coalesce((select price_factor from study_levels where id = p_level), 1)), 2)
  from tutor_profiles t where t.user_id = p_tutor;
$$;

-- Package discount: 25% / 50% / 75% / 100% of the tutor's max for 4 / 8 / 12 / 20+ hours
create or replace function package_discount(p_tutor uuid, p_hours int) returns int
language sql stable security definer set search_path = public as $$
  select case when p_hours < 4 or max_package_discount = 0 then 0
              else greatest(1, round(max_package_discount *
                   case when p_hours >= 20 then 1 when p_hours >= 12 then .75 when p_hours >= 8 then .5 else .25 end)::int)
         end
  from tutor_profiles where user_id = p_tutor;
$$;

create or replace function commission_for(p_tutor uuid) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce((select commission_rate from tutor_profiles where user_id = p_tutor), setting_num('commission_rate'), 0.15);
$$;

create or replace function ensure_conversation(p_student uuid, p_tutor uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare c uuid;
begin
  insert into conversations (student_id, tutor_id) values (p_student, p_tutor)
  on conflict (student_id, tutor_id) do nothing;
  select id into c from conversations where student_id = p_student and tutor_id = p_tutor;
  return c;
end $$;

create or replace function assert_bookable_tutor(p_tutor uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from tutor_profiles t join profiles p on p.id = t.user_id
                 where t.user_id = p_tutor and t.verification = 'approved' and p.status = 'active') then
    raise exception 'This tutor is not available for booking';
  end if;
end $$;

create or replace function assert_slot_free(p_tutor uuid, p_start timestamptz, p_minutes int) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if p_start < now() then raise exception 'Choose a time in the future'; end if;
  if exists (select 1 from lessons
             where tutor_id = p_tutor and status in ('pending_payment', 'confirmed')
               and tstzrange(starts_at, starts_at + make_interval(mins => duration_min))
                && tstzrange(p_start, p_start + make_interval(mins => p_minutes))) then
    raise exception 'The tutor already has a lesson at this time';
  end if;
end $$;

-- =====================================================================
-- STUDENT: book, pay, cancel, review
-- =====================================================================

-- Book a single lesson. Uses wallet credit first; any remainder creates a pending payment.
create or replace function book_lesson(
  p_tutor uuid, p_starts_at timestamptz, p_duration int,
  p_subject text default null, p_level text default null,
  p_mode lesson_mode default 'online', p_notes text default null,
  p_use_wallet boolean default true, p_method payment_method default 'card')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := me();
  lvl text;
  price numeric; comm numeric; use_wallet numeric := 0; due numeric;
  l uuid; pay uuid; st lesson_status;
begin
  if u = p_tutor then raise exception 'You cannot book yourself'; end if;
  perform assert_bookable_tutor(p_tutor);
  perform assert_slot_free(p_tutor, p_starts_at, p_duration);
  if p_mode = 'in_person' and not (select teaches_in_person from tutor_profiles where user_id = p_tutor) then
    raise exception 'This tutor teaches online only';
  end if;
  if p_subject is not null and not exists (select 1 from tutor_subjects where tutor_id = p_tutor and subject_id = p_subject) then
    raise exception 'This tutor does not teach this subject';
  end if;

  lvl   := coalesce(p_level, (select level_id from profiles where id = u), 'high');
  price := round(tutor_price(p_tutor, lvl) * p_duration / 60.0, 2);
  comm  := round(price * commission_for(p_tutor), 2);
  if p_use_wallet then use_wallet := least(greatest(wallet_balance(u), 0), price); end if;
  due := price - use_wallet;
  st  := case when due = 0 then 'confirmed' else 'pending_payment' end;

  insert into lessons (student_id, tutor_id, subject_id, level_id, starts_at, duration_min, mode, status, price, commission, notes)
  values (u, p_tutor, p_subject, lvl, p_starts_at, p_duration, p_mode, st, price, comm, p_notes)
  returning id into l;

  if use_wallet > 0 then
    insert into wallet_transactions (user_id, amount, kind, lesson_id, note) values (u, -use_wallet, 'booking', l, 'Lesson booking');
  end if;
  if due > 0 then
    insert into payments (user_id, lesson_id, amount, method) values (u, l, due, p_method) returning id into pay;
  else
    perform ensure_conversation(u, p_tutor);
    perform push_notification(p_tutor, 'New lesson booked', 'You have a new lesson. Check Upcoming lessons.', jsonb_build_object('lesson_id', l));
  end if;

  return jsonb_build_object('lesson_id', l, 'status', st, 'price', price, 'wallet_used', use_wallet, 'amount_due', due, 'payment_id', pay);
end $$;

-- Buy a package of hours with the tutor's package discount.
create or replace function buy_package(
  p_tutor uuid, p_hours int, p_level text default null,
  p_use_wallet boolean default true, p_method payment_method default 'card')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := me(); lvl text; disc int; price numeric; use_wallet numeric := 0; due numeric; pk uuid; pay uuid;
begin
  perform assert_bookable_tutor(p_tutor);
  if p_hours < 4 then raise exception 'Packages start at 4 hours'; end if;
  lvl   := coalesce(p_level, (select level_id from profiles where id = u), 'high');
  disc  := package_discount(p_tutor, p_hours);
  price := round(tutor_price(p_tutor, lvl) * p_hours * (100 - disc) / 100.0, 2);
  if p_use_wallet then use_wallet := least(greatest(wallet_balance(u), 0), price); end if;
  due := price - use_wallet;

  insert into packages (student_id, tutor_id, level_id, total_hours, discount_pct, price, status)
  values (u, p_tutor, lvl, p_hours, disc, price, case when due = 0 then 'active'::package_status else 'pending_payment' end)
  returning id into pk;

  if use_wallet > 0 then
    insert into wallet_transactions (user_id, amount, kind, note) values (u, -use_wallet, 'booking', 'Package ' || pk);
  end if;
  if due > 0 then
    insert into payments (user_id, package_id, amount, method) values (u, pk, due, p_method) returning id into pay;
  else
    perform push_notification(p_tutor, 'New package purchased', p_hours || ' hours package', jsonb_build_object('package_id', pk));
  end if;
  return jsonb_build_object('package_id', pk, 'discount_pct', disc, 'price', price, 'wallet_used', use_wallet, 'amount_due', due, 'payment_id', pay);
end $$;

-- Book a lesson using hours from an active package.
create or replace function book_from_package(
  p_package uuid, p_starts_at timestamptz, p_duration int,
  p_subject text default null, p_mode lesson_mode default 'online', p_notes text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); pk packages%rowtype; l uuid; share numeric;
begin
  select * into pk from packages where id = p_package for update;
  if pk.id is null or pk.student_id <> u then raise exception 'Package not found'; end if;
  if pk.status <> 'active' then raise exception 'This package is not active'; end if;
  if pk.total_hours * 60 - pk.used_minutes < p_duration then raise exception 'Not enough hours left in this package'; end if;
  perform assert_slot_free(pk.tutor_id, p_starts_at, p_duration);

  share := round(pk.price / (pk.total_hours * 60.0) * p_duration, 2);
  insert into lessons (student_id, tutor_id, package_id, subject_id, level_id, starts_at, duration_min, mode, status, price, commission, notes)
  values (u, pk.tutor_id, pk.id, p_subject, pk.level_id, p_starts_at, p_duration, p_mode, 'confirmed', share,
          round(share * commission_for(pk.tutor_id), 2), p_notes)
  returning id into l;

  update packages set used_minutes = used_minutes + p_duration,
         status = case when used_minutes + p_duration >= total_hours * 60 then 'used_up'::package_status else status end
  where id = pk.id;
  perform ensure_conversation(u, pk.tutor_id);
  perform push_notification(pk.tutor_id, 'New lesson booked', 'A package lesson was booked.', jsonb_build_object('lesson_id', l));
  return l;
end $$;

-- Payment confirmed (called by the payment webhook with the service key, or by an admin for bank transfers).
create or replace function confirm_payment(p_payment uuid, p_provider text default null, p_ref text default null)
returns void language plpgsql security definer set search_path = public as $$
declare pay payments%rowtype; tutor uuid;
begin
  if not (is_service() or is_admin()) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into pay from payments where id = p_payment for update;
  if pay.id is null then raise exception 'Payment not found'; end if;
  if pay.status = 'paid' then return; end if;                     -- idempotent for webhook retries
  update payments set status = 'paid', paid_at = now(), provider = coalesce(p_provider, provider),
         provider_ref = coalesce(p_ref, provider_ref) where id = pay.id;

  if pay.lesson_id is not null then
    update lessons set status = 'confirmed' where id = pay.lesson_id and status = 'pending_payment' returning tutor_id into tutor;
  else
    update packages set status = 'active' where id = pay.package_id and status = 'pending_payment' returning tutor_id into tutor;
  end if;
  if tutor is not null then
    perform ensure_conversation(pay.user_id, tutor);
    perform push_notification(tutor, 'New booking', 'A student completed payment.', jsonb_build_object('payment_id', pay.id));
  end if;
  perform push_notification(pay.user_id, 'Payment & booking confirmed', 'Your payment was received.', jsonb_build_object('payment_id', pay.id));
  if is_admin() then perform audit('confirm_payment', pay.id::text); end if;
end $$;

create or replace function fail_payment(p_payment uuid, p_ref text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_service() or is_admin()) then raise exception 'Not allowed' using errcode = '42501'; end if;
  update payments set status = 'failed', provider_ref = coalesce(p_ref, provider_ref) where id = p_payment and status <> 'paid';
end $$;

-- Student uploaded a bank-transfer receipt → admin reviews it in the dashboard.
create or replace function submit_bank_receipt(p_payment uuid, p_receipt_url text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update payments set receipt_url = p_receipt_url, status = 'under_review', method = 'bank_transfer'
  where id = p_payment and user_id = me() and status in ('pending', 'failed');
  if not found then raise exception 'Payment not found'; end if;
end $$;

-- Refund helper: returns everything the student paid for a lesson to their wallet.
create or replace function refund_lesson_internal(p_lesson uuid, p_note text) returns numeric
language plpgsql security definer set search_path = public as $$
declare l lessons%rowtype; amt numeric := 0;
begin
  select * into l from lessons where id = p_lesson;
  if l.package_id is not null then
    update packages set used_minutes = greatest(used_minutes - l.duration_min, 0),
           status = case when status = 'used_up' then 'active'::package_status else status end
    where id = l.package_id;
  else
    amt := coalesce((select -sum(amount) from wallet_transactions where lesson_id = l.id and kind = 'booking'), 0)
         + coalesce((select sum(amount) from payments where lesson_id = l.id and status = 'paid'), 0);
    if amt > 0 then
      insert into wallet_transactions (user_id, amount, kind, lesson_id, note) values (l.student_id, amt, 'refund', l.id, p_note);
    end if;
    update payments set status = 'refunded' where lesson_id = l.id and status = 'paid';
  end if;
  return amt;
end $$;

-- Tutor earning helper (price − commission → tutor wallet, once per lesson).
create or replace function credit_tutor_internal(p_lesson uuid) returns void
language plpgsql security definer set search_path = public as $$
declare l lessons%rowtype;
begin
  select * into l from lessons where id = p_lesson;
  if exists (select 1 from wallet_transactions where lesson_id = l.id and kind = 'earning') then return; end if;
  insert into wallet_transactions (user_id, amount, kind, lesson_id, note)
  values (l.tutor_id, l.price - l.commission, 'earning', l.id, 'Lesson #' || l.number);
end $$;

-- Cancel: tutor cancels → full refund; student cancels before the tutor's notice window → full refund,
-- inside the window → no refund and the tutor is paid.
create or replace function cancel_lesson(p_lesson uuid, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := me(); l lessons%rowtype; hrs int; refunded numeric := 0; late boolean := false;
begin
  select * into l from lessons where id = p_lesson for update;
  if l.id is null or u not in (l.student_id, l.tutor_id) then raise exception 'Lesson not found'; end if;
  if l.status not in ('pending_payment', 'confirmed') then raise exception 'This lesson can no longer be cancelled'; end if;

  select cancel_hours into hrs from tutor_profiles where user_id = l.tutor_id;
  late := (u = l.student_id and l.status = 'confirmed' and now() > l.starts_at - make_interval(hours => hrs));

  if late then
    perform credit_tutor_internal(l.id);
  else
    refunded := refund_lesson_internal(l.id, 'Cancelled lesson #' || l.number);
  end if;
  update payments set status = 'failed' where lesson_id = l.id and status in ('pending', 'under_review');
  update lessons set status = 'cancelled', cancelled_by = u, cancel_reason = p_reason where id = l.id;

  perform push_notification(case when u = l.student_id then l.tutor_id else l.student_id end,
    'Lesson cancelled', 'Lesson #' || l.number || ' was cancelled.', jsonb_build_object('lesson_id', l.id));
  return jsonb_build_object('refunded', refunded, 'late_cancellation', late);
end $$;

create or replace function reschedule_lesson(p_lesson uuid, p_starts_at timestamptz)
returns void language plpgsql security definer set search_path = public as $$
declare u uuid := me(); l lessons%rowtype;
begin
  select * into l from lessons where id = p_lesson for update;
  if l.id is null or u <> l.student_id then raise exception 'Only the student can reschedule'; end if;
  if l.status not in ('pending_payment', 'confirmed') then raise exception 'This lesson cannot be rescheduled'; end if;
  update lessons set starts_at = p_starts_at, status = 'cancelled' where id = l.id;   -- free the old slot for the check
  begin
    perform assert_slot_free(l.tutor_id, p_starts_at, l.duration_min);
  exception when others then
    update lessons set starts_at = l.starts_at, status = l.status where id = l.id;
    raise;
  end;
  update lessons set status = l.status where id = l.id;
  perform push_notification(l.tutor_id, 'Lesson rescheduled', 'Lesson #' || l.number || ' has a new time.', jsonb_build_object('lesson_id', l.id));
end $$;

create or replace function leave_review(p_lesson uuid, p_stars int, p_comment text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); l lessons%rowtype; r uuid;
begin
  select * into l from lessons where id = p_lesson;
  if l.id is null or l.student_id <> u then raise exception 'Lesson not found'; end if;
  if l.status <> 'delivered' then raise exception 'You can review a lesson after it is delivered'; end if;
  insert into reviews (lesson_id, student_id, tutor_id, stars, comment) values (l.id, u, l.tutor_id, p_stars, p_comment)
  on conflict (lesson_id) do update set stars = excluded.stars, comment = excluded.comment
  returning id into r;
  perform push_notification(l.tutor_id, 'New review received', p_stars || '★', jsonb_build_object('review_id', r));
  return r;
end $$;

-- Student: tutor didn't show / first-hour not satisfied → dispute for the admin team.
create or replace function dispute_lesson(p_lesson uuid, p_reason text)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); l lessons%rowtype; rep uuid;
begin
  select * into l from lessons where id = p_lesson for update;
  if l.id is null or l.student_id <> u then raise exception 'Lesson not found'; end if;
  if l.status not in ('confirmed', 'delivered') or l.starts_at > now() then raise exception 'You can report a lesson after it starts'; end if;
  if l.delivered_at is not null and l.delivered_at < now() - interval '48 hours' then raise exception 'Reports must be made within 48 hours'; end if;
  update lessons set status = 'disputed' where id = l.id;
  insert into reports (reporter_id, target_type, target_id, reason) values (u, 'lesson', l.id::text, p_reason) returning id into rep;
  return rep;
end $$;

-- =====================================================================
-- TUTOR: lessons, availability, payouts
-- =====================================================================

create or replace function set_lesson_link(p_lesson uuid, p_meeting_url text default null, p_recording_url text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  update lessons set meeting_url = coalesce(p_meeting_url, meeting_url), recording_url = coalesce(p_recording_url, recording_url)
  where id = p_lesson and tutor_id = me();
  if not found then raise exception 'Lesson not found'; end if;
end $$;

create or replace function mark_lesson_delivered(p_lesson uuid)
returns void language plpgsql security definer set search_path = public as $$
declare u uuid := me(); l lessons%rowtype;
begin
  select * into l from lessons where id = p_lesson for update;
  if l.id is null or l.tutor_id <> u then raise exception 'Lesson not found'; end if;
  if l.status <> 'confirmed' then raise exception 'Only confirmed lessons can be marked delivered'; end if;
  if l.starts_at > now() then raise exception 'The lesson has not started yet'; end if;
  update lessons set status = 'delivered', delivered_at = now() where id = l.id;
  update tutor_profiles set minutes_taught = minutes_taught + l.duration_min where user_id = l.tutor_id;
  perform credit_tutor_internal(l.id);
  perform push_notification(l.student_id, 'We value your opinion!', 'Rate your lesson #' || l.number, jsonb_build_object('lesson_id', l.id));
end $$;

create or replace function report_student_no_show(p_lesson uuid)
returns void language plpgsql security definer set search_path = public as $$
declare u uuid := me(); l lessons%rowtype;
begin
  select * into l from lessons where id = p_lesson for update;
  if l.id is null or l.tutor_id <> u then raise exception 'Lesson not found'; end if;
  if l.status <> 'confirmed' or now() < l.starts_at + interval '15 minutes' then
    raise exception 'You can report a no-show 15 minutes after the start time';
  end if;
  update lessons set status = 'no_show' where id = l.id;
  perform credit_tutor_internal(l.id);
  perform push_notification(l.student_id, 'Missed lesson', 'Lesson #' || l.number || ' was marked as no-show.', jsonb_build_object('lesson_id', l.id));
end $$;

create or replace function set_availability(p_available boolean, p_dnd_hours int default 0)
returns void language plpgsql security definer set search_path = public as $$
begin
  update tutor_profiles set available_now = p_available,
         dnd_until = case when p_dnd_hours > 0 then now() + make_interval(hours => p_dnd_hours) else null end
  where user_id = me();
end $$;

-- Payout request reserves the money immediately (debit); a rejection gives it back.
create or replace function request_payout(p_amount numeric, p_method payout_method, p_details jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); po uuid;
begin
  if not exists (select 1 from tutor_profiles where user_id = u) then raise exception 'Tutors only'; end if;
  if p_amount <= 0 or p_amount > wallet_balance(u) then raise exception 'Amount is more than your available balance'; end if;
  insert into payouts (tutor_id, amount, method, details) values (u, p_amount, p_method, p_details) returning id into po;
  insert into wallet_transactions (user_id, amount, kind, payout_id, note) values (u, -p_amount, 'payout', po, 'Payout request');
  return po;
end $$;

-- =====================================================================
-- LIVE HELP ("Speak to a tutor now")
-- =====================================================================

create or replace function create_live_request(
  p_subject text, p_level text default null, p_body text default null,
  p_voice_url text default null, p_voice_sec int default null, p_photo_url text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); q uuid; t record;
begin
  if (select count(*) from live_requests where student_id = u and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'You have reached the limit of live requests for now. Try again later.';
  end if;
  update live_requests set status = 'cancelled' where student_id = u and status = 'open';
  insert into live_requests (student_id, subject_id, level_id, body, voice_url, voice_sec, photo_url, expires_at)
  values (u, p_subject, coalesce(p_level, (select level_id from profiles where id = u)), nullif(trim(p_body), ''),
          p_voice_url, p_voice_sec, p_photo_url, now() + make_interval(secs => setting_num('live_request_seconds')))
  returning id into q;

  for t in
    select tp.user_id from tutor_profiles tp join profiles p on p.id = tp.user_id
    where tp.verification = 'approved' and p.status = 'active' and tp.available_now
      and (tp.dnd_until is null or tp.dnd_until < now())
      and (p_subject is null or exists (select 1 from tutor_subjects s where s.tutor_id = tp.user_id and s.subject_id = p_subject))
  loop
    perform push_notification(t.user_id, 'Real time request!', 'A student would like to connect with you.', jsonb_build_object('live_request_id', q, 'urgent', true));
  end loop;
  return q;
end $$;

-- Tutor accepts/declines. Accepting opens a chat with an automatic greeting.
create or replace function respond_live_request(p_request uuid, p_accept boolean, p_greeting text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); q live_requests%rowtype; c uuid; n int;
begin
  if not is_approved_tutor() then raise exception 'Only approved tutors can answer requests'; end if;
  select * into q from live_requests where id = p_request for update;
  if q.id is null then raise exception 'Request not found'; end if;
  if q.status = 'cancelled' then raise exception 'Request cancelled by the student'; end if;
  if q.expires_at < now() or q.status = 'expired' then raise exception 'Times out! This request has expired'; end if;

  if not p_accept then
    insert into live_responses (request_id, tutor_id, accepted) values (q.id, u, false) on conflict do nothing;
    return null;
  end if;

  select count(*) into n from live_responses where request_id = q.id and accepted;
  if n >= setting_num('live_max_tutors') then raise exception 'Max tutors reached for this request'; end if;
  insert into live_responses (request_id, tutor_id, accepted) values (q.id, u, true)
  on conflict (request_id, tutor_id) do update set accepted = true;

  c := ensure_conversation(q.student_id, u);
  -- The student's question opens the chat, so the tutor sees what to help with.
  if q.body is not null and q.body !~ '^🎤' then
    insert into messages (conversation_id, sender_id, kind, body, created_at) values (c, q.student_id, 'text', q.body, q.created_at);
  end if;
  insert into messages (conversation_id, sender_id, kind, body)
  values (c, null, 'system', coalesce(p_greeting, 'Hello, I''ve accepted your request. How can I assist you?'));
  update live_requests set status = 'matched' where id = q.id and status = 'open';
  perform push_notification(q.student_id, 'A tutor accepted your request', 'Open the app to chat or call.', jsonb_build_object('live_request_id', q.id, 'conversation_id', c));
  return c;
end $$;

create or replace function cancel_live_request(p_request uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update live_requests set status = 'cancelled' where id = p_request and student_id = me() and status in ('open', 'matched');
end $$;

create or replace function start_conversation(p_tutor uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me();
begin
  perform assert_bookable_tutor(p_tutor);
  return ensure_conversation(u, p_tutor);
end $$;

create or replace function report_conversation(p_conversation uuid, p_reason text)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); rep uuid;
begin
  if not exists (select 1 from conversations where id = p_conversation and u in (student_id, tutor_id)) then
    raise exception 'Conversation not found';
  end if;
  update conversations set flagged = true where id = p_conversation;
  insert into reports (reporter_id, target_type, target_id, reason) values (u, 'conversation', p_conversation::text, p_reason) returning id into rep;
  return rep;
end $$;

-- =====================================================================
-- SCHEDULED JOBS (run every minute / hour with pg_cron — see 0004)
-- =====================================================================

create or replace function expire_live_requests() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update live_requests set status = 'expired' where status = 'open' and expires_at < now();
  get diagnostics n = row_count;
  return n;
end $$;

-- Unpaid bookings older than the setting (48 h) are cancelled and their wallet part refunded.
create or replace function expire_pending_payments() returns int
language plpgsql security definer set search_path = public as $$
declare l record; n int := 0;
begin
  for l in select id, number from lessons
           where status = 'pending_payment' and created_at < now() - make_interval(hours => setting_num('pending_payment_hours')::int)
  loop
    perform refund_lesson_internal(l.id, 'Unpaid booking #' || l.number || ' expired');
    update lessons set status = 'cancelled', cancel_reason = 'Payment not completed in time' where id = l.id;
    update payments set status = 'failed' where lesson_id = l.id and status = 'pending';
    n := n + 1;
  end loop;
  update packages set status = 'cancelled'
  where status = 'pending_payment' and created_at < now() - make_interval(hours => setting_num('pending_payment_hours')::int);
  return n;
end $$;

-- Lessons that ended more than 24 h ago without a dispute are marked delivered automatically.
create or replace function auto_deliver_lessons() returns int
language plpgsql security definer set search_path = public as $$
declare l record; n int := 0;
begin
  for l in select * from lessons
           where status = 'confirmed' and starts_at + make_interval(mins => duration_min) < now() - interval '24 hours'
  loop
    update lessons set status = 'delivered', delivered_at = now() where id = l.id;
    update tutor_profiles set minutes_taught = minutes_taught + l.duration_min where user_id = l.tutor_id;
    perform credit_tutor_internal(l.id);
    n := n + 1;
  end loop;
  return n;
end $$;

-- =====================================================================
-- ADMIN (management dashboard)
-- =====================================================================

create or replace function admin_set_tutor_verification(p_tutor uuid, p_status verification, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform require_admin();
  update tutor_profiles set verification = p_status,
         rejection_reason = case when p_status = 'rejected' then p_reason end,
         verified_at = case when p_status = 'approved' then coalesce(verified_at, now()) else verified_at end
  where user_id = p_tutor;
  if not found then raise exception 'Tutor not found'; end if;
  perform push_notification(p_tutor,
    case p_status when 'approved' then 'Your profile is approved' when 'rejected' then 'Your profile needs changes' else 'Profile under review' end,
    coalesce(p_reason, case p_status when 'approved' then 'You can now receive bookings and live requests.' else '' end));
  perform audit('tutor_verification', p_tutor::text, jsonb_build_object('status', p_status, 'reason', p_reason));
end $$;

create or replace function admin_set_user_status(p_user uuid, p_status account_status)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform require_admin();
  if p_user = auth.uid() then raise exception 'You cannot change your own status'; end if;
  update profiles set status = p_status where id = p_user;
  if p_status <> 'active' then update tutor_profiles set available_now = false where user_id = p_user; end if;
  perform audit('user_status', p_user::text, jsonb_build_object('status', p_status));
end $$;

create or replace function admin_set_role(p_user uuid, p_role user_role)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform require_admin();
  update profiles set role = p_role where id = p_user;
  if p_role = 'tutor' then insert into tutor_profiles (user_id) values (p_user) on conflict do nothing; end if;
  perform audit('user_role', p_user::text, jsonb_build_object('role', p_role));
end $$;

create or replace function admin_process_payout(p_payout uuid, p_status payout_status, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare po payouts%rowtype;
begin
  perform require_admin();
  select * into po from payouts where id = p_payout for update;
  if po.id is null then raise exception 'Payout not found'; end if;
  if po.status in ('paid', 'rejected') then raise exception 'This payout is already closed'; end if;
  update payouts set status = p_status, admin_note = p_note, processed_by = auth.uid(), processed_at = now() where id = po.id;
  if p_status = 'rejected' then
    insert into wallet_transactions (user_id, amount, kind, payout_id, note) values (po.tutor_id, po.amount, 'adjustment', po.id, 'Payout rejected: ' || coalesce(p_note, ''));
  end if;
  perform push_notification(po.tutor_id, 'Payout ' || p_status, coalesce(p_note, ''), jsonb_build_object('payout_id', po.id));
  perform audit('payout_' || p_status, po.id::text, jsonb_build_object('amount', po.amount, 'note', p_note));
end $$;

-- Refund a lesson to the student's wallet; reverses the tutor's earning if it was already paid in.
create or replace function admin_refund_lesson(p_lesson uuid, p_note text default null)
returns numeric language plpgsql security definer set search_path = public as $$
declare l lessons%rowtype; amt numeric; earned numeric;
begin
  perform require_admin();
  select * into l from lessons where id = p_lesson for update;
  if l.id is null then raise exception 'Lesson not found'; end if;
  if l.status = 'cancelled' then raise exception 'Lesson is already cancelled'; end if;
  amt := refund_lesson_internal(l.id, coalesce(p_note, 'Refund by Dars'));
  select coalesce(sum(amount), 0) into earned from wallet_transactions where lesson_id = l.id and kind = 'earning';
  if earned > 0 then
    insert into wallet_transactions (user_id, amount, kind, lesson_id, note) values (l.tutor_id, -earned, 'adjustment', l.id, 'Earning reversed: refund');
  end if;
  update lessons set status = 'cancelled', cancel_reason = coalesce(p_note, 'Refunded by Dars'), cancelled_by = auth.uid() where id = l.id;
  update reports set status = 'resolved', resolution_note = 'Refunded', resolved_by = auth.uid(), resolved_at = now()
  where target_type = 'lesson' and target_id = l.id::text and status = 'open';
  perform push_notification(l.student_id, 'Refund issued', 'The lesson amount was returned to your balance.', jsonb_build_object('lesson_id', l.id));
  perform audit('refund_lesson', l.id::text, jsonb_build_object('amount', amt, 'note', p_note));
  return amt;
end $$;

-- Close a dispute in the tutor's favour.
create or replace function admin_release_lesson(p_lesson uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare l lessons%rowtype;
begin
  perform require_admin();
  select * into l from lessons where id = p_lesson for update;
  if l.status not in ('disputed', 'confirmed') then raise exception 'Only disputed or confirmed lessons can be released'; end if;
  update lessons set status = 'delivered', delivered_at = coalesce(delivered_at, now()) where id = l.id;
  perform credit_tutor_internal(l.id);
  update reports set status = 'dismissed', resolution_note = coalesce(p_note, 'Lesson released to tutor'), resolved_by = auth.uid(), resolved_at = now()
  where target_type = 'lesson' and target_id = l.id::text and status = 'open';
  perform audit('release_lesson', l.id::text, jsonb_build_object('note', p_note));
end $$;

create or replace function admin_resolve_report(p_report uuid, p_status report_status, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform require_admin();
  update reports set status = p_status, resolution_note = p_note, resolved_by = auth.uid(), resolved_at = now() where id = p_report;
  perform audit('report_' || p_status, p_report::text, jsonb_build_object('note', p_note));
end $$;

create or replace function admin_set_review_status(p_review uuid, p_status review_status)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform require_admin();
  update reviews set status = p_status where id = p_review;
  perform audit('review_' || p_status, p_review::text);
end $$;

create or replace function admin_wallet_adjust(p_user uuid, p_amount numeric, p_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform require_admin();
  if coalesce(trim(p_note), '') = '' then raise exception 'Add a note explaining the adjustment'; end if;
  insert into wallet_transactions (user_id, amount, kind, note) values (p_user, p_amount, 'adjustment', p_note);
  perform audit('wallet_adjust', p_user::text, jsonb_build_object('amount', p_amount, 'note', p_note));
end $$;

create or replace function admin_set_setting(p_key text, p_value jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform require_admin();
  insert into app_settings (key, value, updated_at) values (p_key, p_value, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();
  perform audit('setting', p_key, jsonb_build_object('value', p_value));
end $$;

create or replace function admin_update_lead(p_lead uuid, p_status lead_status, p_assign_to uuid default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform require_admin();
  update leads set status = p_status, assigned_to = coalesce(p_assign_to, assigned_to) where id = p_lead;
end $$;

-- One call for the dashboard overview.
create or replace function admin_dashboard_stats(p_days int default 30)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare since timestamptz := now() - make_interval(days => p_days); res jsonb;
begin
  perform require_admin();
  select jsonb_build_object(
    'students',        (select count(*) from profiles where role in ('student', 'parent') and status = 'active'),
    'tutors_approved', (select count(*) from tutor_profiles where verification = 'approved'),
    'tutors_pending',  (select count(*) from tutor_profiles where verification = 'pending'),
    'tutors_online',   (select count(*) from tutor_profiles where verification = 'approved' and available_now and (dnd_until is null or dnd_until < now())),
    'lessons_upcoming',(select count(*) from lessons where status = 'confirmed' and starts_at > now()),
    'lessons_today',   (select count(*) from lessons where status in ('confirmed', 'delivered') and starts_at::date = now()::date),
    'lessons_delivered_period', (select count(*) from lessons where status = 'delivered' and delivered_at >= since),
    'gross_bookings',  (select coalesce(sum(price), 0) from lessons where status in ('confirmed', 'delivered') and created_at >= since),
    'revenue_period',  (select coalesce(sum(amount), 0) from payments where status = 'paid' and paid_at >= since),
    'commission_period',(select coalesce(sum(commission), 0) from lessons where status = 'delivered' and delivered_at >= since),
    'pending_payments',(select count(*) from payments where status in ('pending', 'under_review')),
    'receipts_to_review',(select count(*) from payments where status = 'under_review'),
    'payouts_requested',(select coalesce(sum(amount), 0) from payouts where status in ('requested', 'approved')),
    'payouts_requested_count',(select count(*) from payouts where status in ('requested', 'approved')),
    'live_today',      (select count(*) from live_requests where created_at::date = now()::date),
    'live_matched_today',(select count(*) from live_requests where created_at::date = now()::date and status = 'matched'),
    'open_reports',    (select count(*) from reports where status = 'open'),
    'disputed_lessons',(select count(*) from lessons where status = 'disputed'),
    'new_leads',       (select count(*) from leads where status = 'new'),
    'daily_revenue',   (select coalesce(jsonb_agg(jsonb_build_object('day', d::date, 'amount', coalesce(x.amount, 0)) order by d), '[]')
                        from generate_series(now()::date - 13, now()::date, interval '1 day') d
                        left join (select paid_at::date as day, sum(amount) as amount from payments where status = 'paid' group by 1) x on x.day = d::date),
    'top_subjects',    (select coalesce(jsonb_agg(row_to_json(s)), '[]') from
                        (select subject_id, count(*) as lessons from lessons where created_at >= since and subject_id is not null
                         group by subject_id order by count(*) desc limit 6) s)
  ) into res;
  return res;
end $$;

-- ---------- permissions on functions ----------
-- Internal helpers are not callable from the apps.
revoke execute on function refund_lesson_internal(uuid, text), credit_tutor_internal(uuid), push_notification(uuid, text, text, jsonb),
  audit(text, text, jsonb), ensure_conversation(uuid, uuid), expire_live_requests(), expire_pending_payments(), auto_deliver_lessons()
  from public, anon, authenticated;
