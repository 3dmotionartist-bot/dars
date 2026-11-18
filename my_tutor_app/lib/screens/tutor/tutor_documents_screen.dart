import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Round E2: the tutor's verification documents — ID and certificate (required), CV (optional).
/// They go to the private tutor-docs bucket: only the tutor and the Dars team can open them.
class TutorDocsPanel extends StatefulWidget {
  const TutorDocsPanel({super.key});
  @override
  State<TutorDocsPanel> createState() => _TutorDocsPanelState();
}

class _TutorDocsPanelState extends State<TutorDocsPanel> {
  final Set<String> _busy = {};
  final Set<String> _demo = {};

  Future<void> _pick(String kind) async {
    final app = context.read<AppState>();
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2200, maxHeight: 2200, imageQuality: 85);
    if (f == null || !mounted) return;
    setState(() => _busy.add(kind));
    final ok = await app.addTutorDocument(kind, await f.readAsBytes(), f.name, f.mimeType ?? 'image/jpeg');
    if (!mounted) return;
    setState(() {
      _busy.remove(kind);
      if (ok && !app.live) _demo.add(kind);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Widget row(String kind, String title, String hint, IconData icon, bool required) {
      final has = app.live ? app.hasTutorDoc(kind) : _demo.contains(kind);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ChoiceTile(
          key: Key('doc-$kind'),
          title: has ? '$title ✓' : '$title${required ? ' *' : ''}',
          subtitle: _busy.contains(kind) ? context.tr('uploading') : (has ? context.tr('doc_uploaded') : hint),
          icon: icon,
          color: has ? AppColors.success : AppColors.info,
          selected: has,
          onTap: () {
            if (!_busy.contains(kind)) _pick(kind);
          },
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.tr('docs_title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 4),
      Text(context.tr('docs_private'), style: const TextStyle(color: AppColors.text2, fontSize: 13, height: 1.5)),
      const SizedBox(height: 10),
      row('id', context.tr('doc_id'), context.tr('doc_id_hint'), Icons.badge_outlined, true),
      row('certificate', context.tr('doc_cert'), context.tr('doc_cert_hint'), Icons.workspace_premium_outlined, true),
      row('cv', context.tr('doc_cv'), context.tr('doc_cv_hint'), Icons.description_outlined, false),
    ]);
  }
}

/// Opened from the dashboard when the Dars team asks for changes: fix the documents and send again.
class TutorDocumentsScreen extends StatelessWidget {
  const TutorDocumentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ready = !app.live || (app.hasTutorDoc('id') && app.hasTutorDoc('certificate'));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(context.tr('docs_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: MaxWidth(
        max: 620,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (app.tutorVerification == 'rejected' && (app.rejectionReason ?? '').isNotEmpty) ...[
            AppCard(
              color: AppColors.dangerSoft,
              borderColor: AppColors.danger,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(child: Text(app.rejectionReason!, style: const TextStyle(height: 1.5))),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          const TutorDocsPanel(),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: MaxWidth(
            max: 620,
            child: ElevatedButton(
              key: const Key('docs-resend'),
              onPressed: ready
                  ? () async {
                      if (await app.resubmitTutorApplication() && context.mounted) Navigator.pop(context);
                    }
                  : null,
              child: Text(context.tr('docs_resend')),
            ),
          ),
        ),
      ),
    );
  }
}
