import type { Metadata } from 'next';
import Link from 'next/link';
import { SectionHead } from '@/components/Ui';
import { getDict, type Lang } from '@/lib/i18n';

export function generateMetadata({ params }: { params: { lang: Lang } }): Metadata {
  return { title: getDict(params.lang).faq.title };
}

export default function Faq({ params }: { params: { lang: Lang } }) {
  const d = getDict(params.lang);
  const ld = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: d.faq.items.map((x) => ({ '@type': 'Question', name: x.q, acceptedAnswer: { '@type': 'Answer', text: x.a } })),
  };
  return (
    <section className="section page-top">
      <div className="container narrow-text">
        <SectionHead title={d.faq.title} />
        <div className="faq">
          {d.faq.items.map((x, i) => (
            <details key={x.q} className="card" open={i === 0}>
              <summary>{x.q}</summary>
              <p>{x.a}</p>
            </details>
          ))}
        </div>
        <p className="center">
          <Link className="btn btn-ghost" href={`/${params.lang}/contact/`}>{d.nav.contact}</Link>
        </p>
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(ld) }} />
      </div>
    </section>
  );
}
