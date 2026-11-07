-- OPTIONAL demo content for a test project (never run on production).
-- Creates sample tutors, students, lessons, payments, payouts, live requests, reviews, reports and leads.
-- Run in the Supabase SQL editor after the migrations + seed.

do $$
declare
  tutors jsonb := '[
    {"n":"م. سامر الحلبي","p":"+963900000011","h":"مهندس ومدرس رياضيات وفيزياء بخبرة 12 سنة","price":15,"disc":20,"s":["math","physics"],"v":"approved","c":"Syria"},
    {"n":"أ. لمى الخطيب","p":"+962700000012","h":"مدرّسة إنجليزي ومدرّبة IELTS معتمدة","price":18,"disc":25,"s":["english","exams"],"v":"approved","c":"Jordan"},
    {"n":"د. ريم العلي","p":"+966500000013","h":"دكتوراه في الكيمياء — ثانوي وجامعة","price":22,"disc":15,"s":["chemistry","biology"],"v":"approved","c":"Saudi Arabia"},
    {"n":"أ. عمر النجار","p":"+971500000014","h":"مطوّر برمجيات يعلّم بايثون وتطوير الويب","price":20,"disc":10,"s":["programming"],"v":"approved","c":"UAE"},
    {"n":"أ. هبة درويش","p":"+963900000015","h":"تأسيس قراءة وكتابة ورياضيات للأطفال","price":12,"disc":20,"s":["kids","arabic"],"v":"approved","c":"Syria"},
    {"n":"الشيخ يوسف القاسم","p":"+201000000016","h":"مجاز في القراءات — تحفيظ وتجويد","price":10,"disc":15,"s":["quran","arabic"],"v":"approved","c":"Egypt"},
    {"n":"أ. نور حداد","p":"+961700000017","h":"محاسبة قانونية — محاسبة ومالية للجامعة","price":17,"disc":0,"s":["accounting"],"v":"pending","c":"Lebanon"},
    {"n":"أ. كريم منصور","p":"+212600000018","h":"مدرس فرنسي — DELF وبكالوريا فرنسية","price":16,"disc":10,"s":["french"],"v":"pending","c":"Morocco"},
    {"n":"م. فادي سلوم","p":"+963900000019","h":"مدرس فيزياء — بدون شهادة مرفقة","price":9,"disc":0,"s":["physics"],"v":"rejected","c":"Syria"}
  ]';
  students text[] := array['ليان محمد','أحمد سليمان','سارة علي','يوسف الأحمد','هيا عبدالله','خالد منصور','ماريا حنا','عمر زيدان','نور الهدى','تيم شاهين','جود العمر','رهف قاسم'];
  t jsonb; uid uuid; sid uuid; tids uuid[] := '{}'; sids uuid[] := '{}'; i int; l uuid; p numeric; st lesson_status; d timestamptz;
