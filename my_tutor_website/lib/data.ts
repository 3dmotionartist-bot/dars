import type { Lang } from './i18n';

export type T = { ar: string; en: string };
export const t = (v: T, l: Lang) => v[l];

export type IconName =
  | 'calc' | 'globe' | 'book' | 'atom' | 'flask' | 'dna' | 'award' | 'code' | 'quran' | 'chart' | 'chat' | 'kid';

export type Subject = { id: string; name: T; icon: IconName; color: string };

export const subjects: Subject[] = [
  { id: 'math', name: { ar: 'الرياضيات', en: 'Math' }, icon: 'calc', color: '#2F6BFF' },
  { id: 'english', name: { ar: 'اللغة الإنجليزية', en: 'English' }, icon: 'globe', color: '#7B61FF' },
  { id: 'arabic', name: { ar: 'اللغة العربية', en: 'Arabic' }, icon: 'book', color: '#0E8F7E' },
  { id: 'physics', name: { ar: 'الفيزياء', en: 'Physics' }, icon: 'atom', color: '#F59E0B' },
  { id: 'chemistry', name: { ar: 'الكيمياء', en: 'Chemistry' }, icon: 'flask', color: '#22B573' },
  { id: 'biology', name: { ar: 'الأحياء', en: 'Biology' }, icon: 'dna', color: '#E5484D' },
  { id: 'exams', name: { ar: 'اختبارات دولية', en: 'Test prep' }, icon: 'award', color: '#FF7A45' },
  { id: 'programming', name: { ar: 'البرمجة', en: 'Programming' }, icon: 'code', color: '#12203A' },
  { id: 'quran', name: { ar: 'القرآن والتجويد', en: 'Quran & Tajweed' }, icon: 'quran', color: '#0A6E61' },
  { id: 'accounting', name: { ar: 'المحاسبة والمالية', en: 'Accounting' }, icon: 'chart', color: '#5B45D6' },
  { id: 'french', name: { ar: 'اللغة الفرنسية', en: 'French' }, icon: 'chat', color: '#0EA5E9' },
  { id: 'kids', name: { ar: 'تأسيس الأطفال', en: 'Kids foundation' }, icon: 'kid', color: '#EC4899' },
];

export const subjectById = (id: string) => subjects.find((s) => s.id === id) ?? subjects[0];

export const levels: { id: string; name: T; factor: number }[] = [
  { id: 'elementary', name: { ar: 'ابتدائي', en: 'Elementary' }, factor: 0.85 },
  { id: 'middle', name: { ar: 'إعدادي', en: 'Middle school' }, factor: 0.9 },
  { id: 'high', name: { ar: 'ثانوي', en: 'High school' }, factor: 1 },
  { id: 'university', name: { ar: 'جامعي', en: 'University' }, factor: 1.2 },
  { id: 'adult', name: { ar: 'مهنيون', en: 'Professionals' }, factor: 1.3 },
];

export const popular: T[] = [
  { ar: 'IELTS', en: 'IELTS' },
  { ar: 'رياضيات ثانوي', en: 'High-school math' },
  { ar: 'فيزياء', en: 'Physics' },
  { ar: 'SAT', en: 'SAT' },
  { ar: 'بايثون', en: 'Python' },
];

export type Review = { by: T; stars: number; text: T; date: string };

export type Tutor = {
  id: string;
  name: T;
  headline: T;
  about: T;
  subjects: string[];
  tags: T[];
  rating: number;
  reviews: number;
  hours: number;
  students: number;
  price: number;
  maxDiscount: number;
  available: boolean;
  instant: boolean;
  isNew: boolean;
  gender: 'm' | 'f';
  country: T;
  languages: T[];
  years: number;
  match: number;
  color: string;
  inPerson: boolean;
  cancelHours: number;
  reviewList: Review[];
};

