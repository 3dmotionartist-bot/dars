import type { Metadata } from 'next';
import Icon from '@/components/Icon';
import { SectionHead } from '@/components/Ui';
import { APP_URL } from '@/lib/data';
import { getDict, type Lang } from '@/lib/i18n';

export function generateMetadata({ params }: { params: { lang: Lang } }): Metadata {
  const d = getDict(params.lang).pricing;
  return { title: d.title, description: d.subtitle };
}

export default function Pricing({ params }: { params: { lang: Lang } }) {
  const d = getDict(params.lang).pricing;
  return (
    <>
      <section className="section page-top">
        <div className="container">
          <SectionHead title={d.title} subtitle={d.subtitle} center />
          <div className="grid-2 narrow">
            {[d.payg, d.pack].map((p, i) => (
              <div key={p.t} className={`card plan ${i === 1 ? 'plan-hi' : ''}`}>
                <Icon name={i === 0 ? 'clock' : 'gift'} size={32} />
                <h3>{p.t}</h3>
                <div className="plan-price">{p.p}<small>{p.u}</small></div>
                <p className="muted">{p.d}</p>
                <ul className="checks">
                  {p.f.map((f) => (<li key={f}><Icon name="check" size={18} /> {f}</li>))}
                </ul>
              </div>
            ))}
          </div>
        </div>
      </section>
      <section className="section alt">
        <div className="container">
          <SectionHead title={d.subsTitle} subtitle={d.subsBody} center />
          <div className="grid-3">
            {d.subs.map((s) => (
              <div key={s.t} className={`card plan ${s.popular ? 'plan-hi' : ''}`}>
                {s.popular && <span className="ribbon">{d.popular}</span>}
                <h3>{s.t}</h3>
                <div className="plan-price">{s.p}<small>{d.perMonth}</small></div>
                <p className="muted">{s.d}</p>
                <ul className="checks">
                  {s.f.map((f) => (<li key={f}><Icon name="check" size={18} /> {f}</li>))}
                </ul>
                <a className={`btn ${s.popular ? 'btn-primary' : 'btn-ghost'} block`} href={APP_URL}>{d.subscribe}</a>
              </div>
            ))}
          </div>
        </div>
      </section>
      <section className="section">
        <div className="container">
          <SectionHead title={d.payTitle} center />
          <div className="pay-row">
            {d.pays.map((p, i) => (
              <span key={p} className="card pay">
                <Icon name={['card', 'apple', 'wallet', 'chart', 'gift'][i] ?? 'card'} size={22} /> {p}
              </span>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
