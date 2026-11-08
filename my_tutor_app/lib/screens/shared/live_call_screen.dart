import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase/supabase.dart' show RealtimeChannel, RealtimeSubscribeStatus;

import '../../data/backend.dart';
import '../../l10n.dart';
import '../../theme.dart';

/// Real voice / video call inside the app (Android and web app).
///
/// Both people open the same "room". They find each other through Supabase Realtime
/// (hello / offer / answer / ice / bye messages) and then talk directly with WebRTC.
/// When a direct route is impossible (most mobile networks), the TURN relay set in the
/// admin dashboard carries the call. The browser call page (my_tutor_call/) speaks the same protocol.
class LiveCallScreen extends StatefulWidget {
  const LiveCallScreen({super.key, required this.room, required this.video, this.peerName = '', this.myName = '', this.testMode = false});

  final String room;
  final bool testMode;
  final bool video;
  final String peerName;
  final String myName;

  @override
  State<LiveCallScreen> createState() => _LiveCallScreenState();
}

enum _Phase { starting, waiting, connecting, connected, reconnecting, failed, noAnswer, denied, offline, full, ended }

class _LiveCallScreenState extends State<LiveCallScreen> {
  static const _ringSeconds = 60;
  static const _connectSeconds = 25;

  final _me = _newId();
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();

  RealtimeChannel? _ch;
  RTCPeerConnection? _pc;
  MediaStream? _stream;
  List<Map<String, dynamic>> _ice = const [];
  bool _hasRelay = false;

  String? _peer;
  String _peerName = '';
  int _peerSeen = 0;
  final _joinedAt = DateTime.now().millisecondsSinceEpoch;
  bool _remoteSet = false;
  final List<RTCIceCandidate> _pendingIce = [];

  _Phase _phase = _Phase.starting;
  bool _micOn = true;
  bool _camOn = true;
  bool _speaker = true;
  bool _remoteVideo = false;
  bool _closing = false;
  DateTime? _connectedAt;

  // connection diagnostics (shown small at the bottom of the call screen)
  int _sent = 0;
  int _heard = 0;
  String _chStatus = '…';
  String _lastError = '';

  Timer? _hello;
  Timer? _ring;
  Timer? _connectTimer;
  Timer? _clock;

