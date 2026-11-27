-- Round H: Arabic server messages (H1). Runs after round_f.sql.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set tut      '00000000-0000-0000-0000-0000000000c1'
\set tut2     '00000000-0000-0000-0000-0000000000c2'

reset role;
\echo '--- H1. every English text the server writes has an Arabic version'
-- Every refusal written in a function of the app ("raise exception '…'"), with any %-placeholders filled in.
create temp table h1_raised as
select distinct replace(replace(m[1], '''''', ''''), '%', '7') as txt
from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
     regexp_matches(p.prosrc, 'raise exception\s+''((?:[^'']|'''')*)''', 'gi') m
where n.nspname = 'public' and p.proname not like 't\_%' and m[1] not like 'FAIL%';
select t_ok((select count(*) from h1_raised) >= 90, 'found the server''s refusal texts (90+)');
select t_ok(not exists (select 1 from h1_raised where server_text_ar(txt) is null),
  'every refusal has Arabic; missing: ' || coalesce((select string_agg(txt, ' | ') from h1_raised where server_text_ar(txt) is null), 'none'));
-- Every fixed notification title ("push_notification(user, 'Title', …").
create temp table h1_titles as
select distinct m[1] as txt
from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
     regexp_matches(p.prosrc, 'push_notification\(\s*[^,]+,\s*''([^'']+)''', 'g') m
where n.nspname = 'public' and m[1] !~ ' $';  -- 'Payout ' || status is checked below with each status
select t_ok((select count(*) from h1_titles) >= 20, 'found the notification titles (20+)');
select t_ok(not exists (select 1 from h1_titles where server_text_ar(txt) is null),
  'every notification title has Arabic; missing: ' || coalesce((select string_agg(txt, ' | ') from h1_titles where server_text_ar(txt) is null), 'none'));

\echo '--- H1. variable parts are kept'
select t_ok(server_text_ar('Lesson #12 was cancelled.') = 'تم إلغاء الدرس رقم 12.', 'lesson number kept');
select t_ok(server_text_ar('The amount must be between 5 and 500') = 'يجب أن يكون المبلغ بين 5 و500', 'two numbers kept in order');
select t_ok(server_text_ar('25 was added to your Dars credit (the amount we received; you asked for 30). You can book lessons with it now.')
  = 'أُضيف $25 إلى رصيدك في درس (المبلغ الذي وصلنا؛ طلبت $30). يمكنك حجز الدروس به الآن.', 'the longer credit text wins over the shorter one');
select t_ok(server_text_ar('25 was added to your Dars credit. You can book lessons with it now.') = 'أُضيف $25 إلى رصيدك في درس. يمكنك حجز الدروس به الآن.', 'plain credit text');
select t_ok(server_text_ar('Something the server never says') is null and server_text_ar('') is null and server_text_ar(null) is null,
  'unknown, empty or missing text: no Arabic (the app shows the English)');
select t_ok(server_text_ar('Payout paid') = 'تم تحويل أرباحك' and server_text_ar('Payout rejected') = 'تم رفض طلب التحويل'
  and server_text_ar('Payout approved') is not null, 'payout titles, for every status');

\echo '--- H1. notifications keep their Arabic'
select push_notification(:'stu', 'Lesson cancelled', 'Lesson #77 was cancelled.', '{"lesson_id": "x"}');
select t_ok((select data->>'title_ar' = 'تم إلغاء الدرس' and data->>'body_ar' = 'تم إلغاء الدرس رقم 77.' and data->>'lesson_id' = 'x'
  from notifications where user_id = :'stu' order by id desc limit 1), 'a new notification has title_ar and body_ar, and keeps its data');
select push_notification(:'tut', 'Profile changes not approved', 'صورة الملف غير واضحة', '{}');
select t_ok((select data->>'title_ar' = 'لم تتم الموافقة على تعديلات ملفك' and not (data ? 'body_ar')
  from notifications where user_id = :'tut' order by id desc limit 1), 'a reason the admin wrote is left as written');
insert into notifications (user_id, title, body, data) values (:'stu', 'Lesson cancelled', 'x', '{"title_ar": "مخصص"}');
select t_ok((select data->>'title_ar' = 'مخصص' from notifications where user_id = :'stu' order by id desc limit 1),
  'an Arabic text already given is not replaced');

\echo '--- H1. who can read and change the list'
set role anon;
select t_ok((select count(*) from server_texts) >= 150, 'a visitor can read the list (the app downloads it before sign-in)');
select t_err('insert into server_texts values (9999, ''x'', ''y'')', 'permission denied', 'a visitor cannot add to the list');
reset role;
select t_as(:'stu'); set role authenticated;
select t_err('update server_texts set ar = ''x'' where id = 1', 'permission denied', 'a signed-in user cannot change the list');
select t_err('delete from server_texts', 'permission denied', 'a signed-in user cannot delete the list');
reset role;

-- ═════════════════════════════ Round H part 2 ═════════════════════════════
\set h2s  '00000000-0000-0000-0000-0000000000d1'
\set h2s2 '00000000-0000-0000-0000-0000000000d2'
reset role;
insert into auth.users (id, email, phone, raw_user_meta_data) values
  (:'h2s',  null, '+963900000021', '{"full_name":"Hiba","role":"student"}'),
  (:'h2s2', null, '+963900000022', '{"full_name":"Omar","role":"student"}');
update profiles set level_id = 'high', status = 'active' where id in (:'h2s', :'h2s2');
update app_settings set value = 'true' where key = 'bookable_without_hours';
delete from availability_slots where tutor_id in (:'tut', :'tut2');  -- any time is bookable for these tests
update tutor_profiles set verification = 'approved', hourly_price = 30 where user_id = :'tut';
update profiles set status = 'active' where id = :'tut';
insert into wallet_transactions (user_id, amount, kind, note) values (:'h2s', 500, 'adjustment', 'test credit'), (:'h2s2', 500, 'adjustment', 'test credit');
select ((now() at time zone 'UTC')::date + 160 + time '09:00') at time zone 'UTC' as far \gset

\echo '--- H4. trial lesson'
select t_as(:'tut'); set role authenticated;
select t_err('select set_trial_price(31)', 'not more than the hourly price', 'a trial dearer than the hourly price is refused');
select t_err('select set_trial_price(0)', 'more than 0', 'a free or negative trial price is refused');
select set_trial_price(8);
reset role;
select t_ok((select trial_price from public_tutors where id = :'tut') = 8, 'the trial price shows on the public profile');
select t_as(:'h2s'); set role authenticated;
select book_trial_lesson(:'tut', :'far'::timestamptz) ->> 'lesson_id' as tl \gset
reset role;
select t_ok((select is_trial and duration_min = 20 and price = 8 and status = 'confirmed' from lessons where id = :'tl'),
  'the trial is 20 minutes at the trial price, paid from the wallet');
select t_ok(tutor_price(:'tut', 'high') = round(coalesce((select price from tutor_level_prices where tutor_id = :'tut' and level_id = 'high'),
              30 * coalesce((select price_factor from study_levels where id = 'high'), 1)), 2) and coalesce(current_setting('dars.trial', true), '') = '',
  'outside a trial booking the price is the normal one');
select t_as(:'h2s'); set role authenticated;
select t_err(format('select book_trial_lesson(%L, %L)', :'tut', (:'far'::timestamptz + interval '2 days')),
  'only for your first lesson', 'a second trial with the same tutor is refused');
reset role;
select t_as(:'h2s2'); set role authenticated;
select book_lesson(:'tut', :'far'::timestamptz + interval '3 days', 60);
select t_err(format('select book_trial_lesson(%L, %L)', :'tut', (:'far'::timestamptz + interval '5 days')),
  'only for your first lesson', 'no trial after a normal lesson with the tutor');
reset role;
select t_as(:'tut'); set role authenticated;
select t_err(format('select book_trial_lesson(%L, %L)', :'tut', (:'far'::timestamptz + interval '6 days')), 'cannot book yourself', 'a tutor cannot book a trial with himself');
reset role;
update tutor_profiles set trial_price = null where user_id = :'tut2';
select t_as(:'h2s2'); set role authenticated;
select t_err(format('select book_trial_lesson(%L, %L)', :'tut2', (:'far'::timestamptz + interval '7 days')), 'does not offer a trial', 'no trial when the tutor offers none');
reset role;
set role anon;
select t_err(format('select book_trial_lesson(%L, %L)', :'tut', :'far'), 'permission denied', 'a visitor cannot book a trial');
select t_err('select set_trial_price(5)', 'permission denied', 'a visitor cannot set a trial price');
reset role;

\echo '--- H4. "first lesson not right" refund'
-- The trial lesson took place yesterday and was delivered.
update lessons set starts_at = now() - interval '20 hours' where id = :'tl';
update lessons set status = 'delivered', delivered_at = now() - interval '19 hours' where id = :'tl';
select credit_tutor_internal(:'tl');
select coalesce(sum(amount), 0) as bal0 from wallet_transactions where user_id = :'h2s' \gset
select t_as(:'h2s2'); set role authenticated;
select t_err(format('select first_lesson_refund(%L)', :'tl'), 'Lesson not found', 'someone else''s lesson cannot be refunded');
reset role;
select t_as(:'h2s'); set role authenticated;
select t_ok(first_lesson_refund(:'tl') = 8, 'the first lesson is refunded in full');
reset role;
select t_ok((select coalesce(sum(amount), 0) from wallet_transactions where user_id = :'h2s') = :bal0 + 8, 'the money is back in the wallet');
select t_ok((select coalesce(sum(amount), 0) from wallet_transactions where lesson_id = :'tl' and user_id = :'tut') = 0, 'the tutor''s earning is reversed');
select t_ok((select status = 'cancelled' and first_refund_at is not null from lessons where id = :'tl'), 'the lesson is marked refunded');
select t_as(:'h2s'); set role authenticated;
select t_err(format('select first_lesson_refund(%L)', :'tl'), 'already used', 'the refund works once per tutor');
reset role;
-- Too late, and not the first lesson.
select t_as(:'h2s2'); set role authenticated;
select (select id from lessons where student_id = auth.uid() and tutor_id = :'tut' limit 1) as nl \gset
reset role;
update lessons set starts_at = now() - interval '30 hours', status = 'delivered' where id = :'nl';
select t_as(:'h2s2'); set role authenticated;
select t_err(format('select first_lesson_refund(%L)', :'nl'), 'within 24 hours', 'after 24 hours it is too late');
reset role;
update lessons set starts_at = now() - interval '5 hours' where id = :'nl';
select t_as(:'h2s2'); set role authenticated;
-- Two requests at the same moment cannot both pay out: the second one finds the first.
select first_lesson_refund(:'nl');
select t_err(format('select first_lesson_refund(%L)', :'nl'), 'already used', 'a repeated request is refused');
reset role;
select t_ok((select count(*) from wallet_transactions where lesson_id = :'nl' and kind = 'refund') = 1, 'paid back exactly once');

\echo '--- H3. reviews: the tutor replies once'
reset role;
insert into lessons (student_id, tutor_id, starts_at, duration_min, status, price, commission, delivered_at)
values (:'h2s', :'tut', now() - interval '3 days', 60, 'delivered', 30, 6, now() - interval '3 days') returning id as rl \gset
select t_as(:'h2s'); set role authenticated;
select leave_review(:'rl', 5, 'Very clear') as rv \gset
reset role;
select t_ok((select student_lessons from reviews where id = :'rv') >= 1, 'the review shows how many lessons the student had with the tutor');
select t_as(:'tut2'); set role authenticated;
select t_err(format('select reply_to_review(%L, %L)', :'rv', 'thanks'), 'Review not found', 'another tutor cannot reply');
reset role;
select t_as(:'h2s'); set role authenticated;
select t_err(format('select reply_to_review(%L, %L)', :'rv', 'thanks'), 'Review not found', 'the student cannot reply to his own review');
reset role;
select t_as(:'tut'); set role authenticated;
select t_err(format('select reply_to_review(%L, %L)', :'rv', '   '), 'Write a reply', 'an empty reply is refused');
select reply_to_review(:'rv', 'Thank you! Call me on 0933 123 456 for more');
select t_err(format('select reply_to_review(%L, %L)', :'rv', 'again'), 'already replied', 'only one reply');
reset role;
select t_ok((select reply !~ '0933' and replied_at is not null from reviews where id = :'rv'), 'contact details in a reply are hidden');
select t_ok(exists (select 1 from message_flags where source = 'review' and source_id = :'rl' and sender_id = :'tut'), 'and the admins are told');
select t_ok((select data->>'title_ar' = 'ردّ المدرس على تقييمك' from notifications where user_id = :'h2s' order by id desc limit 1), 'the student is told, in Arabic too');
set role anon;
select t_ok((select reply is not null from reviews where id = :'rv'), 'a visitor reads the reply with the review');
select t_err(format('select reply_to_review(%L, %L)', :'rv', 'x'), 'permission denied', 'a visitor cannot reply');
reset role;

\echo '--- H5. lesson summary'
select t_as(:'h2s'); set role authenticated;
select t_err(format('select save_lesson_summary(%L, %L)', :'rl', 'x'), 'Lesson not found', 'the student cannot write the summary');
reset role;
select t_as(:'tut'); set role authenticated;
select t_err(format('select save_lesson_summary(%L, %L)', :'rl', ''), 'Write a summary', 'an empty summary is refused');
select save_lesson_summary(:'rl', 'Fractions done. Homework: page 12, exercises 1–5.');
reset role;
select t_ok((select summary like 'Fractions done%' and summary_at is not null from lessons where id = :'rl'), 'the summary is saved on the lesson');
select t_ok((select body = 'Your tutor wrote a summary of lesson #' || (select number from lessons where id = :'rl') || '.'
               and data->>'body_ar' like 'كتب مدرسك ملخصاً للدرس رقم%' from notifications where user_id = :'h2s' order by id desc limit 1),
  'the student is told (Arabic too)');
select t_as(:'h2s'); set role authenticated;
select t_ok((select summary is not null from lessons where id = :'rl'), 'the student reads it on the lesson');
reset role;
select t_as(:'tut'); set role authenticated;
select t_err(format('select save_lesson_summary(%L, %L)', :'tl', 'x'), 'after the lesson starts', 'no summary for a cancelled lesson');
reset role;
select t_as(:'h2s2'); set role authenticated;
select t_ok((select count(*) from child_lesson_summaries(:'h2s')) = 0, 'someone who is not the approved parent sees no summaries');
reset role;
update app_settings set value = 'false' where key = 'bookable_without_hours';
