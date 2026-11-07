import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

/// Voice & video calls run on a small web page (my_tutor_call/) that both people open.
/// The two phones connect directly (WebRTC); Supabase Realtime only passes the connection details.
class Calls {
  static final _rnd = Random.secure();

  /// A new, unguessable room id.
  static String newRoom() => List.generate(16, (_) => _rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  /// Chat invitation format stored in the message body: "video:<room>" or "voice:<room>".
  static String invite(String room, {required bool video}) => '${video ? 'video' : 'voice'}:$room';

  static ({bool video, String room})? parse(String body) {
    final m = RegExp(r'^(video|voice):([a-zA-Z0-9-]{8,64})$').firstMatch(body.trim());
    if (m == null) return null;
    return (video: m.group(1) == 'video', room: m.group(2)!);
  }

  static Uri link({required String room, required bool video, String peer = '', String name = '', String lang = 'ar'}) =>
      Uri.parse(DarsConfig.callPageUrl).replace(queryParameters: {
        'room': room,
        'video': video ? '1' : '0',
        'lang': lang,
        if (peer.isNotEmpty) 'peer': peer,
        if (name.isNotEmpty) 'name': name,
      });

  /// Opens the call in the phone's browser (a new tab on the web app). Returns false if it could not open.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    } catch (_) {
      return false;
    }
  }
}
