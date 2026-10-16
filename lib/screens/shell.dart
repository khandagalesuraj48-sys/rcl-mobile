/* THE APP AFTER SIGN-IN: four tabs at the bottom – Home · Entries · Reports · Me (picture 1–3). The tabs keep their place when
 * switched. Back on another tab goes to Home first; on Home a second Back within 3 s leaves the app. */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/kinds.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'entries.dart';
import 'home.dart';
import 'me.dart';
import 'reports.dart';
import 'start_page.dart';
import '../web/web_host.dart';
import '../ui/t.dart' show tr;

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;
  Session? _s;
  String entriesKind = '';
  int entriesOpen = 0;
  DateTime? lastBack;
  final hostKey = GlobalKey<WebHostState>();
  Timer? warmUp;

  @override
  void initState() {
    super.initState();
    webHost.reset();
    webHost.addListener(_hostChanged);
    // (3.1.7) live: while the app is on the screen it hears what changed (Session.liveTick) and sends what is kept on the phone
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _s = SessionScope.read(context)
        ..keptNote.addListener(_note)
        ..startLive();
      _start();
    });
    // the web (for the modules not yet made for the phone) loads quietly in the background once Home is up
    warmUp = Timer(const Duration(seconds: 4), () {
      if (mounted) webHost.warm();
    });
  }

  @override
  void dispose() {
    warmUp?.cancel();
    webHost.removeListener(_hostChanged);
    WidgetsBinding.instance.removeObserver(this);
    _s?.keptNote.removeListener(_note);
    _s?.stopLive();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _s?.startLive();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _s?.stopLive();
    }
  }

  void _note() {
    final m = _s?.keptNote.value ?? '';
    if (m.isEmpty || !mounted) return;
    toast(context, m, bad: m.contains('not saved'));
    _s!.keptNote.value = '';
  }

  /// (3.14.0) His start page (Settings → "Page to open after sign-in"), once his settings have come.
  Future<void> _start() async {
    final s = _s;
    if (s == null) return;
    await s.prefsReady;
    if (!mounted) return;
    await openStartPage(context, s, s.pref('start'), entries: (k) {
      final diesel = kKinds.any((x) => s.canSee(x.module)) || s.canSee('Log Book');
      setState(() {
        entriesKind = k;
        entriesOpen++;
        if (diesel) tab = 1;
      });
    });
  }

  void _hostChanged() {
    if (mounted) setState(() {});
  }

  void _go(int i) {
    if (i == tab) return;
    HapticFeedback.selectionClick();
    setState(() => tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final diesel = kKinds.any((k) => s.canSee(k.module)) || s.canSee('Log Book');      // (3.1.8) Entries: diesel pages and the Log Book
    final reports = reportsOf(s).isNotEmpty;
    final pages = <(Widget, NavigationDestination)>[
      (
        HomeTab(
          onOpenEntries: (k) => setState(() {
            entriesKind = k;
            entriesOpen++;
            if (diesel) tab = 1;
          }),
          onOpenReports: () => setState(() => tab = diesel ? 2 : 1),
        ),
        NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: tr('Home'))
      ),
      if (diesel) (EntriesTab(kind: entriesKind, open: entriesOpen), NavigationDestination(icon: const Icon(Icons.list_alt_outlined), selectedIcon: const Icon(Icons.list_alt_rounded), label: tr('Entries'))),
      if (reports) (const ReportsTab(), NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart_rounded), label: tr('Reports'))),
      (
        const MeTab(),
        NavigationDestination(
          // (3.1.7) a number: what waits for him to approve, and entries kept on this phone that were not saved
          icon: Badge(isLabelVisible: s.crForMe + s.keptBad > 0, label: Text('${s.crForMe + s.keptBad}'), child: const Icon(Icons.person_outline_rounded)),
          selectedIcon: Badge(isLabelVisible: s.crForMe + s.keptBad > 0, label: Text('${s.crForMe + s.keptBad}'), child: const Icon(Icons.person_rounded)),
          label: tr('Me'),
        )
      ),
    ];
    final cur = tab.clamp(0, pages.length - 1);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (webHost.open) {
          hostKey.currentState?.back();
          return;
        }
        if (cur != 0) {
          setState(() => tab = 0);
          return;
        }
        final now = DateTime.now();
        if (lastBack != null && now.difference(lastBack!) < const Duration(seconds: 3)) {
          SystemNavigator.pop();
          return;
        }
        lastBack = now;
        toast(context, 'Press Back again to leave the app.');
      },
      child: Stack(children: [
        Scaffold(
        body: IndexedStack(index: cur, children: [for (final p in pages) p.$1]),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 16, offset: const Offset(0, -4))]),
          child: NavigationBar(
            selectedIndex: cur,
            onDestinationSelected: _go,
            backgroundColor: Colors.white,
            indicatorColor: C.greenChip,
            destinations: [for (final p in pages) p.$2],
          ),
        ),
        ),
        // the one web view (modules not yet made for the phone) – kept alive, shown only when such a module is open
        if (webHost.started) Positioned.fill(child: Offstage(offstage: !webHost.open, child: WebHost(key: hostKey))),
      ]),
    );
  }
}
