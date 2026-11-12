-- Stage 3 Round A: rule wrapping, indexes, call video settings. Runs after week2_retest.sql.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set tut      '00000000-0000-0000-0000-0000000000c1'

\echo '--- A1. rules run their user checks once per query'
reset role;
select t_ok(not exists (select 1 from pg_policies where schemaname in ('public', 'storage')
  and coalesce(qual, '') || ' ' || coalesce(with_check, '') ~ '(?<!SELECT )(\mauth\.uid|(?<![.\w])is_admin|(?<![.\w])is_active_user|(?<![.\w])is_approved_tutor)\(\)'),
  'no rule calls auth.uid()/is_admin()/is_active_user()/is_approved_tutor() per row');
select t_ok((select qual from pg_policies where tablename = 'conversations' and policyname = 'party_read')
  = '(((student_id = ( SELECT auth.uid() AS uid)) OR (tutor_id = ( SELECT auth.uid() AS uid))) AND ( SELECT is_active_user() AS is_active_user))',
  'chat read rule is the wrapped form');
select t_ok((select count(*) from pg_policies where schemaname = 'storage' and coalesce(qual, '') || coalesce(with_check, '') like '%SELECT auth.uid() AS uid%') >= 4,
  'file rules are wrapped too');
select t_ok((select count(*) from pg_indexes where schemaname = 'public' and indexname in
  ('conversations_student_recent', 'conversations_tutor_recent', 'payments_user_recent', 'payouts_tutor_recent',
   'reviews_student', 'reports_reporter', 'live_responses_tutor', 'availability_slots_tutor', 'wallet_tx_user_recent')) = 9,
  'the missing indexes exist');

\echo '--- A1. behaviour unchanged'
select t_as(:'stu'); set role authenticated;
select t_ok((select count(*) from conversations where student_id <> auth.uid() and tutor_id <> auth.uid()) = 0, 'a student sees only own chats');
select t_ok((select count(*) from conversations) >= 1, 'and does see them');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok((select count(*) from conversations where tutor_id = auth.uid()) >= 1, 'a tutor sees own chats');
select t_ok((select count(*) from conversations where last_message_at > now() + interval '1 hour') = 0, 'the "changed since" filter used by the fallback reload works');
reset role;
update profiles set status = 'blocked' where id = :'stu';
select t_as(:'stu'); set role authenticated;
select t_ok((select count(*) from conversations) = 0, 'a blocked user still sees no chats');
select t_ok((select count(*) from messages) = 0, 'nor messages');
reset role;
update profiles set status = 'active' where id = :'stu';
set role anon; select set_config('request.jwt.claims', '', false);
select t_ok((select count(*) from conversations) = 0, 'a visitor sees no chats');
reset role;

\echo '--- A3. call video cap settings'
select t_as(:'stu'); set role authenticated;
select t_ok((select value::text from app_settings where key = 'call_video_kbps') = '600', 'call_video_kbps 600 readable by signed-in users');
select t_ok((select value::text from app_settings where key = 'call_video_height') = '480', 'call_video_height 480 readable by signed-in users');
reset role;
