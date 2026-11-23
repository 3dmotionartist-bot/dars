// Round E: what can be checked without a server — the verified badge (E2) and the age rule (E3).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/data/models.dart';
import 'package:my_tutor_app/state/app_state.dart';
import 'package:my_tutor_app/widgets/common.dart';

void main() {
  group('E2 — verified badge only after approval', () {
    testWidgets('an approved tutor shows the badge', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VerifiedName('Samer'))));
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('a tutor in review (or no longer public) has no badge', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VerifiedName('Samer', verified: false))));
      expect(find.text('Samer'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsNothing);
    });
  });

  group('E3 — age from the year of birth (same rule as the server)', () {
    final year = DateTime.now().year;
    test('someone who turns 18 this year still counts as under 18', () {
      expect(AppState.minorYear(year - 18), isTrue);
      expect(AppState.minorYear(year - 15), isTrue);
    });
    test('19 and older, or no year saved (older accounts), are adults', () {
      expect(AppState.minorYear(year - 19), isFalse);
      expect(AppState.minorYear(year - 40), isFalse);
      expect(AppState.minorYear(null), isFalse);
    });
  });

  group("E1 — the other person's hidden messages are never shown (phone test 23 Nov 2026)", () {
    final t = DateTime(2026, 11, 23, 14, 20);
    test('a message the filter hid is hidden from the other person', () {
      expect(Message(mine: false, text: '0 9 4 4 7 6 5 4 3 2', time: t, blocked: true).hiddenFromMe, isTrue);
    });
    test('… but the sender still sees it (marked "not sent")', () {
      expect(Message(mine: true, text: '0 9 4 4 7 6 5 4 3 2', time: t, blocked: true).hiddenFromMe, isFalse);
    });
    test('ordinary messages are shown', () {
      expect(Message(mine: false, text: 'the lesson is at 10:30', time: t).hiddenFromMe, isFalse);
    });
  });
}
