import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'help_me_find_screen.dart';
import 'tutor_profile_screen.dart';

class TutorFilters {
  String gender = 'all'; // all | m | f
  RangeValues price = const RangeValues(5, 40);
  bool availableNow = false;
  bool instantOnly = false;
  bool hasPackages = false;
  String mode = 'all'; // all | online | in_person

  int get activeCount =>
      (gender != 'all' ? 1 : 0) +
      (price.start > 5 || price.end < 40 ? 1 : 0) +
      (availableNow ? 1 : 0) +
      (instantOnly ? 1 : 0) +
      (hasPackages ? 1 : 0) +
      (mode != 'all' ? 1 : 0);

  TutorFilters copy() => TutorFilters()
    ..gender = gender
    ..price = price
    ..availableNow = availableNow
    ..instantOnly = instantOnly
    ..hasPackages = hasPackages
    ..mode = mode;
}

/// Search results: query, subject chips, sort (AI best match / price / rating) and filter sheet.
class TutorListScreen extends StatefulWidget {
  final String? initialSubject;
  const TutorListScreen({super.key, this.initialSubject});
  @override
  State<TutorListScreen> createState() => _TutorListScreenState();
}

class _TutorListScreenState extends State<TutorListScreen> {
  final _query = TextEditingController();
  String? _subject;
  String _sort = 'best';
  TutorFilters _f = TutorFilters();

  @override
  void initState() {
    super.initState();
    _subject = widget.initialSubject;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Tutor> _results(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final list = context.read<AppState>().tutors.where((t) {
      if (_subject != null && !t.subjectIds.contains(_subject)) return false;
      if (q.isNotEmpty) {
        final hay = [
          t.name.ar, t.name.en, t.headline.ar, t.headline.en,
          ...t.tags.map((e) => '${e.ar} ${e.en}'),
          ...t.subjectIds.map((id) => '${MockData.subject(id).name.ar} ${MockData.subject(id).name.en}'),
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (_f.gender != 'all' && t.gender != _f.gender) return false;
      if (t.pricePerHour < _f.price.start || t.pricePerHour > _f.price.end) return false;
      if (_f.availableNow && !t.available) return false;
      if (_f.instantOnly && !t.instantBooking) return false;
      if (_f.hasPackages && !t.hasPackages) return false;
      if (_f.mode == 'in_person' && !t.teachesInPerson) return false;
      return true;
    }).toList();
    switch (_sort) {
      case 'price':
        list.sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
        break;
      case 'rating':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      default:
        list.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    }
    return list;
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<TutorFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FilterSheet(initial: _f.copy()),
    );
    if (result != null) setState(() => _f = result);
  }

  void _openSort() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text(context.tr('sort'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          for (final o in [['best', 'sort_best', Icons.auto_awesome_rounded], ['price', 'sort_price', Icons.payments_outlined], ['rating', 'sort_rating', Icons.star_outline_rounded]])
            RadioListTile<String>(
              value: o[0] as String,
              groupValue: _sort,
              activeColor: AppColors.primary,
              secondary: Icon(o[2] as IconData),
              title: Text(context.tr(o[1] as String)),
              onChanged: (v) {
                setState(() => _sort = v!);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final results = _results(context);
    final width = MediaQuery.of(context).size.width;
    final cols = width >= 1300 ? 3 : (width >= 760 ? 2 : 1);
    Widget card(Tutor t) => TutorCard(
          tutor: t,
          favorite: app.favorites.contains(t.id),
          onFavorite: () => app.toggleFavorite(t.id),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TutorProfileScreen(tutor: t))),
        );

    return SafeArea(
      child: MaxWidth(
        max: 1240,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (width < 900) Text(context.tr('tutors_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                if (width < 900) const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: context.tr('search_hint'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.text.isEmpty
                            ? null
                            : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(_query.clear)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SquareButton(icon: Icons.swap_vert_rounded, onTap: _openSort),
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: _f.activeCount > 0,
                    label: Text('${_f.activeCount}'),
                    child: _SquareButton(icon: Icons.tune_rounded, onTap: _openFilters, active: _f.activeCount > 0),
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    _chip(context.tr('all'), _subject == null, () => setState(() => _subject = null)),
                    for (final s in MockData.subjects) _chip(s.name.of(context), _subject == s.id, () => setState(() => _subject = s.id), icon: s.icon, color: s.color),
                  ]),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Text('${results.length} ${context.tr('results')}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text2)),
                  const Spacer(),
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(context.tr(_sort == 'best' ? 'sort_best' : (_sort == 'price' ? 'sort_price' : 'sort_rating')),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
              ]),
            ),
          ),
          if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.person_search_rounded,
                title: context.tr('no_tutors'),
                body: context.tr('no_tutors_b'),
                action: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpMeFindScreen())),
                  icon: const Icon(Icons.support_agent_rounded),
                  label: Text(context.tr('help_find_t')),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: cols == 1
                  ? SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: card(results[i])),
                        childCount: results.length,
                      ),
                    )
                  : SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 268),
                      delegate: SliverChildBuilderDelegate((_, i) => card(results[i]), childCount: results.length),
                    ),
            ),
        ]),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon, Color? color}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        avatar: icon == null ? null : Icon(icon, size: 18, color: selected ? Colors.white : color),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _SquareButton({required this.icon, required this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) => Material(
        color: active ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? AppColors.primary : AppColors.line)),
            child: Icon(icon, color: active ? Colors.white : AppColors.ink),
          ),
        ),
      );
}

class _FilterSheet extends StatefulWidget {
  final TutorFilters initial;
  const _FilterSheet({required this.initial});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TutorFilters f = widget.initial;

  Widget _seg(String title, List<List<String>> opts, String value, ValueChanged<String> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final o in opts)
          ChoiceChip(
            label: Text(context.tr(o[1])),
            selected: value == o[0],
            showCheckmark: false,
            selectedColor: AppColors.primarySoft,
            side: BorderSide(color: value == o[0] ? AppColors.primary : AppColors.line),
            labelStyle: TextStyle(color: value == o[0] ? AppColors.primary : AppColors.ink, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
            onSelected: (_) => setState(() => onChanged(o[0])),
          ),
      ]),
      const SizedBox(height: 18),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            Row(children: [
              Text(context.tr('filters'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(onPressed: () => setState(() => f = TutorFilters()), child: Text(context.tr('reset'))),
            ]),
            const SizedBox(height: 10),
            _seg(context.tr('gender'), [['all', 'all'], ['m', 'male'], ['f', 'female']], f.gender, (v) => f.gender = v),
            _seg(context.tr('teaching_mode'), [['all', 'all'], ['online', 'online'], ['in_person', 'in_person']], f.mode, (v) => f.mode = v),
            Text('${context.tr('price_range')}: ${money(f.price.start.round())} – ${money(f.price.end.round())}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            RangeSlider(
              values: f.price,
              min: 5,
              max: 40,
              divisions: 35,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => f.price = v),
            ),
            SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: AppColors.primary, title: Text(context.tr('available_now')), value: f.availableNow, onChanged: (v) => setState(() => f.availableNow = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: AppColors.primary, title: Text(context.tr('instant_only')), value: f.instantOnly, onChanged: (v) => setState(() => f.instantOnly = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: AppColors.primary, title: Text(context.tr('has_packages')), value: f.hasPackages, onChanged: (v) => setState(() => f.hasPackages = v)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context, f), child: Text(context.tr('apply')))),
          ]),
        ),
      ),
    );
  }
}
