import 'dart:async';

import 'package:flutter/foundation.dart';

/// Round H2: app errors go to the server (table app_errors, read by admins only), so problems on users'
/// phones are seen without an outside service. Only the error text and where in the code it happened are
/// sent — numbers, e-mails and links are blanked out first, and network trouble (offline) is not reported.
class CrashReport {
  /// Set by the app once the server is ready (nothing is sent before that, or in demo mode).
  static Future<void> Function(Map<String, dynamic> params)? send;
  static int build = 0;
  static final Set<String> _sent = {};
  static int _count = 0;

  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      previous?.call(d);
      report(d.exception, d.stack, context: 'flutter');
    };
    PlatformDispatcher.instance.onError = (e, s) {
      debugPrint('Unhandled: $e');
      report(e, s, context: 'async');
      return true;
    };
  }

  static void report(Object error, StackTrace? stack, {String context = ''}) {
    final msg = crashMessage('$error');
    if (msg.isEmpty || isNetworkTrouble(msg)) return;
    if (!_sent.add(msg) || ++_count > 20) return; // once per error, at most 20 per app start
    final f = send;
    if (f == null) return;
    try {
      unawaited(f({
        'p_message': msg,
        'p_stack': crashStack(stack),
        'p_build': build,
        'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'p_context': context,
      }).catchError((_) {}));
    } catch (_) {}
  }
}

/// The error text without personal details: e-mails, links and long numbers (phones, ids) are blanked out.
String crashMessage(String s) {
  var t = s.trim();
  t = t.replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), '<email>');
  t = t.replaceAll(RegExp(r'https?://\S+'), '<link>');
  t = t.replaceAll(RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'), '<id>');
  t = t.replaceAll(RegExp(r'\+?\d[\d\s-]{6,}\d'), '<number>');
  return t.length > 1000 ? t.substring(0, 1000) : t;
}

/// Offline / server-unreachable errors are not bugs in the app.
bool isNetworkTrouble(String msg) => RegExp(
      r'SocketException|ClientException|Failed host lookup|Connection (closed|reset|refused)|TimeoutException|'
      r'HandshakeException|AuthRetryableFetchException|Network is unreachable|XMLHttpRequest error|Failed to fetch',
      caseSensitive: false,
    ).hasMatch(msg);

/// The first lines of where it happened (enough to find the place in the code).
String crashStack(StackTrace? s) {
  if (s == null) return '';
  final lines = s.toString().split('\n').where((l) => l.trim().isNotEmpty).take(25).join('\n');
  return lines.length > 4000 ? lines.substring(0, 4000) : lines;
}
