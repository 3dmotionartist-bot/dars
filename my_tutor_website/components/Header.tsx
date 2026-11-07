import Link from 'next/link';
import type { Lang } from '@/lib/i18n';
import { getDict } from '@/lib/i18n';
import { APP_URL } from '@/lib/data';
import Icon from './Icon';
import LangSwitch from './LangSwitch';
import { Logo } from './Ui';

/** Sticky header. Mobile menu uses <details> so it works without JavaScript. */
export default function Header({ lang }: { lang: Lang }) {
  const d = getDict(lang);
  const other: Lang = lang === 'ar' ? 'en' : 'ar';
  const links = [
    { href: `/${lang}/tutors/`, label: d.nav.tutors },
    { href: `/${lang}/become-a-tutor/`, label: d.nav.become },
    { href: `/${lang}/pricing/`, label: d.nav.pricing },
    { href: `/${lang}/about/`, label: d.nav.about },
    { href: `/${lang}/faq/`, label: d.nav.faq },
  ];
  return (
    <header className="header">
      <div className="container header-inner">
        <Link href={`/${lang}/`} aria-label={d.brand}>
          <Logo lang={lang} />
        </Link>
        <nav className="nav-desktop">
          {links.map((l) => (
            <Link key={l.href} href={l.href}>
              {l.label}
            </Link>
          ))}
        </nav>
        <div className="row gap8 header-actions">
          <LangSwitch to={other} label={d.langSwitch} />
          <a className="btn btn-primary btn-sm hide-sm" href={APP_URL}>
            {d.nav.signIn}
          </a>
          <details className="nav-mobile">
            <summary aria-label={d.nav.menu}>
              <Icon name="menu" />
            </summary>
            <div className="nav-mobile-panel">
              {links.map((l) => (
                <Link key={l.href} href={l.href}>
                  {l.label}
                </Link>
              ))}
              <Link href={`/${lang}/contact/`}>{d.nav.contact}</Link>
              <a className="btn btn-primary" href={APP_URL}>
                {d.nav.signIn}
              </a>
            </div>
          </details>
        </div>
      </div>
    </header>
  );
}
