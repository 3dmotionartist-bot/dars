-- Tests for week 2: wallet top-up with receipt, booking by transfer, payout details,
-- read ticks, sign-up safety, file limits, update switch. Runs after retest_fixes.sql.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set admin    '00000000-0000-0000-0000-0000000000a1'
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set stu2     '00000000-0000-0000-0000-0000000000b2'
\set tut      '00000000-0000-0000-0000-0000000000c1'
\set tut2     '00000000-0000-0000-0000-0000000000c2'

select id as conv from conversations where student_id = :'stu' and tutor_id = :'tut' \gset

\echo '--- settings: pay-to accounts'
select t_as(:'admin'); set role authenticated;
select admin_set_setting('pay_to_sham_cash', '"0944 000 111"');
select admin_set_setting('pay_to_bank', '"SY12 3456 7890"');
reset role;
set role anon; select set_config('request.jwt.claims', '', false);
select t_ok((select count(*) from app_settings where key like 'pay\_to\_%') = 0, 'visitors cannot read the pay-to accounts');
select t_ok((select count(*) from app_settings where key = 'min_app_build') = 1, 'visitors can read min_app_build');
select t_ok((select count(*) from app_settings where key like 'turn\_%') = 0, 'visitors cannot read relay passwords');
select t_err($$select request_top_up(20, 'sham_cash')$$, 'permission denied', 'visitors cannot start a top-up');
reset role;
select t_as(:'stu'); set role authenticated;
select t_ok((select value #>> '{}' from app_settings where key = 'pay_to_sham_cash') = '0944 000 111', 'signed-in users can read the pay-to accounts');
select t_ok((select count(*) from app_settings where key like 'turn\_%') = 0, 'signed-in users still cannot read relay passwords');

\echo '--- Task 1: top-up'
select t_err($$select request_top_up(20, 'mtn_cash')$$, 'not available', 'a method with no account is refused');
select t_err($$select request_top_up(20, 'card')$$, 'not available', 'card is not a top-up method');
select t_err($$select request_top_up(1, 'sham_cash')$$, 'between', 'amount below the minimum is refused');
select t_err($$select request_top_up(5000, 'sham_cash')$$, 'between', 'amount above the maximum is refused');
select t_err($$select request_top_up(10.555, 'sham_cash')$$, 'between', 'amount with more than 2 decimals is refused');
select request_top_up(20, 'sham_cash') as tu \gset
select (:'tu'::jsonb ->> 'payment_id') as tu_id, (:'tu'::jsonb ->> 'reference') as tu_ref \gset
select t_ok(:'tu_ref' ~ '^D-[A-Z2-9]{6}$', 'a top-up gets a short reference');
select t_ok(:'tu'::jsonb ->> 'pay_to' = '0944 000 111', 'a top-up returns the account to pay to');
select t_ok((select status from payments where id = :'tu_id') = 'pending', 'the top-up waits for a receipt');
-- students cannot write payments directly
select t_err(format('insert into payments (user_id, amount, method, purpose, status) values (auth.uid(), 999, %L, %L, %L)', 'sham_cash', 'top_up', 'paid'),
             'row-level security', 'a student cannot create a paid payment directly');
update payments set status = 'paid' where id = :'tu_id';
select t_ok((select status from payments where id = :'tu_id') = 'pending', 'a student cannot mark a payment paid');
-- receipt
select t_err(format('select submit_bank_receipt(%L, %L)', :'tu_id', 'receipts/' || :'stu2' || '/' || :'tu_id' || '.jpg'),
             'from the Dars app', 'a receipt in another user''s folder is refused');
select t_err(format('select submit_bank_receipt(%L, %L)', :'tu_id', 'receipts/' || auth.uid() || '/call-me-0944555666.jpg'),
             'from the Dars app', 'a receipt file name cannot carry text');
select t_err(format('select submit_bank_receipt(%L, %L)', :'tu_id', 'https://example.com/r.jpg'),
             'from the Dars app', 'a receipt cannot be an outside link');
select submit_bank_receipt(:'tu_id', 'receipts/' || auth.uid() || '/' || :'tu_id' || '.jpg');
select t_ok((select status from payments where id = :'tu_id') = 'under_review', 'the receipt puts the top-up under review');
select t_err(format('select submit_bank_receipt(%L, %L)', :'tu_id', 'receipts/' || auth.uid() || '/' || :'tu_id' || '.png'),
             'not waiting', 'a second receipt for the same payment is refused');
select t_err(format('select confirm_payment(%L)', :'tu_id'), 'Not allowed', 'a student cannot confirm their own top-up');
reset role;
select t_ok((select count(*) from notifications where user_id = :'admin' and title = 'Receipt to check' and data ->> 'payment_id' = :'tu_id') = 1,
            'admins are told about the receipt');
select t_as(:'stu2'); set role authenticated;
select t_err(format('select transfer_instructions(%L, %L)', :'tu_id', 'sham_cash'), 'not found', 'another user cannot see my payment');
select t_err(format('select confirm_payment(%L)', :'tu_id'), 'Not allowed', 'another user cannot confirm it');
reset role;
select coalesce((select balance from wallet_balances where user_id = :'stu'), 0) as bal0 \gset
select t_as(:'admin'); set role authenticated;
select confirm_payment(:'tu_id');
select confirm_payment(:'tu_id');
reset role;
select t_ok((select balance from wallet_balances where user_id = :'stu') = :'bal0'::numeric + 20, 'confirming credits exactly the top-up amount');
select t_ok((select count(*) from wallet_transactions where payment_id = :'tu_id' and kind = 'top_up') = 1, 'confirming twice credits once');
select t_ok((select count(*) from notifications where user_id = :'stu' and title = 'Credit added') = 1, 'the student is told the credit was added');
select t_err(format('insert into wallet_transactions (user_id, amount, kind, payment_id) values (%L, 20, %L, %L)', :'stu', 'top_up', :'tu_id'),
             'duplicate key', 'the database itself refuses a second credit for the same top-up');

\echo '--- Task 1: limits, rejection, expiry'
select t_as(:'stu'); set role authenticated;
select (request_top_up(10, 'sham_cash') ->> 'payment_id') as t1 \gset
select (request_top_up(15, 'bank_transfer') ->> 'payment_id') as t2 \gset
select (request_top_up(25, 'sham_cash') ->> 'payment_id') as t3 \gset
select t_err($$select request_top_up(30, 'sham_cash')$$, '3 top-ups', 'a fourth open top-up is refused');
select t_ok((select count(distinct reference) from payments where id in (:'t1', :'t2', :'t3')) = 3, 'every top-up gets its own reference');
select submit_bank_receipt(:'t1', 'receipts/' || auth.uid() || '/' || :'t1' || '.jpg');
select submit_bank_receipt(:'t2', 'receipts/' || auth.uid() || '/' || :'t2' || '.pdf');
reset role;
select t_as(:'admin'); set role authenticated;
select fail_payment(:'t1', p_reason => 'No transfer with this reference arrived');
select t_err(format('select fail_payment(%L)', :'tu_id'), 'already paid', 'a paid top-up cannot be rejected');
reset role;
select t_ok((select status from payments where id = :'t1') = 'failed', 'a rejected top-up is closed');
select t_ok((select fail_reason from payments where id = :'t1') = 'No transfer with this reference arrived', 'the admin''s reason is kept for the student');
select t_ok((select count(*) from wallet_transactions where payment_id = :'t1') = 0, 'a rejected top-up credits nothing');
select t_ok((select count(*) from notifications where user_id = :'stu' and title = 'Top-up not accepted') = 1, 'the student is told why');
update payments set created_at = now() - interval '3 days' where id in (:'t2', :'t3');
select expire_pending_payments();
select t_ok((select status from payments where id = :'t2') = 'under_review', 'a top-up under review is never expired');
select t_ok((select status from payments where id = :'t3') = 'failed', 'a top-up with no receipt expires');
select t_ok((select fail_reason from payments where id = :'t3') like 'No receipt%', 'and says why');
select t_ok((select balance from wallet_balances where user_id = :'stu') = :'bal0'::numeric + 20, 'balance unchanged by rejections and expiry');

\echo '--- Task 1: paying a booking by transfer'
select ((d::date + time '07:00') at time zone 'UTC') as slot
from generate_series(current_date + 12, current_date + 18, interval '1 day') d where extract(dow from d) <> 6 limit 1 \gset
select t_as(:'stu2'); set role authenticated;
select book_lesson(:'tut', :'slot'::timestamptz, 60, 'math', p_use_wallet => false, p_method => 'bank_transfer') as bk \gset
select (:'bk'::jsonb ->> 'payment_id') as bk_pay, (:'bk'::jsonb ->> 'lesson_id') as bk_lesson \gset
select transfer_instructions(:'bk_pay', 'sham_cash') as ti \gset
select t_ok(:'ti'::jsonb ->> 'reference' ~ '^D-' and (:'ti'::jsonb ->> 'amount')::numeric = (:'bk'::jsonb ->> 'amount_due')::numeric,
            'a booking gets the same transfer instructions');
select submit_bank_receipt(:'bk_pay', 'receipts/' || auth.uid() || '/' || :'bk_pay' || '.jpg', 'sham_cash');
reset role;
select t_as(:'admin'); set role authenticated;
select fail_payment(:'bk_pay', p_reason => 'The amount is different');
reset role;
select t_ok((select status from payments where id = :'bk_pay') = 'pending' and (select receipt_url from payments where id = :'bk_pay') is null,
            'a rejected booking receipt goes back to waiting, so a new one can be uploaded');
select t_ok((select status from lessons where id = :'bk_lesson') = 'pending_payment', 'the booking is kept meanwhile');
select t_as(:'stu2'); set role authenticated;
select submit_bank_receipt(:'bk_pay', 'receipts/' || auth.uid() || '/' || :'bk_pay' || '.png');
reset role;
select t_as(:'admin'); set role authenticated;
select confirm_payment(:'bk_pay');
reset role;
select t_ok((select status from lessons where id = :'bk_lesson') = 'confirmed', 'confirming the transfer confirms the lesson');
select t_ok((select method from payments where id = :'bk_pay') = 'sham_cash', 'the payment keeps the method the student used');

\echo '--- Task 2: payout details'
select t_as(:'tut'); set role authenticated;
select t_err($$select request_payout(5, 'sham_cash', '{}')$$, 'holder name', 'a payout without details is refused');
select t_err($$select request_payout(5, 'sham_cash', '{"holder_name":"Samer","account":"  "}')$$, 'holder name', 'an empty account is refused');
select t_err(format('select request_payout(5, %L, %L)', 'sham_cash', jsonb_build_object('holder_name', repeat('x', 121), 'account', '0944')),
             '120 characters', 'details longer than 120 characters are refused');
reset role;
select wallet_balance(:'tut') as tb0 \gset
select count(*) as po0 from payouts where tutor_id = :'tut' \gset
select t_as(:'tut'); set role authenticated;
select request_payout(5, 'sham_cash', '{"holder_name":" Samer Al-Halabi ","account":"0944 222 333"}') as po \gset
reset role;
select t_ok(wallet_balance(:'tut') = :'tb0'::numeric - 5, 'a valid payout reserves the amount');
select t_ok((select count(*) from payouts where tutor_id = :'tut') = :'po0'::int + 1, 'and creates exactly one payout request');
select t_ok((select details ->> 'holder_name' from payouts where id = :'po') = 'Samer Al-Halabi' and (select details ->> 'account' from payouts where id = :'po') = '0944 222 333',
            'the admin gets the holder name and account');
select t_as(:'tut'); set role authenticated;
select request_payout(1, 'bank_transfer', '{"requested_from":"app","name":"Samer","phone":"+963900000003"}') as po_old \gset
reset role;
select t_ok((select details ->> 'account' from payouts where id = :'po_old') = '+963900000003', 'older app versions can still ask for a payout');

\echo '--- Task 3: read ticks'
select t_as(:'stu'); set role authenticated;
insert into messages (conversation_id, sender_id, body) values (:'conv', auth.uid(), 'هل وصلت رسالتي؟');
select max(id) as tick_id from messages where conversation_id = :'conv' and sender_id = auth.uid() \gset
select t_ok((select read_at from recent_messages(array[:'conv'::uuid], 50) where id = :'tick_id') is null, 'a new message is not read yet');
reset role;
select t_as(:'tut'); set role authenticated;
select mark_conversation_read(:'conv');
reset role;
select t_as(:'stu'); set role authenticated;
select t_ok((select read_at from recent_messages(array[:'conv'::uuid], 50) where id = :'tick_id') is not null, 'the sender sees when the other person read it');
reset role;

\echo '--- Task 4.1: sign-up'
insert into auth.users (id, email, phone, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e1', 'e1@test.dars', '',   '{"full_name":"E1","role":"student","phone":"+963900000001"}'),
  ('00000000-0000-0000-0000-0000000000e2', 'e2@test.dars', null, '{"full_name":"E2","role":"superuser","phone":""}'),
  ('00000000-0000-0000-0000-0000000000e3', 'e3@test.dars', null, '{"full_name":"E3","role":"admin"}'),
  ('00000000-0000-0000-0000-0000000000e4', 'e4@test.dars', null, '{"full_name":"E4","role":"tutor"}');
select t_ok((select count(*) from profiles where id::text like '00000000-0000-0000-0000-0000000000e%') = 4, 'sign-ups with an empty phone all succeed');
select t_ok((select phone from profiles where id = '00000000-0000-0000-0000-0000000000e1') is null, 'a phone in the sign-up data is ignored (no stealing someone''s number)');
select t_ok((select role from profiles where id = '00000000-0000-0000-0000-0000000000e2') = 'student', 'an unknown role becomes student');
select t_ok((select role from profiles where id = '00000000-0000-0000-0000-0000000000e3') = 'student', 'nobody signs up as admin');
select t_ok(exists (select 1 from tutor_profiles where user_id = '00000000-0000-0000-0000-0000000000e4'), 'tutors still get a tutor profile');

\echo '--- Task 4.2: file limits'
select t_ok((select file_size_limit from storage.buckets where id = 'avatars') = 2097152, 'profile photos are limited to 2 MB');
select t_ok((select 'audio/*' = any(allowed_mime_types) from storage.buckets where id = 'voice-notes'), 'voice notes accept audio');
select t_ok((select count(*) from storage.buckets where file_size_limit is null) = 0, 'every bucket has a size limit');

\echo 'WEEK 2: ALL PASSED'
