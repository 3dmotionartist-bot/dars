-- End-to-end scenario test. Run with:  psql -v ON_ERROR_STOP=1 -d <db> -f tests/flows.sql
-- Stops (non-zero exit) on the first broken expectation.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set admin    '00000000-0000-0000-0000-0000000000a1'
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set stu2     '00000000-0000-0000-0000-0000000000b2'
\set tut      '00000000-0000-0000-0000-0000000000c1'
\set tut2     '00000000-0000-0000-0000-0000000000c2'

-- ---------- helpers ----------
create or replace function t_ok(cond boolean, label text) returns text language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'FAIL: %', label; end if;
  return 'ok   ' || label;
end $$;

create or replace function t_err(stmt text, expect text, label text) returns text language plpgsql as $$
begin
  execute stmt;
  raise exception 'FAIL (no error): %', label;
exception when others then
  if sqlerrm like 'FAIL (no error)%' then raise; end if;
  if position(lower(expect) in lower(sqlerrm)) = 0 then raise exception 'FAIL: % — got "%"', label, sqlerrm; end if;
  return 'ok   ' || label || '  → "' || sqlerrm || '"';
end $$;

create or replace function t_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, false);
$$;
create or replace function t_service() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role":"service_role"}', false);
$$;

-- ---------- people ----------
insert into auth.users (id, email, phone, raw_user_meta_data) values
  (:'admin', 'admin@dars.app', null,           '{"full_name":"Dars Admin","role":"admin"}'),
  (:'stu',   null, '+963900000001', '{"full_name":"Layan","role":"student"}'),
  (:'stu2',  null, '+963900000002', '{"full_name":"Ahmad","role":"parent"}'),
  (:'tut',   null, '+963900000011', '{"full_name":"Samer Al-Halabi","role":"tutor"}'),
  (:'tut2',  null, '+962700000012', '{"full_name":"Lama Al-Khatib","role":"tutor"}');

select t_ok((select role from profiles where id = :'admin') = 'student', 'sign-up cannot self-assign admin');
update profiles set role = 'admin' where id = :'admin';     -- first admin is promoted in the SQL editor
select t_ok((select count(*) from tutor_profiles) = 2, 'tutor sign-ups get a tutor profile');
update profiles set level_id = 'high' where id = :'stu';

\echo '--- tutor sets up profile'
select t_as(:'tut'); set role authenticated;
update tutor_profiles set headline = 'Math & physics, 12 years', hourly_price = 15, max_package_discount = 20,
       teaches_in_person = true, cancel_hours = 12 where user_id = auth.uid();
insert into tutor_subjects values (auth.uid(), 'math'), (auth.uid(), 'physics');
select t_err($$update tutor_profiles set verification = 'approved' where user_id = auth.uid()$$, 'managed by Dars', 'tutor cannot approve himself');
select t_err($$update profiles set role = 'admin' where id = auth.uid()$$, 'Only an admin', 'tutor cannot become admin');
select t_err($$select admin_set_tutor_verification(auth.uid(), 'approved')$$, 'Admins only', 'non-admin cannot call admin functions');
reset role;

\echo '--- visibility before approval'
set role anon; select set_config('request.jwt.claims', '', false);
select t_ok((select count(*) from public_tutors) = 0, 'pending tutors are hidden from the public');
select t_ok((select count(*) from subjects) = 12, 'anyone can read the subject catalog');
reset role;

\echo '--- admin approves'
select t_as(:'admin'); set role authenticated;
select admin_set_tutor_verification(:'tut', 'approved');
select t_ok((select count(*) from admin_tutors) = 2, 'admin sees all tutors');
reset role;
set role anon; select set_config('request.jwt.claims', '', false);
select t_ok((select count(*) from public_tutors) = 1, 'approved tutor is listed publicly');
select t_ok((select subject_ids from public_tutors) = '{math,physics}', 'public card lists subjects');
reset role;

