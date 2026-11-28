import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One file per account in the app's private folder (other apps cannot read it). Removed at sign-out.
class ChatCache {
  static Future<File> _file(String uid) async {
    final dir = await getApplicationSupportDirectory();
    final safe = uid.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
    return File('${dir.path}/dars_chats_$safe.json');
  }

  static Future<void> save(String uid, Map<String, dynamic> data) async {
    try {
      final f = await _file(uid);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({'v': 1, 'saved': DateTime.now().toUtc().toIso8601String(), ...data}), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> read(String uid) async {
    try {
      final f = await _file(uid);
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString());
      return m is Map<String, dynamic> && m['v'] == 1 ? m : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final dir = await getApplicationSupportDirectory();
      for (final e in dir.listSync()) {
        if (e is File && e.path.contains('dars_chats_')) await e.delete();
      }
    } catch (_) {}
  }
}
