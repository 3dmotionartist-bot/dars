-- Round E: trust and safety. Runs after round_d.sql.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set admin    '00000000-0000-0000-0000-0000000000a1'
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set stu2     '00000000-0000-0000-0000-0000000000b2'
\set tut      '00000000-0000-0000-0000-0000000000c1'
\set tut2     '00000000-0000-0000-0000-0000000000c2'

\echo '--- E1. contact filter: table of cases (hide = hidden + flagged, flag = flagged only, pass = nothing)'
reset role;
create temp table e1_cases (n serial, body text, want text);
insert into e1_cases (body, want) values
  -- wrongly hidden before Round E
  ('الدرس يوم 2026-11-12 10:30', 'pass'),
  ('من 10.30 - 12.30', 'pass'),
  ('2 4 6 8 10 12 14 16', 'pass'),
  ('15.000.000 ليرة', 'pass'),
  ('25000000 ليرة', 'pass'),
  ('x = 12345678 / 9', 'pass'),
  ('3.14159265', 'pass'),
  ('10/11 - 15/11', 'pass'),
  ('حل المعادلة 12345678 / 9', 'pass'),
  ('signal processing in physics', 'pass'),
  ('lesson on 2026-11-09 at 10:30, price 1,500,000', 'pass'),
  ('الموعد 12/11/2026 الساعة 09:30', 'pass'),
  ('السعر 1.000.000.000 ليرة', 'pass'),
  ('0.5 + 0.25 = 0.75', 'pass'),
  ('الأعداد 0 1 2 3 4 5 6 7 8 9', 'pass'),
  ('احسب 0.123456789 × 10', 'pass'),
  ('from 09:00 to 17:30 on 2026-11-20', 'pass'),
  ('صفحة 125 تمرين 7 و 8', 'pass'),
  ('the answer is 1024 or 2048', 'pass'),
  ('رقم السؤال 14 من الوحدة 3', 'pass'),
  ('https://meet.dars.app/0f3a9e21-0933-4123-8456-0933123456ab', 'pass'),
  ('الملف هون https://drive.example.com/file/d/0933123456789/view', 'pass'),
  -- missed before Round E
  ('0933,123,456', 'hide'),
  ('0933*123*456', 'hide'),
  ('0933a123b456', 'hide'),
  ('zero 9 three 3 one 2 three 4 five 6', 'hide'),
  ('0️⃣9️⃣3️⃣3️⃣1️⃣2️⃣3️⃣4️⃣5️⃣6️⃣', 'hide'),
  ('o933 l23 456', 'hide'),
  ('my insta is @ahmad_99', 'hide'),
  ('https://www.tiktok.com/@ahmad', 'hide'),
  ('join https://us02web.zoom.us/j/8812345678', 'hide'),
  ('linkedin.com/in/ahmad-k', 'hide'),
  ('discord.gg/abcd123', 'hide'),
  ('join.skype.com/abcDEF', 'hide'),
  ('ahmad at gmail dot com', 'hide'),
  ('ahmad (at) gmail (dot) com', 'hide'),
  -- still caught
  ('0933 123 456', 'hide'),
  ('0933-123-456', 'hide'),
  ('رقمي ٠٩٣٣ ١٢٣ ٤٥٦', 'hide'),
  ('+963 933 123 456', 'hide'),
  ('00963933123456', 'hide'),
  ('963933123456', 'hide'),
  ('صفر تسعة ثلاثة ثلاثة واحد اثنين ثلاثة اربعة خمسة', 'hide'),
  ('011 2345678', 'hide'),
  ('0933.123.456', 'hide'),
  ('me@example.com', 'hide'),
  ('ahmad @ gmail . com', 'hide'),
  ('wa.me/963933123456', 'hide'),
  ('t.me/ahmad99', 'hide'),
  ('０９３３１２３４５６', 'hide'),
  ('𝟎𝟗𝟑𝟑𝟏𝟐𝟑𝟒𝟓𝟔', 'hide'),
  ('0933 / 123 / 456', 'hide'),
  -- unsure: flagged for the admin, not hidden
  ('933 123 456', 'flag'),
  ('0933 1234', 'flag'),
  ('شو رقم الواتس تبعك؟', 'flag'),
  ('what is your number?', 'flag'),
  ('add me on tiktok', 'flag'),
  ('send me the zoom link', 'flag'),
  ('talk on signal app', 'flag'),
  -- ordinary Arabic lesson messages pass untouched
  ('مرحبا أستاذ، متى الدرس القادم؟', 'pass'),
  ('شكراً أستاذ، الدرس كان ممتاز', 'pass'),
  ('حليت التمارين من 1 إلى 10', 'pass'),
  ('بدي راجع الوحدة الثالثة قبل الامتحان', 'pass'),
  ('ممكن نأجل الدرس لبكرا الساعة 5؟', 'pass'),
  ('الجواب هو س = 25 و ص = 40', 'pass'),
  ('أرسلت لك صورة الواجب', 'pass'),
  ('ما فهمت قانون نيوتن الثاني', 'pass'),
  ('امتحاني يوم الأحد 2026/11/23', 'pass'),
  ('كم سعر الحصة؟ 50000 ليرة؟', 'pass'),
  ('درسنا الفصل 4 صفحة 112', 'pass'),
  ('اشرحلي المسألة رقم 7 لو سمحت', 'pass'),
  ('خلصت الواجب، 20 سؤال', 'pass'),
  ('الساعة 8:15 مناسبة؟', 'pass'),
  ('علامتي بالمذاكرة 18 من 20', 'pass'),
  ('بدنا نكمل المصفوفات 3×3', 'pass'),
  ('رح اتأخر 10 دقائق', 'pass'),
  ('اللوغاريتم log 100 = 2', 'pass'),
  ('شو الفرق بين المضارع والماضي؟', 'pass'),
  ('سنة الامتحان 2027 إن شاء الله', 'pass'),
  ('صحح لي هالجملة لو سمحت: I has a book', 'pass');

