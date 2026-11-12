// Web app: reload the page.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void reloadPage() {
  try {
    (globalContext['location'] as JSObject?)?.callMethod<JSAny?>('reload'.toJS);
  } catch (_) {}
}
