-- Round H (part 2) — reviews, trial lesson, first-lesson refund, lesson summary (H3, H4, H5).
-- Safe to run once (and harmless if run again). Deletes no data. Old app versions keep working: everything
-- here is new columns with defaults and new functions; book_lesson and the price are unchanged for them.
-- Owner decision (27 Nov 2026): reviews show at once (no approval step); admin can still hide one.

-- ── H3. Reviews: one reply by the tutor; how many lessons the student had with the tutor ──────────────────
alter table reviews add column if not exists reply text check (char_length(reply) <= 1000);
alter table reviews add column if not exists replied_at timestamptz;
alter table reviews add column if not exists student_lessons int;   -- delivered lessons with this tutor, at review time

create or replace function reviews_count_lessons() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.student_lessons := (select count(*) from lessons
                          where student_id = new.student_id and tutor_id = new.tutor_id and status = 'delivered');
  return new;
end $$;
drop trigger if exists reviews_lessons on reviews;
create trigger reviews_lessons before insert or update of stars, comment on reviews
  for each row execute function reviews_count_lessons();

-- The tutor of a review answers it once. Contact details are masked (and flagged) as in comments.
create or replace function reply_to_review(p_review uuid, p_text text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); r reviews%rowtype; t text := btrim(coalesce(p_text, '')); h jsonb;
begin
  if u is null or not is_active_user() then raise exception 'Sign in first' using errcode = '42501'; end if;
  select * into r from reviews where id = p_review for update;
  if r.id is null or r.tutor_id <> u then raise exception 'Review not found'; end if;
  if r.reply is not null then raise exception 'You already replied to this review'; end if;
  if char_length(t) = 0 or char_length(t) > 1000 then raise exception 'Write a reply (up to 1000 characters)'; end if;
  h := contact_hits(t);
  if jsonb_array_length(h) > 0 then
    perform flag_contact_hits(h, u, t, null, null, null, 'review', r.lesson_id::text, 'in a review reply');
    t := mask_contacts(t);
  end if;
  update reviews set reply = t, replied_at = now() where id = r.id;
  perform push_notification(r.student_id, 'The tutor replied to your review', 'Open the tutor''s profile to read it.',
                            jsonb_build_object('tutor_id', r.tutor_id, 'review_id', r.id));
end $$;
revoke execute on function reply_to_review(uuid, text) from public, anon;
grant execute on function reply_to_review(uuid, text) to authenticated;

-- ── H4. Trial lesson: 20 minutes at the tutor's trial price, once, as the first lesson with that tutor ────
alter table tutor_profiles add column if not exists trial_price numeric check (trial_price is null or trial_price > 0);
alter table lessons add column if not exists is_trial boolean not null default false;
alter table lessons add column if not exists first_refund_at timestamptz;   -- "first lesson not right" refund

-- The tutor's trial price (null = no trial). At most the hourly price.
create or replace function set_trial_price(p_price numeric) returns void
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); hp numeric;
begin
  if u is null or not is_active_user() then raise exception 'Sign in first' using errcode = '42501'; end if;
  select hourly_price into hp from tutor_profiles where user_id = u;
  if hp is null then raise exception 'Tutors only'; end if;
  if p_price is not null and (p_price <= 0 or p_price > hp) then
    raise exception 'The trial price must be more than 0 and not more than the hourly price';
  end if;
  update tutor_profiles set trial_price = round(p_price, 2) where user_id = u;
end $$;
revoke execute on function set_trial_price(numeric) from public, anon;
grant execute on function set_trial_price(numeric) to authenticated;

-- While book_trial_lesson runs, the price is the trial price for 20 minutes (3 × trial price an hour).
create or replace function tutor_price(p_tutor uuid, p_level text) returns numeric
language sql stable security definer set search_path = public as $$
  select case when current_setting('dars.trial', true) = '1' then t.trial_price * 3
         else round(coalesce(
           (select price from tutor_level_prices where tutor_id = p_tutor and level_id = p_level),
           t.hourly_price * coalesce((select price_factor from study_levels where id = p_level), 1)), 2) end
  from tutor_profiles t where t.user_id = p_tutor;
$$;

create or replace function lessons_mark_trial() returns trigger
language plpgsql set search_path = public as $$
begin
  if current_setting('dars.trial', true) = '1' then new.is_trial := true; end if;
  return new;
end $$;
drop trigger if exists lessons_trial on lessons;
create trigger lessons_trial before insert on lessons for each row execute function lessons_mark_trial();

create or replace function book_trial_lesson(
  p_tutor uuid, p_starts_at timestamptz, p_subject text default null,
  p_mode lesson_mode default 'online', p_notes text default null,
  p_use_wallet boolean default true, p_method payment_method default 'card')
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); r jsonb;
begin
  if u is null or not is_active_user() then raise exception 'Sign in first' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(1, hashtext(u::text));   -- the same lock as book_lesson: one booking of mine at a time
  if (select trial_price from tutor_profiles where user_id = p_tutor) is null then
    raise exception 'This tutor does not offer a trial lesson';
  end if;
  if exists (select 1 from lessons where student_id = u and tutor_id = p_tutor and status <> 'cancelled') then
    raise exception 'The trial lesson is only for your first lesson with this tutor';
  end if;
  perform set_config('dars.trial', '1', true);
  r := book_lesson(p_tutor, p_starts_at, 20, p_subject, null, p_mode, p_notes, p_use_wallet, p_method);
  perform set_config('dars.trial', '', true);
  return r;
