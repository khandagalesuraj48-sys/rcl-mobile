/* STORE – the app's own screens (3.10.0) of the Store module (Home → Store): its Dashboard and the Item Master of this site, by
 * the pages the Portal gave (Store Admin / Store User). The Store's own sign-in (a Portal ticket, used once) and its own server
 * (rcl-store: api/items – list, check, save, remove); the same rules: a name only once at a site, a near name asked first ("is
 * it the same item?"), a near category asked, a proper name suggested; change and delete by the Store Admin; Export to Excel.
 * (3.54.0, the Store's step 2) the Work tab: the pages of the Store's work (store_work.dart – api/work) as he was given them;
 * the Dashboard shows their figures (stock value, below min stock, waiting for my approval, POs open, GRN / issues today). */
import 'package:flutter/material.dart' hide Text;

import '../core/api.dart' show ApiError;
import '../core/format.dart';
import '../core/lb_io.dart' show XSheet;
import '../core/more_imports.dart' show storeImportRows, asShown;
import '../core/rdoc.dart';
import '../core/sheet_read.dart' show readSheets, isZipSheet, SheetError;
import '../core/xlsx.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/pick_file.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/ask_bot.dart';
import 'store_work.dart';

/// The columns of the web's item files (Export, Import template).
const kStoreHead = ['Item Code', 'Item Name', 'Unit', 'Category', 'HSN Code', 'GST %', 'Min Stock', 'Status'];

Future<void> openStore(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StoreScreen()));

String _num(Object? v) {
  if (v == null || v == '') return '';
  final n = num.tryParse('$v');
  if (n == null) return '$v';
  return n == n.truncateToDouble() ? '${n.toInt()}' : '$n';
}

