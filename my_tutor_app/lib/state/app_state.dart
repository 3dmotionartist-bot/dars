import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../l10n.dart';

/// Single app-wide store. Every mutation is where a real API call would go.
class AppState extends ChangeNotifier {
  // ---------- session ----------
  Locale locale = const Locale('ar');
  bool loggedIn = false;
  UserRole role = UserRole.student;
  String phone = '';
  String name = 'محمد';
  String levelId = 'high';
  String curriculumId = 'syrian';
  final Set<String> interests = {'math', 'english'};

  // ---------- navigation (student tabs) ----------
  int studentTab = 0;
  String? subjectFilter;
  void goTab(int i, {String? subject}) {
    studentTab = i;
    if (subject != null) subjectFilter = subject;
    notifyListeners();
  }

  // ---------- student data ----------
  final List<Lesson> lessons = MockData.studentLessons();
  final List<HoursPackage> packages = MockData.packages();
  final List<Conversation> conversations = MockData.conversations();
  final List<AppNotification> notifications = MockData.notifications();
  final List<WalletTx> transactions = MockData.transactions();
  final Set<String> favorites = {'t1'};
  double walletBalance = 25;
  String callPermission = 'mine'; // all | mine | ask

  // ---------- tutor data ----------
  final List<Lesson> tutorLessons = MockData.tutorLessons();
  final List<LiveRequest> liveRequests = MockData.liveRequests();
  bool tutorAvailable = true;
  int dndHours = 0;
  bool instantBooking = true;
  bool packagesEnabled = true;
  String realtimeMode = 'any'; // any | working
  double tutorPending = 180;
  double tutorConfirmed = 420;
  final Map<int, int> packageDiscounts = {4: 5, 8: 10, 12: 15, 20: 20};
  final Map<String, bool> workingDays = {
    'day_sat': true, 'day_sun': true, 'day_mon': true, 'day_tue': true,
    'day_wed': true, 'day_thu': false, 'day_fri': false,
  };

  // ---------- session actions ----------
  void toggleLocale() {
    locale = locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
    notifyListeners();
  }

  void login({required UserRole asRole, required String phoneNumber}) {
    role = asRole;
    phone = phoneNumber;
    loggedIn = true;
    notifyListeners();
  }

  void switchRole() {
    role = role == UserRole.tutor ? UserRole.student : UserRole.tutor;
    notifyListeners();
  }

  void logout() {
    loggedIn = false;
    notifyListeners();
  }

  void setProfile({String? level, String? curriculum, Set<String>? subjects}) {
    if (level != null) levelId = level;
    if (curriculum != null) curriculumId = curriculum;
    if (subjects != null) {
      interests
        ..clear()
        ..addAll(subjects);
    }
    notifyListeners();
  }

  // ---------- student actions ----------
  void toggleFavorite(String tutorId) {
    favorites.contains(tutorId) ? favorites.remove(tutorId) : favorites.add(tutorId);
    notifyListeners();
  }

  int get unreadMessages => conversations.fold(0, (s, c) => s + c.unread);
  int get unreadNotifications => notifications.where((n) => !n.read).length;

  Lesson? get nextLesson {
    final up = lessons.where((l) => l.status == LessonStatus.upcoming).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return up.isEmpty ? null : up.first;
  }

  /// Books a single lesson or buys a package. Returns the new lesson (single) or null (package).
  Lesson? book({
    required Tutor tutor,
    required bool isPackage,
    required int hours,
    required int minutes,
    required DateTime start,
    required bool online,
    required double total,
    required double balanceUsed,
    required L subject,
  }) {
    walletBalance -= balanceUsed;
    transactions.insert(
      0,
      WalletTx(
        isPackage ? L('باقة $hours ساعات - ${tutor.name.ar}', '$hours-hour package - ${tutor.name.en}') : L('حجز درس - ${tutor.name.ar}', 'Lesson booking - ${tutor.name.en}'),
        -total - balanceUsed,
        DateTime.now(),
        const L('مدفوع', 'Paid'),
      ),
    );
    Lesson? created;
    if (isPackage) {
      packages.insert(
        0,
        HoursPackage(id: 'P${400 + packages.length}', tutor: tutor, totalHours: hours, usedHours: 0, discount: discountFor(tutor, hours), active: true, price: total + balanceUsed),
      );
    } else {
      created = Lesson(
        id: 'L${1100 + lessons.length}',
        tutor: tutor,
        studentName: const L('أنت', 'You'),
        subject: subject,
        start: start,
        minutes: minutes,
        online: online,
        status: LessonStatus.upcoming,
        price: total + balanceUsed,
      );
      lessons.add(created);
    }
    notifications.insert(
      0,
      AppNotification(const L('تم تأكيد الدفع والحجز', 'Payment & booking confirmed'), L('مع ${tutor.name.ar}', 'With ${tutor.name.en}'), DateTime.now(), Icons.verified_rounded, const Color(0xFF22B573)),
    );
    conversationFor(tutor);
    notifyListeners();
    return created;
  }

