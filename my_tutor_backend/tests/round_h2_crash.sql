-- Round H2: crash reports.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set stu   '00000000-0000-0000-0000-0000000000b1'
\set admin '00000000-0000-0000-0000-0000000000a1'

\echo '--- H2. crash reports'
reset role;
delete from app_errors;
select t_as(:'stu'); set role authenticated;
select report_app_error('Null check operator used on a null value', '#0 ChatScreen.build (chat_screen.dart:120)', 51, 'android', 'flutter');
select report_app_error('Null check operator used on a null value', '#0 again', 51, 'android', 'flutter');
select report_app_error('   ', null, 51, 'android', null);
select t_ok((select count(*) from app_errors) = 0, 'a user cannot read the reports');
reset role;
select t_ok((select count(*) from app_errors where user_id = :'stu') = 1, 'a report is kept; the same error again within an hour is not; an empty one is not');
select t_ok((select build from app_errors where user_id = :'stu') = 51 and (select platform from app_errors where user_id = :'stu') = 'android',
  'the build and platform are kept');
select t_as(:'stu'); set role authenticated;
select report_app_error('error ' || g) from generate_series(1, 40) g;
reset role;
select t_ok((select count(*) from app_errors where user_id = :'stu') = 20, 'at most 20 reports an hour per person');
select t_ok((select length(message) from app_errors where user_id = :'stu' order by id limit 1) <= 1000, 'messages are cut to 1000 characters');
select set_config('request.jwt.claims', '{"role":"anon"}', false);
set role anon;
select report_app_error('visitor error', repeat('x', 9000), 51, 'web', null);
reset role;
select t_ok((select length(stack) from app_errors where user_id is null and message = 'visitor error') = 4000, 'a visitor can report; the stack is cut to 4000 characters');
set role anon;
select t_err('select count(*) from app_errors', 'permission denied', 'a visitor cannot read the reports');
select t_err('insert into app_errors (message) values (''x'')', 'permission denied', 'nobody writes the table directly');
reset role;
select t_as(:'admin'); set role authenticated;
select t_ok((select count(*) from app_errors) = 21, 'an admin reads the reports (20 from the user, 1 from the visitor)');
reset role;
delete from app_errors;
