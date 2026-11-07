import Link from 'next/link';
import Icon from '@/components/Icon';
import { FeaturedTutors } from '@/components/LiveTutors';
import PhoneMock from '@/components/PhoneMock';
import { Avatar, SectionHead, StoreButtons } from '@/components/Ui';
import { APP_URL, BASE, popular, subjects, t } from '@/lib/data';

const RADAR = ['#2F6BFF', '#7B61FF', '#0E8F7E', '#F59E0B'];
import { getDict, type Lang } from '@/lib/i18n';

export default function Home({ params }: { params: { lang: Lang } }) {
  const lang = params.lang;
  const d = getDict(lang);

  return (
    <>
      {/* HERO */}
      <section className="hero">
        <div className="container hero-grid">
          <div>
            <span className="badge-live">
              <i /> {d.hero.badge}
            </span>
            <h1>
              {d.hero.title} <span className="accent">{d.hero.titleAccent}</span>
            </h1>
            <p className="lead">{d.hero.subtitle}</p>
            <form className="hero-search" action={`${BASE}/${lang}/tutors/`}>
              <Icon name="search" />
              <input name="q" placeholder={d.hero.searchPlaceholder} aria-label={d.hero.searchPlaceholder} />
              <button className="btn btn-primary" type="submit">
                {d.hero.searchCta}
              </button>
            </form>
            <div className="row gap8 wrap popular">
              <span className="muted">{d.hero.popular}</span>
              {popular.map((p) => (
                <Link key={p.en} href={`/${lang}/tutors/`} className="chip">
                  {t(p, lang)}
                </Link>
              ))}
            </div>
            <a className="btn btn-amber live-cta" href={APP_URL}>
              <Icon name="bolt" /> {d.hero.liveCta}
            </a>
          </div>
          <div className="hero-visual">
            <PhoneMock lang={lang} />
            <div className="float-card fc-1">
              <Icon name="shield" style={{ color: 'var(--primary)' }} />
              <span>{d.guarantee.title}</span>
            </div>
            <div className="float-card fc-2">
              <Avatar name={lang === 'ar' ? 'مدرس' : 'Tutor'} color="#7B61FF" size={34} online />
              <span>
                <b>{lang === 'ar' ? 'مدرس متاح' : 'A tutor'}</b>
                <small>{lang === 'ar' ? 'قبِل طلبك ✓' : 'accepted your request ✓'}</small>
              </span>
            </div>
          </div>
        </div>
        <div className="container stats">
          {d.stats.map((s) => (
            <div key={s.label}>
              <strong>{s.value}</strong>
              <span>{s.label}</span>
            </div>
          ))}
        </div>
      </section>

      {/* LIVE HELP */}
      <section className="section">
        <div className="container live">
          <div>
            <SectionHead eyebrow={d.live.eyebrow} title={d.live.title} subtitle={d.live.body} />
            <ol className="live-steps">
              {d.live.steps.map((s, i) => (
                <li key={s}>
                  <span>{i + 1}</span>
                  {s}
                </li>
              ))}
            </ol>
            <a className="btn btn-primary" href={APP_URL}>
              <Icon name="bolt" /> {d.live.cta}
            </a>
          </div>
          <div className="radar" aria-hidden="true">
            <div className="radar-ring r1" />
            <div className="radar-ring r2" />
            <div className="radar-ring r3" />
            <div className="radar-core">
              <Icon name="mic" size={40} />
              <b>0:42</b>
            </div>
            {RADAR.map((c, i) => (
              <span key={c} className={`radar-avatar ra-${i}`}>
                <Avatar name={lang === 'ar' ? 'م' : 'T'} color={c} size={48} online />
              </span>
            ))}
          </div>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section className="section alt">
        <div className="container">
          <SectionHead title={d.how.title} center />
          <div className="grid-3">
            {d.how.steps.map((s, i) => (
              <div key={s.t} className="card step">
                <span className="step-num">{i + 1}</span>
                <h3>{s.t}</h3>
                <p>{s.d}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* SUBJECTS */}
      <section className="section">
        <div className="container">
          <SectionHead title={d.subjects.title} subtitle={d.subjects.subtitle} />
          <div className="grid-subjects">
            {subjects.map((s) => (
              <Link key={s.id} href={`/${lang}/tutors/?subject=${s.id}`} className="card subject">
                <span className="subject-icon" style={{ background: `${s.color}1a`, color: s.color }}>
                  <Icon name={s.icon} size={28} />
                </span>
                <b>{t(s.name, lang)}</b>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* FEATURED TUTORS */}
      <section className="section alt">
        <div className="container">
          <div className="row between wrap gap10">
            <SectionHead title={d.featured.title} subtitle={d.featured.subtitle} />
            <Link className="btn btn-ghost" href={`/${lang}/tutors/`}>
              {d.featured.viewAll} <Icon name="arrow" size={18} className="flip-rtl" />
            </Link>
          </div>
          <div className="grid-tutors">
            <FeaturedTutors lang={lang} fallback={[]} />
          </div>
        </div>
      </section>

      {/* TRUST */}
      <section className="section">
        <div className="container grid-2">
          <div className="card trust trust-amber">
            <Icon name="award" size={40} />
            <h3>{d.guarantee.title}</h3>
            <p>{d.guarantee.body}</p>
          </div>
          <div className="card trust">
            <Icon name="shield" size={40} />
            <h3>{d.safety.title}</h3>
            <ul className="checks">
              {d.safety.items.map((x) => (
                <li key={x}>
                  <Icon name="check" size={18} /> {x}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      {/* CTA: tutors + app */}
      <section className="section">
        <div className="container grid-2">
          <div className="cta cta-ink">
            <h3>{d.tutorsCta.title}</h3>
            <p>{d.tutorsCta.body}</p>
            <Link className="btn btn-amber" href={`/${lang}/become-a-tutor/`}>
              {d.tutorsCta.cta}
            </Link>
          </div>
          <div className="cta cta-teal">
            <h3>{d.app.title}</h3>
            <p>{d.app.body}</p>
            <StoreButtons lang={lang} />
            <a className="link-light" href={APP_URL}>
              {d.app.web} →
            </a>
          </div>
        </div>
      </section>
    </>
  );
}
