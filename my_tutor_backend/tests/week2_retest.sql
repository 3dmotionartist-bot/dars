-- Tests for the reviewer's week 2 retest findings. Runs after week2.sql.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set admin    '00000000-0000-0000-0000-0000000000a1'
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set stu2     '00000000-0000-0000-0000-0000000000b2'
\set tut      '00000000-0000-0000-0000-0000000000c1'
\set e1       '00000000-0000-0000-0000-0000000000e1'
\set e2       '00000000-0000-0000-0000-0000000000e2'

select id as conv from conversations where student_id = :'stu' and tutor_id = :'tut' \gset
-- four free working-hour slots far ahead (10:00 local on days that are not Saturday)
select ((d::date + time '07:00') at time zone 'UTC') as s1 from generate_series(current_date + 40, current_date + 60, interval '1 day') d where extract(dow from d) <> 6 limit 1 offset 0 \gset
select ((d::date + time '07:00') at time zone 'UTC') as s2 from generate_series(current_date + 40, current_date + 60, interval '1 day') d where extract(dow from d) <> 6 limit 1 offset 1 \gset
select ((d::date + time '07:00') at time zone 'UTC') as s3 from generate_series(current_date + 40, current_date + 60, interval '1 day') d where extract(dow from d) <> 6 limit 1 offset 2 \gset
select ((d::date + time '07:00') at time zone 'UTC') as s4 from generate_series(current_date + 40, current_date + 60, interval '1 day') d where extract(dow from d) <> 6 limit 1 offset 3 \gset

\echo '--- 1. unpaid bookings'
select t_as(:'admin'); set role authenticated;
select admin_wallet_adjust(:'e1', 5, 'test credit');
reset role;
select t_as(:'e1'); set role authenticated;
select book_lesson(:'tut', :'s1'::timestamptz, 60, 'math') as b1 \gset
select book_lesson(:'tut', :'s2'::timestamptz, 60, 'math', p_use_wallet => false) as b2 \gset
select t_ok((:'b1'::jsonb ->> 'wallet_used')::numeric = 5 and (:'b1'::jsonb ->> 'status') = 'pending_payment', 'first unpaid booking (5 paid from credit) is accepted');
select t_err(format('select book_lesson(%L, %L::timestamptz, 60, %L, p_use_wallet => false)', :'tut', :'s3', 'math'), 'waiting for payment', 'a 3rd unpaid booking is refused');
select t_err(format('select buy_package(%L, 4, p_use_wallet => false)', :'tut'), 'waiting for payment', 'an unpaid package is refused too');
select (:'b2'::jsonb ->> 'payment_id') as b2pay, (:'b2'::jsonb ->> 'lesson_id') as b2lesson, (:'b1'::jsonb ->> 'lesson_id') as b1lesson \gset
select gen_random_uuid() as rc1 \gset
insert into storage.objects (bucket_id, name) values ('receipts', auth.uid() || '/' || :'rc1' || '.jpg');
select submit_bank_receipt(:'b2pay', 'receipts/' || auth.uid() || '/' || :'rc1' || '.jpg', 'sham_cash');
reset role;
select coalesce((select balance from wallet_balances where user_id = :'e1'), 0) as e1bal \gset
update lessons set created_at = now() - interval '7 hours' where id in (:'b1lesson', :'b2lesson');
select expire_pending_payments();
select t_ok((select status from lessons where id = :'b1lesson') = 'cancelled', 'a booking with no receipt is released after the 6-hour hold');
select t_ok((select balance from wallet_balances where user_id = :'e1') = :'e1bal'::numeric + 5, 'its wallet part is refunded');
select t_ok((select status from lessons where id = :'b2lesson') = 'pending_payment', 'a booking with a receipt under review is not released');
select t_as(:'e2'); set role authenticated;
select book_lesson(:'tut', :'s1'::timestamptz, 60, 'math', p_use_wallet => false) as e2b \gset
reset role;
select t_ok((:'e2b'::jsonb ->> 'status') = 'pending_payment', 'the released time can be booked by someone else');
select t_as(:'e1'); set role authenticated;
select book_lesson(:'tut', :'s3'::timestamptz, 60, 'math', p_use_wallet => false) as b3 \gset
reset role;
select t_ok((:'b3'::jsonb ->> 'lesson_id') is not null, 'after one is released the student can book again');
-- receipt waiting more than 72 h: still held, admins reminded once
update payments set receipt_at = now() - interval '73 hours', created_at = now() - interval '5 days' where id = :'b2pay';
update lessons set created_at = now() - interval '5 days' where id = :'b2lesson';
select expire_pending_payments();
select expire_pending_payments();
select t_ok((select status from lessons where id = :'b2lesson') = 'pending_payment', 'a receipt under review for 5 days still does not cancel the booking');
select t_ok((select count(*) from notifications where user_id = :'admin' and title = 'Receipt waiting too long' and data ->> 'payment_id' = :'b2pay') = 1,
            'admins are reminded about it once');