end $$;
revoke execute on function book_trial_lesson(uuid, timestamptz, text, lesson_mode, text, boolean, payment_method) from public, anon;
grant execute on function book_trial_lesson(uuid, timestamptz, text, lesson_mode, text, boolean, payment_method) to authenticated;

-- "First lesson not right": within 24 h after the first lesson with a tutor, the whole amount back to the
-- wallet (package lessons: the hours back to the package), once per student and tutor. The tutor's
-- earning for it is reversed (earnings are held 48 h, Round F, so it was not paid out yet).
create or replace function first_lesson_refund(p_lesson uuid) returns numeric
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); l lessons%rowtype; amt numeric; earned numeric;
begin
  if u is null or not is_active_user() then raise exception 'Sign in first' using errcode = '42501'; end if;
  select * into l from lessons where id = p_lesson for update;
  if l.id is null or l.student_id <> u then raise exception 'Lesson not found'; end if;
  perform pg_advisory_xact_lock(hashtext('first_refund:' || u::text || ':' || l.tutor_id::text));
  if exists (select 1 from lessons where student_id = u and tutor_id = l.tutor_id and first_refund_at is not null) then
    raise exception 'You already used the first-lesson refund with this tutor';
  end if;
  if l.status not in ('delivered', 'confirmed')
     or exists (select 1 from lessons o where o.student_id = u and o.tutor_id = l.tutor_id and o.id <> l.id
                and o.status <> 'cancelled' and o.starts_at < l.starts_at) then
    raise exception 'The first-lesson refund is for your first lesson with a tutor';
  end if;
  if l.starts_at + make_interval(mins => l.duration_min) > now() then raise exception 'You can ask for it after the lesson ends'; end if;
  if now() > l.starts_at + make_interval(mins => l.duration_min) + interval '24 hours' then
    raise exception 'The first-lesson refund must be asked within 24 hours after the lesson';
  end if;
  amt := refund_lesson_internal(l.id, 'First lesson not right');
  select coalesce(sum(amount), 0) into earned from wallet_transactions where lesson_id = l.id and kind = 'earning';
  if earned > 0 then
    insert into wallet_transactions (user_id, amount, kind, lesson_id, note) values (l.tutor_id, -earned, 'adjustment', l.id, 'Earning reversed: first-lesson refund');
  end if;
  update lessons set status = 'cancelled', cancel_reason = 'First lesson not right (refunded)', cancelled_by = u,
                     first_refund_at = now() where id = l.id;
  perform push_notification(u, 'Refund issued', 'The lesson amount was returned to your balance.', jsonb_build_object('lesson_id', l.id));
  perform push_notification(l.tutor_id, 'First lesson refunded',
    'The student asked for the first-lesson refund for lesson #' || l.number || '. The earning was reversed.', jsonb_build_object('lesson_id', l.id));
  perform audit('first_lesson_refund', l.id::text, jsonb_build_object('amount', amt));
  return amt;
end $$;
revoke execute on function first_lesson_refund(uuid) from public, anon;
grant execute on function first_lesson_refund(uuid) to authenticated;

-- ── H5. The tutor's short summary of a lesson, for the student (and the parent) ─────────────────────────
alter table lessons add column if not exists summary text check (char_length(summary) <= 2000);
alter table lessons add column if not exists summary_at timestamptz;

