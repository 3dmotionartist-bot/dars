import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/ringer.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// "Receive calls" (26 Nov 2026): the phone settings that let a call ring while the phone sleeps, one row each,
/// with a button that opens the right page of the phone's settings and a tick once it is on. Re-checked every
/// time the person comes back from the settings. Tutors finish it before they can switch "available now" on.
class CallSetupScreen extends StatefulWidget {
  const CallSetupScreen({super.key, this.thenAvailable = false});

  /// Opened from "available now": switch it on when everything is done.
  final bool thenAvailable;

  @override
  State<CallSetupScreen> createState() => _CallSetupScreenState();
}

class _CallSetupScreenState extends State<CallSetupScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().checkCallSetup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) context.read<AppState>().checkCallSetup();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.callSetup;
    final ar = context.isAr;
    final tutor = app.role == UserRole.tutor;
    final xiaomi = s.brand == 'xiaomi';

    Widget row(String step, bool ok, IconData icon, String title, String how) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            key: Key('setup-$step'),
            borderColor: ok ? AppColors.success : AppColors.line,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(ok ? Icons.check_circle_rounded : icon, color: ok ? AppColors.success : AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(ok ? (ar ? 'مفعّل' : 'On') : how, style: const TextStyle(color: AppColors.text2, height: 1.4)),
                  if (!ok) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      FilledButton(
                        key: Key('setup-open-$step'),
                        onPressed: () => Ringer.openSetup(step),
                        child: Text(ar ? 'تفعيل' : 'Turn on'),
                      ),
                      if (step == 'autostart' && s.autostart == 'unknown')
                        TextButton(
                          key: const Key('setup-autostart-done'),
                          onPressed: app.confirmAutostart,
                          child: Text(ar ? 'فعّلته' : 'I turned it on'),
                        ),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'استقبال المكالمات' : 'Receive calls')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(
            tutor
                ? (ar
                    ? 'حتى يرن هاتفك عند اتصال طالب وهو مقفل أو في وضع السكون، فعّل هذه الإعدادات. لا يمكن أن تظهر "متاحاً الآن" قبل إكمالها.'
                    : 'So your phone rings when a student calls, even while it is locked or asleep, turn these on. You can\'t show as "available now" until they are done.')
                : (ar
                    ? 'حتى يرن هاتفك عند الاتصال بك وهو مقفل أو في وضع السكون، فعّل هذه الإعدادات.'
                    : 'So your phone rings for calls even while it is locked or asleep, turn these on.'),
            style: const TextStyle(color: AppColors.text2, height: 1.5),
          ),
          const SizedBox(height: 16),
          row('notifications', s.notifications, Icons.notifications_active_rounded, ar ? 'الإشعارات' : 'Notifications',
              ar ? 'اسمح لدرس بالإشعارات، وأبقِ "المكالمات" مفعّلة.' : 'Allow notifications for Dars, with "Calls" on.'),
          row(
            'fullScreen',
            s.fullScreen,
            Icons.ring_volume_rounded,
            ar ? 'المكالمة على شاشة القفل' : 'Calls on the lock screen',
            xiaomi
                ? (ar
                    ? 'في "أذونات أخرى" اسمح بـ "العرض على شاشة القفل" و"عرض النوافذ المنبثقة أثناء التشغيل في الخلفية".'
                    : 'In "Other permissions", allow "Show on lock screen" and "Display pop-up windows while running in the background".')
                : (ar ? 'فعّل "الإشعارات بملء الشاشة" لدرس.' : 'Turn on "full-screen notifications" for Dars.'),
          ),
          row(
            'battery',
            s.battery,
            Icons.battery_charging_full_rounded,
            ar ? 'البطارية: بلا قيود' : 'Battery: no restrictions',
            xiaomi
                ? (ar ? 'اختر "السماح" ثم في "توفير البطارية" لدرس اختر "بلا قيود".' : 'Tap "Allow", then set Dars\' "Battery saver" to "No restrictions".')
                : (ar ? 'اسمح لدرس بالعمل دون تقييد البطارية.' : 'Let Dars run without battery restrictions.'),
          ),
          if (s.showAutostart)
            row('autostart', s.autostartOk, Icons.power_settings_new_rounded, ar ? 'التشغيل التلقائي' : 'Autostart',
                ar ? 'فعّل "التشغيل التلقائي" لدرس، ليصل الاتصال حتى لو أغلقت التطبيق.' : 'Turn on "Autostart" for Dars, so calls reach you even after you close the app.'),
          const SizedBox(height: 8),
          if (s.done)
            FilledButton.icon(
              key: const Key('setup-finish'),
              onPressed: () {
                if (widget.thenAvailable) app.setAvailable(true);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check_rounded),
              label: Text(widget.thenAvailable ? (ar ? 'تم — أنا متاح الآن' : 'Done — I\'m available now') : (ar ? 'تم' : 'Done')),
            )
          else if (!tutor)
            TextButton(onPressed: () => Navigator.pop(context), child: Text(ar ? 'لاحقاً' : 'Later')),
        ]),
      ),
    );
  }
}
