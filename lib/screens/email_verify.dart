/* VERIFY MY E-MAIL (3.104.0, the Portal's steps 10 / 11 – his rules of 12-11-2026; the web's "Verify your e-mail").
 * Many people were made with a made-up e-mail: that one stays their USER ID for ever – every module knows them by it. Here a
 * person types his OWN e-mail, a 6-digit code goes to it, he types the code: from then on that e-mail is the one he signs in
 * with (his password, or a code by e-mail). The Portal checks everything (the code, 60 seconds between two, never another
 * user's address); the app only asks. Reached from "My account" and from the reminder on Home. */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/api.dart' show ApiError;
import '../ui/hr_skin.dart';
import '../ui/motion.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';

Future<void> openVerifyEmail(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VerifyEmailScreen()));

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _mail = TextEditingController(), _code = TextEditingController();
  bool _busy = false, _sent = false, _filled = false;
  int _wait = 0;
  String _err = '';
  Timer? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    _mail.text = SessionScope.read(context).email; // his user ID – he types his own e-mail over it
  }

  @override
  void dispose() {
    _tick?.cancel();
    _mail.dispose();
    _code.dispose();
    super.dispose();
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

  Future<void> _send() async {
    if (_busy) return;
    if (_mail.text.trim().isEmpty) {
      setState(() => _err = bi('Type your own e-mail address.', 'तुमचा स्वतःचा email टाका.', '\n'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final w = await SessionScope.read(context).verifySend(_mail.text);
      if (!mounted) return;
      if (w < 0) {
        await _done(SessionScope.read(context).mailLogin);
        return;
      }
      setState(() {
        _sent = true;
        _code.clear();
      });
      _count(w);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
      if (e.code == 'wait') {
        setState(() => _sent = true); // a code went out a moment ago: it can be typed
        _count(60);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    if (_busy) return;
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _err = bi('Type the 6-digit code from the e-mail.', 'Email मधला 6 अंकी code टाका.', '\n'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final login = await SessionScope.read(context).verifyCheck(code, _mail.text);
      if (mounted) await _done(login);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
          _code.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Verified: said once which e-mail signs in from now on, then back.
  Future<void> _done(String login) async {
    _tick?.cancel();
    await popDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('E-mail verified ✓'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('From now on sign in with this e-mail – with your password, or with a code by e-mail:'),
          const SizedBox(height: 8),
          SelectableText(login, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: sk.ink)),
          MrLine('यापुढे login साठी हाच email वापरा – password ने किंवा Email OTP ने.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: sk.muted)),
        ]),
        actions: [FilledButton(key: const Key('ve-ok'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Scaffold(
      backgroundColor: sk.bg,
      appBar: AppBar(title: const Text('Verify your e-mail')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(Sp.edge, 16, Sp.edge, 24), children: [
          Text('Type your OWN e-mail – one you can open. A 6-digit code is sent to it; type the code here once.', style: TextStyle(fontSize: 14.5, color: sk.ink, height: 1.4)),
          MrLine('तुमचा स्वतःचा, चालू असलेला email टाका. त्यावर 6 अंकी code येईल – तो इथे एकदा टाका.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13.5, color: sk.muted)),
          const SizedBox(height: 16),
          TextField(
            key: const Key('ve-mail'),
            controller: _mail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_sent || _err.isNotEmpty) {
                _tick?.cancel();
                setState(() {
                  _sent = false; // another address: from the first step again
                  _wait = 0;
                  _err = '';
                });
              }
            },
            decoration: InputDecoration(labelText: tr('My e-mail'), prefixIcon: const Icon(Icons.mail_outline_rounded)),
          ),
          const SizedBox(height: 8),
          Text('Your user ID in the ERP stays ${s.email} – nothing of your work changes.', style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
          if (_sent) ...[
            const SizedBox(height: 14),
            TextField(
              key: const Key('ve-code'),
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _check(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4),
              decoration: InputDecoration(labelText: tr('6-digit code'), prefixIcon: const Icon(Icons.pin_outlined)),
            ),
          ],
          if (_err.isNotEmpty)
            Container(
              key: const Key('ve-err'),
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(16)),
              child: Text(_err, style: const TextStyle(color: C.red, fontSize: 14, fontWeight: FontWeight.w500, height: 1.35)),
            ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('ve-go'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy ? null : (_sent ? _check : _send),
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : Text(_sent ? 'Verify' : 'Send code'),
          ),
          if (_sent)
            TextButton(
              key: const Key('ve-again'),
              onPressed: _busy || _wait > 0 ? null : _send,
              child: Text(_wait > 0 ? 'Send again ($_wait s)' : 'Send again'),
            ),
        ]),
      ),
    );
  }
}
