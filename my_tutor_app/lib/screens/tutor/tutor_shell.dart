import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../widgets/adaptive_shell.dart';
import '../shared/account_screen.dart';
import '../shared/messages_screen.dart';
import 'tutor_dashboard_screen.dart';
import 'tutor_lessons_screen.dart';
import 'tutor_requests_screen.dart';

/// Tutor app: Dashboard · Live requests · Lessons · Messages · Account.
class TutorShell extends StatefulWidget {
  const TutorShell({super.key});
  static TutorShellState? of(BuildContext context) => context.findAncestorStateOfType<TutorShellState>();
  @override
  State<TutorShell> createState() => TutorShellState();
}

class TutorShellState extends State<TutorShell> {
  int index = 0;
  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return AdaptiveShell(
      index: index,
      onSelect: go,
      pages: const [
        TutorDashboardScreen(),
        TutorRequestsScreen(),
        TutorLessonsScreen(),
        MessagesScreen(),
        AccountScreen(embedded: true),
      ],
      destinations: [
        ShellDestination(Icons.dashboard_outlined, Icons.dashboard_rounded, context.tr('nav_dashboard')),
        ShellDestination(Icons.bolt_outlined, Icons.bolt_rounded, context.tr('nav_requests'), badge: app.tutorAvailable ? app.liveRequests.length : 0, highlight: true),
        ShellDestination(Icons.event_note_outlined, Icons.event_note_rounded, context.tr('nav_lessons')),
        ShellDestination(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, context.tr('nav_messages'), badge: app.unreadMessages),
        ShellDestination(Icons.person_outline_rounded, Icons.person_rounded, context.tr('nav_account')),
      ],
    );
  }
}