create temp table e1_got as
select n, body, want,
       case when contact_hidden(body) then 'hide' when jsonb_array_length(contact_hits(body)) > 0 then 'flag' else 'pass' end as got
from e1_cases;
select 'case ' || n || ': ' || body || ' → want ' || want || ', got ' || got from e1_got where got <> want;
select t_ok((select count(*) from e1_got) >= 60, 'at least 60 filter cases');
select t_ok((select count(*) from e1_got where got <> want) = 0,
            'every filter case is right (' || (select count(*) from e1_got where got = want) || ' / ' || (select count(*) from e1_got) || ')');
select t_ok((select count(*) from e1_got where want = 'pass' and body ~ '[ء-ي]' and body !~ '\d{4}-' ) >= 20, '20+ ordinary Arabic messages included');

\echo '--- E1. masking (live-help questions, reviews): only contact details are hidden'
select t_ok(mask_contacts('الدرس يوم 2026-11-12 10:30 والسعر 15.000.000 ليرة') = 'الدرس يوم 2026-11-12 10:30 والسعر 15.000.000 ليرة',
  'ordinary numbers are no longer masked');
select t_ok(mask_contacts('حل المعادلة 12345678 / 9 ورقمي 0933 123 456') = 'حل المعادلة 12345678 / 9 ورقمي •••', 'only the phone is masked');
select t_ok(mask_contacts('راسلني me@example.com') = 'راسلني •••', 'an e-mail is masked');
select t_ok(mask_contacts('my insta is @ahmad_99') = 'my insta is •••', 'a handle is masked');
select t_ok(mask_contacts('zero 9 three 3 one 2 three 4 five 6') = '•••', 'a number in words hides the whole text');
select t_ok(mask_contacts('https://wa.me/963933123456 hi') = '••• hi', 'a WhatsApp link is masked');

\echo '--- E1. chat: a number split over messages, flags, what the other person sees'
reset role;
select id as conv from conversations where student_id = :'stu' and tutor_id = :'tut' \gset
delete from message_flags;
select coalesce(max(id), 0) as m0 from messages \gset
select t_as(:'stu'); set role authenticated;
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'رقمي');
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), '0933');
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), '123');
select t_ok(not exists (select 1 from messages where conversation_id = :'conv' and blocked and id > :m0),
  'the first pieces alone are not hidden');
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), '456');
select t_ok((select count(*) from messages where conversation_id = :'conv' and blocked and id > :m0 and body in ('0933', '123', '456')) = 3,
  'a number split over three messages is hidden — all three pieces');
select t_ok((select blocked from messages where conversation_id = :'conv' and body = 'رقمي' order by id desc limit 1) = false,
  '… the words around it stay');
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'شكراً، بدي أسأل عن تمرين 5');
select t_ok((select blocked from messages where conversation_id = :'conv' order by id desc limit 1) = false,
  'the next ordinary message is not hidden because of the earlier number');
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'الدرس يوم 2026-11-12 10:30');
select t_ok((select blocked from messages where conversation_id = :'conv' order by id desc limit 1) = false, 'a date and time is delivered');
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'add me on tiktok');
select t_ok((select blocked from messages where conversation_id = :'conv' order by id desc limit 1) = false, 'an unsure message is delivered …');
reset role;
select t_ok((select count(*) from message_flags where conversation_id = :'conv' and kind = 'phone' and source = 'message') = 1,
  'the split number is flagged once for the admin');
select t_ok(exists (select 1 from message_flags where conversation_id = :'conv' and kind = 'contact_request' and excerpt ~ 'tiktok'),
  '… and flagged for the admin');
select t_ok((select count(*) from notifications where user_id = :'admin' and data ? 'security_flag' and data ->> 'conversation_id' = :'conv') >= 2,
  'the admin is alerted');
select t_as(:'tut'); set role authenticated;
select t_ok(not exists (select 1 from messages where conversation_id = :'conv' and body in ('0933', '123', '456')),
  'the tutor sees none of the hidden pieces');
select t_ok(exists (select 1 from messages where conversation_id = :'conv' and body = 'الدرس يوم 2026-11-12 10:30'), 'the tutor sees the date message');
select t_ok((select count(*) from message_flags) = 0, 'tutors cannot read flags');
reset role;
select t_as(:'stu'); set role authenticated;
select t_ok((select count(*) from message_flags) = 0, 'students cannot read flags');
select t_err($$select flag_contact_hits('[{"kind":"phone","matched":"x"}]', auth.uid(), 'x', null, null, null, 'review', 'x', 'x')$$,
  'permission denied', 'users cannot raise false alarms');