\echo '--- student books & pays by card'
select t_as(:'stu'); set role authenticated;
select (book_lesson(:'tut', date_trunc('hour', now()) + interval '2 days 18 hours', 50, 'math')) as r \gset b1_
select t_ok((select status from lessons where student_id = auth.uid()) = 'pending_payment', 'card booking waits for payment');
select t_ok((select amount from payments where user_id = auth.uid()) = 12.50, 'price = 15/h × 50 min = 12.50');
select t_err($$select book_lesson('00000000-0000-0000-0000-0000000000c1', date_trunc('hour', now()) + interval '2 days 18 hours', 50, 'math')$$,
             'already has a lesson', 'double booking the same slot is blocked');
select t_err($$select book_lesson('00000000-0000-0000-0000-0000000000c2', now() + interval '1 day', 50)$$, 'not available', 'unapproved tutor cannot be booked');
select t_err($$select book_lesson('00000000-0000-0000-0000-0000000000c1', now() + interval '3 days', 50, 'chemistry')$$, 'does not teach', 'subject must match the tutor');
select t_err($$select confirm_payment((select id from payments limit 1))$$, 'Not allowed', 'student cannot confirm own payment');
reset role;

select t_service(); set role service_role;
select confirm_payment((select id from payments where user_id = :'stu'), 'tap', 'chg_123');
select confirm_payment((select id from payments where user_id = :'stu'), 'tap', 'chg_123');   -- webhook retry is harmless
reset role;
select t_ok((select status from lessons where student_id = :'stu') = 'confirmed', 'webhook confirms lesson');
select t_ok((select count(*) from conversations where student_id = :'stu' and tutor_id = :'tut') = 1, 'paid booking opens a chat');

\echo '--- wallet booking, cancel & refund'
select t_as(:'admin'); set role authenticated;
select admin_wallet_adjust(:'stu', 20, 'Welcome credit');
reset role;
select t_as(:'stu'); set role authenticated;
select (book_lesson(:'tut', date_trunc('hour', now()) + interval '4 days 17 hours', 60, 'physics') ->> 'lesson_id') as wl \gset
select t_ok((select status from lessons where id = :'wl') = 'confirmed', 'fully wallet-paid lesson is confirmed instantly');
select t_ok((select balance from wallet_balances where user_id = auth.uid()) = 5, 'wallet 20 − 15 = 5');
select t_ok((cancel_lesson(:'wl', 'Exam moved') ->> 'refunded')::numeric = 15, 'early cancel refunds 15');
select t_ok((select balance from wallet_balances where user_id = auth.uid()) = 20, 'wallet back to 20');

\echo '--- package'
select (buy_package(:'tut', 8)) as pk \gset
select t_ok((:'pk'::jsonb ->> 'discount_pct')::int = 10, '8 h package → 10% (half of 20% max)');
select t_ok((:'pk'::jsonb ->> 'price')::numeric = 108, 'package price 15 × 8 × 0.9 = 108');
select t_ok((:'pk'::jsonb ->> 'amount_due')::numeric = 88, 'wallet 20 used, 88 due');
reset role;
select t_service(); set role service_role;
select confirm_payment((:'pk'::jsonb ->> 'payment_id')::uuid);
reset role;
select t_as(:'stu'); set role authenticated;
select book_from_package((:'pk'::jsonb ->> 'package_id')::uuid, date_trunc('hour', now()) + interval '5 days 16 hours', 60, 'math') as pl \gset
select t_ok((select used_minutes from packages where id = (:'pk'::jsonb ->> 'package_id')::uuid) = 60, 'package used 60 min');
select t_ok((select price from lessons where id = :'pl') = 13.50, 'package lesson value = 108 / 480 min × 60');
reset role;

