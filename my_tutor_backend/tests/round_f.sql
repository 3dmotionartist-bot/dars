-- Round F: money and booking rules. Runs after round_e.sql.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set admin    '00000000-0000-0000-0000-0000000000a1'
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set stu2     '00000000-0000-0000-0000-0000000000b2'
\set tut      '00000000-0000-0000-0000-0000000000c1'
\set tut2     '00000000-0000-0000-0000-0000000000c2'

reset role;
-- The real rules (the older test files ran with them relaxed).
update app_settings set value = 'false' where key = 'bookable_without_hours';
update app_settings set value = '48' where key = 'earnings_hold_hours';
insert into app_settings (key, value) values ('max_unpaid_bookings', '99') on conflict (key) do update set value = excluded.value;
update profiles set level_id = 'high', status = 'active' where id in (:'stu', :'stu2');
update profiles set status = 'active' where id in (:'tut', :'tut2');
update tutor_profiles set verification = 'approved' where user_id in (:'tut', :'tut2');
select t_ok((select count(*) from app_settings where key in ('earnings_hold_hours', 'usd_to_syp', 'display_currency', 'bookable_without_hours')) = 4,
  'Round F settings exist (hold hours, exchange rate, display currency, bookable without hours)');

\echo '--- F3. working hours'
delete from availability_slots where tutor_id = :'tut2';
select min(g::date) as d from generate_series((now() at time zone 'UTC')::date + 70, (now() at time zone 'UTC')::date + 140, interval '1 day') g
where not exists (select 1 from lessons where tutor_id = :'tut' and starts_at between g - interval '1 day' and g + interval '2 days') \gset
select extract(dow from :'d'::date)::int as dw, extract(dow from :'d'::date + 1)::int as dw1 \gset
select t_err(format('select assert_slot_free(%L, %L, 60)', :'tut2', (:'d'::date + time '08:00') at time zone 'UTC'),
  'not taking bookings yet', 'a tutor with no working hours saved cannot be booked');
update app_settings set value = 'true' where key = 'bookable_without_hours';
select t_ok((select assert_slot_free(:'tut2', (:'d'::date + time '08:00') at time zone 'UTC', 60)::text = ''),
  '… unless the setting allows it');
update app_settings set value = 'false' where key = 'bookable_without_hours';

select t_as(:'tut'); set role authenticated;
select set_working_hours(180, jsonb_build_array(
  jsonb_build_object('weekday', :dw, 'start', '09:00', 'end', '12:00'),
  jsonb_build_object('weekday', :dw, 'start', '12:00', 'end', '15:00'),
  jsonb_build_object('weekday', :dw, 'start', '22:00', 'end', '24:00'),
  jsonb_build_object('weekday', :dw1, 'start', '00:00', 'end', '02:00')));
reset role;
-- local time = UTC + 3 h (tz offset 180)
select t_ok((select assert_slot_free(:'tut', (:'d'::date + time '08:30') at time zone 'UTC', 60)::text = ''),
  '11:30–12:30 across two touching periods (09–12 + 12–15) is allowed');
select t_ok((select assert_slot_free(:'tut', (:'d'::date + time '06:00') at time zone 'UTC', 360)::text = ''),
  '09:00–15:00 (the whole joined stretch) is allowed');
select t_err(format('select assert_slot_free(%L, %L, 60)', :'tut', (:'d'::date + time '11:30') at time zone 'UTC'),
  'outside the tutor', '14:30–15:30 runs past the end of the day''s hours');
select t_err(format('select assert_slot_free(%L, %L, 60)', :'tut', (:'d'::date + time '05:00') at time zone 'UTC'),
  'outside the tutor', '08:00–09:00 starts before the hours');
select t_ok((select assert_slot_free(:'tut', (:'d'::date + time '20:30') at time zone 'UTC', 60)::text = ''),
  '23:30–00:30 across midnight is allowed when both days cover it');
select t_err(format('select assert_slot_free(%L, %L, 60)', :'tut', (:'d'::date + time '22:30') at time zone 'UTC'),
  'outside the tutor', '01:30–02:30 next day runs past 02:00');
select t_err(format('select assert_slot_free(%L, %L, 0)', :'tut', (:'d'::date + time '08:30') at time zone 'UTC'),
  'time and a length', 'a lesson of 0 minutes is refused');

