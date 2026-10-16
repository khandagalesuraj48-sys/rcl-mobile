/* HOME (picture 1, 14-10-2026): the site's picture with "Namaskar" and the site; the diesel stock (total and each place), the
 * machinery working today and today's Log Book entries; the modules he may open; today's diesel work. Every number is the
 * server's, read now. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/kinds.dart';
import '../core/session.dart';
import '../core/update.dart';
import '../ui/brand.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../web/web_host.dart';
import 'assistant.dart';
import 'label_scan.dart';
import 'search.dart';
import 'admin.dart';
import 'billing.dart';
import 'breakdown.dart';
import 'verify.dart';
import 'logbook.dart';
import 'store.dart';
import 'masters.dart';
import '../ui/t.dart';

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
        ('Daily Inward & Issue', 'दैनिक आवक व वाटप', 'rdaily', 'calendar'),
        ('Monthly Diesel Issue', 'मासिक डिझेल वाटप', 'rmonthly', 'fuel_pump'),
        ('Monthly Diesel & Average', 'मासिक डिझेल व सरासरी', 'ravg', 'clipboard'),
        ('Actual vs Standard Average', 'प्रत्यक्ष व standard सरासरी', 'rp-average', 'bar_chart'),
        ('Machinery Diesel Ledger', 'यंत्राचे डिझेल खाते', 'rp-ledger', 'ledger'),
        ('Stock Register', 'स्टॉक रजिस्टर', 'rp-stock', 'oil_drum'),
        ('Diesel Purchase Register', 'डिझेल खरेदी रजिस्टर', 'rp-purchase', 'receipt'),
        ('Diesel Cost Report', 'डिझेल खर्च', 'rp-cost', 'receipt'),
        ('Machinery Cost Sheet', 'यंत्र खर्च', 'rp-mcost', 'tractor'),
        ('Owner / Vendor-wise Summary', 'मालक / vendor नुसार', 'rp-owner', 'office_building'),
        ('Type-wise Summary', 'प्रकारानुसार', 'rp-type', 'articulated_lorry'),
        ('Month vs Month', 'महिना विरुद्ध महिना', 'rp-compare', 'calendar'),
        ('Diesel Watch – signs of loss', 'डिझेल वॉच – गळतीची चिन्हे', 'rp-watch', 'shield'),
        ('Tank Check – System vs Physical', 'टँक तपासणी', 'rp-tank', 'oil_drum'),
        ('Debit Recovery Statement', 'डेबिट वसुली', 'rp-debit', 'receipt'),
      ],
      if (s.canSee('Bill Summary')) ('Bill Summary', 'बिल सारांश', 'breg', 'receipt'),
      if (s.canSee('Vendor Ledger')) ('Vendor Ledger', 'vendor खाते', 'vled', 'ledger'),
      if (s.canSee('Vendor Outstanding')) ('Vendor Outstanding', 'vendor बाकी', 'vout', 'ledger'),
    ];

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onOpenEntries, required this.onOpenReports});
  final ValueChanged<String> onOpenEntries;
  final VoidCallback onOpenReports;
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _Act {
  _Act(this.kind, this.r);
  final Kind kind;
  final Map<String, dynamic> r;
}

class _HomeTabState extends State<HomeTab> {
  bool loading = true;
  DateTime? at;
  int? logEntries, running;
  List<_Act> acts = [];
  AppUpdate? update;

  Session? _ls;
  // (3.1.7) live: something changed on the server (another person, the web) – the figures load again by themselves
  void _live() {
    if (mounted) _load(quiet: true);
  }

  @override
  void dispose() {
    _ls?.dataTick.removeListener(_live);
    super.dispose();
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
      await Future.wait(jobs);
      got.sort((a, b) => '${b.r['id']}'.compareTo('${a.r['id']}'));
      if (!mounted) return;
      setState(() {
        acts = got;
        logEntries = le;
        running = run;
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
      return;
    }
    await openWeb(context, m.en, m.page, pic: m.pic);
  }

  Future<void> _site() async {
    final s = SessionScope.read(context);
    if (s.sites.length < 2) {
      toast(context, 'You have one site: ${s.siteName}.');
      return;
    }
    if (await ask(context, 'Change site?', bi('Open another of your sites.', 'दुसरी site उघडायची?'), yes: 'Change')) s.pickAnotherSite();
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
        _MiniTile(pic: i == 0 ? 'fuel_pump' : 'oil_drum', en: l.key, mr: placeMr(l.key), value: '${fmtNum(l.value)} L', color: i == 0 ? C.greenSoft : C.amberSoft),
      if (s.canSee('Log Book')) ...[
        _MiniTile(pic: 'tractor', en: 'Running Machines', mr: 'चालू यंत्रे', value: running == null ? '–' : '$running / ${s.machines.where((m) => m.onSite(s.today)).length}', color: C.blueSoft),
        _MiniTile(pic: 'notebook', en: 'Logbook Entries', mr: 'नोंदी (आज)', value: logEntries == null ? '–' : '$logEntries', color: C.purpleSoft),
      ],
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: RefreshIndicator(
        color: C.green,
        edgeOffset: top,
        onRefresh: () => _load(init: true),
        child: ListView(padding: EdgeInsets.zero, children: [
          // ---------- the picture, Namaskar, the site ----------
          HeroScene(
            height: 250 + top,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 12, 14, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Namaskar${first.isNotEmpty ? ', $first' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                      const Text('Mechanical Management ERP', style: TextStyle(fontSize: 15, color: Color(0xE6FFFFFF), fontWeight: FontWeight.w500)),
                      const MrLine('यांत्रिकी व्यवस्थापन प्रणाली', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: Color(0xCCFFFFFF))),
                    ]),
                  ),
                  // (3.14.0) the search of the whole app (the web's Ctrl + K)
                  _RoundBtn(key: const Key('home-search'), icon: Icons.search_rounded, tip: 'Search', onTap: () => openSearch(context, entries: widget.onOpenEntries, reports: widget.onOpenReports)),
                  const SizedBox(width: 8),
                  // (3.14.0) a machinery's QR label: Diesel Issue / Log Book entry / its diesel ledger for it
                  _RoundBtn(key: const Key('home-scan'), icon: Icons.qr_code_scanner_rounded, tip: 'Scan a machinery label', onTap: () => scanMachineLabel(context, onSaved: () => _load())),
                  const SizedBox(width: 8),
                  _RoundBtn(icon: Icons.refresh_rounded, tip: 'Refresh', onTap: () => _load(init: true)),
                ]),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _site,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: softShadow(.18)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.location_on_rounded, color: C.green, size: 26),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.siteName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          Text(s.sites.length > 1 ? bi('Tap to change', 'साइट बदला') : (s.site?.code ?? ''), style: const TextStyle(fontSize: 12, color: C.green, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                      if (s.sites.length > 1) const Icon(Icons.keyboard_arrow_down_rounded),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          // ---------- the stock card (over the picture) ----------
          Transform.translate(
            offset: const Offset(0, -34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: softShadow(.1)),
                child: Column(children: [
                  Row(children: [
                    Container(width: 70, height: 70, decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 36)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const TwoLang('Total Diesel Stock', 'डिझेल साठा (एकूण)', size: 15.5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(s.stockTotal == null ? '–' : '${fmtNum(s.stockTotal)} L', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.15)),
                        ),
                        if (at != null)
                          Row(children: [
                            const Icon(Icons.schedule_rounded, size: 14, color: C.faint),
                            const SizedBox(width: 4),
                            Text('Updated ${at!.hour % 12 == 0 ? 12 : at!.hour % 12}:${at!.minute.toString().padLeft(2, '0')} ${at!.hour < 12 ? 'AM' : 'PM'}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                          ]),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  if (tiles.length <= 4)
                    Row(children: [for (final (i, t) in tiles.indexed) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: t)]])
                  else
                    SizedBox(height: 132, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: tiles.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) => SizedBox(width: 92, child: tiles[i]))),
                ]),
              ),
            ),
          ),
          // (3.15.0) the assistant – the web's "Ask": a red dot when the daily summary waits (once a day)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: ValueListenableBuilder<bool>(
              valueListenable: s.briefDue,
              builder: (_, due, __) => Press(
                key: const Key('home-ask'),
                onTap: () => openAssistant(context, entries: widget.onOpenEntries),
                color: C.greenDeep,
                border: C.greenDeep,
                padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                child: Row(children: [
                  Badge(isLabelVisible: due, smallSize: 12, backgroundColor: C.brandRed, child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD54F), size: 26)),
                  const SizedBox(width: 12),
                  const Expanded(child: TwoLang('Ask the app', 'ॲपला विचारा', color: Colors.white, size: 16.5, weight: FontWeight.w700)),
                  if (due)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
                      child: const Text('Today\'s summary', style: TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ]),
              ),
            ),
          ),
          if (update != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
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
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.amber.withValues(alpha: .35))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.campaign_rounded, color: C.amber),
                const SizedBox(width: 10),
                Expanded(child: Text('${s.siteRules['announce']}'.trim(), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.35))),
              ]),
            ),
          // (3.1.11, update-118) his entries in verification: waiting / sent back / approved – tap: each, with "Remind"
          const VerifyStrip(days: 1, margin: EdgeInsets.fromLTRB(14, 0, 14, 16)),
          // ---------- the modules ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Modules', mr: 'विभाग'),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .78,
                children: [for (final m in mods) _ModuleCard(m: m, onTap: () => _module(m))],
              ),
              const SizedBox(height: 22),
              // ---------- today's work ----------
              if (kKinds.any((k) => s.canSee(k.module)))
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: softShadow(.05)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SectionTitle("Today's Activity", mr: 'आजची कामे · ${showDate(s.today)}', action: 'View All', onAction: () => widget.onOpenEntries('')),
                    if (loading && acts.isEmpty)
                      ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: Shimmer(height: 70)))
                    else if (acts.isEmpty)
                      const EmptyState('No diesel entry today yet', 'Issue, Inward and Transfer of today show here.', pic: 'fuel_pump')
                    else
                      for (final a in acts.take(6)) _ActRow(a: a, onTap: () => widget.onOpenEntries(a.kind.key)),
                  ]),
                ),
              const SizedBox(height: 28),
              Center(child: Opacity(opacity: .55, child: Image.asset('assets/brand/rachana_logo.png', height: 30))),
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
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
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: Colors.black26,
          child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, color: C.ink, size: 24))),
        ),
      );
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({required this.pic, required this.en, required this.mr, required this.value, required this.color});
  final String pic, en, mr, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        height: 132,
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Pic(pic, size: 34),
          en.contains(' ')
              ? Text(en, mr: mr, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.15))
              : FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
          MrLine(mr, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'NotoDeva', fontSize: 10.5, color: C.muted)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
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
        radius: 20,
        color: m.soft,
        border: Colors.white,
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: double.infinity,
            height: 40,
            child: Stack(children: [
            Pic(m.pic, size: 40),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .85), shape: BoxShape.circle),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: m.color),
              ),
            ),
          ]),
          ),
          const Spacer(),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(m.en, mr: m.mr, maxLines: 1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: MrLine(m.mr, maxLines: 1, style: const TextStyle(fontFamily: 'NotoDeva', fontSize: 11.5, color: C.muted))),
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
