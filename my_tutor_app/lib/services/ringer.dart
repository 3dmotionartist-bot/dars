import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'ringer_web_stub.dart' if (dart.library.js_interop) 'ringer_web.dart' as web;

/// Rings the phone for incoming calls and shows message notifications.
/// Android: real system notification with the phone's ringtone + vibration (also on the lock screen).
/// Web app: a ringing tone in the tab + a browser notification.
class Ringer {
  static const _ch = MethodChannel('dars/ring');

  static Future<void> askPermission() async {
    try {
      if (kIsWeb) {
        web.askPermission();
      } else {
        await _ch.invokeMethod('askPermission');
      }
    } catch (_) {}
  }

  static Future<void> ring({required String title, required String body, required String joinLabel}) async {
    try {
      if (kIsWeb) {
        web.ring(title, body);
      } else {
        await _ch.invokeMethod('ring', {'title': title, 'body': body, 'join': joinLabel});
      }
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      if (kIsWeb) {
        web.stop();
      } else {
        await _ch.invokeMethod('stop');
      }
    } catch (_) {}
  }

  /// The call is over: on Android the app no longer shows over the lock screen.
  static Future<void> callEnded() async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod('callEnded');
    } catch (_) {}
  }

  static Future<void> notify({required String title, required String body}) async {
    try {
      if (kIsWeb) {
        web.notify(title, body);
      } else {
        await _ch.invokeMethod('notify', {'title': title, 'body': body});
      }
    } catch (_) {}
  }

  /// When the app was opened from the call notification: 'open' or 'join' (null otherwise).
  static Future<String?> takeLaunchAction() async {
    if (kIsWeb) return null;
    try {
      return await _ch.invokeMethod<String>('takeAction');
    } catch (_) {
      return null;
    }
  }
}
