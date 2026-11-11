import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/calls.dart';
import '../../services/media_bridge.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/media.dart';
import 'package:url_launcher/url_launcher.dart';
import '../student/booking_screen.dart';
import 'call_screen.dart';
import 'chat_logic.dart';

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
  int _firstUnreadId = 0; // where the "unread messages" line goes (fixed when the chat opens)
  DateTime? _awaySince; // when I scrolled away from the newest message (null = at the bottom)

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    final c = widget.conversation;
    _firstUnreadId = firstUnreadOf(c.messages, c.unread)?.remoteId ?? 0;
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _app.openConversation(widget.conversation);
    });
  }

  @override
  void dispose() {
    _app.closeConversation(widget.conversation);
    _timer?.cancel();
    // Leaving the chat while recording: stop the microphone and drop the clip.
    if (_recording) MediaBridge.cancelRecording();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // The list is reversed: offset 0 is the newest message (the chat opens there and stays
  // there when new messages arrive); scrolling up reaches older messages.
  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 300) _app.loadOlder(widget.conversation);
    final away = p.pixels > 240;
    if (away && _awaySince == null) {
      setState(() => _awaySince = DateTime.now());
    } else if (!away && _awaySince != null) {
      setState(() => _awaySince = null);
    }
  }

  /// New messages from the other person since I scrolled away from the bottom.
  int _newWhileAway(Conversation c) {
    final since = _awaySince;
    if (since == null) return 0;
    return c.messages.where((m) => !m.mine && m.remoteId != 0 && m.time.isAfter(since)).length;
  }

  Future<void> _report(AppState app) async {
    final reason = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.tr('report_chat')),
        content: TextField(
          controller: reason,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: context.isAr ? 'ما المشكلة في هذه المحادثة؟' : 'What is wrong in this chat?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(context.isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(context.isAr ? 'إرسال البلاغ' : 'Send report')),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (send != true || !mounted) return;
    if (text.isEmpty) {
      toast(context, context.isAr ? 'اكتب سبب البلاغ' : 'Please write the reason', icon: Icons.info_outline);
      return;
    }
    final ok = await app.reportConversation(widget.conversation, text);
    if (!mounted) return;
    if (ok) toast(context, context.tr('report_sent'));
  }

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

  Future<void> _toggleVoice(AppState app) async {
    if (_recording) {
      _timer?.cancel();
      setState(() => _recording = false);
      if (!app.live) {
        app.sendMessage(widget.conversation, Message(mine: true, text: '', time: DateTime.now(), type: MsgType.voice, seconds: _secs < 1 ? 1 : _secs));
        _toBottom();
        return;
      }
      final clip = await MediaBridge.stopRecording();
      if (!mounted) return;
      if (clip == null || clip.bytes.isEmpty || clip.ms < 700) {
        toast(context, context.isAr ? 'التسجيل قصير جداً — اضغط مطولاً وتكلّم' : 'Too short — tap, speak, then tap again', icon: Icons.mic_off_rounded);
        return;
      }
      _toBottom();
      await app.sendMedia(widget.conversation,
          type: MsgType.voice, bytes: clip.bytes, name: 'voice.${clip.ext}', mime: clip.mime, seconds: (clip.ms / 1000).ceil());
      _toBottom();
    } else {
      if (app.live) {
        final r = await MediaBridge.startRecording();
        if (!mounted) return;
        if (r != 'ok') {
          toast(
            context,
            r == 'permission'
                ? (context.isAr ? 'اسمح للتطبيق باستخدام الميكروفون ثم اضغط مرة أخرى' : 'Allow the microphone, then tap again')
                : (context.isAr ? 'تعذّر بدء التسجيل' : 'Could not start recording'),
            icon: Icons.mic_off_rounded,
          );
          return;
        }
      }
      setState(() {
        _recording = true;
        _secs = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _secs++);
        if (_secs >= 180) _toggleVoice(app); // 3 minutes max
      });
    }
  }

  Future<void> _cancelVoice() async {
    _timer?.cancel();
    setState(() => _recording = false);
    await MediaBridge.cancelRecording();
  }

  /// Photo / video from the gallery or the camera.
  Future<void> _attach(AppState app) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary), title: Text(context.tr('send_photo')), onTap: () => Navigator.pop(sheet, 'photo')),
          if (!kIsWeb)
            ListTile(leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary), title: Text(context.tr('take_photo')), onTap: () => Navigator.pop(sheet, 'camera')),
          ListTile(leading: const Icon(Icons.video_library_outlined, color: AppColors.primary), title: Text(context.tr('send_video')), onTap: () => Navigator.pop(sheet, 'video')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    final picker = ImagePicker();
    XFile? f;
    try {
      f = choice == 'video'
          ? await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5))
          : await picker.pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    } catch (_) {
      if (mounted) toast(context, context.isAr ? 'تعذّر فتح المعرض/الكاميرا' : 'Could not open the gallery/camera', icon: Icons.error_outline);
      return;
    }
    if (f == null || !mounted) return;
    final bytes = await f.readAsBytes();
    final video = choice == 'video';
    final name = f.name.isNotEmpty ? f.name : (video ? 'video.mp4' : 'photo.jpg');
    final mime = f.mimeType ?? (video ? 'video/mp4' : 'image/jpeg');
    _toBottom();
    await app.sendMedia(widget.conversation, type: video ? MsgType.video : MsgType.image, bytes: bytes, name: name, mime: mime);
    _toBottom();
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
          Avatar(name: c.name, color: c.color, size: 40, online: c.online, photo: c.photo),
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
                await _report(app);
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
            child: Builder(builder: (_) {
              // Rows oldest → newest; the list is reversed, so row 0 of the list is the newest.
              final items = buildChatItems(c.messages, firstUnreadId: _firstUnreadId);
              final away = _newWhileAway(c);
              return Stack(children: [
                ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length + (c.hasOlder ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
                      );
                    }
                    final it = items[items.length - 1 - i];
                    final day = it.day;
                    if (day != null) return _DayHeader(key: ValueKey('d${day.year}-${day.month}-${day.day}'), day: day);
                    if (it.unreadLine) return const _UnreadLine(key: ValueKey('unread'));
                    final m = it.message!;
                    return _Bubble(
                      key: ValueKey(m.remoteId != 0 ? 'r${m.remoteId}' : identityHashCode(m)),
                      m: m,
                      color: c.color,
                      onRetry: m.failed ? () => app.retryMessage(c, m) : null,
                    );
                  },
                ),
                if (_awaySince != null)
                  PositionedDirectional(
                    end: 14,
                    bottom: 12,
                    child: _JumpToNewest(
                      count: away,
                      onTap: () {
                        setState(() => _awaySince = null);
                        _toBottom();
                      },
                    ),
                  ),
              ]);
            }),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
              child: Row(children: [
                _recording
                    ? IconButton(
                        tooltip: context.isAr ? 'إلغاء' : 'Cancel',
                        onPressed: _cancelVoice,
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      )
                    : IconButton(
                        tooltip: context.tr('send_photo'),
                        onPressed: () => _attach(app),
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
                            Text('${context.tr('recording')}  ${_secs ~/ 60}:${two(_secs % 60)}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
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
  final VoidCallback? onRetry; // set for a failed message of mine
  const _Bubble({super.key, required this.m, required this.color, this.onRetry});

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
        content = VoiceNote(m: m);
        break;
      case MsgType.image:
      case MsgType.video:
        return _withStatus(
          context,
          Align(
            alignment: m.mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  m.type == MsgType.image ? ChatImage(m: m) : ChatVideo(m: m),
                  const SizedBox(height: 2),
                  _Footer(m: m, color: AppColors.text3),
                ],
              ),
            ),
          ),
        );
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
          SelectableText(m.text, textDirection: directionOf(m.text), style: TextStyle(color: fg, height: 1.5)),
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

    return _withStatus(context, Align(
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
            _Footer(m: m, color: fg.withOpacity(0.7)),
          ]),
        ),
      ),
    ));
  }

  /// Adds "tap to retry" for a failed message and the notice under a message the filter hid.
  Widget _withStatus(BuildContext context, Widget bubble) {
    final tick = tickFor(m);
    if (tick != Tick.failed && tick != Tick.hidden) return bubble;
    final ar = context.isAr;
    final failed = tick == Tick.failed;
    final note = failed
        ? (ar ? 'لم تُرسل · اضغط لإعادة المحاولة' : 'Not sent · Tap to retry')
        : (ar ? 'لم تُرسل: لا يمكن مشاركة أرقام الهاتف أو وسائل التواصل في درس' : "Not delivered: phone numbers and contact links can't be shared on Dars");
    final body = Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Opacity(opacity: failed ? 1 : 0.55, child: bubble),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(failed ? Icons.error_rounded : Icons.block_rounded, size: 15, color: AppColors.danger),
            const SizedBox(width: 4),
            Flexible(child: Text(note, style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    ]);
    return failed && onRetry != null ? InkWell(onTap: onRetry, borderRadius: BorderRadius.circular(18), child: body) : body;
  }
}

