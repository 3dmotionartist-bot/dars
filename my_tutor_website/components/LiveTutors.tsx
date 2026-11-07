'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { fetchLiveTutor, fetchLiveTutors, LIVE } from '@/lib/backend';
import type { Tutor } from '@/lib/data';
import type { Lang } from '@/lib/i18n';
import TutorProfile from './TutorProfile';
import { TutorCard } from './Ui';

/** Tutors from the backend when connected (falls back to the built-in list if it can't be reached). */
export function useTutors(fallback: Tutor[]) {
  const [list, setList] = useState<Tutor[]>(LIVE ? [] : fallback);
  const [loading, setLoading] = useState(LIVE);
  useEffect(() => {
    if (!LIVE) return;
    let alive = true;
    fetchLiveTutors()
      .then((x) => alive && x && setList(x))
      .catch(() => alive && setList([])) // connected site: never show sample tutors
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return { list, loading };
}

export function FeaturedTutors({ lang, fallback }: { lang: Lang; fallback: Tutor[] }) {
  const { list, loading } = useTutors(fallback);
  const top = [...list].sort((a, b) => b.match - a.match).slice(0, 3);
  if (loading) return <p className="muted center">{lang === 'ar' ? 'جارٍ التحميل…' : 'Loading…'}</p>;
  if (!top.length) return <p className="muted center">{lang === 'ar' ? 'سينضم المدرسون قريباً.' : 'Tutors are joining soon.'}</p>;
  return (
    <>
      {top.map((x) => (
        <TutorCard key={x.id} tutor={x} lang={lang} />
      ))}
    </>
  );
}

/** /[lang]/tutor/?id=… — profile of a tutor stored in the database. */
export function LiveTutorPage({ lang }: { lang: Lang }) {
  const [state, setState] = useState<{ tutor: Tutor | null; done: boolean }>({ tutor: null, done: false });
  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get('id') || '';
    fetchLiveTutor(id)
      .then((tutor) => setState({ tutor, done: true }))
      .catch(() => setState({ tutor: null, done: true }));
  }, []);
  if (state.tutor) return <TutorProfile x={state.tutor} lang={lang} />;
  return (
    <section className="section page-top">
      <div className="container center">
        {state.done ? (
          <>
            <h1>{lang === 'ar' ? 'لم نجد هذا المدرس' : 'Tutor not found'}</h1>
            <Link className="btn btn-primary" href={`/${lang}/tutors/`}>
              {lang === 'ar' ? 'تصفّح المدرسين' : 'Browse tutors'}
            </Link>
          </>
        ) : (
          <p className="muted">{lang === 'ar' ? 'جارٍ التحميل…' : 'Loading…'}</p>
        )}
      </div>
    </section>
  );
}