select t_err($$select contact_recent_text(gen_random_uuid(), auth.uid(), null)$$, 'permission denied', 'users cannot read others'' recent messages through the helper');
reset role;
set role anon; select set_config('request.jwt.claims', '', false);
select t_ok(contact_hidden('0933 123 456') and not contact_hidden('10:30'), 'the pure check functions are harmless for visitors');
select t_err($$select contact_split_hits(gen_random_uuid(), gen_random_uuid(), 1, 'x')$$, 'permission denied', 'visitors cannot call the split helper');
reset role;

\echo '--- E1. tutor profile, review comments, lesson links, live help'
update tutor_profiles set verification = 'pending' where user_id = :'tut';     -- in review: edits are saved at once
select t_as(:'tut'); set role authenticated;
select t_err($$update tutor_profiles set about = 'للتواصل 0933 123 456' where user_id = auth.uid()$$, 'not allowed in your profile',
  'a phone in the tutor''s about is refused');
select t_err($$update tutor_profiles set headline = 'insta @samer_math' where user_id = auth.uid()$$, 'not allowed in your profile',
  'a handle in the headline is refused');
update tutor_profiles set about = 'أدرّس الرياضيات منذ 2014، الحصة 60 دقيقة، أكثر من 1.500 طالب' where user_id = auth.uid();
select t_ok((select about from tutor_profiles where user_id = auth.uid()) ~ '2014', 'ordinary numbers in the about are fine');
update tutor_profiles set about = 'send me the zoom link before the lesson' where user_id = auth.uid();
reset role;
select t_ok(exists (select 1 from message_flags where source = 'tutor_profile' and source_id = :'tut' and kind = 'contact_request'),
  'an unsure about text is saved and flagged');
set session_replication_role = replica;
update tutor_profiles set about = 'old text 0944 555 666' where user_id = :'tut';       -- written before Round E
set session_replication_role = origin;
select t_as(:'tut'); set role authenticated;
update tutor_profiles set hourly_price = hourly_price where user_id = auth.uid();
select t_ok(true, 'a tutor whose old about has a number can still save other fields');
reset role;
update tutor_profiles set about = '', verification = 'approved' where user_id = :'tut';

select id as rl from lessons where tutor_id = :'tut' order by created_at limit 1 \gset
select t_as(:'tut'); set role authenticated;
select t_err(format($$select set_lesson_link(%L, 'https://wa.me/963933123456')$$, :'rl'), 'not allowed', 'a WhatsApp lesson link is refused');
select t_err(format($$select set_lesson_link(%L, 'https://us02web.zoom.us/j/8812345678')$$, :'rl'), 'not allowed', 'an outside Zoom link is refused');
select null from set_lesson_link(:'rl', 'https://meet.dars.app/' || :'rl');
select t_ok((select meeting_url from lessons where id = :'rl') like 'https://meet.dars.app/%', 'the Dars classroom link is fine');
reset role;

delete from reviews where lesson_id = :'rl';
insert into reviews (lesson_id, student_id, tutor_id, stars, comment)
values (:'rl', :'stu', :'tut', 5, 'أستاذ ممتاز، كلموه على 0933 123 456 أو @samer_math');
select t_ok((select comment from reviews where lesson_id = :'rl') = 'أستاذ ممتاز، كلموه على ••• أو •••', 'contact details in a review are masked');
select t_ok(exists (select 1 from message_flags where source = 'review' and source_id = :'rl'), '… and flagged');
update reviews set comment = 'شرح رائع للفصل 4، علامتي صارت 18 من 20' where lesson_id = :'rl';
select t_ok((select comment from reviews where lesson_id = :'rl') = 'شرح رائع للفصل 4، علامتي صارت 18 من 20', 'an ordinary review is unchanged');
delete from reviews where lesson_id = :'rl';

select t_as(:'tut'); set role authenticated;
select null from set_availability(true);
reset role;
select t_as(:'stu2'); set role authenticated;
select create_live_request('math', 'high', 'امتحاني 2026-11-12 10:30، حل 12345678 / 9') as lq2 \gset
select t_ok((select body from live_requests where id = :'lq2') = 'امتحاني 2026-11-12 10:30، حل 12345678 / 9', 'live help: ordinary numbers are no longer masked');
select create_live_request('math', 'high', 'كلمني 0933 123 456') as lq3 \gset
select t_ok((select body from live_requests where id = :'lq3') = 'كلمني •••', 'live help: a phone is masked');
reset role;
select t_ok(exists (select 1 from message_flags where live_request_id = :'lq3' and kind = 'phone'), 'live help: flagged for the admin');
select t_as(:'admin'); set role authenticated;
select t_ok((select count(distinct source) from admin_message_flags where source in ('review', 'tutor_profile', 'live_request', 'message')) = 4,
  'the admin sees flags from chats, profiles, reviews and live help');
select t_ok((select message_body from admin_message_flags where source = 'review' limit 1) ~ '0933', 'the admin sees the original text');
reset role;

\echo '--- E2. tutor documents'
select t_err('set role anon; select add_tutor_document(''id'', ''tutor-docs/x/id.jpg'')', 'permission denied', 'a visitor cannot add documents');
reset role;
select t_as(:'tut2'); set role authenticated;
select add_tutor_document('id', 'tutor-docs/' || auth.uid() || '/id-1700000000000.jpg') as doc1 \gset
select null from add_tutor_document('certificate', 'tutor-docs/' || auth.uid() || '/cert-1700000000001.pdf');
select t_ok((select count(*) from tutor_documents) = 2, 'a tutor records his ID and certificate');
select t_err(format($$select add_tutor_document('id', 'tutor-docs/%s/id.jpg')$$, :'tut'), 'from the Dars app', 'a document in someone else''s folder is refused');
select t_err($$select add_tutor_document('id', 'avatars/x.jpg')$$, 'from the Dars app', 'a document outside tutor-docs is refused');
select t_err($$select add_tutor_document('passport', 'tutor-docs/' || auth.uid() || '/p.jpg')$$, 'Unknown document type', 'unknown document types are refused');
select t_err($$insert into tutor_documents (tutor_id, kind, file_path) values (auth.uid(), 'id', 'tutor-docs/x/y.jpg')$$, 'permission denied',
  'documents cannot be written directly');
