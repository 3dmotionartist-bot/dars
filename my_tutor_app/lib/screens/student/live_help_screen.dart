import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/backend.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/call_screen.dart';
import '../shared/chat_screen.dart';
import 'tutor_profile_screen.dart';

enum _Stage { compose, searching, results }

/// "Speak to a tutor now": compose (text / voice / photo) → broadcast & countdown → tutors who accepted.
class LiveHelpScreen extends StatefulWidget {
  const LiveHelpScreen({super.key});
  @override
  State<LiveHelpScreen> createState() => _LiveHelpScreenState();
}

class _LiveHelpScreenState extends State<LiveHelpScreen> with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.compose;
  String _subject = 'math';
  final _text = TextEditingController();
  bool _recording = false;
  int _voiceSeconds = 0;
  bool _photo = false;
  Timer? _timer;
  int _left = 90;
  final List<Tutor> _accepted = [];
  late final AnimationController _pulse;
  String? _requestId; // live mode
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _text.dispose();
    super.dispose();
  }

  void _toggleRecord() {
    if (_recording) {
      _timer?.cancel();
      setState(() => _recording = false);
    } else {
      _voiceSeconds = 0;
      setState(() => _recording = true);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _voiceSeconds++);
        if (_voiceSeconds >= 60) _toggleRecord();
      });
    }
  }

  void _start() {
    if (_text.text.trim().isEmpty && _voiceSeconds == 0) {
      toast(context, context.tr('live_need_msg'), icon: Icons.info_outline_rounded);
      return;
    }
    _timer?.cancel();
    final app = context.read<AppState>();
    if (app.live) {
      _startLive(app);
      return;
    }
    final pool = MockData.tutors.where((t) => t.available).toList()
      ..sort((a, b) => (b.subjectIds.contains(_subject) ? 1 : 0).compareTo(a.subjectIds.contains(_subject) ? 1 : 0));
    setState(() {
      _recording = false;
      _stage = _Stage.searching;
      _left = 90;
      _accepted.clear();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _left--;
        // Simulated acceptances — in production these arrive by push / websocket.
        final elapsed = 90 - _left;
        if ([3, 7, 12, 18].contains(elapsed) && _accepted.length < pool.length) _accepted.add(pool[_accepted.length]);
        if (_left <= 0 || _accepted.length >= 4) {
          t.cancel();
          _stage = _Stage.results;
        }
      });
    });
  }

  /// Live mode: send the request to online tutors, then check every 2 s who accepted.
  Future<void> _startLive(AppState app) async {
    setState(() {
      _recording = false;
      _stage = _Stage.searching;
      _left = 90;
      _accepted.clear();
    });
    try {
      _requestId = await app.createLiveRequest(subject: _subject, text: _text.text, voiceSeconds: _voiceSeconds);
    } catch (e) {
      app.say(Backend.errorText(e), bad: true);
      if (mounted) setState(() => _stage = _Stage.compose);
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        setState(() => _stage = _Stage.results);
        return;
      }
      if (_left % 2 == 0 && !_checking && _requestId != null) {
        _checking = true;
        try {
          final got = await app.liveAccepted(_requestId!);
          if (mounted && got.length != _accepted.length) {
            setState(() => _accepted
              ..clear()
              ..addAll(got));
          }
        } catch (_) {
        } finally {
          _checking = false;
        }
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _stage = _Stage.results);
  }

  void _reset() {
    _timer?.cancel();
    if (_requestId != null && _stage == _Stage.searching && _accepted.isEmpty) context.read<AppState>().cancelLiveRequest(_requestId!);
    _requestId = null;
    setState(() {
      _stage = _Stage.compose;
      _accepted.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (_stage) {
      case _Stage.compose:
        child = _compose(context);
        break;
      case _Stage.searching:
        child = _searching(context);
        break;
      case _Stage.results:
        child = _results(context);
        break;
    }
    return SafeArea(child: MaxWidth(max: 640, child: child));
  }

  Widget _compose(BuildContext context) {
    final app = context.read<AppState>();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: AppColors.primarySoft),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('live_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(context.tr('live_sub'), style: const TextStyle(color: AppColors.text2, height: 1.5)),
            ]),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 56),
        ]),
      ),
      const SizedBox(height: 18),
      Text(context.tr('live_subject'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in MockData.subjects.where((s) => app.interests.contains(s.id) || ['math', 'physics', 'english', 'chemistry'].contains(s.id)))
          ChoiceChip(
            avatar: Icon(s.icon, size: 18, color: _subject == s.id ? Colors.white : s.color),
            label: Text(s.name.of(context)),
            selected: _subject == s.id,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            side: BorderSide(color: _subject == s.id ? AppColors.primary : AppColors.line),
            labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: _subject == s.id ? Colors.white : AppColors.ink),
            onSelected: (_) => setState(() => _subject = s.id),
          ),
      ]),
      const SizedBox(height: 18),
      TextField(controller: _text, maxLines: 4, maxLength: 400, decoration: InputDecoration(hintText: context.tr('live_hint'))),
      const SizedBox(height: 6),
      AppCard(
        onTap: _toggleRecord,
        color: _recording ? AppColors.dangerSoft : Colors.white,
        borderColor: _recording ? AppColors.danger : AppColors.line,
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: _recording ? AppColors.danger : AppColors.primary, shape: BoxShape.circle),
            child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _recording ? context.tr('recording') : (_voiceSeconds > 0 ? '${context.tr('voice_ready')} · 0:${two(_voiceSeconds)}' : context.tr('record_voice')),
              style: TextStyle(fontWeight: FontWeight.w700, color: _recording ? AppColors.danger : AppColors.ink),
            ),
          ),
          if (_recording) Text('0:${two(_voiceSeconds)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
          if (!_recording && _voiceSeconds > 0)
            IconButton(onPressed: () => setState(() => _voiceSeconds = 0), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.text3)),
        ]),
      ),
      const SizedBox(height: 10),
      AppCard(
        onTap: () => setState(() => _photo = !_photo),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(_photo ? Icons.image_rounded : Icons.add_a_photo_rounded, color: AppColors.info),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_photo ? 'question.jpg ✓' : context.tr('attach_photo'), style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      ),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: _start, icon: const Icon(Icons.wifi_tethering_rounded), label: Text(context.tr('start_search'))),
      const SizedBox(height: 10),
      Text(context.tr('call_recorded'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
    ]);
  }

  Widget _searching(BuildContext context) {
    final msgs = [context.tr('search_msg_1'), context.tr('search_msg_2'), context.tr('search_msg_3')];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 10),
        Text(context.tr('searching'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(msgs[(90 - _left) ~/ 6 % 3], key: ValueKey((90 - _left) ~/ 6 % 3), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text2)),
        ),
        const Spacer(),
        SizedBox(
          width: 260,
          height: 260,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => CustomPaint(
              painter: _RadarPainter(_pulse.value),
              child: Stack(alignment: Alignment.center, children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${_left ~/ 60}:${two(_left % 60)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  Text(context.isAr ? 'دقيقة : ثانية' : 'min : sec', style: const TextStyle(color: AppColors.text3, fontSize: 12)),
                ]),
                for (int i = 0; i < _accepted.length; i++)
                  Transform.translate(
                    offset: Offset(105 * math.cos(i * 1.7 + 0.5), 105 * math.sin(i * 1.7 + 0.5)),
                    child: Avatar(name: _accepted[i].name, color: _accepted[i].color, size: 46, photo: _accepted[i].photoUrl),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('${_accepted.length} ${context.tr('accepted_so_far')}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const Spacer(),
        ElevatedButton(onPressed: _accepted.isEmpty ? null : _stop, child: Text(context.tr('stop_search'))),
        const SizedBox(height: 8),
        TextButton(onPressed: _reset, child: Text(context.tr('cancel_request'), style: const TextStyle(color: AppColors.danger))),
      ]),
    );
  }

  Widget _results(BuildContext context) {
    final app = context.read<AppState>();
    if (_accepted.isEmpty) {
      return EmptyState(
        icon: Icons.person_off_rounded,
        title: context.tr('none_found'),
        body: context.tr('none_found_b'),
        action: ElevatedButton(onPressed: _reset, child: Text(context.tr('try_again'))),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      Text(context.tr('live_results'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      Text(context.tr('live_results_sub'), style: const TextStyle(color: AppColors.text2)),
      const SizedBox(height: 14),
      for (final t in _accepted)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TutorProfileScreen(tutor: t))),
            child: Column(children: [
              Row(children: [
                Avatar(name: t.name, color: t.color, photo: t.photoUrl, size: 54, online: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    VerifiedName(t.name.of(context)),
                    Text(t.headline.of(context), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text2, fontSize: 13)),
                    RatingRow(t.rating, t.reviewCount),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () async {
                      if (app.live) {
                        // The tutor's acceptance already opened this chat (with your question) on the server.
                        await app.refresh();
                        if (!context.mounted) return;
                        final c = app.conversationFor(t);
                        app.openConversation(c);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
                        return;
                      }
                      final c = app.conversationFor(t);
                      if (_text.text.trim().isNotEmpty) app.sendMessage(c, Message(mine: true, text: _text.text.trim(), time: DateTime.now()));
                      if (_voiceSeconds > 0) app.sendMessage(c, Message(mine: true, text: '', time: DateTime.now(), type: MsgType.voice, seconds: _voiceSeconds));
                      app.sendMessage(c, Message(mine: false, text: context.tr('accepted_msg'), time: DateTime.now()));
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(context.tr('chat')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => app.live
                        ? app.startCall(app.conversationFor(t), video: false)
                        : Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(name: t.name, color: t.color))),
                    icon: const Icon(Icons.call_rounded),
                    label: Text(context.tr('call')),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      const SizedBox(height: 6),
      TextButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh_rounded), label: Text(context.tr('try_again'))),
    ]);
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  _RadarPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.primary.withOpacity(0.18);
    for (final f in [0.45, 0.7, 0.95]) {
      canvas.drawCircle(c, r * f, ring);
    }
    for (int i = 0; i < 2; i++) {
      final p = (t + i * 0.5) % 1.0;
      canvas.drawCircle(c, r * (0.35 + 0.6 * p), Paint()..color = AppColors.primary.withOpacity(0.18 * (1 - p)));
    }
    canvas.drawCircle(c, r * 0.36, Paint()..color = Colors.white);
    canvas.drawCircle(c, r * 0.36, ring..color = AppColors.primary.withOpacity(0.4));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t;
}
