import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../l10n.dart';

enum UserRole { student, parent, tutor }

class Subject {
  final String id;
  final L name;
  final IconData icon;
  final Color color;
  const Subject(this.id, this.name, this.icon, this.color);
}

class StudyLevel {
  final String id;
  final L name;
  final IconData icon;
  final double priceFactor;
  const StudyLevel(this.id, this.name, this.icon, this.priceFactor);
}

class Option {
  final String id;
  final L name;
  const Option(this.id, this.name);
}

class Review {
  final L author;
  final int stars;
  final L text;
  final String date;
  final String id; // backend review id ('' in demo)
  final String reply; // the tutor's one answer ('' = none yet) — Round H3
  final int lessons; // lessons the student had with the tutor when reviewing (0 = unknown)
  const Review(this.author, this.stars, this.text, this.date, {this.id = '', this.reply = '', this.lessons = 0});
}

class Tutor {
  final String id;
  final L name;
  final L headline;
  final L about;
  final List<String> subjectIds;
  final List<L> tags;
  final double rating;
  final int reviewCount;
  final int hoursTaught;
  final int students;
  final int pricePerHour;
  final int maxDiscount;
  final bool available;
  final bool instantBooking;
  final bool isNew;
  final String gender; // 'm' | 'f'
  final L country;
  final List<L> languages;
  final int years;
  final int matchScore; // 0-100, order of "best match" (rating, available now, my subjects) — not shown as a percentage
  final Color color;
  final bool teachesOnline;
  final bool teachesInPerson;
  final int cancelHours;
  final List<Review> reviews;
  final String photoUrl; // profile photo ('' = initials)
  final String videoUrl; // intro video ('' = none)
  final double? trialPrice; // Round H4: price of the 20-minute first lesson (null = no trial)
  /// Only an id and a name are known (the tutor is not in the public list any more, or not loaded yet).
  /// Never priced or booked from: the booking screen loads the real tutor first.
  final bool stub;

  const Tutor({
    required this.id,
    required this.name,
    required this.headline,
    required this.about,
    required this.subjectIds,
    required this.tags,
    required this.rating,
    required this.reviewCount,
    required this.hoursTaught,
    required this.students,
    required this.pricePerHour,
    required this.maxDiscount,
    required this.available,
    required this.instantBooking,
    required this.isNew,
    required this.gender,
    required this.country,
    required this.languages,
    required this.years,
    required this.matchScore,
    required this.color,
    this.teachesOnline = true,
    this.teachesInPerson = false,
    this.cancelHours = 12,
    this.reviews = const [],
    this.photoUrl = '',
    this.videoUrl = '',
    this.trialPrice,
    this.stub = false,
  });

  bool get hasPackages => maxDiscount > 0;
}

enum LessonStatus { upcoming, pending, delivered, cancelled }

class Lesson {
  final String id;
  final Tutor tutor;
  final L studentName;
  final L subject;
  DateTime start;
  final int minutes;
  final bool online;
  LessonStatus status;
  final double price;
  String? link;
  bool reviewed;
  final int number; // booking number shown to users (backend)
  final double commission;
  final String studentId; // backend student id ('' in demo)
  final String subjectId; // the subject booked ('' in demo) — used by "Book again"
  final String childName; // Round E3: booked by a parent for this child ('' = for the account holder)
  /// Round F: the server status when it says more than [status]: 'no_show' or 'disputed' ('' otherwise).
  final String state;
  final bool isTrial; // Round H4: the 20-minute trial lesson
  String summary; // Round H5: the tutor's short summary ('' = none)
  bool firstRefunded; // Round H4: refunded as "first lesson not right"

  Lesson({
    required this.id,
    required this.tutor,
    required this.studentName,
    required this.subject,
    required this.start,
    required this.minutes,
    required this.online,
    required this.status,
    required this.price,
    this.link,
    this.reviewed = false,
    this.number = 0,
    this.commission = 0,
    this.studentId = '',
    this.subjectId = '',
    this.childName = '',
    this.state = '',
    this.isTrial = false,
    this.summary = '',
    this.firstRefunded = false,
  });
}

/// Round G2: the kind of document a file is, from its name or stored path ('' when it is not a document).
String docKind(String nameOrPath) {
  final e = RegExp(r'\.([a-zA-Z0-9]{2,5})$').firstMatch(nameOrPath.trim())?.group(1)?.toLowerCase() ?? '';
  return switch (e) {
    'pdf' => 'PDF',
    'doc' || 'docx' => 'Word',
    'xls' || 'xlsx' => 'Excel',
    'ppt' || 'pptx' => 'PowerPoint',
    'txt' => 'TXT',
    _ => '',
  };
}

/// Round G2: the document types a chat takes, with the type the server expects for each.
const docMimes = <String, String>{
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'txt': 'text/plain',
};

