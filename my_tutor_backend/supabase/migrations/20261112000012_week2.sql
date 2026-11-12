-- =====================================================================
-- Dars — week 2: real payments (wallet top-up with a transfer receipt), tutor payout
-- details, sign-up and file-size safety, and the "please update" switch.
-- Safe to run once in the Supabase SQL editor. It adds and replaces rules and
-- functions; it does not delete any user data. Older app versions keep working.
-- =====================================================================

-- ---------- new payment / payout methods (Syrian mobile wallets) ----------
alter type payment_method add value if not exists 'sham_cash';
alter type payment_method add value if not exists 'syriatel_cash';
alter type payment_method add value if not exists 'mtn_cash';
alter type payout_method  add value if not exists 'sham_cash';
alter type payout_method  add value if not exists 'syriatel_cash';
alter type payout_method  add value if not exists 'mtn_cash';

-- ---------- settings ----------
-- Pay-to accounts are left empty: the owner fills them in the admin settings page.
-- A method with an empty account is not offered in the app.
insert into app_settings (key, value) values
  ('top_up_min',            '5'),
  ('top_up_max',            '1000'),
  ('pay_to_sham_cash',      '""'),
  ('pay_to_syriatel_cash',  '""'),
  ('pay_to_mtn_cash',       '""'),
  ('pay_to_bank',           '""'),
  ('min_app_build',         '0')
on conflict (key) do nothing;

-- Visitors may read general settings; pay-to accounts only after signing in; relay passwords never.
drop policy if exists read_all on app_settings;
drop policy if exists read_public on app_settings;
drop policy if exists read_signed_in on app_settings;
create policy read_public on app_settings for select to anon
  using (key not like 'turn\_%' and key not like 'pay\_to\_%');
create policy read_signed_in on app_settings for select to authenticated
  using (key not like 'turn\_%');

