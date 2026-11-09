import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/chat_screen.dart';

/// Tutor: every student who booked so far and where things stand with each one.
class MyStudentsScreen extends StatelessWidget {
  const MyStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.myStudents;
    final active = list.where((s) => s.next != null).length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(context.tr('my_students'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: app.refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: list.isEmpty
          ? EmptyState(icon: Icons.groups_outlined, title: context.tr('no_students_yet'), body: context.tr('no_students_body'))
          : MaxWidth(
              max: 820,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  _total(context, '${list.length}', context.tr('students_total'), AppColors.primary),
                  const SizedBox(width: 10),
                  _total(context, '$active', context.tr('students_active'), AppColors.success),
                  const SizedBox(width: 10),
                  _total(context, money(list.fold(0.0, (s, x) => s + x.earned).round()), context.tr('earned'), AppColors.accent),
                ]),
                const SizedBox(height: 14),
                for (final s in list) ...[_StudentCard(s: s), const SizedBox(height: 10)],
              ]),
            ),
    );
  }

  Widget _total(BuildContext context, String v, String label, Color c) => Expanded(
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(children: [
            Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text2, fontSize: 12.5)),
          ]),
        ),
      );
}

class _StudentCard extends StatelessWidget {
  final StudentSummary s;
  const _StudentCard({required this.s});

  ({String text, Color fg, Color bg}) _state(BuildContext context) {
    if (s.pendingPayment > 0) return (text: context.tr('st_awaiting_payment'), fg: const Color(0xFFB7791F), bg: AppColors.accentSoft);
    if (s.next != null) return (text: context.tr('st_active'), fg: AppColors.success, bg: const Color(0xFFE7F7EE));
    if (s.completed > 0) return (text: context.tr('st_no_upcoming'), fg: AppColors.info, bg: AppColors.infoSoft);
    return (text: context.tr('st_cancelled'), fg: AppColors.danger, bg: AppColors.dangerSoft);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final st = _state(context);
    final color = AppColors.primary;
    return AppCard(
      onTap: () => _details(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(name: s.name, color: color, size: 48, photo: app.photoOf(s.id)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name.of(context), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Pill(st.text, bg: st.bg, fg: st.fg),
            ]),
          ),
          if (app.live && s.id.length > 20)
            IconButton(
              tooltip: context.tr('message'),
              onPressed: () async {
                final c = await app.chatWithStudent(s.id, s.name);
                if (c != null && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
            ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip(Icons.check_circle_outline_rounded, '${s.completed} ${context.tr('st_done')}', AppColors.success),
          _chip(Icons.event_rounded, '${s.upcoming} ${context.tr('st_upcoming')}', AppColors.primary),
          if (s.pendingPayment > 0) _chip(Icons.hourglass_top_rounded, '${s.pendingPayment} ${context.tr('st_unpaid')}', const Color(0xFFB7791F)),
          if (s.cancelled > 0) _chip(Icons.cancel_outlined, '${s.cancelled} ${context.tr('st_cancelled_n')}', AppColors.danger),
          _chip(Icons.payments_outlined, money(s.earned.round()), AppColors.text2),
        ]),
        const SizedBox(height: 10),
        if (s.next != null)
          Text('${context.tr('st_next')}: ${s.next!.subject.of(context)} · ${dayOf(context, s.next!.start)} ${timeOf(context, s.next!.start)}',
              style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
        if (s.last != null)
          Text('${context.tr('st_last')}: ${dayOf(context, s.last!.start)}', style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
      ]),
    );
  }

  Widget _chip(IconData icon, String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withOpacity(0.09), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      );

  void _details(BuildContext context) {
    final lessons = [...s.lessons]..sort((a, b) => b.start.compareTo(a.start));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
          Text(s.name.of(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${lessons.length} ${context.tr('lessons_word')}', style: const TextStyle(color: AppColors.text2)),
          const SizedBox(height: 12),
          for (final l in lessons)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_icon(l.status), color: _color(l.status)),
              title: Text('${l.subject.of(context)} · ${l.minutes} ${context.tr('minutes_short')}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${dayOf(context, l.start)} ${timeOf(context, l.start)}'),
              trailing: Text(context.tr(_status(l.status)), style: TextStyle(color: _color(l.status), fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
        ]),
      ),
    );
  }

  static IconData _icon(LessonStatus s) => switch (s) {
        LessonStatus.upcoming => Icons.event_available_rounded,
        LessonStatus.pending => Icons.hourglass_top_rounded,
        LessonStatus.delivered => Icons.check_circle_rounded,
        LessonStatus.cancelled => Icons.cancel_rounded,
      };
  static Color _color(LessonStatus s) => switch (s) {
        LessonStatus.upcoming => AppColors.primary,
        LessonStatus.pending => const Color(0xFFB7791F),
        LessonStatus.delivered => AppColors.success,
        LessonStatus.cancelled => AppColors.danger,
      };
  static String _status(LessonStatus s) => switch (s) {
        LessonStatus.upcoming => 'status_confirmed',
        LessonStatus.pending => 'status_pending',
        LessonStatus.delivered => 'status_delivered',
        LessonStatus.cancelled => 'status_cancelled',
      };
}
