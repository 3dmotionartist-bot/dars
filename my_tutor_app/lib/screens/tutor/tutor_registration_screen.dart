import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Tutor sign-up: About you → Subjects → Fees per level → Profile (CV/video) → Ethical pledge → Under review.
class TutorRegistrationScreen extends StatefulWidget {
  final String phone;
  const TutorRegistrationScreen({super.key, required this.phone});
  @override
  State<TutorRegistrationScreen> createState() => _TutorRegistrationScreenState();
}

class _TutorRegistrationScreenState extends State<TutorRegistrationScreen> {
  int _step = 0;
  bool _done = false;
  String _gender = 'm';
  final Set<String> _subjects = {'math'};
  final Set<String> _curricula = {'syrian'};
  bool _online = true;
  bool _inPerson = false;
  final Map<String, double> _fees = {'elementary': 10, 'middle': 12, 'high': 15, 'university': 18};
  bool _cv = false;
  bool _video = false;
  bool _pledge = false;

  static const _stepKeys = ['treg_s1', 'treg_s2', 'treg_s3', 'treg_s4', 'treg_s5'];

  void _finish() {
    final app = context.read<AppState>();
    Navigator.of(context).popUntil((r) => r.isFirst);
    app.login(asRole: UserRole.tutor, phoneNumber: widget.phone);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: EmptyState(
            icon: Icons.hourglass_top_rounded,
            title: context.tr('treg_done_t'),
            body: context.tr('treg_done_b'),
            action: ElevatedButton(onPressed: _finish, child: Text(context.tr('go_dashboard'))),
          ),
        ),
      );
    }

    Widget body;
    switch (_step) {
      case 0:
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(decoration: InputDecoration(hintText: context.tr('full_name'), prefixIcon: const Icon(Icons.person_outline))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: ChoiceTile(title: context.tr('male'), selected: _gender == 'm', onTap: () => setState(() => _gender = 'm'))),
            const SizedBox(width: 8),
            Expanded(child: ChoiceTile(title: context.tr('female'), selected: _gender == 'f', onTap: () => setState(() => _gender = 'f'))),
          ]),
          const SizedBox(height: 10),
          TextField(decoration: InputDecoration(hintText: context.tr('city'), prefixIcon: const Icon(Icons.location_city_outlined))),
          const SizedBox(height: 16),
          Center(
            child: Column(children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.primary)),
                child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 34),
              ),
              const SizedBox(height: 6),
              Text(context.isAr ? 'صورة شخصية واضحة' : 'Clear profile photo', style: const TextStyle(color: AppColors.text2)),
            ]),
          ),
        ]);
        break;
      case 1:
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('treg_subjects_note'), style: const TextStyle(color: AppColors.text2)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in MockData.subjects)
              FilterChip(
                avatar: Icon(s.icon, size: 18, color: _subjects.contains(s.id) ? Colors.white : s.color),
                label: Text(s.name.of(context)),
                selected: _subjects.contains(s.id),
                showCheckmark: false,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: _subjects.contains(s.id) ? Colors.white : AppColors.ink),
                onSelected: (v) => setState(() {
                  if (v && _subjects.length < 3) {
                    _subjects.add(s.id);
                  } else {
                    _subjects.remove(s.id);
                  }
                }),
              ),
          ]),
          const SizedBox(height: 18),
          Text(context.tr('wiz_curriculum'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in MockData.curricula)
              FilterChip(
                label: Text(c.name.of(context)),
                selected: _curricula.contains(c.id),
                selectedColor: AppColors.primarySoft,
                checkmarkColor: AppColors.primary,
                labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                onSelected: (v) => setState(() => v ? _curricula.add(c.id) : _curricula.remove(c.id)),
              ),
          ]),
          const SizedBox(height: 18),
          Text(context.tr('teaching_mode'), style: const TextStyle(fontWeight: FontWeight.w800)),
          CheckboxListTile(contentPadding: EdgeInsets.zero, activeColor: AppColors.primary, value: _online, onChanged: (v) => setState(() => _online = v ?? true), title: Text(context.tr('online'))),
          CheckboxListTile(contentPadding: EdgeInsets.zero, activeColor: AppColors.primary, value: _inPerson, onChanged: (v) => setState(() => _inPerson = v ?? false), title: Text(context.tr('in_person'))),
        ]);
        break;
      case 2:
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('treg_fees_note'), style: const TextStyle(color: AppColors.text2)),
          const SizedBox(height: 10),
          for (final l in MockData.levels.where((l) => _fees.containsKey(l.id)))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(children: [
                  Row(children: [
                    Icon(l.icon, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(l.name.of(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${money(_fees[l.id]!.round())}${context.tr('per_hour')}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  ]),
                  Slider(value: _fees[l.id]!, min: 5, max: 60, divisions: 55, activeColor: AppColors.primary, onChanged: (v) => setState(() => _fees[l.id] = v)),
                ]),
              ),
            ),
          Text(context.isAr ? 'عمولة المنصة 15% من كل درس' : 'Platform commission: 15% per lesson', style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
        ]);
        break;
      case 3:
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(maxLength: 50, decoration: InputDecoration(hintText: context.tr('headline'))),
          TextField(maxLines: 5, maxLength: 500, decoration: InputDecoration(hintText: context.tr('about_you'))),
          const SizedBox(height: 6),
          ChoiceTile(title: _cv ? 'CV.pdf ✓' : context.tr('upload_cv'), icon: Icons.upload_file_rounded, color: AppColors.info, selected: _cv, onTap: () => setState(() => _cv = !_cv)),
          const SizedBox(height: 8),
          ChoiceTile(title: _video ? 'intro.mp4 ✓' : context.tr('upload_video'), icon: Icons.video_call_rounded, color: AppColors.lavenderInk, selected: _video, onTap: () => setState(() => _video = !_video)),
          const SizedBox(height: 10),
          TextField(keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'LinkedIn URL', prefixIcon: Icon(Icons.link_rounded))),
        ]);
        break;
      default:
        body = Column(children: [
          AppCard(
            color: AppColors.accentSoft,
            borderColor: AppColors.accentSoft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.handshake_rounded, color: AppColors.accent, size: 30),
                const SizedBox(width: 10),
                Text(context.tr('pledge_t'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ]),
              const SizedBox(height: 10),
              Text(context.tr('pledge_b'), style: const TextStyle(height: 1.8)),
            ]),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
            value: _pledge,
            onChanged: (v) => setState(() => _pledge = v ?? false),
            title: Text(context.tr('pledge_agree'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]);
    }

    final last = _step == _stepKeys.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(context.tr('treg_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: MaxWidth(
        max: 620,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Row(children: [
            for (int i = 0; i < _stepKeys.length; i++)
              Expanded(
                child: Column(children: [
                  Container(
                    height: 5,
                    margin: const EdgeInsetsDirectional.only(end: 5),
                    decoration: BoxDecoration(color: i <= _step ? AppColors.primary : AppColors.line, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 4),
                  Text(context.tr(_stepKeys[i]), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: i <= _step ? AppColors.primary : AppColors.text3)),
                ]),
              ),
          ]),
          const SizedBox(height: 22),
          body,
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: MaxWidth(
            max: 620,
            child: ElevatedButton(
              onPressed: last && !_pledge
                  ? null
                  : () => setState(() {
                        if (last) {
                          _done = true;
                        } else {
                          _step++;
                        }
                      }),
              child: Text(last ? context.tr('pledge_agree') : context.tr('next')),
            ),
          ),
        ),
      ),
    );
  }
}
