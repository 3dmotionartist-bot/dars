import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/data/backend.dart';
import 'package:my_tutor_app/data/mock_data.dart';
import 'package:my_tutor_app/data/models.dart';
import 'package:my_tutor_app/l10n.dart';
import 'package:my_tutor_app/widgets/common.dart';

// Fixes from the build 47 test.
void main() {
  Lesson row(String id, String student, String status) => Backend.lessonFromRow({
        'id': id, 'student_id': student, 'status': status, 'starts_at': '2026-11-20T10:00:00Z',
        'duration_min': 60, 'price': 10, 'subject_id': MockData.tutors.first.subjectIds.first,
      }, tutor: MockData.tutors.first, studentName: const L('ط', 'S'));

  test('students taught counts different students of delivered lessons only', () {
    final ls = [
      row('1', 'a', 'delivered'),
      row('2', 'a', 'delivered'),
      row('3', 'b', 'delivered'),
      row('4', 'c', 'cancelled'),
      row('5', 'd', 'confirmed'),
      row('6', 'e', 'no_show'),
    ];
    expect(studentsTaught(ls), 2);
  });

  test('a price in big text: pounds big, dollars small after them', () {
    Money.sypPerUsd = 150;
    Money.showSyp = true;
    Money.arabic = true;
    const big = TextStyle(fontSize: 18);
    final spans = moneySpans(26, big);
    expect(spans.length, 2);
    expect(spans[0].text, '3,900 ل.س');
    expect(spans[0].style, big);
    expect(spans[1].text, r' ($26)');
    expect(spans[1].style!.fontSize, lessThan(18));
    Money.showSyp = false;
    expect(moneySpans(26, big).map((s) => s.text), [r'$26']);
    Money.showSyp = true;
    Money.sypPerUsd = 0;
  });
}