reset role;
select t_as(:'stu'); set role authenticated;
select t_ok((select count(*) from tutor_documents) = 0, 'a student sees no tutor documents');
select t_err(format($$select add_tutor_document('id', 'tutor-docs/%s/id.jpg')$$, :'stu'), 'Tutors only', 'a student cannot add tutor documents');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok((select count(*) from tutor_documents) = 0, 'another tutor sees none of them');
select null from remove_tutor_document(:'doc1');
reset role;
select t_ok((select count(*) from tutor_documents where tutor_id = :'tut2') = 2, 'another tutor cannot remove them');
select t_as(:'admin'); set role authenticated;
select t_ok((select jsonb_array_length(documents) from admin_tutors where user_id = :'tut2') = 2, 'the admin sees the documents');
reset role;

\echo '--- E2. application, code of conduct, approval with a reason'
update tutor_profiles set verification = 'rejected', rejection_reason = 'blurry ID' where user_id = :'tut2';
select t_as(:'tut2'); set role authenticated;
select t_err($$select submit_tutor_application(false)$$, 'code of conduct', 'the code of conduct must be accepted');
select null from submit_tutor_application(true);
select t_ok((select verification = 'pending' and rejection_reason is null and conduct_accepted_at is not null from tutor_profiles where user_id = auth.uid()),
  'sending again after a rejection puts the profile back in review');
reset role;
select t_ok(exists (select 1 from notifications where user_id = :'admin' and title = 'New tutor application'), 'the admin is told');
select t_as(:'admin'); set role authenticated;
select t_err(format($$select admin_set_tutor_verification(%L, 'rejected', ' ')$$, :'tut2'), 'reason', 'a rejection needs a reason');
select null from admin_set_tutor_verification(:'tut2', 'rejected', 'Please upload a clearer ID photo');
reset role;
select t_ok((select rejection_reason from tutor_profiles where user_id = :'tut2') = 'Please upload a clearer ID photo', 'the reason is saved for the tutor');
update tutor_profiles set verification = 'approved', rejection_reason = null where user_id = :'tut2';

\echo '--- E2. private tutor columns (#18)'
update tutor_profiles set commission_rate = 0.12, cv_url = 'tutor-docs/x/cv.pdf', linkedin_url = 'https://linkedin.com/in/x' where user_id = :'tut';
set role anon; select set_config('request.jwt.claims', '', false);
select t_ok((select count(*) from tutor_profiles) = 0, 'visitors cannot read tutor_profiles (commission, CV, LinkedIn, rejection reason)');
select t_ok((select count(*) from public_tutors where id = :'tut') = 1, '… the public tutor card still works');
reset role;
select t_as(:'stu'); set role authenticated;
select t_ok((select count(*) from tutor_profiles) = 0, 'students cannot read tutor_profiles either');
select t_ok(not exists (select 1 from information_schema.columns where table_name = 'public_tutors'
                        and column_name in ('commission_rate', 'rejection_reason', 'cv_url', 'linkedin_url')), 'the public card has none of those columns');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok((select commission_rate from tutor_profiles where user_id = auth.uid()) = 0.12, 'the tutor still reads his own profile');
reset role;

\echo '--- E2. edits after approval wait for the admin (#18)'
reset role;
select headline as h0, about as a0, hourly_price as p0 from tutor_profiles where user_id = :'tut' \gset
select full_name as n0 from profiles where id = :'tut' \gset
insert into tutor_level_prices (tutor_id, level_id, price) values (:'tut', 'high', 15) on conflict do nothing;
select t_as(:'tut'); set role authenticated;
update tutor_profiles set headline = 'Physics champion', about = 'New about text', hourly_price = 99, teaches_online = false where user_id = auth.uid();
update profiles set full_name = 'Samer New' where id = auth.uid();
update tutor_level_prices set price = 77 where tutor_id = auth.uid();
insert into tutor_level_prices (tutor_id, level_id, price) values (auth.uid(), 'university', 88)
  on conflict (tutor_id, level_id) do update set price = excluded.price;
delete from tutor_level_prices where tutor_id = auth.uid() and level_id = 'high';
select t_ok((my_pending_tutor_changes() -> 'changes' ->> 'headline') = 'Physics champion'
            and (my_pending_tutor_changes() -> 'changes' ->> 'full_name') = 'Samer New'
            and (my_pending_tutor_changes() -> 'changes' -> 'level_prices' ->> 'university')::numeric = 88,
  'the tutor sees his changes waiting for review');
select t_err($$update tutor_profiles set about = 'call 0933 123 456' where user_id = auth.uid()$$, 'not allowed in your profile',
  'a waiting change is still checked for contact details');
reset role;
set role anon; select set_config('request.jwt.claims', '', false);
select t_ok((select headline = :'h0' and hourly_price = :p0 and full_name = :'n0' from public_tutors where id = :'tut'),
  'visitors still see the old name, headline and price');
