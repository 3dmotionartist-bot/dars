import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/calls.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'package:url_launcher/url_launcher.dart';
import '../student/booking_screen.dart';
import 'call_screen.dart';

/// Chat with text, voice notes (tap to record), attachments, contact-info filter,
/// safety banner, "Book a lesson" shortcut and in-app call.
class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  const ChatScreen({super.key, required this.conversation});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _recording = false;
  int _secs = 0;
  Timer? _timer;
  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _app.openConversation(widget.conversation);
    });
  }

  @override
  void dispose() {
    _app.closeConversation(widget.conversation);
    _timer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  void _send(AppState app) {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final ok = app.sendMessage(widget.conversation, Message(mine: true, text: text, time: DateTime.now()));
    if (!ok) {
      toast(context, context.tr('blocked_contact'), icon: Icons.block_rounded);
      return;
    }
    _ctrl.clear();
    _toBottom();
    if (app.live) return;
    // Demo auto-reply
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      app.sendMessage(widget.conversation, Message(mine: false, text: context.isAr ? 'تمام، وصلت رسالتك 👍' : 'Got it 👍', time: DateTime.now()));
      _toBottom();
    });
  }

  void _toggleVoice(AppState app) {
    if (_recording) {
      _timer?.cancel();
      app.sendMessage(widget.conversation, Message(mine: true, text: '', time: DateTime.now(), type: MsgType.voice, seconds: _secs < 1 ? 1 : _secs));
      setState(() => _recording = false);
      _toBottom();
    } else {
      setState(() {
        _recording = true;
        _secs = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secs++);
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = widget.conversation;
    final isTutorSide = app.role == UserRole.tutor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Row(children: [
          Avatar(name: c.name, color: c.color, size: 40, online: c.online),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name.of(context), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (c.online) Text(context.tr('online_now'), style: const TextStyle(color: AppColors.success, fontSize: 12)),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: context.tr('voice_call'),
            onPressed: () => app.live ? app.startCall(c, video: false) : Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(name: c.name, color: c.color))),
            icon: const Icon(Icons.call_outlined, color: AppColors.primary),
          ),
          IconButton(
            tooltip: context.tr('video_call'),
            onPressed: () => app.live ? app.startCall(c, video: true) : Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(name: c.name, color: c.color))),
            icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'meeting') {
                final link = await app.createMeeting(c);
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) toast(context, context.tr('meeting_created'));
              } else {
                toast(context, context.tr('report_sent'));
              }
            },
            itemBuilder: (_) => [
              if (app.live)
                PopupMenuItem(
                  value: 'meeting',
                  child: Row(children: [const Icon(Icons.add_link_rounded, color: AppColors.primary), const SizedBox(width: 10), Text(context.tr('create_meeting'))]),
                ),
              PopupMenuItem(value: 'report', child: Text(context.tr('report_chat'))),
            ],
          ),
        ],
      ),
      body: MaxWidth(
        max: 820,
        child: Column(children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFB7791F), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(context.tr('chat_warning'), style: const TextStyle(fontSize: 12, color: Color(0xFF7A5414)))),
            ]),
          ),
          if (c.tutor != null && !isTutorSide)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(tutor: c.tutor!, hourPrice: c.tutor!.pricePerHour.toDouble()))),
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: Text(context.tr('book_lesson')),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: c.messages.length,
              itemBuilder: (_, i) => _Bubble(m: c.messages[i], color: c.color),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
              child: Row(children: [
                IconButton(
                  onPressed: () {
                    app.sendMessage(c, Message(mine: true, text: 'homework.pdf', time: DateTime.now(), type: MsgType.file));
                    _toBottom();
                  },
                  icon: const Icon(Icons.attach_file_rounded, color: AppColors.text2),
                ),
                Expanded(
                  child: _recording
                      ? Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(24)),
                          child: Row(children: [
                            const Icon(Icons.fiber_manual_record_rounded, color: AppColors.danger, size: 14),
                            const SizedBox(width: 8),
                            Text('${context.tr('recording')}  0:${two(_secs)}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                          ]),
                        )
                      : TextField(
                          controller: _ctrl,
                          minLines: 1,
                          maxLines: 4,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _send(app),
                          decoration: InputDecoration(
                            hintText: context.tr('write_message'),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.line)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.line)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.primary)),
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _recording ? AppColors.danger : AppColors.primary,
                  child: IconButton(
                    onPressed: () {
                      if (_ctrl.text.trim().isNotEmpty && !_recording) {
                        _send(app);
                      } else {
                        _toggleVoice(app);
                      }
                    },
                    icon: Icon(_ctrl.text.trim().isNotEmpty && !_recording ? Icons.send_rounded : (_recording ? Icons.stop_rounded : Icons.mic_rounded), color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message m;
  final Color color;
  const _Bubble({required this.m, required this.color});

  @override
  Widget build(BuildContext context) {
    if (m.type == MsgType.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
          child: Text(m.text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.primaryDark, fontSize: 13, height: 1.5)),
        ),
      );
    }
    final fg = m.mine ? Colors.white : AppColors.ink;
    Widget content;
    switch (m.type) {
      case MsgType.voice:
        content = Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.play_circle_fill_rounded, color: m.mine ? Colors.white : AppColors.primary, size: 32),
          const SizedBox(width: 6),
          for (int i = 0; i < 18; i++)
            Container(
              width: 3,
              height: 6.0 + (i * 7 % 17),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(color: fg.withOpacity(0.7), borderRadius: BorderRadius.circular(2)),
            ),
          const SizedBox(width: 8),
          Text('0:${two(m.seconds)}', style: TextStyle(color: fg, fontSize: 12)),
        ]);
        break;
      case MsgType.call:
        final inv = Calls.parse(m.text);
        final video = inv?.video ?? false;
        final meet = inv?.meet ?? false;
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(meet ? Icons.link_rounded : (video ? Icons.videocam_rounded : Icons.call_rounded), color: fg),
            const SizedBox(width: 8),
            Text(context.tr(meet ? 'meeting_link' : (video ? 'video_call' : 'voice_call')), style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
          ]),
          if (inv != null && meet) ...[
            const SizedBox(height: 6),
            SelectableText(Calls.shareLink(inv.room), style: TextStyle(color: fg.withOpacity(0.85), fontSize: 12.5, height: 1.4)),
          ],
          if (inv != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _JoinButton(mine: m.mine, label: context.tr(meet ? 'join_meeting' : 'join_call'), onTap: () => _join(context, inv.room, inv.video)),
              if (meet)
                _JoinButton(
                  mine: m.mine,
                  outlined: true,
                  icon: Icons.copy_rounded,
                  label: context.tr('copy_link'),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: Calls.shareLink(inv.room)));
                    if (context.mounted) toast(context, context.tr('link_copied'));
                  },
                ),
            ]),
          ],
        ]);
        break;
      case MsgType.file:
        content = Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.description_rounded, color: fg),
          const SizedBox(width: 8),
          Flexible(child: Text(m.text, style: TextStyle(color: fg, fontWeight: FontWeight.w700))),
        ]);
        break;
      default:
        final meetLink = Calls.fromUrl(m.text);
        final url = meetLink == null ? RegExp(r'https?://[^\s]+').firstMatch(m.text)?.group(0) : null;
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          SelectableText(m.text, style: TextStyle(color: fg, height: 1.5)),
          if (meetLink != null) ...[
            const SizedBox(height: 8),
            _JoinButton(mine: m.mine, label: context.tr('join_meeting'), onTap: () => _join(context, meetLink.room, meetLink.video)),
          ] else if (url != null) ...[
            const SizedBox(height: 8),
            _JoinButton(
              mine: m.mine,
              outlined: true,
              icon: Icons.open_in_new_rounded,
              label: context.tr('open_link'),
              onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank'),
            ),
          ],
        ]);
    }

    return Align(
      alignment: m.mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75 > 520 ? 520.0 : MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: m.mine ? AppColors.primary : Colors.white,
            border: m.mine ? null : Border.all(color: AppColors.line),
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(18),
              topEnd: const Radius.circular(18),
              bottomStart: Radius.circular(m.mine ? 18 : 4),
              bottomEnd: Radius.circular(m.mine ? 4 : 18),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            content,
            const SizedBox(height: 2),
            Text(timeOf(context, m.time), style: TextStyle(color: fg.withOpacity(0.65), fontSize: 10.5)),
          ]),
        ),
      ),
    );
  }
}

void _join(BuildContext context, String room, bool video) {
  final app = context.read<AppState>();
  final c = app.activeConversation;
  app.joinCall(room: room, video: video, peer: c == null ? '' : c.name.of(context));
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.mine, required this.label, required this.onTap, this.outlined = false, this.icon = Icons.login_rounded});
  final bool mine;
  final bool outlined;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strong = mine ? Colors.white : AppColors.primary;
    final weak = mine ? AppColors.primary : Colors.white;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: outlined ? Colors.transparent : strong,
        foregroundColor: outlined ? strong : weak,
        side: outlined ? BorderSide(color: strong) : null,
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
