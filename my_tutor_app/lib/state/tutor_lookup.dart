import '../data/models.dart';

/// Tutor ids (of my lessons, packages, chats) that still need loading: unknown, or known only as a
/// placeholder. Each id once; ids that are not real (demo / empty) are skipped.
List<String> missingTutorIds(Iterable<String> ids, Tutor? Function(String id) known) =>
    {for (final id in ids) if (id.length > 20 && (known(id)?.stub ?? true)) id}.toList();

/// The subject a booking uses: the one asked for ("Book again" = the lesson's subject) if the tutor
/// still teaches it, otherwise the tutor's first subject.
String bookingSubject(String? wanted, List<String> teaches) =>
    wanted != null && wanted.isNotEmpty && teaches.contains(wanted) ? wanted : teaches.first;