select t_ok((select review_alerted_at from payments where id = :'b2pay') is not null, 'the dashboard can see it was flagged');

\echo '--- 4. rejected after the window: a fresh window'
select t_as(:'admin'); set role authenticated;
select fail_payment(:'b2pay', p_reason => 'Reference not found');
reset role;
select expire_pending_payments();
select t_ok((select status from lessons where id = :'b2lesson') = 'pending_payment', 'rejected at day 5: not cancelled by the next clean-up');
select t_ok((select count(*) from notifications where user_id = :'e1' and title = 'Receipt not accepted' and body like '%6 hours%') = 1, 'the student is told how long they have');

\echo '--- 2. receipt files cannot be replaced'
select t_as(:'e1'); set role authenticated;
select t_err(format('insert into storage.objects (bucket_id, name) values (%L, %L)', 'receipts', auth.uid() || '/' || :'rc1' || '.jpg'),
             'duplicate key', 'a second upload to the same receipt path is refused');
update storage.objects set name = auth.uid() || '/other.jpg' where bucket_id = 'receipts';
delete from storage.objects where bucket_id = 'receipts';
reset role;
select t_ok((select count(*) from storage.objects where bucket_id = 'receipts' and name = :'e1' || '/' || :'rc1' || '.jpg') = 1,
            'the student cannot rename or delete an uploaded receipt');
select t_as(:'e1'); set role authenticated;
select gen_random_uuid() as rc2 \gset
insert into storage.objects (bucket_id, name) values ('receipts', auth.uid() || '/' || :'rc2' || '.jpg');
select submit_bank_receipt(:'b2pay', 'receipts/' || auth.uid() || '/' || :'rc2' || '.jpg');
insert into storage.objects (bucket_id, name) values ('avatars', auth.uid() || '/me.jpg');
update storage.objects set name = auth.uid() || '/me2.jpg' where bucket_id = 'avatars' and name = auth.uid() || '/me.jpg';
reset role;
select t_ok((select status from payments where id = :'b2pay') = 'under_review', 're-upload after a rejection works (new file name)');
select t_ok((select count(*) from storage.objects where bucket_id = 'avatars' and name = :'e1' || '/me2.jpg') = 1, 'other buckets still allow replacing your own files');
-- rejected again, then no receipt within the fresh window → released
select t_as(:'admin'); set role authenticated;
select fail_payment(:'b2pay', p_reason => 'Wrong amount');
reset role;
update payments set rejected_at = now() - interval '7 hours' where id = :'b2pay';
select expire_pending_payments();
select t_ok((select status from lessons where id = :'b2lesson') = 'cancelled', 'no new receipt within the fresh window → the booking is released');

