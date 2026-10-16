/* VEHICLE COMPLIANCE – the app's own screens (3.4.0), the same as the web's page: Tax, PUC, Permit, Fitness and Insurance of
 * every active Own / Rental / Hired machinery. The four counts (expired, due in 30 days, not entered, valid), the chips (needs
 * attention / expired / due / not entered / all), ownership and search; each machinery with its papers – tap a paper to renew it
 * (the new date goes into Asset Master, the old one into the history); "Papers per type" (which papers a type needs); Export
 * Excel (what is on the screen, the same file the web gives); the renewal history.
 * Server: getCompliance, renewDoc, saveCmpRules. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/masters.dart';
import '../core/rdoc.dart' show RDoc, RTable, RRow, RCell;
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

Future<void> openCompliance(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ComplianceScreen()));

List<Map<String, dynamic>> _maps(dynamic l) => [for (final x in (l as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];

Color cmpFg(String s) => switch (s) { 'expired' => C.red, 'due' => C.amber, 'missing' => C.blue, 'ok' || 'life' => C.greenDark, _ => C.muted };
Color cmpBg(String s) => switch (s) { 'expired' => C.redSoft, 'due' => C.amberSoft, 'missing' => C.blueSoft, 'ok' || 'life' => C.greenSoft, _ => C.slateSoft };

/// The Excel of what is on the screen – the same columns as the web (and its "How to fill" sheet), to be imported back.
RDoc complianceExportDoc(Map<String, dynamic> d, List<Map<String, dynamic>> rows, String today, String filterText) {
  final docs = cmpDocs(d);
  String cellV(Map<String, dynamic> x) => x['s'] == 'notreq' ? 'Not needed' : x['v'] == 'NA' ? 'N/A' : x['v'] == 'LIFETIME' ? 'Lifetime' : RegExp(r'^\d{4}-').hasMatch('${x['v'] ?? ''}') ? showDate('${x['v']}') : '';
  String stat(Map<String, dynamic> m) {
    List<String> of(String st) => docs.where((k) => cmpDoc(m, k)['s'] == st).toList();
    final b = of('expired'), du = of('due'), mi = of('missing');
    final t = [if (b.isNotEmpty) 'Expired: ${b.join(', ')}', if (du.isNotEmpty) 'Due: ${du.join(', ')}', if (mi.isNotEmpty) 'Not entered: ${mi.join(', ')}'].join(' | ');
    return t.isEmpty ? 'OK' : t;
  }

  return RDoc(title: 'Vehicle Compliance', file: 'Vehicle_Compliance_$today', blocks: [
    RTable(sheet: 'Compliance', head: ['Machinery No', 'Type', 'Ownership', 'Owner', ...docs, 'Status (not imported)'], rows: [
      for (final m in rows) RRow([RCell('${m['no']}'), RCell('${m['type'] ?? ''}'), RCell('${m['ownership'] ?? ''}'), RCell('${m['owner'] ?? ''}'), for (final k in docs) RCell(cellV(cmpDoc(m, k))), RCell(stat(m))]),
    ]),
    RTable(sheet: 'How to fill', head: const ['How to fill (for Import)'], rows: [
      for (final l in [
        'Dates: dd-mm-yyyy, e.g. 31-03-2027', 'Lifetime = tax paid for life (Tax column only)', 'N/A = this paper does not apply to this machinery', 'Blank = no change',
        '"Not needed" = the type does not need this paper (set in "Papers per type") – leave it', 'Do not change "Machinery No". Type, Ownership, Owner and Status are not imported.', '',
        'Exported: ${showDate(today)} · Filter: ${filterText.isEmpty ? 'All' : filterText}',
      ])
        RRow([RCell(l)]),
    ]),
  ]);
}

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});
  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  Map<String, dynamic>? d;
  bool loading = true;
  String err = '', chip = 'attention', own = '', q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool quiet = false}) async {
    final s = SessionScope.read(context);
    if (!quiet) setState(() => loading = true);
    try {
      final r = (await s.api.call('getCompliance') as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        d = r;
        loading = false;
        err = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  String get _filterText => [kCmpChips.firstWhere((c) => c.$1 == chip).$2, kCmpOwn.firstWhere((o) => o.$1 == own).$2, if (q.trim().isNotEmpty) 'search "${q.trim()}"'].join(' · ');

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final can = s.canEdit('Vehicle Compliance');
    final dd = d;
    final base = dd == null ? const <Map<String, dynamic>>[] : cmpBase(dd, own, q);
    final rows = dd == null ? const <Map<String, dynamic>>[] : cmpRows(dd, base, chip);
    final n = dd == null ? const <String, int>{} : cmpCounts(dd, base);
    final hist = _maps(dd?['history']).where((h) => q.trim().isEmpty || '${h['no']} ${h['doc']}'.toUpperCase().contains(q.trim().toUpperCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: const TwoLang('Vehicle Compliance', 'वाहन कागदपत्रे', size: 20, weight: FontWeight.w700),
        actions: [
          PopupMenuButton<String>(
            key: const Key('cp-menu'),
            onSelected: (k) {
              if (k == 'rules') _rules();
              if (k == 'xlsx') _export(s, rows);
            },
            itemBuilder: (_) => [
              if (can) PopupMenuItem(value: 'rules', child: Text('Papers per type')),
              PopupMenuItem(value: 'xlsx', child: Text('Export Excel')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Text('Tax, PUC, Permit, Fitness and Insurance of every active Own / Rental / Hired machinery. Tap a paper to renew it – the new date goes into Asset Master and the old one is kept in the history.', style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 12),
          if (loading && dd == null)
            ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: Shimmer(height: 110)))
          else if (dd != null) ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.45,
              children: [
                _count('cpc-x', 'Expired', n['expired'] ?? 0, 'papers · ${n['mexpired'] ?? 0} machinery', 'expired'),
                _count('cpc-d', 'Due in 30 days', n['due'] ?? 0, 'papers · ${n['mdue'] ?? 0} machinery', 'due'),
                _count('cpc-m', 'Not entered', n['missing'] ?? 0, 'papers with no date – enter the date or mark N/A', 'missing'),
                _count('cpc-o', 'Valid', (n['ok'] ?? 0) + (n['life'] ?? 0), 'papers OK${(n['life'] ?? 0) > 0 ? ' · ${n['life']} lifetime tax' : ''}${(n['na'] ?? 0) > 0 ? ' · ${n['na']} not applicable' : ''}', 'ok'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView(key: const Key('cp-chips'), scrollDirection: Axis.horizontal, children: [
                for (final c in kCmpChips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('cpc-${c.$1}'),
                      selected: chip == c.$1,
                      onSelected: (_) => setState(() => chip = c.$1),
                      label: Text('${tr(c.$2)} ${base.where((m) => cmpChipHas(dd, m, c.$1)).length}'),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: PickField(key: const Key('cp-own'), label: 'Ownership', value: own, items: [for (final o in kCmpOwn.skip(1)) o.$1], blank: kCmpOwn.first.$2, onChanged: (v) => setState(() => own = v))),
            ]),
            const SizedBox(height: 8),
            TextField(key: const Key('cp-q'), onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: tr('Search machinery / owner…'), prefixIcon: const Icon(Icons.search_rounded), contentPadding: const EdgeInsets.symmetric(vertical: 12))),
            if ((asNum(dd['noPapers']) ?? 0) > 0)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('${dd['noPapers']} machinery need no papers (DG, pumps, compressors …) and are not listed. Which papers each type needs: Papers per type.', style: const TextStyle(fontSize: 12.5, color: C.muted))),
            const SizedBox(height: 10),
            if (rows.isEmpty) EmptyState('✔ Nothing here – all papers are fine for these filters.', '', pic: 'shield'),
            for (final m in rows) Padding(padding: const EdgeInsets.only(bottom: 10), child: _machine(dd, m, can)),
            FormHead('Renewal history', sub: '${hist.length} entr${hist.length == 1 ? 'y' : 'ies'}${q.trim().isNotEmpty ? ' for "${q.trim()}"' : ''}'),
            if (hist.isEmpty) Text('No renewals yet.', style: const TextStyle(color: C.muted)),
            for (final h in hist.take(300))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${h['no']} · ${h['doc']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text(cmpDateWords(h['on']), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                  ]),
                  const SizedBox(height: 2),
                  Text('${cmpDateWords(h['from'])} → ${cmpDateWords(h['to'])}', style: const TextStyle(fontWeight: FontWeight.w700, color: C.greenDark)),
                  Text([
                    if ('${h['docNo'] ?? ''}'.isNotEmpty) 'Doc / Policy No ${h['docNo']}',
                    if ('${h['amount'] ?? ''}'.isNotEmpty) '₹${fmtNum(asNum(h['amount']))}',
                    if ('${h['remark'] ?? ''}'.isNotEmpty) '${h['remark']}',
                    if (h['source'] == 'Asset Master') 'changed in Asset Master',
                    if ('${h['by'] ?? ''}'.isNotEmpty) '${h['by']}',
                  ].join(' · '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                ]),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _count(String key, String label, int n, String sub, String st) => Container(
        key: Key(key),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cmpBg(st), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: cmpFg(st), fontWeight: FontWeight.w700)),
          Text('$n', style: TextStyle(fontSize: 24, color: cmpFg(st), fontWeight: FontWeight.w800)),
          Expanded(child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: cmpFg(st).withValues(alpha: .85)))),
        ]),
      );

  Widget _machine(Map<String, dynamic> d, Map<String, dynamic> m, bool can) {
    final docs = cmpDocs(d);
    return Container(
      key: Key('cp-${m['no']}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line), boxShadow: softShadow(.04)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${m['no']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Text([m['type'], m['ownership'], m['owner']].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (_, bx) => Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in docs)
            (() {
              final x = cmpDoc(m, k), st = '${x['s']}', t = cmpCellText(x), tap = can && st != 'notreq';
              return InkWell(
                key: Key('cpr-${m['no']}-$k'),
                borderRadius: BorderRadius.circular(12),
                onTap: tap ? () => _renew(m, k) : null,
                child: Container(
                  width: (bx.maxWidth - 6) / 2,
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  decoration: BoxDecoration(color: cmpBg(st), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cmpFg(st))),
                    Text(t.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: cmpFg(st))),
                    Text(t.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: cmpFg(st))),
                  ]),
                ),
              );
            })(),
        ])),
      ]),
    );
  }

  Future<void> _renew(Map<String, dynamic> m, String doc) async {
    final s = SessionScope.read(context), cur = cmpDoc(m, doc), st = '${cur['s']}', no = '${m['no']}';
    var to = '', on = s.today, na = false, lt = st == 'life';
    final docNo = TextEditingController(), amt = TextEditingController(), rem = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('${st == 'missing' ? 'Enter' : 'Renew'} $doc'),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('$no – $doc', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('Now: ${st == 'na' ? 'N/A' : st == 'missing' ? 'not entered' : '${showDate('${cur['v']}')}${st == 'expired' ? ' (expired)' : ''}'}', style: const TextStyle(color: C.muted)),
            const SizedBox(height: 10),
            DateField(key: const Key('cp-to'), label: 'New valid upto', value: to, enabled: !na && !lt, onChanged: (v) => set(() => to = v)),
            if (doc == 'Tax') CheckboxListTile(key: const Key('cp-lt'), contentPadding: EdgeInsets.zero, value: lt, onChanged: (v) => set(() => lt = v == true), title: Text('Lifetime tax paid')),
            CheckboxListTile(key: const Key('cp-na'), contentPadding: EdgeInsets.zero, value: na, onChanged: (v) => set(() => na = v == true), title: Text('Not applicable for this machinery')),
            DateField(key: const Key('cp-on'), label: 'Renewed on', value: on, clear: false, last: parseKey(s.today), onChanged: (v) => set(() => on = v)),
            const SizedBox(height: 8),
            TextBox(key: const Key('cp-docno'), label: 'Doc / Policy No (optional)', controller: docNo),
            const SizedBox(height: 8),
            TextBox(key: const Key('cp-amt'), label: 'Amount ₹ (optional)', controller: amt, kb: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 8),
            TextBox(key: const Key('cp-rem'), label: 'Remark (optional)', controller: rem),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(key: const Key('cp-save'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c, true), child: Text('Save')),
          ],
        ),
      ),
    );
    final x = {'no': no, 'doc': doc, 'to': na ? 'NA' : lt && doc == 'Tax' ? 'LIFETIME' : to, 'on': on, 'docNo': docNo.text, 'amount': amt.text, 'remark': rem.text};
    if (ok != true || !mounted) return;
    if ('${x['to']}'.isEmpty) {
      toast(context, 'Enter the new valid-upto date.', bad: true);
      return;
    }
    try {
      await s.api.call('renewDoc', [x], true);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      toast(context, '$doc of $no saved – ${x['to'] == 'NA' ? 'N/A' : x['to'] == 'LIFETIME' ? 'lifetime tax paid' : 'valid upto ${showDate('${x['to']}')}'}.');
      await _load(quiet: true);
      try {
        await s.loadInit(); // the new date is in Asset Master
        s.setMaster([for (final m in s.machines) m.m]);
      } catch (_) {/* the live sync brings it */}
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  Future<void> _rules() async {
    final dd = d;
    if (dd == null) return;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _RulesScreen(types: _maps(dd['types']))));
    if (saved == true && mounted) {
      toast(context, 'Saved – papers per type.');
      await _load(quiet: true);
    }
  }

  Future<void> _export(Session s, List<Map<String, dynamic>> rows) async {
    final dd = d;
    if (dd == null) return;
    if (rows.isEmpty) {
      toast(context, 'Nothing to export for this filter.', bad: true);
      return;
    }
    try {
      await shareDocXlsx(s, complianceExportDoc(dd, rows, s.today, _filterText), bare: true);
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }
}

