import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/mock_data.dart';
import '../l10n.dart';
import '../theme.dart';

String money(num v) => '\$${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(2)}';

String two(int n) => n.toString().padLeft(2, '0');

String timeOf(BuildContext c, DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? (c.isAr ? 'ص' : 'AM') : (c.isAr ? 'م' : 'PM');
  return '$h:${two(d.minute)} $ampm';
}

String dayOf(BuildContext c, DateTime d) {
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(d.year, d.month, d.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return c.tr('today');
  if (diff == 1) return c.tr('tomorrow');
  const keys = ['day_mon', 'day_tue', 'day_wed', 'day_thu', 'day_fri', 'day_sat', 'day_sun'];
  return '${c.tr(keys[d.weekday - 1])} ${d.day}/${d.month}';
}

String ago(BuildContext c, DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return c.isAr ? 'الآن' : 'now';
  if (m < 60) return c.isAr ? 'منذ $m د' : '${m}m';
  final h = m ~/ 60;
  if (h < 24) return c.isAr ? 'منذ $h س' : '${h}h';
  return c.isAr ? 'منذ ${h ~/ 24} يوم' : '${h ~/ 24}d';
}

void toast(BuildContext context, String text, {IconData icon = Icons.check_circle_rounded}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontFamily: 'Cairo'))),
      ]),
    ));
}

/// Centers content and caps its width — makes every screen look right on web/desktop.
class MaxWidth extends StatelessWidget {
  final Widget child;
  final double max;
  const MaxWidth({super.key, required this.child, this.max = 1100});
  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.topCenter, heightFactor: 1, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: child));
}

class DarsLogo extends StatelessWidget {
  final double size;
  final bool light;
  const DarsLogo({super.key, this.size = 44, this.light = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: light ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Text('د', style: TextStyle(fontSize: size * 0.58, fontWeight: FontWeight.w800, color: light ? AppColors.primary : Colors.white, height: 1.1)),
        PositionedDirectional(
          top: size * 0.16,
          end: size * 0.16,
          child: Container(width: size * 0.16, height: size * 0.16, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
        ),
      ]),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color = Colors.white, this.borderColor});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor ?? AppColors.line),
          ),
          child: child,
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final bool dot;
  const Pill(this.text, {super.key, this.bg = AppColors.lavender, this.fg = AppColors.lavenderInk, this.icon, this.dot = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)), const SizedBox(width: 6)],
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class AvailablePill extends StatelessWidget {
  final bool available;
  const AvailablePill(this.available, {super.key});
  @override
  Widget build(BuildContext context) => available
      ? Pill(context.tr('available'), bg: AppColors.successSoft, fg: AppColors.success, dot: true)
      : Pill(context.tr('busy'), bg: AppColors.surface, fg: AppColors.text3, dot: true);
}

class Avatar extends StatelessWidget {
  final L name;
  final Color color;
  final double size;
  final bool online;
  final bool verified;
  const Avatar({super.key, required this.name, required this.color, this.size = 56, this.online = false, this.verified = false});
  @override
  Widget build(BuildContext context) {
    final n = name.of(context).replaceAll(RegExp(r'^(م\.|أ\.|د\.|الشيخ|Dr\.)\s*'), '');
    final initial = n.isEmpty ? '?' : n.substring(0, 1);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.32),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.85), color]),
          ),
          alignment: Alignment.center,
          child: Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.42, height: 1.2)),
        ),
        if (online)
          PositionedDirectional(
            bottom: -1,
            end: -1,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            ),
          ),
      ]),
    );
  }
}

class VerifiedName extends StatelessWidget {
  final String text;
  final double size;
  const VerifiedName(this.text, {super.key, this.size = 16});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800))),
        const SizedBox(width: 4),
        Icon(Icons.verified_rounded, color: AppColors.info, size: size + 2),
      ]);
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

class RatingRow extends StatelessWidget {
  final double rating;
  final int count;
  const RatingRow(this.rating, this.count, {super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 4),
        Text('($count)', style: const TextStyle(color: AppColors.text3, fontSize: 13)),
      ]);
}

