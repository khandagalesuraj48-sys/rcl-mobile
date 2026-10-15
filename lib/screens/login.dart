/* SIGN IN – the Portal's email and password (one password for every module). Asked 14-10-2026: "login page attractive hawa,
 * login page war rachana cha logo": the green moving background, the Rachana logo springing in, the card rising up; a wrong
 * password shakes the card.
 * (15-10-2026) "super admin new user banwel test password dila … user la first time swatacha banwaycha asel tr to app madhun pn
 * banau shakel": with the password the Super Admin gave (a new user, or a one-time password) the same screen asks for his own
 * password – the given one, the new one twice – and the app opens. No browser needed. */
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/update.dart';
import '../ui/brand.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.setPassword = false});

  /// His first sign-in with a given password: the card asks for his own password.
  final bool setPassword;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _mail = TextEditingController(), _pw = TextEditingController();
  final _given = TextEditingController(), _new = TextEditingController(), _again = TextEditingController();
  String _localErr = '';
  final _pwFocus = FocusNode();
  bool _busy = false, _show = false;
  String _version = '', _lastErr = '';
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    appVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _open.value = 1;
    } else if (_open.value == 0 && !_open.isAnimating) {
      _open.forward();
    }
  }

  @override
  void dispose() {
    _open.dispose();
    _shake.dispose();
    _mail.dispose();
    _pw.dispose();
    _given.dispose();
    _new.dispose();
    _again.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_busy) return;
    if (_mail.text.trim().isEmpty || _pw.text.isEmpty) {
      _shake.forward(from: 0);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    await SessionScope.read(context).signIn(_mail.text, _pw.text);
    if (mounted) setState(() => _busy = false);
  }

  /// (15-10-2026) his own password: the given one, the new one twice – checked here first, then by the Portal (its rules)
  Future<void> _setOwn() async {
    if (_busy) return;
    if (_given.text.isEmpty || _new.text.isEmpty || _again.text.isEmpty) {
      setState(() => _localErr = 'Fill all three boxes.\nतीनही boxes भरा.');
      _shake.forward(from: 0);
      return;
    }
    if (_new.text != _again.text) {
      setState(() => _localErr = 'The two new passwords are not the same.\nदोन्ही नवीन password सारखे नाहीत.');
      _shake.forward(from: 0);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _localErr = '';
    });
    await SessionScope.read(context).setOwnPassword(_given.text, _new.text);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final err = _localErr.isNotEmpty ? _localErr : SessionScope.of(context).error;
    if (err.isNotEmpty && err != _lastErr) {
      _lastErr = err;
      final still = MediaQuery.of(context).disableAnimations;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!still) _shake.forward(from: 0);
        HapticFeedback.mediumImpact();
      });
    } else if (err.isEmpty) {
      _lastErr = '';
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: C.greenDark,
        body: Backdrop(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight - 38),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Arrive(
                          anim: _open,
                          at: 0,
                          scale: true,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 30, offset: const Offset(0, 12))],
                            ),
                            child: const RachanaLogo(height: 58),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Arrive(anim: _open, at: .12, child: const Text('Mechanical Management ERP', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: .2))),
                        const SizedBox(height: 2),
                        Arrive(
                          anim: _open,
                          at: .18,
                          child: Text('यांत्रिकी व्यवस्थापन प्रणाली', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 15, color: Colors.white.withValues(alpha: .85))),
                        ),
                        const SizedBox(height: 28),
                        Arrive(anim: _open, at: .28, rise: 60, child: widget.setPassword ? _pwCard(err) : _card(err)),
                        const SizedBox(height: 18),
                        Arrive(
                          anim: _open,
                          at: .5,
                          child: Text(
                            widget.setPassword ? 'One password for the Portal and every module – the same on the web.' : 'Forgot your password? Ask the Super Admin for a one-time password.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .8), height: 1.35),
                          ),
                        ),
                        if (_version.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Version $_version', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .55)))),
                        const SizedBox(height: 36),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errBox(String err) => AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: err.isEmpty
            ? const SizedBox(width: double.infinity)
            : Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(16)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline_rounded, size: 20, color: C.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(err, style: const TextStyle(color: C.red, fontSize: 14, fontWeight: FontWeight.w500, height: 1.35))),
                ]),
              ),
      );

  Widget _pwBox(TextEditingController c, String label, IconData icon, {TextInputAction next = TextInputAction.next, VoidCallback? go}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: c,
          obscureText: !_show,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: next,
          onChanged: (_) {
            if (_localErr.isNotEmpty) setState(() => _localErr = '');
          },
          onSubmitted: (_) => go == null ? FocusScope.of(context).nextFocus() : go(),
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        ),
      );

  /// (15-10-2026) the first sign-in with a given password: his own password, here in the app
  Widget _pwCard(String err) => AnimatedBuilder(
        animation: _shake,
        builder: (_, ch) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0), child: ch),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Set your own password', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: C.ink)),
            const Text('तुमचा स्वतःचा password बनवा', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 16, fontWeight: FontWeight.w600, color: C.ink)),
            const SizedBox(height: 6),
            const Text('Type the password you were given, then your new password twice.', style: TextStyle(fontSize: 14, color: C.muted)),
            const Text('दिलेला password टाका, मग तुमचा नवीन password दोन वेळा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13.5, color: C.muted)),
            const SizedBox(height: 6),
            _pwBox(_given, 'Given password (दिलेला)', Icons.key_rounded),
            _pwBox(_new, 'New password (नवीन)', Icons.lock_outline_rounded),
            _pwBox(_again, 'New password again (परत)', Icons.lock_reset_rounded, next: TextInputAction.go, go: _setOwn),
            Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: const Text('At least 8 characters, letters and numbers.\nकिमान 8 अक्षरे – अक्षरे आणि अंक दोन्ही.', style: TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
                ),
              ),
              IconButton(tooltip: _show ? 'Hide passwords' : 'Show passwords', icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _show = !_show)),
            ]),
            _errBox(err),
            const SizedBox(height: 18),
            _SignInButton(busy: _busy, onTap: _setOwn, label: 'Save and open'),
            const SizedBox(height: 6),
            TextButton(onPressed: _busy ? null : () => SessionScope.read(context).leaveSetPassword(), child: const Text('Back to sign in')),
          ]),
        ),
      );

  Widget _card(String err) => AnimatedBuilder(
        animation: _shake,
        builder: (_, ch) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0), child: ch),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Namaskar', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: C.ink)),
              const SizedBox(height: 4),
              const Text('Sign in with your Portal email and password.', style: TextStyle(fontSize: 14.5, color: C.muted)),
              const Text('Portal चाच email आणि password वापरा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13.5, color: C.muted)),
              const SizedBox(height: 20),
              TextField(
                controller: _mail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                textInputAction: TextInputAction.next,
                autocorrect: false,
                onSubmitted: (_) => _pwFocus.requestFocus(),
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pw,
                focusNode: _pwFocus,
                obscureText: !_show,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _go(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(tooltip: _show ? 'Hide password' : 'Show password', icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _show = !_show)),
                ),
              ),
              _errBox(err),
              const SizedBox(height: 20),
              _SignInButton(busy: _busy, onTap: _go),
            ]),
          ),
        ),
      );
}

/// The big green button; while signing in it shows a turning ring.
class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.busy, required this.onTap, this.label = 'Sign in'});
  final bool busy;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: const LinearGradient(colors: [C.green, Color(0xFF1E6B4E)]),
          boxShadow: [BoxShadow(color: C.green.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.transparent, disabledBackgroundColor: Colors.transparent, shadowColor: Colors.transparent),
          onPressed: busy ? null : onTap,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: busy
                ? const SizedBox(key: ValueKey('busy'), width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : Row(key: const ValueKey('go'), mainAxisSize: MainAxisSize.min, children: [
                    Text(label, style: const TextStyle(color: Colors.white)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ]),
          ),
        ),
      );
}
