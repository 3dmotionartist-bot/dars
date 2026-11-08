import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../theme.dart';

/// Full-screen "incoming call" page (shown while the phone rings).
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.name,
    required this.video,
    required this.onAccept,
    required this.onDecline,
    this.onTimeout,
  });

  final String name;
  final bool video;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onTimeout;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  Timer? _timeout;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 45), () => _finish(widget.onTimeout ?? widget.onDecline));
  }

  void _finish(VoidCallback action) {
    if (_done) return;
    _done = true;
    _timeout?.cancel();
    action();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.trim().isEmpty ? 'د' : widget.name.trim().characters.first;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(widget.onDecline);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(44),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.5 * (1 - _pulse.value)),
                        blurRadius: 0,
                        spreadRadius: 34 * _pulse.value,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(44),
                    gradient: const LinearGradient(colors: [Color(0xFF13B39E), AppColors.primary]),
                  ),
                  child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 28),
              Text(widget.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.video ? Icons.videocam_rounded : Icons.call_rounded, color: const Color(0xFF9FB0C8), size: 20),
                  const SizedBox(width: 6),
                  Text(context.tr(widget.video ? 'incoming_video' : 'incoming_voice'), style: const TextStyle(color: Color(0xFF9FB0C8), fontSize: 17)),
                ],
              ),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundButton(
                      color: AppColors.danger,
                      icon: Icons.call_end_rounded,
                      label: context.tr('decline'),
                      onTap: () => _finish(widget.onDecline),
                    ),
                    _RoundButton(
                      color: AppColors.success,
                      icon: widget.video ? Icons.videocam_rounded : Icons.call_rounded,
                      label: context.tr('answer'),
                      onTap: () => _finish(widget.onAccept),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.color, required this.icon, required this.label, required this.onTap});
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 74, height: 74, child: Icon(icon, color: Colors.white, size: 34)),
            ),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      );
}
