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

## Connecting a backend (next step)

Recommended: **Supabase** (Postgres + Auth + Realtime + Storage) or **Firebase**.

| Feature | Service |
|---|---|
| WhatsApp OTP login | Twilio Verify / Meta WhatsApp Cloud API → custom auth |
| Live requests (instant) | Supabase Realtime or Firestore listeners + FCM high-priority push + VoIP push on iOS |
| Chat & voice notes | Realtime table + Storage bucket |
| Calls & classroom | LiveKit / Agora / Jitsi (+ `flutter_callkit_incoming`) |
| Payments | Stripe / Checkout.com / Tap / Moyasar (Mada, Apple Pay), Tamara/Tabby BNPL |
| Push | Firebase Cloud Messaging |

Replace the mock lists in `AppState` with repository calls; the UI won't need changes.
