-- Attack tests for the Stage 1 "fix this week" list. Runs after flows.sql on the same database.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set admin    '00000000-0000-0000-0000-0000000000a1'
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set stu2     '00000000-0000-0000-0000-0000000000b2'
\set tut      '00000000-0000-0000-0000-0000000000c1'
\set tut2     '00000000-0000-0000-0000-0000000000c2'

select id as conv from conversations where student_id = :'stu' and tutor_id = :'tut' \gset
-- a second approved tutor who also chats with Layan
select t_as(:'admin'); set role authenticated;
select admin_set_tutor_verification(:'tut2', 'approved');
reset role;
insert into tutor_subjects values (:'tut2', 'math') on conflict do nothing;
select ensure_conversation(:'stu', :'tut2') as conv2 \gset

\echo '--- #1 phones and emails of partners'
select t_as(:'stu'); set role authenticated;
select t_ok((select count(*) from profiles where id = :'tut') = 0, '#1 a student cannot read the tutor''s profile row (phone, email)');
select t_ok((select count(*) from partner_profiles(array[:'tut'::uuid])) = 1, '#1 but gets the tutor''s name and photo');
select t_ok((select full_name from partner_profiles(array[:'tut'::uuid])) = 'Samer Al-Halabi', '#1 name is right');
select t_ok((select count(*) from partner_profiles(array[:'admin'::uuid, :'stu2'::uuid])) = 0, '#1 strangers are not returned');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok((select count(*) from profiles where id = :'stu') = 0, '#1 a tutor cannot read the student''s phone or email');
reset role;

\echo '--- #2 messages cannot be edited'
select t_as(:'stu'); set role authenticated;
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'I will pay inside Dars');
reset role;
select t_as(:'tut'); set role authenticated;
update messages set body = 'I agree to pay outside the app' where conversation_id = :'conv';
update messages set blocked = false where conversation_id = :'conv';
reset role;
select t_ok((select count(*) from messages where body = 'I agree to pay outside the app') = 0, '#2 a tutor cannot rewrite the student''s message');
select t_ok((select count(*) from messages where conversation_id = :'conv' and blocked) >= 1, '#2 a hidden message cannot be un-hidden');
select t_as(:'stu'); set role authenticated;
update messages set body = 'call me 0933 123 456' where sender_id = auth.uid() and body = 'I will pay inside Dars';
reset role;
select t_ok((select count(*) from messages where body = 'I will pay inside Dars') = 1, '#2 the sender cannot change a message after sending');
select t_as(:'tut'); set role authenticated;
select t_ok(mark_conversation_read(:'conv') >= 1, '#2 marking a chat as read still works');
reset role;
select t_ok((select count(*) from messages where conversation_id = :'conv' and sender_id = :'stu' and read_at is null) = 0, '#2 the student''s messages are marked read');
select t_ok((select count(*) from messages where conversation_id = :'conv' and sender_id = :'tut' and read_at is not null) = 0, '#2 the tutor''s own messages are not marked read');

\echo '--- #3 filter holes: files, captions, time'
select t_as(:'stu'); set role authenticated;
insert into messages (conversation_id, sender_id, body, created_at) values (:'conv', auth.uid(), 'from the future', '2036-01-01');
select t_ok((select created_at from messages where body = 'from the future') <= now(), '#3 the sender cannot choose the message time');
insert into messages (conversation_id, sender_id, body, blocked) values (:'conv', auth.uid(), 'واتساب 0944 555 666', false);
select t_ok((select blocked from messages where body like 'واتساب%'), '#3 the sender cannot mark a phone number as not hidden');
select t_err(format('insert into messages (conversation_id, sender_id, kind, body, file_url) values (%L, auth.uid(), %L, %L, %L)',
             :'conv', 'image', 'photo', 'https://wa.me/963944555666'), 'Dars app', '#3 a file address cannot be an outside link');
