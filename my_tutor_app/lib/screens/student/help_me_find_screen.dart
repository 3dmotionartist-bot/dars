import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../l10n.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// "Help me find a tutor" lead wizard → academic advisor follows up on WhatsApp.
class HelpMeFindScreen extends StatefulWidget {
  const HelpMeFindScreen({super.key});
  @override
  State<HelpMeFindScreen> createState() => _HelpMeFindScreenState();
}

class _HelpMeFindScreenState extends State<HelpMeFindScreen> {
  int _step = 0;
  String _who = 'student';
  String _level = 'high';
  String _subject = 'math';
  String _reason = 'hm_r2';
  String _mode = 'online';
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: EmptyState(
            icon: Icons.mark_chat_read_rounded,
            title: context.tr('done'),
            body: context.tr('hm_success'),
            action: ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('close'))),
          ),
        ),
      );
    }

    final steps = <String, Widget>{
      'hm_who': Column(children: [
        ChoiceTile(title: context.tr('role_student'), icon: Icons.school_rounded, selected: _who == 'student', onTap: () => setState(() => _who = 'student')),
        const SizedBox(height: 10),
        ChoiceTile(title: context.tr('role_parent'), icon: Icons.family_restroom_rounded, color: AppColors.accent, selected: _who == 'parent', onTap: () => setState(() => _who = 'parent')),
      ]),
      'hm_level': Column(children: [
        for (final l in MockData.levels)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: ChoiceTile(title: l.name.of(context), icon: l.icon, selected: _level == l.id, onTap: () => setState(() => _level = l.id))),
      ]),
      'hm_subject': Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in MockData.subjects)
          ChoiceChip(
            avatar: Icon(s.icon, size: 18, color: _subject == s.id ? Colors.white : s.color),
            label: Text(s.name.of(context)),
            selected: _subject == s.id,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: _subject == s.id ? Colors.white : AppColors.ink),
            onSelected: (_) => setState(() => _subject = s.id),
          ),
      ]),
      'hm_reason': Column(children: [
        for (final r in ['hm_r1', 'hm_r2', 'hm_r3', 'hm_r4'])
          Padding(padding: const EdgeInsets.only(bottom: 8), child: ChoiceTile(title: context.tr(r), selected: _reason == r, onTap: () => setState(() => _reason = r))),
      ]),
      'hm_mode': Column(children: [
        for (final m in [['online', Icons.videocam_rounded], ['in_person', Icons.home_work_rounded], ['both', Icons.sync_alt_rounded]])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChoiceTile(title: context.tr(m[0] as String), icon: m[1] as IconData, selected: _mode == m[0], onTap: () => setState(() => _mode = m[0] as String)),
          ),
      ]),
      'hm_contact': Column(children: [
        TextField(decoration: InputDecoration(hintText: context.tr('full_name'), prefixIcon: const Icon(Icons.person_outline))),
        const SizedBox(height: 10),
        TextField(keyboardType: TextInputType.phone, decoration: InputDecoration(hintText: context.tr('whatsapp_number'), prefixIcon: const Icon(Icons.chat_outlined))),
        const SizedBox(height: 10),
        TextField(decoration: InputDecoration(hintText: context.tr('city'), prefixIcon: const Icon(Icons.location_city_outlined))),
        const SizedBox(height: 10),
        TextField(maxLines: 3, decoration: InputDecoration(hintText: context.tr('notes_opt'))),
      ]),
    };
    final keys = steps.keys.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white, title: Text(context.tr('help_find_t'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: MaxWidth(
        max: 560,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          StepDots(count: keys.length, index: _step),
          const SizedBox(height: 20),
          Text(context.tr(keys[_step]), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          steps[keys[_step]]!,
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: MaxWidth(
            max: 560,
            child: Row(children: [
              if (_step > 0) ...[
                OutlinedButton(onPressed: () => setState(() => _step--), child: Text(context.tr('back'))),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    if (_step < keys.length - 1) {
                      _step++;
                    } else {
                      _done = true;
                    }
                  }),
                  child: Text(_step < keys.length - 1 ? context.tr('next') : context.tr('send')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
