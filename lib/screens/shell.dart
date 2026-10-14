/* THE APP AFTER SIGN-IN: four tabs at the bottom – Home · Entries · Reports · Me (picture 1–3). The tabs keep their place when
 * switched. Back on another tab goes to Home first; on Home a second Back within 3 s leaves the app. */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/kinds.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'entries.dart';
import 'home.dart';
import 'me.dart';
import 'reports.dart';
import '../web/web_host.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  String entriesKind = '';
  DateTime? lastBack;
  final hostKey = GlobalKey<WebHostState>();

  @override
  void initState() {
    super.initState();
    webHost.reset();
    webHost.addListener(_hostChanged);
    // the web (for the modules not yet made for the phone) loads quietly in the background once Home is up
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) webHost.warm();
    });
  }

  @override
  void dispose() {
    webHost.removeListener(_hostChanged);
    super.dispose();
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
    final diesel = kKinds.any((k) => s.canSee(k.module));
    final reports = reportsOf(s).isNotEmpty;
    final pages = <(Widget, NavigationDestination)>[
      (
        HomeTab(
          onOpenEntries: (k) => setState(() {
            entriesKind = k;
            if (diesel) tab = 1;
          }),
          onOpenReports: () => setState(() => tab = diesel ? 2 : 1),
        ),
        const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home')
      ),
      if (diesel) (EntriesTab(kind: entriesKind), const NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt_rounded), label: 'Entries')),
      if (reports) (const ReportsTab(), const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Reports')),
      (const MeTab(), const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Me')),
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
