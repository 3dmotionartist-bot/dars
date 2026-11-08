/* Dars Admin — management dashboard (no build step).
   Demo mode: works offline with demo-data.js.  Live mode: set supabaseUrl + supabaseAnonKey in config.js. */
(function () {
  "use strict";
  const CFG = window.DARS_CONFIG || {};
  const SUPABASE_CDN = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js";

  // ------------------------------------------------------------------ i18n
  const I18N = {
    ar: {
      brand: "درس", console: "لوحة الإدارة", demo: "وضع تجريبي — بيانات نموذجية", live: "متصل بـ Supabase",
      g_ops: "التشغيل", g_money: "المال", g_quality: "الجودة والنمو", g_setup: "الإعداد",
      overview: "نظرة عامة", tutors: "المدرسون", students: "الطلاب وأولياء الأمور", lessons: "الدروس", live: "المساعدة الفورية",
      payments: "المدفوعات", payouts: "تحويلات المدرسين", reviews: "التقييمات", reports: "البلاغات", leads: "طلبات المساعدة",
      catalog: "المواد والمراحل", config: "الإعدادات",
      search: "بحث…", all: "الكل", refresh: "تحديث", close: "إغلاق", cancel: "إلغاء", save: "حفظ", confirm: "تأكيد", signout: "خروج",
      lang: "English", theme: "المظهر", none: "لا توجد بيانات هنا",
      k_revenue: "المدفوعات المحصّلة", k_commission: "عمولة المنصة", k_delivered: "دروس مكتملة", k_students: "طلاب نشطون",
      k_tutors: "مدرسون معتمدون", k_online: "متصل الآن", k_live: "طلبات فورية اليوم", k_matched: "تمت مطابقتها", last30: "آخر 30 يوماً",
      revenue14: "المدفوعات اليومية — آخر 14 يوماً", attention: "يحتاج إجراء", top_subjects: "المواد الأكثر طلباً",
      a_tutors: "مدرسون بانتظار المراجعة", a_receipts: "إيصالات تحويل بنكي للمراجعة", a_payouts: "طلبات تحويل أرباح",
      a_reports: "بلاغات مفتوحة", a_disputes: "دروس عليها اعتراض", a_leads: "طلبات مساعدة جديدة",
      name: "الاسم", phone: "الهاتف", subjects: "المواد", price: "السعر/ساعة", rating: "التقييم", country: "الدولة", status: "الحالة", joined: "الانضمام",
      pending: "قيد المراجعة", approved: "معتمد", rejected: "مرفوض", active: "نشط", blocked: "محظور", deleted: "محذوف",
      approve: "اعتماد", reject: "رفض", block: "حظر", unblock: "إلغاء الحظر", reject_reason: "سبب الرفض (يصل للمدرس)",
      headline: "العنوان", about: "نبذة", experience: "الخبرة", years: "سنوات", hours_taught: "ساعات التدريس", package_disc: "خصم الباقات حتى",
      in_person: "حضوري", online: "أونلاين", cv: "السيرة الذاتية", video: "فيديو تعريفي", missing: "غير مرفق", languages: "اللغات",
      role: "النوع", student: "طالب", parent: "ولي أمر", level: "المرحلة", city: "المدينة", balance: "الرصيد", adjust: "تعديل الرصيد",
      adjust_amount: "المبلغ (+ إضافة / − خصم)", adjust_note: "سبب التعديل (إلزامي)",
      number: "رقم", student_c: "الطالب", tutor: "المدرس", subject: "المادة", when: "الموعد", duration: "المدة", min: "د", amount: "المبلغ",
      pending_payment: "بانتظار الدفع", confirmed: "مؤكد", delivered: "تم", cancelled: "ملغى", disputed: "اعتراض", no_show: "لم يحضر",
      refund: "استرداد للطالب", release: "تحرير للمدرس", refund_note: "ملاحظة الاسترداد", release_note: "ملاحظة (تُغلق البلاغ)",
      method: "الطريقة", card: "بطاقة", mada: "مدى", apple_pay: "Apple Pay", bnpl: "تقسيط", bank_transfer: "تحويل بنكي", wallet: "رصيد", paypal: "PayPal", western_union: "ويسترن يونيون",
      paid: "مدفوع", under_review: "إيصال للمراجعة", failed: "فشل", refunded: "مسترد", receipt: "إيصال", view_receipt: "عرض الإيصال",
      confirm_payment: "تأكيد الدفع", fail_payment: "رفض الإيصال", requested: "مطلوب", mark_paid: "تم التحويل", payout_note: "ملاحظة للمدرس",
      details: "بيانات الاستلام", tutor_balance: "رصيد المدرس",
      open: "مفتوح", matched: "تمت المطابقة", expired: "انتهى", accepted: "قبِل", voice: "رسالة صوتية", photo: "صورة", request: "الطلب", time: "الوقت",
      match_rate: "نسبة المطابقة", visible: "ظاهر", hidden: "مخفي", hide: "إخفاء", show: "إظهار", stars: "النجوم", comment: "التعليق",
      reporter: "المُبلِّغ", target: "يخص", reason: "السبب", resolved: "تم الحل", dismissed: "مرفوض", resolve: "حل", dismiss: "رفض البلاغ",
      resolution: "ملاحظة الحل", t_lesson: "درس", t_conversation: "محادثة", t_user: "مستخدم", t_review: "تقييم",
      new: "جديد", contacted: "تم التواصل", converted: "تحول لعميل", closed: "مغلق", who: "من", mode: "الطريقة", notes: "ملاحظات", copy: "نسخ الرقم", copied: "تم النسخ",
      both: "كلاهما", sort: "الترتيب", color: "اللون", name_ar: "الاسم بالعربية", name_en: "الاسم بالإنجليزية", factor: "معامل السعر", visible_app: "ظاهر في التطبيق",
      s_commission: "عمولة المنصة %", s_commission_h: "تُخصم من كل درس قبل تحويل أرباح المدرس",
      s_vat: "ضريبة القيمة المضافة %", s_vat_h: "0 لإيقافها",
      s_live_seconds: "مدة البحث في الطلب الفوري (ثانية)", s_live_seconds_h: "بعدها ينتهي الطلب تلقائياً",
      s_live_max: "أقصى عدد مدرسين لكل طلب فوري", s_live_max_h: "",
      s_pending: "مهلة الدفع (ساعة)", s_pending_h: "تُلغى الحجوزات غير المدفوعة بعدها",
      s_referral: "عمولة الإحالة %", s_referral_h: "للمسوّقين",
      s_support: "واتساب الدعم", s_support_h: "يظهر في التطبيق والموقع",
      s_guarantee: "ضمان الساعة الأولى", s_guarantee_h: "استرداد كامل عند عدم الرضا",
      saved: "تم الحفظ", done: "تم", error: "حدث خطأ", login_t: "دخول الإدارة", email: "البريد الإلكتروني", password: "كلمة المرور", signin: "دخول",
      not_admin: "هذا الحساب ليس حساب مدير", menu: "القائمة", ago_now: "الآن", ago_m: "د", ago_h: "س", ago_d: "يوم",
      wallet_hint: "يظهر في محفظة المستخدم مع السبب", lessons_count: "دروس", open_tutor: "فتح الملف",
      set_password: "تغيير كلمة المرور", new_password: "كلمة المرور الجديدة (6 أحرف على الأقل)", pw_hint: "كلمات المرور محفوظة مشفّرة ولا يمكن لأحد عرضها — اكتب كلمة جديدة وأرسلها للمستخدم.", pw_saved: "تم تغيير كلمة المرور", email: "البريد الإلكتروني",
    },
    en: {
      brand: "Dars", console: "Admin console", demo: "Demo mode — sample data", live: "Connected to Supabase",
      g_ops: "Operations", g_money: "Money", g_quality: "Quality & growth", g_setup: "Setup",
      overview: "Overview", tutors: "Tutors", students: "Students & parents", lessons: "Lessons", live: "Live help",
      payments: "Payments", payouts: "Tutor payouts", reviews: "Reviews", reports: "Reports", leads: "Help requests",
      catalog: "Subjects & levels", config: "Settings",
      search: "Search…", all: "All", refresh: "Refresh", close: "Close", cancel: "Cancel", save: "Save", confirm: "Confirm", signout: "Sign out",
      lang: "العربية", theme: "Theme", none: "Nothing here yet",
      k_revenue: "Payments collected", k_commission: "Platform commission", k_delivered: "Lessons delivered", k_students: "Active students",
      k_tutors: "Approved tutors", k_online: "online now", k_live: "Live requests today", k_matched: "matched", last30: "Last 30 days",
      revenue14: "Daily payments — last 14 days", attention: "Needs action", top_subjects: "Most booked subjects",
      a_tutors: "Tutors waiting for review", a_receipts: "Bank-transfer receipts to check", a_payouts: "Payout requests",
      a_reports: "Open reports", a_disputes: "Disputed lessons", a_leads: "New help requests",
      name: "Name", phone: "Phone", subjects: "Subjects", price: "Price/hr", rating: "Rating", country: "Country", status: "Status", joined: "Joined",
      pending: "Pending", approved: "Approved", rejected: "Rejected", active: "Active", blocked: "Blocked", deleted: "Deleted",
      approve: "Approve", reject: "Reject", block: "Block", unblock: "Unblock", reject_reason: "Reason (sent to the tutor)",
      headline: "Headline", about: "About", experience: "Experience", years: "years", hours_taught: "Hours taught", package_disc: "Package discount up to",
      in_person: "In person", online: "Online", cv: "CV", video: "Intro video", missing: "Not uploaded", languages: "Languages",
      role: "Type", student: "Student", parent: "Parent", level: "Level", city: "City", balance: "Balance", adjust: "Adjust balance",
      adjust_amount: "Amount (+ add / − deduct)", adjust_note: "Reason (required)",
      number: "No.", student_c: "Student", tutor: "Tutor", subject: "Subject", when: "When", duration: "Length", min: "min", amount: "Amount",
      pending_payment: "Awaiting payment", confirmed: "Confirmed", delivered: "Delivered", cancelled: "Cancelled", disputed: "Disputed", no_show: "No-show",
      refund: "Refund student", release: "Release to tutor", refund_note: "Refund note", release_note: "Note (closes the report)",
      method: "Method", card: "Card", mada: "Mada", apple_pay: "Apple Pay", bnpl: "Instalments", bank_transfer: "Bank transfer", wallet: "Wallet", paypal: "PayPal", western_union: "Western Union",
      paid: "Paid", under_review: "Receipt to check", failed: "Failed", refunded: "Refunded", receipt: "Receipt", view_receipt: "View receipt",
      confirm_payment: "Confirm payment", fail_payment: "Reject receipt", requested: "Requested", mark_paid: "Mark paid", payout_note: "Note to the tutor",
      details: "Payout details", tutor_balance: "Tutor balance",
      open: "Open", matched: "Matched", expired: "Expired", accepted: "Accepted", voice: "Voice note", photo: "Photo", request: "Request", time: "Time",
      match_rate: "Match rate", visible: "Visible", hidden: "Hidden", hide: "Hide", show: "Show", stars: "Stars", comment: "Comment",
      reporter: "Reported by", target: "About", reason: "Reason", resolved: "Resolved", dismissed: "Dismissed", resolve: "Resolve", dismiss: "Dismiss",
      resolution: "Resolution note", t_lesson: "Lesson", t_conversation: "Chat", t_user: "User", t_review: "Review",
      new: "New", contacted: "Contacted", converted: "Converted", closed: "Closed", who: "Who", mode: "Mode", notes: "Notes", copy: "Copy number", copied: "Copied",
      both: "Both", sort: "Order", color: "Colour", name_ar: "Arabic name", name_en: "English name", factor: "Price factor", visible_app: "Shown in app",
      s_commission: "Platform commission %", s_commission_h: "Deducted from each lesson before tutor earnings",
      s_vat: "VAT %", s_vat_h: "0 to turn off",
      s_live_seconds: "Live request search time (seconds)", s_live_seconds_h: "The request expires after this",
      s_live_max: "Max tutors per live request", s_live_max_h: "",
      s_pending: "Payment window (hours)", s_pending_h: "Unpaid bookings are cancelled after this",
      s_referral: "Referral commission %", s_referral_h: "For marketers",
      s_support: "Support WhatsApp", s_support_h: "Shown in the app and website",
      s_guarantee: "First-hour guarantee", s_guarantee_h: "Full refund if not satisfied",
      saved: "Saved", done: "Done", error: "Something went wrong", login_t: "Admin sign in", email: "Email", password: "Password", signin: "Sign in",
      not_admin: "This account is not an admin", menu: "Menu", ago_now: "now", ago_m: "m", ago_h: "h", ago_d: "d",
      wallet_hint: "Shows in the user's wallet with the reason", lessons_count: "lessons", open_tutor: "Open profile",
      set_password: "Change password", new_password: "New password (at least 6 characters)", pw_hint: "Passwords are stored encrypted and can't be viewed by anyone — type a new one and send it to the user.", pw_saved: "Password changed", email: "Email",
    },
  };

  // ------------------------------------------------------------------ state
  const store = {
    get(k) { try { return localStorage.getItem("dars-admin-" + k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem("dars-admin-" + k, v); } catch (e) { /* ignore */ } },
  };
  const PAGES = ["overview", "tutors", "students", "lessons", "live", "payments", "payouts", "reviews", "reports", "leads", "catalog", "config"];
  const S = {
    lang: store.get("lang") || "ar", page: "overview", mode: "demo", user: null, ready: false,
    data: {}, tab: {}, q: {}, drawer: null, dialog: null, toast: null, navOpen: false, busy: false,
  };
  const t = (k) => (I18N[S.lang][k] ?? I18N.en[k] ?? k);

  // ------------------------------------------------------------------ utils
  const esc = (v) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const money = (v) => "$" + Number(v || 0).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const money0 = (v) => "$" + Math.round(Number(v || 0)).toLocaleString("en-US");
  const locale = () => (S.lang === "ar" ? "ar-SY-u-nu-latn" : "en-GB");
  const fmtDate = (d) => d ? new Intl.DateTimeFormat(locale(), { day: "numeric", month: "short" }).format(new Date(d)) : "—";
  const fmtDateTime = (d) => d ? new Intl.DateTimeFormat(locale(), { day: "numeric", month: "short", hour: "numeric", minute: "2-digit" }).format(new Date(d)) : "—";
  const ago = (d) => {
    const m = Math.round((Date.now() - new Date(d)) / 60000);
    if (m < 1) return t("ago_now");
    if (m < 60) return m + " " + t("ago_m");
    if (m < 1440) return Math.round(m / 60) + " " + t("ago_h");
    return Math.round(m / 1440) + " " + t("ago_d");
  };
  const subjName = (id) => { const s = (S.data.subjects || []).find((x) => x.id === id); return s ? (S.lang === "ar" ? s.name_ar : s.name_en) : (id || "—"); };
  const levelName = (id) => { const s = (S.data.levels || []).find((x) => x.id === id); return s ? (S.lang === "ar" ? s.name_ar : s.name_en) : (id || "—"); };
  const COLORS = ["#2F6BFF", "#7B61FF", "#0E8F7E", "#F59E0B", "#22B573", "#E5484D", "#5B45D6", "#0EA5E9", "#EC4899"];
  const colorFor = (s) => COLORS[[...String(s || "?")].reduce((a, c) => a + c.charCodeAt(0), 0) % COLORS.length];
  const initial = (n) => String(n || "?").replace(/^(م\.|أ\.|د\.|الشيخ)\s*/, "").charAt(0);
  const person = (name, sub) => `<div class="person"><span class="avatar" style="background:${colorFor(name)}">${esc(initial(name))}</span><div><b>${esc(name)}</b>${sub ? `<small>${esc(sub)}</small>` : ""}</div></div>`;
  const TONE = {
    approved: "good", pending: "warn", rejected: "bad", active: "good", blocked: "bad", deleted: "",
    confirmed: "info", pending_payment: "warn", delivered: "good", cancelled: "", disputed: "bad", no_show: "bad",
    paid: "good", under_review: "warn", failed: "bad", refunded: "info",
    requested: "warn", open: "warn", matched: "good", expired: "",
    visible: "good", hidden: "", resolved: "good", dismissed: "",
    new: "warn", contacted: "info", converted: "good", closed: "",
  };
  const REPORT_OPEN_TONE = "bad";
  const pill = (status, label) => `<span class="pill ${status === "open" && label === "report" ? REPORT_OPEN_TONE : TONE[status] || ""}">${esc(t(status))}</span>`;
  const match = (row, q, fields) => !q || fields.some((f) => String(row[f] ?? "").toLowerCase().includes(q.toLowerCase()));
  const icon = (name) => {
    const p = {
      overview: '<path d="M4 13h6V4H4zM14 20h6v-9h-6zM4 20h6v-4H4zM14 4v4h6V4z"/>',
      tutors: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4-6 8-6s7 2 8 6"/><path d="M17 4l2 2 3-3"/>',
      students: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.8-3.5 3.4-5.5 6.5-5.5s5.7 2 6.5 5.5"/><circle cx="17" cy="9" r="2.5"/><path d="M17 14c2.4 0 4 1.6 4.5 4"/>',
      lessons: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>',
      live: '<path d="M13 2L4 14h7l-1 8 9-12h-7l1-8z"/>',
      payments: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M7 15h4"/>',
      payouts: '<path d="M12 3v14M6 11l6 6 6-6"/><path d="M4 21h16"/>',
      reviews: '<path d="M12 3l2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3 6.4 20.2l1.1-6.2L3 9.6l6.2-.9z"/>',
      reports: '<path d="M5 21V4h11l-1.5 4L16 12H5"/>',
      leads: '<path d="M4 5h16v11H9l-5 4z"/><path d="M8 10h8"/>',
      catalog: '<path d="M4 5a2 2 0 012-2h13v16H6a2 2 0 00-2 2z"/><path d="M4 19a2 2 0 012-2h13"/>',
      config: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>',
      menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
    }[name] || "";
    return `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${p}</svg>`;
  };

  // ------------------------------------------------------------------ data layer: demo
  function demoApi() {
    const DB = JSON.parse(JSON.stringify(window.DARS_DEMO));
    const find = (arr, id, key = "id") => DB[arr].find((x) => x[key] === id);
    const wait = (v) => new Promise((r) => setTimeout(() => r(v), 120));
    const day = (d) => new Date(d).toISOString().slice(0, 10);
    return {
      async load(name) {
        if (name === "settings") return wait({ ...DB.settings });
        return wait(JSON.parse(JSON.stringify(DB[name])));
      },
      async stats() {
        const since = Date.now() - 30 * 864e5, today = day(Date.now());
        const paid = DB.payments.filter((p) => p.status === "paid");
        const days = [...Array(14)].map((_, i) => day(Date.now() - (13 - i) * 864e5));
        const subj = {};
        DB.lessons.forEach((l) => { if (new Date(l.created_at) > since) subj[l.subject_id] = (subj[l.subject_id] || 0) + 1; });
        return wait({
          students: DB.students.filter((s) => s.status === "active").length,
          tutors_approved: DB.tutors.filter((x) => x.verification === "approved").length,
          tutors_pending: DB.tutors.filter((x) => x.verification === "pending").length,
          tutors_online: DB.tutors.filter((x) => x.available_now).length,
          lessons_delivered_period: DB.lessons.filter((l) => l.status === "delivered" && new Date(l.starts_at) > since).length,
          revenue_period: paid.filter((p) => new Date(p.paid_at) > since).reduce((a, p) => a + p.amount, 0),
          commission_period: DB.lessons.filter((l) => l.status === "delivered" && new Date(l.starts_at) > since).reduce((a, l) => a + l.commission, 0),
          receipts_to_review: DB.payments.filter((p) => p.status === "under_review").length,
          payouts_requested_count: DB.payouts.filter((p) => ["requested", "approved"].includes(p.status)).length,
          payouts_requested: DB.payouts.filter((p) => ["requested", "approved"].includes(p.status)).reduce((a, p) => a + p.amount, 0),
          live_today: DB.live_requests.filter((q) => day(q.created_at) === today).length,
          live_matched_today: DB.live_requests.filter((q) => day(q.created_at) === today && q.status === "matched").length,
          open_reports: DB.reports.filter((r) => r.status === "open").length,
          disputed_lessons: DB.lessons.filter((l) => l.status === "disputed").length,
          new_leads: DB.leads.filter((l) => l.status === "new").length,
          daily_revenue: days.map((d) => ({ day: d, amount: paid.filter((p) => day(p.paid_at) === d).reduce((a, p) => a + p.amount, 0) })),
          top_subjects: Object.entries(subj).sort((a, b) => b[1] - a[1]).slice(0, 6).map(([subject_id, lessons]) => ({ subject_id, lessons })),
        });
      },
      async verifyTutor(id, status, reason) { const x = find("tutors", id, "user_id"); x.verification = status; x.rejection_reason = status === "rejected" ? reason : null; return wait(); },
      async setUserStatus(id, status) { const x = find("students", id) || find("tutors", id, "user_id"); if (x.account_status !== undefined) x.account_status = status; else x.status = status; return wait(); },
      async setPassword() { return wait(); },
      async walletAdjust(id, amount, note) { const x = find("students", id); x.balance = Math.round((x.balance + amount) * 100) / 100; return wait(note); },
      async refundLesson(id) {
        const l = find("lessons", id); l.status = "cancelled";
        DB.payments.filter((p) => p.lesson_id === id && p.status === "paid").forEach((p) => (p.status = "refunded"));
        DB.reports.filter((r) => r.target_id === id && r.status === "open").forEach((r) => { r.status = "resolved"; r.resolution_note = "Refunded"; });
        return wait();
      },
      async releaseLesson(id, note) {
        find("lessons", id).status = "delivered";
        DB.reports.filter((r) => r.target_id === id && r.status === "open").forEach((r) => { r.status = "dismissed"; r.resolution_note = note; });
        return wait();
      },
      async confirmPayment(id) {
        const p = find("payments", id); p.status = "paid"; p.paid_at = new Date().toISOString();
        const l = find("lessons", p.lesson_id); if (l && l.status === "pending_payment") l.status = "confirmed";
        return wait();
      },
      async failPayment(id) { find("payments", id).status = "failed"; return wait(); },
      async processPayout(id, status, note) { const p = find("payouts", id); p.status = status; p.admin_note = note || p.admin_note; return wait(); },
      async setReviewStatus(id, status) { find("reviews", id).status = status; return wait(); },
      async resolveReport(id, status, note) { const r = find("reports", id); r.status = status; r.resolution_note = note; return wait(); },
      async updateLead(id, status) { find("leads", id).status = status; return wait(); },
      async saveSubject(row) { Object.assign(find("subjects", row.id), row); return wait(); },
      async saveSettings(obj) { Object.assign(DB.settings, obj); return wait(); },
    };
  }

  // ------------------------------------------------------------------ data layer: Supabase
  function liveApi(sb) {
    const must = ({ data, error }) => { if (error) throw new Error(error.message); return data; };
    const rpc = async (fn, args) => must(await sb.rpc(fn, args));
    const lists = {
      tutors: () => sb.from("admin_tutors").select("*").order("joined_at", { ascending: false }).limit(1000),
      lessons: () => sb.from("admin_lessons").select("*").order("starts_at", { ascending: false }).limit(500),
      payments: () => sb.from("admin_payments").select("*").order("created_at", { ascending: false }).limit(500),
      payouts: () => sb.from("admin_payouts").select("*").order("created_at", { ascending: false }).limit(300),
      live_requests: () => sb.from("admin_live_requests").select("*").order("created_at", { ascending: false }).limit(300),
      reviews: () => sb.from("admin_reviews").select("*").order("created_at", { ascending: false }).limit(500),
      leads: () => sb.from("leads").select("*").order("created_at", { ascending: false }).limit(500),
      subjects: () => sb.from("subjects").select("*").order("sort"),
      levels: () => sb.from("study_levels").select("*").order("sort"),
    };
    return {
      async load(name) {
        if (lists[name]) return must(await lists[name]());
        if (name === "students") {
          const people = must(await sb.from("profiles").select("*").in("role", ["student", "parent"]).order("created_at", { ascending: false }).limit(1000));
          const bal = must(await sb.from("wallet_balances").select("*"));
          const by = Object.fromEntries(bal.map((b) => [b.user_id, Number(b.balance)]));
          return people.map((p) => ({ ...p, balance: by[p.id] || 0 }));
        }
        if (name === "reports") {
          const rows = must(await sb.from("reports").select("*, reporter:profiles!reporter_id(full_name)").order("created_at", { ascending: false }).limit(300));
          return rows.map((r) => ({ ...r, reporter_name: r.reporter?.full_name, target_label: r.target_type === "lesson" ? "#" + r.target_id.slice(0, 8) : r.target_id.slice(0, 8) }));
        }
        if (name === "settings") {
          const rows = must(await sb.from("app_settings").select("*"));
          return Object.fromEntries(rows.map((r) => [r.key, r.value]));
        }
        throw new Error("Unknown list " + name);
      },
      stats: () => rpc("admin_dashboard_stats", { p_days: 30 }),
      verifyTutor: (id, status, reason) => rpc("admin_set_tutor_verification", { p_tutor: id, p_status: status, p_reason: reason || null }),
      setUserStatus: (id, status) => rpc("admin_set_user_status", { p_user: id, p_status: status }),
      walletAdjust: (id, amount, note) => rpc("admin_wallet_adjust", { p_user: id, p_amount: amount, p_note: note }),
      setPassword: (id, password) => rpc("admin_set_user_password", { p_user: id, p_password: password }),
      refundLesson: (id, note) => rpc("admin_refund_lesson", { p_lesson: id, p_note: note || null }),
      releaseLesson: (id, note) => rpc("admin_release_lesson", { p_lesson: id, p_note: note || null }),
      confirmPayment: (id) => rpc("confirm_payment", { p_payment: id, p_provider: "manual", p_ref: null }),
      failPayment: (id) => rpc("fail_payment", { p_payment: id, p_ref: null }),
      processPayout: (id, status, note) => rpc("admin_process_payout", { p_payout: id, p_status: status, p_note: note || null }),
      setReviewStatus: (id, status) => rpc("admin_set_review_status", { p_review: id, p_status: status }),
      resolveReport: (id, status, note) => rpc("admin_resolve_report", { p_report: id, p_status: status, p_note: note || null }),
      updateLead: (id, status) => rpc("admin_update_lead", { p_lead: id, p_status: status }),
      async saveSubject(row) { const { id, ...rest } = row; must(await sb.from("subjects").update(rest).eq("id", id)); },
      async saveSettings(obj) { for (const [k, v] of Object.entries(obj)) await rpc("admin_set_setting", { p_key: k, p_value: v }); },
      async receiptUrl(path) { const [bucket, ...rest] = path.split("/"); const r = await sb.storage.from(bucket).createSignedUrl(rest.join("/"), 300); return r.data?.signedUrl; },
    };
  }

  let api = null, sb = null;

  // ------------------------------------------------------------------ loading
  const NEEDS = {
    overview: ["stats", "subjects"], tutors: ["tutors", "subjects"], students: ["students", "levels"], lessons: ["lessons", "subjects"],
    live: ["live_requests", "subjects"], payments: ["payments"], payouts: ["payouts"], reviews: ["reviews"], reports: ["reports"],
    leads: ["leads", "subjects", "levels"], catalog: ["subjects", "levels"], config: ["settings"],
  };
  async function loadPage(force) {
    const need = NEEDS[S.page] || [];
    const missing = need.filter((n) => force || S.data[n] === undefined);
    if (!missing.length) return render();
    S.busy = true; render();
    try {
      const got = await Promise.all(missing.map((n) => (n === "stats" ? api.stats() : api.load(n))));
      missing.forEach((n, i) => (S.data[n] = got[i]));
      if (S.data.stats === undefined && S.page !== "overview") api.stats().then((s) => { S.data.stats = s; render(); }).catch(() => {});
    } catch (e) { toast(e.message || t("error"), true); }
    S.busy = false; render();
  }
  async function act(fn, reloadNames, msg) {
    try {
      await fn();
      reloadNames.concat("stats").forEach((n) => delete S.data[n]);
      S.drawer = null; S.dialog = null;
      toast(msg || t("done"));
      await loadPage(true);
    } catch (e) { toast(e.message || t("error"), true); }
  }
  let toastTimer;
  function toast(text, bad) { S.toast = { text, bad }; render(); clearTimeout(toastTimer); toastTimer = setTimeout(() => { S.toast = null; render(); }, 3200); }

  // ------------------------------------------------------------------ pages
  const tabsBar = (key, options, counts) =>
    `<div class="tabs" role="tablist">${options.map((o) => `<button class="tab ${(S.tab[key] ?? options[0]) === o ? "on" : ""}" role="tab" data-act="tab" data-key="${key}" data-val="${o}">${esc(t(o))}${counts ? `<span class="n num">${counts[o] ?? 0}</span>` : ""}</button>`).join("")}</div>`;
  const searchBox = (key) => `<input class="input search" type="search" id="q-${key}" placeholder="${esc(t("search"))}" value="${esc(S.q[key] || "")}" data-input="q" data-key="${key}" aria-label="${esc(t("search"))}">`;
  const countBy = (rows, field, keys) => { const c = { all: rows.length }; keys.forEach((k) => (c[k] = rows.filter((r) => r[field] === k).length)); return c; };
  const table = (head, rows) => rows.length
    ? `<div class="table-wrap"><table><thead><tr>${head.map((h) => `<th class="${h.cls || ""}">${esc(h.label)}</th>`).join("")}</tr></thead><tbody>${rows.join("")}</tbody></table></div>`
    : `<div class="empty">${esc(t("none"))}</div>`;

  function pageOverview() {
    const s = S.data.stats;
    if (!s) return "";
    const days = s.daily_revenue || [];
    const max = Math.max(1, ...days.map((d) => Number(d.amount)));
    const W = 560, Hh = 180, pad = 40, bw = (W - pad) / Math.max(days.length, 1);
    const ticks = [0, 0.5, 1].map((f) => Math.round(max * f));
    const short = (d) => { const x = new Date(d); return x.getUTCDate() + "/" + (x.getUTCMonth() + 1); };
    const chart = `<svg viewBox="0 0 ${W} ${Hh + 24}" direction="ltr" role="img" aria-label="${esc(t("revenue14"))}">
      ${ticks.map((v) => { const y = Hh - (v / max) * (Hh - 10); return `<line class="grid" x1="${pad}" x2="${W}" y1="${y}" y2="${y}"/><text x="${pad - 6}" y="${y + 4}" text-anchor="end">$${v}</text>`; }).join("")}
      ${days.map((d, i) => { const h = (Number(d.amount) / max) * (Hh - 10); const x = pad + i * bw + 3; return `<rect class="bar ${i === days.length - 1 ? "today" : ""}" x="${x}" y="${Hh - h}" width="${bw - 6}" height="${Math.max(h, 1)}" rx="3"><title>${esc(d.day)}: ${money(d.amount)}</title></rect>${i % 2 === 1 ? `<text x="${x + (bw - 6) / 2}" y="${Hh + 16}" text-anchor="middle">${esc(short(d.day))}</text>` : ""}`; }).join("")}
    </svg>`;
    const att = [
      ["tutors", "a_tutors", s.tutors_pending, "pending"], ["payments", "a_receipts", s.receipts_to_review, "under_review"],
      ["payouts", "a_payouts", s.payouts_requested_count, "requested"], ["reports", "a_reports", s.open_reports, "open"],
      ["lessons", "a_disputes", s.disputed_lessons, "disputed"], ["leads", "a_leads", s.new_leads, "new"],
    ];
    const top = s.top_subjects || [];
    const topMax = Math.max(1, ...top.map((x) => x.lessons));
    const rate = s.live_today ? Math.round((s.live_matched_today / s.live_today) * 100) : 0;
    return `
      <div class="kpis">
        <div class="kpi money"><span>${t("k_revenue")}</span><strong>${money0(s.revenue_period)}</strong><small>${t("last30")}</small></div>
        <div class="kpi money"><span>${t("k_commission")}</span><strong>${money0(s.commission_period)}</strong><small>${t("last30")}</small></div>
        <div class="kpi"><span>${t("k_delivered")}</span><strong>${s.lessons_delivered_period}</strong><small>${t("last30")}</small></div>
        <div class="kpi"><span>${t("k_students")}</span><strong>${s.students}</strong><small>&nbsp;</small></div>
        <div class="kpi"><span>${t("k_tutors")}</span><strong>${s.tutors_approved}</strong><small>${s.tutors_online} ${t("k_online")}</small></div>
        <div class="kpi"><span>${t("k_live")}</span><strong>${s.live_today}</strong><small>${rate}% ${t("k_matched")}</small></div>
      </div>
      <div class="grid-2">
        <section class="panel"><div class="panel-head"><h2>${t("revenue14")}</h2></div><div class="panel-body chart">${chart}</div></section>
        <section class="panel"><div class="panel-head"><h2>${t("attention")}</h2></div>
          <div class="attention">${att.map(([page, label, n, tab]) => `<button data-act="goto" data-page="${page}" data-tab="${tab}"><span class="n ${n > 0 ? "hot" : ""}">${n}</span><span class="label">${t(label)}</span>${page === "payouts" && n ? `<span class="muted num">${money0(s.payouts_requested)}</span>` : ""}</button>`).join("")}</div>
        </section>
      </div>
      <section class="panel"><div class="panel-head"><h2>${t("top_subjects")}</h2><span class="muted small">${t("last30")}</span></div>
        <div class="panel-body bars-h">${top.map((x) => `<div class="item"><span>${esc(subjName(x.subject_id))}</span><div class="track"><div class="fill" style="width:${(x.lessons / topMax) * 100}%"></div></div><b class="num">${x.lessons}</b></div>`).join("") || `<div class="empty">${t("none")}</div>`}</div>
      </section>`;
  }

  function pageTutors() {
    const rows = S.data.tutors || [];
    const tab = S.tab.tutors ?? "pending", q = S.q.tutors || "";
    const list = rows.filter((r) => (tab === "all" || r.verification === tab) && match(r, q, ["full_name", "phone", "country", "headline"]));
    return `<section class="panel"><div class="panel-head">${tabsBar("tutors", ["pending", "approved", "rejected", "all"], countBy(rows, "verification", ["pending", "approved", "rejected"]))}<span style="flex:1"></span>${searchBox("tutors")}</div>
      ${table([{ label: t("name") }, { label: t("subjects"), cls: "hide-sm" }, { label: t("price") }, { label: t("rating"), cls: "hide-sm" }, { label: t("joined"), cls: "hide-sm" }, { label: t("status") }, { label: "" }],
        list.map((r) => `<tr class="clickable" data-act="tutor" data-id="${esc(r.user_id)}">
          <td>${person(r.full_name || "—", r.phone || r.email)}</td>
          <td class="hide-sm">${(r.subject_ids || []).map((s) => `<span class="tag">${esc(subjName(s))}</span>`).join("")}</td>
          <td class="num">${money(r.hourly_price)}</td>
          <td class="hide-sm num">${r.rating_count ? `★ ${Number(r.rating_avg).toFixed(1)} <span class="muted">(${r.rating_count})</span>` : "—"}</td>
          <td class="hide-sm">${fmtDate(r.joined_at)}</td>
          <td>${pill(r.verification)}${r.account_status === "blocked" ? " " + pill("blocked") : ""}</td>
          <td class="actions">${r.verification === "pending" ? `<button class="btn good" data-act="approve" data-id="${esc(r.user_id)}">${t("approve")}</button><button class="btn bad" data-act="reject" data-id="${esc(r.user_id)}">${t("reject")}</button>` : ""}</td>
        </tr>`))}</section>`;
  }

  function tutorDrawer(id) {
    const r = (S.data.tutors || []).find((x) => x.user_id === id);
    if (!r) return "";
    const langs = (r.languages || []).map((l) => (l.code || "").toUpperCase() + (l.level ? " · " + l.level : "")).join(S.lang === "ar" ? "، " : ", ");
    return `<div class="drawer-head">${person(r.full_name || "—", r.phone || r.email)}<span style="flex:1"></span>${pill(r.verification)}</div>
      <div class="drawer-body">
        <dl class="kv">
          <dt>${t("headline")}</dt><dd>${esc(r.headline || "—")}</dd>
          <dt>${t("about")}</dt><dd style="font-weight:500">${esc(r.about || "—")}</dd>
          <dt>${t("subjects")}</dt><dd>${(r.subject_ids || []).map((s) => `<span class="tag">${esc(subjName(s))}</span>`).join("") || "—"}</dd>
          <dt>${t("price")}</dt><dd class="num">${money(r.hourly_price)} · ${t("package_disc")} ${r.max_package_discount}%</dd>
          <dt>${t("experience")}</dt><dd>${r.years_experience} ${t("years")}</dd>
          <dt>${t("mode")}</dt><dd>${t("online")}${r.teaches_in_person ? " · " + t("in_person") : ""}</dd>
          <dt>${t("languages")}</dt><dd>${esc(langs || "—")}</dd>
          <dt>${t("email")}</dt><dd style="direction:ltr;unicode-bidi:plaintext">${esc(r.email || "—")}</dd>
          <dt>${t("country")}</dt><dd>${esc([r.city, r.country].filter(Boolean).join("، ") || "—")}</dd>
          <dt>${t("rating")}</dt><dd class="num">${r.rating_count ? `★ ${Number(r.rating_avg).toFixed(1)} (${r.rating_count})` : "—"}</dd>
          <dt>${t("hours_taught")}</dt><dd class="num">${Math.round((r.minutes_taught || 0) / 60)}</dd>
          <dt>${t("cv")}</dt><dd>${r.cv_url ? "✓ " + esc(r.cv_url) : `<span class="muted">${t("missing")}</span>`}</dd>
          <dt>${t("video")}</dt><dd>${r.video_url ? "✓" : `<span class="muted">${t("missing")}</span>`}</dd>
          ${r.rejection_reason ? `<dt>${t("reason")}</dt><dd>${esc(r.rejection_reason)}</dd>` : ""}
          <dt>${t("joined")}</dt><dd>${fmtDate(r.joined_at)}</dd>
        </dl>
      </div>
      <div class="drawer-foot">
        ${r.verification !== "approved" ? `<button class="btn primary" data-act="approve" data-id="${esc(r.user_id)}">${t("approve")}</button>` : ""}
        ${r.verification !== "rejected" ? `<button class="btn bad" data-act="reject" data-id="${esc(r.user_id)}">${t("reject")}</button>` : ""}
        <button class="btn" data-act="block" data-id="${esc(r.user_id)}" data-status="${r.account_status === "blocked" ? "active" : "blocked"}">${t(r.account_status === "blocked" ? "unblock" : "block")}</button>
        <button class="btn" data-act="password" data-id="${esc(r.user_id)}">${t("set_password")}</button>
        <span style="flex:1"></span><button class="btn" data-act="close">${t("close")}</button>
      </div>`;
  }

  function pageStudents() {
    const rows = S.data.students || [];
    const tab = S.tab.students ?? "all", q = S.q.students || "";
    const list = rows.filter((r) => (tab === "all" || r.status === tab) && match(r, q, ["full_name", "phone", "city"]));
    return `<section class="panel"><div class="panel-head">${tabsBar("students", ["all", "active", "blocked"], countBy(rows, "status", ["active", "blocked"]))}<span style="flex:1"></span>${searchBox("students")}</div>
      ${table([{ label: t("name") }, { label: t("role") }, { label: t("level"), cls: "hide-sm" }, { label: t("city"), cls: "hide-sm" }, { label: t("balance") }, { label: t("joined"), cls: "hide-sm" }, { label: t("status") }, { label: "" }],
        list.map((r) => `<tr>
          <td>${person(r.full_name || "—", r.phone || r.email)}</td><td>${t(r.role)}</td><td class="hide-sm">${esc(levelName(r.level_id))}</td>
          <td class="hide-sm">${esc(r.city || "—")}</td><td class="num">${money(r.balance)}</td><td class="hide-sm">${fmtDate(r.created_at)}</td>
          <td>${pill(r.status)}</td>
          <td class="actions"><button class="btn" data-act="password" data-id="${esc(r.id)}">${t("set_password")}</button><button class="btn" data-act="adjust" data-id="${esc(r.id)}">${t("adjust")}</button><button class="btn ${r.status === "blocked" ? "good" : "bad"}" data-act="block" data-id="${esc(r.id)}" data-status="${r.status === "blocked" ? "active" : "blocked"}">${t(r.status === "blocked" ? "unblock" : "block")}</button></td>
        </tr>`))}</section>`;
  }

  function pageLessons() {
    const rows = S.data.lessons || [];
    const keys = ["pending_payment", "confirmed", "delivered", "disputed", "cancelled"];
    const tab = S.tab.lessons ?? "all", q = S.q.lessons || "";
    const list = rows.filter((r) => (tab === "all" || r.status === tab) && match(r, q, ["student_name", "tutor_name", "number"]));
    return `<section class="panel"><div class="panel-head">${tabsBar("lessons", ["all", ...keys], countBy(rows, "status", keys))}<span style="flex:1"></span>${searchBox("lessons")}</div>
      ${table([{ label: t("number") }, { label: t("student_c") }, { label: t("tutor"), cls: "hide-sm" }, { label: t("subject"), cls: "hide-sm" }, { label: t("when") }, { label: t("duration"), cls: "hide-sm" }, { label: t("amount") }, { label: t("status") }, { label: "" }],
        list.slice(0, 300).map((r) => `<tr>
          <td class="num">#${esc(r.number)}</td><td>${esc(r.student_name)}</td><td class="hide-sm">${esc(r.tutor_name)}</td>
          <td class="hide-sm">${esc(subjName(r.subject_id))}${r.mode === "in_person" ? ` <span class="tag">${t("in_person")}</span>` : ""}</td>
          <td>${fmtDateTime(r.starts_at)}</td><td class="hide-sm num">${r.duration_min} ${t("min")}</td>
          <td class="num">${money(r.price)}</td><td>${pill(r.status)}</td>
          <td class="actions">${["confirmed", "delivered", "disputed", "pending_payment"].includes(r.status) ? `<button class="btn bad" data-act="refund" data-id="${esc(r.id)}">${t("refund")}</button>` : ""}${r.status === "disputed" ? `<button class="btn good" data-act="release" data-id="${esc(r.id)}">${t("release")}</button>` : ""}</td>
        </tr>`))}</section>`;
  }

  function pageLive() {
    const rows = S.data.live_requests || [];
    const keys = ["open", "matched", "expired", "cancelled"];
    const tab = S.tab.live ?? "all";
    const list = rows.filter((r) => tab === "all" || r.status === tab);
    const matched = rows.filter((r) => r.status === "matched").length;
    const closed = rows.filter((r) => r.status !== "open").length;
    return `<div class="kpis">
        <div class="kpi"><span>${t("k_live")}</span><strong>${rows.length}</strong><small>&nbsp;</small></div>
        <div class="kpi"><span>${t("match_rate")}</span><strong>${closed ? Math.round((matched / closed) * 100) : 0}%</strong><small>${matched} / ${closed}</small></div>
        <div class="kpi"><span>${t("k_tutors")}</span><strong>${S.data.stats ? S.data.stats.tutors_online : "—"}</strong><small>${t("k_online")}</small></div>
      </div>
      <section class="panel"><div class="panel-head">${tabsBar("live", ["all", ...keys], countBy(rows, "status", keys))}</div>
      ${table([{ label: t("time") }, { label: t("student_c") }, { label: t("subject") }, { label: t("request") }, { label: t("accepted") }, { label: t("status") }],
        list.map((r) => `<tr>
          <td>${ago(r.created_at)}</td><td>${esc(r.student_name)}</td><td>${esc(subjName(r.subject_id))}</td>
          <td style="max-width:360px">${r.body ? esc(r.body) : ""}${r.voice_sec ? `<span class="tag">🎤 ${t("voice")} 0:${String(r.voice_sec).padStart(2, "0")}</span>` : ""}${r.photo_url ? `<span class="tag">${t("photo")}</span>` : ""}</td>
          <td class="num">${r.accepted_count}</td><td>${pill(r.status)}</td>
        </tr>`))}</section>`;
  }

  function pagePayments() {
    const rows = S.data.payments || [];
    const keys = ["under_review", "pending", "paid", "failed", "refunded"];
    const tab = S.tab.payments ?? "all", q = S.q.payments || "";
    const list = rows.filter((r) => (tab === "all" || r.status === tab) && match(r, q, ["user_name", "provider_ref", "lesson_number"]));
    return `<section class="panel"><div class="panel-head">${tabsBar("payments", ["all", ...keys], countBy(rows, "status", keys))}<span style="flex:1"></span>${searchBox("payments")}</div>
      ${table([{ label: t("time") }, { label: t("name") }, { label: t("method") }, { label: t("amount") }, { label: t("status") }, { label: "" }],
        list.slice(0, 300).map((r) => `<tr>
          <td>${fmtDateTime(r.created_at)}</td><td>${person(r.user_name, r.lesson_number ? "#" + r.lesson_number : r.provider_ref)}</td>
          <td>${t(r.method)}</td><td class="num">${money(r.amount)}</td><td>${pill(r.status)}</td>
          <td class="actions">${r.receipt_url ? `<button class="btn" data-act="receipt" data-path="${esc(r.receipt_url)}">${t("view_receipt")}</button>` : ""}${["under_review", "pending"].includes(r.status) ? `<button class="btn good" data-act="pay-ok" data-id="${esc(r.id)}">${t("confirm_payment")}</button><button class="btn bad" data-act="pay-fail" data-id="${esc(r.id)}">${t("fail_payment")}</button>` : ""}</td>
        </tr>`))}</section>`;
  }

  function pagePayouts() {
    const rows = S.data.payouts || [];
    const keys = ["requested", "approved", "paid", "rejected"];
    const tab = S.tab.payouts ?? "requested";
    const list = rows.filter((r) => tab === "all" || r.status === tab);
    const fmtDetails = (d) => Object.entries(d || {}).map(([k, v]) => `${k}: ${v}`).join(" · ");
    return `<section class="panel"><div class="panel-head">${tabsBar("payouts", [...keys, "all"], countBy(rows, "status", keys))}</div>
      ${table([{ label: t("time") }, { label: t("tutor") }, { label: t("amount") }, { label: t("method") }, { label: t("details"), cls: "hide-sm" }, { label: t("tutor_balance"), cls: "hide-sm" }, { label: t("status") }, { label: "" }],
        list.map((r) => `<tr>
          <td>${fmtDate(r.created_at)}</td><td>${person(r.tutor_name, r.tutor_phone)}</td><td class="num"><b>${money(r.amount)}</b></td>
          <td>${t(r.method)}</td><td class="hide-sm small" style="direction:ltr;unicode-bidi:plaintext">${esc(fmtDetails(r.details))}</td>
          <td class="hide-sm num">${money(r.tutor_balance)}</td><td>${pill(r.status)}${r.admin_note ? `<div class="small muted">${esc(r.admin_note)}</div>` : ""}</td>
          <td class="actions">${r.status === "requested" ? `<button class="btn" data-act="payout" data-id="${esc(r.id)}" data-status="approved">${t("approve")}</button>` : ""}${["requested", "approved"].includes(r.status) ? `<button class="btn good" data-act="payout" data-id="${esc(r.id)}" data-status="paid">${t("mark_paid")}</button><button class="btn bad" data-act="payout" data-id="${esc(r.id)}" data-status="rejected">${t("reject")}</button>` : ""}</td>
        </tr>`))}</section>`;
  }

  function pageReviews() {
    const rows = S.data.reviews || [];
    const tab = S.tab.reviews ?? "all", q = S.q.reviews || "";
    const list = rows.filter((r) => (tab === "all" || r.status === tab) && match(r, q, ["student_name", "tutor_name", "comment"]));
    return `<section class="panel"><div class="panel-head">${tabsBar("reviews", ["all", "visible", "hidden"], countBy(rows, "status", ["visible", "hidden"]))}<span style="flex:1"></span>${searchBox("reviews")}</div>
      ${table([{ label: t("time") }, { label: t("tutor") }, { label: t("student_c"), cls: "hide-sm" }, { label: t("stars") }, { label: t("comment") }, { label: t("status") }, { label: "" }],
        list.map((r) => `<tr>
          <td>${fmtDate(r.created_at)}</td><td>${esc(r.tutor_name)}</td><td class="hide-sm">${esc(r.student_name)}</td>
          <td class="num" style="color:var(--accent);white-space:nowrap">${"★".repeat(r.stars)}<span class="muted">${"★".repeat(5 - r.stars)}</span></td>
          <td style="max-width:340px">${esc(r.comment || "—")}</td><td>${pill(r.status)}</td>
          <td class="actions"><button class="btn" data-act="review" data-id="${esc(r.id)}" data-status="${r.status === "visible" ? "hidden" : "visible"}">${t(r.status === "visible" ? "hide" : "show")}</button></td>
        </tr>`))}</section>`;
  }

  function pageReports() {
    const rows = S.data.reports || [];
    const tab = S.tab.reports ?? "open";
    const list = rows.filter((r) => tab === "all" || r.status === tab);
    return `<section class="panel"><div class="panel-head">${tabsBar("reports", ["open", "resolved", "dismissed", "all"], countBy(rows, "status", ["open", "resolved", "dismissed"]))}</div>
      ${table([{ label: t("time") }, { label: t("reporter") }, { label: t("target") }, { label: t("reason") }, { label: t("status") }, { label: "" }],
        list.map((r) => `<tr>
          <td>${ago(r.created_at)}</td><td>${esc(r.reporter_name || "—")}</td>
          <td><span class="tag">${t("t_" + r.target_type)}</span> ${esc(r.target_label || "")}</td>
          <td style="max-width:340px">${esc(r.reason)}${r.resolution_note ? `<div class="small muted">${esc(r.resolution_note)}</div>` : ""}</td>
          <td>${pill(r.status, "report")}</td>
          <td class="actions">${r.status === "open" ? (r.target_type === "lesson"
            ? `<button class="btn bad" data-act="refund" data-id="${esc(r.target_id)}">${t("refund")}</button><button class="btn good" data-act="release" data-id="${esc(r.target_id)}">${t("release")}</button>`
            : `<button class="btn good" data-act="report" data-id="${esc(r.id)}" data-status="resolved">${t("resolve")}</button><button class="btn" data-act="report" data-id="${esc(r.id)}" data-status="dismissed">${t("dismiss")}</button>`) : ""}</td>
        </tr>`))}</section>`;
  }

  function pageLeads() {
    const rows = S.data.leads || [];
    const keys = ["new", "contacted", "converted", "closed"];
    const tab = S.tab.leads ?? "new";
    const list = rows.filter((r) => tab === "all" || r.status === tab);
    return `<section class="panel"><div class="panel-head">${tabsBar("leads", [...keys, "all"], countBy(rows, "status", keys))}</div>
      ${table([{ label: t("time") }, { label: t("name") }, { label: t("who"), cls: "hide-sm" }, { label: t("subject") }, { label: t("level"), cls: "hide-sm" }, { label: t("mode"), cls: "hide-sm" }, { label: t("notes"), cls: "hide-sm" }, { label: t("status") }],
        list.map((r) => `<tr>
          <td>${ago(r.created_at)}</td>
          <td>${person(r.full_name, r.whatsapp)}<button class="btn small" style="margin-top:4px" data-act="copy" data-text="${esc(r.whatsapp)}">${t("copy")}</button></td>
          <td class="hide-sm">${t(r.who || "student")}</td><td>${esc(subjName(r.subject_id))}</td><td class="hide-sm">${esc(levelName(r.level_id))}</td>
          <td class="hide-sm">${t(r.mode || "online")}</td><td class="hide-sm" style="max-width:260px">${esc(r.notes || r.reason || "—")}</td>
          <td><select class="input" id="lead-${esc(r.id)}" data-change="lead" data-id="${esc(r.id)}" aria-label="${esc(t("status"))}">${keys.map((k) => `<option value="${k}" ${r.status === k ? "selected" : ""}>${t(k)}</option>`).join("")}</select></td>
        </tr>`))}</section>`;
  }

  function pageCatalog() {
    const subs = S.data.subjects || [], lv = S.data.levels || [];
    return `<section class="panel"><div class="panel-head"><h2>${t("subjects")}</h2></div>
      ${table([{ label: t("sort") }, { label: t("name_ar") }, { label: t("name_en") }, { label: t("color"), cls: "hide-sm" }, { label: t("visible_app") }, { label: "" }],
        subs.map((s) => `<tr>
          <td class="num">${s.sort}</td>
          <td><input class="input" id="sar-${esc(s.id)}" value="${esc(s.name_ar)}" aria-label="${esc(t("name_ar"))}"></td>
          <td><input class="input" id="sen-${esc(s.id)}" value="${esc(s.name_en)}" aria-label="${esc(t("name_en"))}"></td>
          <td class="hide-sm"><span class="swatch" style="background:${esc(s.color || "#999")}"></span><span class="small muted">${esc(s.color || "")}</span></td>
          <td><input type="checkbox" id="sact-${esc(s.id)}" ${s.active ? "checked" : ""} aria-label="${esc(t("visible_app"))}"></td>
          <td class="actions"><button class="btn" data-act="save-subject" data-id="${esc(s.id)}">${t("save")}</button></td>
        </tr>`))}</section>
      <section class="panel"><div class="panel-head"><h2>${t("level")}</h2></div>
      ${table([{ label: t("sort") }, { label: t("name_ar") }, { label: t("name_en") }, { label: t("factor") }],
        lv.map((l) => `<tr><td class="num">${l.sort}</td><td>${esc(l.name_ar)}</td><td>${esc(l.name_en)}</td><td class="num">× ${Number(l.price_factor).toFixed(2)}</td></tr>`))}</section>`;
  }

  const SETTINGS = [
    ["commission_rate", "s_commission", "pct"], ["vat_rate", "s_vat", "pct"], ["live_request_seconds", "s_live_seconds", "int"],
    ["live_max_tutors", "s_live_max", "int"], ["pending_payment_hours", "s_pending", "int"], ["referral_commission", "s_referral", "pct"],
    ["support_whatsapp", "s_support", "text"], ["first_hour_guarantee", "s_guarantee", "bool"],
  ];
  function pageConfig() {
    const s = S.data.settings || {};
    return `<form class="panel" id="settings-form"><div class="panel-head"><h2>${t("config")}</h2></div><div class="panel-body form-grid">
      ${SETTINGS.map(([key, label, kind]) => {
        const v = s[key];
        const input = kind === "bool"
          ? `<select class="input" id="set-${key}" name="${key}"><option value="true" ${v === true || v === "true" ? "selected" : ""}>✓</option><option value="false" ${v === false || v === "false" ? "selected" : ""}>✗</option></select>`
          : `<input class="input" id="set-${key}" name="${key}" ${kind === "text" ? 'dir="ltr"' : 'type="number" step="any" min="0"'} value="${esc(kind === "pct" ? Math.round(Number(v) * 1000) / 10 : v ?? "")}">`;
        return `<div class="field"><label for="set-${key}">${t(label)}</label>${input}${t(label + "_h") ? `<small>${t(label + "_h")}</small>` : ""}</div>`;
      }).join("")}
      </div><div class="panel-head" style="border-top:1px solid var(--line);border-bottom:0"><span style="flex:1"></span><button class="btn primary" type="submit">${t("save")}</button></div></form>`;
  }

  const RENDER = { overview: pageOverview, tutors: pageTutors, students: pageStudents, lessons: pageLessons, live: pageLive, payments: pagePayments, payouts: pagePayouts, reviews: pageReviews, reports: pageReports, leads: pageLeads, catalog: pageCatalog, config: pageConfig };

  // ------------------------------------------------------------------ shell
  function navCounts() {
    const s = S.data.stats || {};
    return { tutors: s.tutors_pending, payments: s.receipts_to_review, payouts: s.payouts_requested_count, reports: s.open_reports, leads: s.new_leads };
  }
  function shell() {
    const c = navCounts();
    const item = (p) => `<button class="nav-item ${S.page === p ? "on" : ""}" data-act="nav" data-page="${p}">${icon(p)}<span>${t(p)}</span>${c[p] ? `<span class="count num">${c[p]}</span>` : ""}</button>`;
    const groups = [["g_ops", ["overview", "tutors", "students", "lessons", "live"]], ["g_money", ["payments", "payouts"]], ["g_quality", ["reviews", "reports", "leads"]], ["g_setup", ["catalog", "config"]]];
    const body = S.busy && !hasData() ? `<div class="empty">…</div>` : RENDER[S.page]();
    return `<div class="shell">
      <aside class="side ${S.navOpen ? "open" : ""}" aria-label="${esc(t("menu"))}">
        <div class="brand"><span class="brand-mark">د<i></i></span><div><b>${t("brand")}</b><small>${t("console")}</small></div></div>
        ${groups.map(([g, ps]) => `<div class="nav-label">${t(g)}</div>${ps.map(item).join("")}`).join("")}
        <div class="side-foot">
          <div>${esc(S.user?.name || "")}</div>
          <div class="row"><button data-act="lang">${t("lang")}</button>${S.mode === "live" ? `<button data-act="signout">${t("signout")}</button>` : ""}</div>
        </div>
      </aside>
      ${S.navOpen ? `<div class="scrim" data-act="nav-close"></div>` : ""}
      <div class="main">
        <header class="topbar">
          <button class="btn menu-btn" data-act="nav-open" aria-label="${esc(t("menu"))}">${icon("menu")}</button>
          <h1>${t(S.page)}</h1><span class="spacer"></span>
          ${S.mode === "demo" ? `<span class="demo-badge">${t("demo")}</span>` : `<span class="small muted hide-sm">${t("live")}</span>`}
          <button class="btn" data-act="refresh">${t("refresh")}</button>
        </header>
        <main class="content">${body}</main>
      </div>
    </div>
    ${S.drawer ? `<div class="scrim" data-act="close"></div><aside class="drawer" role="dialog" aria-modal="true">${tutorDrawer(S.drawer.id)}</aside>` : ""}
    ${S.dialog ? dialogHtml() : ""}
    ${S.toast ? `<div class="toast ${S.toast.bad ? "bad" : ""}" role="status">${esc(S.toast.text)}</div>` : ""}`;
  }
  const hasData = () => (NEEDS[S.page] || []).every((n) => S.data[n] !== undefined);

  function dialogHtml() {
    const d = S.dialog;
    return `<div class="scrim" data-act="dialog-cancel"></div><form class="dialog" id="dialog-form" role="dialog" aria-modal="true">
      <h3>${esc(d.title)}</h3>
      ${d.amount ? `<label class="field"><span>${t("adjust_amount")}</span><input class="input" id="dlg-amount" type="number" step="0.01" required></label>` : ""}
      <label class="field"><span>${esc(d.label)}</span>${d.pw
        ? `<input class="input" id="dlg-text" type="text" minlength="6" required autocomplete="new-password" dir="ltr" spellcheck="false">`
        : `<textarea class="input" id="dlg-text" rows="3" ${d.required ? "required" : ""}></textarea>`}${d.hint ? `<small class="muted">${esc(d.hint)}</small>` : ""}</label>
      <div class="row" style="justify-content:flex-end"><button class="btn" type="button" data-act="dialog-cancel">${t("cancel")}</button><button class="btn ${d.danger ? "bad" : "primary"}" type="submit">${esc(d.confirm)}</button></div>
    </form>`;
  }
  function ask(opts) { S.dialog = opts; render(); setTimeout(() => (document.getElementById(opts.amount ? "dlg-amount" : "dlg-text") || {}).focus?.(), 0); }

  function loginHtml(err) {
    return `<div class="login"><form id="login-form">
      <div class="brand" style="color:var(--ink);padding:0"><span class="brand-mark">د<i></i></span><div><b style="color:var(--ink)">${t("brand")}</b><small style="color:var(--text-3)">${t("console")}</small></div></div>
      <h2>${t("login_t")}</h2>
      <label class="field"><span>${t("email")}</span><input class="input" id="login-email" type="email" autocomplete="username" required dir="ltr"></label>
      <label class="field"><span>${t("password")}</span><input class="input" id="login-pass" type="password" autocomplete="current-password" required dir="ltr"></label>
      ${err ? `<div class="pill bad">${esc(err)}</div>` : ""}
      <button class="btn primary" type="submit" style="justify-content:center">${t("signin")}</button>
      <button class="btn" type="button" data-act="lang" style="justify-content:center">${t("lang")}</button>
    </form></div>`;
  }

  const root = () => document.getElementById("app");
  function render() {
    document.documentElement.lang = S.lang;
    document.documentElement.dir = S.lang === "ar" ? "rtl" : "ltr";
    document.title = (S.lang === "ar" ? "درس — " : "Dars — ") + t(S.page);
    if (!S.ready) return;
    const active = document.activeElement;
    const focusId = active && active.id, selStart = active && active.selectionStart;
    root().innerHTML = S.user ? shell() : loginHtml(S.loginError);
    if (focusId) { const el = document.getElementById(focusId); if (el) { el.focus(); try { if (selStart != null) el.setSelectionRange(selStart, selStart); } catch (e) { /* ignore */ } } }
  }

  // ------------------------------------------------------------------ events
  function go(page, tab) {
    if (!PAGES.includes(page)) page = "overview";
    S.page = page; S.navOpen = false; S.drawer = null;
    if (tab) S.tab[page] = tab;
    if (location.hash.slice(1) !== page) history.replaceState(null, "", "#" + page);
    loadPage(false);
  }

  document.addEventListener("click", async (e) => {
    const el = e.target.closest("[data-act]");
    if (!el) return;
    const a = el.dataset.act, id = el.dataset.id;
    if (el.tagName === "TR" && e.target.closest("button, select, input")) return;
    switch (a) {
      case "nav": go(el.dataset.page); break;
      case "goto": go(el.dataset.page, el.dataset.tab); break;
      case "nav-open": S.navOpen = true; render(); break;
      case "nav-close": S.navOpen = false; render(); break;
      case "tab": S.tab[el.dataset.key] = el.dataset.val; render(); break;
      case "refresh": loadPage(true); break;
      case "lang": S.lang = S.lang === "ar" ? "en" : "ar"; store.set("lang", S.lang); render(); break;
      case "close": S.drawer = null; render(); break;
      case "tutor": S.drawer = { id }; render(); break;
      case "approve": act(() => api.verifyTutor(id, "approved"), ["tutors"]); break;
      case "reject": ask({ title: t("reject"), label: t("reject_reason"), confirm: t("reject"), danger: true, required: true, run: (v) => act(() => api.verifyTutor(id, "rejected", v), ["tutors"]) }); break;
      case "block": act(() => api.setUserStatus(id, el.dataset.status), ["students", "tutors"]); break;
      case "password": ask({ title: t("set_password"), label: t("new_password"), hint: t("pw_hint"), confirm: t("save"), pw: true, required: true, run: (v) => act(() => api.setPassword(id, v), [], t("pw_saved")) }); break;
      case "adjust": ask({ title: t("adjust"), label: t("adjust_note"), hint: t("wallet_hint"), confirm: t("save"), amount: true, required: true, run: (v, amt) => act(() => api.walletAdjust(id, amt, v), ["students"]) }); break;
      case "refund": ask({ title: t("refund"), label: t("refund_note"), confirm: t("refund"), danger: true, run: (v) => act(() => api.refundLesson(id, v), ["lessons", "reports", "payments"]) }); break;
      case "release": ask({ title: t("release"), label: t("release_note"), confirm: t("release"), run: (v) => act(() => api.releaseLesson(id, v), ["lessons", "reports"]) }); break;
      case "pay-ok": act(() => api.confirmPayment(id), ["payments", "lessons"]); break;
      case "pay-fail": act(() => api.failPayment(id), ["payments"]); break;
      case "payout": {
        const st = el.dataset.status;
        if (st === "approved") act(() => api.processPayout(id, st), ["payouts"]);
        else ask({ title: t(st === "paid" ? "mark_paid" : "reject"), label: t("payout_note"), confirm: t(st === "paid" ? "mark_paid" : "reject"), danger: st === "rejected", required: st === "rejected", run: (v) => act(() => api.processPayout(id, st, v), ["payouts"]) });
        break;
      }
      case "review": act(() => api.setReviewStatus(id, el.dataset.status), ["reviews"]); break;
      case "report": ask({ title: t(el.dataset.status === "resolved" ? "resolve" : "dismiss"), label: t("resolution"), confirm: t("confirm"), run: (v) => act(() => api.resolveReport(id, el.dataset.status, v), ["reports"]) }); break;
      case "save-subject": {
        const row = { id, name_ar: document.getElementById("sar-" + id).value.trim(), name_en: document.getElementById("sen-" + id).value.trim(), active: document.getElementById("sact-" + id).checked };
        act(() => api.saveSubject(row), ["subjects"], t("saved")); break;
      }
      case "copy": {
        const text = el.dataset.text;
        try { await navigator.clipboard.writeText(text); toast(t("copied")); } catch (err) { toast(text); }
        break;
      }
      case "receipt": {
        if (S.mode === "live" && api.receiptUrl) { const url = await api.receiptUrl(el.dataset.path); if (url) window.open(url, "_blank", "noopener"); }
        else toast(el.dataset.path);
        break;
      }
      case "dialog-cancel": S.dialog = null; render(); break;
      case "signout": await sb.auth.signOut(); S.user = null; S.data = {}; render(); break;
    }
  });

  document.addEventListener("input", (e) => {
    const el = e.target;
    if (el.dataset.input === "q") { S.q[el.dataset.key] = el.value; render(); }
  });
  document.addEventListener("change", (e) => {
    const el = e.target;
    if (el.dataset.change === "lead") act(() => api.updateLead(el.dataset.id, el.value), ["leads"]);
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && (S.dialog || S.drawer || S.navOpen)) { S.dialog = null; S.drawer = null; S.navOpen = false; render(); }
    if (e.key === "Enter" && e.target.matches("tr.clickable")) e.target.click();
  });
  document.addEventListener("submit", async (e) => {
    e.preventDefault();
    const f = e.target;
    if (f.id === "dialog-form") {
      const v = document.getElementById("dlg-text").value.trim();
      const amtEl = document.getElementById("dlg-amount");
      const amt = amtEl ? Number(amtEl.value) : undefined;
      const run = S.dialog.run;
      if (amtEl && (!amt || isNaN(amt))) return;
      S.dialog = null; run(v, amt);
    } else if (f.id === "settings-form") {
      const out = {};
      SETTINGS.forEach(([key, , kind]) => {
        const raw = document.getElementById("set-" + key).value;
        out[key] = kind === "pct" ? Number(raw) / 100 : kind === "int" ? parseInt(raw, 10) : kind === "bool" ? raw === "true" : raw;
      });
      act(() => api.saveSettings(out), ["settings"], t("saved"));
    } else if (f.id === "login-form") {
      const email = document.getElementById("login-email").value, password = document.getElementById("login-pass").value;
      const { data, error } = await sb.auth.signInWithPassword({ email, password });
      if (error) { S.loginError = error.message; return render(); }
      await afterLogin(data.user);
    }
  });
  window.addEventListener("hashchange", () => { const p = location.hash.slice(1); if (p && p !== S.page) go(p); });

  // ------------------------------------------------------------------ boot
  function loadScript(src) {
    return new Promise((res, rej) => { const s = document.createElement("script"); s.src = src; s.onload = res; s.onerror = () => rej(new Error("Could not load " + src)); document.head.appendChild(s); });
  }
  async function afterLogin(user) {
    const { data: prof, error } = await sb.from("profiles").select("role, full_name").eq("id", user.id).maybeSingle();
    // A network hiccup must not sign the admin out — keep the saved session and try again shortly.
    if (error && !prof) { S.user = null; S.loginError = (error.message || "Network error") + " — retrying…"; render(); setTimeout(() => afterLogin(user), 5000); return; }
    if (!prof || prof.role !== "admin") { await sb.auth.signOut(); S.loginError = t("not_admin"); S.user = null; return render(); }
    S.user = { id: user.id, name: prof.full_name || user.email }; S.loginError = null;
    go(PAGES.includes(location.hash.slice(1)) ? location.hash.slice(1) : "overview");
  }
  async function boot() {
    if (CFG.supabaseUrl && CFG.supabaseAnonKey) {
      S.mode = "live";
      try {
        await loadScript(SUPABASE_CDN);
        sb = window.supabase.createClient(CFG.supabaseUrl, CFG.supabaseAnonKey, {
          auth: { persistSession: true, autoRefreshToken: true },
        });
        api = liveApi(sb);
        S.ready = true;
        const { data } = await sb.auth.getSession();
        if (data.session) await afterLogin(data.session.user); else render();
        return;
      } catch (e) {
        // Connected dashboard: never fall back to sample data.
        S.ready = true; S.user = null; S.loginError = (e && e.message) || "Could not reach the backend"; render();
        return;
      }
    }
    S.mode = "demo"; api = demoApi(); S.ready = true;
    S.user = { id: "demo", name: S.lang === "ar" ? "مدير تجريبي" : "Demo admin" };
    go(PAGES.includes(location.hash.slice(1)) ? location.hash.slice(1) : "overview");
  }
  boot();
})();
