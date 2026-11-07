import { LiveTutorPage } from '@/components/LiveTutors';
import { locales, type Lang } from '@/lib/i18n';

export function generateStaticParams() {
  return locales.map((lang) => ({ lang }));
}

export default function TutorFromDatabase({ params }: { params: { lang: Lang } }) {
  return <LiveTutorPage lang={params.lang} />;
}
