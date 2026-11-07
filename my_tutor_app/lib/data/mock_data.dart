import 'package:flutter/material.dart';
import '../l10n.dart';
import 'models.dart';

/// Demo content. Replace with API calls (see README → "Connecting a backend").
class MockData {
  static const subjects = <Subject>[
    Subject('math', L('الرياضيات', 'Math'), Icons.calculate_rounded, Color(0xFF2F6BFF)),
    Subject('english', L('اللغة الإنجليزية', 'English'), Icons.translate_rounded, Color(0xFF7B61FF)),
    Subject('arabic', L('اللغة العربية', 'Arabic'), Icons.menu_book_rounded, Color(0xFF0E8F7E)),
    Subject('physics', L('الفيزياء', 'Physics'), Icons.bolt_rounded, Color(0xFFF59E0B)),
    Subject('chemistry', L('الكيمياء', 'Chemistry'), Icons.science_rounded, Color(0xFF22B573)),
    Subject('biology', L('الأحياء', 'Biology'), Icons.biotech_rounded, Color(0xFFE5484D)),
    Subject('exams', L('اختبارات دولية', 'Test prep'), Icons.assignment_turned_in_rounded, Color(0xFFFF7A45)),
    Subject('programming', L('البرمجة', 'Programming'), Icons.code_rounded, Color(0xFF12203A)),
    Subject('quran', L('القرآن والتجويد', 'Quran & Tajweed'), Icons.auto_stories_rounded, Color(0xFF0A6E61)),
    Subject('accounting', L('المحاسبة والمالية', 'Accounting'), Icons.account_balance_rounded, Color(0xFF5B45D6)),
    Subject('french', L('اللغة الفرنسية', 'French'), Icons.language_rounded, Color(0xFF0EA5E9)),
    Subject('kids', L('تأسيس الأطفال', 'Kids foundation'), Icons.child_care_rounded, Color(0xFFEC4899)),
  ];

  static const levels = <StudyLevel>[
    StudyLevel('kids', L('رياض الأطفال', 'Pre-school'), Icons.toys_rounded, 0.8),
    StudyLevel('elementary', L('ابتدائي', 'Elementary'), Icons.backpack_rounded, 0.85),
    StudyLevel('middle', L('إعدادي / متوسط', 'Middle school'), Icons.edit_note_rounded, 0.9),
    StudyLevel('high', L('ثانوي', 'High school'), Icons.school_rounded, 1.0),
    StudyLevel('university', L('جامعي', 'University'), Icons.account_balance_rounded, 1.2),
    StudyLevel('adult', L('مهنيون وبالغون', 'Adults & professionals'), Icons.work_rounded, 1.3),
  ];

  static const curricula = <Option>[
    Option('syrian', L('المنهج السوري', 'Syrian curriculum')),
    Option('saudi', L('المنهج السعودي', 'Saudi curriculum')),
    Option('uae', L('المنهج الإماراتي', 'UAE curriculum')),
    Option('egyptian', L('المنهج المصري', 'Egyptian curriculum')),
    Option('jordanian', L('المنهج الأردني', 'Jordanian curriculum')),
    Option('american', L('المنهج الأمريكي', 'American curriculum')),
    Option('british', L('المنهج البريطاني IG', 'British IGCSE')),
    Option('ib', L('البكالوريا الدولية IB', 'International Baccalaureate')),
    Option('other', L('غير ذلك', 'Other')),
  ];

  static const popular = <L>[
    L('IELTS', 'IELTS'),
    L('رياضيات ثانوي', 'High-school math'),
    L('فيزياء', 'Physics'),
    L('محادثة إنجليزي', 'English conversation'),
    L('SAT', 'SAT'),
    L('STEP', 'STEP'),
    L('تجويد', 'Tajweed'),
    L('بايثون', 'Python'),
  ];

  static Subject subject(String id) => subjects.firstWhere((s) => s.id == id, orElse: () => subjects.first);