select t_err(format('insert into messages (conversation_id, sender_id, kind, body, file_url) values (%L, auth.uid(), %L, %L, %L)',
             :'conv', 'image', 'photo', 'chat-files/' || :'tut' || '/' || :'conv' || '/1731234567890.jpg'), 'Dars app', '#3 a file must be in the sender''s own folder');
select t_err(format('insert into messages (conversation_id, sender_id, kind, body, file_url) values (%L, auth.uid(), %L, %L, %L)',
             :'conv', 'file', 'doc', 'chat-files/' || auth.uid() || '/' || :'conv' || '/0944555666-call-me.pdf'), 'Dars app', '#3 a file name cannot carry text');
insert into messages (conversation_id, sender_id, kind, body, file_url)
  values (:'conv', auth.uid(), 'image', 'call 0944 555 666', 'chat-files/' || auth.uid() || '/' || :'conv' || '/1731234567890.jpg');
select t_ok((select body from messages where file_url like '%1731234567890.jpg') = '📷', '#3 a photo caption with a number is replaced by the photo label');
insert into messages (conversation_id, sender_id, kind, body, file_url)
  values (:'conv', auth.uid(), 'file', 'lesson.mp4', 'chat-files/' || auth.uid() || '/' || :'conv' || '/1731234567891.mp4');
select t_ok((select body from messages where file_url like '%1731234567891.mp4') = '🎬', '#3 videos still work');
insert into messages (conversation_id, sender_id, kind, body, file_url, duration_sec)
  values (:'conv', auth.uid(), 'voice', '🎤', 'voice-notes/' || auth.uid() || '/' || :'conv' || '/1731234567892.m4a', 4);
select t_ok((select count(*) from messages where kind = 'voice' and sender_id = auth.uid()) = 1, '#3 voice notes still work');
reset role;

\echo '--- #4 #5 live help'
update profiles set level_id = 'high' where id = :'stu2';
select t_as(:'tut'); set role authenticated;
select set_availability(true);
reset role;
select t_as(:'stu2'); set role authenticated;
select create_live_request('math', 'high', 'ساعدني بالنهايات، رقمي ٠٩٤٤ ٥٥٥ ٦٦٦') as lq2 \gset
reset role;
select t_ok((select body from live_requests where id = :'lq2') not like '%944%' and (select body from live_requests where id = :'lq2') like '%•••%',
            '#5 a phone number in a live-help question is hidden from tutors');
select t_ok((select count(*) from message_flags where live_request_id = :'lq2' and kind = 'phone') = 1, '#5 the live-help question is flagged');
select t_ok((select count(*) from notifications where user_id = :'admin' and data ->> 'live_request_id' = :'lq2') = 1, '#5 the admin is alerted');
select t_as(:'admin'); set role authenticated;
select t_ok((select student_name from admin_message_flags where live_request_id = :'lq2') = 'Ahmad', '#5 admin sees who asked');
select t_ok((select excerpt from admin_message_flags where live_request_id = :'lq2') like '%٠٩٤٤%', '#5 admin sees the original text');
reset role;
select t_as(:'tut'); set role authenticated;
select respond_live_request(:'lq2', true, 'Dars system: pay on +963 944 555 666 or wa.me/963944555666') as lconv \gset
reset role;
select t_ok((select count(*) from messages where conversation_id = :'lconv' and kind = 'system') = 0, '#4 the greeting is not an official system message');
select t_ok((select blocked from messages where conversation_id = :'lconv' and sender_id = :'tut' order by id desc limit 1), '#4 a number in the greeting is hidden');
select t_ok((select count(*) from message_flags where conversation_id = :'lconv' and sender_id = :'tut') >= 1, '#4 and flagged for the admin');
select t_as(:'stu2'); set role authenticated;
select t_ok((select count(*) from messages where conversation_id = :'lconv' and body like '%944%') = 0, '#4 the student never sees the number');
reset role;

