/// Backend connection.
///
/// Leave both values empty → the app runs in DEMO mode with sample data (no account needed).
/// Fill them → the app uses your real Supabase backend: real sign-in, tutors, bookings, chat,
/// live help and payments, all visible in the admin dashboard.
///
/// Where to find them: Supabase → Project Settings → API → "Project URL" and "anon public" key.
/// The anon key is safe to ship inside the app — every rule is enforced by the database.
///
/// You can also pass them at build time instead of editing this file:
///   flutter build apk --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
class DarsConfig {
  // ▼ Paste your values here (or leave empty for demo mode).
  static const _url = 'https://upfaylwpfnqplmqqngoj.supabase.co';
  static const _anonKey = 'sb_publishable_e4P1x5mV9AWkdWJGJKfvXg_W5_6ex2h';

  static const _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const supabaseUrl = _envUrl != '' ? _envUrl : _url;
  static const supabaseAnonKey = _envKey != '' ? _envKey : _anonKey;

  /// How the sign-in code is sent to phones: 'sms' or 'whatsapp' (needs Twilio WhatsApp in Supabase Auth).
  static const otpChannel = String.fromEnvironment('OTP_CHANNEL', defaultValue: 'sms');

  /// Length of the sign-in code Supabase sends (6 by default).
  static const otpLength = 6;

  /// Voice / video call page (published with the website). Calls open there in the phone's browser.
  static const callPageUrl = 'https://3dmotionartist-bot.github.io/dars/call/';

  /// Build number set by the build server (--dart-define=DARS_BUILD=<run number>); 0 for local / older builds.
  static const build = int.fromEnvironment('DARS_BUILD');

  /// Latest Android app (published with the website on every build).
  static const apkUrl = 'https://3dmotionartist-bot.github.io/dars/Dars.apk';

  static bool get live => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
