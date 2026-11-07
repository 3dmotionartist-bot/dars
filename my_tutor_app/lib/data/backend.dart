import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import '../config.dart';
import '../l10n.dart';
import 'mock_data.dart';
import 'models.dart';

/// Thin wrapper around the Supabase backend (database rules live in my_tutor_backend/).
/// Every money / booking change goes through a server function, so the app can never
/// give itself credit or skip a rule.
class Backend {
  Backend._();
  static final Backend I = Backend._();

  static const _sessionKey = 'dars.session';
  late final SupabaseClient db;
  bool _ready = false;
  StreamSubscription<AuthState>? _authSub;

  bool get ready => _ready;
  String? get uid => _ready ? db.auth.currentUser?.id : null;

  Future<void> init() async {
    if (_ready || !DarsConfig.live) return;
    db = SupabaseClient(
      DarsConfig.supabaseUrl,
      DarsConfig.supabaseAnonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    _ready = true;
    // Keep the user signed in between app launches.
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_sessionKey);
    if (saved != null) {
      try {
        await db.auth.recoverSession(saved);
      } catch (_) {
        await prefs.remove(_sessionKey);
      }
    }
    _authSub = db.auth.onAuthStateChange.listen((s) async {
      final p = await SharedPreferences.getInstance();
      if (s.session != null) {
        await p.setString(_sessionKey, jsonEncode(s.session!.toJson()));
      } else if (s.event == AuthChangeEvent.signedOut) {
        await p.remove(_sessionKey);
      }
    });
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
  }

