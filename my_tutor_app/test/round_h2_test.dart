import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/data/mock_data.dart';
import 'package:my_tutor_app/data/models.dart';
import 'package:my_tutor_app/l10n.dart';

// Round H part 2: review replies, trial lesson, lesson summary — the new fields default to "nothing yet",
// so demo data and older server rows show exactly as before.
void main() {
  test('a review without a reply or lesson count', () {
    const r = Review(L('أ', 'A'), 5, L('x', 'x'), '2026-11-27');
    expect(r.reply, '');
    expect(r.lessons, 0);
    expect(r.id, '');
  });

  test('a lesson is not a trial, has no summary and was not refunded unless the server says so', () {
    final l = Lesson(
      id: 'L1',
      tutor: MockData.tutors.first,
      studentName: const L('أنت', 'You'),
      subject: const L('رياضيات', 'Math'),
      start: DateTime(2026, 12, 1, 10),
      minutes: 20,
      online: true,
      status: LessonStatus.delivered,
      price: 8,
    );
    expect(l.isTrial, isFalse);
    expect(l.summary, '');
    expect(l.firstRefunded, isFalse);
  });

  test('demo tutors offer no trial', () {
    expect(MockData.tutors.every((t) => t.trialPrice == null), isTrue);
  });
}