\echo '--- F1. no-show disputes and the earnings hold'
reset role;
select wallet_balance(:'tut') as tb0 \gset
insert into lessons (student_id, tutor_id, starts_at, duration_min, mode, status, price, commission)
values (:'stu', :'tut', now() - interval '2 hours', 60, 'online', 'confirmed', 20, 3) returning id as l1 \gset
select t_as(:'tut'); set role authenticated;
select report_student_no_show(:'l1');
reset role;
select t_ok((select status = 'no_show' and no_show_at is not null from lessons where id = :'l1'), 'a no-show is recorded with its time');
select t_ok((select count(*) from wallet_transactions where lesson_id = :'l1' and kind = 'earning') = 1, 'the tutor is credited once');
select t_ok(wallet_balance(:'tut') = :'tb0'::numeric, 'but the earning is held: the available balance does not change');
select t_as(:'tut'); set role authenticated;
select t_ok((my_wallet() ->> 'held')::numeric >= 17 and (my_wallet() ->> 'hold_hours')::numeric = 48, 'the tutor sees it as held (48 h)');
select t_err(format($$select request_payout(%s, 'sham_cash', '{"holder_name":"Samer","account":"0944"}')$$, :'tb0'::numeric + 17),
  'more than your available balance', 'held earnings cannot be paid out');
select t_err(format($$select dispute_lesson(%L, 'I was there')$$, :'l1'), 'not found', 'the tutor cannot dispute his own lesson');
select t_as(:'stu2'); set role authenticated;
select t_err(format($$select dispute_lesson(%L, 'I was there')$$, :'l1'), 'not found', 'another student cannot dispute it');
select t_as(:'stu'); set role authenticated;
select t_err(format($$select dispute_lesson(%L, '   ')$$, :'l1'), 'write what happened', 'a dispute needs a reason');
select t_ok(dispute_lesson(:'l1', 'I was there, the tutor did not come') is not null, 'the student can dispute a no-show within 48 h');
select t_err(format($$select dispute_lesson(%L, 'again')$$, :'l1'), 'after it starts', 'the same lesson cannot be disputed twice');
reset role;
select t_ok((select status from lessons where id = :'l1') = 'disputed', 'the lesson is now disputed');
update wallet_transactions set created_at = now() - interval '72 hours' where lesson_id = :'l1' and kind = 'earning';
select t_ok(wallet_balance(:'tut') = :'tb0'::numeric, 'a disputed earning stays frozen even after the hold time');

insert into lessons (student_id, tutor_id, starts_at, duration_min, mode, status, price, commission, no_show_at)
values (:'stu', :'tut', now() - interval '60 hours', 60, 'online', 'no_show', 20, 3, now() - interval '49 hours') returning id as l2 \gset
select t_as(:'stu'); set role authenticated;
select t_err(format($$select dispute_lesson(%L, 'late')$$, :'l2'), 'within 48 hours', 'a no-show cannot be disputed after 48 h');

-- the admin refunds the disputed lesson: the earning is reversed exactly once
select t_as(:'stu'); set role authenticated;
select t_err(format($$select admin_refund_lesson(%L, 'test')$$, :'l1'), 'admin', 'a student cannot refund');
select t_as(:'admin'); set role authenticated;
select admin_refund_lesson(:'l1', 'Tutor did not come');
select t_err(format($$select admin_refund_lesson(%L, 'again')$$, :'l1'), 'already cancelled', 'a lesson cannot be refunded twice');
reset role;
select t_ok((select sum(amount) from wallet_transactions where lesson_id = :'l1' and user_id = :'tut') = 0, 'the earning is reversed once (earning + reversal = 0)');
select t_ok(wallet_balance(:'tut') = :'tb0'::numeric, 'the tutor''s available balance is back where it was, never below');

