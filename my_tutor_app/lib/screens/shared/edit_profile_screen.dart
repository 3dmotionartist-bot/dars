import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/media.dart';

/// Edit my profile: photo and name for everyone; tutors also edit their public profile and intro video.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final AppState _app = context.read<AppState>();
  late final _name = TextEditingController(text: _app.name);
  late final _headline = TextEditingController(text: _app.role == UserRole.tutor ? _app.me.headline.of(context) : '');
  late final _about = TextEditingController(text: _app.role == UserRole.tutor ? _app.me.about.of(context) : '');
  late final _price = TextEditingController(text: _app.role == UserRole.tutor ? '${_app.me.pricePerHour}' : '');
  late final _years = TextEditingController(text: _app.role == UserRole.tutor ? '${_app.me.years}' : '');
  late bool _online = _app.me.teachesOnline;
  late bool _inPerson = _app.me.teachesInPerson;
  late final Set<String> _subjects = {..._app.me.subjectIds};
  bool _saving = false;
  bool _photoBusy = false;
  bool _videoBusy = false;

  @override
  void dispose() {
    for (final c in [_name, _headline, _about, _price, _years]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 640, maxHeight: 640, imageQuality: 85);
    if (f == null || !mounted) return;
    setState(() => _photoBusy = true);
    await _app.setProfilePhoto(await f.readAsBytes(), f.name, f.mimeType ?? 'image/jpeg');
    if (mounted) setState(() => _photoBusy = false);
  }

  Future<void> _pickVideo() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
    if (f == null || !mounted) return;
    setState(() => _videoBusy = true);
    final bytes = await f.readAsBytes();
    await _app.setIntroVideo(bytes, name: f.name.isEmpty ? 'intro.mp4' : f.name, mime: f.mimeType ?? 'video/mp4');
    if (mounted) setState(() => _videoBusy = false);
  }

  Future<void> _removeVideo() async {
    setState(() => _videoBusy = true);
    await _app.setIntroVideo(null);
    if (mounted) setState(() => _videoBusy = false);
  }

  Future<void> _save() async {
    final tutor = _app.role == UserRole.tutor;
    if (tutor && _headline.text.trim().isEmpty) {
      toast(context, context.tr('headline_required'), icon: Icons.info_outline);
      return;
    }
    setState(() => _saving = true);
    final ok = await _app.saveMyProfile(
      fullName: _name.text,
      headline: tutor ? _headline.text : null,
      about: tutor ? _about.text : null,
      years: tutor ? int.tryParse(_years.text.trim()) : null,
      hourlyPrice: tutor ? int.tryParse(_price.text.trim()) : null,
      online: tutor ? _online : null,
      inPerson: tutor ? _inPerson : null,
      subjects: tutor ? _subjects : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tutor = app.role == UserRole.tutor;
    final t = app.me;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(context.tr('edit_profile'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: MaxWidth(
        max: 720,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: GestureDetector(
              onTap: _photoBusy ? null : _pickPhoto,
              child: Stack(clipBehavior: Clip.none, children: [
                Avatar(name: L(app.name, app.name), color: AppColors.primary, size: 108, photo: app.avatarUrl),
                PositionedDirectional(
                  bottom: -6,
                  end: -6,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary,
                    child: _photoBusy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: TextButton(onPressed: _photoBusy ? null : _pickPhoto, child: Text(context.tr('change_photo')))),
          const SizedBox(height: 8),
          TextField(controller: _name, textInputAction: TextInputAction.next, decoration: _dec(context.tr('your_name'))),
          if (tutor) ...[
            const SizedBox(height: 14),
            TextField(controller: _headline, maxLength: 80, decoration: _dec(context.tr('headline_label'))),
            const SizedBox(height: 6),
            TextField(controller: _about, maxLength: 1000, minLines: 4, maxLines: 10, decoration: _dec(context.tr('about_label'))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: _dec(context.tr('hourly_price_usd')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _years,
                  keyboardType: TextInputType.number,
                  decoration: _dec(context.tr('years_label')),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _online,
              onChanged: (v) => setState(() => _online = v),
              title: Text(context.tr('teach_online')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _inPerson,
              onChanged: (v) => setState(() => _inPerson = v),
              title: Text(context.tr('teach_in_person')),
            ),
            const SizedBox(height: 6),
            Text(context.tr('subjects_label'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final sub in MockData.subjects)
                FilterChip(
                  label: Text(sub.name.of(context)),
                  selected: _subjects.contains(sub.id),
                  onSelected: (v) => setState(() => v ? _subjects.add(sub.id) : (_subjects.length > 1 ? _subjects.remove(sub.id) : null)),
                ),
            ]),
            const SizedBox(height: 18),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.ondemand_video_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.tr('intro_video'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                ]),
                const SizedBox(height: 6),
                Text(context.tr('intro_video_hint'), style: const TextStyle(color: AppColors.text2, height: 1.5)),
                const SizedBox(height: 12),
                if (_videoBusy)
                  Row(children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                    const SizedBox(width: 12),
                    Text(context.tr('uploading')),
                  ])
                else
                  Wrap(spacing: 10, runSpacing: 8, children: [
                    if (t.videoUrl.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(stored: t.videoUrl, title: t.name.of(context)))),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(context.tr('watch')),
                      ),
                    ElevatedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.upload_rounded),
                      label: Text(context.tr(t.videoUrl.isEmpty ? 'upload_video' : 'replace_video')),
                    ),
                    if (t.videoUrl.isNotEmpty)
                      TextButton.icon(
                        onPressed: _removeVideo,
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                        label: Text(context.tr('remove'), style: const TextStyle(color: AppColors.danger)),
                      ),
                  ]),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(context.tr('save')),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
