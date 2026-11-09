/* Demo data for the dashboard when no Supabase project is configured.
   Shapes match the database views (admin_tutors, admin_lessons, admin_payments, …). */
(function () {
  let seed = 7;
  const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
  const pick = (a) => a[Math.floor(rnd() * a.length)];
  const id = (p, i) => `${p}-${String(i).padStart(4, "0")}`;
  const now = Date.now();
  const H = 3600e3, D = 24 * H;
  const iso = (t) => new Date(t).toISOString();

  const subjects = [
    ["math", "الرياضيات", "Math", "#2F6BFF"], ["english", "اللغة الإنجليزية", "English", "#7B61FF"],
    ["arabic", "اللغة العربية", "Arabic", "#0E8F7E"], ["physics", "الفيزياء", "Physics", "#F59E0B"],
    ["chemistry", "الكيمياء", "Chemistry", "#22B573"], ["biology", "الأحياء", "Biology", "#E5484D"],
    ["exams", "اختبارات دولية", "Test prep", "#FF7A45"], ["programming", "البرمجة", "Programming", "#12203A"],
    ["quran", "القرآن والتجويد", "Quran & Tajweed", "#0A6E61"], ["accounting", "المحاسبة والمالية", "Accounting", "#5B45D6"],
    ["french", "اللغة الفرنسية", "French", "#0EA5E9"], ["kids", "تأسيس الأطفال", "Kids foundation", "#EC4899"],
  ].map(([id, name_ar, name_en, color], i) => ({ id, name_ar, name_en, color, sort: i + 1, active: true }));

  const levels = [
    ["kids", "رياض الأطفال", "Pre-school", 0.8], ["elementary", "ابتدائي", "Elementary", 0.85], ["middle", "إعدادي / متوسط", "Middle school", 0.9],
    ["high", "ثانوي", "High school", 1], ["university", "جامعي", "University", 1.2], ["adult", "مهنيون وبالغون", "Adults & professionals", 1.3],
  ].map(([id, name_ar, name_en, price_factor], i) => ({ id, name_ar, name_en, price_factor, sort: i + 1 }));

  const tutorSeed = [
    ["م. سامر الحلبي", "+963 933 100 011", "Syria", "دمشق", "مهندس ومدرس رياضيات وفيزياء بخبرة 12 سنة", 15, 20, ["math", "physics"], "approved", 4.9, 214],
    ["أ. لمى الخطيب", "+962 79 100 0012", "Jordan", "عمّان", "مدرّسة إنجليزي ومدرّبة IELTS معتمدة", 18, 25, ["english", "exams"], "approved", 4.8, 167],
    ["د. ريم العلي", "+966 50 100 0013", "Saudi Arabia", "الرياض", "دكتوراه في الكيمياء — ثانوي وجامعة", 22, 15, ["chemistry", "biology"], "approved", 4.9, 98],
    ["أ. عمر النجار", "+971 50 100 0014", "UAE", "دبي", "مطوّر برمجيات يعلّم بايثون وتطوير الويب", 20, 10, ["programming"], "approved", 4.7, 64],
    ["أ. هبة درويش", "+963 944 100 015", "Syria", "حلب", "تأسيس قراءة وكتابة ورياضيات للأطفال", 12, 20, ["kids", "arabic"], "approved", 5.0, 120],
    ["الشيخ يوسف القاسم", "+20 100 100 0016", "Egypt", "القاهرة", "مجاز في القراءات — تحفيظ وتجويد", 10, 15, ["quran", "arabic"], "approved", 4.9, 75],
    ["أ. نور حداد", "+961 70 100 017", "Lebanon", "بيروت", "محاسبة قانونية — محاسبة ومالية للجامعة", 17, 0, ["accounting"], "pending", 0, 0],
    ["أ. كريم منصور", "+212 600 100 018", "Morocco", "الرباط", "مدرس فرنسي — DELF وبكالوريا فرنسية", 16, 10, ["french"], "pending", 0, 0],
    ["أ. دانة الصالح", "+965 600 100 020", "Kuwait", "الكويت", "مدرّسة أحياء — منهج IB وIGCSE", 19, 15, ["biology"], "pending", 0, 0],
    ["م. فادي سلوم", "+963 955 100 019", "Syria", "حمص", "مدرس فيزياء", 9, 0, ["physics"], "rejected", 0, 0],
  ];
  const tutors = tutorSeed.map((t, i) => ({
    user_id: id("t", i + 1), full_name: t[0], phone: t[1], email: null, country: t[2], city: t[3], headline: t[4],
    about: t[4] + ". أبني لكل طالب خطة تناسب مستواه وموعد اختباره.", hourly_price: t[5], max_package_discount: t[6], subject_ids: t[7],
    verification: t[8], rating_avg: t[9], rating_count: t[10], years_experience: 4 + Math.floor(rnd() * 12),
    minutes_taught: t[8] === "approved" ? Math.floor(rnd() * 3000 + 400) * 60 : 0, available_now: t[8] === "approved" && rnd() > 0.4,
    teaches_in_person: rnd() > 0.6, instant_booking: rnd() > 0.3, cancel_hours: pick([12, 24]), commission_rate: null,
    cv_url: t[8] === "rejected" ? null : "tutor-docs/cv.pdf", video_url: t[8] === "approved" ? "tutor-media/intro.mp4" : null,
    rejection_reason: t[8] === "rejected" ? "يرجى رفع صورة الشهادة الجامعية" : null, account_status: "active",
    joined_at: iso(now - (t[8] === "pending" ? (i - 5) * D : (200 - i * 12) * D)),
    languages: [{ code: "ar", level: "native" }, ...(rnd() > 0.4 ? [{ code: "en", level: "advanced" }] : [])],
  }));

  const studentNames = ["ليان محمد", "أحمد سليمان", "سارة علي", "يوسف الأحمد", "هيا عبدالله", "خالد منصور", "ماريا حنا", "عمر زيدان", "نور الهدى", "تيم شاهين", "جود العمر", "رهف قاسم", "Adam K.", "Lina S."];
  const cities = ["دمشق", "الرياض", "عمّان", "دبي", "حلب", "جدة", "الكويت"];
  const students = studentNames.map((n, i) => ({
    id: id("s", i + 1), full_name: n, phone: `+963 93${i} ${200 + i} ${300 + i}`, role: i % 4 === 3 ? "parent" : "student",
    level_id: pick(["elementary", "middle", "high", "high", "university"]), city: pick(cities),
    status: i === 6 ? "blocked" : "active", created_at: iso(now - Math.floor(rnd() * 90) * D), balance: [25, 0, 12.5, 0, 0, 40][i] ?? 0,
  }));

  const approved = tutors.filter((t) => t.verification === "approved");
  const lessons = [];
  for (let i = 1; i <= 64; i++) {
    const t = pick(approved), s = pick(students.filter((x) => x.status === "active"));
    const start = Math.floor((now - 28 * D + rnd() * 36 * D) / H) * H;
    const dur = pick([50, 50, 60, 100]);
    const price = Math.round(t.hourly_price * dur / 60 * 100) / 100;
    let status = start > now ? (i % 7 === 0 ? "pending_payment" : "confirmed") : i % 13 === 0 ? "cancelled" : i % 17 === 0 ? "disputed" : "delivered";
    lessons.push({
      id: id("l", i), number: 1000 + i, student_id: s.id, student_name: s.full_name, student_phone: s.phone, tutor_id: t.user_id, tutor_name: t.full_name,
      subject_id: pick(t.subject_ids), level_id: s.level_id, starts_at: iso(start), duration_min: dur, mode: rnd() > 0.85 ? "in_person" : "online",
      status, price, commission: Math.round(price * 0.15 * 100) / 100, created_at: iso(Math.min(start, now) - D), package_id: rnd() > 0.8 ? "pkg" : null,
    });
  }
  lessons.sort((a, b) => b.starts_at.localeCompare(a.starts_at));

  const methods = ["card", "mada", "apple_pay", "bank_transfer", "bnpl"];
  const payments = lessons.map((l, i) => ({
    id: id("p", i + 1), user_id: l.student_id, user_name: l.student_name, user_phone: l.student_phone, lesson_id: l.id, lesson_number: l.number,
    package_id: null, amount: l.price, currency: "USD", method: l.status === "pending_payment" && i % 2 === 0 ? "bank_transfer" : pick(methods),
    status: l.status === "pending_payment" ? (i % 2 === 0 ? "under_review" : "pending") : l.status === "cancelled" ? "refunded" : "paid",
    receipt_url: l.status === "pending_payment" && i % 2 === 0 ? "receipts/transfer.jpg" : null,
    provider: "tap", provider_ref: "chg_" + (100000 + i), created_at: l.created_at, paid_at: l.status === "pending_payment" ? null : l.created_at,
  }));

  const payouts = approved.slice(0, 6).map((t, i) => ({
    id: id("po", i + 1), tutor_id: t.user_id, tutor_name: t.full_name, tutor_phone: t.phone, amount: 40 + i * 15,
    method: i === 3 ? "paypal" : "bank_transfer", details: i === 3 ? { email: "tutor@example.com" } : { iban: "SA03 8000 0000 6080 1016 75" + i },
    status: ["requested", "requested", "approved", "paid", "paid", "rejected"][i], admin_note: i === 5 ? "IBAN غير صحيح" : null,
    created_at: iso(now - (i + 1) * D), tutor_balance: 60 + i * 22,
  }));

  const liveBodies = ["سؤال في النهايات للاختبار غداً", "Help with Newton's laws homework", "IELTS writing task 2 — can someone check my essay?", "موازنة معادلة كيميائية", "حل مسألة احتمالات", "Python: my loop never stops", "إعراب جملة فعلية", "قانون أوم — فيزياء ثالث ثانوي"];
  const liveSubjects = ["math", "physics", "english", "chemistry", "math", "programming", "arabic", "physics"];
  const live_requests = liveBodies.map((b, i) => ({
    id: id("q", i + 1), student_id: students[i].id, student_name: students[i].full_name, subject_id: liveSubjects[i], level_id: "high",
    body: i === 4 ? null : b, voice_sec: i === 4 ? 41 : null, photo_url: i === 3 ? "chat-files/question.jpg" : null,
    status: ["matched", "matched", "expired", "matched", "open", "cancelled", "matched", "expired"][i],
    accepted_count: [3, 2, 0, 4, 0, 0, 1, 0][i], created_at: iso(now - (i * 47 + 3) * 60e3), expires_at: iso(now + 60e3),
  }));

  const reviewTexts = ["شرح ممتاز وصبور جداً", "Very helpful, finally understood it", "ملتزم بالمواعيد ويرسل ملخصاً", "Great explanation", "الحصة كانت قصيرة ولم نكمل الدرس", "رقم واتساب المدرس 0933…", "أفضل مدرس تعاملت معه"];
  const reviews = lessons.filter((l) => l.status === "delivered").slice(0, 7).map((l, i) => ({
    id: id("r", i + 1), lesson_id: l.id, student_name: l.student_name, tutor_name: l.tutor_name, stars: [5, 5, 5, 4, 2, 3, 5][i],
    comment: reviewTexts[i], status: i === 5 ? "hidden" : "visible", created_at: l.starts_at,
  }));

  const disputed = lessons.filter((l) => l.status === "disputed");
  const reports = [
    ...disputed.map((l, i) => ({ id: id("rp", i + 1), reporter_name: l.student_name, target_type: "lesson", target_id: l.id, target_label: "#" + l.number,
      reason: i % 2 ? "Not satisfied with the first hour" : "المدرس لم يحضر في الموعد", status: "open", created_at: l.starts_at })),
    { id: id("rp", 50), reporter_name: students[1].full_name, target_type: "conversation", target_id: "c-1", target_label: students[1].full_name + " ↔ " + approved[0].full_name,
      reason: "طلب مني الدفع خارج التطبيق", status: "open", created_at: iso(now - 5 * H) },
    { id: id("rp", 51), reporter_name: students[4].full_name, target_type: "review", target_id: "r-6", target_label: "Review", reason: "Review contains a phone number", status: "resolved",
      resolution_note: "Review hidden", created_at: iso(now - 3 * D) },
  ];

  const leads = [
    { full_name: "أم يوسف", whatsapp: "+966 50 000 0101", city: "الرياض", who: "parent", level_id: "elementary", subject_id: "kids", reason: "Better grades", mode: "online", notes: "ابني في الصف الثالث ويحتاج تأسيس قراءة", status: "new", hrs: 2 },
    { full_name: "Rami K.", whatsapp: "+971 50 000 0102", city: "Dubai", who: "student", level_id: "university", subject_id: "accounting", reason: "Exam preparation", mode: "online", notes: "Final exam in 3 weeks", status: "new", hrs: 6 },
    { full_name: "سلمى", whatsapp: "+963 930 000 103", city: "دمشق", who: "student", level_id: "high", subject_id: "physics", reason: "Homework help", mode: "in_person", notes: "بكالوريا علمي", status: "contacted", hrs: 30 },
    { full_name: "أبو خالد", whatsapp: "+962 79 000 0104", city: "عمّان", who: "parent", level_id: "middle", subject_id: "math", reason: "Better grades", mode: "both", notes: null, status: "converted", hrs: 80 },
  ].map((l, i) => ({ id: id("ld", i + 1), ...l, created_at: iso(now - l.hrs * H) }));

  const settings = { commission_rate: 0.15, vat_rate: 0, live_request_seconds: 90, live_max_tutors: 5, pending_payment_hours: 48, first_hour_guarantee: true, referral_commission: 0.1, support_whatsapp: "+963000000000" };

  // chat monitor + security alerts
  const cv = (i) => "cv-000" + i;
  const S1 = "st-1", S2 = "st-2", T1 = "tu-1", T2 = "tu-2";
  const conversations = [
    { id: cv(1), student_id: S1, student_name: "ليان", student_role: "student", student_phone: "+963 933 000 001", tutor_id: T1, tutor_name: "أ. سامر الحلبي", tutor_phone: "+963 944 000 011", message_count: 6, flag_count: 2, open_flags: 1, last_kind: "text", last_body: "ممكن رقمك؟", last_message_at: iso(now - 0.2 * H), created_at: iso(now - 50 * H) },
    { id: cv(2), student_id: S2, student_name: "أبو أحمد", student_role: "parent", student_phone: "+962 79 000 0002", tutor_id: T2, tutor_name: "أ. لمى الخطيب", tutor_phone: "+962 79 000 0012", message_count: 3, flag_count: 0, open_flags: 0, last_kind: "voice", last_body: "🎤", last_message_at: iso(now - 3 * H), created_at: iso(now - 30 * H) },
  ];
  const messages = {
    [cv(1)]: [
      { id: 1, conversation_id: cv(1), sender_id: S1, kind: "text", body: "مرحباً أستاذ، عندي امتحان رياضيات الأحد", created_at: iso(now - 26 * H) },
      { id: 2, conversation_id: cv(1), sender_id: T1, kind: "text", body: "أهلاً ليان، احجزي درس السبت الساعة 6 ونراجع كل شيء", created_at: iso(now - 25.8 * H) },
      { id: 3, conversation_id: cv(1), sender_id: S1, kind: "image", body: "homework.jpg", file_url: "chat-files/demo/homework.jpg", created_at: iso(now - 25 * H) },
      { id: 4, conversation_id: cv(1), sender_id: T1, kind: "text", body: "كلميني على واتساب أسهل ٠٩٤٤ ٥٥٥ ٦٦٦", blocked: true, created_at: iso(now - 1 * H) },
      { id: 5, conversation_id: cv(1), sender_id: S1, kind: "voice", body: "🎤", duration_sec: 12, created_at: iso(now - 0.5 * H) },
      { id: 6, conversation_id: cv(1), sender_id: S1, kind: "text", body: "ممكن رقمك؟", created_at: iso(now - 0.2 * H) },
    ],
    [cv(2)]: [
      { id: 7, conversation_id: cv(2), sender_id: S2, kind: "text", body: "ابني بالصف التاسع ويحتاج تقوية بالإنجليزي", created_at: iso(now - 5 * H) },
      { id: 8, conversation_id: cv(2), sender_id: T2, kind: "text", body: "أكيد، عندي باقة 8 ساعات بخصم", created_at: iso(now - 4 * H) },
      { id: 9, conversation_id: cv(2), sender_id: S2, kind: "voice", body: "🎤", duration_sec: 20, created_at: iso(now - 3 * H) },
    ],
  };
  const flags = [
    { id: 2, message_id: 6, conversation_id: cv(1), sender_id: S1, sender_name: "ليان", sender_role: "student", sender_phone: "+963 933 000 001", kind: "contact_request", matched: "رقمك", excerpt: "ممكن رقمك؟", status: "new", student_name: "ليان", student_role: "student", tutor_name: "أ. سامر الحلبي", created_at: iso(now - 0.2 * H) },
    { id: 1, message_id: 4, conversation_id: cv(1), sender_id: T1, sender_name: "أ. سامر الحلبي", sender_role: "tutor", sender_phone: "+963 944 000 011", kind: "phone", matched: "0944 555 666", excerpt: "كلميني على واتساب أسهل ٠٩٤٤ ٥٥٥ ٦٦٦", status: "reviewed", student_name: "ليان", student_role: "student", tutor_name: "أ. سامر الحلبي", created_at: iso(now - 1 * H) },
  ];

  window.DARS_DEMO = { subjects, levels, tutors, students, lessons, payments, payouts, live_requests, reviews, reports, leads, settings, conversations, flags, messages };
})();