/// Round G2: the extension of a stored path or name ('' when none), lower case.
String docExt(String nameOrPath) => RegExp(r'\.([a-zA-Z0-9]{2,5})$').firstMatch(nameOrPath.trim())?.group(1)?.toLowerCase() ?? '';

/// Round G2: the name a document is saved under to open it (my own file keeps its name).
String docFileName(Message m) {
  final ext = docExt(m.url).isNotEmpty ? docExt(m.url) : docExt(m.text);
  final named = ext.isNotEmpty && m.text != '📎' && docExt(m.text) == ext ? m.text : '';
  final base = named.isNotEmpty ? named.substring(0, named.length - ext.length - 1) : 'Dars-${m.remoteId > 0 ? m.remoteId : m.url.hashCode.abs()}';
  final safe = base.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
  return '${safe.isEmpty ? 'Dars' : safe}.${ext.isEmpty ? 'bin' : ext}';
}

/// Round G2: a file message's label ("ملف PDF" / "PDF file"), from the name I picked or the stored path.
String fileLabel(Message m, {required bool ar}) {
  final named = m.text.isNotEmpty && m.text != '📎' ? m.text : '';
  final kind = docKind(named.isNotEmpty ? named : m.url);
  if (named.isNotEmpty) return named;
  if (kind.isEmpty) return ar ? 'ملف' : 'File';
  return ar ? 'ملف $kind' : '$kind file';
}

/// Round G2: "last seen" under a chat's name ('' when unknown).
String lastSeenLabel(DateTime? seen, DateTime now, {required bool ar}) {
  if (seen == null) return '';
  final s = seen.toLocal();
  final d = now.difference(s);
  if (d.inMinutes < 2) return ar ? 'متصل الآن' : 'Online now';
  if (d.inMinutes < 60) return ar ? 'آخر ظهور منذ ${d.inMinutes} د' : 'Last seen ${d.inMinutes} min ago';
  String hm() => '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(s.year, s.month, s.day);
  if (day == today) return ar ? 'آخر ظهور اليوم ${hm()}' : 'Last seen today ${hm()}';
  if (day == today.subtract(const Duration(days: 1))) return ar ? 'آخر ظهور أمس ${hm()}' : 'Last seen yesterday ${hm()}';
  return ar ? 'آخر ظهور ${s.day}/${s.month}' : 'Last seen ${s.day}/${s.month}';
}

/// Round G1: how many different students a tutor has actually taught (delivered, not no-show or disputed).
int studentsTaught(Iterable<Lesson> lessons) =>
    lessons.where((l) => l.status == LessonStatus.delivered && l.studentId.isNotEmpty && l.state.isEmpty).map((l) => l.studentId).toSet().length;

class HoursPackage {
  final String id;
  final Tutor tutor;
  final int totalHours;
  double usedHours;
  final int discount;
  final bool active;
  final double price;
  final String? remoteId; // backend package id

  HoursPackage({
    required this.id,
    required this.tutor,
    required this.totalHours,
    required this.usedHours,
    required this.discount,
    required this.active,
    required this.price,
    this.remoteId,
  });

  double get remaining => totalHours - usedHours;
}

enum MsgType { text, voice, file, system, call, image, video }

class Message {
  final bool mine;
  final String text;
  final DateTime time;
  final MsgType type;
  final int seconds;
  final int remoteId; // backend message id (0 = local only)
  final String url; // stored file: "<bucket>/<path>" ('' = none)
  final Uint8List? bytes; // local preview while uploading
  final bool sending;
  final bool failed; // could not reach the server (tap to retry)
  final DateTime? readAt; // when the other person read it (my messages)
  final bool blocked; // hidden by the contact filter (only the sender sees it)
  /// The other person's message that the contact filter hid: never shown here, however it arrived
  /// (phone test 23 Nov 2026: hidden messages reached the other side through the live connection).
  bool get hiddenFromMe => blocked && !mine;
  final String? clientId; // made once per message, sent on every attempt (no duplicates on retry)
  final int replyTo; // Round G1: the backend id of the quoted message (0 = none)
  final bool deleted; // Round G1: the sender deleted it (shown as "message deleted")
  const Message({
    required this.mine,
    required this.text,
    required this.time,
    this.type = MsgType.text,
    this.seconds = 0,
    this.remoteId = 0,
    this.url = '',
    this.bytes,
    this.sending = false,
    this.failed = false,
    this.readAt,
    this.blocked = false,
    this.clientId,
    this.replyTo = 0,
    this.deleted = false,
  });