  static String _newId() {
    final r = Random.secure();
    return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  @override
  void initState() {
    super.initState();
    _peerName = widget.peerName;
    _speaker = widget.video;
    _start();
  }

  // ------------------------------------------------------------------ setup
  Future<void> _start() async {
    await Backend.I.init();
    await _local.initialize();
    await _remote.initialize();
    try {
      _stream = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
        'video': widget.video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      });
    } catch (e) {
      _lastError = 'media: $e';
      if (!widget.testMode) {
        _set(_Phase.denied);
        return;
      }
    }
    if (!mounted) return _cleanup();
    _local.srcObject = _stream;
    if (!kIsWeb) {
      try {
        await Helper.setSpeakerphoneOn(_speaker);
      } catch (_) {}
    }
    _ice = await Backend.I.iceServers();
    _hasRelay = _ice.any((s) => '${s['urls']}'.contains('turn'));
    await _newPeer();
    _join();
    _ring = Timer(const Duration(seconds: _ringSeconds), () {
      if (_peer == null && _phase == _Phase.waiting) _set(_Phase.noAnswer);
    });
  }

  Future<void> _newPeer() async {
    final old = _pc;
    _pc = null;
    if (old != null) {
      try {
        await old.close();
      } catch (_) {}
    }
    _remoteSet = false;
    _pendingIce.clear();
    final pc = await createPeerConnection({'iceServers': _ice, 'sdpSemantics': 'unified-plan'});
    for (final t in _stream?.getTracks() ?? const <MediaStreamTrack>[]) {
      await pc.addTrack(t, _stream!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null || _peer == null) return;
      _send('ice', {
        'to': _peer,
        'candidate': {'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex},
      });
    };
    pc.onTrack = (e) {
      if (e.streams.isEmpty) return;
      _remote.srcObject = e.streams.first;
      if (e.track.kind == 'video') _remoteVideo = true;
      if (mounted) setState(() {});
    };
    pc.onConnectionState = (s) {
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _onConnected();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          if (_phase == _Phase.connected) _set(_Phase.reconnecting);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _onFailed();
          break;
        default:
          break;
      }
    };
    _pc = pc;
  }

  void _join() {
    final ch = Backend.I.callChannel(widget.room);
    _ch = ch;
    ch
        .onBroadcast(event: 'hello', callback: (m) {
          _heard++;
          _onHello(_body(m));
        })
        .onBroadcast(event: 'offer', callback: (m) => _onOffer(_body(m)))
        .onBroadcast(event: 'answer', callback: (m) => _onAnswer(_body(m)))
        .onBroadcast(event: 'ice', callback: (m) => _onIce(_body(m)))
        .onBroadcast(event: 'busy', callback: (m) => _onBusy(_body(m)))
        .onBroadcast(event: 'bye', callback: (m) => _onBye(_body(m)))
        .subscribe((status, err) {
      _chStatus = status.name;
      if (err != null) _lastError = '$err';
      if (mounted) setState(() {});
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (_phase == _Phase.starting) _set(_Phase.waiting);
        _sayHello();
        _hello?.cancel();
        _hello = Timer.periodic(const Duration(seconds: 3), (_) {
          if (_phase != _Phase.connected || DateTime.now().second % 12 < 3) _sayHello();
          _checkPeerGone();
        });
      } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        if (_peer == null) _set(_Phase.offline);
      }
    });
  }

  /// Broadcasts arrive either as the bare payload or wrapped in {type, event, payload}.
  static Map<String, dynamic> _body(Map<String, dynamic> m) {
    final inner = m['payload'];
    return inner is Map ? Map<String, dynamic>.from(inner) : m;
  }

  Future<void> _send(String event, Map<String, dynamic> payload) async {
    final ch = _ch;
    if (ch == null) return;
    try {
      // Same message shape as the web call page: {type, event, payload: {...}}.
      final r = await ch.sendBroadcastMessage(event: event, payload: {
        'payload': {'from': _me, ...payload},
      });
      _sent++;
      if ('$r' != 'ChannelResponse.ok') _lastError = 'send: $r';
    } catch (e) {
      _lastError = 'send: $e';
    }
  }

  void _sayHello() {
    _send('hello', {'name': widget.myName, 'video': widget.video, 'at': _joinedAt});
  }

  // ------------------------------------------------------------------ signaling
  void _onHello(Map<String, dynamic> p) {
    final from = '${p['from'] ?? ''}';
    if (from.isEmpty || from == _me || _closing) return;
    if (_peer != null && from != _peer) {
      _send('busy', {'to': from}); // two people per call
      return;
    }
    _peerSeen = DateTime.now().millisecondsSinceEpoch;
    final n = '${p['name'] ?? ''}'.trim();
    if (n.isNotEmpty && _peerName.isEmpty) _peerName = n;
    if (_peer == from) return;
    _peer = from;
    _ring?.cancel();
    _sayHello(); // let them know about me right away
    _set(_Phase.connecting);
    _armConnectTimer();
    if (_me.compareTo(from) < 0) _makeOffer(); // exactly one side starts
  }

  Future<void> _makeOffer({bool restart = false}) async {
    final pc = _pc;
    if (pc == null || _peer == null) return;
    try {
      final offer = await pc.createOffer({if (restart) 'iceRestart': true});
      await pc.setLocalDescription(offer);
      _send('offer', {
        'to': _peer,
        'sdp': {'type': offer.type, 'sdp': offer.sdp},
      });
    } catch (_) {}
  }

  Future<void> _onOffer(Map<String, dynamic> p) async {
    if (p['to'] != _me || _closing) return;
    final from = '${p['from']}';
    if (_peer != null && _peer != from) {
      // The other person rejoined with a new id: start fresh with them.
      await _newPeer();
    }
    _peer = from;
    _peerSeen = DateTime.now().millisecondsSinceEpoch;
    _ring?.cancel();
    if (_phase != _Phase.connected) _set(_Phase.connecting);
    _armConnectTimer();
    final pc = _pc;
    final sdp = p['sdp'];
    if (pc == null || sdp is! Map) return;
    try {
      await pc.setRemoteDescription(RTCSessionDescription('${sdp['sdp']}', '${sdp['type']}'));
      _remoteSet = true;
      await _flushIce();
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _send('answer', {
        'to': from,
        'sdp': {'type': answer.type, 'sdp': answer.sdp},
      });
    } catch (_) {}
  }

  Future<void> _onAnswer(Map<String, dynamic> p) async {
    if (p['to'] != _me || p['from'] != _peer) return;
    final pc = _pc;
    final sdp = p['sdp'];
    if (pc == null || sdp is! Map) return;
    try {
      await pc.setRemoteDescription(RTCSessionDescription('${sdp['sdp']}', '${sdp['type']}'));
      _remoteSet = true;
      await _flushIce();
    } catch (_) {}
  }

  Future<void> _onIce(Map<String, dynamic> p) async {
    if (p['to'] != _me) return;
    final c = p['candidate'];
    if (c is! Map || c['candidate'] == null) return;
    final cand = RTCIceCandidate('${c['candidate']}', c['sdpMid'] as String?, (c['sdpMLineIndex'] as num?)?.toInt());
    if (!_remoteSet) {
      _pendingIce.add(cand);
      return;
    }
    try {
      await _pc?.addCandidate(cand);
    } catch (_) {}
  }

  Future<void> _flushIce() async {
    final list = List<RTCIceCandidate>.from(_pendingIce);
    _pendingIce.clear();
    for (final c in list) {
      try {
        await _pc?.addCandidate(c);
      } catch (_) {}
    }
  }

  void _onBusy(Map<String, dynamic> p) {
    if (p['to'] == _me && _peer == null) _set(_Phase.full);
  }

  void _onBye(Map<String, dynamic> p) {
    if (p['from'] != _peer) return;
    _peerLeft();
  }

  void _checkPeerGone() {
    if (_peer == null || _phase == _Phase.connected) return;
    if (DateTime.now().millisecondsSinceEpoch - _peerSeen > 20000) _peerLeft();
  }

  Future<void> _peerLeft() async {
    _peer = null;
    _remoteVideo = false;
    _connectedAt = null;
    _clock?.cancel();
    _clock = null;
    _connectTimer?.cancel();
    _remote.srcObject = null;
    await _newPeer();
    _set(_Phase.waiting);
  }

  void _armConnectTimer() {
    _connectTimer?.cancel();
    _connectTimer = Timer(const Duration(seconds: _connectSeconds), () {
      if (_phase == _Phase.connecting) _onFailed();
    });
  }

  int _restarts = 0;
  void _onFailed() {
    if (_closing) return;
    if (_restarts < 2 && _peer != null) {
      _restarts++;
      _set(_Phase.reconnecting);
      _armConnectTimer();
      if (_me.compareTo(_peer!) < 0) _makeOffer(restart: true);
      return;
    }
    _set(_Phase.failed);
  }

  void _onConnected() {
    _connectTimer?.cancel();
    _restarts = 0;
    _connectedAt ??= DateTime.now();
    _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _set(_Phase.connected);
  }

  void _set(_Phase p) {
    if (!mounted || _phase == _Phase.ended) return;
    setState(() => _phase = p);
  }

  // ------------------------------------------------------------------ controls
  void _toggleMic() {
    final a = _stream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (a.isEmpty) return;
    _micOn = !_micOn;
    for (final t in a) {
      t.enabled = _micOn;
    }
    setState(() {});
  }

  void _toggleCam() {
    final v = _stream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (v.isEmpty) return;
    _camOn = !_camOn;
    for (final t in v) {
      t.enabled = _camOn;
    }
    setState(() {});
  }

  Future<void> _flip() async {
    final v = _stream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (v.isEmpty) return;
    try {
      await Helper.switchCamera(v.first);
    } catch (_) {}
  }

  Future<void> _toggleSpeaker() async {
    _speaker = !_speaker;
    try {
      await Helper.setSpeakerphoneOn(_speaker);
    } catch (_) {}
    setState(() {});
  }

  Future<void> _hangUp() async {
    if (_closing) return;
    _closing = true;
    _send('bye', {});
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _cleanup() async {
    _hello?.cancel();
    _ring?.cancel();
    _connectTimer?.cancel();
    _clock?.cancel();
    final ch = _ch;
    _ch = null;
    if (ch != null) Backend.I.closeChannel(ch);
    try {
      await _pc?.close();
    } catch (_) {}
    for (final t in _stream?.getTracks() ?? const <MediaStreamTrack>[]) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await _stream?.dispose();
    } catch (_) {}
    _local.srcObject = null;
    _remote.srcObject = null;
    await _local.dispose();
    await _remote.dispose();
    if (!kIsWeb) {
      try {
        await Helper.setSpeakerphoneOn(false);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    if (!_closing) _send('bye', {});
    _closing = true;
    _phase = _Phase.ended;
    _cleanup();
    super.dispose();
  }

  // ------------------------------------------------------------------ UI
  String _status(BuildContext context) {
    final ar = context.isAr;
    String t(String a, String e) => ar ? a : e;
    switch (_phase) {
      case _Phase.starting:
        return t('جارٍ التحضير…', 'Getting ready…');
      case _Phase.waiting:
        return t('بانتظار انضمام الطرف الآخر…', 'Waiting for the other person to join…');
      case _Phase.connecting:
        return t('جارٍ الاتصال…', 'Connecting…');
      case _Phase.reconnecting:
        return t('جارٍ إعادة الاتصال…', 'Reconnecting…');
      case _Phase.connected:
        final s = DateTime.now().difference(_connectedAt ?? DateTime.now()).inSeconds;
        return '${t('متصل', 'Connected')} · ${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
      case _Phase.noAnswer:
        return t('لا يوجد رد — لم ينضم الطرف الآخر.', 'No answer — the other person did not join.');
      case _Phase.failed:
        return _hasRelay
            ? t('تعذّر الاتصال على هذه الشبكة. جرّب واي فاي أو بيانات أخرى.', 'Could not connect on this network. Try Wi-Fi or other data.')
            : t('الطرفان متصلان لكن الشبكة تمنع الاتصال المباشر. أضف خادم ترحيل (TURN) من لوحة التحكم ← الإعدادات.',
                'Both sides joined, but the network blocks a direct connection. Add a call relay (TURN) in the dashboard → Settings.');
      case _Phase.denied:
        return t('اسمح للتطبيق باستخدام الكاميرا والميكروفون من الإعدادات ثم حاول مجدداً.',
            'Allow camera and microphone for the app in Settings, then try again.');
      case _Phase.offline:
        return t('تعذّر الوصول لخادم المكالمات. تحقّق من الإنترنت.', 'Could not reach the call server. Check your internet.');
      case _Phase.full:
        return t('المكالمة ممتلئة (شخصان فقط).', 'This call is full (two people only).');
      case _Phase.ended:
        return t('انتهت المكالمة', 'Call ended');
    }
    // ignore: dead_code
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final showRemote = widget.video && _remoteVideo && _phase == _Phase.connected;
    final name = _peerName.isEmpty ? context.tr(widget.video ? 'video_call' : 'voice_call') : _peerName;
    final bad = const {_Phase.noAnswer, _Phase.failed, _Phase.denied, _Phase.offline, _Phase.full}.contains(_phase);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_closing) {
          _closing = true;
          _send('bye', {});
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: Stack(
          children: [
            // remote video (or audio-only renderer, kept tiny so the web app still plays the sound)
            Positioned.fill(
              child: Opacity(
                opacity: showRemote ? 1 : 0,
                child: RTCVideoView(_remote, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
            if (!showRemote)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 112,
                      height: 112,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        gradient: const LinearGradient(colors: [Color(0xFF13B39E), AppColors.primary]),
                      ),
                      child: Text(name.trim().isEmpty ? 'د' : name.trim().characters.first,
                          style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 22),
                    Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_status(context),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: bad ? const Color(0xFFFFB4B4) : const Color(0xFF9FB0C8), fontSize: 16, height: 1.5)),
                  ]),
                ),
              ),
            if (showRemote)
              PositionedDirectional(
                top: MediaQuery.of(context).padding.top + 16,
                start: 18,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6)])),
                  Text(_status(context), style: const TextStyle(color: Color(0xFFE6EDF7), fontSize: 13, shadows: [Shadow(blurRadius: 6)])),
                ]),
              ),
            if (widget.video && _stream != null)
              PositionedDirectional(
                top: MediaQuery.of(context).padding.top + 16,
                end: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 108,
                    height: 156,
                    color: const Color(0xFF222222),
                    child: Opacity(
                      opacity: _camOn ? 1 : 0.25,
                      child: RTCVideoView(_local, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 110,
              child: Text(
                'ch $_chStatus · sent $_sent · heard $_heard · peer ${_peer == null ? '-' : 'ok'}${_hasRelay ? ' · relay' : ''}${_lastError.isEmpty ? '' : ' · $_lastError'}',
                key: const Key('call-diag'),
                textAlign: TextAlign.center,
                maxLines: 3,
                style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 28,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  _CallButton(icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded, off: !_micOn, onTap: _toggleMic),
                  if (widget.video) _CallButton(icon: _camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded, off: !_camOn, onTap: _toggleCam),
                  if (widget.video && !kIsWeb) _CallButton(icon: Icons.cameraswitch_rounded, onTap: _flip),
                  if (!kIsWeb) _CallButton(icon: _speaker ? Icons.volume_up_rounded : Icons.hearing_rounded, off: !_speaker, onTap: _toggleSpeaker),
                  _CallButton(icon: Icons.call_end_rounded, color: AppColors.danger, onTap: _hangUp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.icon, required this.onTap, this.off = false, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final bool off;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
        color: color ?? (off ? Colors.white : Colors.white.withOpacity(0.14)),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 62, height: 62, child: Icon(icon, color: off ? const Color(0xFF0B1220) : Colors.white, size: 28)),
        ),
      );
}
