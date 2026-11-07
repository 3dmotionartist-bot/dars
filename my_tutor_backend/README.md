# Dars — Backend (Supabase)

Everything the app, website and admin dashboard need: database, sign-in, file storage, real-time chat,
payments webhook, push notifications and scheduled jobs. Runs on **Supabase** (free tier is enough to start).

## What's inside

| Path | What it does |
|---|---|
| `supabase/migrations/…01_schema.sql` | Tables: profiles, tutors, subjects, availability, lessons, packages, payments, wallet ledger, payouts, live help, chat, reviews, reports, help-request leads, notifications, settings, audit log |
| `supabase/migrations/…02_security.sql` | Row Level Security on every table — users only see their own data; admins see everything |
| `supabase/migrations/…03_logic.sql` | All money and booking rules as server functions (book, pay, cancel, reschedule, refund, payouts, live help matching, admin actions, dashboard stats) |
| `supabase/migrations/…04_platform.sql` | Scheduled jobs, file-storage buckets, real-time channels |
| `supabase/seed.sql` | Subjects, study levels, curricula (Arabic + English) |
| `supabase/demo_data.sql` | **Optional** sample tutors/students/lessons for a test project — never on production |
| `supabase/functions/payment-webhook` | Receives the payment gateway's callback and confirms/fails the payment |
| `supabase/functions/push-notifications` | Sends phone notifications through Firebase when a notification row is created |
| `tests/` | 56 automated checks of the whole flow (booking → payment → lesson → review → payout, live help, chat filter, permissions) |

### Business rules built in
- Platform commission (default 15 %) is taken when a lesson is delivered; the tutor's share goes to their wallet.
- Wallet balances come only from the ledger — nobody can edit a balance directly.
- Unpaid bookings auto-cancel after 48 h; delivered lessons auto-complete 24 h after the end time if nobody disputes.
- Cancel ≥ tutor's notice period → full refund to wallet; later → no refund.
- Live help request is sent to up to 5 online tutors and expires after 90 s.
- Chat blocks phone numbers, emails and social handles (keeps students and tutors on the platform).
- Tutors appear publicly only after an admin approves them.
- Every admin action is written to the audit log.
All numbers are editable in the dashboard → Settings.

## Set up (about 20 minutes)

1. **Create the project** — sign up at supabase.com → *New project*. Pick a region near your users (Frankfurt works for the Middle East).
2. **Create the database** — open *SQL Editor* and run these files **in order** (copy-paste each one, press *Run*):
   1. `migrations/20261107000001_schema.sql`
   2. `migrations/20261107000002_security.sql`
   3. `migrations/20261107000003_logic.sql`
   4. `migrations/20261107000004_platform.sql`
   5. `seed.sql`
   6. *(test project only)* `demo_data.sql`

   Step 4 switches on the **pg_cron** extension and schedules the automatic jobs (you can see them under *Database → Cron*).
   *(Developers can instead run `supabase link` then `supabase db push`.)*
3. **Phone sign-in** — *Authentication → Providers → Phone*: turn it on and connect Twilio (SMS or WhatsApp) or MessageBird. Also keep **Email** on — the admin dashboard signs in with email.
4. **Create your admin account** — *Authentication → Users → Add user* (email + password, "Auto confirm"). Then in SQL Editor:
   ```sql
   update profiles set role = 'admin', full_name = 'Your name' where email = 'you@example.com';
   ```
   For safety, nobody can make themselves admin from the app — it can only be done here.
5. **Connect the dashboard, app and website** — *Project Settings → API*, copy the **Project URL** and the
   **anon public** key (or the newer **publishable** key) into:
   - `my_tutor_admin/config.js`
   - `my_tutor_app/lib/config.dart`
   - `my_tutor_website/lib/backend.ts`

   …or, for the app and website, add them once as GitHub repository variables `SUPABASE_URL` and `SUPABASE_ANON_KEY`
   (*Settings → Secrets and variables → Actions → Variables*) — every cloud build then uses them.
   For quick testing before SMS/WhatsApp codes are set up: *Authentication → Providers → Email* on, and
   *Confirm email* off — people can then sign up in the app with "Continue with email".
6. **Payments webhook** (when you pick a gateway — Tap, HyperPay, Moyasar, Stripe…):
   ```bash
   supabase secrets set PAYMENT_WEBHOOK_SECRET=some-long-random-text
   supabase functions deploy payment-webhook
   ```
   Point the gateway's webhook at `https://<project>.supabase.co/functions/v1/payment-webhook`.
   The function expects JSON `{ "payment_id", "status": "paid"|"failed", "provider", "reference" }` signed with
   HMAC-SHA256 of the body in the `x-dars-signature` header — adapt the top of `index.ts` to your gateway's format.
   Bank-transfer receipts don't need this: admins confirm them in the dashboard.
7. **Push notifications** — create a Firebase project, download a service-account key, then:
   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)"
   supabase functions deploy push-notifications
   ```
   In *Database → Webhooks* add a webhook: table `notifications`, event *Insert*, type *Supabase Edge Function* → `push-notifications`.

## Run the tests (developers)
Needs PostgreSQL 15+ locally:
```bash
sudo -u postgres bash tests/run.sh      # → ALL FLOW TESTS PASSED
```

## Never put in the app or website
The **service_role** key. Only the anon key goes in front-end code; every rule is enforced in the database.
