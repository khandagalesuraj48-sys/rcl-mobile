/* BREAKDOWN – the app's own screen (3.7.0) of the web's Breakdown page (Home → Maintenance): the daily machinery status – every
 * machinery on site on a date, Working or Breakdown (the reason; a remark), since when and how many days; Submit / Save changes,
 * Delete this day, Print; the saved days (tap: open that day); the period report – breakdown days per machinery, per owner or
 * owner → machinery, with Print and Excel. The rules: core/breakdown.dart. Server: getBreakdowns, submitBdReport, deleteBdReport. */
import 'package:flutter/material.dart' hide Text;

import '../core/breakdown.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart' show MachinePicker;

Future<void> openBreakdown(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BreakdownScreen()));

class BreakdownScreen extends StatefulWidget {
  const BreakdownScreen({super.key});
  @override
  State<BreakdownScreen> createState() => _BreakdownScreenState();
}

class _BreakdownScreenState extends State<BreakdownScreen> {
  String date = '', q = '', err = '';
  final owns = {'Own', 'Rental', 'Hired'};
  BkDay? d;
  bool loading = true, busy = false;
  final _c = <String, TextEditingController>{};
  // the period report
  String pFrom = '', pTo = '', pView = 'mach', pOwn = '', pOwner = '', pNo = '';
  bool pOnly = false;
  int _seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (date.isNotEmpty) return;
    final s = SessionScope.read(context);
    date = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    pFrom = '${date.substring(0, 8)}01';
    pTo = date;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _master(Session s) => [for (final m in s.machines) m.m];

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = ((await s.api.call('getBreakdowns', [
        {'date': date}
      ])) as Map).cast<String, dynamic>();
      if (my != _seq || !mounted) return;
      for (final c in _c.values) {
        c.dispose();
      }
      _c.clear();
      setState(() {
        d = BkDay(r);
        loading = false;
      });
    } catch (e) {
      if (my != _seq || !mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  TextEditingController _box(Map m, String f) => _c.putIfAbsent('${bkKey(m['id'])}|$f', () => TextEditingController(text: f == 'reason' ? d!.state(m).reason : d!.state(m).remark));

  Future<void> _submit() async {
    final s = SessionScope.read(context), x = d!, list = x.list(_master(s), owns, q), rows = x.body(list);
    final no = x.problem(rows);
    if (no.isNotEmpty) {
      toast(context, no, bad: true);
      return;
    }
    final nb = rows.where((r) => r['status'] == 'Breakdown').length;
    final ok = await askLines(context, '${x.report != null ? 'Save changes – ' : 'Submit – '}${showDate(x.date)}', [
      '${rows.length} machinery (${kBkOwns.where(owns.contains).join(', ')}): ${rows.length - nb} working, $nb breakdown.',
    ], note: x.report != null ? 'It updates the status already saved for this date.' : '', yes: x.report != null ? 'Save' : 'Submit');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await s.api.call('submitBdReport', [
        {'date': x.date, 'rows': rows}
      ], true);
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, 'Status of ${showDate(x.date)} saved.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  Future<void> _delete() async {
    final s = SessionScope.read(context), x = d!;
    if (x.report == null) return;
    if (!await ask(context, 'Delete the status of ${showDate(x.date)}?', 'All ${(x.report!['rows'] as List? ?? const []).length} machinery of this date are removed. Other dates stay.', yes: 'Delete', danger: true)) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await s.api.call('deleteBdReport', [x.date], true);
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, 'Deleted.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const TwoLang('Breakdown', 'ब्रेकडाउन', size: 20, weight: FontWeight.w700),
          actions: [IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
          bottom: TabBar(
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            tabs: [
              Tab(key: const Key('bt-day'), child: Text('Daily status')),
              Tab(key: const Key('bt-days'), child: Text('Saved days')),
              Tab(key: const Key('bt-period'), child: Text('Period')),
            ],
          ),
        ),
        body: loading && d == null
            ? const Center(child: CircularProgressIndicator())
            : d == null
                ? ListView(padding: const EdgeInsets.all(16), children: [InfoLine(err, bad: true)])
                : TabBarView(children: [_day(s, d!), _days(d!), _period(s, d!)]),
      ),
    );
  }

  // ---------- the day ----------
  Widget _day(Session s, BkDay x) {
    final can = s.canEdit('Breakdown'), list = x.list(_master(s), owns, q), nb = list.where((m) => x.state(m).bd).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        key: const Key('bk-list'),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
        itemCount: list.length + 1,
        itemBuilder: (_, i) {
          if (i > 0) return _card(x, list[i - 1], i, can);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Every machinery on site: Working or Breakdown. A machinery under breakdown can still take diesel and have Log Book entries.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
            const SizedBox(height: 10),
            DateField(key: const Key('bk-date'), label: 'Date', value: date, clear: false, last: x.today.isEmpty ? null : parseKey(x.today), onChanged: (v) {
              setState(() => date = v);
              _load();
            }),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Machinery:', style: const TextStyle(fontSize: 13, color: C.muted)),
              for (final o in kBkOwns)
                FilterChip(
                  key: Key('bk-own-$o'),
                  label: Text(o),
                  selected: owns.contains(o),
                  onSelected: (on) => setState(() => on ? owns.add(o) : owns.remove(o)),
                ),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: x.report != null ? C.greenSoft : C.amberSoft, borderRadius: BorderRadius.circular(14)),
              child: Text(x.statusText, key: const Key('bk-status'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: x.report != null ? C.greenDark : C.amber, height: 1.35)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Pill('Working ${list.length - nb}', color: C.greenDark, bg: C.greenSoft),
              const SizedBox(width: 6),
              Pill('Breakdown $nb', color: C.red, bg: C.redSoft),
              const SizedBox(width: 8),
              Expanded(child: Text('${list.length} machinery shown', style: const TextStyle(fontSize: 12.5, color: C.muted))),
            ]),
            const SizedBox(height: 8),
            TextField(key: const Key('bk-q'), onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: tr('Search machinery / owner…'), prefixIcon: const Icon(Icons.search_rounded), isDense: true)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (can)
                FilledButton.icon(
                  key: const Key('bk-submit'),
                  onPressed: busy ? null : _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(x.submitWord),
                ),
              if (can && x.report != null) OutlinedButton.icon(key: const Key('bk-del'), onPressed: busy ? null : _delete, icon: const Icon(Icons.delete_outline_rounded, color: C.red), label: Text('Delete this day')),
              OutlinedButton.icon(key: const Key('bk-print'), onPressed: () => printDoc(context, s, x.dayDoc(list, owns)), icon: const Icon(Icons.print_rounded), label: Text('Print')),
              if (can)
                OutlinedButton(
                  key: const Key('bk-clear'),
                  onPressed: () async {
                    if (await ask(context, 'Clear the breakdown sheet?', 'What is typed here and not saved will be removed. Saved entries are not touched.', yes: 'Clear')) _load();
                  },
                  child: Text('Clear'),
                ),
            ]),
            const SizedBox(height: 12),
            if (list.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No machinery for these choices.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
          ]);
        },
      ),
    );
  }

  Widget _card(BkDay x, Map<String, dynamic> m, int i, bool can) {
    final st = x.state(m), sn = x.since(m);
    final sub = [if ('${m['no'] ?? ''}'.isNotEmpty) '${m['name'] ?? ''}', '${m['type'] ?? ''}'].where((e) => e.isNotEmpty).join(' · ');
    return Container(
      key: ValueKey('bk-${m['id']}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: st.bd ? const Color(0xFFFFF7F6) : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: st.bd ? C.red : C.line, width: st.bd ? 1.4 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 26, child: Text('$i', style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w700))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['id']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12.5, color: C.muted)),
              Text([if ('${m['owner'] ?? ''}'.isNotEmpty) '${m['owner']}', '${m['ownership'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ]),
          ),
          if (sn != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Since ${showDate(sn.from)}', style: const TextStyle(fontSize: 12, color: C.muted)),
              Text('${sn.days} day${sn.days == 1 ? '' : 's'}', key: Key('bk-days-${m['id']}'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: sn.days >= 7 ? C.red : C.ink)),
            ]),
        ]),
        const SizedBox(height: 8),
        if (can)
          SegmentedButton<String>(
            key: Key('bk-sw-${m['id']}'),
            segments: [
              ButtonSegment(value: 'Working', label: Text('Working'), icon: const Icon(Icons.check_circle_outline_rounded)),
              ButtonSegment(value: 'Breakdown', label: Text('Breakdown'), icon: const Icon(Icons.build_circle_outlined)),
            ],
            selected: {st.status},
            onSelectionChanged: (v) => setState(() => x.edit(m).status = v.first),
          )
        else
          Align(alignment: Alignment.centerLeft, child: Pill(st.status, color: st.bd ? C.red : C.greenDark, bg: st.bd ? C.redSoft : C.greenSoft)),
        if (st.bd) ...[
          const SizedBox(height: 8),
          if (can)
            TextBox(key: Key('bk-reason-${m['id']}'), label: 'Reason (breakdown) *', controller: _box(m, 'reason'), options: kBkReasons, onChanged: (v) => setState(() => x.edit(m).reason = v))
          else
            InfoRow('Reason', st.reason),
        ],
        if (can) ...[
          const SizedBox(height: 8),
          TextBox(key: Key('bk-remark-${m['id']}'), label: 'Remark', controller: _box(m, 'remark'), onChanged: (v) => x.edit(m).remark = v),
        ] else if (st.remark.isNotEmpty)
          InfoRow('Remark', st.remark),
      ]),
    );
  }

  // ---------- the saved days ----------
  Widget _days(BkDay x) => ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
        Text('Tap a day to open it – change or delete it there.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        const SizedBox(height: 10),
        if (x.reports.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No day saved yet.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
        for (final r in x.reports)
          Builder(
            builder: (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Press(
                key: Key('bkd-${r['date']}'),
                radius: 16,
                shadow: false,
                padding: const EdgeInsets.all(12),
                onTap: () {
                  setState(() => date = '${r['date']}');
                  DefaultTabController.of(c).animateTo(0);
                  _load();
                },
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(showDate('${r['date']}'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: r['date'] == x.date ? C.green : C.ink)),
                      Text([if ('${r['by'] ?? ''}'.isNotEmpty) '${r['by']}', '${r['at'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    ]),
                  ),
                  Pill('${r['total']} machinery', color: C.slate, bg: C.slateSoft),
                  const SizedBox(width: 6),
                  Pill('${(asNum(r['total']) ?? 0) - (asNum(r['count']) ?? 0)}', color: C.greenDark, bg: C.greenSoft),
                  const SizedBox(width: 4),
                  Pill('${r['count']}', color: C.red, bg: C.redSoft),
                ]),
              ),
            ),
          ),
      ]);

  // ---------- the period report ----------
  Widget _period(Session s, BkDay x) {
    final master = _master(s), rows = bpCalc(x, master, pFrom, pTo, own: pOwn, owner: pOwner, no: pNo, only: pOnly);
    final owners = {for (final m in master) if ('${m['owner'] ?? ''}'.isNotEmpty) '${m['owner']}'}.toList()..sort();
    final tot = (site: rows.fold<int>(0, (a, r) => a + r.site), bd: rows.fold<int>(0, (a, r) => a + r.bd), work: rows.fold<int>(0, (a, r) => a + r.work), times: rows.fold<int>(0, (a, r) => a + r.times));
    return ListView(key: const Key('bp-list'), padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
      Text('How many days each machinery was under breakdown.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: DateField(key: const Key('bp-from'), label: 'From', value: pFrom, clear: false, onChanged: (v) => setState(() => pFrom = v))),
        const SizedBox(width: 8),
        Expanded(child: DateField(key: const Key('bp-to'), label: 'To', value: pTo, clear: false, onChanged: (v) => setState(() => pTo = v))),
      ]),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        key: const Key('bp-view'),
        segments: [for (final v in kBpViews.entries) ButtonSegment(value: v.key, label: Text(v.value, style: const TextStyle(fontSize: 12.5)))],
        selected: {pView},
        onSelectionChanged: (v) => setState(() => pView = v.first),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: PickField(key: const Key('bp-own'), label: 'Ownership', value: pOwn, items: kBkOwns, blank: 'Own + Rental + Hired + Other', onChanged: (v) => setState(() => pOwn = v))),
        const SizedBox(width: 8),
        Expanded(child: PickField(key: const Key('bp-owner'), label: 'Owner', value: pOwner, items: owners, blank: 'All owners', onChanged: (v) => setState(() => pOwner = v))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: Press(
            key: const Key('bp-no'),
            radius: 16,
            shadow: false,
            padding: const EdgeInsets.all(12),
            onTap: () async {
              final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => MachinePicker(only: s.machines));
              if (m != null) setState(() => pNo = m.id);
            },
            child: Row(children: [
              Expanded(child: Text(pNo.isEmpty ? 'All machinery' : pNo, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: pNo.isEmpty ? C.faint : C.ink))),
              if (pNo.isNotEmpty) InkWell(onTap: () => setState(() => pNo = ''), child: const Icon(Icons.close_rounded, size: 18, color: C.muted)),
            ]),
          ),
        ),
      ]),
      SwitchListTile(key: const Key('bp-only'), contentPadding: EdgeInsets.zero, value: pOnly, onChanged: (v) => setState(() => pOnly = v), title: Text('Only machinery with breakdown', style: const TextStyle(fontSize: 14))),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(key: const Key('bp-print'), onPressed: () => printDoc(context, s, bpDoc(rows, pView, pFrom, pTo, own: pOwn, owner: pOwner)), icon: const Icon(Icons.print_rounded), label: Text('Print')),
        OutlinedButton.icon(key: const Key('bp-xls'), onPressed: () => shareDocXlsx(s, bpXlsDoc(rows, pFrom, pTo), bare: true), icon: const Icon(Icons.table_view_rounded), label: Text('Excel')),
        OutlinedButton(
          key: const Key('bp-clear'),
          onPressed: () => setState(() {
            pFrom = '${x.today.substring(0, 8)}01';
            pTo = x.today;
            pOwn = pOwner = pNo = '';
            pOnly = false;
          }),
          child: Text('Clear filters'),
        ),
      ]),
      const SizedBox(height: 10),
      Container(
        key: const Key('bp-total'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.slateSoft, borderRadius: BorderRadius.circular(16)),
        child: Wrap(spacing: 16, runSpacing: 6, children: [
          _fig('Machinery', '${rows.length}'),
          _fig('Days on site', '${tot.site}'),
          _fig('Breakdown days', '${tot.bd}', tone: tot.bd > 0 ? C.red : C.ink),
          _fig('Working days', '${tot.work}'),
          _fig('Breakdown %', bpPct(tot.bd, tot.site)),
          _fig('Times', '${tot.times}'),
        ]),
      ),
      const SizedBox(height: 10),
      if (rows.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Nothing for these choices.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
      if (pView == 'owner')
        for (final o in bpOwners(rows)) _ownerCard(o.owner, o.ownership, o.n, o.site, o.bd, o.work, o.times)
      else if (pView == 'both')
        for (final o in bpOwners(rows)) ...[
          _ownerCard(o.owner, o.ownership, o.n, o.site, o.bd, o.work, o.times),
          for (final r in rows.where((r) => (r.owner.isEmpty ? '–' : r.owner) == o.owner)) Padding(padding: const EdgeInsets.only(left: 14), child: _machCard(r, owner: false)),
        ]
      else
        for (final r in rows) _machCard(r),
    ]);
  }

  Widget _fig(String l, String v, {Color tone = C.ink}) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(l, style: const TextStyle(fontSize: 11.5, color: C.muted)),
        Text(v, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: tone)),
      ]);

  Widget _ownerCard(String owner, String ownership, int n, int site, int bd, int work, int times) => Container(
        key: ValueKey('bpo-$owner'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(owner, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          Text('$n machinery · $ownership', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 14, runSpacing: 4, children: [_fig('On site', '$site'), _fig('Breakdown', '$bd', tone: bd > 0 ? C.red : C.ink), _fig('Working', '$work'), _fig('%', bpPct(bd, site)), if (times > 0) _fig('Times', '$times')]),
        ]),
      );

  Widget _machCard(BpRow r, {bool owner = true}) => Container(
        key: ValueKey('bpm-${r.no}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: r.bd > 0 ? C.red : C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.no, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          Text([r.type, if (owner) r.owner, if (owner) r.ownership].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 14, runSpacing: 4, children: [_fig('On site', '${r.site}'), _fig('Breakdown', '${r.bd}', tone: r.bd > 0 ? C.red : C.ink), _fig('Working', '${r.work}'), _fig('%', bpPct(r.bd, r.site)), if (r.times > 0) _fig('Times', '${r.times}')]),
          if (r.why.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.why.join(' · '), style: const TextStyle(fontSize: 12.5, height: 1.35))),
        ]),
      );
}
