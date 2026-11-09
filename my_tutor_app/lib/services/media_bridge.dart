import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'media_bridge_stub.dart' if (dart.library.js_interop) 'media_bridge_web.dart' as web;

/// A finished voice recording.
class VoiceClip {
  final Uint8List bytes;
  final int ms;
  final String mime;
  final String ext;
  const VoiceClip(this.bytes, this.ms, this.mime, this.ext);
}

/// Voice notes (record / play), the Android screen-share service and meeting links opened from outside.
/// Android uses the app's own native code (MainActivity.kt); the web app uses the browser.
class MediaBridge {
  static const _ch = MethodChannel('dars/ring');

  /// 'ok', 'permission' (microphone not allowed yet) or 'error'.
  static Future<String> startRecording() async {
    try {
      if (kIsWeb) return await web.startRecording() ? 'ok' : 'permission';
      return (await _ch.invokeMethod<String>('recStart')) ?? 'error';
    } catch (_) {
      return 'error';
    }
  }

  static Future<VoiceClip?> stopRecording() async {
    try {
      if (kIsWeb) return await web.stopRecording();
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('recStop');
      if (r == null || r['bytes'] is! Uint8List) return null;
      return VoiceClip(r['bytes'] as Uint8List, (r['ms'] as num?)?.toInt() ?? 0, '${r['mime'] ?? 'audio/mp4'}', '${r['ext'] ?? 'm4a'}');
    } catch (_) {
      return null;
    }
  }

  static Future<void> cancelRecording() async {
    try {
      if (kIsWeb) {
        web.cancelRecording();
      } else {
        await _ch.invokeMethod('recCancel');
      }
    } catch (_) {}
  }

  /// Plays a voice note; returns its length in ms (0 = unknown, -1 = could not play).
  static Future<int> play(String url) async {
    try {
      if (kIsWeb) return await web.play(url);
      return (await _ch.invokeMethod<int>('play', {'url': url})) ?? -1;
    } catch (_) {
      return -1;
    }
  }

  static Future<void> stopPlaying() async {
    try {
      if (kIsWeb) {
        web.stopPlaying();
      } else {
        await _ch.invokeMethod('stopPlay');
      }
    } catch (_) {}
  }

  /// Android only: the visible service Android requires while the screen is shared.
  static Future<void> screenShareService(bool on) async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod(on ? 'shareStart' : 'shareStop');
    } catch (_) {}
  }

  /// A meeting link that opened the app (dars://join?room=… or the web app's ?join=…), once.
  static Future<Uri?> takeLaunchLink() async {
    try {
      if (kIsWeb) return web.takeLaunchLink();
      final s = await _ch.invokeMethod<String>('takeLink');
      return s == null ? null : Uri.tryParse(s);
    } catch (_) {
      return null;
    }
  }
}