-- =====================================================================
-- Task 1 — payments: a payment is either for a booking or a wallet top-up
-- =====================================================================
alter table payments add column if not exists purpose text not null default 'booking';
alter table payments add column if not exists reference text;
alter table payments add column if not exists fail_reason text;
do $$
declare c text;
begin
  -- the old rule "a payment must belong to a lesson or a package" (unnamed check)
  for c in select conname from pg_constraint
           where conrelid = 'payments'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) ilike '%lesson_id IS NOT NULL%package_id IS NOT NULL%'
             and conname <> 'payments_target' loop
    execute format('alter table payments drop constraint %I', c);
  end loop;
  if not exists (select 1 from pg_constraint where conname = 'payments_purpose_check') then
    alter table payments add constraint payments_purpose_check check (purpose in ('booking', 'top_up'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'payments_target') then
    alter table payments add constraint payments_target check (
      (purpose = 'booking' and (lesson_id is not null or package_id is not null))
      or (purpose = 'top_up' and lesson_id is null and package_id is null));
  end if;
end $$;
create unique index if not exists payments_reference_key on payments (reference) where reference is not null;
-- A top-up can credit the wallet only once, whatever happens.
create unique index if not exists wallet_top_up_once on wallet_transactions (payment_id) where kind = 'top_up';

-- The pay-to account for a method ('' when not set).
create or replace function pay_to_account(p_method payment_method) returns text
language sql stable security definer set search_path = public as $$
  select coalesce(nullif(trim(value #>> '{}'), ''), '')
  from app_settings
  where key = 'pay_to_' || case p_method::text when 'bank_transfer' then 'bank' else p_method::text end;
$$;

-- A short reference the student writes in the transfer note, e.g. "D-7KQ2MX".
create or replace function ensure_payment_reference(p_payment uuid) returns text
language plpgsql security definer set search_path = public as $$
declare r text; abc constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; i int;
begin
  select reference into r from payments where id = p_payment;
  if r is not null then return r; end if;
  loop
    r := 'D-';
    for i in 1..6 loop r := r || substr(abc, 1 + floor(random() * length(abc))::int, 1); end loop;
    begin
      update payments set reference = r where id = p_payment and reference is null;
      return coalesce((select reference from payments where id = p_payment), r);
    exception when unique_violation then
      -- extremely rare: try another one
    end;
  end loop;
end $$;

-- Student: start a top-up. Returns where to send the money and the reference to write.
create or replace function request_top_up(p_amount numeric, p_method payment_method)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := me();
  mn numeric := coalesce(setting_num('top_up_min'), 5);
  mx numeric := coalesce(setting_num('top_up_max'), 1000);
  acct text; pay uuid; ref text;
begin
  if p_method::text not in ('sham_cash', 'syriatel_cash', 'mtn_cash', 'bank_transfer') then
    raise exception 'This payment method is not available';
  end if;
  acct := pay_to_account(p_method);
  if acct = '' then raise exception 'This payment method is not available'; end if;
  if p_amount is null or p_amount < mn or p_amount > mx or p_amount <> round(p_amount, 2) then
    raise exception 'The amount must be between % and %', mn, mx;
  end if;
  perform pg_advisory_xact_lock(1, hashtext(u::text));            -- my wallet
  if (select count(*) from payments where user_id = u and purpose = 'top_up' and status in ('pending', 'under_review')) >= 3 then
    raise exception 'You already have 3 top-ups waiting. Finish or wait for those first.';
  end if;
  insert into payments (user_id, amount, method, purpose) values (u, p_amount, p_method, 'top_up') returning id into pay;
  ref := ensure_payment_reference(pay);
  return jsonb_build_object('payment_id', pay, 'reference', ref, 'amount', p_amount, 'method', p_method, 'pay_to', acct);
end $$;

-- Student: pay a waiting booking by transfer. Returns the same instructions as a top-up.
create or replace function transfer_instructions(p_payment uuid, p_method payment_method)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := me(); pay payments%rowtype; acct text;
begin
  if p_method::text not in ('sham_cash', 'syriatel_cash', 'mtn_cash', 'bank_transfer') then
    raise exception 'This payment method is not available';
  end if;
  acct := pay_to_account(p_method);
  if acct = '' then raise exception 'This payment method is not available'; end if;
  select * into pay from payments where id = p_payment and user_id = u for update;
  if pay.id is null then raise exception 'Payment not found'; end if;
  if pay.status <> 'pending' then raise exception 'This payment is not waiting for a transfer'; end if;
  update payments set method = p_method where id = pay.id;
  return jsonb_build_object('payment_id', pay.id, 'reference', ensure_payment_reference(pay.id),
                            'amount', pay.amount, 'method', p_method, 'pay_to', acct);
end $$;

-- Student uploaded the transfer screenshot → the admin checks it in the dashboard.
drop function if exists submit_bank_receipt(uuid, text);
create or replace function submit_bank_receipt(p_payment uuid, p_receipt_url text, p_method payment_method default null)
returns void language plpgsql security definer set search_path = public as $$
declare u uuid := me(); pay payments%rowtype; who text; a uuid;
begin
  if coalesce(p_receipt_url, '') !~ ('^receipts/' || u::text || '/[0-9a-f-]{36}\.(jpg|jpeg|png|webp|pdf)$') then
    raise exception 'Upload the receipt from the Dars app';
  end if;
  if p_method is not null and (p_method::text not in ('sham_cash', 'syriatel_cash', 'mtn_cash', 'bank_transfer') or pay_to_account(p_method) = '') then
    raise exception 'This payment method is not available';
  end if;
  select * into pay from payments where id = p_payment and user_id = u for update;
  if pay.id is null then raise exception 'Payment not found'; end if;
  if pay.status <> 'pending' then raise exception 'This payment is not waiting for a receipt'; end if;
  update payments
     set receipt_url = p_receipt_url, status = 'under_review', fail_reason = null,
         method = coalesce(p_method,
                           case when pay.method::text in ('sham_cash', 'syriatel_cash', 'mtn_cash', 'bank_transfer')
                                then pay.method else 'bank_transfer'::payment_method end)
   where id = pay.id;
  perform ensure_payment_reference(pay.id);
  select coalesce(nullif(full_name, ''), 'A user') into who from profiles where id = u;
  for a in select id from profiles where role = 'admin' and status = 'active' loop
    perform push_notification(a, 'Receipt to check',
      who || ' uploaded a transfer receipt for ' || pay.amount || ' (' || case when pay.purpose = 'top_up' then 'credit top-up' else 'booking' end || ').',
      jsonb_build_object('payment_id', pay.id));
  end loop;
end $$;

-- Admin / payment provider confirms a payment.
create or replace function confirm_payment(p_payment uuid, p_provider text default null, p_ref text default null)
returns void language plpgsql security definer set search_path = public as $$
declare pay payments%rowtype; tutor uuid;
begin
  if not (is_service() or is_admin()) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into pay from payments where id = p_payment for update;
  if pay.id is null then raise exception 'Payment not found'; end if;
  if pay.status in ('paid', 'refunded') then return; end if;          -- idempotent for retries / double clicks
  perform pg_advisory_xact_lock(1, hashtext(pay.user_id::text));
  update payments set status = 'paid', paid_at = now(), fail_reason = null, provider = coalesce(p_provider, provider),
         provider_ref = coalesce(p_ref, provider_ref) where id = pay.id;

  if pay.purpose = 'top_up' then
    insert into wallet_transactions (user_id, amount, kind, payment_id, note)
    values (pay.user_id, pay.amount, 'top_up', pay.id, 'Credit top-up ' || coalesce(pay.reference, ''));
    perform push_notification(pay.user_id, 'Credit added',
      pay.amount || ' was added to your Dars credit. You can book lessons with it now.',
      jsonb_build_object('payment_id', pay.id, 'wallet', true));
    if is_admin() then perform audit('confirm_payment', pay.id::text); end if;
    return;
  end if;

  if pay.lesson_id is not null then
    update lessons set status = 'confirmed' where id = pay.lesson_id and status = 'pending_payment' returning tutor_id into tutor;
  else
    update packages set status = 'active' where id = pay.package_id and status = 'pending_payment' returning tutor_id into tutor;
  end if;

  if tutor is null then
    -- The booking expired or was cancelled before the money arrived: keep the money in the student's wallet.
    insert into wallet_transactions (user_id, amount, kind, payment_id, lesson_id, package_id, note)
    values (pay.user_id, pay.amount, 'refund', pay.id, pay.lesson_id, pay.package_id, 'Payment received after the booking was cancelled');
    update payments set status = 'refunded' where id = pay.id;
    perform push_notification(pay.user_id, 'Payment added to your wallet',
      'Your booking had already expired, so the amount was added to your Dars wallet. You can use it for a new booking.',
      jsonb_build_object('payment_id', pay.id));
  else
    perform ensure_conversation(pay.user_id, tutor);
    perform push_notification(tutor, 'New booking', 'A student completed payment.', jsonb_build_object('payment_id', pay.id));
    perform push_notification(pay.user_id, 'Payment & booking confirmed', 'Your payment was received.', jsonb_build_object('payment_id', pay.id));
  end if;
  if is_admin() then perform audit('confirm_payment', pay.id::text); end if;
end $$;

-- Admin rejects a receipt (with a reason the student sees).
--  * top-up: the top-up is closed as failed; the student can start a new one.
--  * booking: the payment goes back to "waiting for a transfer" so the student can upload a new receipt.
drop function if exists fail_payment(uuid, text);
create or replace function fail_payment(p_payment uuid, p_ref text default null, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare pay payments%rowtype; why text := nullif(left(trim(coalesce(p_reason, '')), 300), '');
begin
  if not (is_service() or is_admin()) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into pay from payments where id = p_payment for update;
  if pay.id is null then raise exception 'Payment not found'; end if;
  if pay.status in ('paid', 'refunded') then raise exception 'This payment is already paid'; end if;
  if pay.purpose = 'booking' and pay.status = 'under_review' and not is_service() then
    update payments set status = 'pending', receipt_url = null, fail_reason = why, provider_ref = coalesce(p_ref, provider_ref) where id = pay.id;
    perform push_notification(pay.user_id, 'Receipt not accepted',
      coalesce(why, 'We could not match your transfer.') || ' You can upload a new receipt from your lessons.',
      jsonb_build_object('payment_id', pay.id));
  else
    update payments set status = 'failed', fail_reason = why, provider_ref = coalesce(p_ref, provider_ref) where id = pay.id;
    if pay.purpose = 'top_up' then
      perform push_notification(pay.user_id, 'Top-up not accepted',
        coalesce(why, 'We could not match your transfer.') || ' Contact support if you sent the money.',
        jsonb_build_object('payment_id', pay.id, 'wallet', true));
    end if;
  end if;
  if is_admin() then perform audit('fail_payment', pay.id::text, jsonb_build_object('reason', why)); end if;
end $$;

-- Expire unpaid bookings, unpaid packages and top-ups without a receipt. Never anything under review.
create or replace function expire_pending_payments() returns int
language plpgsql security definer set search_path = public as $$
declare l record; k record; amt numeric; n int := 0; c int; hrs int := coalesce(setting_num('pending_payment_hours')::int, 48);
begin
  for l in select id, number from lessons
           where status = 'pending_payment' and created_at < now() - make_interval(hours => hrs)
             and not exists (select 1 from payments p where p.lesson_id = lessons.id and p.status = 'under_review')
  loop
    perform refund_lesson_internal(l.id, 'Unpaid booking #' || l.number || ' expired');
    update lessons set status = 'cancelled', cancel_reason = 'Payment not completed in time' where id = l.id;
    update payments set status = 'failed', fail_reason = 'Payment not completed in time' where lesson_id = l.id and status = 'pending';
    n := n + 1;
  end loop;
  for k in select id, student_id from packages
           where status = 'pending_payment' and created_at < now() - make_interval(hours => hrs)
             and not exists (select 1 from payments p where p.package_id = packages.id and p.status = 'under_review')
  loop
    amt := coalesce((select -sum(amount) from wallet_transactions where package_id = k.id and kind = 'booking'), 0);
    if amt > 0 then
      insert into wallet_transactions (user_id, amount, kind, package_id, note)
      values (k.student_id, amt, 'refund', k.id, 'Unpaid package expired');
    end if;
    update packages set status = 'cancelled' where id = k.id;
    update payments set status = 'failed', fail_reason = 'Payment not completed in time' where package_id = k.id and status = 'pending';
    n := n + 1;
  end loop;
  update payments set status = 'failed', fail_reason = 'No receipt was uploaded in time'
  where purpose = 'top_up' and status = 'pending' and created_at < now() - make_interval(hours => hrs);
  get diagnostics c = row_count;
  return n + c;
end $$;

-- Admin view of payments, with purpose, reference and the related lesson number.
drop view if exists admin_payments;
create view admin_payments with (security_invoker = true) as
select pay.*, p.full_name as user_name, p.phone as user_phone, l.number as lesson_number
from payments pay
join profiles p on p.id = pay.user_id
left join lessons l on l.id = pay.lesson_id;

-- =====================================================================
-- Task 2 — tutor payouts need the account to send the money to
-- =====================================================================
create or replace function request_payout(p_amount numeric, p_method payout_method, p_details jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); po uuid; holder text; acct text; d jsonb := coalesce(p_details, '{}'::jsonb);
begin
  if not exists (select 1 from tutor_profiles where user_id = u) then raise exception 'Tutors only'; end if;
  holder := trim(coalesce(d ->> 'holder_name', ''));
  acct   := trim(coalesce(d ->> 'account', ''));
  if holder = '' and acct = '' and d ->> 'requested_from' = 'app' then
    -- older app versions (no form yet): keep the name and phone they send so the admin can follow up
    holder := trim(coalesce(d ->> 'name', ''));
    acct   := trim(coalesce(d ->> 'phone', ''));
  end if;
  if holder = '' or acct = '' then raise exception 'Enter the account holder name and the account or wallet number'; end if;
  if length(holder) > 120 or length(acct) > 120 then raise exception 'Name and account must be 120 characters or less'; end if;
  perform pg_advisory_xact_lock(1, hashtext(u::text));            -- my earnings
  if p_amount is null or p_amount <= 0 or p_amount > wallet_balance(u) then raise exception 'Amount is more than your available balance'; end if;
  insert into payouts (tutor_id, amount, method, details)
  values (u, p_amount, p_method, jsonb_build_object('holder_name', holder, 'account', acct)
                                 || case when d ? 'requested_from' then jsonb_build_object('legacy_app', true) else '{}'::jsonb end)
  returning id into po;
  insert into wallet_transactions (user_id, amount, kind, payout_id, note) values (u, -p_amount, 'payout', po, 'Payout request');
  return po;
end $$;

-- =====================================================================
-- Task 4.1 — sign-up: phone only from the verified login; unknown roles become student
-- =====================================================================
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  meta_role text := new.raw_user_meta_data->>'role';
  r user_role := case when meta_role in ('student', 'parent', 'tutor') then meta_role::user_role else 'student'::user_role end;
begin
  insert into profiles (id, role, full_name, phone, email)
  values (new.id, r,
          left(coalesce(new.raw_user_meta_data->>'full_name', ''), 120),
          nullif(trim(coalesce(new.phone, '')), ''),
          new.email);
  if r = 'tutor' then
    insert into tutor_profiles (user_id) values (new.id);
  end if;
  return new;
end $$;

-- =====================================================================
-- Task 4.2 — file size and type limits per bucket
-- =====================================================================
do $$
begin
  if to_regclass('storage.buckets') is null then return; end if;
  update storage.buckets set file_size_limit = 50 * 1024 * 1024, allowed_mime_types = array['image/*', 'video/*', 'application/pdf'] where id = 'chat-files';
  update storage.buckets set file_size_limit =  5 * 1024 * 1024, allowed_mime_types = array['audio/*', 'video/webm', 'video/mp4'] where id = 'voice-notes';
  update storage.buckets set file_size_limit =  2 * 1024 * 1024, allowed_mime_types = array['image/*'] where id = 'avatars';
  update storage.buckets set file_size_limit = 50 * 1024 * 1024, allowed_mime_types = array['image/*', 'video/*'] where id = 'tutor-media';
  update storage.buckets set file_size_limit =  5 * 1024 * 1024, allowed_mime_types = array['image/*', 'application/pdf'] where id = 'receipts';
  update storage.buckets set file_size_limit = 10 * 1024 * 1024, allowed_mime_types = array['image/*', 'application/pdf'] where id = 'tutor-docs';
end $$;

-- ---------- permissions ----------
revoke execute on function pay_to_account(payment_method), ensure_payment_reference(uuid) from public, anon, authenticated;
revoke execute on function request_top_up(numeric, payment_method), transfer_instructions(uuid, payment_method),
  submit_bank_receipt(uuid, text, payment_method) from public, anon;
grant execute on function request_top_up(numeric, payment_method), transfer_instructions(uuid, payment_method),
  submit_bank_receipt(uuid, text, payment_method) to authenticated;