  static final tutors = <Tutor>[
    Tutor(
      id: 't1',
      name: const L('م. سامر الحلبي', 'Samer Al-Halabi'),
      headline: const L('مهندس ومدرس رياضيات وفيزياء بخبرة 12 سنة', 'Engineer teaching math & physics for 12 years'),
      about: const L(
          'أدرّس الرياضيات والفيزياء لطلاب الثانوي والجامعة منذ 12 عاماً. أركز على الفهم العميق بدلاً من الحفظ، وأبني لكل طالب خطة تناسب مستواه وموعد اختباره. ساعدت أكثر من 600 طالب على رفع درجاتهم في الشهادة الثانوية واختبارات القدرات.',
          'I have taught math and physics to high-school and university students for 12 years. I focus on real understanding instead of memorising, and I build each student a plan that fits their level and exam date. I have helped 600+ students raise their grades in finals and aptitude tests.'),
      subjectIds: const ['math', 'physics'],
      tags: const [L('تفاضل وتكامل', 'Calculus'), L('جبر', 'Algebra'), L('فيزياء ثانوي', 'HS physics'), L('قدرات', 'Aptitude')],
      rating: 4.9,
      reviewCount: 214,
      hoursTaught: 3120,
      students: 612,
      pricePerHour: 15,
      maxDiscount: 20,
      available: true,
      instantBooking: true,
      isNew: false,
      gender: 'm',
      country: const L('سوريا', 'Syria'),
      languages: const [L('العربية (أم)', 'Arabic (native)'), L('الإنجليزية (متقدم)', 'English (advanced)')],
      years: 12,
      matchScore: 96,
      color: const Color(0xFF2F6BFF),
      teachesInPerson: true,
      cancelHours: 12,
      reviews: const [
        Review(L('ليان', 'Layan'), 5, L('شرح ممتاز وصبور جداً، رفعت درجتي من 70 إلى 94.', 'Excellent and very patient, my grade went from 70 to 94.'), '2026-10-28'),
        Review(L('أحمد', 'Ahmad'), 5, L('أفضل مدرس فيزياء تعاملت معه.', 'Best physics tutor I have had.'), '2026-10-11'),
        Review(L('ولي أمر - أم يوسف', 'Parent - Um Yousef'), 4, L('ملتزم بالمواعيد ويرسل تقارير بعد كل حصة.', 'Always on time and sends a report after each lesson.'), '2026-09-30'),
      ],
    ),
    Tutor(
      id: 't2',
      name: const L('أ. لمى الخطيب', 'Lama Al-Khatib'),
      headline: const L('مدرّسة إنجليزي ومدرّبة IELTS معتمدة', 'Certified English & IELTS trainer'),
      about: const L(
          'حاصلة على شهادة CELTA ودرجة 8.5 في IELTS. أساعد الطلاب على تحسين المحادثة والكتابة والاستعداد لاختبارات IELTS وTOEFL وSTEP بخطط أسبوعية واضحة ونماذج اختبارات حقيقية.',
          'CELTA-certified with an IELTS band of 8.5. I help students improve speaking and writing and prepare for IELTS, TOEFL and STEP with clear weekly plans and real mock tests.'),
      subjectIds: const ['english', 'exams'],
      tags: const [L('IELTS', 'IELTS'), L('محادثة', 'Conversation'), L('TOEFL', 'TOEFL'), L('STEP', 'STEP')],
      rating: 4.8,
      reviewCount: 167,
      hoursTaught: 2400,
      students: 390,
      pricePerHour: 18,
      maxDiscount: 25,
      available: true,
      instantBooking: true,
      isNew: false,
      gender: 'f',
      country: const L('الأردن', 'Jordan'),
      languages: const [L('العربية (أم)', 'Arabic (native)'), L('الإنجليزية (طلاقة)', 'English (fluent)')],
      years: 9,
      matchScore: 91,
      color: const Color(0xFF7B61FF),
      cancelHours: 24,
      reviews: const [
        Review(L('سارة', 'Sara'), 5, L('حصلت على 7.5 في IELTS بعد شهرين معها!', 'Got band 7.5 after two months with her!'), '2026-10-20'),
        Review(L('محمد', 'Mohammad'), 5, L('أسلوب ممتع ومنظم.', 'Fun and well-organised.'), '2026-10-02'),
      ],
    ),
    Tutor(
      id: 't3',
      name: const L('د. ريم العلي', 'Dr. Reem Al-Ali'),
      headline: const L('دكتوراه في الكيمياء — ثانوي وجامعة', 'PhD in Chemistry — high school & university'),
      about: const L(
          'أستاذة كيمياء جامعية سابقة، أبسّط الكيمياء العضوية والتحليلية بالأمثلة والرسوم. أدرّس المناهج السعودية والسورية والـIB.',
          'Former university chemistry lecturer. I make organic and analytical chemistry simple with examples and diagrams. I teach Saudi, Syrian and IB curricula.'),
      subjectIds: const ['chemistry', 'biology'],
      tags: const [L('كيمياء عضوية', 'Organic chem'), L('أحياء', 'Biology'), L('IB', 'IB')],
      rating: 4.9,
      reviewCount: 98,
      hoursTaught: 1500,
      students: 210,
      pricePerHour: 22,
      maxDiscount: 15,
      available: false,
      instantBooking: false,
      isNew: false,
      gender: 'f',
      country: const L('السعودية', 'Saudi Arabia'),
      languages: const [L('العربية (أم)', 'Arabic (native)'), L('الإنجليزية (متقدم)', 'English (advanced)')],
      years: 15,
      matchScore: 88,
      color: const Color(0xFF22B573),
      cancelHours: 24,
      reviews: const [Review(L('هيا', 'Haya'), 5, L('فهمت الكيمياء العضوية لأول مرة.', 'I understood organic chemistry for the first time.'), '2026-10-15')],
    ),
    Tutor(
      id: 't4',
      name: const L('أ. عمر النجار', 'Omar Al-Najjar'),
      headline: const L('مطوّر برمجيات يعلّم بايثون وتطوير الويب', 'Software engineer teaching Python & web dev'),
      about: const L('أعمل مطوراً منذ 8 سنوات. أعلّم البرمجة من الصفر بمشاريع عملية: بايثون، جافاسكربت، وقواعد البيانات، كما أساعد طلاب الجامعة في مشاريع التخرج.',
          'Developer for 8 years. I teach programming from scratch through real projects: Python, JavaScript and databases, and I help university students with graduation projects.'),
      subjectIds: const ['programming'],
      tags: const [L('بايثون', 'Python'), L('جافاسكربت', 'JavaScript'), L('مشاريع تخرج', 'Graduation projects')],
      rating: 4.7,
      reviewCount: 64,
      hoursTaught: 820,
      students: 120,
      pricePerHour: 20,
      maxDiscount: 10,
      available: true,
      instantBooking: false,
      isNew: false,
      gender: 'm',
      country: const L('الإمارات', 'UAE'),
      languages: const [L('العربية (أم)', 'Arabic (native)'), L('الإنجليزية (طلاقة)', 'English (fluent)')],
      years: 8,
      matchScore: 74,
      color: const Color(0xFF12203A),
    ),
    Tutor(
      id: 't5',
      name: const L('أ. هبة درويش', 'Hiba Darwish'),
      headline: const L('تأسيس قراءة وكتابة ورياضيات للأطفال', 'Reading, writing & math foundations for kids'),
      about: const L('معلمة صفوف أولى بخبرة 10 سنوات. أستخدم الألعاب التعليمية والقصص لتأسيس الأطفال من 4 إلى 9 سنوات في العربية والرياضيات، مع تقرير أسبوعي لولي الأمر.',
          'Early-years teacher for 10 years. I use educational games and stories to build strong Arabic and math foundations for ages 4–9, with a weekly report for parents.'),
      subjectIds: const ['kids', 'arabic'],
      tags: const [L('تأسيس', 'Foundations'), L('قراءة', 'Reading'), L('خط عربي', 'Handwriting')],
      rating: 5.0,
      reviewCount: 120,
      hoursTaught: 1900,
      students: 180,
      pricePerHour: 12,
      maxDiscount: 20,
      available: true,
      instantBooking: true,
      isNew: false,
      gender: 'f',
      country: const L('سوريا', 'Syria'),
      languages: const [L('العربية (أم)', 'Arabic (native)')],
      years: 10,
      matchScore: 82,
      color: const Color(0xFFEC4899),
      teachesInPerson: true,
    ),
    Tutor(
      id: 't6',
      name: const L('الشيخ يوسف القاسم', 'Sheikh Yousef Al-Qasem'),
      headline: const L('مجاز في القراءات — تحفيظ وتجويد', 'Licensed Quran reciter — memorisation & Tajweed'),
      about: const L('حاصل على إجازة برواية حفص، أدرّس التلاوة والتجويد والتحفيظ للصغار والكبار بأسلوب ميسّر.',
          'Holder of an ijazah in Hafs. I teach recitation, Tajweed and memorisation to children and adults in an easy way.'),
      subjectIds: const ['quran', 'arabic'],
      tags: const [L('تجويد', 'Tajweed'), L('تحفيظ', 'Memorisation')],
      rating: 4.9,
      reviewCount: 75,
      hoursTaught: 2200,
      students: 260,
      pricePerHour: 10,
      maxDiscount: 15,
      available: false,
      instantBooking: true,
      isNew: false,
      gender: 'm',
      country: const L('مصر', 'Egypt'),
      languages: const [L('العربية (أم)', 'Arabic (native)')],
      years: 14,
      matchScore: 63,
      color: const Color(0xFF0A6E61),
    ),
    Tutor(
      id: 't7',
      name: const L('أ. نور حداد', 'Nour Haddad'),
      headline: const L('محاسبة قانونية — محاسبة ومالية للجامعة', 'CPA — accounting & finance for university'),
      about: const L('محاسبة قانونية معتمدة. أشرح المحاسبة المالية والتكاليف والإدارة المالية لطلاب الجامعات وأحضّر لاختبارات CMA.',
          'Certified public accountant. I teach financial and cost accounting and corporate finance to university students and prepare for CMA exams.'),
      subjectIds: const ['accounting'],
      tags: const [L('محاسبة مالية', 'Financial accounting'), L('CMA', 'CMA')],
      rating: 4.6,
      reviewCount: 41,
      hoursTaught: 540,
      students: 88,
      pricePerHour: 17,
      maxDiscount: 0,
      available: true,
      instantBooking: false,
      isNew: true,
      gender: 'f',
      country: const L('لبنان', 'Lebanon'),
      languages: const [L('العربية (أم)', 'Arabic (native)'), L('الفرنسية (متقدم)', 'French (advanced)'), L('الإنجليزية (متقدم)', 'English (advanced)')],
      years: 6,
      matchScore: 58,
      color: const Color(0xFF5B45D6),
    ),
    Tutor(
      id: 't8',
      name: const L('أ. كريم منصور', 'Karim Mansour'),
      headline: const L('مدرس فرنسي — DELF وبكالوريا فرنسية', 'French tutor — DELF & French Bac'),
      about: const L('خريج جامعة السوربون، أدرّس الفرنسية لجميع المستويات وأحضّر لاختبارات DELF وDALF.',
          'Sorbonne graduate teaching French at every level and preparing students for DELF and DALF.'),
      subjectIds: const ['french'],
      tags: const [L('DELF', 'DELF'), L('محادثة', 'Conversation')],
      rating: 4.8,
      reviewCount: 52,
      hoursTaught: 700,
      students: 95,
      pricePerHour: 16,
      maxDiscount: 10,
      available: true,
      instantBooking: true,
      isNew: true,
      gender: 'm',
      country: const L('المغرب', 'Morocco'),
      languages: const [L('العربية (أم)', 'Arabic (native)'), L('الفرنسية (طلاقة)', 'French (fluent)')],
      years: 5,
      matchScore: 55,
      color: const Color(0xFF0EA5E9),
    ),
  ];

