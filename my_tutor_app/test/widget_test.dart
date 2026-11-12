// Unit tests for the chat logic (send status, day headers, unread line, text direction).
// The app itself connects to the live backend on start, so it is not pumped here.
import 'package:flutter/widgets.dart' show TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/data/models.dart';
import 'package:my_tutor_app/screens/shared/chat_logic.dart';

Message msg(String text, DateTime t, {bool mine = false, int id = 0, bool sending = false, bool failed = false, DateTime? readAt, bool blocked = false}) =>
    Message(mine: mine, text: text, time: t, remoteId: id, sending: sending, failed: failed, readAt: readAt, blocked: blocked);

void main() {
  final day1 = DateTime(2026, 11, 10, 9, 0);
  final day1b = DateTime(2026, 11, 10, 23, 30);
  final day2 = DateTime(2026, 11, 11, 8, 15);

  group('message footer state', () {
    test('sending → clock', () => expect(tickFor(msg('a', day1, mine: true, sending: true)), Tick.sending));
    test('sent → single tick', () => expect(tickFor(msg('a', day1, mine: true, id: 5)), Tick.sent));
    test('read → double tick', () => expect(tickFor(msg('a', day1, mine: true, id: 5, readAt: day2)), Tick.read));
    test('failed → red !', () => expect(tickFor(msg('a', day1, mine: true, failed: true)), Tick.failed));
    test('hidden by the filter', () => expect(tickFor(msg('0944', day1, mine: true, id: 6, blocked: true)), Tick.hidden));
    test('messages from the other person have no tick', () => expect(tickFor(msg('a', day1, id: 7)), Tick.none));
  });

  group('day headers and unread line', () {
    final list = [msg('a', day1, id: 1), msg('b', day1b, id: 2), msg('c', day2, id: 3), msg('d', day2, id: 4)];

    test('a header before each new day', () {
      final items = buildChatItems(list);
      expect(items.where((i) => i.day != null).length, 2);
      expect(items.first.day, isNotNull);
      expect(items[3].day, isNotNull); // header, a, b, header, c, d
      expect(items.length, 6);
    });

    test('unread line goes before the first unread message', () {
      final items = buildChatItems(list, firstUnreadId: 3);
      final i = items.indexWhere((x) => x.unreadLine);
      expect(i, greaterThan(0));
      expect(items[i + 1].message?.remoteId, 3);
    });

    test('no unread line when everything is read', () {
      expect(buildChatItems(list).any((x) => x.unreadLine), isFalse);
    });

    test('first unread is the first unread message from the other person', () {
      final mixed = [msg('mine', day1, mine: true, id: 1), msg('read', day1, id: 2, readAt: day1), msg('new', day2, id: 3), msg('new2', day2, id: 4)];
      expect(firstUnreadOf(mixed, 0)?.remoteId, 3);
    });

    test('day labels', () {
      final now = DateTime(2026, 11, 11, 12);
      expect(dayLabel(DateTime(2026, 11, 11, 8), ar: true, now: now), 'اليوم');
      expect(dayLabel(DateTime(2026, 11, 10, 8), ar: false, now: now), 'Yesterday');
      expect(dayLabel(DateTime(2026, 10, 2, 8), ar: false, now: now), '2/10');
      expect(dayLabel(DateTime(2025, 10, 2, 8), ar: false, now: now), '2/10/2025');
    });
  });

  group('message id survives retries', () {
    test('a failed copy keeps the id it was sent with', () {
      final m = msg('hi', day1, mine: true, sending: true).copyWith(clientId: 'abc');
      expect(m.copyWith(sending: false, failed: true).clientId, 'abc');
      expect(m.copyWith(sending: true, failed: false).clientId, 'abc');
    });
  });

  group('text direction per message', () {
    test('Arabic → right to left', () => expect(directionOf('مرحبا، كيف الحال؟'), TextDirection.rtl));
    test('English → left to right', () => expect(directionOf('Hello, see you at 5?'), TextDirection.ltr));
    test('first strong letter decides', () => expect(directionOf('5 بعد العصر, ok'), TextDirection.rtl));
    test('only numbers / emoji → keep the screen direction', () => expect(directionOf('12:30 👍'), isNull));
  });
}
