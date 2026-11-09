import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../data/models.dart';
import '../l10n.dart';
import '../services/media_bridge.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

String _clock(int secs) => '${secs ~/ 60}:${two(secs % 60)}';

/// Voice note in a chat bubble: tap to play / stop.
class VoiceNote extends StatefulWidget {
  final Message m;
  const VoiceNote({super.key, required this.m});
  @override
  State<VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<VoiceNote> {
  static _VoiceNoteState? _playing; // only one voice note plays at a time
  bool _busy = false;
  bool _on = false;
  int _left = 0;
  Timer? _tick;

  int get _total => widget.m.seconds > 0 ? widget.m.seconds : 1;

  Future<void> _toggle() async {
    if (_on) return _stop();
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
    final secs = ms > 0 ? (ms / 1000).ceil() : _total;
    setState(() {
      _busy = false;
      _on = true;
      _left = secs;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_left <= 1) {
        _stop(silent: true);
      } else {
        setState(() => _left--);
      }
    });
  }

  void _stop({bool silent = false}) {
    _tick?.cancel();
    if (!silent) MediaBridge.stopPlaying();
    if (identical(_playing, this)) _playing = null;
    if (mounted) setState(() => _on = false);
  }

  @override
  void dispose() {
    if (_on) {
      _tick?.cancel();
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
    final progress = _on ? 1 - (_left / _total).clamp(0.0, 1.0) : 0.0;
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
      for (int i = 0; i < 18; i++)
        Container(
          width: 3,
          height: 6.0 + (i * 7 % 17),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: (i / 18) < progress ? accent : fg.withOpacity(0.45),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      const SizedBox(width: 8),
      Text(_clock(_on ? _left : _total), style: TextStyle(color: fg, fontSize: 12)),
    ]);
  }
}

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
                : Image.network(s.data!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))),
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
                    builder: (_, s) => (s.data ?? '').isEmpty ? const CircularProgressIndicator(color: Colors.white) : Image.network(s.data!),
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
