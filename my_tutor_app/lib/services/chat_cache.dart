// Round G3: the last chats and messages, kept on the phone so they still show when Dars starts offline.
// The web keeps nothing (the browser has its own cache and the page needs the network anyway).
export 'chat_cache_stub.dart' if (dart.library.io) 'chat_cache_io.dart';
