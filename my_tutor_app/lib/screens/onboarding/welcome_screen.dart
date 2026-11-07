import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';

/// Language switch + "Who is going to use the application?" (student / parent / tutor).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  UserRole _role = UserRole.student;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final wide = MediaQuery.of(context).size.width > 900;

    final form = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (!wide) const DarsLogo(size: 44),
          const Spacer(),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), side: const BorderSide(color: AppColors.line), foregroundColor: AppColors.ink),
            onPressed: app.toggleLocale,
            icon: const Icon(Icons.language_rounded, size: 18),
            label: Text(context.tr('switch_lang')),
          ),
        ]),
        const SizedBox(height: 28),
        Text(context.tr('who_uses'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        ChoiceTile(
          title: context.tr('role_student'),
          subtitle: context.tr('role_student_d'),
          icon: Icons.school_rounded,
          color: AppColors.info,
          selected: _role == UserRole.student,
          onTap: () => setState(() => _role = UserRole.student),
        ),
        const SizedBox(height: 10),
        ChoiceTile(
          title: context.tr('role_parent'),
          subtitle: context.tr('role_parent_d'),
          icon: Icons.family_restroom_rounded,
          color: AppColors.accent,
          selected: _role == UserRole.parent,
          onTap: () => setState(() => _role = UserRole.parent),
        ),
        const SizedBox(height: 10),
        ChoiceTile(
          title: context.tr('role_tutor'),
          subtitle: context.tr('role_tutor_d'),
          icon: Icons.co_present_rounded,
          color: AppColors.primary,
          selected: _role == UserRole.tutor,
          onTap: () => setState(() => _role = UserRole.tutor),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(role: _role))),
          child: Text(context.tr('get_started')),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(role: _role))),
          child: Text(context.tr('have_account')),
        ),
      ]),
    );

    final hero = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primaryDark]),
      ),
      padding: const EdgeInsets.all(40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        const DarsLogo(size: 64, light: true),
        const SizedBox(height: 28),
        Text(context.tr('tagline'), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 14),
        Text(context.tr('tagline_sub'), style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 18, height: 1.6)),
        const SizedBox(height: 32),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _heroChip(Icons.verified_user_rounded, context.isAr ? 'مدرسون موثّقون' : 'Verified tutors'),
          _heroChip(Icons.bolt_rounded, context.isAr ? 'مساعدة خلال دقائق' : 'Help in minutes'),
          _heroChip(Icons.workspace_premium_rounded, context.tr('guarantee_t')),
        ]),
      ]),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: wide
            ? Row(children: [Expanded(flex: 6, child: hero), Expanded(flex: 5, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: form)))])
            : Column(children: [
                Expanded(child: form),
              ]),
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      );
}
