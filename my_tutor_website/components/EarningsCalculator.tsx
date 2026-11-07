'use client';

import { useState } from 'react';
import type { Lang } from '@/lib/i18n';
import { getDict } from '@/lib/i18n';

export default function EarningsCalculator({ lang }: { lang: Lang }) {
  const d = getDict(lang).become;
  const [rate, setRate] = useState(15);
  const [hours, setHours] = useState(12);
  const monthly = Math.round(rate * hours * 4.3 * 0.85);
  return (
    <div className="card calc">
      <h3>{d.calcTitle}</h3>
      <label className="field">
        <span>
          {d.calcRate}: <b>${rate}</b>
        </span>
        <input type="range" min={5} max={60} value={rate} onChange={(e) => setRate(Number(e.target.value))} />
      </label>
      <label className="field">
        <span>
          {d.calcHours}: <b>{hours}</b>
        </span>
        <input type="range" min={1} max={40} value={hours} onChange={(e) => setHours(Number(e.target.value))} />
      </label>
      <div className="calc-result">
        <span>{d.calcMonthly}</span>
        <strong>${monthly.toLocaleString('en-US')}</strong>
      </div>
      <p className="muted small">{d.calcNote}</p>
    </div>
  );
}
