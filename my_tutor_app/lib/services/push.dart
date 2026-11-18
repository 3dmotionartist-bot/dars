import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Round D (D1): push notifications on Android (Firebase Cloud Messaging, shown by the app's own code in
/// DarsMessagingService.kt). The web app has none and keeps its in-tab notifications.
class Push {
  static const _ch = MethodChannel('dars/ring');

  /// This phone's push token, or null (web app, Firebase not set up in this build, no Google services).
  static Future<String?> token() async {
    if (kIsWeb) return null;
    try {
      final t = await _ch.invokeMethod<String>('pushToken').timeout(const Duration(seconds: 15));
      return (t == null || t.length < 20) ? null : t;
    } catch (_) {
      return null;
    }
  }

  /// What a tapped notification asked to open, once: {'open': 'chat', 'conversation_id': …} or
  /// {'open': 'notifications'}; null if the app was not opened from a notification.
  static Future<Map<String, String>?> takeOpen() async {
    if (kIsWeb) return null;
    try {
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('takeOpen');
      return r == null ? null : r.map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return null;
    }
  }

  /// The chat is open on screen: remove its notification (and the lines collected in it).
  static Future<void> clearChat(String conversationId) async {
    if (kIsWeb || conversationId.isEmpty) return;
    try {
      await _ch.invokeMethod('clearChat', {'conversation_id': conversationId});
    } catch (_) {}
  }

  /// The server address and public key, so "Decline" in a ringing notification can tell the caller even
  /// while the app is closed, and whether this phone shows message notices itself.
  static Future<void> setBackend({required String url, required String key, required String lang}) async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod('setBackend', {'url': url, 'key': key, 'lang': lang});
    } catch (_) {}
  }
}
