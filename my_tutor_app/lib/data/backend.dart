import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

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

  /// A saved sign-in exists on this device, even if it could not be refreshed yet (no internet).
  bool hasSavedSession = false;

  /// The user id stored with the saved sign-in (known even while offline).
  String? savedUid;

  Future<void>? _initOnce;

  /// Safe to call many times / at the same time.
  Future<void> init() => _initOnce ??= _init();

  Future<void> _init() async {
    if (_ready || !DarsConfig.live) return;
    db = SupabaseClient(
      DarsConfig.supabaseUrl,
      DarsConfig.supabaseAnonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    _ready = true;
    _authSub = db.auth.onAuthStateChange.listen((s) async {
      final p = await SharedPreferences.getInstance();
      if (s.session != null) {
        hasSavedSession = true;
        savedUid = s.session!.user.id;
        await p.setString(_sessionKey, jsonEncode(s.session!.toJson()));
      } else if (s.event == AuthChangeEvent.signedOut && !_restoring) {
        hasSavedSession = false;
        savedUid = null;
        await p.remove(_sessionKey);
      }
    });
    // Keep the user signed in between app launches — only "Sign out" (or a revoked account) ends it.
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_sessionKey);
    if (saved != null) {
      hasSavedSession = true;
      try {
        savedUid = ((jsonDecode(saved) as Map)['user'] as Map?)?['id'] as String?;
      } catch (_) {}
      await restore();
    }
  }

  bool _restoring = false;

  /// Re-activates the saved sign-in. Returns true when signed in. A network problem keeps the
  /// saved sign-in (we simply try again later); only a rejected/expired-for-good token removes it.
  Future<bool> restore() async {
    if (!_ready) return false;
    if (db.auth.currentSession != null && !db.auth.currentSession!.isExpired) return true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_sessionKey);
    if (saved == null) return db.auth.currentUser != null;
    _restoring = true;
    try {
      await db.auth.recoverSession(saved);
      return db.auth.currentUser != null;
    } on AuthException catch (e) {
      final code = int.tryParse(e.statusCode ?? '') ?? 0;
      final msg = e.message.toLowerCase();
      final rejected = (code >= 400 && code < 500) || msg.contains('refresh token') || msg.contains('invalid');
      if (rejected) {
        hasSavedSession = false;
        savedUid = null;
        await prefs.remove(_sessionKey);
      }
      return false;
    } catch (_) {
      return false; // offline / server unreachable — keep the saved sign-in
    } finally {
      _restoring = false;
    }
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

  Future<void> signOut() async {
    hasSavedSession = false;
    savedUid = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_sessionKey);
    try {
      await db.auth.signOut();
    } catch (_) {}
  }

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
  /// How many of the newest messages of each chat are loaded at first (older ones load on scroll).
  static const pageSize = 50;

  /// The newest [pageSize] messages of each chat, oldest first (asked 20 chats at a time,
  /// so no answer goes over the server's 1,000-row limit).
  Future<List<Map<String, dynamic>>> messagesFor(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return [];
    final chunks = [
      for (var i = 0; i < conversationIds.length; i += 20)
        conversationIds.sublist(i, i + 20 > conversationIds.length ? conversationIds.length : i + 20),
    ];
    final parts = await Future.wait<List<Map<String, dynamic>>>([
      for (final ids in chunks) _rows('recent_messages', {'p_conversations': ids, 'p_limit': pageSize}),
    ]);
    return [for (final p in parts) ...p];
  }

  Future<List<Map<String, dynamic>>> _rows(String fn, Map<String, dynamic> params) async {
    final r = await db.rpc(fn, params: params);
    return [for (final x in (r as List)) Map<String, dynamic>.from(x as Map)];
  }

  /// [pageSize] messages of a chat written before the given one, oldest first.
  Future<List<Map<String, dynamic>>> olderMessages(String conversationId, DateTime beforeAt, int beforeId) => _rows('older_messages', {
        'p_conversation': conversationId,
        'p_before_at': beforeAt.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': pageSize,
      });

  /// Names and photos of people I share a lesson or chat with (never their phone or email).
  Future<Map<String, String>> names(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final rows = await _rows('partner_profiles', {'p_ids': list});
    for (final r in rows) {
      photos[r['id'] as String] = (r['avatar_url'] as String?) ?? '';
    }
    return {for (final r in rows) r['id'] as String: (r['full_name'] as String?) ?? ''};
  }

  /// Profile photos of the people I have chats / lessons with (filled by [names]).
  final Map<String, String> photos = {};

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

  // ------------------------------------------------------------------ working hours
  Future<List<Map<String, dynamic>>> myWorkHours() =>
      db.from('availability_slots').select('weekday, start_time, end_time').eq('tutor_id', uid!).order('weekday').order('start_time');

  Future<void> setWorkingHours(int tzOffset, List<Map<String, dynamic>> slots) =>
      db.rpc('set_working_hours', params: {'p_tz_offset': tzOffset, 'p_slots': slots});

  Future<Map<String, dynamic>> tutorSchedule(String tutorId) async =>
      Map<String, dynamic>.from((await db.rpc('tutor_schedule', params: {'p_tutor': tutorId})) as Map);

  // ------------------------------------------------------------------ calls
  /// Servers that help two phones find each other. STUN is public; the TURN relay (needed on most
  /// mobile networks) is entered by the admin in the dashboard and handed out only to signed-in users.
  Future<List<Map<String, dynamic>>> iceServers() async {
    final list = <Map<String, dynamic>>[
      {
        'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302', 'stun:stun.cloudflare.com:3478'],
      },
    ];
    try {
      final r = await db.rpc('call_ice_servers');
      if (r is List) {
        for (final x in r) {
          if (x is Map) list.add(Map<String, dynamic>.from(x));
        }
      }
    } catch (_) {}
    return list;
  }

  /// Realtime room the two sides of a call use to exchange connection details.
  RealtimeChannel callChannel(String room) => db.channel('dars-call-$room', opts: const RealtimeChannelConfig(self: false));

  Future<void> closeChannel(RealtimeChannel ch) async {
    try {
      await db.removeChannel(ch);
    } catch (_) {}
  }

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

  /// Posts a message and returns the server's copy (id, time, and whether the contact filter hid it).
  /// [clientId] is made once per message: if an earlier attempt already reached the server
  /// (only the answer was lost), the server refuses the copy and the stored message is returned.
  Future<Map<String, dynamic>> sendMessage(String conversationId, String text,
      {String kind = 'text', int? seconds, String? fileUrl, String? clientId}) async {
    try {
      return await db
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': uid,
            'kind': kind,
            'body': text,
            if (seconds != null) 'duration_sec': seconds,
            if (fileUrl != null && fileUrl.isNotEmpty) 'file_url': fileUrl,
            if (clientId != null) 'client_id': clientId,
          })
          .select()
          .single();
    } on PostgrestException catch (e) {
      if (e.code != '23505' || clientId == null) rethrow;
      return await db.from('messages').select().eq('sender_id', uid!).eq('client_id', clientId).single();
    }
  }

  static final _rnd = Random.secure();

  /// A random id (UUID v4), e.g. for a message or a receipt file name.
  static String newId() {
    final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ------------------------------------------------------------------ payments (transfer + receipt)
  /// Pay-to accounts the owner has set up, by method ('' = not offered).
  Future<Map<String, String>> payToAccounts() async {
    final rows = await db.from('app_settings').select('key, value').like('key', 'pay_to_%');
    final out = <String, String>{};
    for (final r in rows) {
      final v = r['value'];
      final s = (v is String ? v : '${v ?? ''}').trim();
      if (s.isNotEmpty) out['${r['key']}'.substring(7)] = s; // pay_to_sham_cash → sham_cash, pay_to_bank → bank
    }
    return out;
  }

  /// A setting everyone can read (e.g. min_app_build, top_up_min).
  Future<dynamic> setting(String key) async => (await db.from('app_settings').select('value').eq('key', key).maybeSingle())?['value'];

  Future<List<Map<String, dynamic>>> myTopUps() =>
      db.from('payments').select().eq('user_id', uid!).eq('purpose', 'top_up').order('created_at', ascending: false).limit(30);

  /// The latest payment of one of my lessons (null if none).
  Future<Map<String, dynamic>?> latestPaymentFor(String lessonId) async {
    final rows = await db.from('payments').select().eq('user_id', uid!).eq('lesson_id', lessonId).order('created_at', ascending: false).limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  static PaymentInfo paymentFromRow(Map<String, dynamic> r) => PaymentInfo(
        id: '${r['id']}',
        amount: _num(r['amount']),
        method: '${r['method'] ?? ''}',
        status: '${r['status'] ?? ''}',
        reference: (r['reference'] as String?) ?? '',
        failReason: (r['fail_reason'] as String?) ?? '',
        created: time(r['created_at']),
      );

  static TransferInfo transferFromJson(Map r) => TransferInfo(
        paymentId: '${r['payment_id']}',
        amount: _num(r['amount']),
        method: '${r['method']}',
        payTo: '${r['pay_to'] ?? ''}',
        reference: '${r['reference'] ?? ''}',
      );

  /// Uploads a receipt under a new random name (receipts/<me>/<random id>.<ext>) and returns the stored path.
  /// Never overwrites: a receipt cannot be replaced once uploaded.
  Future<String> uploadReceipt(Uint8List bytes, String ext, String mime) async {
    final path = '$uid/${newId()}.$ext';
    await db.storage.from('receipts').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
    return 'receipts/$path';
  }

  // ------------------------------------------------------------------ files
  /// Uploads into "<my id>/<name>" of a storage bucket; returns "<bucket>/<path>".
  Future<String> upload(String bucket, String name, Uint8List bytes, String contentType) async {
    final path = '$uid/$name';
    await db.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: true));
    return '$bucket/$path';
  }

  static const _publicBuckets = {'avatars', 'tutor-media'};

  /// A URL that can be opened for a stored "<bucket>/<path>" (public link, or a 1-hour signed link).
  Future<String> fileUrl(String stored) async {
    if (stored.startsWith('http')) return stored;
    final i = stored.indexOf('/');
    if (i <= 0) return '';
    final bucket = stored.substring(0, i);
    final path = stored.substring(i + 1);
    if (_publicBuckets.contains(bucket)) return db.storage.from(bucket).getPublicUrl(path);
    return db.storage.from(bucket).createSignedUrl(path, 3600);
  }

  String publicUrl(String stored) {
    final i = stored.indexOf('/');
    return db.storage.from(stored.substring(0, i)).getPublicUrl(stored.substring(i + 1));
  }

  Future<void> markRead(String conversationId) => db.rpc('mark_conversation_read', params: {'p_conversation': conversationId});

  Future<void> reportConversation(String conversationId, String reason) =>
      db.rpc('report_conversation', params: {'p_conversation': conversationId, 'p_reason': reason});

  /// The price the server will charge: hourly price for my level and the real package discounts.
  Future<Map<String, dynamic>?> priceQuote(String tutorId, String level) async {
    final r = await db.rpc('price_quote', params: {'p_tutor': tutorId, 'p_level': level});
    return r == null ? null : Map<String, dynamic>.from(r as Map);
  }

  Future<void> markNotificationRead(int id) =>
      db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('user_id', uid!);

  /// New hourly price: every level price moves by the same ratio.
  Future<void> updateTutorPrice(double price, double oldPrice) async {
    await updateTutor({'hourly_price': double.parse(price.toStringAsFixed(2))});
    final rows = await db.from('tutor_level_prices').select().eq('tutor_id', uid!);
    final f = oldPrice > 0 ? price / oldPrice : 1.0;
    for (final r in rows) {
      final p = _num(r['price']) * f;
      await db.from('tutor_level_prices').update({'price': double.parse((p < 1 ? 1 : p).toStringAsFixed(2))}).eq('tutor_id', uid!).eq('level_id', '${r['level_id']}');
    }
  }

  Future<void> setMySubjects(Set<String> subjects) async {
    final me = uid!;
    await db.from('tutor_subjects').delete().eq('tutor_id', me);
    await db.from('tutor_subjects').insert([for (final s in subjects) {'tutor_id': me, 'subject_id': s}]);
  }

  Future<void> markNotificationsRead() =>
      db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', uid!).isFilter('read_at', null);

  Future<void> submitLead(Map<String, dynamic> lead) => db.from('leads').insert(lead);

  /// Pushes new chat messages / notifications / live requests to the app as they happen.
  RealtimeChannel listen({
    required void Function(Map<String, dynamic>) onMessage,
    required void Function(Map<String, dynamic>) onNotification,
    void Function(Map<String, dynamic>)? onMessageUpdate,
    void Function(Map<String, dynamic>)? onLiveRequest,
    void Function()? onConnected,
  }) {
    var ch = db
        .channel('dars-${uid ?? 'anon'}')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'messages', callback: (p) => onMessage(p.newRecord))
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'notifications', callback: (p) => onNotification(p.newRecord));
    if (onMessageUpdate != null) {
      // "read" ticks: the other person opened the chat.
      ch = ch.onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'messages', callback: (p) => onMessageUpdate(p.newRecord));
    }
    if (onLiveRequest != null) {
      ch = ch.onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'live_requests', callback: (p) => onLiveRequest(p.newRecord));
    }
    return ch.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) onConnected?.call();
    });
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
      photoUrl: (r['avatar_url'] as String?) ?? '',
      videoUrl: (r['video_url'] as String?) ?? '',
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
      studentId: '${r['student_id'] ?? ''}',
    );
  }

  static MsgType msgType(String k) => switch (k) {
        'voice' => MsgType.voice,
        'image' => MsgType.image,
        'file' => MsgType.file,
        'system' => MsgType.system,
        'call' => MsgType.call,
        _ => MsgType.text,
      };

  static final _videoName = RegExp(r'\.(mp4|mov|m4v|webm|3gp|mkv)$', caseSensitive: false);

  static Message messageFromRow(Map<String, dynamic> r, String? me) {
    final body = (r['body'] as String?) ?? '';
    final url = (r['file_url'] as String?) ?? '';
    var type = msgType('${r['kind']}');
    if (type == MsgType.file && (_videoName.hasMatch(body) || _videoName.hasMatch(url))) type = MsgType.video;
    return Message(
      mine: r['sender_id'] != null && r['sender_id'] == me,
      text: body,
      time: time(r['created_at']),
      type: type,
      seconds: _int(r['duration_sec']),
      remoteId: _int(r['id']),
      url: url,
      readAt: r['read_at'] == null ? null : time(r['read_at']),
      blocked: r['blocked'] == true,
      clientId: r['client_id'] as String?,
    );
  }

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
      data: Map<String, dynamic>.from(data),
      remoteId: _int(r['id']),
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
