import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart' show RealtimeChannel;

import '../config.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../l10n.dart';
import '../services/calls.dart';

/// Lets the state show short messages (errors, confirmations) from anywhere.
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Lets the state show the incoming-call pop-up from anywhere.
final navigatorKey = GlobalKey<NavigatorState>();

/// Single app-wide store.
/// DEMO mode (config.dart empty): works offline with sample data.
/// LIVE mode: every action goes to the Supabase backend — the same data the admin dashboard manages.
class AppState extends ChangeNotifier {
  AppState() {
    if (live) _boot();
  }

  final bool live = DarsConfig.live;
  Backend get _b => Backend.I;

  /// True while a saved session is being restored on launch (live mode).
  bool booting = DarsConfig.live;

  // ---------- session ----------
  Locale locale = const Locale('ar');
  bool loggedIn = false;
  UserRole role = UserRole.student;
  String phone = '';
  String name = DarsConfig.live ? '' : 'محمد';
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

  // ---------- catalog ----------
  final List<Tutor> tutors = DarsConfig.live ? <Tutor>[] : List.of(MockData.tutors);
  Tutor? tutorById(String id) {
    for (final t in tutors) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ---------- student data ----------
  final List<Lesson> lessons = DarsConfig.live ? <Lesson>[] : MockData.studentLessons();
  final List<HoursPackage> packages = DarsConfig.live ? <HoursPackage>[] : MockData.packages();
  final List<Conversation> conversations = DarsConfig.live ? <Conversation>[] : MockData.conversations();
  final List<AppNotification> notifications = DarsConfig.live ? <AppNotification>[] : MockData.notifications();
  final List<WalletTx> transactions = DarsConfig.live ? <WalletTx>[] : MockData.transactions();
  final Set<String> favorites = DarsConfig.live ? <String>{} : {'t1'};
  double walletBalance = DarsConfig.live ? 0 : 25;
  String callPermission = 'mine'; // all | mine | ask
  /// Amount still to pay for the last booking (live mode; 0 = fully paid).
  double lastAmountDue = 0;

  // ---------- tutor data ----------
  final List<Lesson> tutorLessons = DarsConfig.live ? <Lesson>[] : MockData.tutorLessons();
  final List<LiveRequest> liveRequests = DarsConfig.live ? <LiveRequest>[] : MockData.liveRequests();
  bool tutorAvailable = !DarsConfig.live;
  int dndHours = 0;
  bool instantBooking = true;
  bool packagesEnabled = true;
  String realtimeMode = 'any'; // any | working
  double tutorPending = DarsConfig.live ? 0 : 180;
  double tutorConfirmed = DarsConfig.live ? 0 : 420;
  final Map<int, int> packageDiscounts = {4: 5, 8: 10, 12: 15, 20: 20};
  final Map<String, bool> workingDays = {
    'day_sat': true, 'day_sun': true, 'day_mon': true, 'day_tue': true,
    'day_wed': true, 'day_thu': false, 'day_fri': false,
  };
  /// Live mode: 'pending' | 'approved' | 'rejected' for the signed-in tutor.
  String? tutorVerification;
  String? rejectionReason;
  Tutor? _me;

  /// The signed-in tutor's public card.
  Tutor get me => _me ?? MockData.tutors.first;

  double get tutorGross => tutorLessons.where((l) => l.status == LessonStatus.delivered).fold(0.0, (s, l) => s + l.price);
  double get tutorCommission => live
      ? tutorLessons.where((l) => l.status == LessonStatus.delivered).fold(0.0, (s, l) => s + l.commission)
      : tutorGross * 0.15;

  // =====================================================================
  // helpers
  // =====================================================================
  String _t(String ar, String en) => locale.languageCode == 'ar' ? ar : en;

  void say(String text, {bool bad = false}) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: bad ? const Color(0xFFE5484D) : null,
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _error(Object e) => say(Backend.errorText(e), bad: true);

  /// Runs a backend call, reloads data, and shows the error if it fails.
  Future<bool> _run(Future<dynamic> Function() call, {bool reload = true, String? ok}) async {
    try {
      await call();
      if (reload) await refresh();
      if (ok != null) say(ok);
      return true;
    } catch (e) {
      _error(e);
      if (reload) await refresh();
      return false;
    }
  }

  static L _name(String? n, L fallback) => (n == null || n.trim().isEmpty) ? fallback : L(n, n);

  // =====================================================================
  // live mode: loading
  // =====================================================================
  RealtimeChannel? _channel;
  Timer? _poll;
  Conversation? activeConversation;

  Future<void> _boot() async {
    try {
      await _b.init();
      await _loadTutors();
      if (_b.uid != null && await _loadProfile()) {
        loggedIn = true;
        await refresh();
        _startRealtime();
      }
    } catch (e) {
      _error(e);
    }
    booting = false;
    notifyListeners();
  }

  /// Reloads everything for the signed-in user (pull-to-refresh, after actions).
  Future<void> refresh() async {
    if (!live || _b.uid == null) return;
    try {
      await Future.wait([_loadTutors(), _loadWallet(), _loadNotifications()]);
      await _loadLessons();
      await _loadConversations();
      if (role == UserRole.tutor) {
        await _loadLiveRequests();
      } else {
        await _loadPackages();
      }
    } catch (e) {
      _error(e);
    }
    notifyListeners();
  }

  Future<bool> _loadProfile() async {
    final p = await _b.myProfile();
    if (p == null) return false;
    final r = '${p['role']}';
    role = r == 'tutor' ? UserRole.tutor : (r == 'parent' ? UserRole.parent : UserRole.student);
    name = (p['full_name'] as String?) ?? '';
    phone = (p['phone'] as String?) ?? (p['email'] as String?) ?? '';
    levelId = (p['level_id'] as String?) ?? levelId;
    curriculumId = (p['curriculum_id'] as String?) ?? curriculumId;
    if (p['locale'] == 'en' || p['locale'] == 'ar') locale = Locale(p['locale'] as String);
    if (role != UserRole.tutor) return name.trim().isNotEmpty;

    final tp = await _b.myTutorProfile();
    if (tp == null) return false;
    tutorVerification = '${tp['verification']}';
    rejectionReason = tp['rejection_reason'] as String?;
    final dnd = tp['dnd_until'] == null ? null : Backend.time(tp['dnd_until']);
    tutorAvailable = tp['available_now'] == true && (dnd == null || dnd.isBefore(DateTime.now()));
    instantBooking = tp['instant_booking'] != false;
    packagesEnabled = ((tp['max_package_discount'] as num?) ?? 0) > 0;
    realtimeMode = tp['realtime_any_time'] == false ? 'working' : 'any';
    final subjects = await _b.mySubjects();
    _me = Backend.tutorFromRow({...tp, 'id': _b.uid, 'full_name': name, 'subject_ids': subjects});
    return name.trim().isNotEmpty && '${tp['headline'] ?? ''}'.trim().isNotEmpty;
  }

  Future<void> _loadTutors() async {
    final rows = await _b.publicTutors();
    var reviewRows = <Map<String, dynamic>>[];
    try {
      reviewRows = await _b.visibleReviews();
    } catch (_) {}
    final byTutor = <String, List<Review>>{};
    for (final r in reviewRows) {
      final c = (r['comment'] as String?) ?? '';
      final d = Backend.time(r['created_at']);
      byTutor.putIfAbsent('${r['tutor_id']}', () => []).add(
            Review(const L('طالب في درس', 'Dars student'), (r['stars'] as num?)?.toInt() ?? 5, L(c, c), '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'),
          );
    }
    final list = [for (final r in rows) Backend.tutorFromRow(r, reviews: byTutor['${r['id']}'] ?? const [], interests: interests)];
    tutors
      ..clear()
      ..addAll(list);
  }

  Future<void> _loadWallet() async {
    final bal = await _b.walletBalance();
    final tx = await _b.walletTx();
    walletBalance = bal;
    if (role == UserRole.tutor) tutorConfirmed = bal;
    transactions
      ..clear()
      ..addAll(tx.map(Backend.txFromRow));
  }

  Future<void> _loadNotifications() async {
    final rows = await _b.notifications();
    notifications
      ..clear()
      ..addAll(rows.map(Backend.notificationFromRow));
  }

  Future<void> _loadLessons() async {
    final asTutor = role == UserRole.tutor;
    final rows = await _b.myLessons(asTutor: asTutor);
    final reviewed = <String>{};
    if (!asTutor) {
      for (final r in await _b.myReviews()) {
        reviewed.add('${r['lesson_id']}');
      }
    }
    final names = await _b.names(rows.map((r) => '${asTutor ? r['student_id'] : r['tutor_id']}'));
    final list = <Lesson>[];
    for (final r in rows) {
      if (asTutor) {
        final sid = '${r['student_id']}';
        list.add(Backend.lessonFromRow(r, tutor: me, studentName: _name(names[sid], const L('طالب', 'Student'))));
      } else {
        final tid = '${r['tutor_id']}';
        final t = tutorById(tid) ?? Backend.stubTutor(tid, names[tid] ?? '');
        list.add(Backend.lessonFromRow(r, tutor: t, studentName: const L('أنت', 'You'), reviewed: reviewed.contains('${r['id']}')));
      }
    }
    if (asTutor) {
      tutorLessons
        ..clear()
        ..addAll(list);
      tutorPending = list.where((l) => l.status == LessonStatus.upcoming).fold(0.0, (s, l) => s + l.price - l.commission);
    } else {
      lessons
        ..clear()
        ..addAll(list);
    }
  }

  Future<void> _loadPackages() async {
    final rows = await _b.myPackages();
    final names = await _b.names(rows.map((r) => '${r['tutor_id']}'));
    packages
      ..clear()
      ..addAll(rows.map((r) {
        final id = '${r['id']}';
        final tid = '${r['tutor_id']}';
        return HoursPackage(
          id: id.substring(0, 6).toUpperCase(),
          remoteId: id,
          tutor: tutorById(tid) ?? Backend.stubTutor(tid, names[tid] ?? ''),
          totalHours: (r['total_hours'] as num).toInt(),
          usedHours: ((r['used_minutes'] as num?) ?? 0) / 60.0,
          discount: (r['discount_pct'] as num?)?.toInt() ?? 0,
          active: r['status'] == 'active',
          price: ((r['price'] as num?) ?? 0).toDouble(),
        );
      }));
  }

  Future<void> _loadConversations() async {
    final uid = _b.uid!;
    final rows = await _b.conversations();
    final others = {for (final r in rows) '${r['id']}': '${r['student_id'] == uid ? r['tutor_id'] : r['student_id']}'};
    final names = await _b.names(others.values);
    final msgs = await _b.messagesFor(rows.map((r) => '${r['id']}').toList());
    final byConv = <String, List<Map<String, dynamic>>>{};
    for (final m in msgs) {
      byConv.putIfAbsent('${m['conversation_id']}', () => []).add(m);
    }
    final next = <Conversation>[];
    for (final r in rows) {
      final id = '${r['id']}';
      final other = others[id]!;
      final iAmStudent = r['student_id'] == uid;
      final tutor = iAmStudent ? (tutorById(other) ?? Backend.stubTutor(other, names[other] ?? '')) : null;
      final mrows = byConv[id] ?? const [];
      final messages = [for (final m in mrows) Backend.messageFromRow(m, uid)];
      final unread = mrows.where((m) => m['sender_id'] != null && m['sender_id'] != uid && m['read_at'] == null).length;
      // Re-use the object an open chat screen is holding, so new messages appear there.
      Conversation? c;
      for (final x in conversations) {
        if (x.id == id) c = x;
      }
      if (c != null) {
        c.messages
          ..clear()
          ..addAll(messages);
        c.unread = identical(c, activeConversation) ? 0 : unread;
        c.online = tutor?.available ?? false;
      } else {
        c = Conversation(
          id: id,
          name: tutor?.name ?? _name(names[other], const L('طالب', 'Student')),
          color: tutor?.color ?? Backend.colorFor(other),
          tutor: tutor,
          counterpartId: other,
          messages: messages,
          unread: unread,
          online: tutor?.available ?? false,
        );
      }
      next.add(c);
    }
    // Keep chats that are still being created on the server.
    final pending = conversations.where((c) => c.id.isEmpty).toList();
    conversations
      ..clear()
      ..addAll(pending)
      ..addAll(next);
  }

  Future<void> _loadLiveRequests() async {
    if (tutorVerification != 'approved') {
      liveRequests.clear();
      return;
    }
    final rows = await _b.openLiveRequests();
    liveRequests
      ..clear()
      ..addAll(rows.map(_liveFromRow));
  }

  LiveRequest _liveFromRow(Map<String, dynamic> r) {
    final lvl = MockData.levels.firstWhere((l) => l.id == r['level_id'], orElse: () => MockData.levels[3]);
    return LiveRequest(
      id: '${r['id']}',
      studentName: const L('طالب', 'Student'),
      subject: MockData.subject((r['subject_id'] as String?) ?? 'math').name,
      level: lvl.name,
      text: (r['body'] as String?) ?? '',
      voiceSeconds: (r['voice_sec'] as num?)?.toInt() ?? 0,
      // The request card counts down from created + 120 s; align it with the server's expiry.
      created: Backend.time(r['expires_at']).subtract(const Duration(seconds: 120)),
      color: Backend.colorFor('${r['id']}'),
    );
  }

  void _startRealtime() {
    _stopRealtime();
    try {
      _channel = _b.listen(
        onMessage: _onRemoteMessage,
        onNotification: (r) {
          final n = Backend.notificationFromRow(r);
          notifications.insert(0, n);
          final title = '${r['title']}';
          if (title.isNotEmpty) say(_t(n.title.ar, n.title.en));
          if (RegExp(r'book|cancel|Payment|Payout|Refund|approved|changes|review|Missed|rescheduled', caseSensitive: false).hasMatch(title)) {
            _loadProfile().then((_) => refresh());
          } else {
            notifyListeners();
          }
        },
        onLiveRequest: role == UserRole.tutor ? (_) => _loadLiveRequests().then((_) => notifyListeners()).catchError((_) {}) : null,
      );
    } catch (_) {}
    // Fallback in case realtime is not enabled on the project.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        if (role == UserRole.tutor) await _loadLiveRequests();
        await _loadConversations();
        notifyListeners();
      } catch (_) {}
    });
  }

  void _stopRealtime() {
    _poll?.cancel();
    _poll = null;
    final ch = _channel;
    _channel = null;
    if (ch != null) _b.unlisten(ch).catchError((_) => '');
  }

  void _onRemoteMessage(Map<String, dynamic> r) {
    final cid = '${r['conversation_id']}';
    Conversation? c;
    for (final x in conversations) {
      if (x.id == cid) c = x;
    }
    if (c == null) {
      _loadConversations().then((_) => notifyListeners()).catchError((_) {});
      return;
    }
    final m = Backend.messageFromRow(r, _b.uid);
    if (c.messages.any((x) => x.remoteId == m.remoteId)) return;
    if (m.mine) {
      final i = c.messages.lastIndexWhere((x) => x.mine && x.remoteId == 0 && x.text == m.text);
      if (i >= 0) {
        c.messages[i] = m;
        return;
      }
    }
    c.messages.add(m);
    if (m.type == MsgType.call && !m.mine && DateTime.now().difference(m.time).inMinutes < 2) _incomingCall(c, m);
    if (!m.mine) {
      if (identical(c, activeConversation)) {
        _b.markRead(c.id).catchError((_) {});
      } else {
        c.unread++;
      }
    }
    if (conversations.remove(c)) conversations.insert(0, c);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopRealtime();
    super.dispose();
  }

  // =====================================================================
  // session actions
  // =====================================================================
  void toggleLocale() {
    locale = locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
    notifyListeners();
    if (live && _b.uid != null) _b.updateProfile({'locale': locale.languageCode}).catchError((_) {});
  }

  /// Live mode: send the sign-in code by SMS/WhatsApp. Throws with a readable message on failure.
  Future<void> sendCode(String phoneNumber, UserRole asRole) => _b.sendPhoneCode(phoneNumber, asRole);

  /// Live mode: check the code. Returns true when the account is already set up (go straight in).
  Future<bool> verifyCode(String phoneNumber, String code) async {
    await _b.verifyPhoneCode(phoneNumber, code);
    return _afterSignIn();
  }

  /// Live mode: email + password sign-in / sign-up. Returns true when the account is already set up.
  Future<bool> emailAuth(String email, String password, UserRole asRole, {required bool create}) async {
    await _b.emailSignIn(email, password, asRole, create: create);
    return _afterSignIn();
  }

  Future<bool> _afterSignIn() async {
    final ready = await _loadProfile();
    if (ready) {
      loggedIn = true;
      await refresh();
      _startRealtime();
      notifyListeners();
    }
    return ready;
  }

  void login({required UserRole asRole, required String phoneNumber}) {
    if (live) {
      loggedIn = true;
      notifyListeners();
      refresh();
      _startRealtime();
      return;
    }
    role = asRole;
    phone = phoneNumber;
    loggedIn = true;
    notifyListeners();
  }

  void switchRole() {
    if (live) {
      say(_t('نوع الحساب يُحدد عند التسجيل — سجّل الخروج وادخل بحساب آخر', 'The account type is set at sign-up — sign out and use another account'));
      return;
    }
    role = role == UserRole.tutor ? UserRole.student : UserRole.tutor;
    notifyListeners();
  }

  Future<void> logout() async {
    loggedIn = false;
    notifyListeners();
    if (!live) return;
    _stopRealtime();
    try {
      await _b.signOut();
    } catch (_) {}
    for (final l in [lessons, packages, conversations, notifications, transactions, tutorLessons, liveRequests]) {
      l.clear();
    }
    _me = null;
    tutorVerification = null;
    walletBalance = 0;
    tutorConfirmed = 0;
    tutorPending = 0;
    name = '';
    notifyListeners();
  }

  /// Saves the student/parent profile (name, level, curriculum, interests).
  Future<void> setProfile({String? fullName, String? level, String? curriculum, Set<String>? subjects}) async {
    if (fullName != null && fullName.trim().isNotEmpty) name = fullName.trim();
    if (level != null) levelId = level;
    if (curriculum != null) curriculumId = curriculum;
    if (subjects != null) {
      interests
        ..clear()
        ..addAll(subjects);
    }
    notifyListeners();
    if (live) {
      await _b.updateProfile({
        if (name.isNotEmpty) 'full_name': name,
        'level_id': levelId,
        'curriculum_id': curriculumId,
        'locale': locale.languageCode,
      });
    }
  }

  /// Tutor application → shows up as "pending" in the admin dashboard.
  Future<void> registerTutor({
    required String fullName,
    required String gender,
    required String city,
    required Set<String> subjects,
    required Set<String> curricula,
    required bool online,
    required bool inPerson,
    required Map<String, double> fees,
    required String headline,
    required String about,
    String linkedin = '',
  }) async {
    if (fullName.trim().isNotEmpty) name = fullName.trim();
    if (!live) return;
    final h = headline.trim();
    await _b.saveTutorApplication(
      profile: {'full_name': name, 'gender': gender, if (city.trim().isNotEmpty) 'city': city.trim(), 'locale': locale.languageCode},
      tutor: {
        'headline': h.length > 80 ? h.substring(0, 80) : h,
        'about': about.trim().length > 1000 ? about.trim().substring(0, 1000) : about.trim(),
        'teaches_online': online,
        'teaches_in_person': inPerson,
        'hourly_price': double.parse((fees['high'] ?? fees.values.first).toStringAsFixed(2)),
        'max_package_discount': 20,
        if (linkedin.trim().isNotEmpty) 'linkedin_url': linkedin.trim(),
      },
      subjects: subjects,
      curricula: curricula,
      levelPrices: fees,
    );
    await _loadProfile();
  }

  // =====================================================================
  // student actions
  // =====================================================================
  void toggleFavorite(String tutorId) {
    favorites.contains(tutorId) ? favorites.remove(tutorId) : favorites.add(tutorId);
    notifyListeners();
  }

  int get unreadMessages => conversations.fold(0, (s, c) => s + c.unread);
  int get unreadNotifications => notifications.where((n) => !n.read).length;

  Lesson? get nextLesson {
    final up = lessons.where((l) => l.status == LessonStatus.upcoming).toList()..sort((a, b) => a.start.compareTo(b.start));
    return up.isEmpty ? null : up.first;
  }

  static const _methods = {'card': 'card', 'apple': 'apple_pay', 'bnpl': 'bnpl', 'bank': 'bank_transfer', 'mada': 'mada'};

  /// Books a single lesson or buys a package. Returns the new lesson (single) or null (package).
  /// Live mode throws a readable error if the server refuses (slot taken, tutor unavailable…).
  Future<Lesson?> book({
    required Tutor tutor,
    required bool isPackage,
    required int hours,
    required int minutes,
    required DateTime start,
    required bool online,
    required double total,
    required double balanceUsed,
    required L subject,
    String? subjectId,
    String method = 'card',
  }) async {
    if (live) {
      final pm = _methods[method] ?? 'card';
      final Map res;
      if (isPackage) {
        res = await _b.rpc('buy_package', {'p_tutor': tutor.id, 'p_hours': hours, 'p_level': levelId, 'p_use_wallet': balanceUsed > 0, 'p_method': pm}) as Map;
      } else {
        res = await _b.rpc('book_lesson', {
          'p_tutor': tutor.id,
          'p_starts_at': start.toUtc().toIso8601String(),
          'p_duration': minutes,
          'p_subject': subjectId ?? tutor.subjectIds.first,
          'p_level': levelId,
          'p_mode': online ? 'online' : 'in_person',
          'p_use_wallet': balanceUsed > 0,
          'p_method': pm,
        }) as Map;
      }
      lastAmountDue = ((res['amount_due'] as num?) ?? 0).toDouble();
      await refresh();
      final id = res['lesson_id'];
      for (final l in lessons) {
        if (l.id == id) return l;
      }
      return null;
    }

    lastAmountDue = 0;
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
    if (live) {
      _run(() => _b.rpc('cancel_lesson', {'p_lesson': l.id}), ok: _t('تم إلغاء الدرس', 'Lesson cancelled'));
      return;
    }
    l.status = LessonStatus.cancelled;
    walletBalance += l.price;
    transactions.insert(0, WalletTx(L('استرداد ${l.id}', 'Refund ${l.id}'), l.price, DateTime.now(), const L('مسترد', 'Refunded')));
    notifyListeners();
  }

  void payPending(Lesson l) {
    if (live) {
      say(_t('حجزك محفوظ. يؤكد فريق درس الدفع فور استلامه (التحويل البنكي من لوحة الإدارة).', 'Your booking is held. The Dars team confirms the payment as soon as it is received.'));
      refresh();
      return;
    }
    l.status = LessonStatus.upcoming;
    notifyListeners();
  }

  void reschedule(Lesson l, DateTime when) {
    if (live) {
      _run(() => _b.rpc('reschedule_lesson', {'p_lesson': l.id, 'p_starts_at': when.toUtc().toIso8601String()}), ok: _t('تم تغيير الموعد', 'Lesson rescheduled'));
      return;
    }
    l.start = when;
    notifyListeners();
  }

  void markReviewed(Lesson l, {int stars = 5, String? comment}) {
    l.reviewed = true;
    notifyListeners();
    if (live) {
      _run(() => _b.rpc('leave_review', {'p_lesson': l.id, 'p_stars': stars, 'p_comment': (comment ?? '').trim().isEmpty ? null : comment!.trim()}));
    }
  }

  /// "Not satisfied" / "Tutor didn't show" → a report the admin team handles (refund or release).
  void disputeLesson(Lesson l, String reason) {
    if (live) _run(() => _b.rpc('dispute_lesson', {'p_lesson': l.id, 'p_reason': reason}));
  }

  void usePackageHour(HoursPackage p, double hours, {DateTime? start}) {
    if (live && p.remoteId != null) {
      final when = start ?? DateTime.now().add(const Duration(days: 1));
      _run(
        () => _b.rpc('book_from_package', {
          'p_package': p.remoteId,
          'p_starts_at': when.toUtc().toIso8601String(),
          'p_duration': (hours * 60).round(),
          'p_subject': p.tutor.subjectIds.first,
        }),
        ok: _t('تم حجز الدرس من الباقة', 'Lesson booked from your package'),
      );
      return;
    }
    p.usedHours = (p.usedHours + hours).clamp(0.0, p.totalHours.toDouble()).toDouble();
    notifyListeners();
  }

  void requestRefund() {
    if (live) {
      final amount = walletBalance;
      _run(
        () => _b.db.from('reports').insert({
          'reporter_id': _b.uid,
          'target_type': 'user',
          'target_id': _b.uid,
          'reason': 'Wallet refund request: \$${amount.toStringAsFixed(2)}',
        }),
        reload: false,
        ok: _t('تم إرسال طلب الاسترداد لفريق درس', 'Refund request sent to the Dars team'),
      );
      return;
    }
    transactions.insert(0, WalletTx(const L('طلب استرداد الرصيد', 'Balance refund request'), -walletBalance, DateTime.now(), const L('قيد المعالجة', 'In process')));
    walletBalance = 0;
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
    if (live) _b.markNotificationsRead().catchError((_) {});
  }

  void setCallPermission(String v) {
    callPermission = v;
    notifyListeners();
  }

  /// "Help me find a tutor" → appears in the dashboard's Help requests.
  Future<void> submitLead({
    required String fullName,
    required String whatsapp,
    String city = '',
    required String who,
    required String levelId,
    required String subjectId,
    required String reason,
    required String mode,
    String notes = '',
  }) async {
    if (!live) return;
    await _b.submitLead({
      'full_name': fullName.trim(),
      'whatsapp': whatsapp.trim(),
      if (city.trim().isNotEmpty) 'city': city.trim(),
      'who': who,
      'level_id': levelId,
      'subject_id': subjectId,
      'reason': reason,
      'mode': mode,
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  // ---------- live help (student) ----------
  Future<String> createLiveRequest({required String subject, String text = '', int voiceSeconds = 0}) async {
    final body = text.trim().isEmpty ? '🎤 ${voiceSeconds}s' : text.trim();
    final id = await _b.rpc('create_live_request', {
      'p_subject': subject,
      'p_level': levelId,
      'p_body': body,
      'p_voice_sec': voiceSeconds > 0 ? voiceSeconds : null,
    });
    return '$id';
  }

  Future<List<Tutor>> liveAccepted(String requestId) async {
    final ids = await _b.liveAcceptedTutors(requestId);
    if (ids.any((id) => tutorById(id) == null)) await _loadTutors();
    return [for (final id in ids) tutorById(id) ?? Backend.stubTutor(id, '')];
  }

  void cancelLiveRequest(String requestId) {
    if (live) _b.rpc('cancel_live_request', {'p_request': requestId}).catchError((_) => null);
  }

  // =====================================================================
  // chat
  // =====================================================================
  final Map<Conversation, Future<String>> _creating = {};

  Conversation conversationFor(Tutor t) {
    for (final c in conversations) {
      if (c.tutor?.id == t.id || c.counterpartId == t.id) return c;
    }
    final c = Conversation(id: live ? '' : 'c${conversations.length + 1}', name: t.name, color: t.color, tutor: t, counterpartId: t.id, messages: [], online: t.available);
    conversations.insert(0, c);
    if (live) _ensure(c).catchError((Object e) {
      _error(e);
      return '';
    });
    return c;
  }

  Future<String> _ensure(Conversation c) {
    if (c.id.isNotEmpty) return Future.value(c.id);
    return _creating[c] ??= () async {
      final id = '${await _b.rpc('start_conversation', {'p_tutor': c.counterpartId})}';
      _adopt(c, id);
      return id;
    }();
  }

  /// Gives a locally created chat its server id (and drops any duplicate already loaded).
  void _adopt(Conversation c, String id) {
    conversations.removeWhere((x) => !identical(x, c) && x.id == id);
    c.id = id;
    _creating.remove(c);
    notifyListeners();
  }

  void openConversation(Conversation c) {
    c.unread = 0;
    activeConversation = c;
    notifyListeners();
    if (live && c.id.isNotEmpty) _b.markRead(c.id).catchError((_) {});
  }

  void closeConversation(Conversation c) {
    if (identical(activeConversation, c)) activeConversation = null;
  }

  static final _contactPattern = RegExp(r'(\+?\d[\d\s\-]{6,}\d)|([\w.\-]+@[\w\-]+\.\w+)');

  /// Returns false when the message was blocked by the contact-info filter.
  bool sendMessage(Conversation c, Message m) {
    if (m.type == MsgType.text && _contactPattern.hasMatch(m.text)) return false;
    c.messages.add(m);
    if (conversations.remove(c)) conversations.insert(0, c);
    notifyListeners();
    if (live && m.mine) _push(c, m);
    return true;
  }

  Future<void> _push(Conversation c, Message m) async {
    try {
      final id = await _ensure(c);
      final kind = switch (m.type) { MsgType.voice => 'voice', MsgType.file => 'file', MsgType.call => 'call', _ => 'text' };
      final text = m.type == MsgType.voice ? '🎤' : m.text;
      await _b.sendMessage(id, text, kind: kind, seconds: m.seconds > 0 ? m.seconds : null);
    } catch (e) {
      _error(e);
    }
  }

  // =====================================================================
  // calls (voice & video)
  // =====================================================================
  String _nameOf(L n) => locale.languageCode == 'ar' ? n.ar : n.en;

  /// Opens a call room in the browser. Both people open the same room to talk.
  Future<void> joinCall({required String room, required bool video, String peer = ''}) async {
    final ok = await Calls.open(Calls.link(room: room, video: video, peer: peer, name: name, lang: locale.languageCode));
    if (!ok) say(_t('تعذّر فتح المكالمة. تأكد من وجود متصفح على الجهاز.', 'Could not open the call. Make sure a browser is installed.'), bad: true);
  }

  /// Calls the other person in a chat: sends them a "join call" message (and a pop-up if their app is open),
  /// then opens the call for me.
  Future<void> startCall(Conversation c, {required bool video}) async {
    final room = Calls.newRoom();
    final m = Message(mine: true, text: Calls.invite(room, video: video), time: DateTime.now(), type: MsgType.call);
    c.messages.add(m);
    if (conversations.remove(c)) conversations.insert(0, c);
    notifyListeners();
    if (live) await _push(c, m);
    await joinCall(room: room, video: video, peer: _nameOf(c.name));
  }

  /// Video room for a booked lesson — the student and the tutor both join from "Join lesson".
  Future<void> joinLesson(Lesson l) {
    final other = role == UserRole.tutor ? _nameOf(l.studentName) : _nameOf(l.tutor.name);
    return joinCall(room: 'lesson-${l.id}', video: true, peer: other);
  }

  void _incomingCall(Conversation c, Message m) {
    final inv = Calls.parse(m.text);
    final ctx = navigatorKey.currentContext;
    if (inv == null || ctx == null) return;
    final who = _nameOf(c.name);
    showDialog<void>(
      context: ctx,
      builder: (d) => AlertDialog(
        icon: Icon(inv.video ? Icons.videocam_rounded : Icons.call_rounded, color: const Color(0xFF0E8F7E), size: 40),
        title: Text(who, textAlign: TextAlign.center),
        content: Text(
          inv.video ? _t('مكالمة فيديو واردة', 'Incoming video call') : _t('مكالمة صوتية واردة', 'Incoming voice call'),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(_t('رفض', 'Decline'), style: const TextStyle(color: Color(0xFFE5484D)))),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(d);
              joinCall(room: inv.room, video: inv.video, peer: who);
            },
            icon: const Icon(Icons.call_rounded),
            label: Text(_t('انضم', 'Join')),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // tutor actions
  // =====================================================================
  void setAvailable(bool v) {
    tutorAvailable = v;
    if (v) dndHours = 0;
    notifyListeners();
    if (live) _run(() => _b.rpc('set_availability', {'p_available': v, 'p_dnd_hours': 0}), reload: false);
  }

  void setDnd(int hours) {
    dndHours = hours;
    tutorAvailable = hours == 0;
    notifyListeners();
    if (live) _run(() => _b.rpc('set_availability', {'p_available': hours == 0, 'p_dnd_hours': hours}), reload: false);
  }

  void updateTutorSettings({bool? instant, bool? packages, String? rtMode}) {
    if (instant != null) instantBooking = instant;
    if (packages != null) packagesEnabled = packages;
    if (rtMode != null) realtimeMode = rtMode;
    notifyListeners();
    if (live) {
      _run(
        () => _b.updateTutor({
          if (instant != null) 'instant_booking': instant,
          if (packages != null) 'max_package_discount': packages ? math.max(5, _maxDiscount).clamp(0, 50) : 0,
          if (rtMode != null) 'realtime_any_time': rtMode == 'any',
        }),
        reload: false,
      );
    }
  }

  void setPackageDiscount(int hours, int value) {
    packageDiscounts[hours] = value;
    notifyListeners();
    if (live && packagesEnabled) {
      _run(() => _b.updateTutor({'max_package_discount': _maxDiscount.clamp(0, 50)}), reload: false);
    }
  }

  int get _maxDiscount => packageDiscounts.values.fold(0, (a, b) => a > b ? a : b);

  void toggleWorkingDay(String key) {
    workingDays[key] = !(workingDays[key] ?? false);
    notifyListeners();
  }

  Conversation acceptRequest(LiveRequest r, String greeting) {
    liveRequests.remove(r);
    final c = Conversation(
      id: live ? '' : 'cr${r.id}',
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
    if (live) {
      _creating[c] = () async {
        try {
          final id = '${await _b.rpc('respond_live_request', {'p_request': r.id, 'p_accept': true, 'p_greeting': greeting})}';
          _adopt(c, id);
          await _loadConversations();
          notifyListeners();
          return id;
        } catch (e) {
          conversations.remove(c);
          _creating.remove(c);
          _error(e);
          notifyListeners();
          rethrow;
        }
      }();
      _creating[c]!.catchError((_) => '');
    }
    return c;
  }

  void declineRequest(LiveRequest r) {
    liveRequests.remove(r);
    notifyListeners();
    if (live) _run(() => _b.rpc('respond_live_request', {'p_request': r.id, 'p_accept': false}), reload: false);
  }

  void setLessonLink(Lesson l, String link) {
    l.link = link;
    notifyListeners();
    if (live) _run(() => _b.rpc('set_lesson_link', {'p_lesson': l.id, 'p_meeting_url': link}), reload: false);
  }

  void markDelivered(Lesson l) {
    if (live) {
      _run(() => _b.rpc('mark_lesson_delivered', {'p_lesson': l.id}), ok: _t('تم تسجيل الدرس كمكتمل', 'Lesson marked as delivered'));
      return;
    }
    l.status = LessonStatus.delivered;
    tutorPending += l.price * 0.85;
    notifyListeners();
  }

  void reportStudentNoShow(Lesson l) {
    if (live) _run(() => _b.rpc('report_student_no_show', {'p_lesson': l.id}));
  }

  static const _payoutMethods = {'bank': 'bank_transfer', 'paypal': 'paypal', 'wu': 'western_union'};

  void requestPayout({String method = 'bank'}) {
    if (live) {
      final amount = tutorConfirmed;
      _run(() => _b.rpc('request_payout', {
            'p_amount': double.parse(amount.toStringAsFixed(2)),
            'p_method': _payoutMethods[method] ?? 'bank_transfer',
            'p_details': {'requested_from': 'app', 'name': name, 'phone': phone},
          }));
      return;
    }
    tutorConfirmed = 0;
    notifyListeners();
  }
}
