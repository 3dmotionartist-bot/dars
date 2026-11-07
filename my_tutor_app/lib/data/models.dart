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

  HoursPackage({
    required this.id,
    required this.tutor,
    required this.totalHours,
    required this.usedHours,
    required this.discount,
    required this.active,
    required this.price,
  });

  double get remaining => totalHours - usedHours;
}

enum MsgType { text, voice, file, system }

class Message {
  final bool mine;
  final String text;
  final DateTime time;
  final MsgType type;
  final int seconds;
  const Message({required this.mine, required this.text, required this.time, this.type = MsgType.text, this.seconds = 0});
}

class Conversation {
  final String id;
  final L name;
  final Color color;
  final Tutor? tutor;
  final List<Message> messages;
  int unread;
  bool online;

  Conversation({required this.id, required this.name, required this.color, this.tutor, required this.messages, this.unread = 0, this.online = false});

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
  AppNotification(this.title, this.body, this.time, this.icon, this.color, {this.read = false});
}

class WalletTx {
  final L title;
  final double amount;
  final DateTime date;
  final L status;
  const WalletTx(this.title, this.amount, this.date, this.status);
}
