import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/doc_open.dart';
import 'package:video_player/video_player.dart';

import '../data/models.dart';
import '../l10n.dart';
import '../services/media_bridge.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

String _clock(int secs) => '${secs ~/ 60}:${two(secs % 60)}';

/// Voice note in a chat bubble: tap to play / stop, tap or drag the bars to jump, 1× / 1.5× / 2×.
class VoiceNote extends StatefulWidget {
  final Message m;
  const VoiceNote({super.key, required this.m});
  @override
  State<VoiceNote> createState() => _VoiceNoteState();
}

/// Round G2: the bar heights of a voice note differ from note to note (6..22), always the same for one note.
double voiceBarHeight(String key, int i) {
  var h = 0x811c9dc5;
  for (final c in '$key#$i'.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return 6.0 + (h % 17);
}

/// Round G2: the next voice-note speed after [r] (1 → 1.5 → 2 → 1).
double nextVoiceSpeed(double r) => r < 1.25 ? 1.5 : (r < 1.75 ? 2 : 1);

class _VoiceNoteState extends State<VoiceNote> {
  static _VoiceNoteState? _playing; // only one voice note plays at a time
  static double _rate = 1; // the speed is kept for the next voice notes too
  bool _busy = false;
  bool _on = false;
  int _pos = 0; // ms
  int _len = 0; // ms
  Timer? _tick;

  int get _total => widget.m.seconds > 0 ? widget.m.seconds : 1;
  int get _lenMs => _len > 0 ? _len : _total * 1000;

  Future<void> _toggle({double? jumpTo}) async {
    if (_on) {
      if (jumpTo != null) return _seek(jumpTo);
      return _stop();
    }
    if (widget.m.url.isEmpty || _busy) return;
    _playing?._stop();
    setState(() => _busy = true);
    final url = await context.read<AppState>().mediaUrl(widget.m.url);
    final ms = url.isEmpty ? -1 : await MediaBridge.play(url);
    if (!mounted) return;
    if (ms < 0) {
      setState(() => _busy = false);
      toast(context, context.isAr ? 'تعذّر تشغيل الرسالة الصوتية' : 'Could not play this voice note', icon: Icons.error_outline);
      return;
    }
    _playing = this;
    if (_rate != 1) unawaited(MediaBridge.speed(_rate));
    setState(() {
      _busy = false;
      _on = true;
      _pos = 0;
      _len = ms;
    });
    if (jumpTo != null) unawaited(_seek(jumpTo));
    var misses = 0;
    _tick = Timer.periodic(const Duration(milliseconds: 250), (t) async {
      if (!mounted) return t.cancel();
      final p = await MediaBridge.position();
      if (!mounted || !_on) return;
      if (p == null) {
        if (++misses >= 2) _stop(silent: true); // finished
        return;
      }
      misses = 0;
      setState(() {
        _pos = p[0];
        if (p[1] > 0) _len = p[1];
      });
    });
  }

  Future<void> _seek(double fraction) async {
    final ms = (fraction.clamp(0.0, 1.0) * _lenMs).round();
    setState(() => _pos = ms);
    await MediaBridge.seek(ms);
  }

  void _cycleSpeed() {
    setState(() => _rate = nextVoiceSpeed(_rate));
    if (_on) unawaited(MediaBridge.speed(_rate));
  }

  void _stop({bool silent = false}) {
    _tick?.cancel();
    if (!silent) MediaBridge.stopPlaying();
    if (identical(_playing, this)) _playing = null;
    if (mounted) {
      setState(() {
        _on = false;
        _pos = 0;
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (_on) {
      MediaBridge.stopPlaying();
      if (identical(_playing, this)) _playing = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final fg = m.mine ? Colors.white : AppColors.ink;
    final accent = m.mine ? Colors.white : AppColors.primary;
    final progress = _on ? (_pos / _lenMs).clamp(0.0, 1.0) : 0.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const bars = 18;
    const barsWidth = bars * 5.0;
    double fractionAt(double dx) {
      final f = (dx / barsWidth).clamp(0.0, 1.0);
      return rtl ? 1 - f : f;
    }

    final left = _on ? ((_lenMs - _pos) / 1000).ceil() : _total;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 36,
        height: 36,
        child: m.sending || _busy
            ? Padding(padding: const EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2.4, color: accent))
            : IconButton(
                padding: EdgeInsets.zero,
                onPressed: _toggle,
                icon: Icon(_on ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: accent, size: 34),
              ),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: m.sending ? null : (d) => _toggle(jumpTo: fractionAt(d.localPosition.dx)),
        onHorizontalDragUpdate: _on ? (d) => setState(() => _pos = (fractionAt(d.localPosition.dx) * _lenMs).round()) : null,
        onHorizontalDragEnd: _on ? (_) => MediaBridge.seek(_pos) : null,
        child: SizedBox(
          width: barsWidth,
          height: 36,
          child: Row(children: [
            for (int i = 0; i < bars; i++)
              Container(
                width: 3,
                height: voiceBarHeight(m.url.isNotEmpty ? m.url : '${m.remoteId}', i),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: (i / bars) < progress ? accent : fg.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Text(_clock(left < 0 ? 0 : left), style: TextStyle(color: fg, fontSize: 12)),
      const SizedBox(width: 6),
      InkWell(
        onTap: _cycleSpeed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: fg.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Text('${_rate == 1.5 ? '1.5' : _rate.toInt()}×', style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ),
      ),
    ]);
  }
}

/// Round G2: a document in a chat bubble (PDF / Word / Excel / PowerPoint / text): tap to open it.
class ChatFile extends StatefulWidget {
  final Message m;
  const ChatFile({super.key, required this.m});
  @override
  State<ChatFile> createState() => _ChatFileState();
}

class _ChatFileState extends State<ChatFile> {
  bool _opening = false;

  Future<void> _open() async {
    final m = widget.m;
    if (m.url.isEmpty || _opening) return;
    setState(() => _opening = true);
    final url = await context.read<AppState>().mediaUrl(m.url);
    var ok = false;
    if (url.isNotEmpty) {
      // On the phone: download and open in a viewer app (a browser only downloads it).
      try {
        ok = await openDocument(url, docFileName(m), docMimes[docExt(m.url)] ?? 'application/octet-stream');
      } catch (_) {
        ok = false;
      }
      if (!ok) {
        try {
          ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {
          ok = false;
        }
      }
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!ok) toast(context, context.isAr ? 'تعذّر فتح الملف' : 'Could not open the file', icon: Icons.error_outline);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final fg = m.mine ? Colors.white : AppColors.ink;
    final kind = docKind(m.text != '📎' && m.text.isNotEmpty ? m.text : m.url);
    final icon = switch (kind) {
      'PDF' => Icons.picture_as_pdf_rounded,
      'Excel' => Icons.table_chart_rounded,
      'PowerPoint' => Icons.slideshow_rounded,
      _ => Icons.description_rounded,
    };
    return InkWell(
      onTap: m.sending ? null : _open,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 30,
            height: 30,
            child: m.sending || _opening
                ? Padding(padding: const EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
                : Icon(icon, color: fg, size: 28),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(fileLabel(m, ar: context.isAr), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
              Text(context.isAr ? 'اضغط للفتح' : 'Tap to open', style: TextStyle(color: fg.withOpacity(0.7), fontSize: 11.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A spinner while a photo downloads (the bubble used to stay blank).
Widget _loading(BuildContext context, Widget child, ImageChunkEvent? p) => p == null
    ? child
    : Container(
        color: Colors.black12,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            value: p.expectedTotalBytes == null ? null : p.cumulativeBytesLoaded / p.expectedTotalBytes!,
          ),
        ),
      );

/// Photo in a chat bubble (tap to open full screen).
class ChatImage extends StatelessWidget {
  final Message m;
  const ChatImage({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    final local = m.bytes;
    final Widget img = local != null
        ? Image.memory(local, fit: BoxFit.cover)
        : FutureBuilder<String>(
            future: context.read<AppState>().mediaUrl(m.url),
            builder: (_, s) => (s.data ?? '').isEmpty
                ? Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
                : Image.network(s.data!, fit: BoxFit.cover, loadingBuilder: _loading, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))),
          );
    return GestureDetector(
      onTap: m.url.isEmpty && local == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoViewer(m: m))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(fit: StackFit.expand, children: [
            img,
            if (m.sending)
              Container(color: Colors.black38, child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))),
          ]),
        ),
      ),
    );
  }
}

class PhotoViewer extends StatelessWidget {
  final Message m;
  const PhotoViewer({super.key, required this.m});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: m.bytes != null
                ? Image.memory(m.bytes!)
                : FutureBuilder<String>(
                    future: context.read<AppState>().mediaUrl(m.url),
                    builder: (_, s) => (s.data ?? '').isEmpty ? const CircularProgressIndicator(color: Colors.white) : Image.network(s.data!, loadingBuilder: _loading),
                  ),
          ),
        ),
      );
}

/// Video in a chat bubble (tap to play inside the app).
class ChatVideo extends StatelessWidget {
  final Message m;
  const ChatVideo({super.key, required this.m});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: m.url.isEmpty
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(stored: m.url, title: m.text))),
        child: Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(color: const Color(0xFF0B1220), borderRadius: BorderRadius.circular(12)),
          child: Stack(alignment: Alignment.center, children: [
            m.sending
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)
                : Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, size: 36, color: AppColors.primary),
                  ),
            PositionedDirectional(
              bottom: 8,
              start: 10,
              end: 10,
              child: Text(m.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ]),
        ),
      );
}

