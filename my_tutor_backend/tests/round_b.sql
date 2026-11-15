-- Stage 3 Round B: tutor search in pages (B3) and guest relay checks (B2). Runs after capacity.sql.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set stu      '00000000-0000-0000-0000-0000000000b1'

-- Six more approved tutors with Arabic names and different prices / ratings / options.
reset role;
set session_replication_role = replica;
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000b0e1', 'e1@test', '{"role":"tutor"}'),
  ('00000000-0000-0000-0000-00000000b0e2', 'e2@test', '{"role":"tutor"}'),
  ('00000000-0000-0000-0000-00000000b0e3', 'e3@test', '{"role":"tutor"}'),
  ('00000000-0000-0000-0000-00000000b0e4', 'e4@test', '{"role":"tutor"}'),
  ('00000000-0000-0000-0000-00000000b0e5', 'e5@test', '{"role":"tutor"}'),
  ('00000000-0000-0000-0000-00000000b0e6', 'e6@test', '{"role":"tutor"}');
insert into profiles (id, role, full_name, gender, status) values
  ('00000000-0000-0000-0000-00000000b0e1', 'tutor', 'أحمد إبراهيم', 'm', 'active'),
  ('00000000-0000-0000-0000-00000000b0e2', 'tutor', 'آمنة الشامي', 'f', 'active'),
  ('00000000-0000-0000-0000-00000000b0e3', 'tutor', 'مصطفى حداد', 'm', 'active'),
  ('00000000-0000-0000-0000-00000000b0e4', 'tutor', 'Rana 100% Haddad', 'f', 'active'),
  ('00000000-0000-0000-0000-00000000b0e5', 'tutor', 'هدى معلّمة', 'f', 'active'),
  ('00000000-0000-0000-0000-00000000b0e6', 'tutor', 'Blocked Tutor', 'm', 'blocked');
insert into tutor_profiles (user_id, headline, verification, verified_at, hourly_price, rating_avg, rating_count,
                            available_now, instant_booking, max_package_discount, teaches_in_person) values
  ('00000000-0000-0000-0000-00000000b0e1', 'مدرسة رياضيات للثانوية', 'approved', now(), 12, 4.8, 30, true,  true,  10, false),
  ('00000000-0000-0000-0000-00000000b0e2', 'لغة عربية ونحو',          'approved', now(), 8,  4.2, 12, false, true,  0,  true),
  ('00000000-0000-0000-0000-00000000b0e3', 'فيزياء',                  'approved', now(), 25, 3.9, 5,  false, false, 0,  false),
  ('00000000-0000-0000-0000-00000000b0e4', 'English & IELTS',         'approved', now(), 18, 4.9, 40, true,  true,  15, false),
  ('00000000-0000-0000-0000-00000000b0e5', 'مُعَلِّمَة لغة إنكليزية', 'pending',  null,  9,  0,   0,  false, true,  0,  false),
  ('00000000-0000-0000-0000-00000000b0e6', 'Hidden',                  'approved', now(), 10, 5,   99, true,  true,  0,  false);
insert into tutor_subjects (tutor_id, subject_id) values
  ('00000000-0000-0000-0000-00000000b0e1', 'math'),
  ('00000000-0000-0000-0000-00000000b0e2', 'arabic'),
  ('00000000-0000-0000-0000-00000000b0e3', 'physics'),
  ('00000000-0000-0000-0000-00000000b0e4', 'english');
set session_replication_role = origin;

\echo '--- B3. search_tutors: visitors, Arabic letters, filters, sort, paging'
set role anon; select set_config('request.jwt.claims', '', false);
select t_ok((select count(*) from search_tutors()) = (select count(*) from public_tutors), 'a visitor gets the tutor list');
select t_ok(not exists (select 1 from search_tutors(p_limit => 50) where full_name in ('Blocked Tutor', 'هدى معلّمة')),
  'blocked and not-yet-approved tutors never appear');