\echo '--- 3. no duplicate messages on retry'
select t_as(:'stu'); set role authenticated;
insert into messages (conversation_id, sender_id, body, client_id) values (:'conv', auth.uid(), 'sent once', '11111111-2222-4333-8444-555555555555');
select t_err(format('insert into messages (conversation_id, sender_id, body, client_id) values (%L, auth.uid(), %L, %L)', :'conv', 'sent once', '11111111-2222-4333-8444-555555555555'),
             'duplicate key', 'the same message id sent twice is refused');
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'old app');
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'old app');
select t_ok((select count(*) from messages where body = 'sent once') = 1, 'one row for the retried message');
select t_ok((select count(*) from messages where body = 'old app') = 2, 'messages without an id (older apps) are still accepted');
select t_ok((select client_id from recent_messages(array[:'conv'::uuid], 50) where body = 'sent once') = '11111111-2222-4333-8444-555555555555',
            'the app can find the message by its id');
reset role;
select t_as(:'tut'); set role authenticated;
insert into messages (conversation_id, sender_id, body, client_id) values (:'conv', auth.uid(), 'same id, other sender', '11111111-2222-4333-8444-555555555555');
reset role;
select t_ok((select count(*) from messages where body = 'same id, other sender') = 1, 'the rule is per sender');

\echo '--- 5. confirm a top-up with the amount that arrived'
select t_as(:'e1'); set role authenticated;
select (request_top_up(50, 'sham_cash') ->> 'payment_id') as tp \gset
select gen_random_uuid() as rc3 \gset
select submit_bank_receipt(:'tp', 'receipts/' || auth.uid() || '/' || :'rc3' || '.jpg');
reset role;
select t_as(:'stu2'); set role authenticated;
select t_err(format('select confirm_payment(%L, p_amount => 40)', :'tp'), 'Not allowed', 'a non-admin cannot confirm (with or without an amount)');
reset role;
select coalesce((select balance from wallet_balances where user_id = :'e1'), 0) as e1b2 \gset
select t_as(:'admin'); set role authenticated;
select t_err(format('select confirm_payment(%L, p_amount => 5000)', :'tp'), 'between', 'the amount must stay within the top-up limits');
select confirm_payment(:'tp', p_amount => 40);
select confirm_payment(:'tp', p_amount => 60);
reset role;
select t_ok((select balance from wallet_balances where user_id = :'e1') = :'e1b2'::numeric + 40, 'the confirmed amount is what gets credited');
select t_ok((select count(*) from wallet_transactions where payment_id = :'tp') = 1, 'credited once');
select t_ok((select amount from payments where id = :'tp') = 40 and (select requested_amount from payments where id = :'tp') = 50, 'both amounts are kept');
select t_ok((select count(*) from audit_log where action = 'confirm_payment' and target = :'tp' and (data ->> 'requested')::numeric = 50 and (data ->> 'confirmed')::numeric = 40) = 1, 'and written to the audit log');
select t_ok((select count(*) from notifications where user_id = :'e1' and title = 'Credit added' and body like '40%you asked for 50%') = 1, 'the student is told the real amount');
select (:'e2b'::jsonb ->> 'payment_id') as e2pay, (:'e2b'::jsonb ->> 'amount_due') as e2due \gset
select t_as(:'admin'); set role authenticated;
select confirm_payment(:'e2pay', p_amount => 1);
reset role;
select t_ok((select amount from payments where id = :'e2pay') = :'e2due'::numeric and (select status from payments where id = :'e2pay') = 'paid', 'bookings ignore p_amount');

\echo '--- 7. accepting a live-help request twice'
select t_as(:'stu2'); set role authenticated;
select create_live_request('math', 'high', 'Please help me with derivatives') as lq \gset
reset role;
select t_as(:'tut'); set role authenticated;
select respond_live_request(:'lq', true, 'Hi, I can help') as lc \gset
reset role;
select count(*) as m1 from messages where conversation_id = :'lc' \gset
select t_as(:'tut'); set role authenticated;
select respond_live_request(:'lq', true, 'Hi again') as lc2 \gset
reset role;
select t_ok(:'lc2' = :'lc', 'accepting again opens the same chat');
select t_ok((select count(*) from messages where conversation_id = :'lc') = :'m1'::int, 'and does not post the question or the greeting again');

\echo 'WEEK 2 RETEST: ALL PASSED'
