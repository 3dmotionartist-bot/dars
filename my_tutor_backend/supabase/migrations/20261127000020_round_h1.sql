-- Round H (part 1) — Arabic server messages (H1).
-- Safe to run once (and harmless if run again: the list is updated in place). Deletes no data.
-- Old app versions keep working: the server still answers in English; this only adds the Arabic.
--
-- H1. server_texts: the English sentences the server writes (refusals and notifications) as patterns, with
--     their Arabic. The app downloads the list (anyone may read it) and shows refusals in Arabic. New
--     notifications get their Arabic title and body saved in data (title_ar / body_ar); the push to the phone
--     carries the notification's data, so a phone in Arabic shows the Arabic text.

create table if not exists server_texts (
  id      int primary key,
  pattern text not null,   -- the whole English text; (.+) marks a variable part
  ar      text not null    -- the Arabic; \1, \2 … put the variable parts back
);
alter table server_texts enable row level security;
revoke all on server_texts from public, anon, authenticated;
grant select on server_texts to anon, authenticated;
drop policy if exists server_texts_read on server_texts;
create policy server_texts_read on server_texts for select using (true);

insert into server_texts (id, pattern, ar) values
  (1, 'Add a note explaining the adjustment', 'اكتب ملاحظة تشرح التعديل'),
  (2, 'Admin accounts are removed by another admin', 'حسابات المشرفين يحذفها مشرف آخر'),
  (3, 'Admins only', 'للمشرفين فقط'),
  (4, 'Amount is more than your available balance', 'المبلغ أكبر من رصيدك المتاح'),
  (5, 'Bad device token', 'تعذّر تسجيل هذا الجهاز للإشعارات'),
  (6, 'Cancel or finish your upcoming lessons first', 'ألغِ دروسك القادمة أو أكملها أولاً'),
  (7, 'Choose a time and a length', 'اختر الوقت ومدة الدرس'),
  (8, 'Choose a time in the future', 'اختر وقتاً في المستقبل'),
  (9, 'Contact details \(phone, email, social accounts or links\) are not allowed in your profile', 'لا يُسمح بمعلومات التواصل (هاتف، بريد، حسابات تواصل أو روابط) في ملفك'),
  (10, 'Contact details are not allowed in a name', 'لا يُسمح بمعلومات التواصل في الاسم'),
  (11, 'Conversation not found', 'المحادثة غير موجودة'),
  (12, 'Documents must be uploaded from the Dars app', 'يجب رفع الوثائق من تطبيق درس'),
  (13, 'Each discount must be a whole number from 0 to 50', 'كل خصم يجب أن يكون رقماً صحيحاً من 0 إلى 50'),
  (14, 'Each period must end after it starts', 'يجب أن تنتهي كل فترة بعد بدايتها'),
  (15, 'Enter the account holder name and the account or wallet number', 'أدخل اسم صاحب الحساب ورقم الحساب أو المحفظة'),
  (16, 'Files must be sent from the Dars app', 'يجب إرسال الملفات من تطبيق درس'),
  (17, 'In-person lessons for students under 18 are booked by a parent', 'الدروس الحضورية للطلاب دون 18 سنة يحجزها ولي الأمر'),
  (18, 'Invalid call message', 'رسالة مكالمة غير صالحة'),
  (19, 'Invalid discounts', 'خصومات غير صالحة'),
  (20, 'Invalid time zone', 'منطقة زمنية غير صالحة'),
  (21, 'It is too late to reschedule this lesson \(less than (.+) hours before it starts\)', 'فات وقت تغيير موعد هذا الدرس (بقي أقل من \1 ساعة على بدايته)'),
  (22, 'Lesson is already cancelled', 'الدرس ملغى مسبقاً'),
  (23, 'Lesson not found', 'الدرس غير موجود'),
  (24, 'Lessons are priced at your own study level\. Change it in your profile if it is wrong', 'تُسعَّر الدروس حسب مرحلتك الدراسية. غيّرها من ملفك إن كانت خاطئة'),
  (25, 'Max tutors reached for this request', 'وصل هذا الطلب إلى العدد الأقصى من المدرسين'),
  (26, 'Name and account must be 120 characters or less', 'يجب ألا يزيد الاسم والحساب عن 120 حرفاً'),
  (27, 'No changes waiting', 'لا توجد تعديلات بانتظار المراجعة'),
  (28, 'Not allowed', 'غير مسموح'),
  (29, 'Not enough hours left in this package', 'لا تكفي الساعات المتبقية في هذه الباقة'),
  (30, 'Not your child', 'هذا ليس طفلك'),
  (31, 'Nothing to cancel', 'لا يوجد ما يُلغى'),
  (32, 'Only a parent account can add children', 'فقط حساب ولي الأمر يمكنه إضافة أطفال'),
  (33, 'Only a parent account can approve a child', 'فقط حساب ولي الأمر يمكنه الموافقة على حساب طفل'),
  (34, 'Only an admin can change role or account status', 'فقط المشرف يمكنه تغيير نوع الحساب أو حالته'),
  (35, 'Only approved tutors can answer requests', 'فقط المدرسون المعتمدون يمكنهم الرد على الطلبات'),
  (36, 'Only confirmed lessons can be marked delivered', 'فقط الدروس المؤكدة يمكن تسجيلها كمكتملة'),
  (37, 'Only disputed or confirmed lessons can be released', 'فقط الدروس المؤكدة أو قيد المراجعة يمكن تحرير مبلغها'),
  (38, 'Only the student can reschedule', 'فقط الطالب يمكنه تغيير الموعد'),
  (39, 'Only tutors have working hours', 'أوقات العمل للمدرسين فقط'),
  (40, 'Package not found', 'الباقة غير موجودة'),
  (41, 'Packages start at 4 hours', 'تبدأ الباقات من 4 ساعات'),
  (42, 'Password must be at least 10 characters', 'يجب ألا تقل كلمة المرور عن 10 أحرف'),
  (43, 'Payment not found', 'الدفعة غير موجودة'),
  (44, 'Payout not found', 'طلب التحويل غير موجود'),
  (45, 'Please accept the tutor code of conduct', 'يرجى الموافقة على ميثاق سلوك المدرس'),
  (46, 'Reports must be made within 48 hours', 'يجب الإبلاغ خلال 48 ساعة'),
  (47, 'Request cancelled by the student', 'ألغى الطالب الطلب'),
  (48, 'Request not found', 'الطلب غير موجود'),
  (49, 'Sign in first', 'سجّل الدخول أولاً'),
  (50, 'Students under 13 use Dars through a parent''s account\. Ask your parent to add you as a child', 'الطلاب تحت 13 سنة يستخدمون درس من حساب ولي الأمر. اطلب من أحد والديك إضافتك كطفل'),
  (51, 'The amount must be between (.+) and (.+)', 'يجب أن يكون المبلغ بين \1 و\2'),
  (52, 'The lesson has not started yet', 'لم يبدأ الدرس بعد'),
  (53, 'The tutor already has a lesson at this time', 'لدى المدرس درس آخر في هذا الوقت'),
  (54, 'These tutor fields are managed by Dars', 'هذه الحقول تديرها إدارة درس'),
  (55, 'This account did not ask to be deleted', 'هذا الحساب لم يطلب الحذف'),
  (56, 'This account is not active', 'هذا الحساب غير مفعّل'),
  (57, 'This code is not valid', 'هذا الرمز غير صالح'),
  (58, 'This lesson can no longer be cancelled', 'لم يعد بالإمكان إلغاء هذا الدرس'),
  (59, 'This lesson cannot be rescheduled', 'لا يمكن تغيير موعد هذا الدرس'),
  (60, 'This link is not allowed\. Use the Dars classroom or a meeting link without contact details', 'هذا الرابط غير مسموح. استخدم صف درس أو رابط اجتماع دون معلومات تواصل'),
  (61, 'This package is not active', 'هذه الباقة غير فعّالة'),
  (62, 'This payment is already paid', 'هذه الدفعة مدفوعة مسبقاً'),
  (63, 'This payment is not waiting for a receipt', 'هذه الدفعة لا تنتظر إيصالاً'),
  (64, 'This payment is not waiting for a transfer', 'هذه الدفعة لا تنتظر تحويلاً'),
  (65, 'This payment method is not available', 'طريقة الدفع هذه غير متاحة'),
  (66, 'This payout is already closed', 'طلب التحويل هذا مغلق مسبقاً'),
  (67, 'This student has not booked with you', 'هذا الطالب لم يحجز معك'),
  (68, 'This time is outside the tutor''s working hours', 'هذا الوقت خارج أوقات عمل المدرس'),
  (69, 'This tutor does not teach this subject', 'هذا المدرس لا يدرّس هذه المادة'),
  (70, 'This tutor is not available for booking', 'هذا المدرس غير متاح للحجز'),
  (71, 'This tutor is not taking bookings yet', 'هذا المدرس لا يستقبل حجوزات بعد'),
  (72, 'This tutor teaches online only', 'هذا المدرس يدرّس أونلاين فقط'),
  (73, 'Times out! This request has expired', 'انتهى الوقت! انتهت صلاحية هذا الطلب'),
  (74, 'Too many documents \(10 at most\)', 'عدد الوثائق كبير (10 كحد أقصى)'),
  (75, 'Too many tries\. Try again later', 'محاولات كثيرة. حاول لاحقاً'),
  (76, 'Tutor and parent accounts are for adults \(18\+\)', 'حسابات المدرسين وأولياء الأمور للبالغين (18+)'),
  (77, 'Tutor not found', 'المدرس غير موجود'),
  (78, 'Tutors only', 'للمدرسين فقط'),
  (79, 'Unknown document type', 'نوع وثيقة غير معروف'),
  (80, 'Unknown event', 'حدث غير معروف'),
  (81, 'Unknown version', 'إصدار غير معروف'),
  (82, 'Up to 10 children', 'حتى 10 أطفال كحد أقصى'),
  (83, 'Upload the receipt from the Dars app', 'ارفع الإيصال من تطبيق درس'),
  (84, 'User not found', 'المستخدم غير موجود'),
  (85, 'Write the reason for the tutor', 'اكتب السبب للمدرس'),
  (86, 'Write what happened \(up to 2000 characters\)', 'اكتب ما حدث (حتى 2000 حرف)'),
  (87, 'You already have (.+) bookings waiting for payment\. Pay for them or cancel one before booking again\.', 'لديك \1 حجوزات بانتظار الدفع. ادفعها أو ألغِ أحدها قبل حجز جديد.'),
  (88, 'You already have 3 top-ups waiting\. Finish or wait for those first\.', 'لديك 3 طلبات شحن قيد الانتظار. أكملها أو انتظرها أولاً.'),
  (89, 'You can only block people you are in touch with', 'يمكنك حظر من تتواصل معهم فقط'),
  (90, 'You can report a lesson after it starts', 'يمكنك الإبلاغ عن الدرس بعد بدايته'),
  (91, 'You can report a no-show 15 minutes after the start time', 'يمكنك الإبلاغ عن الغياب بعد 15 دقيقة من موعد البداية'),
  (92, 'You can review a lesson after it is delivered', 'يمكنك تقييم الدرس بعد اكتماله'),
  (93, 'You cannot book yourself', 'لا يمكنك حجز درس مع نفسك'),
  (94, 'You cannot change your own status', 'لا يمكنك تغيير حالة حسابك بنفسك'),
  (95, 'You cannot message or call this person \(blocked\)', 'لا يمكنك مراسلة هذا الشخص أو الاتصال به (محظور)'),
  (96, 'You cannot message yourself', 'لا يمكنك مراسلة نفسك'),
  (97, 'You have reached the limit of live requests for now\. Try again later\.', 'وصلت إلى الحد الأقصى من الطلبات الفورية حالياً. حاول لاحقاً.'),
  (98, 'Your parent needs to approve your account first \(Account → Parent approval\)', 'يجب أن يوافق ولي أمرك على حسابك أولاً (حسابي ← موافقة ولي الأمر)'),
  (99, 'Your year of birth is already saved\. Contact Dars to change it', 'سنة ميلادك محفوظة مسبقاً. تواصل مع درس لتغييرها'),
  (100, 'New lesson booked', 'تم حجز درس جديد'),
  (101, 'You have a new lesson\. Check Upcoming lessons\.', 'لديك درس جديد. راجع الدروس القادمة.'),
  (102, 'New package purchased', 'تم شراء باقة جديدة'),
  (103, '(.+) hours package', 'باقة \1 ساعات'),
  (104, 'A package lesson was booked\.', 'تم حجز درس من باقة.'),
  (105, 'Credit added', 'تمت إضافة الرصيد'),
  (106, '(.+) was added to your Dars credit \(the amount we received; you asked for (.+)\)\. You can book lessons with it now\.', 'أُضيف $\1 إلى رصيدك في درس (المبلغ الذي وصلنا؛ طلبت $\2). يمكنك حجز الدروس به الآن.'),
  (107, '(.+) was added to your Dars credit\. You can book lessons with it now\.', 'أُضيف $\1 إلى رصيدك في درس. يمكنك حجز الدروس به الآن.'),
  (108, 'Payment added to your wallet', 'أُضيفت الدفعة إلى محفظتك'),
  (109, 'Your booking had already expired, so the amount was added to your Dars wallet\. You can use it for a new booking\.', 'انتهت صلاحية حجزك، لذا أُضيف المبلغ إلى محفظتك في درس. يمكنك استخدامه لحجز جديد.'),
  (110, 'New booking', 'حجز جديد'),
  (111, 'A student completed payment\.', 'أكمل طالب الدفع.'),
  (112, 'Payment & booking confirmed', 'تم تأكيد الدفع والحجز'),
  (113, 'Your payment was received\.', 'تم استلام دفعتك.'),
  (114, 'Receipt not accepted', 'لم يُقبل الإيصال'),
  (115, 'We could not match your transfer\. You can upload a new receipt from your lessons within (.+) hours\.', 'لم نتمكن من مطابقة تحويلك. يمكنك رفع إيصال جديد من دروسك خلال \1 ساعة.'),
  (116, '(.+) You can upload a new receipt from your lessons within (.+) hours\.', '\1 يمكنك رفع إيصال جديد من دروسك خلال \2 ساعة.'),
  (117, 'Top-up not accepted', 'لم يُقبل شحن الرصيد'),
  (118, 'We could not match your transfer\. Contact support if you sent the money\.', 'لم نتمكن من مطابقة تحويلك. تواصل مع الدعم إن كنت أرسلت المبلغ.'),
  (119, '(.+) Contact support if you sent the money\.', '\1 تواصل مع الدعم إن كنت أرسلت المبلغ.'),
  (120, 'Receipt to check', 'إيصال للمراجعة'),
  (121, '(.+) uploaded a transfer receipt for (.+) \(credit top-up\)\.', 'رفع \1 إيصال تحويل بقيمة $\2 (شحن رصيد).'),
  (122, '(.+) uploaded a transfer receipt for (.+) \(booking\)\.', 'رفع \1 إيصال تحويل بقيمة $\2 (حجز).'),
  (123, 'Lesson cancelled', 'تم إلغاء الدرس'),
  (124, 'Lesson #(.+) was cancelled\.', 'تم إلغاء الدرس رقم \1.'),
  (125, 'Lesson rescheduled', 'تم تغيير موعد الدرس'),
  (126, 'Lesson #(.+) has a new time\.', 'للدرس رقم \1 موعد جديد.'),
  (127, 'New review received', 'وصلك تقييم جديد'),
  (128, 'Lesson reported', 'تم الإبلاغ عن درس'),
  (129, 'The student reported lesson #(.+)\. Dars will review it\.', 'أبلغ الطالب عن الدرس رقم \1. ستراجعه إدارة درس.'),
  (130, 'We value your opinion!', 'رأيك يهمنا!'),
  (131, 'Rate your lesson #(.+)', 'قيّم درسك رقم \1'),
  (132, 'Missed lesson', 'درس فائت'),
  (133, 'Lesson #(.+) was marked as no-show\. If you attended, report it within 48 hours\.', 'سُجّل الدرس رقم \1 كغياب. إن كنت حاضراً فأبلغ خلال 48 ساعة.'),
  (134, 'Real time request!', 'طلب مساعدة فورية!'),
  (135, 'A student would like to connect with you\.', 'طالب يريد التواصل معك.'),
  (136, 'A tutor accepted your request', 'قبِل مدرس طلبك'),
  (137, 'Open the app to chat or call\.', 'افتح التطبيق للمراسلة أو الاتصال.'),
  (138, 'Receipt waiting too long', 'إيصال ينتظر منذ مدة طويلة'),
  (139, 'A booking receipt \((.+)\) has been waiting more than (.+) hours\. The tutor''s time stays held until you confirm or reject it\.', 'إيصال حجز ($\1) ينتظر منذ أكثر من \2 ساعة. يبقى وقت المدرس محجوزاً حتى تؤكده أو ترفضه.'),
  (140, 'Your profile is approved', 'تم اعتماد ملفك'),
  (141, 'Your profile needs changes', 'ملفك يحتاج تعديلات'),
  (142, 'Profile under review', 'ملفك قيد المراجعة'),
  (143, 'You can now receive bookings and live requests\.', 'يمكنك الآن استقبال الحجوزات والطلبات الفورية.'),
  (144, 'Payout approved', 'تمت الموافقة على طلب التحويل'),
  (145, 'Payout paid', 'تم تحويل أرباحك'),
  (146, 'Payout rejected', 'تم رفض طلب التحويل'),
  (147, 'Refund issued', 'تم استرداد المبلغ لرصيدك'),
  (148, 'The lesson amount was returned to your balance\.', 'أُعيد مبلغ الدرس إلى رصيدك.'),
  (149, 'Missed call', 'مكالمة فائتة'),
  (150, 'Security alert', 'تنبيه أمني'),
  (151, '(.+) shared or asked for contact details (.+)\.', 'شارك \1 معلومات تواصل أو طلبها (\2).'),
  (152, 'New tutor application', 'طلب انضمام مدرس جديد'),
  (153, '(.+) sent documents for review\.', 'أرسل \1 وثائق للمراجعة.'),
  (154, 'Profile changes approved', 'تمت الموافقة على تعديلات ملفك'),
  (155, 'Your changes are now on your public profile\.', 'تعديلاتك ظاهرة الآن في ملفك العام.'),
  (156, 'Profile changes not approved', 'لم تتم الموافقة على تعديلات ملفك'),
  (157, 'Your parent approved your account', 'وافق ولي أمرك على حسابك'),
  (158, 'You can now book lessons and chat with tutors\.', 'يمكنك الآن حجز الدروس ومراسلة المدرسين.'),
  (159, 'Lesson reminder', 'تذكير بالدرس')