\echo '--- delivery, earnings, review'
update lessons set starts_at = now() - interval '2 hours' where id = (:'b1_r'::jsonb ->> 'lesson_id')::uuid;
select t_as(:'tut'); set role authenticated;
select mark_lesson_delivered((:'b1_r'::jsonb ->> 'lesson_id')::uuid);
select t_ok((select balance from wallet_balances where user_id = auth.uid()) = 10.62, 'tutor earns 12.50 − 15% commission = 10.62');
select t_ok((select count(*) from lessons) = 3, 'tutor sees his 3 lessons (incl. cancelled)');
reset role;
select t_as(:'stu'); set role authenticated;
select leave_review((:'b1_r'::jsonb ->> 'lesson_id')::uuid, 5, 'شرح ممتاز');
reset role;
select t_ok((select rating_avg from tutor_profiles where user_id = :'tut') = 5 and (select rating_count from tutor_profiles where user_id = :'tut') = 1, 'rating updated');

\echo '--- privacy between students'
select t_as(:'stu2'); set role authenticated;
select t_ok((select count(*) from lessons) = 0, 'another student sees none of Layan''s lessons');
select t_ok((select count(*) from payments) = 0, 'or her payments');
select t_ok((select count(*) from profiles) = 1, 'and only their own profile');
reset role;

\echo '--- live help'
select t_as(:'tut'); set role authenticated;
select set_availability(true);
reset role;
select t_as(:'stu2'); set role authenticated;
select create_live_request('math', 'high', 'عندي سؤال في النهايات') as lq \gset
reset role;
select t_ok((select count(*) from notifications where user_id = :'tut' and data ->> 'urgent' = 'true') = 1, 'available math tutor is notified');
select t_as(:'tut'); set role authenticated;
select t_ok((select count(*) from live_requests where status = 'open') = 1, 'tutor sees the open request');
select respond_live_request(:'lq', true) as conv \gset
reset role;
select t_as(:'stu2'); set role authenticated;
select t_ok((select status from live_requests where id = :'lq') = 'matched', 'request matched');
select t_ok((select body from messages where conversation_id = :'conv' order by created_at, id limit 1) = 'عندي سؤال في النهايات', 'the question opens the chat');
select t_ok((select sender_id from messages where conversation_id = :'conv' order by created_at desc, id desc limit 1) = :'tut', 'student gets the greeting from the tutor (not a system message)');
\echo '--- chat contact filter'
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'call me on 0933 123 456');
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'Can we start now?');
select t_ok((select count(*) from messages where conversation_id = :'conv' and blocked) = 1, 'phone number message is blocked (sender still sees it)');
select t_err($$insert into messages (conversation_id, sender_id, kind, body) values ((select id from conversations limit 1), auth.uid(), 'system', 'fake')$$,
             'row-level security', 'users cannot post system messages');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok((select count(*) from messages where conversation_id = :'conv') = 3, 'tutor does not see the blocked message (question + greeting + 1 normal)');
reset role;
update live_requests set expires_at = now() - interval '1 minute', status = 'open' where id = :'lq';
select t_ok(expire_live_requests() = 1, 'cron job expires old requests');

\echo '--- payouts'
select t_as(:'tut'); set role authenticated;
select t_err($$select request_payout(500, 'bank_transfer', '{"holder_name":"Samer","account":"SY00"}')$$, 'more than your available balance', 'cannot withdraw more than balance');
select request_payout(10, 'bank_transfer', '{"holder_name":"Samer Al-Halabi","account":"SY00 1234"}') as po \gset
select t_ok((select balance from wallet_balances where user_id = auth.uid()) = 0.62, 'payout reserves money');
reset role;
select t_as(:'admin'); set role authenticated;
select admin_process_payout(:'po', 'rejected', 'IBAN missing');
reset role;
select t_ok(wallet_balance(:'tut') = 10.62, 'rejected payout returns the money');

