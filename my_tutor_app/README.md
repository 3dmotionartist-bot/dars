# Dars | درس — Mobile app + Web app (Flutter)

One Flutter codebase → **Android, iOS and Web**. Arabic (RTL) by default, English switch everywhere.
Built from the Modarby teardown in `../ANALYSIS.md`, with Dars' own brand (teal `#0E8F7E` + amber `#F5A524`, Cairo font).

## Run it (first time)

```bash
# 1) Install Flutter 3.22+  →  https://docs.flutter.dev/get-started/install/windows
cd my_tutor_app
flutter create --org com.dars --project-name my_tutor_app --platforms=android,ios,web .   # adds the platform folders, keeps lib/
flutter pub get
flutter run -d chrome        # web app
flutter run                  # Android phone / emulator
```

Build releases:

```bash
flutter build web --release          # → build/web  (upload to any static host / Firebase Hosting)
flutter build apk --release          # → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release    # Play Store
flutter build ipa                    # App Store (needs a Mac)
```

> Note: this code was written without a Flutter SDK available, so it has not been compiled yet.
> If `flutter analyze` reports anything, it will be small (an API rename between Flutter versions) — paste the error to Claude.

## What's inside (≈ 30 screens)

| Area | Screens |
|---|---|
| Onboarding | Welcome + language + role (student / parent / tutor), WhatsApp login, OTP, PIN, first-install wizard (level → curriculum → subjects) |
| Student | Home, tutor search (AI sort, filters), tutor profile (fees per level, packages, availability, reviews, policies), booking wizard (single / package → time → summary → payment → success), **Live help** (text/voice/photo → radar search → accepted tutors → chat/call), My lessons (upcoming / pending / past / packages, join, reschedule, cancel, review, report), Help-me-find-a-tutor wizard |
| Shared | Messages, chat (voice notes, files, contact-info filter, safety banner), voice call, **built-in classroom with whiteboard**, notifications, wallet, account & settings, referral |
| Tutor | Registration (5 steps + ethical pledge), dashboard (available-now switch, DND, stats), incoming live requests (countdown, accept/decline), lessons (link, mark delivered, no-show), availability & booking mode, packages & discounts, earnings & payout |

Phone ⇢ bottom navigation. Width ≥ 900 px (web/tablet) ⇢ side rail + top bar (`lib/widgets/adaptive_shell.dart`).

## Project layout

```
lib/
  main.dart                 app + locale + role routing
  theme.dart                brand colours & Material theme
  l10n.dart                 all Arabic/English strings (context.tr('key'))
  data/models.dart          Tutor, Lesson, Package, Conversation, LiveRequest…
  data/mock_data.dart       demo content (replace with API)
  state/app_state.dart      ChangeNotifier store — every method = one future API call
  widgets/                  shared UI (cards, pills, avatar, adaptive shell)
  screens/{onboarding,auth,student,shared,tutor}/
```

## Connected to the backend

The app talks to the Supabase backend in `../my_tutor_backend` — the same data the admin dashboard
(`../my_tutor_admin`) manages.

- **Demo mode** (default): `lib/config.dart` is empty → sample data, works offline.
- **Live mode**: paste your Supabase *Project URL* and *anon/publishable key* into `lib/config.dart`
  (or set the GitHub repository variables `SUPABASE_URL` and `SUPABASE_ANON_KEY` — the cloud build passes them in).

What is live:

| In the app | What happens on the server | Seen in the dashboard |
|---|---|---|
| Sign in with phone code (SMS / WhatsApp) or email + password | Supabase Auth account + profile | Students & parents / Tutors |
| Tutor sign-up (name, subjects, curricula, fees per level, headline, about) | Tutor application | Tutors → **Pending** (approve / reject) |
| Tutor list, profiles, reviews | Only **approved** tutors are shown | — |
| Book a lesson / buy a package (wallet credit used first) | `book_lesson` / `buy_package` — price, commission and free slot checked by the server | Lessons, Payments |
| Cancel, reschedule, rate, "not satisfied", "tutor didn't show" | Refund rules, reviews, disputes | Lessons, Reviews, Reports |
| Live help ("speak to a tutor now") | Sent to online tutors; accepting opens a chat with the question | Live help |
| Chat (real time, contact-info filter) | Messages table | Reports (if flagged) |
| Tutor: availability, lesson links, mark delivered, no-show, payout request | Earnings go to the tutor's wallet after delivery | Tutor payouts |
| "Help me find a tutor" | Lead | Help requests |
| Notifications | Written by the server (push via Firebase if configured) | — |

Not live yet (still demo UI): card payment gateway (bookings wait for admin confirmation — use *Payments → Confirm*),
voice notes / files / photos upload, video classroom and in-app calls, favourites sync.
