import 'page_reload_stub.dart' if (dart.library.js_interop) 'page_reload_web.dart' as impl;

/// Web app: reloads the page (to pick up a new version). Does nothing on Android.
void reloadPage() => impl.reloadPage();
