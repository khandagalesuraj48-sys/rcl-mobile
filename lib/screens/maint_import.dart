/* (3.53.0, Mechanical update-173) THE OLD MAINTENANCE LOG BOOK, IMPORTED AS IT IS – the app's own screen of the web's "Import the old
 * log book (Excel)" (the Admin): the file read as the web reads it (core/maint_import.dart); a card a sheet – its name in the file, its
 * machinery (Own, on the site – it can be changed; "– not imported –"), rows, bills, the file's total and the total as it will be kept;
 * Check (checkMaintImport – nothing saved), then Import (importMaint, one machinery at a time – a bill already there is left out).
 * The same server actions, checks and access as the web. */
import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/maint_import.dart';
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class MaintImportScreen extends StatefulWidget {
  const MaintImportScreen({super.key, required this.name, required this.sheets});
  final String name;
  final List<MliSheet> sheets;
  @override
  State<MaintImportScreen> createState() => _MaintImportScreenState();
}

class _MaintImportScreenState extends State<MaintImportScreen> {
  bool busy = false, any = false;

  List<MliSheet> get _ready => [for (final x in widget.sheets) if (x.no.isNotEmpty && x.done == null) x];

  void _twice() {
    final seen = <String>{};
    for (final x in widget.sheets) {
      x.twice = x.no.isNotEmpty && seen.contains(x.no);
      if (x.no.isNotEmpty) seen.add(x.no);
    }
  }

  Future<void> _check() async {
    final s = SessionScope.read(context);
    setState(() => busy = true);
    for (final x in _ready) {
      if (x.twice) continue;
      try {
        x.res = (await s.api.call('checkMaintImport', [{'no': x.no, 'bills': x.bills}]) as Map).cast<String, dynamic>();
        x.err = '';
      } catch (e) {
        x.res = null;
        x.err = errText(e);
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _import() async {
    final s = SessionScope.read(context);
    final todo = [for (final x in _ready) if (!x.twice && x.res != null && x.res!['ok'] == true) x];
    if (todo.isEmpty) return;
    if (!await askLines(context, 'Import the old log book?', [
      for (final x in todo) '${x.no}: ${x.res!['fresh']} bill(s), ₹${fmtNum(asNum(x.res!['total']))}',
      'Each machinery all of it or nothing; a bill already there is left out.',
    ], yes: 'Import')) return;
    setState(() => busy = true);
    var added = 0;
    for (final x in todo) {
      try {
        x.done = (await s.api.call('importMaint', [{'no': x.no, 'bills': x.bills}], true) as Map).cast<String, dynamic>();
        added += (asNum(x.done!['added']) ?? 0).toInt();
        any = true;
      } catch (e) {
        x.err = errText(e);
      }
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, '$added bill(s) imported.');
  }

  /// What a sheet is now – the web's mliState, word for word
  (String, Color) _state(MliSheet x) {
    final d = x.done;
    if (d != null) {
      final first = '${d['first'] ?? ''}', last = '${d['last'] ?? ''}', n = asNum(d['added']) ?? 0, same = asNum(d['same']) ?? 0;
      return ('✓ ${fmtNum(n)} bill(s) imported${n > 0 ? ' ($first${last != first ? ' – $last' : ''})' : ''}${same > 0 ? ' · ${fmtNum(same)} already there – left out' : ''}', C.greenDark);
    }
    if (x.no.isEmpty) return ('not imported', C.muted);
    if (x.twice) return ('Two sheets for ${x.no} – keep one.', C.red);
    if (x.err.isNotEmpty) return (x.err, C.red);
    final r = x.res;
    if (r == null) return x.bad.isNotEmpty ? ('${x.bad.length} row(s) without a date – ${x.bad.take(3).join('; ')}', C.red) : ('Press Check', C.muted);
    if (r['ok'] != true) {
      final errs = [for (final e in (r['errors'] as List? ?? const []).whereType<Map>().take(8)) '${e['rows']}: ${e['msg']}'];
      return ('✗ ${r['errorCount']} mistake(s) – nothing of this sheet is imported:\n${errs.join('\n')}', C.red);
    }
    final from = '${r['from'] ?? ''}', to = '${r['to'] ?? ''}', same = asNum(r['same']) ?? 0;
    return ('✓ ${r['fresh']} new bill(s), ${r['lines']} line(s), ₹${fmtNum(asNum(r['total']))}${from.isNotEmpty ? ' (${showDate(from)} – ${showDate(to)})' : ''}${same > 0 ? '\n${fmtNum(same)} bill(s) already there – left out' : ''}', C.greenDark);
  }

  Widget _card(Session s, int i, MliSheet x, List<Map<String, dynamic>> own) {
    final (st, tone) = _state(x);
    return Container(
      key: Key('mli-$i'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(x.sheet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (x.label.isNotEmpty) Text('${tr('Name in the file')}: ${x.label}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        const SizedBox(height: 10),
        PickField(
          key: Key('mli-no-$i'),
          label: 'Machinery (Active, Own)',
          value: x.no,
          items: [for (final m in own) '${m['id']}'],      // (PickField puts the blank line first)
          blank: '– not imported –',
          labels: {for (final m in own) '${m['id']}': '${m['id']}${'${m['name'] ?? ''}'.isNotEmpty && m['name'] != m['id'] ? ' · ${m['name']}' : ''}'},
          enabled: !busy && x.done == null,
          onChanged: (v) => setState(() {
            x.no = v;
            x.res = null;
            x.err = '';
            _twice();
          }),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _fact('Rows', fmtNum(x.rows)),
          _fact('Bills', fmtNum(x.bills.length)),
          _fact('File total (₹)', fmtNum(x.fileTotal)),
          _fact('Total (₹)', fmtNum(x.total)),
        ]),
        const SizedBox(height: 8),
        Text(st, key: Key('mli-st-$i'), style: TextStyle(fontSize: 13, color: tone, fontWeight: FontWeight.w600, height: 1.35)),
      ]),
    );
  }

  Widget _fact(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(fontSize: 11.5, color: C.muted)),
        Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ]);

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), own = mliOwn([for (final m in s.machines) m.m], s.today);
    _twice();
    final ready = _ready, okAll = ready.isNotEmpty && ready.every((x) => !x.twice && x.res != null && x.res!['ok'] == true);
    return PopScope(
      canPop: !busy,      // (not while it imports)
      child: Scaffold(
        appBar: AppBar(title: const TwoLang('Import the old log book (Excel)', 'जुनी log book import करा (Excel)', size: 17, weight: FontWeight.w700)),
        body: ListView(key: const Key('mli-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 20), children: [
          Text('${widget.name} – ${widget.sheets.length} sheet(s)', key: const Key('mli-name'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Total (₹) = the lines with their GST as they will be kept; the file total is its "Amount With GST" (whole rupees in an old file).', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
          const SizedBox(height: 10),
          for (final (i, x) in widget.sheets.indexed) _card(s, i, x, own),
        ]),
        // Check and Import always at hand (a file of many sheets is a long list)
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
            child: Row(children: [
              Expanded(child: OutlinedButton(key: const Key('mli-check'), onPressed: busy || ready.isEmpty ? null : _check, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text('Check'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(key: const Key('mli-go'), onPressed: busy || !okAll ? null : _import, style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(busy ? 'Importing…' : 'Import'))),
            ]),
          ),
        ),
      ),
    );
  }
}
