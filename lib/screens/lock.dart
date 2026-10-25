/* (3.27.0) THE LOCK SCREEN over the whole app (lib/core/applock.dart) – (3.39.0) on the approved design: the mark, "RCL ERP is locked", Unlock – the phone's own
 * box (fingerprint / face / PIN) opens by itself when the lock screen comes. Over the call's bar too (the names are not shown). */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/applock.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import 'splash.dart';

class LockLayer extends StatefulWidget {
  const LockLayer({super.key, required this.lock, required this.nav, required this.child});
  final AppLock? lock;
  final GlobalKey<NavigatorState> nav;
  final Widget child;
  @override
  State<LockLayer> createState() => _LockLayerState();
}

class _LockLayerState extends State<LockLayer> with WidgetsBindingObserver {
  bool _asked = false, _told = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.lock?.addListener(_changed);
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
    // a phone with no screen lock: said once, in red, when the app opens
    if (l != null && l.noLock && !_told) {
      _told = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = widget.nav.currentContext;
        final m = ctx == null ? null : ScaffoldMessenger.maybeOf(ctx);
        m?.showSnackBar(SnackBar(
          content: const Text('This phone has no screen lock – set a PIN, pattern or fingerprint (the phone\'s Settings → Security), so that RCL ERP is locked.'),
          backgroundColor: C.red,
          duration: const Duration(seconds: 10),
        ));
      });
    }
    setState(() {});
  }

  static const _signedIn = {Stage.pickSite, Stage.opening, Stage.ready, Stage.waiting};

  @override
  Widget build(BuildContext context) {
    final l = widget.lock, s = SessionScope.of(context);
    final show = l != null && l.locked && _signedIn.contains(s.stage);
    if (show && !l.asking && !_asked) {
      _asked = true; // the phone's box opens by itself, once each time the app is locked
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) l.unlock(tr('Unlock RCL ERP'));
      });
    }
    return Stack(children: [
      widget.child,
      if (show) Positioned.fill(child: _LockScreen(lock: l, name: s.name)),
    ]);
  }
}

/// (3.39.0, asked 25-10-2026: "old screen nahi disli pahije … jr passowrd finger nahi takla or chukich asel tewa … sagle hoyla
/// pahije but new screen war") The lock on the approved design (screens/splash.dart): the same navy, road, mark and RCL ERP as the
/// opening; at the bottom "RCL ERP is locked", his name, what the phone said (not unlocked, wrong, …) and Unlock – the old green
/// screen is gone. What it does is as before.
class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.lock, required this.name});
  final AppLock lock;
  final String name;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Material(
          key: const Key('lock-screen'),
          color: SplashC.navy,
          child: SplashScene(
            room: 300,
            side: .07,
            bottom: (s) => SplashPanel(children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              const Text('RCL ERP is locked', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, color: Color(0xE6FFFFFF))),
              ],
              const SizedBox(height: 8),
              const Text('Use your fingerprint, face or the phone\'s PIN.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, height: 1.35, color: Color(0xCCFFFFFF))),
              if (lock.said.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0x33D90A16), border: Border.all(color: const Color(0x80F25750)), borderRadius: BorderRadius.circular(14)),
                  child: Text(lock.said, key: const Key('lock-said'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ],
              const SizedBox(height: 18),
              SplashButton(
                key: const Key('lock-unlock'),
                onPressed: lock.asking ? null : () => lock.unlock(tr('Unlock RCL ERP')),
                icon: Icons.fingerprint_rounded,
                label: const Text('Unlock'),
              ),
            ]),
          ),
        ),
      );
}
