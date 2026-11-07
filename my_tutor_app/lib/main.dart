import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/models.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/student/student_shell.dart';
import 'screens/tutor/tutor_shell.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(create: (_) => AppState(), child: const DarsApp()));
}

class DarsApp extends StatelessWidget {
  const DarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Widget home;
    if (app.booting) {
      home = const _Splash();
    } else if (!app.loggedIn) {
      home = const WelcomeScreen();
    } else if (app.role == UserRole.tutor) {
      home = const TutorShell();
    } else {
      home = const StudentShell();
    }
    return MaterialApp(
      title: 'Dars | درس',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      locale: app.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('درس', style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
            SizedBox(height: 18),
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white)),
          ]),
        ),
      );
}
