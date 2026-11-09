import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Tutor: working hours for every day of the week (one or more periods per day).
/// Students can only book lessons inside these hours.
class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});
  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  // Saturday first, as the week starts in Syria.
  static const _order = [6, 0, 1, 2, 3, 4, 5];
  static const _dayKeys = ['day_sun', 'day_mon', 'day_tue', 'day_wed', 'day_thu', 'day_fri', 'day_sat'];

  late final Map<int, List<(int, int)>> _days = {
    for (final d in _order) d: [
      for (final p in context.read<AppState>().workHours.where((p) => p.weekday == d)) (p.start, p.end),
    ],
  };
  (int, int) _lastPeriod = (16 * 60, 22 * 60);
  bool _saving = false;

  String _label(int minutes) => minutes >= 1440 ? (context.isAr ? '12:00 منتصف الليل' : '12:00 midnight') : timeOf(context, DateTime(2026, 1, 1).add(Duration(minutes: minutes)));

  Future<int?> _pick(int minutes) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (t == null) return null;
    return t.hour * 60 + t.minute;
  }

  Future<void> _edit(int day, int i, {required bool start}) async {
    final (s, e) = _days[day]![i];
    final v = await _pick(start ? s : (e >= 1440 ? 0 : e));
    if (v == null || !mounted) return;
    setState(() {
      final end = start ? e : (v == 0 ? 1440 : v); // "12:00 AM" as an end time means midnight
      _days[day]![i] = start ? (v, end) : (s, end);
      _lastPeriod = _days[day]![i];
    });
  }

  void _toggle(int day, bool on) => setState(() {
        if (on) {
          _days[day] = [_lastPeriod];
        } else {
          _days[day] = [];
        }
      });

  void _add(int day) => setState(() {
        final list = _days[day]!;
        final after = list.isEmpty ? 9 * 60 : list.map((p) => p.$2).reduce((a, b) => a > b ? a : b);
        final start = after >= 23 * 60 ? 9 * 60 : after + 60;
        final end = start + 120 > 1440 ? 1440 : start + 120;
        list.add((start, end));
      });

  void _copyToAll(int day) => setState(() {
        final src = [..._days[day]!];
        for (final d in _order) {
          if (d != day && _days[d]!.isNotEmpty) _days[d] = [...src];
        }
      });

  String? _problem() {
    if (_days.values.every((l) => l.isEmpty)) {
      return context.isAr ? 'فعّل يوماً واحداً على الأقل حتى يتمكن الطلاب من الحجز.' : 'Turn on at least one day so students can book.';
    }
    for (final d in _order) {
      final l = [..._days[d]!]..sort((a, b) => a.$1 - b.$1);
      for (var i = 0; i < l.length; i++) {
        if (l[i].$2 <= l[i].$1) {
          return context.isAr ? '${context.tr(_dayKeys[d])}: وقت النهاية يجب أن يكون بعد البداية.' : '${context.tr(_dayKeys[d])}: the end must be after the start.';
        }
        if (i > 0 && l[i].$1 < l[i - 1].$2) {
          return context.isAr ? '${context.tr(_dayKeys[d])}: الفترات متداخلة.' : '${context.tr(_dayKeys[d])}: the periods overlap.';
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    final p = _problem();
    if (p != null) {
      toast(context, p, icon: Icons.info_outline);
      return;
    }
    setState(() => _saving = true);
    final ok = await context.read<AppState>().saveWorkHours([
      for (final d in _order)
        for (final (s, e) in _days[d]!) WorkPeriod(d, s, e),
    ]);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  Widget _timeButton(String text, VoidCallback onTap) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: AppColors.line),
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
      );

  @override
  Widget build(BuildContext context) {
    final off = DateTime.now().timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final tz = 'UTC$sign${off.inHours.abs()}${off.inMinutes.abs() % 60 == 0 ? '' : ':${two(off.inMinutes.abs() % 60)}'}';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(context.tr('working_hours'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: MaxWidth(
        max: 720,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
          AppCard(
            color: AppColors.primarySoft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.schedule_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.isAr
                      ? 'حدّد ساعات عملك لكل يوم. الطلاب يرون فقط الأوقات المتاحة داخل هذه الساعات ولا يمكنهم الحجز خارجها. الأوقات حسب توقيتك ($tz) ويراها كل طالب بتوقيته.'
                      : 'Set your hours for each day. Students only see free times inside these hours and cannot book outside them. Times are in your time zone ($tz); each student sees them in their own.',
                  style: const TextStyle(color: AppColors.ink, height: 1.5),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          for (final d in _order) ...[
            AppCard(
              key: Key('day-$d'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(context.tr(_dayKeys[d]), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  if (_days[d]!.isEmpty)
                    Text(context.isAr ? 'عطلة' : 'Day off', style: const TextStyle(color: AppColors.text3, fontWeight: FontWeight.w700)),
                  Switch(value: _days[d]!.isNotEmpty, activeColor: AppColors.primary, onChanged: (v) => _toggle(d, v)),
                ]),
                for (var i = 0; i < _days[d]!.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      _timeButton(_label(_days[d]![i].$1), () => _edit(d, i, start: true)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–', style: TextStyle(fontWeight: FontWeight.w800))),
                      Flexible(child: _timeButton(_label(_days[d]![i].$2), () => _edit(d, i, start: false))),
                      const Spacer(),
                      IconButton(
                        tooltip: context.tr('remove'),
                        onPressed: () => setState(() => _days[d]!.removeAt(i)),
                        icon: const Icon(Icons.close_rounded, color: AppColors.text3),
                      ),
                    ]),
                  ),
                if (_days[d]!.isNotEmpty)
                  Wrap(spacing: 4, children: [
                    TextButton.icon(
                      onPressed: () => _add(d),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(context.isAr ? 'إضافة فترة' : 'Add a period'),
                    ),
                    TextButton.icon(
                      onPressed: () => _copyToAll(d),
                      icon: const Icon(Icons.copy_all_rounded, size: 18),
                      label: Text(context.isAr ? 'نسخ لكل أيام العمل' : 'Copy to all working days'),
                    ),
                  ]),
              ]),
            ),
            const SizedBox(height: 10),
          ],
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            key: const Key('save-hours'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(context.tr('save')),
          ),
        ),
      ),
    );
  }
}
