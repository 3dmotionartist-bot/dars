# Dars — Admin dashboard

A management console for the Dars team, in Arabic and English, on desktop and phone.
No build step — it's three plain files you can host anywhere (GitHub Pages, Netlify, Vercel, Supabase storage, any web server).

## Try it now
Open `index.html` in a browser. With `config.js` empty it runs in **demo mode** with sample data, so you can click
through everything; changes are kept until you reload.

## Connect your real backend
1. Set up the backend — see `../my_tutor_backend/README.md`.
2. In `config.js` paste your Supabase **Project URL** and **anon public key**.
3. Open the page and sign in with the admin email you created. Non-admin accounts are refused (and the database
   refuses them too, so the anon key is safe to publish).

## Screens
| Screen | What you can do |
|---|---|
| Overview | Revenue & commission (30 days), lessons, students, tutors online, live-help match rate, 14-day payments chart, everything waiting for action |
| Tutors | Review new applications (CV, video, subjects, price), approve, reject with a reason, block |
| Students & parents | Search, block/unblock, add or deduct wallet balance with a reason |
| Lessons | Filter by status, refund the student, or release a disputed lesson to the tutor |
| Live help | Every instant-help request, how many tutors accepted, match rate |
| Payments | Confirm or reject pending payments (bank-transfer receipts, or any booking while the card gateway isn't connected yet) |
| Tutor payouts | Approve, mark as paid, or reject withdrawal requests (shows the tutor's balance) |
| Reviews | Hide or show reviews (tutor rating updates automatically) |
| Reports | Complaints about lessons and chats — refund/release or resolve/dismiss with a note |
| Help requests | Leads from the website's "find me a tutor" form — copy the WhatsApp number, track status |
| Subjects & levels | Rename subjects, hide/show them in the app, see level price factors |
| Settings | Commission, VAT, live-help timing, payment window, referral commission, support WhatsApp, first-hour guarantee |