/// Time + status mark under a message: clock (sending), ✓ (sent), ✓✓ (read), ! (failed).
class _Footer extends StatelessWidget {
  final Message m;
  final Color color;
  const _Footer({required this.m, required this.color});

  @override
  Widget build(BuildContext context) {
    final tick = tickFor(m);
    final IconData? icon = switch (tick) {
      Tick.sending => Icons.schedule_rounded,
      Tick.sent => Icons.done_rounded,
      Tick.read => Icons.done_all_rounded,
      Tick.failed => Icons.error_rounded,
      Tick.hidden => Icons.block_rounded,
      Tick.none => null,
    };
    final iconColor = tick == Tick.read
        ? (m.mine && m.type != MsgType.image && m.type != MsgType.video ? const Color(0xFFB9F3E8) : AppColors.info)
        : (tick == Tick.failed || tick == Tick.hidden ? AppColors.danger : color);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(timeOf(context, m.time), style: TextStyle(color: color, fontSize: 10.5)),
      if (icon != null) ...[
        const SizedBox(width: 3),
        Icon(icon, key: ValueKey('tick-${tick.name}'), size: 14, color: iconColor),
      ],
    ]);
  }
}

/// "Today" / "Yesterday" / a date, between messages of different days.
class _DayHeader extends StatelessWidget {
  final DateTime day;
  const _DayHeader({super.key, required this.day});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
          child: Text(dayLabel(day, ar: context.isAr), style: const TextStyle(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      );
}

/// Marks where the messages I had not read yet start.
class _UnreadLine extends StatelessWidget {
  const _UnreadLine({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const Expanded(child: Divider(color: AppColors.accent)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(context.isAr ? 'رسائل غير مقروءة' : 'Unread messages', style: const TextStyle(color: Color(0xFFB7791F), fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const Expanded(child: Divider(color: AppColors.accent)),
        ]),
      );
}

/// Floating "jump to newest" button, with how many new messages arrived meanwhile.
class _JumpToNewest extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _JumpToNewest({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
          elevation: 3,
          child: IconButton(
            tooltip: context.isAr ? 'إلى أحدث رسالة' : 'Jump to newest',
            onPressed: onTap,
            icon: const Icon(Icons.keyboard_double_arrow_down_rounded, color: AppColors.primary),
          ),
        ),
        if (count > 0)
          PositionedDirectional(
            top: -4,
            end: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
      ]);
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