-- a delivered lesson: held for 48 h, then withdrawable
insert into lessons (student_id, tutor_id, starts_at, duration_min, mode, status, price, commission)
values (:'stu', :'tut', now() - interval '3 hours', 60, 'online', 'confirmed', 20, 3) returning id as l3 \gset
select t_as(:'tut'); set role authenticated;
select mark_lesson_delivered(:'l3');
reset role;
select t_ok(wallet_balance(:'tut') = :'tb0'::numeric, 'a fresh earning is held');
update wallet_transactions set created_at = now() - interval '49 hours' where lesson_id = :'l3' and kind = 'earning';
select t_ok(wallet_balance(:'tut') = :'tb0'::numeric + 17, 'after 48 h it can be withdrawn');
select t_as(:'tut'); set role authenticated;
-- (the tutor's balance before this file may be below zero from the older tests: pay out what is available)
select my_wallet() ->> 'available' as avail \gset
select t_ok(:'avail'::numeric > 0 and request_payout(:'avail'::numeric, 'sham_cash', '{"holder_name":"Samer","account":"0944"}') is not null,
  '… and paid out');
select t_err(format($$select request_payout(%s, 'sham_cash', '{"holder_name":"Samer","account":"0944"}')$$, :'avail'),
  'more than your available balance', 'but not twice');

-- visitors and other users
reset role; select set_config('request.jwt.claims', '', false); set role anon;
select t_err('select my_wallet()', 'permission denied', 'a visitor cannot read a wallet');
select t_err(format('select held_earnings(%L)', :'tut'), 'permission denied', 'a visitor cannot read held earnings');
select t_as(:'stu'); set role authenticated;
select t_err(format('select held_earnings(%L)', :'tut'), 'permission denied', 'a student cannot read someone''s held earnings');
select t_ok((my_wallet() ->> 'held')::numeric = 0, 'a student has nothing held');

\echo '--- F2. package discounts'
select t_as(:'stu'); set role authenticated;
select t_err($$select set_package_discounts('{"4":5,"8":10,"12":15,"20":20}')$$, 'tutors only', 'a student cannot set discounts');
select t_as(:'tut'); set role authenticated;
select t_err($$select set_package_discounts('{"4":5,"8":10,"12":15,"20":51}')$$, 'from 0 to 50', 'more than 50 % is refused');
select t_err($$select set_package_discounts('{"4":-1,"8":10,"12":15,"20":20}')$$, 'from 0 to 50', 'a negative discount is refused');
select t_err($$select set_package_discounts('{"4":2.5,"8":10,"12":15,"20":20}')$$, 'from 0 to 50', 'a fraction is refused');
select t_err($$select set_package_discounts('{"4":5,"8":10,"12":15}')$$, 'from 0 to 50', 'all four sizes are needed');
select t_err($$select set_package_discounts('"x"')$$, 'invalid discounts', 'bad input is refused');
select set_package_discounts('{"4":5,"8":10,"12":15,"20":20}');
reset role;
select t_ok((select package_discounts = '{"4":5,"8":10,"12":15,"20":20}' and max_package_discount = 20 from tutor_profiles where user_id = :'tut'),
  'the four numbers are stored (and the largest kept for older apps)');
select t_as(:'stu'); set role authenticated;
select price_quote(:'tut') as q \gset
select t_ok((:'q'::jsonb -> 'discounts') = '{"4":5,"8":10,"12":15,"20":20}', 'the student is quoted exactly the tutor''s numbers');
select buy_package(:'tut', 4, null, false, 'card') as p4 \gset
select buy_package(:'tut', 8, null, false, 'card') as p8 \gset
select buy_package(:'tut', 12, null, false, 'card') as p12 \gset
select buy_package(:'tut', 20, null, false, 'card') as p20 \gset
select t_ok((:'p4'::jsonb ->> 'price')::numeric = round((:'q'::jsonb ->> 'hourly')::numeric * 4 * 95 / 100.0, 2)
        and (:'p8'::jsonb ->> 'price')::numeric = round((:'q'::jsonb ->> 'hourly')::numeric * 8 * 90 / 100.0, 2)
        and (:'p12'::jsonb ->> 'price')::numeric = round((:'q'::jsonb ->> 'hourly')::numeric * 12 * 85 / 100.0, 2)
        and (:'p20'::jsonb ->> 'price')::numeric = round((:'q'::jsonb ->> 'hourly')::numeric * 20 * 80 / 100.0, 2),
  'the price charged equals the quote for every package size');
reset role;
update tutor_profiles set package_discounts = null, max_package_discount = 0 where user_id = :'tut2';
select t_ok(package_discount(:'tut2', 4) = 0 and package_discount(:'tut2', 20) = 0, 'a tutor who set nothing gives no discount');

\echo '--- F6. own study level; admin passwords'
select t_as(:'stu'); set role authenticated;
select t_ok((price_quote(:'tut', 'kids') ->> 'level') = 'high', 'a student is quoted at his own level, not a cheaper one he names');
select t_err(format($$select buy_package(%L, 4, 'kids', false, 'card')$$, :'tut'), 'own study level', 'buying at a cheaper level is refused');
reset role; select set_config('request.jwt.claims', '', false); set role anon;
select t_ok((price_quote(:'tut', 'kids') ->> 'level') = 'kids', 'a visitor can still see the price for a level');
reset role;
insert into auth.sessions (user_id) values (:'stu2');
insert into auth.refresh_tokens (token, user_id) values ('x', :'stu2');
select t_as(:'stu'); set role authenticated;
select t_err(format($$select admin_set_user_password(%L, 'abcdefghijk')$$, :'stu2'), 'admin', 'only admins set passwords');
select t_as(:'admin'); set role authenticated;
select t_err(format($$select admin_set_user_password(%L, '123456789')$$, :'stu2'), 'at least 10', 'a 9-character password is refused');
select admin_set_user_password(:'stu2', 'a-long-pass-1');
reset role;
select t_ok((select count(*) from auth.sessions where user_id = :'stu2') = 0
        and (select count(*) from auth.refresh_tokens where user_id = :'stu2') = 0, 'the user is signed out everywhere');
