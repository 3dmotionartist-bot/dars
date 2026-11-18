// Terms & Conditions and Privacy Policy (Round E4). DRAFT texts written from how Dars works today —
// the owner and a lawyer must review them before launch. Items in [square brackets] are for the owner to fill.
// After changing a text, raise "terms_version" in the admin Settings so every user is asked to accept again.
import type { Lang } from './i18n';

export type LegalDoc = { t: string; intro: string; s: { h: string; p: string[] }[] };
export type LegalKey = 'terms' | 'privacy';

export const legalVersion = 1;
export const legalUpdated = { ar: 'نوفمبر 2026', en: 'November 2026' };

export const legal: Record<Lang, Record<LegalKey, LegalDoc>> = {
  ar: {
    terms: {
      t: 'الشروط والأحكام',
      intro: 'تنظم هذه الشروط استخدامك لتطبيق وموقع "درس" (المنصة) التي تربط الطلاب وأولياء الأمور بمدرسين خصوصيين. بإنشاء حساب أو استخدام المنصة فأنت توافق عليها.',
      s: [
        { h: '1. الحسابات والأعمار', p: [
          'يجب أن تكون المعلومات التي تقدمها صحيحة، وأنت مسؤول عن حسابك وعن كل ما يتم من خلاله.',
          'الطلاب دون 13 سنة يستخدمون المنصة فقط من خلال حساب ولي أمر يضيفهم كأطفال ويحجز لهم.',
          'الطلاب من 13 إلى 17 سنة يحتاجون موافقة ولي الأمر (برمز ربط) قبل الحجز أو المراسلة أو طلب المساعدة الفورية، ويستطيع ولي الأمر رؤية دروسهم ومحادثاتهم.',
          'حسابات المدرسين وأولياء الأمور للبالغين (18 سنة فأكثر).',
        ] },
        { h: '2. المدرسون', p: [
          'يُطلب من المدرس رفع وثيقة هوية وشهادة، ويظهر ملفه للطلاب وعليه علامة "موثّق" بعد مراجعة فريق درس وموافقته فقط.',
          'بعد الاعتماد، تظهر تعديلات الاسم والنبذة والسعر والفيديو بعد مراجعتها.',
          'يلتزم المدرس بقواعد سلوك المدرس التي وافق عليها عند التسجيل، وبمواعيده وسياسة الإلغاء التي حددها.',
          'المدرس يقدّم دروسه بشكل مستقل، ودرس منصة وسيطة للحجز والدفع والتواصل. [يراجع المحامي طبيعة العلاقة]',
        ] },
        { h: '3. الحجز والدفع والعمولة', p: [
          'تتم جميع الحجوزات والمدفوعات داخل المنصة فقط. يُمنع الاتفاق على دروس أو دفعات خارج درس.',
          'يُحسب سعر الدرس من سعر المدرس ومدة الدرس، ويظهر قبل التأكيد. قد تُدفع الحجوزات من رصيد المحفظة أو بتحويل مع إيصال يراجعه فريق درس.',
          'تحتفظ درس بعمولة من أجر كل درس مقابل خدماتها.',
          'الإلغاء والاسترداد وفق سياسة الإلغاء الخاصة بالمدرس وسياسة الاسترجاع المنشورة.',
          'الدروس الحضورية للطلاب دون 18 سنة يحجزها ولي الأمر فقط.',
        ] },
        { h: '4. التواصل والأمان', p: [
          'يُمنع تبادل أرقام الهواتف أو البريد الإلكتروني أو حسابات التواصل الاجتماعي أو روابط التواصل الخارجي داخل المنصة.',
          'تُفحص الرسائل وأسئلة المساعدة الفورية وملفات المدرسين والتقييمات وروابط الدروس آلياً بحثاً عن معلومات التواصل. الرسائل التي تحتويها تُحجب عن الطرف الآخر، وقد يراجعها فريق درس.',
          'المكالمات الصوتية والمرئية مباشرة بين الطرفين ولا تسجلها درس. تُحفظ أوقات دخول وخروج الدرس لحل الخلافات.',
          'يمكنك الإبلاغ عن محادثة أو حظر أي شخص؛ الحظر يمنع الرسائل والمكالمات بين الطرفين.',
        ] },
        { h: '5. الممنوعات', p: [
          'الإساءة أو التحرش أو التمييز، أو أي محتوى غير لائق، خاصة مع القاصرين.',
          'طلب صور أو معلومات شخصية من الطلاب، أو محاولة التواصل معهم خارج المنصة.',
          'انتحال الشخصية أو تقديم وثائق أو مؤهلات غير صحيحة.',
          'التلاعب بالحجوزات أو المدفوعات أو التقييمات.',
        ] },
        { h: '6. إيقاف الحساب وحذفه', p: [
          'يحق لدرس إيقاف أي حساب يخالف هذه الشروط، مع إبلاغ صاحبه بالسبب حين يكون ذلك ممكناً.',
          'يمكنك حذف حسابك من التطبيق (حسابي ← حذف حسابي). يُحذف بعد 14 يوماً ويمكنك التراجع قبلها بتسجيل الدخول. تبقى سجلات الدروس والمدفوعات بدون بياناتك الشخصية لأغراض المحاسبة.',
        ] },
        { h: '7. المسؤولية والتعديلات', p: [
          'تبذل درس جهدها لتشغيل المنصة بشكل مستمر وآمن، لكنها لا تضمن خلوها من الأعطال. [حدود المسؤولية يحددها المحامي]',
          'قد نعدّل هذه الشروط؛ عند تعديلها نطلب منك الموافقة على النسخة الجديدة داخل التطبيق.',
          'القانون المطبق والجهة المختصة: [يحددها المحامي].',
          'للتواصل: [البريد الإلكتروني / رقم الدعم].',
        ] },
      ],
    },
    privacy: {
      t: 'سياسة الخصوصية',
      intro: 'توضح هذه السياسة البيانات التي تجمعها درس وكيف تستخدمها وتحميها. الجهة المسؤولة عن البيانات: [اسم المالك / الشركة، العنوان، البريد].',
      s: [
        { h: '1. البيانات التي نجمعها', p: [
          'الحساب: الاسم، رقم الهاتف أو البريد الإلكتروني، نوع الحساب، سنة الميلاد (للطلاب)، المرحلة الدراسية والمنهج، المدينة، الصورة الشخصية إن أضفتها.',
          'المدرسون: النبذة والمواد والأسعار وفيديو التعريف (علنية)، ووثيقة الهوية والشهادة والسيرة الذاتية (خاصة: لا يراها إلا المدرس وفريق درس).',
          'الدروس والمدفوعات: الحجوزات، رصيد المحفظة، صور إيصالات التحويل، طلبات تحويل الأرباح.',
          'المحادثات: الرسائل والرسائل الصوتية والصور والملفات وأسئلة المساعدة الفورية. المكالمات لا تُسجَّل.',
          'بيانات تقنية: رمز الإشعارات للجهاز، لغة التطبيق، أوقات دخول وخروج الدروس، وعنوان الإنترنت عند طلب خادم المكالمات (للحد من إساءة الاستخدام).',
        ] },
        { h: '2. كيف نستخدمها', p: [
          'تقديم الخدمة: البحث عن مدرس، الحجز، الدفع، المحادثة، المكالمات، الإشعارات والتذكير بالدروس.',
          'الأمان: فحص آلي للنصوص بحثاً عن معلومات التواصل وإخفاؤها، ومراجعة الحالات المشتبه بها من فريق درس، والتحقق من وثائق المدرسين.',
          'التحقق من الإيصالات وحل الخلافات (مثل عدم الحضور) والدعم.',
          'لا نستخدم بياناتك للإعلانات ولا نبيعها لأي طرف.',
        ] },
        { h: '3. الأطفال', p: [
          'الطلاب دون 13 سنة لا ينشئون حساباً؛ يضيفهم ولي الأمر كملف داخل حسابه.',
          'الطلاب من 13 إلى 17 سنة يحتاجون موافقة ولي الأمر، ويستطيع ولي الأمر المرتبط رؤية دروسهم ومحادثاتهم دون الكتابة فيها.',
        ] },
        { h: '4. مع من نشارك البيانات', p: [
          'الطرف الآخر في الدرس أو المحادثة يرى ما يلزم فقط (الاسم والصورة والرسائل الموجهة إليه).',
          'مزودو خدمات يعملون لصالحنا: الاستضافة وقاعدة البيانات (Supabase)، الإشعارات (Firebase من Google)، خوادم ربط المكالمات (Cloudflare / Metered)، استضافة الموقع (GitHub). [يُكمل المالك القائمة]',
          'الجهات الرسمية عندما يفرض القانون ذلك.',
        ] },
        { h: '5. مدة الاحتفاظ', p: [
          'نحتفظ ببيانات الحساب طالما الحساب قائم.',
          'عند حذف الحساب تُزال البيانات الشخصية ونصوص الرسائل خلال 14 يوماً، وتبقى سجلات الدروس والمدفوعات بدون اسمك لأغراض المحاسبة. [مدة الاحتفاظ بالسجلات المالية يحددها المحاسب]',
        ] },
        { h: '6. حقوقك', p: [
          'يمكنك الاطلاع على بياناتك وتعديلها من التطبيق، وحذف حسابك من: حسابي ← حذف حسابي.',
          'يمكنك سحب موافقتك بحذف حسابك. لأي طلب آخر تواصل معنا: [البريد].',
        ] },
        { h: '7. الحماية والتعديلات', p: [
          'تُحفظ البيانات لدى مزودين موثوقين، ويصل كل مستخدم فقط لما يخصه عبر قواعد حماية في قاعدة البيانات، والوثائق الخاصة في تخزين غير علني.',
          'عند تعديل هذه السياسة نطلب موافقتك على النسخة الجديدة داخل التطبيق.',
        ] },
      ],
    },
  },
  en: {
    terms: {
      t: 'Terms & Conditions',
      intro: 'These terms govern your use of the Dars app and website (the platform), which connects students and parents with private tutors. By creating an account or using Dars you agree to them.',
      s: [
        { h: '1. Accounts and ages', p: [
          'The information you give must be true. You are responsible for your account and everything done with it.',
          'Students under 13 use Dars only through a parent\'s account, which adds them as children and books for them.',
          'Students aged 13–17 need a parent\'s approval (with a link code) before booking, chatting or asking for live help, and the linked parent can see their lessons and chats.',
          'Tutor and parent accounts are for adults (18+).',
        ] },
        { h: '2. Tutors', p: [
          'Tutors upload an ID and a certificate. A tutor\'s profile is shown to students, with the "verified" badge, only after the Dars team reviews and approves it.',
          'After approval, changes to name, about, prices and video go public after review.',
          'Tutors follow the tutor code of conduct they accepted at registration, their own schedule and their cancellation policy.',
          'Tutors teach independently; Dars is a platform for booking, payment and communication. [lawyer to review the relationship]',
        ] },
        { h: '3. Booking, payment and commission', p: [
          'All bookings and payments happen inside Dars only. Arranging lessons or payments outside Dars is not allowed.',
          'The lesson price comes from the tutor\'s price and the lesson length, and is shown before you confirm. Bookings can be paid from the wallet or by transfer with a receipt that the Dars team checks.',
          'Dars keeps a commission from each lesson fee for its services.',
          'Cancellations and refunds follow the tutor\'s cancellation policy and the published refund policy.',
          'In-person lessons for students under 18 are booked by a parent only.',
        ] },
        { h: '4. Communication and safety', p: [
          'Sharing phone numbers, e-mail addresses, social accounts or outside contact links on Dars is not allowed.',
          'Messages, live-help questions, tutor profiles, reviews and lesson links are checked automatically for contact details. Messages that contain them are hidden from the other person and may be reviewed by the Dars team.',
          'Voice and video calls go directly between the two people and are not recorded by Dars. Join and leave times of lessons are kept to settle disputes.',
          'You can report a chat or block anyone; blocking stops messages and calls between you.',
        ] },
        { h: '5. Not allowed', p: [
          'Abuse, harassment, discrimination or inappropriate content — especially with minors.',
          'Asking students for photos or personal details, or trying to contact them outside Dars.',
          'Impersonation, or false documents or qualifications.',
          'Manipulating bookings, payments or reviews.',
        ] },
        { h: '6. Suspension and deletion', p: [
          'Dars may suspend an account that breaks these terms, and tells the owner why when possible.',
          'You can delete your account in the app (Account → Delete my account). It is deleted after 14 days; signing in before then lets you keep it. Lesson and payment records stay, without your personal details, for accounting.',
        ] },
        { h: '7. Liability and changes', p: [
          'Dars works to keep the platform running safely, but cannot promise it is free of faults. [limits of liability: lawyer]',
          'We may change these terms; when we do, the app asks you to accept the new version.',
          'Governing law and courts: [lawyer].',
          'Contact: [e-mail / support number].',
        ] },
      ],
    },
    privacy: {
      t: 'Privacy Policy',
      intro: 'This policy explains what data Dars collects and how it is used and protected. Responsible for the data: [owner / company name, address, e-mail].',
      s: [
        { h: '1. Data we collect', p: [
          'Account: name, phone number or e-mail, account type, year of birth (students), study level and curriculum, city, profile photo if you add one.',
          'Tutors: about text, subjects, prices and intro video (public); ID, certificate and CV (private: seen only by the tutor and the Dars team).',
          'Lessons and payments: bookings, wallet balance, transfer receipt photos, payout requests.',
          'Chats: messages, voice notes, photos, files and live-help questions. Calls are not recorded.',
          'Technical: the device\'s notification token, app language, lesson join/leave times, and the internet address when the call relay is requested (to limit abuse).',
        ] },
        { h: '2. How we use it', p: [
          'To provide the service: finding a tutor, booking, payment, chat, calls, notifications and lesson reminders.',
          'For safety: automatic checks of texts for contact details (which are hidden), review of suspicious cases by the Dars team, and verification of tutor documents.',
          'To check receipts, settle disputes (such as no-shows) and give support.',
          'We do not use your data for advertising and never sell it.',
        ] },
        { h: '3. Children', p: [
          'Students under 13 do not create an account; a parent adds them as a profile in the parent\'s account.',
          'Students aged 13–17 need a parent\'s approval; the linked parent can read their lessons and chats but not write in them.',
        ] },
        { h: '4. Who we share data with', p: [
          'The other person in a lesson or chat sees only what is needed (name, photo and the messages sent to them).',
          'Service providers working for us: hosting and database (Supabase), notifications (Firebase by Google), call relay servers (Cloudflare / Metered), website hosting (GitHub). [owner to complete the list]',
          'Authorities, when the law requires it.',
        ] },
        { h: '5. How long we keep it', p: [
          'Account data is kept while the account exists.',
          'When an account is deleted, personal details and message texts are removed within 14 days; lesson and payment records stay without your name for accounting. [retention of financial records: accountant]',
        ] },
        { h: '6. Your rights', p: [
          'You can see and correct your data in the app, and delete your account under Account → Delete my account.',
          'You can withdraw your consent by deleting your account. For any other request contact us: [e-mail].',
        ] },
        { h: '7. Security and changes', p: [
          'Data is stored with trusted providers; each user reaches only their own data through database access rules, and private documents are kept in non-public storage.',
          'When this policy changes, the app asks you to accept the new version.',
        ] },
      ],
    },
  },
};
