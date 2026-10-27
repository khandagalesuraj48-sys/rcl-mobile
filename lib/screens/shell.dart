/* THE APP AFTER SIGN-IN: four tabs at the bottom – Home · Entries · Reports · Me (picture 1–3). The tabs keep their place when
 * switched.
 * (3.31.0, asked 20-10-2026 with his picture) the bar at the bottom: green, rounded, the chosen tab in its own pill (Reports in
 * gold), the gold + in the middle – a new entry (only the ones he may add).
 * (3.31.0, asked 20-10-2026: "jewa mi entry madhun diesel issue sathi jatoy tewa back dabale ki entry madhe yeyla haw … ek back
 * mhanje ekach back ek step madhe") Back goes one step back, to where he came from: the Entries list from a diesel page, the tab
 * he came from; on Home a second Back within 3 s leaves the app (as before). */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/kinds.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'breakdown.dart';
import 'entries.dart';
import 'forms.dart' show newEntry;
import 'home.dart';
import 'logbook.dart';
import 'me.dart';
import 'reports.dart';
import 'store.dart';
import 'assistant.dart' show shellEntries, shellReports;
import 'start_page.dart';
import '../ui/t.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  String tab = 'home';

  /// (3.31.0) the tabs he came from – Back goes to them, one at a time
  final hist = <String>[];
  Session? _s;
  String entriesKind = '';
  int entriesOpen = 0;
  DateTime? lastBack;

  void _to(String t) {
    if (t == tab) return;
    hist.remove(t);
    hist.add(tab);
    tab = t;
    _s?.showing(t); // (update-155) the live sync's rhythm follows the tab on the screen
  }

  /// The Entries tab of a diesel page (issue / inward / transfer).
  void _entries(String k) {
    final s = _s ?? SessionScope.read(context);
    final diesel = kKinds.any((x) => s.canSee(x.module)) || s.canSee('Log Book');
    setState(() {
      entriesKind = k;
      entriesOpen++;
      if (diesel) _to('entries');
    });
  }

  @override
  void initState() {
    super.initState();
    shellEntries = _entries; // (3.16.0) the assistant opened from a help card can open the Entries tab too
    shellReports = () {
      if (mounted && reportsOf(SessionScope.read(context)).isNotEmpty) _go('reports');
    };
    // (3.1.7) live: while the app is on the screen it hears what changed (Session.liveTick) and sends what is kept on the phone
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _s = SessionScope.read(context)
        ..keptNote.addListener(_note)
        ..startLive();
      _start();
    });
  }

  @override
  void dispose() {
    if (shellEntries == _entries) shellEntries = null;
    shellReports = null;
    WidgetsBinding.instance.removeObserver(this);
    _s?.keptNote.removeListener(_note);
    _s?.stopLive();
    _s?.rtcOff(); // (3.26.0) another site / signed out: the call ends
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
    await s.checkBrief(); // (3.15.0) the daily summary, once a day – a red dot on the robot (Ask)
    if (!mounted) return;
    await openStartPage(context, s, s.pref('start'), entries: _entries);
  }

  void _go(String t) {
    if (t == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _to(t));
  }

  /// (3.31.0) the gold + : the new entries he may add – one tap opens its form
  Future<void> _plus() async {
    final s = SessionScope.read(context);
    HapticFeedback.selectionClick();
    final tankers = s.machines.any((m) => m.onSite(s.today) && m.waterTanker);
    final items = <(String, String, String, Color, Future<void> Function())>[
      for (final k in kKinds.where((k) => s.canEdit(k.module)))
        (k.en, k.mr, k.pic, k.soft, () async {
          if (await newEntry(context, k)) _entries(k.key);
        }),
      if (s.canEdit('Log Book')) ('Log Book entry', 'लॉग बुक नोंद', 'notebook', C.purpleSoft, () => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LogForm()))),
      if (s.canEdit('Log Book') && tankers) ('Tanker trip', 'टँकर फेरी', 'delivery_truck', C.blueSoft, () => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => TankerScreen(date: s.today)))),
      if (s.canEdit('Breakdown')) ('Breakdown', 'ब्रेकडाऊन', 'wrench', C.orangeSoft, () => openBreakdown(context)),
      if (s.hasModule('store')) ('Store', 'स्टोअर', 'package', C.amberSoft, () => openStore(context)),
    ];
    if (items.isEmpty) {
      toast(context, bi('You may not add entries. Ask the Admin for access.', 'तुम्हाला एंट्री करायची परवानगी नाही. Admin ला विचारा.'));
      return;
    }
    final pick = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.edge, 0, Sp.edge, Sp.edge),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const TwoLang('New entry', 'नवीन एन्ट्री', size: 20, weight: FontWeight.w700),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Sp.chips,
              crossAxisSpacing: Sp.chips,
              childAspectRatio: .95,
              children: [
                for (final (i, x) in items.indexed)
                  Press(
                    key: Key('plus-${x.$1}'),
                    onTap: () => Navigator.pop(c, i),
                    color: x.$4,
                    border: x.$4,
                    shadow: false,
                    radius: 18,
                    padding: const EdgeInsets.all(8),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Pic(x.$3, size: 38),
                      const SizedBox(height: 6),
                      Text(x.$1, mr: x.$2, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.15)),
                    ]),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
    if (pick != null && mounted) await items[pick].$5();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final diesel = kKinds.any((k) => s.canSee(k.module)) || s.canSee('Log Book');      // (3.1.8) Entries: diesel pages and the Log Book
    final reports = reportsOf(s).isNotEmpty;
    // (update-155) the tab on the screen (as "cur" below): Home and Entries load after others' changes only when they are seen
    final seen = (tab == 'entries' && diesel) || (tab == 'reports' && reports) || tab == 'me' ? tab : 'home';
    // (3.48.0) each tab in its own keeper: a hidden one is not built again (_TabKeep)
    final pages = <String, Widget>{
      'home': HomeTab(onOpenEntries: _entries, onOpenReports: () => _go(reports ? 'reports' : 'home'), active: seen == 'home'),
      if (diesel) 'entries': EntriesTab(kind: entriesKind, open: entriesOpen, active: tab == 'entries'),
      if (reports) 'reports': ReportsTab(active: tab == 'reports'),
      'me': const MeTab(),
    }.map((k, w) => MapEntry(k, _TabKeep(key: ValueKey('tab-$k'), on: k == seen, child: w)));
    final keys = pages.keys.toList();
    final cur = pages.containsKey(tab) ? tab : 'home';
    final meCount = s.crForMe + s.keptBad;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // (3.31.0) one step back: a diesel page goes back to the Entries list first
        if (cur == 'entries' && (entriesBack?.call() ?? false)) return;
        while (hist.isNotEmpty) {
          final t = hist.removeLast();
          if (pages.containsKey(t) && t != cur) {
            setState(() => tab = t);
            return;
          }
        }
        if (cur != 'home') {
          setState(() => tab = 'home');
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
      child: Scaffold(
        body: IndexedStack(index: keys.indexOf(cur), children: [for (final k in keys) pages[k]!]),
        bottomNavigationBar: _Bar(
          tab: cur,
          tabs: keys,
          meCount: meCount,
          onTab: _go,
          onPlus: _plus,
        ),
      ),
    );
  }
}

