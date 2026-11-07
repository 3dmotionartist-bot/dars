'use client';

import { useState, type FormEvent } from 'react';
import type { Lang } from '@/lib/i18n';
import { getDict } from '@/lib/i18n';
import Icon from './Icon';

/** Static-site friendly: wire `onSubmit` to Formspree / a Supabase function / your API. */
export default function ContactForm({ lang }: { lang: Lang }) {
  const d = getDict(lang).contact;
  const [sent, setSent] = useState(false);
  const submit = (e: FormEvent) => {
    e.preventDefault();
    setSent(true);
  };
  if (sent) {
    return (
      <div className="card empty">
        <Icon name="check" size={40} style={{ color: 'var(--success)' }} />
        <h3>{d.sent}</h3>
      </div>
    );
  }
  return (
    <form className="card form" onSubmit={submit}>
      <label className="field">
        <span>{d.name}</span>
        <input required />
      </label>
      <label className="field">
        <span>{d.email}</span>
        <input required dir="ltr" />
      </label>
      <label className="field">
        <span>{d.type}</span>
        <select>
          {d.types.map((x) => (
            <option key={x}>{x}</option>
          ))}
        </select>
      </label>
      <label className="field">
        <span>{d.message}</span>
        <textarea rows={5} required />
      </label>
      <button className="btn btn-primary" type="submit">
        {d.send}
      </button>
    </form>
  );
}
