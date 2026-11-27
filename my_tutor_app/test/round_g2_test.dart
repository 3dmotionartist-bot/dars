import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/data/backend.dart';
import 'package:my_tutor_app/data/models.dart';
import 'package:my_tutor_app/widgets/media.dart';

// Round G2: documents in a chat, voice-note speed, "last seen".
void main() {
  test('document kinds from a name or a stored path', () {
    expect(docKind('homework.PDF'), 'PDF');
    expect(docKind('chat-files/u/c/1764200000001.docx'), 'Word');
    expect(docKind('marks.xls'), 'Excel');
    expect(docKind('lesson.pptx'), 'PowerPoint');
    expect(docKind('notes.txt'), 'TXT');
    expect(docKind('video.mp4'), '');
    expect(docKind('no-extension'), '');
    expect(docMimes['docx'], 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    expect(docMimes.containsKey('exe'), isFalse);
  });

  test('a file message from the server is labelled by its kind (the server keeps no file name)', () {
    final m = Backend.messageFromRow({
      'id': 5, 'sender_id': 'u2', 'kind': 'file', 'body': '📎', 'file_url': 'chat-files/u2/c/1764200000001.pdf',
      'created_at': '2026-11-28T10:00:00Z',
    }, 'u1');
    expect(m.type, MsgType.file);
    expect(fileLabel(m, ar: true), 'ملف PDF');
    expect(fileLabel(m, ar: false), 'PDF file');
    final mine = Message(mine: true, text: 'واجب 3.docx', time: DateTime(2026), type: MsgType.file);
    expect(fileLabel(mine, ar: true), 'واجب 3.docx');
    final unknown = Message(mine: false, text: '📎', time: DateTime(2026), type: MsgType.file);
    expect(fileLabel(unknown, ar: true), 'ملف');
  });

  test('voice-note speed goes 1 → 1.5 → 2 → 1', () {
    expect(nextVoiceSpeed(1), 1.5);
    expect(nextVoiceSpeed(1.5), 2);
    expect(nextVoiceSpeed(2), 1);
  });

  test('last seen', () {
    final now = DateTime(2026, 11, 28, 15, 30);
    expect(lastSeenLabel(null, now, ar: true), '');
    expect(lastSeenLabel(now.subtract(const Duration(seconds: 50)), now, ar: true), 'متصل الآن');
    expect(lastSeenLabel(now.subtract(const Duration(minutes: 12)), now, ar: true), 'آخر ظهور منذ 12 د');
    expect(lastSeenLabel(DateTime(2026, 11, 28, 9, 5), now, ar: true), 'آخر ظهور اليوم 09:05');
    expect(lastSeenLabel(DateTime(2026, 11, 27, 22, 40), now, ar: false), 'Last seen yesterday 22:40');
    expect(lastSeenLabel(DateTime(2026, 11, 20, 8, 0), now, ar: true), 'آخر ظهور 20/11');
  });
}
