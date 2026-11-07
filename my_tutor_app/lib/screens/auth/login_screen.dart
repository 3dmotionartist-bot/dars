import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../../config.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
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
  bool _sending = false;

  String get _fullPhone => '$_code ${_phone.text.replaceAll(' ', '').replaceFirst(RegExp(r'^0+'), '')}';

  Future<void> _send() async {
    final app = context.read<AppState>();
    if (app.live) {
      setState(() => _sending = true);
      try {
        await app.sendCode(_fullPhone, widget.role);
      } catch (e) {
        if (mounted) setState(() => _sending = false);
        app.say(Backend.errorText(e), bad: true);
        return;
      }
      if (!mounted) return;
      setState(() => _sending = false);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(role: widget.role, phone: _fullPhone)));
  }

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
              onPressed: valid && !_sending ? _send : null,
              child: _sending
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(context.tr('send_code')),
            ),
            const SizedBox(height: 22),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(context.tr('or'), style: const TextStyle(color: AppColors.text3))),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            if (!DarsConfig.live) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.line)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(role: widget.role, phone: 'Google'))),
                icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF4285F4))),
                label: Text(context.tr('continue_google')),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.line)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DarsConfig.live ? EmailAuthScreen(role: widget.role) : OtpScreen(role: widget.role, phone: 'email')),
              ),
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

  Future<void> _verify() async {
    final app = context.read<AppState>();
    if (!app.live) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PinScreen(role: widget.role, phone: widget.phone)));
      return;
    }
    try {
      final ready = await app.verifyCode(widget.phone, _ctrl.text);
      if (!mounted) return;
      afterSignIn(context, ready: ready, role: widget.role, phone: widget.phone);
    } catch (e) {
      app.say(Backend.errorText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = DarsConfig.live;
    return _CodeScaffold(
      title: context.tr('otp_title'),
      subtitle: '${context.tr('otp_sub')} ${widget.phone}',
      controller: _ctrl,
      length: live ? DarsConfig.otpLength : 4,
      obscure: false,
      button: context.tr('verify'),
      footer: _seconds > 0
          ? Text('${context.tr('resend_in')} 0:${two(_seconds)}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text3))
          : TextButton(
              onPressed: () {
                setState(_start);
                if (live) context.read<AppState>().sendCode(widget.phone, widget.role).catchError((Object e) => context.read<AppState>().say(Backend.errorText(e), bad: true));
              },
              child: Text(context.tr('resend')),
            ),
      onDone: _verify,
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
  final int length;
  final FutureOr<void> Function() onDone;
  const _CodeScaffold({required this.title, required this.subtitle, this.controller, required this.obscure, required this.button, required this.onDone, this.footer, this.length = 4});
  @override
  State<_CodeScaffold> createState() => _CodeScaffoldState();
}

class _CodeScaffoldState extends State<_CodeScaffold> {
  final _focus = FocusNode();
  late final TextEditingController _ctrl = widget.controller ?? TextEditingController();
  bool _busy = false;

  Future<void> _done() async {
    setState(() => _busy = true);
    try {
      await widget.onDone();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                  maxLength: widget.length,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              GestureDetector(
                onTap: () => _focus.requestFocus(),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (int i = 0; i < widget.length; i++)
                      Container(
                        width: widget.length > 4 ? 46 : 62,
                        height: widget.length > 4 ? 56 : 68,
                        margin: EdgeInsets.symmetric(horizontal: widget.length > 4 ? 4 : 6),
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
            ElevatedButton(
              onPressed: code.length == widget.length && !_busy ? _done : null,
              child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : Text(widget.button),
            ),
            const SizedBox(height: 12),
            if (widget.footer != null) widget.footer!,
          ]),
        ),
      ),
    );
  }
}


/// After a real sign-in: existing accounts go straight in; new ones finish their profile.
void afterSignIn(BuildContext context, {required bool ready, required UserRole role, required String phone}) {
  if (ready) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    return;
  }
  // The account type stored on the server wins (it was chosen when the account was created).
  final app = context.read<AppState>();
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => app.role == UserRole.tutor ? TutorRegistrationScreen(phone: phone) : StudentWizardScreen(role: app.role, phone: phone)),
  );
}

/// Live mode: email + password (for testing before SMS / WhatsApp codes are connected).
class EmailAuthScreen extends StatefulWidget {
  final UserRole role;
  const EmailAuthScreen({super.key, required this.role});
  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final ready = await app.emailAuth(_email.text, _password.text, widget.role, create: _create);
      if (!mounted) return;
      afterSignIn(context, ready: ready, role: widget.role, phone: _email.text.trim());
    } catch (e) {
      app.say(Backend.errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _email.text.contains('@') && _password.text.length >= 6;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      body: SafeArea(
        child: MaxWidth(
          max: 480,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text(context.tr(_create ? 'email_create_t' : 'email_signin_t'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(context.tr('email_sub'), style: const TextStyle(color: AppColors.text2, fontSize: 15)),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(hintText: context.tr('email'), prefixIcon: const Icon(Icons.mail_outline_rounded)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: true,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(hintText: context.tr('password_6'), prefixIcon: const Icon(Icons.lock_outline_rounded)),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => valid && !_busy ? _submit() : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: valid && !_busy ? _submit : null,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(context.tr(_create ? 'create_account' : 'sign_in')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _create = !_create),
              child: Text(context.tr(_create ? 'email_have_account' : 'new_account')),
            ),
          ]),
        ),
      ),
    );
  }
}
