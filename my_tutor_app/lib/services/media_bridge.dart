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

  /// The phone's processor types, best first (e.g. ['arm64-v8a', 'armeabi-v7a']); empty if unknown.
  static Future<List<String>> supportedAbis() async {
    if (kIsWeb) return const [];
    try {
      final r = await _ch.invokeListMethod<String>('abis');
      return r ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// The installed app's version number (1xxx arm32, 2xxx arm64, 3xxx all-phones file); 0 if unknown.
  static Future<int> installedVersionCode() async {
    if (kIsWeb) return 0;
    try {
      final r = await _ch.invokeMethod<int>('versionCode');
      return r ?? 0;
    } catch (_) {
      return 0;
    }
  }

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

  /// Round G2: where the playing voice note is ([position, length] in ms), or null when nothing plays.
  static Future<List<int>?> position() async {
    try {
      if (kIsWeb) return web.position();
      final r = await _ch.invokeListMethod<int>('playPos');
      return r == null || r.length < 2 || r[0] < 0 ? null : r;
    } catch (_) {
      return null;
    }
  }

  /// Round G2: jumps the playing voice note to [ms].
  static Future<void> seek(int ms) async {
    try {
      if (kIsWeb) return web.seek(ms);
      await _ch.invokeMethod('playSeek', {'ms': ms});
    } catch (_) {}
  }

  /// Round G2: plays the voice note faster (1, 1.5 or 2).
  static Future<void> speed(double rate) async {
    try {
      if (kIsWeb) return web.speed(rate);
      await _ch.invokeMethod('playSpeed', {'rate': rate});
    } catch (_) {}
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
