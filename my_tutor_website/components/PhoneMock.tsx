import type { Lang } from '@/lib/i18n';
import { subjects, t } from '@/lib/data';
import Icon from './Icon';
import { Avatar } from './Ui';

/** Pure-CSS phone showing the Dars app home — no screenshots needed. */
export default function PhoneMock({ lang }: { lang: Lang }) {
  const ar = lang === 'ar';
  return (
    <div className="phone" aria-hidden="true">
      <div className="phone-notch" />
      <div className="phone-screen">
        <div className="pm-head">
          <Avatar name={ar ? 'محمد' : 'Mohammad'} color="#0E8F7E" size={34} />
          <div>
            <b>{ar ? 'أهلاً محمد 👋' : 'Hello Mohammad 👋'}</b>
            <small>{ar ? 'ماذا تريد أن تتعلم اليوم؟' : 'What will you learn today?'}</small>
          </div>
        </div>
        <div className="pm-search">
          <Icon name="search" size={16} /> {ar ? 'ابحث عن مادة أو مدرس…' : 'Search a subject or tutor…'}
        </div>
        <div className="pm-live">
          <div>
            <small>● {ar ? 'مدرسون متاحون الآن' : 'Tutors online now'}</small>
            <b>{ar ? 'تكلّم مع مدرس الآن' : 'Speak to a tutor now'}</b>
            <span>{ar ? 'من المتاح الآن؟' : "Who's online?"}</span>
          </div>
          <Icon name="mic" size={34} />
        </div>
        <div className="pm-subjects">
          {subjects.slice(0, 4).map((s) => (
            <div key={s.id}>
              <span style={{ background: `${s.color}1f`, color: s.color }}>
                <Icon name={s.icon} size={20} />
              </span>
              <small>{t(s.name, lang)}</small>
            </div>
          ))}
        </div>
        <div className="pm-card">
          <Avatar name={ar ? 'مدرس' : 'Tutor'} color="#2F6BFF" size={40} online />
          <div>
            <b>{ar ? 'مدرّس رياضيات' : 'Math tutor'}</b>
            <small>{ar ? 'متاح الآن · أونلاين' : 'Available now · online'}</small>
          </div>
        </div>
        <div className="pm-nav">
          {['chat', 'clock', 'bolt', 'search', 'book'].map((n, i) => (
            <span key={n} className={i === 4 ? 'on' : ''}>
              <Icon name={n} size={18} />
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}
