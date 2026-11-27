import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_compress/video_compress.dart';

/// Round G2: makes a chat video smaller before it is sent (Android only; the web sends the original).
class VideoShrink {
  /// Videos smaller than this are sent as they are.
  static const minBytes = 6 * 1024 * 1024;

  static bool get available => !kIsWeb;

  /// Shrinks the video at [path]; [onProgress] gets 0..1. Returns the new file's path, or null when
  /// shrinking failed, was cancelled, or did not make the file smaller.
  static Future<String?> shrink(String path, int originalBytes, void Function(double) onProgress) async {
    if (!available) return null;
    final sub = VideoCompress.compressProgress$.subscribe((p) => onProgress((p / 100).clamp(0.0, 1.0)));
    try {
      final info = await VideoCompress.compressVideo(path, quality: VideoQuality.MediumQuality, includeAudio: true);
      final out = info?.path;
      final size = info?.filesize ?? 0;
      if (info == null || info.isCancel == true || out == null || size <= 0 || size >= originalBytes) return null;
      return out;
    } catch (_) {
      return null;
    } finally {
      sub.unsubscribe();
    }
  }

  static Future<void> cancel() async {
    try {
      await VideoCompress.cancelCompression();
    } catch (_) {}
  }
}
