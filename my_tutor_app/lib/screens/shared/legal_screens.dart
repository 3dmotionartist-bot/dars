import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Round E4: the Terms & Conditions and the Privacy Policy are pages of the Dars website (one text for
/// the app and the site), opened in the phone's browser.
Future<void> openLegal(BuildContext context, String doc) =>
    launchUrl(Uri.parse(DarsConfig.legalUrl(doc, context.isAr ? 'ar' : 'en')), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');

/// The consent tick: Terms, Privacy and the automatic checks of chats. Used at sign-up and when the texts change.
class ConsentTick extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const ConsentTick({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CheckboxListTile(
        key: const Key('consent-tick'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.primary,
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        title: Text(context.tr('consent_text'), style: const TextStyle(fontSize: 13.5, height: 1.5)),
      ),
      Wrap(spacing: 4, children: [
        TextButton(onPressed: () => openLegal(context, 'terms'), child: Text(context.tr('terms'))),
        TextButton(onPressed: () => openLegal(context, 'privacy'), child: Text(context.tr('privacy'))),
      ]),
    ]);
  }
}

/// Shown after sign-in when the user has not accepted the current version of the texts.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _tick = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: MaxWidth(
          max: 560,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 48),
            const SizedBox(height: 12),
            Text(context.tr('consent_t'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(context.tr('consent_b'), style: const TextStyle(color: AppColors.text2, height: 1.6)),
            const SizedBox(height: 16),
            ConsentTick(value: _tick, onChanged: (v) => setState(() => _tick = v)),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('consent-accept'),
              onPressed: !_tick || _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await app.acceptTerms();
                      if (mounted) setState(() => _busy = false);
                    },
              child: Text(context.tr('accept_continue')),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: app.logout, child: Text(context.tr('logout'))),
          ]),
        ),
      ),
    );
  }
}

/// Signed in again during the 14 days after "Delete my account": keep the account, or sign out.
class DeletionPendingScreen extends StatelessWidget {
  const DeletionPendingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final at = app.deletionAfter?.toLocal();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: MaxWidth(
          max: 560,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 48),
            const SizedBox(height: 12),
            Text('${context.tr('deletion_waiting')} ${at == null ? '' : '${at.day}/${at.month}/${at.year}'}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            ElevatedButton(key: const Key('keep-account'), onPressed: app.cancelAccountDeletion, child: Text(context.tr('keep_account'))),
            const SizedBox(height: 8),
            TextButton(onPressed: app.logout, child: Text(context.tr('logout'))),
          ]),
        ),
      ),
    );
  }
}
