import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Round H1: the server answers in English (old app versions rely on it). The Arabic for each English text it
/// can write — refusals and notifications — is kept on the server (table server_texts) as patterns: the
/// whole English sentence, with (.+) for a variable part, and the Arabic with \1, \2 … for those parts.
/// The app downloads the list (and keeps a copy for offline starts) and shows the Arabic when the app is in Arabic.
class ServerText {
  static List<(RegExp, String)> _rules = const [];
  static const _cacheKey = 'dars.server_texts';

  /// Set from AppState with the app's language (like Money.arabic).
  static bool arabic = true;

  // Texts from the sign-in service and the network, not from our own database functions.
  static final _builtIn = <(RegExp, String)>[
    (RegExp(r'^Invalid login credentials$'), 'البريد أو كلمة المرور غير صحيحة'),
    (RegExp(r'^User already registered$'), 'هذا البريد مسجّل مسبقاً. سجّل الدخول بدلاً من ذلك'),
    (RegExp(r'^Email not confirmed$'), 'لم يتم تأكيد البريد بعد. افتح رسالة التأكيد في بريدك'),
    (RegExp(r'^Password should be at least (\d+) characters\.?$'), r'يجب ألا تقل كلمة المرور عن \1 أحرف'),
    (RegExp(r'^Unable to validate email address: invalid format$'), 'صيغة البريد الإلكتروني غير صحيحة'),
    (RegExp(r'rate limit', caseSensitive: false), 'محاولات كثيرة. حاول لاحقاً'),
    (RegExp(r'SocketException|Failed host lookup|ClientException|Connection (refused|reset|failed)|TimeoutException'),
        'تعذّر الاتصال بالخادم. تحقّق من الإنترنت وحاول مجدداً'),
  ];

  static void setRules(Iterable<Map<String, dynamic>> rows) {
    final out = <(RegExp, String)>[];
    for (final r in rows) {
      try {
        out.add((RegExp('^(?:${r['pattern']})\$', dotAll: true), '${r['ar']}'));
      } catch (_) {/* a pattern Dart can't read: skip it, the English shows */}
    }
    _rules = out;
  }

  static Future<void> loadCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_cacheKey);
      if (s != null) setRules((jsonDecode(s) as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  static Future<void> save(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    setRules(rows);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_cacheKey, jsonEncode(rows));
    } catch (_) {}
  }

  static String _fill(RegExpMatch m, String ar) =>
      ar.replaceAllMapped(RegExp(r'\\(\d)'), (x) {
        final i = int.parse(x[1]!);
        return i <= m.groupCount ? (m.group(i) ?? '') : '';
      });

  /// The Arabic for an English server text, or null when it isn't on the list.
  static String? ar(String en) {
    final t = en.trim();
    if (t.isEmpty) return null;
    for (final (re, ar) in _rules) {
      final m = re.firstMatch(t);
      if (m != null) return _fill(m, ar);
    }
    for (final (re, ar) in _builtIn) {
      final m = re.firstMatch(t);
      if (m != null) return re.pattern.startsWith('^') ? _fill(m, ar) : ar;
    }
    return null;
  }

  /// What to show: the Arabic when the app is in Arabic and the text is known, otherwise the text itself.
  static String show(String en) => arabic ? (ar(en) ?? en) : en;
}