\echo '--- dispute & refund'
update lessons set starts_at = now() - interval '1 hour' where id = :'pl';
select t_as(:'stu'); set role authenticated;
select dispute_lesson(:'pl', 'Tutor did not show up');
reset role;
select t_as(:'admin'); set role authenticated;
select admin_refund_lesson(:'pl', 'Tutor no-show confirmed');
select t_ok((select used_minutes from packages where id = (:'pk'::jsonb ->> 'package_id')::uuid) = 0, 'package hours restored');
select t_ok((select count(*) from reports where status = 'open') = 0, 'report closed automatically');


\echo '--- reschedule & scheduled jobs'
select t_as(:'stu'); set role authenticated;
select (book_lesson(:'tut', date_trunc('hour', now()) + interval '6 days 15 hours', 60, 'math', p_use_wallet => true) ->> 'lesson_id') as rl \gset
select (book_lesson(:'tut', date_trunc('hour', now()) + interval '6 days 19 hours', 60, 'math', p_use_wallet => false) ->> 'lesson_id') as rl2 \gset
select t_err(format('select reschedule_lesson(%L, %L)', :'rl', date_trunc('hour', now()) + interval '6 days 19 hours'), 'already has a lesson', 'reschedule onto a busy slot is blocked');
select t_ok((select status from lessons where id = :'rl') <> 'cancelled', 'failed reschedule leaves the lesson untouched');
select reschedule_lesson(:'rl', date_trunc('hour', now()) + interval '7 days 15 hours');
select t_ok((select starts_at from lessons where id = :'rl') = date_trunc('hour', now()) + interval '7 days 15 hours', 'reschedule to a free slot works');
reset role;
update lessons set created_at = now() - interval '49 hours' where id = :'rl2';
select t_ok(expire_pending_payments() >= 1, 'unpaid bookings expire after 48 h');
select t_ok((select status from lessons where id = :'rl2') = 'cancelled', 'expired booking is cancelled');
update lessons set starts_at = now() - interval '30 hours', status = 'confirmed' where id = :'rl';
select t_ok(auto_deliver_lessons() = 1, 'lessons are auto-delivered 24 h after they end');

\echo '--- leads, settings, stats'
reset role;
set role anon; select set_config('request.jwt.claims', '', false);
insert into leads (full_name, whatsapp, who, subject_id, mode) values ('Um Yousef', '+966500000000', 'parent', 'math', 'online');
select t_ok((select count(*) from leads) = 0, 'visitors can submit but not read leads');
reset role;
select t_as(:'admin'); set role authenticated;
select admin_set_setting('commission_rate', '0.12');
select t_ok(setting_num('commission_rate') = 0.12, 'admin changes commission');
select admin_dashboard_stats() as stats \gset
select t_ok((:'stats'::jsonb ->> 'tutors_approved')::int = 1 and (:'stats'::jsonb ->> 'new_leads')::int = 1
            and jsonb_array_length(:'stats'::jsonb -> 'daily_revenue') = 14, 'dashboard stats');
select t_ok((select count(*) from audit_log) >= 5, 'admin actions are audited');
select admin_set_user_password(:'tut', 'NewPass#2026');
reset role;
select t_ok((select encrypted_password = crypt('NewPass#2026', encrypted_password) from auth.users where id = :'tut'), 'admin sets a new password (stored hashed)');
select t_ok((select encrypted_password not like '%NewPass%' from auth.users where id = :'tut'), 'password is never stored in plain text');
select t_ok(not exists (select 1 from audit_log where data::text like '%NewPass%'), 'password is not written to the audit log');
select t_as(:'admin'); set role authenticated;
select t_err($$select admin_set_user_password(auth.uid(), '123')$$, 'at least 6', 'short passwords are refused');
reset role;
select t_as(:'stu'); set role authenticated;
select t_err($$select admin_set_user_password('00000000-0000-0000-0000-0000000000a1', 'hijack123')$$, 'Admins only', 'non-admin cannot change passwords');
reset role;
-- calls: a call invitation is a chat message of kind 'call'
select t_as(:'stu'); set role authenticated;
insert into messages (conversation_id, sender_id, kind, body)
  select id, auth.uid(), 'call', 'video:abcde-fghjk-mnpqr-stuvw' from conversations where student_id = :'stu' and tutor_id = :'tut';
