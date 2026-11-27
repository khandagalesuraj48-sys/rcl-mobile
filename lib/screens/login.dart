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
 * light, dark when it is dark. Everything the sign-in did stays exactly as it was.
 * (3.166.0, the Portal's "Login with WhatsApp OTP" of 22-11-2026 and his design A; asked: "otp takla auto verify sign in button
 * dabayla lagu naye … web and app doni sathi") THE CODE BY WHATSAPP: when the Portal has it switched on the sheet OPENS on it – the
 * mobile number, "Send code on WhatsApp", then the six boxes. No button: the sixth digit checks the code by itself (the boxes run
 * into one bar with a light passing, then it fills green and a ✓ – straight in); a wrong code shakes red and the boxes empty from
 * the right. "Copy code" in WhatsApp and back to the app: the code fills by itself (Android), or "Paste code". "Use email and
 * password" is always one tap away and leads to the password card (its "Login with Email OTP" stays). Switched off: as before.
 * (25-11-2026, his words: "login with otp krtan given password nko aahe new set kru shakel … forgot kru shkel email la otp yeil … resend
 * 6 time tya nantr 15 minute cha block … remaining kiti sangitle jail"; his answers: 6 codes, 6 wrong codes, "Forgot password" for
 * everybody but the Super Admin) signed in with a code, "Set your own password" asks only the new password twice; "Forgot password?"
 * (when the e-mail code is switched on) turns the card: the e-mail, "Send code", then the code and the new password twice – the
 * Portal sets it and the app opens; after every code sent, how many more may be asked for; a wrong code, how many tries are left;
 * blocked, the minutes to wait (core/code_words.dart – the Portal counts). The e-mail code switched off: the help of before. */
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart';

import '../core/api.dart' show ApiError;
import '../core/code_words.dart';
import '../core/update.dart';
import '../ui/brand.dart';
import '../ui/code_boxes.dart';
import '../ui/crest.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/t.dart';
import '../ui/motion.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.setPassword = false, this.askCompany = false});

  /// His first sign-in with a given password: the card asks for his own password.
  final bool setPassword;

  /// (3.173.0, the approved design "LION – Modules & Subscription", board 1) no company code on this phone yet: the card asks it
  /// first ("Only your company's sign-in opens"); the sign-in card comes after it.
  final bool askCompany;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
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
  // (25-11-2026) "Forgot password?": the e-mail code and the new password (the boxes of "Set your own password" – [_new], [_again])
  final _rCode = TextEditingController();
  bool _reset = false, _rSent = false;
  int _wait = 0;
  Timer? _tick;
  // (3.166.0) the third way in: a code by WhatsApp – the sheet opens on it when the Portal has it switched on
  final _mob = TextEditingController(), _waCode = TextEditingController();
  final _waFocus = FocusNode();
  bool _waOn = false, _wa = false, _waSent = false, _clearing = false;
  CodeState _cs = CodeState.idle;
  String _waTo = '', _waSay = '', _pasted = '';
  Timer? _auto;
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
    // (3.166.0) and "Login with WhatsApp OTP": switched on, the sheet opens on it – unless he has started on another card
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.setPassword) return;
      final w = await SessionScope.read(context).signInWays();
      if (!mounted) return;
      setState(() {
        _otpOn = w.otp;
        _waOn = w.wa;
        if (w.wa && !_otp && !_busy && _pw.text.isEmpty) _wa = true;
      });
    });
    _waCode.addListener(_waTyped);
    WidgetsBinding.instance.addObserver(this);
  }

  /// (3.166.0) Back from WhatsApp (where he tapped "Copy code"): the code copied fills the boxes by itself – Android only (an iPhone
  /// asks "Allow Paste?" for every look at the clipboard: there "Paste code").
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _paste(auto: true);
  }

  /// The 10 digits of an Indian mobile number typed in any usual way (+91…, 0…, spaces) – null when it is not one.
  static String? waMobile(String v) {
    var t = v.replaceAll(RegExp(r'[\s\-().]'), '');
    if (RegExp(r'^\+?91[6-9]\d{9}$').hasMatch(t)) {
      t = t.substring(t.length - 10);
    } else if (RegExp(r'^0[6-9]\d{9}$').hasMatch(t)) {
      t = t.substring(1);
    }
    return RegExp(r'^[6-9]\d{9}$').hasMatch(t) ? t : null;
  }

  /// "Send code on WhatsApp" / "Send again": the Portal's answer is the same for everybody – the card goes on to the six boxes.
  Future<void> _waAsk() async {
    if (_busy) return;
    final mob = waMobile(_waSent ? _waTo : _mob.text);
    if (mob == null) {
      setState(() => _localErr = bi('Enter your 10-digit mobile number.', 'तुमचा 10 अंकी मोबाइल नंबर टाका.', '\n'));
      _shake.forward(from: 0);
      return;
    }
    FocusScope.of(context).unfocus();
    SessionScope.read(context).error = '';
    setState(() {
      _busy = true;
      _localErr = '';
    });
    try {
      final w = await SessionScope.read(context).waSend(mob);
      if (!mounted) return;
      _auto?.cancel();
      setState(() {
        _waSent = true;
        _waTo = mob;
        _cs = CodeState.idle;
        _waSay = '';
        _waCode.clear();
      });
      _count(w);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _waSent) _waFocus.requestFocus();
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _localErr = codeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A digit typed, pasted or filled: the sixth checks the code by itself (no button). A new digit after a wrong code: red goes.
  void _waTyped() {
    if (!mounted) return;
    final t = _waCode.text;
    setState(() {
      if (_cs == CodeState.bad && t.isNotEmpty && !_clearing) {
        _cs = CodeState.idle;
        _waSay = '';
      }
    });
    if (t.length == 6 && _cs == CodeState.idle && !_busy && _waSent && !_clearing) {
      _auto?.cancel();
      _auto = Timer(const Duration(milliseconds: 160), _waGo);
    }
  }

  /// The six digits are checked by the Portal: right – the bar fills green, ✓, straight in; wrong – it shakes red and empties.
  Future<void> _waGo() async {
    final code = _waCode.text;
    if (_busy || !_waSent || code.length != 6 || _cs != CodeState.idle) return;
    final still = MediaQuery.of(context).disableAnimations, s = SessionScope.read(context), sw = Stopwatch()..start();
    s.error = '';
    setState(() {
      _busy = true;
      _cs = CodeState.checking;
      _localErr = '';
      _waSay = '';
    });
    Future<void> hold(int ms) async {
      final left = still ? 0 : ms - sw.elapsedMilliseconds;
      if (left > 0) await Future<void>.delayed(Duration(milliseconds: left));
    }

    bool must;
    try {
      must = await s.waCheck(_waTo, code);
    } on ApiError catch (e) {
      await hold(650);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _cs = CodeState.bad;
        _waSay = codeError(e); // (25-11-2026) the tries left; blocked: the minutes to wait
        _busy = false;
        _clearing = true;
      });
      if (!still) _shake.forward(from: 0);
      // the boxes empty from the right, one by one – then he types again
      if (!still) await Future<void>.delayed(const Duration(milliseconds: 520));
      while (mounted && _waCode.text.isNotEmpty) {
        final t = _waCode.text.substring(0, _waCode.text.length - 1);
        _waCode.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
        if (!still) await Future<void>.delayed(const Duration(milliseconds: 70));
      }
      if (!mounted) return;
      setState(() => _clearing = false);
      _waFocus.requestFocus();
      return;
    }
    await hold(650);
    if (!mounted) return;
    _tick?.cancel();
    HapticFeedback.lightImpact();
    setState(() => _cs = CodeState.ok);
    await Future<void>.delayed(Duration(milliseconds: still ? 250 : 1050));
    if (!mounted) return;
    await s.waFinish(must);
    if (!mounted) return;
    setState(() {
      // (still here: his own password is asked first, or the sites could not be read – the message is on the card)
      _busy = false;
      _cs = CodeState.idle;
      _waSent = false;
      _wait = 0;
      _waCode.clear();
    });
  }

  /// "Paste code" – or, by itself, back from WhatsApp: a code copied there goes into the six boxes (and checks itself).
  Future<void> _paste({bool auto = false}) async {
    if (!_wa || !_waSent || _busy || _clearing || _cs == CodeState.checking || _cs == CodeState.ok) return;
    if (auto && (_waCode.text.isNotEmpty || defaultTargetPlatform != TargetPlatform.android)) return;
    var t = '';
    try {
      t = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    } catch (_) {/* nothing on the clipboard to read */}
    if (!mounted) return;
    // by itself only a copied code (WhatsApp's "Copy code" copies just the six digits) – and never the same one twice
    final d = auto ? (RegExp(r'^\s*(\d{6})\s*$').firstMatch(t)?.group(1) ?? '') : (RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(t)?.group(0) ?? '');
    if (d.isEmpty || (auto && d == _pasted)) {
      if (!auto) _waFocus.requestFocus();
      return;
    }
    _pasted = d;
    _waCode.value = TextEditingValue(text: d, selection: const TextSelection.collapsed(offset: 6));
  }

  /// Between WhatsApp and the password card (a mobile number typed as the user ID is carried over).
  void _waWay(bool on) {
    _tick?.cancel();
    _auto?.cancel();
    SessionScope.read(context).error = '';
    setState(() {
      _wa = on;
      _otp = false;
      _waSent = false;
      _wait = 0;
      _localErr = '';
      _cs = CodeState.idle;
      _waSay = '';
      _waCode.clear();
      if (on && _mob.text.isEmpty && waMobile(_mail.text) != null) _mob.text = waMobile(_mail.text)!;
    });
  }

  /// "Change": back to the number.
  void _waBack() {
    _tick?.cancel();
    _auto?.cancel();
    SessionScope.read(context).error = '';
    setState(() {
      _waSent = false;
      _wait = 0;
      _localErr = '';
      _cs = CodeState.idle;
      _waSay = '';
      _waCode.clear();
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
      if (mounted) setState(() => _localErr = codeError(e));
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
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _auto?.cancel();
    _waCode.removeListener(_waTyped);
    _mob.dispose();
    _waCode.dispose();
    _waFocus.dispose();
    _code.dispose();
    _co.dispose();
    _rCode.dispose();
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
    final byCode = SessionScope.read(context).byCode; // (25-11-2026) signed in with a code: the given password is not asked
    if ((!byCode && _given.text.isEmpty) || _new.text.isEmpty || _again.text.isEmpty) {
      setState(() => _localErr = byCode ? bi('Type the new password twice.', 'नवीन password दोन वेळा टाका.', '\n') : bi('Fill all three boxes.', 'तीनही boxes भरा.', '\n'));
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
    await SessionScope.read(context).setOwnPassword(byCode ? '' : _given.text, _new.text);
    if (mounted) setState(() => _busy = false);
  }

  /// (25-11-2026) "Forgot password?": with the e-mail code switched on, the forgot card; else the help of before.
  Future<void> _forgot() async {
    if (!_otpOn) return _forgotHelp();
    _tick?.cancel();
    SessionScope.read(context).error = '';
    setState(() {
      _reset = true;
      _rSent = false;
      _otp = false;
      _wait = 0;
      _localErr = '';
      _rCode.clear();
      _new.clear();
      _again.clear();
      if (!_mail.text.contains('@')) _mail.clear(); // (a mobile number typed: the code goes to an e-mail only)
    });
  }

  /// Back from the forgot card to the password card (the e-mail typed stays).
  void _resetBack() {
    _tick?.cancel();
    SessionScope.read(context).error = '';
    setState(() {
      _reset = false;
      _rSent = false;
      _wait = 0;
      _localErr = '';
      _rCode.clear();
    });
  }

  /// "Send code" / "Send again" of the forgot card: the answer is the same for everybody – the card goes on to the code.
  Future<void> _resetAsk() async {
    if (_busy) return;
    if (!_mail.text.contains('@')) {
      setState(() => _localErr = bi('Enter your e-mail.', 'तुमचा email टाका.', '\n'));
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
      final w = await s.resetSend(_mail.text);
      if (!mounted) return;
      setState(() {
        _rSent = true;
        _rCode.clear();
      });
      _count(w);
    } on ApiError catch (e) {
      if (mounted) setState(() => _localErr = codeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The code and the new password twice: checked here first, then by the Portal (the code, its password rules).
  Future<void> _resetGo() async {
    if (_busy) return;
    final code = _rCode.text.replaceAll(RegExp(r'\D'), '');
    String bad = '';
    if (code.length != 6) {
      bad = bi('Type the 6-digit code from the e-mail.', 'Email मधला 6 अंकी code टाका.', '\n');
    } else if (_new.text.isEmpty || _again.text.isEmpty) {
      bad = bi('Type the new password twice.', 'नवीन password दोन वेळा टाका.', '\n');
    } else if (_new.text != _again.text) {
      bad = bi('The two new passwords are not the same.', 'दोन्ही नवीन password सारखे नाहीत.', '\n');
    }
    if (bad.isNotEmpty) {
      setState(() => _localErr = bad);
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
      await s.resetPassword(_mail.text, code, _new.text);
      if (!mounted) return;
      _tick?.cancel();
      setState(() {
        _reset = false;
        _rSent = false;
        _rCode.clear();
        _new.clear();
        _again.clear();
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _localErr = codeError(e);
        if (e.code != 'policy') _rCode.clear(); // (a weak password costs no code: the code stays)
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotHelp() => popDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Forgot your password?'),
          content: const Text('Ask the Super Admin for a one-time password. Sign in with it here – then the app asks for your own password.'),
          actions: [FilledButton(key: const Key('forgot-ok'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );

  // ---------- (3.173.0) the company code (board 1 of the approved design) ----------
  final _co = TextEditingController();
  bool _coBusy = false;

  Future<void> _coGo() async {
    if (_coBusy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _coBusy = true;
      _localErr = '';
    });
    final why = await SessionScope.read(context).setCompany(_co.text);
    if (!mounted) return;
    setState(() {
      _coBusy = false;
      _localErr = why;
    });
  }

  Widget _coCard(String err) => _shaken(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Company code', key: const Key('co-title')),
        const SizedBox(height: 10),
        Text('Type the code your company gave you. Only your company\'s sign-in opens.', style: TextStyle(fontSize: 15, color: _l.muted, height: 1.35)),
        _lab('Company code'),
        TextField(
          key: const Key('co-code'),
          controller: _co,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.go,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), LengthLimitingTextInputFormatter(20)],
          style: _typed.copyWith(letterSpacing: 2),
          onSubmitted: (_) => _coGo(),
          decoration: _dec('e.g. RCL', Icons.apartment_rounded),
        ),
        _errBox(err),
        const SizedBox(height: 18),
        _SignInButton(busy: _coBusy, onTap: _coGo, label: 'Continue', buttonKey: const Key('co-go')),
        const SizedBox(height: 12),
        Text('No list of companies is shown – the code is the only way in.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: _l.faint, height: 1.35)),
      ]));

  /// The company of this sign-in on the navy; a tap: "Change company?" – the code is asked again.
  Widget _coPill() {
    final s = SessionScope.of(context);
    return Semantics(
      button: true,
      label: tr('Change company'),
      child: GestureDetector(
        key: const Key('co-change'),
        onTap: () async {
          final yes = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Change company?'),
              content: Text('You are signing in to ${s.companyCode}. Type another company code?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                FilledButton(key: const Key('co-change-yes'), onPressed: () => Navigator.pop(c, true), child: const Text('Change company')),
              ],
            ),
          );
          if (yes == true && mounted) {
            setState(() => _localErr = '');
            await SessionScope.read(context).forgetCompany();
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(22), border: Border.all(color: kCrestGold.withValues(alpha: .55))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.apartment_rounded, size: 17, color: kCrestGold),
            const SizedBox(width: 7),
            m.Text(s.companyCode, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
            const SizedBox(width: 6),
            const Text('Change', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrestGold)),
          ]),
        ),
      ),
    );
  }

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
                    // (3.173.0) the company this sign-in is for – a tap asks the code again
                    if (!widget.askCompany && !widget.setPassword && SessionScope.of(context).companyCode.isNotEmpty) Positioned(top: mq.padding.top + 10, left: Sp.edge, child: _coPill()),
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
                      widget.setPassword ? _pwCard(err) : (widget.askCompany ? _coCard(err) : (_reset ? _resetCard(err) : (_wa ? _waCard(err) : (_otp ? _otpCard(err) : _card(err))))),
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
  Widget _pwCard(String err) {
    // (25-11-2026, his words: "login with otp krtan given password nko aahe new set kru shakel") signed in with a code: only the new one
    final byCode = SessionScope.of(context).byCode;
    return _shaken(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Set your own password'),
        const SizedBox(height: 8),
        MrLine('तुमचा स्वतःचा password बनवा', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 16, fontWeight: FontWeight.w600, color: _l.ink)),
        const SizedBox(height: 4),
        if (byCode)
          Text(bi('You signed in with a code – the password you were given is not needed. Type your new password twice.', 'तुम्ही code ने sign in केले – दिलेला password लागणार नाही. तुमचा नवीन password दोन वेळा टाका.', '\n'),
              key: const Key('login-pw-bycode'), style: TextStyle(fontSize: 14, color: _l.muted))
        else ...[
          Text('Type the password you were given, then your new password twice.', style: TextStyle(fontSize: 14, color: _l.muted)),
          MrLine('दिलेला password टाका, मग तुमचा नवीन password दोन वेळा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13.5, color: _l.muted)),
          _pwBox(_given, 'Given password', Icons.key_rounded),
        ],
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
  }

  /// (25-11-2026) how many more codes may be asked for – under a code sent ('' when the Portal did not say)
  Widget _left({Key key = const Key('login-codes-left')}) {
    final t = codesLeftLine(SessionScope.of(context).codesLeft);
    if (t.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 6), child: m.Text(t, key: key, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _l.muted, height: 1.35)));
  }

  /// (25-11-2026) "Forgot password?": the e-mail and "Send code"; then the code, the new password twice and "Set the new password".
  Widget _resetCard(String err) => _shaken(AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Forgot password', key: const Key('login-reset-title')),
          const SizedBox(height: 10),
          Text(bi('A 6-digit code comes to your registered e-mail. Type it with your new password.', 'तुमच्या नोंदलेल्या email वर 6 अंकी code येईल. तो code आणि तुमचा नवीन password टाका.', '\n'),
              style: TextStyle(fontSize: 14, color: _l.muted, height: 1.35)),
          _lab('Email address'),
          TextField(
            key: const Key('login-reset-mail'),
            controller: _mail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            textInputAction: TextInputAction.done,
            autocorrect: false,
            style: _typed,
            onChanged: (_) {
              if (_rSent || _localErr.isNotEmpty) {
                _tick?.cancel();
                setState(() {
                  _rSent = false; // another e-mail: from the first step again
                  _wait = 0;
                  _localErr = '';
                });
              }
            },
            onSubmitted: (_) {
              if (!_rSent) _resetAsk();
            },
            decoration: _dec('name@company.com', Icons.mail_outline_rounded),
          ),
          if (_rSent) ...[
            const SizedBox(height: 10),
            Text(bi('If this e-mail is registered, a code is on its way to it.', 'Email नोंदलेला असेल तर code पाठवला आहे.', '\n'), style: TextStyle(fontSize: 13, color: _l.muted, height: 1.35)),
            _left(),
            _lab('6-digit code'),
            TextField(
              key: const Key('login-reset-code'),
              controller: _rCode,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_localErr.isNotEmpty) setState(() => _localErr = '');
              },
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4, color: _l.ink),
              decoration: _dec('', Icons.pin_outlined),
            ),
            _pwBox(_new, 'New password', Icons.lock_outline_rounded),
            _pwBox(_again, 'New password again', Icons.lock_reset_rounded, next: TextInputAction.go, go: _resetGo),
            Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(bi('At least 8 characters, letters and numbers.', 'किमान 8 अक्षरे – अक्षरे आणि अंक दोन्ही.', '\n'), style: TextStyle(fontSize: 12.5, color: _l.muted, height: 1.35)),
                ),
              ),
              IconButton(tooltip: tr(_show ? 'Hide passwords' : 'Show passwords'), color: _l.muted, icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _show = !_show)),
            ]),
          ],
          _errBox(err),
          const SizedBox(height: 16),
          _SignInButton(busy: _busy, onTap: _rSent ? _resetGo : _resetAsk, label: _rSent ? 'Set the new password' : 'Send code'),
          if (_rSent) _link(_wait > 0 ? 'Send again ($_wait s)' : 'Send again', key: const Key('login-reset-again'), onTap: _busy || _wait > 0 ? null : _resetAsk),
          _link('Back to sign in', key: const Key('login-reset-back'), onTap: _busy ? null : _resetBack),
        ]),
      ));

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
          // (3.166.0) and the code by WhatsApp beside it (both on: the two side by side, so the page still fits the screen)
          if (_otpOn || _waOn) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Container(height: 1, color: _l.line)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _l.faint))),
              Expanded(child: Container(height: 1, color: _l.line)),
            ]),
            const SizedBox(height: 16),
            if (_otpOn && _waOn)
              Row(children: [
                Expanded(child: _wayBtn(const Key('login-wa'), 'WhatsApp OTP', null, () => _waWay(true))),
                const SizedBox(width: 10),
                Expanded(child: _wayBtn(const Key('login-otp'), 'Email OTP', Icons.mail_outline_rounded, () => _way(true))),
              ])
            else if (_waOn)
              _wayBtn(const Key('login-wa'), 'Login with WhatsApp OTP', null, () => _waWay(true))
            else
              _wayBtn(const Key('login-otp'), 'Login with Email OTP', Icons.mail_outline_rounded, () => _way(true)),
          ],
        ]),
      ));

  /// (3.166.0) A way in under "Sign in": the code by e-mail, the code by WhatsApp ([icon] null = WhatsApp's own sign).
  Widget _wayBtn(Key key, String label, IconData? icon, VoidCallback go) => OutlinedButton.icon(
        key: key,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: _l.ink, side: BorderSide(color: _l.dark ? kCrestGold.withValues(alpha: .7) : _l.ink, width: 1.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
        onPressed: _busy ? null : go,
        icon: icon == null ? const _WaMark(size: 20) : Icon(icon, size: 20),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
      );

  /// (3.166.0) The code by WhatsApp: the number and "Send code on WhatsApp"; then the six boxes – no button, the sixth digit checks.
  Widget _waCard(String err) => _shaken(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _waSent ? _waTwo(err) : _waOne(err)));

  List<Widget> _waOne(String err) => [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.fromLTRB(5, 4, 11, 4),
            decoration: BoxDecoration(color: _l.dark ? const Color(0x2617A35A) : const Color(0xFFE3F5EA), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const _WaMark(size: 20, filled: true),
              const SizedBox(width: 7),
              Text('Code on WhatsApp', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _l.dark ? const Color(0xFF5FD892) : CodeLook.good)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        _title('Sign in', key: const Key('login-wa-title')),
        const SizedBox(height: 10),
        Text('Enter your mobile number. We send a 6-digit code on WhatsApp.', style: TextStyle(fontSize: 14.5, color: _l.muted, height: 1.35)),
        MrLine('तुमचा मोबाइल नंबर टाका – WhatsApp वर 6 अंकी code येईल.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: _l.muted)),
        _lab('Mobile number'),
        TextField(
          key: const Key('login-wa-mobile'),
          controller: _mob,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
          textInputAction: TextInputAction.go,
          autocorrect: false,
          style: _typed.copyWith(letterSpacing: 1),
          onChanged: (_) {
            if (_localErr.isNotEmpty) setState(() => _localErr = '');
          },
          onSubmitted: (_) => _waAsk(),
          decoration: _dec('10-digit number', Icons.phone_iphone_rounded).copyWith(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.phone_iphone_rounded, color: _l.muted),
                const SizedBox(width: 8),
                m.Text('+91', style: _typed.copyWith(color: _l.muted)),
                const SizedBox(width: 10),
                Container(width: 1, height: 22, color: _l.line),
              ]),
            ),
          ),
        ),
        _errBox(err),
        const SizedBox(height: 16),
        _SignInButton(busy: _busy, onTap: _waAsk, label: 'Send code on WhatsApp'),
        const SizedBox(height: 4),
        _waAlt(),
      ];

  List<Widget> _waTwo(String err) {
    final n = _waCode.text.length, still = MediaQuery.of(context).disableAnimations;
    final say = switch (_cs) {
      CodeState.checking => ('Verifying…', _l.muted),
      CodeState.ok => ('Verified – signing you in', _l.dark ? const Color(0xFF5FD892) : CodeLook.good),
      CodeState.bad => (_waSay, _l.bad),
      CodeState.idle => ('You are signed in as soon as the 6th digit is in.', _l.muted),
    };
    return [
      _title('Enter the code', key: const Key('login-wa-title2')),
      const SizedBox(height: 10),
      Text('Open WhatsApp – the code comes from Sketchline Industries. Tap "Copy code" there and come back.', style: TextStyle(fontSize: 14, color: _l.muted, height: 1.35)),
      MrLine('WhatsApp उघडा – Sketchline Industries कडून code येईल. तिथे "Copy code" दाबा आणि इथे परत या.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: _l.muted)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(color: _l.dark ? const Color(0x1F17A35A) : const Color(0xFFEEF8F1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _l.dark ? const Color(0x4017A35A) : const Color(0xFFCDEBD7))),
        child: Row(children: [
          Icon(Icons.check_circle_rounded, size: 18, color: _l.dark ? const Color(0xFF5FD892) : CodeLook.good),
          const SizedBox(width: 8),
          Text('Sent to', style: TextStyle(fontSize: 13.5, color: _l.muted)),
          const SizedBox(width: 6),
          Expanded(child: m.Text('+91 ${_waTo.substring(0, 5)} ${_waTo.substring(5)}', key: const Key('login-wa-to'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _l.ink, letterSpacing: .3))),
          _link('Change', key: const Key('login-wa-change'), onTap: _busy && _cs != CodeState.bad ? null : _waBack),
        ]),
      ),
      _lab('6-digit code'),
      CodeBoxes(
        controller: _waCode,
        focusNode: _waFocus,
        state: _cs,
        fieldKey: const Key('login-wa-code'),
        look: CodeLook(card: _l.card, line: _l.line, ink: _l.ink, focus: kCrestGold, bad: _l.bad, badSoft: _l.dark ? const Color(0x33E5484D) : C.redSoft),
      ),
      const SizedBox(height: 10),
      CodeTrack(count: n, bad: _cs == CodeState.bad, line: _l.line),
      const SizedBox(height: 10),
      AnimatedSwitcher(
        duration: still ? Duration.zero : const Duration(milliseconds: 200),
        child: Row(key: ValueKey('${_cs.name}:${say.$1}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_cs == CodeState.checking) ...[
            SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: _l.gold)),
            const SizedBox(width: 8),
          ],
          if (_cs == CodeState.ok) ...[
            Icon(Icons.verified_rounded, size: 17, color: say.$2),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(say.$1, key: const Key('login-wa-state'), style: TextStyle(fontSize: 13.5, fontWeight: _cs == CodeState.idle ? FontWeight.w500 : FontWeight.w700, color: say.$2, height: 1.35))),
        ]),
      ),
      if (_cs == CodeState.idle) _left(), // (25-11-2026) how many more codes
      _errBox(err),
      const SizedBox(height: 6),
      Row(children: [
        if (_wait > 0)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12), child: Text('Send again in ${_wait ~/ 60}:${(_wait % 60).toString().padLeft(2, '0')}', key: const Key('login-wa-wait'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _l.faint)))
        else
          _link('Send again', key: const Key('login-wa-again'), onTap: _busy ? null : _waAsk),
        const Spacer(),
        _link('Paste code', key: const Key('login-wa-paste'), onTap: _busy ? null : () => _paste()),
      ]),
      _waAlt(),
    ];
  }

  /// "No WhatsApp code? Use email and password" – always one tap away.
  Widget _waAlt() => Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('No WhatsApp code?', style: TextStyle(fontSize: 13.5, color: _l.muted)),
        _link('Use email and password', key: const Key('login-wa-pw'), onTap: _busy && _cs != CodeState.bad ? null : () => _waWay(false)),
      ]);

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
          _left(), // (25-11-2026) how many more codes
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

/// (3.166.0) WhatsApp's sign on the sign-in: a green speech bubble ([filled]: white on a green circle, for the chip).
class _WaMark extends StatelessWidget {
  const _WaMark({this.size = 20, this.filled = false});
  final double size;
  final bool filled;
  @override
  Widget build(BuildContext context) => filled
      ? Container(width: size, height: size, decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle), child: Icon(Icons.chat_bubble_rounded, size: size * .56, color: Colors.white))
      : Icon(Icons.chat_rounded, size: size, color: const Color(0xFF1FAF55));
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
  const _SignInButton({required this.busy, required this.onTap, this.label = 'Sign in', this.buttonKey = const Key('login-go')});
  final bool busy;
  final VoidCallback onTap;
  final String label;
  final Key buttonKey;
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
          key: buttonKey,
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
