/* (3.127.0, asked 15-11-2026: "app lock … te setting madhe asel – app la lock lawaych ki nahi to user cha perspective asel, ani kas
 * lawaych te user tharwel: pin thewaych ki password ki only finger ki only face – mhanje phone lock cha nahi") MY SETTINGS → APP LOCK
 * (the approved picture): "Lock the app" off by itself; on → he picks how it opens – his own 4-digit PIN (typed twice), his own
 * password (twice), only his fingerprint or only his face (the phone asks once, to be sure it works). What this phone cannot do is
 * grey. Kept on this phone only (lib/core/applock.dart). */
import 'package:flutter/material.dart' hide Text;

import '../core/applock.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.lock});
  final AppLock lock;
  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  Set<String>? _bios;
  bool _want = false, _busy = false;

  @override
  void initState() {
    super.initState();
    widget.lock.gate.bios().then((b) {
      if (mounted) setState(() => _bios = b);
    }, onError: (Object _) {
      if (mounted) setState(() => _bios = {});
    });
  }

  Future<void> _pick(String how) async {
    final l = widget.lock;
    if (_busy) return;
    if (how == 'pin' || how == 'password') {
      final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => SetCodeScreen(pin: how == 'pin')));
      if (code == null || code.isEmpty || !mounted) return;
      setState(() => _busy = true);
      await l.choose(how, code);
    } else {
      setState(() => _busy = true);
      final a = await l.gate.ask(tr('Unlock Sketchline'));
      if (!mounted) return;
      if (a.outcome != LockOutcome.ok) {
        setState(() => _busy = false);
        toast(context, a.outcome == LockOutcome.noLock ? 'No fingerprint or face is set on this phone.' : (a.text.isEmpty ? 'Not saved – it was not checked.' : a.text), bad: true);
        return;
      }
      await l.choose(how);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _want = false;
    });
    toast(context, 'App lock: ${tr(lockWay(how))}');
  }

  Future<void> _off() async {
    setState(() => _want = false);
    await widget.lock.forget();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.lock.choice, on = c != null || _want, bios = _bios;
    Widget opt(String how, String en, String mr, String subEn, String subMr, IconData icon) {
      final can = how == 'pin' || how == 'password' || (bios?.contains(how) ?? false);
      final picked = c?.how == how;
      return Opacity(
        opacity: can ? 1 : .45,
        child: InkWell(
          key: Key('al-$how'),
          onTap: can && !_busy && !picked ? () => _pick(how) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(children: [
              Icon(picked ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: picked ? C.green : C.faint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(en, mr: mr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  can
                      ? Text(subEn, mr: subMr, style: const TextStyle(fontSize: 12.5, color: C.muted))
                      : Text(bios == null ? '…' : 'Not set on this phone', mr: bios == null ? '…' : 'या phone वर सेट नाही', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                ]),
              ),
              Icon(icon, color: C.greenDark),
            ]),
          ),
        ),
      );
    }

    Widget card(List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(height: 1, color: C.line), children[i]],
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const TwoLang('App lock', 'ॲप लॉक', size: 20, weight: FontWeight.w700)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 30), children: [
        card([
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(children: [
              const Expanded(child: TwoLang('Lock the app', 'ॲप उघडताना विचारा', size: 15.5)),
              Switch(key: const Key('al-on'), value: on, onChanged: _busy ? null : (v) => v ? setState(() => _want = true) : _off()),
            ]),
          ),
        ]),
        if (on) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Text('How should it open? (choose one)', mr: 'App कशाने उघडायचा? (एक निवडा)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          card([
            opt('pin', 'PIN', 'PIN', '4 digits, your own (not the phone\'s)', '4 अंकी, तुमचा स्वतःचा (phone चा नाही)', Icons.pin_outlined),
            opt('password', 'Password', 'पासवर्ड', 'Your own, for this phone', 'तुमचा स्वतःचा, या phone साठी', Icons.password_rounded),
            opt('finger', 'Fingerprint only', 'फक्त fingerprint', 'Only the finger – not the phone\'s PIN', 'फक्त बोट – phone चा PIN नाही', Icons.fingerprint_rounded),
            opt('face', 'Face only', 'फक्त face', 'Only the face – not the phone\'s PIN', 'फक्त चेहरा – phone चा PIN नाही', Icons.face_rounded),
          ]),
          if (c != null && c.code)
            card([
              InkWell(
                key: const Key('al-change'),
                onTap: _busy ? null : () => _pick(c.how),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(children: [
                    Expanded(child: c.how == 'pin' ? const TwoLang('Change PIN', 'PIN बदला', size: 15) : const TwoLang('Change password', 'पासवर्ड बदला', size: 15)),
                    const Icon(Icons.chevron_right_rounded, color: C.faint),
                  ]),
                ),
              ),
            ]),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: Text('Locked again after a minute away. Kept only on this phone – never sent anywhere.',
                mr: 'App 1 मिनिटापेक्षा जास्त बाहेर राहिला की परत lock. फक्त या phone वर राहतो, server वर जात नाही.', style: TextStyle(fontSize: 12.5, color: C.muted, height: 1.4)),
          ),
        ],
      ]),
    );
  }
}

