import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/backend.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/chat_screen.dart';
import '../shared/transfer_screens.dart';

/// Booking wizard: type (single / package) → time → summary → payment → success.
class BookingScreen extends StatefulWidget {
  final Tutor tutor;
  final double hourPrice;
  const BookingScreen({super.key, required this.tutor, required this.hourPrice});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _step = 0;
  bool _package = false;
  int _hours = 8;
  int _minutes = 60;
  int _day = 0;
  DateTime? _slot; // chosen lesson start (my local time)
  TutorSchedule? _schedule; // the tutor's working hours + booked times (null while loading)
  bool _online = true;
  bool _useBalance = true;
  String? _method; // transfer method (pay-to key) when credit does not cover the booking
  bool _terms = true;
  bool _processing = false;
  final _notes = TextEditingController();

  // Used only when the tutor has not set working hours yet.
  static const _defaultHours = [9, 10, 13, 16, 17, 18, 19, 20, 21];

  // The price the server will charge (per 60 minutes at my level + real package discounts).
  ({double hourly, Map<int, int> discounts})? _quote;
  double get _hourly => _quote?.hourly ?? widget.hourPrice;
  int _discount(AppState app, int hours) => _quote?.discounts[hours] ?? app.discountFor(widget.tutor, hours);
  static double _r2(num v) => (v * 100).round() / 100;
  /// Same rule as the server: hourly price × minutes / 60, rounded to cents.
  double _lessonPrice(int minutes) => _r2(_hourly * minutes / 60);

  @override
  void initState() {
    super.initState();
    context.read<AppState>().priceQuote(widget.tutor).then((q) {
      if (mounted && q != null) setState(() => _quote = q);
    });
    context.read<AppState>().scheduleFor(widget.tutor).then((s) {
      if (!mounted) return;
      setState(() {
        _schedule = s;
        // Start on the first day that has free times.
        for (var i = 0; i < 14; i++) {
          if (_timesFor(i).any((t) => !t.taken)) {
            _day = i;
            break;
          }
        }
      });
    });
  }

  int get _lessonMinutes => _package ? 60 : _minutes;

  /// Start times on day [i] (from today), in my local time, with whether each one is already taken.
  List<({DateTime time, bool taken})> _timesFor(int i) {
    final day = _dayDate(i);
    final now = DateTime.now();
    final s = _schedule;
    final len = Duration(minutes: _lessonMinutes);
    final starts = <DateTime>[];
    if (s == null || s.periods.isEmpty) {
      for (final h in _defaultHours) {
        starts.add(day.add(Duration(hours: h)));
      }
    } else {
      // The tutor's hours are in their own time zone; check the tutor days around mine.
      for (var k = -1; k <= 1; k++) {
        final td = DateTime.utc(day.year, day.month, day.day + k);
        final dow = td.weekday % 7; // 0 = Sunday
        for (final p in s.periods.where((p) => p.weekday == dow)) {
          for (var m = p.start; m + _lessonMinutes <= p.end; m += 60) {
            final local = td.add(Duration(minutes: m - s.tzOffset)).toLocal();
            if (local.year == day.year && local.month == day.month && local.day == day.day) starts.add(local);
          }
        }
      }
      starts.sort();
    }
    final out = <({DateTime time, bool taken})>[];
    for (final t in starts) {
      final end = t.add(len);
      var taken = t.isBefore(now.add(const Duration(minutes: 30)));
      for (final b in s?.busy ?? const <({DateTime start, DateTime end})>[]) {
        if (t.isBefore(b.end) && end.isAfter(b.start)) taken = true;
      }
      if (!taken && !context.read<AppState>().live) taken = (i * 3 + t.hour) % 5 == 0; // demo: some taken
      if (out.every((x) => x.time != t)) out.add((time: t, taken: taken));
    }
    return out;
  }

  List<String> get _steps => _package ? ['step_type', 'step_summary', 'step_pay'] : ['step_type', 'step_time', 'step_summary', 'step_pay'];
  String get _current => _steps[_step];

