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
 * (3.154.0, his choice of 21-11-2026: "login p1 choose krel mi ekdam perfect aahe"; "aplela to jcb lawaycha nahiye") THE CREST: the
 * navy with its fine gold survey lines, the language pill, the lion in its round gold ring, the product's name and its line, the
 * gold wave; under it "Sign in" with its gold line, the boxes (each with its name above it), Remember me, Forgot password?, the
 * gold "Sign in", "or", "Login with Email OTP", "Build • Manage • Move Forward", the version. No photo. Light when the phone is
 * light, dark when it is dark. Everything the sign-in did stays exactly as it was. */
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart';

import '../core/api.dart' show ApiError;
import '../core/update.dart';
import '../ui/brand.dart';
import '../ui/crest.dart';
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
  /// (3.161.0) the sheet under the crest and its height as drawn – the crest takes the rest of the screen
  final _sheetKey = GlobalKey();
  double _sheetH = 0;

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
    // (3.104.0) is "Login with Email OTP" switched on at the Portal? (no answer: the password sign-in as before)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.setPassword) return;
      final on = await SessionScope.read(context).otpOffered();
      if (mounted && on) setState(() => _otpOn = true);
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

  /// Between the two ways in (the e-mail typed stays).
  void _way(bool otp) {
    _tick?.cancel();
    SessionScope.read(context).error = '';
    setState(() {
      _otp = otp;
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

  /// (3.31.0) English / मराठी / हिंदी – the app in it from here: a glass pill on the navy
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
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: .34))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language_rounded, size: 17, color: Colors.white),
          const SizedBox(width: 7),
          m.Text(names[code] ?? 'English', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white),
        ]),
      ),
    );
  }

  /// The page's own colours: light or dark, as the phone is.
  _Look _l = const _Look(false);

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
    final l = _l = _Look(mq.platformBrightness == Brightness.dark);
    /* (3.161.0, asked 21-11-2026: "app che login page scroll nahi zal pahije – ata te scroll hotey") THE PAGE FITS THE SCREEN: the crest
     * takes what the sheet leaves (the sheet is measured after it is drawn), so the page is exactly as high as the screen and does not
     * scroll. It scrolls only while the keyboard is open, or on a phone too small for the sheet and the smallest crest together. */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = _sheetKey.currentContext?.size?.height;
      if (h != null && (h - _sheetH).abs() > 1 && mounted) setState(() => _sheetH = h);
    });
    final headH = (_sheetH > 0 ? (mq.size.height - _sheetH).clamp(200.0 + mq.padding.top, 440.0 + mq.padding.top) : (mq.size.height * .44).clamp(330.0, 440.0) + mq.padding.top).toDouble(), small = headH - mq.padding.top < 270, lion = (headH - mq.padding.top) * (small ? .30 : .36);
    final lionTop = mq.padding.top + ((headH - mq.padding.top) * .115).clamp(small ? 18.0 : 24.0, 50.0);
    /* (3.162.0, asked 21-11-2026: "login page ajun pn scroll krtey … thode pn scroll nahi zal pahije") the crest may now grow as small as
     * 200 (the lion and the name grow smaller with it), so the sheet with "Login with Email OTP" fits a shorter phone too; and while
     * the page fits and no keyboard is open it cannot be moved at all. */
    final fits = _sheetH > 0 && mq.viewInsets.bottom == 0 && headH + _sheetH <= mq.size.height + 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent), // (the navy is at the top in both)
      child: Theme(
        // (the boxes, the cursor and what is typed follow the page – dark on a dark phone)
        data: Theme.of(context).copyWith(
          textSelectionTheme: TextSelectionThemeData(cursorColor: l.gold, selectionColor: kCrestGold.withValues(alpha: .35), selectionHandleColor: kCrestGold),
          inputDecorationTheme: const InputDecorationTheme(),
        ),
        child: Scaffold(
          backgroundColor: l.page,
          body: SingleChildScrollView(
            physics: fits ? const NeverScrollableScrollPhysics() : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: mq.size.height),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ---------- the crest: the navy with its survey lines, the language, the lion, the name, the gold wave ----------
                SizedBox(
                  height: headH,
                  child: Stack(fit: StackFit.expand, children: [
                    DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: l.head, stops: const [0, .5, 1]))),
                    RepaintBoundary(child: CustomPaint(painter: CrestLines(eddy: Offset(mq.size.width / 2, lionTop + lion / 2), ring: lion, color: kCrestGold.withValues(alpha: .3), depth: 1))),
                    CustomPaint(painter: CrestWave(top: headH - 64, rise: 44, fill: l.page, broad: true)),
                    Positioned(top: mq.padding.top + 10, right: Sp.edge, child: _lang()),
                    Positioned(
                      top: lionTop,
                      left: 16,
                      right: 16,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Arrive(anim: _open, at: 0, scale: true, child: CrestLion(key: const Key('login-logo'), size: lion, dark: true)), // (3.124.0) the product's lion – the client is known only after the sign-in
                        SizedBox(height: small ? 8 : 14),
                        Arrive(anim: _open, at: .12, child: ProductName(style: TextStyle(fontFamily: 'Montserrat', fontSize: small ? 25 : 34, fontWeight: FontWeight.w800, color: Colors.white, height: 1.05, shadows: const [Shadow(color: Color(0x66000000), blurRadius: 12)]))),
                        const SizedBox(height: 6),
                        Arrive(anim: _open, at: .18, child: const FittedBox(fit: BoxFit.scaleDown, child: ProductName(line: true, upper: true, style: TextStyle(fontFamily: 'Montserrat', fontSize: 13, color: kCrestGold, fontWeight: FontWeight.w800, letterSpacing: 3.6)))), // (a long line grows smaller – never cut)
                      ]),
                    ),
                  ]),
                ),
                // ---------- the sheet ----------
                Arrive(
                  key: _sheetKey,
                  anim: _open,
                  at: .28,
                  rise: 40,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      widget.setPassword ? _pwCard(err) : (_otp ? _otpCard(err) : _card(err)),
                      const SizedBox(height: 16),
                      if (widget.setPassword) ...[
                        Text('One password for the Portal and every module – the same on the web.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: l.muted, height: 1.35)),
                        const SizedBox(height: 14),
                      ],
                      Text('Build  •  Manage  •  Move Forward', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: l.faint, letterSpacing: .6)),
                      if (_version.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Version $_version', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: l.faint))),
                      SizedBox(height: mq.padding.bottom),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// The title of a card with its gold line.
  Widget _title(String en, {Key? key}) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(en, key: key, style: TextStyle(fontFamily: 'Montserrat', fontSize: 28, fontWeight: FontWeight.w800, color: _l.ink, height: 1.1)),
        const SizedBox(height: 8),
        Container(width: 44, height: 4, decoration: BoxDecoration(gradient: kCrestGoldFill, borderRadius: BorderRadius.circular(2))),
      ]);

  /// The small name above a box.
  Widget _lab(String en) => Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 7), child: Text(en, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _l.muted)));

  /// A box of the page: round, of the page's own card colour, its sign in front.
  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) {
    final l = _l;
    OutlineInputBorder edge(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: tr(hint),
      hintStyle: TextStyle(color: l.faint, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: l.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      prefixIcon: Icon(icon, color: l.muted),
      prefixIconColor: l.muted,
      suffixIcon: suffix,
      suffixIconColor: l.faint,
      border: edge(l.line),
      enabledBorder: edge(l.line),
      focusedBorder: edge(kCrestGold, 1.6),
    );
  }

  TextStyle get _typed => TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _l.ink);

  Widget _errBox(String err) => AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: err.isEmpty
            ? const SizedBox(width: double.infinity)
            : Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: _l.dark ? const Color(0x33E5484D) : C.redSoft, borderRadius: BorderRadius.circular(16)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.error_outline_rounded, size: 20, color: _l.bad),
                  const SizedBox(width: 10),
                  Expanded(child: Text(err, style: TextStyle(color: _l.bad, fontSize: 14, fontWeight: FontWeight.w500, height: 1.35))),
                ]),
              ),
      );

  Widget _pwBox(TextEditingController c, String label, IconData icon, {TextInputAction next = TextInputAction.next, VoidCallback? go}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _lab(label),
        TextField(
          controller: c,
          obscureText: !_show,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: next,
          style: _typed,
          onChanged: (_) {
            if (_localErr.isNotEmpty) setState(() => _localErr = '');
          },
          onSubmitted: (_) => go == null ? FocusScope.of(context).nextFocus() : go(),
          decoration: _dec(label, icon),
        ),
      ]);

  Widget _shaken(Widget child) => AnimatedBuilder(
        animation: _shake,
        builder: (_, ch) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0), child: ch),
        child: child,
      );

  Widget _link(String en, {required Key key, required VoidCallback? onTap}) => TextButton(
        key: key,
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: _l.gold, disabledForegroundColor: _l.faint, padding: const EdgeInsets.symmetric(horizontal: 6)),
        child: Text(en, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );

  /// (15-10-2026) the first sign-in with a given password: his own password, here in the app
  Widget _pwCard(String err) => _shaken(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Set your own password'),
        const SizedBox(height: 8),
        MrLine('तुमचा स्वतःचा password बनवा', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 16, fontWeight: FontWeight.w600, color: _l.ink)),
        const SizedBox(height: 4),
        Text('Type the password you were given, then your new password twice.', style: TextStyle(fontSize: 14, color: _l.muted)),
        MrLine('दिलेला password टाका, मग तुमचा नवीन password दोन वेळा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13.5, color: _l.muted)),
        _pwBox(_given, 'Given password', Icons.key_rounded),
        _pwBox(_new, 'New password', Icons.lock_outline_rounded),
        _pwBox(_again, 'New password again', Icons.lock_reset_rounded, next: TextInputAction.go, go: _setOwn),
        Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(bi('At least 8 characters, letters and numbers.', 'किमान 8 अक्षरे – अक्षरे आणि अंक दोन्ही.', '\n'), style: TextStyle(fontSize: 12.5, color: _l.muted, height: 1.35)),
            ),
          ),
          IconButton(tooltip: tr(_show ? 'Hide passwords' : 'Show passwords'), color: _l.muted, icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _show = !_show)),
        ]),
        _errBox(err),
        const SizedBox(height: 18),
        _SignInButton(busy: _busy, onTap: _setOwn, label: 'Save and open'),
        const SizedBox(height: 6),
        _link('Back to sign in', key: const Key('login-back'), onTap: _busy ? null : () => SessionScope.read(context).leaveSetPassword()),
      ]));

  Widget _card(String err) => _shaken(AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Sign in', key: const Key('login-title')),
          const SizedBox(height: 10),
          Text('Welcome back – sign in to continue', style: TextStyle(fontSize: 15, color: _l.muted)),
          MrLine('Portal चाच email किंवा mobile number, आणि password वापरा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: _l.muted)),
          const SizedBox(height: 4),
          _lab('Email or mobile number'), // (3.119.0, the Portal's step 12) a mobile number signs in too – with the password
          TextField(
            controller: _mail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            textInputAction: TextInputAction.next,
            autocorrect: false,
            style: _typed,
            onSubmitted: (_) => _pwFocus.requestFocus(),
            decoration: _dec('name@company.com', Icons.person_outline_rounded),
          ),
          _lab('Password'),
          TextField(
            controller: _pw,
            focusNode: _pwFocus,
            obscureText: !_show,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.go,
            style: _typed,
            onSubmitted: (_) => _go(),
            decoration: _dec('Enter your password', Icons.lock_outline_rounded,
                suffix: IconButton(tooltip: tr(_show ? 'Hide password' : 'Show password'), icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _show = !_show))),
          ),
          const SizedBox(height: 10),
          Row(children: [
            // (3.31.0) Remember me: the email of the last sign-in kept on this phone
            Semantics(
              checked: _remember,
              child: GestureDetector(
                key: const Key('login-remember'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _remember = !_remember),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: _remember ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kCrestGoldPale, kCrestGold]) : null,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _remember ? kCrestGold : _l.faint, width: 1.5),
                      ),
                      child: _remember ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF2A1D00)) : null,
                    ),
                    const SizedBox(width: 10),
                    Text('Remember me', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _l.ink)),
                  ]),
                ),
              ),
            ),
            const Spacer(),
            _link('Forgot password?', key: const Key('login-forgot'), onTap: _forgot),
          ]),
          _errBox(err),
          const SizedBox(height: 16),
          _SignInButton(busy: _busy, onTap: _go),
          // (3.104.0) the second way in – only when the Portal has it switched on
          if (_otpOn) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Container(height: 1, color: _l.line)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _l.faint))),
              Expanded(child: Container(height: 1, color: _l.line)),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('login-otp'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), foregroundColor: _l.ink, side: BorderSide(color: _l.dark ? kCrestGold.withValues(alpha: .7) : _l.ink, width: 1.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
              onPressed: _busy ? null : () => _way(true),
              icon: const Icon(Icons.mail_outline_rounded, size: 20),
              label: const Text('Login with Email OTP', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ));

  /// (3.104.0) the code by e-mail: the e-mail and "Send code"; then the code and "Sign in"
  Widget _otpCard(String err) => _shaken(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Login with Email OTP'),
        const SizedBox(height: 10),
        Text('A 6-digit code comes to your registered e-mail. It is valid for 10 minutes and works once.', style: TextStyle(fontSize: 14, color: _l.muted, height: 1.35)),
        MrLine('तुमच्या नोंदलेल्या email वर 6 अंकी code येईल – 10 मिनिटांसाठी, एकदाच.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: _l.muted)),
        const SizedBox(height: 2),
        _lab('Email address'),
        TextField(
          key: const Key('login-otp-mail'),
          controller: _mail,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          textInputAction: TextInputAction.done,
          autocorrect: false,
          style: _typed,
          onChanged: (_) {
            if (_sent) _way(true); // another e-mail: from the first step again
          },
          onSubmitted: (_) {
            if (!_sent) _otpAsk();
          },
          decoration: _dec('name@company.com', Icons.mail_outline_rounded),
        ),
        if (_sent) ...[
          const SizedBox(height: 10),
          Text('If this e-mail is registered and verified, a code is on its way to it.', style: TextStyle(fontSize: 13, color: _l.muted, height: 1.35)),
          _lab('6-digit code'),
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4, color: _l.ink),
            decoration: _dec('', Icons.pin_outlined),
          ),
        ],
        _errBox(err),
        const SizedBox(height: 16),
        _SignInButton(busy: _busy, onTap: _sent ? _otpGo : _otpAsk, label: _sent ? 'Sign in' : 'Send code'),
        if (_sent) _link(_wait > 0 ? 'Send again ($_wait s)' : 'Send again', key: const Key('login-otp-again'), onTap: _busy || _wait > 0 ? null : _otpAsk),
        _link('Continue with Password', key: const Key('login-otp-back'), onTap: _busy ? null : () => _way(false)),
      ]));
}