  Message copyWith({bool? sending, bool? failed, String? text, String? url, DateTime? readAt, String? clientId}) => Message(
        mine: mine,
        text: text ?? this.text,
        time: time,
        type: type,
        seconds: seconds,
        remoteId: remoteId,
        url: url ?? this.url,
        bytes: bytes,
        sending: sending ?? this.sending,
        failed: failed ?? this.failed,
        readAt: readAt ?? this.readAt,
        blocked: blocked,
        clientId: clientId ?? this.clientId,
        replyTo: replyTo,
        deleted: deleted,
      );

  /// The server's copy of this message, keeping the local photo preview.
  Message withPreviewOf(Message local) => local.bytes == null || bytes != null
      ? this
      : Message(
          mine: mine, text: text, time: time, type: type, seconds: seconds, remoteId: remoteId, url: url,
          bytes: local.bytes, readAt: readAt, blocked: blocked, clientId: clientId, replyTo: replyTo, deleted: deleted);

  /// The same message after its sender deleted it (Round G1).
  Message asDeleted() => Message(mine: mine, text: '', time: time, type: type == MsgType.call || type == MsgType.system ? type : MsgType.text,
      remoteId: remoteId, readAt: readAt, blocked: blocked, clientId: clientId, replyTo: replyTo, deleted: true);
}

class Conversation {
  String id; // backend conversation id ('' until the chat is created on the server)
  final L name;
  final Color color;
  final Tutor? tutor;
  final String? counterpartId; // the other person's user id (backend)
  final List<Message> messages;
  int unread;
  bool online;
  String photo; // the other person's profile photo ('' = initials)
  bool hasOlder = false; // older messages exist on the server (load on scroll)
  bool loadingOlder = false;

  Conversation({required this.id, required this.name, required this.color, this.tutor, this.counterpartId, required this.messages, this.unread = 0, this.online = false, this.photo = ''});

  Message? get last => messages.isEmpty ? null : messages.last;
}

class LiveRequest {
  final String id;
  final L studentName;
  final L subject;
  final L level;
  final String text;
  final int voiceSeconds;
  final DateTime created;
  final Color color;

  const LiveRequest({
    required this.id,
    required this.studentName,
    required this.subject,
    required this.level,
    required this.text,
    required this.voiceSeconds,
    required this.created,
    required this.color,
  });
}

class AppNotification {
  final L title;
  final L body;
  final DateTime time;
  final IconData icon;
  final Color color;
  bool read;
  final Map<String, dynamic> data; // what it is about: conversation_id, lesson_id, live_request_id…
  final int remoteId;
  AppNotification(this.title, this.body, this.time, this.icon, this.color, {this.read = false, this.data = const {}, this.remoteId = 0});
}

class WalletTx {
  final L title;
  final double amount;
  final DateTime date;
  final L status;
  const WalletTx(this.title, this.amount, this.date, this.status);
}

/// One student of a tutor and where things stand with them.
class StudentSummary {
  final String id;
  final L name;
  final List<Lesson> lessons;
  final int completed;
  final int upcoming;
  final int pendingPayment;
  final int cancelled;
  final Lesson? next;
  final Lesson? last;
  final double earned;
  const StudentSummary({
    required this.id,
    required this.name,
    required this.lessons,
    required this.completed,
    required this.upcoming,
    required this.pendingPayment,
    required this.cancelled,
    required this.next,
    required this.last,
    required this.earned,
  });
}

/// One working period of a tutor's week, in the tutor's own local time.
class WorkPeriod {
  final int weekday; // 0 = Sunday … 6 = Saturday
  final int start; // minutes after midnight
  final int end; // minutes after midnight (1440 = end of the day)
  const WorkPeriod(this.weekday, this.start, this.end);

  static String hm(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  /// "09:00" / "09:00:00" / "24:00:00" → minutes.
  static int parse(String s) {
    final p = s.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }
}

/// What a student needs to choose a lesson time with a tutor.
class TutorSchedule {
  final int tzOffset; // the tutor's UTC offset in minutes
  final List<WorkPeriod> periods; // empty = the tutor has not set working hours
  final List<({DateTime start, DateTime end})> busy; // times already booked
  const TutorSchedule({required this.tzOffset, required this.periods, required this.busy});
}

/// A payment of mine made by transfer (a wallet top-up, or a booking paid by transfer).
class PaymentInfo {
  final String id;
  final double amount;
  final String method; // sham_cash | syriatel_cash | mtn_cash | bank_transfer | …
  final String status; // pending | under_review | paid | failed | refunded
  final String reference;
  final String failReason;
  final DateTime created;
  const PaymentInfo({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    required this.reference,
    required this.failReason,
    required this.created,
  });
}

/// Where to send the money for one payment, and what to write in the transfer note.
class TransferInfo {
  final String paymentId;
  final double amount;
  final String method; // payment method value (sham_cash … bank_transfer)
  final String payTo; // account / wallet number
  final String reference; // e.g. D-7KQ2MX
  const TransferInfo({required this.paymentId, required this.amount, required this.method, required this.payTo, required this.reference});
}