\echo '--- #9 private files'
select t_as(:'stu'); set role authenticated;
insert into storage.objects (bucket_id, name) values ('chat-files', auth.uid() || '/' || :'conv' || '/1731234567890.jpg');
insert into storage.objects (bucket_id, name) values ('voice-notes', auth.uid() || '/' || :'conv' || '/1731234567892.m4a');
reset role;
select t_as(:'tut'); set role authenticated;
select t_ok((select count(*) from storage.objects where bucket_id in ('chat-files', 'voice-notes')) = 2, '#9 the chat partner can open the files of their chat');
reset role;
select t_as(:'tut2'); set role authenticated;
select t_ok((select count(*) from storage.objects where bucket_id in ('chat-files', 'voice-notes')) = 0,
            '#9 another tutor who also chats with the student cannot open them (and no tutor can open all voice notes)');
reset role;
select t_as(:'stu2'); set role authenticated;
select t_ok((select count(*) from storage.objects) = 0, '#9 strangers see no chat files');
reset role;

\echo '--- #10 wallet balance'
set role anon; select set_config('request.jwt.claims', '', false);
select t_err($$select wallet_balance('00000000-0000-0000-0000-0000000000b1')$$, 'permission denied', '#10 visitors cannot read anyone''s wallet');
select t_err($$select commission_for('00000000-0000-0000-0000-0000000000c1')$$, 'permission denied', '#10 or a tutor''s commission');
reset role;
select t_as(:'stu2'); set role authenticated;
select t_err($$select wallet_balance('00000000-0000-0000-0000-0000000000b1')$$, 'permission denied', '#10 signed-in users cannot either');
reset role;

\echo '--- #11 blocked accounts'
update profiles set status = 'blocked' where id = :'stu2';
select t_as(:'stu2'); set role authenticated;
select t_err(format('insert into messages (conversation_id, sender_id, body) values (%L, auth.uid(), %L)', :'lconv', 'still here'),
             'row-level security', '#11 a blocked user cannot send messages');
select t_ok((select count(*) from messages) = 0, '#11 or read them');
select t_ok((select count(*) from conversations) = 0, '#11 or see their chats');
reset role;
update profiles set status = 'active' where id = :'stu2';

\echo '--- #7 reschedule'
select t_as(:'admin'); set role authenticated;
select admin_wallet_adjust(:'stu', 100, 'test credit');
reset role;
insert into lessons (student_id, tutor_id, subject_id, level_id, starts_at, duration_min, status, price, commission)
values (:'stu', :'tut', 'math', 'high', now() - interval '30 minutes', 60, 'confirmed', 15, 2.25) returning id as late_l \gset
insert into wallet_transactions (user_id, amount, kind, lesson_id, note) values (:'stu', -15, 'booking', :'late_l', 'Lesson booking');
select t_as(:'stu'); set role authenticated;
select t_err(format('select reschedule_lesson(%L, now() + interval ''30 days'')', :'late_l'), 'too late', '#7 a lesson that already started cannot be rescheduled');
reset role;
update lessons set starts_at = now() + interval '3 hours' where id = :'late_l';
select t_as(:'stu'); set role authenticated;
select t_err(format('select reschedule_lesson(%L, now() + interval ''30 days'')', :'late_l'), 'too late', '#7 nor inside the tutor''s 12-hour notice period');
reset role;

