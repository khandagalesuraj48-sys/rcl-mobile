/* THE REST OF THE WEB'S DIESEL PAGES (3.11.0) – in the app's own screens (Entries → a page → ⋮):
 *   – All dates & Export: the web's list of the page with its filters (dates, Today / Yesterday / Last 7 days / This month, and
 *     the page's own: machinery, shift, source, owner, driver, ID / remark · pump, received at, bill · stock point, ID / remark),
 *     the server's totals, Export to Excel (the web's file), and on Diesel Issue each entry's % of the total and "% by machinery";
 *   – Import from Excel: the file read as the web reads it (core/sheet_read.dart, core/imports.dart), every row checked
 *     (✓ / ✗) – "Fix the file first" or "Import N rows" – then the server's own import (all rows or none);
 *   – Download template: the web's template file;
 *   – Multiple entries: Transfer (rows of date, shift, from, to, qty, remark → saveTransferBulk) and Diesel Issue (one date – many
 *     machinery → saveDieselBulk with its warnings; one machinery – many dates → importDiesel), with the web's running stock.
 * Every check here is the web's; the server checks everything again. */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/imports.dart';
import '../core/kinds.dart';
import '../core/rdoc.dart';
import '../core/session.dart';
import '../core/sheet_read.dart';
import '../core/xlsx.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/pick_file.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'entries.dart' show EntryCard;
import 'forms.dart' show MachinePicker;

final _sm = OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12));
String _today(Session s) => s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
String _company(Session s) => s.printNames.isEmpty ? 'Rachana Construction Limited' : s.printNames.first;
String _what(Kind k, int n) => switch (k.key) { 'inward' => 'inward entries', 'transfer' => 'transfers', _ => 'diesel issues' };
String _showD(Object? d) => RegExp(r'^\d{4}-').hasMatch('$d') ? showDate('$d') : '$d';

/// A text box's number as the web's input gives it: '' or a number (NaN when it is not one).
Object _boxNum(String t) => t.trim().isEmpty ? '' : jsNumber(t);

// =====================================================================================================================
//  IMPORT FROM EXCEL · DOWNLOAD TEMPLATE
// =====================================================================================================================

/// The web's "Import from Excel" of a diesel page: true when rows were imported.
Future<bool> importEntries(BuildContext context, Kind k) async {
  final s = SessionScope.read(context);
  final f = await pickSheetFile();
  if (f == null || !context.mounted) return false;
  List<Map<String, Object?>> rows;
  try {
    final tabs = readSheets(f.bytes);
    rows = switch (k.key) {
      'inward' => readInward(tabs, s.locations),
      'transfer' => transferRows(tabs, s.locations),
      _ => issueRows(tabs, s.locations, s.machines.map((m) => m.m)),
    };
    if (rows.isEmpty) throw SheetError('No rows found under the heading row.');
  } on SheetError catch (e) {
    toast(context, e.message, bad: true);
    return false;
  } catch (_) {
    toast(context, 'Could not read the file.', bad: true);
    return false;
  }
  if (!context.mounted) return false;
  return await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ImportCheckScreen(kind: k, rows: rows, file: f.name))) ?? false;
}

/// The web's "Download template" of a diesel page.
Future<void> downloadTemplate(BuildContext context, Kind k) async {
  final s = SessionScope.read(context), today = _today(s);
  final t = importTemplate(k.key, today, s.locations, [for (final m in s.machines) if (onSiteOn(m.m, today)) m.id]);
  final doc = RDoc(title: t.sheet, file: t.file, blocks: [
    RTable(
      sheet: t.sheet,
      head: [for (final h in t.rows.first) '$h'],
      rows: [
        for (final r in t.rows.skip(1)) RRow([for (final v in r) v is num ? RCell(jsNumS(v), n: true, value: v) : RCell('$v')]),
      ],
    ),
  ]);
  try {
    await shareXlsx(reportXlsx(doc, const []), '${t.file}.xlsx');
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
  }
}

/// The rows of a file, each checked – then the server's import (all or none).
class ImportCheckScreen extends StatefulWidget {
  const ImportCheckScreen({super.key, required this.kind, required this.rows, this.file = ''});
  final Kind kind;
  final List<Map<String, Object?>> rows;
  final String file;
  @override
  State<ImportCheckScreen> createState() => _ImportCheckScreenState();
}

class _ImportCheckScreenState extends State<ImportCheckScreen> {
  bool busy = false;

  List<String> _problems(Session s, Map r) => switch (widget.kind.key) {
        'inward' => inwardProblems(r, _today(s), s.locations),
        'transfer' => transferProblems(r, _today(s), s.locations),
        _ => issueProblems(r, _today(s), s.locations, s.machines.map((m) => m.m)),
      };

