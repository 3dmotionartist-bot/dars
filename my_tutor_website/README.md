# Dars | درس — Marketing website (Next.js)

Bilingual (Arabic RTL default `/ar/`, English `/en/`), static-exported, SEO-ready marketing site for Dars.
Same brand as the app: teal `#0E8F7E`, amber `#F5A524`, Cairo font.

## Pages (18 per language, 36 total)
| Route | Content |
|---|---|
| `/ar/` `/en/` | Hero + search, live stats, **Live help** section, how it works, subjects, featured tutors (AI match), guarantee & safety, testimonials, tutor CTA, app download |
| `/tutors/` | Search, subject chips, filters (gender, max price, available now, instant booking), sort (AI / price / rating) — supports `?q=` and `?subject=` |
| `/tutors/[id]/` | Tutor profile: stats, about, subjects, reviews, fees per level, package discounts, cancellation policy, Book / Message |
| `/become-a-tutor/` | Tutor landing, perks, **earnings calculator**, 4 steps, requirements |
| `/pricing/` | Single lesson vs packages, parent subscriptions (Foundation / Strength / Excellence), payment methods |
| `/about/` `/faq/` (FAQ schema.org) `/contact/` `/legal/terms|privacy|refund/` | |

## Run
```bash
cd my_tutor_website
npm install
npm run dev        # http://localhost:3000/ar/
npm run build      # static site in ./out  → upload to Netlify, Vercel, Firebase Hosting, cPanel…
```

## Connected to the backend

`lib/backend.ts` — leave empty for the built-in sample tutors, or set `NEXT_PUBLIC_SUPABASE_URL` and
`NEXT_PUBLIC_SUPABASE_ANON_KEY` (the cloud build passes the GitHub repository variables `SUPABASE_URL` / `SUPABASE_ANON_KEY`).

When connected:
- **Find a tutor**, the home page's featured tutors and tutor profiles (`/[lang]/tutor/?id=…`) show tutors approved in the admin dashboard.
- **Contact** form messages arrive in the dashboard under **Help requests**.

## Edit content
- All text (both languages): `lib/i18n.ts`
- Tutors, subjects, levels: `lib/data.ts` (replace with your API / CMS later)
- Styles & brand tokens: `app/globals.css` (`:root` variables)
- Links to the web app: `APP_URL` in `lib/data.ts` (point it at the deployed Flutter web build)

## Checked so far
Every file was syntax- and type-checked with TypeScript. All 36 pages were rendered and screenshotted at
desktop and phone widths, in Arabic and English, with no horizontal overflow. Not yet run: `npm install` / `next build`.
The workspace that wrote this code had no network access, so run those two first.