/// Papers needed per machinery type (a type with nothing ticked is left out of Vehicle Compliance).
class _RulesScreen extends StatefulWidget {
  const _RulesScreen({required this.types});
  final List<Map<String, dynamic>> types;
  @override
  State<_RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<_RulesScreen> {
  static const docs = ['Tax', 'PUC', 'Permit', 'Fitness', 'Insurance'];
  late final rules = <String, Set<String>>{for (final t in widget.types) '${t['key']}': {for (final x in (t['docs'] as List? ?? const [])) '$x'}};
  bool busy = false;

  Future<void> _save() async {
    final s = SessionScope.read(context);
    setState(() => busy = true);
    try {
      await s.api.call('saveCmpRules', [{for (final e in rules.entries) e.key: [for (final x in docs) if (e.value.contains(x)) x]}], true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Papers needed per machinery type')),
        body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Tick the papers a type of machinery must have. Papers not ticked are not asked for (shown as —). A type with nothing ticked (DG, pump …) is left out of Vehicle Compliance.', style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
          const SizedBox(height: 10),
          for (final t in widget.types)
            Container(
              key: Key('cr-${t['key']}'),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${t['type']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
                  Pill('${t['count']} machinery', color: C.slate, bg: C.slateSoft),
                ]),
                Text(t['set'] == true ? 'set by you' : '${t['guess'] ?? ''}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final x in docs)
                    FilterChip(
                      key: Key('cr-${t['key']}-$x'),
                      label: Text(x),
                      selected: rules['${t['key']}']!.contains(x),
                      onSelected: (v) => setState(() => v ? rules['${t['key']}']!.add(x) : rules['${t['key']}']!.remove(x)),
                    ),
                ]),
                Wrap(spacing: 0, children: [
                  for (final p in kCmpPresets)
                    TextButton(
                      onPressed: () => setState(() => rules['${t['key']}']!
                        ..clear()
                        ..addAll(p.$2)),
                      child: Text(p.$1),
                    ),
                ]),
              ]),
            ),
        ])),
        bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: FilledButton(key: const Key('cr-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save')))),
      );
}
