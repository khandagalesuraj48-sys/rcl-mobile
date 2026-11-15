/* (3.27.0) THE LOCK SCREEN over the whole app (lib/core/applock.dart). Over the call's bar too (the names are not shown).
 * (3.127.0, asked 15-11-2026: "app lock … user tharwel pin thewaych ki password ki only finger ki only face"; "ji screen ahe user jewa
 * pass takel ti redesign kr – Sketchline name khali mala Version Lion as name haway"; "Android madhe finger set asel tr mobile swatah
 * pop up deto … mg apan design madhe finger ka dakhawtoy"; "app home screen light colour madhe ahe … lock che page dark nko") – on
 * the approved light design: the lion, the product's name, its line from the Portal (Branding) under it, the person's name; then
 * what HE chose: the PIN pad, his password, or (fingerprint / face) the phone's own popup over it – the screen itself shows only
 * Unlock (to ask again) and "Use password instead". Shown only when he turned the lock on (My settings → App lock). The red line
 * "set a screen lock on the phone" is gone. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/applock.dart';
import '../core/product_brand.dart';
import '../core/session.dart';
import '../ui/brand.dart' show Product, ProductMark;
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';

/// (3.127.0) the lock, for My settings (the screens under the lock layer)
class LockScope extends InheritedWidget {
  const LockScope({super.key, required this.lock, required super.child});
  final AppLock lock;
  static AppLock? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LockScope>()?.lock;
  @override
  bool updateShouldNotify(LockScope oldWidget) => oldWidget.lock != lock;
}

class LockLayer extends StatefulWidget {
  const LockLayer({super.key, required this.lock, required this.nav, required this.child});
  final AppLock? lock;
  final GlobalKey<NavigatorState> nav;
  final Widget child;
  @override
  State<LockLayer> createState() => _LockLayerState();
}

class _LockLayerState extends State<LockLayer> with WidgetsBindingObserver {
  bool _asked = false, _out = false;
  Session? _s;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.lock?.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant LockLayer old) {
    super.didUpdateWidget(old);
    if (old.lock != widget.lock) {
      // (another lock given: listen to the new one – its "5 wrong" and its changes)
      old.lock?.removeListener(_changed);
      widget.lock?.addListener(_changed);
      _asked = false;
      _out = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.lock?.removeListener(_changed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final l = widget.lock;
    if (l == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) l.away0();
    if (state == AppLifecycleState.resumed) l.back();
  }

  void _changed() {
    if (!mounted) return;
    final l = widget.lock;
    if (l != null && !l.locked) _asked = false; // (the next lock asks by itself again)
    // (3.127.0) 5 wrong PINs / passwords: he signs in again with his Sketchline password
    if (l != null && l.tooMany && !_out) {
      _out = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _s?.signOut('Too many wrong tries – sign in again with your password.'));
    }
    if (l != null && !l.tooMany) _out = false;
    setState(() {});
  }

  static const _signedIn = {Stage.pickSite, Stage.opening, Stage.ready, Stage.waiting};

  /// "Forgot PIN / password?" ([forget]: the one he forgot goes) or "Use password instead": the sign-in with his password.
  Future<void> _signInAgain(bool forget) async {
    final l = widget.lock, s = _s;
    if (l == null || s == null) return;
    if (forget) await l.forget();
    await s.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lock, s = SessionScope.of(context);
    _s = s;
    if (l != null) l.user = _signedIn.contains(s.stage) ? s.email : '';
    final show = l != null && l.closed;
    final how = l?.choice?.how ?? '';
    if (l != null && show && (how == 'finger' || how == 'face') && l.loaded && l.locked && !l.asking && !_asked) {
      _asked = true; // the phone's own popup comes by itself, once each time the app is locked
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) l.unlock(tr('Unlock Sketchline'));
      });
    }
    final body = Stack(children: [
      widget.child,
      if (l != null && show) Positioned.fill(child: _LockScreen(lock: l, name: s.name, out: _signInAgain)),
    ]);
    return l == null ? body : LockScope(lock: l, child: body);
  }
}

/// The light colours of the lock (as Home), the gold of the lion
class _L {
  static const top = Color(0xFFFFF6DD), mid = Color(0xFFFAF8F2), end = Color(0xFFF3EFE5);
  static const ink = Color(0xFF14181D), gold = Color(0xFFD4AF37), goldText = Color(0xFFA8821F);
}

/// The lock screen: its own Overlay, so that the password box works above the app's pages.
class _LockScreen extends StatefulWidget {
  const _LockScreen({required this.lock, required this.name, required this.out});
  final AppLock lock;
  final String name;
  final Future<void> Function(bool forget) out;
  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  late final _entry = OverlayEntry(builder: (_) => _LockBody(lock: widget.lock, name: widget.name, out: widget.out));

  @override
  void didUpdateWidget(covariant _LockScreen old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        child: Material(key: const Key('lock-screen'), color: _L.mid, child: Overlay(initialEntries: [_entry])),
      );
}

class _LockBody extends StatefulWidget {
  const _LockBody({required this.lock, required this.name, required this.out});
  final AppLock lock;
  final String name;
  final Future<void> Function(bool forget) out;
  @override
  State<_LockBody> createState() => _LockBodyState();
}

class _LockBodyState extends State<_LockBody> {
  String _pin = '';
  bool _hide = true, _sure = false, _busy = false;
  final _pass = TextEditingController();

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _digit(String d) async {
    if (_busy || _pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length < 4) return;
    _busy = true;
    final ok = await widget.lock.tryCode(_pin);
    if (!ok) await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() => _pin = '');
    _busy = false;
  }

  Future<void> _password() async {
    if (_busy || _pass.text.isEmpty) return;
    _busy = true;
    final ok = await widget.lock.tryCode(_pass.text);
    if (!ok) _pass.clear();
    _busy = false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        // (3.127.1, his picture of 15-11-2026: "screen … cut zali") the whole screen – a Scaffold's page is only as wide as what is
        // in it, so the lock stood at the left, as wide as its Unlock button
        body: SizedBox.expand(
          child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -.68), radius: 1.25, colors: [_L.top, _L.mid, _L.end], stops: [0, .55, 1]),
          ),
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([widget.lock, ProductBrand.i]),
              builder: (context, _) {
                final l = widget.lock, c = l.choice, how = l.loaded ? c?.how ?? '' : '';
                return LayoutBuilder(builder: (context, box) {
                  final head = _head();
                  if (how == 'pin' || how == 'password') {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(children: [
                          head,
                          if (how == 'pin') ..._pinPad(box.maxHeight) else ..._passBox(),
                          const SizedBox(height: 18),
                        ]),
                      ),
                    );
                  }
                  return SizedBox(
                    height: box.maxHeight,
                    child: Column(children: [
                      head,
                      const Spacer(),
                      if (how == 'finger' || how == 'face') ..._bioBottom(),
                    ]),
                  );
                });
              },
            ),
          ),
        ),
        ),
      );

  /// The lion, the name, the line under it (the Portal's Branding), the person
  Widget _head() {
    final line = Product.line.trim();
    return Column(children: [
      const SizedBox(height: 26),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: _L.gold.withValues(alpha: .32), blurRadius: 46, spreadRadius: 6), BoxShadow(color: const Color(0xFF3C2D0A).withValues(alpha: .28), blurRadius: 26, offset: const Offset(0, 12))],
        ),
        foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(28), border: Border.all(color: _L.gold.withValues(alpha: .6))),
        child: const ProductMark(key: Key('lock-mark'), size: 96, radius: 28),
      ),
      const SizedBox(height: 14),
      Text(Product.name, key: const Key('lock-name'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 28, fontWeight: FontWeight.w800, color: _L.ink, letterSpacing: .4)),
      if (line.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 3, 24, 0),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 18, height: 1, color: _L.gold),
            const SizedBox(width: 8),
            // (a long line is made smaller to fit – never cut)
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(line.toUpperCase(), key: const Key('lock-line'), maxLines: 1, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11.5, letterSpacing: 3.2, color: _L.goldText)),
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 18, height: 1, color: _L.gold),
          ]),
        ),
      if (widget.name.isNotEmpty) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 14, backgroundColor: C.green, child: Text(widget.name[0].toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
            const SizedBox(width: 9),
            Text(widget.name, style: const TextStyle(fontSize: 14, color: C.ink)),
          ]),
        ),
      ],
    ]);
  }

  Widget _said() => widget.lock.said.isEmpty
      ? const SizedBox(height: 22)
      : Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(widget.lock.said, key: const Key('lock-said'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: C.red, fontWeight: FontWeight.w500)),
        );

  /// "Forgot …?" → asked once on the screen itself (no box: the lock is over the app's pages)
  Widget _forgot(String label, bool forget) => _sure
      ? Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(children: [
            const Text('Sign in again with your Sketchline password?', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: C.ink)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              // (the app's buttons are a whole line wide by themselves: here two side by side)
              TextButton(key: const Key('lock-out-no'), style: TextButton.styleFrom(minimumSize: const Size(90, 46)), onPressed: () => setState(() => _sure = false), child: const Text('Back')),
              const SizedBox(width: 8),
              FilledButton(key: const Key('lock-out-yes'), style: FilledButton.styleFrom(minimumSize: const Size(150, 46)), onPressed: () => widget.out(forget), child: const Text('Sign in again')),
            ]),
          ]),
        )
      : TextButton(key: const Key('lock-forgot'), onPressed: () => setState(() => _sure = true), child: Text(label, style: const TextStyle(fontSize: 13.5, color: C.greenDark, fontWeight: FontWeight.w500)));

  List<Widget> _pinPad(double h) {
    final k = ((h - 420) / 4.7).clamp(52.0, 68.0);
    Widget key(String d) => SizedBox(
          width: k,
          height: k,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: C.line)),
            child: InkWell(key: Key('lock-key-$d'), customBorder: const CircleBorder(), onTap: () => _digit(d), child: Center(child: Text(d, style: TextStyle(fontSize: k * .4, color: C.ink)))),
          ),
        );
    Widget back() => SizedBox(
          width: k,
          height: k,
          child: InkWell(
            key: const Key('lock-key-back'),
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
            child: const Icon(Icons.backspace_outlined, color: C.greenDark, size: 26),
          ),
        );
    Widget rowOf(List<Widget> w) => Padding(padding: const EdgeInsets.only(top: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [w[0], const SizedBox(width: 26), w[1], const SizedBox(width: 26), w[2]]));
    return [
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < 4; i++)
          Container(
            key: Key('lock-dot-$i'),
            margin: const EdgeInsets.symmetric(horizontal: 9),
            width: 13,
            height: 13,
            decoration: BoxDecoration(shape: BoxShape.circle, color: i < _pin.length ? C.green : null, border: Border.all(color: i < _pin.length ? C.green : const Color(0xFF9DB8A9), width: 1.6)),
          ),
      ]),
      _said(),
      rowOf([key('1'), key('2'), key('3')]),
      rowOf([key('4'), key('5'), key('6')]),
      rowOf([key('7'), key('8'), key('9')]),
      rowOf([SizedBox(width: k), key('0'), back()]),
      const SizedBox(height: 6),
      _forgot('Forgot PIN?', true),
    ];
  }

  List<Widget> _passBox() => [
        const SizedBox(height: 24),
        SizedBox(
          width: 280,
          child: TextField(
            key: const Key('lock-pass'),
            controller: _pass,
            obscureText: _hide,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _password(),
            style: const TextStyle(fontSize: 17, color: C.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: tr('Password'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.green, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.green, width: 2)),
              suffixIcon: IconButton(onPressed: () => setState(() => _hide = !_hide), icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: C.green)),
            ),
          ),
        ),
        _said(),
        const SizedBox(height: 6),
        _GreenButton(key: const Key('lock-open'), label: 'Unlock', onTap: _password),
        const SizedBox(height: 6),
        _forgot('Forgot password?', true),
      ];

  List<Widget> _bioBottom() {
    final l = widget.lock;
    return [
      _said(),
      const SizedBox(height: 10),
      _GreenButton(key: const Key('lock-unlock'), label: 'Unlock', onTap: l.asking ? null : () => l.unlock(tr('Unlock Sketchline'))),
      const SizedBox(height: 6),
      _forgot('Use password instead', false),
      const SizedBox(height: 22),
    ];
  }
}

class _GreenButton extends StatelessWidget {
  const _GreenButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .55 : 1,
        child: Container(
          width: 280,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(colors: [C.greenLight, C.green, C.greenEnd], stops: [0, .55, 1]),
            boxShadow: [BoxShadow(color: C.green.withValues(alpha: .28), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(borderRadius: BorderRadius.circular(26), onTap: onTap, child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)))),
          ),
        ),
      );
}
