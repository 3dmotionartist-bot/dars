import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'call_logic.dart' show CallSetup;
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

  /// Android 14+: can an incoming call fill the locked screen? (Phones and Xiaomi dual apps can switch this
  /// off; then calls only show a small banner.) Always true elsewhere.
  static Future<bool> fullScreenOk() async {
    if (kIsWeb) return true;
    try {
      return await _ch.invokeMethod<bool>('fullScreenOk') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Xiaomi / Redmi / POCO phone: calls on the lock screen need Xiaomi's own "Show on lock screen" permission.
  static Future<bool> isXiaomi() async {
    if (kIsWeb) return false;
    try {
      return await _ch.invokeMethod<bool>('isXiaomi') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the phone's settings page where full-screen call alerts are turned on for Dars.
  static Future<void> openFullScreenSettings() async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod('openFullScreenSettings');
    } catch (_) {}
  }

  /// What this phone still needs so calls ring while it sleeps (Android only; null elsewhere or unknown).
  static Future<CallSetup?> callSetup() async {
    if (kIsWeb) return null;
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('callSetup');
      return m == null ? null : CallSetup.fromMap(m);
    } catch (_) {
      return null;
    }
  }

  /// Opens the phone's settings page for one step of [CallSetup].
  static Future<void> openSetup(String step) async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod('openSetup', {'step': step});
    } catch (_) {}
  }

  /// A "Missed call" in the phone's notification bar (Android; same notification as the missed-call push).
  static Future<void> missedCall({required String title, required String body, required String conversationId}) async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod('missedCall', {'title': title, 'body': body, 'conversation_id': conversationId});
    } catch (_) {}
  }

  /// [room] / [video] / [conversationId] go into the Android notification, so "Join" / "Decline" there work
  /// even after the app was put away (Round D).
  static Future<void> ring({
    required String title,
    required String body,
    required String joinLabel,
    String declineLabel = '',
    String room = '',
    bool video = true,
    String conversationId = '',
  }) async {
    try {
      if (kIsWeb) {
        web.ring(title, body);
      } else {
        await _ch.invokeMethod('ring', {
          'title': title,
          'body': body,
          'join': joinLabel,
          'decline': declineLabel,
          'room': room,
          'video': '$video',
          'conversation_id': conversationId,
        });
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

  /// When the app was opened from a ringing notification that carries the call (push, Round D):
  /// {action: 'open' | 'join', room, video, name, conversation_id, sent_at}; null otherwise.
  static Future<Map<String, String>?> takeLaunchCall() async {
    if (kIsWeb) return null;
    try {
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('takeCall');
      return r?.map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return null;
    }
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
