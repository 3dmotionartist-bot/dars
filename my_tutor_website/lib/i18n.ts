export const locales = ['ar', 'en'] as const;
export type Lang = (typeof locales)[number];

export const isLang = (v: string): v is Lang => (locales as readonly string[]).includes(v);
export const dirOf = (l: Lang) => (l === 'ar' ? 'rtl' : 'ltr');

const ar = {
  brand: 'درس',
  meta: {
    title: 'درس | مدرسون خصوصيون أونلاين وحضورياً',
    description: 'منصة درس تصلك بمدرسين خصوصيين موثّقين للدروس الأونلاين والحضورية، ومساعدة فورية في الواجبات والاختبارات خلال دقائق.',
  },
  nav: { home: 'الرئيسية', tutors: 'ابحث عن مدرس', become: 'انضم كمدرس', pricing: 'الباقات والأسعار', about: 'من نحن', faq: 'الأسئلة الشائعة', contact: 'تواصل معنا', getApp: 'حمّل التطبيق', signIn: 'تسجيل الدخول', menu: 'القائمة' },
  hero: {
    badge: 'مدرسون موثّقون · مساعدة فورية',
    title: 'مدرّسك الخاص،',
    titleAccent: 'متى ما احتجته',
    subtitle: 'دروس خصوصية أونلاين وحضورية مع مدرسين موثّقين، ومساعدة فورية في الواجبات والاختبارات خلال دقائق — لكل المراحل والمناهج.',
    searchPlaceholder: 'ماذا تريد أن تتعلم؟ رياضيات، IELTS، فيزياء…',
    searchCta: 'ابحث عن مدرس',
    liveCta: 'تكلّم مع مدرس الآن',
    popular: 'الأكثر طلباً:',
  },
  stats: [
    { value: '12', label: 'مادة ومهارة' },
    { value: '6', label: 'مراحل دراسية من الروضة للجامعة' },
    { value: '100%', label: 'ضمان استرداد الساعة الأولى' },
    { value: '90 ثانية', label: 'لإيصال سؤالك لكل المدرسين المتاحين' },
  ],
  live: {
    eyebrow: 'مساعدة فورية',
    title: 'عالق في واجب؟ تكلّم مع مدرس خلال دقائق',
    body: 'اكتب سؤالك أو سجّله صوتياً أو صوّره، وسنرسله لكل المدرسين المتاحين الآن. اختر من قبل طلبك وابدأ المحادثة أو المكالمة داخل التطبيق.',
    steps: ['أرسل سؤالك نصاً أو صوتاً أو صورة', 'يصل طلبك لكل المدرسين المتاحين', 'تواصل مع من قبل طلبك فوراً'],
    cta: 'جرّبها الآن',
  },
  how: {
    title: 'كيف يعمل درس؟',
    steps: [
      { t: 'ابحث واختر', d: 'فلتر حسب المادة والمرحلة والمنهج والسعر، وشاهد تقييمات الطلاب الحقيقية ونسبة التطابق.' },
      { t: 'احجز وادفع بأمان', d: 'درس منفرد أو باقة ساعات بخصم يصل إلى 25%. ادفع بالبطاقة أو Apple Pay أو قسّطها.' },
      { t: 'تعلّم وتقدّم', d: 'ادخل الصف الافتراضي بالفيديو والسبورة، واحصل على ملخص وواجب بعد كل درس.' },
    ],
  },
  subjects: { title: 'تصفح حسب المادة', subtitle: 'من تأسيس الأطفال إلى الجامعة والمهارات المهنية', all: 'كل المواد' },
  featured: { title: 'مدرسون مميزون', subtitle: 'اختيارات الذكاء الاصطناعي حسب التقييم والخبرة والتطابق', viewAll: 'عرض كل المدرسين' },
  tutor: {
    perHour: '/ساعة', from: 'يبدأ من', reviews: 'تقييم', available: 'متاح الآن', busy: 'غير متاح', instant: 'حجز فوري', match: 'تطابق', newTutor: 'انضم حديثاً',
    upTo: 'خصم حتى', onPackages: 'على الباقات', view: 'عرض الملف', book: 'احجز درساً', message: 'راسل المدرس',
    about: 'عن المدرس', subjects: 'المواد', speaks: 'يتحدث', country: 'الدولة', experience: 'الخبرة', years: 'سنوات', hoursTaught: 'ساعة تدريس', students: 'طالب',
    fees: 'الأسعار حسب المرحلة', packages: 'الباقات', hours: 'ساعات', policies: 'السياسات', cancel: 'إلغاء مجاني حتى {h} ساعة قبل الدرس',
    reviewsTitle: 'آراء الطلاب', reviewsNote: 'فقط الطلاب الذين حضروا درساً يمكنهم التقييم', online: 'أونلاين', inPerson: 'حضوري', mode: 'طريقة التدريس',
    bookInApp: 'أكمل الحجز في التطبيق', back: 'العودة للنتائج', notFound: 'المدرس غير موجود',
  },
  browse: {
    title: 'ابحث عن مدرس', subtitle: 'مدرسون موثّقون لكل المواد والمراحل', search: 'ابحث بالاسم أو المادة…', subject: 'المادة', all: 'الكل',
    sort: 'الترتيب', best: 'الأنسب (ذكاء اصطناعي)', price: 'الأقل سعراً', rating: 'الأعلى تقييماً', availableNow: 'متاح الآن', instantOnly: 'حجز فوري',
    gender: 'الجنس', male: 'ذكر', female: 'أنثى', maxPrice: 'أقصى سعر للساعة', results: 'نتيجة', empty: 'لا يوجد مدرسون مطابقون', emptyCta: 'دع مستشارنا يساعدك',
  },
  guarantee: { title: 'ضمان الرضا', body: 'إن لم تكن راضياً عن الساعة الأولى مع أي مدرس، نعيد لك المبلغ كاملاً — بلا أسئلة.' },
  safety: { title: 'آمن وموثوق', items: ['كل المدرسين يمرون بتحقق من الهوية والشهادات', 'المحادثات والمكالمات داخل التطبيق ومسجلة للجودة', 'الدفع عبر المنصة فقط — أموالك محمية حتى إتمام الدرس'] },
  testimonials: {
    title: 'ماذا يقول الطلاب وأولياء الأمور',
    items: [
      { q: 'رفعت درجتي في الرياضيات من 70 إلى 94 خلال فصل واحد. الشرح واضح والمدرس صبور جداً.', n: 'ليان', r: 'طالبة ثانوي - دمشق' },
      { q: 'الميزة الأجمل هي المساعدة الفورية، ابني يرسل سؤاله صوتياً ويحصل على مدرس خلال دقائق.', n: 'أم يوسف', r: 'ولي أمر - الرياض' },
      { q: 'حصلت على 7.5 في IELTS بعد شهرين فقط مع أ. لمى، والباقة وفّرت علي 25%.', n: 'سارة', r: 'طالبة جامعية - عمّان' },
    ],
  },
  tutorsCta: { title: 'هل أنت مدرس؟', body: 'انضم إلى درس، حدد أسعارك وأوقاتك، ودرّس طلاباً من كل الوطن العربي أونلاين أو في مدينتك.', cta: 'سجّل كمدرس' },
  app: { title: 'كل هذا في جيبك', body: 'حمّل تطبيق درس للحجز السريع والمساعدة الفورية والمكالمات والإشعارات.', ios: 'App Store', android: 'أندرويد', androidSmall: 'حمّل لأجهزة', older: 'هاتف قديم؟ استخدم هذه النسخة', web: 'افتح تطبيق الويب' },
  become: {
    title: 'درّس على درس واكسب دخلاً مرناً',
    subtitle: 'أونلاين أو حضورياً قرب منطقتك. أنت تحدد السعر والأوقات، ونحن نجلب لك الطلاب ونضمن الدفع.',
    cta: 'ابدأ التسجيل',
    steps: [
      { t: 'أنشئ ملفك', d: 'عرّف بنفسك وبالمواد التي تدرّسها وخبراتك وشهاداتك، وأضف فيديو تعريفياً.' },
      { t: 'قابل طلاباً من كل مكان', d: 'نساعد الطلاب في المدارس والجامعات ومتعلمي اللغات والمهارات على إيجادك.' },
      { t: 'استقبل الحجوزات', d: 'حجز فوري من تقويمك أو طلب حجز توافق عليه، بالإضافة لطلبات المساعدة الفورية.' },
      { t: 'استلم أرباحك', d: 'الطالب يدفع مسبقاً، فأجرك مضمون. حوّل أرباحك بنكياً أو عبر PayPal.' },
    ],
    perks: ['عمولة واضحة 15% فقط', 'خصومات باقات تحددها أنت (1–50%)', 'صف افتراضي بالفيديو والسبورة مجاناً', 'لوحة تحكم للأرباح والتقييمات', 'تفعيل "متاح الآن" لطلبات فورية'],
    calcTitle: 'احسب أرباحك المتوقعة',
    calcRate: 'سعر الساعة', calcHours: 'ساعات أسبوعياً', calcMonthly: 'صافي شهري تقريبي', calcNote: 'بعد خصم عمولة المنصة 15%، على أساس 4.3 أسابيع في الشهر.',
    reqTitle: 'المتطلبات',
    reqs: ['شهادة جامعية أو خبرة مثبتة في مجالك', 'هوية سارية وصورة شخصية واضحة', 'اتصال إنترنت مستقر للدروس الأونلاين', 'الالتزام بالتعهد الأخلاقي: كل الحجوزات عبر المنصة'],
  },
  pricing: {
    title: 'باقات وأسعار مرنة',
    subtitle: 'ادفع فقط مقابل الوقت الذي تحتاجه. بدون اشتراكات إجبارية.',
    payg: { t: 'درس منفرد', p: 'من $8', u: '/ساعة', d: 'لأقل من 4 ساعات، بسعر المدرس حسب المرحلة', f: ['25 أو 50 أو 100 دقيقة', 'إلغاء مجاني حسب سياسة المدرس', 'ضمان الساعة الأولى'] },
    pack: { t: 'باقة ساعات', p: 'وفّر حتى 25%', u: '', d: '4 ساعات أو أكثر مع نفس المدرس', f: ['خصم يحدده المدرس', 'رصيد ساعات صالح دائماً', 'احجز الدروس من الباقة بنقرة'] },
    subsTitle: 'اشتراكات المتابعة المدرسية لأولياء الأمور',
    subsBody: 'متابعة شهرية مع مرشد أكاديمي، تقارير تقييم، وجدولة مرنة لكل المواد.',
    subs: [
      { t: 'باقة التأسيس', p: '$79', d: 'لطالب ضعيف في مادة أو مادتين', f: ['8 ساعات شهرياً', 'تقرير تقييم شهري', 'مرونة في المواعيد'] },
      { t: 'باقة القوة', p: '$149', d: 'لطالب يحتاج متابعة يومية في 3 مواد أو أكثر', f: ['16 ساعة شهرياً', 'مرشد أكاديمي يرتب الأسبوع', 'تقارير بعد كل حصة'], popular: true },
      { t: 'باقة التفوق', p: '$249', d: 'دعم مكثف في معظم المواد والاستعداد للاختبارات النهائية', f: ['28 ساعة شهرياً', 'اختبارات تجريبية', 'أولوية في الحجز الفوري'] },
    ],
    popular: 'الأكثر طلباً', perMonth: '/شهرياً', subscribe: 'اشترك الآن',
    payTitle: 'طرق دفع محلية وآمنة',
    pays: ['بطاقات Visa / Mastercard / مدى', 'Apple Pay و Google Pay', 'قسّطها على 3 دفعات (تمارا / تابي)', 'تحويل بنكي', 'رصيد المحفظة'],
  },
  about: {
    title: 'من نحن',
    body: 'درس منصة عربية تجمع الطلاب بأفضل المدرسين الخصوصيين، أونلاين وحضورياً. بدأنا لأن إيجاد مدرس موثوق ما زال يعتمد على المعارف والمجموعات، ولأن الطالب يحتاج المساعدة في اللحظة التي يعلق فيها — لا بعد أيام.',
    mission: 'مهمتنا', missionBody: 'أن يحصل كل طالب عربي على مدرس ممتاز متى احتاجه، بسعر عادل، وأن يحصل كل مدرس على دخل كريم ومرن.',
    values: [{ t: 'الثقة', d: 'تحقق من كل مدرس وتقييمات حقيقية فقط.' }, { t: 'السرعة', d: 'مساعدة فورية خلال دقائق.' }, { t: 'العدالة', d: 'أسعار واضحة وعمولة منخفضة.' }, { t: 'الأثر', d: 'نقيس تقدّم الطالب لا عدد الساعات.' }],
  },
  faq: {
    title: 'الأسئلة الشائعة',
    items: [
      { q: 'كيف أختار المدرس المناسب؟', a: 'استخدم البحث والفلاتر حسب المادة والمرحلة والمنهج والسعر. نعرض لك نسبة التطابق المحسوبة بالذكاء الاصطناعي وتقييمات الطلاب الحقيقيين. وإن احترت، يساعدك المستشار الأكاديمي عبر واتساب.' },
      { q: 'ما هي المساعدة الفورية؟', a: 'ترسل سؤالك نصاً أو صوتاً أو صورة، فيصل لكل المدرسين المتاحين الآن. تظهر لك قائمة من قبلوا طلبك خلال دقائق لتبدأ المحادثة أو المكالمة.' },
      { q: 'كيف تعمل الباقات؟', a: 'عند حجز 4 ساعات أو أكثر مع نفس المدرس تحصل على خصم يحدده المدرس (حتى 25% عادةً). تبقى الساعات في رصيدك وتحجز منها متى شئت.' },
      { q: 'ماذا لو لم أكن راضياً؟', a: 'إن لم تكن راضياً عن الساعة الأولى مع أي مدرس، نعيد لك المبلغ كاملاً. ويمكنك الإبلاغ عن عدم حضور المدرس لاسترداد المبلغ.' },
      { q: 'ما طرق الدفع المتاحة؟', a: 'البطاقات البنكية ومدى، Apple Pay، التقسيط على 3 دفعات، التحويل البنكي، ورصيد المحفظة.' },
      { q: 'هل يمكنني إلغاء الدرس أو تغيير موعده؟', a: 'نعم، من صفحة "دروسي". الإلغاء مجاني قبل المدة التي يحددها المدرس (من 2 إلى 72 ساعة)، ويعود المبلغ لرصيدك.' },
      { q: 'كيف أصبح مدرساً على درس؟', a: 'سجّل من صفحة "انضم كمدرس"، أكمل ملفك وأسعارك وارفع سيرتك الذاتية. نراجع الملف خلال 24–48 ساعة.' },
    ],
  },
  contact: {
    title: 'تواصل معنا', subtitle: 'فريقنا متاح يومياً من 9 صباحاً حتى 11 مساءً', name: 'الاسم الكامل', email: 'البريد الإلكتروني أو واتساب', type: 'نوع الاستفسار',
    types: ['طالب / ولي أمر', 'مدرس', 'شراكات ومدارس', 'دعم فني'], message: 'رسالتك', send: 'إرسال', sent: 'شكراً! وصلت رسالتك وسنرد عليك قريباً.', whatsapp: 'واتساب المستشار الأكاديمي', emailUs: 'البريد',
  },
  legal: {
    terms: { t: 'الشروط والأحكام', b: ['باستخدامك منصة درس فأنت توافق على هذه الشروط.', 'تتم جميع الحجوزات والمدفوعات عبر المنصة، ويُمنع تبادل وسائل التواصل خارجها.', 'يلتزم المدرس بالمواعيد وسياسة الإلغاء التي حددها، ويلتزم الطالب بآداب التعامل.', 'تحتفظ المنصة بعمولة من أجر الدرس مقابل خدماتها.'] },
    privacy: { t: 'سياسة الخصوصية', b: ['نجمع فقط البيانات اللازمة لتقديم الخدمة: الاسم، رقم واتساب، المرحلة الدراسية، وسجل الدروس.', 'لا نبيع بياناتك لأي طرف ثالث.', 'تُسجَّل المحادثات والمكالمات لضمان الجودة والأمان وتُحذف وفق سياسة الاحتفاظ.', 'يمكنك طلب حذف حسابك وبياناتك في أي وقت من الإعدادات.'] },
    refund: { t: 'سياسة الاسترجاع', b: ['ضمان الساعة الأولى: استرداد كامل إن لم تكن راضياً عن أول ساعة مع مدرس جديد.', 'الإلغاء قبل مهلة المدرس: يعود المبلغ كاملاً لرصيدك.', 'عدم حضور المدرس: استرداد كامل بعد التحقق.', 'يمكنك طلب تحويل رصيد المحفظة إلى حسابك البنكي.'] },
  },
  footer: { tagline: 'مدرّسك الخاص، متى ما احتجته.', product: 'المنصة', company: 'الشركة', legal: 'قانوني', rights: 'جميع الحقوق محفوظة', terms: 'الشروط والأحكام', privacy: 'سياسة الخصوصية', refund: 'سياسة الاسترجاع' },
  langSwitch: 'English',
};