  DateTime _dayDate(int i) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + i);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = widget.tutor;
    final discount = _package ? _discount(app, _hours) : 0;
    final original = _package ? _r2(_hourly * _hours) : _lessonPrice(_minutes);
    final subtotal = _package ? _r2(_hourly * _hours * (100 - discount) / 100) : original;
    final balanceUsed = _useBalance ? (app.walletBalance < subtotal ? app.walletBalance : subtotal) : 0.0;
    final total = subtotal - balanceUsed;

    final methods = transferMethodKeys.where((k) => (app.payTo[k] ?? '').isNotEmpty).toList();
    final ar = context.isAr;
    final dueNow = double.parse(total.toStringAsFixed(2));
    bool canNext = true;
    if (_current == 'step_time') canNext = _slot != null;
    if (_current == 'step_pay') canNext = _terms && !_processing && (dueNow <= 0 || methods.isEmpty || !app.live || _method != null);

    Widget body;
    switch (_current) {
      case 'step_type':
        body = Column(children: [
          ChoiceTile(
            title: context.tr('single_lesson'),
            subtitle: context.tr('single_lesson_d'),
            icon: Icons.event_available_rounded,
            color: AppColors.info,
            selected: !_package,
            onTap: () => setState(() => _package = false),
          ),
          const SizedBox(height: 10),
          if (t.hasPackages)
            ChoiceTile(
              title: context.tr('package'),
              subtitle: '${context.tr('package_d')} ${t.maxDiscount}%',
              icon: Icons.card_giftcard_rounded,
              color: AppColors.accent,
              selected: _package,
              onTap: () => setState(() => _package = true),
            ),
          const SizedBox(height: 20),
          if (_package) ...[
            _label(context.tr('choose_hours')),
            Row(children: [
              for (final h in [4, 8, 12, 20])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: _optionBox(
                      selected: _hours == h,
                      onTap: () => setState(() => _hours = h),
                      top: '$h',
                      bottom: '-${_discount(app, h)}%',
                    ),
                  ),
                ),
            ]),
          ] else ...[
            _label(context.tr('duration')),
            Row(children: [
              for (final m in [30, 60, 90])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: _optionBox(
                      selected: _minutes == m,
                      onTap: () => setState(() => _minutes = m),
                      top: '$m ${context.tr('min')}',
                      bottom: money(_lessonPrice(m)),
                    ),
                  ),
                ),
            ]),
          ],
        ]);
        break;

      case 'step_time':
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(context.tr('date')),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = _dayDate(i);
                final sel = _day == i;
                final dayOff = _schedule != null && _schedule!.periods.isNotEmpty && !_timesFor(i).any((x) => !x.taken);
                const keys = ['day_mon', 'day_tue', 'day_wed', 'day_thu', 'day_fri', 'day_sat', 'day_sun'];
                return InkWell(
                  onTap: () => setState(() {
                    _day = i;
                    _slot = null;
                  }),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 64,
                    foregroundDecoration: dayOff && !sel ? BoxDecoration(color: Colors.white.withOpacity(0.55), borderRadius: BorderRadius.circular(16)) : null,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.line),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(i == 0 ? context.tr('today') : context.tr(keys[d.weekday - 1]),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppColors.text3)),
                      Text('${d.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.ink)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _label(context.tr('time')),
          if (_schedule == null)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
          else if (_timesFor(_day).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(context.tr('no_times_day'), style: const TextStyle(color: AppColors.text3, fontWeight: FontWeight.w700)),
            )
          else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final x in _timesFor(_day))
              Builder(builder: (_) {
                final taken = x.taken;
                final sel = _slot == x.time;
                return ChoiceChip(
                  label: Text(timeOf(context, x.time)),
                  selected: sel,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  disabledColor: AppColors.surface,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: sel ? AppColors.primary : AppColors.line),
                  labelStyle: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : (taken ? AppColors.text3 : AppColors.ink),
                    decoration: taken ? TextDecoration.lineThrough : null,
                  ),
                  onSelected: taken ? null : (_) => setState(() => _slot = x.time),
                );
              }),
          ]),
          const SizedBox(height: 6),
          Text(context.tr('tz_note'), style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
          const SizedBox(height: 18),
          _label(context.tr('lesson_mode')),
          Row(children: [
            Expanded(child: ChoiceTile(title: context.tr('online'), icon: Icons.videocam_rounded, selected: _online, onTap: () => setState(() => _online = true))),
            const SizedBox(width: 8),
            Expanded(
              child: Opacity(
                opacity: t.teachesInPerson ? 1 : 0.4,
                child: ChoiceTile(title: context.tr('in_person'), icon: Icons.home_work_rounded, selected: !_online, onTap: () {
                  if (t.teachesInPerson) setState(() => _online = false);
                }),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(hintText: context.tr('notes_opt'))),
        ]);
        break;

      case 'step_summary':
        final start = _slot;
        body = Column(children: [
          AppCard(
            child: Row(children: [
              Avatar(name: t.name, color: t.color, photo: t.photoUrl, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  VerifiedName(t.name.of(context)),
                  Text(MockData.subject(t.subjectIds.first).name.of(context), style: const TextStyle(color: AppColors.text2)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(children: [
              if (_package) ...[
                _line(context.tr('package'), '$_hours ${context.tr('hours')}'),
                _line(context.tr('package_price'), money(original)),
                _line(context.tr('discount'), '-$discount%  (-${money(double.parse((original - subtotal).toStringAsFixed(2)))})', color: AppColors.success),
              ] else ...[
                if (start != null) _line(context.tr('date'), '${dayOf(context, start)} · ${timeOf(context, start)}'),
                _line(context.tr('duration'), '$_minutes ${context.tr('min')}'),
                _line(context.tr('lesson_mode'), _online ? context.tr('online') : context.tr('in_person')),
                _line(context.tr('lesson_price'), money(double.parse(original.toStringAsFixed(2)))),
              ],
              const Divider(height: 24),
              Row(children: [
                const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('${context.tr('use_balance')} (${money(app.walletBalance)})', style: const TextStyle(fontWeight: FontWeight.w600))),
                Switch(value: _useBalance, activeColor: AppColors.primary, onChanged: app.walletBalance > 0 ? (v) => setState(() => _useBalance = v) : null),
              ]),
              if (balanceUsed > 0) _line(context.tr('balance'), '-${money(double.parse(balanceUsed.toStringAsFixed(2)))}', color: AppColors.success),
              const Divider(height: 24),
              _line(context.tr('total'), money(double.parse(total.toStringAsFixed(2))), bold: true),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.accentSoft,
            borderColor: AppColors.accentSoft,
            child: Row(children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(child: Text(context.tr('guarantee_b'), style: const TextStyle(fontSize: 13.5))),
            ]),
          ),
        ]);
        break;

      default: // step_pay
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (dueNow <= 0)
            AppCard(
              color: AppColors.successSoft,
              borderColor: AppColors.successSoft,
              child: Row(children: [
                const Icon(Icons.verified_rounded, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(ar ? 'سيُدفع الحجز كاملاً من رصيدك ويتأكد فوراً.' : 'Paid in full from your credit — confirmed right away.',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            )
          else ...[
            AppCard(
              color: AppColors.accentSoft,
              borderColor: AppColors.accentSoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  balanceUsed > 0
                      ? (ar ? 'رصيدك يغطي ${money(_r2(balanceUsed))}. المتبقي ${money(dueNow)}.' : 'Your credit covers ${money(_r2(balanceUsed))}. ${money(dueNow)} is still due.')
                      : (ar ? 'المبلغ المطلوب ${money(dueNow)}.' : '${money(dueNow)} to pay.'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(ar ? 'اشحن رصيدك ثم احجز، فيتأكد الحجز فوراً.' : 'Add credit, then book — the booking is confirmed right away.',
                    style: const TextStyle(color: AppColors.text2, fontSize: 13.5)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopUpScreen(suggested: dueNow))),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(ar ? 'شحن الرصيد' : 'Add credit'),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            _label(ar ? 'أو ادفع هذا الحجز بالتحويل' : 'Or pay this booking by transfer'),
            if (methods.isNotEmpty)
              TransferMethodTiles(accounts: app.payTo, selected: _method, onSelect: (k) => setState(() => _method = k))
            else
              AppCard(
                color: AppColors.infoSoft,
                borderColor: AppColors.infoSoft,
                child: Text(
                  ar
                      ? 'الدفع بالتحويل قيد التجهيز. سيُحجز موعدك ٤٨ ساعة ويتواصل معك فريق درس لإتمام الدفع.'
                      : 'Paying by transfer is being set up. Your time is held for 48 hours and the Dars team will contact you to complete payment.',
                  style: const TextStyle(fontSize: 13.5, height: 1.5),
                ),
              ),
            if (methods.isNotEmpty && app.live) ...[
              const SizedBox(height: 6),
              Text(
                ar
                    ? 'بعد الحجز ستظهر لك بيانات الحساب ورقم مرجع، ثم ترفع صورة الإيصال. يُحجز موعدك ٤٨ ساعة.'
                    : 'After booking you will see the account and a reference, then upload the receipt. Your time is held for 48 hours.',
                style: const TextStyle(color: AppColors.text2, fontSize: 13, height: 1.5),
              ),
            ],
          ],
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
            value: _terms,
            onChanged: (v) => setState(() => _terms = v ?? false),
            title: Text(context.tr('accept_terms'), style: const TextStyle(fontSize: 14)),
          ),
        ]);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(context.tr('booking'), style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const BackButtonIcon(), onPressed: () {
          if (_step > 0) {
            setState(() => _step--);
          } else {
            Navigator.pop(context);
          }
        }),
      ),
      body: MaxWidth(
        max: 640,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Row(children: [
            for (int i = 0; i < _steps.length; i++)
              Expanded(
                child: Column(children: [
                  Container(
                    height: 5,
                    margin: const EdgeInsetsDirectional.only(end: 6),
                    decoration: BoxDecoration(color: i <= _step ? AppColors.primary : AppColors.line, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 6),
                  Text(context.tr(_steps[i]), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: i <= _step ? AppColors.primary : AppColors.text3)),
                ]),
              ),
          ]),
          const SizedBox(height: 20),
          body,
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
          child: MaxWidth(
            max: 640,
            child: Row(children: [
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('total'), style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
                Text(money(double.parse(total.toStringAsFixed(2))), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: !canNext
                      ? null
                      : () async {
                          if (_current != 'step_pay') {
                            setState(() => _step++);
                            return;
                          }
                          setState(() => _processing = true);
                          if (!app.live) await Future.delayed(const Duration(milliseconds: 1600));
                          if (!mounted) return;
                          final start = _slot ?? _dayDate(1).add(const Duration(hours: 18));
                          try {
                            await app.book(
                              tutor: t,
                              isPackage: _package,
                              hours: _hours,
                              minutes: _minutes,
                              start: start,
                              online: _online,
                              total: total,
                              balanceUsed: balanceUsed,
                              subject: MockData.subject(t.subjectIds.first).name,
                              subjectId: t.subjectIds.first,
                              method: _method ?? 'bank',
                              notes: _notes.text,
                            );
                          } catch (e) {
                            if (mounted) setState(() => _processing = false);
                            app.say(Backend.errorText(e), bad: true);
                            return;
                          }
                          if (!mounted) return;
                          // Something left to pay by transfer: go straight to the account, reference and receipt screen.
                          final payId = app.lastPaymentId;
                          final m = _method;
                          if (app.live && app.lastAmountDue > 0 && payId != null && m != null) {
                            final info = await app.transferFor(payId, m);
                            if (!mounted) return;
                            if (info != null) {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TransferScreen(info: info)));
                              return;
                            }
                          }
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => BookingSuccessScreen(tutor: t, isPackage: _package, awaitingPayment: app.lastAmountDue > 0)),
                          );
                        },
                  child: _processing
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                          const SizedBox(width: 10),
                          Text(context.tr('paying')),
                        ])
                      : Text(_current != 'step_pay'
                          ? context.tr('next')
                          : (dueNow <= 0 || !app.live ? (ar ? 'تأكيد الحجز' : 'Confirm booking') : (ar ? 'احجز وادفع بالتحويل' : 'Book & pay by transfer'))),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(s, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)));

  Widget _optionBox({required bool selected, required VoidCallback onTap, required String top, required String bottom}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: selected ? 1.6 : 1),
          ),
          child: Column(children: [
            Text(top, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(bottom, style: TextStyle(color: selected ? AppColors.primary : AppColors.text2, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _line(String k, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(k, style: TextStyle(color: bold ? AppColors.ink : AppColors.text2, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 17 : 14.5)),
          const Spacer(),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700, fontSize: bold ? 19 : 14.5, color: color)),
        ]),
      );
}

class BookingSuccessScreen extends StatelessWidget {
  final Tutor tutor;
  final bool isPackage;
  final bool awaitingPayment;
  const BookingSuccessScreen({super.key, required this.tutor, required this.isPackage, this.awaitingPayment = false});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: MaxWidth(
          max: 480,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(color: awaitingPayment ? AppColors.accentSoft : AppColors.successSoft, shape: BoxShape.circle),
                child: Icon(awaitingPayment ? Icons.hourglass_top_rounded : Icons.check_rounded, color: awaitingPayment ? AppColors.accent : AppColors.success, size: 64),
              ),
              const SizedBox(height: 22),
              Text(context.tr(awaitingPayment ? 'reserved_t' : 'success_t'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(context.tr(awaitingPayment ? 'reserved_b' : 'success_b'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text2, height: 1.6)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final c = app.conversationFor(tutor);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
                  },
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(context.tr('chat_tutor')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    app.goTab(3);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: Text(context.tr('go_lessons')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
