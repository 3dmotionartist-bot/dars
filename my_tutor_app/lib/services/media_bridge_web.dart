// Web app: voice notes with the browser's MediaRecorder / Audio, meeting links from the page address.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'media_bridge.dart';

const _setup = r'''
(function () {
  if (window.darsMedia) return;
  window.darsMedia = {
    rec: null, stream: null, chunks: [], t0: 0, mime: '', audio: null,
    start: async function () {
      try {
        var s = await navigator.mediaDevices.getUserMedia({ audio: true });
        var types = ['audio/webm;codecs=opus', 'audio/mp4', 'audio/webm', 'audio/ogg;codecs=opus'];
        var m = '';
        for (var i = 0; i < types.length; i++) { if (window.MediaRecorder && MediaRecorder.isTypeSupported(types[i])) { m = types[i]; break; } }
        var r = new MediaRecorder(s, m ? { mimeType: m } : undefined);
        var self = this; self.chunks = [];
        r.ondataavailable = function (e) { if (e.data && e.data.size) self.chunks.push(e.data); };
        r.start(250);
        self.rec = r; self.stream = s; self.t0 = Date.now(); self.mime = r.mimeType || m || 'audio/webm';
        return true;
      } catch (e) { return false; }
    },
    stop: function () {
      var self = this;
      return new Promise(function (res) {
        var r = self.rec;
        if (!r) { res(null); return; }
        r.onstop = async function () {
          try {
            var blob = new Blob(self.chunks, { type: self.mime });
            if (self.stream) self.stream.getTracks().forEach(function (t) { t.stop(); });
            self.rec = null; self.stream = null;
            var buf = await blob.arrayBuffer();
            res({ bytes: new Uint8Array(buf), ms: Date.now() - self.t0, mime: self.mime.split(';')[0], ext: self.mime.indexOf('mp4') >= 0 ? 'm4a' : (self.mime.indexOf('ogg') >= 0 ? 'ogg' : 'webm') });
          } catch (e) { res(null); }
        };
        try { r.stop(); } catch (e) { res(null); }
      });
    },
    cancel: function () {
      try { if (this.rec) { this.rec.onstop = null; this.rec.stop(); } } catch (e) {}
      if (this.stream) this.stream.getTracks().forEach(function (t) { t.stop(); });
      this.rec = null; this.stream = null; this.chunks = [];
    },
    play: function (url) {
      var self = this;
      return new Promise(function (res) {
        try {
          if (self.audio) { self.audio.pause(); }
          var a = new Audio(url); self.audio = a;
          var done = false;
          a.onloadedmetadata = function () { if (!done) { done = true; res(isFinite(a.duration) ? Math.round(a.duration * 1000) : 0); } };
          a.onerror = function () { if (!done) { done = true; res(-1); } };
          a.play().catch(function () { if (!done) { done = true; res(-1); } });
        } catch (e) { res(-1); }
      });
    },
    stopPlay: function () { if (this.audio) { this.audio.pause(); this.audio = null; } }
  };
})();
''';

JSObject? _media() {
  try {
    if (!globalContext.has('darsMedia')) globalContext.callMethod<JSAny?>('eval'.toJS, _setup.toJS);
    return globalContext['darsMedia'] as JSObject?;
  } catch (_) {
    return null;
  }
}

Future<bool> startRecording() async {
  final m = _media();
  if (m == null) return false;
  final r = await m.callMethod<JSPromise<JSAny?>>('start'.toJS).toDart;
  return r.dartify() == true;
}

Future<VoiceClip?> stopRecording() async {
  final m = _media();
  if (m == null) return null;
  final r = await m.callMethod<JSPromise<JSAny?>>('stop'.toJS).toDart;
  if (r.isUndefinedOrNull) return null;
  final o = r as JSObject;
  final bytes = o.getProperty<JSUint8Array>('bytes'.toJS).toDart;
  final ms = o.getProperty<JSNumber>('ms'.toJS).toDartInt;
  final mime = o.getProperty<JSString>('mime'.toJS).toDart;
  final ext = o.getProperty<JSString>('ext'.toJS).toDart;
  return VoiceClip(bytes, ms, mime, ext);
}

void cancelRecording() {
  _media()?.callMethod<JSAny?>('cancel'.toJS);
}

Future<int> play(String url) async {
  final m = _media();
  if (m == null) return -1;
  final r = await m.callMethod<JSPromise<JSAny?>>('play'.toJS, url.toJS).toDart;
  final v = r.dartify();
  return v is num ? v.toInt() : -1;
}

void stopPlaying() {
  _media()?.callMethod<JSAny?>('stopPlay'.toJS);
}

bool _linkTaken = false;

/// The web app opened with ?join=<room>&video=1 (from a shared meeting link).
Uri? takeLaunchLink() {
  if (_linkTaken) return null;
  _linkTaken = true;
  final q = Uri.base.queryParameters;
  final room = q['join'] ?? '';
  if (room.isEmpty) return null;
  return Uri(scheme: 'dars', host: 'join', queryParameters: {'room': room, 'video': q['video'] ?? '1'});
}
