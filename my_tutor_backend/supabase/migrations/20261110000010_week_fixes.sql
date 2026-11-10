-- =====================================================================
-- Dars — security & money fixes from the Stage 1 review ("fix this week").
-- Safe to run once in the Supabase SQL editor. It adds and replaces rules and
-- functions; it does not delete any user data.
-- =====================================================================

-- ---------- helper: is the signed-in account active (not blocked / deleted)? ----------
create or replace function is_active_user() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and status = 'active');
$$;

-- =====================================================================
-- #1  Phones and emails of chat / lesson partners were readable.
--     Partners now get only id, name and photo through a function.
-- =====================================================================
drop policy if exists counterpart_read on profiles;

create or replace function partner_profiles(p_ids uuid[])
returns table (id uuid, full_name text, avatar_url text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.avatar_url
  from profiles p
  where p.id = any(p_ids) and p.id <> auth.uid() and is_active_user()
    and (exists (select 1 from conversations c where (c.student_id = auth.uid() and c.tutor_id = p.id)
                                                or (c.tutor_id = auth.uid() and c.student_id = p.id))
      or exists (select 1 from lessons l where (l.student_id = auth.uid() and l.tutor_id = p.id)
                                           or (l.tutor_id = auth.uid() and l.student_id = p.id))
      or exists (select 1 from packages k where (k.student_id = auth.uid() and k.tutor_id = p.id)
                                            or (k.tutor_id = auth.uid() and k.student_id = p.id)));
$$;
revoke execute on function partner_profiles(uuid[]) from public, anon;
grant execute on function partner_profiles(uuid[]) to authenticated;

-- Blocked accounts can no longer change their profile.
drop policy if exists own_update on profiles;
create policy own_update on profiles for update to authenticated
  using (id = auth.uid() and is_active_user()) with check (id = auth.uid());

-- =====================================================================
-- #2  Messages could be edited after sending (even the other person's).
--     No one but an admin can change a message now; "read" goes through a function.
-- =====================================================================
drop policy if exists party_mark_read on messages;

create or replace function mark_conversation_read(p_conversation uuid) returns int
language plpgsql security definer set search_path = public as $$
declare u uuid := me(); n int;
begin
  if not exists (select 1 from conversations where id = p_conversation and u in (student_id, tutor_id)) then
    raise exception 'Conversation not found';
  end if;
  update messages set read_at = now()
  where conversation_id = p_conversation and read_at is null and sender_id is distinct from u;
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function mark_conversation_read(uuid) from public, anon;
grant execute on function mark_conversation_read(uuid) to authenticated;

-- =====================================================================
-- #11 Blocked accounts could still send and read chat messages.
-- =====================================================================
drop policy if exists party_read on conversations;
create policy party_read on conversations for select to authenticated
  using (auth.uid() in (student_id, tutor_id) and is_active_user());

drop policy if exists party_read on messages;
create policy party_read on messages for select to authenticated using (
  is_active_user()
  and exists (select 1 from conversations c where c.id = conversation_id and auth.uid() in (c.student_id, c.tutor_id))
  and (not blocked or sender_id = auth.uid()));

drop policy if exists party_send on messages;
create policy party_send on messages for insert to authenticated with check (
  sender_id = auth.uid() and kind <> 'system' and is_active_user()
  and exists (select 1 from conversations c where c.id = conversation_id and auth.uid() in (c.student_id, c.tutor_id)));

-- =====================================================================
-- #3  The contact filter only looked at text messages, and senders could set
--     the time / hidden / read fields themselves.
--     Now: time, hidden and read are always set by the server; files must be
--     the app's own upload in the sender's chat folder (no text in file names);
--     call messages must be a real call invitation; text is checked as before.
-- =====================================================================
create or replace function filter_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.created_at := now();
  new.read_at := null;
  new.blocked := false;
  if new.sender_id is not null then
    if new.kind = 'call' then
      if coalesce(new.body, '') !~ '^(video|voice|meet):[a-zA-Z0-9-]{8,64}$' then
        raise exception 'Invalid call message';
      end if;
      new.file_url := null;
    elsif new.kind in ('voice', 'image', 'file') then
      if coalesce(new.file_url, '') !~ ('^(chat-files|voice-notes)/' || new.sender_id::text || '/'
                                         || new.conversation_id::text || '/[0-9]{10,16}\.[a-z0-9]{2,5}$') then
        raise exception 'Files must be sent from the Dars app';
      end if;
      -- The label is set here, so a file name or caption cannot carry a phone number.
      new.body := case
        when new.kind = 'voice' then '🎤'
        when new.kind = 'image' then '📷'
        when new.file_url ~* '\.(mp4|mov|m4v|webm|3gp|mkv)$' then '🎬'
        else '📎' end;
    else
      new.file_url := null;
      if exists (select 1 from jsonb_array_elements(contact_hits(new.body)) e where e->>'kind' in ('phone', 'email', 'link')) then
        new.blocked := true;
      end if;
    end if;
  end if;
  update conversations set last_message_at = now() where id = new.conversation_id;
  return new;
end $$;

-- =====================================================================
-- #5  Live-help question text was not checked.
--     Security flags can now point at a live-help question as well as a chat message.
-- =====================================================================
alter table message_flags alter column message_id drop not null;
alter table message_flags alter column conversation_id drop not null;
alter table message_flags add column if not exists live_request_id uuid references live_requests(id) on delete cascade;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'message_flags_target') then
    alter table message_flags add constraint message_flags_target check (message_id is not null or live_request_id is not null);
  end if;