select t_ok((select full_name from search_tutors('احمد')) = 'أحمد إبراهيم', 'احمد finds أحمد (أ = ا)');
select t_ok((select full_name from search_tutors('ابراهيم')) = 'أحمد إبراهيم', 'ابراهيم finds إبراهيم (إ = ا)');
select t_ok((select full_name from search_tutors('امنه')) = 'آمنة الشامي', 'امنه finds آمنة (آ = ا, ة = ه)');
select t_ok((select full_name from search_tutors('مصطفي')) = 'مصطفى حداد', 'مصطفي finds مصطفى (ى = ي)');
select t_ok((select full_name from search_tutors('مدرسه رياضيات')) = 'أحمد إبراهيم', 'the headline is searched too');
select t_ok((select count(*) from search_tutors('ielts')) = 1, 'search ignores upper / lower case');
select t_ok((select count(*) from search_tutors('100%')) = 1 and (select count(*) from search_tutors('%')) = 1
            and (select count(*) from search_tutors('_')) = 0,
  'a % or _ in the search is a plain character (not "anything")');
select t_ok((select bool_and('physics' = any (subject_ids)) and count(*) >= 1 from search_tutors(p_subject => 'physics')), 'subject filter');
select t_ok((select bool_and(gender = 'f') and count(*) >= 2 from search_tutors(p_gender => 'f')), 'gender filter');
select t_ok((select count(*) from search_tutors(p_gender => 'all')) = (select count(*) from search_tutors()), 'gender "all" = no filter');
select t_ok((select bool_and(hourly_price between 10 and 20) and count(*) >= 2 from search_tutors(p_price_min => 10, p_price_max => 20)), 'price range');
select t_ok((select bool_and(available_now) and count(*) >= 2 from search_tutors(p_available => true)), 'online now only');
select t_ok((select bool_and(instant_booking) from search_tutors(p_instant => true)), 'instant booking only');
select t_ok((select bool_and(max_package_discount > 0) and count(*) >= 2 from search_tutors(p_packages => true)), 'packages only');
select t_ok((select bool_and(teaches_in_person) and count(*) >= 1 from search_tutors(p_in_person => true)), 'in person only');
select t_ok((select array_agg(hourly_price order by n) = (select array_agg(hourly_price order by hourly_price) from public_tutors)
             from (select hourly_price, row_number() over () n from search_tutors(p_sort => 'price', p_limit => 50)) x), 'sort by price, cheapest first');
select t_ok((select array_agg(rating_avg order by n) = (select array_agg(rating_avg order by rating_avg desc) from public_tutors)
             from (select rating_avg, row_number() over () n from search_tutors(p_sort => 'rating', p_limit => 50)) x), 'sort by rating, best first');
select t_ok((select n from (select full_name, row_number() over () n from search_tutors(p_interests => array['physics'])) x where full_name = 'مصطفى حداد')
           < (select n from (select full_name, row_number() over () n from search_tutors()) x where full_name = 'مصطفى حداد'),
  'best match lifts tutors of the student''s subjects');
select t_ok((with a as (select id from search_tutors(p_limit => 2, p_offset => 0)),
                  b as (select id from search_tutors(p_limit => 2, p_offset => 2)),
                  c as (select id from search_tutors(p_limit => 2, p_offset => 4))
             select (select count(*) from (select * from a union select * from b union select * from c) u)
                    = least(6, (select count(*) from public_tutors))
                and not exists (select 1 from a join b using (id)) and not exists (select 1 from b join c using (id))),
  'pages of 2 never repeat or skip a tutor');
select t_ok((select max(total_count) from search_tutors(p_limit => 1)) = (select count(*) from public_tutors), 'total_count = all matches');
select t_ok((select count(*) from search_tutors(p_limit => 1000)) <= 50, 'at most 50 a page');
select t_ok((select count(*) from search_tutors(p_limit => 50) s full join public_tutors p on p.id = s.id
             where s.id is null or p.id is null or s.full_name is distinct from p.full_name or s.headline is distinct from p.headline
                or s.subject_ids <> p.subject_ids or s.students <> p.students or s.available_now <> p.available_now
                or s.hourly_price <> p.hourly_price or s.hours_taught <> p.hours_taught or s.is_new is distinct from p.is_new) = 0,
  'same tutors and same values as the public_tutors view');
reset role;

