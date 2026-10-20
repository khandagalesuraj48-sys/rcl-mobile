/* SIGN IN – the Portal's email and password (one password for every module). Asked 14-10-2026: "login page attractive hawa,
 * login page war rachana cha logo": the green moving background, the Rachana logo springing in, the card rising up; a wrong
 * password shakes the card.
 * (15-10-2026) "super admin new user banwel test password dila … user la first time swatacha banwaycha asel tr to app madhun pn
 * banau shakel": with the password the Super Admin gave (a new user, or a one-time password) the same screen asks for his own
 * password – the given one, the new one twice – and the app opens. No browser needed.
 * (3.31.0, asked 20-10-2026 with his picture and his photo: "LOGIN PAGE LA VEDIO NKO MAST EKHADA IMAGE ANI PREMIUM LOGIN DESIGN") his
 * site's photo on top with the Rachana logo, RCL ERP and the language (English / मराठी / हिंदी); the sheet: Welcome Back, the email
 * and the password, Remember me (the email kept on this phone), Forgot password?, Sign in; "Build • Manage • Move Forward". */
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart';

import '../core/update.dart';
import '../ui/brand.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/t.dart';

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
  bool _busy = false, _show = false, _remember = true;
  static const kRemember = 'remember_mail';
  String _version = '', _lastErr = '';
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    appVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
    // (3.31.0) Remember me: the email of the last sign-in on this phone
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final m = await SessionScope.read(context).api.keep.read(kRemember);
      if (!mounted || m == null || m.isEmpty || _mail.text.isNotEmpty) return;
      setState(() => _mail.text = m);
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
    final s = SessionScope.read(context);
    await s.api.keep.write(kRemember, _remember ? _mail.text.trim() : null);
    await s.signIn(_mail.text, _pw.text);
    if (mounted) setState(() => _busy = false);
  }

  /// (15-10-2026) his own password: the given one, the new one twice – checked here first, then by the Portal (its rules)
  Future<void> _setOwn() async {
    if (_busy) return;
    if (_given.text.isEmpty || _new.text.isEmpty || _again.text.isEmpty) {
      setState(() => _localErr = bi('Fill all three boxes.', 'तीनही boxes भरा.', '\n'));
      _shake.forward(from: 0);
      return;
    }
    if (_new.text != _again.text) {
      setState(() => _localErr = bi('The two new passwords are not the same.', 'दोन्ही नवीन password सारखे नाहीत.', '\n'));
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

  Future<void> _forgot() => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Forgot your password?'),
          content: const Text('Ask the Super Admin for a one-time password. Sign in with it here – then the app asks for your own password.'),
          actions: [FilledButton(key: const Key('forgot-ok'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );

  /// (3.31.0) English / मराठी / हिंदी – the app in it from here
  Widget _lang() {
    final code = LangScope.of(context).code;
    const names = {'': 'English', 'en': 'English', 'mr': 'मराठी', 'hi': 'हिंदी'};
    return PopupMenuButton<String>(
      key: const Key('login-lang'),
      tooltip: tr('App language'),
      onSelected: (c) => SessionScope.read(context).pickLanguageHere(c),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'en', child: m.Text('English')),
        PopupMenuItem(value: 'mr', child: m.Text('मराठी')),
        PopupMenuItem(value: 'hi', child: m.Text('हिंदी')),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .78), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language_rounded, size: 17, color: C.greenDark),
          const SizedBox(width: 6),
          m.Text(names[code] ?? 'English', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.ink)),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: C.ink),
        ]),
      ),
    );
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
    final mq = MediaQuery.of(context);
    final photoH = (mq.size.height * .42).clamp(280.0, 440.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: C.bg,
        body: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: mq.size.height),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ---------- his site's photo, the logo, the language, RCL ERP ----------
              SizedBox(
                height: photoH,
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset('assets/brand/site_login.jpg', fit: BoxFit.cover, alignment: const Alignment(-.1, .2), filterQuality: FilterQuality.medium, errorBuilder: (_, __, ___) => const ColoredBox(color: C.greenDark)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66FFFFFF), Color(0x00FFFFFF), Color(0x00000000), Color(0xB3141A12)], stops: [0, .3, .55, 1]),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(Sp.edge, mq.padding.top + 12, Sp.edge, 46),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Arrive(
                          anim: _open,
                          at: 0,
                          scale: true,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 18, offset: const Offset(0, 6))]),
                            child: const RachanaLogo(height: 44),
                          ),
                        ),
                        const Spacer(),
                        _lang(),
                      ]),
                      const Spacer(),
                      Arrive(anim: _open, at: .12, child: const m.Text('RCL ERP', style: TextStyle(fontFamily: 'Rubik', fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: .3, shadows: [Shadow(color: Color(0x66000000), blurRadius: 12)]))),
                      Arrive(anim: _open, at: .18, child: const Text('Fleet & Diesel Management', style: TextStyle(fontSize: 15, color: Color(0xF2FFFFFF), fontWeight: FontWeight.w500, shadows: [Shadow(color: Color(0x66000000), blurRadius: 10)]))),
                    ]),
                  ),
                ]),
              ),
              // ---------- the sheet ----------
              Transform.translate(
                offset: const Offset(0, -30),
                child: Arrive(
                  anim: _open,
                  at: .28,
                  rise: 60,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 24, offset: const Offset(0, -6))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      widget.setPassword ? _pwCard(err) : _card(err),
                      const SizedBox(height: 18),
                      if (widget.setPassword)
                        Text('One password for the Portal and every module – the same on the web.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
                      SizedBox(height: 70, child: CustomPaint(painter: _Skyline(), child: const Center(child: Text('Build  •  Manage  •  Move Forward', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.muted, letterSpacing: .4))))),
                      if (_version.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Version $_version', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: C.faint))),
                    ]),
                  ),
                ),
              ),
            ]),
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
          decoration: InputDecoration(labelText: tr(label), prefixIcon: Icon(icon)),
        ),
      );

  /// (15-10-2026) the first sign-in with a given password: his own password, here in the app
  Widget _pwCard(String err) => AnimatedBuilder(
        animation: _shake,
        builder: (_, ch) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0), child: ch),
        child: Container(
          padding: EdgeInsets.zero, // (3.31.0) in the sheet itself
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Set your own password', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: C.ink)),
            const MrLine('तुमचा स्वतःचा password बनवा', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 16, fontWeight: FontWeight.w600, color: C.ink)),
            const SizedBox(height: 6),
            const Text('Type the password you were given, then your new password twice.', style: TextStyle(fontSize: 14, color: C.muted)),
            const MrLine('दिलेला password टाका, मग तुमचा नवीन password दोन वेळा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13.5, color: C.muted)),
            const SizedBox(height: 6),
            _pwBox(_given, Lang.i.chosen ? tr('Given password') : 'Given password (दिलेला)', Icons.key_rounded),
            _pwBox(_new, Lang.i.chosen ? tr('New password') : 'New password (नवीन)', Icons.lock_outline_rounded),
            _pwBox(_again, Lang.i.chosen ? tr('New password again') : 'New password again (परत)', Icons.lock_reset_rounded, next: TextInputAction.go, go: _setOwn),
            Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(bi('At least 8 characters, letters and numbers.', 'किमान 8 अक्षरे – अक्षरे आणि अंक दोन्ही.', '\n'), style: TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
                ),
              ),
              IconButton(tooltip: tr(_show ? 'Hide passwords' : 'Show passwords'), icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _show = !_show)),
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
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Welcome Back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: C.ink)),
            const SizedBox(height: 2),
            const Text('Sign in to continue to RCL ERP', style: TextStyle(fontSize: 14, color: C.muted)),
            const MrLine('Portal चाच email आणि password वापरा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: C.muted)),
            const SizedBox(height: 18),
            TextField(
              controller: _mail,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              onSubmitted: (_) => _pwFocus.requestFocus(),
              decoration: InputDecoration(labelText: tr('Email address'), prefixIcon: const Icon(Icons.mail_outline_rounded)),
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
                labelText: tr('Password'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(tooltip: tr(_show ? 'Hide password' : 'Show password'), icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _show = !_show)),
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              SizedBox(
                width: 34,
                height: 40,
                child: Checkbox(key: const Key('login-remember'), value: _remember, activeColor: C.green, onChanged: (v) => setState(() => _remember = v ?? false)),
              ),
              GestureDetector(onTap: () => setState(() => _remember = !_remember), child: const Text('Remember me', style: TextStyle(fontSize: 13.5, color: C.ink))),
              const Spacer(),
              TextButton(
                key: const Key('login-forgot'),
                onPressed: _forgot,
                style: TextButton.styleFrom(foregroundColor: C.gold, padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: const Text('Forgot password?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: C.gold)),
              ),
            ]),
            _errBox(err),
            const SizedBox(height: 14),
            _SignInButton(busy: _busy, onTap: _go),
          ]),
        ),
      );
}

/// (3.31.0) a faint line of a city and a crane under "Build • Manage • Move Forward"
class _Skyline extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = C.gold.withValues(alpha: .16);
    final base = s.height;
    final r = math.Random(7);
    var x = 0.0;
    while (x < s.width) {
      final w = 10 + r.nextDouble() * 18, h = 10 + r.nextDouble() * 34;
      if (x < s.width * .3 || x > s.width * .7) c.drawRect(Rect.fromLTWH(x, base - h, w - 2, h), p);
      x += w;
    }
    final line = Paint()
      ..color = C.gold.withValues(alpha: .22)
      ..strokeWidth = 1.6;
    final cx = s.width * .88;
    c.drawLine(Offset(cx, base), Offset(cx, base - 54), line);
    c.drawLine(Offset(cx - 30, base - 50), Offset(cx + 14, base - 50), line);
    c.drawLine(Offset(cx - 26, base - 50), Offset(cx - 26, base - 34), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
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
