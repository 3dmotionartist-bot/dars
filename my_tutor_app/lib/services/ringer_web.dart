// Web app: ring tone (Web Audio) + browser notifications.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

const _setup = r'''
(function () {
  if (window.darsRinger) return;
  var ctx = null, timer = null, note = null;
  function beep() {
    try {
      ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
      if (ctx.state === 'suspended') ctx.resume();
      [0, 0.45].forEach(function (d) {
        var o = ctx.createOscillator(), g = ctx.createGain();
        o.type = 'sine'; o.frequency.value = 440; o.connect(g); g.connect(ctx.destination);
        var t = ctx.currentTime + d;
        g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.35, t + 0.03);
        g.gain.setValueAtTime(0.35, t + 0.35); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.4);
        o.start(t); o.stop(t + 0.42);
        var o2 = ctx.createOscillator(); o2.type = 'sine'; o2.frequency.value = 480; o2.connect(g); o2.start(t); o2.stop(t + 0.42);
      });
    } catch (e) {}
  }
  function show(title, body, tag, sticky) {
    try {
      if (!('Notification' in window) || Notification.permission !== 'granted') return null;
      var n = new Notification(title, { body: body, tag: tag, requireInteraction: !!sticky, renotify: true });
      n.onclick = function () { window.focus(); n.close(); };
      return n;
    } catch (e) { return null; }
  }
  window.darsRinger = {
    ask: function () { try { if ('Notification' in window && Notification.permission === 'default') Notification.requestPermission(); } catch (e) {} },
    ring: function (title, body) {
      window.darsRinger.stop();
      beep(); timer = setInterval(beep, 2500);
      setTimeout(window.darsRinger.stop, 45000);
      if (document.hidden) note = show(title, body, 'dars-call', true);
    },
    stop: function () { if (timer) clearInterval(timer); timer = null; if (note) { try { note.close(); } catch (e) {} note = null; } },
    notify: function (title, body) { if (document.hidden) show(title, body, 'dars-msg', false); }
  };
})();
''';

JSObject? _ringer() {
  try {
    if (!globalContext.has('darsRinger')) globalContext.callMethod<JSAny?>('eval'.toJS, _setup.toJS);
    return globalContext['darsRinger'] as JSObject?;
  } catch (_) {
    return null;
  }
}

void askPermission() {
  _ringer()?.callMethod<JSAny?>('ask'.toJS);
}

void ring(String title, String body) {
  _ringer()?.callMethod<JSAny?>('ring'.toJS, title.toJS, body.toJS);
}

void stop() {
  _ringer()?.callMethod<JSAny?>('stop'.toJS);
}

void notify(String title, String body) {
  _ringer()?.callMethod<JSAny?>('notify'.toJS, title.toJS, body.toJS);
}
