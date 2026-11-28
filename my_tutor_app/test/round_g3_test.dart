import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/data/models.dart';
import 'package:my_tutor_app/l10n.dart';

// Round G3: pinned chats come first.
void main() {
  Conversation chat(String id) => Conversation(id: id, name: L(id, id), color: Colors.blue, messages: []);

  test('pinned chats first, newest pin first, the rest keep their order', () {
    final list = [chat('a'), chat('b'), chat('c'), chat('d'), chat('')];
    expect(orderChats(list, ['c', 'a']).map((c) => c.id), ['c', 'a', 'b', 'd', '']);
    expect(orderChats(list, []).map((c) => c.id), ['a', 'b', 'c', 'd', '']);
    expect(orderChats(list, ['gone', 'd']).map((c) => c.id), ['d', 'a', 'b', 'c', '']);
  });
}
