import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(context.tr('notifications'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [if (app.unreadNotifications > 0) TextButton(onPressed: app.markAllNotificationsRead, child: Text(context.tr('mark_read')))],
      ),
      body: app.notifications.isEmpty
          ? EmptyState(icon: Icons.notifications_off_outlined, title: context.tr('no_notifications'), body: '')
          : MaxWidth(
              max: 720,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: app.notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final n = app.notifications[i];
                  return AppCard(
                    onTap: () => app.openNotification(n),
                    color: n.read ? Colors.white : AppColors.primarySoft,
                    borderColor: n.read ? AppColors.line : AppColors.primarySoft,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: n.color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
                        child: Icon(n.icon, color: n.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title.of(context), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(n.body.of(context), style: const TextStyle(color: AppColors.text2)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(ago(context, n.time), style: const TextStyle(color: AppColors.text3, fontSize: 12)),
                        const SizedBox(height: 6),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
                      ]),
                    ]),
                  );
                },
              ),
            ),
    );
  }
}