class SubjectTile extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTap;
  const SubjectTile(this.subject, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: subject.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(subject.icon, color: subject.color, size: 30),
        ),
        const SizedBox(height: 6),
        Text(subject.name.of(context), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text2)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

/// Tutor result card (list & grid). Mirrors Modarby's card: photo, verified name, availability,
/// headline, subject tags, rating, AI match, price and package discount.
class TutorCard extends StatelessWidget {
  final Tutor tutor;
  final VoidCallback onTap;
  final bool favorite;
  final VoidCallback? onFavorite;
  const TutorCard({super.key, required this.tutor, required this.onTap, this.favorite = false, this.onFavorite});

  @override
  Widget build(BuildContext context) {
    final t = tutor;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: t.name, color: t.color, size: 64, online: t.available),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: VerifiedName(t.name.of(context))),
                if (onFavorite != null)
                  InkWell(
                    onTap: onFavorite,
                    child: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: favorite ? AppColors.danger : AppColors.text3, size: 22),
                  ),
              ]),
              const SizedBox(height: 2),
              Text(t.headline.of(context), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text2, fontSize: 13.5, height: 1.4)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                RatingRow(t.rating, t.reviewCount),
                AvailablePill(t.available),
                if (t.isNew) Pill(context.tr('new_tutor'), bg: AppColors.accentSoft, fg: const Color(0xFFB7791F)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 28,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final id in t.subjectIds)
              Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: Pill(MockData.subject(id).name.of(context), bg: AppColors.infoSoft, fg: AppColors.info)),
            for (final tag in t.tags.take(3)) Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: Pill(tag.of(context))),
          ]),
        ),
        const Divider(height: 22),
        Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: t.matchScore >= 85 ? AppColors.success : AppColors.text3),
          const SizedBox(width: 4),
          Text('${t.matchScore}% ${context.tr('match')}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.matchScore >= 85 ? AppColors.success : AppColors.text2)),
          if (t.instantBooking) ...[
            const SizedBox(width: 10),
            const Icon(Icons.flash_on_rounded, size: 16, color: AppColors.accent),
            Text(context.tr('instant_booking'), style: const TextStyle(fontSize: 12.5, color: AppColors.text2)),
          ],
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '${context.tr('from')} ', style: const TextStyle(fontSize: 12, color: AppColors.text3)),
              TextSpan(text: money(t.pricePerHour), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
              TextSpan(text: context.tr('per_hour'), style: const TextStyle(fontSize: 12, color: AppColors.text3)),
            ])),
            if (t.hasPackages)
              Text('${context.tr('pkg_off')} ${t.maxDiscount}% ${context.tr('off')}', style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ]),
    );
  }
}

/// Selectable option card used by wizards.
class ChoiceTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const ChoiceTile({super.key, required this.title, this.subtitle, this.icon, this.color = AppColors.primary, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: selected ? AppColors.primarySoft : Colors.white,
      borderColor: selected ? AppColors.primary : AppColors.line,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.text2, fontSize: 13)),
          ]),
        ),
        Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? AppColors.primary : AppColors.line),
      ]),
    );
  }
}

class StepDots extends StatelessWidget {
  final int count;
  final int index;
  const StepDots({super.key, required this.count, required this.index});
  @override
  Widget build(BuildContext context) => Row(children: [
        for (int i = 0; i < count; i++)
          Expanded(
            child: Container(
              height: 5,
              margin: const EdgeInsetsDirectional.only(end: 6),
              decoration: BoxDecoration(color: i <= index ? AppColors.primary : AppColors.line, borderRadius: BorderRadius.circular(4)),
            ),
          ),
      ]);
}

class MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final Color color;
  final VoidCallback onTap;
  final int badge;
  const MenuRow({super.key, required this.icon, required this.title, required this.onTap, this.trailing, this.color = AppColors.ink, this.badge = 0});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color == AppColors.ink ? AppColors.primary : color, size: 21),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (badge > 0) Badge(label: Text('$badge')),
        if (trailing != null) Text(trailing!, style: const TextStyle(color: AppColors.text3)),
        const SizedBox(width: 4),
        Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: AppColors.text3),
      ]),
    );
  }
}