  Future<void> _go() async {
    final s = SessionScope.read(context), k = widget.kind;
    setState(() => busy = true);
    try {
      final fn = switch (k.key) { 'inward' => 'importInward', 'transfer' => 'saveTransferBulk', _ => 'importDiesel' };
      final res = (await s.api.call(fn, [widget.rows.map(sendable).toList()], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (res['ok'] != true) {
        final errs = [for (final e in (res['errors'] as List? ?? const []).whereType<Map>()) '${k.key == 'inward' || jsTrue(e['row']) ? 'Line ${e['row']}: ' : ''}${e['msg'] ?? ''}'];
        await tellLines(context, k.key == 'transfer' ? 'Nothing saved' : 'Nothing imported', errs);
        return;
      }
      if (res['stock'] != null) s.setStock(res['stock']);
      toast(context, k.key == 'transfer' ? '${res['count']} transfers saved (${fmt(res['qty'])} Ltr).' : '${res['count']} ${_what(k, 0)} imported (${fmt(res['qty'])} Ltr).');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<(String, String)> _fields(Map r) => switch (widget.kind.key) {
        'inward' => [
            ('Date', _showD(r['date'])),
            ('Received at', '${r['location']}'),
            ('Pump', '${r['pump']}'),
            ('Qty', fmt(r['qty'])),
            ('Rate', fmt(r['rate'])),
            ('Amount', fmt(r2(((r['qty'] is num) ? r['qty'] as num : 0) * ((r['rate'] is num) ? r['rate'] as num : 0)))),
            ('Bill No', '${r['billNo']}'),
            ('Bill Date', _showD(r['billDate'])),
          ],
        'transfer' => [
            ('Date', _showD(r['date'])),
            ('Shift', '${r['shift']}'),
            ('From', '${r['from']}'),
            ('To', '${r['to']}'),
            ('Qty', fmt(r['qty'])),
            ('Remark', '${r['remark']}'),
          ],
        _ => [
            ('Date', _showD(r['date'])),
            ('Shift', '${r['shift']}'),
            ('Source', '${r['source']}'),
            ('Machinery', '${r['no']}'),
            ('Qty', fmt(r['qty'])),
            ('KM', fmt(r['kmReading'])),
            ('Hrs', fmt(r['hrReading'])),
            ('Driver', '${r['driver']}'),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), k = widget.kind, rows = widget.rows;
    final probs = [for (final r in rows) _problems(s, r)];
    final bad = probs.where((p) => p.isNotEmpty).length;
    num sum(String f) => rows.fold<num>(0, (a, r) => a + (r[f] is num && !(r[f] as num).isNaN ? r[f] as num : 0));
    final qty = r2(sum('qty'));
    final amt = r2(rows.fold<num>(0, (a, r) => a + (r['qty'] is num && !(r['qty'] as num).isNaN ? r['qty'] as num : 0) * (r['rate'] is num && !(r['rate'] as num).isNaN ? r['rate'] as num : 0)));
    final title = bad > 0 ? 'Fix the file first' : 'Import ${rows.length} ${_what(k, rows.length)}?';
    final note = bad > 0
        ? '$bad of ${rows.length} rows have a problem (marked ✗). Nothing was imported.'
        : k.key == 'inward'
            ? '${fmt(qty)} Ltr, amount ₹${fmt(amt)}. All rows are saved together, or none if any row has a problem.'
            : 'Total ${fmt(qty)} Ltr. Stock is checked with all rows together; all are saved, or none.';
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('imp-list'), padding: const EdgeInsets.fromLTRB(14, 8, 14, 120), children: [
        if (widget.file.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(widget.file, style: const TextStyle(color: C.muted, fontSize: 13))),
        InfoLine(note, bad: bad > 0, icon: bad > 0 ? Icons.error_outline_rounded : Icons.fact_check_outlined),
        const SizedBox(height: 10),
        for (final (i, r) in rows.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              key: Key('imp-row-$i'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: probs[i].isEmpty ? Colors.white : C.redSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: probs[i].isEmpty ? C.line : C.red.withValues(alpha: .4))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Line ${r['line']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Flexible(
                    child: Text(probs[i].isEmpty ? '✓' : '✗ ${probs[i].join(', ')}',
                        textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, color: probs[i].isEmpty ? C.greenDark : C.red)),
                  ),
                ]),
                const SizedBox(height: 4),
                Wrap(spacing: 12, runSpacing: 2, children: [
                  for (final f in _fields(r))
                    if (f.$2.isNotEmpty) Text('${tr(f.$1)}: ${f.$2}', style: const TextStyle(fontSize: 13.5, color: C.ink)),
                ]),
              ]),
            ),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: bad > 0
              ? FilledButton(key: const Key('imp-ok'), onPressed: () => Navigator.pop(context, false), child: const Text('OK'))
              : FilledButton.icon(
                  key: const Key('imp-go'),
                  style: FilledButton.styleFrom(backgroundColor: k.color),
                  onPressed: busy ? null : _go,
                  icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload_file_rounded),
                  label: Text('Import ${rows.length} rows'),
                ),
        ),
      ),
    );
  }
}

// =====================================================================================================================
//  ALL DATES & EXPORT – the web's list of the page
// =====================================================================================================================
class EntryFindScreen extends StatefulWidget {
  const EntryFindScreen({super.key, required this.kind});
  final Kind kind;
  @override
  State<EntryFindScreen> createState() => _EntryFindScreenState();
}

class _EntryFindScreenState extends State<EntryFindScreen> {
  String from = '', to = '', shift = '', place = '', err = '';
  final no = TextEditingController(), owner = TextEditingController(), driver = TextEditingController(), q = TextEditingController(), pump = TextEditingController(), bill = TextEditingController();
  Map<String, dynamic>? res;
  bool loading = true, share = false;
  int _seq = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _t?.cancel();
    for (final c in [no, owner, driver, q, pump, bill]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The web's filter of the page (dieselFilter / the inward and transfer filters).
  Map<String, Object> _filter() => switch (widget.kind.key) {
        'inward' => {'from': from, 'to': to, 'pump': pump.text.trim(), 'bill': bill.text.trim(), 'location': place},
        'transfer' => {'from': from, 'to': to, 'location': place, 'q': q.text.trim()},
        _ => {'from': from, 'to': to, 'no': no.text.trim(), 'shift': shift, 'source': place, 'owner': owner.text.trim(), 'driver': driver.text.trim(), 'q': q.text.trim()},
      };

  void _set(VoidCallback f) {
    setState(f);
    _load();
  }

  void _soon() {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = (await s.api.call(widget.kind.list, [_filter()]) as Map).cast<String, dynamic>();
      if (my != _seq || !mounted) return;
      setState(() {
        res = r;
        loading = false;
      });
    } catch (e) {
      if (my != _seq || !mounted) return;
      setState(() {
        err = errText(e);
        loading = false;
      });
    }
  }

  void _range(String k) {
    final t = parseKey(_today(SessionScope.read(context)));
    String d(DateTime x) => dateKey(x);
    setState(() {
      switch (k) {
        case 'today':
          from = to = d(t);
        case 'yesterday':
          from = to = d(t.subtract(const Duration(days: 1)));
        case '7':
          from = d(t.subtract(const Duration(days: 6)));
          to = d(t);
        case 'month':
          from = d(DateTime(t.year, t.month, 1));
          to = d(t);
      }
    });
    _load();
  }

  void _clear() {
    setState(() {
      from = to = shift = place = '';
      for (final c in [no, owner, driver, q, pump, bill]) {
        c.clear();
      }
    });
    _load();
  }

