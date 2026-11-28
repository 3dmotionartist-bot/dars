import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads a chat document into the app's cache and opens it in a viewer app (PDF reader, Word, ...).
/// False when it could not be downloaded or no app opens it — the caller then opens the link.
Future<bool> openDocument(String url, String fileName, String mime) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$fileName');
  if (!await f.exists() || await f.length() == 0) {
    final client = HttpClient();
    try {
      final res = await (await client.getUrl(Uri.parse(url))).close();
      if (res.statusCode != 200) return false;
      await res.pipe(f.openWrite());
    } finally {
      client.close();
    }
  }
  final r = await OpenFilex.open(f.path, type: mime);
  return r.type == ResultType.done;
}
