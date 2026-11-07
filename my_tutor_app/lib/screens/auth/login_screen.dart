import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../onboarding/student_wizard_screen.dart';
import '../tutor/tutor_registration_screen.dart';

const _countries = [
  ['🇸🇾', '+963'],
  ['🇸🇦', '+966'],
  ['🇦🇪', '+971'],
  ['🇯🇴', '+962'],
  ['🇪🇬', '+20'],
  ['🇰🇼', '+965'],
  ['🇶🇦', '+974'],
  ['🇱🇧', '+961'],
  ['🇹🇷', '+90'],
];

/// Step 1 — WhatsApp number (Modarby-style passwordless sign-in).
class LoginScreen extends StatefulWidget {
  final UserRole role;
  const LoginScreen({super.key, required this.role});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _code = '+963';
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _phone.text.replaceAll(' ', '').length >= 8;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      body: SafeArea(
        child: MaxWidth(
          max: 480,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Container(
              width: 64,
              height: 64,
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: const Color(0xFFE7F8EE), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 34),
              ),
            ),
            const SizedBox(height: 20),
            Text(context.tr('login_title'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(context.tr('login_sub'), style: const TextStyle(color: AppColors.text2, fontSize: 15)),
            const SizedBox(height: 28),
            Text(context.tr('whatsapp_number'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(children: [
                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _code,
                      items: [
                        for (final c in _countries) DropdownMenuItem(value: c[1], child: Text('${c[0]}  ${c[1]}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
                      ],
                      onChanged: (v) => setState(() => _code = v ?? _code),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1),
                    decoration: const InputDecoration(hintText: '9xx xxx xxx'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: valid
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(role: widget.role, phone: '$_code ${_phone.text}')))
                  : null,
              child: Text(context.tr('send_code')),
            ),
            const SizedBox(height: 22),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(context.tr('or'), style: const TextStyle(color: AppColors.text3))),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.line)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(role: widget.role, phone: 'Google'))),
              icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF4285F4))),
              label: Text(context.tr('continue_google')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.line)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(role: widget.role, phone: 'email'))),
              icon: const Icon(Icons.mail_outline_rounded),
              label: Text(context.tr('continue_email')),
            ),
            const SizedBox(height: 24),
            Text(context.tr('terms_agree'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

/// Step 2 — 4-digit code sent to WhatsApp.
class OtpScreen extends StatefulWidget {
  final UserRole role;
  final String phone;
  const OtpScreen({super.key, required this.role, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = TextEditingController();
  Timer? _timer;
  int _seconds = 30;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _seconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _seconds = _seconds > 0 ? _seconds - 1 : 0);
      if (_seconds == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CodeScaffold(
      title: context.tr('otp_title'),
      subtitle: '${context.tr('otp_sub')} ${widget.phone}',
      controller: _ctrl,
      obscure: false,
      button: context.tr('verify'),
      footer: _seconds > 0
          ? Text('${context.tr('resend_in')} 0:${two(_seconds)}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text3))
          : TextButton(onPressed: () => setState(_start), child: Text(context.tr('resend'))),
      onDone: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PinScreen(role: widget.role, phone: widget.phone))),
    );
  }
}

/// Step 3 — create a 4-digit PIN for quick sign-in.
class PinScreen extends StatelessWidget {
  final UserRole role;
  final String phone;
  const PinScreen({super.key, required this.role, required this.phone});
  @override
  Widget build(BuildContext context) {
    return _CodeScaffold(
      title: context.tr('pin_title'),
      subtitle: context.tr('pin_sub'),
      obscure: true,
      button: context.tr('save'),
      onDone: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == UserRole.tutor ? TutorRegistrationScreen(phone: phone) : StudentWizardScreen(role: role, phone: phone),
        ),
      ),
    );
  }
}

class _CodeScaffold extends StatefulWidget {
  final String title;
  final String subtitle;
  final TextEditingController? controller;
  final bool obscure;
  final String button;
  final Widget? footer;
  final VoidCallback onDone;
  const _CodeScaffold({required this.title, required this.subtitle, this.controller, required this.obscure, required this.button, required this.onDone, this.footer});
  @override
  State<_CodeScaffold> createState() => _CodeScaffoldState();
}

class _CodeScaffoldState extends State<_CodeScaffold> {
  final _focus = FocusNode();
  late final TextEditingController _ctrl = widget.controller ?? TextEditingController();

  @override
  void dispose() {
    _focus.dispose();
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _ctrl.text;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      body: SafeArea(
        child: MaxWidth(
          max: 480,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text(widget.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(widget.subtitle, style: const TextStyle(color: AppColors.text2, fontSize: 15)),
            const SizedBox(height: 32),
            // Hidden field + 4 visual boxes
            Stack(children: [
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              GestureDetector(
                onTap: () => _focus.requestFocus(),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (int i = 0; i < 4; i++)
                      Container(
                        width: 62,
                        height: 68,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i < code.length ? AppColors.primarySoft : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: i == code.length ? AppColors.primary : AppColors.line, width: i == code.length ? 2 : 1),
                        ),
                        child: Text(
                          i < code.length ? (widget.obscure ? '●' : code[i]) : '',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: code.length == 4 ? widget.onDone : null, child: Text(widget.button)),
            const SizedBox(height: 12),
            if (widget.footer != null) widget.footer!,
          ]),
        ),
      ),
    );
  }
}
