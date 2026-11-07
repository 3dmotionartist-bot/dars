'use client';

import { useEffect, useMemo, useState } from 'react';
import type { Lang } from '@/lib/i18n';
import { getDict } from '@/lib/i18n';
import { subjects, t, tutors, WHATSAPP } from '@/lib/data';
import Icon from './Icon';
import { TutorCard } from './Ui';

/** Client-side search, subject chips, filters and AI/price/rating sort. */
export default function TutorBrowser({ lang, initialSubject = '' }: { lang: Lang; initialSubject?: string }) {
  const d = getDict(lang).browse;
  const [q, setQ] = useState('');
  const [subject, setSubject] = useState(initialSubject);
  const [sort, setSort] = useState<'best' | 'price' | 'rating'>('best');
  const [availableNow, setAvailableNow] = useState(false);
  const [instantOnly, setInstantOnly] = useState(false);
  const [gender, setGender] = useState<'' | 'm' | 'f'>('');
  const [maxPrice, setMaxPrice] = useState(40);

  // Read ?q= and ?subject= from the URL (works on a fully static export).
  useEffect(() => {
    const sp = new URLSearchParams(window.location.search);
    const qs = sp.get('q');
    const sub = sp.get('subject');
    if (qs) setQ(qs);
    if (sub && subjects.some((x) => x.id === sub)) setSubject(sub);
  }, []);

  const results = useMemo(() => {
    const needle = q.trim().toLowerCase();
    const list = tutors.filter((x) => {
      if (subject && !x.subjects.includes(subject)) return false;
      if (availableNow && !x.available) return false;
      if (instantOnly && !x.instant) return false;
      if (gender && x.gender !== gender) return false;
      if (x.price > maxPrice) return false;
      if (needle) {
        const hay = [x.name.ar, x.name.en, x.headline.ar, x.headline.en, ...x.tags.map((g) => g.ar + ' ' + g.en), ...x.subjects]
          .join(' ')
          .toLowerCase();
        if (!hay.includes(needle)) return false;
      }
      return true;
    });
    return list.sort((a, b) => (sort === 'price' ? a.price - b.price : sort === 'rating' ? b.rating - a.rating : b.match - a.match));
  }, [q, subject, sort, availableNow, instantOnly, gender, maxPrice]);

  return (
    <div className="browser">
      <aside className="card filters">
        <label className="field">
          <span>{d.sort}</span>
          <select value={sort} onChange={(e) => setSort(e.target.value as 'best' | 'price' | 'rating')}>
            <option value="best">{d.best}</option>
            <option value="price">{d.price}</option>
            <option value="rating">{d.rating}</option>
          </select>
        </label>
        <label className="field">
          <span>{d.gender}</span>
          <select value={gender} onChange={(e) => setGender(e.target.value as '' | 'm' | 'f')}>
            <option value="">{d.all}</option>
            <option value="m">{d.male}</option>
            <option value="f">{d.female}</option>
          </select>
        </label>
        <label className="field">
          <span>
            {d.maxPrice}: <b>${maxPrice}</b>
          </span>
          <input type="range" min={8} max={40} value={maxPrice} onChange={(e) => setMaxPrice(Number(e.target.value))} />
        </label>
        <label className="check">
          <input type="checkbox" checked={availableNow} onChange={(e) => setAvailableNow(e.target.checked)} /> {d.availableNow}
        </label>
        <label className="check">
          <input type="checkbox" checked={instantOnly} onChange={(e) => setInstantOnly(e.target.checked)} /> {d.instantOnly}
        </label>
      </aside>

      <div className="browser-main">
        <div className="searchbar">
          <Icon name="search" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={d.search} aria-label={d.search} />
        </div>
        <div className="chips">
          <button className={`chip ${subject === '' ? 'chip-on' : ''}`} onClick={() => setSubject('')}>
            {d.all}
          </button>
          {subjects.map((s) => (
            <button key={s.id} className={`chip ${subject === s.id ? 'chip-on' : ''}`} onClick={() => setSubject(s.id)}>
              <Icon name={s.icon} size={16} style={{ color: subject === s.id ? '#fff' : s.color }} /> {t(s.name, lang)}
            </button>
          ))}
        </div>
        <p className="muted">
          {results.length} {d.results}
        </p>
        {results.length === 0 ? (
          <div className="card empty">
            <Icon name="search" size={40} />
            <h3>{d.empty}</h3>
            <a className="btn btn-primary" href={WHATSAPP}>
              {d.emptyCta}
            </a>
          </div>
        ) : (
          <div className="grid-tutors">
            {results.map((x) => (
              <TutorCard key={x.id} tutor={x} lang={lang} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