type Dict = typeof ar;

const en: Dict = {
  brand: 'Dars',
  meta: {
    title: 'Dars | Online & in-person private tutors',
    description: 'Dars connects students with verified private tutors for online and in-person lessons, plus instant homework and exam help in minutes.',
  },
  nav: { home: 'Home', tutors: 'Find a tutor', become: 'Become a tutor', pricing: 'Pricing', about: 'About', faq: 'FAQ', contact: 'Contact', getApp: 'Get the app', signIn: 'Sign in', menu: 'Menu' },
  hero: {
    badge: 'Verified tutors · instant help',
    title: 'Your private tutor,',
    titleAccent: 'whenever you need',
    subtitle: 'Online and in-person lessons with verified tutors, plus instant help with homework and exams in minutes — for every level and curriculum.',
    searchPlaceholder: 'What do you want to learn? Math, IELTS, Physics…',
    searchCta: 'Find a tutor',
    liveCta: 'Speak to a tutor now',
    popular: 'Popular:',
  },
  stats: [
    { value: '12', label: 'subjects & skills' },
    { value: '6', label: 'study levels, pre-school to university' },
    { value: '100%', label: 'first-hour money-back guarantee' },
    { value: '90 sec', label: 'to reach every tutor online with your question' },
  ],
  live: {
    eyebrow: 'Live help',
    title: 'Stuck on homework? Talk to a tutor in minutes',
    body: 'Type, record or snap your question and we send it to every tutor who is online. Pick one of the tutors who accept and start chatting or calling in the app.',
    steps: ['Send your question as text, voice or photo', 'It reaches every available tutor', 'Connect instantly with a tutor who accepts'],
    cta: 'Try it now',
  },
  how: {
    title: 'How Dars works',
    steps: [
      { t: 'Search & choose', d: 'Filter by subject, level, curriculum and price, and see real reviews plus an AI match score.' },
      { t: 'Book & pay safely', d: 'Single lessons or hour packages with up to 25% off. Pay by card, Apple Pay or in 3 instalments.' },
      { t: 'Learn & progress', d: 'Join the virtual classroom with video and whiteboard, and get a summary and homework after every lesson.' },
    ],
  },
  subjects: { title: 'Explore by subject', subtitle: 'From early-years foundations to university and professional skills', all: 'All subjects' },
  featured: { title: 'Featured tutors', subtitle: 'AI picks based on rating, experience and match', viewAll: 'View all tutors' },
  tutor: {
    perHour: '/hr', from: 'From', reviews: 'reviews', available: 'Available now', busy: 'Busy', instant: 'Instant booking', match: 'match', newTutor: 'Newly joined',
    upTo: 'Up to', onPackages: 'off packages', view: 'View profile', book: 'Book a lesson', message: 'Message',
    about: 'About the tutor', subjects: 'Subjects', speaks: 'Speaks', country: 'Country', experience: 'Experience', years: 'years', hoursTaught: 'hours taught', students: 'students',
    fees: 'Fees by study level', packages: 'Packages', hours: 'hours', policies: 'Policies', cancel: 'Free cancellation up to {h} hours before the lesson',
    reviewsTitle: 'Student reviews', reviewsNote: 'Only students who had a lesson can leave a review', online: 'Online', inPerson: 'In person', mode: 'Teaching mode',
    bookInApp: 'Finish booking in the app', back: 'Back to results', notFound: 'Tutor not found',
  },
  browse: {
    title: 'Find a tutor', subtitle: 'Verified tutors for every subject and level', search: 'Search by name or subject…', subject: 'Subject', all: 'All',
    sort: 'Sort', best: 'Best match (AI)', price: 'Lowest price', rating: 'Top rated', availableNow: 'Available now', instantOnly: 'Instant booking',
    gender: 'Gender', male: 'Male', female: 'Female', maxPrice: 'Max price per hour', results: 'results', empty: 'No matching tutors', emptyCta: 'Let our advisor help',
  },
  guarantee: { title: 'Satisfaction guarantee', body: 'Not happy with your first hour with any tutor? We refund you in full — no questions asked.' },
  safety: { title: 'Safe & trusted', items: ['Every tutor passes ID and credential checks', 'Chats and calls stay in the app and are recorded for quality', 'Payments go through Dars only — your money is protected until the lesson happens'] },
  testimonials: {
    title: 'What students and parents say',
    items: [
      { q: 'My math grade went from 70 to 94 in one term. Clear explanations and a very patient tutor.', n: 'Layan', r: 'High-school student, Damascus' },
      { q: 'Live help is the best part — my son records his question and gets a tutor within minutes.', n: 'Um Yousef', r: 'Parent, Riyadh' },
      { q: 'I got IELTS band 7.5 after just two months with Lama, and the package saved me 25%.', n: 'Sara', r: 'University student, Amman' },
    ],
  },
  tutorsCta: { title: 'Are you a tutor?', body: 'Join Dars, set your own prices and hours, and teach students across the Arab world online or in your city.', cta: 'Apply as a tutor' },
  app: { title: 'All of it in your pocket', body: 'Get the Dars app for fast booking, live help, in-app calls and notifications.', ios: 'App Store', android: 'Android', androidSmall: 'Download for', older: 'Older phone? Use this version', web: 'Open the web app' },
  become: {
    title: 'Teach on Dars and earn on your terms',
    subtitle: 'Online or in person near you. You set the price and hours — we bring the students and guarantee payment.',
    cta: 'Start your application',
    steps: [
      { t: 'Build your profile', d: 'Tell students about yourself, what you teach, your experience and certificates, and add an intro video.' },
      { t: 'Meet students everywhere', d: 'We help school and university students, language learners and professionals find you.' },
      { t: 'Get booked', d: 'Instant booking from your calendar or requests you approve, plus live-help requests.' },
      { t: 'Get paid', d: 'Students pay upfront, so your fee is guaranteed. Withdraw by bank transfer or PayPal.' },
    ],
    perks: ['Clear 15% commission only', 'Package discounts you control (1–50%)', 'Free video classroom with whiteboard', 'Dashboard for earnings & reviews', 'Go "Available now" for instant requests'],
    calcTitle: 'Estimate your earnings',
    calcRate: 'Hourly rate', calcHours: 'Hours per week', calcMonthly: 'Approx. monthly net', calcNote: 'After the 15% platform commission, based on 4.3 weeks per month.',
    reqTitle: 'Requirements',
    reqs: ['A university degree or proven experience in your field', 'Valid ID and a clear profile photo', 'Stable internet for online lessons', 'Accept the ethical pledge: all bookings through Dars'],
  },
  pricing: {
    title: 'Flexible packages & pricing',
    subtitle: 'Pay only for the time you need. No forced subscriptions.',
    payg: { t: 'Single lesson', p: 'From $8', u: '/hr', d: 'Under 4 hours, at the tutor’s rate for your level', f: ['25, 50 or 100 minutes', 'Free cancellation per tutor policy', 'First-hour guarantee'] },
    pack: { t: 'Hours package', p: 'Save up to 25%', u: '', d: '4+ hours with the same tutor', f: ['Discount set by the tutor', 'Hours never expire', 'Book lessons from the package in one tap'] },
    subsTitle: 'School follow-up subscriptions for parents',
    subsBody: 'Monthly follow-up with an academic advisor, evaluation reports and flexible scheduling across subjects.',
    subs: [
      { t: 'Foundation', p: '$79', d: 'For a student weak in one or two subjects', f: ['8 hours / month', 'Monthly evaluation report', 'Flexible times'] },
      { t: 'Strength', p: '$149', d: 'Daily follow-up in 3+ subjects', f: ['16 hours / month', 'Advisor plans the week', 'Report after every lesson'], popular: true },
      { t: 'Excellence', p: '$249', d: 'Intensive support in most subjects and finals prep', f: ['28 hours / month', 'Mock exams', 'Priority live help'] },
    ],
    popular: 'Most popular', perMonth: '/month', subscribe: 'Subscribe',
    payTitle: 'Local, secure payment methods',
    pays: ['Visa / Mastercard / Mada', 'Apple Pay & Google Pay', 'Split in 3 (Tamara / Tabby)', 'Bank transfer', 'Wallet credit'],
  },
  about: {
    title: 'About us',
    body: 'Dars is an Arabic-first platform connecting students with great private tutors, online and in person. We started because finding a trusted tutor still depends on word of mouth and group chats — and because students need help the moment they get stuck, not days later.',
    mission: 'Our mission', missionBody: 'Every Arab student gets an excellent tutor whenever they need one, at a fair price — and every tutor earns a dignified, flexible income.',
    values: [{ t: 'Trust', d: 'Every tutor verified, only real reviews.' }, { t: 'Speed', d: 'Live help in minutes.' }, { t: 'Fairness', d: 'Clear prices, low commission.' }, { t: 'Impact', d: 'We measure progress, not hours.' }],
  },
  faq: {
    title: 'Frequently asked questions',
    items: [
      { q: 'How do I choose the right tutor?', a: 'Use search and filters for subject, level, curriculum and price. We show an AI match score and reviews from real students. If you are unsure, our academic advisor can help on WhatsApp.' },
      { q: 'What is live help?', a: 'Send your question as text, voice or a photo and it reaches every tutor who is online. Within minutes you see who accepted and can start chatting or calling.' },
      { q: 'How do packages work?', a: 'Book 4+ hours with the same tutor to get a discount the tutor sets (usually up to 25%). The hours stay in your balance and you book from them anytime.' },
      { q: 'What if I am not satisfied?', a: 'If you are not happy with your first hour with any tutor, we refund you in full. You can also report a tutor no-show for a refund.' },
      { q: 'Which payment methods are available?', a: 'Bank cards and Mada, Apple Pay, split-in-3 instalments, bank transfer and wallet credit.' },
      { q: 'Can I cancel or reschedule?', a: 'Yes, from "My lessons". Cancelling is free before the tutor’s notice period (2 to 72 hours) and the amount returns to your balance.' },
      { q: 'How do I become a tutor on Dars?', a: 'Apply on the "Become a tutor" page, complete your profile and fees and upload your CV. We review profiles within 24–48 hours.' },
    ],
  },
  contact: {
    title: 'Contact us', subtitle: 'Our team is available daily, 9 AM – 11 PM', name: 'Full name', email: 'Email or WhatsApp', type: 'Inquiry type',
    types: ['Student / parent', 'Tutor', 'Partnerships & schools', 'Technical support'], message: 'Your message', send: 'Send', sent: 'Thanks! We received your message and will reply soon.', whatsapp: 'Academic advisor on WhatsApp', emailUs: 'Email',
  },
  legal: {
    terms: { t: 'Terms & Conditions', b: ['By using Dars you agree to these terms.', 'All bookings and payments happen through the platform; exchanging contact details off-platform is not allowed.', 'Tutors keep their schedule and cancellation policy; students follow the code of conduct.', 'Dars keeps a commission from the lesson fee for its services.'] },
    privacy: { t: 'Privacy Policy', b: ['We collect only what the service needs: name, WhatsApp number, study level and lesson history.', 'We never sell your data to third parties.', 'Chats and calls are recorded for quality and safety and deleted per our retention policy.', 'You can request deletion of your account and data at any time in Settings.'] },
    refund: { t: 'Refund Policy', b: ['First-hour guarantee: full refund if you are not satisfied with your first hour with a new tutor.', 'Cancelling before the tutor’s notice period: full amount back to your balance.', 'Tutor no-show: full refund after verification.', 'You can request a transfer of your wallet balance to your bank account.'] },
  },
  footer: { tagline: 'Your private tutor, whenever you need.', product: 'Product', company: 'Company', legal: 'Legal', rights: 'All rights reserved', terms: 'Terms & Conditions', privacy: 'Privacy Policy', refund: 'Refund Policy' },
  langSwitch: 'العربية',
};

const dicts: Record<Lang, Dict> = { ar, en };
export const getDict = (l: Lang): Dict => dicts[l];
export type { Dict };
