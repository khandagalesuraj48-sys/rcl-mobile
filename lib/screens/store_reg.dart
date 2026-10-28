/* THE OLD INWARD REGISTER (3.57.0) – the app's own screens of the Store's import (rcl-store public/work.js regFile / regDraw / regAi /
 * regImport, 28-10-2026): his "INWARD UPTO GRN … .xlsx" (or any file with the register's headings). Every sheet read, the register's
 * taken (core/grn_reg.dart – word for word the web's reading). The check first – nothing saved: the new suppliers and items, the names
 * the AI finds written in more than one way (he ticks), the same row twice (he deletes what he wants – kept when he does not), the rows
 * to look at (corrected here, else left out), the notes, the Excel of the check. Then Import a part at a time – suppliers (the Vendor
 * Master, "Material Supplier"), items (the Item Master), GRNs with the file's GRN No; a GRN already in the Store is never saved twice:
 * Import again goes on from where it stopped. The same actions as the web: regInfo, regNames, regVendors, regItems, regGrns.
 * What he chose is kept for this file while the app is open (the web: in that browser). */
part of 'store_work.dart';

final _regMem = <String, (GrnChoice, Map<String, dynamic>?)>{};
const _regAil = {'party': ('supplier', 'Suppliers'), 'item': ('item', 'Items'), 'category': ('category', 'Categories')};

/// Inward (GRN) → Import from Excel: the file picked, its register read, the check.
Future<void> storeRegImport(BuildContext context, StoreKit k, Future<void> Function() reload) async {
  final f = await pickSheetFile();
  if (f == null || !context.mounted) return;
  GrnSheet? sh;
  try {
    sh = grnPickSheet(readSheets(f.bytes));
  } on SheetError catch (e) {
    toast(context, e.message, bad: true);
    return;
  } catch (_) {
    toast(context, 'Could not read the file.', bad: true);
    return;
  }
  if (sh == null) {
    toast(context, 'No sheet of this file has the inward register\'s headings (GRN No or GRN Date, Supplier Name, Material Description, Received Qty) – see "Import format".', bad: true);
    return;
  }
  final rows = grnReadRows(sh);
  if (rows.isEmpty) {
    toast(context, 'The sheet "${sh.name}" has no rows under its headings.', bad: true);
    return;
  }
  final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => GrnRegScreen(k: k, file: f.name, size: f.bytes.length, sheet: sh!, rows: rows)));
  if (done == true) {
    await k.boot().catchError((_) {});
    await reload();
  }
}

class GrnRegScreen extends StatefulWidget {
  const GrnRegScreen({super.key, required this.k, required this.file, required this.size, required this.sheet, required this.rows});
  final StoreKit k;
  final String file;
  final int size;
  final GrnSheet sheet;
  final List<Map<String, dynamic>> rows;
  @override
  State<GrnRegScreen> createState() => _GrnRegScreenState();
}

class _RegRun {
  bool busy = true;
  int supDone = 0, supOf = 0, itemDone = 0, itemOf = 0, grnDone = 0, grnOf = 0, sup = 0, items = 0, saved = 0, skipped = 0;
  final errors = <Map<String, dynamic>>[], bad = <Map<String, dynamic>>[];
  String stopped = '';
}

class _GrnRegScreenState extends State<GrnRegScreen> {
  Map<String, dynamic>? info, p;
  late GrnChoice ch;
  Map<String, dynamic>? ai;
  String err = '', aiRun = '';
  bool aiStop = false, any = false;
  _RegRun? run;
  StoreKit get k => widget.k;
  String get _mem => '${k.b['site'] ?? ''}|${widget.file}|${widget.size}';

  @override
  void initState() {
    super.initState();
    final m = _regMem[_mem];
    ch = m?.$1 ?? GrnChoice();
    ai = m?.$2;
    _start();
  }

