import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/account_screen.dart';
import '../shared/notifications_screen.dart';
import 'help_me_find_screen.dart';
import 'student_shell.dart';
import 'tutor_profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final shell = StudentShell.of(context);
    final wide = MediaQuery.of(context).size.width >= 900;
    final next = app.nextLesson;
    final top = [...MockData.tutors]..sort((a, b) => b.matchScore.compareTo(a.matchScore));

    return SafeArea(
      child: ListView(padding: EdgeInsets.zero, children: [
        MaxWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ---------- header ----------
              Row(children: [
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
                  borderRadius: BorderRadius.circular(16),
                  child: Avatar(name: L(app.name, app.name), color: AppColors.primary, size: 46),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${context.tr('hello')} ${app.name} 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(context.tr('home_q'), style: const TextStyle(color: AppColors.text2)),
                  ]),
                ),
                if (!wide) ...[
                  IconButton(onPressed: app.toggleLocale, icon: const Icon(Icons.language_rounded)),
                  IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                    icon: Badge(isLabelVisible: app.unreadNotifications > 0, label: Text('${app.unreadNotifications}'), child: const Icon(Icons.notifications_none_rounded)),
                  ),
                ],
              ]),
              const SizedBox(height: 18),

              // ---------- search ----------
              InkWell(
                onTap: () => shell?.go(1),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, color: AppColors.text3),
                    const SizedBox(width: 10),
                    Expanded(child: Text(context.tr('search_hint'), style: const TextStyle(color: AppColors.text3))),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                    ),
                  ]),
                ),
              ),

              // ---------- next lesson ----------
              if (next != null) ...[
                const SizedBox(height: 18),
                AppCard(
                  color: AppColors.ink,
                  borderColor: AppColors.ink,
                  child: Row(children: [
                    Avatar(name: next.tutor.name, color: next.tutor.color, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.tr('next_lesson'), style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5)),
                        Text(next.subject.of(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        Text('${dayOf(context, next.start)} · ${timeOf(context, next.start)} · ${next.minutes} ${context.tr('min')}',
                            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
                      ]),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.ink, minimumSize: const Size(0, 42)),
                      onPressed: () => shell?.go(3),
                      child: Text(context.tr('join')),
                    ),
                  ]),
                ),
              ],

              // ---------- live help banner ----------
              const SizedBox(height: 18),
              InkWell(
                onTap: () => shell?.go(2),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF13B39E)], begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(context.isAr ? '42 مدرساً متصلاً الآن' : '42 tutors online now', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 6),
                        Text(context.tr('live_banner_t'), style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(context.tr('live_banner_b'), style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13.5, height: 1.5)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                          child: Text(context.tr('live_banner_cta'), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 86,
                      height: 86,
                      decoration: const BoxDecoration(color: Color(0x26FFFFFF), shape: BoxShape.circle),
                      child: const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 44),
                    ),
                  ]),
                ),
              ),

              // ---------- subjects ----------
              SectionTitle(context.tr('explore_subjects'), action: context.tr('see_all'), onAction: () => shell?.go(1)),
              GridView.count(
                crossAxisCount: wide ? 8 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
                children: [
                  for (final s in MockData.subjects.take(wide ? 16 : 8)) SubjectTile(s, onTap: () => shell?.go(1, subject: s.id)),
                ],
              ),

              // ---------- popular ----------
              SectionTitle(context.tr('popular')),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in MockData.popular)
                  ActionChip(
                    label: Text(p.of(context)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () => shell?.go(1),
                  ),
              ]),

              // ---------- top tutors ----------
              SectionTitle(context.tr('top_tutors'), action: context.tr('see_all'), onAction: () => shell?.go(1)),
              SizedBox(
                height: 222,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final t = top[i];
                    return SizedBox(
                      width: 200,
                      child: AppCard(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TutorProfileScreen(tutor: t))),
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Avatar(name: t.name, color: t.color, size: 52, online: t.available), const Spacer(), RatingRow(t.rating, t.reviewCount)]),
                          const SizedBox(height: 10),
                          VerifiedName(t.name.of(context), size: 15),
                          const SizedBox(height: 2),
                          Text(t.headline.of(context), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text2, fontSize: 12.5, height: 1.4)),
                          const Spacer(),
                          Row(children: [
                            Text(money(t.pricePerHour), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                            Text(context.tr('per_hour'), style: const TextStyle(color: AppColors.text3, fontSize: 12)),
                            const Spacer(),
                            Text('${t.matchScore}%', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800)),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
              ),

              // ---------- guarantee + help ----------
              const SizedBox(height: 22),
              _maybeIntrinsic(wide, Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoCard(
                    icon: Icons.workspace_premium_rounded,
                    color: AppColors.accent,
                    bg: AppColors.accentSoft,
                    title: context.tr('guarantee_t'),
                    body: context.tr('guarantee_b'),
                    wide: wide,
                  ),
                  SizedBox(width: wide ? 14 : 0, height: wide ? 0 : 12),
                  _InfoCard(
                    icon: Icons.support_agent_rounded,
                    color: AppColors.info,
                    bg: AppColors.infoSoft,
                    title: context.tr('help_find_t'),
                    body: context.tr('help_find_b'),
                    wide: wide,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpMeFindScreen())),
                  ),
                ],
              )),
              const SizedBox(height: 12),
              AppCard(
                child: Row(children: [
                  Avatar(name: const L('مرام', 'Maram'), color: const Color(0xFF25D366), size: 48, online: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.tr('advisor_t'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(context.tr('advisor_b'), style: const TextStyle(color: AppColors.text2, fontSize: 13)),
                    ]),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: const Color(0xFF128C7E), side: const BorderSide(color: Color(0xFF25D366))),
                    onPressed: () => toast(context, 'wa.me/963000000000', icon: Icons.chat_rounded),
                    child: Text(context.tr('contact_now')),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

Widget _maybeIntrinsic(bool wide, Widget child) => wide ? IntrinsicHeight(child: child) : child;

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String body;
  final bool wide;
  final VoidCallback? onTap;
  const _InfoCard({required this.icon, required this.color, required this.bg, required this.title, required this.body, required this.wide, this.onTap});
  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      onTap: onTap,
      color: bg,
      borderColor: bg,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(color: AppColors.text2, fontSize: 13.5, height: 1.5)),
          ]),
        ),
        if (onTap != null) Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: color),
      ]),
    );
    return wide ? Expanded(child: card) : card;
  }
}
