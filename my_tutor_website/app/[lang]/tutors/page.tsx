import type { Metadata } from 'next';
import TutorBrowser from '@/components/TutorBrowser';
import { SectionHead } from '@/components/Ui';
import { getDict, type Lang } from '@/lib/i18n';

export function generateMetadata({ params }: { params: { lang: Lang } }): Metadata {
  const d = getDict(params.lang).browse;
  return { title: d.title, description: d.subtitle };
}

export default function TutorsPage({ params }: { params: { lang: Lang } }) {
  const d = getDict(params.lang).browse;
  return (
    <section className="section page-top">
      <div className="container">
        <SectionHead title={d.title} subtitle={d.subtitle} />
        <TutorBrowser lang={params.lang} />
      </div>
    </section>
  );
}
