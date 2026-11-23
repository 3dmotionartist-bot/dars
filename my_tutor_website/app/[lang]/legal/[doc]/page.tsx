import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { SectionHead } from '@/components/Ui';
import { getDict, locales, type Lang } from '@/lib/i18n';
import { legal, legalUpdated, legalVersion } from '@/lib/legal';

const docs = ['terms', 'privacy', 'refund'] as const;
type Doc = (typeof docs)[number];
const isDoc = (v: string): v is Doc => (docs as readonly string[]).includes(v);

export function generateStaticParams() {
  return locales.flatMap((lang) => docs.map((doc) => ({ lang, doc })));
}

export function generateMetadata({ params }: { params: { lang: Lang; doc: string } }): Metadata {
  if (!isDoc(params.doc)) return {};
  return { title: getDict(params.lang).legal[params.doc].t };
}

export default function Legal({ params }: { params: { lang: Lang; doc: string } }) {
  if (!isDoc(params.doc)) notFound();
  if (params.doc === 'terms' || params.doc === 'privacy') {
    const x = legal[params.lang][params.doc];
    return (
      <section className="section page-top">
        <div className="container narrow-text">
          <SectionHead title={x.t} />
          <div className="card legal">
            <p>{x.intro}</p>
            {x.s.map((sec) => (
              <div key={sec.h}>
                <h3>{sec.h}</h3>
                <ul>
                  {sec.p.map((p) => (<li key={p}>{p}</li>))}
                </ul>
              </div>
            ))}
            <p className="muted small">
              {params.lang === 'ar'
                ? `النسخة ${legalVersion} — آخر تحديث: ${legalUpdated.ar} — نص مبدئي يجب مراجعته قانونياً قبل الإطلاق.`
                : `Version ${legalVersion} — last updated: ${legalUpdated.en} — draft text, to be reviewed by a lawyer before launch.`}
            </p>
          </div>
        </div>
      </section>
    );
  }
  const d = getDict(params.lang).legal[params.doc];
  return (
    <section className="section page-top">
      <div className="container narrow-text">
        <SectionHead title={d.t} />
        <div className="card legal">
          <ol>
            {d.b.map((p) => (<li key={p}>{p}</li>))}
          </ol>
          <p className="muted small">{params.lang === 'ar' ? 'آخر تحديث: نوفمبر 2026 — نص مبدئي يجب مراجعته قانونياً.' : 'Last updated: November 2026 — draft text, have it reviewed by a lawyer.'}</p>
        </div>
      </div>
    </section>
  );
}