/// The Store's dashboard as the web works it out from the items: counts, recently added, items by category.
({int all, int active, int cats, int newMonth, List<Map> recent, List<(String, int, int)> byCat}) storeDash(List<Map> items, DateTime now) {
  final month = now.toUtc().add(const Duration(minutes: 330)).toIso8601String().substring(0, 7);
  final cats = <String, (int, int)>{};
  for (final i in items) {
    final c = '${i['category'] ?? ''}', x = cats[c] ?? (0, 0);
    cats[c] = (x.$1 + 1, x.$2 + (i['status'] == 'Active' ? 1 : 0));
  }
  final recent = [...items]..sort((a, b) => '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));
  return (
    all: items.length,
    active: items.where((i) => i['status'] == 'Active').length,
    cats: cats.length,
    newMonth: items.where((i) => '${i['created_at'] ?? ''}'.length >= 7 && '${i['created_at']}'.substring(0, 7) == month).length,
    recent: recent.take(8).toList(),
    byCat: [for (final c in cats.keys.toList()..sort()) (c, cats[c]!.$1, cats[c]!.$2)],
  );
}

/// The Item Master as the web's Excel (Export to Excel).
RDoc storeItemsDoc(List<Map> items, String day) => RDoc(
      title: 'Items',
      file: 'Items_$day',
      blocks: [
        RTable(
          sheet: 'Items',
          head: kStoreHead,
          numCols: const {5, 6},
          rows: [
            for (final i in items)
              RRow([
                RCell('${i['code'] ?? ''}'),
                RCell('${i['name'] ?? ''}'),
                RCell('${i['unit'] ?? ''}'),
                RCell('${i['category'] ?? ''}'),
                RCell('${i['hsn'] ?? ''}'),
                RCell(_num(i['gst_pct']), n: true, value: num.tryParse('${i['gst_pct'] ?? ''}')),
                RCell(_num(i['min_stock']), n: true, value: num.tryParse('${i['min_stock'] ?? ''}')),
                RCell('${i['status'] ?? ''}'),
              ]),
          ],
        ),
      ],
    );

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.find = '', this.items = false});

  /// (3.14.0) opened by the search on the Item Master ([items]), with this item code in the search box (the Store's rclModule.open)
  final String find;
  final bool items;
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  Map<String, dynamic>? me;
  List<Map<String, dynamic>> items = [];
  List<String> units = [], cats = [];
  String err = '', q = '', fCat = '', fSt = '', dashErr = '';
  bool loading = true, started = false;
  /// (3.54.0) the Store's work: what he may do there, its figures
  StoreKit? kit;
  Map<String, dynamic>? dash;
  late final qc = TextEditingController(text: widget.find);

  @override
  void initState() {
    super.initState();
    q = widget.find;
  }

  @override
  void dispose() {
    qc.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  String get _url => SessionScope.read(context).site?.module('store')?.url ?? '';
  String get _site => SessionScope.read(context).site?.code ?? '';

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) => SessionScope.read(context).api.store(_site, _url, body);

  Future<void> _start() async {
    final s = SessionScope.read(context);
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final site = _site, url = _url;
      final m = await s.api.storeOpen(site, url);
      if (!mounted) return;
      setState(() {
        me = m;
        kit = StoreKit(call: (a, [x]) => s.api.store(site, url, {'action': a, ...?x}, path: 'work'), pages: (m['pages'] as Map?) ?? const {}, admin: (m['user'] as Map?)?['admin'] == true, superAdmin: (m['user'] as Map?)?['super'] == true);
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  Map get _pages => (me?['pages'] as Map?) ?? const {'dashboard': 'View', 'items': 'Edit'};
  bool get _admin => (me?['user'] as Map?)?['admin'] == true;

  /// (3.54.0) the figures of the Store's work (none while the site's database has not its step 2: said on the Dashboard)
  Future<void> _loadDash() async {
    final k = kit;
    if (k == null || (!k.anyWork && _pages['dashboard'] == 'None')) return;
    try {
      final d = await k.call('dash');
      if (mounted) {
        setState(() {
          dash = d;
          dashErr = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => dashErr = e is ApiError && e.code == 'notinstalled' ? e.message : '');
    }
  }

  Future<void> _load() async {
    _loadDash();
    try {
      final r = await _call({'action': 'list'});
      if (!mounted) return;
      setState(() {
        items = [for (final i in (r['items'] as List? ?? const []).whereType<Map>()) i.cast<String, dynamic>()];
        units = [for (final u in (r['units'] as List? ?? const [])) '$u'];
        cats = [for (final c in (r['categories'] as List? ?? const [])) '$c'];
        loading = false;
        err = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _form([Map<String, dynamic>? it]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ItemFormScreen(item: it, units: units, cats: cats, call: _call)));
    if (saved == true) _load();
  }

  Future<void> _delete(Map it) async {
    if (!await ask(context, 'Delete ${it['code']}?', '${it['name']} (${it['unit']}, ${it['category']}) is taken out of the Item Master.', yes: 'Delete', danger: true)) return;
    try {
      await _call({'action': 'remove', 'code': it['code']});
      if (!mounted) return;
      toast(context, '${it['code']} deleted.');
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  Future<void> _export() async {
    final day = dateKey(DateTime.now());
    await shareXlsx(reportXlsx(storeItemsDoc(items, day), const []), 'Items_$day.xlsx');
    if (mounted) toast(context, 'Exported ${items.length} items.');
  }

  /// (3.13.0) Import template – the web's b_tpl: the headings and one example row.
  Future<void> _template() async {
    try {
      await shareXlsx(
          sheetsXlsx([
            XSheet('Items', [kStoreHead, ['', 'Hydraulic Hose 1/2 inch', 'Mtr', 'Spare Parts', '40092100', 18, 10]], widths: const [10, 40, 8, 22, 12, 8, 10, 10]),
          ]),
          'Items_template.xlsx');
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  /// (3.13.0) Import from Excel – the web's f_file: the first tab, the cells as the sheet shows them, the heading row found by its
  /// names ("Item Code" of the file is not used – the next codes are given); then the check, row by row, before anything is saved.
  Future<void> _import() async {
    final f = await pickSheetFile();
    if (f == null || !mounted) return;
    List<Map<String, Object?>> rows;
    try {
      rows = storeImportRows(isZipSheet(f.bytes) ? asShown(readSheets(f.bytes)) : readSheets(f.bytes, shown: true));
    } on SheetError catch (e) {
      toast(context, e.message, bad: true);
      return;
    } catch (_) {
      toast(context, 'Could not read the file.', bad: true);
      return;
    }
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => StoreImportScreen(rows: rows, call: _call)));
    if (done == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), pg = _pages;
    final tabs = [if (pg['dashboard'] != 'None') 'dashboard', if (kit?.anyWork == true) 'work', if (pg['items'] != 'None') 'items'];
    return DefaultTabController(
      length: tabs.isEmpty ? 1 : tabs.length,
      initialIndex: (widget.find.isNotEmpty || widget.items) && tabs.contains('items') ? tabs.indexOf('items') : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const TwoLang('Store', 'स्टोअर', size: 20, weight: FontWeight.w700),
          actions: withAsk([IconButton(tooltip: tr('Refresh'), onPressed: me == null ? _start : _load, icon: const Icon(Icons.refresh_rounded))]),
          bottom: me == null || tabs.length < 2
              ? null
              : TabBar(labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5), tabs: [
                  for (final t in tabs) Tab(key: Key('st-tab-$t'), child: Text(t == 'dashboard' ? 'Dashboard' : t == 'work' ? 'Work' : 'Item Master')),
                ]),
        ),
        // (3.55.0) "Add item" – not on the Work tab (its pages have their own)
        floatingActionButton: me != null && pg['items'] == 'Edit'
            ? Builder(builder: (c) {
                final tc = DefaultTabController.of(c);
                return AnimatedBuilder(
                  animation: tc,
                  builder: (_, __) => tc.index < tabs.length && tabs[tc.index] == 'work'
                      ? const SizedBox.shrink()
                      : FloatingActionButton.extended(
                          key: const Key('st-new'),
                          onPressed: () => _form(),
                          backgroundColor: C.green,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: const StadiumBorder(),
                          icon: const Icon(Icons.add_rounded, size: 26),
                          label: const Text('Add item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                );
              })
            : null,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : me == null || tabs.isEmpty
                ? ListView(padding: const EdgeInsets.all(16), children: [
                    if (err.isNotEmpty) InfoLine(err, bad: true),
                    if (me != null && tabs.isEmpty) InfoLine('You have no page of the Store on this site – ask the Super Admin.', bad: true),
                  ])
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(children: [
                        Expanded(child: Text('${(me?['user'] as Map?)?['name'] ?? s.name} · ${_admin ? 'Store Admin' : 'Store User'} · ${me?['siteName'] ?? s.siteName}', style: const TextStyle(fontSize: 12.5, color: C.muted))),
                      ]),
                    ),
                    if (err.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: InfoLine(err, bad: true)),
                    Expanded(child: TabBarView(children: [for (final t in tabs) t == 'dashboard' ? _dash() : t == 'work' ? StoreWorkTab(k: kit!, dash: dash, err: dashErr, back: _loadDash) : _items()])),
                  ]),
      ),
    );
  }

  Widget _dash() {
    final d = storeDash(items, DateTime.now());
    Widget tile(String label, int n, String sub, Color c, Color bg) => Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
            Text('$n', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c)),
            Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
          ]),
        );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(key: const Key('st-dash'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 90), children: [
        if (dashErr.isNotEmpty) InfoLine(dashErr, bad: true),
        if (dash != null) ...[StoreDashWork(dash: dash!), const SizedBox(height: 16), Text('Item Master', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), const SizedBox(height: 6)],
        Wrap(spacing: 8, runSpacing: 8, children: [
          tile('Items', d.all, 'in the Item Master', C.ink, Colors.white),
          tile('Active', d.active, 'can be used', C.greenDark, C.greenSoft),
          tile('Inactive', d.all - d.active, 'switched off', C.muted, C.slateSoft),
          tile('Categories', d.cats, 'kinds of items', C.blue, C.blueSoft),
          tile('Added this month', d.newMonth, 'new items', C.amber, C.amberSoft),
        ]),
        const SizedBox(height: 16),
        Text('Recently added items', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (d.recent.isEmpty) Text('No item yet.', style: const TextStyle(color: C.muted)),
        for (final i in d.recent)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${i['code']} · ${i['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${i['unit']} · ${i['category']} · added ${showDate('${i['created_at'] ?? ''}'.length >= 10 ? '${i['created_at']}'.substring(0, 10) : '')}'),
          ),
        const SizedBox(height: 12),
        Text('Items by category', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (d.byCat.isEmpty) Text('–', style: const TextStyle(color: C.muted)),
        for (final c in d.byCat)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(c.$1, style: const TextStyle(fontWeight: FontWeight.w600))),
              Pill('${c.$2} ${c.$2 == 1 ? 'item' : 'items'}', color: C.slate, bg: C.slateSoft),
              const SizedBox(width: 6),
              Pill('${c.$3} active', color: C.greenDark, bg: C.greenSoft),
            ]),
          ),
      ]),
    );
  }

  Widget _items() {
    final x = q.toLowerCase();
    final list = items.where((i) => (fCat.isEmpty || i['category'] == fCat) && (fSt.isEmpty || i['status'] == fSt) && (x.isEmpty || [i['code'], i['name'], i['category'], i['hsn']].join(' ').toLowerCase().contains(x))).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(key: const Key('st-items'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 90), children: [
        Text('The items of this site. A name is there once: a name that is nearly the same as one already there is asked about first.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        const SizedBox(height: 8),
        TextField(key: const Key('st-q'), controller: qc, onChanged: (v) => setState(() => q = v.trim()), decoration: InputDecoration(hintText: tr('Item name, code, category, HSN'), prefixIcon: const Icon(Icons.search_rounded), isDense: true)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: PickField(key: const Key('st-cat'), label: 'Category', value: fCat, items: cats, blank: 'All', onChanged: (v) => setState(() => fCat = v))),
          const SizedBox(width: 8),
          Expanded(child: PickField(key: const Key('st-st'), label: 'Status', value: fSt, items: const ['Active', 'Inactive'], blank: 'All', onChanged: (v) => setState(() => fSt = v))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('${list.length} of ${items.length} items', key: const Key('st-count'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          OutlinedButton.icon(key: const Key('st-export'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 12)), onPressed: _export, icon: const Icon(Icons.table_view_rounded), label: Text('Export to Excel')),
        ]),
        if (_admin)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(key: const Key('st-import'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 10)), onPressed: _import, icon: const Icon(Icons.upload_file_rounded), label: Text('Import from Excel'))),
              const SizedBox(width: 8),
              TextButton.icon(key: const Key('st-tpl'), style: TextButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: _template, icon: const Icon(Icons.download_rounded), label: Text('Import template')),
            ]),
          ),
        const SizedBox(height: 8),
        if (list.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(items.isEmpty ? 'No item yet – press "+ Add item".' : 'No item for this search.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
        for (final i in list) _itemTile(i),
      ]),
    );
  }

  Widget _itemTile(Map<String, dynamic> i) {
    final off = i['status'] == 'Inactive';
    return Container(
      key: Key('st-${i['code']}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: off ? C.slateSoft : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i['name']}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              Text('${i['code']} · ${i['unit']} · ${i['category']}${'${i['hsn'] ?? ''}'.isNotEmpty ? ' · HSN ${i['hsn']}' : ''}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
              Text([if (_num(i['gst_pct']).isNotEmpty) 'GST ${_num(i['gst_pct'])}%', if (_num(i['min_stock']).isNotEmpty) 'Min stock ${_num(i['min_stock'])}', if ('${i['created_by'] ?? ''}'.isNotEmpty) '${i['created_by']}'].join(' · '), style: const TextStyle(fontSize: 12, color: C.faint)),
              if ('${i['similar_note'] ?? ''}'.isNotEmpty) Text('near another name – confirmed different', style: const TextStyle(fontSize: 12, color: C.amber)),
            ]),
          ),
          off ? Pill('Inactive', color: C.muted, bg: Colors.white) : Pill('Active', color: C.greenDark, bg: C.greenSoft),
        ]),
        if (_admin)
          Wrap(spacing: 8, children: [
            TextButton(key: Key('st-edit-${i['code']}'), onPressed: () => _form(i), child: Text('Edit')),
            TextButton(key: Key('st-del-${i['code']}'), onPressed: () => _delete(i), child: Text('Delete', style: const TextStyle(color: C.red))),
          ]),
      ]),
    );
  }
}

