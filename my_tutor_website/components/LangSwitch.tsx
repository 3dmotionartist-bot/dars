'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import Icon from './Icon';

/** Swaps /ar/... <-> /en/... while staying on the same page. */
export default function LangSwitch({ to, label }: { to: 'ar' | 'en'; label: string }) {
  const pathname = usePathname() || '/';
  const rest = pathname.replace(/^\/(ar|en)(?=\/|$)/, '');
  return (
    <Link className="btn btn-ghost btn-sm" href={`/${to}${rest || '/'}`} hrefLang={to}>
      <Icon name="globe" size={18} /> {label}
    </Link>
  );
}
