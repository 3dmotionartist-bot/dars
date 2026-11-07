'use client';

import { useState, type FormEvent } from 'react';
import { submitLead } from '@/lib/backend';
import type { Lang } from '@/lib/i18n';
import { getDict } from '@/lib/i18n';
import Icon from './Icon';

/** Sends a "Help request" to the admin dashboard (when the site is connected to the backend). */
export default function ContactForm({ lang }: { lang: Lang }) {
  const d = getDict(lang).contact;
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [name, setName] = useState('');
  const [contact, setContact] = useState('');
  const [type, setType] = useState(0);
  const [message, setMessage] = useState('');

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      await submitLead({
        full_name: name.trim(),
        whatsapp: contact.trim(),
        who: type === 0 ? 'student' : null,
        reason: `Website contact — ${getDict('en').contact.types[type] ?? ''}`,
        notes: message.trim(),
      });
      setSent(true);
    } catch {
      setError(lang === 'ar' ? 'تعذّر الإرسال، حاول مرة أخرى أو راسلنا على واتساب.' : 'Could not send — please try again or message us on WhatsApp.');
    } finally {
      setBusy(false);
    }
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
        <input required value={name} onChange={(e) => setName(e.target.value)} autoComplete="name" />
      </label>
      <label className="field">
        <span>{d.email}</span>
        <input required dir="ltr" value={contact} onChange={(e) => setContact(e.target.value)} />
      </label>
      <label className="field">
        <span>{d.type}</span>
        <select value={type} onChange={(e) => setType(Number(e.target.value))}>
          {d.types.map((x, i) => (
            <option key={x} value={i}>
              {x}
            </option>
          ))}
        </select>
      </label>
      <label className="field">
        <span>{d.message}</span>
        <textarea rows={5} required value={message} onChange={(e) => setMessage(e.target.value)} />
      </label>
      {error && <p className="small" style={{ color: 'var(--danger)' }}>{error}</p>}
      <button className="btn btn-primary" type="submit" disabled={busy}>
        {busy ? '…' : d.send}
      </button>
    </form>
  );
}
