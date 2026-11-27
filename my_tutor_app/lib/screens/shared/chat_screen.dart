import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/calls.dart';
import '../../services/media_bridge.dart';
import '../../services/video_shrink.dart';
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
  Message? _replying; // Round G1: the message my next one answers (quote)
  // Round G2: "typing…" and "last seen"
  ({void Function() typing, Future<void> Function() close})? _typingLink;
  bool _peerTyping = false;
  Timer? _typingOff;
  DateTime? _lastSeen;
  Timer? _seenTimer;
  // Round G2: hold the microphone to record, slide away to cancel
  bool _held = false;
  bool _slid = false;
  Future<void>? _holdStart;

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
    _linkTyping();
    _loadLastSeen();
    _seenTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadLastSeen());
  }

  void _linkTyping() {
    if (_typingLink != null) return;
    _typingLink = _app.typingLink(widget.conversation, () {
      if (!mounted) return;
      _typingOff?.cancel();
      _typingOff = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _peerTyping = false);
      });
      if (!_peerTyping) setState(() => _peerTyping = true);
    });
  }

  Future<void> _loadLastSeen() async {
    final t = await _app.lastSeen(widget.conversation);
    if (mounted && t != null) setState(() => _lastSeen = t);
  }

  @override
  void dispose() {
    _app.closeConversation(widget.conversation);
    _timer?.cancel();
    _typingOff?.cancel();
    _seenTimer?.cancel();
    final link = _typingLink;
    if (link != null) unawaited(link.close());
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

  /// The next upcoming lesson with the other person of this chat (null = none).
  Lesson? _nextLesson(AppState app, Conversation c, bool tutorSide) {
    if (!app.live) return null;
    final now = DateTime.now();
    Lesson? next;
    for (final l in app.lessons) {
      if (l.status != LessonStatus.upcoming || l.start.add(Duration(minutes: l.minutes)).isBefore(now)) continue;
      final same = tutorSide ? (c.counterpartId != null && l.studentId == c.counterpartId) : (c.tutor != null && l.tutor.id == c.tutor!.id);
      if (same && (next == null || l.start.isBefore(next.start))) next = l;
    }
    return next;
  }

  /// Round G1: long-press a message — copy, reply, or delete my own (for both people; the admins keep a copy).
  Future<void> _menu(AppState app, Conversation c, Message m) async {
    if (m.type == MsgType.system || m.hiddenFromMe || m.deleted) return;
    final ar = context.isAr;
    final canCopy = m.type == MsgType.text && m.text.isNotEmpty;
    final canReply = m.remoteId > 0 && !m.failed && !m.blocked;
    final canDelete = m.mine && m.remoteId > 0 && m.type != MsgType.call;
    final pick = await showModalBottomSheet<String>(
      context: context,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (canReply)
            ListTile(leading: const Icon(Icons.reply_rounded), title: Text(ar ? 'ردّ' : 'Reply'), onTap: () => Navigator.pop(s, 'reply')),
          if (canCopy)
            ListTile(leading: const Icon(Icons.copy_rounded), title: Text(ar ? 'نسخ' : 'Copy'), onTap: () => Navigator.pop(s, 'copy')),
          if (canDelete)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: Text(ar ? 'حذف عند الجميع' : 'Delete for everyone', style: const TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(s, 'delete'),
            ),
        ]),
      ),
    );
    if (!mounted || pick == null) return;
    switch (pick) {
      case 'reply':
        setState(() => _replying = m);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.text));
        if (mounted) toast(context, ar ? 'تم النسخ' : 'Copied');
      case 'delete':
        final yes = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(ar ? 'حذف الرسالة؟' : 'Delete the message?'),
            content: Text(ar ? 'ستُحذف عندك وعند الطرف الآخر.' : 'It will be deleted for you and the other person.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
              FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(ar ? 'حذف' : 'Delete')),
            ],
          ),
        );
        if (yes == true) await app.deleteMessage(c, m);
    }
  }

  void _send(AppState app) {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final quote = _replying;
    final ok = app.sendMessage(widget.conversation,
        Message(mine: true, text: text, time: DateTime.now(), replyTo: quote != null && quote.remoteId > 0 ? quote.remoteId : 0));
    if (!ok) {
      toast(context, context.tr('blocked_contact'), icon: Icons.block_rounded);
      return;
    }
    _ctrl.clear();
    if (_replying != null) setState(() => _replying = null);
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
          ListTile(
            leading: const Icon(Icons.description_outlined, color: AppColors.primary),
            title: Text(context.isAr ? 'إرسال ملف (PDF / Word / Excel)' : 'Send a file (PDF / Word / Excel)'),
            onTap: () => Navigator.pop(sheet, 'file'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'file') return _attachFile(app);
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
    var bytes = await f.readAsBytes();
    final video = choice == 'video';
    // Round G2: a big video is made smaller first (with progress and Cancel).
    if (video && VideoShrink.available && bytes.length > VideoShrink.minBytes && f.path.isNotEmpty) {
      final r = await _shrinkVideo(f.path, bytes.length);
      if (r.cancelled || !mounted) return;
      final out = r.path;
      if (out != null) {
        try {
          bytes = await XFile(out).readAsBytes();
        } catch (_) {}
      }
    }
    if (!mounted) return;
    final name = f.name.isNotEmpty ? f.name : (video ? 'video.mp4' : 'photo.jpg');
    final mime = f.mimeType ?? (video ? 'video/mp4' : 'image/jpeg');
    _toBottom();
    await app.sendMedia(widget.conversation, type: video ? MsgType.video : MsgType.image, bytes: bytes, name: name, mime: mime);
    _toBottom();
  }

  /// Round G2: a PDF / Word / Excel / PowerPoint / text file.
  Future<void> _attachFile(AppState app) async {
    PlatformFile? f;
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: docMimes.keys.toList(), withData: true);
      f = res == null || res.files.isEmpty ? null : res.files.first;
    } catch (_) {
      if (mounted) toast(context, context.isAr ? 'تعذّر فتح الملفات' : 'Could not open your files', icon: Icons.error_outline);
      return;
    }
    if (f == null || !mounted) return;
    final ext = (f.extension ?? '').toLowerCase();
    final mime = docMimes[ext];
    final bytes = f.bytes;
    if (mime == null || bytes == null || bytes.isEmpty) {
      toast(context, context.isAr ? 'هذا النوع من الملفات غير مدعوم' : 'This kind of file is not supported', icon: Icons.error_outline);
      return;
    }
    _toBottom();
    await app.sendMedia(widget.conversation, type: MsgType.file, bytes: bytes, name: f.name.isNotEmpty ? f.name : 'file.$ext', mime: mime);
    _toBottom();
  }

  /// Round G2: shrinks a video with a progress window; Cancel stops and sends nothing.
  Future<({bool cancelled, String? path})> _shrinkVideo(String path, int size) async {
    final ar = context.isAr;
    final progress = ValueNotifier<double>(0);
    final cancelled = Completer<String?>();
    var open = true;
    void close() {
      if (open && mounted) Navigator.of(context, rootNavigator: true).pop();
      open = false;
    }

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (d) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(ar ? 'تصغير الفيديو قبل الإرسال…' : 'Making the video smaller…'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
              LinearProgressIndicator(value: v <= 0 ? null : v),
              const SizedBox(height: 10),
              Text(v <= 0 ? '' : '${(v * 100).round()}%'),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!cancelled.isCompleted) cancelled.complete(null);
                unawaited(VideoShrink.cancel());
              },
              child: Text(ar ? 'إلغاء' : 'Cancel'),
            ),
          ],
        ),
      ),
    ));
    final out = await Future.any([VideoShrink.shrink(path, size, (v) => progress.value = v), cancelled.future]);
    close();
    final wasCancelled = cancelled.isCompleted;
    Future<void>.delayed(const Duration(seconds: 1), progress.dispose);
    return (cancelled: wasCancelled, path: wasCancelled ? null : out);
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
              if (_peerTyping)
                Text(context.isAr ? 'يكتب…' : 'typing…', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700))
              else if (lastSeenLabel(_lastSeen, DateTime.now(), ar: context.isAr).isNotEmpty)
                Text(lastSeenLabel(_lastSeen, DateTime.now(), ar: context.isAr),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: DateTime.now().difference(_lastSeen!).inMinutes < 2 ? AppColors.success : AppColors.text3, fontSize: 12))
              else if (c.online)
                Text(context.tr('online_now'), style: const TextStyle(color: AppColors.success, fontSize: 12)),
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
              } else if (v == 'block' || v == 'unblock') {
                final id = c.counterpartId ?? '';
                if (v == 'block') {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      content: Text(context.tr('block_q')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(context.tr('cancel'))),
                        TextButton(onPressed: () => Navigator.pop(d, true), child: Text(context.tr('block_user'), style: const TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  );
                  if (yes != true) return;
                }
                await app.setBlocked(id, v == 'block');
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
              if (app.live && (c.counterpartId ?? '').isNotEmpty)
                PopupMenuItem(
                  key: const Key('block-user'),
                  value: app.isBlocked(c.counterpartId!) ? 'unblock' : 'block',
                  child: Text(context.tr(app.isBlocked(c.counterpartId!) ? 'unblock_user' : 'block_user'), style: const TextStyle(color: AppColors.danger)),
                ),
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
          // Round G1: the next lesson with this person at the top of the chat.
          if (_nextLesson(app, c, isTutorSide) case final next?)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: AppCard(
                key: const Key('chat-next-lesson'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.event_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${context.isAr ? 'الدرس القادم' : 'Next lesson'}: ${next.start.day}/${next.start.month} · ${timeOf(context, next.start)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (next.start.difference(DateTime.now()).inMinutes < 30)
                    FilledButton(onPressed: () => app.joinLesson(next), child: Text(context.tr('join_lesson'))),
                ]),
              ),
            )
          else if (c.tutor != null && !isTutorSide)
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
                    Message? quoted;
                    if (m.replyTo > 0) {
                      for (final x in c.messages) {
                        if (x.remoteId == m.replyTo) quoted = x;
                      }
                    }
                    return _Bubble(
                      key: ValueKey(m.remoteId != 0 ? 'r${m.remoteId}' : identityHashCode(m)),
                      m: m,
                      color: c.color,
                      onRetry: m.failed ? () => app.retryMessage(c, m) : null,
                      quoted: quoted,
                      quotedMissing: m.replyTo > 0 && quoted == null,
                      onLongPress: () => _menu(app, c, m),
                      peer: c.name.of(context),
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
          if (_replying != null)
            Container(
              key: const Key('reply-bar'),
              padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 8),
              decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
              child: Row(children: [
                const Icon(Icons.reply_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: _QuoteText(m: _replying!, peer: c.name.of(context))),
                IconButton(
                  tooltip: context.isAr ? 'إلغاء الرد' : 'Cancel reply',
                  onPressed: () => setState(() => _replying = null),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ]),
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
                            if (_held) ...[
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  _slid ? (context.isAr ? 'اترك للإلغاء' : 'Let go to cancel') : (context.isAr ? '↔ اسحب للإلغاء' : '↔ Slide to cancel'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: _slid ? AppColors.danger : AppColors.text3, fontSize: 12, fontWeight: _slid ? FontWeight.w800 : FontWeight.w500),
                                ),
                              ),
                            ],
                          ]),
                        )
                      : TextField(
                          controller: _ctrl,
                          minLines: 1,
                          maxLines: 4,
                          onChanged: (t) {
                            setState(() {});
                            if (t.trim().isNotEmpty) {
                              _linkTyping(); // a new chat gets its id with the first message
                              _typingLink?.typing();
                            }
                          },
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
                GestureDetector(
                  // Round G2: hold to record, let go to send, slide away to cancel (a tap still works as before)
                  onLongPressStart: (_) {
                    if (_ctrl.text.trim().isNotEmpty || _recording) return;
                    _held = true;
                    _slid = false;
                    _holdStart = _toggleVoice(app);
                  },
                  onLongPressMoveUpdate: (d) {
                    if (!_held) return;
                    final slid = d.offsetFromOrigin.dx.abs() > 80;
                    if (slid != _slid) setState(() => _slid = slid);
                  },
                  onLongPressEnd: (_) async {
                    if (!_held) return;
                    await _holdStart;
                    _held = false;
                    if (!mounted || !_recording) return;
                    if (_slid) {
                      setState(() => _slid = false);
                      await _cancelVoice();
                    } else {
                      await _toggleVoice(app);
                    }
                  },
                  child: CircleAvatar(
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
  final Message? quoted; // Round G1: the message this one answers
  final bool quotedMissing; // it answers a message not loaded here
  final VoidCallback? onLongPress;
  final String peer;
  const _Bubble({super.key, required this.m, required this.color, this.onRetry, this.quoted, this.quotedMissing = false, this.onLongPress, this.peer = ''});

  @override
  Widget build(BuildContext context) => GestureDetector(onLongPress: onLongPress, child: _build(context));

  Widget _build(BuildContext context) {
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
    if (m.deleted) {
      content = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.block_rounded, size: 16, color: fg.withOpacity(0.7)),
        const SizedBox(width: 6),
        Text(context.isAr ? 'تم حذف هذه الرسالة' : 'This message was deleted',
            style: TextStyle(color: fg.withOpacity(0.8), fontStyle: FontStyle.italic)),
      ]);
    } else {
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
              _JoinButton(mine: m.mine, label: context.tr(meet ? 'join_meeting' : 'join_call'), onTap: () => _join(context, inv.room, inv.video, direct: !meet)),
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
        content = ChatFile(m: m);
        break;
      default:
        final meetLink = Calls.fromUrl(m.text);
        final url = meetLink == null ? RegExp(r'https?://[^\s]+').firstMatch(m.text)?.group(0) : null;
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(m.text, textDirection: directionOf(m.text), style: TextStyle(color: fg, height: 1.5)),
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
            if (!m.deleted && (quoted != null || quotedMissing))
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
                decoration: BoxDecoration(
                  color: (m.mine ? Colors.white : AppColors.primary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: BorderDirectional(start: BorderSide(color: m.mine ? Colors.white70 : AppColors.primary, width: 3)),
                ),
                child: quoted != null
                    ? _QuoteText(m: quoted!, color: fg, peer: peer)
                    : Text(context.isAr ? 'رسالة سابقة' : 'An earlier message', style: TextStyle(color: fg.withOpacity(0.8), fontSize: 12.5)),
              ),
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

void _join(BuildContext context, String room, bool video, {bool direct = false}) {
  final app = context.read<AppState>();
  final c = app.activeConversation;
  app.joinCall(room: room, video: video, peer: c == null ? '' : c.name.of(context), direct: direct);
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

/// Round G1: a one-line preview of a quoted message.
class _QuoteText extends StatelessWidget {
  final Message m;
  final Color? color;
  final String peer;
  const _QuoteText({required this.m, this.color, this.peer = ''});
  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final who = m.mine ? (ar ? 'أنت' : 'You') : (peer.isNotEmpty ? peer : (ar ? 'الطرف الآخر' : 'Them'));
    final what = m.deleted
        ? (ar ? 'رسالة محذوفة' : 'Deleted message')
        : switch (m.type) {
            MsgType.voice => ar ? '🎤 رسالة صوتية' : '🎤 Voice message',
            MsgType.image => ar ? '📷 صورة' : '📷 Photo',
            MsgType.video => ar ? '🎬 فيديو' : '🎬 Video',
            MsgType.file => '📎 ${fileLabel(m, ar: ar)}',
            _ => m.text,
          };
    final c = color ?? AppColors.ink;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(who, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12)),
      Text(what, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.withOpacity(0.85), fontSize: 12.5)),
    ]);
  }
}