export const tutors: Tutor[] = [
  {
    id: 'samer-halabi', name: { ar: 'م. سامر الحلبي', en: 'Samer Al-Halabi' },
    headline: { ar: 'مهندس ومدرس رياضيات وفيزياء بخبرة 12 سنة', en: 'Engineer teaching math & physics for 12 years' },
    about: { ar: 'أدرّس الرياضيات والفيزياء لطلاب الثانوي والجامعة منذ 12 عاماً. أركز على الفهم العميق بدلاً من الحفظ، وأبني لكل طالب خطة تناسب مستواه وموعد اختباره. ساعدت أكثر من 600 طالب على رفع درجاتهم.', en: 'I have taught math and physics to high-school and university students for 12 years. I focus on real understanding instead of memorising and build each student a plan for their level and exam date. 600+ students have raised their grades with me.' },
    subjects: ['math', 'physics'], tags: [{ ar: 'تفاضل وتكامل', en: 'Calculus' }, { ar: 'جبر', en: 'Algebra' }, { ar: 'قدرات', en: 'Aptitude' }],
    rating: 4.9, reviews: 214, hours: 3120, students: 612, price: 15, maxDiscount: 20, available: true, instant: true, isNew: false, gender: 'm',
    country: { ar: 'سوريا', en: 'Syria' }, languages: [{ ar: 'العربية (أم)', en: 'Arabic (native)' }, { ar: 'الإنجليزية (متقدم)', en: 'English (advanced)' }],
    years: 12, match: 96, color: '#2F6BFF', inPerson: true, cancelHours: 12,
    reviewList: [
      { by: { ar: 'ليان', en: 'Layan' }, stars: 5, text: { ar: 'شرح ممتاز وصبور جداً، رفعت درجتي من 70 إلى 94.', en: 'Excellent and very patient — my grade went from 70 to 94.' }, date: '2026-10-28' },
      { by: { ar: 'أحمد', en: 'Ahmad' }, stars: 5, text: { ar: 'أفضل مدرس فيزياء تعاملت معه.', en: 'Best physics tutor I have had.' }, date: '2026-10-11' },
    ],
  },
  {
    id: 'lama-khatib', name: { ar: 'أ. لمى الخطيب', en: 'Lama Al-Khatib' },
    headline: { ar: 'مدرّسة إنجليزي ومدرّبة IELTS معتمدة', en: 'Certified English & IELTS trainer' },
    about: { ar: 'حاصلة على شهادة CELTA ودرجة 8.5 في IELTS. أساعد الطلاب على تحسين المحادثة والكتابة والاستعداد لاختبارات IELTS وTOEFL وSTEP بخطط أسبوعية ونماذج اختبارات حقيقية.', en: 'CELTA-certified with IELTS band 8.5. I help students improve speaking and writing and prepare for IELTS, TOEFL and STEP with weekly plans and real mock tests.' },
    subjects: ['english', 'exams'], tags: [{ ar: 'IELTS', en: 'IELTS' }, { ar: 'محادثة', en: 'Conversation' }, { ar: 'STEP', en: 'STEP' }],
    rating: 4.8, reviews: 167, hours: 2400, students: 390, price: 18, maxDiscount: 25, available: true, instant: true, isNew: false, gender: 'f',
    country: { ar: 'الأردن', en: 'Jordan' }, languages: [{ ar: 'العربية (أم)', en: 'Arabic (native)' }, { ar: 'الإنجليزية (طلاقة)', en: 'English (fluent)' }],
    years: 9, match: 91, color: '#7B61FF', inPerson: false, cancelHours: 24,
    reviewList: [{ by: { ar: 'سارة', en: 'Sara' }, stars: 5, text: { ar: 'حصلت على 7.5 في IELTS بعد شهرين معها!', en: 'Got band 7.5 after two months with her!' }, date: '2026-10-20' }],
  },
  {
    id: 'reem-ali', name: { ar: 'د. ريم العلي', en: 'Dr. Reem Al-Ali' },
    headline: { ar: 'دكتوراه في الكيمياء — ثانوي وجامعة', en: 'PhD in Chemistry — high school & university' },
    about: { ar: 'أستاذة كيمياء جامعية سابقة، أبسّط الكيمياء العضوية والتحليلية بالأمثلة والرسوم. أدرّس المناهج السعودية والسورية والـIB.', en: 'Former university chemistry lecturer. I make organic and analytical chemistry simple with examples and diagrams. Saudi, Syrian and IB curricula.' },
    subjects: ['chemistry', 'biology'], tags: [{ ar: 'كيمياء عضوية', en: 'Organic chem' }, { ar: 'IB', en: 'IB' }],
    rating: 4.9, reviews: 98, hours: 1500, students: 210, price: 22, maxDiscount: 15, available: false, instant: false, isNew: false, gender: 'f',
    country: { ar: 'السعودية', en: 'Saudi Arabia' }, languages: [{ ar: 'العربية (أم)', en: 'Arabic (native)' }, { ar: 'الإنجليزية (متقدم)', en: 'English (advanced)' }],
    years: 15, match: 88, color: '#22B573', inPerson: false, cancelHours: 24,
    reviewList: [{ by: { ar: 'هيا', en: 'Haya' }, stars: 5, text: { ar: 'فهمت الكيمياء العضوية لأول مرة.', en: 'I understood organic chemistry for the first time.' }, date: '2026-10-15' }],
  },
  {
    id: 'hiba-darwish', name: { ar: 'أ. هبة درويش', en: 'Hiba Darwish' },
    headline: { ar: 'تأسيس قراءة وكتابة ورياضيات للأطفال', en: 'Reading, writing & math foundations for kids' },
    about: { ar: 'معلمة صفوف أولى بخبرة 10 سنوات. أستخدم الألعاب التعليمية والقصص لتأسيس الأطفال من 4 إلى 9 سنوات، مع تقرير أسبوعي لولي الأمر.', en: 'Early-years teacher for 10 years. Games and stories build strong foundations for ages 4–9, with a weekly report for parents.' },
    subjects: ['kids', 'arabic'], tags: [{ ar: 'تأسيس', en: 'Foundations' }, { ar: 'قراءة', en: 'Reading' }],
    rating: 5.0, reviews: 120, hours: 1900, students: 180, price: 12, maxDiscount: 20, available: true, instant: true, isNew: false, gender: 'f',
    country: { ar: 'سوريا', en: 'Syria' }, languages: [{ ar: 'العربية (أم)', en: 'Arabic (native)' }],
    years: 10, match: 82, color: '#EC4899', inPerson: true, cancelHours: 12, reviewList: [],
  },
  {
    id: 'omar-najjar', name: { ar: 'أ. عمر النجار', en: 'Omar Al-Najjar' },
    headline: { ar: 'مطوّر برمجيات يعلّم بايثون وتطوير الويب', en: 'Software engineer teaching Python & web dev' },
    about: { ar: 'أعمل مطوراً منذ 8 سنوات. أعلّم البرمجة من الصفر بمشاريع عملية وأساعد طلاب الجامعة في مشاريع التخرج.', en: 'Developer for 8 years. I teach programming from scratch through real projects and help with graduation projects.' },
    subjects: ['programming'], tags: [{ ar: 'بايثون', en: 'Python' }, { ar: 'جافاسكربت', en: 'JavaScript' }],
    rating: 4.7, reviews: 64, hours: 820, students: 120, price: 20, maxDiscount: 10, available: true, instant: false, isNew: false, gender: 'm',
    country: { ar: 'الإمارات', en: 'UAE' }, languages: [{ ar: 'العربية (أم)', en: 'Arabic (native)' }, { ar: 'الإنجليزية (طلاقة)', en: 'English (fluent)' }],
    years: 8, match: 74, color: '#12203A', inPerson: false, cancelHours: 12, reviewList: [],
  },
  {
    id: 'yousef-qasem', name: { ar: 'الشيخ يوسف القاسم', en: 'Sheikh Yousef Al-Qasem' },
    headline: { ar: 'مجاز في القراءات — تحفيظ وتجويد', en: 'Licensed Quran reciter — memorisation & Tajweed' },
    about: { ar: 'حاصل على إجازة برواية حفص، أدرّس التلاوة والتجويد والتحفيظ للصغار والكبار بأسلوب ميسّر.', en: 'Ijazah in Hafs. I teach recitation, Tajweed and memorisation to children and adults.' },
    subjects: ['quran', 'arabic'], tags: [{ ar: 'تجويد', en: 'Tajweed' }, { ar: 'تحفيظ', en: 'Memorisation' }],
    rating: 4.9, reviews: 75, hours: 2200, students: 260, price: 10, maxDiscount: 15, available: false, instant: true, isNew: false, gender: 'm',
    country: { ar: 'مصر', en: 'Egypt' }, languages: [{ ar: 'العربية (أم)', en: 'Arabic (native)' }],
    years: 14, match: 63, color: '#0A6E61', inPerson: false, cancelHours: 12, reviewList: [],
  },
  {
    id: 'nour-haddad', name: { ar: 'أ. نور حداد', en: 'Nour Haddad' },
    headline: { ar: 'محاسبة قانونية — محاسبة ومالية للجامعة', en: 'CPA — accounting & finance for university' },
    about: { ar: 'محاسبة قانونية معتمدة. أشرح المحاسبة المالية والتكاليف والإدارة المالية وأحضّر لاختبارات CMA.', en: 'Certified public accountant teaching financial and cost accounting and finance, plus CMA prep.' },
    subjects: ['accounting'], tags: [{ ar: 'محاسبة مالية', en: 'Financial accounting' }, { ar: 'CMA', en: 'CMA' }],
    rating: 4.6, reviews: 41, hours: 540, students: 88, price: 17, maxDiscount: 0, available: true, instant: false, isNew: true, gender: 'f',
    country: { ar: 'لبنان', en: 'Lebanon' }, languages: [{ ar: 'العربية (أم)', en: 'Arabic (native)' }, { ar: 'الفرنسية (متقدم)', en: 'French (advanced)' }],
    years: 6, match: 58, color: '#5B45D6', inPerson: false, cancelHours: 24, reviewList: [],
  },
  {
    id: 'karim-mansour', name: { ar: 'أ. كريم منصور', en: 'Karim Mansour' },
    headline: { ar: 'مدرس فرنسي — DELF وبكالوريا فرنسية', en: 'French tutor — DELF & French Bac' },
    about: { ar: 'خريج جامعة السوربون، أدرّس الفرنسية لجميع المستويات وأحضّر لاختبارات DELF وDALF.', en: 'Sorbonne graduate teaching French at every level and preparing for DELF and DALF.' },
    subjects: ['french'], tags: [{ ar: 'DELF', en: 'DELF' }, { ar: 'محادثة', en: 'Conversation' }],
    rating: 4.8, reviews: 52, hours: 700, students: 95, price: 16, maxDiscount: 10, available: true, instant: true, isNew: true, gender: 'm',
    country: { ar: 'المغرب', en: 'Morocco' }, languages: [{ ar: 'العربية (أم)', en: 'Arabic (native)' }, { ar: 'الفرنسية (طلاقة)', en: 'French (fluent)' }],
    years: 5, match: 55, color: '#0EA5E9', inPerson: false, cancelHours: 12, reviewList: [],
  },
];

export const tutorById = (id: string) => tutors.find((x) => x.id === id);

export const initialOf = (name: string) => name.replace(/^(م\.|أ\.|د\.|الشيخ|Dr\.|Sheikh)\s*/, '').charAt(0);

export const discountFor = (tutor: Tutor, hours: number) => {
  if (!tutor.maxDiscount || hours < 4) return 0;
  const f = hours >= 20 ? 1 : hours >= 12 ? 0.75 : hours >= 8 ? 0.5 : 0.25;
  return Math.max(1, Math.round(tutor.maxDiscount * f));
};

export const BASE = process.env.NEXT_PUBLIC_BASE_PATH || '';
export const APP_URL = process.env.NEXT_PUBLIC_APP_URL || 'https://app.dars.app';
export const WHATSAPP = 'https://wa.me/963000000000';