reset role;
select t_ok((select teaches_online from tutor_profiles where user_id = :'tut') = false, 'other settings are saved at once');
select t_ok(not exists (select 1 from tutor_level_prices where tutor_id = :'tut' and price in (77, 88)), 'the public price list is unchanged');
select t_ok(exists (select 1 from tutor_level_prices where tutor_id = :'tut' and level_id = 'high'), 'a price cannot be deleted by the tutor after approval');
select t_as(:'tut'); set role authenticated;
select t_err($$select admin_review_tutor_changes(auth.uid(), true)$$, 'Admins only', 'a tutor cannot approve his own changes');
reset role;
select t_as(:'admin'); set role authenticated;
select t_ok((select pending_changes ->> 'about' from admin_tutors where user_id = :'tut') = 'New about text', 'the admin sees the waiting changes');
select t_err(format($$select admin_review_tutor_changes(%L, false, '')$$, :'tut'), 'reason', 'turning changes down needs a reason');
select null from admin_review_tutor_changes(:'tut', true);
reset role;
select t_ok((select headline = 'Physics champion' and about = 'New about text' and hourly_price = 99 from public_tutors where id = :'tut'),
  'approved changes go public');
select t_ok((select full_name from profiles where id = :'tut') = 'Samer New', '… the new name too');
select t_ok((select price from tutor_level_prices where tutor_id = :'tut' and level_id = 'university') = 88, '… and the new prices');
select t_ok(not exists (select 1 from tutor_pending_changes where tutor_id = :'tut'), 'nothing is left waiting');
select t_ok(exists (select 1 from notifications where user_id = :'tut' and title = 'Profile changes approved'), 'the tutor is told');
select t_as(:'tut'); set role authenticated;
update tutor_profiles set headline = 'Too good to be true' where user_id = auth.uid();
reset role;
select t_as(:'admin'); set role authenticated;
select null from admin_review_tutor_changes(:'tut', false, 'Please keep the headline factual');
reset role;
select t_ok((select headline from tutor_profiles where user_id = :'tut') = 'Physics champion', 'turned-down changes are dropped');
select t_ok(exists (select 1 from notifications where user_id = :'tut' and body = 'Please keep the headline factual'), 'the tutor gets the reason');
update tutor_profiles set headline = :'h0', about = :'a0', hourly_price = :p0, teaches_online = true where user_id = :'tut';
update profiles set full_name = :'n0' where id = :'tut';
select t_as(:'tut2'); set role authenticated;
select null from submit_tutor_application(true);
reset role;

\echo '--- E3. age at sign-up'
\set teen     '00000000-0000-0000-0000-0000000000b3'
\set kid      '00000000-0000-0000-0000-0000000000b4'
insert into auth.users (id, email, phone, raw_user_meta_data) values
  (:'teen', null, '+963900000003', '{"full_name":"Rami","role":"student"}'),
  (:'kid',  null, '+963900000004', '{"full_name":"Tala","role":"student"}');
select extract(year from now())::int as yr \gset
select t_as(:'teen'); set role authenticated;
update profiles set birth_year = :yr - 15 where id = auth.uid();
reset role;
select t_ok(is_minor(:'teen'), 'a 15-year-old is under 18');
select t_as(:'teen'); set role authenticated;
select t_err(format($$update profiles set birth_year = %s where id = auth.uid()$$, :yr - 30), 'already saved', 'the year of birth cannot be changed afterwards');
reset role;
select t_as(:'kid'); set role authenticated;
select t_err(format($$update profiles set birth_year = %s where id = auth.uid()$$, :yr - 11), 'through a parent', 'under 13 cannot have an own account');
reset role;
select t_as(:'stu2'); set role authenticated;
select t_err(format($$update profiles set birth_year = %s where id = auth.uid()$$, :yr - 16), 'for adults', 'a parent account must be 18+');
update profiles set birth_year = :yr - 40 where id = auth.uid();
reset role;
select t_ok(not is_minor(:'stu') and not is_minor(:'stu2'), 'accounts without a year (older apps) and adults are not minors');

\echo '--- E3. parent approval with a code'
select t_as(:'teen'); set role authenticated;
select t_err($$select create_live_request('math', 'high', 'سؤال')$$, 'parent needs to approve', 'a teen without a parent cannot ask for live help');
select (my_parent_code() ->> 'code') as pcode \gset
select t_ok(length(:'pcode') = 8 and (my_parent_code() ->> 'code') = :'pcode', 'the teen gets one 8-letter code');
select t_ok((select count(*) from parent_links) = 1, 'the teen sees his own link only');
reset role;
select t_as(:'stu'); set role authenticated;
select t_err(format($$select link_child_account(%L)$$, :'pcode'), 'Only a parent account', 'a student cannot approve a child');
select t_ok((select count(*) from parent_links) = 0, 'other users cannot see codes');
reset role;
select t_as(:'stu2'); set role authenticated;
select t_err($$select link_child_account('WRONGCOD')$$, 'not valid', 'a wrong code is refused');
select t_ok((link_child_account(lower(:'pcode')) ->> 'name') = 'Rami', 'the parent approves with the code');
select t_err(format($$select link_child_account(%L)$$, :'pcode'), 'not valid', 'a code works once');
select t_ok((my_children() -> 'accounts' -> 0 ->> 'name') = 'Rami', 'the parent sees the child in "my children"');
reset role;
select t_ok(exists (select 1 from notifications where user_id = :'teen' and title = 'Your parent approved your account'), 'the teen is told');
select t_ok(not needs_parent(:'teen'), 'the teen can now use Dars');