  // ------------------------------------------------------------------ auth
  static String e164(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> sendPhoneCode(String phone, UserRole role) => db.auth.signInWithOtp(
        phone: e164(phone),
        channel: DarsConfig.otpChannel == 'whatsapp' ? OtpChannel.whatsapp : OtpChannel.sms,
        data: {'role': role.name},
      );

  Future<void> verifyPhoneCode(String phone, String code) async {
    await db.auth.verifyOTP(phone: e164(phone), token: code, type: OtpType.sms);
  }

  /// Email + password (handy for testers before WhatsApp/SMS is connected).
  Future<void> emailSignIn(String email, String password, UserRole role, {required bool create}) async {
    if (create) {
      final r = await db.auth.signUp(email: email.trim(), password: password, data: {'role': role.name});
      if (r.session == null) {
        throw AuthException('Check your inbox to confirm your email, then sign in. (Admins can turn off "Confirm email" in Supabase → Authentication.)');
      }
    } else {
      await db.auth.signInWithPassword(email: email.trim(), password: password);
    }
  }

  Future<void> signOut() => db.auth.signOut();

  // ------------------------------------------------------------------ reads
  Future<Map<String, dynamic>?> myProfile() => db.from('profiles').select().eq('id', uid!).maybeSingle();
  Future<Map<String, dynamic>?> myTutorProfile() => db.from('tutor_profiles').select().eq('user_id', uid!).maybeSingle();

  Future<List<String>> mySubjects() async {
    final rows = await db.from('tutor_subjects').select('subject_id').eq('tutor_id', uid!);
    return [for (final r in rows) '${r['subject_id']}'];
  }

  Future<List<Map<String, dynamic>>> publicTutors() => db.from('public_tutors').select().order('rating_avg', ascending: false).limit(500);
  Future<List<Map<String, dynamic>>> visibleReviews() =>
      db.from('reviews').select('lesson_id, tutor_id, student_id, stars, comment, created_at').eq('status', 'visible').order('created_at', ascending: false).limit(500);
  Future<List<Map<String, dynamic>>> myReviews() => db.from('reviews').select('lesson_id').eq('student_id', uid!);

  Future<List<Map<String, dynamic>>> myLessons({required bool asTutor}) =>
      db.from('lessons').select().eq(asTutor ? 'tutor_id' : 'student_id', uid!).order('starts_at').limit(500);
  Future<List<Map<String, dynamic>>> myPackages() => db.from('packages').select().eq('student_id', uid!).order('created_at', ascending: false);
  Future<List<Map<String, dynamic>>> walletTx() => db.from('wallet_transactions').select().eq('user_id', uid!).order('created_at', ascending: false).limit(100);
  Future<double> walletBalance() async {
    final r = await db.from('wallet_balances').select('balance').eq('user_id', uid!).maybeSingle();
    return _num(r?['balance']);
  }

  Future<List<Map<String, dynamic>>> notifications() => db.from('notifications').select().eq('user_id', uid!).order('created_at', ascending: false).limit(60);
  Future<List<Map<String, dynamic>>> conversations() => db.from('conversations').select().order('last_message_at', ascending: false).limit(100);
  Future<List<Map<String, dynamic>>> messagesFor(List<String> conversationIds) => conversationIds.isEmpty
      ? Future.value(<Map<String, dynamic>>[])
      : db.from('messages').select().inFilter('conversation_id', conversationIds).order('created_at').limit(2000);

  /// Names of people I share a lesson or chat with (allowed by the database rules).
  Future<Map<String, String>> names(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final rows = await db.from('profiles').select('id, full_name').inFilter('id', list);
    return {for (final r in rows) r['id'] as String: (r['full_name'] as String?) ?? ''};
  }

  Future<List<Map<String, dynamic>>> openLiveRequests() async {
    final rows = await db.from('live_requests').select().eq('status', 'open').gt('expires_at', DateTime.now().toUtc().toIso8601String()).order('created_at', ascending: false);
    final answered = await db.from('live_responses').select('request_id').eq('tutor_id', uid!);
    final done = {for (final a in answered) a['request_id']};
    return rows.where((r) => r['student_id'] != uid && !done.contains(r['id'])).toList();
  }

  Future<List<String>> liveAcceptedTutors(String requestId) async {
    final rows = await db.from('live_responses').select('tutor_id').eq('request_id', requestId).eq('accepted', true);
    return [for (final r in rows) r['tutor_id'] as String];
  }

  // ------------------------------------------------------------------ writes
  Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]) => db.rpc(fn, params: params);

  Future<void> updateProfile(Map<String, dynamic> values) => db.from('profiles').update(values).eq('id', uid!);
  Future<void> updateTutor(Map<String, dynamic> values) => db.from('tutor_profiles').update(values).eq('user_id', uid!);

  Future<void> saveTutorApplication({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> tutor,
    required Set<String> subjects,
    required Set<String> curricula,
    required Map<String, double> levelPrices,
  }) async {
    final me = uid!;
    if (await myTutorProfile() == null) {
      throw PostgrestException(message: 'This account is registered as a student. Sign out and sign in again choosing "I am a tutor" with a different number or email.');
    }
    await updateProfile(profile);
    await updateTutor(tutor);
    await db.from('tutor_subjects').delete().eq('tutor_id', me);
    if (subjects.isNotEmpty) await db.from('tutor_subjects').insert([for (final s in subjects) {'tutor_id': me, 'subject_id': s}]);
    await db.from('tutor_curricula').delete().eq('tutor_id', me);
    if (curricula.isNotEmpty) await db.from('tutor_curricula').insert([for (final c in curricula) {'tutor_id': me, 'curriculum_id': c}]);
    await db.from('tutor_level_prices').delete().eq('tutor_id', me);
    if (levelPrices.isNotEmpty) {
      await db.from('tutor_level_prices').insert([
        for (final e in levelPrices.entries) {'tutor_id': me, 'level_id': e.key, 'price': double.parse(e.value.toStringAsFixed(2))}
      ]);
    }
  }

  Future<void> sendMessage(String conversationId, String text, {String kind = 'text', int? seconds}) =>
      db.from('messages').insert({'conversation_id': conversationId, 'sender_id': uid, 'kind': kind, 'body': text, if (seconds != null) 'duration_sec': seconds});

  Future<void> markRead(String conversationId) => db
      .from('messages')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('conversation_id', conversationId)
      .neq('sender_id', uid!)
      .isFilter('read_at', null);

  Future<void> markNotificationsRead() =>
      db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', uid!).isFilter('read_at', null);

  Future<void> submitLead(Map<String, dynamic> lead) => db.from('leads').insert(lead);

  /// Pushes new chat messages / notifications / live requests to the app as they happen.
  RealtimeChannel listen({
    required void Function(Map<String, dynamic>) onMessage,
    required void Function(Map<String, dynamic>) onNotification,
    void Function(Map<String, dynamic>)? onLiveRequest,
  }) {
    var ch = db
        .channel('dars-${uid ?? 'anon'}')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'messages', callback: (p) => onMessage(p.newRecord))
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'notifications', callback: (p) => onNotification(p.newRecord));
    if (onLiveRequest != null) {
      ch = ch.onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'live_requests', callback: (p) => onLiveRequest(p.newRecord));
    }
    return ch.subscribe();
  }

  Future<void> unlisten(RealtimeChannel ch) => db.removeChannel(ch);

  // ------------------------------------------------------------------ mapping helpers
  static double _num(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
  static int _int(dynamic v) => _num(v).round();
  static DateTime time(dynamic v) => v == null ? DateTime.now() : DateTime.parse('$v').toLocal();

  static const _palette = [
    Color(0xFF2F6BFF), Color(0xFF7B61FF), Color(0xFF0E8F7E), Color(0xFFF59E0B), Color(0xFF22B573),
    Color(0xFFE5484D), Color(0xFF5B45D6), Color(0xFF0EA5E9), Color(0xFFEC4899),
  ];
  static Color colorFor(String s) => _palette[s.codeUnits.fold<int>(0, (a, c) => a + c) % _palette.length];

  static const _langs = {
    'ar': L('العربية', 'Arabic'), 'en': L('الإنجليزية', 'English'), 'fr': L('الفرنسية', 'French'),
    'tr': L('التركية', 'Turkish'), 'de': L('الألمانية', 'German'), 'es': L('الإسبانية', 'Spanish'),
  };

  static Tutor tutorFromRow(Map<String, dynamic> r, {List<Review> reviews = const [], Set<String> interests = const {}}) {
    final id = (r['id'] ?? r['user_id']) as String;
    final name = (r['full_name'] as String?)?.trim();
    final display = (name == null || name.isEmpty) ? 'مدرّس' : name;
    final subjects = [for (final s in (r['subject_ids'] as List?) ?? const []) '$s'];
    final langs = <L>[];
    for (final l in (r['languages'] as List?) ?? const []) {
      final code = l is Map ? '${l['code']}' : '$l';
      langs.add(_langs[code] ?? L(code.toUpperCase(), code.toUpperCase()));
    }
    final rating = _num(r['rating_avg']);
    final overlap = subjects.where(interests.contains).length;
    final country = (r['country'] as String?) ?? '';
    final headline = (r['headline'] as String?) ?? '';
    final about = (r['about'] as String?) ?? '';
    return Tutor(
      id: id,
      name: L(display, display),
      headline: L(headline, headline),
      about: L(about, about),
      subjectIds: subjects.isEmpty ? ['math'] : subjects,
      tags: const [],
      rating: rating,
      reviewCount: _int(r['rating_count']),
      hoursTaught: _int(r['hours_taught'] ?? (_num(r['minutes_taught']) / 60)),
      students: _int(r['students']),
      pricePerHour: _int(r['hourly_price']).clamp(1, 100000).toInt(),
      maxDiscount: _int(r['max_package_discount']),
      available: r['available_now'] == true,
      instantBooking: r['instant_booking'] != false,
      isNew: r['is_new'] == true,
      gender: (r['gender'] as String?) ?? 'm',
      country: L(country, country),
      languages: langs.isEmpty ? const [L('العربية', 'Arabic')] : langs,
      years: _int(r['years_experience']),
      matchScore: (55 + rating * 6 + overlap * 8 + (r['available_now'] == true ? 4 : 0)).clamp(0, 99).round(),
      color: colorFor(id),
      teachesOnline: r['teaches_online'] != false,
      teachesInPerson: r['teaches_in_person'] == true,
      cancelHours: _int(r['cancel_hours'] ?? 12),
      reviews: reviews,
    );
  }

  static Tutor stubTutor(String id, String name) => tutorFromRow({'id': id, 'full_name': name, 'hourly_price': 10});

  static LessonStatus lessonStatus(String s) => switch (s) {
        'pending_payment' => LessonStatus.pending,
        'confirmed' => LessonStatus.upcoming,
        'cancelled' => LessonStatus.cancelled,
        _ => LessonStatus.delivered, // delivered, no_show, disputed
      };

  static Lesson lessonFromRow(Map<String, dynamic> r, {required Tutor tutor, required L studentName, bool reviewed = false}) {
    final subject = MockData.subject((r['subject_id'] as String?) ?? tutor.subjectIds.first).name;
    final status = '${r['status']}';
    return Lesson(
      id: r['id'] as String,
      tutor: tutor,
      studentName: studentName,
      subject: subject,
      start: time(r['starts_at']),
      minutes: _int(r['duration_min']),
      online: r['mode'] != 'in_person',
      status: lessonStatus(status),
      price: _num(r['price']),
      link: r['meeting_url'] as String?,
      reviewed: reviewed || status == 'disputed' || status == 'no_show',
      number: _int(r['number']),
      commission: _num(r['commission']),
    );
  }

  static MsgType msgType(String k) => switch (k) {
        'voice' => MsgType.voice,
        'file' || 'image' => MsgType.file,
        'system' => MsgType.system,
        'call' => MsgType.call,
        _ => MsgType.text,
      };

  static Message messageFromRow(Map<String, dynamic> r, String? me) => Message(
        mine: r['sender_id'] != null && r['sender_id'] == me,
        text: (r['body'] as String?) ?? '',
        time: time(r['created_at']),
        type: msgType('${r['kind']}'),
        seconds: _int(r['duration_sec']),
        remoteId: _int(r['id']),
      );

  static WalletTx txFromRow(Map<String, dynamic> r) {
    final note = (r['note'] as String?) ?? '';
    final title = switch ('${r['kind']}') {
      'booking' => const L('حجز درس / باقة', 'Lesson / package booking'),
      'refund' => const L('استرداد', 'Refund'),
      'earning' => const L('أرباح درس', 'Lesson earnings'),
      'payout' => const L('طلب تحويل أرباح', 'Payout request'),
      'top_up' => const L('شحن رصيد', 'Top-up'),
      'referral' => const L('عمولة إحالة', 'Referral commission'),
      _ => L('تعديل رصيد · $note', 'Balance adjustment · $note'),
    };
    return WalletTx(title, _num(r['amount']), time(r['created_at']), const L('مكتمل', 'Completed'));
  }

  static AppNotification notificationFromRow(Map<String, dynamic> r) {
    final title = (r['title'] as String?) ?? '';
    final body = (r['body'] as String?) ?? '';
    final data = (r['data'] as Map?) ?? const {};
    final urgent = data['urgent'] == true;
    return AppNotification(
      L(_arTitles[title] ?? title, title),
      L(body, body),
      time(r['created_at']),
      urgent ? Icons.bolt_rounded : Icons.notifications_rounded,
      urgent ? const Color(0xFFF59E0B) : const Color(0xFF0E8F7E),
      read: r['read_at'] != null,
    );
  }

  // Server notifications are written in English; show the usual ones in Arabic too.
  static const _arTitles = {
    'New lesson booked': 'تم حجز درس جديد',
    'New package purchased': 'تم شراء باقة جديدة',
    'Payment & booking confirmed': 'تم تأكيد الدفع والحجز',
    'New booking': 'حجز جديد',
    'Refund issued': 'تم استرداد المبلغ لرصيدك',
    'Profile under review': 'ملفك قيد المراجعة',
    'Payout approved': 'تمت الموافقة على طلب التحويل',
    'Payout paid': 'تم تحويل أرباحك',
    'Payout rejected': 'تم رفض طلب التحويل',
    'Lesson cancelled': 'تم إلغاء الدرس',
    'Lesson rescheduled': 'تم تغيير موعد الدرس',
    'We value your opinion!': 'رأيك يهمنا!',
    'New review received': 'وصلك تقييم جديد',
    'Missed lesson': 'درس فائت',
    'Real time request!': 'طلب مساعدة فورية!',
    'A tutor accepted your request': 'قبِل مدرس طلبك',
    'Your profile is approved': 'تم اعتماد ملفك',
    'Your profile needs changes': 'ملفك يحتاج تعديلات',
  };

  static String errorText(Object e) {
    if (e is AuthException) return e.message;
    if (e is PostgrestException) return e.message;
    final s = '$e';
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }
}
