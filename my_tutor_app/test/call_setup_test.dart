import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/services/call_logic.dart';

// "Receive calls" setup (26 Nov 2026): which phone settings are still missing.
void main() {
  test('unknown phone (web, old build, no answer) counts as done', () {
    expect(const CallSetup().done, isTrue);
  });

  test('Xiaomi with Autostart off and battery saving on: both missing, in order', () {
    final s = CallSetup.fromMap({'notifications': true, 'fullScreen': true, 'battery': false, 'autostart': 'off', 'brand': 'xiaomi'});
    expect(s.missing, ['battery', 'autostart']);
    expect(s.done, isFalse);
  });

  test('everything on (the tested phone after the fix)', () {
    final s = CallSetup.fromMap({'notifications': true, 'fullScreen': true, 'battery': true, 'autostart': 'on', 'brand': 'xiaomi'});
    expect(s.done, isTrue);
  });

  test('a brand that cannot report Autostart needs "I turned it on"', () {
    final s = CallSetup.fromMap({'battery': true, 'autostart': 'unknown', 'brand': 'oppo'});
    expect(s.missing, ['autostart']);
    expect(s.withConfirmed(true).done, isTrue);
  });

  test('phones without an Autostart page never show that step', () {
    final s = CallSetup.fromMap({'notifications': false, 'fullScreen': false, 'battery': true, 'autostart': 'none'});
    expect(s.showAutostart, isFalse);
    expect(s.missing, ['notifications', 'fullScreen']);
  });
}