\echo '--- E3. in-person lessons for minors only when booked by a parent'
select t_err(format($$insert into lessons (student_id, tutor_id, starts_at, duration_min, mode, status, price) values (%L, %L, now() + interval '3 days', 60, 'in_person', 'pending_payment', 10)$$, :'teen', :'tut'),
  'booked by a parent', 'a teen cannot book an in-person lesson');
insert into app_settings (key, value) values ('max_unpaid_bookings', '99') on conflict (key) do update set value = excluded.value;
select (select d + interval '6 hours 30 minutes' from generate_series(date_trunc('day', now()) + interval '30 days', date_trunc('day', now()) + interval '60 days', interval '1 day') d
        where extract(dow from d + interval '3 hours') between 0 and 5
          and not exists (select 1 from lessons where tutor_id = :'tut' and starts_at::date = d::date) limit 1) as slot \gset
select t_as(:'stu2'); set role authenticated;
select save_child_profile(null, 'Tala', 'elementary', :yr - 9) as kidp \gset
select t_err($$select save_child_profile(null, 'Tala 0933123456')$$, 'not allowed', 'no contact details in a child''s name');
select (book_lesson_for_child(:'kidp', :'tut', :'slot', 60, 'math', null, 'in_person', null, false) ->> 'lesson_id') as kl \gset
select t_ok((select child_name = 'Tala' and mode = 'in_person' and student_id = auth.uid() and level_id = 'elementary' from lessons where id = :'kl'),
  'a parent books an in-person lesson for a child (the tutor sees the child''s name)');
reset role;
select t_as(:'stu'); set role authenticated;
select t_err(format($$select book_lesson_for_child(%L, %L, %L, 60, 'math')$$, :'kidp', :'tut', :'slot'), 'Not your child', 'nobody else can book for that child');
select t_ok((select count(*) from child_profiles) = 0, 'nobody else sees the child profile');
reset role;
select t_as(:'stu2'); set role authenticated;
select t_ok(jsonb_array_length(child_activity(:'kidp') -> 'lessons') = 1, 'the parent sees the child''s lessons');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok((select child_name from lessons where id = :'kl') = 'Tala', 'the tutor sees whom the lesson is for');
reset role;

\echo '--- E3. the parent sees the linked child''s lessons and chats (read-only)'
select t_as(:'teen'); set role authenticated;
select create_live_request('math', 'high', 'كيف أحل هذه المعادلة؟') as tq \gset
reset role;
select t_as(:'tut'); set role authenticated;
select respond_live_request(:'tq', true) as tconv \gset
reset role;
select t_as(:'teen'); set role authenticated;
insert into messages (conversation_id, sender_id, body) values (:'tconv', auth.uid(), 'شكراً أستاذ');
reset role;
select t_as(:'stu2'); set role authenticated;
select t_ok(jsonb_array_length(child_activity(:'teen') -> 'chats') = 1, 'the parent sees the teen''s chats');
select t_ok((child_chat_messages(:'tconv') -> 0 ->> 'body') = 'شكراً أستاذ' and (child_chat_messages(:'tconv') -> 0 ->> 'from_child')::boolean,
  '… and the messages, read-only');
select t_err(format($$insert into messages (conversation_id, sender_id, body) values (%L, auth.uid(), 'hi')$$, :'tconv'), 'row-level security',
  'the parent cannot write in the child''s chat');
reset role;
select t_as(:'stu'); set role authenticated;
select t_err(format($$select child_activity(%L)$$, :'teen'), 'Not your child', 'another user cannot see the teen''s activity');
select t_err(format($$select child_chat_messages(%L)$$, :'tconv'), 'Not your child', 'another user cannot read the teen''s chat');
reset role;
select t_as(:'tut'); set role authenticated;
select t_err(format($$select child_chat_messages(%L)$$, :'tconv'), 'Not your child', 'the tutor cannot use the parent''s view');
reset role;
set role anon; select set_config('request.jwt.claims', '', false);
select t_err(format($$select child_activity(%L)$$, :'teen'), 'permission denied', 'visitors cannot call the parent''s view');
reset role;
select t_as(:'stu2'); set role authenticated;
select null from unlink_child_account(:'teen');
reset role;
select t_ok(needs_parent(:'teen'), 'after the parent removes the link, the teen waits for a parent again');
select t_as(:'teen'); set role authenticated;
select t_err(format($$insert into messages (conversation_id, sender_id, body) values (%L, auth.uid(), 'hi')$$, :'tconv'), 'parent needs to approve',
  'a teen without a parent cannot message');
reset role;

\echo '--- E3. block a user'
select id as bconv from conversations where student_id = :'stu' and tutor_id = :'tut' \gset
select t_as(:'stu'); set role authenticated;
select t_err(format($$select block_user(%L)$$, :'kid'), 'in touch with', 'you can only block people you are in touch with');
select null from block_user(:'tut');
select t_err(format($$insert into messages (conversation_id, sender_id, body) values (%L, auth.uid(), 'hi')$$, :'bconv'), 'blocked',
  'the blocker cannot message the blocked person (unblock first)');
