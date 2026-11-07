import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../student/tutor_profile_screen.dart';
import '../tutor/tutor_settings_screen.dart';
import 'notifications_screen.dart';
import 'wallet_screen.dart';

class AccountScreen extends StatelessWidget {
  final bool embedded;
  const AccountScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isTutor = app.role == UserRole.tutor;
    final level = MockData.levels.firstWhere((l) => l.id == app.levelId, orElse: () => MockData.levels[3]);

    final content = MaxWidth(
      max: 720,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Row(children: [
            Avatar(name: L(app.name, app.name), color: AppColors.primary, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isTutor ? app.me.name.of(context) : (app.name.isEmpty ? '—' : app.name), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                Text(app.phone.isEmpty ? '+963 9xx xxx xxx' : app.phone, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.text2)),
                const SizedBox(height: 4),
                Pill(isTutor ? context.tr('role_tutor') : '${context.tr(app.role == UserRole.parent ? 'role_parent' : 'role_student')} · ${level.name.of(context)}',
                    bg: AppColors.primarySoft, fg: AppColors.primary),
              ]),
            ),
            IconButton(onPressed: () => toast(context, context.tr('edit_profile')), icon: const Icon(Icons.edit_outlined)),
          ]),
        ),
        const SizedBox(height: 12),
        if (!isTutor)
          AppCard(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
            color: AppColors.ink,
            borderColor: AppColors.ink,
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_rounded, color: AppColors.accent, size: 30),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr('wallet_balance'), style: const TextStyle(color: Color(0xCCFFFFFF)))),
              Text(money(app.walletBalance), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
        const SizedBox(height: 12),
        _group([
          if (isTutor) ...[
            MenuRow(icon: Icons.badge_outlined, title: context.tr('public_profile'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TutorProfileScreen(tutor: app.me)))),
            MenuRow(icon: Icons.schedule_rounded, title: context.tr('my_availability'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorSettingsScreen()))),
            MenuRow(icon: Icons.card_giftcard_rounded, title: context.tr('my_packages'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorSettingsScreen(initialTab: 1)))),
          ] else ...[
            MenuRow(icon: Icons.receipt_long_rounded, title: context.tr('wallet'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
            MenuRow(
              icon: Icons.favorite_border_rounded,
              title: context.tr('favorites'),
              trailing: '${app.favorites.length}',
              onTap: () => _favorites(context, app),
            ),
          ],
          MenuRow(
            icon: Icons.notifications_none_rounded,
            title: context.tr('notifications'),
            badge: app.unreadNotifications,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          MenuRow(icon: Icons.phone_in_talk_outlined, title: context.tr('call_settings'), trailing: context.tr('call_${app.callPermission}'), onTap: () => _callSettings(context, app)),
          MenuRow(icon: Icons.language_rounded, title: context.tr('language'), trailing: context.isAr ? 'العربية' : 'English', onTap: app.toggleLocale),
        ]),
        const SizedBox(height: 12),
        AppCard(
          color: AppColors.accentSoft,
          borderColor: AppColors.accentSoft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.redeem_rounded, color: AppColors.accent, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(context.tr('referral'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            ]),
            const SizedBox(height: 4),
            Text(context.tr('referral_b'), style: const TextStyle(color: AppColors.text2)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Expanded(child: Text('dars.app/r/MOH2026', textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.w700))),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'https://dars.app/r/MOH2026'));
                    toast(context, context.tr('copied'));
                  },
                  child: Text(context.tr('copy_link')),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _group([
          if (!app.live)
            MenuRow(icon: Icons.swap_horiz_rounded, title: context.tr(isTutor ? 'switch_student' : 'switch_tutor'), onTap: () {
              app.switchRole();
              if (Navigator.canPop(context)) Navigator.popUntil(context, (r) => r.isFirst);
            }),
          MenuRow(icon: Icons.support_agent_rounded, title: context.tr('support'), onTap: () => toast(context, 'wa.me/963000000000', icon: Icons.chat_rounded)),
          MenuRow(icon: Icons.policy_outlined, title: context.tr('terms'), onTap: () => toast(context, 'dars.app/terms', icon: Icons.link_rounded)),
          MenuRow(icon: Icons.logout_rounded, title: context.tr('logout'), color: AppColors.danger, onTap: () {
            if (Navigator.canPop(context)) Navigator.popUntil(context, (r) => r.isFirst);
            app.logout();
          }),
        ]),
        const SizedBox(height: 16),
        Center(child: Text('${context.tr('app_name')} · ${context.tr('version')} 1.0.0', style: const TextStyle(color: AppColors.text3, fontSize: 12.5))),
        TextButton(onPressed: () => toast(context, context.tr('delete_account'), icon: Icons.info_outline), child: Text(context.tr('delete_account'), style: const TextStyle(color: AppColors.text3))),
      ]),
    );

    if (embedded) return SafeArea(child: content);
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.surface, surfaceTintColor: AppColors.surface, title: Text(context.tr('account_title'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: content,
    );
  }

  Widget _group(List<Widget> rows) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
        child: Column(children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) const Divider(height: 1, indent: 68),
          ],
        ]),
      );

  void _callSettings(BuildContext context, AppState app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Text(context.tr('call_settings'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          for (final v in ['all', 'mine', 'ask'])
            RadioListTile<String>(
              value: v,
              groupValue: app.callPermission,
              activeColor: AppColors.primary,
              title: Text(context.tr('call_$v')),
              onChanged: (x) {
                app.setCallPermission(x!);
                Navigator.pop(sheet);
              },
            ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  void _favorites(BuildContext context, AppState app) {
    final favs = app.tutors.where((t) => app.favorites.contains(t.id)).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('favorites'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (favs.isEmpty) Text(context.tr('no_tutors')),
            for (final t in favs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(name: t.name, color: t.color, size: 44),
                title: Text(t.name.of(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(t.headline.of(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TutorProfileScreen(tutor: t)));
                },
              ),
          ]),
        ),
      ),
    );
  }
}
