import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/classroom_screen.dart';
import '../student/lessons_screen.dart';

/// Tutor lessons: add lesson link, start classroom, mark delivered, report student no-show.
class TutorLessonsScreen extends StatelessWidget {
  const TutorLessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final up = app.tutorLessons.where((l) => l.status == LessonStatus.upcoming).toList()..sort((a, b) => a.start.compareTo(b.start));
    final past = app.tutorLessons.where((l) => l.status != LessonStatus.upcoming).toList();

    return DefaultTabController(
      length: 2,
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
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.text2,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
              tabs: [Tab(text: '${context.tr('tab_upcoming')} (${up.length})'), Tab(text: context.tr('tab_past'))],
            ),
            Expanded(
              child: TabBarView(children: [
                up.isEmpty
                    ? EmptyState(icon: Icons.event_available_rounded, title: context.tr('no_lessons'), body: '')
                    : ListView(padding: const EdgeInsets.all(16), children: [
                        for (final l in up)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(children: [
                              LessonCard(lesson: l, tutorView: true),
                              const SizedBox(height: 6),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                                  onPressed: () => app.live ? app.joinLesson(l) : Navigator.push(context, MaterialPageRoute(builder: (_) => ClassroomScreen(lesson: l))),
                                  icon: const Icon(Icons.videocam_rounded, size: 18),
                                  label: Text(context.tr('join_lesson')),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                                  onPressed: () => _addLink(context, app, l),
                                  icon: Icon(l.link == null ? Icons.add_link_rounded : Icons.link_rounded, size: 18),
                                  label: Text(l.link == null ? context.tr('add_link') : l.link!.replaceFirst('https://', '')),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: AppColors.success, side: const BorderSide(color: AppColors.line)),
                                  onPressed: () => app.markDelivered(l),
                                  icon: const Icon(Icons.task_alt_rounded, size: 18),
                                  label: Text(context.tr('mark_delivered')),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.line)),
                                  onPressed: () {
                                    app.reportStudentNoShow(l);
                                    if (!app.live) toast(context, context.tr('report_sent'));
                                  },
                                  icon: const Icon(Icons.person_off_outlined, size: 18),
                                  label: Text(context.tr('student_no_show')),
                                ),
                              ]),
                            ]),
                          ),
                      ]),
                ListView(padding: const EdgeInsets.all(16), children: [
                  for (final l in past) Padding(padding: const EdgeInsets.only(bottom: 12), child: LessonCard(lesson: l, tutorView: true)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _addLink(BuildContext context, AppState app, Lesson l) {
    final ctrl = TextEditingController(text: l.link ?? 'https://meet.dars.app/${l.id}');
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.tr('add_link'), style: const TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(controller: ctrl, keyboardType: TextInputType.url, textDirection: TextDirection.ltr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(context.tr('cancel'))),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (Uri.tryParse(v)?.hasScheme ?? false) {
                app.setLessonLink(l, v);
                Navigator.pop(d);
                toast(context, context.tr('link_saved'));
              }
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }
}