reset role;
select t_as(:'tut'); set role authenticated;
select t_err(format($$insert into messages (conversation_id, sender_id, body) values (%L, auth.uid(), 'hello?')$$, :'bconv'), 'blocked',
  'the blocked person cannot message');
select t_err(format($$insert into messages (conversation_id, sender_id, kind, body) values (%L, auth.uid(), 'call', 'video:kqzpt-mwhra-bcdeg-xyzab')$$, :'bconv'),
  'blocked', '… nor call');
select t_ok((select count(*) from user_blocks) = 0, 'the blocked person does not see the block list');
reset role;
select t_as(:'stu'); set role authenticated;
select null from unblock_user(:'tut');
insert into messages (conversation_id, sender_id, body) values (:'bconv', auth.uid(), 'sorry, back');
select t_ok(true, 'after unblocking, messages work again');
reset role;
set role anon; select set_config('request.jwt.claims', '', false);
select t_err(format($$select block_user(%L)$$, :'tut'), 'permission denied', 'visitors cannot block');
reset role;

\echo '--- E3. lesson attendance log'
select t_as(:'tut'); set role authenticated;
update lessons set starts_at = now() + interval '10 minutes' where id = :'kl';
reset role;
update lessons set starts_at = now() + interval '10 minutes' where id = :'kl';
select t_as(:'tut'); set role authenticated;
select null from log_lesson_attendance(:'kl', 'join');
reset role;
select t_as(:'stu2'); set role authenticated;
select null from log_lesson_attendance(:'kl', 'join');
select null from log_lesson_attendance(:'kl', 'leave');
select t_err(format($$select log_lesson_attendance(%L, 'teleport')$$, :'kl'), 'Unknown event', 'only join / leave');
select t_ok((select count(*) from lesson_attendance) = 0, 'users cannot read the attendance log');
reset role;
select t_as(:'stu'); set role authenticated;
select t_err(format($$select log_lesson_attendance(%L, 'join')$$, :'kl'), 'Lesson not found', 'someone else cannot write attendance for a lesson');
reset role;
select t_as(:'admin'); set role authenticated;
select t_ok((select jsonb_array_length(attendance) from admin_lessons where id = :'kl') = 3
            and (select attendance -> 0 ->> 'who' from admin_lessons where id = :'kl') = 'tutor',
  'the admin sees join and leave times of both sides');
reset role;

\echo '--- E4. consent to Terms & Privacy'
select t_as(:'stu'); set role authenticated;
select t_ok((terms_status() ->> 'accepted')::boolean = false and (terms_status() ->> 'version')::int = 1, 'a user who never accepted is asked');
select t_err($$select accept_terms(7)$$, 'Unknown version', 'only the current version can be accepted');
select null from accept_terms(1);
select t_ok((terms_status() ->> 'accepted')::boolean, 'accepted once, not asked again');
reset role;
update app_settings set value = '2' where key = 'terms_version';
select t_as(:'stu'); set role authenticated;
select t_ok((terms_status() ->> 'accepted')::boolean = false, 'after the owner raises the version, everyone is asked again');
select null from accept_terms(2);
reset role;
update app_settings set value = '1' where key = 'terms_version';
set role anon; select set_config('request.jwt.claims', '', false);
select t_err($$select accept_terms(1)$$, 'permission denied', 'visitors cannot record consent');
reset role;

\echo '--- E4. delete my account'
\set gone '00000000-0000-0000-0000-0000000000b5'
insert into auth.users (id, email, phone, raw_user_meta_data) values (:'gone', 'gone@example.com', '+963900000005', '{"full_name":"Nour Leaving","role":"student"}');
select id as tconv2 from conversations where student_id = :'stu' and tutor_id = :'tut' \gset
insert into conversations (student_id, tutor_id) values (:'gone', :'tut') returning id as gconv \gset
select t_as(:'gone'); set role authenticated;
insert into messages (conversation_id, sender_id, body) values (:'gconv', auth.uid(), 'my private question about homework');
select null from save_device_token('fcmTokenGone_0123456789abcdef', 'android', 'ar');
select t_ok((request_account_deletion() ->> 'delete_after')::timestamptz > now() + interval '13 days', 'a user asks to delete his account (14 days)');
select t_ok((terms_status() -> 'deletion' ->> 'delete_after') is not null, 'the app knows a deletion is waiting');
select null from cancel_account_deletion();
select t_ok((terms_status() -> 'deletion') = 'null'::jsonb, 'signing in again and keeping the account cancels it');
select null from request_account_deletion();
reset role;
select t_ok(not exists (select 1 from device_tokens where user_id = :'gone'), 'no more notifications after asking');
select t_as(:'stu'); set role authenticated;
select t_ok((select count(*) from account_deletions) = 0, 'other users cannot see the deletion queue');
reset role;
select t_as(:'tut'); set role authenticated;
select t_err(format($$select admin_delete_account_now(%L)$$, :'gone'), 'Admins only', 'only an admin can delete at once');
reset role;
select t_as(:'admin'); set role authenticated;
select t_ok((select full_name from admin_account_deletions where user_id = :'gone') = 'Nour Leaving', 'the admin sees the queue');
select t_err($$select request_account_deletion()$$, 'another admin', 'an admin account is not deleted this way');
reset role;
select t_ok(process_account_deletions() = 0, 'nothing is deleted before the 14 days');
update account_deletions set delete_after = now() - interval '1 minute' where user_id = :'gone';
select t_ok(process_account_deletions() = 1, 'the daily job deletes it after 14 days');
select t_ok((select full_name = 'Deleted user' and phone is null and email is null and status = 'deleted' from profiles where id = :'gone'),
  'name, phone and e-mail are gone; the account is closed');