  /// The web's Export to Excel of the page: every entry that matches the filter, oldest first, with its total.
  Future<void> _export() async {
    final s = SessionScope.read(context), k = widget.kind, today = _today(s);
    try {
      final f = {..._filter(), 'all': true};
      final d = (await s.api.call(k.list, [f]) as Map).cast<String, dynamic>();
      final rows = [for (final r in (d['rows'] as List? ?? const []).whereType<Map>()) r.cast<String, dynamic>()].reversed.toList();
      if (rows.isEmpty) {
        if (mounted) toast(context, 'No ${k.key == 'issue' ? 'diesel issues' : k.key == 'inward' ? 'inward entries' : 'transfers'} match this filter.', bad: true);
        return;
      }
      final period = exportPeriod('${f['from']}', '${f['to']}', today);
      final title = '${k.key == 'issue' ? 'Diesel Issue' : k.key == 'inward' ? 'Diesel Inward' : 'Diesel Transfer'} – $period';
      RCell c(Object? v) => v is num ? RCell(jsNumS(v), n: true, value: v) : RCell('${v ?? ''}');
      final (head, lines, total) = switch (k.key) {
        'inward' => (
            ['Inward ID', 'Date', 'Received at', 'Pump Name', 'Qty (Ltr)', 'Rate (₹/Ltr)', 'Amount (₹)', 'Bill Number', 'Bill Date', 'Balance (Ltr)'],
            [for (final r in rows) [r['id'], showDate('${r['date']}'), r['location'], r['pump'], r['qty'], r['rate'], r['amount'], r['billNo'], jsTrue(r['billDate']) ? showDate('${r['billDate']}') : '', r['balance']]],
            <Object?>['Total', '', '', '', d['qty'], '', d['amount']],
          ),
        'transfer' => (
            ['Transfer ID', 'Date', 'Shift', 'From', 'To', 'Qty (Ltr)', 'From balance (Ltr)', 'To balance (Ltr)', 'Remark'],
            [for (final r in rows) [r['id'], showDate('${r['date']}'), r['shift'], r['from'], r['to'], r['qty'], r['fromBal'], r['toBal'], r['remark']]],
            <Object?>['Total', '', '', '', '', d['qty']],
          ),
        _ => (
            ['Issue ID', 'Date', 'Shift', 'Diesel Source', 'Machinery Number', 'Type of Machinery', 'Owner Name', 'Driver Name', 'Diesel Qty (Ltr)', 'KM Reading', 'Hrs Reading', 'Balance (Ltr)', 'Remark'],
            [for (final r in rows) [r['id'], showDate('${r['date']}'), r['shift'], r['source'], r['no'], r['type'], r['owner'], r['driver'], r['qty'], r['kmReading'], r['hrReading'], r['balance'], r['remark']]],
            <Object?>['Total', '', '', '', '', '', '', '', r2(rows.fold<num>(0, (a, r) => a + (asNum(r['qty']) ?? 0)))],
          ),
      };
      final sheet = k.key == 'issue' ? 'Diesel Issue' : k.key == 'inward' ? 'Diesel Inward' : 'Diesel Transfer';
      final doc = RDoc(title: title, file: '$sheet ${period.replaceAll('/', '-')}', blocks: [
        RTable(sheet: sheet, head: head, rows: [for (final l in lines) RRow([for (final v in l) c(v)])], foot: [const RRow([]), RRow([for (final v in total) c(v)])]),
      ]);
      await shareXlsx(reportXlsx(doc, [_company(s), s.siteLabel, title]), '${doc.file}.xlsx');
      if (mounted) toast(context, '${rows.length} ${_what(k, rows.length)} exported.');
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), k = widget.kind, today = _today(s);
    final rows = [for (final r in (res?['rows'] as List? ?? const []).whereType<Map>()) r.cast<String, dynamic>()];
    final count = asNum(res?['count']) ?? 0;
    final total = asNum(k.key == 'issue' ? res?['totalQty'] : res?['qty']) ?? 0;
    final shareList = [for (final x in (res?['share'] as List? ?? const []).whereType<Map>()) x];
    final sum = switch (k.key) {
      'inward' => 'Entries: ${fmt(count)}   Qty: ${fmt(res?['qty'])} Ltr   Amount: ₹${money(res?['amount'])}',
      'transfer' => 'Entries: ${fmt(count)}   Qty: ${fmt(res?['qty'])} Ltr',
      _ => 'Entries: ${fmt(count)}   Total diesel: ${fmt(res?['totalQty'])} Ltr',
    };
    final more = count > rows.length ? (k.key == 'issue' ? '(showing latest ${rows.length} – narrow the filter to see the rest)' : '(showing latest ${rows.length})') : '';
    Widget box(String label, TextEditingController c, String key, {List<String> options = const []}) => TextBox(key: Key(key), label: label, controller: c, options: options, onChanged: (_) => _soon());
    final last = parseKey(today);
    return Scaffold(
      appBar: AppBar(
        title: TwoLang('${k.en} – all dates', '${k.mr} – सर्व तारखा', size: 19, weight: FontWeight.w700),
        actions: [IconButton(key: const Key('ef-reload'), tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('ef-list'), padding: const EdgeInsets.fromLTRB(14, 8, 14, 40), children: [
          Row(children: [
            Expanded(child: DateField(key: const Key('ef-from'), label: 'From (blank = from start)', value: from, last: last, onChanged: (v) => _set(() => from = v))),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('ef-to'), label: 'To (blank = till today)', value: to, last: last, onChanged: (v) => _set(() => to = v))),
          ]),
          const SizedBox(height: 8),
          if (k.key == 'issue') ...[
            box('Machinery Number / Name', no, 'ef-no', options: [for (final m in s.machines) m.id]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: PickField(key: const Key('ef-shift'), label: 'Shift', value: shift, items: const ['Day', 'Night'], blank: 'All', onChanged: (v) => _set(() => shift = v))),
              const SizedBox(width: 8),
              Expanded(child: PickField(key: const Key('ef-place'), label: 'Diesel Source', value: place, items: s.locations, blank: 'All', onChanged: (v) => _set(() => place = v))),
            ]),
            const SizedBox(height: 8),
            box('Owner Name', owner, 'ef-owner', options: {for (final m in s.machines) if (m.owner.isNotEmpty) m.owner}.toList()..sort()),
            const SizedBox(height: 8),
            box('Driver Name', driver, 'ef-driver', options: s.drivers),
            const SizedBox(height: 8),
            box('Issue ID / Remark', q, 'ef-q'),
          ],
          if (k.key == 'inward') ...[
            box('Pump Name', pump, 'ef-pump', options: s.pumps),
            const SizedBox(height: 8),
            PickField(key: const Key('ef-place'), label: 'Received at', value: place, items: s.locations, blank: 'All', onChanged: (v) => _set(() => place = v)),
            const SizedBox(height: 8),
            box('Bill Number / Inward ID', bill, 'ef-bill'),
          ],
          if (k.key == 'transfer') ...[
            PickField(key: const Key('ef-place'), label: 'Stock point', value: place, items: s.locations, blank: 'All', onChanged: (v) => _set(() => place = v)),
            const SizedBox(height: 8),
            box('Transfer ID / Remark', q, 'ef-q'),
          ],
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final x in [('today', 'Today'), ('yesterday', 'Yesterday'), if (k.key == 'issue') ('7', 'Last 7 days'), ('month', 'This month')])
                Padding(padding: const EdgeInsets.only(right: 6), child: OutlinedButton(key: Key('ef-r-${x.$1}'), style: _sm, onPressed: () => _range(x.$1), child: Text(x.$2))),
              Padding(padding: const EdgeInsets.only(right: 6), child: OutlinedButton(key: const Key('ef-clear'), style: _sm, onPressed: _clear, child: const Text('Clear filters'))),
              OutlinedButton.icon(key: const Key('ef-export'), style: _sm, onPressed: _export, icon: const Icon(Icons.table_view_rounded, size: 18), label: const Text('Export to Excel')),
            ]),
          ),
          const SizedBox(height: 12),
          if (loading && res == null)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          else if (err.isNotEmpty)
            InfoLine(err, bad: true)
          else ...[
            Text(sum, key: const Key('ef-sum'), style: TextStyle(fontWeight: FontWeight.w800, color: k.color, fontSize: 15)),
            if (more.isNotEmpty) Text(more, style: const TextStyle(color: C.muted, fontSize: 13)),
            const SizedBox(height: 10),
            if (rows.isEmpty) EmptyState('No ${_what(k, 0)} match this filter.', 'Change the dates or the filter.', pic: k.pic),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: EntryCard(
                  key: Key('ef-${r['id']}'),
                  kind: k,
                  r: r,
                  onChanged: _load,
                  note: [
                    showDate('${r['date'] ?? ''}'),
                    if (k.key == 'issue') total > 0 ? '${fmt(r2((asNum(r['qty']) ?? 0) / total * 100))}% of total' : '–',
                  ].join(' · '),
                ),
              ),
            if (count > 0) Text('Total – ${fmt(count)} ${k.key == 'transfer' ? 'transfers' : 'entries'}: ${fmt(total)} Ltr', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (k.key == 'issue') ...[
              const SizedBox(height: 14),
              Row(children: [
                OutlinedButton(key: const Key('ef-share'), style: _sm, onPressed: () => setState(() => share = !share), child: Text(share ? 'Hide % by machinery' : 'Show % by machinery')),
                const SizedBox(width: 10),
                if (shareList.isNotEmpty) Expanded(child: Text('${shareList.length} machinery, ${fmt(total)} Ltr', style: const TextStyle(color: C.muted, fontSize: 13))),
              ]),
              if (share) ...[
                const SizedBox(height: 8),
                if (shareList.isEmpty) const InfoLine('No diesel issues match this filter.'),
                for (final (i, x) in shareList.indexed) _shareRow(i, x, total),
                if (shareList.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('Total: ${fmt(total)} Ltr · 100%', style: const TextStyle(fontWeight: FontWeight.w800))),
              ],
            ],
          ],
        ]),
      ),
    );
  }

  Widget _shareRow(int i, Map x, num total) {
    final p = total > 0 ? (asNum(x['qty']) ?? 0) / total * 100 : 0;
    return Container(
      key: Key('ef-sh-$i'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${i + 1}. ', style: const TextStyle(color: C.muted, fontWeight: FontWeight.w700)),
          Expanded(child: Text('${x['no'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('${fmt(x['qty'])} Ltr · ${fmt(r2(p))}%', style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        Text([x['type'], x['owner'], '${fmt(x['entries'])} entries'].where((e) => '${e ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(color: C.muted, fontSize: 12.5)),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (p > 100 ? 100 : p) / 100, minHeight: 6, color: C.green, backgroundColor: C.greenSoft)),
      ]),
    );
  }
}

