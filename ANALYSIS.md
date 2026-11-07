# Modarby (مدربي) v6.0.9 — Full Teardown & Blueprint for **My Tutor – Dars (درس)**

> Source: the Modarby XAPK you supplied (`com.yesatlas.modarby`, version 6.0.9, build 582, min Android 7.0).
> Method: unpacked the base APK + Arabic/English/xhdpi splits; read all **2,322 bilingual UI strings** (`resources.json`),
> **15 lookup tables**, **31 subjects / sub-subjects / topics**, ~**450 images & icons**, fonts, sounds and Android permissions.
> Everything below is what the app actually contains — not guesses from the store page.

---

## 1. What Modarby is (in one paragraph)

A **Flutter** app (Android, iOS, plus a web version at modarby.com) that connects **students / parents** with **private tutors** across the
Gulf & Levant (Saudi, UAE, Kuwait, Jordan, Egypt, Qatar). It has **two ways to get help**:

1. **Book a tutor** — search → filter → tutor profile → book a single lesson or a discounted hours **package** → pay → lesson (online or in-person).
2. **"Speak to a tutor now" (Real-time / Live / Emergency request)** — student records a voice or text message describing the problem,
   the request is broadcast to all *available* tutors for a countdown window, tutors **accept**, student sees who accepted and **chats or
   calls in-app** (VoIP, recorded 5-min calls).

Business model: **commission on each lesson**, packages with discounts (1–50% set by tutor), monthly **school subscriptions** for parents,
a **referral / marketer program (10% commission)**, and BNPL (**Tamara / Tabby**) payments. Communication is kept inside the app
(phone numbers/emails are filtered in chat; tutors sign an "ethical commitment" oath not to take students off-platform).

---

## 2. Tech stack found in the APK

| Area | What Modarby uses |
|---|---|
| App framework | **Flutter** (Dart) — same as the stack chosen for Dars |
| Font | **Cairo** (8 weights) — Arabic + Latin |
| Backend | Custom REST API (`modarby.com`, `test.modarby.com`), content versioning for cached lookups |
| Push / analytics | Firebase Messaging, Firebase Analytics, Play Install Referrer, Ad-ID |
| Auth | **WhatsApp OTP** + 4-digit **PIN code**, email/password fallback, Google & Facebook login |
| Calls | In-app VoIP with CallKit-style full-screen incoming call (`MANAGE_OWN_CALLS`, `FOREGROUND_SERVICE_PHONE_CALL`), call recording |
| Media | Voice-note recording, file/image attachments, YouTube intro videos, in-app WebView, screen sharing permission |
| Payments | Card (Telr / Moyasar), **Mada**, **Apple Pay**, **Tamara** & **Tabby** (BNPL), bank transfer with receipt upload, cash at partner offices, wallet credit |
| Other | Location (for time-zone), in-app review, in-app update (mandatory / recommended), country flags package, Lottie animations |

---

## 3. User types

| Role | Arabic | Purpose |
|---|---|---|
| Student | طالب | Searches, books, chats, uses live help |
| Parent | ولي أمر | Same as student, books for a child, subscriptions |
| Tutor (Instructor) | مدرس | Profile, availability, prices per level, packages, accepts live requests, gets paid |
| Marketer (Referral) | مسوّق | Invites students via link, earns 10% of their bookings |
| Academic advisor (staff) | المرشد الأكاديمي | Human help via WhatsApp ("Maram, Academic Advisor") when search finds nothing |

---

## 4. Complete screen map

### 4.1 Onboarding & Auth
1. **Splash** → language detection, forced/recommended update check.
2. **Language picker** (عربي / English).
3. **"Who is going to use the application?"** — Student / Parent / Tutor / Marketer cards.
4. **First-install wizard** (students): study level (6 levels with illustrations) → curriculum (11 options) → "Which area do you want to improve?" (multi-select subjects).
5. **Permissions explainers**: notifications ("To keep you updated on messages and class schedules"), location ("To select time zone"), microphone, storage.
6. **Sign up / in by WhatsApp** — enter WhatsApp number with country flag picker → OTP code (sent to WhatsApp & email) → **create 4-digit PIN**.
7. **Login by WhatsApp + PIN**, "Forgot your PIN?" (reset via WhatsApp), Login by email, Google, Facebook.
8. **Complete profile** (student: name, gender, level, year of study, school/university, curriculum; "How did you hear about us?").
9. **Ethical commitment** screen ("I pledge … all bookings through the platform") — student, tutor & marketer versions.
10. **Change WhatsApp number**, **Delete account** (with WhatsApp OTP).

