import Link from 'next/link';
import type { Lang } from '@/lib/i18n';
import { getDict } from '@/lib/i18n';
import { WHATSAPP } from '@/lib/data';
import { Logo, StoreButtons } from './Ui';

export default function Footer({ lang }: { lang: Lang }) {
  const d = getDict(lang);
  return (
    <footer className="footer">
      <div className="container footer-grid">
        <div>
          <Logo lang={lang} light />
          <p className="footer-tag">{d.footer.tagline}</p>
          <StoreButtons lang={lang} />
        </div>
        <div>
          <h4>{d.footer.product}</h4>
          <Link href={`/${lang}/tutors/`}>{d.nav.tutors}</Link>
          <Link href={`/${lang}/pricing/`}>{d.nav.pricing}</Link>
          <Link href={`/${lang}/become-a-tutor/`}>{d.nav.become}</Link>
          <Link href={`/${lang}/faq/`}>{d.nav.faq}</Link>
        </div>
        <div>
          <h4>{d.footer.company}</h4>
          <Link href={`/${lang}/about/`}>{d.nav.about}</Link>
          <Link href={`/${lang}/contact/`}>{d.nav.contact}</Link>
          <a href={WHATSAPP}>WhatsApp</a>
        </div>
        <div>
          <h4>{d.footer.legal}</h4>
          <Link href={`/${lang}/legal/terms/`}>{d.footer.terms}</Link>
          <Link href={`/${lang}/legal/privacy/`}>{d.footer.privacy}</Link>
          <Link href={`/${lang}/legal/refund/`}>{d.footer.refund}</Link>
        </div>
      </div>
      <div className="container footer-bottom">
        © {new Date().getFullYear()} {d.brand} · {d.footer.rights}
      </div>
    </footer>
  );
}