  /// Tutor-defined package discount for a number of hours (capped by the tutor's max).
  int discountFor(Tutor t, int hours) {
    if (!t.hasPackages || hours < 4) return 0;
    final tiers = {4: 0.25, 8: 0.5, 12: 0.75, 20: 1.0};
    double f = 0.25;
    tiers.forEach((h, v) {
      if (hours >= h) f = v;
    });
    return (t.maxDiscount * f).round().clamp(1, t.maxDiscount).toInt();
  }

  void cancelLesson(Lesson l) {
    l.status = LessonStatus.cancelled;
    walletBalance += l.price;
    transactions.insert(0, WalletTx(L('استرداد ${l.id}', 'Refund ${l.id}'), l.price, DateTime.now(), const L('مسترد', 'Refunded')));
    notifyListeners();
  }

  void payPending(Lesson l) {
    l.status = LessonStatus.upcoming;
    notifyListeners();
  }

  void reschedule(Lesson l, DateTime when) {
    l.start = when;
    notifyListeners();
  }

  void markReviewed(Lesson l) {
    l.reviewed = true;
    notifyListeners();
  }

  void usePackageHour(HoursPackage p, double hours) {
    p.usedHours = (p.usedHours + hours).clamp(0.0, p.totalHours.toDouble()).toDouble();
    notifyListeners();
  }

  void requestRefund() {
    transactions.insert(0, WalletTx(const L('طلب استرداد الرصيد', 'Balance refund request'), -walletBalance, DateTime.now(), const L('قيد المعالجة', 'In process')));
    walletBalance = 0;
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void setCallPermission(String v) {
    callPermission = v;
    notifyListeners();
  }

  // ---------- chat ----------
  Conversation conversationFor(Tutor t) {
    for (final c in conversations) {
      if (c.tutor?.id == t.id) return c;
    }
    final c = Conversation(id: 'c${conversations.length + 1}', name: t.name, color: t.color, tutor: t, messages: [], online: t.available);
    conversations.insert(0, c);
    return c;
  }

  void openConversation(Conversation c) {
    c.unread = 0;
    notifyListeners();
  }

  static final _contactPattern = RegExp(r'(\+?\d[\d\s\-]{6,}\d)|([\w.\-]+@[\w\-]+\.\w+)');

  /// Returns false when the message was blocked by the contact-info filter.
  bool sendMessage(Conversation c, Message m) {
    if (m.type == MsgType.text && _contactPattern.hasMatch(m.text)) return false;
    c.messages.add(m);
    if (conversations.remove(c)) conversations.insert(0, c);
    notifyListeners();
    return true;
  }

  // ---------- tutor actions ----------
  void setAvailable(bool v) {
    tutorAvailable = v;
    if (v) dndHours = 0;
    notifyListeners();
  }

  void setDnd(int hours) {
    dndHours = hours;
    tutorAvailable = hours == 0;
    notifyListeners();
  }

  void updateTutorSettings({bool? instant, bool? packages, String? rtMode}) {
    if (instant != null) instantBooking = instant;
    if (packages != null) packagesEnabled = packages;
    if (rtMode != null) realtimeMode = rtMode;
    notifyListeners();
  }

  void setPackageDiscount(int hours, int value) {
    packageDiscounts[hours] = value;
    notifyListeners();
  }

  void toggleWorkingDay(String key) {
    workingDays[key] = !(workingDays[key] ?? false);
    notifyListeners();
  }

  Conversation acceptRequest(LiveRequest r, String greeting) {
    liveRequests.remove(r);
    final c = Conversation(
      id: 'cr${r.id}',
      name: r.studentName,
      color: r.color,
      online: true,
      messages: [
        if (r.text.isNotEmpty) Message(mine: false, text: r.text, time: r.created),
        if (r.voiceSeconds > 0) Message(mine: false, text: '', time: r.created, type: MsgType.voice, seconds: r.voiceSeconds),
        Message(mine: true, text: greeting, time: DateTime.now()),
      ],
    );
    conversations.insert(0, c);
    notifyListeners();
    return c;
  }

  void declineRequest(LiveRequest r) {
    liveRequests.remove(r);
    notifyListeners();
  }

  void setLessonLink(Lesson l, String link) {
    l.link = link;
    notifyListeners();
  }

  void markDelivered(Lesson l) {
    l.status = LessonStatus.delivered;
    tutorPending += l.price * 0.85;
    notifyListeners();
  }

  void requestPayout() {
    tutorConfirmed = 0;
    notifyListeners();
  }
}
