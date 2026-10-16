/* SEARCH (3.14.0) – the web's Ctrl + K in the app's own screen (Home → 🔍): one box for the whole app – pages, quick actions,
 * machinery, owners (at once, from what the app has) and the entries of the server (globalSearch: diesel issues, Log Book,
 * inward, transfers, tank checks, breakdowns, vendors, bills, debit notes, payments, BOQs, vehicle papers), and the Store's
 * items (the Store's own search). The same matcher as the web (core/gsearch.dart): every word must be found; a spelling mistake
 * is allowed only when nothing is found, and "Did you mean …" says the word it was taken for. A result opens the app's own
 * screen with the web's filter (the machinery, the ID, the date …); its buttons ("Log Book", "Ledger", "Edit" …) as on the web. */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/gsearch.dart';
import '../core/kinds.dart';
import '../core/rdoc.dart' show fmt;
import '../core/report_defs.dart' show kDieselReports;
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'admin.dart' show ReadMeScreen;
import 'bill_drive.dart' show DriveScreen;
import 'bill_money.dart' show PaymentsScreen;
import 'billing.dart' show openBillPage;
import 'boq.dart' show openBoq;
import 'breakdown.dart' show BreakdownScreen;
import 'compliance.dart' show ComplianceScreen;
import 'dashboard.dart' show openDashboard;
import 'entry_more.dart' show EntryFindScreen;
import 'forms.dart' show newEntry, changeEntry;
import 'home.dart' show reportsOf;
import 'log_more.dart' show LogFindScreen;
import 'logbook.dart' show LogForm;
import 'machine_form.dart' show MachineFormScreen;
import 'machinery.dart' show AssetMasterScreen;
import 'report_screen.dart' show openReport, reportOfPage;
import 'settings.dart' show SettingsScreen;
import 'start_page.dart' show startPagesFor, openStartPage;
import 'store.dart' show StoreScreen;
import 'tank_check.dart' show TankCheckScreen;
import 'vendors.dart' show VendorMasterScreen;

/// One result: what it is, its two lines, where it takes him, and its buttons.
class GsItem {
  GsItem(this.kind, this.title, this.sub, this.run, [this.chips = const []]);
  final String kind, title, sub;
  final Future<void> Function() run;
  List<(String, Future<void> Function())> chips;
}

const _icons = <String, IconData>{
  'page': Icons.dashboard_outlined, 'action': Icons.add_circle_outline_rounded, 'mach': Icons.precision_manufacturing_outlined, 'owner': Icons.person_outline_rounded,
  'issue': Icons.local_gas_station_outlined, 'inward': Icons.download_rounded, 'transfer': Icons.swap_horiz_rounded, 'log': Icons.menu_book_outlined,
  'vendor': Icons.business_outlined, 'bill': Icons.receipt_long_outlined, 'note': Icons.note_alt_outlined, 'pay': Icons.currency_rupee_rounded,
  'boq': Icons.description_outlined, 'tank': Icons.oil_barrel_outlined, 'brk': Icons.build_outlined, 'paper': Icons.article_outlined, 'item': Icons.inventory_2_outlined,
};