/// (3.127.0) His new PIN (4 digits, typed twice) or password (at least 6, typed twice); pops with it.
class SetCodeScreen extends StatefulWidget {
  const SetCodeScreen({super.key, required this.pin});
  final bool pin;
  @override
  State<SetCodeScreen> createState() => _SetCodeScreenState();
}

class _SetCodeScreenState extends State<SetCodeScreen> {
  String _first = '', _now = '', _said = '';
  final _a = TextEditingController(), _b = TextEditingController();
  bool _hide = true;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _digit(String d) {
    if (_now.length >= 4) return;
    setState(() => _now += d);
    if (_now.length < 4) return;
    if (_first.isEmpty) {
      setState(() {
        _first = _now;
        _now = '';
        _said = '';
      });
    } else if (_now == _first) {
      Navigator.of(context).pop(_now);
    } else {
      setState(() {
        _first = '';
        _now = '';
        _said = 'The two PINs are not the same – type it again.';
      });
    }
  }

  void _savePassword() {
    final a = _a.text, b = _b.text;
    if (a.length < 6) {
      setState(() => _said = 'At least 6 letters or numbers.');
    } else if (a != b) {
      setState(() => _said = 'The two passwords are not the same.');
    } else {
      Navigator.of(context).pop(a);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: widget.pin ? const TwoLang('Set app PIN', 'ॲप PIN ठेवा', size: 20, weight: FontWeight.w700) : const TwoLang('Set app password', 'ॲप पासवर्ड ठेवा', size: 20, weight: FontWeight.w700)),
        body: widget.pin ? _pinBody() : _passBody(),
      );

  Widget _pinBody() {
    Widget key(String d) => SizedBox(
          width: 66,
          height: 66,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: C.line)),
            child: InkWell(key: Key('set-key-$d'), customBorder: const CircleBorder(), onTap: () => _digit(d), child: Center(child: Text(d, style: const TextStyle(fontSize: 25, color: C.ink)))),
          ),
        );
    Widget rowOf(List<Widget> w) => Padding(padding: const EdgeInsets.only(top: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [w[0], const SizedBox(width: 24), w[1], const SizedBox(width: 24), w[2]]));
    return ListView(children: [
      const SizedBox(height: 28),
      const Icon(Icons.lock_rounded, size: 46, color: C.greenDark),
      const SizedBox(height: 10),
      Center(
        child: _first.isEmpty
            ? const TwoLang('Type a 4-digit PIN', '4 अंकी PIN टाका', size: 18, weight: FontWeight.w700, align: CrossAxisAlignment.center)
            : const TwoLang('Type the same PIN again', 'तोच PIN परत टाका', size: 18, weight: FontWeight.w700, align: CrossAxisAlignment.center),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 9),
            width: 14,
            height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle, color: i < _now.length ? C.green : null, border: Border.all(color: C.green, width: 1.6)),
          ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        child: Text(_said, key: const Key('set-said'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: C.red)),
      ),
      rowOf([key('1'), key('2'), key('3')]),
      rowOf([key('4'), key('5'), key('6')]),
      rowOf([key('7'), key('8'), key('9')]),
      rowOf([
        const SizedBox(width: 66),
        key('0'),
        SizedBox(
          width: 66,
          height: 66,
          child: InkWell(
            key: const Key('set-key-back'),
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _now = _now.isEmpty ? '' : _now.substring(0, _now.length - 1)),
            child: const Icon(Icons.backspace_outlined, color: C.greenDark),
          ),
        ),
      ]),
    ]);
  }

  Widget _passBody() {
    InputDecoration deco(String hint) => InputDecoration(
          hintText: tr(hint),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          suffixIcon: IconButton(onPressed: () => setState(() => _hide = !_hide), icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 30), children: [
      const Text('At least 6 letters or numbers – for this phone only (not your Sketchline password).', mr: 'कमीत कमी 6 अक्षरे / अंक – फक्त या phone साठी (Sketchline चा पासवर्ड नाही).', style: TextStyle(fontSize: 13, color: C.muted, height: 1.4)),
      const SizedBox(height: 14),
      TextField(key: const Key('set-pass-1'), controller: _a, obscureText: _hide, autocorrect: false, enableSuggestions: false, decoration: deco('New password')),
      const SizedBox(height: 12),
      TextField(key: const Key('set-pass-2'), controller: _b, obscureText: _hide, autocorrect: false, enableSuggestions: false, decoration: deco('Same password again'), onSubmitted: (_) => _savePassword()),
      Padding(padding: const EdgeInsets.only(top: 10), child: Text(_said, key: const Key('set-said'), style: const TextStyle(fontSize: 13.5, color: C.red))),
      const SizedBox(height: 10),
      FilledButton(key: const Key('set-save'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: _savePassword, child: const Text('Save')),
    ]);
  }
}