/// Add one item or change one (the Store Admin) – the web's save: a proper name suggested, the same name refused, a near name
/// asked ("is it the same item?"), a near category asked.
class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({super.key, this.item, required this.units, required this.cats, required this.call});
  final Map<String, dynamic>? item;
  final List<String> units, cats;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) call;
  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final name = TextEditingController(), cat = TextEditingController(), hsn = TextEditingController(), gst = TextEditingController(), minS = TextEditingController();
  String unit = '', status = 'Active', hint = '', proper = '';
  Color hintColor = C.muted;
  bool busy = false;
  DateTime _typed = DateTime(0);

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      name.text = '${it['name'] ?? ''}';
      unit = '${it['unit'] ?? ''}';
      cat.text = '${it['category'] ?? ''}';
      hsn.text = '${it['hsn'] ?? ''}';
      gst.text = _num(it['gst_pct']);
      minS.text = _num(it['min_stock']);
      status = '${it['status'] ?? 'Active'}';
    }
  }

  @override
  void dispose() {
    for (final c in [name, cat, hsn, gst, minS]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _code => '${widget.item?['code'] ?? ''}';

  /// While typing a name: the names already there that are near it (said at once; the save asks again).
  void _typedName() {
    final at = _typed = DateTime.now();
    Future<void>.delayed(const Duration(milliseconds: 450), () async {
      if (!mounted || at != _typed) return;
      final n = name.text.trim();
      if (n.length < 3) {
        setState(() => hint = proper = '');
        return;
      }
      try {
        final r = await widget.call({'action': 'check', 'name': n, 'category': cat.text, 'code': _code});
        if (!mounted || name.text.trim() != n) return;
        final ex = r['exact'] as Map?, sim = (r['similar'] as List? ?? const []).whereType<Map>().toList(), p = '${((r['proper'] as Map?) ?? const {})['name'] ?? n}';
        setState(() {
          proper = '';
          if (ex != null) {
            hint = 'Already there: ${ex['code']} ${ex['name']}';
            hintColor = C.red;
          } else if (sim.isNotEmpty) {
            hint = 'Near: ${sim.map((y) => '${y['code']} ${y['name']}').join(', ')}';
            hintColor = C.amber;
          } else if (p != n) {
            hint = 'Suggested: $p';
            hintColor = C.blue;
            proper = p;
          } else {
            hint = '';
          }
        });
      } catch (_) {/* the save checks anyway */}
    });
  }

  Future<void> _save() async {
    final it = <String, dynamic>{'name': name.text, 'unit': unit, 'category': cat.text, 'hsn': hsn.text, 'gst': gst.text, 'minStock': minS.text, 'status': status};
    if (name.text.trim().isEmpty) return toast(context, 'Enter the item name.', bad: true);
    setState(() => busy = true);
    try {
      final chk = await widget.call({'action': 'check', 'name': it['name'], 'category': it['category'], 'code': _code});
      final pr = (chk['proper'] as Map?) ?? const {}, pn = '${pr['name'] ?? ''}';
      if (!mounted) return;
      if (pn.isNotEmpty && pn != '${it['name']}'.trim().replaceAll(RegExp(r'\s+'), ' ')) {
        final fixes = [for (final f in (pr['fixes'] as List? ?? const [])) '$f'];
        final v = await _choose('A proper name', ['You typed: ${it['name']}', 'Suggested: $pn', if (fixes.isNotEmpty) 'Spelling: ${fixes.join(', ')}'], [('mine', 'Keep mine'), ('use', 'Use "$pn"')]);
        if (v == null) return;
        if (v == 'use') {
          it['name'] = pn;
          name.text = pn;
        }
      }
      var confirm = <String>[];
      var confirmCat = false;
      Map<String, dynamic>? r;
      for (var round = 0; round < 4 && r == null; round++) {
        try {
          r = await widget.call({'action': 'save', 'code': _code, 'item': it, 'confirm': confirm, 'confirmCat': confirmCat});
        } on ApiError catch (er) {
          if (!mounted) return;
          if (er.code == 'exact') {
            await tellLines(context, 'Already there', [er.message, 'हा item आधीच आहे – save केलेला नाही.']);
            return;
          }
          if (er.code == 'similar') {
            final sim = [for (final y in (er.data['similar'] as List? ?? const []).whereType<Map>()) y];
            final v = await _choose('Is it the same item?', ['${it['name']} – nearly the same name is already there:', for (final y in sim) '${y['name']} (${y['code']}, ${y['unit']}, ${y['category']})'], [('diff', 'Different item – save'), ('same', 'Same item – do not save')]);
            if (v != 'diff') {
              if (mounted && sim.isNotEmpty) toast(context, 'Not saved – ${sim.first['name']} (${sim.first['code']}) is already there.');
              return;
            }
            confirm = [for (final y in sim) '${y['code']}'];
            continue;
          }
          if (er.code == 'cat') {
            final near = [for (final c in (er.data['categories'] as List? ?? const [])) '$c'];
            final v = await _choose('Category', ['You typed the category ${it['category']}; nearly the same is already there: ${near.join(', ')}.'], [('new', 'New category "${'${it['category']}'.trim()}"'), ('use', 'Use "${near.isEmpty ? '' : near.first}"')]);
            if (v == null) return;
            if (v == 'use' && near.isNotEmpty) {
              it['category'] = near.first;
              cat.text = near.first;
            } else {
              confirmCat = true;
            }
            continue;
          }
          rethrow;
        }
      }
      if (r == null || !mounted) return;
      final out = (r['item'] as Map?) ?? const {};
      toast(context, '${widget.item != null ? 'Saved: ' : 'Item added: '}${out['code']} ${out['name']}');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _choose(String title, List<String> lines, List<(String, String)> options) => showDialog<String>(
        context: context,
        builder: (dc) => AlertDialog(
          title: Text(title),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l))]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc), child: Text('Cancel')),
            for (var i = 0; i < options.length; i++)
              i == options.length - 1
                  ? FilledButton(key: Key('itc-${options[i].$1}'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(dc, options[i].$1), child: Text(options[i].$2))
                  : TextButton(key: Key('itc-${options[i].$1}'), onPressed: () => Navigator.pop(dc, options[i].$1), child: Text(options[i].$2)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(actions: withAsk(), title: Text(widget.item != null ? 'Change ${widget.item!['code']}' : 'Add item')),
        bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: FilledButton(key: const Key('it-save'), onPressed: busy ? null : _save, child: Text('Save item')))),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
          TextBox(key: const Key('it-name'), label: 'Item Name *', controller: name, hint: 'e.g. Hydraulic Hose 1/2 inch', onChanged: (_) => _typedName()),
          if (hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Expanded(child: Text(hint, key: const Key('it-hint'), style: TextStyle(fontSize: 13, color: hintColor, fontWeight: FontWeight.w600))),
                if (proper.isNotEmpty)
                  TextButton(
                    key: const Key('it-use'),
                    onPressed: () => setState(() {
                      name.text = proper;
                      hint = proper = '';
                    }),
                    child: Text('Use this'),
                  ),
              ]),
            ),
          const SizedBox(height: 8),
          PickField(key: const Key('it-unit'), label: 'Unit *', value: unit, items: widget.units, blank: 'Pick…', onChanged: (v) => setState(() => unit = v)),
          const SizedBox(height: 8),
          TextBox(key: const Key('it-cat'), label: 'Category *', controller: cat, options: widget.cats, hint: 'e.g. Spare Parts'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextBox(key: const Key('it-hsn'), label: 'HSN Code', controller: hsn, kb: TextInputType.number, hint: '4, 6 or 8 digits')),
            const SizedBox(width: 8),
            Expanded(child: TextBox(key: const Key('it-gst'), label: 'GST %', controller: gst, kb: const TextInputType.numberWithOptions(decimal: true), options: const ['0', '5', '18', '40'], hint: 'e.g. 18')),
          ]),
          const SizedBox(height: 8),
          TextBox(key: const Key('it-min'), label: 'Min Stock', controller: minS, kb: const TextInputType.numberWithOptions(decimal: true), hint: 'e.g. 10'),
          if (widget.item != null) ...[
            const SizedBox(height: 8),
            PickField(key: const Key('it-status'), label: 'Status', value: status, items: const ['Active', 'Inactive'], onChanged: (v) => setState(() => status = v)),
          ],
        ]),
      );
}

