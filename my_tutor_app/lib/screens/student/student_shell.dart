import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../widgets/adaptive_shell.dart';
import '../shared/chat_screen.dart';
import '../shared/messages_screen.dart';
import 'home_screen.dart';
import 'lessons_screen.dart';
import 'live_help_screen.dart';
import 'tutor_list_screen.dart';

/// Student/parent app: Home · Tutors · Live help · Lessons · Messages.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});
  static StudentShellState? of(BuildContext context) => context.findAncestorStateOfType<StudentShellState>();
  @override
  State<StudentShell> createState() => StudentShellState();
}

class StudentShellState extends State<StudentShell> {
  void go(int i, {String? subject}) => context.read<AppState>().goTab(i, subject: subject);

  @override
  void initState() {
    super.initState();
    context.read<AppState>().openChatRoute = (c) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final index = app.studentTab;
    final subjectFilter = app.subjectFilter;
    final pages = [
      const HomeScreen(),
      TutorListScreen(key: ValueKey(subjectFilter), initialSubject: subjectFilter),
      const LiveHelpScreen(),
      const LessonsScreen(),
      const MessagesScreen(),
    ];
    return AdaptiveShell(
      index: index,
      onSelect: (i) => go(i),
      pages: pages,
      destinations: [
        ShellDestination(Icons.home_outlined, Icons.home_rounded, context.tr('nav_home')),
        ShellDestination(Icons.search_rounded, Icons.manage_search_rounded, context.tr('nav_tutors')),
        ShellDestination(Icons.bolt_outlined, Icons.bolt_rounded, context.tr('nav_live'), highlight: true),
        ShellDestination(Icons.event_note_outlined, Icons.event_note_rounded, context.tr('nav_lessons')),
        ShellDestination(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, context.tr('nav_messages'), badge: app.unreadMessages),
      ],
    );
  }
}
