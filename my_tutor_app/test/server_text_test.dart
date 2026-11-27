import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/services/server_text.dart';

// Round H1: the server's English texts shown in Arabic.
void main() {
  // The same list the database migration loads, read straight from it.
  List<Map<String, dynamic>> migrationRows() {
    final f = File('../my_tutor_backend/supabase/migrations/20261127000020_round_h1.sql');
    final sql = f.readAsStringSync();
    final row = RegExp(r"^  \((\d+), '((?:[^']|'')*)', '((?:[^']|'')*)'\)", multiLine: true);
    return [
      for (final m in row.allMatches(sql))
        {'id': int.parse(m[1]!), 'pattern': m[2]!.replaceAll("''", "'"), 'ar': m[3]!.replaceAll("''", "'")},
    ];
  }

  test('every pattern of the migration works in the app', () {
    final rows = migrationRows();
    expect(rows.length, greaterThanOrEqualTo(150));
    for (final r in rows) {
      expect(() => RegExp('^(?:${r['pattern']})\$'), returnsNormally, reason: '${r['pattern']}');
    }
  });

  test('refusals and notifications in Arabic, with their numbers', () {
    ServerText.setRules(migrationRows());
    ServerText.arabic = true;
    expect(ServerText.show('Sign in first'), 'سجّل الدخول أولاً');
    expect(ServerText.show('Lesson #12 was cancelled.'), 'تم إلغاء الدرس رقم 12.');
    expect(ServerText.show('The amount must be between 5 and 500'), 'يجب أن يكون المبلغ بين 5 و500');
    expect(ServerText.show("This time is outside the tutor's working hours"), 'هذا الوقت خارج أوقات عمل المدرس');
  });

  test('unknown text stays as it is; English app shows English', () {
    ServerText.setRules(migrationRows());
    ServerText.arabic = true;
    expect(ServerText.show('Something new from the server'), 'Something new from the server');
    ServerText.arabic = false;
    expect(ServerText.show('Sign in first'), 'Sign in first');
    ServerText.arabic = true;
  });

  test('sign-in and network messages', () {
    ServerText.setRules(const []);
    ServerText.arabic = true;
    expect(ServerText.show('Invalid login credentials'), 'البريد أو كلمة المرور غير صحيحة');
    expect(ServerText.show('Password should be at least 6 characters.'), 'يجب ألا تقل كلمة المرور عن 6 أحرف');
    expect(ServerText.show('ClientException with SocketException: Connection failed (OS Error: Permission denied, errno = 13)'),
        'تعذّر الاتصال بالخادم. تحقّق من الإنترنت وحاول مجدداً');
  });
}
