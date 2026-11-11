-- Attack tests for the reviewer's retest of the week fixes. Runs after week_fixes.sql.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set tut      '00000000-0000-0000-0000-0000000000c1'

select id as conv from conversations where student_id = :'stu' and tutor_id = :'tut' \gset
select id as anyq from live_requests order by created_at desc limit 1 \gset

\echo '--- R1 no false security alarms'
select count(*) as flags_before from message_flags \gset
set role anon; select set_config('request.jwt.claims', '', false);
select t_err(format('select flag_live_request_internal(%L, %L, %L)', :'anyq', :'tut', 'call me 0944 555 666'),
             'permission denied', 'R1 a visitor cannot raise a security alarm');
reset role;
select t_as(:'stu'); set role authenticated;
select t_err(format('select flag_live_request_internal(%L, %L, %L)', :'anyq', :'tut', 'call me 0944 555 666'),
             'permission denied', 'R1 a signed-in user cannot raise one against someone else');
select t_err(format('select assert_slot_free(%L, now() + interval ''2 days'', 60)', :'tut'), 'permission denied', 'R1 internal booking checks are not callable');
select t_err(format('select assert_bookable_tutor(%L)', :'tut'), 'permission denied', 'R1 internal tutor check is not callable');
reset role;
select t_ok((select count(*) from message_flags) = :'flags_before'::int, 'R1 no flag was created');

\echo '--- R3 call invitations carry only the app''s room format'
select t_as(:'stu'); set role authenticated;
select t_err(format('insert into messages (conversation_id, sender_id, kind, body) values (%L, auth.uid(), %L, %L)', :'conv', 'call', 'voice:0944555666'),
             'Invalid call message', 'R3 a phone number as a room name is refused');
select t_err(format('insert into messages (conversation_id, sender_id, kind, body) values (%L, auth.uid(), %L, %L)', :'conv', 'call', 'video:09445-55666-12345-67890'),
             'Invalid call message', 'R3 digits in the room format are refused');
select t_err(format('insert into messages (conversation_id, sender_id, kind, body) values (%L, auth.uid(), %L, %L)', :'conv', 'call', 'meet:whats-appme-nowpl-ease'),
             'Invalid call message', 'R3 a wrong-shaped room is refused');
insert into messages (conversation_id, sender_id, kind, body) values (:'conv', auth.uid(), 'call', 'voice:kqzpt-mwhra-bcdeg-xyzab');
select t_ok((select count(*) from messages where body = 'voice:kqzpt-mwhra-bcdeg-xyzab') = 1, 'R3 a real app invitation still works');
reset role;
\echo 'RETEST FIXES: ALL PASSED'