// =====================================================================================================================
//  MULTIPLE ENTRIES – TRANSFER
// =====================================================================================================================
class _TrRow {
  _TrRow(this.date, this.shift, this.from, this.to);
  String date, shift, from, to;
  final qty = TextEditingController(), remark = TextEditingController();
  Map<String, Object> value(int line) => {'line': line, 'date': date, 'shift': shift, 'from': from, 'to': to, 'qty': _boxNum(qty.text), 'remark': remark.text.trim()};
}

class TransferManyScreen extends StatefulWidget {
  const TransferManyScreen({super.key});
  @override
  State<TransferManyScreen> createState() => _TransferManyScreenState();
}

class _TransferManyScreenState extends State<TransferManyScreen> {
  final rows = <_TrRow>[];
  List<String> errors = [];
  bool busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (rows.isEmpty) {
      _add();
      _add();
    }
  }

  /// A new row – the same date, shift, from and to as the row above.
  void _add() {
    final s = SessionScope.read(context), l = s.locations.isEmpty ? const ['Dispenser', 'VTR Store'] : s.locations;
    final last = rows.isEmpty ? null : rows.last;
    rows.add(last == null ? _TrRow(_today(s), 'Day', l[0], l.length > 1 ? l[1] : l[0]) : _TrRow(last.date, last.shift, last.from, last.to));
  }

  void _reset() {
    setState(() {
      rows.clear();
      _add();
      _add();
      errors = [];
    });
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    final all = [for (final (i, r) in rows.indexed) r.value(i + 1)];
    final list = all.where((r) => r['qty'] != '').toList();
    if (list.isEmpty) {
      toast(context, 'Type the Qty in at least one row.', bad: true);
      return;
    }
    final bad = list.where((r) => transferProblems(r, _today(s), s.locations).isNotEmpty).toList();
    if (bad.isNotEmpty) {
      toast(context, 'Fix the rows in red first (row ${bad.map((r) => r['line']).join(', ')}).', bad: true);
      return;
    }
    final tot = r2(list.fold<num>(0, (a, r) => a + (r['qty'] as num)));
    if (!await ask(context, 'Save ${list.length} transfers?', 'Total ${fmt(tot)} Ltr. All rows are saved together, or none if any row has a problem.', yes: 'Save ${list.length} transfers')) return;
    setState(() {
      busy = true;
      errors = [];
    });
    try {
      final res = (await s.api.call('saveTransferBulk', [list.map((r) => sendable(r)).toList()], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (res['ok'] != true) {
        setState(() => errors = [for (final e in (res['errors'] as List? ?? const []).whereType<Map>()) '${jsTrue(e['row']) ? 'Row ${e['row']}: ' : ''}${e['msg'] ?? ''}']);
        return;
      }
      if (res['stock'] != null) s.setStock(res['stock']);
      toast(context, '${res['count']} transfers saved (${fmt(res['qty'])} Ltr).');
      _reset();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), today = _today(s), locs = s.locations;
    final vals = [for (final (i, r) in rows.indexed) r.value(i + 1)];
    final filled = vals.where((r) => r['qty'] != '').toList();
    final tot = r2(filled.fold<num>(0, (a, r) => a + (r['qty'] is num && !(r['qty'] as num).isNaN ? r['qty'] as num : 0)));
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Transfer – multiple entries', 'एकाच वेळी अनेक', size: 19, weight: FontWeight.w700)),
      body: ListView(key: const Key('tm-list'), padding: const EdgeInsets.fromLTRB(14, 8, 14, 140), children: [
        if (errors.isNotEmpty) ...[InfoLine('Nothing saved:\n${errors.join('\n')}', bad: true), const SizedBox(height: 8)],
        for (final (i, r) in rows.indexed) _row(i, r, vals[i], today, locs),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(key: const Key('tm-add'), style: _sm, onPressed: () => setState(_add), icon: const Icon(Icons.add_rounded), label: const Text('+ Add row')),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Rows: ${filled.length}  Qty: ${fmt(tot)} Ltr', key: const Key('tm-sum'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(children: [
              OutlinedButton(key: const Key('tm-clear'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)), onPressed: _reset, child: const Text('Clear')),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(key: const Key('tm-save'), style: FilledButton.styleFrom(backgroundColor: C.purple), onPressed: busy ? null : _save, child: const Text('Save all transfers'))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _row(int i, _TrRow r, Map<String, Object> v, String today, List<String> locs) {
    final p = v['qty'] == '' ? const <String>[] : transferProblems(v, today, locs);
    return Container(
      key: Key('tm-row-$i'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.isEmpty ? Colors.white : C.redSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.isEmpty ? C.line : C.red.withValues(alpha: .4))),
      child: Column(children: [
        Row(children: [
          Text('Row ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          if (p.isNotEmpty) Flexible(child: Text('✗ ${p.join(', ')}', textAlign: TextAlign.right, style: const TextStyle(color: C.red, fontWeight: FontWeight.w700))),
          IconButton(
            key: Key('tm-del-$i'),
            tooltip: tr('Remove row'),
            onPressed: () => setState(() {
              rows.removeAt(i);
              if (rows.isEmpty) _add();
            }),
            icon: const Icon(Icons.close_rounded),
          ),
        ]),
        Row(children: [
          Expanded(child: DateField(key: Key('tm-date-$i'), label: 'Date', value: r.date, clear: false, last: parseKey(today), onChanged: (x) => setState(() => r.date = x))),
          const SizedBox(width: 8),
          Expanded(child: PickField(key: Key('tm-shift-$i'), label: 'Shift', value: r.shift, items: const ['Day', 'Night'], onChanged: (x) => setState(() => r.shift = x))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: PickField(key: Key('tm-from-$i'), label: 'From', value: r.from, items: locs, onChanged: (x) => setState(() => r.from = x))),
          const SizedBox(width: 8),
          Expanded(child: PickField(key: Key('tm-to-$i'), label: 'To', value: r.to, items: locs, onChanged: (x) => setState(() => r.to = x))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextBox(key: Key('tm-qty-$i'), label: 'Qty (Ltr)', controller: r.qty, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: TextBox(key: Key('tm-remark-$i'), label: 'Remark', controller: r.remark)),
        ]),
      ]),
    );
  }
}

// =====================================================================================================================
//  MULTIPLE ENTRIES – DIESEL ISSUE (one date – many machinery · one machinery – many dates)
// =====================================================================================================================

/// The web's confirmReadings: the readings a fill needs ("Fill these first") – true when nothing is missing.
Future<bool> confirmReadings(BuildContext context, List<({int i, Machine m, String way, Object km, Object hr})> list) async {
  final miss = <String>[];
  for (final x in list) {
    final what = <String>[];
    if (!x.m.debit) {
      if (x.way.isEmpty) {
        what.add('pick "Measured by" (${x.m.modes.isEmpty ? 'tick Works on in Asset Master' : x.m.modes.join(' / ')})');
      } else {
        if (hasKm(x.way) && x.km == '') what.add('KM reading');
        if (hasHr(x.way) && x.hr == '') what.add('Hrs reading');
      }
    }
    if (what.isNotEmpty) miss.add('${x.i > 0 ? 'Row ${x.i} – ' : ''}${x.m.id}: ${what.join(', ')}');
  }
  if (miss.isEmpty) return true;
  await tellLines(context, 'Fill these first', miss);
  return false;
}

class _DRow {
  _DRow({this.date = '', this.shift = 'Day', this.source = ''});
  Machine? m;
  String date, shift, source;
  bool meterOff = false;
  final qty = TextEditingController(), km = TextEditingController(), hr = TextEditingController(), driver = TextEditingController(), remark = TextEditingController();

  /// The way of this fill: the machinery's own (Asset Master), "No reading" when its meter is not working, '' for no meter.
  String wayFor(Machine? mm) => mm == null || mm.debit || mm.dieselWay.isEmpty ? '' : (meterOff ? kNoReading : mm.dieselWay);
}

class IssueManyScreen extends StatefulWidget {
  const IssueManyScreen({super.key});
  @override
  State<IssueManyScreen> createState() => _IssueManyScreenState();
}

class _IssueManyScreenState extends State<IssueManyScreen> {
  String type = 'date';
  // one date – many machinery
  String date = '', shift = 'Day', source = '';
  Map<String, dynamic>? bal;
  int _balSeq = 0;
  final dRows = <_DRow>[];
  List<(int, String, bool)> dNotes = []; // (row, message, warning)
  // one machinery – many dates
  Machine? bm;
  String bmSrc = '';
  final mRows = <_DRow>[];
  final pts = <String, Map>{};
  int _ptSeq = 0;
  Timer? _ptT;
  List<String> mErrors = [];
  bool busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SessionScope.read(context);
    if (date.isEmpty) {
      date = _today(s);
      source = bmSrc = s.locations.isNotEmpty ? s.locations.first : 'Dispenser';
      dRows.addAll([_DRow(), _DRow()]);
      mRows.add(_DRow(source: bmSrc));
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadBal());
    }
  }

  @override
  void dispose() {
    _ptT?.cancel();
    super.dispose();
  }

  void _setBal(VoidCallback f) {
    setState(f);
    _loadBal();
  }

  Future<void> _loadBal() async {
    final s = SessionScope.read(context), my = ++_balSeq;
    setState(() => bal = null);
    try {
      final r = (await s.api.call('getIssueBalance', [date, shift, '', source]) as Map).cast<String, dynamic>();
      if (my == _balSeq && mounted) setState(() => bal = r);
    } catch (_) {/* checked again on save */}
  }

  // ---------------- one date – many machinery ----------------
  Future<void> _pickMachine(_DRow r) async {
    final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, builder: (_) => MachinePicker(date: date));
    if (m == null) return;
    setState(() {
      r.m = m;
      r.meterOff = false;
      if (!hasKm(r.wayFor(m))) r.km.clear();
      if (!hasHr(r.wayFor(m))) r.hr.clear();
    });
  }

  Future<void> _saveDate({bool force = false}) async {
    final s = SessionScope.read(context);
    setState(() => dNotes = []);
    // the web sends every row (the server leaves out the empty ones)
    final rows = [
      for (final r in dRows)
        {
          'no': r.m?.id ?? '',
          'qty': r.qty.text.trim(),
          'kmReading': hasKm(r.wayFor(r.m)) ? r.km.text.trim() : '',
          'hrReading': hasHr(r.wayFor(r.m)) ? r.hr.text.trim() : '',
          'driver': r.driver.text.trim(),
          'remark': r.remark.text.trim(),
          'mode': r.wayFor(r.m),
        },
    ];
    if (!await confirmReadings(context, [
      for (final (i, r) in dRows.indexed)
        if (r.m != null) (i: i + 1, m: r.m!, way: rows[i]['mode']!, km: rows[i]['kmReading']!, hr: rows[i]['hrReading']!),
    ])) {
      return;
    }
    final total = r2(rows.fold<num>(0, (a, r) => a + (double.tryParse(r['qty']!) ?? 0)));
    final inactive = [for (final (i, r) in dRows.indexed) if (r.m != null && activeProblem(r.m!.m, date).isNotEmpty) (i + 1, activeProblem(r.m!.m, date))];
    if (!mounted) return;
    if (inactive.isNotEmpty) {
      setState(() => dNotes = [for (final x in inactive) (x.$1, x.$2, false)]);
      await tellLines(context, 'Machinery is not active', [for (final x in inactive) 'Row ${x.$1}: ${x.$2}']);
      return;
    }
    final avail = asNum(bal?['available']);
    if (avail != null && total > avail) {
      await tellLines(context, 'Not enough diesel in stock', ['At $source for ${showDate(date)} ($shift) you can issue up to ${fmt(avail)} Ltr, and these rows total ${fmt(total)} Ltr. Add a Diesel Inward entry first or reduce the quantities.']);
      return;
    }
    setState(() => busy = true);
    try {
      final res = (await s.api.call('saveDieselBulk', [{'date': date, 'shift': shift, 'source': source, 'rows': rows, 'force': force}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      List<(int, String, bool)> notes(Object? l, bool warn) => [for (final x in (l as List? ?? const []).whereType<Map>()) ((asNum(x['row']) ?? 0).toInt(), '${x['msg'] ?? ''}'.replaceFirst(RegExp(r'^Error:\s*'), ''), warn)];
      if (res['errors'] != null) {
        setState(() => dNotes = notes(res['errors'], false));
        toast(context, 'Nothing saved. Fix the rows marked in red.', bad: true);
        return;
      }
      if (res['warnings'] != null) {
        final w = notes(res['warnings'], true);
        setState(() => dNotes = w);
        setState(() => busy = false);
        if (await askLines(context, 'Please check these rows', [for (final x in w) 'Row ${x.$1}: ${x.$2}'], yes: 'Save all anyway')) await _saveDate(force: true);
        return;
      }
      toast(context, '${res['count']} diesel issues saved (${res['firstId']} to ${res['lastId']}).');
      setState(() {
        dRows
          ..clear()
          ..addAll([_DRow(), _DRow()]);
        dNotes = [];
      });
      _loadBal();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ---------------- one machinery – many dates ----------------
  String _ptKey(_DRow r) => '${r.date}|${r.shift}|${r.source}';
  static final _dk = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  void _ptSoon() {
    _ptT?.cancel();
    _ptT = Timer(const Duration(milliseconds: 250), () async {
      final need = {for (final r in mRows) if (_dk.hasMatch(r.date)) _ptKey(r)}.toList();
      if (need.isEmpty || !mounted) return;
      final my = ++_ptSeq, s = SessionScope.read(context);
      try {
        final res = await s.api.call('getStockPoints', [
          [for (final k in need) () { final p = k.split('|'); return {'date': p[0], 'shift': p[1], 'source': p[2]}; }()],
        ]);
        if (my != _ptSeq || !mounted || res is! List) return;
        setState(() {
          for (final (i, k) in need.indexed) {
            if (i < res.length && res[i] is Map) pts[k] = res[i] as Map;
          }
        });
      } catch (_) {/* checked again on save */}
    });
  }

  /// Each row's stock just before it (saved entries + the rows above in this list, same source, same or earlier time) and after.
  List<(num?, num?)> _mBalances() {
    int ord(_DRow r) => r.shift == 'Night' ? 1 : 0;
    final filled = [for (final (i, r) in mRows.indexed) if (r.qty.text.trim().isNotEmpty && _dk.hasMatch(r.date)) (i, r)];
    return [
      for (final (i, r) in mRows.indexed)
        () {
          final p = pts[_ptKey(r)];
          if (!_dk.hasMatch(r.date) || p == null) return (null, null);
          final before = filled.where((x) {
            final o = x.$2;
            if (x.$1 == i || o.source != r.source) return false;
            final c = '${o.date}|${ord(o)}'.compareTo('${r.date}|${ord(r)}');
            return c < 0 || (c == 0 && x.$1 < i);
          }).fold<num>(0, (a, x) => a + (double.tryParse(x.$2.qty.text.trim()) ?? 0));
          final open = r2((asNum(p['balance']) ?? 0) - before);
          return (open, r2(open - (double.tryParse(r.qty.text.trim()) ?? 0)));
        }(),
    ];
  }

  List<String> _mProblems(_DRow r, num? after) {
    final s = SessionScope.read(context), p = <String>[];
    if (r.qty.text.trim().isEmpty) return p;
    if (!_dk.hasMatch(r.date)) {
      p.add('pick the date');
    } else if (r.date.compareTo(_today(s)) > 0) {
      p.add('date after today');
    }
    final q = _boxNum(r.qty.text);
    if (!(q is num && q > 0)) p.add('qty');
    if (bm != null && r.date.isNotEmpty && activeProblem(bm!.m, r.date).isNotEmpty) p.add('not active on that date');
    if (after != null && after < 0) p.add('not enough diesel at ${r.source}');
    return p;
  }

  void _mAdd() {
    final s = SessionScope.read(context);
    final last = mRows.isEmpty ? null : mRows.last;
    var v = _DRow(source: bmSrc);
    if (last != null) {
      v = _DRow(date: last.date.isNotEmpty ? dateKey(parseKey(last.date).add(const Duration(days: 1))) : '', shift: last.shift, source: last.source);
      if (v.date.compareTo(_today(s)) > 0) {
        toast(context, 'Diesel can be entered only up to today (${showDate(_today(s))}).', bad: true);
        return;
      }
    }
    setState(() => mRows.add(v));
    _ptSoon();
  }

  Future<void> _saveMach() async {
    final s = SessionScope.read(context), m = bm;
    if (m == null) {
      toast(context, 'Pick the machinery first.', bad: true);
      return;
    }
    final bals = _mBalances();
    final list = [for (final (i, r) in mRows.indexed) if (r.qty.text.trim().isNotEmpty) (i + 1, r, bals[i])];
    if (list.isEmpty) {
      toast(context, 'Type the Diesel Qty in at least one row.', bad: true);
      return;
    }
    final bad = list.where((x) => _mProblems(x.$2, x.$3.$2).isNotEmpty).toList();
    if (bad.isNotEmpty) {
      toast(context, 'Fix the rows in red first (row ${bad.map((x) => x.$1).join(', ')}).', bad: true);
      return;
    }
    Object n(TextEditingController c) => _boxNum(c.text);
    if (!await confirmReadings(context, [
      for (final x in list) (i: x.$1, m: m, way: x.$2.wayFor(m), km: hasKm(x.$2.wayFor(m)) ? n(x.$2.km) : '', hr: hasHr(x.$2.wayFor(m)) ? n(x.$2.hr) : ''),
    ])) {
      return;
    }
    final tot = r2(list.fold<num>(0, (a, x) => a + (n(x.$2.qty) as num)));
    if (!mounted) return;
    if (!await ask(context, 'Save ${list.length} diesel issues of ${m.id}?',
        'Total ${fmt(tot)} Ltr from ${showDate(list.first.$2.date)}${list.length > 1 ? ' to ${showDate(list.last.$2.date)}' : ''}. All rows are saved together, or none.',
        yes: 'Save ${list.length} entries')) {
      return;
    }
    setState(() {
      busy = true;
      mErrors = [];
    });
    try {
      final res = (await s.api.call('importDiesel', [
        [
          for (final x in list)
            sendable({
              'line': x.$1,
              'date': x.$2.date,
              'shift': x.$2.shift,
              'source': x.$2.source,
              'no': m.id,
              'qty': n(x.$2.qty),
              'kmReading': hasKm(x.$2.wayFor(m)) ? n(x.$2.km) : '',
              'hrReading': hasHr(x.$2.wayFor(m)) ? n(x.$2.hr) : '',
              'driver': x.$2.driver.text.trim(),
              'remark': x.$2.remark.text.trim(),
            }),
        ],
      ], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (res['ok'] != true) {
        setState(() => mErrors = [for (final e in (res['errors'] as List? ?? const []).whereType<Map>()) '${jsTrue(e['row']) ? 'Row ${e['row']}: ' : ''}${e['msg'] ?? ''}']);
        return;
      }
      if (res['stock'] != null) s.setStock(res['stock']);
      toast(context, '${res['count']} diesel issues saved for ${m.id} (${fmt(res['qty'])} Ltr).');
      setState(() {
        pts.clear();
        mRows
          ..clear()
          ..add(_DRow(source: bmSrc));
      });
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ---------------- the screen ----------------
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), today = _today(s), locs = s.locations;
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Diesel Issue – multiple entries', 'एकाच वेळी अनेक', size: 19, weight: FontWeight.w700)),
      body: ListView(key: const Key('im-list'), padding: const EdgeInsets.fromLTRB(14, 8, 14, 150), children: [
        SegmentedButton<String>(
          key: const Key('im-type'),
          segments: [
            ButtonSegment(value: 'date', label: Text('One date – many machinery', key: const Key('im-t-date'), textAlign: TextAlign.center)),
            ButtonSegment(value: 'mach', label: Text('One machinery – many dates', key: const Key('im-t-mach'), textAlign: TextAlign.center)),
          ],
          selected: {type},
          showSelectedIcon: false,
          onSelectionChanged: (v) {
            setState(() => type = v.first);
            if (type == 'mach') _ptSoon();
          },
        ),
        const SizedBox(height: 12),
        if (type == 'date') ..._dateMode(s, today, locs) else ..._machMode(s, today, locs),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 10), child: type == 'date' ? _dateBar() : _machBar())),
    );
  }

  List<Widget> _dateMode(Session s, String today, List<String> locs) => [
        Row(children: [
          Expanded(child: DateField(key: const Key('im-date'), label: 'Issue Date', value: date, clear: false, last: parseKey(today), onChanged: (v) => _setBal(() => date = v))),
          const SizedBox(width: 8),
          Expanded(child: PickField(key: const Key('im-shift'), label: 'Shift', value: shift, items: const ['Day', 'Night'], onChanged: (v) => _setBal(() => shift = v))),
        ]),
        const SizedBox(height: 8),
        PickField(key: const Key('im-src'), label: 'Diesel Source', value: source, items: locs, onChanged: (v) => _setBal(() => source = v)),
        const SizedBox(height: 8),
        Text('Date, Shift and Diesel Source apply to every row (for the other source, save a separate batch).', style: const TextStyle(color: C.muted, fontSize: 13)),
        const SizedBox(height: 10),
        ..._dateRows(),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(key: const Key('im-add'), style: _sm, onPressed: () => setState(() => dRows.add(_DRow())), icon: const Icon(Icons.add_rounded), label: const Text('+ Add row')),
        ),
      ];

  List<Widget> _dateRows() {
    final start = asNum(bal?['balance']);
    var run = start ?? 0;
    final out = <Widget>[];
    for (final (i, r) in dRows.indexed) {
      final q = double.tryParse(r.qty.text.trim()) ?? 0;
      final used = q > 0 || r.m != null;
      if (q > 0) run = r2(run - q);
      final prob = r.m == null ? '' : activeProblem(r.m!.m, date);
      final notes = dNotes.where((x) => x.$1 == i + 1).toList();
      out.add(_dieselRow(
        i: i,
        r: r,
        m: r.m,
        key: 'im-row-$i',
        head: r.m == null ? 'Pick machinery' : '${r.m!.id} · ${prob.isNotEmpty ? 'Inactive' : (r.m!.m['unit'] ?? '–')} · ${r.m!.owner.isEmpty ? '–' : r.m!.owner}',
        bad: prob.isNotEmpty || notes.any((x) => !x.$3),
        warn: notes.any((x) => x.$3),
        note: [if (prob.isNotEmpty) prob, for (final x in notes) x.$2].join('\n'),
        balance: used ? (start == null ? '…' : '${fmt(run)} Ltr') : '',
        onPick: () => _pickMachine(r),
        onRemove: () => setState(() {
          dRows.removeAt(i);
          if (dRows.isEmpty) dRows.add(_DRow());
        }),
      ));
    }
    return out;
  }

  Widget _dateBar() {
    final start = asNum(bal?['balance']), avail = asNum(bal?['available']);
    final filled = dRows.where((r) => r.m != null).length;
    final total = r2(dRows.fold<num>(0, (a, r) => a + ((double.tryParse(r.qty.text.trim()) ?? 0) > 0 ? double.parse(r.qty.text.trim()) : 0)));
    final short = avail != null && total > avail;
    final line = start == null
        ? 'Loading $source stock…  Rows: $filled  Total: ${fmt(total)} Ltr'
        : '$source stock on this date: ${fmt(start)} Ltr  Rows: $filled  Total: ${fmt(total)} Ltr  Closing: ${fmt(r2(start - total))} Ltr${short ? '  (can issue up to ${fmt(avail)} Ltr)' : ''}';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(line, key: const Key('im-sum'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: short ? C.red : C.ink, fontSize: 13.5)),
      const SizedBox(height: 6),
      Row(children: [
        OutlinedButton(
          key: const Key('im-clear'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () => setState(() {
            dRows
              ..clear()
              ..addAll([_DRow(), _DRow()]);
            dNotes = [];
          }),
          child: const Text('Clear'),
        ),
        const SizedBox(width: 10),
        Expanded(child: FilledButton(key: const Key('im-save'), onPressed: busy ? null : () => _saveDate(), child: const Text('Save all diesel issues'))),
      ]),
    ]);
  }

  List<Widget> _machMode(Session s, String today, List<String> locs) {
    final m = bm, bals = _mBalances();
    return [
      Press(
        key: const Key('im-mach'),
        onTap: () async {
          final x = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, builder: (_) => const MachinePicker());
          if (x == null) return;
          setState(() {
            bm = x;
            for (final r in mRows) {
              r.meterOff = false;
              if (!hasKm(r.wayFor(x))) r.km.clear();
              if (!hasHr(r.wayFor(x))) r.hr.clear();
            }
          });
        },
        radius: 16,
        shadow: false,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.precision_manufacturing_outlined, color: C.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              m == null ? 'Pick the machinery – then one row per date.' : '${m.id}${m.type.isNotEmpty ? ' · ${m.type}' : ''}${m.owner.isNotEmpty ? ' · ${m.owner}' : ''} · Unit ${m.m['unit'] ?? '–'}${m.debit ? ' · Debit Basis (no reading)' : ''} – one row per date.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Icon(Icons.expand_more_rounded),
        ]),
      ),
      const SizedBox(height: 8),
      PickField(key: const Key('im-msrc'), label: 'Diesel Source (new rows)', value: bmSrc, items: locs, onChanged: (v) => setState(() => bmSrc = v)),
      const SizedBox(height: 8),
      if (mErrors.isNotEmpty) ...[InfoLine(mErrors.join('\n'), bad: true), const SizedBox(height: 8)],
      for (final (i, r) in mRows.indexed)
        () {
          final p = _mProblems(r, bals[i].$2);
          return _dieselRow(
            i: i,
            r: r,
            m: m,
            key: 'im-mrow-$i',
            head: 'Row ${i + 1}',
            bad: p.isNotEmpty,
            note: p.isEmpty ? '' : '✗ ${p.join(', ')}',
            balance: bals[i].$2 == null ? '–' : '${fmt(bals[i].$2)} Ltr after',
            dateBox: true,
            today: today,
            locs: locs,
            onRemove: () => setState(() {
              mRows.removeAt(i);
              if (mRows.isEmpty) mRows.add(_DRow(source: bmSrc));
            }),
          );
        }(),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(key: const Key('im-madd'), style: _sm, onPressed: _mAdd, icon: const Icon(Icons.add_rounded), label: const Text('+ Add row'))),
    ];
  }

  Widget _machBar() {
    final filled = mRows.where((r) => r.qty.text.trim().isNotEmpty).toList();
    final tot = r2(filled.fold<num>(0, (a, r) => a + (double.tryParse(r.qty.text.trim()) ?? 0)));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Rows: ${filled.length}  Diesel: ${fmt(tot)} Ltr', key: const Key('im-msum'), style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Row(children: [
        OutlinedButton(
          key: const Key('im-mclear'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () => setState(() {
            bm = null;
            mRows
              ..clear()
              ..add(_DRow(source: bmSrc));
            mErrors = [];
          }),
          child: const Text('Clear'),
        ),
        const SizedBox(width: 10),
        Expanded(child: FilledButton(key: const Key('im-msave'), onPressed: busy ? null : _saveMach, child: const Text('Save all diesel issues'))),
      ]),
    ]);
  }

  /// One row of either kind: the machinery (or the date, shift, source), the qty, the readings its way needs ("Meter not
  /// working" for no reading), the driver, the remark, the stock after it.
  Widget _dieselRow({
    required int i,
    required _DRow r,
    required Machine? m,
    required String key,
    required String head,
    bool bad = false,
    bool warn = false,
    String note = '',
    String balance = '',
    bool dateBox = false,
    String today = '',
    List<String> locs = const [],
    VoidCallback? onPick,
    required VoidCallback onRemove,
  }) {
    final way = r.wayFor(m), auto = m == null || m.debit ? '' : m.dieselWay;
    return Container(
      key: Key(key),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bad ? C.redSoft : warn ? C.amberSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bad ? C.red.withValues(alpha: .4) : C.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w800, color: C.muted)),
          const SizedBox(width: 6),
          Expanded(
            child: onPick == null
                ? Text(head, style: const TextStyle(fontWeight: FontWeight.w800))
                : InkWell(
                    key: Key('$key-pick'),
                    onTap: onPick,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(child: Text(head, style: TextStyle(fontWeight: FontWeight.w800, color: m == null ? C.green : C.ink))),
                        const Icon(Icons.expand_more_rounded, size: 20),
                      ]),
                    ),
                  ),
          ),
          if (balance.isNotEmpty) Text(balance, style: const TextStyle(fontWeight: FontWeight.w700, color: C.muted, fontSize: 13)),
          IconButton(key: Key('$key-del'), tooltip: tr('Remove row'), onPressed: onRemove, icon: const Icon(Icons.close_rounded)),
        ]),
        if (dateBox) ...[
          Row(children: [
            Expanded(
              child: DateField(
                key: Key('$key-date'),
                label: 'Issue Date',
                value: r.date,
                clear: false,
                last: parseKey(today),
                onChanged: (v) {
                  setState(() => r.date = v);
                  _ptSoon();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PickField(
                key: Key('$key-shift'),
                label: 'Shift',
                value: r.shift,
                items: const ['Day', 'Night'],
                onChanged: (v) {
                  setState(() => r.shift = v);
                  _ptSoon();
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          PickField(
            key: Key('$key-src'),
            label: 'Diesel Source',
            value: r.source,
            items: locs,
            onChanged: (v) {
              setState(() => r.source = v);
              _ptSoon();
            },
          ),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Expanded(child: TextBox(key: Key('$key-qty'), label: 'Diesel Qty (Ltr)', controller: r.qty, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: TextBox(key: Key('$key-driver'), label: 'Driver Name', controller: r.driver, options: SessionScope.read(context).drivers)),
        ]),
        if (m != null) ...[
          const SizedBox(height: 8),
          if (m.debit)
            const Text('Debit Basis – no reading', style: TextStyle(color: C.muted, fontSize: 13))
          else if (auto.isEmpty)
            const Text('no reading', style: TextStyle(color: C.muted, fontSize: 13))
          else ...[
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Pill(auto, icon: Icons.verified_rounded, color: r.meterOff ? C.muted : C.greenDark, bg: r.meterOff ? C.bg : C.greenSoft),
              FilterChip(
                key: Key('$key-off'),
                label: const Text('Meter not working'),
                selected: r.meterOff,
                onSelected: (on) => setState(() {
                  r.meterOff = on;
                  if (on) {
                    r.km.clear();
                    r.hr.clear();
                  }
                }),
              ),
            ]),
            if (hasKm(way) || hasHr(way)) const SizedBox(height: 8),
            Row(children: [
              if (hasKm(way)) Expanded(child: TextBox(key: Key('$key-km'), label: 'KM Reading', controller: r.km, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
              if (hasKm(way) && hasHr(way)) const SizedBox(width: 8),
              if (hasHr(way)) Expanded(child: TextBox(key: Key('$key-hr'), label: 'Hrs Reading', controller: r.hr, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
            ]),
          ],
        ],
        const SizedBox(height: 8),
        TextBox(key: Key('$key-remark'), label: 'Remark', controller: r.remark),
        if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(note, style: TextStyle(color: bad ? C.red : C.amber, fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
    );
  }
}