### 4.2 Student — Home & Discovery
11. **Home** — header "On-demand private tutoring support", search bar ("Search an area or subject"), **"Speak to a tutor now" banner**,
    "Explore tutors by subjects" grid (3D icons), popular sub-subjects chips (General English, IELTS, Physics…), "Student packages"
    subscription banner, "Help in homework & exam preparation" banner, guarantee badge ("First hour free if not satisfied"),
    "Need help with booking? → WhatsApp advisor".
12. **Search wizard** (bottom sheets): level → curriculum → subject → sub-subjects (max 9) → teaching mode (online / in-person + city).
13. **Tutor list (search results)** — sort: **Best match (AI)** / Price; filter sheet: gender, nationality, price range per hour,
    availability, curriculum, level, sub-subject, *instant booking only*, *has packages*, *has video*, *speaks Arabic*, *research/thesis expert*.
    Tutor cards: photo, name, verified tick, "Available" pill, headline, subject tags, price from, "Up to X% off packages",
    rating, **matching score** (Excellent / Very good / Good), "Newly joined" badge.
14. **No results** state with advisor card + WhatsApp CTA.
15. **"Help me find a tutor" wizard** (lead form): user type → level → year → major → reason (better grades, exam prep, homework, research) → mode → contact info (name, city, WhatsApp) → extra notes → success.

### 4.3 Tutor Public Profile
16. Photo, name, verified, headline, intro **video**, "About the tutor" (200–500 chars), subjects & sub-subjects, **languages spoken + level**,
    teaching experience (country, years, levels taught), resume (degrees, certificates, experiences, CV/LinkedIn),
    **fees per study level** (choose your level to see price), packages ("Discount up to #%"), **availability calendar**,
    cancellation policy (2–72 h), reviews (only real students), stats (hours, students), "Contact the tutor", "Book".