\echo '--- B2. relay passwords: guests only for a recent real room (10 an hour per address, 20 per room); users active, 30 an hour'
select t_err('set role anon; select turn_guest_allowed(''1.2.3.4'', ''zyxwv-utsrq-pnmkj-hgfed'')', 'permission denied', 'a visitor cannot call turn_guest_allowed');
reset role;
select t_err('set role authenticated; select turn_guest_allowed(''1.2.3.4'', ''zyxwv-utsrq-pnmkj-hgfed'')', 'permission denied', 'nor a signed-in user');
reset role;
select t_err(format('set role authenticated; select turn_user_allowed(%L)', :'stu'), 'permission denied', 'nor turn_user_allowed');
reset role;
select t_err('set role anon; select * from turn_requests', 'permission denied', 'nobody reads the relay log');
reset role;
set session_replication_role = replica;
insert into messages (conversation_id, sender_id, kind, body, created_at)
  select id, student_id, 'call', b, now() - age
  from (select id, student_id from conversations order by created_at limit 1) c,
       (values ('video:kqzpt-mwhra-bcdeg-xyzab', interval '1 minute'),    -- today's call
               ('voice:aaaaa-bbbbb-ccccc-ddddd', interval '400 days'),    -- a call long ago
               ('video:eeeee-fffff-ggggg-hhhhh', interval '2 days'),      -- a call two days ago
               ('meet:jjjjj-kkkkk-mmmmm-nnnnn',  interval '6 days'),      -- a meeting link from this week
               ('meet:ppppp-qqqqq-rrrrr-sssss',  interval '8 days')       -- a meeting link from last week
       ) v(b, age);
set session_replication_role = origin;
set role service_role;
select t_ok(not turn_guest_allowed('1.2.3.4', 'voice:0944555666'), 'a room in another format is refused');
select t_ok(not turn_guest_allowed('1.2.3.4', 'zyxwv-utsrq-pnmkj-hgfed'), 'a made-up room (no call in any chat) is refused');
select t_ok(not turn_guest_allowed('1.2.3.4', 'aaaaa-bbbbb-ccccc-ddddd'), 'a room from a call 400 days ago is refused');
select t_ok(not turn_guest_allowed('1.2.3.4', 'eeeee-fffff-ggggg-hhhhh'), 'a video / voice room older than 24 hours is refused');
select t_ok(turn_guest_allowed('1.2.3.4', 'jjjjj-kkkkk-mmmmm-nnnnn'), 'a meeting link from this week works');
select t_ok(not turn_guest_allowed('1.2.3.4', 'ppppp-qqqqq-rrrrr-sssss'), 'a meeting link older than 7 days is refused');
select t_ok(turn_guest_allowed('1.2.3.4', 'kqzpt-mwhra-bcdeg-xyzab'), 'a recent real call room works');
select t_ok((select bool_and(turn_guest_allowed('1.2.3.4', 'kqzpt-mwhra-bcdeg-xyzab')) from generate_series(1, 8)), '… up to 10 times an hour from one address');
select t_ok(not turn_guest_allowed('1.2.3.4', 'kqzpt-mwhra-bcdeg-xyzab'), 'the 11th from that address in an hour is refused');
select t_ok((select bool_and(turn_guest_allowed('10.0.0.' || g, 'kqzpt-mwhra-bcdeg-xyzab')) from generate_series(1, 11) g), 'other addresses: the room reaches 20 in the hour (9 + 11)');
select t_ok(not turn_guest_allowed('10.0.1.1', 'kqzpt-mwhra-bcdeg-xyzab'), 'the 21st request for one room in an hour is refused, whatever the address');
select t_ok(turn_guest_allowed('10.0.1.1', 'jjjjj-kkkkk-mmmmm-nnnnn'), '… while another room still works');
select t_ok(not turn_guest_allowed('', 'jjjjj-kkkkk-mmmmm-nnnnn'), 'no address → refused');
select t_ok(turn_user_allowed(:'stu'), 'an active signed-in user gets relay passwords');
select t_ok((select bool_and(turn_user_allowed(:'stu')) from generate_series(1, 29)), '… up to 30 an hour');
select t_ok(not turn_user_allowed(:'stu'), 'the 31st in an hour is refused');
reset role;
update profiles set status = 'blocked' where id = '00000000-0000-0000-0000-0000000000b2';
set role service_role;
select t_ok(not turn_user_allowed('00000000-0000-0000-0000-0000000000b2'), 'a blocked account is refused');
select t_ok(not turn_user_allowed(gen_random_uuid()), 'an unknown account is refused');
reset role;
update profiles set status = 'active' where id = '00000000-0000-0000-0000-0000000000b2';