/// Opens the search. [entries]: the Entries tab of a diesel page; [reports]: the Reports tab.
Future<void> openSearch(BuildContext context, {required void Function(String kind) entries, required VoidCallback reports}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SearchScreen(entries: entries, reports: reports)));

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.entries, required this.reports});
  final void Function(String kind) entries;
  final VoidCallback reports;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final box = TextEditingController();
  String q = '';
  Map? server;
  List<Map>? storeItems;
  bool storeWait = false;
  int _seq = 0;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    box.dispose();
    super.dispose();
  }

  Session get s => SessionScope.read(context);

  Future<void> _push(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

  void _input(String v) {
    setState(() {
      q = v;
      server = null;
    });
    _t?.cancel();
    if (v.trim().length < 2) {
      _seq++;
      return;
    }
    final my = ++_seq;
    _t = Timer(const Duration(milliseconds: 250), () async {
      _store(my);
      try {
        final r = await s.api.call('globalSearch', [v]);
        if (my == _seq && mounted) setState(() => server = r is Map ? r : {});
      } catch (_) {
        if (my == _seq && mounted) setState(() => server = {});
      }
    });
  }

  /// The Store's items, once (its own sign-in); searched here as the Store searches them.
  Future<void> _store(int my) async {
    final site = s.site, st = site?.module('store');
    if (storeItems != null || storeWait || site == null || st == null) return;
    setState(() => storeWait = true);
    try {
      await s.api.storeOpen(site.code, st.url);
      final r = await s.api.store(site.code, st.url, {'action': 'list'});
      storeItems = [for (final i in (r['items'] as List? ?? const [])) if (i is Map) i];
    } catch (_) {
      storeItems = [];
    }
    if (mounted) setState(() => storeWait = false);
  }

  // ---------------- what the app has: pages, quick actions, machinery, owners ----------------
  List<GsItem> _pages() {
    final s = this.s;
    final out = <GsItem>[
      if (s.canSee('Dashboard')) GsItem('page', 'Dashboard', 'Dashboard', () => openDashboard(context)),
      for (final k in kKinds.where((k) => s.canSee(k.module)))
        GsItem('page', k.module, 'Diesel', () async {
          Navigator.of(context).pop();
          widget.entries(k.key);
        }),
      for (final p in startPagesFor(s).where((p) => !const {'diesel', 'inward', 'transfer', 'rdaily', 'rmonthly', 'ravg'}.contains(p.$1)))
        GsItem('page', p.$2, _groupOf(p.$1), () => openStartPage(context, s, p.$1, entries: (k) {
              Navigator.of(context).pop();
              widget.entries(k);
            })),
      for (final r in reportsOf(s).where((r) => r.$3 != 'dash'))
        GsItem('page', r.$1, 'Reports', () async {
          const bill = {'breg': 'Bill Summary', 'vled': 'Vendor Ledger', 'vout': 'Vendor Outstanding'};
          final d = reportOfPage(r.$3);
          if (bill[r.$3] != null) {
            openBillPage(context, bill[r.$3]!);
          } else if (d != null) {
            await openReport(context, d);
          }
        }),
      if (s.admin) GsItem('page', 'Read Me', 'Administration', () => _push(const ReadMeScreen())),
      GsItem('page', 'My settings', 'Me', () => _push(const SettingsScreen())),
      if (s.site?.module('store') != null) ...[
        GsItem('page', 'Dashboard', 'Store', () => _push(const StoreScreen())),
        GsItem('page', 'Item Master', 'Store', () => _push(const StoreScreen(items: true))),
      ],
    ];
    return out;
  }

  static String _groupOf(String page) => switch (page) {
        'log' || 'logedit' || 'tankcheck' => 'Log Book',
        'brk' => 'Maintenance',
        'master' || 'vendors' || 'boq' || 'comp' || 'lbf' => 'Machinery',
        'bill' || 'bills' || 'breg' || 'pay' || 'vled' || 'vout' => 'Billing',
        'users' || 'activity' => 'Administration',
        _ => '',
      };

  List<GsItem> _actions() {
    final s = this.s;
    Kind k(String key) => kKinds.firstWhere((x) => x.key == key);
    return [
      if (s.canEdit('Diesel Issue')) GsItem('action', 'New diesel issue', 'Diesel Issue', () async => newEntry(context, k('issue'))),
      if (s.canEdit('Diesel Inward')) GsItem('action', 'New diesel inward', 'Diesel Inward', () async => newEntry(context, k('inward'))),
      if (s.canEdit('Diesel Transfer')) GsItem('action', 'New diesel transfer', 'Diesel Transfer', () async => newEntry(context, k('transfer'))),
      if (s.canEdit('Log Book')) GsItem('action', 'Log Book entry', 'Log Book', () => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LogForm(date: s.today)))),
      if (s.canEdit('Master')) GsItem('action', 'Add machinery', 'Master', () => _push(const MachineFormScreen())),
    ];
  }

  List<(String, Future<void> Function())> _machChips(String id) {
    final s = this.s, ledger = kDieselReports.where((d) => d.key == 'ledger').firstOrNull;
    return [
      if (s.canSee('Diesel Issue')) ('Diesel issued', () => _push(EntryFindScreen(kind: kKinds.first, no: id))),
      if (s.canSee('Log Book')) ('Log Book', () => _push(LogFindScreen(no: id, found: true))),
      if (s.canSee('Reports') && ledger != null) ('Ledger', () => openReport(context, ledger, no: id, run: true)),
      if (s.canSee('Master')) ('Master', () => _push(AssetMasterScreen(find: id))),
    ];
  }

  /// The web's gsLocal: exact first; only when nothing is found, allowing a spelling mistake.
  List<(String, List<GsItem>)> _local(String q, List<(String, String)> fixes) {
    final a = <(String, String)>[], x = _localPass(q, a, false);
    if (gsWords(q).isEmpty || x.any((g) => g.$2.isNotEmpty)) {
      fixes.addAll(a);
      return x;
    }
    return _localPass(q, fixes, true);
  }

  List<(String, List<GsItem>)> _localPass(String q, List<(String, String)> fixes, bool fz) {
    final s = this.s, words = gsWords(q), pages = _pages(), actions = _actions();
    if (words.isEmpty) return [('Pages', pages.take(8).toList()), ('Quick actions', actions)];
    final out = <(String, List<GsItem>)>[
      ('Pages', gsRank(words, pages, (p) => [('Page', p.title), ('Group', p.sub)], fixes, fuzzy: fz).take(6).toList()),
      ('Quick actions', gsRank(words, actions, (a) => [('Action', a.title), ('Page', a.sub)], fixes, fuzzy: fz)),
    ];
    final ms = [for (final m in s.machines) m.m];
    final machines = _machChips('').isEmpty
        ? <Map<String, dynamic>>[]
        : gsRank(words, ms, (m) => [('Machinery', m['id']), ('No', m['no']), ('Name', m['name']), ('Type', m['type']), ('Make', m['make']), ('Owner', m['owner']), ('Ownership', m['ownership']), ('Supply', m['supply']), ('Status', m['status']), ('Unit', m['unit']), ('Engine', m['engineNo']), ('Chassis', m['chassisNo'])], fixes, fuzzy: fz)
            .take(8)
            .toList();
    out.add((
      'Machinery',
      [
        for (final m in machines)
          () {
            final id = '${m['id']}', chips = _machChips(id);
            final sub = [if ('${m['name'] ?? ''}'.isNotEmpty && m['name'] != m['id']) '${m['name']}', '${m['type'] ?? ''}', '${m['owner'] ?? ''}', '${m['ownership'] ?? ''}', if (m['status'] == 'Inactive') 'Inactive'].where((v) => v.isNotEmpty).join('  |  ');
            return GsItem('mach', id, sub, chips.first.$2, [
              ...chips,
              if (s.canEdit('Diesel Issue')) ('New issue', () async => newEntry(context, kKinds.first, no: id)),
            ]);
          }(),
      ]
    ));
    final owners = <String, ({String name, int n, Set<String> own, bool debit})>{};
    if (s.canSee('Master')) {
      for (final m in ms) {
        final o = '${m['owner'] ?? ''}';
        if (o.isEmpty) continue;
        final k = o.toUpperCase(), was = owners[k];
        owners[k] = (name: was?.name ?? o, n: (was?.n ?? 0) + 1, own: {...?was?.own, '${m['ownership']}'}, debit: (was?.debit ?? false) || m['supply'] == 'Debit Basis');
      }
    }
    final debit = kDieselReports.where((d) => d.key == 'debit').firstOrNull;
    out.add((
      'Owners',
      [
        for (final o in gsRank(words, owners.values.toList(), (o) => [('Owner', o.name)], fixes, fuzzy: fz).take(5))
          GsItem('owner', o.name, '${o.own.join(', ')}  |  ${o.n} machinery', () => _push(AssetMasterScreen(find: o.name)), [
            ('Machinery', () => _push(AssetMasterScreen(find: o.name))),
            if (o.debit && s.canSee('Reports') && debit != null) ('Debit statement', () => openReport(context, debit, owner: o.name, run: true)),
          ]),
      ]
    ));
    return out;
  }

  // ---------------- the server's entries ----------------
  /// A list entry opened to be changed: the page's own list with that ID, then its form (the web's "Edit" button).
  Future<void> _edit(Kind k, String id) async {
    final f = switch (k.key) { 'inward' => {'from': '', 'to': '', 'pump': '', 'bill': id, 'location': ''}, 'transfer' => {'from': '', 'to': '', 'location': '', 'q': id}, _ => {'from': '', 'to': '', 'q': id} };
    try {
      final r = await s.api.call(k.list, [f]);
      final row = [for (final x in ((r is Map ? r['rows'] : null) as List? ?? const [])) if (x is Map && '${x['id']}' == id) x.cast<String, dynamic>()].firstOrNull;
      if (!mounted) return;
      if (row == null) {
        toast(context, '$id was not found.', bad: true);
        return;
      }
      await changeEntry(context, k, row);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  List<(String, List<GsItem>)> _server(Map r) {
    final s = this.s, c = (r['counts'] as Map?) ?? const {};
    List<Map> l(String k) => [for (final x in (r[k] as List? ?? const [])) if (x is Map) x];
    String head(String name, String key) => name + ((c[key] as num? ?? 0) > l(key).length ? '  (${c[key]} found – the best ${l(key).length})' : '');
    String why(Map x, String base) => [base, if ('${x['why'] ?? ''}'.isNotEmpty) 'found: ${x['why']}'].where((v) => v.isNotEmpty).join('  |  ');
    String sd(Object? d) => showDate('${d ?? ''}');
    String v(Object? x) => x == null ? '' : '$x';
    Kind k(String key) => kKinds.firstWhere((x) => x.key == key);
    return [
      (
        head('Diesel issues', 'issues'),
        [
          for (final x in l('issues'))
            GsItem('issue', '${x['id']}  –  ${x['no']}', why(x, '${sd(x['date'])} ${v(x['shift'])}  |  ${fmt(x['qty'])} L  |  ${v(x['source'])}${v(x['driver']).isNotEmpty ? '  |  ${x['driver']}' : ''}'),
                () => _push(EntryFindScreen(kind: k('issue'), q: '${x['id']}')), [if (s.canEdit('Diesel Issue')) ('Edit', () => _edit(k('issue'), '${x['id']}'))]),
        ]
      ),
      (
        head('Log Book', 'logs'),
        [
          for (final x in l('logs'))
            GsItem('log', '${x['no']}  –  ${sd(x['date'])} (${v(x['shift'])})', why(x, [if (v(x['wkm']).isNotEmpty) '${fmt(x['wkm'])} km', if (v(x['whr']).isNotEmpty) '${fmt(x['whr'])} hr', v(x['work'])].where((y) => y.isNotEmpty).join('  |  ')),
                () => _push(LogFindScreen(no: '${x['no']}', date: '${x['date']}', found: true))),
        ]
      ),
      (
        head('Diesel inward', 'inwards'),
        [
          for (final x in l('inwards'))
            GsItem('inward', '${x['id']}  –  ${v(x['pump'])}', why(x, '${sd(x['date'])}  |  ${fmt(x['qty'])} L  |  ${v(x['location'])}${v(x['bill']).isNotEmpty ? '  |  Bill ${x['bill']}' : ''}'),
                () => _push(EntryFindScreen(kind: k('inward'), bill: '${x['id']}')), [if (s.canEdit('Diesel Inward')) ('Edit', () => _edit(k('inward'), '${x['id']}'))]),
        ]
      ),
      (
        head('Transfers', 'transfers'),
        [
          for (final x in l('transfers'))
            GsItem('transfer', '${x['id']}  –  ${v(x['from'])} → ${v(x['to'])}', why(x, '${sd(x['date'])}  |  ${fmt(x['qty'])} L'), () => _push(EntryFindScreen(kind: k('transfer'), q: '${x['id']}')),
                [if (s.canEdit('Diesel Transfer')) ('Edit', () => _edit(k('transfer'), '${x['id']}'))]),
        ]
      ),
      (
        head('Tank checks', 'tanks'),
        [
          for (final x in l('tanks'))
            GsItem('tank', '${x['id']}  –  ${x['no']}', why(x, '${sd(x['date'])}  |  found ${fmt(x['physical'])} L  |  difference ${fmt(x['diff'])} L'), () => _push(TankCheckScreen(no: '${x['no']}', date: '${x['date']}'))),
        ]
      ),
      (
        head('Breakdowns', 'breakdowns'),
        [
          for (final x in l('breakdowns'))
            GsItem('brk', '${x['no']}  –  from ${sd(x['from'])}',
                why(x, '${v(x['backOn']).isNotEmpty ? 'working again ${sd(x['backOn'])}' : 'still in breakdown'}  |  ${v(x['days'])} day(s)${v(x['reason']).isNotEmpty ? '  |  ${x['reason']}' : ''}'), () => _push(BreakdownScreen(date: '${x['from']}'))),
        ]
      ),
      (
        head('Vendors', 'vendors'),
        [
          for (final x in l('vendors'))
            GsItem('vendor', '${x['name']}', why(x, [v(x['ownership']), if ((x['machines'] as num? ?? 0) > 0) '${x['machines']} machinery', if (v(x['gst']).isNotEmpty) 'GST ${x['gst']}'].where((y) => y.isNotEmpty).join('  |  ')),
                () => _push(VendorMasterScreen(find: '${x['name']}'))),
        ]
      ),
      (
        head('Bills', 'bills'),
        [
          for (final x in l('bills'))
            GsItem('bill', '${x['billNo']}  –  ${x['vendor']}', why(x, '${sd(x['from'])} to ${sd(x['to'])}  |  ₹ ${fmt(x['net'])}'), () => _push(DriveScreen(vendor: '${x['vendor']}', from: '${x['from']}', to: '${x['to']}'))),
        ]
      ),
      (
        head('Debit notes', 'notes'),
        [
          for (final x in l('notes'))
            GsItem('note', '${x['no']}  –  ${x['vendor']}', why(x, '${sd(x['date'])}  |  ₹ ${fmt(x['total'])}'),
                () => _push(DriveScreen(vendor: '${x['vendor']}', from: v(x['from']).isNotEmpty ? '${x['from']}' : '${x['date']}', to: v(x['to']).isNotEmpty ? '${x['to']}' : '${x['date']}'))),
        ]
      ),
      (
        head('Payments', 'payments'),
        [
          for (final x in l('payments'))
            GsItem('pay', '${x['id']}  –  ${x['vendor']}', why(x, '${sd(x['date'])}  |  ₹ ${fmt(x['amount'])}${v(x['mode']).isNotEmpty ? '  |  ${x['mode']}' : ''}${v(x['ref']).isNotEmpty ? '  |  ${x['ref']}' : ''}'),
                () => _push(PaymentsScreen(vendor: '${x['vendor']}', date: '${x['date']}'))),
        ]
      ),
      (
        head('BOQ / work orders', 'boqs'),
        [
          for (final x in l('boqs'))
            GsItem('boq', '${v(x['no']).isNotEmpty ? x['no'] : x['id']}  –  ${x['vendor']}',
                why(x, '${v(x['woNo']).isNotEmpty ? 'WO ${x['woNo']}  |  ' : ''}from ${sd(x['from'])}${(x['amendNo'] as num? ?? 0) > 0 ? '  |  amendment ${x['amendNo']}' : ''}'), () => openBoq(context, vendor: '${x['vendor']}')),
        ]
      ),
      (
        head('Vehicle papers', 'papers'),
        [
          for (final x in l('papers'))
            GsItem('paper', '${x['no']}  –  ${x['doc']}',
                why(x, '${v(x['docNo']).isNotEmpty ? 'No ${x['docNo']}  |  ' : ''}${v(x['to']).isNotEmpty ? 'valid up to ${RegExp(r'^\d{4}-\d\d-\d\d$').hasMatch(v(x['to'])) ? sd(x['to']) : x['to']}' : ''}'),
                () => _push(ComplianceScreen(find: '${x['no']}'))),
        ]
      ),
    ];
  }

  List<(String, List<GsItem>)> _storeGroups() {
    final items = storeItems;
    if (items == null || gsWords(q).isEmpty) return [];
    return [
      (
        'Store – Items',
        [
          for (final i in storeFind(q, items))
            GsItem('item', '${i['code']}  –  ${i['name']}', [i['unit'], i['category'], if ('${i['hsn'] ?? ''}'.isNotEmpty) 'HSN ${i['hsn']}', if (i['status'] == 'Inactive') 'Inactive'].where((v) => '${v ?? ''}'.isNotEmpty).join('  |  '),
                () => _push(StoreScreen(find: '${i['code']}'))),
        ]
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    SessionScope.of(context);
    final words = gsWords(q), fixes = <(String, String)>[];
    final groups = [..._local(q, fixes), if (server != null) ..._server(server!), ..._storeGroups()];
    // an owner of the machinery list that is also a vendor found by the server: one result, with a "Vendor" button
    final ownG = groups.where((g) => g.$1 == 'Owners').firstOrNull, venI = groups.indexWhere((g) => g.$1.startsWith('Vendors'));
    if (ownG != null && venI >= 0) {
      final keep = <GsItem>[];
      for (final v in groups[venI].$2) {
        final o = ownG.$2.where((x) => x.title.toUpperCase() == v.title.toUpperCase()).firstOrNull;
        if (o == null) {
          keep.add(v);
        } else {
          o.chips = [...o.chips, ('Vendor', v.run)];
        }
      }
      groups[venI] = (groups[venI].$1, keep);
    }
    groups.removeWhere((g) => g.$2.isEmpty);
    for (final f in (server?['fixes'] as List? ?? const [])) {
      if (f is Map) fixes.add(('${f['w']}', '${f['to']}'));
    }
    final better = gsBetter(words, fixes, groups.any((g) => g.$2.isNotEmpty));
    final waiting = words.isNotEmpty && (server == null || storeWait) && q.trim().length >= 2;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('gs-in'),
          controller: box,
          autofocus: true,
          onChanged: _input,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: tr('Search everything – machinery, IDs, readings, vendors, bills…'), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
        ),
        actions: [
          if (q.isNotEmpty)
            IconButton(
              tooltip: tr('Clear'),
              onPressed: () {
                box.clear();
                _input('');
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: ListView(key: const Key('gs-list'), padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
        if (better.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              Text('Did you mean', style: const TextStyle(color: C.muted)),
              ActionChip(
                key: const Key('gs-fix'),
                label: Text(better, style: const TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () {
                  box.text = better;
                  _input(better);
                },
              ),
              Text('(shown below as well)', style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(waiting ? 'Searching…' : 'Nothing found for “$q”. Try fewer words, a number (reading, bill no, challan) or a part of a name.', key: const Key('gs-none'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
          ),
        for (final g in groups) ...[
          Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 6), child: Text(g.$1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: C.muted, letterSpacing: .4))),
          for (final it in g.$2) _item(it),
        ],
        if (groups.isNotEmpty && waiting) Padding(padding: const EdgeInsets.all(12), child: Text('Searching entries…', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
      ]),
    );
  }

  Widget _item(GsItem it) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Press(
          key: Key('gs-${it.kind}-${it.title}'),
          onTap: () => it.run(),
          radius: 16,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_icons[it.kind] ?? Icons.circle_outlined, color: C.green, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (it.sub.isNotEmpty) Text(it.sub, style: const TextStyle(fontSize: 12.5, color: C.muted)),
                ]),
              ),
            ]),
            if (it.chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 6),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in it.chips)
                    ActionChip(key: Key('gs-chip-${it.title}-${c.$1}'), visualDensity: VisualDensity.compact, label: Text(c.$1), onPressed: () => c.$2()),
                ]),
              ),
          ]),
        ),
      );
}
