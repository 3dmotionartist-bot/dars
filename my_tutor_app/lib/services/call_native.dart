import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Round D (D2): the Android side of a call — one "call in progress" service for the whole call (so the
/// microphone keeps working when the person leaves the app or shares the screen), the screen kept on, and
/// the proximity sensor on voice calls. Does nothing on the web app.
class CallNative {
  static const _ch = MethodChannel('dars/ring');

  /// Set by the open call screen: the "Hang up" button in the call notification was tapped.
  static void Function()? onHangUp;

  /// Set by AppState: a push said "incoming call" while the app was open (in case live updates missed it).
  static void Function(Map<String, dynamic> call)? onIncomingCall;

  /// Set by AppState: "Decline" was tapped in the ringing notification (the caller was told already).
  static void Function(String room)? onDeclined;

  static bool _handler = false;

  /// Listens for messages from the Android side (once).
  static void listen() {
    if (kIsWeb || _handler) return;
    _handler = true;
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'hangUp':
          onHangUp?.call();
        case 'incomingCall':
          final call0 = call.arguments;
          if (call0 is Map) onIncomingCall?.call(Map<String, dynamic>.from(call0));
        case 'callDeclined':
          final declined = call.arguments;
          if (declined is Map) onDeclined?.call('${declined['room'] ?? ''}');
      }
      return null;
    });
  }

  /// The call started ([on] true) or ended: starts / stops the call service and keeps the screen on.
  static Future<void> active(bool on, {bool video = false, String title = '', String text = '', String hangUp = ''}) async {
    if (kIsWeb) return;
    listen();
    try {
      await _ch.invokeMethod('callActive', {'on': on, 'video': video, 'title': title, 'text': text, 'hangUp': hangUp});
    } catch (_) {}
  }

  /// Screen sharing on / off. Returns true once Android is ready to capture the screen (the call service
  /// runs as "screen capture"), waiting up to 3 seconds for slow phones.
  static Future<bool> share(bool on) async {
    if (kIsWeb) return true;
    try {
      final r = await _ch.invokeMethod<bool>('callShare', {'on': on});
      if (!on || r == true) return true;
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (await _ch.invokeMethod<bool>('callShareReady') == true) return true;
      }
    } catch (_) {}
    return false;
  }

  /// Voice calls on the earpiece: the screen turns off when the phone is held to the ear.
  static Future<void> proximity(bool on) async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod('proximity', {'on': on});
    } catch (_) {}
  }
}
