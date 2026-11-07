import Link from 'next/link';
import type { Lang } from '@/lib/i18n';
import { getDict } from '@/lib/i18n';
import { initialOf, subjectById, t, type Tutor } from '@/lib/data';
import Icon from './Icon';

export function Logo({ lang, light = false }: { lang: Lang; light?: boolean }) {
  return (
    <span className={`logo ${light ? 'logo-light' : ''}`}>
      <span className="logo-mark">
        د<i />
      </span>
      <span className="logo-word">{getDict(lang).brand}</span>
    </span>
  );
}

export function Avatar({ name, color, size = 56, online = false }: { name: string; color: string; size?: number; online?: boolean }) {
  return (
    <span className="avatar" style={{ width: size, height: size, background: `linear-gradient(135deg, ${color}d9, ${color})`, fontSize: size * 0.42, borderRadius: size * 0.32 }}>
      {initialOf(name)}
      {online && <i className="avatar-dot" />}
    </span>
  );
}

export function Stars({ rating, count }: { rating: number; count?: number }) {
  return (
    <span className="stars">
      <Icon name="star" size={16} fill style={{ color: 'var(--accent)' }} />
      <b>{rating.toFixed(1)}</b>
      {count !== undefined && <span className="muted">({count})</span>}
    </span>
  );
}

export function TutorCard({ tutor, lang }: { tutor: Tutor; lang: Lang }) {
  const d = getDict(lang).tutor;
  return (
    <Link href={`/${lang}/tutor/?id=${tutor.id}`} className="card tutor-card">
      <div className="tc-head">
        <Avatar name={t(tutor.name, lang)} color={tutor.color} size={64} online={tutor.available} />
        <div className="tc-main">
          <div className="tc-name">
            <span>{t(tutor.name, lang)}</span>
            <Icon name="verified" size={18} style={{ color: 'var(--info)' }} />
          </div>
          <p className="tc-headline">{t(tutor.headline, lang)}</p>
          <div className="row gap8 wrap">
            <Stars rating={tutor.rating} count={tutor.reviews} />
            <span className={`pill ${tutor.available ? 'pill-green' : 'pill-grey'}`}>
              <i className="dot" />
              {tutor.available ? d.available : d.busy}
            </span>
            {tutor.isNew && <span className="pill pill-amber">{d.newTutor}</span>}
          </div>
        </div>
      </div>
      <div className="row gap6 wrap tc-tags">
        {tutor.subjects.map((s) => (
          <span key={s} className="pill pill-blue">{t(subjectById(s).name, lang)}</span>
        ))}
        {tutor.tags.slice(0, 2).map((x) => (
          <span key={x.en} className="pill">{t(x, lang)}</span>
        ))}
      </div>
      <div className="tc-foot">
        <span className={`match ${tutor.match >= 85 ? 'match-high' : ''}`}>
          <Icon name="sparkle" size={15} /> {tutor.match}% {d.match}
        </span>
        {tutor.instant && (
          <span className="muted small">
            <Icon name="bolt" size={14} style={{ color: 'var(--accent)' }} /> {d.instant}
          </span>
        )}
        <span className="tc-price">
          <small>{d.from}</small> <b>${tutor.price}</b>
          <small>{d.perHour}</small>
          {tutor.maxDiscount > 0 && (
            <em>
              {d.upTo} {tutor.maxDiscount}% {d.onPackages}
            </em>
          )}
        </span>
      </div>
    </Link>
  );
}

export function SectionHead({ eyebrow, title, subtitle, center = false }: { eyebrow?: string; title: string; subtitle?: string; center?: boolean }) {
  return (
    <div className={`section-head ${center ? 'center' : ''}`}>
      {eyebrow && <span className="eyebrow">{eyebrow}</span>}
      <h2>{title}</h2>
      {subtitle && <p>{subtitle}</p>}
    </div>
  );
}

export function StoreButtons({ lang }: { lang: Lang }) {
  const d = getDict(lang).app;
  return (
    <div className="row gap10 wrap">
      <a className="store" href="#" aria-label={d.ios}>
        <Icon name="apple" size={24} fill />
        <span>
          <small>Download on the</small>
          {d.ios}
        </span>
      </a>
      <a className="store" href="#" aria-label={d.android}>
        <Icon name="android" size={24} />
        <span>
          <small>Get it on</small>
          {d.android}
        </span>
      </a>
    </div>
  );
}