/// The colours of the sign-in: light or dark, as the phone is (the navy at the top is in both).
class _Look {
  const _Look(this.dark);
  final bool dark;
  Color get page => dark ? const Color(0xFF0B1024) : const Color(0xFFFAFAFC);
  Color get card => dark ? const Color(0xFF151B33) : Colors.white;
  Color get line => dark ? const Color(0xFF2B3454) : const Color(0xFFE1E5EF);
  Color get ink => dark ? const Color(0xFFF4F6FC) : const Color(0xFF0F1830);
  Color get muted => dark ? const Color(0xFFA7B0CA) : const Color(0xFF59647E);
  Color get faint => dark ? const Color(0xFF727B9A) : const Color(0xFF98A1B8);
  Color get gold => dark ? kCrestGold : const Color(0xFFA9741A);
  Color get bad => dark ? const Color(0xFFFF9A92) : C.red;
  List<Color> get head => dark ? const [Color(0xFF080B1C), Color(0xFF161B36), Color(0xFF1D2F74)] : const [Color(0xFF0E1638), Color(0xFF1A2C68), Color(0xFF21398A)];
}

/// The big gold button; while signing in it shows a turning ring.
class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.busy, required this.onTap, this.label = 'Sign in'});
  final bool busy;
  final VoidCallback onTap;
  final String label;
  static const _ink = Color(0xFF2A1D00);
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          // (the shine: a pale streak across the gold)
          gradient: const LinearGradient(begin: Alignment(-1, -.6), end: Alignment(1, .6), colors: [Color(0xFFF3D477), Color(0xFFE9C45A), Color(0xFFF9E7AE), Color(0xFFE2B548), Color(0xFFBE8A14)], stops: [0, .18, .26, .5, 1]),
          boxShadow: [BoxShadow(color: kCrestGoldDeep.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 9))],
        ),
        child: FilledButton(
          key: const Key('login-go'),
          style: FilledButton.styleFrom(backgroundColor: Colors.transparent, disabledBackgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: _ink, minimumSize: const Size.fromHeight(58), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
          onPressed: busy ? null : onTap,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: busy
                ? const SizedBox(key: ValueKey('busy'), width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: _ink))
                : Row(key: const ValueKey('go'), mainAxisSize: MainAxisSize.min, children: [
                    Text(label, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, color: _ink),
                  ]),
          ),
        ),
      );
}
