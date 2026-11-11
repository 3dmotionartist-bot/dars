import 'dart:async';
import 'dart:math' as math;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart' show PostgrestException, RealtimeChannel;

import '../config.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../l10n.dart';
import '../screens/shared/incoming_call_screen.dart';
import '../screens/shared/live_call_screen.dart';
import '../screens/shared/transfer_screens.dart';
import '../services/calls.dart';
import '../services/media_bridge.dart';
import '../services/ringer.dart';

/// Lets the state show short messages (errors, confirmations) from anywhere.
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Lets the state show the incoming-call pop-up from anywhere.
final navigatorKey = GlobalKey<NavigatorState>();

/// Single app-wide store.
/// DEMO mode (config.dart empty): works offline with sample data.
/// LIVE mode: every action goes to the Supabase backend — the same data the admin dashboard manages.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState() {
    WidgetsBinding.instance.addObserver(this);
    if (live) _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _foreground = s == AppLifecycleState.resumed;
    if (_foreground && live && loggedIn) _resume();
  }

  bool _foreground = true;

  /// Coming back to the app: wake the sign-in up again and fetch anything missed.
  Future<void> _resume() async {
    _handleLaunchAction();
    checkLaunchLink();
    checkAppVersion();
    if (await _b.restore()) {
      _startRealtime();
      await refresh();
      retryFailedMessages();
    } else {
      _scheduleRestore();
    }
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

  String avatarUrl = ''; // my profile photo

  // ---------- navigation ----------
  int tutorTab = 0;
  void goTutorTab(int i) {
    tutorTab = i;
    notifyListeners();
  }

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
  /// The waiting payment of the last booking (live mode; null = nothing to pay).
  String? lastPaymentId;
  /// Pay-to accounts set up by Dars, by method: sham_cash, syriatel_cash, mtn_cash, bank ('' = not offered).
  Map<String, String> payTo = const {};
  /// My wallet top-ups (newest first).
  final List<PaymentInfo> topUps = [];

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
  /// The signed-in tutor's weekly working hours (their own local time). Empty = not set yet.
  List<WorkPeriod> workHours = const [
    WorkPeriod(6, 16 * 60, 22 * 60), WorkPeriod(0, 16 * 60, 22 * 60), WorkPeriod(1, 16 * 60, 22 * 60),
    WorkPeriod(2, 16 * 60, 22 * 60), WorkPeriod(3, 16 * 60, 22 * 60),
  ];
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
    } catch (e) {
      _error(e);
    }
    checkAppVersion();
    try {
      await _loadTutors();
    } catch (_) {/* offline — retried on refresh */}
    if (_b.hasSavedSession) {
      var ok = false;
      if (_b.uid != null) {
        try {
          ok = await _loadProfile();
          if (ok) await _saveProfileCache();
        } catch (_) {
          ok = await _readProfileCache(); // signed in, but the server is unreachable right now
        }
      } else {
        ok = await _readProfileCache(); // saved sign-in could not be refreshed yet (offline)
        if (ok) _scheduleRestore();
      }
      if (ok) {
        loggedIn = true;
        if (_b.uid != null) {
          await refresh();
          _startRealtime();
        }
      }
    }
    booting = false;
    notifyListeners();
    if (loggedIn) {
      Ringer.askPermission();
      Future.delayed(const Duration(seconds: 2), _handleLaunchAction);
    }
    Future.delayed(const Duration(milliseconds: 1500), checkLaunchLink);
  }

  // ---- staying signed in ----
  static const _profileKey = 'dars.profile';
  Timer? _restoreTimer;

  Future<void> _saveProfileCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_profileKey, jsonEncode({'uid': _b.uid, 'role': role.name, 'name': name, 'phone': phone, 'avatar': avatarUrl, 'locale': locale.languageCode}));
    } catch (_) {}
  }

  Future<bool> _readProfileCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_profileKey);
      if (raw == null) return false;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['uid'] != (_b.uid ?? _b.savedUid)) return false;
      role = UserRole.values.firstWhere((r) => r.name == m['role'], orElse: () => UserRole.student);
      name = '${m['name'] ?? ''}';
      phone = '${m['phone'] ?? ''}';
      avatarUrl = '${m['avatar'] ?? ''}';
      if (m['locale'] == 'en' || m['locale'] == 'ar') locale = Locale(m['locale'] as String);
      return name.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Keeps trying to wake the saved sign-in up (e.g. the phone was offline when the app opened).
  void _scheduleRestore() {
    if (_restoreTimer?.isActive ?? false) return;
    _restoreTimer = Timer.periodic(const Duration(seconds: 10), (t) async {
      if (!loggedIn) {
        t.cancel();
        return;
      }
      if (!await _b.restore()) {
        if (!_b.hasSavedSession) {
          t.cancel();
          await logout(); // the account was signed out elsewhere / revoked
        }
        return;
      }
      t.cancel();
      try {
        if (await _loadProfile()) await _saveProfileCache();
      } catch (_) {}
      _startRealtime();
      await refresh();
    });
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
    avatarUrl = (p['avatar_url'] as String?) ?? '';
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
    try {
      workHours = [
        for (final x in await _b.myWorkHours())
          WorkPeriod((x['weekday'] as num).toInt(), WorkPeriod.parse('${x['start_time']}'), WorkPeriod.parse('${x['end_time']}')),
      ];
    } catch (_) {}
    final subjects = await _b.mySubjects();
    _me = Backend.tutorFromRow({...tp, 'id': _b.uid, 'full_name': name, 'subject_ids': subjects, 'avatar_url': avatarUrl});
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
    if (role == UserRole.tutor) return;
    try {
      payTo = await _b.payToAccounts();
      final rows = await _b.myTopUps();
      topUps
        ..clear()
        ..addAll(rows.map(Backend.paymentFromRow));
    } catch (_) {/* payments by transfer not set up on this server yet */}
  }

  // ---------- "please update" switch ----------
  /// True when the admin requires a newer app build than this one (min_app_build setting).
  bool updateRequired = false;

  /// Checks min_app_build (on start and whenever the app comes back to the front).
  /// Builds without a build number (older versions, local builds) are never blocked.
  Future<void> checkAppVersion() async {
    if (!live || DarsConfig.build <= 0) return;
    try {
      final v = await _b.setting('min_app_build');
      final min = v is num ? v.toInt() : int.tryParse('${v ?? 0}') ?? 0;
      final need = DarsConfig.build < min;
      if (need != updateRequired) {
        updateRequired = need;
        notifyListeners();
      }
    } catch (_) {/* offline: check again next time */}
  }

  // ---------- paying by transfer (wallet top-up, or a booking) ----------
  /// Payment method value for a pay-to key ('bank' → 'bank_transfer').
  static String methodValue(String key) => key == 'bank' ? 'bank_transfer' : key;

  /// Starts a wallet top-up; returns where to send the money (null if refused — the reason is shown).
  Future<TransferInfo?> requestTopUp(double amount, String methodKey) async {
    if (!live) {
      say(_t('الشحن متاح في النسخة الحقيقية فقط.', 'Top-up works in the live app only.'));
      return null;
    }
    try {
      final r = await _b.rpc('request_top_up', {'p_amount': amount, 'p_method': methodValue(methodKey)}) as Map;
      _loadWallet().then((_) => notifyListeners()).catchError((_) {});
      return Backend.transferFromJson(r);
    } catch (e) {
      _error(e);
      return null;
    }
  }

  /// Transfer details for a payment that is waiting (a booking, or a top-up started earlier).
  Future<TransferInfo?> transferFor(String paymentId, String methodKey) async {
    try {
      final r = await _b.rpc('transfer_instructions', {'p_payment': paymentId, 'p_method': methodValue(methodKey)}) as Map;
      return Backend.transferFromJson(r);
    } catch (e) {
      _error(e);
      return null;
    }
  }

  /// Uploads the transfer screenshot and sends it for checking. True when it was received.
  Future<bool> submitReceipt(TransferInfo info, Uint8List bytes, String fileName, String? mime) async {
    if (bytes.length > 5 * 1024 * 1024) {
      say(_t('الصورة كبيرة جداً (الحد 5 ميغابايت).', 'The picture is too big (5 MB max).'), bad: true);
      return false;
    }
    final e0 = _ext(fileName, 'jpg');
    final ext = const {'jpg', 'jpeg', 'png', 'webp', 'pdf'}.contains(e0) ? e0 : 'jpg';
    final type = mime ?? (ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg')));
    try {
      final stored = await _b.uploadReceipt(info.paymentId, bytes, ext, type);
      await _b.rpc('submit_bank_receipt', {'p_payment': info.paymentId, 'p_receipt_url': stored, 'p_method': info.method});
      await refresh();
      return true;
    } catch (e) {
      _error(e);
      return false;
    }
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

  String _photoFor(String id, Tutor? tutor) {
    final t = tutor?.photoUrl ?? '';
    return t.isNotEmpty ? t : (_b.photos[id] ?? '');
  }

  /// Profile photo of someone I have a chat or lesson with ('' = show initials).
  String photoOf(String userId) => userId.isEmpty ? '' : (_b.photos[userId] ?? '');

  Future<void> _loadConversations() async {
    final uid = _b.uid!;
    // Hide any old chat someone opened with themselves.
    final rows = (await _b.conversations()).where((r) => r['student_id'] != r['tutor_id']).toList();
    final others = {for (final r in rows) '${r['id']}': '${r['student_id'] == uid ? r['tutor_id'] : r['student_id']}'};
    final names = await _b.names(others.values);
    final msgs = await _b.messagesFor(rows.map((r) => '${r['id']}').toList());
    final byConv = <String, List<Map<String, dynamic>>>{};
    for (final m in msgs) {
      byConv.putIfAbsent('${m['conversation_id']}', () => []).add(m);
    }
    final next = <Conversation>[];
    final pendingAnnounce = <(String, Message)>[];
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
      if (_seenReady) {
        final known = c?.messages.map((x) => x.remoteId).toSet() ?? const <int>{};
        for (final m in messages) {
          if (!m.mine && m.remoteId != 0 && !known.contains(m.remoteId)) pendingAnnounce.add((id, m));
        }
      }
      if (c != null) {
        // Messages still on their way to the server stay at the end, in the order they were sent.
        final unsent = <Message>[];
        final used = <int>{};
        for (final x in c.messages) {
          if (!x.mine || x.remoteId != 0 || !(x.sending || x.failed)) continue;
          final j = messages.indexWhere((s) =>
              s.mine && !used.contains(s.remoteId) && _sameMessage(x, s) && s.time.isAfter(x.time.subtract(const Duration(minutes: 2))));
          if (j >= 0) {
            used.add(messages[j].remoteId);
          } else {
            unsent.add(x);
          }
        }
        // Older messages already loaded by scrolling up stay in front of the newest page.
        final newIds = {for (final m in messages) m.remoteId};
        final first = messages.isEmpty ? null : messages.first;
        final older = first == null
            ? const <Message>[]
            : c.messages
                .where((x) =>
                    x.remoteId != 0 &&
                    !newIds.contains(x.remoteId) &&
                    (x.time.isBefore(first.time) || (x.time == first.time && x.remoteId < first.remoteId)))
                .toList();
        if (older.isEmpty) c.hasOlder = mrows.length >= Backend.pageSize;
        c.messages
          ..clear()
          ..addAll(older)
          ..addAll(messages)
          ..addAll(unsent);
        c.unread = identical(c, activeConversation) ? 0 : unread;
        c.online = tutor?.available ?? false;
        c.photo = _photoFor(other, tutor);
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
          photo: _photoFor(other, tutor),
        )..hasOlder = mrows.length >= Backend.pageSize;
      }
      next.add(c);
    }
    // Keep chats that are still being created on the server.
    final pending = conversations.where((c) => c.id.isEmpty).toList();
    conversations
      ..clear()
      ..addAll(pending)
      ..addAll(next);
    // Messages that arrived while realtime was asleep (app in background, poll fallback).
    for (final (id, m) in pendingAnnounce) {
      for (final c in next) {
        if (c.id == id) _announce(c, m);
      }
    }
    _seenReady = true;
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
          if (!_foreground || kIsWeb) Ringer.notify(title: _t(n.title.ar, n.title.en), body: _t(n.body.ar, n.body.en));
          final title = '${r['title']}';
          if (title.isNotEmpty) say(_t(n.title.ar, n.title.en));
          if (RegExp(r'book|cancel|Payment|Payout|Refund|approved|changes|review|Missed|rescheduled', caseSensitive: false).hasMatch(title)) {
            _loadProfile().then((_) => refresh());
          } else {
            notifyListeners();
          }
        },
        onLiveRequest: role == UserRole.tutor ? (_) => _loadLiveRequests().then((_) => notifyListeners()).catchError((_) {}) : null,
        onMessageUpdate: _onRemoteMessageUpdate,
        // (Re)connected: send anything that could not go out while offline.
        onConnected: retryFailedMessages,
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

  /// Same message, local copy vs. the server's row (files by their stored path, others by text + kind).
  static bool _sameMessage(Message local, Message server) {
    if (server.url.isNotEmpty || local.url.isNotEmpty) return local.url == server.url;
    final kindOk = local.type == server.type ||
        (local.type == MsgType.video && server.type == MsgType.file) ||
        (local.type == MsgType.file && server.type == MsgType.video);
    final text = local.type == MsgType.voice ? '🎤' : local.text;
    return kindOk && text == server.text;
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
      // My own message coming back from the server: swap it in for the local copy, keeping its place.
      // (Oldest unconfirmed match first: messages are posted in order, so they come back in order.)
      final i = c.messages.indexWhere((x) => x.mine && x.remoteId == 0 && _sameMessage(x, m));
      if (i >= 0) {
        c.messages[i] = m.withPreviewOf(c.messages[i]);
        notifyListeners();
        return;
      }
    }
    c.messages.add(m);
    _announce(c, m);
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

  /// A message changed on the server — the other person read it (double tick).
  void _onRemoteMessageUpdate(Map<String, dynamic> r) {
    final id = (r['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;
    for (final c in conversations) {
      if (c.id != '${r['conversation_id']}') continue;
      final i = c.messages.indexWhere((x) => x.remoteId == id);
      if (i < 0) return;
      c.messages[i] = Backend.messageFromRow(r, _b.uid).withPreviewOf(c.messages[i]);
      notifyListeners();
      return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreTimer?.cancel();
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
      await _saveProfileCache();
      Ringer.askPermission();
      loggedIn = true;
      Future.delayed(const Duration(seconds: 1), _offerPendingJoin);
      await refresh();
      _startRealtime();
      notifyListeners();
    }
    return ready;
  }

  void login({required UserRole asRole, required String phoneNumber}) {
    if (live) {
      _saveProfileCache();
      Ringer.askPermission();
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
    tutorTab = 0;
    studentTab = 0;
    notifyListeners();
    if (!live) return;
    _restoreTimer?.cancel();
    _stopRealtime();
    try {
      (await SharedPreferences.getInstance()).remove(_profileKey);
    } catch (_) {}
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
  // media: chat photos / videos / voice notes, profile photo, intro video
  // =====================================================================
  final Map<String, ({String url, DateTime until})> _urlCache = {};

  /// A link that can be opened/played for a stored file ("<bucket>/<path>").
  Future<String> mediaUrl(String stored) async {
    if (stored.isEmpty) return '';
    final hit = _urlCache[stored];
    if (hit != null && hit.until.isAfter(DateTime.now())) return hit.url;
    try {
      final u = await _b.fileUrl(stored);
      _urlCache[stored] = (url: u, until: DateTime.now().add(const Duration(minutes: 50)));
      return u;
    } catch (_) {
      return '';
    }
  }

  static const maxUploadBytes = 45 * 1024 * 1024;

  static String _ext(String name, String fallback) {
    final i = name.lastIndexOf('.');
    final e = i < 0 ? '' : name.substring(i + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(e) ? e : fallback;
  }

  /// Sends a photo / video / voice note in a chat: shows it right away, uploads, then posts the message.
  Future<bool> sendMedia(Conversation c, {required MsgType type, required Uint8List bytes, required String name, required String mime, int seconds = 0}) async {
    if (bytes.length > maxUploadBytes) {
      say(_t('الملف كبير جداً (الحد 45 ميغابايت).', 'The file is too big (45 MB max).'), bad: true);
      return false;
    }
    final draft = Message(mine: true, text: name, time: DateTime.now(), type: type, seconds: seconds, bytes: type == MsgType.image ? bytes : null, sending: live);
    c.messages.add(draft);
    if (conversations.remove(c)) conversations.insert(0, c);
    notifyListeners();
    if (!live) {
      final i = c.messages.indexOf(draft);
      if (i >= 0) c.messages[i] = Message(mine: true, text: name, time: draft.time, type: type, seconds: seconds, bytes: draft.bytes);
      notifyListeners();
      return true;
    }
    // Uploads run in the chat's send queue, so a text typed while a video uploads still lands after it.
    return _inOrder(c, () async {
      try {
        final id = await _ensure(c);
        final bucket = type == MsgType.voice ? 'voice-notes' : 'chat-files';
        final fallback = switch (type) { MsgType.voice => 'm4a', MsgType.image => 'jpg', MsgType.video => 'mp4', _ => 'bin' };
        final stored = await _b.upload(bucket, '$id/${DateTime.now().millisecondsSinceEpoch}.${_ext(name, fallback)}', bytes, mime);
        final sent = draft.copyWith(text: type == MsgType.voice ? '🎤' : name, url: stored);
        final i = c.messages.indexOf(draft);
        if (i >= 0) c.messages[i] = sent;
        notifyListeners();
        await _pushNow(c, sent);
        return true;
      } catch (e) {
        c.messages.remove(draft);
        notifyListeners();
        _error(e);
        return false;
      }
    });
  }

  /// Loads the next page of older messages of a chat (when the user scrolls to the top).
  Future<void> loadOlder(Conversation c) async {
    if (!live || c.id.isEmpty || !c.hasOlder || c.loadingOlder) return;
    Message? oldest;
    for (final m in c.messages) {
      if (m.remoteId != 0) {
        oldest = m;
        break;
      }
    }
    if (oldest == null) {
      c.hasOlder = false;
      return;
    }
    c.loadingOlder = true;
    notifyListeners();
    try {
      final rows = await _b.olderMessages(c.id, oldest.time, oldest.remoteId);
      final have = {for (final m in c.messages) m.remoteId};
      final uid = _b.uid;
      final more = [
        for (final r in rows)
          if (!have.contains(Backend.messageFromRow(r, uid).remoteId)) Backend.messageFromRow(r, uid),
      ];
      c.messages.insertAll(0, more);
      c.hasOlder = rows.length >= Backend.pageSize;
    } catch (e) {
      _error(e);
    } finally {
      c.loadingOlder = false;
      notifyListeners();
    }
  }

  /// Sends a "report this chat" to the Dars team. Returns true when it reached the server.
  Future<bool> reportConversation(Conversation c, String reason) async {
    final r = reason.trim();
    if (!live) return true;
    if (c.id.isEmpty || r.isEmpty) return false;
    try {
      await _b.reportConversation(c.id, r.length > 500 ? r.substring(0, 500) : r);
      return true;
    } catch (e) {
      _error(e);
      return false;
    }
  }

  final Map<String, ({double hourly, Map<int, int> discounts})> _quotes = {};

  /// The price the server will charge for this tutor at my level (null in demo mode or offline).
  Future<({double hourly, Map<int, int> discounts})?> priceQuote(Tutor t) async {
    if (!live || t.id.length < 20) return null;
    final key = '${t.id}|$levelId';
    final hit = _quotes[key];
    if (hit != null) return hit;
    try {
      final r = await _b.priceQuote(t.id, levelId);
      if (r == null) return null;
      final d = Map<String, dynamic>.from((r['discounts'] as Map?) ?? const {});
      final q = (
        hourly: ((r['hourly'] as num?) ?? t.pricePerHour).toDouble(),
        discounts: {for (final e in d.entries) int.parse(e.key): ((e.value as num?) ?? 0).toInt()},
      );
      _quotes[key] = q;
      return q;
    } catch (_) {
      return null;
    }
  }

  // ---- sending in order ----
  // Each chat sends one message at a time, in the order they were written, so the server keeps
  // the same order the sender sees (voice notes / photos / videos upload first, then post).
  final Map<int, Future<void>> _sendQueue = {};

  Future<T> _inOrder<T>(Conversation c, Future<T> Function() job) {
    final key = identityHashCode(c);
    final prev = _sendQueue[key] ?? Future<void>.value();
    final next = prev.then((_) => job());
    _sendQueue[key] = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  /// Changes my name (and, for tutors, any part of the public profile).
  Future<bool> saveMyProfile({
    String? fullName,
    String? headline,
    String? about,
    int? years,
    bool? online,
    bool? inPerson,
    int? hourlyPrice,
    Set<String>? subjects,
  }) async {
    final n = fullName?.trim() ?? name;
    if (n.isEmpty) {
      say(_t('اكتب اسمك', 'Please enter your name'), bad: true);
      return false;
    }
    name = n;
    notifyListeners();
    if (!live) return true;
    try {
      await _b.updateProfile({'full_name': n});
      if (role == UserRole.tutor) {
        final h = headline?.trim();
        final a = about?.trim();
        await _b.updateTutor({
          if (h != null) 'headline': h.length > 80 ? h.substring(0, 80) : h,
          if (a != null) 'about': a.length > 1000 ? a.substring(0, 1000) : a,
          if (years != null) 'years_experience': years.clamp(0, 60),
          if (online != null) 'teaches_online': online,
          if (inPerson != null) 'teaches_in_person': inPerson,
        });
        if (hourlyPrice != null && hourlyPrice > 0 && hourlyPrice != me.pricePerHour) await _b.updateTutorPrice(hourlyPrice.toDouble(), me.pricePerHour.toDouble());
        if (subjects != null && subjects.isNotEmpty) await _b.setMySubjects(subjects);
      }
      await _loadProfile();
      await _saveProfileCache();
      try {
        await _loadTutors();
      } catch (_) {}
      notifyListeners();
      say(_t('تم حفظ الملف الشخصي', 'Profile saved'));
      return true;
    } catch (e) {
      _error(e);
      return false;
    }
  }

  /// New profile photo (shown to students on the tutor card and in chats).
  Future<bool> setProfilePhoto(Uint8List bytes, String name, String mime) async {
    if (!live) return false;
    try {
      final stored = await _b.upload('avatars', 'avatar-${DateTime.now().millisecondsSinceEpoch}.${_ext(name, 'jpg')}', bytes, mime);
      avatarUrl = _b.publicUrl(stored);
      await _b.updateProfile({'avatar_url': avatarUrl});
      await _loadProfile();
      await _saveProfileCache();
      try {
        await _loadTutors();
      } catch (_) {}
      notifyListeners();
      say(_t('تم تحديث الصورة', 'Photo updated'));
      return true;
    } catch (e) {
      _error(e);
      return false;
    }
  }

  /// Tutor intro video on the public profile ('' removes it).
  Future<bool> setIntroVideo(Uint8List? bytes, {String name = 'intro.mp4', String mime = 'video/mp4'}) async {
    if (!live) return false;
    if (bytes != null && bytes.length > maxUploadBytes) {
      say(_t('الفيديو كبير جداً (الحد 45 ميغابايت). اختر فيديو أقصر.', 'The video is too big (45 MB max). Choose a shorter one.'), bad: true);
      return false;
    }
    try {
      var url = '';
      if (bytes != null) {
        final stored = await _b.upload('tutor-media', 'intro-${DateTime.now().millisecondsSinceEpoch}.${_ext(name, 'mp4')}', bytes, mime);
        url = _b.publicUrl(stored);
      }
      await _b.updateTutor({'video_url': url.isEmpty ? null : url});
      await _loadProfile();
      try {
        await _loadTutors();
      } catch (_) {}
      notifyListeners();
      say(url.isEmpty ? _t('تم حذف الفيديو', 'Video removed') : _t('تم رفع فيديو التعريف', 'Intro video uploaded'));
      return true;
    } catch (e) {
      _error(e);
      return false;
    }
  }

  bool isMe(Tutor t) => role == UserRole.tutor && (t.id == me.id || (live && t.id == _b.uid));

  // =====================================================================
  // tutor: my students
  // =====================================================================
  List<StudentSummary> get myStudents {
    final by = <String, List<Lesson>>{};
    for (final l in tutorLessons) {
      final key = l.studentId.isNotEmpty ? l.studentId : _nameOf(l.studentName);
      by.putIfAbsent(key, () => []).add(l);
    }
    final now = DateTime.now();
    final list = <StudentSummary>[];
    by.forEach((id, ls) {
      ls.sort((a, b) => a.start.compareTo(b.start));
      final upcoming = ls.where((l) => l.status == LessonStatus.upcoming && l.start.isAfter(now.subtract(Duration(minutes: l.minutes)))).toList();
      final done = ls.where((l) => l.status == LessonStatus.delivered).toList();
      final pending = ls.where((l) => l.status == LessonStatus.pending).length;
      final cancelled = ls.where((l) => l.status == LessonStatus.cancelled).length;
      list.add(StudentSummary(
        id: id,
        name: ls.first.studentName,
        lessons: ls,
        completed: done.length,
        upcoming: upcoming.length,
        pendingPayment: pending,
        cancelled: cancelled,
        next: upcoming.isEmpty ? null : upcoming.first,
        last: done.isEmpty ? null : done.last,
        earned: done.fold(0.0, (s, l) => s + l.price - l.commission),
      ));
    });
    list.sort((a, b) {
      if ((a.next == null) != (b.next == null)) return a.next == null ? 1 : -1;
      if (a.next != null) return a.next!.start.compareTo(b.next!.start);
      return (b.last?.start ?? DateTime(2000)).compareTo(a.last?.start ?? DateTime(2000));
    });
    return list;
  }

  /// Opens (or starts) the chat with one of my students.
  Future<Conversation?> chatWithStudent(String studentId, L name) async {
    for (final c in conversations) {
      if (c.counterpartId == studentId) return c;
    }
    if (!live) return null;
    try {
      final id = '${await _b.rpc('tutor_start_conversation', {'p_student': studentId})}';
      await _loadConversations();
      for (final c in conversations) {
        if (c.id == id || c.counterpartId == studentId) return c;
      }
    } catch (e) {
      _error(e);
    }
    return null;
  }

  // =====================================================================
  // notifications → open what they are about
  // =====================================================================
  Future<void> openNotification(AppNotification n) async {
    if (!n.read) {
      n.read = true;
      notifyListeners();
      if (live && n.remoteId != 0) _b.markNotificationRead(n.remoteId).catchError((_) {});
    }
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    final d = n.data;
    final tutor = role == UserRole.tutor;
    final convId = '${d['conversation_id'] ?? ''}';
    if (convId.isNotEmpty) {
      Conversation? c;
      for (final x in conversations) {
        if (x.id == convId) c = x;
      }
      if (c == null) {
        try {
          await _loadConversations();
        } catch (_) {}
        for (final x in conversations) {
          if (x.id == convId) c = x;
        }
      }
      if (c != null) {
        tutor ? goTutorTab(3) : goTab(4);
        openChatRoute?.call(c);
        return;
      }
    }
    if (d.containsKey('live_request_id')) {
      tutor ? goTutorTab(1) : goTab(2);
    } else if (d.containsKey('lesson_id') || d.containsKey('package_id') || d.containsKey('payment_id')) {
      tutor ? goTutorTab(2) : goTab(3);
    } else if (d.containsKey('payout_id') || d.containsKey('review_id')) {
      tutor ? goTutorTab(0) : goTab(0);
    } else if (d['call'] == true) {
      tutor ? goTutorTab(3) : goTab(4);
    }
  }

  /// Set by the shells: pushes the chat screen for a conversation.
  void Function(Conversation c)? openChatRoute;

  void _addLocalNotification(L title, L body, IconData icon, Color color, Map<String, dynamic> data) {
    notifications.insert(0, AppNotification(title, body, DateTime.now(), icon, color, data: data));
    notifyListeners();
  }

  // =====================================================================
  // meeting links opened from outside the app
  // =====================================================================
  Uri? _pendingJoin;
  String _joinAskedFor = '';
  DateTime _joinAskedAt = DateTime(2000);

  Future<void> checkLaunchLink() async {
    final u = await MediaBridge.takeLaunchLink();
    if (u != null) _pendingJoin = u;
    _offerPendingJoin();
  }

  void _offerPendingJoin() {
    final u = _pendingJoin;
    if (u == null || !loggedIn) return;
    final room = u.queryParameters['room'] ?? '';
    if (!RegExp(r'^[a-zA-Z0-9-]{8,64}$').hasMatch(room)) {
      _pendingJoin = null;
      return;
    }
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    _pendingJoin = null;
    final key = '$room|${u.queryParameters['video']}';
    final now = DateTime.now();
    if (_joinAskedFor == key && now.difference(_joinAskedAt).inSeconds < 60) return; // just asked about this link
    _joinAskedFor = key;
    _joinAskedAt = now;
    final video = u.queryParameters['video'] != '0';
    showDialog<void>(
      context: ctx,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.video_call_rounded, color: Color(0xFF0E8F7E), size: 44),
        title: Text(_t('الانضمام للجلسة؟', 'Join the session?'), textAlign: TextAlign.center),
        content: Text(
          _t('فتحت رابط جلسة على درس. هل تريد الانضمام الآن؟', 'You opened a Dars session link. Do you want to join now?'),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(_t('ليس الآن', 'Not now'))),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(d);
              joinCall(room: room, video: video);
            },
            icon: const Icon(Icons.login_rounded),
            label: Text(_t('انضم', 'Join')),
          ),
        ],
      ),
    );
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
    String method = 'bank', // pay-to key of the transfer method (used when credit does not cover it)
    String notes = '',
  }) async {
    if (live) {
      final pm = methodValue(method);
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
          if (notes.trim().isNotEmpty) 'p_notes': notes.trim(),
        }) as Map;
      }
      lastAmountDue = ((res['amount_due'] as num?) ?? 0).toDouble();
      lastPaymentId = res['payment_id'] == null ? null : '${res['payment_id']}';
      await refresh();
      final id = res['lesson_id'];
      for (final l in lessons) {
        if (l.id == id) return l;
      }
      return null;
    }

    lastAmountDue = 0;
    lastPaymentId = null;
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

  /// "Complete payment" on a booking that waits for payment: opens the transfer + receipt screens.
  Future<void> payPending(Lesson l) async {
    if (!live) {
      l.status = LessonStatus.upcoming;
      notifyListeners();
      return;
    }
    try {
      final r = await _b.latestPaymentFor(l.id);
      final p = r == null ? null : Backend.paymentFromRow(r);
      if (p == null || p.status == 'paid') {
        await refresh();
        return;
      }
      if (p.status == 'under_review') {
        say(_t('وصلنا إيصالك وهو قيد المراجعة. سيصلك إشعار عند التأكيد.', 'We have your receipt and are checking it. You will be notified once it is confirmed.'));
        return;
      }
      if (p.status != 'pending') {
        say(_t('انتهت مهلة الدفع لهذا الحجز. احجز موعداً جديداً.', 'The time to pay for this booking has passed. Please book again.'), bad: true);
        await refresh();
        return;
      }
      navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => PayByTransferScreen(paymentId: p.id, amount: p.amount)));
    } catch (e) {
      _error(e);
    }
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

  /// Sends a message. (Phone numbers / contact details are not blocked here: the server flags them
  /// silently for the admin's security monitor.)
  bool sendMessage(Conversation c, Message m) {
    final local = live && m.mine ? m.copyWith(sending: true) : m;
    c.messages.add(local);
    if (conversations.remove(c)) conversations.insert(0, c);
    notifyListeners();
    if (live && m.mine) _push(c, local);
    return true;
  }

  /// Posts a message to the server after everything sent before it in this chat.
  Future<void> _push(Conversation c, Message m) => _inOrder(c, () => _pushNow(c, m));

  Future<void> _pushNow(Conversation c, Message m) async {
    try {
      final id = await _ensure(c);
      final kind = switch (m.type) {
        MsgType.voice => 'voice',
        MsgType.file || MsgType.video => 'file',
        MsgType.image => 'image',
        MsgType.call => 'call',
        _ => 'text',
      };
      final text = m.type == MsgType.voice ? '🎤' : m.text;
      final row = await _b.sendMessage(id, text, kind: kind, seconds: m.seconds > 0 ? m.seconds : null, fileUrl: m.url);
      // Swap in the server's copy (id for read ticks, and whether the contact filter hid it).
      final server = Backend.messageFromRow(row, _b.uid);
      final i = c.messages.indexOf(m);
      if (c.messages.any((x) => x.remoteId == server.remoteId)) {
        if (i >= 0) c.messages.removeAt(i); // realtime already delivered it
      } else if (i >= 0) {
        c.messages[i] = server.withPreviewOf(m);
      }
      notifyListeners();
    } catch (e) {
      // Kept in the chat with a red "!" — tap to retry (also retried when the connection is back).
      final i = c.messages.indexOf(m);
      final failed = m.copyWith(sending: false, failed: true);
      if (i >= 0) c.messages[i] = failed;
      notifyListeners();
      if (_permanentSendError(e)) {
        _refused.add(failed); // retried only when the user taps it
        _error(e);
      }
    }
  }

  /// Failed messages the server refused (not a connection problem): no automatic retry.
  final Set<Message> _refused = Set.identity();

  /// Errors that a retry cannot fix (the server refused the message itself).
  static bool _permanentSendError(Object e) => e is PostgrestException && !(e.code ?? '').startsWith('PGRST3');

  /// Tap on a failed message: send it again, in order with the rest of the chat.
  void retryMessage(Conversation c, Message m) {
    final i = c.messages.indexOf(m);
    if (i < 0 || !m.failed) return;
    _refused.remove(m);
    final again = m.copyWith(sending: true, failed: false);
    c.messages[i] = again;
    notifyListeners();
    _push(c, again);
  }

  bool _retrying = false;

  /// Re-sends every failed message (app back in front, or realtime reconnected).
  void retryFailedMessages() {
    if (!live || _retrying) return;
    _retrying = true;
    try {
      for (final c in conversations) {
        for (final m in c.messages.where((x) => x.mine && x.failed && x.remoteId == 0 && !_refused.contains(x)).toList()) {
          retryMessage(c, m);
        }
      }
    } finally {
      _retrying = false;
    }
  }

  // =====================================================================
  // calls (voice & video)
  // =====================================================================
  String _nameOf(L n) => locale.languageCode == 'ar' ? n.ar : n.en;

  bool _inCall = false;

  /// Opens the call screen inside the app. Both people open the same room to talk.
  Future<void> joinCall({required String room, required bool video, String peer = ''}) async {
    final nav = navigatorKey.currentState;
    if (nav == null || _inCall) return;
    _inCall = true;
    try {
      await nav.push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LiveCallScreen(room: room, video: video, peerName: peer, myName: name),
      ));
    } finally {
      _inCall = false;
      Ringer.callEnded(); // the app stops showing over the lock screen
    }
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

  // ---- ringing & notifications ----
  bool _seenReady = false;
  final Set<int> _announced = {};
  Route<void>? _ringRoute;
  ({String room, bool video, String who})? _ringing;

  /// Something new arrived from the other person: ring for calls, notify for messages.
  void _announce(Conversation c, Message m) {
    if (m.mine) return;
    if (m.remoteId != 0 && !_announced.add(m.remoteId)) return;
    final who = _nameOf(c.name);
    if (m.type == MsgType.call) {
      final inv = Calls.parse(m.text);
      if (inv == null) return;
      if (inv.meet) {
        Ringer.notify(title: who, body: _t('أرسل رابط اجتماع', 'sent a meeting link'));
        return;
      }
      if (DateTime.now().difference(m.time).inSeconds.abs() > 60) return; // an old call — don't ring
      _incomingCall(who, inv.room, inv.video, conversationId: c.id);
      return;
    }
    if (!_foreground || kIsWeb) {
      final body = switch (m.type) {
        MsgType.voice => _t('🎤 رسالة صوتية', '🎤 Voice message'),
        MsgType.file => _t('📎 ملف', '📎 File'),
        MsgType.image => _t('📷 صورة', '📷 Photo'),
        MsgType.video => _t('🎬 فيديو', '🎬 Video'),
        _ => m.text,
      };
      Ringer.notify(title: who, body: body);
    }
  }

  String _ringingConv = '';

  void _incomingCall(String who, String room, bool video, {String conversationId = ''}) {
    if (_ringing != null || _inCall) return; // already ringing / already in a call
    _ringing = (room: room, video: video, who: who);
    _ringingConv = conversationId;
    Ringer.ring(
      title: who,
      body: video ? _t('مكالمة فيديو واردة', 'Incoming video call') : _t('مكالمة صوتية واردة', 'Incoming voice call'),
      joinLabel: _t('انضم', 'Join'),
    );
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    _ringRoute = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => IncomingCallScreen(
        name: who,
        video: video,
        onAccept: () => _answer(true),
        onDecline: () => _answer(false),
        onTimeout: () {
          _answer(false);
          say(_t('مكالمة فائتة من $who', 'Missed call from $who'));
          _addLocalNotification(L('مكالمة فائتة', 'Missed call'), L('من $who', 'From $who'), Icons.phone_missed_rounded, const Color(0xFFE5484D),
              {if (_ringingConv.isNotEmpty) 'conversation_id': _ringingConv, 'call': true});
        },
      ),
    );
    nav.push(_ringRoute!);
  }

  /// Accept or decline the call that is ringing now.
  void _answer(bool accept) {
    final call = _ringing;
    _ringing = null;
    Ringer.stop();
    final r = _ringRoute;
    _ringRoute = null;
    if (r != null && r.isActive) navigatorKey.currentState?.removeRoute(r);
    if (accept && call != null) {
      joinCall(room: call.room, video: call.video, peer: call.who);
    } else {
      Ringer.callEnded(); // declined / missed: lock-screen access ends here
    }
  }

  /// Opened from the ringing notification ("Join" button / tap).
  Future<void> _handleLaunchAction() async {
    final a = await Ringer.takeLaunchAction();
    if (a == 'join' && _ringing != null) _answer(true);
  }

  /// Sends a meeting link into the chat (anyone in the chat can join it any time) and returns the link.
  Future<String> createMeeting(Conversation c) async {
    final room = Calls.newRoom();
    final m = Message(mine: true, text: Calls.meeting(room), time: DateTime.now(), type: MsgType.call);
    c.messages.add(m);
    if (conversations.remove(c)) conversations.insert(0, c);
    notifyListeners();
    if (live) await _push(c, m);
    return Calls.shareLink(room);
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

  /// Saves the tutor's weekly hours (students can only book inside them).
  Future<bool> saveWorkHours(List<WorkPeriod> periods) async {
    final sorted = [...periods]..sort((a, b) => a.weekday != b.weekday ? a.weekday - b.weekday : a.start - b.start);
    if (!live) {
      workHours = sorted;
      notifyListeners();
      say(_t('تم حفظ أوقات العمل', 'Working hours saved'));
      return true;
    }
    try {
      await _b.setWorkingHours(DateTime.now().timeZoneOffset.inMinutes, [
        for (final p in sorted) {'weekday': p.weekday, 'start': WorkPeriod.hm(p.start), 'end': WorkPeriod.hm(p.end)},
      ]);
      workHours = sorted;
      notifyListeners();
      say(_t('تم حفظ أوقات العمل', 'Working hours saved'));
      return true;
    } catch (e) {
      _error(e);
      return false;
    }
  }

  /// A tutor's working hours and already-booked times, for choosing a lesson time.
  Future<TutorSchedule> scheduleFor(Tutor t) async {
    if (!live || t.id.length < 20) {
      return TutorSchedule(tzOffset: DateTime.now().timeZoneOffset.inMinutes, periods: const [], busy: const []);
    }
    try {
      final r = await _b.tutorSchedule(t.id);
      return TutorSchedule(
        tzOffset: (r['tz_offset'] as num?)?.toInt() ?? 180,
        periods: [
          for (final x in (r['slots'] as List? ?? const []))
            WorkPeriod((x['weekday'] as num).toInt(), WorkPeriod.parse('${x['start']}'), WorkPeriod.parse('${x['end']}')),
        ],
        busy: [
          for (final x in (r['busy'] as List? ?? const [])) (start: Backend.time(x['start']), end: Backend.time(x['end'])),
        ],
      );
    } catch (_) {
      return TutorSchedule(tzOffset: DateTime.now().timeZoneOffset.inMinutes, periods: const [], busy: const []);
    }
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

  static const _payoutMethods = {
    'sham_cash': 'sham_cash',
    'syriatel_cash': 'syriatel_cash',
    'mtn_cash': 'mtn_cash',
    'bank': 'bank_transfer',
    'paypal': 'paypal',
    'wu': 'western_union',
  };

  /// Asks Dars to send my earnings to the given account. True only when the server accepted it
  /// (the server's reason is shown otherwise). Nothing changes on screen before the server answers.
  Future<bool> requestPayout({required String method, required double amount, required String holderName, required String account}) async {
    if (!live) {
      tutorConfirmed = 0;
      notifyListeners();
      return true;
    }
    try {
      await _b.rpc('request_payout', {
        'p_amount': double.parse(amount.toStringAsFixed(2)),
        'p_method': _payoutMethods[method] ?? 'bank_transfer',
        'p_details': {'holder_name': holderName.trim(), 'account': account.trim()},
      });
      await refresh();
      return true;
    } catch (e) {
      _error(e);
      return false;
    }
  }
}
