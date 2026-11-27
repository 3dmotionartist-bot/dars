import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/chat_screen.dart';
import '../shared/classroom_screen.dart';
import 'booking_screen.dart';

/// My lessons: Upcoming · Pending payment · Past · Packages — with Join / Reschedule / Cancel / Review / Report.
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final up = app.lessons.where((l) => l.status == LessonStatus.upcoming).toList()..sort((a, b) => a.start.compareTo(b.start));
    final pending = app.lessons.where((l) => l.status == LessonStatus.pending).toList();
    final past = app.lessons.where((l) => l.status == LessonStatus.delivered || l.status == LessonStatus.cancelled).toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    return DefaultTabController(
      length: 4,
      child: SafeArea(
        child: MaxWidth(
          max: 900,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (MediaQuery.of(context).size.width < 900)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(context.tr('lessons_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.text2,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
              tabs: [
                Tab(text: '${context.tr('tab_upcoming')} (${up.length})'),
                Tab(text: '${context.tr('tab_pending')} (${pending.length})'),
                Tab(text: context.tr('tab_past')),
                Tab(text: context.tr('tab_packages')),
              ],
            ),
            Expanded(
              child: TabBarView(children: [
                _list(context, up),
                _list(context, pending, note: context.tr('pending_note')),
                _list(context, past),
                _packages(context, app),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<Lesson> items, {String? note}) {
    if (items.isEmpty) {
      return EmptyState(icon: Icons.event_note_rounded, title: context.tr('no_lessons'), body: context.tr('no_lessons_b'));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (note != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            const Icon(Icons.schedule_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 6),
            Expanded(child: Text(note, style: const TextStyle(color: AppColors.text2, fontSize: 13))),
          ]),
        ),
      for (final l in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: LessonCard(lesson: l)),
    ]);
  }

  Widget _packages(BuildContext context, AppState app) {
    if (app.packages.isEmpty) {
      return EmptyState(icon: Icons.card_giftcard_rounded, title: context.tr('packages'), body: context.tr('packages_hint'));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final p in app.packages)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(name: p.tutor.name, color: p.tutor.color, size: 46, photo: p.tutor.photoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    VerifiedName(p.tutor.name.of(context), size: 15, verified: !p.tutor.stub),
                    Text('#${p.id} · ${p.totalHours} ${context.tr('hours')} · -${p.discount}%', style: const TextStyle(color: AppColors.text3, fontSize: 13)),
                  ]),
                ),
                Pill(p.active && p.remaining > 0 ? context.tr('pkg_active') : context.tr('pkg_expired'),
                    bg: p.active && p.remaining > 0 ? AppColors.successSoft : AppColors.surface, fg: p.active && p.remaining > 0 ? AppColors.success : AppColors.text3),
              ]),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: p.usedHours / p.totalHours, minHeight: 9, backgroundColor: AppColors.primarySoft, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Text('${p.remaining.toStringAsFixed(p.remaining % 1 == 0 ? 0 : 1)} ${context.tr('pkg_remaining')}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(money(p.price), style: const TextStyle(color: AppColors.text2)),
              ]),
              if (p.active && p.remaining > 0) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () async {
                      if (!app.live) {
                        app.usePackageHour(p, 1);
                        toast(context, '${context.tr('success_t')} · ${p.tutor.name.of(context)}');
                        return;
                      }
                      // Round F: only the tutor's free times, like a normal booking
                      final start = await pickPackageTime(context, app, p.tutor);
                      if (start == null) return;
                      app.usePackageHour(p, 1, start: start);
                    },
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(context.tr('pkg_book_from')),
                  ),
                ),
              ],
            ]),
          ),
        ),
    ]);
  }
}

