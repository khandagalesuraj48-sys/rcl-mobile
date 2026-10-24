/* VENDOR BOQ – the app's own screens (3.4.0), the same as the web's BOQ page: rate contracts vendor-wise for a period; "Amend"
 * changes a rate from a date (bills take the newest rate in force on each date).
 *   – the list (vendor, All BOQs / Machinery without a BOQ on a date), each BOQ with its period, version and lines; Print, Edit,
 *     Make amendment, Delete; "Make BOQ" for machinery without one;
 *   – the form: vendor, BOQ No (blank = next), Valid From / To, Work Order No / Date, GST % (a GST-registered vendor), TDS %,
 *     Remark; the vendor's machinery to tick (one already in another BOQ of the vendor for these dates cannot be); each line: rent
 *     type (Monthly, Per Day, Per Hour – with hour slabs –, Per KM, Per Trip – a Night trip rate –, Item-wise – items with their own
 *     rates –, No rent – diesel only), rate, diesel (company / all debited), remark; "same terms → other machinery";
 *   – Rate check: the BOQ rate in force for a machinery on a date.
 * Server: getBoqs, saveBoq, deleteBoq, boqMissing, boqRateCheck. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as mat show Text;
import 'package:flutter/services.dart';

import '../core/assets.dart' show dayBefore, noKey;
import '../core/format.dart';
import '../core/masters.dart';
import '../core/rdoc.dart' show RDoc, RTable, RRow, RCell, RNote;
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/help.dart' show GuideButton;
import '../ui/ask_bot.dart';

Future<void> openBoq(BuildContext context, {String vendor = '', bool newIfNone = false}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BoqScreen(vendor: vendor, newIfNone: newIfNone)));

List<Map<String, dynamic>> _maps(dynamic l) => [for (final x in (l as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];

class BoqScreen extends StatefulWidget {
  const BoqScreen({super.key, this.vendor = '', this.newIfNone = false});
  final String vendor;
  final bool newIfNone;
  @override
  State<BoqScreen> createState() => _BoqScreenState();
}

class _BoqScreenState extends State<BoqScreen> {
  List<Map<String, dynamic>> vendors = [], boqs = [], hist = []; // (3.23.0) hist: the rate history machinery-wise (Mechanical update-132)
  Map<String, dynamic>? missing;
  bool loading = true, showMissing = false;
  String err = '', vendor = '', asOn = '';
  // rate check
  String rcNo = '', rcDate = '', rcOut = '';

  @override
  void initState() {
    super.initState();
    vendor = widget.vendor;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      if (!mounted || !widget.newIfNone || vendor.isEmpty) return;
      if (!boqs.any((b) => b['vendor'] == vendor) && SessionScope.read(context).canEdit('Vendor BOQ')) await _form('new'); // no BOQ yet → the form opens for this vendor
    });
  }

  Future<void> _load({bool quiet = false}) async {
    final s = SessionScope.read(context);
    if (!quiet) setState(() => loading = true);
    try {
      final d = (await s.api.call('getBoqs', [<String, dynamic>{}]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        vendors = _maps(d['vendors']);
        boqs = _maps(d['boqs']);
        hist = _maps(d['history']);
        loading = false;
        err = '';
        if (vendor.isNotEmpty && !vendors.any((v) => v['name'] == vendor)) vendor = '';
      });
      if (showMissing) await _loadMissing();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  Future<void> _loadMissing() async {
    final s = SessionScope.read(context);
    try {
      final d = (await s.api.call('boqMissing', [{'date': asOn.isEmpty ? s.today : asOn}]) as Map).cast<String, dynamic>();
      if (mounted) setState(() => missing = d);
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  String _noOf(String id) {
    for (final x in boqs) {
      if (x['id'] == id) return 'BOQ ${x['no']}';
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final can = s.canEdit('Vendor BOQ');
    final list = boqs.where((b) => vendor.isEmpty || b['vendor'] == vendor).toList();
    final miss = _maps(missing?['rows']).where((x) => vendor.isEmpty || x['vendor'] == vendor).toList();
    return Scaffold(
      appBar: AppBar(
        title: const TwoLang('Vendor BOQ', 'व्हेंडर BOQ', size: 20, weight: FontWeight.w700),
        actions: withAsk([const GuideButton('boq'), 
          if (can) IconButton(key: const Key('b-new'), tooltip: tr('+ New BOQ'), onPressed: () => _form('new'), icon: const Icon(Icons.post_add_rounded)),
          IconButton(tooltip: tr('Refresh'), onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ]),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Text('Vendor-wise, for a period. Change a rate with "Amend" – bills take the newest rate in force on each date.', style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
          const SizedBox(height: 10),
          PickField(key: const Key('bf-vendor'), label: 'Vendor', value: vendor, items: [for (final v in vendors) '${v['name']}'], blank: 'All vendors', onChanged: (v) => setState(() => vendor = v)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: PickField(
                key: const Key('bf-show'),
                label: 'Show',
                value: showMissing ? 'Machinery without a BOQ' : 'All BOQs',
                items: const ['All BOQs', 'Machinery without a BOQ'],
                onChanged: (v) {
                  setState(() => showMissing = v != 'All BOQs');
                  if (showMissing) _loadMissing();
                },
              ),
            ),
            if (showMissing) ...[
              const SizedBox(width: 8),
              Expanded(
                child: DateField(key: const Key('bf-date'), label: 'As on', value: asOn.isEmpty ? s.today : asOn, clear: false, onChanged: (v) {
                  setState(() => asOn = v);
                  _loadMissing();
                }),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Text(
            showMissing ? 'Without a BOQ on ${showDate('${missing?['date'] ?? s.today}')}: ${miss.length}' : 'BOQs: ${list.where((b) => '${b['amendOf'] ?? ''}'.isEmpty).length} · amendments: ${list.where((b) => '${b['amendOf'] ?? ''}'.isNotEmpty).length}',
            key: const Key('bf-sum'),
            style: const TextStyle(fontSize: 13, color: C.muted),
          ),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 10),
          if (loading && boqs.isEmpty)
            ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: Shimmer(height: 130)))
          else if (showMissing) ...[
            if (miss.isEmpty) EmptyState('Every Rental / Hired / Debit machinery has a BOQ on this date.', '', pic: 'shield'),
            for (final (i, x) in miss.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  key: Key('bm-${x['no']}'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${i + 1}. ${x['no']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text([x['type'], x['ownership']].where((y) => '${y ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 13, color: C.muted)),
                        Text('${x['vendor'] ?? ''}'.isEmpty ? 'No vendor' : '${x['vendor']}${x['vendorSaved'] == true ? '' : ' (not in Vendor Master)'}', style: TextStyle(fontSize: 13.5, color: '${x['vendor'] ?? ''}'.isEmpty ? C.red : C.ink, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    if (can && x['vendorSaved'] == true)
                      TextButton(
                        key: Key('bmk-${x['no']}'),
                        onPressed: () async {
                          setState(() => vendor = '${x['vendor']}');
                          await _form('new');
                        },
                        child: Text('Make BOQ'),
                      ),
                  ]),
                ),
              ),
          ] else if (list.isEmpty)
            EmptyState('No BOQ yet${vendor.isNotEmpty ? ' for $vendor' : ''} – press "+ New BOQ" (or "Make BOQ" in the vendor list).', '', pic: 'clipboard')
          else
            for (final b in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(b, can)),
          if (!showMissing && !loading) ..._history(),
          const SizedBox(height: 14),
          _rateCheck(s),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> b, bool can) {
    final amend = '${b['amendOf'] ?? ''}'.isNotEmpty, id = '${b['id']}';
    return Container(
      key: Key('boq-$id'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: amend ? const Color(0xFFFCFBF6) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line), boxShadow: softShadow(.04)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${amend ? '↳ ' : ''}BOQ ${b['no']}', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800))),
          Pill(amend ? 'Amendment ${b['amendNo']}' : 'Original', color: amend ? C.amber : C.greenDark, bg: amend ? C.amberSoft : C.greenSoft),
        ]),
        Text('$id${amend ? ' · of ${_noOf('${b['amendOf']}')}' : ''}', style: const TextStyle(fontSize: 12.5, color: C.faint)),
        const SizedBox(height: 4),
        Text('${b['vendor']}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        Text('${showDate('${b['from']}')} – ${'${b['to'] ?? ''}'.isEmpty ? 'open' : showDate('${b['to']}')}', style: const TextStyle(fontSize: 13.5, color: C.muted)),
        const SizedBox(height: 8),
        for (final l in _maps(b['lines']))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: mat.Text.rich(
              TextSpan(children: [
                TextSpan(text: '${l['no']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: ' – ${boqLineText(l)}'),
                TextSpan(text: ' · ${boqDieselText(l)}', style: const TextStyle(color: C.muted, fontSize: 12.5)),
              ]),
              style: const TextStyle(fontSize: 13.5, height: 1.3, color: C.ink),
            ),
          ),
        Text('${'${b['gstPct'] ?? ''}'.isNotEmpty ? 'GST ${fmtNum(asNum(b['gstPct']))}%' : 'No GST'} · ${'${b['tdsPct'] ?? ''}'.isNotEmpty ? 'TDS ${fmtNum(asNum(b['tdsPct']))}%' : 'No TDS'}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        if ('${b['enteredBy'] ?? ''}'.isNotEmpty) Text('Entered by ${b['enteredBy']}${'${b['updatedBy'] ?? ''}'.isNotEmpty && b['updatedBy'] != b['enteredBy'] ? ' · edited: ${b['updatedBy']}' : ''}', style: const TextStyle(fontSize: 12, color: C.faint)),
        const SizedBox(height: 6),
        Wrap(spacing: 2, children: [
          TextButton.icon(key: Key('bp-$id'), onPressed: () => _print(b), icon: const Icon(Icons.print_rounded, size: 18), label: Text('Print')),
          if (can) TextButton.icon(key: Key('be-$id'), onPressed: () => _form('edit', b), icon: const Icon(Icons.edit_rounded, size: 18), label: Text('Edit')),
          if (can && !amend) TextButton.icon(key: Key('ba-$id'), onPressed: () => _form('amend', b), icon: const Icon(Icons.call_split_rounded, size: 18), label: Text('Make amendment')),
          if (can) TextButton.icon(key: Key('bd-$id'), style: TextButton.styleFrom(foregroundColor: C.red), onPressed: () => _delete(b), icon: const Icon(Icons.delete_outline_rounded, size: 18), label: Text('Delete')),
        ]),
      ]),
    );
  }

  /* (3.23.0, Mechanical update-132: "mala disayla haw old kay hot nantr amendment zali kadhi … boq period wise ani vehicle wise")
   * THE RATE HISTORY of the vendor's machinery – period by period, as the bills take it (Mechanical boqHistory_): from – to, the rate,
   * which BOQ / amendment gave it, and what changed. */
  List<Widget> _history() {
    if (vendor.isEmpty) {
      return [Padding(padding: const EdgeInsets.only(top: 4), child: Text('Pick a vendor to see the rate history of each machinery – which rate from which date, and which amendment changed it.', key: const Key('bh-pick'), style: const TextStyle(fontSize: 13, color: C.muted)))];
    }
    final list = hist.where((h) => h['vendor'] == vendor).toList();
    if (list.isEmpty) return const [];
    String txt(Map<String, dynamic> l) => '${boqLineText(l)} · ${boqDieselText(l)}';
    return [
      const SizedBox(height: 8),
      Text('Rate history – machinery-wise', key: const Key('bh-head'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(tr('Each machinery of {0}: which rate from which date to which date, and which BOQ or amendment gave it. The old rate ends the day before an amendment starts. Bills take exactly these rates.').replaceFirst('{0}', vendor),
          style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
      const SizedBox(height: 8),
      for (final h in list)
        Container(
          key: Key('bh-${h['no']}'),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${h['no']}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            for (final (i, p) in _maps(h['periods']).indexed)
              () {
                final none = p['none'] == true, amendNo = (asNum(p['amendNo']) ?? 0).toInt();
                final prev = _maps(h['periods']).take(i).toList().reversed.firstWhere((x) => x['none'] != true, orElse: () => <String, dynamic>{});
                final line = none ? <String, dynamic>{} : (p['line'] as Map).cast<String, dynamic>();
                final prevLine = prev.isEmpty ? <String, dynamic>{} : (prev['line'] as Map).cast<String, dynamic>();
                final changed = !none && prev.isNotEmpty && txt(prevLine) != txt(line);
                final chg = none ? '' : prev.isEmpty ? 'First rate' : changed ? tr('Changed – was {0}').replaceFirst('{0}', boqLineText(prevLine)) : 'Same rate';
                return Container(
                  key: Key('bh-${h['no']}-$i'),
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(color: none ? C.bg : amendNo > 0 ? C.amberSoft : C.greenSoft.withValues(alpha: .5), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${showDate('${p['from']}')} – ${'${p['to'] ?? ''}'.isEmpty ? tr('open') : showDate('${p['to']}')}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    if (none)
                      Text('No BOQ – no rate', style: const TextStyle(fontSize: 13.5, color: C.muted))
                    else ...[
                      Text(txt(line), style: const TextStyle(fontSize: 13.5)),
                      Text('${amendNo > 0 ? tr('Amendment {0} of BOQ {1}').replaceFirst('{0}', '$amendNo').replaceFirst('{1}', '${p['of']}') : tr('BOQ {0} – Original').replaceFirst('{0}', '${p['boqNo']}')}${'${p['woNo'] ?? ''}'.isNotEmpty ? ' · WO ${p['woNo']}' : ''}',
                          style: const TextStyle(fontSize: 12.5, color: C.muted)),
                      Text(chg, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: changed ? C.amber : C.greenDark)),
                    ],
                  ]),
                );
              }(),
          ]),
        ),
    ];
  }

  Widget _rateCheck(Session s) {
    final ids = {for (final v in vendors) for (final m in machinesOfVendor(v)) '${m['id']}'}.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Rate check', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Text('Which BOQ rate is in force for a machinery on a date', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        const SizedBox(height: 10),
        Press(
          key: const Key('rc-no'),
          radius: 16,
          shadow: false,
          padding: const EdgeInsets.all(14),
          onTap: () async {
            final v = await pickFromList(context, 'Machinery', ids);
            if (v != null) setState(() => rcNo = v);
          },
          child: Row(children: [const Icon(Icons.precision_manufacturing_outlined, color: C.blue, size: 18), const SizedBox(width: 8), Expanded(child: Text(rcNo.isEmpty ? 'Type or pick' : rcNo, style: TextStyle(fontWeight: FontWeight.w700, color: rcNo.isEmpty ? C.faint : C.ink)))]),
        ),
        const SizedBox(height: 8),
        DateField(key: const Key('rc-date'), label: 'Date', value: rcDate.isEmpty ? s.today : rcDate, clear: false, onChanged: (v) => setState(() => rcDate = v)),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('rc-go'),
          onPressed: rcNo.isEmpty
              ? null
              : () async {
                  try {
                    final r = (await s.api.call('boqRateCheck', [{'no': rcNo, 'date': rcDate.isEmpty ? s.today : rcDate}]) as Map).cast<String, dynamic>();
                    final hit = r['hit'] is Map ? (r['hit'] as Map).cast<String, dynamic>() : null;
                    setState(() => rcOut = hit != null
                        ? '${r['no']} (${r['vendor']}) on ${showDate('${r['date']}')}: ${boqLineText(((hit['line'] as Map?) ?? const {}).cast<String, dynamic>())} – from BOQ ${hit['boqNo']}${(asNum(hit['amendNo']) ?? 0) > 0 ? ' (amendment ${hit['amendNo']})' : ''}, valid ${showDate('${hit['from']}')} – ${'${hit['to'] ?? ''}'.isEmpty ? 'open' : showDate('${hit['to']}')}'
                        : 'No BOQ rate for ${r['no']} on ${showDate('${r['date']}')}.');
                  } catch (e) {
                    if (mounted) toast(context, tr(errText(e)), bad: true);
                  }
                },
          child: Text('Check'),
        ),
        if (rcOut.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(rcOut, key: const Key('rc-out'), style: const TextStyle(fontSize: 14, height: 1.35))),
      ]),
    );
  }

  Future<void> _form(String mode, [Map<String, dynamic>? b]) async {
    final s = SessionScope.read(context);
    final saved = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => BoqFormScreen(mode: mode, rec: b, vendors: vendors, boqs: boqs, vendor: vendor, today: s.today)));
    if (saved != null && mounted) {
      setState(() => vendor = saved);
      await _load(quiet: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> b) async {
    final s = SessionScope.read(context);
    final amend = '${b['amendOf'] ?? ''}'.isNotEmpty;
    if (!await ask(context, 'Delete ${b['id']}${amend ? ' (amendment ${b['amendNo']})' : ''}?', '${b['vendor']} – ${showDate('${b['from']}')} to ${'${b['to'] ?? ''}'.isEmpty ? 'open' : showDate('${b['to']}')}', yes: 'Delete', danger: true)) return;
    try {
      await s.api.call('deleteBoq', ['${b['id']}', '${b['ver'] ?? ''}'], true); // (update-156) the version shown
      if (!mounted) return;
      toast(context, '${b['id']} deleted.');
      await _load(quiet: true);
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  Future<void> _print(Map<String, dynamic> b) async {
    final s = SessionScope.read(context);
    await printDoc(context, s, boqDoc(b, vendors, boqs, hist: hist));
  }
}

/// The BOQ as the web prints it: the vendor's facts, the rates, the remark, all versions; signed by the vendor, billing, PM.
/// (3.24.0, Mechanical update-133, asked 19-10-2026 with his "Amendment letter Of Intent" picture: "je boq bantat je amendment bante
/// tya warti work order number date he sagle yeu de … proper amendment watayla haw") the work order number and date on top; an
/// amendment prints as an amendment letter: To the vendor, Subject, Reference (the work order), with effect from, Annexure-I – each
/// machinery's earlier rate ([hist]: the rate history, the bills' own rule) and its new rate –, the vendor's details, all versions,
/// "For and on behalf of …", accepted by the vendor.
RDoc boqDoc(Map<String, dynamic> b, List<Map<String, dynamic>> vendors, List<Map<String, dynamic>> boqs, {List<Map<String, dynamic>> hist = const []}) {
  final v = vendors.firstWhere((x) => x['name'] == b['vendor'], orElse: () => <String, dynamic>{});
  final amend = '${b['amendOf'] ?? ''}'.isNotEmpty;
  final root = amend ? boqs.firstWhere((x) => x['id'] == b['amendOf'], orElse: () => <String, dynamic>{}) : b;
  final rootId = '${root['id'] ?? b['id']}';
  final versions = boqs.where((x) => x['id'] == rootId || x['amendOf'] == rootId).toList()..sort((x, y) => ((asNum(x['amendNo']) ?? 0) - (asNum(y['amendNo']) ?? 0)).toInt());
  String p(dynamic x) => '${x ?? ''}';
  final no = p(b['no']).isEmpty ? p(b['id']) : p(b['no']);
  final rootNo = amend ? (p(root['no']).isNotEmpty ? p(root['no']) : p(b['amendOf'])) : no;
  final wo = p(b['woNo']).isNotEmpty || p(b['woDate']).isNotEmpty ? b : root;      // an amendment without its own: the work order of its BOQ
  final woNo = p(wo['woNo']), woDate = p(wo['woDate']);
  final woBits = [if (woNo.isNotEmpty) 'Work Order No: $woNo', if (woDate.isNotEmpty) 'Work Order Date: ${showDate(woDate)}'];
  final facts = <(String, String)>[
    ('Vendor', p(v['name']).isNotEmpty ? p(v['name']) : p(b['vendor'])), ('GST Number', v['gstReg'] == 'Yes' ? p(v['gst']) : 'Not registered'), ('PAN', p(v['pan'])),
    ('GST % (this BOQ)', p(b['gstPct']).isNotEmpty ? '${fmtNum(asNum(b['gstPct']))}%' : ''), ('TDS % (this BOQ)', p(b['tdsPct']).isNotEmpty ? '${fmtNum(asNum(b['tdsPct']))}%' : ''),
    ('Bank', [v['bank'], v['branch']].where((x) => p(x).isNotEmpty).join(', ')), ('Account No', p(v['account'])), ('IFSC', p(v['ifsc'])), ('Address', p(v['address'])), ('Phone', p(v['phone'])),
  ].where((x) => x.$2.isNotEmpty && !(amend && const ['Vendor', 'Address', 'Phone'].contains(x.$1))).toList();
  const per = {'Monthly': 'per month', 'Per Day': 'per day', 'Per Hour': 'per hour', 'Per KM': 'per km', 'Per Trip': 'per trip'};
  String rate(Map<String, dynamic> l) {
    final items = _maps(l['items']);
    if (items.isNotEmpty) return items.map((it) => '${it['name']} – ${boqRateText(it)}').join('\n');
    if (_maps(l['slabs']).isNotEmpty) return boqLineText(l);
    return '${rupees(l['rate'])} ${per[l['basis']] ?? ''}${(asNum(l['nightRate']) ?? 0) > 0 ? ' (Night trip ${rupees(l['nightRate'])})' : ''}';
  }

  String diesel(Map<String, dynamic> l) => l['diesel'] == 'Debit Basis' ? 'Debit basis' : 'Company paid';
  final lines = _maps(b['lines']);
  final versionsBlock = [
    if (versions.length > 1) ...[
      const RNote('All versions of this BOQ', heading: true),
      RTable(sheet: 'Versions', head: const ['BOQ ID', 'Version', 'From', 'To', 'Rates'], rows: [
        for (final x in versions)
          RRow([RCell(p(x['id'])), RCell(p(x['amendOf']).isNotEmpty ? 'Amendment ${x['amendNo']}' : 'Original'), RCell(showDate(p(x['from']))), RCell(p(x['to']).isEmpty ? 'open' : showDate(p(x['to']))), RCell(_maps(x['lines']).map((l) => '${l['no']}: ${boqLineText(l)}').join('\n'))]),
      ]),
    ],
  ];
  if (!amend) {
    return RDoc(
      title: 'BOQ / Rate Contract – BOQ $no',
      file: 'BOQ_${b['id']}',
      period: '${showDate(p(b['from']))} to ${p(b['to']).isEmpty ? 'open' : showDate(p(b['to']))}',
      meta: ['BOQ ID: ${b['id']}', ...woBits].join(' · '),
      kpis: facts,
      signs: const [('VENDOR', 'SIGN & STAMP'), ('PREPARED BY', 'BILLING DEPT'), ('APPROVED BY', 'PROJECT MANAGER')],
      blocks: [
        const RNote('Rates', heading: true),
        RTable(sheet: 'Rates', head: const ['Sr', 'Machinery', 'Type', 'Rent type', 'Rate', 'Diesel', 'Remark'], numCols: const {0}, rows: [
          for (final (i, l) in lines.indexed)
            RRow([RCell('${i + 1}', n: true, value: i + 1), RCell(p(l['no']), bold: true), RCell(p(l['type'])), RCell(p(l['basis'])), RCell(rate(l)), RCell(diesel(l)), RCell(p(l['remark']))]),
        ]),
        if (p(b['remark']).isNotEmpty) RNote('Remark: ${b['remark']}'),
        ...versionsBlock,
      ],
    );
  }
  // THE AMENDMENT LETTER
  final from = p(b['from']), to = p(b['to']), many = lines.length > 1, s = many ? 's' : '';
  final types = <String, int>{};
  for (final l in lines) {
    final t = p(l['type']).isEmpty ? 'machinery' : p(l['type']);
    types[t] = (types[t] ?? 0) + 1;
  }
  final what = types.entries.map((e) => '${'${e.value}'.padLeft(2, '0')} Nos ${e.key}').join(', ');
  // each machinery's earlier rate: its last period before this amendment in the rate history
  final hv = hist.where((h) => h['vendor'] == b['vendor']).toList();
  (Map<String, dynamic>, String)? earlier(Map<String, dynamic> l) {
    final h = hv.firstWhere((x) => noKey(p(x['no'])) == noKey(p(l['no'])), orElse: () => <String, dynamic>{});
    final ps = _maps(h['periods']).where((x) => x['none'] != true && p(x['from']).compareTo(from) < 0).toList();
    if (ps.isEmpty || ps.last['line'] is! Map) return null;
    final pt = p(ps.last['to']);
    return ((ps.last['line'] as Map).cast<String, dynamic>(), pt.isNotEmpty && pt.compareTo(from) < 0 ? pt : dayBefore(from));
  }

  String earlierText(Map<String, dynamic> l) {
    final e = earlier(l);
    if (e == null) return '–';
    return '${rate(e.$1)}${e.$1['diesel'] != l['diesel'] ? ' · ${diesel(e.$1)}' : ''}\ntill ${showDate(e.$2)}';
  }

  final woRef = woNo.isNotEmpty ? 'Work Order No. $woNo${woDate.isNotEmpty ? ' dated ${showDate(woDate)}' : ''}; ' : woDate.isNotEmpty ? 'Work Order dated ${showDate(woDate)}; ' : '';
  final rootRef = 'BOQ $rootNo${p(root['id']).isNotEmpty ? ' (${root['id']}) from ${showDate(p(root['from']))}${p(root['to']).isNotEmpty ? ' to ${showDate(p(root['to']))}' : ''}' : ''}.';
  return RDoc(
    title: 'Amendment Letter – Amendment ${b['amendNo']} of BOQ $rootNo',
    file: 'BOQ_${b['id']}',
    meta: ['BOQ ID: ${b['id']} (BOQ $no)', ...woBits, 'With effect from: ${showDate(from)}${to.isNotEmpty ? ' to ${showDate(to)}' : ''}'].join(' · '),
    signs: const [('ACCEPTED BY VENDOR', 'SIGN & STAMP'), ('PREPARED BY', 'BILLING DEPT'), ('APPROVED BY', 'PROJECT MANAGER')],
    onBehalf: true,
    blocks: [
      RNote(['To,', p(v['name']).isNotEmpty ? p(v['name']) : p(b['vendor']), if (p(v['address']).isNotEmpty) p(v['address']), if (p(v['phone']).isNotEmpty) 'Contact No. ${v['phone']}'].join('\n'), letter: true),
      RNote('Subject: Amendment ${b['amendNo']} of BOQ $rootNo – change of rate$s for $what.', letter: true),
      RNote('Reference: $woRef$rootRef', letter: true),
      RNote('Dear Sir,\nWith reference to the above ${woNo.isNotEmpty || woDate.isNotEmpty ? 'work order' : 'BOQ'}, we are changing the rate$s of the machinery given below (Annexure-I) with effect from ${showDate(from)}${to.isNotEmpty ? ' to ${showDate(to)}' : ''}. '
          'The other machinery of BOQ $rootNo and all other terms and conditions remain the same.', letter: true),
      RNote('Annexure-I – BOQ (amended rate$s)', heading: true),
      RTable(sheet: 'Annexure-I', head: ['Sr', 'Machinery', 'Type', 'Rent type', 'Earlier rate', 'New rate from ${showDate(from)}', 'Diesel', 'Remark'], numCols: const {0}, rows: [
        for (final (i, l) in lines.indexed)
          RRow([
            RCell('${i + 1}', n: true, value: i + 1), RCell(p(l['no']), bold: true), RCell(p(l['type'])), RCell(p(l['basis'])),
            RCell(earlierText(l)),
            RCell(rate(l), bold: true), RCell(diesel(l)), RCell(p(l['remark'])),
          ]),
      ]),
      if (p(b['remark']).isNotEmpty) RNote('Remark: ${b['remark']}'),
      if (facts.isNotEmpty) ...[
        const RNote('Vendor details', heading: true),
        RTable(sheet: 'Vendor', head: [for (final f in facts) f.$1], rows: [RRow([for (final f in facts) RCell(f.$2, bold: true)])]),
      ],
      ...versionsBlock,
    ],
  );
}

/* ================= THE BOQ FORM ================= */
class BoqFormScreen extends StatefulWidget {
  const BoqFormScreen({super.key, required this.mode, this.rec, required this.vendors, required this.boqs, this.vendor = '', required this.today});
  final String mode; // new · edit · amend
  final Map<String, dynamic>? rec;
  final List<Map<String, dynamic>> vendors, boqs;
  final String vendor, today;
  @override
  State<BoqFormScreen> createState() => _BoqFormScreenState();
}

class _BoqFormScreenState extends State<BoqFormScreen> {
  String vendor = '', from = '', to = '', woDate = '';
  final no = TextEditingController(), wo = TextEditingController(), gst = TextEditingController(), tds = TextEditingController(), remark = TextEditingController();
  final lines = <BoqLine>[];
  bool busy = false;
  String err = '';
  Map<String, dynamic>? get b => widget.rec;
  String get mode => widget.mode;

  @override
  void initState() {
    super.initState();
    final t = widget.today;
    if (mode == 'new') {
      vendor = widget.vendors.any((v) => v['name'] == widget.vendor) ? widget.vendor : '';
      no.text = vendor.isEmpty ? '' : boqNextNo(widget.boqs, vendor);
      from = '${t.substring(0, 8)}01';
      final v = _v;
      gst.text = v['gstReg'] == 'Yes' ? ('${v['gstPct'] ?? ''}'.isNotEmpty ? '${v['gstPct']}' : '18') : '';
      tds.text = '${v['tds'] ?? ''}';
    } else {
      final r = b!;
      vendor = '${r['vendor']}';
      no.text = mode == 'amend' ? boqNextNo(widget.boqs, vendor) : '${r['no'] ?? ''}';
      remark.text = mode == 'amend' ? '' : '${r['remark'] ?? ''}';
      if (mode == 'amend') {      // (3.23.0, Mechanical update-132) from any date on or after the BOQ start – also after its end
        final rf = '${r['from']}', rt = '${r['to'] ?? ''}';
        from = t.compareTo(rf) > 0 ? t : rf;
        to = rt.isNotEmpty && rt.compareTo(from) >= 0 ? rt : '';
      } else {
        from = '${r['from']}';
        to = '${r['to'] ?? ''}';
      }
      lines.addAll([for (final l in _maps(r['lines'])) BoqLine.of(l)..tidy()]);
      gst.text = '${r['gstPct'] ?? ''}';
      tds.text = '${r['tdsPct'] ?? ''}';
      wo.text = '${r['woNo'] ?? ''}';
      woDate = '${r['woDate'] ?? ''}';
    }
    if (lines.isEmpty && vendor.isNotEmpty && mode != 'new') lines.add(BoqLine());
  }

  @override
  void dispose() {
    for (final c in [no, wo, gst, tds, remark]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _v => widget.vendors.firstWhere((x) => x['name'] == vendor, orElse: () => <String, dynamic>{});
  List<Map<String, dynamic>> get _machines => vendor.isEmpty ? const [] : machinesOfVendor(_v);
  Map<String, Map<String, dynamic>> get _taken => boqTaken(widget.boqs, vendor: vendor, from: from.isEmpty ? widget.today : from, to: to, mode: mode, editId: '${b?['id'] ?? ''}');

  String get _title {
    if (mode == 'new') return 'New BOQ';
    final r = b!;
    if (mode == 'amend') {
      final next = widget.boqs.where((x) => x['amendOf'] == r['id']).fold<int>(0, (m, x) => (asNum(x['amendNo']) ?? 0).toInt() > m ? (asNum(x['amendNo']) ?? 0).toInt() : m) + 1;
      return 'Amendment $next of BOQ ${r['no']} – ${r['vendor']} (saves as BOQ ${boqNextNo(widget.boqs, vendor)})';
    }
    final root = '${r['amendOf'] ?? ''}'.isNotEmpty ? widget.boqs.firstWhere((x) => x['id'] == r['amendOf'], orElse: () => <String, dynamic>{}) : null;
    return 'Edit BOQ ${r['no']}${root != null ? ' (amendment ${r['amendNo']} of BOQ ${root['no'] ?? r['amendOf']})' : ''} – ${r['vendor']}';
  }

  void _vendorChanged(String v) {
    setState(() {
      vendor = v;
      no.text = v.isEmpty ? '' : boqNextNo(widget.boqs, v);
      gst.text = _v['gstReg'] == 'Yes' ? '18' : '';
      tds.text = '${_v['tds'] ?? ''}';
      lines.clear();
    });
  }

  // the dates changed: machinery already in a BOQ for the new dates is taken out
  void _datesChanged() {
    final tk = _taken, out = <String>[];
    lines.removeWhere((l) {
      if (l.no.isNotEmpty && tk[l.no] != null) {
        out.add('${l.no} (in BOQ ${tk[l.no]!['no'] ?? tk[l.no]!['id']})');
        return true;
      }
      return false;
    });
    setState(() {});
    if (out.isNotEmpty) toast(context, '${out.join(', ')} – taken out: already in a BOQ for these dates.');
  }

  void _tick(String id, bool on) => setState(() => on ? lines.add(BoqLine(no: id)) : lines.removeWhere((l) => l.no == id));

  void _addAll() {
    final have = lines.map((l) => l.no).toSet(), tk = _taken;
    final add = _machines.where((m) => !have.contains(m['id']) && tk[m['id']] == null), skip = _machines.where((m) => !have.contains(m['id']) && tk[m['id']] != null).toList();
    setState(() => lines.addAll([for (final m in add) BoqLine(no: '${m['id']}')]));
    if (skip.isNotEmpty) toast(context, '${skip.map((m) => '${m['id']} (already in BOQ ${tk[m['id']]!['no'] ?? tk[m['id']]!['id']})').join(', ')} – not added.');
  }

  Future<void> _same(BoqLine src) async {
    if (src.no.isEmpty) {
      toast(context, 'Pick the machinery of this line first.', bad: true);
      return;
    }
    final tk = _taken, have = lines.map((l) => l.no).toSet();
    final others = _machines.where((m) => m['id'] != src.no && tk[m['id']] == null).toList();
    if (others.isEmpty) {
      toast(context, 'There is no other machinery of $vendor free for these dates.', bad: true);
      return;
    }
    final picked = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('Same terms as ${src.no}'),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Terms of ${src.no}: ${src.termsText}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tick the machinery that run on the same terms:'),
            for (final m in others)
              CheckboxListTile(
                key: Key('same-${m['id']}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: picked.contains(m['id']),
                onChanged: (v) => set(() => v == true ? picked.add('${m['id']}') : picked.remove(m['id'])),
                title: Text('${m['id']}'),
                subtitle: Text('${m['type'] ?? ''}${have.contains(m['id']) ? ' · already a line – its terms will be replaced' : ''}'),
              ),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => set(() => picked.addAll(others.map((m) => '${m['id']}'))), child: Text('Tick all'))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(key: const Key('same-ok'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c, true), child: Text('Apply')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (picked.isEmpty) {
      toast(context, 'Nothing was ticked.', bad: true);
      return;
    }
    setState(() {
      for (final id in picked) {
        final i = lines.indexWhere((l) => l.no == id);
        if (i > -1) {
          lines[i] = src.sameFor(id);
        } else {
          lines.add(src.sameFor(id));
        }
      }
    });
    toast(context, '${picked.length} machinery now have the terms of ${src.no} – check and Save BOQ.');
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    final used = lines.where((l) => !l.empty).toList();
    final noMach = [for (final (k, l) in lines.indexed) if (l.no.isEmpty && used.isNotEmpty) k + 1];
    if (noMach.isNotEmpty && noMach.length < lines.length) {
      setState(() => err = 'Pick the machinery in line ${noMach.join(', ')} (or remove that line).');
      return;
    }
    // a machinery already in another BOQ of this vendor for these dates: say which, and offer to leave it out
    final tk = _taken;
    final dup = [for (final (k, l) in used.indexed) if (l.no.isNotEmpty && tk[l.no] != null && used.indexWhere((y) => y.no == l.no) == k) l];
    if (dup.isNotEmpty) {
      String d(dynamic x) => '${x ?? ''}'.isEmpty ? 'open' : showDate('$x');
      final allDup = used.every((l) => l.no.isEmpty || tk[l.no] != null);
      final msg = [for (final l in dup) '${l.no} is already in BOQ ${tk[l.no]!['no'] ?? tk[l.no]!['id']} (${d(tk[l.no]!['from'])} to ${d(tk[l.no]!['to'])})'];
      if (allDup) {
        await tellLines(context, 'Already in another BOQ', [...msg, 'Every machinery here is already in a BOQ. To change a rate, open that BOQ and use Amend.']);
        return;
      }
      if (!mounted) return;
      if (!await askLines(context, 'Already in another BOQ', msg, note: 'A machinery can be in only one BOQ of a vendor for the same dates (otherwise it would be billed twice). "Leave them out and save" saves this BOQ with the other machinery only. To change their rate, use Amend on that BOQ.', yes: 'Leave them out and save')) return;
      setState(() => lines.removeWhere((l) => tk[l.no] != null));
      used.removeWhere((l) => tk[l.no] != null);
    }
    final body = <String, dynamic>{
      'vendor': vendor, 'no': no.text.trim(), 'from': from, 'to': to, 'remark': remark.text.trim(), 'lines': [for (final l in used) l.toJson()],
      'gstPct': gst.text.trim(), 'tdsPct': tds.text.trim(), 'woNo': wo.text.trim(), 'woDate': woDate,
    };
    setState(() {
      busy = true;
      err = '';
    });
    try {
      Map<String, dynamic> res;
      if (mode == 'edit') {
        body['ver'] = '${b!['ver'] ?? ''}'; // (update-156) the version it had when it was opened
        res = (await s.api.call('saveBoq', [body, 'edit', '${b!['id']}'], true) as Map).cast<String, dynamic>();
      } else {
        if (mode == 'amend') body['amendOf'] = b!['id'];
        res = (await s.api.call('saveBoq', [body, 'add'], true) as Map).cast<String, dynamic>();
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();
      toast(context, mode == 'amend' ? 'Saved as BOQ ${res['no']} – amendment ${res['amendNo']} of BOQ ${b!['no']}' : 'BOQ ${res['no']} saved for $vendor');
      Navigator.of(context).pop(vendor);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _v, reg = v['gstReg'] == 'Yes', tk = _taken, ms = _machines;
    final have = lines.map((l) => l.no).toSet();
    Widget gap() => const SizedBox(height: 10);
    return Scaffold(
      appBar: AppBar(title: Text(_title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), actions: withAsk([const GuideButton('boq')])),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (mode == 'amend')
          Text(tr('Keep only the machinery whose rate changes, change its rate / rent type, and set "Valid From" = the date the new rate starts (on or after {0} – also after BOQ {1} ends: that machinery goes on at the new rate). Before that date the old rate stays; the other machinery of BOQ {2} stay as they are.').replaceFirst('{0}', showDate('${b!['from']}')).replaceFirst('{1}', '${b!['no']}').replaceFirst('{2}', '${b!['no']}'),
              style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
        if (mode == 'new' && widget.vendors.isEmpty) Text('Fill a vendor\'s details first (Vendors, above).', style: const TextStyle(color: C.red)),
        gap(),
        PickField(key: const Key('bq-vendor'), label: 'Vendor *', value: vendor, items: [for (final x in widget.vendors) '${x['name']}'], blank: 'Pick the vendor…', enabled: mode == 'new', onChanged: _vendorChanged),
        gap(),
        TextBox(key: const Key('bq-no'), label: 'BOQ No (vendor-wise)', controller: no, hint: 'blank = next number'),
        gap(),
        Row(children: [
          Expanded(child: DateField(key: const Key('bq-from'), label: 'Valid From *', value: from, onChanged: (x) {
            from = x;
            _datesChanged();
          })),
          const SizedBox(width: 8),
          Expanded(child: DateField(key: const Key('bq-to'), label: 'Valid To (blank = open)', value: to, onChanged: (x) {
            to = x;
            _datesChanged();
          })),
        ]),
        gap(),
        TextBox(key: const Key('bq-wo'), label: 'Work Order No', controller: wo, hint: 'e.g. SLI/VTR-Office/WO/2024-2025/47'),
        gap(),
        DateField(key: const Key('bq-wodate'), label: 'Work Order Date', value: woDate, onChanged: (x) => setState(() => woDate = x)),
        gap(),
        Row(children: [
          if (reg) ...[
            Expanded(child: TextBox(key: const Key('bq-gst'), label: 'GST % ${'${v['gst'] ?? ''}'.isNotEmpty ? '(${v['gst']})' : ''}', controller: gst, hint: '18', kb: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
          ],
          Expanded(child: TextBox(key: const Key('bq-tds'), label: 'TDS %', controller: tds, hint: 'e.g. 2', kb: const TextInputType.numberWithOptions(decimal: true))),
        ]),
        gap(),
        TextBox(key: const Key('bq-remark'), label: 'Remark', controller: remark),
        if (ms.isNotEmpty) ...[
          FormHead('Machinery of $vendor', sub: 'Tick the ones this BOQ is for (${ms.where((m) => have.contains(m['id'])).length} of ${ms.length} ticked)'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in ms)
              FilterChip(
                key: Key('bq-tick-${m['id']}'),
                selected: have.contains(m['id']),
                onSelected: tk[m['id']] != null ? null : (on) => _tick('${m['id']}', on),
                label: Text('${m['id']}${'${m['type'] ?? ''}'.isNotEmpty ? ' · ${m['type']}' : ''}${tk[m['id']] != null ? ' · in BOQ ${tk[m['id']]!['no'] ?? tk[m['id']]!['id']}' : ''}'),
              ),
          ]),
          Row(children: [
            TextButton(key: const Key('bq-all'), onPressed: _addAll, child: Text('Tick all')),
            TextButton(onPressed: () => setState(lines.clear), child: Text('None')),
          ]),
          if (ms.every((m) => tk[m['id']] != null)) Text('Every machinery of this vendor is already in a BOQ for these dates.', style: const TextStyle(color: C.muted)),
        ],
        const SizedBox(height: 6),
        for (final (i, l) in lines.indexed) Padding(padding: const EdgeInsets.only(bottom: 12), child: _line(i, l, ms, tk)),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            child: OutlinedButton.icon(
              key: const Key('bq-addline'),
              onPressed: () {
                if (vendor.isEmpty) {
                  toast(context, 'Pick the vendor first.', bad: true);
                  return;
                }
                setState(() => lines.add(BoqLine()));
              },
              icon: const Icon(Icons.add_rounded),
              label: Text('+ Add line'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(key: const Key('bq-addall'), onPressed: vendor.isEmpty ? null : _addAll, child: Text('Add all machinery of this vendor', textAlign: TextAlign.center)),
        ]),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 16),
        FilledButton(key: const Key('bq-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save BOQ')),
      ])),
    );
  }

  Widget _line(int i, BoqLine l, List<Map<String, dynamic>> ms, Map<String, Map<String, dynamic>> tk) {
    final free = ms.where((m) => tk[m['id']] == null || m['id'] == l.no).toList();
    final noRent = l.basis == 'No rent – diesel only', iw = l.basis == 'Item-wise';
    void up(void Function() f) => setState(() {
          f();
          l.tidy();
        });
    return Container(
      key: Key('bl-$i'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Line ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          IconButton(key: Key('bl-x-$i'), tooltip: tr('Remove line'), onPressed: () => setState(() => lines.removeAt(i)), icon: const Icon(Icons.close_rounded)),
        ]),
        PickField(
          key: Key('bl-no-$i'),
          label: 'Machinery',
          value: l.no,
          items: [for (final m in free) '${m['id']}'],
          blank: 'Pick…',
          onChanged: (x) => setState(() => l.no = x),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('bl-basis-$i-${l.basis}'),
          initialValue: l.basis,
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('Rent type')),
          items: [for (final x in kBoqBasis) DropdownMenuItem(value: x, child: Text(kBoqBasisWords[x] ?? x))],
          onChanged: (x) => up(() => l.basis = x ?? 'Monthly'),
        ),
        const SizedBox(height: 8),
        if (!iw && !noRent && l.slabs.isEmpty)
          _num(Key('bl-rate-$i'), 'Rate (₹)', l.rate, (x) => l.rate = x)
        else if (noRent)
          Text('No rent – all diesel given is debited.', style: const TextStyle(color: C.muted))
        else if (l.slabs.isNotEmpty)
          Text('Rate: see the hour slabs below.', style: const TextStyle(color: C.muted)),
        if (l.basis == 'Per Trip') ...[const SizedBox(height: 8), _num(Key('bl-night-$i'), 'Night trip ₹ (empty = the same rate as by day)', l.nightRate, (x) => l.nightRate = x)],
        if (l.basis == 'Per Hour') ...[
          const SizedBox(height: 6),
          _slabs(l.slabs, (on) => l.slabOn = on, l.slabOn, () => up(() {
                if (l.slabs.isEmpty) {
                  l.slabs.addAll([BoqSlab('1', l.rate), BoqSlab('', '')]);
                } else {
                  l.slabs.add(BoqSlab('', ''));
                }
              }), (k) => up(() {
                l.slabs.removeAt(k);
                if (l.slabs.length == 1) l.slabs.clear();
              }), 'bl-$i'),
        ],
        if (iw) ...[
          const SizedBox(height: 6),
          for (final (k, it) in l.items.indexed) _item(i, k, l, it),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('bl-additem-$i'),
              onPressed: () => up(() {
                final hasRest = l.items.any((it) => itemKind(it.basis) == 'hr' && it.qty == 'rest');
                l.items.add(BoqItem(qty: hasRest ? 'typed' : 'rest'));
              }),
              icon: const Icon(Icons.add_rounded),
              label: Text('+ add item'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('bl-diesel-$i-${l.diesel}-$noRent'),
          initialValue: l.diesel,
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('Diesel')),
          items: [
            DropdownMenuItem(value: 'Company', child: Text('Company diesel – only extra over standard debited', maxLines: 2)),
            DropdownMenuItem(value: 'Debit Basis', child: Text('Debit – ALL diesel given is debited', maxLines: 2)),
          ],
          selectedItemBuilder: (_) => [
            for (final x in ['Company diesel – only extra over standard debited', 'Debit – ALL diesel given is debited']) Align(alignment: Alignment.centerLeft, child: Text(x, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: noRent ? null : (x) => setState(() => l.diesel = x ?? 'Company'),
        ),
        const SizedBox(height: 8),
        _text(Key('bl-remark-$i'), 'Remark', l.remark, (x) => l.remark = x),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(key: Key('bl-same-$i'), onPressed: () => _same(l), icon: const Icon(Icons.copy_all_rounded, size: 18), label: Text('same terms → other machinery')),
        ),
      ]),
    );
  }

  Widget _item(int i, int k, BoqLine l, BoqItem it) {
    final day = itemKind(it.basis) == 'day';
    return Container(
      key: Key('bi-$i-$k'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C.slateSoft, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _text(Key('bi-name-$i-$k'), 'Item (e.g. Bucket)', it.name, (x) => it.name = x)),
          IconButton(tooltip: tr('Remove item'), onPressed: () => setState(() => l.items.removeAt(k)), icon: const Icon(Icons.close_rounded, size: 20)),
        ]),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey('bi-basis-$i-$k-${it.basis}'),
          initialValue: it.basis,
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('Rent type')),
          items: [for (final x in kItemBasis) DropdownMenuItem(value: x, child: Text(kItemBasisWords[x] ?? x))],
          onChanged: (x) => setState(() {
            it.basis = x ?? 'Per Hour';
            l.tidy();
          }),
        ),
        const SizedBox(height: 6),
        if (it.slabs.isEmpty) _num(Key('bi-rate-$i-$k'), 'rate ₹', it.rate, (x) => it.rate = x) else Text('Rate: see the hour slabs below.', style: const TextStyle(color: C.muted)),
        if (!day) ...[
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('bi-qty-$i-$k-${it.qty}'),
            initialValue: it.qty,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('Where the quantity of this item comes from in the Log Book entry')),
            items: [
              DropdownMenuItem(value: 'rest', child: Text('quantity: rest of the entry (automatic)')),
              DropdownMenuItem(value: 'typed', child: Text('quantity: typed in the Log Book')),
            ],
            onChanged: (x) => setState(() => it.qty = x ?? 'rest'),
          ),
        ],
        if (it.basis == 'Per Hour')
          _slabs(it.slabs, (on) => it.slabOn = on, it.slabOn, () => setState(() {
                if (it.slabs.isEmpty) {
                  it.slabs.addAll([BoqSlab('1', it.rate), BoqSlab('', '')]);
                } else {
                  it.slabs.add(BoqSlab('', ''));
                }
                l.tidy();
              }), (j) => setState(() {
                it.slabs.removeAt(j);
                if (it.slabs.length == 1) it.slabs.clear();
              }), 'bi-$i-$k'),
      ]),
    );
  }

  /// Hour slabs: "up to … hr @ ₹ …" (the last one blank = after that), counted on each day's or the period's hours.
  Widget _slabs(List<BoqSlab> slabs, ValueChanged<String> onOn, String slabOn, VoidCallback add, ValueChanged<int> del, String key) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (j, sl) in slabs.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Expanded(child: _num(Key('$key-up-$j'), 'up to … hr', sl.upTo, (x) => sl.upTo = x, hint: 'after')),
              const SizedBox(width: 6),
              Expanded(child: _num(Key('$key-sr-$j'), 'hr @ ₹', sl.rate, (x) => sl.rate = x)),
              IconButton(onPressed: () => del(j), icon: const Icon(Icons.remove_circle_outline_rounded, color: C.red)),
            ]),
          ),
        if (slabs.isNotEmpty) ...[
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('$key-on-$slabOn'),
            initialValue: slabOn,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('Slab hours counted on')),
            items: [DropdownMenuItem(value: 'Day', child: Text('on each day\'s hours')), DropdownMenuItem(value: 'Period', child: Text('on the period\'s total hours'))],
            onChanged: (x) => setState(() => onOn(x ?? 'Day')),
          ),
        ],
        Align(alignment: Alignment.centerLeft, child: TextButton(key: Key('$key-addslab'), onPressed: add, child: Text('+ add hour slab (e.g. 1st hr ₹1,000, after that ₹2,000)'))),
      ]);

  Widget _num(Key key, String label, String value, ValueChanged<String> on, {String hint = ''}) => _Box(key: key, label: label, value: value, on: on, number: true, hint: hint);
  Widget _text(Key key, String label, String value, ValueChanged<String> on) => _Box(key: key, label: label, value: value, on: on);
}

/// A box that keeps its own text (the lines of the form are rebuilt often).
class _Box extends StatefulWidget {
  const _Box({super.key, required this.label, required this.value, required this.on, this.number = false, this.hint = ''});
  final String label, value, hint;
  final ValueChanged<String> on;
  final bool number;
  @override
  State<_Box> createState() => _BoxState();
}

class _BoxState extends State<_Box> {
  late final c = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(_Box old) {
    super.didUpdateWidget(old);
    if (widget.value != c.text && widget.value != old.value) c.text = widget.value;
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: c,
        keyboardType: widget.number ? const TextInputType.numberWithOptions(decimal: true) : null,
        onChanged: (x) => widget.on(x.trim()),
        decoration: InputDecoration(labelText: tr(widget.label), hintText: widget.hint.isEmpty ? null : tr(widget.hint)),
      );
}
