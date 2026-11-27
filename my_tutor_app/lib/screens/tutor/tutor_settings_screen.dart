import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'working_hours_screen.dart';

/// Tutor settings: working days & booking method & real-time mode | packages & discounts.
class TutorSettingsScreen extends StatelessWidget {
  final int initialTab;
  const TutorSettingsScreen({super.key, this.initialTab = 0});

  static String _t(BuildContext context, int minutes) =>
      minutes >= 1440 ? (context.isAr ? '12 ليلاً' : '12 AM') : timeOf(context, DateTime(2026, 1, 1).add(Duration(minutes: minutes)));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: AppColors.surface,
          title: Text(context.tr('my_availability'), style: const TextStyle(fontWeight: FontWeight.w800)),
          bottom: TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
            tabs: [Tab(text: context.tr('availability')), Tab(text: context.tr('packages'))],
          ),
        ),
        body: TabBarView(children: [
          MaxWidth(
            max: 720,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              SectionTitle(context.tr('my_availability')),
              AppCard(
                key: const Key('hours-card'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkingHoursScreen())),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final d in const [6, 0, 1, 2, 3, 4, 5])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        SizedBox(width: 90, child: Text(context.tr(const ['day_sun', 'day_mon', 'day_tue', 'day_wed', 'day_thu', 'day_fri', 'day_sat'][d]), style: const TextStyle(fontWeight: FontWeight.w700))),
                        Expanded(
                          child: Text(
                            app.workHours.where((p) => p.weekday == d).isEmpty
                                ? (context.isAr ? 'عطلة' : 'Day off')
                                : app.workHours.where((p) => p.weekday == d).map((p) => '${_t(context, p.start)} – ${_t(context, p.end)}').join('  ·  '),
                            style: TextStyle(color: app.workHours.any((p) => p.weekday == d) ? AppColors.ink : AppColors.text3),
                          ),
                        ),
                      ]),
                    ),
                  const Divider(height: 18),
                  Row(children: [
                    const Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.tr('edit_working_hours'), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
                  ]),
                ]),
              ),
              SectionTitle(context.tr('booking_mode')),
              ChoiceTile(title: context.tr('booking_instant'), icon: Icons.flash_on_rounded, color: AppColors.accent, selected: app.instantBooking, onTap: () => app.updateTutorSettings(instant: true)),
              const SizedBox(height: 8),
              ChoiceTile(title: context.tr('booking_request'), icon: Icons.mark_email_unread_outlined, selected: !app.instantBooking, onTap: () => app.updateTutorSettings(instant: false)),
              SectionTitle(context.tr('rt_settings')),
              ChoiceTile(title: context.tr('rt_any'), icon: Icons.all_inclusive_rounded, selected: app.realtimeMode == 'any', onTap: () => app.updateTutorSettings(rtMode: 'any')),
              const SizedBox(height: 8),
              ChoiceTile(title: context.tr('rt_working'), icon: Icons.work_history_outlined, selected: app.realtimeMode == 'working', onTap: () => app.updateTutorSettings(rtMode: 'working')),
            ]),
          ),
          MaxWidth(
            max: 720,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              AppCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  title: Text(context.tr('packages_enabled'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(context.tr('packages_hint')),
                  value: app.packagesEnabled,
                  onChanged: (v) => app.updateTutorSettings(packages: v),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: app.packagesEnabled ? 1 : 0.4,
                child: Column(children: [
                  for (final h in app.packageDiscounts.keys)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('${context.tr('discount_for')} $h ${context.tr('hours')}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text('${app.packageDiscounts[h]}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
                          ]),
                          Slider(
                            value: app.packageDiscounts[h]!.toDouble(),
                            min: 0,
                            max: 50,
                            divisions: 50,
                            activeColor: AppColors.primary,
                            onChanged: app.packagesEnabled ? (v) => app.setPackageDiscount(h, v.round(), save: false) : null,
                            onChangeEnd: app.packagesEnabled ? (v) => app.setPackageDiscount(h, v.round()) : null,
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
              Text(context.isAr ? 'من 0% (بلا خصم) حتى 50%' : 'From 0% (no discount) to 50%', style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
              if (app.live) ...[const SizedBox(height: 16), const _TrialPriceCard()],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Round H4: the tutor's 20-minute trial lesson (once per student, before the first lesson). The price is typed
/// in pounds when pounds are shown and kept in dollars, like the rest of the money.
class _TrialPriceCard extends StatefulWidget {
  const _TrialPriceCard();
  @override
  State<_TrialPriceCard> createState() => _TrialPriceCardState();
}

class _TrialPriceCardState extends State<_TrialPriceCard> {
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().myTrialPrice;
    _price = TextEditingController(text: p == null ? '' : '${fromUsd(p).round()}');
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ar = context.isAr;
    final on = app.myTrialPrice != null;
    return AppCard(
      key: const Key('trial-settings'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ar ? 'درس تجريبي (20 دقيقة)' : 'Trial lesson (20 minutes)', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          ar ? 'يحجزه الطالب مرة واحدة كأول درس معك، بسعر أقل تحدده أنت.' : 'A student books it once, as the first lesson with you, at a lower price you choose.',
          style: const TextStyle(color: AppColors.text2),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: ar ? 'السعر' : 'Price',
                suffixText: Money.syp ? (ar ? 'ل.س' : 'SYP') : null,
                prefixText: Money.syp ? null : '\$ ',
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            key: const Key('trial-save'),
            onPressed: () {
              final v = double.tryParse(_price.text.trim().replaceAll(',', '.'));
              if (v == null || v <= 0) return;
              app.setTrialPrice(double.parse(toUsd(v).toStringAsFixed(2)));
            },
            child: Text(ar ? 'حفظ' : 'Save'),
          ),
        ]),
        if (on)
          TextButton(
            key: const Key('trial-off'),
            onPressed: () {
              _price.clear();
              app.setTrialPrice(null);
            },
            child: Text(ar ? 'إيقاف الدرس التجريبي' : 'Turn the trial off'),
          ),
      ]),
    );
  }
}
