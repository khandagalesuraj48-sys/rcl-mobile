/* SIGN IN – the Portal's email and password (one password for every module). Asked 14-10-2026: "login page interesting banaw,
 * animations de … clean UI sobat beautiful": the green moving background, the RCL mark springing in, the card rising up; a
 * wrong password shakes the card. */
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/update.dart';
import '../ui/brand.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _mail = TextEditingController(), _pw = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final err = SessionScope.of(context).error;
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
                        Arrive(anim: _open, at: 0, scale: true, child: const Mark(size: 88)),
                        const SizedBox(height: 18),
                        Arrive(anim: _open, at: .12, child: const Text('RCL ERP', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: .5))),
                        const SizedBox(height: 4),
                        Arrive(
                          anim: _open,
                          at: .18,
                          child: Text('One Click Solution · Fleet ERP', style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: .82), fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(height: 28),
                        Arrive(anim: _open, at: .28, rise: 60, child: _card(err)),
                        const SizedBox(height: 18),
                        Arrive(
                          anim: _open,
                          at: .5,
                          child: Text(
                            'Forgot your password? Ask the Super Admin for a one-time password.',
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
              AnimatedSize(
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
              ),
              const SizedBox(height: 20),
              _SignInButton(busy: _busy, onTap: _go),
            ]),
          ),
        ),
      );
}

/// The big green button; while signing in it shows a turning ring.
class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;
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
                : const Row(key: ValueKey('go'), mainAxisSize: MainAxisSize.min, children: [
                    Text('Sign in', style: TextStyle(color: Colors.white)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ]),
          ),
        ),
      );
}
