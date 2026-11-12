-- =====================================================================
-- Dars — fixes from the reviewer's week 2 retest.
-- Safe to run once in the Supabase SQL editor. It adds and replaces rules and
-- functions; it does not delete any user data. Older app versions keep working.
-- =====================================================================

insert into app_settings (key, value) values
  ('max_unpaid_bookings', '2'),    -- open bookings waiting for payment, per student
  ('unpaid_hold_hours',   '6'),    -- how long a booking without a receipt holds the tutor's time
  ('review_alert_hours',  '72')    -- remind admins about a booking receipt waiting this long
on conflict (key) do nothing;

alter table payments add column if not exists receipt_at timestamptz;          -- when the receipt was uploaded
alter table payments add column if not exists rejected_at timestamptz;         -- when the admin last rejected a receipt
alter table payments add column if not exists review_alerted_at timestamptz;   -- admins reminded about a slow review
alter table payments add column if not exists requested_amount numeric(10, 2); -- top-up: what the student asked, when the admin confirmed a different amount

-- =====================================================================
-- 1. Unpaid bookings holding a tutor's time
-- =====================================================================
create or replace function unpaid_bookings_of(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select ((select count(*) from lessons where student_id = p_user and status = 'pending_payment')
        + (select count(*) from packages where student_id = p_user and status = 'pending_payment'))::int;
$$;

create or replace function book_lesson(
  p_tutor uuid, p_starts_at timestamptz, p_duration int,
  p_subject text default null, p_level text default null,
  p_mode lesson_mode default 'online', p_notes text default null,
  p_use_wallet boolean default true, p_method payment_method default 'card')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := me();
  lvl text;
  price numeric; comm numeric; use_wallet numeric := 0; due numeric;
  l uuid; pay uuid; st lesson_status; mx int := coalesce(setting_num('max_unpaid_bookings')::int, 2);
begin
  if u = p_tutor then raise exception 'You cannot book yourself'; end if;
  perform pg_advisory_xact_lock(1, hashtext(u::text));            -- my wallet
  perform assert_bookable_tutor(p_tutor);
  perform assert_slot_free(p_tutor, p_starts_at, p_duration);     -- takes the tutor's calendar lock
  if p_mode = 'in_person' and not (select teaches_in_person from tutor_profiles where user_id = p_tutor) then
    raise exception 'This tutor teaches online only';
  end if;
  if p_subject is not null and not exists (select 1 from tutor_subjects where tutor_id = p_tutor and subject_id = p_subject) then
    raise exception 'This tutor does not teach this subject';
  end if;

  lvl   := coalesce(p_level, (select level_id from profiles where id = u), 'high');
  price := round(tutor_price(p_tutor, lvl) * p_duration / 60.0, 2);
  comm  := round(price * commission_for(p_tutor), 2);
  if p_use_wallet then use_wallet := least(greatest(wallet_balance(u), 0), price); end if;
  due := price - use_wallet;
  if due > 0 and unpaid_bookings_of(u) >= mx then
    raise exception 'You already have % bookings waiting for payment. Pay for them or cancel one before booking again.', mx;
  end if;
  st  := case when due = 0 then 'confirmed' else 'pending_payment' end;

  insert into lessons (student_id, tutor_id, subject_id, level_id, starts_at, duration_min, mode, status, price, commission, notes)
  values (u, p_tutor, p_subject, lvl, p_starts_at, p_duration, p_mode, st, price, comm, p_notes)
  returning id into l;

  if use_wallet > 0 then
    insert into wallet_transactions (user_id, amount, kind, lesson_id, note) values (u, -use_wallet, 'booking', l, 'Lesson booking');
  end if;
  if due > 0 then
    insert into payments (user_id, lesson_id, amount, method) values (u, l, due, p_method) returning id into pay;
  else
    perform ensure_conversation(u, p_tutor);
    perform push_notification(p_tutor, 'New lesson booked', 'You have a new lesson. Check Upcoming lessons.', jsonb_build_object('lesson_id', l));
  end if;

  return jsonb_build_object('lesson_id', l, 'status', st, 'price', price, 'wallet_used', use_wallet, 'amount_due', due, 'payment_id', pay);
end $$;

create or replace function buy_package(
  p_tutor uuid, p_hours int, p_level text default null,
  p_use_wallet boolean default true, p_method payment_method default 'card')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := me(); lvl text; disc int; price numeric; use_wallet numeric := 0; due numeric; pk uuid; pay uuid;
  mx int := coalesce(setting_num('max_unpaid_bookings')::int, 2);
begin
  if u = p_tutor then raise exception 'You cannot book yourself'; end if;
  perform pg_advisory_xact_lock(1, hashtext(u::text));            -- my wallet
  perform assert_bookable_tutor(p_tutor);
  if p_hours < 4 then raise exception 'Packages start at 4 hours'; end if;
  lvl   := coalesce(p_level, (select level_id from profiles where id = u), 'high');
  disc  := package_discount(p_tutor, p_hours);
  price := round(tutor_price(p_tutor, lvl) * p_hours * (100 - disc) / 100.0, 2);
  if p_use_wallet then use_wallet := least(greatest(wallet_balance(u), 0), price); end if;
  due := price - use_wallet;
  if due > 0 and unpaid_bookings_of(u) >= mx then
    raise exception 'You already have % bookings waiting for payment. Pay for them or cancel one before booking again.', mx;
  end if;

  insert into packages (student_id, tutor_id, level_id, total_hours, discount_pct, price, status)
  values (u, p_tutor, lvl, p_hours, disc, price, case when due = 0 then 'active'::package_status else 'pending_payment' end)
  returning id into pk;

  if use_wallet > 0 then
    insert into wallet_transactions (user_id, amount, kind, package_id, note) values (u, -use_wallet, 'booking', pk, 'Package ' || pk);
  end if;
  if due > 0 then
    insert into payments (user_id, package_id, amount, method) values (u, pk, due, p_method) returning id into pay;
  else
    perform push_notification(p_tutor, 'New package purchased', p_hours || ' hours package', jsonb_build_object('package_id', pk));
  end if;
  return jsonb_build_object('package_id', pk, 'discount_pct', disc, 'price', price, 'wallet_used', use_wallet, 'amount_due', due, 'payment_id', pay);
end $$;

-- Clean-up (runs on a schedule):
--  * a booking with no receipt is released after unpaid_hold_hours (counted from the booking, or from
--    the last rejected receipt — finding 4), and the wallet part is refunded;
--  * a booking whose receipt is being checked is never cancelled; after review_alert_hours the admins
--    are reminded once (it is also shown first, in red, in the dashboard);
--  * a top-up with no receipt closes after pending_payment_hours (it holds no tutor time).
create or replace function expire_pending_payments() returns int
language plpgsql security definer set search_path = public as $$
declare
  l record; k record; r record; a uuid; amt numeric; n int := 0; c int;
  hold int := coalesce(setting_num('unpaid_hold_hours')::int, 6);
  hrs int := coalesce(setting_num('pending_payment_hours')::int, 48);
  alert int := coalesce(setting_num('review_alert_hours')::int, 72);
begin
  for l in select ls.id, ls.number from lessons ls
           where ls.status = 'pending_payment'
             and not exists (select 1 from payments p where p.lesson_id = ls.id and p.status = 'under_review')
             and greatest(ls.created_at, coalesce((select max(p.rejected_at) from payments p where p.lesson_id = ls.id), ls.created_at))
                 < now() - make_interval(hours => hold)
  loop
    perform refund_lesson_internal(l.id, 'Unpaid booking #' || l.number || ' expired');
    update lessons set status = 'cancelled', cancel_reason = 'Payment not completed in time' where id = l.id;
    update payments set status = 'failed', fail_reason = 'Payment not completed in time' where lesson_id = l.id and status = 'pending';
    n := n + 1;
  end loop;
  for k in select pk.id, pk.student_id from packages pk
           where pk.status = 'pending_payment'
             and not exists (select 1 from payments p where p.package_id = pk.id and p.status = 'under_review')
             and greatest(pk.created_at, coalesce((select max(p.rejected_at) from payments p where p.package_id = pk.id), pk.created_at))
                 < now() - make_interval(hours => hold)
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

  for r in select p.id, p.amount from payments p
           where p.status = 'under_review' and p.purpose = 'booking' and p.review_alerted_at is null
             and coalesce(p.receipt_at, p.created_at) < now() - make_interval(hours => alert)
  loop
    update payments set review_alerted_at = now() where id = r.id;
    for a in select id from profiles where role = 'admin' and status = 'active' loop
      perform push_notification(a, 'Receipt waiting too long',
        'A booking receipt (' || r.amount || ') has been waiting more than ' || alert || ' hours. The tutor''s time stays held until you confirm or reject it.',
        jsonb_build_object('payment_id', r.id, 'overdue', true));
    end loop;
  end loop;
  return n + c;
end $$;

-- Receipt upload: remember when it arrived (for the reminder above).
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
     set receipt_url = p_receipt_url, status = 'under_review', fail_reason = null, receipt_at = now(), review_alerted_at = null,
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

-- =====================================================================
-- 4. A rejected booking receipt gets a fresh window to upload a new one
-- =====================================================================
create or replace function fail_payment(p_payment uuid, p_ref text default null, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare pay payments%rowtype; why text := nullif(left(trim(coalesce(p_reason, '')), 300), '');
  hold int := coalesce(setting_num('unpaid_hold_hours')::int, 6);
begin
  if not (is_service() or is_admin()) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into pay from payments where id = p_payment for update;
  if pay.id is null then raise exception 'Payment not found'; end if;
  if pay.status in ('paid', 'refunded') then raise exception 'This payment is already paid'; end if;
  if pay.purpose = 'booking' and pay.status = 'under_review' and not is_service() then
    update payments set status = 'pending', receipt_url = null, fail_reason = why, rejected_at = now(),
           provider_ref = coalesce(p_ref, provider_ref) where id = pay.id;
    perform push_notification(pay.user_id, 'Receipt not accepted',
      coalesce(why, 'We could not match your transfer.') || ' You can upload a new receipt from your lessons within ' || hold || ' hours.',
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

-- =====================================================================
-- 5. Confirm a top-up with the amount that really arrived
-- =====================================================================
drop function if exists confirm_payment(uuid, text, text);
create or replace function confirm_payment(p_payment uuid, p_provider text default null, p_ref text default null, p_amount numeric default null)
returns void language plpgsql security definer set search_path = public as $$
declare pay payments%rowtype; tutor uuid; asked numeric;
  mn numeric := coalesce(setting_num('top_up_min'), 5);
  mx numeric := coalesce(setting_num('top_up_max'), 1000);
begin
  if not (is_service() or is_admin()) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into pay from payments where id = p_payment for update;
  if pay.id is null then raise exception 'Payment not found'; end if;
  if pay.status in ('paid', 'refunded') then return; end if;          -- idempotent for retries / double clicks
  perform pg_advisory_xact_lock(1, hashtext(pay.user_id::text));

  if pay.purpose = 'top_up' then
    asked := pay.amount;
    if p_amount is not null and p_amount <> pay.amount then
      if not is_admin() then raise exception 'Not allowed' using errcode = '42501'; end if;
      if p_amount < mn or p_amount > mx or p_amount <> round(p_amount, 2) then
        raise exception 'The amount must be between % and %', mn, mx;
      end if;
      pay.amount := p_amount;
    end if;
    update payments set status = 'paid', paid_at = now(), fail_reason = null, amount = pay.amount,
           requested_amount = case when pay.amount <> asked then asked end,
           provider = coalesce(p_provider, provider), provider_ref = coalesce(p_ref, provider_ref)
     where id = pay.id;
    insert into wallet_transactions (user_id, amount, kind, payment_id, note)
    values (pay.user_id, pay.amount, 'top_up', pay.id, 'Credit top-up ' || coalesce(pay.reference, ''));
    perform push_notification(pay.user_id, 'Credit added',
      pay.amount || ' was added to your Dars credit'
        || case when pay.amount <> asked then ' (the amount we received; you asked for ' || asked || ')' else '' end
        || '. You can book lessons with it now.',
      jsonb_build_object('payment_id', pay.id, 'wallet', true));
    if is_admin() then
      perform audit('confirm_payment', pay.id::text, jsonb_build_object('requested', asked, 'confirmed', pay.amount));
    end if;
    return;
  end if;

  -- Bookings: the amount is fixed by the booking (p_amount is ignored).
  update payments set status = 'paid', paid_at = now(), fail_reason = null, provider = coalesce(p_provider, provider),
         provider_ref = coalesce(p_ref, provider_ref) where id = pay.id;
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

-- The admin view lists payments with the new columns.
drop view if exists admin_payments;
create view admin_payments with (security_invoker = true) as
select pay.*, p.full_name as user_name, p.phone as user_phone, l.number as lesson_number
from payments pay
join profiles p on p.id = pay.user_id
left join lessons l on l.id = pay.lesson_id;

-- =====================================================================
-- 2. Receipt files cannot be replaced or deleted by users once uploaded
-- =====================================================================
do $$
begin
  if to_regclass('storage.objects') is null then return; end if;
  execute 'drop policy if exists "own folder update" on storage.objects';
  execute 'drop policy if exists "own folder delete" on storage.objects';
  execute 'drop policy if exists "admin receipts update" on storage.objects';
  execute 'drop policy if exists "admin receipts delete" on storage.objects';
  execute $p$create policy "own folder update" on storage.objects for update to authenticated
    using (bucket_id <> 'receipts' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
  execute $p$create policy "own folder delete" on storage.objects for delete to authenticated
    using (bucket_id <> 'receipts' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
  execute $p$create policy "admin receipts update" on storage.objects for update to authenticated
    using (bucket_id = 'receipts' and public.is_admin())$p$;
  execute $p$create policy "admin receipts delete" on storage.objects for delete to authenticated
    using (bucket_id = 'receipts' and public.is_admin())$p$;
end $$;

-- =====================================================================
-- 3. A message sent again after a lost answer is stored only once
-- =====================================================================
alter table messages add column if not exists client_id uuid;
create unique index if not exists messages_client_once on messages (sender_id, client_id) where client_id is not null;

-- recent_messages lists its columns, so it is rebuilt to include the new one.
create or replace function recent_messages(p_conversations uuid[], p_limit int default 50)
returns setof messages language sql stable set search_path = public as $$
  select id, conversation_id, sender_id, kind, body, file_url, duration_sec, blocked, read_at, created_at, client_id
  from (
    select m.*, row_number() over (partition by m.conversation_id order by m.created_at desc, m.id desc) as rn
    from messages m
    where m.conversation_id = any(p_conversations)
  ) x
  where rn <= least(greatest(coalesce(p_limit, 50), 1), 200)
  order by conversation_id, created_at, id;
$$;

-- =====================================================================
-- 7. Accepting the same live-help request twice does not post the messages again
-- =====================================================================
create or replace function respond_live_request(p_request uuid, p_accept boolean, p_greeting text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare u uuid := me(); q live_requests%rowtype; c uuid; n int;
begin
  if not is_approved_tutor() then raise exception 'Only approved tutors can answer requests'; end if;
  select * into q from live_requests where id = p_request for update;
  if q.id is null then raise exception 'Request not found'; end if;
  if q.status = 'cancelled' then raise exception 'Request cancelled by the student'; end if;
  if q.expires_at < now() or q.status = 'expired' then raise exception 'Times out! This request has expired'; end if;

  if not p_accept then
    insert into live_responses (request_id, tutor_id, accepted) values (q.id, u, false) on conflict do nothing;
    return null;
  end if;

  -- Already accepted by me: just open the chat again.
  if exists (select 1 from live_responses where request_id = q.id and tutor_id = u and accepted) then
    return ensure_conversation(q.student_id, u);
  end if;

  select count(*) into n from live_responses where request_id = q.id and accepted;
  if n >= setting_num('live_max_tutors') then raise exception 'Max tutors reached for this request'; end if;
  insert into live_responses (request_id, tutor_id, accepted) values (q.id, u, true)
  on conflict (request_id, tutor_id) do update set accepted = true;

  c := ensure_conversation(q.student_id, u);
  -- The student's question opens the chat, so the tutor sees what to help with.
  if q.body is not null and q.body !~ '^🎤' then
    insert into messages (conversation_id, sender_id, kind, body) values (c, q.student_id, 'text', q.body);
  end if;
  insert into messages (conversation_id, sender_id, kind, body)
  values (c, u, 'text', left(coalesce(nullif(trim(p_greeting), ''), 'Hello, I''ve accepted your request. How can I assist you?'), 300));
  update live_requests set status = 'matched' where id = q.id and status = 'open';
  perform push_notification(q.student_id, 'A tutor accepted your request', 'Open the app to chat or call.', jsonb_build_object('live_request_id', q.id, 'conversation_id', c));
  return c;
end $$;

-- ---------- permissions ----------
revoke execute on function unpaid_bookings_of(uuid) from public, anon, authenticated;