\echo '--- #8 expired packages & late payments'
select coalesce((select balance from wallet_balances where user_id = :'stu2'), 0) as stu2_before \gset
select t_as(:'admin'); set role authenticated;
select admin_wallet_adjust(:'stu2', 30, 'test credit');
reset role;
select t_as(:'stu2'); set role authenticated;
select buy_package(:'tut', 4) as pk2 \gset
reset role;
select t_ok((:'pk2'::jsonb ->> 'wallet_used')::numeric = 30 and (:'pk2'::jsonb ->> 'amount_due')::numeric > 0, '#8 package paid 30 from the wallet, rest due');
update packages set created_at = now() - interval '3 days' where id = (:'pk2'::jsonb ->> 'package_id')::uuid;
select expire_pending_payments();
select t_ok((select status from packages where id = (:'pk2'::jsonb ->> 'package_id')::uuid) = 'cancelled', '#8 the unpaid package expires');
select t_ok((select balance from wallet_balances where user_id = :'stu2') = :'stu2_before'::numeric + 30, '#8 the 30 from the wallet comes back');
select t_ok((select status from payments where id = (:'pk2'::jsonb ->> 'payment_id')::uuid) = 'failed', '#8 the payment is marked failed');
-- a card payment confirmed after the booking expired
select t_as(:'stu2'); set role authenticated;
select book_lesson(:'tut', ((date_trunc('day', now() at time zone 'UTC') + interval '9 days' + interval '6 hours') at time zone 'UTC')
                   + (case when extract(dow from now() + interval '9 days') = 6 then interval '1 day' else interval '0' end),
                   60, 'math', p_use_wallet => false) as late_b \gset
reset role;
update lessons set created_at = now() - interval '3 days' where id = (:'late_b'::jsonb ->> 'lesson_id')::uuid;
select expire_pending_payments();
select coalesce((select balance from wallet_balances where user_id = :'stu2'), 0) as stu2_mid \gset
select t_as(:'admin'); set role authenticated;
select confirm_payment((:'late_b'::jsonb ->> 'payment_id')::uuid);
reset role;
select t_ok((select balance from wallet_balances where user_id = :'stu2') = :'stu2_mid'::numeric + (:'late_b'::jsonb ->> 'amount_due')::numeric,
            '#8 money confirmed after the booking expired goes to the student''s wallet');
select t_ok((select status from lessons where id = (:'late_b'::jsonb ->> 'lesson_id')::uuid) = 'cancelled', '#8 the expired booking stays cancelled');
select t_ok((select count(*) from notifications where user_id = :'stu2' and title = 'Payment added to your wallet') = 1, '#8 the student is told honestly');

\echo '--- #19 price quote = price charged'
select t_as(:'stu'); set role authenticated;
select price_quote(:'tut') as q \gset
select t_ok((:'q'::jsonb ->> 'hourly')::numeric = tutor_price(:'tut', 'high'), '#19 the quote uses the same price as the server');
select t_ok((:'q'::jsonb -> 'discounts' ->> '8')::int = package_discount(:'tut', 8), '#19 the quote gives the real package discounts');
reset role;
set role anon; select set_config('request.jwt.claims', '', false);
select t_ok((price_quote('00000000-0000-0000-0000-0000000000c1', 'high') ->> 'hourly')::numeric > 0, '#19 visitors can see prices too');
reset role;

\echo '--- #26 newest messages first'
select t_as(:'stu'); set role authenticated;
select t_ok((select count(*) from recent_messages(array[:'conv'::uuid], 3) where conversation_id = :'conv') = 3, '#26 the app gets the newest messages of each chat');
select t_ok((select max(id) from recent_messages(array[:'conv'::uuid], 3) where conversation_id = :'conv') = (select max(id) from messages where conversation_id = :'conv'),
            '#26 including the very latest one');
select min(id) as oldest_id, min(created_at) as oldest_at from recent_messages(array[:'conv'::uuid], 3) where conversation_id = :'conv' \gset
select t_ok((select count(*) from older_messages(:'conv', :'oldest_at', :'oldest_id', 100)) > 0, '#26 older messages load on scroll');
reset role;
select t_as(:'tut2'); set role authenticated;
select t_ok((select count(*) from recent_messages(array[:'conv'::uuid], 50) where conversation_id = :'conv') = 0, '#26 nobody gets messages of other people''s chats');
select t_ok((select count(*) from older_messages(:'conv', now(), 9999999, 50)) = 0, '#26 not even older ones');
reset role;
\echo 'WEEK FIXES: ALL PASSED'