  Future<void> _start() async {
    try {
      final x = await k.call('regInfo');
      if (!mounted) return;
      setState(() {
        info = x;
        _plan();
      });
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  void _plan() {
    p = grnPlan(widget.rows, info!, ch, '${info!['today'] ?? k.today}');
    _regMem[_mem] = (ch, ai);
  }

  void _again() => setState(_plan);
  List<Map<String, dynamic>> _l(String key) => listOf(p?[key]);
  String _n0(num v) => fmtNum(v, maxDecimals: 0);

  /* ---------- the AI: the names in parts (sorted – the same name written differently is mostly near), 4 parts at a time ---------- */
  Future<void> _ai() async {
    final x = ai;
    if (x != null && nOf(x['parts']) > 0 && nOf(x['left']) == 0) ai = null; // all asked before: asked again from the start
    final names = grnNamesOf(widget.rows), inf = info!;
    final a = ai ??= {'party': <List>[], 'item': <List>[], 'category': <List>[], 'parts': 0, 'done': <String, bool>{}};
    final saved = {
      'party': [for (final v in (inf['vendors'] as List? ?? const [])) '$v'],
      'item': [for (final i in (inf['items'] as List? ?? const []).whereType<List>()) '${i[1]}'],
      'category': <String>{for (final i in (inf['items'] as List? ?? const []).whereType<List>()) if ('${i[3] ?? ''}'.isNotEmpty) '${i[3]}'}.toList(),
    };
    const size = {'party': 250, 'item': 200, 'category': 400};
    final jobs = <(String, String, List<(String, int)>, List<String>)>[];
    for (final l in _regAil.keys) {
      final list = grnNamesSorted(names[l]!);
      final sv = [for (final n in saved[l]!) (grnKeyOf(n), n)]..sort((x, y) => x.$1.compareTo(y.$1));
      for (var i = 0; i < list.length; i += size[l]!) {
        final part = list.sublist(i, i + size[l]! > list.length ? list.length : i + size[l]!);
        if (part.length < 2) continue;
        final k1 = grnKeyOf(part.first.$1), k2 = grnKeyOf(part.last.$1);
        jobs.add(('$l:$i', l, part, [for (final z in sv) if (z.$1.compareTo(k1) >= 0 && z.$1.compareTo(k2) <= 0) z.$2].take(300).toList()));
      }
    }
    final done = a['done'] as Map;
    a['parts'] = jobs.length;
    a['err'] = '';
    final todo = [for (final j in jobs) if (done[j.$1] != true) j];
    a['left'] = todo.length;
    aiStop = false;
    var stop = '';
    void show() {
      if (!mounted) return;
      setState(() => aiRun = 'The AI is reading the names – part ${jobs.length - nOf(a['left']).toInt()} of ${jobs.length}');
    }

    show();
    Future<void> one((String, String, List<(String, int)>, List<String>) j) async {
      for (var t = 0; t < 2; t++) {
        try {
          final r = await k.call('regNames', {'list': _regAil[j.$2]!.$1, 'names': [for (final n in j.$3) [n.$1, n.$2]], 'saved': j.$4});
          final rows = {for (final n in j.$3) n.$1: n.$2};
          for (final z in (r['fixes'] as List? ?? const []).whereType<List>()) {
            (a[j.$2] as List).add(['${z[0]}', '${z[1]}', rows['${z[0]}'] ?? 0]);
          }
          done[j.$1] = true;
          a['left'] = nOf(a['left']) - 1;
          return;
        } catch (e) {
          if (t > 0 || RegExp('not accept its key|no credit|not set up', caseSensitive: false).hasMatch(errText(e))) rethrow;
          await Future<void>.delayed(const Duration(seconds: 4));
        }
      }
    }

    Future<void> worker() async {
      while (todo.isNotEmpty && !aiStop && stop.isEmpty) {
        final j = todo.removeAt(0);
        try {
          await one(j);
        } catch (e) {
          stop = errText(e);
        }
        _regMem[_mem] = (ch, ai);
        show();
      }
    }

    await Future.wait([worker(), worker(), worker(), worker()]);
    if (!mounted) return;
    setState(() {
      aiRun = '';
      a['err'] = stop.isNotEmpty ? stop : (aiStop ? 'Stopped – press Go on for the rest' : '');
      _regMem[_mem] = (ch, ai);
    });
    if (stop.isEmpty && !aiStop) toast(context, 'The AI found ${_regAil.keys.fold<int>(0, (s, l) => s + (a[l] as List).length)} name(s) written differently – tick what is the same.');
  }

  /* ---------- IMPORT: suppliers (500 a part), items (1,000), then the GRNs (150 or 3,000 lines a part) – each part whole or not at all ---------- */
  Future<void> _import() async {
    final pl = p!, docs = _l('docs'), dups = _l('dups'), d0 = dups.where((d) => d['gone'] != true).length, sup = _l('newSup'), items = _l('newItems');
    if (docs.isEmpty) return toast(context, 'Nothing to import.');
    if (!await askLines(context, 'Import ${_n0(docs.length)} GRN?', [
      '${_n0(nOf(pl['lines']))} lines, ${rs(pl['gross'])} (${dmy(pl['from'])} to ${dmy(pl['to'])}) – counted in the stock',
      '${_n0(sup.length)} new supplier(s) into the Vendor Master ("Material Supplier"), ${_n0(items.length)} new item(s) into the Item Master',
      'GRN No as in the file; the next new GRN: ${pl['next']}',
      if (d0 > 0) '$d0 duplicate row(s) kept (imported as they are)',
      if (_l('look').isNotEmpty) '${_l('look').length} row(s) to look at are left out',
      if (_l('already').isNotEmpty) '${_n0(_l('already').length)} GRN already in the Store – left out',
    ], note: 'हे सर्व Store मध्ये save होईल. मोठी फाईल असल्याने काही मिनिटे लागतील – हा screen बंद करू नका.', yes: 'Import')) {
      return;
    }
    final r = run = _RegRun()
      ..supOf = sup.length
      ..itemOf = items.length
      ..grnOf = docs.length;
    setState(() {});
    try {
      for (var i = 0; i < sup.length; i += 500) {
        final z = await k.call('regVendors', {'names': [for (final s in sup.skip(i).take(500)) s['name']]});
        r.sup += nOf(z['added']).toInt();
        r.supDone = i + 500 > sup.length ? sup.length : i + 500;
        if (mounted) setState(() {});
      }
      for (var i = 0; i < items.length; i += 1000) {
        final z = await k.call('regItems', {'items': [for (final x in items.skip(i).take(1000)) {'name': x['name'], 'unit': x['unit'], 'category': x['category'], 'gst': x['gst']}]});
        r.items += (z['added'] as List? ?? const []).length;
        r.bad.addAll(listOf(z['bad']));
        r.itemDone = i + 1000 > items.length ? items.length : i + 1000;
        if (mounted) setState(() {});
      }
      var part = <Map<String, dynamic>>[];
      var lines = 0;
      Future<void> send() async {
        final z = await k.call('regGrns', {
          'docs': [
            for (final d in part)
              {'ref': d['ref'], 'date': d['date'], 'supplier': d['supplier'], 'challan_no': d['challan_no'], 'invoice_no': d['invoice_no'], 'invoice_date': d['invoice_date'], 'vehicle_no': d['vehicle_no'], 'lines': d['lines']},
          ],
        });
        r.saved += (z['saved'] as List? ?? const []).length;
        r.skipped += (z['skipped'] as List? ?? const []).length;
        r.errors.addAll(listOf(z['errors']));
        r.grnDone += part.length;
        part = [];
        lines = 0;
        if (mounted) setState(() {});
      }

      for (final d in docs) {
        final n = (d['lines'] as List).length;
        if (part.isNotEmpty && (part.length >= 150 || lines + n > 3000)) await send();
        part.add(d);
        lines += n;
      }
      if (part.isNotEmpty) await send();
      _regMem.remove(_mem);
      any = true;
      if (mounted) toast(context, '${_n0(r.saved)} GRN imported${r.skipped > 0 ? ', ${_n0(r.skipped)} already there' : ''}${r.errors.isNotEmpty ? ', ${r.errors.length} with a mistake' : ''}.');
    } catch (e) {
      r.stopped = errText(e);
      any = any || r.saved > 0 || r.sup > 0 || r.items > 0;
      if (mounted) toast(context, r.stopped, bad: true);
    }
    r.busy = false;
    try {
      info = await k.call('regInfo');
    } catch (_) {/* the check stays as it was */}
    if (mounted) setState(_plan);
  }

  /* ---------- the Excel of the check ---------- */
  Future<void> _excel() async {
    List<Object> row(List<Object?> v) => [for (final x in v) x ?? ''];
    var sr = 0;
    final grn = <List<Object>>[[...grnRegHead, 'Excel line']];
    for (final d in _l('docs')) {
      for (final (i, l) in listOf(d['lines']).indexed) {
        grn.add(row([++sr, d['ref'], dmy(d['date']), i > 0 ? '' : d['challan_no'], i > 0 ? '' : d['invoice_no'], i > 0 ? '' : dmy(d['invoice_date']), i > 0 ? '' : d['vehicle_no'], d['supplier'], l['item'], l['qty'], grnUnit(l['unit']).unit, l['rate'], l['taxable'], l['gst'], l['tcs'],
          r2(nOf(l['taxable']) + nOf(l['gst']) + nOf(l['tcs'])), l['remark'], l['line']]));
      }
    }
    final tabs = [
      XSheet('GRNs to import', grn, head: 1),
      XSheet('Rows to look at', [row(['Excel line', 'GRN No', 'GRN Date', 'Supplier', 'Material', 'Qty', 'Why']), for (final l in _l('look')) row([l['line'], l['ref'], dmy(l['date']), l['party'], l['item'], l['qty'], (l['why'] as List).join('; ')])], head: 1),
      XSheet('Duplicate rows', [
        row(['Excel line', 'Same as line', 'GRN No', 'GRN Date', 'Supplier', 'Material', 'Qty', 'Gross', 'Deleted']),
        for (final d in _l('dups')) row([d['line'], d['first'], (d['row'] as Map)['ref'], dmy((d['row'] as Map)['date']), (d['row'] as Map)['party'], (d['row'] as Map)['item'], (d['row'] as Map)['qty'], (d['row'] as Map)['gross'], d['gone'] == true ? 'Yes' : '']),
      ], head: 1),
      XSheet('Notes', [row(['Excel line', 'GRN No', 'Note']), for (final z in _l('notes')) row([z['line'], z['ref'], z['msg']])], head: 1),
      XSheet('New suppliers', [row(['Supplier', 'Rows']), for (final s in _l('newSup')) row([s['name'], s['rows']])], head: 1),
      XSheet('New items', [row(['Item', 'Unit', 'Category', 'GST %', 'Rows']), for (final i in _l('newItems')) row([i['name'], i['unit'], i['category'], i['gst'], i['rows']])], head: 1),
      if (ai != null)
        XSheet('Names (AI)', [
          row(['List', 'In the file', 'Right spelling', 'Rows', 'Ticked']),
          for (final l in _regAil.keys)
            for (final z in (ai![l] as List? ?? const []).whereType<List>()) row([_regAil[l]!.$2, z[0], z[1], z[2], ch.fix[l]![z[0]] == z[1] ? 'Yes' : '']),
        ], head: 1),
      XSheet('Already in the Store', [row(['GRN No', 'GRN Date', 'Supplier', 'Invoice No']), for (final d in _l('already')) row([d['ref'], dmy(d['date']), d['supplier'], d['invoice_no']])], head: 1),
    ];
    try {
      await shareXlsx(sheetsXlsx(tabs), 'Inward_register_check_${k.today}.xlsx');
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  /* ---------- a row to look at: what is missing typed ---------- */
  Future<void> _edit(Map<String, dynamic> l) async {
    final line = nOf(l['line']).toInt(), e = ch.edit[line] ?? const <String, String>{};
    var date = e['date'] ?? '${l['date'] ?? ''}';
    final sup = TextEditingController(text: e['party'] ?? '${l['party'] ?? ''}'), item = TextEditingController(text: e['item'] ?? '${l['item'] ?? ''}'), qty = TextEditingController(text: e['qty'] ?? '${l['qty'] ?? ''}');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Line $line${'${l['ref'] ?? ''}'.isNotEmpty ? ' · GRN ${l['ref']}' : ''}', style: _bold),
            Text((l['why'] as List).join(' · '), style: const TextStyle(fontSize: 13, color: C.red)),
            const SizedBox(height: 10),
            DateField(key: const Key('rge-date'), label: 'GRN date', value: date, onChanged: (v) => set(() => date = v)),
            const SizedBox(height: 8),
            TextBox(key: const Key('rge-sup'), label: 'Supplier', controller: sup, options: k.names('suppliers')),
            const SizedBox(height: 8),
            TextBox(key: const Key('rge-item'), label: 'Material', controller: item),
            const SizedBox(height: 8),
            TextBox(key: const Key('rge-qty'), label: 'Received Qty', controller: qty, kb: _dec),
            const SizedBox(height: 12),
            FilledButton(key: const Key('rge-ok'), onPressed: () => Navigator.pop(c, true), child: Text('Check this row again')),
          ]),
        ),
      ),
    );
    if (ok == true) {
      final x = ch.edit[line] = {...e};
      void put(String key, String v, String was) {
        if (v.trim() != was) x[key] = v.trim();
      }

      put('date', date, '${l['date'] ?? ''}');
      put('party', sup.text, '${l['party'] ?? ''}');
      put('item', item.text, '${l['item'] ?? ''}');
      put('qty', qty.text, '${l['qty'] ?? ''}');
      _again();
    }
  }

  Widget _stat(String key, String label, String n, String sub, Color c) => Container(
        key: Key(key),
        width: 158,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 4, color: c),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
              Text(n, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text(sub, style: const TextStyle(fontSize: 11.5, color: C.muted, height: 1.3)),
            ]),
          ),
        ]),
      );

  Widget _sec(String key, String title, int n, List<Widget> body, {bool open = false}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
        child: ExpansionTile(
          key: PageStorageKey(key),
          initiallyExpanded: open,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))), Pill(_n0(n), key: Key('$key-n'), color: n > 0 ? C.amber : C.muted, bg: n > 0 ? C.amberSoft : C.slateSoft)]),
          children: body,
        ),
      );

  /// a long list: the first [max] rows, the rest in the Excel of the check
  List<Widget> _first(List<Map<String, dynamic>> l, Widget Function(Map<String, dynamic>) f, {int max = 150}) => [
        for (final x in l.take(max)) f(x),
        if (l.length > max) Padding(padding: const EdgeInsets.only(top: 4), child: Text('… ${_n0(l.length - max)} more – every one in "Excel of the check"', style: _muted)),
        if (l.isEmpty) Text('None.', style: _muted),
      ];

  Widget _runCard(_RegRun r) {
    Widget bar(String t, int a, int n) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('$t – ${_n0(a)} of ${_n0(n)}', style: _muted),
            const SizedBox(height: 3),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: n == 0 ? 1 : a / n, minHeight: 8, color: C.green, backgroundColor: C.slateSoft)),
          ]),
        );
    return _card(key: const Key('rg-run'), color: C.slateSoft, children: [
      Text(r.busy ? 'Importing … (keep this screen open)' : r.stopped.isNotEmpty ? 'Stopped' : 'Imported', style: _bold),
      bar('Suppliers', r.supDone, r.supOf),
      bar('Items', r.itemDone, r.itemOf),
      bar('GRNs', r.grnDone, r.grnOf),
      const SizedBox(height: 6),
      Text('${_n0(r.sup)} supplier(s) and ${_n0(r.items)} item(s) made · ${_n0(r.saved)} GRN saved${r.skipped > 0 ? ' · ${_n0(r.skipped)} already in the Store (left out)' : ''}${r.errors.isNotEmpty ? ' · ${r.errors.length} GRN with a mistake (not saved)' : ''}',
          key: const Key('rg-run-sum'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      if (r.stopped.isNotEmpty) InfoLine('${r.stopped} – press Import again: what is saved already is left (never twice), the rest goes on.', bad: true),
      for (final z in r.errors.take(50)) Text('GRN ${z['ref']}: ${z['msg']}', style: const TextStyle(fontSize: 12.5, color: C.red)),
      if (r.bad.isNotEmpty) Text('Items not made: ${r.bad.take(10).map((z) => '${z['name']} (${z['msg']})').join('; ')}', style: _muted),
      const SizedBox(height: 6),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pl = p, inf = info;
    return PopScope(
      canPop: false, // (back: the GRN list is shown again when something was imported; not while the import runs)
      onPopInvokedWithResult: (did, _) {
        if (did || (run?.busy ?? false)) return;
        Navigator.of(context).pop(any);
      },
      child: Scaffold(
        appBar: AppBar(actions: withAsk(), title: Text('Import the inward register')),
        body: pl == null || inf == null
            ? (err.isEmpty ? _loading() : ListView(padding: const EdgeInsets.all(16), children: [InfoLine(err, bad: true)]))
            : _body(pl, inf),
        bottomNavigationBar: pl == null || inf == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(key: const Key('rg-xl'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: _excel, child: Text('Excel of the check'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: FilledButton(
                            key: const Key('rg-go'),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                            onPressed: inf['step3'] != true || _l('docs').isEmpty || (run?.busy ?? false) || aiRun.isNotEmpty ? null : _import,
                            child: Text((run?.busy ?? false) ? 'Importing…' : 'Import ${_n0(_l('docs').length)} GRN'))),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> pl, Map<String, dynamic> inf) {
    final dups = _l('dups'), kept = dups.where((d) => d['gone'] != true).length, look = _l('look'), a = ai;
    final aiN = a == null ? 0 : _regAil.keys.fold<int>(0, (s, l) => s + (a[l] as List? ?? const []).length);
    final ticked = _regAil.keys.fold<int>(0, (s, l) => s + (ch.fix[l]?.length ?? 0));
    return ListView(key: const Key('rg-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
      Text('${widget.file} · sheet "${widget.sheet.name}" – ${_n0(widget.rows.length)} rows${widget.sheet.others.isNotEmpty ? ' (the other sheets – ${widget.sheet.others.take(6).join(', ')}${widget.sheet.others.length > 6 ? ' …' : ''} – are not the register)' : ''}. Nothing is saved until Import.',
          key: const Key('rg-head'), style: _muted),
      Text('काहीही save झालेले नाही – खालची यादी तपासा, मग Import दाबा.', style: _muted),
      if (inf['step3'] != true)
        InfoLine('The Store\'s database step 3 is not run in this site yet: the Admin runs sql/store_step3_grn_import.sql once in Supabase → SQL Editor (in every site). Until then the check can be seen, Import cannot be done.', bad: true),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _stat('rg-t-docs', 'GRNs to import', _n0(_l('docs').length), '${_n0(nOf(pl['lines']))} lines · ${rs(pl['gross'])}${'${pl['from']}'.isNotEmpty ? ' · ${dmy(pl['from'])} to ${dmy(pl['to'])}' : ''}', C.green),
        _stat('rg-t-have', 'Already in the Store', _n0(_l('already').length), 'left out – never twice', C.muted),
        _stat('rg-t-sup', 'New suppliers', _n0(_l('newSup').length), 'into the Vendor Master (Material Supplier)', C.blue),
        _stat('rg-t-items', 'New items', _n0(_l('newItems').length), 'into the Item Master', C.blue),
        _stat('rg-t-dups', 'Duplicate rows', _n0(dups.length), '$kept kept (imported) · ${dups.length - kept} deleted', kept > 0 ? C.amber : C.muted),
        _stat('rg-t-look', 'Rows to look at', _n0(look.length), 'left out until corrected', look.isNotEmpty ? C.amber : C.muted),
        _stat('rg-t-next', 'Next new GRN', '${pl['next']}', 'goes on after the file\'s ${nOf(pl['maxRef']) > 0 ? pl['maxRef'] : '–'}', C.green),
      ]),
      const SizedBox(height: 8),
      if (nOf(pl['noRef']) > 0)
        InfoLine('${pl['noRef']} GRN(s) of the file have no GRN No – they get the numbers ${pl['first']}${nOf(pl['noRef']) > 1 ? ' to ${nOf(pl['first']) + nOf(pl['noRef']) - 1}' : ''}.'),
      if (_l('empty').isNotEmpty) Text('${_n0(_l('empty').length)} row(s) have only a GRN No, date or supplier (no material, quantity or amount) – nothing to import there.', style: _muted),
      if (run != null) _runCard(run!),
      const SizedBox(height: 6),
      _sec('rg-s-look', 'Rows to look at – correct here, else they are left out', look.length, [
        Text('Type what is missing (the row is then checked again). तपासायच्या ओळी – इथेच दुरुस्त करा, नाहीतर त्या import होणार नाहीत.', style: _muted),
        const SizedBox(height: 6),
        ..._first(look, (l) => _card(key: Key('rg-lk-${l['line']}'), children: [
              Text('Line ${l['line']}${'${l['ref'] ?? ''}'.isNotEmpty ? ' · GRN ${l['ref']}' : ''}${'${l['date'] ?? ''}'.isNotEmpty ? ' · ${dmy(l['date'])}' : ''}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              Text([l['party'], l['item'], if ('${l['qty'] ?? ''}'.isNotEmpty) 'Qty ${l['qty']}'].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 13.5)),
              Wrap(spacing: 4, runSpacing: 4, children: [for (final w in l['why'] as List) Pill('$w', color: C.red, bg: C.redSoft)]),
              Align(alignment: Alignment.centerLeft, child: _act('rg-lke-${l['line']}', 'Correct this row', () => _edit(l), color: C.blue)),
            ])),
      ], open: look.isNotEmpty),
      _sec('rg-s-dup', 'Duplicate rows – the same row twice in the file', dups.length, [
        Text('Every column the same as an earlier row. Delete what is a mistake; what you do not delete is imported as it is. Duplicate ओळी – चुकीची असेल ती Delete करा; Delete न केलेली तशीच save होईल.', style: _muted),
        Wrap(spacing: 8, children: [
          _act('rg-dupall', 'Delete all duplicates', dups.isEmpty
              ? null
              : () async {
                  if (!await ask(context, 'Delete all ${dups.length} duplicate rows?', bi('Each row that is the same as an earlier row is left out of the import (the earlier one is imported).', 'सर्व duplicate ओळी वगळल्या जातील.'), yes: 'Delete all', danger: true)) return;
                  for (final d in dups) {
                    ch.gone[nOf(d['line']).toInt()] = true;
                  }
                  _again();
                }, color: C.red),
          _act('rg-dupnone', 'Keep all', () {
            ch.gone.clear();
            _again();
          }, color: C.blue),
        ]),
        ..._first(dups, (d) {
          final r = d['row'] as Map, gone = d['gone'] == true, line = nOf(d['line']).toInt();
          return _card(key: Key('rg-dp-$line'), color: gone ? C.slateSoft : Colors.white, children: [
            Text('Line $line = line ${d['first']} · GRN ${r['ref'] ?? r['refText'] ?? ''} · ${dmy(r['date'])}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text('${r['party']} · ${r['item']} · Qty ${r['qty'] is num ? q3(r['qty']) : r['qty']}${r['gross'] is num ? ' · ${rs(r['gross'])}' : ''}', style: const TextStyle(fontSize: 13.5)),
            Row(children: [
              if (gone) const Pill('Deleted', color: C.muted, bg: C.slateSoft),
              const Spacer(),
              _act('rg-dup-$line', gone ? 'Undo' : 'Delete', () {
                if (gone) {
                  ch.gone.remove(line);
                } else {
                  ch.gone[line] = true;
                }
                _again();
              }, color: gone ? C.blue : C.red),
            ]),
          ]);
        }),
      ], open: dups.isNotEmpty),
      _sec('rg-s-ai', 'Names written in more than one way (the AI) – tick what is the same', aiN, [
        if (inf['ai'] != true)
          InfoLine('The AI is not set up for the Store (ANTHROPIC_API_KEY in Vercel → rcl-store → Environment Variables) – the names stay as in the file (a name with the same letters – "Oil-Filter", "OIL FILTER" – is one already).')
        else ...[
          Text('The AI reads the suppliers, items and categories of the file and lists the ones written differently. Tick (✓) what is the same thing – it is then saved with the right spelling. What is not ticked stays as in the file.${aiN > 0 ? ' $ticked ticked.' : ''}', style: _muted),
          const SizedBox(height: 6),
          if (aiRun.isNotEmpty)
            Row(children: [Expanded(child: Text(aiRun, key: const Key('rg-airun'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.amber))), _act('rg-aistop', 'Stop', () => aiStop = true, color: C.red)])
          else
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                    key: const Key('rg-ai'),
                    onPressed: (run?.busy ?? false) ? null : _ai,
                    child: Text(a != null && nOf(a['parts']) > 0 ? (nOf(a['left']) > 0 ? 'Go on with the AI (${a['left']} parts left)' : 'Ask the AI again') : 'Find them with the AI'))),
          if ('${a?['err'] ?? ''}'.isNotEmpty) InfoLine('${a!['err']}', bad: true),
          for (final l in _regAil.keys)
            if (a != null && (a[l] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text('${_regAil[l]!.$2} · ${(a[l] as List).length}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
                _act('rg-aiall-$l', '✓ all', () {
                  ch.fix[l] = {for (final z in (a[l] as List).whereType<List>()) '${z[0]}': '${z[1]}'};
                  _again();
                }, color: C.blue),
                _act('rg-ainone-$l', 'None', () {
                  ch.fix[l] = {};
                  _again();
                }, color: C.blue),
              ]),
              for (final z in (a[l] as List).whereType<List>().take(300))
                CheckboxListTile(
                  key: Key('rg-ai-$l-${z[0]}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: ch.fix[l]?[z[0]] == z[1],
                  onChanged: (v) {
                    if (v == true) {
                      (ch.fix[l] ??= {})['${z[0]}'] = '${z[1]}';
                    } else {
                      ch.fix[l]?.remove('${z[0]}');
                    }
                    _again();
                  },
                  title: Text('${z[0]}  →  ${z[1]}', style: const TextStyle(fontSize: 13.5)),
                  subtitle: Text('${z[2]} row(s)', style: _faint),
                ),
            ],
        ],
      ]),
      _sec('rg-s-sup', 'New suppliers – into the Vendor Master as "Material Supplier" (GST, PAN, Aadhaar to fill later)', _l('newSup').length,
          _first(_l('newSup'), (s) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${s['name']} · ${s['rows']} row(s)', style: const TextStyle(fontSize: 13.5))))),
      _sec('rg-s-items', 'New items – into the Item Master', _l('newItems').length, [
        Text('Unit: the one most of its rows have; category: its Remark when that is used in 20 rows or more, else General; GST %: the usual one of its rows. All can be changed later in the Item Master.', style: _muted),
        const SizedBox(height: 4),
        ..._first(_l('newItems'), (i) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${i['name']} · ${i['unit']} · ${i['category']}${'${i['gst']}'.isNotEmpty ? ' · GST ${i['gst'] is num ? q3(i['gst']) : i['gst']}%' : ''} · ${i['rows']} row(s)', style: const TextStyle(fontSize: 13.5)))),
      ]),
      _sec('rg-s-notes', 'Notes – imported as the file has them', _l('notes').length,
          _first(_l('notes'), (z) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Line ${z['line']}${'${z['ref'] ?? ''}'.isNotEmpty ? ' · GRN ${z['ref']}' : ''}: ${z['msg']}', style: TextStyle(fontSize: 13, color: z['big'] == true ? C.amber : C.ink, fontWeight: z['big'] == true ? FontWeight.w700 : FontWeight.w400))))),
      _sec('rg-s-have', 'Already in the Store – left out', _l('already').length,
          _first(_l('already'), (d) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('GRN ${d['ref']} · ${dmy(d['date'])} · ${d['supplier']}', style: const TextStyle(fontSize: 13.5))))),
      if (any) Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton(key: const Key('rg-close'), onPressed: () => Navigator.pop(context, true), child: Text('Show the GRNs'))),
    ]);
  }
}