select t_ok((select body from messages where conversation_id = :'gconv' and sender_id = :'gone' limit 1) = '', 'the chat text is removed');
select t_ok((select email is null and phone is null from auth.users where id = :'gone'), 'the sign-in has no phone / e-mail left');
select t_ok((select status from account_deletions where user_id = :'gone') = 'done', 'the queue shows it as done');
select t_ok(exists (select 1 from conversations where id = :'gconv'), 'the tutor keeps the (emptied) chat and lesson history');
select t_as(:'gone'); set role authenticated;
select t_err($$select request_account_deletion()$$, 'Not allowed', 'a deleted account can do nothing');
reset role;
update lessons set starts_at = now() + interval '20 days', status = 'pending_payment' where id = :'kl';
select t_as(:'stu2'); set role authenticated;
select t_err($$select request_account_deletion()$$, 'upcoming lessons', 'an account with upcoming lessons must cancel or finish them first');
reset role;

\echo '--- E5. phone sign-in switch and adding a phone'
set role anon; select set_config('request.jwt.claims', '', false);
select t_ok((select value #>> '{}' from app_settings where key = 'phone_signin') = 'off', 'phone sign-in starts switched off (the app shows e-mail only)');
reset role;
update auth.users set phone = '+963944555666' where id = :'admin';
select t_ok((select phone from profiles where id = :'admin') = '+963944555666', 'a phone added to an e-mail account becomes the profile''s phone');
update auth.users set phone = null where id = :'admin';
select t_ok((select phone from profiles where id = :'admin') = '+963944555666', 'removing it from the sign-in does not wipe the profile');

\echo '--- Round E: who may call each new function'
reset role;
create temp table e_funcs as
select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args, p.prorettype = 'trigger'::regtype as is_trigger
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = any (array[
  'accept_terms','add_tutor_document','admin_delete_account_now','admin_review_tutor_changes','anonymise_account','block_user',
  'blocked_between','book_lesson_for_child','cancel_account_deletion','child_activity','child_chat_messages','contact_recent_text',
  'contact_split_hits','flag_contact_hits','hold_tutor_change','is_minor','link_child_account','log_lesson_attendance','my_children',
  'my_parent_code','my_pending_tutor_changes','needs_parent','process_account_deletions','remove_child_profile','remove_tutor_document',
  'request_account_deletion','save_child_profile','submit_tutor_application','terms_status','tutor_edit_held','unblock_user',
  'unlink_child_account','flag_live_request_internal']);
select 'visitor can call: ' || proname || '(' || args || ')' from e_funcs where not is_trigger and has_function_privilege('anon', oid, 'execute');
select t_ok(not exists (select 1 from e_funcs where not is_trigger and has_function_privilege('anon', oid, 'execute')),
  'visitors can call none of the ' || (select count(*) from e_funcs) || ' new account functions');
select 'user can call internal: ' || proname from e_funcs
where proname in ('anonymise_account','process_account_deletions','is_minor','needs_parent','blocked_between','contact_recent_text',
                  'contact_split_hits','flag_contact_hits','flag_live_request_internal')
  and has_function_privilege('authenticated', oid, 'execute');
select t_ok(not exists (select 1 from e_funcs
                        where proname in ('anonymise_account','process_account_deletions','is_minor','needs_parent','blocked_between',
                                          'contact_recent_text','contact_split_hits','flag_contact_hits','flag_live_request_internal')
                          and has_function_privilege('authenticated', oid, 'execute')),
  'signed-in users cannot call the internal helpers (ages, parent links, blocks, deletion, flags)');
select t_as(:'stu'); set role authenticated;
select t_err(format($$select hold_tutor_change(%L, '{"headline":"x"}')$$, :'tut'), 'Not allowed', 'nobody can hold changes for another tutor');
reset role;

\echo '--- Round E: a blocked account'
update profiles set status = 'blocked' where id in (:'stu2', :'tut2');
select t_as(:'stu2'); set role authenticated;
select t_ok(my_children() is null, 'a blocked parent sees no children');
select t_err(format($$select child_activity(%L)$$, :'kidp'), 'Not allowed', 'a blocked parent cannot read a child''s lessons');
select t_err($$select save_child_profile(null, 'X')$$, 'Only a parent', 'a blocked parent cannot add children');
select t_err($$select link_child_account('ABCDEFGH')$$, 'Only a parent', 'a blocked parent cannot link a child');
select t_err($$select request_account_deletion()$$, 'Not allowed', 'a blocked account cannot ask for deletion (the admin handles it)');
select t_err(format($$select log_lesson_attendance(%L, 'join')$$, :'kl'), 'Not allowed', 'a blocked account writes no attendance');
reset role;
select t_as(:'tut2'); set role authenticated;
select t_err($$select add_tutor_document('id', 'tutor-docs/' || auth.uid() || '/x.jpg')$$, 'Tutors only', 'a blocked tutor cannot add documents');
select t_err($$select submit_tutor_application(true)$$, 'Tutors only', 'a blocked tutor cannot send an application');
select t_ok((select count(*) from tutor_documents) = 2, '… but still sees his own documents');
reset role;
update profiles set status = 'active' where id in (:'stu2', :'tut2');
