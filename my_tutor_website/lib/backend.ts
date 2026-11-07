/**
 * Connection to the Dars backend (Supabase). Plain `fetch` — no extra packages.
 *
 * Empty values → the website shows its built-in sample tutors and the forms just say "thanks".
 * Filled → tutors come from the database (only tutors approved in the admin dashboard) and
 * forms create "Help requests" in the dashboard.
 *
 * Set them as environment variables at build time (NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY)
 * or paste them below. The anon key is public by design — the database rules protect everything.
 */
import type { T, Tutor } from './data';

const FILE_URL = '';
const FILE_KEY = '';

const API_URL = (process.env.NEXT_PUBLIC_SUPABASE_URL || FILE_URL).replace(/\/$/, '');
const KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || FILE_KEY;

export const LIVE = Boolean(API_URL && KEY);

function headers(extra: Record<string, string> = {}): Record<string, string> {
  // Legacy anon keys are JWTs and also go in Authorization; new "publishable" keys only go in apikey.
  return { apikey: KEY, ...(KEY.startsWith('eyJ') ? { Authorization: `Bearer ${KEY}` } : {}), ...extra };
}

async function get<R>(path: string): Promise<R> {
  const r = await fetch(`${API_URL}/rest/v1/${path}`, { headers: headers(), cache: 'no-store' });
  if (!r.ok) throw new Error(`Backend error ${r.status}`);
  return (await r.json()) as R;
}

type Row = Record<string, unknown>;

const PALETTE = ['#2F6BFF', '#7B61FF', '#0E8F7E', '#F59E0B', '#22B573', '#E5484D', '#5B45D6', '#0EA5E9', '#EC4899'];
const colorFor = (s: string) => PALETTE[[...s].reduce((a, c) => a + c.charCodeAt(0), 0) % PALETTE.length];
const LANGS: Record<string, T> = {
  ar: { ar: 'العربية', en: 'Arabic' }, en: { ar: 'الإنجليزية', en: 'English' }, fr: { ar: 'الفرنسية', en: 'French' },
  tr: { ar: 'التركية', en: 'Turkish' }, de: { ar: 'الألمانية', en: 'German' }, es: { ar: 'الإسبانية', en: 'Spanish' },
};
const same = (v: unknown): T => ({ ar: String(v ?? ''), en: String(v ?? '') });
const num = (v: unknown) => Number(v ?? 0) || 0;

function toTutor(r: Row): Tutor {
  const id = String(r.id);
  const name = String(r.full_name || '').trim() || 'مدرّس';
  const rating = num(r.rating_avg);
  const langs = ((r.languages as Array<{ code?: string } | string>) || []).map((l) => {
    const code = typeof l === 'string' ? l : String(l.code ?? '');
    return LANGS[code] ?? same(code.toUpperCase());
  });
  const subjects = ((r.subject_ids as string[]) || []).map(String);
  return {
    id,
    live: true,
    name: same(name),
    headline: same(r.headline),
    about: same(r.about),
    subjects: subjects.length ? subjects : ['math'],
    tags: [],
    rating,
    reviews: num(r.rating_count),
    hours: num(r.hours_taught),
    students: num(r.students),
    price: Math.max(1, Math.round(num(r.hourly_price))),
    maxDiscount: num(r.max_package_discount),
    available: r.available_now === true,
    instant: r.instant_booking !== false,
    isNew: r.is_new === true,
    gender: r.gender === 'f' ? 'f' : 'm',
    country: same(r.country),
    languages: langs.length ? langs : [LANGS.ar],
    years: num(r.years_experience),
    match: Math.min(99, Math.round(60 + rating * 6 + (r.available_now === true ? 4 : 0))),
    color: colorFor(id),
    inPerson: r.teaches_in_person === true,
    cancelHours: num(r.cancel_hours) || 12,
    reviewList: [],
  };
}

/** Approved tutors from the database, or null when the site isn't connected. */
export async function fetchLiveTutors(): Promise<Tutor[] | null> {
  if (!LIVE) return null;
  const rows = await get<Row[]>('public_tutors?select=*&order=rating_avg.desc&limit=500');
  return rows.map(toTutor);
}

/** One approved tutor with their visible reviews. */
export async function fetchLiveTutor(id: string): Promise<Tutor | null> {
  if (!LIVE || !/^[0-9a-f-]{36}$/i.test(id)) return null;
  const [rows, reviews] = await Promise.all([
    get<Row[]>(`public_tutors?select=*&id=eq.${id}`),
    get<Row[]>(`reviews?select=stars,comment,created_at&tutor_id=eq.${id}&status=eq.visible&order=created_at.desc&limit=20`).catch(() => [] as Row[]),
  ]);
  if (!rows.length) return null;
  const x = toTutor(rows[0]);
  x.reviewList = reviews.map((r) => ({
    by: { ar: 'طالب في درس', en: 'Dars student' },
    stars: num(r.stars),
    text: same(r.comment ?? ''),
    date: String(r.created_at ?? '').slice(0, 10),
  }));
  return x;
}

export type Lead = {
  full_name: string;
  whatsapp: string;
  city?: string;
  who?: 'student' | 'parent' | null;
  level_id?: string;
  subject_id?: string;
  reason?: string;
  mode?: 'online' | 'in_person' | 'both';
  notes?: string;
};

/** Creates a "Help request" in the admin dashboard. No-op when the site isn't connected. */
export async function submitLead(lead: Lead): Promise<void> {
  if (!LIVE) return;
  const clean = Object.fromEntries(Object.entries(lead).filter(([, v]) => v !== undefined && v !== null && v !== ''));
  const r = await fetch(`${API_URL}/rest/v1/leads`, {
    method: 'POST',
    headers: headers({ 'Content-Type': 'application/json', Prefer: 'return=minimal' }),
    body: JSON.stringify(clean),
  });
  if (!r.ok) throw new Error(`Could not send (${r.status})`);
}