class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final bool tutorView;
  const LessonCard({super.key, required this.lesson, this.tutorView = false});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final l = lesson;
    final (String statusText, Color fg, Color bg) = switch (l.status) {
      LessonStatus.upcoming => (context.tr('status_confirmed'), AppColors.info, AppColors.infoSoft),
      LessonStatus.pending => (context.tr('status_pending'), const Color(0xFFB7791F), AppColors.accentSoft),
      LessonStatus.delivered => (context.tr('status_delivered'), AppColors.success, AppColors.successSoft),
      LessonStatus.cancelled => (context.tr('status_cancelled'), AppColors.danger, AppColors.dangerSoft),
    };
    // Round F: no-show and disputed lessons have their own labels
    final (String st, Color sfg, Color sbg) = switch (l.state) {
      'no_show' => (context.isAr ? 'غياب' : 'No-show', AppColors.danger, AppColors.dangerSoft),
      'disputed' => (context.isAr ? 'قيد المراجعة' : 'Under review', const Color(0xFFB7791F), AppColors.accentSoft),
      _ => (statusText, fg, bg),
    };
    final soon = l.status == LessonStatus.upcoming && l.start.difference(DateTime.now()).inMinutes < 60 * 6;
    final who = tutorView ? l.studentName : l.tutor.name;

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('${l.start.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
              Text(timeOf(context, l.start), style: const TextStyle(fontSize: 10.5, color: AppColors.text2)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.subject.of(context), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              Text('${context.tr('with')} ${who.of(context)}', style: const TextStyle(color: AppColors.text2, fontSize: 13)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                Pill(st, bg: sbg, fg: sfg),
                Pill('${l.minutes} ${context.tr('min')}', bg: AppColors.surface, fg: AppColors.text2, icon: Icons.timer_outlined),
                Pill(l.online ? context.tr('online') : context.tr('in_person'), bg: AppColors.surface, fg: AppColors.text2, icon: l.online ? Icons.videocam_outlined : Icons.home_outlined),
                if (l.childName.isNotEmpty) Pill('${context.tr('for_child')} ${l.childName}', bg: AppColors.accentSoft, fg: AppColors.accent, icon: Icons.child_care_rounded),
                if (l.isTrial) Pill(context.isAr ? 'درس تجريبي' : 'Trial', bg: AppColors.accentSoft, fg: AppColors.accent, icon: Icons.emoji_objects_rounded),
              ]),
              // Round H5: the tutor's short summary of the lesson.
              if (l.summary.isNotEmpty)
                Container(
                  key: Key('summary-${l.id}'),
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.isAr ? 'ملخص الدرس' : 'Lesson summary', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    Text(l.summary, style: const TextStyle(color: AppColors.text2, height: 1.4)),
                  ]),
                ),
            ]),
          ),
          Text(money(l.price), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: _actions(context, app, soon)),
      ]),
    );
  }

  List<Widget> _actions(BuildContext context, AppState app, bool soon) {
    final l = lesson;
    Widget btn(String label, IconData icon, VoidCallback onTap, {bool primary = false, Color? color}) => primary
        ? ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label))
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: color ?? AppColors.ink, side: BorderSide(color: color ?? AppColors.line)),
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );

    void chat() {
      final c = app.conversationFor(l.tutor);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
    }

    switch (l.status) {
      case LessonStatus.upcoming:
        if (tutorView) return [];
        return [
          btn(context.tr('join_lesson'), Icons.videocam_rounded, () => app.live ? app.joinLesson(l) : Navigator.push(context, MaterialPageRoute(builder: (_) => ClassroomScreen(lesson: l))), primary: soon),
          btn(context.tr('message_tutor'), Icons.chat_bubble_outline_rounded, chat),
          btn(context.tr('reschedule'), Icons.edit_calendar_rounded, () async {
            final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)), initialDate: l.start.isAfter(DateTime.now()) ? l.start : DateTime.now());
            if (d != null) app.reschedule(l, DateTime(d.year, d.month, d.day, l.start.hour, l.start.minute));
          }),
          btn(context.tr('cancel_lesson'), Icons.close_rounded, () => _confirmCancel(context, app), color: AppColors.danger),
        ];
      case LessonStatus.pending:
        return [
          btn(context.tr('complete_payment'), Icons.payments_rounded, () => app.payPending(l), primary: true),
          btn(context.tr('cancel'), Icons.close_rounded, () => app.cancelLesson(l), color: AppColors.danger),
        ];
      case LessonStatus.delivered:
        if (tutorView) return [];
        if (l.state == 'disputed') {
          return [Pill(context.isAr ? 'أبلغت عن هذا الدرس، وسيراجعه فريق درس' : 'You reported this lesson; Dars will review it',
              icon: Icons.hourglass_top_rounded, bg: AppColors.accentSoft, fg: const Color(0xFFB7791F))];
        }
        if (l.state == 'no_show') {
          // Round F: the student may dispute a no-show within 48 hours
          return [
            btn(context.isAr ? 'كنت حاضراً — أبلغ' : 'I was there — report', Icons.flag_outlined, () {
              app.disputeLesson(l, 'Marked as no-show, but the student says they attended');
              toast(context, context.tr('report_sent'));
            }),
            btn(context.tr('book_again'), Icons.replay_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(tutor: l.tutor, hourPrice: l.tutor.pricePerHour.toDouble(), subjectId: l.subjectId)))),
          ];
        }
        return [
          l.reviewed
              ? Pill(context.tr('rated'), icon: Icons.check_rounded, bg: AppColors.successSoft, fg: AppColors.success)
              : btn(context.tr('rate_lesson'), Icons.star_outline_rounded, () => _review(context, app), primary: true),
          btn(context.tr('book_again'), Icons.replay_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(tutor: l.tutor, hourPrice: l.tutor.pricePerHour.toDouble(), subjectId: l.subjectId)))),
          // Round H4: "first lesson not right" — the whole amount back, within 24 h, once per tutor.
          if (app.canAskFirstRefund(l))
            btn(context.isAr ? 'الدرس الأول لم يناسبني — استرداد' : 'First lesson not right — refund', Icons.undo_rounded,
                () => _confirmFirstRefund(context, app), color: AppColors.danger),
          if (!l.reviewed || !app.live) ...[
            btn(context.tr('not_satisfied'), Icons.sentiment_dissatisfied_outlined, () {
              app.disputeLesson(l, 'Student not satisfied with the lesson (first-hour guarantee)');
              toast(context, context.tr('report_sent'));
            }),
            btn(context.tr('no_show'), Icons.person_off_outlined, () {
              app.disputeLesson(l, 'Tutor did not show up');
              toast(context, context.tr('report_sent'));
            }),
          ],
        ];
      case LessonStatus.cancelled:
        return [btn(context.tr('book_again'), Icons.replay_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(tutor: l.tutor, hourPrice: l.tutor.pricePerHour.toDouble(), subjectId: l.subjectId))))];
    }
  }

  void _confirmFirstRefund(BuildContext context, AppState app) {
    final ar = context.isAr;
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(ar ? 'استرداد الدرس الأول' : 'First-lesson refund'),
        content: Text(ar
            ? 'سيُعاد كامل مبلغ هذا الدرس إلى رصيدك في درس. يمكنك طلب ذلك مرة واحدة فقط مع هذا المدرس.'
            : 'The whole amount of this lesson goes back to your Dars balance. You can ask for it once with this tutor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(ar ? 'تراجع' : 'Back')),
          FilledButton(
            key: const Key('first-refund-ok'),
            onPressed: () {
              Navigator.pop(d);
              app.firstLessonRefund(lesson);
            },
            child: Text(ar ? 'استرداد' : 'Refund'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, AppState app) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.tr('cancel_lesson'), style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(context.tr('cancel_lesson_q')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(context.tr('no'))),
          TextButton(
            onPressed: () {
              app.cancelLesson(lesson);
              Navigator.pop(d);
            },
            child: Text(context.tr('yes'), style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _review(BuildContext context, AppState app) {
    int stars = 5;
    final comment = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Avatar(name: lesson.tutor.name, color: lesson.tutor.color, size: 60, photo: lesson.tutor.photoUrl),
            const SizedBox(height: 10),
            Text(context.tr('your_review'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(lesson.tutor.name.of(context), style: const TextStyle(color: AppColors.text2)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 1; i <= 5; i++)
                IconButton(onPressed: () => set(() => stars = i), icon: Icon(Icons.star_rounded, size: 38, color: i <= stars ? AppColors.accent : AppColors.line)),
            ]),
            const SizedBox(height: 8),
            TextField(controller: comment, maxLines: 3, decoration: InputDecoration(hintText: context.tr('review_hint'))),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  app.markReviewed(lesson, stars: stars, comment: comment.text);
                  Navigator.pop(sheet);
                  toast(context, context.tr('thanks_review'));
                },
                child: Text(context.tr('send')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The next two weeks of the tutor's free one-hour times; returns the chosen start (null = closed).
Future<DateTime?> pickPackageTime(BuildContext context, AppState app, Tutor tutor) async {
  final ar = context.isAr;
  final schedule = await app.scheduleFor(tutor);
  if (!context.mounted) return null;
  final now = DateTime.now();
  final days = [
    for (var i = 0; i < 14; i++)
      (day: DateTime(now.year, now.month, now.day + i), times: freeStartsOn(schedule, DateTime(now.year, now.month, now.day + i), 60).where((x) => !x.taken).toList()),
  ].where((d) => d.times.isNotEmpty).toList();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(sheet).size.height * .7,
        child: schedule.periods.isEmpty || days.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    schedule.periods.isEmpty
                        ? (ar ? 'هذا المدرس لم يحدد ساعات عمله بعد.' : 'This tutor has not set working hours yet.')
                        : (ar ? 'لا توجد أوقات متاحة خلال الأسبوعين القادمين.' : 'No free times in the next two weeks.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text2, fontWeight: FontWeight.w700)),
              )
            : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                Text(ar ? 'اختر وقت الدرس' : 'Choose the lesson time', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                for (final d in days) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(dayOf(sheet, d.day), style: const TextStyle(color: AppColors.text2, fontWeight: FontWeight.w700)),
                  ),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final x in d.times) ActionChip(label: Text(timeOf(sheet, x.time)), onPressed: () => Navigator.pop(sheet, x.time)),
                  ]),
                ],
              ]),
      ),
    ),
  );
}
