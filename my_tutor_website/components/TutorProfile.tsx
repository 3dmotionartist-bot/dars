import Link from 'next/link';
import Icon from '@/components/Icon';
import { Avatar, Stars } from '@/components/Ui';
import { APP_URL, discountFor, levels, subjectById, t, type Tutor } from '@/lib/data';
import { getDict, type Lang } from '@/lib/i18n';

/** Full tutor profile — used by the static pages and by live (database) tutors. */
export default function TutorProfile({ x, lang }: { x: Tutor; lang: Lang }) {
  const d = getDict(lang).tutor;
  return (
    <section className="section page-top">
      <div className="container">
        <Link href={`/${lang}/tutors/`} className="back-link">
          <Icon name="arrow" size={18} className="flip-ltr" /> {d.back}
        </Link>
        <div className="profile">
          <div className="profile-main">
            <div className="card profile-head">
              <Avatar name={t(x.name, lang)} color={x.color} size={96} online={x.available} />
              <div>
                <h1>
                  {t(x.name, lang)} <Icon name="verified" size={24} style={{ color: 'var(--info)' }} />
                </h1>
                <p className="lead">{t(x.headline, lang)}</p>
                <div className="row gap8 wrap">
                  <span className={`pill ${x.available ? 'pill-green' : 'pill-grey'}`}>
                    <i className="dot" />
                    {x.available ? d.available : d.busy}
                  </span>
                  {x.instant && <span className="pill pill-amber">⚡ {d.instant}</span>}
                  {x.isNew && <span className="pill pill-blue">{d.newTutor}</span>}
                </div>
              </div>
            </div>
            <div className="card stat-row">
              <div><Stars rating={x.rating} /><span>{x.reviews} {d.reviews}</span></div>
              <div><b>{x.hours.toLocaleString('en-US')}</b><span>{d.hoursTaught}</span></div>
              <div><b>{x.students}</b><span>{d.students}</span></div>
              <div><b className="green">{x.match}%</b><span>{d.match}</span></div>
            </div>

            <div className="card">
              <h2>{d.about}</h2>
              <p className="body">{t(x.about, lang)}</p>
              <dl className="facts">
                <div><dt>{d.country}</dt><dd>{t(x.country, lang)}</dd></div>
                <div><dt>{d.experience}</dt><dd>{x.years} {d.years}</dd></div>
                <div><dt>{d.speaks}</dt><dd>{x.languages.map((l) => t(l, lang)).join(' · ')}</dd></div>
                <div><dt>{d.mode}</dt><dd>{d.online}{x.inPerson ? ` · ${d.inPerson}` : ''}</dd></div>
              </dl>
            </div>

            <div className="card">
              <h2>{d.subjects}</h2>
              <div className="row gap8 wrap">
                {x.subjects.map((s) => (
                  <span key={s} className="pill pill-blue">
                    <Icon name={subjectById(s).icon} size={15} /> {t(subjectById(s).name, lang)}
                  </span>
                ))}
                {x.tags.map((g) => (
                  <span key={g.en} className="pill">{t(g, lang)}</span>
                ))}
              </div>
            </div>

            <div className="card">
              <h2>{d.reviewsTitle}</h2>
              <p className="muted small">{d.reviewsNote}</p>
              {x.reviewList.length === 0 && <p className="muted">—</p>}
              {x.reviewList.map((r) => (
                <div key={r.date + r.by.en} className="review">
                  <Avatar name={t(r.by, lang)} color="#8D93A1" size={40} />
                  <div>
                    <b>{t(r.by, lang)}</b> <span className="review-stars">{'★'.repeat(r.stars)}</span>
                    <p>{t(r.text, lang)}</p>
                    <small className="muted">{r.date}</small>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <aside className="profile-side">
            <div className="card video">
              <span className="video-play"><Icon name="play" size={30} fill /></span>
            </div>
            <div className="card">
              <h2>{d.fees}</h2>
              <table className="fees">
                <tbody>
                  {levels.map((l) => (
                    <tr key={l.id}>
                      <td>{t(l.name, lang)}</td>
                      <td><b>${Math.round(x.price * l.factor)}</b><small>{d.perHour}</small></td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {x.maxDiscount > 0 && (
                <>
                  <h3>{d.packages}</h3>
                  <div className="pkg-row">
                    {[4, 8, 12, 20].map((h) => (
                      <div key={h}>
                        <small>{h} {d.hours}</small>
                        <b>-{discountFor(x, h)}%</b>
                      </div>
                    ))}
                  </div>
                </>
              )}
              <h3>{d.policies}</h3>
              <p className="small">
                <Icon name="clock" size={16} /> {d.cancel.replace('{h}', String(x.cancelHours))}
              </p>
              <a className="btn btn-primary block" href={APP_URL}>{d.book}</a>
              <a className="btn btn-ghost block" href={APP_URL}>
                <Icon name="chat" size={18} /> {d.message}
              </a>
              <p className="muted small center">{d.bookInApp}</p>
            </div>
          </aside>
        </div>
      </div>
    </section>
  );
}