on conflict (id) do update set pattern = excluded.pattern, ar = excluded.ar;
delete from server_texts where id > 159 and id < 1000;  -- only list entries (no user data); later rounds use 1000+

-- The Arabic for one English server text (null when it is not on the list).
create or replace function server_text_ar(p text) returns text
language plpgsql stable set search_path = public as $$
declare r record;
begin
  if p is null or btrim(p) = '' then return null; end if;
  for r in select pattern, ar from server_texts order by id loop
    if p ~ ('^(?:' || r.pattern || ')$') then
      return regexp_replace(p, '^(?:' || r.pattern || ')$', r.ar);
    end if;
  end loop;
  return null;
end $$;

-- Every new notification keeps its Arabic next to the English (the app and the phone pick by language).
create or replace function notifications_add_ar() returns trigger
language plpgsql set search_path = public as $$
declare t text; b text;
begin
  t := server_text_ar(new.title);
  b := server_text_ar(new.body);
  if t is not null and not (coalesce(new.data, '{}'::jsonb) ? 'title_ar') then
    new.data := coalesce(new.data, '{}'::jsonb) || jsonb_build_object('title_ar', t);
  end if;
  if b is not null and not (coalesce(new.data, '{}'::jsonb) ? 'body_ar') then
    new.data := coalesce(new.data, '{}'::jsonb) || jsonb_build_object('body_ar', b);
  end if;
  return new;
end $$;
drop trigger if exists notifications_ar on notifications;
create trigger notifications_ar before insert on notifications for each row execute function notifications_add_ar();
