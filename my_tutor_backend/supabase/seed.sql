-- Catalog data (same lists as the app). Safe to run more than once.
insert into subjects (id, name_ar, name_en, icon, color, sort) values
  ('math',        'الرياضيات',          'Math',            'calculate',   '#2F6BFF', 1),
  ('english',     'اللغة الإنجليزية',    'English',         'translate',   '#7B61FF', 2),
  ('arabic',      'اللغة العربية',       'Arabic',          'menu_book',   '#0E8F7E', 3),
  ('physics',     'الفيزياء',           'Physics',         'bolt',        '#F59E0B', 4),
  ('chemistry',   'الكيمياء',           'Chemistry',       'science',     '#22B573', 5),
  ('biology',     'الأحياء',            'Biology',         'biotech',     '#E5484D', 6),
  ('exams',       'اختبارات دولية',      'Test prep',       'assignment',  '#FF7A45', 7),
  ('programming', 'البرمجة',            'Programming',     'code',        '#12203A', 8),
  ('quran',       'القرآن والتجويد',     'Quran & Tajweed', 'auto_stories','#0A6E61', 9),
  ('accounting',  'المحاسبة والمالية',    'Accounting',      'account_balance','#5B45D6', 10),
  ('french',      'اللغة الفرنسية',      'French',          'language',    '#0EA5E9', 11),
  ('kids',        'تأسيس الأطفال',       'Kids foundation', 'child_care',  '#EC4899', 12)
on conflict (id) do update set name_ar = excluded.name_ar, name_en = excluded.name_en, icon = excluded.icon, color = excluded.color, sort = excluded.sort;

insert into study_levels (id, name_ar, name_en, price_factor, sort) values
  ('kids',       'رياض الأطفال',     'Pre-school',             0.80, 1),
  ('elementary', 'ابتدائي',          'Elementary',             0.85, 2),
  ('middle',     'إعدادي / متوسط',   'Middle school',          0.90, 3),
  ('high',       'ثانوي',            'High school',            1.00, 4),
  ('university', 'جامعي',            'University',             1.20, 5),
  ('adult',      'مهنيون وبالغون',   'Adults & professionals', 1.30, 6)
on conflict (id) do update set name_ar = excluded.name_ar, name_en = excluded.name_en, price_factor = excluded.price_factor, sort = excluded.sort;

insert into curricula (id, name_ar, name_en, sort) values
  ('syrian',    'المنهج السوري',        'Syrian curriculum',           1),
  ('saudi',     'المنهج السعودي',       'Saudi curriculum',            2),
  ('uae',       'المنهج الإماراتي',     'UAE curriculum',              3),
  ('egyptian',  'المنهج المصري',        'Egyptian curriculum',         4),
  ('jordanian', 'المنهج الأردني',       'Jordanian curriculum',        5),
  ('american',  'المنهج الأمريكي',      'American curriculum',         6),
  ('british',   'المنهج البريطاني IG',  'British IGCSE',               7),
  ('ib',        'البكالوريا الدولية IB', 'International Baccalaureate', 8),
  ('other',     'غير ذلك',              'Other',                       9)
on conflict (id) do update set name_ar = excluded.name_ar, name_en = excluded.name_en, sort = excluded.sort;