select t_ok((select count(*) from messages where kind = 'call' and not blocked) = 1, 'student can invite the tutor to a video call');
insert into messages (conversation_id, sender_id, kind, body)
  select id, auth.uid(), 'call', 'meet:kqzpt-mwhra-bcdeg-xyzab' from conversations where student_id = :'stu' and tutor_id = :'tut';
select t_ok((select count(*) from messages where kind = 'call' and body like 'meet:%') = 1, 'student can share a meeting link');
select t_err($$insert into messages (conversation_id, sender_id, kind, body)
  select id, auth.uid(), 'call', 'call me on +1 555 123 4567' from conversations limit 1$$, 'Invalid call message', 'call messages cannot carry free text');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok((select count(*) from messages where kind = 'call') = 2, 'tutor receives the call invitation and the meeting link');
reset role;
-- call relay settings
select t_as(:'admin'); set role authenticated;
select admin_set_setting('turn_urls', '"turn:relay.example.com:80, turns:relay.example.com:443?transport=tcp"');
select admin_set_setting('turn_username', '"u1"');
select admin_set_setting('turn_credential', '"secret1"');
reset role;
select t_as(:'stu'); set role authenticated;
select t_ok(jsonb_array_length(call_ice_servers() -> 0 -> 'urls') = 2 and call_ice_servers() -> 0 ->> 'credential' = 'secret1', 'signed-in users get the call relay');
select t_ok((select count(*) from app_settings where key like 'turn%') = 0, 'relay secrets are not readable from the settings table');
reset role;
set role anon;
select t_ok((select count(*) from app_settings where key like 'turn%') = 0 and (select count(*) from app_settings) > 0, 'visitors cannot see relay secrets');
select t_err($$select call_ice_servers()$$, 'permission denied', 'visitors cannot ask for the relay');
reset role;
-- no chats with yourself; tutors can open a chat with their students
select t_as(:'tut'); set role authenticated;
select t_err($$select start_conversation(auth.uid())$$, 'yourself', 'a tutor cannot message himself');
select t_ok(tutor_start_conversation(:'stu') is not null, 'tutor can open the chat with his student');
select t_err($$select tutor_start_conversation(auth.uid())$$, 'yourself', 'tutor cannot open a chat with himself');
reset role;
select t_ok((select count(*) from conversations where student_id = tutor_id) = 0, 'no self conversations exist');