/* (3.48.0, the performance work – asked 27-10-2026, measured: every redraw of the session – a stock, a count of approvals –
 * built all four tabs again, the three hidden under the IndexedStack too) A TAB THAT IS NOT SEEN IS NOT BUILT AGAIN: the
 * session's redraws reach it only while it is the tab on the screen; one that came meanwhile is made once, the moment it is seen
 * again. What it does by itself goes on as before (its lists still load after others' changes – ui/live.dart – and its own
 * setState still draws it). */
class _TabKeep extends StatefulWidget {
  const _TabKeep({super.key, required this.on, required this.child});
  final bool on;
  final Widget child;
  @override
  State<_TabKeep> createState() => _TabKeepState();
}

class _TabKeepState extends State<_TabKeep> {
  _Relay? _r;
  Widget? _kept;
  int _gen = 0;

  @override
  void didUpdateWidget(covariant _TabKeep old) {
    super.didUpdateWidget(old);
    final r = _r;
    if (r != null) {
      r.on = widget.on;
      if (widget.on && r.missed) {
        r.missed = false;
        _gen++; // a redraw came while it was hidden: once now
      }
    }
    if (widget.on || old.on) _kept = null; // seen – or just hidden (it is told so): built with the new one
  }

  @override
  void dispose() {
    _r?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.read(context);
    final r = _r ??= _Relay(s)..on = widget.on;
    return _kept ??= SessionScope(session: s, relay: r, gen: _gen, child: widget.child);
  }
}

