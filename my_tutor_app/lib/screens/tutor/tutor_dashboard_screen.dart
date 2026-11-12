import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/notifications_screen.dart';
import 'my_students_screen.dart';
import 'tutor_shell.dart';

class TutorDashboardScreen extends StatelessWidget {
  const TutorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.me;
    final wide = MediaQuery.of(context).size.width >= 900;
    final upcoming = app.tutorLessons.where((l) => l.status == LessonStatus.upcoming).toList()..sort((a, b) => a.start.compareTo(b.start));

    return SafeArea(
      child: ListView(padding: EdgeInsets.zero, children: [
        MaxWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Avatar(name: me.name, color: me.color, size: 48, online: app.tutorAvailable, photo: app.avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('tutor_hello'), style: const TextStyle(color: AppColors.text2)),
                    VerifiedName(me.name.of(context), size: 18),
                  ]),
                ),
                if (!wide) ...[
                  IconButton(onPressed: app.toggleLocale, icon: const Icon(Icons.language_rounded)),
                  IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ]),
              const SizedBox(height: 16),
              if (app.live && app.tutorVerification != null && app.tutorVerification != 'approved') ...[
                AppCard(
                  color: app.tutorVerification == 'rejected' ? AppColors.dangerSoft : AppColors.accentSoft,
                  borderColor: app.tutorVerification == 'rejected' ? AppColors.danger : AppColors.accent,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(app.tutorVerification == 'rejected' ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
                        color: app.tutorVerification == 'rejected' ? AppColors.danger : AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.tr(app.tutorVerification == 'rejected' ? 'profile_rejected_t' : 'treg_done_t'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          app.tutorVerification == 'rejected' ? (app.rejectionReason ?? '') : context.tr('profile_pending_b'),
                          style: const TextStyle(color: AppColors.text2, fontSize: 13.5, height: 1.5),
                        ),
                      ]),
                    ),
                    IconButton(onPressed: app.refresh, icon: const Icon(Icons.refresh_rounded), tooltip: context.tr('refresh')),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // Availability switch — drives live requests
              AppCard(
                color: app.tutorAvailable ? AppColors.primary : Colors.white,
                borderColor: app.tutorAvailable ? AppColors.primary : AppColors.line,
                child: Column(children: [
                  Row(children: [
                    Icon(app.tutorAvailable ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded, color: app.tutorAvailable ? Colors.white : AppColors.text3, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.tr('available_toggle'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: app.tutorAvailable ? Colors.white : AppColors.ink)),
                        Text(app.tutorAvailable ? context.tr('available_on') : context.tr('available_off'),
                            style: TextStyle(color: app.tutorAvailable ? const Color(0xD9FFFFFF) : AppColors.text2, fontSize: 13)),
                      ]),
                    ),
                    Switch(value: app.tutorAvailable, activeColor: Colors.white, activeTrackColor: AppColors.accent, onChanged: app.setAvailable),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: [
                    Icon(Icons.do_not_disturb_on_outlined, size: 18, color: app.tutorAvailable ? Colors.white : AppColors.text2),
                    const SizedBox(width: 6),
                    Text('${context.tr('dnd')} ${context.tr('dnd_for')}:', style: TextStyle(color: app.tutorAvailable ? Colors.white : AppColors.text2, fontSize: 13)),
                    const SizedBox(width: 6),
                    for (final h in [1, 2, 4, 8])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: InkWell(
                          onTap: () => app.setDnd(app.dndHours == h ? 0 : h),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: app.dndHours == h ? AppColors.accent : (app.tutorAvailable ? const Color(0x26FFFFFF) : AppColors.surface),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${h}h', style: TextStyle(fontWeight: FontWeight.w700, color: app.tutorAvailable ? Colors.white : AppColors.ink)),
                          ),
                        ),
                      ),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),

              // Stats
              GridView.count(
                crossAxisCount: wide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: wide ? 1.9 : 1.4,
                children: [
                  _stat(context.tr('stat_earnings'), money(app.tutorPending + app.tutorConfirmed), Icons.payments_rounded, AppColors.success,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()))),
                  _stat(context.tr('stat_hours'), '${me.hoursTaught}', Icons.schedule_rounded, AppColors.info),
                  _stat(context.tr('stat_rating'), me.rating.toStringAsFixed(1), Icons.star_rounded, AppColors.accent),
                  _stat(context.tr('stat_students'), '${me.students}', Icons.groups_rounded, AppColors.lavenderInk),
                ],
              ),

              // Live requests preview
              SectionTitle(context.tr('incoming_requests'), action: context.tr('see_all'), onAction: () => TutorShell.of(context)?.go(1)),
              if (!app.tutorAvailable || app.liveRequests.isEmpty)
                AppCard(child: Row(children: [
                  const Icon(Icons.inbox_outlined, color: AppColors.text3),
                  const SizedBox(width: 10),
                  Expanded(child: Text(app.tutorAvailable ? context.tr('no_requests') : context.tr('no_requests_b'), style: const TextStyle(color: AppColors.text2))),
                ]))
              else
                for (final r in app.liveRequests.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => TutorShell.of(context)?.go(1),
                      child: Row(children: [
                        Avatar(name: r.studentName, color: r.color, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${r.studentName.of(context)} · ${r.subject.of(context)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(r.text.isNotEmpty ? r.text : '🎤 ${context.tr('voice_msg')} 0:${two(r.voiceSeconds)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text2)),
                          ]),
                        ),
                        const Icon(Icons.bolt_rounded, color: AppColors.accent),
                      ]),
                    ),
                  ),

              // My students
              AppCard(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyStudentsScreen())),
                child: Row(children: [
                  const Icon(Icons.groups_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.tr('my_students'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  Pill('${app.myStudents.length}', bg: AppColors.primarySoft, fg: AppColors.primary),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
                ]),
              ),
              const SizedBox(height: 12),

              // Upcoming lessons
              SectionTitle(context.tr('upcoming_lessons'), action: context.tr('see_all'), onAction: () => TutorShell.of(context)?.go(2)),
              for (final l in upcoming.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(children: [
                      Avatar(name: l.studentName, color: AppColors.info, size: 44, photo: app.photoOf(l.studentId)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.subject.of(context), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${l.studentName.of(context)} · ${dayOf(context, l.start)} ${timeOf(context, l.start)}', style: const TextStyle(color: AppColors.text2, fontSize: 13)),
                        ]),
                      ),
                      Pill(l.online ? context.tr('online') : context.tr('in_person'), bg: AppColors.surface, fg: AppColors.text2),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: color),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text2, fontSize: 12.5)),
          ]),
        ]),
      );
}

