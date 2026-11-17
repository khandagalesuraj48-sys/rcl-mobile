/* SIGN IN – the Portal's email and password (one password for every module). Asked 14-10-2026: "login page attractive hawa,
 * login page war rachana cha logo": the green moving background, the Rachana logo springing in, the card rising up; a wrong
 * password shakes the card.
 * (15-10-2026) "super admin new user banwel test password dila … user la first time swatacha banwaycha asel tr to app madhun pn
 * banau shakel": with the password the Super Admin gave (a new user, or a one-time password) the same screen asks for his own
 * password – the given one, the new one twice – and the app opens. No browser needed.
 * (3.31.0, asked 20-10-2026 with his picture and his photo: "LOGIN PAGE LA VEDIO NKO MAST EKHADA IMAGE ANI PREMIUM LOGIN DESIGN") his
 * site's photo on top with the Rachana logo, RCL ERP and the language (English / मराठी / हिंदी); the sheet: Welcome Back, the email
 * and the password, Remember me (the email kept on this phone), Forgot password?, Sign in; "Build • Manage • Move Forward".
 * (3.104.0, his rules of 12-11-2026) TWO WAYS IN: under "Sign in" the button "Login with Email OTP" – only when the Portal has
 * it switched on. It turns the card: the e-mail, "Send code", then the 6-digit code that came to his e-mail and "Sign in";
 * "Send again" after the 60 seconds the Portal keeps between two codes; "Continue with Password" turns it back.
 * (3.133.0, the Portal's step 14 – his brief and answers of 17-11-2026) THE THIRD WAY IN: "Login with Mobile OTP" – only when the Portal
 * offers it. +91 and his number, "Send OTP", then six boxes for the code that came on WhatsApp (typed, pasted or filled in by the
 * phone – six digits sign in at once), "Resend OTP in 60 s", "Change number", "Continue with Password". Switched on but not ready at
 * the Portal: the card says "temporarily unavailable" – the password works as ever. */
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart';

