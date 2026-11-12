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
  const Review(this.author, this.stars, this.text, this.date);
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
  final int matchScore; // 0-100, AI best match
  final Color color;
  final bool teachesOnline;
  final bool teachesInPerson;
  final int cancelHours;
  final List<Review> reviews;
  final String photoUrl; // profile photo ('' = initials)
  final String videoUrl; // intro video ('' = none)

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
  });
}

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
  final String? clientId; // made once per message, sent on every attempt (no duplicates on retry)
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
      );

  /// The server's copy of this message, keeping the local photo preview.
  Message withPreviewOf(Message local) => local.bytes == null || bytes != null
      ? this
      : Message(
          mine: mine, text: text, time: time, type: type, seconds: seconds, remoteId: remoteId, url: url,
          bytes: local.bytes, readAt: readAt, blocked: blocked, clientId: clientId);
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