end $$;

-- Hides phone numbers, emails and contact links inside a text (digits normalised).
create or replace function mask_contacts(p_body text) returns text
language plpgsql immutable set search_path = public as $$
declare b text; m text;
begin
  if p_body is null then return null; end if;
  b := translate(p_body, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789');
  for m in select (regexp_matches(b, '\+?\d[\d\s\-\.\(\)/_]{5,}\d', 'g'))[1] loop
    if length(regexp_replace(m, '\D', '', 'g')) >= 7 then b := replace(b, m, '•••'); end if;
  end loop;
  b := regexp_replace(b, '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}', '•••', 'gi');
  b := regexp_replace(b, '(wa\.me|chat\.whatsapp\.com|api\.whatsapp\.com|t\.me/|telegram\.me|instagram\.com|snapchat\.com|facebook\.com|fb\.com|m\.me/)\S*', '•••', 'gi');
  -- numbers written as words: hide the whole text
  if exists (select 1 from jsonb_array_elements(contact_hits(b)) e where e->>'kind' in ('phone', 'email', 'link')) then
    return '•••';
  end if;
  return b;
end $$;

create or replace function flag_live_request_internal(p_request uuid, p_student uuid, p_body text) returns void
language plpgsql security definer set search_path = public as $$
declare e jsonb; n int := 0; who text; a uuid;
begin
  for e in select * from jsonb_array_elements(contact_hits(p_body)) loop
    insert into message_flags (live_request_id, sender_id, kind, matched, excerpt)
    values (p_request, p_student, e->>'kind', left(coalesce(e->>'matched', ''), 200), left(coalesce(p_body, ''), 500));
    n := n + 1;
  end loop;
  if n > 0 then
    select coalesce(nullif(full_name, ''), 'User') into who from profiles where id = p_student;
    for a in select id from profiles where role = 'admin' and status = 'active' loop
      perform push_notification(a, 'Security alert', who || ' shared or asked for contact details in a live-help question.',
        jsonb_build_object('security_flag', true, 'live_request_id', p_request));
    end loop;
  end if;
end $$;

create or replace function create_live_request(
  p_subject text, p_level text default null, p_body text default null,
  p_voice_url text default null, p_voice_sec int default null, p_photo_url text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); q uuid; t record; body text := nullif(trim(p_body), '');
begin
  if (select count(*) from live_requests where student_id = u and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'You have reached the limit of live requests for now. Try again later.';
  end if;
  update live_requests set status = 'cancelled' where student_id = u and status = 'open';
  insert into live_requests (student_id, subject_id, level_id, body, voice_url, voice_sec, photo_url, expires_at)
  values (u, p_subject, coalesce(p_level, (select level_id from profiles where id = u)), mask_contacts(body),
          p_voice_url, p_voice_sec, p_photo_url, now() + make_interval(secs => setting_num('live_request_seconds')))
  returning id into q;
  if body is not null then perform flag_live_request_internal(q, u, body); end if;

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

-- =====================================================================
-- #4  The tutor's live-help greeting was posted as an official "system" message
--     without any check. It is now a normal message from the tutor (checked and
--     flagged like any other) and limited to 300 characters.
-- =====================================================================
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
    insert into messages (conversation_id, sender_id, kind, body) values (c, q.student_id, 'text', q.body);
  end if;
  insert into messages (conversation_id, sender_id, kind, body)
  values (c, u, 'text', left(coalesce(nullif(trim(p_greeting), ''), 'Hello, I''ve accepted your request. How can I assist you?'), 300));
  update live_requests set status = 'matched' where id = q.id and status = 'open';
  perform push_notification(q.student_id, 'A tutor accepted your request', 'Open the app to chat or call.', jsonb_build_object('live_request_id', q.id, 'conversation_id', c));
  return c;
end $$;

-- Admin view: flags on chat messages and on live-help questions.
drop view if exists admin_message_flags;
create view admin_message_flags with (security_invoker = true) as
select f.*,
       s.full_name as sender_name, s.role as sender_role, s.phone as sender_phone,
       coalesce(c.student_id, lr.student_id) as student_id, st.full_name as student_name, st.role as student_role,
       c.tutor_id, tu.full_name as tutor_name,
       coalesce(m.body, lr.body) as message_body, coalesce(m.created_at, lr.created_at) as message_at
from message_flags f
left join conversations c on c.id = f.conversation_id
left join messages m on m.id = f.message_id
left join live_requests lr on lr.id = f.live_request_id
left join profiles s on s.id = f.sender_id
left join profiles st on st.id = coalesce(c.student_id, lr.student_id)
left join profiles tu on tu.id = c.tutor_id;

-- =====================================================================
-- #9  Voice notes and chat files were readable by the wrong people.
--     A chat file can be read only by the two people of THAT chat
--     (files are stored as <sender>/<conversation>/<file>).
-- =====================================================================
do $$
begin
  if to_regclass('storage.objects') is null then return; end if;
  execute 'drop policy if exists "live voice read" on storage.objects';
  execute 'drop policy if exists "chat partner read" on storage.objects';
  execute $p$create policy "chat partner read" on storage.objects for select to authenticated
    using (bucket_id in ('chat-files','voice-notes') and public.is_active_user() and exists (
      select 1 from public.conversations c
      where c.id::text = (storage.foldername(name))[2]
        and auth.uid() in (c.student_id, c.tutor_id)
        and (storage.foldername(name))[1] in (c.student_id::text, c.tutor_id::text)))$p$;
end $$;

-- =====================================================================
-- #10 Anyone could ask for any user's wallet balance or a tutor's commission.
-- =====================================================================
revoke execute on function wallet_balance(uuid), commission_for(uuid) from public, anon, authenticated;

-- =====================================================================
-- #6  Two requests at the same moment could both spend the same money or book
--     the same time. Each money action now waits its turn per person, and each
--     booking waits its turn per tutor.
--     Lock keys: (1, person) = wallet / earnings, (2, tutor) = the tutor's calendar.
-- =====================================================================
create or replace function assert_slot_free(p_tutor uuid, p_start timestamptz, p_minutes int) returns void
language plpgsql security definer set search_path = public as $$
declare off int; loc timestamp; loc_end timestamp;
begin
  perform pg_advisory_xact_lock(2, hashtext(p_tutor::text));
  if p_start < now() then raise exception 'Choose a time in the future'; end if;
  if exists (select 1 from lessons
             where tutor_id = p_tutor and status in ('pending_payment', 'confirmed')
               and tstzrange(starts_at, starts_at + make_interval(mins => duration_min))
                && tstzrange(p_start, p_start + make_interval(mins => p_minutes))) then
    raise exception 'The tutor already has a lesson at this time';
  end if;
  if exists (select 1 from availability_slots where tutor_id = p_tutor) then
    select tz_offset_min into off from tutor_profiles where user_id = p_tutor;
    loc := (p_start at time zone 'UTC') + make_interval(mins => coalesce(off, 180));
    loc_end := loc + make_interval(mins => p_minutes);
    if not exists (
      select 1 from availability_slots s
      where s.tutor_id = p_tutor
        and s.weekday = extract(dow from loc)::int
        and s.start_time <= loc::time
        and case when loc_end::date > loc::date
                 then loc_end::time = '00:00'::time and s.end_time = '24:00'::time
                 else s.end_time >= loc_end::time end) then
      raise exception 'This time is outside the tutor''s working hours';
    end if;
  end if;
end $$;

-- Wallet rows can now point at a package (so an expired package can be refunded).
alter table wallet_transactions add column if not exists package_id uuid references packages(id);
update wallet_transactions w set package_id = substring(w.note from 'Package ([0-9a-f-]{36})')::uuid
where w.package_id is null and w.kind = 'booking' and w.note ~ '^Package [0-9a-f-]{36}$'
  and exists (select 1 from packages k where k.id = substring(w.note from 'Package ([0-9a-f-]{36})')::uuid);

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
  perform pg_advisory_xact_lock(1, hashtext(u::text));            -- my wallet
  perform assert_bookable_tutor(p_tutor);
  perform assert_slot_free(p_tutor, p_starts_at, p_duration);     -- takes the tutor's calendar lock
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

create or replace function buy_package(
  p_tutor uuid, p_hours int, p_level text default null,
  p_use_wallet boolean default true, p_method payment_method default 'card')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := me(); lvl text; disc int; price numeric; use_wallet numeric := 0; due numeric; pk uuid; pay uuid;
begin
  if u = p_tutor then raise exception 'You cannot book yourself'; end if;
  perform pg_advisory_xact_lock(1, hashtext(u::text));            -- my wallet
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
    insert into wallet_transactions (user_id, amount, kind, package_id, note) values (u, -use_wallet, 'booking', pk, 'Package ' || pk);
  end if;
  if due > 0 then
    insert into payments (user_id, package_id, amount, method) values (u, pk, due, p_method) returning id into pay;
  else
    perform push_notification(p_tutor, 'New package purchased', p_hours || ' hours package', jsonb_build_object('package_id', pk));
  end if;
  return jsonb_build_object('package_id', pk, 'discount_pct', disc, 'price', price, 'wallet_used', use_wallet, 'amount_due', due, 'payment_id', pay);
end $$;

create or replace function request_payout(p_amount numeric, p_method payout_method, p_details jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); po uuid;
begin
  if not exists (select 1 from tutor_profiles where user_id = u) then raise exception 'Tutors only'; end if;
  perform pg_advisory_xact_lock(1, hashtext(u::text));            -- my earnings
  if p_amount is null or p_amount <= 0 or p_amount > wallet_balance(u) then raise exception 'Amount is more than your available balance'; end if;
  insert into payouts (tutor_id, amount, method, details) values (u, p_amount, p_method, p_details) returning id into po;
  insert into wallet_transactions (user_id, amount, kind, payout_id, note) values (u, -p_amount, 'payout', po, 'Payout request');
  return po;
end $$;

-- =====================================================================
-- #7  A student could reschedule a lesson after it had started (or inside the
--     tutor's notice period) and then cancel it for a full refund.
-- =====================================================================
create or replace function reschedule_lesson(p_lesson uuid, p_starts_at timestamptz)
returns void language plpgsql security definer set search_path = public as $$
declare u uuid := me(); l lessons%rowtype; hrs int;
begin
  select * into l from lessons where id = p_lesson for update;
  if l.id is null or u <> l.student_id then raise exception 'Only the student can reschedule'; end if;
  if l.status not in ('pending_payment', 'confirmed') then raise exception 'This lesson cannot be rescheduled'; end if;
  select coalesce(cancel_hours, 0) into hrs from tutor_profiles where user_id = l.tutor_id;
  if now() > l.starts_at - make_interval(hours => coalesce(hrs, 0)) then
    raise exception 'It is too late to reschedule this lesson (less than % hours before it starts)', coalesce(hrs, 0);
  end if;
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

-- =====================================================================
-- #8  Expired unpaid packages kept the wallet part; a payment confirmed after
--     the booking had expired was marked "paid" but the booking stayed cancelled.
-- =====================================================================
create or replace function expire_pending_payments() returns int
language plpgsql security definer set search_path = public as $$
declare l record; k record; amt numeric; n int := 0; hrs int := coalesce(setting_num('pending_payment_hours')::int, 48);
begin
  -- Bookings with a receipt waiting for review are not expired.
  for l in select id, number from lessons
           where status = 'pending_payment' and created_at < now() - make_interval(hours => hrs)
             and not exists (select 1 from payments p where p.lesson_id = lessons.id and p.status = 'under_review')
  loop
    perform refund_lesson_internal(l.id, 'Unpaid booking #' || l.number || ' expired');
    update lessons set status = 'cancelled', cancel_reason = 'Payment not completed in time' where id = l.id;
    update payments set status = 'failed' where lesson_id = l.id and status = 'pending';
    n := n + 1;
  end loop;
  for k in select id, student_id from packages
           where status = 'pending_payment' and created_at < now() - make_interval(hours => hrs)
             and not exists (select 1 from payments p where p.package_id = packages.id and p.status = 'under_review')
  loop
    amt := coalesce((select -sum(amount) from wallet_transactions where package_id = k.id and kind = 'booking'), 0);
    if amt > 0 then
      insert into wallet_transactions (user_id, amount, kind, package_id, note)
      values (k.student_id, amt, 'refund', k.id, 'Unpaid package expired');
    end if;
    update packages set status = 'cancelled' where id = k.id;
    update payments set status = 'failed' where package_id = k.id and status = 'pending';
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function confirm_payment(p_payment uuid, p_provider text default null, p_ref text default null)
returns void language plpgsql security definer set search_path = public as $$
declare pay payments%rowtype; tutor uuid;
begin
  if not (is_service() or is_admin()) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into pay from payments where id = p_payment for update;
  if pay.id is null then raise exception 'Payment not found'; end if;
  if pay.status in ('paid', 'refunded') then return; end if;          -- idempotent for webhook retries
  perform pg_advisory_xact_lock(1, hashtext(pay.user_id::text));
  update payments set status = 'paid', paid_at = now(), provider = coalesce(p_provider, provider),
         provider_ref = coalesce(p_ref, provider_ref) where id = pay.id;

  if pay.lesson_id is not null then
    update lessons set status = 'confirmed' where id = pay.lesson_id and status = 'pending_payment' returning tutor_id into tutor;
  else
    update packages set status = 'active' where id = pay.package_id and status = 'pending_payment' returning tutor_id into tutor;
  end if;

  if tutor is null then
    -- The booking expired or was cancelled before the money arrived: keep the money in the student's wallet.
    insert into wallet_transactions (user_id, amount, kind, payment_id, lesson_id, package_id, note)
    values (pay.user_id, pay.amount, 'refund', pay.id, pay.lesson_id, pay.package_id, 'Payment received after the booking was cancelled');
    update payments set status = 'refunded' where id = pay.id;
    perform push_notification(pay.user_id, 'Payment added to your wallet',
      'Your booking had already expired, so the amount was added to your Dars wallet. You can use it for a new booking.',
      jsonb_build_object('payment_id', pay.id));
  else
    perform ensure_conversation(pay.user_id, tutor);
    perform push_notification(tutor, 'New booking', 'A student completed payment.', jsonb_build_object('payment_id', pay.id));
    perform push_notification(pay.user_id, 'Payment & booking confirmed', 'Your payment was received.', jsonb_build_object('payment_id', pay.id));
  end if;
  if is_admin() then perform audit('confirm_payment', pay.id::text); end if;
end $$;

-- =====================================================================
-- #19 The app showed a different price from the one charged.
--     The app now asks the server: price per 60 minutes for the student's level,
--     and the real package discount for each package size.
-- =====================================================================
create or replace function price_quote(p_tutor uuid, p_level text default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'level', lvl,
    'hourly', tutor_price(p_tutor, lvl),
    'discounts', jsonb_build_object('4', package_discount(p_tutor, 4), '8', package_discount(p_tutor, 8),
                                    '12', package_discount(p_tutor, 12), '20', package_discount(p_tutor, 20)))
  from (select coalesce(p_level, (select level_id from profiles where id = auth.uid()), 'high') as lvl) x
  where exists (select 1 from tutor_profiles where user_id = p_tutor and verification = 'approved');
$$;
grant execute on function price_quote(uuid, text) to anon, authenticated;

-- =====================================================================
-- #26 Chats stopped updating after ~1,000 messages (the app loaded the oldest first).
--     The app now loads the newest 50 of each chat (20 chats per request), and older ones on scroll.
--     (Security invoker: the normal message rules apply.)
-- =====================================================================
create or replace function recent_messages(p_conversations uuid[], p_limit int default 50)
returns setof messages language sql stable set search_path = public as $$
  select id, conversation_id, sender_id, kind, body, file_url, duration_sec, blocked, read_at, created_at
  from (
    select m.*, row_number() over (partition by m.conversation_id order by m.created_at desc, m.id desc) as rn
    from messages m
    where m.conversation_id = any(p_conversations)
  ) x
  where rn <= least(greatest(coalesce(p_limit, 50), 1), 200)
  order by conversation_id, created_at, id;
$$;

create or replace function older_messages(p_conversation uuid, p_before_at timestamptz, p_before_id bigint, p_limit int default 50)
returns setof messages language sql stable set search_path = public as $$
  select * from (
    select * from messages
    where conversation_id = p_conversation and (created_at, id) < (p_before_at, p_before_id)
    order by created_at desc, id desc
    limit least(greatest(coalesce(p_limit, 50), 1), 200)
  ) x order by created_at, id;
$$;
revoke execute on function recent_messages(uuid[], int), older_messages(uuid, timestamptz, bigint, int) from public, anon;
grant execute on function recent_messages(uuid[], int), older_messages(uuid, timestamptz, bigint, int) to authenticated;

create index if not exists messages_conv_time_idx on messages (conversation_id, created_at desc, id desc);
