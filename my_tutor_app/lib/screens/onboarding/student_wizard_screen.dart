import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// First-install wizard: study level → curriculum → subjects of interest.
class StudentWizardScreen extends StatefulWidget {
  final UserRole role;
  final String phone;
  const StudentWizardScreen({super.key, required this.role, required this.phone});
  @override
  State<StudentWizardScreen> createState() => _StudentWizardScreenState();
}

class _StudentWizardScreenState extends State<StudentWizardScreen> {
  int _step = 0;
  String _level = 'high';
  String _curriculum = 'syrian';
  final Set<String> _subjects = {};

  void _finish() {
    final app = context.read<AppState>();
    app.setProfile(level: _level, curriculum: _curriculum, subjects: _subjects.isEmpty ? {'math'} : _subjects);
    Navigator.of(context).popUntil((r) => r.isFirst);
    app.login(asRole: widget.role, phoneNumber: widget.phone);
  }

  @override
  Widget build(BuildContext context) {
    final titles = [context.tr('wiz_level'), context.tr('wiz_curriculum'), context.tr('wiz_interests')];
    final subs = [context.tr('wiz_level_sub'), context.tr('wiz_curriculum_sub'), context.tr('wiz_interests_sub')];

    Widget body;
    if (_step == 0) {
      body = Column(children: [
        for (final l in MockData.levels)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceTile(title: l.name.of(context), icon: l.icon, selected: _level == l.id, onTap: () => setState(() => _level = l.id)),
          ),
      ]);
    } else if (_step == 1) {
      body = Column(children: [
        for (final c in MockData.curricula)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceTile(title: c.name.of(context), icon: Icons.menu_book_outlined, selected: _curriculum == c.id, onTap: () => setState(() => _curriculum = c.id)),
          ),
      ]);
    } else {
      body = GridView.count(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
        children: [
          for (final s in MockData.subjects)
            InkWell(
              onTap: () => setState(() => _subjects.contains(s.id) ? _subjects.remove(s.id) : _subjects.add(s.id)),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: _subjects.contains(s.id) ? AppColors.primarySoft : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _subjects.contains(s.id) ? AppColors.primary : AppColors.line, width: _subjects.contains(s.id) ? 1.6 : 1),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(s.icon, color: s.color, size: 32),
                  const SizedBox(height: 6),
                  Text(s.name.of(context), textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3)),
                ]),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: _step > 0 ? IconButton(icon: const BackButtonIcon(), onPressed: () => setState(() => _step--)) : null,
        actions: [TextButton(onPressed: _finish, child: Text(context.tr('skip')))],
      ),
      body: SafeArea(
        child: MaxWidth(
          max: 560,
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
                StepDots(count: 3, index: _step),
                const SizedBox(height: 22),
                Text(titles[_step], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subs[_step], style: const TextStyle(color: AppColors.text2)),
                const SizedBox(height: 20),
                body,
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_step < 2) {
                      setState(() => _step++);
                    } else {
                      _finish();
                    }
                  },
                  child: Text(_step < 2 ? context.tr('next') : context.tr('finish')),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
