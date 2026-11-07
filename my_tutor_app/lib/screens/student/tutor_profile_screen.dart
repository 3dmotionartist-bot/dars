import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/chat_screen.dart';
import 'booking_screen.dart';

class TutorProfileScreen extends StatefulWidget {
  final Tutor tutor;
  const TutorProfileScreen({super.key, required this.tutor});
  @override
  State<TutorProfileScreen> createState() => _TutorProfileScreenState();
}

class _TutorProfileScreenState extends State<TutorProfileScreen> {
  bool _more = false;
  late String _level = context.read<AppState>().levelId;

  @override
  Widget build(BuildContext context) {
    final t = widget.tutor;
    final app = context.watch<AppState>();
    final level = MockData.levels.firstWhere((l) => l.id == _level, orElse: () => MockData.levels[3]);
    final levelPrice = t.pricePerHour * level.priceFactor;
    final wide = MediaQuery.of(context).size.width >= 900;

    final header = AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: t.name, color: t.color, size: 84, online: t.available),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              VerifiedName(t.name.of(context), size: 20),
              const SizedBox(height: 4),
              Text(t.headline.of(context), style: const TextStyle(color: AppColors.text2, height: 1.4)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                AvailablePill(t.available),
                if (t.instantBooking) Pill(context.tr('instant_booking'), icon: Icons.flash_on_rounded, bg: AppColors.accentSoft, fg: const Color(0xFFB7791F)),
                if (t.isNew) Pill(context.tr('new_tutor'), bg: AppColors.infoSoft, fg: AppColors.info),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _stat(t.rating.toStringAsFixed(1), '${t.reviewCount} ${context.tr('reviews')}', Icons.star_rounded, AppColors.accent),
          _stat('${t.hoursTaught}', context.tr('hours_taught'), Icons.schedule_rounded, AppColors.info),
          _stat('${t.students}', context.tr('students'), Icons.groups_rounded, AppColors.primary),
          _stat('${t.matchScore}%', context.tr('match'), Icons.auto_awesome_rounded, AppColors.success),
        ]),
      ]),
    );

    final video = AppCard(
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: [t.color.withOpacity(0.85), AppColors.ink], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(Icons.play_arrow_rounded, size: 40, color: t.color),
            ),
            PositionedDirectional(
              bottom: 12,
              start: 14,
              child: Text(context.tr('intro_video'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );

    final about = _section(context.tr('about_tutor'), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.about.of(context), maxLines: _more ? null : 4, overflow: _more ? null : TextOverflow.ellipsis, style: const TextStyle(height: 1.7, color: AppColors.text2)),
      TextButton(onPressed: () => setState(() => _more = !_more), child: Text(context.tr(_more ? 'read_less' : 'read_more'))),
      const Divider(),
      _kv(Icons.public_rounded, context.tr('country'), t.country.of(context)),
      _kv(Icons.workspace_premium_outlined, context.tr('experience'), '${t.years} ${context.tr('years_exp')}'),
      _kv(Icons.translate_rounded, context.tr('speaks'), t.languages.map((e) => e.of(context)).join('، ')),
      _kv(Icons.laptop_mac_rounded, context.tr('teaching_mode'),
          [context.tr('online'), if (t.teachesInPerson) context.tr('in_person')].join(' · ')),
    ]));

    final subjects = _section(context.tr('subjects'), Wrap(spacing: 8, runSpacing: 8, children: [
      for (final id in t.subjectIds) Pill(MockData.subject(id).name.of(context), bg: AppColors.infoSoft, fg: AppColors.info, icon: MockData.subject(id).icon),
      for (final tag in t.tags) Pill(tag.of(context)),
    ]));

    final fees = _section(context.tr('fees_by_level'), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.tr('choose_level_price'), style: const TextStyle(color: AppColors.text2, fontSize: 13)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in MockData.levels.skip(1))
          ChoiceChip(
            label: Text(l.name.of(context)),
            selected: _level == l.id,
            showCheckmark: false,
            selectedColor: AppColors.primarySoft,
            side: BorderSide(color: _level == l.id ? AppColors.primary : AppColors.line),
            labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: _level == l.id ? AppColors.primary : AppColors.ink),
            onSelected: (_) => setState(() => _level = l.id),
          ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Text(money(levelPrice.round()), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        Text(' ${context.tr('per_hour')}', style: const TextStyle(color: AppColors.text3)),
        const Spacer(),
        Pill('25 ${context.tr('min')}: ${money((levelPrice / 2).round())}', bg: AppColors.surface, fg: AppColors.text2),
      ]),
      if (t.hasPackages) ...[
        const SizedBox(height: 14),
        Text(context.tr('packages'), style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(context.tr('packages_hint'), style: const TextStyle(color: AppColors.text2, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          for (final h in [4, 8, 12, 20])
            Expanded(
              child: Container(
                margin: const EdgeInsetsDirectional.only(end: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text('$h ${context.tr('hours')}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('-${app.discountFor(t, h)}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
              ),
            ),
        ]),
      ],
    ]));

    final availability = _section(context.tr('availability'), Column(children: [
      for (final d in ['day_sat', 'day_sun', 'day_mon', 'day_tue', 'day_wed'])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 80, child: Text(context.tr(d), style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(
              child: Wrap(spacing: 6, children: [
                for (final s in d == 'day_mon' ? ['10:00', '17:00'] : ['16:00', '18:00', '20:00']) Pill(s, bg: AppColors.surface, fg: AppColors.ink),
              ]),
            ),
          ]),
        ),
      const SizedBox(height: 4),
      Row(children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.text3),
        const SizedBox(width: 6),
        Expanded(child: Text(context.tr('tz_note'), style: const TextStyle(color: AppColors.text3, fontSize: 12.5))),
      ]),
    ]));

    final reviews = _section('${context.tr('reviews_title')} (${t.reviewCount})', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.tr('reviews_note'), style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
      const SizedBox(height: 8),
      if (t.reviews.isEmpty) Text(context.tr('no_reviews')),
      for (final r in t.reviews)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Avatar(name: r.author, color: AppColors.text3, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(r.author.of(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  for (int i = 0; i < 5; i++) Icon(Icons.star_rounded, size: 15, color: i < r.stars ? AppColors.accent : AppColors.line),
                ]),
                Text(r.text.of(context), style: const TextStyle(color: AppColors.text2, height: 1.5)),
                Text(r.date, style: const TextStyle(color: AppColors.text3, fontSize: 12)),
              ]),
            ),
          ]),
        ),
    ]));

    final policies = _section(context.tr('policies'), Column(children: [
      _kv(Icons.event_busy_rounded, context.tr('cancel_policy'), '${t.cancelHours} ${context.tr('hours')} ${context.tr('before_lesson')}'),
      _kv(Icons.workspace_premium_rounded, context.tr('guarantee_t'), context.tr('guarantee_b')),
    ]));

    final left = [header, const SizedBox(height: 12), about, subjects, availability, reviews];
    final right = [video, const SizedBox(height: 12), fees, policies];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        actions: [
          IconButton(
            onPressed: () => app.toggleFavorite(t.id),
            icon: Icon(app.favorites.contains(t.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: app.favorites.contains(t.id) ? AppColors.danger : null),
          ),
          IconButton(onPressed: () => toast(context, 'dars.app/t/${t.id}', icon: Icons.link_rounded), icon: const Icon(Icons.ios_share_rounded)),
        ],
      ),
      body: MaxWidth(
        max: 1180,
        child: wide
            ? SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
                ]),
              )
            : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [header, const SizedBox(height: 12), video, const SizedBox(height: 12), about, subjects, fees, availability, reviews, policies]),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
          child: MaxWidth(
            max: 1180,
            child: Row(children: [
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${money(levelPrice.round())}${context.tr('per_hour')}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  Text(level.name.of(context), style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
                ]),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(50, 50), padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: () {
                  final c = app.conversationFor(t);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chat_bubble_outline_rounded),
                  if (MediaQuery.of(context).size.width >= 480) ...[const SizedBox(width: 8), Text(context.tr('message_tutor'))],
                ]),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(tutor: t, hourPrice: levelPrice))),
                child: Text(context.tr('book_lesson')),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );

  Widget _kv(IconData icon, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.text3))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _stat(String v, String label, IconData icon, Color c) => Expanded(
        child: Column(children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text3, fontSize: 11.5)),
        ]),
      );
}