/// Plays a video inside the app. [stored] is "<bucket>/<path>" or a full https link.
class VideoPlayerScreen extends StatefulWidget {
  final String stored;
  final String title;
  const VideoPlayerScreen({super.key, required this.stored, this.title = ''});
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _c;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final url = await context.read<AppState>().mediaUrl(widget.stored);
    if (url.isEmpty) {
      setState(() => _error = 'x');
      return;
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await c.initialize();
      if (!mounted) return c.dispose();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      await c.play();
      setState(() => _c = c);
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _error = 'x');
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.title, style: const TextStyle(fontSize: 15))),
      body: Center(
        child: _error.isNotEmpty
            ? Text(context.isAr ? 'تعذّر تشغيل الفيديو' : 'Could not play this video', style: const TextStyle(color: Colors.white70))
            : c == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: AspectRatio(aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio, child: VideoPlayer(c))),
                    const SizedBox(height: 8),
                    VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(
                        iconSize: 46,
                        color: Colors.white,
                        onPressed: () => c.value.isPlaying ? c.pause() : c.play(),
                        icon: Icon(c.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                      ),
                      Text('${_clock(c.value.position.inSeconds)} / ${_clock(c.value.duration.inSeconds)}', style: const TextStyle(color: Colors.white70)),
                    ]),
                  ]),
      ),
    );
  }
}
