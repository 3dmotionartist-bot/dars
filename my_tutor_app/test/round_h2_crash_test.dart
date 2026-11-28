import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/services/crash_report.dart';

// Round H2: what an error report may contain.
void main() {
  test('personal details are blanked out of the error text', () {
    expect(crashMessage('Bad state: no user a.b@mail.com at https://x.supabase.co/rest/v1/p?id=5'),
        'Bad state: no user <email> at <link>');
    expect(crashMessage('call 0933 123 456 failed'), 'call <number> failed');
    expect(crashMessage('tutor 4f3c2a10-1b2c-4d5e-8f90-123456789abc not found'), 'tutor <id> not found');
    expect(crashMessage('x' * 2000).length, 1000);
    expect(crashMessage('Null check operator used on a null value'), 'Null check operator used on a null value');
  });

  test('offline trouble is not reported', () {
    expect(isNetworkTrouble('SocketException: Failed host lookup: x.supabase.co'), isTrue);
    expect(isNetworkTrouble('ClientException: XMLHttpRequest error.'), isTrue);
    expect(isNetworkTrouble('TimeoutException after 0:00:10'), isTrue);
    expect(isNetworkTrouble('RangeError (index): Invalid value'), isFalse);
  });

  test('only the first lines of the stack are kept', () {
    final s = StackTrace.fromString(List.generate(60, (i) => '#$i frame $i').join('\n'));
    expect(crashStack(s).split('\n').length, 25);
    expect(crashStack(null), '');
  });

  test('nothing is sent before the server is ready', () {
    CrashReport.send = null;
    CrashReport.report(StateError('boom'), null); // must not throw
    final sent = <Map<String, dynamic>>[];
    CrashReport.send = (p) async => sent.add(p);
    CrashReport.build = 52;
    CrashReport.report(StateError('first'), null, context: 'test');
    CrashReport.report(StateError('first'), null, context: 'test'); // same error: once
    CrashReport.report(Exception('SocketException: Failed host lookup'), null); // offline: never
    expect(sent.length, 1);
    expect(sent.first['p_message'], 'Bad state: first');
    expect(sent.first['p_build'], 52);
    CrashReport.send = null;
  });
}
