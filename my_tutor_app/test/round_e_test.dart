// Round E: what can be checked without a server — the verified badge (E2) and the age rule (E3).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
