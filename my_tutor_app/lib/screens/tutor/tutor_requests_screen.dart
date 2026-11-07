import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/chat_screen.dart';

/// Incoming "real-time" help requests: student's text / voice, countdown, Accept / Decline.
class TutorRequestsScreen extends StatefulWidget {
  const TutorRequestsScreen({super.key});
  @override
  State<TutorRequestsScreen> createState() => _TutorRequestsScreenState();
}

class _TutorRequestsScreenState extends State<TutorRequestsScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.tutorAvailable ? app.liveRequests : <LiveRequest>[];

    return SafeArea(
      child: MaxWidth(
        max: 760,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Expanded(child: Text(context.tr('incoming_requests'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              Switch(value: app.tutorAvailable, activeColor: AppColors.primary, onChanged: app.setAvailable),
            ]),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(icon: Icons.notifications_paused_outlined, title: context.tr('no_requests'), body: context.tr('no_requests_b'))
                : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                    for (final r in items) _card(context, app, r),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _card(BuildContext context, AppState app, LiveRequest r) {
    final left = (120 - DateTime.now().difference(r.created).inSeconds).clamp(0, 120).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        borderColor: AppColors.accent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(name: r.studentName, color: r.color, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.studentName.of(context), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('${r.subject.of(context)} · ${r.level.of(context)}', style: const TextStyle(color: AppColors.text2, fontSize: 13)),
              ]),
            ),
            Column(children: [
              Text('${left ~/ 60}:${two(left % 60)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: left < 30 ? AppColors.danger : AppColors.ink)),
              Text(context.tr('expires_in'), style: const TextStyle(fontSize: 11, color: AppColors.text3)),
            ]),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: r.text.isNotEmpty
                ? Text(r.text, style: const TextStyle(height: 1.6))
                : Row(children: [
                    const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 30),
                    const SizedBox(width: 8),
                    Expanded(child: LinearProgressIndicator(value: 0, backgroundColor: AppColors.line, color: AppColors.primary, minHeight: 4)),
                    const SizedBox(width: 8),
                    Text('0:${two(r.voiceSeconds)}'),
                  ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.line)),
                onPressed: () => app.declineRequest(r),
                child: Text(context.tr('decline')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: () {
                  final c = app.acceptRequest(r, context.tr('accepted_msg'));
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(context.tr('accept')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