/// The session's redraws for one tab: passed on while it is seen, else only marked.
class _Relay extends ChangeNotifier {
  _Relay(this.s) {
    s.addListener(_heard);
  }
  final Session s;
  bool on = true, missed = false;
  void _heard() {
    if (on) {
      notifyListeners();
    } else {
      missed = true;
    }
  }

  @override
  void dispose() {
    s.removeListener(_heard);
    super.dispose();
  }
}

/// (3.31.0) the bar at the bottom of his picture: green, rounded, the chosen tab in a pill, the gold + in the middle.
class _Bar extends StatelessWidget {
  const _Bar({required this.tab, required this.tabs, required this.meCount, required this.onTab, required this.onPlus});
  final String tab;
  final List<String> tabs;
  final int meCount;
  final ValueChanged<String> onTab;
  final VoidCallback onPlus;

  static const _info = {
    'home': ('Home', Icons.home_outlined, Icons.home_rounded),
    'entries': ('Entries', Icons.list_alt_outlined, Icons.list_alt_rounded),
    'reports': ('Reports', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    'me': ('Me', Icons.person_outline_rounded, Icons.person_rounded),
  };

  Widget _item(String k) {
    final on = k == tab, i = _info[k]!;
    final gold = k == 'reports';
    Widget icon = AnimatedScale(scale: on ? 1.1 : 1, duration: const Duration(milliseconds: 260), curve: Curves.easeOutBack, child: Icon(on ? i.$3 : i.$2, size: 24, color: Colors.white.withValues(alpha: on ? 1 : .78)));
    if (k == 'me' && meCount > 0) icon = Badge(label: Text('$meCount'), child: icon);
    return Expanded(
      child: Semantics(
        selected: on,
        button: true,
        child: InkWell(
          key: Key('tab-$k'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => onTab(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: on && !gold ? Colors.white.withValues(alpha: .16) : null,
              gradient: on && gold ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.goldLight, C.gold]) : null,
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              icon,
              const SizedBox(height: 2),
              Text(i.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: Colors.white.withValues(alpha: on ? 1 : .8))),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final left = [for (final k in tabs) if (k == 'home' || k == 'entries') k];
    final right = [for (final k in tabs) if (k == 'reports' || k == 'me') k];
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 8 + bottom),
      child: SizedBox(
        height: 70,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.bar, C.barDeep]),
                boxShadow: [BoxShadow(color: C.greenDeep.withValues(alpha: .28), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  for (final k in left) _item(k),
                  const SizedBox(width: 74),
                  for (final k in right) _item(k),
                ]),
              ),
            ),
          ),
          // the gold + (a new entry)
          Positioned(
            top: -24,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                button: true,
                label: tr('New entry'),
                child: Material(
                  key: const Key('tab-plus'),
                  shape: const CircleBorder(side: BorderSide(color: C.bg, width: 4)),
                  elevation: 6,
                  shadowColor: C.gold.withValues(alpha: .6),
                  color: C.gold,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPlus,
                    child: Ink(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.goldLight, C.gold])),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
