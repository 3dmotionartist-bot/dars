-- Round D: device tokens, notification switches, lesson reminders, missed calls, server clock. Runs after round_b.sql.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set stu2     '00000000-0000-0000-0000-0000000000b2'
\set tut      '00000000-0000-0000-0000-0000000000c1'
\set tut2     '00000000-0000-0000-0000-0000000000c2'
\set tokA     'fcmTokenA_0123456789abcdef:APA91b-xyz.123'
\set tokB     'fcmTokenB_0123456789abcdef:APA91b-xyz.456'

\echo '--- D1. device tokens: own rows only, functions only'
reset role;
select t_err('set role anon; select save_device_token(''' || :'tokA' || ''')', 'permission denied', 'a visitor cannot save a device token');
reset role;
select t_err('set role anon; select * from device_tokens', 'permission denied', 'a visitor cannot read device tokens');
reset role;
select t_err('set role anon; select remove_device_token(''x'')', 'permission denied', 'a visitor cannot remove device tokens');
reset role;
select t_as(:'stu'); set role authenticated;
select null from save_device_token(:'tokA', 'android', 'en');
select t_ok((select count(*) from device_tokens) = 1 and (select lang from device_tokens) = 'en', 'a student saves his phone''s token (language kept)');
select null from save_device_token(:'tokA', 'android', 'ar');
select t_ok((select count(*) from device_tokens) = 1 and (select lang from device_tokens) = 'ar', 'saving again updates the same row');
select t_err($$select save_device_token('short')$$, 'Bad device token', 'a too-short token is refused');
select t_err($$select save_device_token('abc def <script>alert(1)</script> 0123456789')$$, 'Bad device token', 'a token with odd characters is refused');
select t_err($$insert into device_tokens (token, user_id) values ('fcmTokenZ_0123456789abcdef', auth.uid())$$, 'permission denied',
  'tokens cannot be written to the table directly');
select t_err(format($$update device_tokens set user_id = %L$$, :'stu2'), 'permission denied', 'nor changed directly');
reset role;
select t_as(:'stu2'); set role authenticated;
select t_ok((select count(*) from device_tokens) = 0, 'another user sees none of the student''s tokens');
select null from remove_device_token(:'tokA');
reset role;
select t_ok((select user_id from device_tokens where token = :'tokA') = :'stu', '… and cannot remove them');
select t_as(:'stu2'); set role authenticated;
select null from save_device_token(:'tokA');
reset role;
select t_ok((select user_id from device_tokens where token = :'tokA') = :'stu2',
  'a phone signed in to another account moves to that account (the old account stops getting its notifications)');
select t_as(:'stu'); set role authenticated;
select count(save_device_token('fcmTok' || g || '_0123456789abcdefghij')::text) from generate_series(1, 12) g \g /dev/null
select t_ok((select count(*) from device_tokens) = 10, 'at most 10 phones per account (the oldest drop out)');
select null from save_device_token(:'tokB');
select null from remove_device_token(:'tokB');
select t_ok(not exists (select 1 from device_tokens where token = :'tokB'), 'sign-out removes this phone''s token');
reset role;
update profiles set status = 'blocked' where id = :'stu2';
select t_as(:'stu2'); set role authenticated;
select t_err($$select save_device_token('fcmTokenC_0123456789abcdef')$$, 'Not allowed', 'a blocked account cannot save a token');
reset role;
update profiles set status = 'active' where id = :'stu2';

\echo '--- D1. on / off switches'
select t_err('set role anon; select * from my_notification_prefs()', 'permission denied', 'a visitor has no switches');
reset role;
select t_err('set role anon; select set_notification_prefs(false, false, false)', 'permission denied', 'nor can a visitor set them');
reset role;
select t_err('set role authenticated; select * from notification_prefs', 'permission denied', 'the switches table is not read directly');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok((select messages and calls and reminders from my_notification_prefs()), 'everything is on by default');
select null from set_notification_prefs(p_calls => false);
select t_ok((select messages and not calls and reminders from my_notification_prefs()), 'turning calls off leaves the others on');
select null from set_notification_prefs(p_reminders => false);
select t_ok((select messages and not calls and not reminders from my_notification_prefs()), '… and a later change keeps the earlier one');
select null from set_notification_prefs(true, true, true);
reset role;
select t_as(:'tut2'); set role authenticated;
select t_ok((select messages and calls and reminders from my_notification_prefs()), 'another user''s switches are his own');
reset role;

\echo '--- D1. lesson reminders 24 h / 1 h / 10 min before, each once'
select t_err('set role authenticated; select send_lesson_reminders()', 'permission denied', 'users cannot send reminders');
reset role;
set session_replication_role = replica;
insert into lessons (id, student_id, tutor_id, starts_at, duration_min, status, price, created_at) values
  ('00000000-0000-0000-0000-00000000d001', :'stu', :'tut', now() + interval '23 hours 50 minutes', 60, 'confirmed', 10, now() - interval '3 days'),
  ('00000000-0000-0000-0000-00000000d002', :'stu', :'tut', now() + interval '55 minutes',          60, 'confirmed', 10, now() - interval '3 days'),
  ('00000000-0000-0000-0000-00000000d003', :'stu', :'tut', now() + interval '6 minutes',           60, 'confirmed', 10, now() - interval '3 days'),
  ('00000000-0000-0000-0000-00000000d004', :'stu', :'tut', now() + interval '3 hours',             60, 'confirmed', 10, now() - interval '20 minutes'),
  ('00000000-0000-0000-0000-00000000d005', :'stu', :'tut', now() + interval '30 minutes',          60, 'cancelled', 10, now() - interval '3 days'),
  ('00000000-0000-0000-0000-00000000d006', :'stu', :'tut', now() + interval '30 hours',            60, 'confirmed', 10, now() - interval '3 days'),
  ('00000000-0000-0000-0000-00000000d007', :'stu', :'tut', now() - interval '5 minutes',           60, 'confirmed', 10, now() - interval '3 days');
set session_replication_role = origin;
select t_ok(send_lesson_reminders() = 3, 'three reminders are due now (24 h, 1 h, 10 min)');
select t_ok((select array_agg(lesson_id::text || ':' || kind order by kind) from lesson_reminders)
            = array['00000000-0000-0000-0000-00000000d003:10m', '00000000-0000-0000-0000-00000000d002:1h',
                    '00000000-0000-0000-0000-00000000d001:24h'],
  '… for the right lessons; none for a lesson booked 20 minutes ago, a cancelled one, one 30 hours away or one that started');
select t_ok((select count(*) from notifications where data ->> 'type' = 'reminder') = 6, 'the student and the tutor each get them');
select t_ok((select body from notifications where data ->> 'type' = 'reminder' and data ->> 'kind' = '1h' limit 1) like '% starts in 1 hour.',
  'the text says when');
select t_ok(send_lesson_reminders() = 0, 'running again sends nothing twice');
update lessons set starts_at = now() + interval '8 minutes' where id = '00000000-0000-0000-0000-00000000d002';
select t_ok(send_lesson_reminders() = 1, 'the same lesson later gets its 10-minute reminder …');
select t_ok(exists (select 1 from lesson_reminders where lesson_id = '00000000-0000-0000-0000-00000000d002' and kind = '10m'), '… recorded as sent');

\echo '--- D1 / D4. missed call'
select id as conv from conversations where student_id = :'stu' and tutor_id = :'tut' \gset
set session_replication_role = replica;
insert into messages (conversation_id, sender_id, kind, body, created_at) values
  (:'conv', :'stu', 'call', 'video:mmmmm-nnnnn-ppppp-qqqqq', now() - interval '1 minute'),
  (:'conv', :'stu', 'call', 'voice:rrrrr-sssss-ttttt-uuuuu', now() - interval '20 minutes'),
  (:'conv', :'stu', 'call', 'meet:vvvvv-wwwww-xxxxx-yyyyy',  now() - interval '1 minute');
set session_replication_role = origin;
select t_err('set role anon; select call_not_answered(''mmmmm-nnnnn-ppppp-qqqqq'')', 'permission denied', 'a visitor cannot send a missed call');
reset role;
select t_as(:'tut2'); set role authenticated;
select t_ok(not call_not_answered('mmmmm-nnnnn-ppppp-qqqqq'), 'someone who did not make the call cannot send its missed call');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok(not call_not_answered('mmmmm-nnnnn-ppppp-qqqqq'), '… not even the person who was called');
reset role;
select t_as(:'stu'); set role authenticated;
select t_ok(call_not_answered('mmmmm-nnnnn-ppppp-qqqqq'), 'the caller sends "missed call" for his unanswered call');
select t_ok(not call_not_answered('mmmmm-nnnnn-ppppp-qqqqq'), '… only once per call');
select t_ok(not call_not_answered('rrrrr-sssss-ttttt-uuuuu'), 'not for a call from 20 minutes ago');
select t_ok(not call_not_answered('vvvvv-wwwww-xxxxx-yyyyy'), 'not for a meeting link');
select t_ok(not call_not_answered('zzzzz-zzzzz-zzzzz-zzzzz'), 'not for a made-up room');
select t_ok(not call_not_answered('video:mmmmm'), 'not for a room in another format');
reset role;
select t_ok((select count(*) from notifications where user_id = :'tut' and data ->> 'type' = 'missed_call') = 1
            and (select title from notifications where user_id = :'tut' and data ->> 'type' = 'missed_call') = 'Missed call'
            and (select (data ->> 'video')::boolean from notifications where user_id = :'tut' and data ->> 'type' = 'missed_call'),
  'the tutor got exactly one missed-call notice, marked as a video call');
select t_ok(not exists (select 1 from notifications where user_id = :'stu' and data ->> 'type' = 'missed_call'), 'the caller gets none');

\echo '--- D4. server clock'
select t_ok((select abs(extract(epoch from server_now() - now())) < 5 from (select 1) x), 'server_now() for the app''s ring check');
set role anon;
select t_ok(server_now() is not null, '… callable before sign-in');
reset role;
