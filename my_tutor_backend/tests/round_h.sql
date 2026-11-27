-- Round H: Arabic server messages (H1). Runs after round_f.sql.
\set QUIET on
\pset format unaligned
\pset tuples_only on
\set stu      '00000000-0000-0000-0000-0000000000b1'
\set tut      '00000000-0000-0000-0000-0000000000c1'

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
