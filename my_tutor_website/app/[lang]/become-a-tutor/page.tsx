import type { Metadata } from 'next';
import EarningsCalculator from '@/components/EarningsCalculator';
import Icon from '@/components/Icon';
import { SectionHead } from '@/components/Ui';
import { APP_URL } from '@/lib/data';
import { getDict, type Lang } from '@/lib/i18n';

export function generateMetadata({ params }: { params: { lang: Lang } }): Metadata {
  const d = getDict(params.lang).become;
  return { title: getDict(params.lang).nav.become, description: d.subtitle };
}

export default function BecomeTutor({ params }: { params: { lang: Lang } }) {
  const lang = params.lang;
  const d = getDict(lang).become;
  return (
    <>
      <section className="hero hero-small">
        <div className="container hero-grid">
          <div>
            <h1>{d.title}</h1>
            <p className="lead">{d.subtitle}</p>
            <a className="btn btn-amber" href={APP_URL}>{d.cta}</a>
            <ul className="checks light">
              {d.perks.map((p) => (
                <li key={p}><Icon name="check" size={18} /> {p}</li>
              ))}
            </ul>
          </div>
          <EarningsCalculator lang={lang} />
        </div>
      </section>
      <section className="section">
        <div className="container">
          <SectionHead title={getDict(lang).how.title} center />
          <div className="grid-4">
            {d.steps.map((s, i) => (
              <div key={s.t} className="card step">
                <span className="step-num">{i + 1}</span>
                <h3>{s.t}</h3>
                <p>{s.d}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
      <section className="section alt">
        <div className="container grid-2">
          <div className="card">
            <h2>{d.reqTitle}</h2>
            <ul className="checks">
              {d.reqs.map((r) => (
                <li key={r}><Icon name="check" size={18} /> {r}</li>
              ))}
            </ul>
          </div>
          <div className="cta cta-teal">
            <h3>{d.title}</h3>
            <p>{d.subtitle}</p>
            <a className="btn btn-amber" href={APP_URL}>{d.cta}</a>
          </div>
        </div>
      </section>
    </>
  );
}
