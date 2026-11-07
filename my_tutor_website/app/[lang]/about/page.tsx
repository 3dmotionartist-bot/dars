import type { Metadata } from 'next';
import Icon from '@/components/Icon';
import { SectionHead } from '@/components/Ui';
import { getDict, type Lang } from '@/lib/i18n';

export function generateMetadata({ params }: { params: { lang: Lang } }): Metadata {
  return { title: getDict(params.lang).about.title };
}

export default function About({ params }: { params: { lang: Lang } }) {
  const d = getDict(params.lang);
  return (
    <section className="section page-top">
      <div className="container narrow-text">
        <SectionHead title={d.about.title} />
        <p className="lead">{d.about.body}</p>
        <div className="card mission">
          <h2>{d.about.mission}</h2>
          <p>{d.about.missionBody}</p>
        </div>
        <div className="grid-4">
          {d.about.values.map((v, i) => (
            <div key={v.t} className="card step">
              <Icon name={['shield', 'bolt', 'chart', 'sparkle'][i]} size={30} style={{ color: 'var(--primary)' }} />
              <h3>{v.t}</h3>
              <p>{v.d}</p>
            </div>
          ))}
        </div>
        <div className="container stats flat">
          {d.stats.map((s) => (
            <div key={s.label}><strong>{s.value}</strong><span>{s.label}</span></div>
          ))}
        </div>
      </div>
    </section>
  );
}
