import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Tutor settings: working days & booking method & real-time mode | packages & discounts.
class TutorSettingsScreen extends StatelessWidget {
  final int initialTab;
  const TutorSettingsScreen({super.key, this.initialTab = 0});

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
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  for (final d in app.workingDays.keys)
                    SwitchListTile(
                      activeColor: AppColors.primary,
                      title: Text(context.tr(d), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(app.workingDays[d]! ? '16:00 – 22:00' : '—', textDirection: TextDirection.ltr, textAlign: context.isAr ? TextAlign.right : TextAlign.left),
                      value: app.workingDays[d]!,
                      onChanged: (_) => app.toggleWorkingDay(d),
                    ),
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
                            min: 1,
                            max: 50,
                            divisions: 49,
                            activeColor: AppColors.primary,
                            onChanged: app.packagesEnabled ? (v) => app.setPackageDiscount(h, v.round()) : null,
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
              Text(context.isAr ? 'أقل خصم 1% وأعلى خصم 50%' : 'Minimum discount 1%, maximum 50%', style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}
