import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/data/backend.dart';
import 'package:my_tutor_app/data/models.dart';

// Round G1: reply (quote) and delete-for-everyone in chat.
void main() {
  test('a server row with a quote and a deleted mark', () {
    final m = Backend.messageFromRow({
      'id': 12, 'sender_id': 'u1', 'kind': 'text', 'body': null, 'created_at': '2026-11-27T10:00:00Z',
      'reply_to': 7, 'deleted_at': '2026-11-27T10:05:00Z',
    }, 'u1');
    expect(m.replyTo, 7);
    expect(m.deleted, isTrue);
    expect(m.mine, isTrue);
  });

  test('older rows (no new columns) are plain messages', () {
    final m = Backend.messageFromRow({'id': 3, 'sender_id': 'u2', 'kind': 'text', 'body': 'hi', 'created_at': '2026-11-27T10:00:00Z'}, 'u1');
    expect(m.replyTo, 0);
    expect(m.deleted, isFalse);
  });

  test('deleting keeps the id and quote, drops the text and file', () {
    final m = Message(mine: true, text: 'secret', time: DateTime(2026, 11, 27), type: MsgType.image, remoteId: 5, url: 'chat/x.jpg', replyTo: 2);
    final d = m.asDeleted();
    expect(d.deleted, isTrue);
    expect(d.text, '');
    expect(d.url, '');
    expect(d.remoteId, 5);
    expect(d.replyTo, 2);
    expect(d.copyWith(sending: false).deleted, isTrue);
  });
}
