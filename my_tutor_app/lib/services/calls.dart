import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

/// Voice & video calls run on a small web page (my_tutor_call/) that both people open.
/// The two phones connect directly (WebRTC); Supabase Realtime only passes the connection details.
class Calls {
  static final _rnd = Random.secure();

  static const _letters = 'abcdefghjkmnpqrstuvwxyz';

  /// A new, unguessable room id like "kqzpt-mwhra-bcdeg-xyzab" (letters only, so a pasted link is
  /// never mistaken for a phone number by the chat filter).
  static String newRoom() => List.generate(4, (_) => List.generate(5, (_) => _letters[_rnd.nextInt(_letters.length)]).join()).join('-');

  /// Chat invitation format stored in the message body: "video:<room>", "voice:<room>" (a call that rings)
  /// or "meet:<room>" (a meeting link anyone in the chat can join any time).
  static String invite(String room, {required bool video}) => '${video ? 'video' : 'voice'}:$room';
  static String meeting(String room) => 'meet:$room';

  static ({bool video, bool meet, String room})? parse(String body) {
    final m = RegExp(r'^(video|voice|meet):([a-zA-Z0-9-]{8,64})$').firstMatch(body.trim());
    if (m == null) return null;
    final kind = m.group(1)!;
    return (video: kind != 'voice', meet: kind == 'meet', room: m.group(2)!);
  }

  /// A clean link to share anywhere (no names inside).
  static String shareLink(String room, {bool video = true}) =>
      Uri.parse(DarsConfig.callPageUrl).replace(queryParameters: {'room': room, 'video': video ? '1' : '0'}).toString();

  /// Finds a Dars meeting link inside any text (so pasted links open as calls).
  static ({bool video, String room})? fromUrl(String text) {
    final m = RegExp(r'https?://\S+/call/?\?\S*').firstMatch(text);
    if (m == null) return null;
    final u = Uri.tryParse(m.group(0)!);
    final room = u?.queryParameters['room'] ?? '';
    if (!RegExp(r'^[a-zA-Z0-9-]{8,64}$').hasMatch(room)) return null;
    return (video: u!.queryParameters['video'] != '0', room: room);
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
