import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase/supabase.dart' show RealtimeChannel, RealtimeSubscribeStatus;

import '../../data/backend.dart';
import '../../l10n.dart';
import '../../services/media_bridge.dart';
import '../../theme.dart';
import '../../widgets/common.dart' show toast;

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

  // screen sharing
  MediaStream? _screen;
  bool _sharing = false;
  bool _peerSharing = false;

  // shared notes board: my lines in teal, the other person's in orange
  bool _board = false;
  bool _boardUnseen = false;
  final List<_Stroke> _strokes = [];
  _Stroke? _drawing;
  int _sentPoints = 0;
  int _strokeNo = 0;
  Timer? _flush;

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
    if (widget.video) await _loadVideoCap();
    try {
      _stream = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
        // Camera at most 640×480 at 24 frames a second by default ("ideal": phones pick the nearest they have).
        'video': widget.video
            ? {
                'facingMode': 'user',
                'width': {'ideal': (_capHeight * 4 / 3).round()},
                'height': {'ideal': _capHeight},
                'frameRate': {'ideal': 24, 'max': 24},
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
      final sender = await pc.addTrack(t, _stream!);
      final screen = _screen;
      if (t.kind == 'video' && _sharing && screen != null && screen.getVideoTracks().isNotEmpty) {
        await sender.replaceTrack(screen.getVideoTracks().first);
      }
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
        .onBroadcast(event: 'draw', callback: (m) => _onDraw(_body(m)))
        .onBroadcast(event: 'board', callback: (m) => _onBoard(_body(m)))
        .onBroadcast(event: 'clear', callback: (m) => _onClear(_body(m)))
        .onBroadcast(event: 'share', callback: (m) => _onShare(_body(m)))
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
    if (widget.video) _startCameraCap();
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

  // ------------------------------------------------------------------ screen sharing
  Future<void> _toggleShare() async {
    if (_sharing) return _stopShare();
    final pc = _pc;
    if (pc == null) return;
    try {
      if (!kIsWeb) {
        final allowed = await Helper.requestCapturePermission();
        if (!allowed) return;
        await MediaBridge.screenShareService(true);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final screen = await navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
      final tracks = screen.getVideoTracks();
      if (tracks.isEmpty) throw Exception('no screen');
      final track = tracks.first;
      final senders = await pc.getSenders();
      final video = senders.where((x) => x.track?.kind == 'video').toList();
      if (video.isEmpty) throw Exception('no video sender');
      await video.first.replaceTrack(track);
      track.onEnded = () => _stopShare();
      _screen = screen;
      _sharing = true;
      _send('share', {'on': true});
      _startShareQuality();
      if (mounted) setState(() {});
    } catch (e) {
      await MediaBridge.screenShareService(false);
      _lastError = 'share: $e';
      if (mounted) {
        setState(() {});
        toast(context, context.isAr ? 'تعذّرت مشاركة الشاشة' : 'Could not share the screen', icon: Icons.error_outline);
      }
    }
  }

  Future<void> _stopShare() async {
    if (!_sharing) return;
    _sharing = false;
    _qualityTimer?.cancel();
    _qualityTimer = null;
    await _applyQuality(null); // back to the camera limit
    final screen = _screen;
    _screen = null;
    try {
      final cam = _stream?.getVideoTracks() ?? const <MediaStreamTrack>[];
      final senders = await _pc?.getSenders() ?? const <RTCRtpSender>[];
      for (final x in senders) {
        if (x.track?.kind == 'video' && cam.isNotEmpty) await x.replaceTrack(cam.first);
      }
    } catch (_) {}
    for (final t in screen?.getTracks() ?? const <MediaStreamTrack>[]) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await screen?.dispose();
    } catch (_) {}
    await MediaBridge.screenShareService(false);
    _send('share', {'on': false});
    if (mounted) setState(() {});
  }

  // ---- screen-share quality that follows the connection speed ----
  // Every few seconds we read how fast the connection can send and how many packets get lost,
  // then pick a level: slow internet → smaller picture, fewer frames, lower bitrate (text stays readable).
  static const _levels = [
    (bitrate: 250000, scale: 3.0, fps: 4, ar: 'منخفضة', en: 'Low'),
    (bitrate: 600000, scale: 2.0, fps: 8, ar: 'متوسطة', en: 'Medium'),
    (bitrate: 1200000, scale: 1.5, fps: 12, ar: 'جيدة', en: 'Good'),
    (bitrate: 2500000, scale: 1.0, fps: 15, ar: 'عالية', en: 'High'),
  ];
  int _level = 2;
  int _upVotes = 0;
  Timer? _qualityTimer;
  num? _lastBytes;
  DateTime? _lastBytesAt;

  void _startShareQuality() {
    _level = 2;
    _upVotes = 0;
    _lastBytes = null;
    _applyQuality(_level);
    _qualityTimer?.cancel();
    _qualityTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkQuality());
  }

  static num? _num(dynamic v) => v is num ? v : (v is String ? num.tryParse(v) : null);

  Future<void> _checkQuality() async {
    final pc = _pc;
    if (pc == null || !_sharing) return;
    try {
      final stats = await pc.getStats();
      num? avail;
      num? loss;
      num? rtt;
      String limit = '';
      num? sentBytes;
      for (final r in stats) {
        final v = r.values;
        switch (r.type) {
          case 'candidate-pair':
            final ok = v['nominated'] == true || '${v['nominated']}' == 'true' || v['state'] == 'succeeded';
            final a = _num(v['availableOutgoingBitrate']);
            if (ok && a != null && a > 0) avail = a;
            final t = _num(v['currentRoundTripTime']);
            if (ok && t != null) rtt = t;
            break;
          case 'remote-inbound-rtp':
            if ('${v['kind'] ?? v['mediaType']}' == 'video') {
              loss = _num(v['fractionLost']) ?? loss;
              rtt = _num(v['roundTripTime']) ?? rtt;
            }
            break;
          case 'outbound-rtp':
            if ('${v['kind'] ?? v['mediaType']}' == 'video') {
              limit = '${v['qualityLimitationReason'] ?? ''}';
              sentBytes = _num(v['bytesSent']) ?? sentBytes;
            }
            break;
        }
      }
      // What we actually manage to send, for phones that don't report the available bitrate.
      num? sendRate;
      final now = DateTime.now();
      if (sentBytes != null && _lastBytes != null && _lastBytesAt != null) {
        final secs = now.difference(_lastBytesAt!).inMilliseconds / 1000;
        if (secs > 0) sendRate = (sentBytes - _lastBytes!) * 8 / secs;
      }
      _lastBytes = sentBytes;
      _lastBytesAt = now;

      var next = _level;
      final bad = (loss != null && loss > 0.08) || (rtt != null && rtt > 0.7) || limit == 'bandwidth';
      if (avail != null) {
        // Highest level that fits comfortably in the bandwidth the connection reports.
        var fit = 0;
        for (var i = 0; i < _levels.length; i++) {
          if (_levels[i].bitrate <= avail * 0.85) fit = i;
        }
        if (fit < next) next = fit;
        if (bad && next == _level && next > 0) next--;
        if (!bad && fit > _level) {
          _upVotes++;
          if (_upVotes >= 2) next = _level + 1;
        } else {
          _upVotes = 0;
        }
      } else if (bad) {
        next = _level > 0 ? _level - 1 : 0;
        _upVotes = 0;
      } else if ((loss ?? 0) < 0.02 && (sendRate == null || sendRate > _levels[_level].bitrate * 0.6)) {
        _upVotes++;
        if (_upVotes >= 3 && _level < _levels.length - 1) {
          next = _level + 1;
        }
      } else {
        _upVotes = 0;
      }
      if (next != _level) {
        _upVotes = 0;
        _level = next;
        await _applyQuality(next);
        if (mounted) setState(() {});
      }
    } catch (e) {
      _lastError = 'quality: $e';
    }
  }

  /// Sets bitrate / picture size / frame rate on the video we send ([level] null = camera defaults).
  Future<void> _applyQuality(int? level) async {
    try {
      final senders = await _pc?.getSenders() ?? const <RTCRtpSender>[];
      for (final x in senders) {
        if (x.track?.kind != 'video') continue;
        final p = x.parameters;
        final encs = p.encodings;
        if (encs == null || encs.isEmpty) continue;
        for (final e in encs) {
          if (level == null) {
            // Camera: capped at call_video_kbps (600 kbit/s), stepped down on a bad link.
            e.maxBitrate = _camSteps[_camStep] * 1000;
            e.maxFramerate = 24;
            e.scaleResolutionDownBy = 1.0;
          } else {
            final l = _levels[level];
            e.maxBitrate = l.bitrate;
            e.maxFramerate = l.fps;
            e.scaleResolutionDownBy = l.scale;
          }
        }
        await x.setParameters(p);
      }
    } catch (e) {
      _lastError = 'quality: $e';
    }
  }

  // ---- camera video limit (Stage 3 A3) ----
  // Default 640×480, 24 fps, 600 kbit/s (settings call_video_height / call_video_kbps, no new build needed).
  // On a bad link (loss > 8 % or round trip > 0.7 s) it steps down to half, then a quarter (300 → 150 kbit/s),
  // and back up after three good checks in a row.
  static int? _cachedKbps;
  static int? _cachedHeight;
  int _capHeight = 480;
  List<int> _camSteps = const [600, 300, 150];
  int _camStep = 0;
  int _camGood = 0;
  Timer? _camTimer;
  num? _camBytes;
  DateTime? _camBytesAt;
  int _sendKbps = 0; // measured, shown in the debug line

  Future<void> _loadVideoCap() async {
    if (_cachedKbps == null || _cachedHeight == null) {
      try {
        final v = await Future.wait([Backend.I.setting('call_video_kbps'), Backend.I.setting('call_video_height')])
            .timeout(const Duration(seconds: 3));
        final k = _num(v[0]);
        final h = _num(v[1]);
        _cachedKbps = k != null && k >= 100 && k <= 4000 ? k.toInt() : 600;
        _cachedHeight = h != null && h >= 144 && h <= 1080 ? h.toInt() : 480;
      } catch (_) {/* defaults below */}
    }
    final k = _cachedKbps ?? 600;
    _capHeight = _cachedHeight ?? 480;
    _camSteps = [k, (k / 2).round(), (k / 4).round()];
  }

  void _startCameraCap() {
    if (_camTimer != null) return;
    _camStep = 0;
    _camGood = 0;
    if (!_sharing) _applyQuality(null);
    _camTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkCamera());
  }

  Future<void> _checkCamera() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      num? loss;
      num? rtt;
      num? sentBytes;
      for (final r in await pc.getStats()) {
        final v = r.values;
        if (r.type == 'candidate-pair') {
          final ok = v['nominated'] == true || '${v['nominated']}' == 'true' || v['state'] == 'succeeded';
          final t = _num(v['currentRoundTripTime']);
          if (ok && t != null) rtt = t;
        } else if (r.type == 'remote-inbound-rtp' && '${v['kind'] ?? v['mediaType']}' == 'video') {
          loss = _num(v['fractionLost']) ?? loss;
          rtt = _num(v['roundTripTime']) ?? rtt;
        } else if (r.type == 'outbound-rtp' && '${v['kind'] ?? v['mediaType']}' == 'video') {
          sentBytes = (sentBytes ?? 0) + (_num(v['bytesSent']) ?? 0);
        }
      }
      final now = DateTime.now();
      if (sentBytes != null && _camBytes != null && _camBytesAt != null) {
        final secs = now.difference(_camBytesAt!).inMilliseconds / 1000;
        if (secs > 0) _sendKbps = ((sentBytes - _camBytes!) * 8 / secs / 1000).round();
      }
      _camBytes = sentBytes;
      _camBytesAt = now;
      if (_sharing) return; // screen share has its own levels
      final bad = (loss != null && loss > 0.08) || (rtt != null && rtt > 0.7);
      var next = _camStep;
      if (bad) {
        _camGood = 0;
        if (next < _camSteps.length - 1) next++;
      } else if ((loss ?? 0) < 0.02 && (rtt ?? 0) < 0.4) {
        _camGood++;
        if (_camGood >= 3 && next > 0) {
          next--;
          _camGood = 0;
        }
      } else {
        _camGood = 0;
      }
      if (next != _camStep) {
        _camStep = next;
        await _applyQuality(null);
      }
      if (mounted && (kDebugMode || widget.testMode)) setState(() {});
    } catch (e) {
      _lastError = 'camera: $e';
    }
  }

  void _onShare(Map<String, dynamic> p) {
    if (p['from'] == _me) return;
    _peerSharing = p['on'] == true;
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------------ shared notes board
  void _toggleBoard() {
    setState(() {
      _board = !_board;
      _boardUnseen = false;
    });
    _send('board', {'open': _board});
  }

  void _onBoard(Map<String, dynamic> p) {
    if (p['from'] == _me || !mounted) return;
    if (p['open'] == true && !_board) setState(() => _board = true);
  }

  void _penDown(Offset o) {
    final st = _Stroke('$_me-${_strokeNo++}', true)..pts.add(o);
    _drawing = st;
    _sentPoints = 0;
    setState(() => _strokes.add(st));
    // Points are sent in batches every 250 ms (fewer messages; same message shape as before).
    _flush ??= Timer.periodic(const Duration(milliseconds: 250), (_) => _sendPoints());
  }

  void _penMove(Offset o) {
    final st = _drawing;
    if (st == null) return;
    setState(() => st.pts.add(o));
  }

  void _penUp() {
    _sendPoints();
    _drawing = null;
    _flush?.cancel();
    _flush = null;
  }

  void _sendPoints() {
    final st = _drawing;
    if (st == null || st.pts.length <= _sentPoints) return;
    final from = _sentPoints == 0 ? 0 : _sentPoints - 1; // overlap one point so the line stays joined
    final pts = [
      for (final o in st.pts.sublist(from)) [double.parse(o.dx.toStringAsFixed(4)), double.parse(o.dy.toStringAsFixed(4))]
    ];
    _sentPoints = st.pts.length;
    _send('draw', {'id': st.id, 'pts': pts});
  }

  void _onDraw(Map<String, dynamic> p) {
    if (p['from'] == _me || !mounted) return;
    final id = '${p['id']}';
    final raw = p['pts'];
    if (raw is! List) return;
    var st = _strokes.where((x) => x.id == id).firstOrNull;
    if (st == null) {
      st = _Stroke(id, false);
      _strokes.add(st);
    }
    // A batch holds up to 250 ms of drawing: play it out over ~200 ms so the line grows smoothly.
    final queue = _incoming.putIfAbsent(st, () => []);
    for (final q in raw) {
      if (q is List && q.length == 2) queue.add(Offset((q[0] as num).toDouble(), (q[1] as num).toDouble()));
    }
    _drip ??= Timer.periodic(const Duration(milliseconds: 33), (_) => _dripPoints());
    setState(() {
      if (!_board) {
        _board = true;
        _boardUnseen = true;
      }
    });
  }

  final Map<_Stroke, List<Offset>> _incoming = {};
  Timer? _drip;

  void _dripPoints() {
    if (!mounted) return;
    if (_incoming.isEmpty) {
      _drip?.cancel();
      _drip = null;
      return;
    }
    setState(() {
      for (final e in _incoming.entries) {
        final n = max(1, (e.value.length / 6).ceil());
        e.key.pts.addAll(e.value.take(n));
        e.value.removeRange(0, min(n, e.value.length));
      }
      _incoming.removeWhere((_, q) => q.isEmpty);
    });
  }

  void _clearBoard() {
    _incoming.clear();
    setState(_strokes.clear);
    _send('clear', {});
  }

  void _onClear(Map<String, dynamic> p) {
    if (p['from'] == _me || !mounted) return;
    _incoming.clear();
    setState(_strokes.clear);
  }

  Widget _boardView(BuildContext context) {
    final peer = _peerName.isEmpty ? (context.isAr ? 'الطرف الآخر' : 'Other person') : _peerName;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          _legend(AppColors.primary, context.isAr ? 'أنت' : 'You'),
          const SizedBox(width: 14),
          _legend(_peerInk, peer),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearBoard,
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
            label: Text(context.isAr ? 'مسح' : 'Clear', style: const TextStyle(color: Colors.white70)),
          ),
          IconButton(onPressed: _toggleBoard, icon: const Icon(Icons.close_rounded, color: Colors.white70)),
        ]),
      ),
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (_, box) {
              final size = box.biggest;
              Offset norm(Offset o) => Offset((o.dx / size.width).clamp(0.0, 1.0), (o.dy / size.height).clamp(0.0, 1.0));
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GestureDetector(
                  onPanStart: (d) => _penDown(norm(d.localPosition)),
                  onPanUpdate: (d) => _penMove(norm(d.localPosition)),
                  onPanEnd: (_) => _penUp(),
                  onPanCancel: _penUp,
                  child: CustomPaint(painter: _BoardPainter(_strokes, AppColors.primary, _peerInk), size: size),
                ),
              );
            }),
          ),
        ),
      ),
    ]);
  }

  static const _peerInk = Color(0xFFF97316);

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]);

  Future<void> _cleanup() async {
    _flush?.cancel();
    _drip?.cancel();
    _qualityTimer?.cancel();
    _camTimer?.cancel();
    if (_sharing) {
      for (final t in _screen?.getTracks() ?? const <MediaStreamTrack>[]) {
        try {
          await t.stop();
        } catch (_) {}
      }
      MediaBridge.screenShareService(false);
    }
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
                child: RTCVideoView(
                  _remote,
                  objectFit: _peerSharing ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
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
            if (_board)
              Positioned(
                left: 8,
                right: 8,
                top: MediaQuery.of(context).padding.top + 8,
                bottom: MediaQuery.of(context).padding.bottom + 132,
                child: Container(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xEE0B1220), borderRadius: BorderRadius.circular(18)),
                  child: _boardView(context),
                ),
              ),
            if (_sharing)
              PositionedDirectional(
                top: MediaQuery.of(context).padding.top + 180,
                end: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(20)),
                  child: Text(context.isAr ? 'تشارك شاشتك' : 'Sharing your screen', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            if (_sharing)
              PositionedDirectional(
                top: MediaQuery.of(context).padding.top + 214,
                end: 16,
                child: Container(
                  key: const Key('share-quality'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xCC0B1220), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      Icons.speed_rounded,
                      color: _level >= 2 ? const Color(0xFF4ADE80) : (_level == 1 ? const Color(0xFFFBBF24) : const Color(0xFFF87171)),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.isAr ? 'الجودة: ${_levels[_level].ar}' : 'Quality: ${_levels[_level].en}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ),
            if (kDebugMode || widget.testMode)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 110,
              child: Text(
                'ch $_chStatus · sent $_sent · heard $_heard · peer ${_peer == null ? '-' : 'ok'}${_hasRelay ? ' · relay' : ''} · video $_sendKbps/${_camSteps[_camStep]} kbps${_lastError.isEmpty ? '' : ' · $_lastError'}',
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
                  _CallButton(icon: Icons.draw_rounded, off: _board, dot: _boardUnseen, onTap: _toggleBoard),
                  if (widget.video) _CallButton(icon: _sharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded, off: _sharing, onTap: _toggleShare),
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
  const _CallButton({required this.icon, required this.onTap, this.off = false, this.color, this.dot = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool off;
  final Color? color;
  final bool dot;

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Material(
          color: color ?? (off ? Colors.white : Colors.white.withOpacity(0.14)),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 58, height: 58, child: Icon(icon, color: off ? const Color(0xFF0B1220) : Colors.white, size: 26)),
          ),
        ),
        if (dot)
          Positioned(
            top: 2,
            right: 2,
            child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle)),
          ),
      ]);
}

class _Stroke {
  _Stroke(this.id, this.mine);
  final String id;
  final bool mine;
  final List<Offset> pts = []; // 0..1 of the board's width / height
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.strokes, this.mineColor, this.peerColor);
  final List<_Stroke> strokes;
  final Color mineColor;
  final Color peerColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final grid = Paint()
      ..color = const Color(0xFFE8EEF5)
      ..strokeWidth = 1;
    for (double y = size.height / 16; y < size.height; y += size.height / 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (final st in strokes) {
      final paint = Paint()
        ..color = st.mine ? mineColor : peerColor
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (st.pts.length == 1) {
        final o = st.pts.first;
        canvas.drawCircle(Offset(o.dx * size.width, o.dy * size.height), 1.8, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path();
      for (int i = 0; i < st.pts.length; i++) {
        final o = Offset(st.pts[i].dx * size.width, st.pts[i].dy * size.height);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
