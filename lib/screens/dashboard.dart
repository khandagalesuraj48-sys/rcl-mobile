/* DASHBOARD – the app's own screen (3.5.0, part 4 of the whole web in the app). The web's Dashboard, its two tabs:
 *   DIESEL – the dates (Today, Yesterday, This month, Last month, All dates or From – To), the Daily report (one day on one page),
 *     opening / received / issued / closing / stock now, issued today, machines fuelled, entries, average; the tanks (live, or the
 *     closing of the last date) with their size (Tank size); issued by ownership (tap: machine-wise, with Print); Own vehicle
 *     compliance; the stock of each place and combined; in & out by day; top machines; the day-wise stock (a place or all).
 *   LOG BOOK – the dates, ownership, vendor; machinery at work, work done, diesel, Log Book pending; machine-wise work (All, Idle,
 *     Diesel high, Worked less than half the days); pending Log Book by machinery with its dates – a date opens its new entry.
 * Server: getDashboard, getStockLedger, saveTankSettings, getOwnershipDetail, getCompliance, logDashboard, pendingLog (and for the
 * Daily report getDieselIssues, getInwards, getLogBookList, getBreakdowns) – the same as the web. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/dash.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/report_view.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../web/print_view.dart';
import 'compliance.dart' show openCompliance;
import 'logbook.dart' show LogForm;

Future<void> openDashboard(BuildContext context, {int tab = 0}) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DashboardScreen(tab: tab)));

const kLbPendFrom = '2026-09-01';
Color ownColor(String o) => Color(kOwnTone[o] ?? 0xFF7A8791);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.tab = 0});
  final int tab;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // diesel
  String from = '', to = '', ledLoc = '';
  Map<String, dynamic>? d, led, cp;
  bool loading = true, daily = false;
  String err = '';
  int _seq = 0;
  // log book
  String lFrom = '', lTo = '', lOwn = '', lVendor = '', lChip = 'all', lQuick = 'month';
  Map<String, dynamic>? ld, pend;
  String pFrom = kLbPendFrom, pTo = '', pChip = 'all', pQ = '';
  bool lLoading = false;
  Session? _ls;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = SessionScope.read(context);
      _ls = s..dataTick.addListener(_live);
      from = to = s.today; // (as the web: the Dashboard opens on Today)
      final r = lbRange('month', s.today);
      lFrom = r.$1;
      lTo = r.$2;
      pTo = s.today;
      _load();
      if (s.canSee('Vehicle Compliance')) _loadCp();
      if (widget.tab == 1) _loadLog();
    });
  }

  @override
  void dispose() {
    _ls?.dataTick.removeListener(_live);
    super.dispose();
  }

  // another person saved something (the live sync): the figures again, quietly
  void _live() {
    if (!mounted) return;
    final g = _ls?.lastChanged ?? {};
    if (g.contains('stock') || g.contains('master')) _load(quiet: true);
    if (ld != null && (g.contains('log') || g.contains('master'))) _loadLog(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async {
    final s = SessionScope.read(context), seq = ++_seq;
    if (!quiet) setState(() => loading = true);
    try {
      final r = (await s.api.call('getDashboard', [{'from': from, 'to': to}]) as Map).cast<String, dynamic>();
      final l = (await s.api.call('getStockLedger', [{'from': from, 'to': to, 'location': ledLoc}]) as Map).cast<String, dynamic>();
      if (!mounted || seq != _seq) return;
      if (r['stock'] is Map) s.setStock(r['stock']);
      setState(() {
        d = r;
        led = l;
        loading = false;
        err = '';
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        loading = false;
        if (!quiet) err = errText(e);
      });
    }
  }

  Future<void> _loadLedger() async {
    final s = SessionScope.read(context);
    try {
      final l = (await s.api.call('getStockLedger', [{'from': from, 'to': to, 'location': ledLoc}]) as Map).cast<String, dynamic>();
      if (mounted) setState(() => led = l);
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  Future<void> _loadCp() async {
    try {
      final r = (await SessionScope.read(context).api.call('getCompliance') as Map).cast<String, dynamic>();
      if (mounted) setState(() => cp = r);
    } catch (_) {/* the panel only */}
  }

  Future<void> _loadLog({bool quiet = false}) async {
    final s = SessionScope.read(context);
    if (!quiet) setState(() => lLoading = true);
    try {
      final r = (await s.api.call('logDashboard', [{'from': lFrom, 'to': lTo, 'vendor': lVendor, 'ownerships': lOwn.isEmpty ? <String>[] : lOwn.split(',')}]) as Map).cast<String, dynamic>();
      final p = (await s.api.call('pendingLog', [{'from': pFrom, 'to': pTo}]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        ld = r;
        pend = p;
        lLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => lLoading = false);
      if (!quiet) toast(context, tr(errText(e)), bad: true);
    }
  }

  Future<void> _loadPend() async {
    try {
      final p = (await SessionScope.read(context).api.call('pendingLog', [{'from': pFrom, 'to': pTo}]) as Map).cast<String, dynamic>();
      if (mounted) setState(() => pend = p);
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  void _range(String k) {
    final s = SessionScope.read(context);
    final r = dashRange(k, s.today);
    setState(() {
      from = r.$1;
      to = r.$2;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final pendN = (asNum(pend?['total']) ?? asNum((d?['pending'] as Map?)?['total']) ?? 0).toInt();
    return DefaultTabController(
      length: 2,
      initialIndex: widget.tab,
      child: Scaffold(
        appBar: AppBar(
          title: const TwoLang('Dashboard', 'डॅशबोर्ड', size: 20, weight: FontWeight.w700),
          actions: [
            IconButton(
              tooltip: tr('Refresh'),
              onPressed: () {
                _load();
                if (ld != null) _loadLog();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            onTap: (i) {
              if (i == 1 && ld == null && !lLoading) _loadLog();
            },
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            tabs: [
              Tab(key: const Key('dt-diesel'), child: Text('Diesel')),
              Tab(
                key: const Key('dt-log'),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Log Book'), if (pendN > 0) ...[const SizedBox(width: 6), Badge(label: Text('$pendN'))]]),
              ),
            ],
          ),
        ),
        body: TabBarView(children: [_diesel(s), _log(s)]),
      ),
    );
  }

  /* ================= DIESEL ================= */
  Widget _diesel(Session s) {
    final dd = d;
    final which = dashWhich(from, to, s.today);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(key: const Key('dash-diesel'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        Row(children: [
          Expanded(child: Text('Diesel summary – all locations', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          Pill(rangeText(from, to), color: C.blue, bg: C.blueSoft),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final q in const [('today', 'Today'), ('yesterday', 'Yesterday'), ('month', 'This month'), ('lastmonth', 'Last month'), ('all', 'All dates')])
            ChoiceChip(key: Key('dq-${q.$1}'), selected: which == q.$1, onSelected: (_) => _range(q.$1), label: Text(q.$2)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DateField(key: const Key('d-from'), label: 'From', value: from, onChanged: (v) {
            setState(() => from = v);
            _load();
          })),
          const SizedBox(width: 8),
          Expanded(child: DateField(key: const Key('d-to'), label: 'To', value: to, onChanged: (v) {
            setState(() => to = v);
            _load();
          })),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('d-daily'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: daily ? null : () => _daily(s),
          icon: const Icon(Icons.description_outlined),
          label: Text(daily ? 'Making…' : 'Daily report'),
        ),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 12),
        if (loading && dd == null)
          ...List.generate(4, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: Shimmer(height: 110)))
        else if (dd != null) ...[
          _kpis(s, dd),
          const SizedBox(height: 14),
          _tanks(s, dd),
          const SizedBox(height: 14),
          _ownership(dd),
          if (s.canSee('Vehicle Compliance')) ...[const SizedBox(height: 14), _ownPapers()],
          const SizedBox(height: 14),
          _locations(s, dd),
          const SizedBox(height: 14),
          _chart(dd),
          const SizedBox(height: 14),
          _top(dd),
          const SizedBox(height: 14),
          _ledger(s),
        ],
      ]),
    );
  }

  Widget _panel(String title, List<Widget> kids, {Widget? trailing, Key? key, String note = ''}) => Container(
        key: key,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.line), boxShadow: softShadow(.04)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))), if (trailing != null) trailing]),
          if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.3))),
          const SizedBox(height: 10),
          ...kids,
        ]),
      );

  Widget _kpis(Session s, Map<String, dynamic> dd) {
    final locs = mapsOf(dd['locations']);
    num sumL(String k) => r2n(locs.fold<num>(0, (a, x) => a + (asNum(x[k]) ?? 0)));
    final total = (dd['total'] as Map?) ?? const {}, inward = (dd['inward'] as Map?) ?? const {}, stock = (dd['stock'] as Map?) ?? const {};
    final entries = asNum(total['entries']) ?? 0;
    Widget card(String key, String label, String value, String sub, Color fg, Color bg) => Container(
          key: Key(key),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12.5, color: fg, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 22, color: fg, fontWeight: FontWeight.w800))),
            if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: fg.withValues(alpha: .85))),
          ]),
        );
    final byLoc = (stock['byLoc'] as Map?) ?? const {};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.55,
        children: [
          card('k-open', 'Opening stock', '${fmtNum(sumL('opening'))} Ltr', from.isNotEmpty ? 'as on start of ${showDate(from)}' : 'at the very start', C.slate, C.slateSoft),
          card('k-in', 'Received (inward)', '${fmtNum(asNum(inward['qty']))} Ltr', inward.isEmpty ? '' : '₹${fmtNum(asNum(inward['amount']))}, ${inward['entries']} bills', C.greenDark, C.greenSoft),
          card('k-out', 'Issued to machinery', '${fmtNum(asNum(total['qty']))} Ltr', '${fmtNum(entries)} entries', C.orange, C.orangeSoft),
          card('k-close', 'Closing stock', '${fmtNum(sumL('closing'))} Ltr', 'as on end of ${to.isNotEmpty ? showDate(to) : 'today'}', C.blue, C.blueSoft),
        ],
      ),
      const SizedBox(height: 8),
      card('k-now', 'Stock now (live)', '${fmtNum(asNum(stock['stock']))} Ltr', byLoc.entries.map((e) => '${e.key} ${fmtNum(asNum(e.value))}').join(', '), C.purple, C.purpleSoft),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final x in [
          ('Issued today', '${fmtNum(asNum(total['todayQty']))} Ltr'),
          ('Machines fuelled', fmtNum(asNum(total['machines']))),
          ('Issue entries', fmtNum(entries)),
          ('Average per entry', entries > 0 ? '${fmtNum(r2n((asNum(total['qty']) ?? 0) / entries))} Ltr' : '–'),
        ])
          Container(
            width: (MediaQuery.of(context).size.width - 32 - 8) / 2,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x.$1, style: const TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600)),
              Text(x.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
    ]);
  }

  Widget _tanks(Session s, Map<String, dynamic> dd) {
    final endsToday = to.isEmpty || to.compareTo(s.today) >= 0;
    final locs = mapsOf(dd['locations']);
    final stock = (dd['stock'] as Map?)?.cast<String, dynamic>() ?? const {};
    final byLoc = endsToday ? ((stock['byLoc'] as Map?)?.cast<String, dynamic>() ?? const {}) : {for (final x in locs) '${x['loc']}': asNum(x['closing']) ?? 0};
    final tanks = (dd['tanks'] as Map?)?.cast<String, dynamic>() ?? const {};
    final caps = (tanks['caps'] as Map?) ?? const {};
    final places = s.locations.isNotEmpty ? s.locations : [for (final k in caps.keys) '$k'];
    return _panel(
      endsToday ? 'Diesel tank – live stock (today)' : 'Diesel tank – closing stock on ${showDate(to)} (end of day)',
      note: endsToday ? '' : 'Live now: ${fmtNum(asNum(stock['stock']))} Ltr',
      key: const Key('d-tanks'),
      trailing: s.canEdit('Master') ? TextButton(key: const Key('tank-set'), onPressed: () => _tankSize(tanks), child: Text('Tank size')) : null,
      [
        for (final (i, l) in places.indexed)
          (() {
            final t = tankOf(byLoc, tanks, l, i);
            final fg = t.low ? C.red : t.p >= .5 ? C.greenDark : C.amber;
            return Container(
              key: Key('tank-$l'),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.low ? C.redSoft : C.bg, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                // the tank: filled to its level
                Container(
                  width: 46,
                  height: 86,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line, width: 2)),
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.antiAlias,
                  child: FractionallySizedBox(
                    heightFactor: t.p,
                    widthFactor: 1,
                    child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: t.low ? const [Color(0xFFFCA5A5), Color(0xFFDC2626)] : const [Color(0xFFFCD34D), Color(0xFFD97706)]))),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(l, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))), Pill(t.chip, color: fg, bg: Colors.white)]),
                    Text('${fmtNum(t.qty)} Ltr', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
                    Text('${(t.p * 100).round()}% of ${fmtNum(t.cap)} Ltr', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    Text(t.note, style: TextStyle(fontSize: 12, color: t.low ? C.red : C.faint)),
                  ]),
                ),
              ]),
            );
          })(),
      ],
    );
  }

  Future<void> _tankSize(Map<String, dynamic> t) async {
    final s = SessionScope.read(context);
    final caps = ((t['caps'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', TextEditingController(text: '${v ?? ''}')));
    final low = TextEditingController(text: '${t['low'] ?? 1000}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Tank size'),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('How much each tank holds, and the level below which it turns red.', style: const TextStyle(color: C.muted)),
          for (final e in caps.entries) Padding(padding: const EdgeInsets.only(top: 10), child: TextBox(key: Key('tcap-${e.key}'), label: '${e.key} tank size (Ltr)', controller: e.value, kb: TextInputType.number)),
          Padding(padding: const EdgeInsets.only(top: 10), child: TextBox(key: const Key('tcap-low'), label: 'Low stock below (Ltr)', controller: low, kb: TextInputType.number)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(key: const Key('tcap-save'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c, true), child: Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await s.api.call('saveTankSettings', [{'caps': {for (final e in caps.entries) e.key: num.tryParse(e.value.text.trim()) ?? 0}, 'low': num.tryParse(low.text.trim()) ?? 0}], true);
      if (!mounted) return;
      toast(context, 'Tank size saved.');
      _load(quiet: true);
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  Widget _ownership(Map<String, dynamic> dd) {
    final groups = mapsOf(dd['byOwnership']);
    final total = asNum((dd['total'] as Map?)?['qty']) ?? 0;
    final filled = [...groups.where((g) => (asNum(g['qty']) ?? 0) > 0)]..sort((a, b) => (asNum(b['qty']) ?? 0).compareTo(asNum(a['qty']) ?? 0));
    return _panel('Issued by ownership', key: const Key('d-own'), [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 30,
          child: filled.isEmpty
              ? Container(color: C.slateSoft, alignment: Alignment.center, child: Text('No diesel issued in this period', style: const TextStyle(fontSize: 12.5, color: C.muted)))
              : Row(children: [
                  for (final g in filled)
                    Expanded(
                      flex: (((asNum(g['qty']) ?? 0) / total) * 1000).round().clamp(1, 1000).toInt(),
                      child: Container(color: ownColor('${g['ownership']}'), alignment: Alignment.center, child: ((asNum(g['qty']) ?? 0) / total) >= .09 ? Text('${g['ownership']} ${((asNum(g['qty']) ?? 0) / total * 100).round()}%', maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)) : null),
                    ),
                ]),
        ),
      ),
      const SizedBox(height: 10),
      for (final g in groups)
        InkWell(
          key: Key('own-${g['ownership']}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _ownDetail('${g['ownership']}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: ownColor('${g['ownership']}'), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${g['ownership']}  ${total > 0 ? ((asNum(g['qty']) ?? 0) / total * 100).round() : 0}%', style: TextStyle(fontWeight: FontWeight.w700, color: (asNum(g['qty']) ?? 0) > 0 ? C.ink : C.faint)),
                  Text('${g['machines']} machines, ${g['entries']} entries', style: const TextStyle(fontSize: 12, color: C.muted)),
                ]),
              ),
              Text('${fmtNum(asNum(g['qty']))} Ltr', style: const TextStyle(fontWeight: FontWeight.w800)),
              const Icon(Icons.chevron_right_rounded, color: C.faint),
            ]),
          ),
        ),
    ]);
  }

  Future<void> _ownDetail(String own) async {
    final s = SessionScope.read(context);
    try {
      final r = (await s.api.call('getOwnershipDetail', [own, {'from': from, 'to': to}]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final rows = mapsOf(r['rows']), tot = (r['total'] as Map?) ?? const {};
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SizedBox(
          height: MediaQuery.of(c).size.height * .85,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$own – Diesel issued', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    Text('${rangeText('${r['from'] ?? ''}', '${r['to'] ?? ''}')}, ${rows.length} machines, ${tot['entries'] ?? 0} entries', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                  ]),
                ),
                IconButton(key: const Key('own-print'), tooltip: tr('Print'), onPressed: rows.isEmpty ? null : () => printDoc(c, s, ownershipDoc(r)), icon: const Icon(Icons.print_rounded)),
              ]),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(child: Text('No diesel issued to $own machinery in this period.', style: const TextStyle(color: C.muted)))
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), children: [
                      for (final (i, x) in rows.indexed)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(16)),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${i + 1}. ${x['no']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text([x['type'], x['owner']].where((y) => '${y ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                                Text('${x['entries']} entries · ${showDate('${x['first']}')} – ${showDate('${x['last']}')}', style: const TextStyle(fontSize: 12, color: C.faint)),
                              ]),
                            ),
                            Text('${fmtNum(asNum(x['qty']))} L', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ]),
                        ),
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text('Total: ${fmtNum(asNum(tot['qty']))} Ltr', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
                    ]),
            ),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  Widget _ownPapers() {
    final c = cp;
    final l = c == null ? const <Map<String, dynamic>>[] : ownPapersDue(c);
    final ex = l.where((x) => x['s'] == 'expired').length;
    return _panel('Own vehicle compliance', key: const Key('d-cp'), trailing: TextButton(onPressed: () => openCompliance(context), child: Text('Open Vehicle Compliance')), [
      if (c == null)
        Text('Loading…', style: const TextStyle(color: C.muted))
      else ...[
        Row(children: [
          Expanded(child: _mini('Expired', '$ex', C.red, C.redSoft)),
          const SizedBox(width: 8),
          Expanded(child: _mini('Expiring in 30 days', '${l.length - ex}', C.amber, C.amberSoft)),
        ]),
        const SizedBox(height: 8),
        if (l.isEmpty) Text('No Own vehicle paper is expired or expiring in the next 30 days.', style: const TextStyle(color: C.greenDark, fontWeight: FontWeight.w600)),
        for (final x in l.take(9))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text('${x['no']} · ${x['doc']}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(
                '${x['s'] == 'expired' ? 'Expired on' : 'Expires on'} ${showDate('${x['v']}')} (${x['s'] == 'expired' ? '${-(x['days'] as num)} day${x['days'] == -1 ? '' : 's'} ago' : x['days'] == 0 ? 'today' : 'in ${x['days']} day${x['days'] == 1 ? '' : 's'}'})',
                style: TextStyle(fontSize: 12.5, color: x['s'] == 'expired' ? C.red : C.amber),
              ),
            ]),
          ),
        if (l.length > 9) TextButton(onPressed: () => openCompliance(context), child: Text('+ ${l.length - 9} more – open Vehicle Compliance')),
      ],
    ]);
  }

  Widget _mini(String label, String n, Color fg, Color bg) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg)), Text(label, style: TextStyle(fontSize: 12, color: fg))]),
      );

  Widget _locations(Session s, Map<String, dynamic> dd) {
    final cards = locationCards(mapsOf(dd['locations']), from, to, s.locations);
    return _panel('Diesel stock – combined and by location', key: const Key('d-locs'), note: 'Period: ${rangeText(from, to)}. "Stock now" is the live stock after every entry saved till now.', [
      for (final c in cards)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.title.startsWith('Combined') ? C.greenSoft : C.bg, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              Text('Stock now ', style: const TextStyle(fontSize: 12, color: C.muted)),
              Text('${fmtNum(c.now)} Ltr', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            for (final l in c.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(l.$1, style: TextStyle(fontSize: l.$3 == 'note' ? 11.5 : 13, color: l.$3 == 'note' ? C.muted : C.ink, fontWeight: l.$3 == 'tot' ? FontWeight.w800 : FontWeight.w400))),
                  Text('${fmtNum(l.$2)}${l.$3 == 'tot' ? ' Ltr' : ''}', style: TextStyle(fontSize: 13, fontWeight: l.$3 == 'tot' ? FontWeight.w800 : FontWeight.w600, color: l.$3 == 'plus' ? C.greenDark : l.$3 == 'minus' ? C.red : l.$3 == 'note' ? C.muted : C.ink)),
                ]),
              ),
            const SizedBox(height: 4),
            Text('${c.ok ? '✓ ' : ''}${c.check}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.ok ? C.greenDark : C.red)),
          ]),
        ),
    ]);
  }

  Widget _chart(Map<String, dynamic> dd) {
    final days = mapsOf(dd['daily']), today = '${dd['today'] ?? ''}';
    final mx = days.fold<num>(0, (m, x) => [m, asNum(x['qty']) ?? 0, asNum(x['inQty']) ?? 0].reduce((a, b) => a > b ? a : b));
    double h(dynamic v) => mx > 0 && (asNum(v) ?? 0) > 0 ? ((asNum(v)! / mx) * 120).clamp(3, 120).toDouble() : 0;
    return _panel('Diesel in & out by day', key: const Key('d-chart'), note: days.isEmpty ? '' : '${showDate('${days.first['date']}')} to ${showDate('${days.last['date']}')}${mx > 0 ? ', highest ${fmtNum(mx)} Ltr in a day' : ''}', [
      Row(children: [
        _legend('Inward', C.greenDark),
        const SizedBox(width: 12),
        _legend('Issued', C.orange),
        const SizedBox(width: 12),
        _legend('Today', C.blue),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 132,
        child: ListView(scrollDirection: Axis.horizontal, reverse: true, children: [
          for (final x in days.reversed)
            Tooltip(
              message: '${showDate('${x['date']}')}\nInward: ${fmtNum(asNum(x['inQty']) ?? 0)} Ltr\nIssued: ${fmtNum(asNum(x['qty']))} Ltr\nClosing stock: ${fmtNum(asNum(x['closing']))} Ltr',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(width: 7, height: h(x['inQty']), decoration: BoxDecoration(color: C.greenDark, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 1),
                  Container(width: 7, height: h(x['qty']), decoration: BoxDecoration(color: x['date'] == today ? C.blue : C.orange, borderRadius: BorderRadius.circular(3))),
                ]),
              ),
            ),
        ]),
      ),
      if (days.isNotEmpty)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(showDate('${days.first['date']}'), style: const TextStyle(fontSize: 11, color: C.muted)),
          Text(showDate('${days.last['date']}'), style: const TextStyle(fontSize: 11, color: C.muted)),
        ]),
    ]);
  }

  Widget _legend(String t, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 4), Text(t, style: const TextStyle(fontSize: 12, color: C.muted))]);

  Widget _top(Map<String, dynamic> dd) {
    final top = mapsOf(dd['top']);
    final mx = top.isEmpty ? 0 : asNum(top.first['qty']) ?? 0;
    return _panel('Top machines', key: const Key('d-top'), note: 'by diesel in this period', [
      if (top.isEmpty) Text('No diesel issued in this period.', style: const TextStyle(color: C.muted)),
      for (final m in top)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Expanded(child: Text('${m['no']}', style: const TextStyle(fontWeight: FontWeight.w700))), Text('${fmtNum(asNum(m['qty']))} Ltr', style: const TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: mx > 0 ? ((asNum(m['qty']) ?? 0) / mx).toDouble() : 0.0, minHeight: 8, backgroundColor: C.slateSoft, color: ownColor('${m['ownership']}')),
            ),
          ]),
        ),
    ]);
  }

  Widget _ledger(Session s) {
    final l = led;
    return _panel('Day-wise diesel stock', key: const Key('d-ledger'), note: l == null ? '' : '${showDate('${l['from']}')} to ${showDate('${l['to']}')}', [
      PickField(key: const Key('lg-loc'), label: 'Location', value: ledLoc, items: s.locations, blank: 'All locations', onChanged: (v) {
        setState(() => ledLoc = v);
        _loadLedger();
      }),
      const SizedBox(height: 6),
      Text(ledgerHelp(ledLoc, s.locations), style: const TextStyle(fontSize: 12, color: C.muted, height: 1.3)),
      const SizedBox(height: 8),
      if (l != null) RTableView(ledgerTable(l, ledLoc, s.locations)),
    ]);
  }

  /* ---------------- the Daily report ---------------- */
  Future<void> _daily(Session s) async {
    setState(() => daily = true);
    try {
      final day = from.isNotEmpty && to.isNotEmpty && from == to ? to : s.today;
      final res = await Future.wait([
        s.api.call('getDashboard', [{'from': day, 'to': day}]),
        s.api.call('getDieselIssues', [{'from': day, 'to': day, 'all': true}]),
        s.api.call('getInwards', [{'from': day, 'to': day}]),
        s.api.call('getLogBookList', [{'from': day, 'to': day, 'all': true}]),
        s.api.call('getBreakdowns', [{'date': day}]).catchError((_) => <String, dynamic>{}),
      ]);
      Map<String, dynamic> m(dynamic x) => x is Map ? x.cast<String, dynamic>() : <String, dynamic>{};
      final html = dailyReportHtml(
        day: day,
        company: s.company.isNotEmpty ? s.company : 'Rachana Construction Limited',
        site: s.siteLabel,
        madeAt: whenText(DateTime.now().toIso8601String()),
        madeBy: s.name,
        dash: m(res[0]),
        issues: mapsOf(m(res[1])['rows']),
        inwards: mapsOf(m(res[2])['rows']),
        logs: mapsOf(m(res[3])['rows']),
        breakdowns: m(res[4]),
        activeMachines: [for (final x in s.machines) if (x.onSite(day) && needsLogBook(x.m)) x.m],
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrintView(html: html, title: 'Daily Report ${showDate(day)}')));
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => daily = false);
    }
  }

  /* ================= LOG BOOK ================= */
  Widget _log(Session s) {
    final dd = ld;
    return RefreshIndicator(
      onRefresh: _loadLog,
      child: ListView(key: const Key('dash-log'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        Row(children: [
          Expanded(child: Text('Log Book – work of the machinery', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          if (dd != null) Pill('${showDate('${dd['from']}')} – ${showDate('${dd['to']}')}', color: C.blue, bg: C.blueSoft),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final q in const [('month', 'This month'), ('lastmonth', 'Last month'), ('7', 'Last 7 days')])
            ChoiceChip(
              key: Key('lq-${q.$1}'),
              selected: lQuick == q.$1,
              onSelected: (_) {
                final r = lbRange(q.$1, s.today);
                setState(() {
                  lQuick = q.$1;
                  lFrom = r.$1;
                  lTo = r.$2;
                });
                _loadLog();
              },
              label: Text(q.$2),
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DateField(label: 'From', value: lFrom, clear: false, onChanged: (v) {
            setState(() {
              lFrom = v;
              lQuick = '';
            });
            _loadLog();
          })),
          const SizedBox(width: 8),
          Expanded(child: DateField(label: 'To', value: lTo, clear: false, onChanged: (v) {
            setState(() {
              lTo = v;
              lQuick = '';
            });
            _loadLog();
          })),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: PickField(label: 'Ownership', value: lOwn, items: const ['Own', 'Rental,Hired'], blank: 'All machinery', onChanged: (v) {
              setState(() => lOwn = v);
              _loadLog();
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PickField(label: 'Vendor', value: lVendor, items: [for (final v in (dd?['vendors'] as List? ?? const [])) '$v'], blank: 'All vendors', onChanged: (v) {
              setState(() => lVendor = v);
              _loadLog();
            }),
          ),
        ]),
        const SizedBox(height: 12),
        if (lLoading && dd == null)
          ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: Shimmer(height: 110)))
        else if (dd != null) ...[
          _lbCards(dd),
          const SizedBox(height: 14),
          _lbMachines(dd),
          const SizedBox(height: 14),
          _lbPending(s),
        ],
      ]),
    );
  }

  Widget _lbCards(Map<String, dynamic> dd) {
    final k = (dd['kpi'] as Map?)?.cast<String, dynamic>() ?? const {}, p = (dd['prev'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ms = mapsOf(dd['machines']).where((m) => (asNum(m['avail']) ?? 0) > 0).toList();
    final avgDays = ms.isEmpty ? 0 : ms.fold<num>(0, (a, m) => a + (asNum(m['util']) ?? 0)) / ms.length;
    final pendN = (asNum(pend?['total']) ?? asNum(k['pendingDays']) ?? 0).toInt();
    final work = [if ((asNum(k['hrs']) ?? 0) > 0) '${lbN(k['hrs'])} hrs', if ((asNum(k['km']) ?? 0) > 0) '${lbN(k['km'])} km', if ((asNum(k['trips']) ?? 0) > 0) '${lbN(k['trips'])} trips'].join(' · ');
    Widget card(String key, String label, String big, String small, (String, bool) cmp, {bool warn = false}) => Container(
          key: Key(key),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: warn ? C.amberSoft : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: warn ? C.amber.withValues(alpha: .3) : C.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: warn ? C.amber : C.muted)),
            const SizedBox(height: 2),
            Text(big, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(small, style: const TextStyle(fontSize: 12, color: C.muted, height: 1.3)),
            if (cmp.$1.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(cmp.$1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cmp.$2 ? C.greenDark : C.red))),
          ]),
        );
    final extra = asNum(k['extra']) ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      card('lc-1', 'Machinery at work', '${k['worked'] ?? 0} of ${k['machines'] ?? 0}', 'on average each machinery worked ${lbN(avgDays)}% of its days', lbCmp(k['util'], p['util'], true)),
      const SizedBox(height: 8),
      card('lc-2', 'Work done', work.isEmpty ? 'no work' : work, 'from all Log Book entries of these dates', lbCmp((asNum(k['hrs']) ?? 0) + (asNum(k['km']) ?? 0), (asNum(p['hrs']) ?? 0) + (asNum(p['km']) ?? 0), true)),
      const SizedBox(height: 8),
      card('lc-3', 'Diesel', '${lbN(k['issued'])} L used',
          (asNum(k['std']) ?? 0) > 0 ? (extra > 0 ? '${lbN(extra)} L more than the standard average allows${(asNum(k['extraAmt']) ?? 0) > 0 ? ' (≈ ₹${lbN(k['extraAmt'])})' : ''}' : 'within the standard average') : 'no standard average set', ('', true),
          warn: extra > 0),
      const SizedBox(height: 8),
      card('lc-4', 'Log Book pending', '$pendN day${pendN == 1 ? '' : 's'}', pendN > 0 ? 'active machinery, Log Book not filled (since 01-09-2026)' : 'every active machinery has its Log Book', ('', true), warn: pendN > 0),
    ]);
  }

  Widget _lbMachines(Map<String, dynamic> dd) {
    final all = mapsOf(dd['machines']).where((m) => (asNum(m['avail']) ?? 0) > 0).toList();
    final list = lbMachines(dd, lChip);
    return _panel('Machine-wise work', key: const Key('lb-mw'), note: 'How many days each machinery worked, how much it did, and whether its diesel is right.', [
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final c in kLbChips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(key: Key('lbc-${c.$1}'), selected: lChip == c.$1, onSelected: (_) => setState(() => lChip = c.$1), label: Text('${tr(c.$2)} ${all.where((m) => lbChipHas(m, c.$1)).length}')),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      if (list.isEmpty) Text('Nothing here for these filters.', style: const TextStyle(color: C.muted)),
      for (final m in list.take(200))
        (() {
          final st = lbStatus(m), util = (asNum(m['util']) ?? 0).toDouble(), high = lbDieselHigh(m);
          return Container(
            key: Key('lbm-${m['no']}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('${m['no']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                Pill(st.$2, color: st.$3 == 'bad' ? C.red : st.$3 == 'warn' ? C.amber : C.greenDark, bg: Colors.white),
              ]),
              Text([m['type'], m['ownership'], m['owner']].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12, color: C.muted)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: (util / 100).clamp(0.0, 1.0).toDouble(), minHeight: 8, backgroundColor: Colors.white, color: util >= 75 ? C.greenDark : util >= 50 ? C.amber : C.red),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${m['workDays']} of ${m['avail']} days', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
              if ((asNum(m['nights']) ?? 0) > 0) Text('${m['nights']} night shift${m['nights'] == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11.5, color: C.muted)),
              const SizedBox(height: 6),
              Text('Work done: ${lbWork(m, ' · ').isEmpty ? '–' : lbWork(m, ' · ')} · per working day ${lbPerDay(m)}', style: const TextStyle(fontSize: 12.5)),
              Text(
                (asNum(m['issued']) ?? 0) == 0
                    ? 'no diesel'
                    : (asNum(m['std']) ?? 0) == 0
                        ? '${lbN(m['issued'])} L · no standard set'
                        : '${lbN(m['issued'])} L · ${high ? 'High +${lbN(m['extraPct'])}%' : 'OK'} · average ${lbN(m['actualAvg'], 2)} ${m['avgUnit']} · standard ${lbN(m['stdAvg'], 2)}',
                style: TextStyle(fontSize: 12.5, color: high ? C.red : C.ink, fontWeight: high ? FontWeight.w700 : FontWeight.w400),
              ),
              if ('${m['lastLog'] ?? ''}'.isNotEmpty) Text('last work ${showDate('${m['lastLog']}')}', style: const TextStyle(fontSize: 11.5, color: C.faint)),
            ]),
          );
        })(),
    ]);
  }

  Widget _lbPending(Session s) {
    final p = pend;
    final can = s.canEdit('Log Book');
    final res = p == null ? null : pendingCards(p, own: lOwn, vendor: lVendor, q: pQ, chip: pChip, ownOf: (no) => s.machine(no)?.ownership ?? '');
    return _panel('Pending Log Book', key: const Key('lb-pend'), note: 'Active machinery with no Log Book for the day. Tap a date to fill it. Debit-basis parties and Ownership "Other" are not counted – they need no Log Book.', [
      Row(children: [
        Expanded(child: DateField(label: 'From', value: pFrom, clear: false, onChanged: (v) {
          setState(() => pFrom = v);
          _loadPend();
        })),
        const SizedBox(width: 8),
        Expanded(child: DateField(label: 'To', value: pTo, clear: false, onChanged: (v) {
          setState(() => pTo = v);
          _loadPend();
        })),
      ]),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () {
            setState(() {
              pFrom = kLbPendFrom;
              pTo = s.today;
            });
            _loadPend();
          },
          child: Text('From ${showDate(kLbPendFrom)}'),
        ),
      ),
      TextField(key: const Key('lb-psearch'), onChanged: (v) => setState(() => pQ = v), decoration: InputDecoration(hintText: tr('Search machinery / owner…'), prefixIcon: const Icon(Icons.search_rounded), contentPadding: const EdgeInsets.symmetric(vertical: 12))),
      const SizedBox(height: 8),
      if (res == null)
        Text('Loading…', style: const TextStyle(color: C.muted))
      else ...[
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final c in kPendChips)
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(key: Key('lbp-${c.$1}'), selected: pChip == c.$1, onSelected: (_) => setState(() => pChip = c.$1), label: Text('${tr(c.$2)} ${res.counts[c.$1] ?? 0}'))),
          ]),
        ),
        const SizedBox(height: 8),
        if (res.cards.isEmpty) Text('✔ Nothing pending${pChip != 'all' || pQ.isNotEmpty || lOwn.isNotEmpty || lVendor.isNotEmpty ? ' for these filters' : ''}.', style: const TextStyle(color: C.greenDark, fontWeight: FontWeight.w600)),
        for (final c in res.cards.take(150))
          Container(
            key: Key('pc-${c.no}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.oldest > 7 ? C.redSoft : c.oldest > 1 ? C.amberSoft : C.bg, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.no, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text([c.type, c.owner].where((x) => x.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
                Column(children: [Text('${c.dates.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)), Text('day${c.dates.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: C.muted))]),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final dt in c.dates.take(12))
                  ActionChip(
                    key: Key('pf-${c.no}-$dt'),
                    visualDensity: VisualDensity.compact,
                    label: Text(showDate(dt).substring(0, 5)),
                    onPressed: can ? () => _fill(c.no, dt) : null,
                  ),
                if (c.dates.length > 12) Padding(padding: const EdgeInsets.only(top: 8), child: Text('+${c.dates.length - 12} more', style: const TextStyle(fontSize: 12, color: C.muted))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: Text(c.oldest > 0 ? 'oldest ${c.oldest} day${c.oldest == 1 ? '' : 's'} ago' : 'today', style: const TextStyle(fontSize: 12.5, color: C.muted))),
                if (can) TextButton(key: Key('pfo-${c.no}'), onPressed: () => _fill(c.no, c.dates.first), child: Text('Fill oldest')),
              ]),
            ]),
          ),
      ],
    ]);
  }

  Future<void> _fill(String no, String date) async {
    HapticFeedback.selectionClick();
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LogForm(date: date, no: no)));
    if (saved == true && mounted) _loadLog(quiet: true);
  }
}