  static Tutor tutor(String id) => tutors.firstWhere((t) => t.id == id);

  static DateTime _at(int dayOffset, int hour, [int minute = 0]) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + dayOffset, hour, minute);
  }

  static List<Lesson> studentLessons() => [
        Lesson(id: 'L1001', tutor: tutor('t1'), studentName: const L('أنت', 'You'), subject: const L('رياضيات - تفاضل', 'Math - Calculus'), start: _at(0, 19), minutes: 50, online: true, status: LessonStatus.upcoming, price: 15, link: 'https://meet.dars.app/L1001'),
        Lesson(id: 'L1002', tutor: tutor('t2'), studentName: const L('أنت', 'You'), subject: const L('IELTS - كتابة', 'IELTS - Writing'), start: _at(2, 17, 30), minutes: 50, online: true, status: LessonStatus.upcoming, price: 18),
        Lesson(id: 'L1003', tutor: tutor('t3'), studentName: const L('أنت', 'You'), subject: const L('كيمياء عضوية', 'Organic chemistry'), start: _at(4, 16), minutes: 100, online: true, status: LessonStatus.pending, price: 44),
        Lesson(id: 'L0991', tutor: tutor('t1'), studentName: const L('أنت', 'You'), subject: const L('فيزياء - كهرباء', 'Physics - Electricity'), start: _at(-3, 18), minutes: 50, online: true, status: LessonStatus.delivered, price: 15),
        Lesson(id: 'L0980', tutor: tutor('t2'), studentName: const L('أنت', 'You'), subject: const L('محادثة إنجليزي', 'English conversation'), start: _at(-8, 20), minutes: 25, online: true, status: LessonStatus.delivered, price: 9, reviewed: true),
        Lesson(id: 'L0975', tutor: tutor('t5'), studentName: const L('أنت', 'You'), subject: const L('تأسيس قراءة', 'Reading foundations'), start: _at(-10, 16), minutes: 50, online: false, status: LessonStatus.cancelled, price: 12),
      ];

  static List<Lesson> tutorLessons() => [
        Lesson(id: 'L2001', tutor: tutor('t1'), studentName: const L('ليان محمد', 'Layan Mohammad'), subject: const L('رياضيات - تفاضل', 'Math - Calculus'), start: _at(0, 19), minutes: 50, online: true, status: LessonStatus.upcoming, price: 15),
        Lesson(id: 'L2002', tutor: tutor('t1'), studentName: const L('أحمد سليمان', 'Ahmad Suleiman'), subject: const L('فيزياء ثانوي', 'HS physics'), start: _at(1, 18), minutes: 50, online: true, status: LessonStatus.upcoming, price: 15, link: 'https://meet.dars.app/L2002'),
        Lesson(id: 'L2003', tutor: tutor('t1'), studentName: const L('يوسف (ابن أم يوسف)', 'Yousef (Um Yousef\'s son)'), subject: const L('جبر', 'Algebra'), start: _at(1, 20), minutes: 100, online: false, status: LessonStatus.upcoming, price: 30),
        Lesson(id: 'L1990', tutor: tutor('t1'), studentName: const L('سارة علي', 'Sara Ali'), subject: const L('قدرات - كمي', 'Aptitude - Quant'), start: _at(-1, 17), minutes: 50, online: true, status: LessonStatus.delivered, price: 15),
      ];

  static List<HoursPackage> packages() => [
        HoursPackage(id: 'P301', tutor: tutor('t2'), totalHours: 8, usedHours: 3, discount: 15, active: true, price: 122.4),
        HoursPackage(id: 'P288', tutor: tutor('t1'), totalHours: 4, usedHours: 4, discount: 5, active: false, price: 57),
      ];

  static List<Conversation> conversations() {
    final n = DateTime.now();
    return [
      Conversation(
        id: 'c1',
        name: tutor('t1').name,
        color: tutor('t1').color,
        tutor: tutor('t1'),
        online: true,
        unread: 2,
        messages: [
          Message(mine: true, text: 'مرحباً أستاذ، عندي اختبار تفاضل يوم الخميس', time: n.subtract(const Duration(hours: 3))),
          Message(mine: false, text: 'أهلاً بك! أرسل لي صورة المسائل التي تجدها صعبة', time: n.subtract(const Duration(hours: 2, minutes: 50))),
          Message(mine: true, text: 'question_1.jpg', time: n.subtract(const Duration(hours: 2, minutes: 40)), type: MsgType.file),
          Message(mine: false, text: '', time: n.subtract(const Duration(minutes: 20)), type: MsgType.voice, seconds: 34),
          Message(mine: false, text: 'نلتقي اليوم الساعة 7 مساءً، جهّز الدفتر 👍', time: n.subtract(const Duration(minutes: 18))),
        ],
      ),
      Conversation(
        id: 'c2',
        name: tutor('t2').name,
        color: tutor('t2').color,
        tutor: tutor('t2'),
        messages: [
          Message(mine: false, text: 'Great job today! Your homework: write one Task 2 essay.', time: n.subtract(const Duration(days: 1))),
          Message(mine: true, text: 'Thank you! I will send it tomorrow.', time: n.subtract(const Duration(days: 1))),
        ],
      ),
    ];
  }

  static List<LiveRequest> liveRequests() {
    final n = DateTime.now();
    return [
      LiveRequest(id: 'r1', studentName: const L('ماريا', 'Maria'), subject: const L('الرياضيات', 'Math'), level: const L('ثانوي', 'High school'), text: 'عندي سؤال في النهايات ولم أفهم طريقة الحل، الاختبار بكرة', voiceSeconds: 0, created: n.subtract(const Duration(seconds: 20)), color: const Color(0xFFF59E0B)),
      LiveRequest(id: 'r2', studentName: const L('خالد', 'Khaled'), subject: const L('الفيزياء', 'Physics'), level: const L('جامعي', 'University'), text: '', voiceSeconds: 41, created: n.subtract(const Duration(seconds: 45)), color: const Color(0xFF2F6BFF)),
    ];
  }

  static List<AppNotification> notifications() {
    final n = DateTime.now();
    return [
      AppNotification(const L('تذكير: درسك بعد ساعة', 'Reminder: lesson in 1 hour'), const L('درس الرياضيات مع م. سامر الساعة 7:00 مساءً', 'Math with Samer at 7:00 PM'), n.subtract(const Duration(minutes: 5)), Icons.alarm_rounded, const Color(0xFF2F6BFF)),
      AppNotification(const L('تم تأكيد الدفع والحجز', 'Payment & booking confirmed'), const L('حجز رقم L1002 مع أ. لمى', 'Booking L1002 with Lama'), n.subtract(const Duration(hours: 4)), Icons.verified_rounded, const Color(0xFF22B573)),
      AppNotification(const L('رأيك يهمنا!', 'We value your opinion!'), const L('قيّم درس الفيزياء مع م. سامر', 'Rate your physics lesson with Samer'), n.subtract(const Duration(days: 2)), Icons.star_rounded, const Color(0xFFF5A524), read: true),
    ];
  }

  static List<WalletTx> transactions() {
    final n = DateTime.now();
    return [
      WalletTx(const L('حجز L1002 - IELTS', 'Booking L1002 - IELTS'), -18, n.subtract(const Duration(hours: 4)), const L('مدفوع', 'Paid')),
      WalletTx(const L('استرداد درس ملغى L0975', 'Refund cancelled lesson L0975'), 12, n.subtract(const Duration(days: 10)), const L('مسترد', 'Refunded')),
      WalletTx(const L('باقة 8 ساعات P301', '8-hour package P301'), -122.4, n.subtract(const Duration(days: 14)), const L('مدفوع', 'Paid')),
      WalletTx(const L('رصيد ترحيبي', 'Welcome credit'), 13, n.subtract(const Duration(days: 20)), const L('رصيد', 'Credit')),
    ];
  }
}
