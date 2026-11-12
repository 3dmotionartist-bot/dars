import 'package:flutter/widgets.dart' show TextDirection;

import '../../data/models.dart';

/// What the little mark under one of my messages shows.
enum Tick { none, sending, sent, read, failed, hidden }

Tick tickFor(Message m) {
  if (!m.mine || m.type == MsgType.system) return Tick.none;
  if (m.blocked) return Tick.hidden;
  if (m.failed) return Tick.failed;
  if (m.sending || m.remoteId == 0) return m.sending ? Tick.sending : Tick.sent;
  return m.readAt != null ? Tick.read : Tick.sent;
}

/// One row of the chat list: a message, a day header, or the "unread messages" line.
class ChatItem {
  final Message? message;
  final DateTime? day; // set for a day header
  final bool unreadLine;
  const ChatItem.message(Message this.message)
      : day = null,
        unreadLine = false;
  const ChatItem.day(DateTime this.day)
      : message = null,
        unreadLine = false;
  const ChatItem.unread()
      : message = null,
        day = null,
        unreadLine = true;
}

bool sameDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Messages (oldest first) → rows (oldest first) with a header before each new day and the
/// "unread messages" line before the message with server id [firstUnreadId] (0 = no line).
List<ChatItem> buildChatItems(List<Message> messages, {int firstUnreadId = 0}) {
  final out = <ChatItem>[];
  DateTime? prev;
  for (final m in messages) {
    if (prev == null || !sameDay(prev, m.time)) out.add(ChatItem.day(m.time));
    if (firstUnreadId != 0 && m.remoteId == firstUnreadId) out.add(const ChatItem.unread());
    out.add(ChatItem.message(m));
    prev = m.time;
  }
  return out;
}

/// The first message from the other person that I had not read when the chat opened.
Message? firstUnreadOf(List<Message> messages, int unreadCount) {
  for (final m in messages) {
    if (!m.mine && m.type != MsgType.system && m.remoteId != 0 && m.readAt == null) return m;
  }
  // Fallback: the chat's unread counter (messages loaded before read times were known).
  if (unreadCount > 0 && unreadCount <= messages.length) {
    final m = messages[messages.length - unreadCount];
    return m.mine ? null : m;
  }
  return null;
}

/// "Today" / "Yesterday" / day.month.year, in the user's language.
String dayLabel(DateTime d, {required bool ar, DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final x = d.toLocal();
  if (sameDay(x, n)) return ar ? 'اليوم' : 'Today';
  if (sameDay(x, DateTime(n.year, n.month, n.day - 1))) return ar ? 'أمس' : 'Yesterday';
  return x.year == n.year ? '${x.day}/${x.month}' : '${x.day}/${x.month}/${x.year}';
}

final _rtl = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]');
final _ltr = RegExp(r'[A-Za-zÀ-ɏͰ-ϿЀ-ӿ]');

/// Direction of a text from its first strong letter (Arabic → right-to-left, Latin → left-to-right);
/// null when it has no letters (numbers, emoji), so the screen's direction is kept.
TextDirection? directionOf(String text) {
  for (final r in text.runes) {
    final ch = String.fromCharCode(r);
    if (_rtl.hasMatch(ch)) return TextDirection.rtl;
    if (_ltr.hasMatch(ch)) return TextDirection.ltr;
  }
  return null;
}
