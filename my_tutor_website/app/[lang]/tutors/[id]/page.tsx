import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import TutorProfile from '@/components/TutorProfile';
import { t, tutorById, tutors } from '@/lib/data';
import { locales, type Lang } from '@/lib/i18n';

export function generateStaticParams() {
  return locales.flatMap((lang) => tutors.map((x) => ({ lang, id: x.id })));
}

export function generateMetadata({ params }: { params: { lang: Lang; id: string } }): Metadata {
  const x = tutorById(params.id);
  if (!x) return {};
  return { title: t(x.name, params.lang), description: t(x.headline, params.lang) };
}

export default function TutorPage({ params }: { params: { lang: Lang; id: string } }) {
  const lang = params.lang;
  const x = tutorById(params.id);
  if (!x) notFound();

  return <TutorProfile x={x} lang={lang} />;
}