import '../core/api.dart' show ApiError;
import '../core/session.dart' show Session;
import '../core/update.dart';
import '../ui/brand.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/t.dart';
import '../ui/motion.dart';

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
  // (3.104.0) the second way in: a code by e-mail
  final _code = TextEditingController();
  bool _otpOn = false, _otp = false, _sent = false;
  // (3.133.0) the third way in: a code on WhatsApp – 'off' (not there), 'unavailable' (its card says so), 'on'
  String _waState = 'off';
  bool _wa = false;
  final _mob = TextEditingController();
  int _wait = 0;
  Timer? _tick;
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
    // (3.104.0) is "Login with Email OTP" switched on at the Portal? (3.133.0) and "Login with Mobile OTP"? – one question
    // (no answer: the password sign-in as before)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.setPassword) return;
      final o = await SessionScope.read(context).signInOffers();
      if (mounted && (o.otp || o.wa != 'off')) {
        setState(() {
          _otpOn = o.otp;
          _waState = o.wa;
        });
      }
    });
  }

  /// "Send code" / "Send again": the Portal's answer is the same for everybody – the card goes on to the code.
  Future<void> _otpAsk() async {
    if (_busy) return;
    if (_mail.text.trim().isEmpty) {
      _shake.forward(from: 0);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _localErr = '';
    });
    final s = SessionScope.read(context);
    try {
      await s.api.keep.write(kRemember, _remember ? _mail.text.trim() : null);
      final w = await s.otpSend(_mail.text);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _code.clear();
      });
      _count(w);
    } on ApiError catch (e) {
      if (mounted) setState(() => _localErr = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _count(int secs) {
    _tick?.cancel();
    setState(() => _wait = secs < 0 ? 0 : secs);
    if (_wait == 0) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _otpGo() async {
    if (_busy) return;
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _localErr = bi('Type the 6-digit code from the e-mail.', 'Email मधला 6 अंकी code टाका.', '\n'));
      _shake.forward(from: 0);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _localErr = '';
    });
    await SessionScope.read(context).otpSignIn(_mail.text, code);
    if (mounted) {
      setState(() {
        _busy = false;
        _code.clear();
      });
    }
  }

  /// (3.133.0) "Send OTP" / "Resend OTP" on WhatsApp: the Portal's answer is the same for every number – the card goes on to the code.
  Future<void> _waAsk() async {
    if (_busy) return;
    final s = SessionScope.read(context);
    if (Session.mobileOf(_mob.text).isEmpty) {
      setState(() => _localErr = bi('Enter your 10-digit mobile number.', '10 अंकी mobile number टाका.', '\n'));
      _shake.forward(from: 0);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _localErr = '';
    });
    try {
      final w = await s.waSend(_mob.text);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _code.clear();
      });
      _count(w);
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'waoff') {
        setState(() => _waState = 'unavailable');
      } else if (e.code == 'wait' && !_sent) {
        setState(() {
          _sent = true;
          _localErr = e.toString();
        });
        _count(60);
      } else {
        setState(() => _localErr = e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// (3.133.0) the six digits from WhatsApp: right → signed in (his sites, as after the password); wrong → said, the boxes empty
  Future<void> _waGo() async {
    if (_busy) return;
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _localErr = bi('Type the 6-digit code from WhatsApp.', 'WhatsApp वर आलेला 6 अंकी code टाका.', '\n'));
      _shake.forward(from: 0);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _localErr = '';
    });
    try {
      await SessionScope.read(context).waSignIn(_mob.text, code);
    } on ApiError catch (_) {
      if (mounted) setState(() => _waState = 'unavailable');
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _code.clear();
      });
    }
  }

  /// (3.133.0) "Login with Mobile OTP": a mobile number typed in the sign-in box is carried over
  void _waOpen() {
    final m = Session.mobileOf(_mail.text);
    if (m.isNotEmpty && _mob.text.isEmpty) _mob.text = '${m.substring(0, 5)} ${m.substring(5)}';
    _way(false, wa: true);
  }

  /// Between the ways in (the e-mail typed stays).
  void _way(bool otp, {bool wa = false}) {
    _tick?.cancel();
    SessionScope.read(context).error = '';
    setState(() {
      _otp = otp;
      _wa = wa;
      _sent = false;
      _wait = 0;
      _localErr = '';
      _code.clear();
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
    _tick?.cancel();
    _code.dispose();
    _mob.dispose();
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

  Future<void> _forgot() => popDialog<void>(
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
                        // (3.99.0, asked 11-11-2026: "rachana name perfect nahiye … kuthe konawar overlap nako") the name on a full white
                        // plate (the photo no longer shows through it); on a narrow phone or with big letters it grows smaller – it
                        // never runs under the language button
                        Expanded(
                          child: Align(alignment: Alignment.topLeft, child: Arrive(
                            anim: _open,
                            at: 0,
                            scale: true,
                            child: Container(
                              key: const Key('login-logo'),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 18, offset: const Offset(0, 6))]),
                              child: const FittedBox(fit: BoxFit.scaleDown, child: ProductMark(size: 44, radius: 12)), // (3.124.0) the product's lion – the client is known only after the sign-in
                            ),
                          )),
                        ),
                        const SizedBox(width: 12),
                        _lang(),
                      ]),
                      const Spacer(),
                      Arrive(anim: _open, at: .12, child: const ProductName(style: TextStyle(fontFamily: 'Rubik', fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: .3, shadows: [Shadow(color: Color(0x66000000), blurRadius: 12)]))),
                      Arrive(anim: _open, at: .18, child: const ProductName(line: true, style: TextStyle(fontSize: 15, color: Color(0xF2FFFFFF), fontWeight: FontWeight.w500, shadows: [Shadow(color: Color(0x66000000), blurRadius: 10)]))),
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
                      widget.setPassword ? _pwCard(err) : (_wa ? _waCard(err) : _otp ? _otpCard(err) : _card(err)),
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
            const ProductName(prefix: 'Sign in to continue to ', style: TextStyle(fontSize: 14, color: C.muted)),
            const MrLine('Portal चाच email किंवा mobile number, आणि password वापरा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: C.muted)),
            const SizedBox(height: 18),
            TextField(
              controller: _mail,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              onSubmitted: (_) => _pwFocus.requestFocus(),
              decoration: InputDecoration(labelText: tr('Email or mobile number'), prefixIcon: const Icon(Icons.person_outline_rounded)),      // (3.119.0, the Portal's step 12) a mobile number signs in too – with the password
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
                style: TextButton.styleFrom(foregroundColor: C.goldInk, padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: const Text('Forgot password?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: C.goldInk)),
              ),
            ]),
            _errBox(err),
            const SizedBox(height: 14),
            _SignInButton(busy: _busy, onTap: _go),
            // (3.104.0) the second way in – only when the Portal has it switched on
            if (_otpOn) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                key: const Key('login-otp'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: C.greenDark, side: const BorderSide(color: C.green), shape: const StadiumBorder()),
                onPressed: _busy ? null : () => _way(true),
                child: const Text('Login with Email OTP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
            // (3.133.0) the third way in – when the Portal offers it
            if (_waState != 'off') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('login-wa'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: C.greenDark, side: const BorderSide(color: C.green), shape: const StadiumBorder()),
                onPressed: _busy ? null : _waOpen,
                icon: const Icon(Icons.phone_iphone_rounded, size: 20),
                label: const Text('Login with Mobile OTP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ),
      );

  /// (3.104.0) the code by e-mail: the e-mail and "Send code"; then the code and "Sign in"
  Widget _otpCard(String err) => AnimatedBuilder(
        animation: _shake,
        builder: (_, ch) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0), child: ch),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Login with Email OTP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.ink)),
          const SizedBox(height: 4),
          const Text('A 6-digit code comes to your registered e-mail. It is valid for 10 minutes and works once.', style: TextStyle(fontSize: 14, color: C.muted, height: 1.35)),
          const MrLine('तुमच्या नोंदलेल्या email वर 6 अंकी code येईल – 10 मिनिटांसाठी, एकदाच.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: C.muted)),
          const SizedBox(height: 16),
          TextField(
            key: const Key('login-otp-mail'),
            controller: _mail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            textInputAction: TextInputAction.done,
            autocorrect: false,
            onChanged: (_) {
              if (_sent) _way(true); // another e-mail: from the first step again
            },
            onSubmitted: (_) {
              if (!_sent) _otpAsk();
            },
            decoration: InputDecoration(labelText: tr('Email address'), prefixIcon: const Icon(Icons.mail_outline_rounded)),
          ),
          if (_sent) ...[
            const SizedBox(height: 10),
            const Text('If this e-mail is registered and verified, a code is on its way to it.', style: TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
            const SizedBox(height: 10),
            TextField(
              key: const Key('login-otp-code'),
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              textInputAction: TextInputAction.go,
              onChanged: (_) {
                if (_localErr.isNotEmpty) setState(() => _localErr = '');
              },
              onSubmitted: (_) => _otpGo(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4),
              decoration: InputDecoration(labelText: tr('6-digit code'), prefixIcon: const Icon(Icons.pin_outlined)),
            ),
          ],
          _errBox(err),
          const SizedBox(height: 14),
          _SignInButton(busy: _busy, onTap: _sent ? _otpGo : _otpAsk, label: _sent ? 'Sign in' : 'Send code'),
          if (_sent)
            TextButton(
              key: const Key('login-otp-again'),
              onPressed: _busy || _wait > 0 ? null : _otpAsk,
              child: Text(_wait > 0 ? 'Send again ($_wait s)' : 'Send again'),
            ),
          TextButton(key: const Key('login-otp-back'), onPressed: _busy ? null : () => _way(false), child: const Text('Continue with Password')),
        ]),
      );

  /// (3.133.0) the code on WhatsApp: +91 and the number, "Send OTP"; then the six boxes and "Verify & sign in"
  Widget _waCard(String err) {
    final m = Session.mobileOf(_mob.text), off = _waState != 'on';
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, ch) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0), child: ch),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Login with Mobile OTP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.ink)),
        const SizedBox(height: 4),
        if (off) ...[
          // switched on at the Portal but not ready: nothing to send – the password works as ever
          Container(
            key: const Key('login-wa-off'),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(16)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mobile OTP login is temporarily unavailable.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.amber)),
              SizedBox(height: 4),
              Text('Please sign in with your password.', style: TextStyle(fontSize: 14, color: C.ink, height: 1.35)),
              MrLine('Mobile OTP login सध्या उपलब्ध नाही – कृपया password ने sign in करा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: C.muted)),
            ]),
          ),
          const SizedBox(height: 10),
        ] else if (!_sent) ...[
          const Text('A 6-digit code comes on WhatsApp to your registered mobile number. It is valid for 5 minutes and works once.', style: TextStyle(fontSize: 14, color: C.muted, height: 1.35)),
          const MrLine('तुमच्या नोंदलेल्या mobile number वर WhatsApp वर 6 अंकी code येईल – 5 मिनिटांसाठी, एकदाच.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: C.muted)),
          const SizedBox(height: 16),
          TextField(
            key: const Key('login-wa-mobile'),
            controller: _mob,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')), LengthLimitingTextInputFormatter(16)],
            textInputAction: TextInputAction.done,
            autocorrect: false,
            onChanged: (_) {
              if (_localErr.isNotEmpty) setState(() => _localErr = '');
            },
            onSubmitted: (_) => _waAsk(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: .5),
            decoration: InputDecoration(
              labelText: tr('Mobile number'),
              prefixIcon: const Padding(padding: EdgeInsets.fromLTRB(16, 0, 10, 0), child: Text('+91', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink))),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
        ] else ...[
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Text('If +91 ${m.isEmpty ? _mob.text.trim() : '${m.substring(0, 5)} ${m.substring(5)}'} is registered, the code is on its way on WhatsApp.', style: const TextStyle(fontSize: 13.5, color: C.muted, height: 1.35))),
            TextButton(key: const Key('login-wa-change'), onPressed: _busy ? null : () => _way(false, wa: true), child: const Text('Change number')),
          ]),
          const SizedBox(height: 10),
          _SixBoxes(
            fieldKey: const Key('login-wa-code'),
            controller: _code,
            bad: _localErr.isNotEmpty || SessionScope.of(context).error.isNotEmpty,
            onChanged: () {
              final s = SessionScope.read(context);
              if (_localErr.isNotEmpty || s.error.isNotEmpty) {
                s.error = '';
                setState(() => _localErr = '');
              }
            },
            onDone: _waGo,
          ),
        ],
        if (!off) ...[
          _errBox(err),
          const SizedBox(height: 14),
          _SignInButton(busy: _busy, onTap: _sent ? _waGo : _waAsk, label: _sent ? 'Verify & sign in' : 'Send OTP'),
          if (_sent)
            TextButton(
              key: const Key('login-wa-again'),
              onPressed: _busy || _wait > 0 ? null : _waAsk,
              child: Text(_wait > 0 ? 'Resend OTP in $_wait s' : 'Resend OTP'),
            ),
        ],
        TextButton(key: const Key('login-wa-back'), onPressed: _busy ? null : () => _way(false), child: const Text('Continue with Password')),
      ]),
    );
  }
}

