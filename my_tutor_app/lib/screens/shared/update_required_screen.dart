import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../l10n.dart';
import '../../services/media_bridge.dart';
import '../../services/page_reload.dart';
import '../../theme.dart';

/// Shown instead of the app when Dars requires a newer version (admin setting "min_app_build").
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 56),
                ),
                const SizedBox(height: 22),
                Text(ar ? 'حدّث تطبيق درس' : 'Update Dars', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  kIsWeb
                      ? (ar ? 'يوجد إصدار أحدث من درس. أعد تحميل الصفحة للمتابعة.' : 'A newer version of Dars is available. Reload the page to continue.')
                      : (ar ? 'يوجد إصدار أحدث من درس. نزّل التحديث وثبّته فوق التطبيق الحالي للمتابعة.' : 'A newer version of Dars is available. Download it and install it over this app to continue.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.text2, height: 1.6),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (kIsWeb) {
                        reloadPage();
                      } else {
                        // The smaller file made for this phone's processor (falls back to the one for all phones).
                        MediaBridge.supportedAbis().then((abis) =>
                            launchUrl(Uri.parse(DarsConfig.apkUrlFor(abis)), mode: LaunchMode.externalApplication));
                      }
                    },
                    icon: Icon(kIsWeb ? Icons.refresh_rounded : Icons.download_rounded),
                    label: Text(kIsWeb ? (ar ? 'إعادة التحميل' : 'Reload') : (ar ? 'تنزيل التحديث' : 'Download update')),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