create or replace function save_lesson_summary(p_lesson uuid, p_text text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid(); l lessons%rowtype; t text := btrim(coalesce(p_text, '')); h jsonb; par uuid;
begin
  if u is null or not is_active_user() then raise exception 'Sign in first' using errcode = '42501'; end if;
  select * into l from lessons where id = p_lesson for update;
  if l.id is null or l.tutor_id <> u then raise exception 'Lesson not found'; end if;
  if l.status not in ('confirmed', 'delivered') or l.starts_at > now() then
    raise exception 'You can write a summary after the lesson starts';
  end if;
  if char_length(t) = 0 or char_length(t) > 2000 then raise exception 'Write a summary (up to 2000 characters)'; end if;
  h := contact_hits(t);
  if jsonb_array_length(h) > 0 then
    perform flag_contact_hits(h, u, t, null, null, null, 'lesson', l.id::text, 'in a lesson summary');
    t := mask_contacts(t);
  end if;
  update lessons set summary = t, summary_at = now() where id = l.id;
  perform push_notification(l.student_id, 'Lesson summary', 'Your tutor wrote a summary of lesson #' || l.number || '.',
                            jsonb_build_object('lesson_id', l.id));
  -- A teen whose parent approved the account: the parent is told too.
  select parent_id into par from parent_links where student_id = l.student_id and status = 'approved';
  if par is not null and par <> l.student_id then
    perform push_notification(par, 'Lesson summary', 'Your tutor wrote a summary of lesson #' || l.number || '.',
                              jsonb_build_object('lesson_id', l.id, 'child', l.student_id));
  end if;
end $$;
revoke execute on function save_lesson_summary(uuid, text) from public, anon;
grant execute on function save_lesson_summary(uuid, text) to authenticated;

-- The parent of an approved teen reads that teen's lesson summaries.
create or replace function child_lesson_summaries(p_child uuid) returns table (lesson_id uuid, number int, starts_at timestamptz, summary text, summary_at timestamptz)
language sql stable security definer set search_path = public as $$
  select l.id, l.number, l.starts_at, l.summary, l.summary_at from lessons l
  where l.student_id = p_child and l.summary is not null
    and exists (select 1 from parent_links pl where pl.student_id = p_child and pl.parent_id = auth.uid() and pl.status = 'approved')
  order by l.starts_at desc limit 50;
$$;
revoke execute on function child_lesson_summaries(uuid) from public, anon;
grant execute on function child_lesson_summaries(uuid) to authenticated;

-- Trial price on the public profile (columns added at the end of the view).
create or replace view public_tutors as
select t.user_id as id, p.full_name, p.avatar_url, p.gender, p.country,
       t.headline, t.about, t.years_experience, t.languages, t.teaches_online, t.teaches_in_person,
       t.hourly_price, t.currency, t.max_package_discount, t.instant_booking, t.cancel_hours,
       t.available_now and (t.dnd_until is null or t.dnd_until < now()) as available_now,
       t.rating_avg, t.rating_count, round(t.minutes_taught / 60.0) as hours_taught, t.video_url,
       (t.verified_at > now() - interval '30 days') as is_new,
       coalesce((select array_agg(subject_id order by subject_id) from tutor_subjects s where s.tutor_id = t.user_id), '{}') as subject_ids,
       coalesce((select array_agg(curriculum_id) from tutor_curricula c where c.tutor_id = t.user_id), '{}') as curriculum_ids,
       (select count(distinct student_id) from lessons l where l.tutor_id = t.user_id and l.status = 'delivered') as students,
       t.trial_price
from tutor_profiles t join profiles p on p.id = t.user_id
where t.verification = 'approved' and p.status = 'active';
grant select on public_tutors to anon, authenticated;

-- Arabic for the new server texts (Round H1 list; ids from 1000 on).
insert into server_texts (id, pattern, ar) values
  (1001, 'Review not found', 'التقييم غير موجود'),
  (1002, 'You already replied to this review', 'لقد رددت على هذا التقييم مسبقاً'),
  (1003, 'Write a reply \(up to 1000 characters\)', 'اكتب رداً (حتى 1000 حرف)'),
  (1004, 'This tutor does not offer a trial lesson', 'هذا المدرس لا يقدّم درساً تجريبياً'),
  (1005, 'The trial lesson is only for your first lesson with this tutor', 'الدرس التجريبي لأول درس لك مع هذا المدرس فقط'),
  (1006, 'The trial price must be more than 0 and not more than the hourly price', 'يجب أن يكون سعر الدرس التجريبي أكثر من 0 وألا يزيد عن سعر الساعة'),
  (1007, 'You already used the first-lesson refund with this tutor', 'استخدمت استرداد الدرس الأول مع هذا المدرس مسبقاً'),
  (1008, 'The first-lesson refund is for your first lesson with a tutor', 'استرداد الدرس الأول مخصص لأول درس لك مع المدرس'),
  (1009, 'You can ask for it after the lesson ends', 'يمكنك طلبه بعد انتهاء الدرس'),
  (1010, 'The first-lesson refund must be asked within 24 hours after the lesson', 'يجب طلب استرداد الدرس الأول خلال 24 ساعة بعد الدرس'),
  (1011, 'You can write a summary after the lesson starts', 'يمكنك كتابة الملخص بعد بداية الدرس'),
  (1012, 'Write a summary \(up to 2000 characters\)', 'اكتب ملخصاً (حتى 2000 حرف)'),
  (1013, 'The tutor replied to your review', 'ردّ المدرس على تقييمك'),
  (1014, 'Open the tutor''s profile to read it\.', 'افتح ملف المدرس لقراءة الرد.'),
  (1015, 'First lesson refunded', 'تم استرداد الدرس الأول'),
  (1016, 'The student asked for the first-lesson refund for lesson #(.+)\. The earning was reversed\.', 'طلب الطالب استرداد الدرس الأول رقم \1. أُلغيت أرباحه.'),
  (1017, 'Lesson summary', 'ملخص الدرس'),
  (1018, 'Your tutor wrote a summary of lesson #(.+)\.', 'كتب مدرسك ملخصاً للدرس رقم \1.')
on conflict (id) do update set pattern = excluded.pattern, ar = excluded.ar;
