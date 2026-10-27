/* HOME (picture 1, 14-10-2026): the site's picture with "Namaskar" and the site; the diesel stock (total and each place), the
 * machinery working today and today's Log Book entries; the modules he may open; today's diesel work. Every number is the
 * server's, read now.
 *
 * (3.31.0, asked 20-10-2026 with his picture: "HE BGH SAME AS IT IS HAW AAHE") ≡ (every page he may open, and Call), the Rachana
 * mark and RCL ERP, search, the bell (approvals, missed calls, entries kept on the phone, a new version), the robot (Ask); his
 * site's photo with "Good Morning, Sujit 👋"; the site and Scan; the green stock card – the change since the start of the day and
 * the stock of each place in one bar; the four tiles; Modules (View All); no Rachana logo at the bottom any more. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/device.dart';
import '../core/format.dart';
import '../core/kinds.dart';
import '../core/push.dart' show pushUpdateTick;
import '../core/session.dart';
import '../core/update.dart';
import '../ui/ask_bot.dart';
import '../ui/help.dart' show showGuide;
import 'approvals.dart';
import 'me.dart' show KeptSheet;
import 'settings.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'assistant.dart';
import 'label_scan.dart';
import 'search.dart';
import 'admin.dart';
import 'billing.dart';
import 'breakdown.dart';
import 'call.dart';
import 'fuel_cards.dart' show FuelCardsScreen, rupees;
import 'verify.dart';
import 'logbook.dart';
import 'store.dart';
import 'masters.dart';
import '../ui/t.dart';
import '../ui/live.dart';

/// A module tile of Home: where it goes and who may see it.
class ModuleTile {
  const ModuleTile(this.en, this.mr, this.pic, this.color, this.soft, {this.page = '', this.native = '', this.perm = '', this.module = '', this.admin = false});
  final String en, mr, pic, page, native, perm, module;
  final Color color, soft;
  final bool admin;
  bool visible(Session s) {
    if (admin) return s.admin;
    if (module.isNotEmpty) return s.hasModule(module);
    if (native == 'diesel') return kKinds.any((k) => s.canSee(k.module));
    if (native == 'reports') return reportsOf(s).isNotEmpty;
    if (native == 'masters') return mastersOf(s).isNotEmpty;
    if (native == 'billing') return seesBilling(s);
    return perm.isEmpty || s.canSee(perm);
  }
}

const kModules = [
  ModuleTile('Machinery', 'यंत्रे', 'tractor', C.green, C.greenSoft, native: 'masters'), // (3.4.0) the app's own Master screens
  ModuleTile('Logbook', 'लॉगबुक', 'notebook', C.blue, C.blueSoft, native: 'logbook', perm: 'Log Book'),
  ModuleTile('Diesel', 'डिझेल', 'fuel_pump', C.green, C.greenSoft, native: 'diesel'),
  ModuleTile('Maintenance', 'देखभाल', 'wrench', C.orange, C.orangeSoft, native: 'breakdown', perm: 'Breakdown'), // (3.7.0) the app's own Breakdown
  ModuleTile('Billing', 'बिलिंग', 'receipt', C.purple, C.purpleSoft, native: 'billing'), // (3.8.0) the app's own Billing screens
  ModuleTile('Store', 'स्टोअर', 'package', C.amber, C.amberSoft, native: 'store', module: 'store'), // (3.10.0) the app's own Store screens
  ModuleTile('Reports', 'रिपोर्ट्स', 'bar_chart', C.blue, C.blueSoft, native: 'reports'),
  ModuleTile('Administration', 'प्रशासन', 'gear', C.slate, C.slateSoft, native: 'admin', admin: true), // (3.9.0) the app's own Admin screens
];

/// The reports of the web he may open – (3.1.8) every report of the web, one under the other, by his access.
List<(String, String, String, String)> reportsOf(Session s) => [
      if (s.canSee('Dashboard')) ('Dashboard', 'डॅशबोर्ड', 'dash', 'bar_chart'),
      if (s.canSee('Reports')) ...[
        if (!s.cardSite) ('Daily Inward & Issue', 'दैनिक आवक व वाटप', 'rdaily', 'calendar'),      // (3.45.0) not at a site on fuel cards (no stock) – as the web
        ('Monthly Diesel Issue', 'मासिक डिझेल वाटप', 'rmonthly', 'fuel_pump'),
        ('Monthly Diesel & Average', 'मासिक डिझेल व सरासरी', 'ravg', 'clipboard'),
        ('Actual vs Standard Average', 'प्रत्यक्ष व standard सरासरी', 'rp-average', 'bar_chart'),
        ('Machinery Diesel Ledger', 'यंत्राचे डिझेल खाते', 'rp-ledger', 'ledger'),
        if (!s.cardSite) ...[('Stock Register', 'स्टॉक रजिस्टर', 'rp-stock', 'oil_drum'), ('Diesel Purchase Register', 'डिझेल खरेदी रजिस्टर', 'rp-purchase', 'receipt')],
        ('Diesel Cost Report', 'डिझेल खर्च', 'rp-cost', 'receipt'),
        ('Machinery Cost Sheet', 'यंत्र खर्च', 'rp-mcost', 'tractor'),
        ('Owner / Vendor-wise Summary', 'मालक / vendor नुसार', 'rp-owner', 'office_building'),
        ('Type-wise Summary', 'प्रकारानुसार', 'rp-type', 'articulated_lorry'),
        ('Month vs Month', 'महिना विरुद्ध महिना', 'rp-compare', 'calendar'),
        ('Diesel Watch – signs of loss', 'डिझेल वॉच – गळतीची चिन्हे', 'rp-watch', 'shield'),
        ('Tank Check – System vs Physical', 'टँक तपासणी', 'rp-tank', 'oil_drum'),
        ('Debit Recovery Statement', 'डेबिट वसुली', 'rp-debit', 'receipt'),
        ('Log Book Debit Statement', 'Log Book डेबिट', 'rp-ldebit', 'receipt'), // (3.31.7, update-149)
      ],
      if (s.canSee('Bill Summary')) ('Bill Summary', 'बिल सारांश', 'breg', 'receipt'),
      if (s.canSee('Vendor Ledger')) ('Vendor Ledger', 'vendor खाते', 'vled', 'ledger'),
      if (s.canSee('Vendor Outstanding')) ('Vendor Outstanding', 'vendor बाकी', 'vout', 'ledger'),
    ];

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onOpenEntries, required this.onOpenReports, this.active = true});
  final ValueChanged<String> onOpenEntries;
  final VoidCallback onOpenReports;

  /// (update-155) Home is the tab on the screen (the shell says so): only then it loads after others' changes
  final bool active;
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _Act {
  _Act(this.kind, this.r);
  final Kind kind;
  final Map<String, dynamic> r;
}

class _HomeTabState extends State<HomeTab> with LiveWhenSeen<HomeTab> {
  bool loading = true;
  DateTime? at;
  int? logEntries, running;
  num? opening; // (3.31.0) the stock at the start of today (the Dashboard's opening) – for the change on the stock card
  List<_Act> acts = [];
  AppUpdate? update;

  Session? _ls;
  // (3.1.7) live: something changed on the server (another person, the web) – the figures load again by themselves
  // (update-155) only for what Home shows (diesel and stock, the Log Book, the machinery), and only when Home is seen – else
  // when it is seen again (lib/ui/live.dart)
  void _live() {
    if (mounted && (_ls?.lastChanged.any((g) => g == 'stock' || g == 'log' || g == 'master') ?? true)) liveChanged();
  }

  @override
  bool get liveActive => widget.active;
  @override
  void liveReload() => _load(quiet: true);

  @override
  void didUpdateWidget(covariant HomeTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) liveMaybe();
  }

  @override
  void dispose() {
    _ls?.dataTick.removeListener(_live);
    pushUpdateTick.removeListener(_newVersion);
    super.dispose();
  }

  // (3.42.0) a new version was told (Firebase – core/push.dart): its Update on Home now, not at the next opening
  void _newVersion() {
    if (!mounted) return;
    checkUpdate(SessionScope.read(context).api).then((u) {
      if (mounted && u != null) setState(() => update = u);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      final s = SessionScope.read(context);
      _ls = s..dataTick.addListener(_live);
      checkUpdate(s.api).then((u) {
        if (mounted && u != null) setState(() => update = u);
      });
      pushUpdateTick.addListener(_newVersion);
    });
  }

  Future<void> _load({bool init = false, bool quiet = false}) async {
    final s = SessionScope.read(context);
    if (!quiet) setState(() => loading = true);
    try {
      if (init) await s.loadInit();
      final day = s.today;
      final jobs = <Future<void>>[];
      final got = <_Act>[];
      for (final k in kKinds.where((k) => s.canSee(k.module))) {
        jobs.add(s.api.call(k.list, [{'from': day, 'to': day, 'all': true}]).then((r) {
          for (final x in ((r as Map)['rows'] as List? ?? []).whereType<Map>()) {
            got.add(_Act(k, x.cast<String, dynamic>()));
          }
        }).catchError((_) {}));
      }
      int? le, run;
      if (s.canSee('Log Book')) {
        jobs.add(s.api.call('getLogBookList', [{'from': day, 'to': day, 'all': true}]).then((r) {
          final rows = ((r as Map)['rows'] as List? ?? []).whereType<Map>().toList();
          le = rows.length;
          const off = ['Idle', 'Holiday', 'Breakdown'];
          run = rows.where((x) => !off.contains('${x['mode'] ?? x['unit'] ?? ''}')).map((x) => '${x['no']}').toSet().length;
        }).catchError((_) {}));
      }
      num? open;
      if (s.canSee('Dashboard')) {
        jobs.add(s.api.call('getDashboard', [{'from': day, 'to': day}]).then((r) {
          final locs = ((r as Map)['locations'] as List? ?? []).whereType<Map>().toList();
          if (locs.isNotEmpty) open = locs.fold<num>(0, (a, x) => a + (asNum(x['opening']) ?? 0));
        }).catchError((_) {}));
      }
      await Future.wait(jobs);
      got.sort((a, b) => '${b.r['id']}'.compareTo('${a.r['id']}'));
      if (!mounted) return;
      setState(() {
        acts = got;
        logEntries = le;
        running = run;
        opening = open;
        at = DateTime.now();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      if (!quiet) toast(context, errText(e), bad: true);
    }
  }

  Future<void> _module(ModuleTile m) async {
    HapticFeedback.selectionClick();
    if (m.native == 'diesel') {
      widget.onOpenEntries('');
      return;
    }
    if (m.native == 'logbook') {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LogBookScreen()));
      return;
    }
    if (m.native == 'reports') {
      widget.onOpenReports();
      return;
    }
    if (m.native == 'masters') {
      await openMasters(context);
      return;
    }
    if (m.native == 'breakdown') {
      await openBreakdown(context);
      return;
    }
    if (m.native == 'billing') {
      await openBilling(context);
      return;
    }
    if (m.native == 'admin') {
      await openAdmin(context);
      return;
    }
    if (m.native == 'store') {
      await openStore(context);
    }
    // (3.18.0) every module is the app's own screens – no web page in the app
  }

  Future<void> _site() async {
    final s = SessionScope.read(context);
    if (s.sites.length < 2) {
      toast(context, 'You have one site: ${s.siteName}.');
      return;
    }
    if (await ask(context, 'Change site?', bi('Open another of your sites.', 'दुसरी site उघडायची?'), yes: 'Change')) s.pickAnotherSite();
  }

  String get _hello {
    final h = SessionScope.read(context).clock().hour;
    return h < 12 ? 'Good Morning,' : (h < 17 ? 'Good Afternoon,' : 'Good Evening,');
  }

  /// (3.31.0) the bell: what waits for him – approvals, missed calls, entries kept on the phone, a new version
  Future<void> _bell() async {
    final s = SessionScope.read(context);
    final miss = s.rtc?.missN ?? 0;
    final rows = <(String, String, String, Color, Future<void> Function())>[
      if (s.crForMe > 0) ('Approvals', bi('${s.crForMe} waiting for you to approve', '${s.crForMe} तुमच्या मंजुरीसाठी थांबले आहेत'), 'clipboard', C.amberSoft, () async {
        await openApprovals(context);
        s.loadApprovals();
      }),
      if (miss > 0) ('Missed calls', bi('$miss missed – call back', '$miss चुकलेले कॉल – परत कॉल करा'), 'mobile_phone', C.greenSoft, () => openCallPick(context)),
      if (s.kept.isNotEmpty) ('Waiting on this phone', s.keptBad > 0 ? bi('${s.keptBad} not saved – open to see why', '${s.keptBad} सेव्ह झाल्या नाहीत – कारण पहा') : bi('${s.kept.length} to send when the network is back', 'नेटवर्क आल्यावर ${s.kept.length} पाठवायच्या'), 'calendar', s.keptBad > 0 ? C.redSoft : C.amberSoft, () => showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const KeptSheet())),
      if (update != null) ('New version ${update!.version}', bi('Update the app', 'ॲप update करा'), 'mobile_phone', C.blueSoft, () => runUpdate(context, update!)),
    ];
    final pick = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.edge, 0, Sp.edge, Sp.edge),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const TwoLang('For you', 'तुमच्यासाठी', size: 20, weight: FontWeight.w700),
            const SizedBox(height: 12),
            if (rows.isEmpty) const EmptyState('Nothing new', 'Approvals, missed calls and entries waiting on this phone show here.', pic: 'bell'),
            for (final (i, x) in rows.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.chips),
                child: Press(
                  onTap: () => Navigator.pop(c, i),
                  radius: 18,
                  shadow: false,
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(width: 46, height: 46, decoration: BoxDecoration(color: x.$4, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Pic(x.$3, size: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(x.$1, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                        Text(x.$2, style: const TextStyle(fontSize: 13, color: C.muted)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: C.faint),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
    if (pick != null && mounted) await rows[pick].$5();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final top = MediaQuery.of(context).padding.top;
    final first = s.name.split(' ').first;
    final mods = kModules.where((m) => m.visible(s)).toList();
    final locs = s.stockByLoc.entries.toList();
    final tiles = <Widget>[
      for (final (i, l) in locs.indexed)
        _MiniTile(pic: i == 0 ? 'fuel_pump' : 'oil_drum', en: l.key, mr: placeMr(l.key), value: '${fmtNum(l.value)} ${s.placeUnit(l.key) == 'kg' ? 'kg' : 'L'}', color: i == 0 ? C.redSoft : C.blueSoft),
      if (s.canSee('Log Book')) ...[
        _MiniTile(pic: 'tractor', en: 'Running', mr: 'चालू यंत्रे', value: running == null ? '–' : '$running / ${s.machines.where((m) => m.onSite(s.today)).length}', color: C.greenSoft),
        _MiniTile(pic: 'notebook', en: 'Logbook', mr: 'नोंदी (आज)', value: logEntries == null ? '–' : '$logEntries', color: C.purpleSoft),
      ],
    ];
    // (3.44.0, Mechanical update-163) a site with more than one fuel: each fuel's stock on its own – the first in big, the others under it
    final multi = s.multiFuel, f0 = multi ? s.siteFuels.first : 'Diesel', byFuel = <String, num>{};
    for (final l in locs) {
      byFuel[s.placeFuel(l.key)] = (byFuel[s.placeFuel(l.key)] ?? 0) + l.value;
    }
    final total = multi ? byFuel[f0] : s.stockTotal;
    final pct = (!multi && total != null && opening != null && opening! > 0) ? ((total - opening!) / opening! * 100) : null;
    final picH = 236 + top;
    return Scaffold(
      backgroundColor: C.bg,
      drawer: _HomeMenu(mods: mods, onModule: _module, onHelp: () => openHelp(context)),
      body: Builder(
        builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
          child: RefreshIndicator(
            color: C.green,
            edgeOffset: top,
            onRefresh: () => _load(init: true),
            child: ListView(padding: EdgeInsets.zero, children: [
              // ---------- his site's photo, the bar, "Good Morning, Sujit", the site ----------
              Stack(children: [
                Positioned(
                  left: 70,
                  right: 0,
                  top: 0,
                  height: picH,
                  child: Image.asset('assets/brand/site_home.jpg', fit: BoxFit.cover, alignment: const Alignment(.35, .1), filterQuality: FilterQuality.medium, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: picH,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [C.bg, Color(0xE6FAF8F2), Color(0x00FAF8F2)], stops: [.22, .45, .78]),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: picH,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCCFAF8F2), Color(0x00FAF8F2), Color(0x00FAF8F2), C.bg], stops: [0, .28, .7, 1]),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(6, top + 6, 12, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      IconButton(key: const Key('home-menu'), tooltip: tr('Menu'), visualDensity: VisualDensity.compact, onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu_rounded, size: 26, color: C.ink)),
                      Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                        child: Image.asset('assets/brand/rachana_mark.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('RCL ERP', maxLines: 1, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.greenDark, height: 1.1)),
                          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Fleet & Diesel Management', maxLines: 1, style: TextStyle(fontSize: 10.5, color: C.muted))),
                        ]),
                      ),
                      // (3.14.0) the search of the whole app (the web's Ctrl + K)
                      _RoundBtn(key: const Key('home-search'), icon: Icons.search_rounded, tip: 'Search', onTap: () => openSearch(context, entries: widget.onOpenEntries, reports: widget.onOpenReports)),
                      const SizedBox(width: 6),
                      ListenableBuilder(
                        listenable: s.rtc ?? ValueNotifier(0),
                        builder: (_, __) {
                          final n = s.crForMe + (s.rtc?.missN ?? 0) + s.keptBad + (update == null ? 0 : 1);
                          return Badge(
                          isLabelVisible: n > 0,
                          label: Text('$n'),
                          child: _RoundBtn(key: const Key('home-bell'), icon: Icons.notifications_none_rounded, tip: 'For you', onTap: _bell),
                        );
                        },
                      ),
                      const SizedBox(width: 6),
                      const AskBot(key: Key('home-ask'), size: 38),
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 14, 0, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_hello, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: C.greenDark)),
                        Row(children: [
                          Flexible(child: Text(first.isEmpty ? 'Namaskar' : first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15))),
                          const SizedBox(width: 6),
                          const Text('👋', style: TextStyle(fontSize: 24)),
                        ]),
                        const Text('Have a productive day!', style: TextStyle(fontSize: 13, color: C.muted)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Row(children: [
                        Expanded(
                          child: Press(
                            onTap: _site,
                            radius: 18,
                            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                            child: Row(children: [
                              const Icon(Icons.location_on_rounded, color: C.green, size: 26),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(s.siteName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                                  Text(s.sites.length > 1 ? bi('Tap to change site', 'साइट बदला') : (s.site?.code ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted)),
                                ]),
                              ),
                              if (s.sites.length > 1) const Icon(Icons.chevron_right_rounded, color: C.faint),
                            ]),
                          ),
                        ),
                        // (3.14.0) a machinery's QR label: Diesel Issue / Log Book entry / its diesel ledger for it
                        // (3.19.0) the phone's live camera – not on a computer
                        if (!onComputer) ...[
                          const SizedBox(width: 8),
                          Press(
                            key: const Key('home-scan'),
                            onTap: () => scanMachineLabel(context, onSaved: () => _load()),
                            radius: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            child: const Column(children: [
                              Icon(Icons.qr_code_scanner_rounded, color: C.greenDark, size: 24),
                              Text('Scan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.greenDark)),
                            ]),
                          ),
                        ],
                      ]),
                    ),
                  ]),
                ),
              ]),
              // ---------- the stock card (green) ----------
              // (3.45.0, Mechanical update-164) a site on fuel cards (HO) keeps no stock: the cards' balances in its place
              if (s.cardSite)
                _HomeCards(at: at, onRefresh: () => _load(init: true))
              else
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.edge, 12, Sp.edge, 0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.greenLight, C.green, C.greenEnd]),
                    boxShadow: [BoxShadow(color: C.green.withValues(alpha: .3), blurRadius: 22, offset: const Offset(0, 10))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .1), border: Border.all(color: Colors.white.withValues(alpha: .45), width: 1.5)),
                        alignment: Alignment.center,
                        child: const Icon(Icons.local_gas_station_outlined, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          multi
                              ? Text('$f0 stock', mr: '$f0 साठा', style: const TextStyle(fontSize: 14, color: Color(0xE6FFFFFF), fontWeight: FontWeight.w500))
                              : const Text('Total Diesel Stock', mr: 'डिझेल साठा (एकूण)', style: TextStyle(fontSize: 14, color: Color(0xE6FFFFFF), fontWeight: FontWeight.w500)),
                          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(total == null ? '–' : '${fmtNum(total)} ${f0 == 'CNG' ? 'kg' : 'L'}', key: const Key('home-stock'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
                              ),
                            ),
                            if (pct != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                key: const Key('home-pct'),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(pct >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: Colors.white),
                                  const SizedBox(width: 2),
                                  Text('${pct >= 0 ? '+' : '−'}${fmtNum((pct.abs() * 10).round() / 10)}%', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                ]),
                              ),
                            ],
                          ]),
                        ]),
                      ),
                      IconButton(
                        tooltip: tr('Refresh'),
                        style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .14), fixedSize: const Size(40, 40)),
                        onPressed: () => _load(init: true),
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                      ),
                    ]),
                    if (multi)      // the other fuels, never added to it
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(spacing: 8, runSpacing: 6, children: [
                          for (final f in s.siteFuels.skip(1))
                            Container(
                              key: Key('home-fuel-$f'),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
                              child: Text('$f ${fmtNum(byFuel[f] ?? 0)} ${f == 'CNG' ? 'kg' : 'L'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                        ]),
                      ),
                    if (!multi && locs.isNotEmpty && (total ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 8,
                          child: Row(children: [
                            for (final (i, l) in locs.indexed)
                              if (l.value > 0) Expanded(flex: (l.value * 1000 ~/ total!).clamp(1, 1000), child: ColoredBox(color: _locTone[i % _locTone.length])),
                          ]),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      for (final (i, l) in locs.indexed)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: _locTone[i % _locTone.length], shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text('${l.key} ${fmtNum(l.value)} ${s.placeUnit(l.key) == 'kg' ? 'kg' : 'L'}', style: const TextStyle(fontSize: 11.5, color: Color(0xE6FFFFFF), fontWeight: FontWeight.w500)),
                        ]),
                      if (at != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.schedule_rounded, size: 13, color: Color(0xCCFFFFFF)),
                          const SizedBox(width: 4),
                          Text('Updated ${at!.hour % 12 == 0 ? 12 : at!.hour % 12}:${at!.minute.toString().padLeft(2, '0')} ${at!.hour < 12 ? 'AM' : 'PM'}', style: const TextStyle(fontSize: 11.5, color: Color(0xCCFFFFFF))),
                        ]),
                    ]),
                  ]),
                ),
              ),
              // ---------- the four tiles ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.edge, 12, Sp.edge, 0),
                child: tiles.length <= 4
                    ? Row(children: [for (final (i, t) in tiles.indexed) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: t)]])
                    : SizedBox(height: 96, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: tiles.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) => SizedBox(width: 80, child: tiles[i]))),
              ),
              const SizedBox(height: Sp.block),
              if (update != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.edge, 0, Sp.edge, Sp.block),
                  child: Press(
                    onTap: () => runUpdate(context, update!),
                    color: C.greenDeep,
                    border: C.greenDeep,
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const Icon(Icons.system_update_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: TwoLang('New version ${update!.version} – Update', 'नवीन version आली आहे', color: Colors.white, size: 15.5)),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ]),
                  ),
                ),
              // (3.14.0) the notice of the site (Admin → Rules of this site), shown to everybody – as the web's line at the top
              if ('${s.siteRules['announce'] ?? ''}'.trim().isNotEmpty)
                Container(
                  key: const Key('home-notice'),
                  margin: const EdgeInsets.fromLTRB(Sp.edge, 0, Sp.edge, Sp.block),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.amber.withValues(alpha: .35))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.campaign_rounded, color: C.amber),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${s.siteRules['announce']}'.trim(), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.35))),
                  ]),
                ),
              // (3.1.11, update-118) his entries in verification: waiting / sent back / approved – tap: each, with "Remind"
              const VerifyStrip(days: 1, margin: EdgeInsets.fromLTRB(Sp.edge, 0, Sp.edge, Sp.block)),
              // ---------- the modules ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.edge, 0, Sp.edge, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Expanded(child: TwoLang('Modules', 'विभाग', size: 19, weight: FontWeight.w800)),
                    TextButton(
                      key: const Key('home-all'),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      style: TextButton.styleFrom(foregroundColor: C.goldInk, padding: const EdgeInsets.symmetric(horizontal: 6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Text('View All', style: const TextStyle(fontWeight: FontWeight.w700, color: C.goldInk)), const Icon(Icons.arrow_forward_rounded, size: 18)]),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: .95,
                    children: [for (final m in mods) _ModuleCard(m: m, onTap: () => _module(m))],
                  ),
                  const SizedBox(height: 22),
                  // ---------- today's work ----------
                  if (kKinds.any((k) => s.canSee(k.module)))
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.line)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SectionTitle("Today's Activity", mr: 'आजची कामे · ${showDate(s.today)}', action: 'View All', onAction: () => widget.onOpenEntries('')),
                        if (loading && acts.isEmpty)
                          ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: Shimmer(height: 70)))
                        else if (acts.isEmpty)
                          s.cardSite
                              ? const EmptyState('No fill today yet', 'The fills of today (card or Cash) show here.', pic: 'fuel_pump')
                              : const EmptyState('No diesel entry today yet', 'Issue, Inward and Transfer of today show here.', pic: 'fuel_pump')
                        else
                          for (final a in acts.take(6)) _ActRow(a: a, onTap: () => widget.onOpenEntries(a.kind.key)),
                      ]),
                    ),
                  const SizedBox(height: 28),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// (3.31.0) the colours of the places in the stock bar (gold, light green, …)
const _locTone = [C.goldLight, Color(0xFF90D7AE), Color(0xFFACC0F5), Color(0xFFECAA98)];

/// (3.31.0) ≡ – every module he may open, Call, Approvals, My settings, Help.
class _HomeMenu extends StatelessWidget {
  const _HomeMenu({required this.mods, required this.onModule, required this.onHelp});
  final List<ModuleTile> mods;
  final Future<void> Function(ModuleTile m) onModule;

  /// Help opens from Home (the menu closes first).
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    Widget row(String key, String pic, String en, String mr, Color soft, VoidCallback onTap, {Widget? trailing}) => ListTile(
          key: Key(key),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(13)), alignment: Alignment.center, child: Pic(pic, size: 28)),
          title: Text(en, mr: mr, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
          trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: C.faint),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
        );
    return Drawer(
      backgroundColor: C.bg,
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(8, 12, 8, 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Row(children: [
              Container(width: 44, height: 44, padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: C.line)), child: Image.asset('assets/brand/rachana_mark.png')),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('RCL ERP', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.greenDark)),
                  Text(s.siteName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted)),
                ]),
              ),
            ]),
          ),
          const Padding(padding: EdgeInsets.fromLTRB(12, 4, 12, 6), child: Text('Modules', mr: 'विभाग', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted))),
          for (final m in mods) row('menu-${m.en}', m.pic, m.en, m.mr, m.soft, () => onModule(m)),
          const Divider(height: 24, indent: 12, endIndent: 12),
          // (3.26.0) a call with a web or app user (Android) – the number of missed calls on it
          if (s.rtc != null)
            row('home-call', 'mobile_phone', 'Call', 'कॉल', C.greenSoft, () => openCallPick(context),
                trailing: (s.rtc?.missN ?? 0) > 0 ? Badge(label: Text('${s.rtc!.missN}'), child: const Icon(Icons.chevron_right_rounded, color: C.faint)) : null),
          row('menu-approvals', 'clipboard', 'Approvals', 'मंजुरी', C.amberSoft, () async {
            await openApprovals(context);
            s.loadApprovals();
          }, trailing: s.crForMe > 0 ? Badge(label: Text('${s.crForMe}'), child: const Icon(Icons.chevron_right_rounded, color: C.faint)) : null),
          row('menu-settings', 'gear', 'My settings', 'माझ्या सेटिंग्ज', C.slateSoft, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()))),
          row('menu-help', 'robot', 'Help & Support', 'मदत', C.blueSoft, onHelp),
        ]),
      ),
    );
  }
}

/// (3.31.0) Help & Support: ask the robot, or the guide of a page (the web's "?").
Future<void> openHelp(BuildContext context) async {
  final s = SessionScope.read(context);
  // (3.45.0) a site on fuel cards has no Inward / Transfer – its page Fuel Cards instead
  final pages = [
    ('diesel', 'Diesel Issue', 'fuel_pump'),
    if (!s.cardSite) ...[('inward', 'Diesel Inward', 'inbox_tray'), ('transfer', 'Diesel Transfer', 'left-right_arrow')],
    if (s.cardSite && s.canSee('Fuel Cards')) ('cards', 'Fuel Cards', 'ledger'),
    if (s.cardSite && s.canSee('Maintenance')) ('mnt', 'Maintenance', 'wrench'),      // (3.46.0)
    ('log', 'Log Book', 'notebook'), ('brk', 'Breakdown', 'wrench'), ('approvals', 'Approvals', 'clipboard'), ('settings', 'My settings', 'gear'),
  ];
  final pick = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(Sp.edge, 0, Sp.edge, Sp.edge), children: [
        const TwoLang('Help & Support', 'मदत', size: 20, weight: FontWeight.w700),
        const SizedBox(height: 12),
        Press(
          key: const Key('help-ask'),
          onTap: () => Navigator.pop(c, '_ask'),
          radius: 18,
          shadow: false,
          color: C.greenSoft,
          border: C.greenSoft,
          padding: const EdgeInsets.all(12),
          child: const Row(children: [
            Pic('robot', size: 36),
            SizedBox(width: 12),
            Expanded(child: TwoLang('Ask the app', 'ॲपला विचारा', size: 16, weight: FontWeight.w700)),
            Icon(Icons.chevron_right_rounded, color: C.faint),
          ]),
        ),
        const SizedBox(height: 14),
        const Text('Guides', mr: 'मार्गदर्शन', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted)),
        const SizedBox(height: 6),
        for (final p in pages)
          ListTile(
            key: Key('help-${p.$1}'),
            contentPadding: EdgeInsets.zero,
            leading: Pic(p.$3, size: 30),
            title: Text(p.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded, color: C.faint),
            onTap: () => Navigator.pop(c, p.$1),
          ),
      ]),
    ),
  );
  if (pick == null || !context.mounted) return;
  if (pick == '_ask') {
    await openAssistant(context);
  } else {
    await showGuide(context, pick);
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({super.key, required this.icon, required this.tip, required this.onTap});
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: C.line)),
          child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(7), child: Icon(icon, color: C.greenDark, size: 22))),
        ),
      );
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({required this.pic, required this.en, required this.mr, required this.value, required this.color});
  final String pic, en, mr, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        height: 96,
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Pic(pic, size: 30),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: const TextStyle(fontSize: 10.5, color: C.muted, fontWeight: FontWeight.w500))),
        ]),
      );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.m, required this.onTap});
  final ModuleTile m;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        radius: 18,
        color: m.soft,
        border: m.soft,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Pic(m.pic, size: 34),
          const SizedBox(height: 6),
          SizedBox(
            height: 16,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(m.en, mr: m.mr, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          ),
        ]),
      );
}

class _ActRow extends StatelessWidget {
  const _ActRow({required this.a, required this.onTap});
  final _Act a;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final r = a.r, k = a.kind;
    final title = switch (k.key) {
      'issue' => '${r['no'] ?? ''}  •  ${fmtNum(asNum(r['qty']))} L',
      'inward' => '${'${r['pump'] ?? ''}'.isEmpty ? 'Received' : r['pump']}  •  ${fmtNum(asNum(r['qty']))} L',
      _ => '${r['from'] ?? ''} › ${r['to'] ?? ''}  •  ${fmtNum(asNum(r['qty']))} L',
    };
    final sub = switch (k.key) {
      'issue' => '${r['driver'] ?? ''}'.isNotEmpty ? 'Operator: ${r['driver']}' : '${r['type'] ?? ''} · ${r['source'] ?? ''}',
      'inward' => 'Received at ${r['location'] ?? ''}',
      _ => '${r['remark'] ?? ''}'.isNotEmpty ? '${r['remark']}' : 'By: ${r['enteredBy'] ?? ''}',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Press(
        onTap: onTap,
        radius: 18,
        shadow: false,
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: k.soft, borderRadius: BorderRadius.circular(15)), alignment: Alignment.center, child: Pic(k.key == 'issue' ? picOfType('${r['type'] ?? ''}') : k.pic, size: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.en, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ]),
          ),
          if ('${r['shift'] ?? ''}'.isNotEmpty) Pill('${r['shift']}', color: k.color, bg: k.soft),
          const Icon(Icons.chevron_right_rounded, color: C.faint),
        ]),
      ),
    );
  }
}

/// (3.45.0, Mechanical update-164) Home at a site on fuel cards (HO): every card's balance now (opening + payments − fills), the total
/// of the Active cards in big; a card short of money in red. Tap: the page Fuel Cards (when he may open it).
class _HomeCards extends StatelessWidget {
  const _HomeCards({required this.at, required this.onRefresh});
  final DateTime? at;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final act = s.cards.where((c) => c.active).toList();
    final total = act.fold<num>(0, (a, c) => a + c.balance);
    final open = s.canSee('Fuel Cards') ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FuelCardsScreen())) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.edge, 12, Sp.edge, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('home-cards'),
          borderRadius: BorderRadius.circular(24),
          onTap: open,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.greenLight, C.green, C.greenEnd]),
              boxShadow: [BoxShadow(color: C.green.withValues(alpha: .3), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .1), border: Border.all(color: Colors.white.withValues(alpha: .45), width: 1.5)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Fuel cards – balance', mr: 'फ्युएल कार्ड – शिल्लक', style: TextStyle(fontSize: 14, color: Color(0xE6FFFFFF), fontWeight: FontWeight.w500)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(act.isEmpty ? '–' : rupees(total), key: const Key('home-cards-total'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: tr('Refresh'),
                  style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .14), fixedSize: const Size(40, 40)),
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                ),
              ]),
              const SizedBox(height: 8),
              if (act.isEmpty)
                const Text('No fuel card yet – add them in Fuel Cards.', mr: 'अजून fuel card नाही – Fuel Cards मध्ये भरा.', style: TextStyle(fontSize: 12.5, color: Color(0xE6FFFFFF)))
              else
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final c in act)
                    Container(
                      key: Key('home-card-${c.name}'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: c.balance < 0 ? C.red : Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
                      child: Text('${c.name}${c.last4.isEmpty ? '' : ' ••${c.last4}'}  ${rupees(c.balance)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                ]),
              if (at != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    const Icon(Icons.schedule_rounded, size: 13, color: Color(0xCCFFFFFF)),
                    const SizedBox(width: 4),
                    Text('Updated ${at!.hour % 12 == 0 ? 12 : at!.hour % 12}:${at!.minute.toString().padLeft(2, '0')} ${at!.hour < 12 ? 'AM' : 'PM'}', style: const TextStyle(fontSize: 11.5, color: Color(0xCCFFFFFF))),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
