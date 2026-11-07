import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// In-app voice call UI (ringing → connected timer, mute, speaker, end).
/// Wire to WebRTC / Agora / LiveKit + CallKit / ConnectionService in production.
class CallScreen extends StatefulWidget {
  final L name;
  final Color color;
  const CallScreen({super.key, required this.name, required this.color});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  int _secs = -3; // negative = ringing
  bool _mute = false;
  bool _speaker = false;
  Timer? _timer;

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
    final status = _secs < 0 ? context.tr('ringing') : '${two(_secs ~/ 60)}:${two(_secs % 60)}';
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [widget.color, AppColors.ink]),
        ),
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const DarsLogo(size: 26, light: true),
              const SizedBox(width: 8),
              Text(context.tr('app_name'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
            const Spacer(),
            Avatar(name: widget.name, color: Colors.white24, size: 120),
            const SizedBox(height: 18),
            Text(widget.name.of(context), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(status, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 18)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.fiber_manual_record_rounded, color: AppColors.danger, size: 12),
              const SizedBox(width: 6),
              Text(context.tr('call_recorded'), style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12.5)),
            ]),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _btn(_mute ? Icons.mic_off_rounded : Icons.mic_rounded, context.tr('mute'), _mute, () => setState(() => _mute = !_mute)),
              _btn(Icons.call_end_rounded, context.tr('end_call'), false, () => Navigator.pop(context), danger: true),
              _btn(_speaker ? Icons.volume_up_rounded : Icons.volume_down_rounded, context.tr('speaker'), _speaker, () => setState(() => _speaker = !_speaker)),
            ]),
            const SizedBox(height: 48),
          ]),
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String label, bool active, VoidCallback onTap, {bool danger = false}) => Column(children: [
        Material(
          color: danger ? AppColors.danger : (active ? Colors.white : const Color(0x33FFFFFF)),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: danger ? 76 : 64, height: danger ? 76 : 64, child: Icon(icon, color: danger ? Colors.white : (active ? AppColors.ink : Colors.white), size: 30)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ]);
}