/// Tutor balance: pending / confirmed, commission breakdown, payout request.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  static const _prefsKey = 'dars.payout_details';
  String _method = 'sham_cash';
  final _holder = TextEditingController();
  final _account = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    super.dispose();
  }

  /// The details used last time, remembered on this device.
  Future<void> _loadSaved() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (raw == null || !mounted) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _method = '${m['method'] ?? _method}';
        _holder.text = '${m['holder'] ?? ''}';
        _account.text = '${m['account'] ?? ''}';
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_prefsKey, jsonEncode({'method': _method, 'holder': _holder.text.trim(), 'account': _account.text.trim()}));
    } catch (_) {}
  }

  String _methodName(String k, bool ar) => switch (k) {
        'sham_cash' => ar ? 'شام كاش' : 'Sham Cash',
        'syriatel_cash' => ar ? 'سيريتل كاش' : 'Syriatel Cash',
        'mtn_cash' => ar ? 'MTN كاش' : 'MTN Cash',
        'bank' => ar ? 'تحويل بنكي' : 'Bank transfer',
        'paypal' => 'PayPal',
        _ => 'Western Union',
      };

  Future<void> _request(AppState app) async {
    final ar = context.isAr;
    final holder = _holder.text.trim();
    final account = _account.text.trim();
    if (holder.isEmpty || account.isEmpty) {
      toast(context, ar ? 'اكتب اسم صاحب الحساب ورقم الحساب أو المحفظة' : 'Enter the account holder name and the account or wallet number', icon: Icons.info_outline);
      return;
    }
    final amount = double.parse(app.tutorConfirmed.toStringAsFixed(2));
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(ar ? 'تأكيد طلب التحويل' : 'Confirm payout'),
        content: Text(
          ar
              ? 'سنحوّل ${money(amount)} إلى:\n${_methodName(_method, ar)}\n$holder\n$account'
              : 'We will send ${money(amount)} to:\n${_methodName(_method, ar)}\n$holder\n$account',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ar ? 'تعديل' : 'Edit')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(ar ? 'تأكيد' : 'Confirm')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _busy = true);
    await _save();
    final ok = await app.requestPayout(method: _method, amount: amount, holderName: holder, account: account);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) toast(context, context.tr('payout_sent'));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.surface, surfaceTintColor: AppColors.surface, title: Text(context.tr('earnings'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: MaxWidth(
        max: 720,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(child: _box(context.tr('pending_amount'), app.tutorPending, AppColors.accent)),
            const SizedBox(width: 10),
            Expanded(child: _box(context.tr('confirmed_amount'), app.tutorConfirmed, AppColors.success)),
          ]),
          const SizedBox(height: 12),
          AppCard(
            child: Column(children: [
              _row(context.isAr ? 'رسوم الدروس المكتملة' : 'Delivered lesson fees', money(double.parse(app.tutorGross.toStringAsFixed(2)))),
              _row(context.tr('commission'), '-${money(double.parse(app.tutorCommission.toStringAsFixed(2)))}'),
              const Divider(),
              _row(context.isAr ? 'الصافي' : 'Net', money(double.parse((app.tutorGross - app.tutorCommission).toStringAsFixed(2))), bold: true),
            ]),
          ),
          SectionTitle(context.tr('payout_method')),
          for (final k in const ['sham_cash', 'syriatel_cash', 'mtn_cash', 'bank', 'paypal', 'wu'])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChoiceTile(
                title: _methodName(k, context.isAr),
                icon: k == 'bank' ? Icons.account_balance_rounded : (k == 'paypal' || k == 'wu' ? Icons.public_rounded : Icons.phone_android_rounded),
                selected: _method == k,
                onTap: () => setState(() => _method = k),
              ),
            ),
          const SizedBox(height: 6),
          TextField(
            controller: _holder,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: context.isAr ? 'اسم صاحب الحساب' : 'Account holder name', counterText: ''),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _account,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: _method == 'paypal'
                  ? (context.isAr ? 'بريد PayPal' : 'PayPal email')
                  : (_method == 'bank' ? (context.isAr ? 'رقم الحساب / IBAN' : 'Account number / IBAN') : (context.isAr ? 'رقم الحساب أو المحفظة' : 'Account or wallet number')),
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: app.tutorConfirmed <= 0 || _busy ? null : () => _request(app),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text('${context.tr('pay_me')} · ${money(app.tutorConfirmed)}'),
          ),
        ]),
      ),
    );
  }

  Widget _box(String label, double v, Color c) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.text2)),
          const SizedBox(height: 4),
          Text(money(double.parse(v.toStringAsFixed(2))), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c)),
        ]),
      );

  Widget _row(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(k, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          const Spacer(),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}