/// (3.13.0) Import from Excel – check: the web's p_imp. Every row of the file and what will happen to it (new – will be added,
/// already there – left out, near name – confirm, mistake); a near name is added only when "Different item – add it" is ticked.
/// Nothing is imported while a mistake is left.
class StoreImportScreen extends StatefulWidget {
  const StoreImportScreen({super.key, required this.rows, required this.call});
  final List<Map<String, Object?>> rows;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) call;
  @override
  State<StoreImportScreen> createState() => _StoreImportScreenState();
}

const _kImpSt = {
  'new': ('New – will be added', C.greenDark, C.greenSoft),
  'exists': ('Already there – left out', C.muted, C.slateSoft),
  'similar': ('Near name – confirm', C.amber, C.amberSoft),
  'error': ('Mistake', C.red, C.redSoft),
};

class _StoreImportScreenState extends State<StoreImportScreen> {
  final confirm = <String, List<String>>{};
  Map<String, dynamic>? r;
  String err = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    try {
      final x = await widget.call({'action': 'import', 'check': true, 'rows': widget.rows, 'confirm': confirm});
      if (mounted) setState(() => r = x);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  int _n(String k) => (asNum(r?[k]) ?? 0).toInt();

  Future<void> _go() async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final x = await widget.call({'action': 'import', 'rows': widget.rows, 'confirm': confirm});
      if (!mounted) return;
      final exists = (asNum(x['exists']) ?? 0).toInt();
      toast(context, '${x['added']} items imported${exists > 0 ? ', $exists already there (left out)' : ''}.');
      Navigator.pop(context, true);
    } catch (e) {
      if (e is ApiError && e.data['report'] != null) await _check();
      if (!mounted) return;
      setState(() {
        busy = false;
        err = errText(e);
      });
      toast(context, errText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rr = r;
    final list = [for (final x in (rr?['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
    final errors = _n('errors');
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: Text('Import from Excel – check')),
      body: rr == null
          ? (err.isEmpty ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [InfoLine(err, bad: true)]))
          : ListView(key: const Key('si-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
              Text(
                '${widget.rows.length} rows: ${_n('fresh')} new, ${_n('exists')} already there (left out), ${_n('similar')} near names to confirm, $errors with a mistake.'
                '${errors > 0 ? ' Correct the mistakes in the file and choose it again – nothing is imported while one is left.' : ''}',
                key: const Key('si-sum'),
                style: TextStyle(fontSize: 13.5, color: errors > 0 ? C.red : C.muted, height: 1.35),
              ),
              if (err.isNotEmpty) InfoLine(err, bad: true),
              const SizedBox(height: 10),
              for (final x in list) _row(x),
            ]),
      bottomNavigationBar: rr == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: Row(children: [
                  Expanded(child: OutlinedButton(key: const Key('si-x'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: busy ? null : () => Navigator.pop(context, false), child: Text('Cancel'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('si-go'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48), backgroundColor: C.green),
                      onPressed: busy || errors > 0 || _n('fresh') + _n('similar') == 0 ? null : _go,
                      child: Text(busy ? 'Importing…' : 'Import'),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _row(Map<String, dynamic> x) {
    final st = _kImpSt['${x['status']}'] ?? _kImpSt['error']!;
    final line = '${x['line']}';
    final near = [for (final y in (x['similar'] as List? ?? const []).whereType<Map>()) y];
    final codes = [for (final y in near) '${y['code']}'];
    final note = '${x['msg'] ?? ''}'.isNotEmpty ? '${x['msg']}' : '${x['catNote'] ?? ''}';
    return Container(
      key: Key('si-row-$line'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: x['status'] == 'error' ? C.red : C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text('Line $line · ${x['name'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
          Pill(st.$1, color: st.$2, bg: st.$3),
        ]),
        if (x['status'] == 'similar') ...[
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('Near: ${[for (final y in near) '${y['code']} ${y['name']}'].join(', ')}', style: const TextStyle(fontSize: 13, color: C.muted))),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: Key('si-ok-$line'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: confirm.containsKey(line),
              onChanged: (v) => setState(() => v == true ? confirm[line] = codes : confirm.remove(line)),
              title: Text('Different item – add it', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ] else if (note.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(note, style: TextStyle(fontSize: 13, color: x['status'] == 'error' ? C.red : C.muted))),
      ]),
    );
  }
}