begin
  -- tutors
  for t in select * from jsonb_array_elements(tutors) loop
    insert into auth.users (phone, raw_user_meta_data) values (t->>'p', jsonb_build_object('full_name', t->>'n', 'role', 'tutor')) returning id into uid;
    update profiles set country = t->>'c', gender = case when t->>'n' like 'أ. لمى%' or t->>'n' like 'د. ريم%' or t->>'n' like 'أ. هبة%' or t->>'n' like 'أ. نور%' then 'f' else 'm' end where id = uid;
    update tutor_profiles set headline = t->>'h', hourly_price = (t->>'price')::numeric, max_package_discount = (t->>'disc')::int,
           verification = (t->>'v')::verification, verified_at = case when t->>'v' = 'approved' then now() - interval '120 days' end,
           rejection_reason = case when t->>'v' = 'rejected' then 'Please upload your degree certificate' end,
           years_experience = 5 + (random() * 10)::int, available_now = random() > .4, about = t->>'h'
    where user_id = uid;
    insert into tutor_subjects select uid, jsonb_array_elements_text(t->'s');
    if t->>'v' = 'approved' then tids := tids || uid; end if;
  end loop;

  -- students
  for i in 1 .. array_length(students, 1) loop
    insert into auth.users (phone, raw_user_meta_data)
    values ('+9639310000' || lpad(i::text, 2, '0'), jsonb_build_object('full_name', students[i], 'role', case when i % 4 = 0 then 'parent' else 'student' end))
    returning id into sid;
    update profiles set level_id = (array['elementary','middle','high','high','university'])[1 + i % 5], city = (array['دمشق','الرياض','عمّان','دبي','حلب'])[1 + i % 5],
           created_at = now() - make_interval(days => (random() * 60)::int) where id = sid;
    sids := sids || sid;
  end loop;

  -- lessons over the last 30 days + next 7 days
  for i in 1 .. 70 loop
    uid := tids[1 + (random() * (array_length(tids, 1) - 1))::int];
    sid := sids[1 + (random() * (array_length(sids, 1) - 1))::int];
    d := date_trunc('hour', now()) - make_interval(days => 30) + make_interval(hours => (random() * 37 * 24)::int);
    p := round((select hourly_price from tutor_profiles where user_id = uid) * (array[50, 50, 60, 100])[1 + i % 4] / 60.0, 2);
    st := case when d > now() then (case when i % 7 = 0 then 'pending_payment' else 'confirmed' end)::lesson_status
               when i % 13 = 0 then 'cancelled' when i % 17 = 0 then 'disputed' else 'delivered' end;
    insert into lessons (student_id, tutor_id, subject_id, level_id, starts_at, duration_min, status, price, commission, delivered_at, created_at)
    values (sid, uid, (select subject_id from tutor_subjects where tutor_id = uid limit 1), 'high', d, (array[50, 50, 60, 100])[1 + i % 4],
            st, p, round(p * 0.15, 2), case when st = 'delivered' then d + interval '1 hour' end, least(d, now()) - interval '1 day')
    returning id into l;
    insert into payments (user_id, lesson_id, amount, method, status, paid_at, created_at)
    values (sid, l, p, (array['card','mada','apple_pay','bank_transfer','bnpl'])[1 + i % 5]::payment_method,
            case when st = 'pending_payment' then (case when i % 2 = 0 then 'under_review' else 'pending' end)::payment_status
                 when st = 'cancelled' then 'refunded' else 'paid' end,
            case when st not in ('pending_payment', 'cancelled') then least(d, now()) - interval '1 day' end, least(d, now()) - interval '1 day');
    if st = 'delivered' then
      insert into wallet_transactions (user_id, amount, kind, lesson_id, note, created_at) values (uid, p - round(p * 0.15, 2), 'earning', l, 'Lesson', d);
      update tutor_profiles set minutes_taught = minutes_taught + 60 where user_id = uid;
      if i % 3 = 0 then
        insert into reviews (lesson_id, student_id, tutor_id, stars, comment)
        values (l, sid, uid, (array[5,5,4,5,3])[1 + i % 5], (array['شرح ممتاز وصبور','Very helpful lesson','ملتزم بالمواعيد','Great explanation','الحصة كانت قصيرة'])[1 + i % 5]);
      end if;
    end if;
    if st = 'disputed' then
      insert into reports (reporter_id, target_type, target_id, reason) values (sid, 'lesson', l::text, 'المدرس لم يحضر في الموعد');
    end if;
  end loop;

  -- payouts
  insert into payouts (tutor_id, amount, method, details, status, created_at)
  select tids[k], 40 + k * 15, 'bank_transfer', jsonb_build_object('iban', 'SA00 0000 0000 000' || k), (array['requested','requested','approved','paid','paid','rejected'])[k]::payout_status, now() - make_interval(days => k)
  from generate_series(1, 6) k;

  -- live requests today
  insert into live_requests (student_id, subject_id, level_id, body, status, expires_at, created_at)
  select sids[k], (array['math','physics','english','chemistry','math','programming'])[k], 'high',
         (array['سؤال في النهايات للاختبار غداً','Help with Newton''s laws homework','IELTS writing task 2 feedback','موازنة معادلة كيميائية','حل مسألة احتمالات','Python loop error'])[k],
         (array['matched','matched','expired','matched','open','cancelled'])[k]::live_status, now() + interval '1 minute', now() - make_interval(mins => k * 37)
  from generate_series(1, 6) k;

  -- conversation report + leads
  insert into conversations (student_id, tutor_id, flagged) values (sids[2], tids[1], true) on conflict do nothing;
  insert into reports (reporter_id, target_type, target_id, reason)
  select sids[2], 'conversation', id::text, 'طلب مني الدفع خارج التطبيق' from conversations where student_id = sids[2] and tutor_id = tids[1];
  insert into leads (full_name, whatsapp, city, who, level_id, subject_id, reason, mode, notes) values
    ('أم يوسف', '+966500000101', 'الرياض', 'parent', 'elementary', 'kids', 'Better grades', 'online', 'ابني في الصف الثالث'),
    ('Rami K.', '+971500000102', 'Dubai', 'student', 'university', 'accounting', 'Exam preparation', 'online', null),
    ('سلمى', '+963900000103', 'دمشق', 'student', 'high', 'physics', 'Homework help', 'in_person', 'بكالوريا علمي');
end $$;