-- security monitor: contact details in chats
select t_ok(contact_hits('رقمي ٠٩٣٣ ١٢٣ ٤٥٦') -> 0 ->> 'kind' = 'phone', 'Arabic-Indic phone digits are detected');
select t_ok(contact_hits('صفر تسعة ثلاثة ثلاثة واحد اثنين ثلاثة اربعة خمسة') -> 0 ->> 'kind' = 'phone', 'numbers written as words are detected');
select t_ok(contact_hits('0933-123-456') -> 0 ->> 'kind' = 'phone', 'dashed phone numbers are detected');
select t_ok(contact_hits('شو رقم الواتس تبعك؟') -> 0 ->> 'kind' = 'contact_request', 'asking for WhatsApp is detected');
select t_ok(contact_hits('what is your number?') -> 0 ->> 'kind' = 'contact_request', 'asking for a number (English) is detected');
select t_ok(contact_hits('me@example.com') -> 0 ->> 'kind' = 'email', 'emails are detected');
select t_ok(jsonb_array_length(contact_hits('lesson on 2026-11-09 at 10:30, price 1,500,000')) = 0, 'dates, times and prices are not flagged');
select t_ok(jsonb_array_length(contact_hits('شكراً أستاذ، الدرس كان ممتاز')) = 0, 'normal messages are not flagged');
select t_as(:'stu'); set role authenticated;
select start_conversation(:'tut') as mc \gset
insert into messages (conversation_id, sender_id, body) values (:'mc', auth.uid(), 'كلمني على ٠٩٤٤ ٥٥٥ ٦٦٦');
insert into messages (conversation_id, sender_id, body) values (:'mc', auth.uid(), 'ممكن رقمك؟');
select t_ok((select count(*) from message_flags) = 0, 'students cannot see security flags');
reset role;
select t_ok((select count(*) from message_flags where conversation_id = :'mc' and sender_id = :'stu') = 2, 'both messages are flagged for the admin');
select t_ok((select count(*) from notifications where user_id = :'admin' and data ? 'security_flag') >= 2, 'the admin is notified');
select t_ok((select count(*) from notifications where user_id in (:'stu', :'tut') and data ? 'security_flag') = 0, 'the student and tutor are not told');
select t_as(:'tut'); set role authenticated;
select t_ok((select count(*) from messages where conversation_id = :'mc' and body like '%٠٩٤٤%') = 0, 'the tutor does not see the number');
select t_ok((select count(*) from message_flags) = 0, 'tutors cannot see security flags');
reset role;
select t_as(:'admin'); set role authenticated;
select t_ok((select count(*) from admin_message_flags where conversation_id = :'mc') = 2, 'admin sees the flags with names');
select t_ok((select open_flags from admin_conversations where id = :'mc') = 2, 'admin chat list counts open flags');
select t_ok((select count(*) from messages where conversation_id = :'mc') >= 2, 'admin can read every message');
reset role;

-- working hours
select t_as(:'tut'); set role authenticated;
select set_working_hours(180, jsonb_build_array(
  jsonb_build_object('weekday', 0, 'start', '09:00', 'end', '12:00'), jsonb_build_object('weekday', 1, 'start', '09:00', 'end', '12:00'),
  jsonb_build_object('weekday', 2, 'start', '09:00', 'end', '12:00'), jsonb_build_object('weekday', 3, 'start', '09:00', 'end', '12:00'),
  jsonb_build_object('weekday', 4, 'start', '09:00', 'end', '12:00'), jsonb_build_object('weekday', 5, 'start', '09:00', 'end', '12:00'),
  jsonb_build_object('weekday', 6, 'start', '16:00', 'end', '24:00')));
select t_ok((select count(*) from availability_slots where tutor_id = auth.uid()) = 7, 'tutor saves working hours for each day');
select t_err($$select set_working_hours(180, '[{"weekday":1,"start":"12:00","end":"10:00"}]')$$, 'end after', 'a period must end after it starts');
reset role;
select t_ok((select count(*) from availability_slots where tutor_id = :'tut') = 7, 'bad input keeps the old hours');
select t_ok(jsonb_array_length(tutor_schedule(:'tut') -> 'slots') = 7, 'visitors can read the working hours for booking');
select t_as(:'stu2'); set role authenticated;
-- 10:00 Damascus (UTC+3) = 07:00 UTC, ten days ahead on a weekday that is not Saturday
select (date_trunc('day', now() at time zone 'UTC') + interval '10 days') as d10 \gset
select (case when extract(dow from :'d10'::timestamp) = 6 then :'d10'::timestamp + interval '1 day' else :'d10'::timestamp end) as wd \gset
select t_ok((book_lesson(:'tut', (:'wd'::timestamp + interval '7 hours') at time zone 'UTC', 60, 'math', p_use_wallet => false) ->> 'lesson_id') is not null,
            'booking inside the working hours works');
select t_err(format('select book_lesson(%L, %L, 60, %L, p_use_wallet => false)', :'tut', (:'wd'::timestamp + interval '15 hours') at time zone 'UTC', 'math'),
             'working hours', 'booking outside the working hours is refused');
reset role;
\echo
\echo 'ALL FLOW TESTS PASSED'
