/* (3.41.0) A "Scan with Mobile" QR code waiting (core/scan_link.dart) is opened here as soon as it can be – over every screen of
 * the app: he is signed in, the lock is open, the QR code's site is open (another of HIS sites: opened first by itself), then the
 * capture screen (attach_box.dart CaptureScreen). Signed out: it waits for the sign-in. A site he does not have: said, and dropped. */
import 'package:flutter/material.dart' hide Text;

import '../core/applock.dart';
import '../core/scan_link.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/widgets.dart';
import 'attach_box.dart' show CaptureScreen;

class ScanLinkLayer extends StatefulWidget {
  const ScanLinkLayer({super.key, required this.nav, required this.child, this.lock});
  final GlobalKey<NavigatorState> nav;
  final AppLock? lock;
  final Widget child;
  @override
  State<ScanLinkLayer> createState() => _ScanLinkLayerState();
}

class _ScanLinkLayerState extends State<ScanLinkLayer> {
  bool _busy = false;
  String _switchedFor = ''; // the code whose site was opened already (never again in a loop)

  @override
  void initState() {
    super.initState();
    ScanLink.i.addListener(_soon);
    widget.lock?.addListener(_soon);
  }

  @override
  void dispose() {
    ScanLink.i.removeListener(_soon);
    widget.lock?.removeListener(_soon);
    super.dispose();
  }

  // (after this frame – and a frame is asked for: on a still screen none would come until the next touch)
  void _soon() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _say(String en, String mr) {
    final c = widget.nav.currentContext;
    if (c != null && c.mounted) toast(c, bi(en, mr), bad: true);
  }

  Future<void> _go() async {
    final l = ScanLink.i;
    if (_busy || !mounted || l.code.isEmpty) return;
    final s = SessionScope.read(context);
    if (s.stage != Stage.ready && s.stage != Stage.pickSite) return; // signed out, opening, no network: it waits
    if (widget.lock?.locked == true) return; // the lock first (its listener calls again)
    final want = l.site;
    if (want.isNotEmpty && s.site?.code != want) {
      final has = s.sites.any((x) => x.code == want && x.module('mechanical') != null);
      if (!has || _switchedFor == l.code) {
        l.done();
        _say(has ? 'Site $want could not be opened – open it and scan the QR code again.' : 'This QR code is for site $want – that site is not given to you.',
            has ? '$want site उघडली नाही – ती उघडा आणि QR code पुन्हा scan करा.' : 'हा QR code $want site चा आहे – ती site तुम्हाला दिलेली नाही.');
        return;
      }
      _switchedFor = l.code;
      _busy = true;
      // (a screen of the site before is not left open under the other site's – as "Change site" on Home)
      widget.nav.currentState?.popUntil((r) => r.isFirst);
      try {
        await s.chooseSite(want); // (the opening screen, then the app at that site)
      } finally {
        _busy = false;
      }
      _soon();
      return;
    }
    if (s.stage != Stage.ready) return; // Which site (a QR code without its site): he picks his site first
    final nav = widget.nav.currentState;
    if (nav == null) return;
    final code = l.code;
    l.done();
    await nav.push(MaterialPageRoute<void>(builder: (_) => CaptureScreen(code: code)));
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context); // (rebuilt when the session changes: the sign-in, the site, ready)
    if (ScanLink.i.code.isNotEmpty && (s.stage == Stage.ready || s.stage == Stage.pickSite)) _soon();
    return widget.child;
  }
}
