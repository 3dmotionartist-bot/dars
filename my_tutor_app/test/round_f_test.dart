// Round F: what can be checked without a server — prices in Syrian pounds, and lesson states.
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/data/mock_data.dart';
import 'package:my_tutor_app/data/models.dart';
import 'package:my_tutor_app/l10n.dart';
import 'package:my_tutor_app/widgets/common.dart';

void main() {
  tearDown(() {
    Money.sypPerUsd = 0;
    Money.showSyp = true;
    Money.arabic = true;
  });

  group('F5 — prices in Syrian pounds', () {
    test('no rate set: dollars as before', () {
      expect(money(10), r'$10');
      expect(money(12.5), r'$12.50');
      expect(toUsd(20), 20);
    });
    test('with a rate: pounds first, dollars small', () {
      Money.sypPerUsd = 13000;
      expect(money(10), r'130,000 ل.س ($10)');
      Money.arabic = false;
      expect(money(12.5), r'162,500 SYP ($12.50)');
      expect(moneyMain(1), '13,000 SYP');
    });
    test('amounts typed in pounds are sent in dollars, and back', () {
      Money.sypPerUsd = 13000;
      expect(toUsd(260000), 20);
      expect(fromUsd(20), 260000);
    });
    test('display currency USD: dollars only, even with a rate', () {
      Money.sypPerUsd = 13000;
      Money.showSyp = false;
      expect(money(10), r'$10');
      expect(toUsd(20), 20);
    });
  });

  group('F4 — no-show and disputed lessons keep their own state', () {
    test('a lesson has no special state by default', () {
      expect(Lesson(id: 'x', tutor: _tutor(), studentName: const L('a', 'a'), subject: const L('m', 'm'), start: DateTime(2026),
              minutes: 60, online: true, status: LessonStatus.delivered, price: 10)
          .state, '');
    });
  });
}

Tutor _tutor() => MockData.tutors.first;
