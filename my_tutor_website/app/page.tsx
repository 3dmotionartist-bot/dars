import Link from 'next/link';

const BASE = process.env.NEXT_PUBLIC_BASE_PATH || '';

/** "/" → language chooser (static export can't do server redirects). Arabic is the default. */
export default function Root() {
  return (
    <main className="lang-gate">
      <meta httpEquiv="refresh" content={`0; url=${BASE}/ar/`} />
      <span className="logo-mark big">
        د<i />
      </span>
      <h1>درس · Dars</h1>
      <div className="row gap10">
        <Link className="btn btn-primary" href="/ar/">
          العربية
        </Link>
        <Link className="btn btn-ghost" href="/en/">
          English
        </Link>
      </div>
    </main>
  );
}