/// (3.133.0) SIX BOXES for the code from WhatsApp – one box a digit. One hidden field lies over them, so the phone can fill the code in
/// by itself, a long press pastes it (WhatsApp's "Copy code" gives "123456"; anything else around the digits is dropped), and six digits
/// sign in at once.
class _SixBoxes extends StatefulWidget {
  const _SixBoxes({required this.fieldKey, required this.controller, required this.onDone, this.onChanged, this.bad = false});
  final Key fieldKey;
  final TextEditingController controller;
  final VoidCallback onDone;
  final VoidCallback? onChanged;
  final bool bad;
  @override
  State<_SixBoxes> createState() => _SixBoxesState();
}

class _SixBoxesState extends State<_SixBoxes> {
  final _focus = FocusNode();

  void _again() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_again);
    _focus.addListener(_again);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant _SixBoxes old) {
    super.didUpdateWidget(old);
    if (widget.bad && !old.bad) _focus.requestFocus(); // a wrong code: straight back to the first box
  }

  @override
  void dispose() {
    widget.controller.removeListener(_again);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.controller.text, at = t.length.clamp(0, 5);
    return Semantics(
      label: tr('6-digit code'),
      child: SizedBox(
        height: 60,
        child: Stack(children: [
          Row(children: [
            for (var i = 0; i < 6; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(width: _focus.hasFocus && i == at ? 2 : 1.4, color: widget.bad ? C.red : (_focus.hasFocus && i == at ? C.green : C.line)),
                    ),
                    child: m.Text(i < t.length ? t[i] : '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.ink)),
                  ),
                ),
              ),
          ]),
          Positioned.fill(
            child: TextField(
              key: widget.fieldKey,
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              showCursor: false,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              // (no border, no fill of the app's theme – only the six boxes are seen)
              decoration: const InputDecoration(
                isCollapsed: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
              onChanged: (v) {
                widget.onChanged?.call();
                if (v.length == 6) widget.onDone();
              },
              onSubmitted: (_) => widget.onDone(),
            ),
          ),
        ]),
      ),
    );
  }
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
          gradient: const LinearGradient(colors: [C.green, C.greenBright]),
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