### 4.4 Booking & Payment
17. **Booking type**: Single lesson (< 4 h) vs Package (≥ 4 h, up to 25–30% off).
18. **Select time** — calendar + slots, time-zone conversion ("equal to {time} in your local time"), duration 25 / 50 min or 20–180 min,
    lesson type (online / in-person at student's / tutor's place), add multiple lessons, notes.
    *Instant booking* (tutor's calendar) vs *Request to book* (tutor must accept).
19. **Missing info** sheet (name, WhatsApp) if profile incomplete.
20. **Summary preview** — subject, date, duration, price, VAT 15% (KSA), used credit, total.
21. **Payment method** — billing country → Online (card / Mada / Apple Pay), Tamara "split in 3", Bank transfer (agent banks KSA/UAE/Kuwait, upload receipt, 48 h hold), Cash at partner office, *Use my balance*.
22. **Card checkout** / processing / waiting for bank / **success** ("Lesson booked – contact your tutor" + WhatsApp CTA) / failed.
23. **Package purchase** — choose hours (presets or custom), discount calc, original vs discounted price → pay → "Book lessons through the package".

### 4.5 Live Help ("Speak to a tutor now")
24. **Intro** — "Connect with your tutor! Speak with your tutor directly within the app" + complete-profile gate.
25. **Compose request** — "Write your learning goals / Why do you need help?" text **or** voice note (one recording, re-record replaces).
26. **Searching** — animated radar, countdown (minutes:seconds), rotating messages ("Test tomorrow? Find a tutor now…"), Stop search / Cancel.
27. **Results** — list of tutors who accepted (max N), each with Chat + Call buttons; "Try again", "Edit search".
28. **Timeout / none found** → WhatsApp support.

### 4.6 Messaging & Calls
29. **Messages list** (My Messages, unread, mark all read).
30. **Chat** — text, **voice notes** (hold to record, slide to cancel), images & files (doc/pdf/jpg/xls ≤ 5 MB), copy/forward to many tutors,
    "Book a lesson" shortcut, warning banner ("All calls/messages recorded. No personal info. Payments via platform only"),
    **contact-info filter**, report conversation, delete.
31. **Voice call** — outgoing (ringing / busy / no answer), incoming full-screen, mute / speaker / record, "5-min recorded call for quality",
    **call permission settings** (allow all tutors / only my tutors / ask first).

### 4.7 Student Dashboard
32. **My lessons** — Coming / Pending payment (auto-cancel 48 h) / Past; actions: **Join lesson** (1 min before), Reschedule, Cancel
    (refund rules), Report **No-show**, **Not satisfied** (first-hour guarantee), Repeat booking, Review.
33. **My packages** — Active / Pending / Expired; remaining hours, book from package, cancel (reasons).
34. **My balance / wallet** — credit, refunds, "Pay me / Refund to me" request.
35. **Payment history** — receipts.
36. **Notifications** list.
37. **Reviews** — add / edit / delete (1–5 stars + comment).
38. **Profile & settings** — edit profile, language, call settings, notification settings, referral program, share app, rate app,
    contact us (WhatsApp), policies (terms, privacy, refund), version, logout, delete account.
39. **Customer satisfaction questionnaire** (1–10 NPS-style).

### 4.8 Tutor (Instructor) side
40. **Tutor registration (4 steps)** — personal info → subjects (≤ 3 main, ≤ 9 subs) & curricula & teaching modes →
    levels + **fee per level** + currency → resume (CV upload + LinkedIn, degrees, certificates, experience by country), languages, headline (15–50 chars),
    about (200–500), photo crop, intro video → commitment oath → **pending verification**.
41. **Tutor dashboard** — "Congratulations, you're verified", announcements, upcoming lessons, lessons in last 24 h, lessons awaiting payment,
    stats (hours, students, rating).
42. **Availability** — working hours per day, **"I'm available now" toggle**, **Do-not-disturb (N hours)**, booking mode
    (instant vs request), real-time request settings ("Any time" / "Only during my working hours").
43. **Incoming live requests** — student's text/voice, accept / reject, countdown, "Another tutor accepted / request expired / canceled" dialogs,
    "Max tutors reached".
44. **Tutor lessons** — add lesson link / recording link, mark delivered, report student no-show, contact student on WhatsApp, update student info.
45. **My packages settings** — enable/disable, discount per hours tier (1–50%).
46. **My balance** — lesson fees, commission, net, pending / confirmed / transferred, **Pay me** (bank IBAN/Swift, PayPal, Western Union), billing info.
47. **Public profile preview & edit** (locked fields after verification → "contact customer service").

### 4.9 Marketer (Referral)
48. Explanation → register → referral link → add students by WhatsApp → students list (pending / accepted) → referral balance & commission %.

### 4.10 Other
49. **Subscriptions** (parents): Foundation / Strength / Superiority / kids packages; academic monitor; evaluation reports; flexible times → request via WhatsApp OTP.
50. **Online / summer courses** (group courses: capacity, schedule, age group, what to bring).
51. **Static pages**: About, Terms, Privacy, Refund policy, Common questions, Blog, Sitemap, "Become a tutor" landing, Student guide.

**Total ≈ 50 distinct screens / sheets** plus ~40 dialogs.

---

## 5. Key user flows (diagrams)

```
STUDENT – BOOK
Home ─► Search/wizard ─► Tutor list ─► Tutor profile ─► Booking type ─► Time ─► Summary ─► Payment ─► Success ─► Chat/WhatsApp ─► Lesson ─► Review
                                   └─► Filter / Sort (AI best match)          └─► Package ─► hours ─► pay ─► book from package

STUDENT – LIVE HELP
Home banner ─► Compose (text/voice) ─► Broadcast ─► Searching (countdown) ─► Accepted tutors ─► Chat / Call ─► Book lesson

TUTOR – LIVE HELP
Push "Real time Request!" ─► Request card (voice/text) ─► Accept ─► auto message "Hello, I've accepted your request…" ─► chat / call

TUTOR – ONBOARD
Role ─► WhatsApp OTP ─► PIN ─► Info ─► Subjects ─► Levels & fees ─► Resume ─► Commitment ─► Pending ─► Verified dashboard
```

Lesson status machine: `Pending payment → Confirmed → Delivered | No-show | Not satisfied | Cancelled → Refunded | Transferred`.

---

## 6. Design system (extracted)

| Token | Value | Use |
|---|---|---|
| Primary (brand coral) | `#FF5A5F` (197 uses in SVGs) | Logo, CTAs, active icons, call buttons |
| Ink | `#1A1818`, `#1C1C1E`, `#111C3A` | Headlines, text |
| iOS greys | `#8D8D92`, `#636366`, `#48484A`, `#3A3A3C`, `#C9C9C9`, `#D1D1D6`, `#E5E5EA`, `#F2F2F7` | Secondary text, borders, surfaces |
| Info blue | `#007AFF`, `#E2EFFD`, `#EAEEF9` | Verified tick, links, tag chips |
| Success | `#34C759` | "Available" pill, online dot |
| Navy accents | `#2B4D66`, `#26467A`, `#3D5188` | Illustrations |
| Font | **Cairo** 200–900 | Both languages |

**Visual style**: clean white cards with 12–16 px radius, soft shadows, iOS-style list rows; **glossy 3D subject icons** (calculator, flask,
TOEFL/IELTS/SAT/STEP books, Arabic letter bubble, Quran); flat outline icons for UI; real tutor photos with verified badge;
pill tags (lavender for languages, blue for science); green "Available" pill; Lottie skeletons for loading; full-bleed gradient
backgrounds on call screens; RTL-first layout with mirrored arrows (`edit_pin_icon_ar/en`). Sounds: ringtone, message, request alerts.

---

## 7. Content & data model

- **Study levels (6)**: Pre-school, Elementary (6 yrs), Middle (3), High school (3), University, Adult professionals.
- **Curricula (11)**: American, British IG, IB, French Bac, Saudi, UAE, Egyptian, Jordanian, Kuwaiti, Qatari, None.
- **Subjects (31)** → **sub-subjects** (348) → topics. Popular: General English, IELTS, Physics, Math…
- **Degrees**: Diploma, Bachelor, Master, High Diploma, PhD.
- **Cancellation policy** options: 2, 4, 6, 8, 12, 16, 24, 36, 48, 60, 72 hours.
- **Booking statuses (11)**, **payment methods (7)**, **payout methods (3)**, currencies, 240 country codes, languages + 5 proficiency levels.

Core entities for Dars: `User(role)`, `StudentProfile`, `TutorProfile`, `Subject/SubSubject`, `LevelPrice`, `Availability`,
`Lesson`, `Package`, `LiveRequest`, `Conversation/Message`, `Call`, `Payment`, `Wallet/Transaction`, `Review`, `Referral`, `Notification`.

---

## 8. Business ideas worth keeping

1. **Two-speed help**: instant live help (impulse, homework panic) + scheduled booking (recurring revenue).
2. **WhatsApp-first identity** — no passwords; matches how the region communicates.
3. **Per-level pricing** set by tutor (Elementary cheaper than University).
4. **Packages with tutor-defined discounts** → prepaid hours, lower churn.
5. **First-hour guarantee** ("Not satisfied → refund") lowers the trust barrier.
6. **AI "matching score"** on every card.
7. **Human fallback** (academic advisor on WhatsApp) when search fails — converts leads.
8. **Anti-leakage**: chat filter, recorded calls, commitment oath, WhatsApp only revealed after booking.
9. **Referral marketers** (10%) — a cheap acquisition channel via teachers/schools.
10. **Parent subscriptions** with an academic monitor and evaluation reports.
11. **BNPL + local payment rails** (Mada, Tamara, bank transfer, cash offices).

## 9. Weak points found (opportunities for Dars)

| Modarby problem | Evidence | Dars improvement |
|---|---|---|
| Live requests arrive late on iPhone; app doesn't run in background | App Store review 2024 | Push via FCM/APNs high-priority + VoIP push, SMS/WhatsApp fallback, tutor "on-duty" heartbeat |
| ~100 strings whose English text is just the raw key name, plus 37 empty strings, shown to users (`anothertutoraccepteddialog.body`, `lessons.reschedulebookingtext`…) | resources.json | Typed l10n (ARB) with CI check for missing keys |
| Very long registration (5 steps students, 4 steps tutors, oath) | strings | Progressive profiling: ask only what's needed at the moment it's needed |
| Many payment branches are manual (bank receipt, cash office, 48 h holds) | strings | Start with card/Apple Pay/Mada + wallet; add manual rails later |
| Booking coordination falls back to WhatsApp after paying | "Chat with your tutor on WhatsApp to plan the lesson" | Built-in scheduling + built-in video classroom (no off-app hop) |
| No in-app classroom (tutor pastes external lesson link) | "Add lesson link" | Integrated video room (Agora/LiveKit/Jitsi) with whiteboard + recording |
| Privacy complaint | App Store review 2021 | Clear privacy center, granular data controls, parental mode |
| Generic, inconsistent copy (typos: "Gurantee", "mssage") | strings | Copy review in both languages |

**Extra ideas for Dars**: AI homework-photo triage (snap a question → auto-pick subject & level → route live request),
lesson summaries & homework sent to parents, progress reports, tutor quality score, group classes, Syrian & Gulf curricula,
local pricing in SYP/SAR/AED/USD, offline-friendly low-bandwidth mode, gamified streaks for students.

---

## 10. What was built for Dars (this folder)

| Folder | What | Stack |
|---|---|---|
| `my_tutor_app/` | Mobile app **and** web app (same code) — student + tutor experiences, AR/EN with RTL, mock data, ready to plug into a backend | Flutter 3 + Provider |
| `my_tutor_website/` | Marketing website — home, find tutors, tutor profile, become a tutor, pricing, about, FAQ, contact, legal — `/ar` & `/en` | Next.js 14 (App Router), static export |

See each folder's `README.md` for run & build commands.
