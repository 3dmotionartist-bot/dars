import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Footer from '@/components/Footer';
import Header from '@/components/Header';
import { dirOf, getDict, isLang, locales } from '@/lib/i18n';

export function generateStaticParams() {
  return locales.map((lang) => ({ lang }));
}

export function generateMetadata({ params }: { params: { lang: string } }): Metadata {
  if (!isLang(params.lang)) return {};
  const d = getDict(params.lang);
  return {
    title: { default: d.meta.title, template: `%s | ${d.brand}` },
    description: d.meta.description,
    alternates: { languages: { ar: '/ar/', en: '/en/' } },
    openGraph: { title: d.meta.title, description: d.meta.description, locale: params.lang === 'ar' ? 'ar_SA' : 'en_US', type: 'website' },
  };
}

export default function LangLayout({ children, params }: { children: React.ReactNode; params: { lang: string } }) {
  if (!isLang(params.lang)) notFound();
  const lang = params.lang;
  return (
    <div lang={lang} dir={dirOf(lang)} className={`site site-${lang}`}>
      <Header lang={lang} />
      <main>{children}</main>
      <Footer lang={lang} />
    </div>
  );
}
