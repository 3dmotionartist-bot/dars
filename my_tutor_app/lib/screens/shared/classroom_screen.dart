import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Built-in lesson room (improvement over Modarby, which pastes external links).
/// Layout only — plug in LiveKit / Agora / Jitsi for real video, plus a whiteboard SDK.
class ClassroomScreen extends StatefulWidget {
  final Lesson lesson;
  const ClassroomScreen({super.key, required this.lesson});
  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  bool _mic = true;
  bool _cam = true;
  bool _board = false;
  int _secs = 0;
  Timer? _timer;
  final List<Offset?> _points = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secs++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final stage = _board
        ? Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: GestureDetector(
              onPanUpdate: (d) => setState(() => _points.add(d.localPosition)),
              onPanEnd: (_) => _points.add(null),
              child: ClipRRect(borderRadius: BorderRadius.circular(18), child: CustomPaint(painter: _BoardPainter(_points), size: Size.infinite)),
            ),
          )
        : Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: [l.tutor.color.withOpacity(0.7), const Color(0xFF0B1324)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Center(child: Avatar(name: l.tutor.name, color: l.tutor.color, size: 110)),
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0B1324),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1324),
        foregroundColor: Colors.white,
        title: Text('${l.subject.of(context)} · ${two(_secs ~/ 60)}:${two(_secs % 60)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          if (_board) IconButton(onPressed: () => setState(_points.clear), icon: const Icon(Icons.delete_sweep_outlined)),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(child: stage),
        PositionedDirectional(
          top: 24,
          end: 24,
          child: Container(
            width: 110,
            height: 150,
            decoration: BoxDecoration(color: const Color(0xFF1C2740), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
            child: Center(child: Icon(_cam ? Icons.person_rounded : Icons.videocam_off_rounded, color: Colors.white54, size: 44)),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _ctrl(_mic ? Icons.mic_rounded : Icons.mic_off_rounded, () => setState(() => _mic = !_mic), active: _mic),
            _ctrl(_cam ? Icons.videocam_rounded : Icons.videocam_off_rounded, () => setState(() => _cam = !_cam), active: _cam),
            _ctrl(Icons.draw_rounded, () => setState(() => _board = !_board), active: _board),
            _ctrl(Icons.screen_share_rounded, () => toast(context, context.isAr ? 'مشاركة الشاشة' : 'Screen share'), active: false),
            _ctrl(Icons.call_end_rounded, () => Navigator.pop(context), danger: true),
          ]),
        ),
      ),
    );
  }

  Widget _ctrl(IconData icon, VoidCallback onTap, {bool active = true, bool danger = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Material(
          color: danger ? AppColors.danger : (active ? const Color(0xFF26324D) : Colors.white),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 54, height: 54, child: Icon(icon, color: danger || active ? Colors.white : AppColors.ink)),
          ),
        ),
      );
}

class _BoardPainter extends CustomPainter {
  final List<Offset?> points;
  _BoardPainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a != null && b != null) canvas.drawLine(a, b, p);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
