import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../screens/shared/account_screen.dart';
import '../screens/shared/notifications_screen.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

class ShellDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  final bool highlight;
  ShellDestination(this.icon, this.activeIcon, this.label, {this.badge = 0, this.highlight = false});
}

/// Phone: bottom NavigationBar. Tablet/Web (≥ 900 px): side NavigationRail + top bar.
/// This one widget is what turns the mobile app into the web app.
class AdaptiveShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<Widget> pages;
  final List<ShellDestination> destinations;
  const AdaptiveShell({super.key, required this.index, required this.onSelect, required this.pages, required this.destinations});

  Widget _icon(ShellDestination d, bool active) {
    Widget i = Icon(active ? d.activeIcon : d.icon, color: d.highlight && !active ? AppColors.accent : null);
    if (d.badge > 0) i = Badge(label: Text('${d.badge}'), child: i);
    return i;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final body = IndexedStack(index: index, children: pages);

    if (!wide) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onSelect,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          indicatorColor: AppColors.primarySoft,
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (int i = 0; i < destinations.length; i++)
              NavigationDestination(icon: _icon(destinations[i], false), selectedIcon: _icon(destinations[i], true), label: destinations[i].label),
          ],
        ),
      );
    }

    final app = context.watch<AppState>();
    return Scaffold(
      body: Row(children: [
        Container(
          decoration: const BoxDecoration(color: Colors.white, border: BorderDirectional(end: BorderSide(color: AppColors.line))),
          child: NavigationRail(
            extended: MediaQuery.of(context).size.width >= 1200,
            minExtendedWidth: 220,
            backgroundColor: Colors.white,
            selectedIndex: index,
            onDestinationSelected: onSelect,
            indicatorColor: AppColors.primarySoft,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const DarsLogo(size: 40),
                if (MediaQuery.of(context).size.width >= 1200) ...[
                  const SizedBox(width: 10),
                  Text(context.tr('app_name'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(icon: _icon(d, false), selectedIcon: _icon(d, true), label: Text(d.label, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        Expanded(
          child: Column(children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.line))),
              child: Row(children: [
                Text(destinations[index].label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton.icon(onPressed: app.toggleLocale, icon: const Icon(Icons.language_rounded), label: Text(context.tr('switch_lang'))),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                  icon: Badge(isLabelVisible: app.unreadNotifications > 0, label: Text('${app.unreadNotifications}'), child: const Icon(Icons.notifications_none_rounded)),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
                  borderRadius: BorderRadius.circular(20),
                  child: Avatar(name: L(app.name, app.name), color: AppColors.primary, size: 38),
                ),
              ]),
            ),
            Expanded(child: body),
          ]),
        ),
      ]),
    );
  }
}
