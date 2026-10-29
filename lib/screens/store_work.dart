/* THE STORE'S WORK – the app's own screens (3.54.0) of the Store's step 2 (28-10-2026: "sagle banwayla chalu kr"): Material
 * Requirements and their approvals (level by level – who approves is given by the Super Admin in the Portal), Purchase – every
 * site (HO Purchase), Purchase Orders, Inward (GRN), Issue & Return, Stock & Reports, Opening stock & Numbers. The same actions,
 * checks and access as the web's pages (rcl-store api/work.js and public/work.js); every save is checked again by the Store's
 * server and inside its database (one save at a time on the site, an item's stock never below zero on any date). */
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show rootBundle;

import '../core/api.dart' show ApiError;
import '../core/format.dart';
import '../core/grn_reg.dart';
import '../core/lb_io.dart' show XSheet;
import '../core/more_imports.dart' show generalText;
import '../core/rdoc.dart';
import '../core/sheet_read.dart' show readSheets, SheetError, SheetTab;
import '../core/store_papers.dart';
import '../core/xlsx.dart';
import '../ui/ask_bot.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/pick_file.dart';
import '../ui/report_view.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../web/print_view.dart';

part 'store_reg.dart';

/// One action of the Store's work (POST <store>/api/work { action, … }).
typedef StoreCall = Future<Map<String, dynamic>> Function(String action, [Map<String, dynamic>? x]);

/// The pages of the Store's work, as the web's menu: key, name, Marathi, what it is, icon.
const kWorkPages = <(String, String, String, String, IconData)>[
  ('req', 'Requirements', 'मटेरियल मागणी', 'Material Requirements – approved level by level', Icons.playlist_add_check_rounded),
  ('purchase', 'Purchase – every site', 'खरेदी – सर्व साइट', 'HO Purchase: approved requirements → purchase orders', Icons.shopping_cart_rounded),
  ('po', 'Purchase Orders', 'खरेदी ऑर्डर', 'The POs of this site and what has come', Icons.receipt_long_rounded),
  ('grn', 'Inward (GRN)', 'आवक (GRN)', 'Material received – against a PO or direct', Icons.move_to_inbox_rounded),
  ('issue', 'Issue & Return', 'इश्यू आणि परत', 'Material given out; what comes back', Icons.outbox_rounded),
  ('reports', 'Stock & Reports', 'स्टॉक आणि रिपोर्ट', 'Stock, statement, ledger, registers, consumption', Icons.bar_chart_rounded),
  ('settings', 'Opening stock & Numbers', 'ओपनिंग स्टॉक आणि नंबर', 'The stock when the Store starts here; the numbers', Icons.tune_rounded),
];

const _kFor = ['Site work', 'Machinery', 'Office', 'Other'], _kTo = ['Site work', 'Sub-contractor', 'Machinery', 'Office'], _kSides = ['LHS', 'RHS', 'Both'];

/// What the Store's work needs (its "boot"): who works and what he may do, the items and their stock, the machinery, the names
/// typed before, who approves – read again when a page opens and after a save (the web's B).
class StoreKit {
  StoreKit({required this.call, required Map pages, required this.admin}) : pages = Map<String, dynamic>.from(pages);
  final StoreCall call;
  final Map<String, dynamic> pages;
  final bool admin;
  Map<String, dynamic> b = {};

  /// a page of the web's menu: Edit / View / None ("purchase" only when given; "settings" is the Store Admin's)
  String pg(String k) => k == 'purchase' ? (pages['purchase'] == 'Edit' ? 'Edit' : 'None') : k == 'settings' ? (admin ? 'Edit' : 'None') : '${pages[k] ?? 'None'}';
  bool can(String k) => pg(k) != 'None';
  bool edit(String k) => pg(k) == 'Edit';
  bool get buyer => pg('purchase') == 'Edit';
  bool get anyWork => kWorkPages.any((p) => can(p.$1));

  Future<void> boot() async {
    b = await call('boot');
  }

  String get today => '${b['today'] ?? dateKey(DateTime.now())}';
  String get monthStart => '${today.substring(0, 8)}01';
  List<Map<String, dynamic>> get items => listOf(b['items']);
  List<Map<String, dynamic>> get active => [for (final i in items) if (i['status'] == 'Active') i];
  Map<String, dynamic>? item(String code) => items.where((i) => i['code'] == code).firstOrNull;
  num stock(String code) => nOf(mapOf(b['stock'])[code]);
  List<Map<String, dynamic>> get machinery => listOf(b['machinery']);
  List<String> names(String k) => [for (final x in (mapOf(b['names'])[k] as List? ?? const [])) '$x'];
  Map<String, dynamic> get gstOf => mapOf(mapOf(b['names'])['gst']);
  List<String> kinds(String k) {
    final l = [for (final x in (mapOf(b['kinds'])[k] as List? ?? const [])) '$x'];
    return l.isNotEmpty ? l : (k == 'for' ? _kFor : k == 'to' ? _kTo : _kSides);
  }

  List<String> get cats => (<String>{for (final i in items) '${i['category'] ?? ''}'}..remove('')).toList()..sort();
  Map<String, String> get machLabels => {for (final m in machinery) '${m['no']}': '${m['no']}${'${m['name'] ?? ''}'.isNotEmpty ? ' – ${m['name']}' : ''}${'${m['own'] ?? ''}'.isNotEmpty && m['own'] != 'Own' ? ' (${m['own']})' : ''}'};
}

/* ---------------- the web's ways of writing (n2, money, dmy) ---------------- */
double _d(String s) => double.tryParse(s.replaceAll(',', '').replaceAll('₹', '').trim()) ?? 0;

String _grp(String whole) {
  if (whole.length <= 3) return whole;
  final last3 = whole.substring(whole.length - 3);
  var rest = whole.substring(0, whole.length - 3);
  final g = <String>[];
  while (rest.length > 2) {
    g.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) g.insert(0, rest);
  return '${g.join(',')},$last3';
}

/// A quantity as the web writes it (en-IN, up to 3 decimals): 1,234.5
String q3(dynamic v) {
  if (blankV(v)) return '';
  final n = nOf(v);
  final p = n.abs().toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '').split('.');
  return '${n < 0 ? '-' : ''}${_grp(p[0])}${p.length > 1 ? '.${p[1]}' : ''}';
}

/// A number for a box to type in (no commas): 12.5
String plainN(dynamic v) => blankV(v) ? '' : nOf(v).toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

/// ₹1,234.50
String rs(dynamic v) => '₹${money(blankV(v) ? 0 : v)}';

String storeItemLabel(Map i) => '${i['code']} · ${i['name']} (${i['unit']})';

/// Who an issue went to (the web's toWho).
String storeToWho(Map i) => i['to_kind'] == 'Machinery'
    ? '${i['machinery'] ?? ''}${'${i['party'] ?? ''}'.isNotEmpty ? ' (${i['party']})' : ''}'
    : i['to_kind'] == 'Sub-contractor'
        ? '${i['party'] ?? ''}'
        : i['to_kind'] == 'Site work'
            ? 'RCL – site work'
            : 'Office';

Widget statePill(String s) {
  final t = RegExp(r'^(Approved|Received|Open)$').hasMatch(s)
      ? (C.greenDark, C.greenSoft)
      : RegExp('Pending|Part').hasMatch(s)
          ? (C.amber, C.amberSoft)
          : RegExp('Rejected|Cancelled').hasMatch(s)
              ? (C.red, C.redSoft)
              : (C.muted, C.slateSoft);
  return Pill(s, color: t.$1, bg: t.$2);
}

const _muted = TextStyle(fontSize: 12.5, color: C.muted, height: 1.35);
const _faint = TextStyle(fontSize: 12, color: C.faint);
const _bold = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800);
const _dec = TextInputType.numberWithOptions(decimal: true);

Widget _card({Key? key, required List<Widget> children, Color color = Colors.white, Color border = C.line}) => Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );

Widget _act(String key, String label, VoidCallback? onTap, {Color color = C.green}) => TextButton(
      key: Key(key),
      style: TextButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 10)),
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );

Widget _small(String key, String label, VoidCallback? onTap, {IconData icon = Icons.table_view_rounded}) => OutlinedButton.icon(
      key: Key(key),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 12)),
      onPressed: onTap,
      icon: Icon(icon, size: 19),
      label: Text(label),
    );

Widget _fab(String key, String label, VoidCallback onTap) => FloatingActionButton.extended(
      key: Key(key),
      onPressed: onTap,
      backgroundColor: C.green,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: const StadiumBorder(),
      icon: const Icon(Icons.add_rounded, size: 26),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );

Widget _saveBar(String key, String label, bool busy, VoidCallback onTap) => SafeArea(
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: FilledButton(key: Key(key), onPressed: busy ? null : onTap, child: Text(busy ? 'Saving…' : label))),
    );

AppBar _bar(String en, String mr, {VoidCallback? refresh}) => AppBar(
      title: TwoLang(en, mr, size: 18, weight: FontWeight.w700),
      actions: withAsk([if (refresh != null) IconButton(tooltip: tr('Refresh'), onPressed: refresh, icon: const Icon(Icons.refresh_rounded))]),
    );

Widget _dates(String key, String from, String to, ValueChanged<String> onFrom, ValueChanged<String> onTo, VoidCallback onShow) => Row(children: [
      Expanded(child: DateField(key: Key('$key-from'), label: 'From', value: from, clear: false, onChanged: onFrom)),
      const SizedBox(width: 8),
      Expanded(child: DateField(key: Key('$key-to'), label: 'To', value: to, clear: false, onChanged: onTo)),
      const SizedBox(width: 8),
      FilledButton(key: Key('$key-show'), style: FilledButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 16)), onPressed: onShow, child: Text('Show')),
    ]);

Widget _loading() => const Center(child: CircularProgressIndicator());

/// A choice of several (null = Cancel).
Future<String?> _choose(BuildContext context, String title, List<String> lines, List<(String, String)> options) => showDialog<String>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: const TextStyle(fontSize: 14.5, height: 1.35))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc), child: Text('Cancel')),
          for (var i = 0; i < options.length; i++)
            i == options.length - 1
                ? FilledButton(key: Key('swc-${options[i].$1}'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(dc, options[i].$1), child: Text(options[i].$2))
                : TextButton(key: Key('swc-${options[i].$1}'), onPressed: () => Navigator.pop(dc, options[i].$1), child: Text(options[i].$2)),
        ],
      ),
    );

/// A save that asks first (the web's saveAsk): a party's name nearly one written before ("the same supplier?"), or more than a PO
/// still has to come ("take it in anyway?"). null: not saved (Cancel).
Future<Map<String, dynamic>?> storeSaveAsk(BuildContext context, StoreCall call, String action, Map<String, dynamic> x) async {
  for (var round = 0; round < 4; round++) {
    try {
      return await call(action, x);
    } on ApiError catch (e) {
      if (!context.mounted) return null;
      if (e.code == 'party') {
        final near = [for (final n in (e.data['near'] as List? ?? const [])) '$n'], field = '${e.data['field'] ?? ''}';
        final v = await _choose(context, 'The same $field?', [
          '${e.data['typed'] ?? ''} – nearly the same is already there:',
          for (final n in near) '• $n',
          'हेच नाव आधी असे लिहिलेले आहे – तेच आहे का?',
        ], [
          ('__new', 'Another $field – save as typed'),
          for (final n in near) (n, 'Use "$n"'),
        ]);
        if (v == null) return null;
        if (v == '__new') {
          x['confirmParty'] = true;
        } else {
          final f = const {'supplier': ('grn', 'supplier'), 'vendor': ('po', 'vendor'), 'sub-contractor': ('issue', 'party')}[field];
          if (f != null && x[f.$1] is Map) (x[f.$1] as Map)[f.$2] = v;
        }
        continue;
      }
      if (e.code == 'over') {
        if (!await ask(context, 'More than the PO', '${e.message}\nPO मध्ये उरलेल्यापेक्षा जास्त माल आला आहे – तरी घ्यायचा का?', yes: 'Take it in')) return null;
        x['confirmOver'] = true;
        continue;
      }
      rethrow;
    }
  }
  return null;
}

/// A report of the Store ({ title, sub, cols: [{h, n}], rows, total } – the same as the web shows, prints and gives as Excel).
RDoc storeRepDoc(Map<String, dynamic> rep) {
  final cols = listOf(rep['cols']);
  final numCols = {for (var i = 0; i < cols.length; i++) if (cols[i]['n'] == true) i};
  RCell cell(int i, dynamic v, {bool bold = false}) => numCols.contains(i) && v is num ? RCell(q3(v), n: true, bold: bold, value: v) : RCell(v == null ? '' : '$v', n: numCols.contains(i), bold: bold);
  RRow line(List r, {bool bold = false, RKind kind = RKind.normal}) => RRow([for (final (i, v) in r.indexed) cell(i, v, bold: bold)], kind: kind);
  final rows = [for (final r in (rep['rows'] as List? ?? const [])) if (r is List) line(r)];
  final tot = rep['total'] is List ? line(rep['total'] as List, bold: true, kind: RKind.grand) : null;
  final title = '${rep['title'] ?? 'Report'}', sub = '${rep['sub'] ?? ''}';
  final sheet = title.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ');
  return RDoc(
    title: title,
    meta: '${sub.isEmpty ? '' : '$sub · '}${rows.length} row(s)',
    period: sub,
    portrait: cols.length <= 8,
    file: '${title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${dateKey(DateTime.now())}',
    blocks: [RTable(sheet: sheet.length > 31 ? sheet.substring(0, 31) : sheet, head: [for (final c in cols) '${c['h'] ?? ''}'], rows: rows, foot: tot == null ? const [] : [tot], numCols: numCols, empty: 'Nothing in these dates.')],
  );
}

/// A report of the Store as an Excel file (the web's "Export to Excel" of a list).
Future<void> storeExcel(BuildContext context, StoreKit k, Map<String, dynamic> x) async {
  final s = SessionScope.read(context);
  try {
    await shareDocXlsx(s, storeRepDoc(await k.call('report', x)));
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
  }
}

/// An item picked from a list with a search box (null = nothing picked).
Future<Map<String, dynamic>?> pickStoreItem(BuildContext context, List<Map<String, dynamic>> items) async {
  final by = {for (final i in items) storeItemLabel(i): i};
  final v = await pickFromList(context, 'Item', by.keys.toList());
  return v == null ? null : by[v];
}

/* ---------------- the LINES of a paper (the web's Lines): a card each, "+ Add item" ---------------- */
class SLine {
  SLine({this.code = '', this.name = '', this.unit = '', String qty = '', String rate = '', String gst = '', String note = '', String serial = '', String brand = '', String spec = '', String disc = '', String hsn = '', this.returnable = false, this.reqNo, this.reqLine, this.poLine, this.info = ''})
      : disc = TextEditingController(text: disc),
        hsn = TextEditingController(text: hsn),
        qty = TextEditingController(text: qty),
        rate = TextEditingController(text: rate),
        gst = TextEditingController(text: gst),
        note = TextEditingController(text: note),
        serial = TextEditingController(text: serial),
        brand = TextEditingController(text: brand),
        spec = TextEditingController(text: spec);
  final String code, name, unit, info;

  /// (3.58.0, the web's 28-10-2026) a requirement's / PO's line: its Brand and Material specification
  final TextEditingController qty, rate, gst, note, serial, brand, spec;

  /// (3.62.0, the Store's step 5) a PO's line: its Disc. % and HSN
  final TextEditingController disc, hsn;
  bool returnable;
  final int? reqNo, reqLine, poLine;

  /// taxable = qty × rate less the Disc. % (the web's lineMoney), the GST on it, the total
  ({double t, double g, double all}) money() {
    final t = r2(r2(_d(qty.text) * _d(rate.text)) * (100 - _d(disc.text)) / 100), g = r2(t * _d(gst.text) / 100);
    return (t: t, g: g, all: r2(t + g));
  }

  void dispose() {
    for (final c in [qty, rate, gst, note, serial, brand, spec, disc, hsn]) {
      c.dispose();
    }
  }
}

({double t, double g, double all}) linesMoney(List<SLine> l) {
  var t = 0.0, g = 0.0;
  for (final x in l) {
    final m = x.money();
    t += m.t;
    g += m.g;
  }
  return (t: r2(t), g: r2(g), all: r2(t + g));
}

class SLinesEditor extends StatelessWidget {
  const SLinesEditor({super.key, required this.k, required this.lines, required this.onChanged, this.items, this.tag = 'ln', this.qtyLabel = 'Qty *', this.rateLabel = '', this.gst = false, this.gstFill = false, this.noteLabel = '', this.returnable = false, this.serial = false, this.stock = false, this.money = false, this.brandSpec = false, this.discHsn = false});
  final StoreKit k;
  final List<SLine> lines;
  final VoidCallback onChanged;

  /// the items to pick from (another site's for its PO); null: this site's active items
  final List<Map<String, dynamic>>? items;
  final String tag, qtyLabel, rateLabel, noteLabel;
  final bool gst, gstFill, returnable, serial, stock, money, brandSpec;

  /// (3.62.0) a PO's line: Disc. % and HSN (the item's own HSN filled in)
  final bool discHsn;

  Future<void> _add(BuildContext context) async {
    final i = await pickStoreItem(context, items ?? k.active);
    if (i == null) return;
    lines.add(SLine(code: '${i['code']}', name: '${i['name']}', unit: '${i['unit']}', gst: gstFill && i['gst_pct'] != null ? plainN(i['gst_pct']) : '', hsn: discHsn ? '${i['hsn'] ?? ''}' : ''));
    onChanged();
  }

  Widget _line(int i, SLine l) {
    final m = l.money();
    return Container(
      key: Key('$tag-$i'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
      child: Material(
        type: MaterialType.transparency,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('${i + 1}. ${l.name} (${l.unit})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
            if (l.info.isNotEmpty) Pill(l.info, color: C.blue, bg: C.blueSoft),
            IconButton(
              key: Key('$tag-x-$i'),
              tooltip: tr('Take this line out'),
              onPressed: () {
                lines.removeAt(i); // (its boxes are let go with the screen – a box still drawn this frame keeps its text)
                onChanged();
              },
              icon: const Icon(Icons.close_rounded, color: C.red),
            ),
          ]),
          Text('${l.code}${stock ? ' · stock now ${q3(k.stock(l.code))} ${l.unit}' : ''}', style: _faint),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(children: [
              Expanded(child: TextBox(key: Key('$tag-q-$i'), label: qtyLabel, controller: l.qty, kb: _dec, onChanged: (_) => onChanged())),
              if (rateLabel.isNotEmpty) ...[const SizedBox(width: 8), Expanded(child: TextBox(key: Key('$tag-r-$i'), label: rateLabel, controller: l.rate, kb: _dec, onChanged: (_) => onChanged()))],
              if (gst) ...[const SizedBox(width: 8), SizedBox(width: 86, child: TextBox(key: Key('$tag-g-$i'), label: 'GST %', controller: l.gst, kb: _dec, onChanged: (_) => onChanged()))],
            ]),
          ),
          if (discHsn)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Row(children: [
                Expanded(child: TextBox(key: Key('$tag-d-$i'), label: 'Disc. %', controller: l.disc, kb: _dec, onChanged: (_) => onChanged())),
                const SizedBox(width: 8),
                Expanded(child: TextBox(key: Key('$tag-h-$i'), label: 'HSN', controller: l.hsn, kb: TextInputType.number)),
              ]),
            ),
          if (serial) Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: TextBox(key: Key('$tag-s-$i'), label: 'Serial No (tyre / battery)', controller: l.serial)),
          if (brandSpec) ...[
            Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: TextBox(key: Key('$tag-b-$i'), label: 'Brand', controller: l.brand)),
            Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: TextBox(key: Key('$tag-sp-$i'), label: 'Material specification', controller: l.spec, maxLines: 2)),
          ],
          if (noteLabel.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: TextBox(key: Key('$tag-n-$i'), label: noteLabel, controller: l.note)),
          if (returnable)
            CheckboxListTile(
              key: Key('$tag-ret-$i'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: l.returnable,
              onChanged: (v) {
                l.returnable = v == true;
                onChanged();
              },
              title: Text('Returnable', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          if (money) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Taxable ${rs(m.t)} · GST ${rs(m.g)} · Total ${rs(m.all)}', key: Key('$tag-m-$i'), style: _muted)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < lines.length; i++) _line(i, lines[i]),
        if (lines.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('No item yet – press "+ Add item".', textAlign: TextAlign.center, style: _muted)),
        OutlinedButton.icon(key: Key('$tag-add'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)), onPressed: () => _add(context), icon: const Icon(Icons.add_rounded), label: Text('+ Add item')),
      ]);
}

/* ======================== THE WORK TAB of Home → Store: the pages (the web's menu) ======================== */
class StoreWorkTab extends StatelessWidget {
  const StoreWorkTab({super.key, required this.k, required this.dash, required this.err, required this.back});
  final StoreKit k;
  final Map<String, dynamic>? dash;
  final String err;

  /// after a page is closed: the figures read again
  final VoidCallback back;

  @override
  Widget build(BuildContext context) {
    final d = dash ?? const <String, dynamic>{}, rq = mapOf(d['req']);
    final pages = [for (final p in kWorkPages) if (k.can(p.$1)) p];
    return ListView(key: const Key('st-work'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 90), children: [
      if (err.isNotEmpty) InfoLine(err, bad: true),
      for (final p in pages)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Press(
            key: Key('sw-${p.$1}'),
            radius: 18,
            onTap: () async {
              await openStoreWork(context, k, p.$1);
              back();
            },
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(14)), child: Icon(p.$5, color: C.greenDark)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TwoLang(p.$2, p.$3, size: 16, weight: FontWeight.w800),
                  Text(p.$4, style: _muted),
                ]),
              ),
              if (p.$1 == 'req' && nOf(rq['mine']) > 0) Pill('${rq['mine']} for me', key: const Key('sw-req-mine'), color: C.amber, bg: C.amberSoft),
              const Icon(Icons.chevron_right_rounded, color: C.faint),
            ]),
          ),
        ),
      if (pages.isEmpty) InfoLine('You have no page of the Store\'s work on this site – ask the Super Admin.', bad: true),
    ]);
  }
}

/// The figures of the Store's work on the Dashboard (the web's db_work tiles and the recent GRN / issues).
class StoreDashWork extends StatelessWidget {
  const StoreDashWork({super.key, required this.dash});
  final Map<String, dynamic> dash;
  @override
  Widget build(BuildContext context) {
    final st = mapOf(dash['stock']), rq = mapOf(dash['req']), po = mapOf(dash['po']), g = mapOf(dash['grn']), iss = mapOf(dash['issue']);
    Widget tile(String key, String label, String n, String sub, Color c, Color bg) => Container(
          key: Key(key),
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
            Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
            Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
          ]),
        );
    Widget recent(String title, List<Map<String, dynamic>> l, String Function(Map) line) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          if (l.isEmpty) Text('None this month.', style: _muted),
          for (final x in l) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(line(x), style: const TextStyle(fontSize: 13.5))),
        ]);
    return Column(key: const Key('st-dwork'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (st.isNotEmpty) tile('sd-value', 'Stock value', rs(st['value']).replaceFirst(RegExp(r'\.\d\d$'), ''), 'at the average basic rate', C.greenDark, C.greenSoft),
        if (st.isNotEmpty) tile('sd-below', 'Below min stock', '${st['below'] ?? 0}', 'items to order', nOf(st['below']) > 0 ? C.amber : C.muted, nOf(st['below']) > 0 ? C.amberSoft : C.slateSoft),
        if (rq.isNotEmpty) tile('sd-mine', 'Waiting for my approval', '${rq['mine'] ?? 0}', '${rq['pending'] ?? 0} requirement(s) pending', C.amber, C.amberSoft),
        if (rq.isNotEmpty) tile('sd-appr', 'Approved – to order', '${rq['approved'] ?? 0}', 'requirements', C.blue, C.blueSoft),
        if (po.isNotEmpty) tile('sd-po', 'POs open', '${po['open'] ?? 0}', 'material to come', C.slate, C.slateSoft),
        if (g.isNotEmpty) tile('sd-grn', 'GRN today', '${g['today'] ?? 0}', '${rs(g['todayValue'])} · month ${g['month'] ?? 0}', C.greenDark, C.greenSoft),
        if (iss.isNotEmpty) tile('sd-iss', 'Issues today', '${iss['today'] ?? 0}', '${rs(iss['todayValue'])} · month ${iss['month'] ?? 0}', C.blue, C.blueSoft),
      ]),
      if (g.isNotEmpty) recent('Recent GRN', listOf(g['recent']), (x) => 'GRN ${grnRef(x)} · ${dmy(x['date'])} · ${x['supplier'] ?? ''} · ${rs(x['gross'])}'),
      if (iss.isNotEmpty) recent('Recent issues', listOf(iss['recent']), (x) => 'Outward ${x['no']} · ${dmy(x['date'])} · ${storeToWho(x)} · ${rs(x['amount'])}'),
    ]);
  }
}

Future<void> openStoreWork(BuildContext context, StoreKit k, String page) {
  final Widget w = switch (page) {
    'req' => ReqListScreen(k: k),
    'purchase' => PurchaseScreen(k: k),
    'po' => PoListScreen(k: k),
    'grn' => GrnListScreen(k: k),
    'issue' => IssueListScreen(k: k),
    'reports' => StoreReportsScreen(k: k),
    _ => OpeningScreen(k: k),
  };
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
}

/// (3.58.0) a line's Brand and Material specification after its item (the web's bsOf)
String bsOf(Map l) {
  final x = ['${l['brand'] ?? ''}', '${l['spec'] ?? ''}'].where((v) => v.trim().isNotEmpty).join(' · ');
  return x.isEmpty ? '' : ' – $x';
}

/* ======================== MATERIAL REQUIREMENTS ======================== */
const _kReqF = [('open', 'Open (pending + to order)'), ('mine', 'Waiting for me'), ('Pending', 'Pending'), ('Approved', 'Approved'), ('Rejected', 'Rejected'), ('Closed', 'Closed'), ('Cancelled', 'Cancelled'), ('all', 'All')];

/// Is a requirement in this filter (the web's reqIn)?
bool reqIn(Map x, String f) {
  final st = '${x['status']}', lines = listOf(x['lines']);
  if (f == 'all') return true;
  if (f == 'mine') return x['mayApprove'] == true;
  if (f == 'open') return st == 'Pending' || (st == 'Approved' && lines.any((l) => nOf(l['left']) > 0));
  return st == f;
}

class ReqListScreen extends StatefulWidget {
  const ReqListScreen({super.key, required this.k});
  final StoreKit k;
  @override
  State<ReqListScreen> createState() => _ReqListScreenState();
}

class _ReqListScreenState extends State<ReqListScreen> {
  List<Map<String, dynamic>> reqs = [], levels = [];

  /// (3.62.0) the heading of this site's papers (the company, the site, e-mail …) – for the Purchase Requisition Form
  Map<String, dynamic> heading = {};
  String filter = 'open', err = '';
  bool loading = true;
  final ticked = <int>{};
  StoreKit get k => widget.k;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await k.boot();
      final r = await k.call('reqList');
      if (!mounted) return;
      setState(() {
        reqs = listOf(r['reqs']);
        levels = listOf(r['levels']);
        heading = mapOf(r['heading']);
        ticked.removeWhere((n) => !reqs.any((x) => nOf(x['no']) == n && x['mayApprove'] == true));
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

  Future<void> _do(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  Future<void> _approve(List<int> nos) => _do(() async {
        final r = await k.call('reqDecide', {'nos': nos, 'ok': true});
        final done = listOf(r['done']), left = listOf(r['left']);
        if (mounted) {
          toast(context, nos.length == 1 && left.isEmpty ? 'Requirement ${nos.first} approved.' : '${done.length} approved${left.isEmpty ? '' : '; ${left.map((l) => '${l['no']}: ${l['why']}').join('; ')}'}.');
        }
        ticked.clear();
        await _load();
      });

  Future<void> _reject(Map x) async {
    final why = await askNote(context, 'Reject requirement ${x['no']}?', label: 'Say why (the person who made it sees it):', ok: 'Reject', danger: true, neededMsg: 'Say why it is rejected.');
    if (why == null) return;
    await _do(() async {
      await k.call('reqDecide', {'no': x['no'], 'ok': false, 'note': why});
      if (mounted) toast(context, 'Requirement ${x['no']} rejected.');
      await _load();
    });
  }

  Future<void> _cancel(Map x) async {
    if (!await ask(context, 'Cancel requirement ${x['no']}?', bi('It will not be ordered.', 'ही मागणी रद्द होईल.'), yes: 'Cancel it', no: 'No', danger: true)) return;
    await _do(() async {
      await k.call('reqCancel', {'no': x['no']});
      if (mounted) toast(context, 'Requirement ${x['no']} cancelled.');
      await _load();
    });
  }

  Future<void> _close(Map x) async {
    if (!await ask(context, 'Close requirement ${x['no']}?', 'What is still to order will not be bought.', yes: 'Close', no: 'No')) return;
    await _do(() async {
      await k.call('reqClose', {'no': x['no']});
      if (mounted) toast(context, 'Requirement ${x['no']} closed.');
      await _load();
    });
  }

  Future<void> _form(Map<String, dynamic>? x) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ReqFormScreen(k: k, req: x)));
    if (saved == true) _load();
  }

  void _details(Map x) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SizedBox(
          height: MediaQuery.of(c).size.height * .75,
          child: ListView(key: const Key('rq-det'), padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
            Text('Requirement ${x['no']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if ('${x['remark'] ?? ''}'.isNotEmpty) Text('${x['remark']}', style: _muted),
            const SizedBox(height: 8),
            for (final l in listOf(x['lines']))
              _card(children: [
                Text('${l['name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if ('${l['brand'] ?? ''}'.isNotEmpty) InfoRow('Brand', '${l['brand']}'),
                if ('${l['spec'] ?? ''}'.isNotEmpty) InfoRow('Material specification', '${l['spec']}'),
                InfoRow('Asked', '${q3(l['qty'])} ${l['unit']}'),
                InfoRow('Ordered', q3(l['ordered'] ?? 0)),
                InfoRow('To order', q3(l['left'] ?? 0)),
                InfoRow('Stock now', q3(k.stock('${l['code']}'))),
                if ('${l['note'] ?? ''}'.isNotEmpty) InfoRow('Note', '${l['note']}'),
              ]),
            for (final a in listOf(x['approvals'])) Text('Level ${a['level']}: ${a['ok'] == true ? 'approved' : 'rejected'} by ${a['name'] ?? ''} on ${dmy(a['at'])}${'${a['note'] ?? ''}'.isNotEmpty ? ' – "${a['note']}"' : ''}', style: _muted),
            if ('${x['close_note'] ?? ''}'.isNotEmpty) Text('${x['close_note']}', style: _muted),
          ]),
        ),
      );

  Widget _tile(Map<String, dynamic> x) {
    final no = nOf(x['no']).toInt(), st = '${x['status']}', lines = listOf(x['lines']), may = x['mayApprove'] == true, mine = x['mine'] == true;
    final wait = [for (final p in (x['waitFor'] as List? ?? const [])) '$p'];
    return _card(key: Key('rq-$no'), color: may ? C.amberSoft.withValues(alpha: .35) : Colors.white, children: [
      Row(children: [
        if (may) Checkbox(key: Key('rq-tick-$no'), value: ticked.contains(no), onChanged: (v) => setState(() => v == true ? ticked.add(no) : ticked.remove(no))),
        Expanded(child: Text('REQ $no · ${dmy(x['date'])}', style: _bold)),
        statePill(st),
      ]),
      Text('For: ${x['for_kind'] ?? ''}${'${x['for_text'] ?? ''}'.isNotEmpty ? ' – ${x['for_text']}' : ''}${'${x['need_by'] ?? ''}'.isNotEmpty ? ' · needed by ${dmy(x['need_by'])}' : ''}', style: const TextStyle(fontSize: 13.5)),
      for (final l in lines) Text('• ${l['name']} ${q3(l['qty'])} ${l['unit']}${bsOf(l)}${st == 'Approved' && nOf(l['left']) < nOf(l['qty']) ? ' (ordered ${q3(l['ordered'])})' : ''}', style: const TextStyle(fontSize: 13.5)),
      if (st == 'Pending') Text('Level ${x['level']}${wait.isNotEmpty ? ' – ${wait.join(', ')}' : ''}', style: const TextStyle(fontSize: 12.5, color: C.amber, fontWeight: FontWeight.w600)),
      Text('Asked by ${x['created_name'] ?? x['created_by'] ?? ''}', style: _faint),
      Wrap(spacing: 2, children: [
        if (may) ...[_act('rq-ok-$no', 'Approve', () => _approve([no])), _act('rq-no-$no', 'Reject', () => _reject(x), color: C.red)],
        _act('rq-det-$no', 'Details', () => _details(x), color: C.blue),
        // (3.62.0, his format) the Purchase Requisition Form
        _act('rq-print-$no', 'Print', () => _do(() => printStorePaper(context, heading, 'Requirement ${'${x['ref'] ?? ''}'.isEmpty ? no : x['ref']}', (logo) => reqPaperHtml(x, heading, logo: logo))), color: C.blue),
        if ((mine || k.admin) && st == 'Pending' && listOf(x['approvals']).isEmpty && k.edit('req')) _act('rq-edit-$no', 'Change', () => _form(x), color: C.blue),
        if ((mine || k.admin) && (st == 'Pending' || st == 'Approved') && !lines.any((l) => nOf(l['ordered']) > 0)) _act('rq-cancel-$no', 'Cancel', () => _cancel(x), color: C.red),
        if ((k.buyer || k.admin) && st == 'Approved' && lines.any((l) => nOf(l['left']) > 0)) _act('rq-close-$no', 'Close', () => _close(x), color: C.slate),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final rows = reqs.where((x) => reqIn(x, filter)).toList();
    final tickable = rows.any((x) => x['mayApprove'] == true);
    return Scaffold(
      appBar: _bar('Requirements', 'मटेरियल मागणी', refresh: _load),
      floatingActionButton: !loading && k.edit('req') ? _fab('rq-new', 'New requirement', () => _form(null)) : null,
      body: loading
          ? _loading()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('rq-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 90), children: [
                Text('What the site needs. Approved level by level (who approves: given by the Super Admin in the Portal) – then HO Purchase makes its purchase order.', style: _muted),
                const SizedBox(height: 4),
                Text(levels.isEmpty ? 'No approver set for this site – a requirement is approved when it is made.' : 'Approved by: ${levels.map((l) => 'Level ${l['level']} – ${(l['people'] as List? ?? const []).join(', ')}').join(' · ')}', key: const Key('rq-lv'), style: const TextStyle(fontSize: 12.5, color: C.blue, fontWeight: FontWeight.w600)),
                if (err.isNotEmpty) InfoLine(err, bad: true),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final f in _kReqF)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(key: Key('rq-f-${f.$1}'), label: Text('${tr(f.$2)} (${reqs.where((x) => reqIn(x, f.$1)).length})'), selected: filter == f.$1, onSelected: (_) => setState(() => filter = f.$1)),
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: Text('${rows.length} requirement(s)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                  _small('rq-xl', 'Export to Excel', () => storeExcel(context, k, {'kind': 'req'})),
                ]),
                if (tickable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton(key: const Key('rq-okall'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)), onPressed: ticked.isEmpty ? null : () => _approve(ticked.toList()..sort()), child: Text('Approve the ticked (${ticked.length})')),
                  ),
                const SizedBox(height: 8),
                if (rows.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No requirement here.', textAlign: TextAlign.center, style: _muted)),
                for (final x in rows) _tile(x),
              ]),
            ),
    );
  }
}

class ReqFormScreen extends StatefulWidget {
  const ReqFormScreen({super.key, required this.k, this.req});
  final StoreKit k;
  final Map<String, dynamic>? req;
  @override
  State<ReqFormScreen> createState() => _ReqFormScreenState();
}

class _ReqFormScreenState extends State<ReqFormScreen> {
  late String date = '${widget.req?['date'] ?? widget.k.today}', need = '${widget.req?['need_by'] ?? ''}', kind = '${widget.req?['for_kind'] ?? 'Site work'}';
  late String mach = kind == 'Machinery' ? '${widget.req?['for_text'] ?? ''}' : '';
  late final which = TextEditingController(text: kind == 'Machinery' ? '' : '${widget.req?['for_text'] ?? ''}'), rem = TextEditingController(text: '${widget.req?['remark'] ?? ''}');
  final lines = <SLine>[];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    for (final l in listOf(widget.req?['lines'])) {
      lines.add(SLine(code: '${l['code']}', name: '${l['name']}', unit: '${l['unit']}', qty: plainN(l['qty']), note: '${l['note'] ?? ''}', brand: '${l['brand'] ?? ''}', spec: '${l['spec'] ?? ''}'));
    }
  }

  @override
  void dispose() {
    which.dispose();
    rem.dispose();
    for (final l in lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (lines.isEmpty) return toast(context, 'Add at least one item.', bad: true);
    setState(() => busy = true);
    try {
      final r = await widget.k.call('reqSave', {
        if (widget.req != null) 'no': widget.req!['no'],
        'req': {'date': date, 'need_by': need, 'for_kind': kind, 'for_text': kind == 'Machinery' ? mach : which.text, 'remark': rem.text, 'lines': [for (final l in lines) {'code': l.code, 'qty': l.qty.text, 'brand': l.brand.text, 'spec': l.spec.text, 'note': l.note.text}]},
      });
      if (!mounted) return;
      toast(context, 'Requirement ${r['no']} saved – ${r['status'] == 'Approved' ? 'approved (no approver set for this site).' : 'it waits for Level ${r['level']}.'}');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.k, ml = k.machLabels;
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: Text(widget.req != null ? 'Change requirement ${widget.req!['no']}' : 'New requirement')),
      bottomNavigationBar: _saveBar('rq-save', 'Save requirement', busy, _save),
      body: ListView(key: const Key('rqf'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        Row(children: [
          Expanded(child: DateField(key: const Key('rqf-date'), label: 'Date *', value: date, clear: false, onChanged: (v) => setState(() => date = v))),
          const SizedBox(width: 8),
          Expanded(child: DateField(key: const Key('rqf-need'), label: 'Needed by', value: need, onChanged: (v) => setState(() => need = v))),
        ]),
        const SizedBox(height: 8),
        PickField(key: const Key('rqf-kind'), label: 'For *', value: kind, items: k.kinds('for'), onChanged: (v) => setState(() => kind = v)),
        const SizedBox(height: 8),
        if (kind == 'Machinery')
          PickField(key: const Key('rqf-mach'), label: 'Machinery *', value: mach, items: ml.keys.toList(), labels: ml, blank: 'Pick…', onChanged: (v) => setState(() => mach = v))
        else
          TextBox(key: const Key('rqf-for'), label: kind == 'Site work' ? 'Location / work (e.g. Ch 540+450 toe wall)' : 'Which', controller: which),
        const SizedBox(height: 8),
        TextBox(key: const Key('rqf-rem'), label: 'Remark', controller: rem),
        const SizedBox(height: 14),
        Text('Items', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        SLinesEditor(k: k, lines: lines, tag: 'rql', stock: true, brandSpec: true, noteLabel: 'Note', onChanged: () => setState(() {})),
      ]),
    );
  }
}

/* ======================== PURCHASE – EVERY SITE (HO Purchase) ======================== */
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key, required this.k});
  final StoreKit k;
  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  List<Map<String, dynamic>> sites = [], pos = [];
  final ticks = <String>{}; // 'site|req|line'
  String err = '';
  bool loading = true;
  StoreKit get k => widget.k;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await k.call('purPending'), l = await k.call('poList', {'all': true});
      if (!mounted) return;
      setState(() {
        sites = listOf(p['sites']);
        pos = listOf(l['pos']);
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

  Future<void> _make(Map<String, dynamic> st) async {
    final site = '${st['site']}', picked = <Map<String, dynamic>>[];
    for (final r in listOf(st['reqs'])) {
      for (final l in listOf(r['lines'])) {
        if (ticks.contains('$site|${r['no']}|${l['line']}')) picked.add({'req': r, 'line': l});
      }
    }
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PoFormScreen(k: k, site: site, picked: picked)));
    if (saved == true) {
      ticks.removeWhere((t) => t.startsWith('$site|'));
      _load();
    }
  }

  Widget _site(Map<String, dynamic> st) {
    final site = '${st['site']}', reqs = listOf(st['reqs']);
    return _card(key: Key('pu-$site'), children: [
      Text('${st['name']} ($site)', style: _bold),
      if ('${st['error'] ?? ''}'.isNotEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${st['error']}', style: _muted))
      else ...[
        if (reqs.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Nothing to order.', style: _muted)),
        for (final r in reqs)
          for (final l in listOf(r['lines']))
            if (nOf(l['left']) > 0)
              Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  key: Key('pu-t-$site-${r['no']}-${l['line']}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: ticks.contains('$site|${r['no']}|${l['line']}'),
                  onChanged: (v) => setState(() => v == true ? ticks.add('$site|${r['no']}|${l['line']}') : ticks.remove('$site|${r['no']}|${l['line']}')),
                  title: Text('REQ ${r['no']} · ${l['name']}${bsOf(l)} – to order ${q3(l['left'])} ${l['unit']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: Text('${r['for_kind'] ?? ''}${'${r['for_text'] ?? ''}'.isNotEmpty ? ' – ${r['for_text']}' : ''} · ${dmy(r['date'])}${'${r['need_by'] ?? ''}'.isNotEmpty ? ' · needed by ${dmy(r['need_by'])}' : ''} · asked ${q3(l['qty'])}, ordered ${q3(l['ordered'])}', style: _faint),
                ),
              ),
        if (nOf(st['open']) > 0) Text('${st['open']} PO(s) open', style: _muted),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: FilledButton(
            key: Key('pu-mk-$site'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: () => _make(st),
            child: Text(reqs.isEmpty ? 'Make a PO for $site' : 'Make a PO for $site (the ticked lines)', textAlign: TextAlign.center),
          ),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: _bar('Purchase – every site', 'खरेदी – सर्व साइट', refresh: _load),
        body: loading
            ? _loading()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(key: const Key('pu-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), children: [
                  Text('The approved requirements of every site still to order. Tick the lines of one site and make its purchase order – it is kept in that site\'s own records.', style: _muted),
                  if (err.isNotEmpty) InfoLine(err, bad: true),
                  Align(alignment: Alignment.centerRight, child: _small('pu-xl', 'Export the POs (Excel)', () => storeExcel(context, k, {'kind': 'po', 'all': true}))),
                  const SizedBox(height: 8),
                  for (final st in sites) _site(st),
                  const SizedBox(height: 8),
                  Text('Purchase orders of every site', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  if (pos.isEmpty) Text('No purchase order.', style: _muted),
                  for (final p in pos) PoCard(k: k, po: p, sites: true, reload: _load),
                ]),
              ),
      );
}

/// A purchase order in a list: its lines and what has come; its approval; Approve / Reject, Print, Change, Cancel, Close (as the
/// web's poTable).
class PoCard extends StatelessWidget {
  const PoCard({super.key, required this.k, required this.po, required this.sites, required this.reload});
  final StoreKit k;
  final Map<String, dynamic> po;
  final bool sites;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final p = po, no = nOf(p['no']).toInt(), site = '${p['site'] ?? ''}', lines = listOf(p['lines']), open = p['status'] == 'Open';
    // (3.62.0, the Store's step 5) its approval: waiting (for whom), rejected (why), approved (by whom) – as the web's apprTag
    final appr = '${p['appr'] ?? ''}', may = p['mayApprove'] == true, wait = [for (final w in (p['waitFor'] as List? ?? const [])) '$w'];
    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        if (context.mounted) toast(context, errText(e), bad: true);
      }
    }

    return _card(key: Key('po-$site-$no'), color: may ? C.amberSoft.withValues(alpha: .35) : Colors.white, children: [
      Row(children: [
        Expanded(child: Text('${sites ? '$site · ' : ''}PO $no · ${dmy(p['date'])}', style: _bold)),
        statePill('${p['state'] ?? p['status']}'),
      ]),
      Text('${p['vendor'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      for (final l in lines) Text('• ${l['name']} ${q3(l['qty'])} ${l['unit']}${bsOf(l)}${nOf(l['received']) > 0 ? ' (came ${q3(l['received'])})' : ''}', style: const TextStyle(fontSize: 13.5)),
      Text('Total ${rs(p['total'])}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      if (open && appr == 'Waiting')
        Text('Waiting approval${wait.isNotEmpty ? ' – ${wait.join(', ')}' : ''}', key: Key('po-appr-$site-$no'), style: const TextStyle(fontSize: 12.5, color: C.amber, fontWeight: FontWeight.w600))
      else if (open && appr == 'Rejected')
        Text('Rejected${'${p['appr_note'] ?? ''}'.isNotEmpty ? ' – "${p['appr_note']}" – ${p['appr_name'] ?? ''}' : ''}', key: Key('po-appr-$site-$no'), style: const TextStyle(fontSize: 12.5, color: C.red, fontWeight: FontWeight.w600))
      else if (open && appr == 'Approved' && '${p['appr_name'] ?? ''}'.isNotEmpty)
        Text('Approved by ${p['appr_name']}', key: Key('po-appr-$site-$no'), style: _faint),
      Wrap(spacing: 2, children: [
        if (may) ...[
          _act('po-ok-$site-$no', 'Approve', () => run(() async {
                await k.call('poDecide', {'no': no, 'ok': true});
                if (context.mounted) toast(context, 'PO $no approved.');
                await reload();
              })),
          _act('po-no-$site-$no', 'Reject', () async {
            final why = await askNote(context, 'Reject PO $no?', label: 'Say why (the one who made it sees it and changes it):', ok: 'Reject', danger: true, neededMsg: 'Say why the PO is rejected (the one who made it sees it).');
            if (why == null) return;
            await run(() async {
              await k.call('poDecide', {'no': no, 'ok': false, 'note': why});
              if (context.mounted) toast(context, 'PO $no rejected.');
              await reload();
            });
          }, color: C.red),
        ],
        _act('po-print-$site-$no', 'Print', () => run(() async {
              final r = await k.call('poGet', {if (site.isNotEmpty) 'site': site, 'no': no});
              if (!context.mounted) return;
              final h = mapOf(r['heading']), x = mapOf(r['po']);
              await printStorePaper(context, h, 'PO ${'${x['ref'] ?? ''}'.isEmpty ? no : x['ref']}', (logo) => poPaperHtml(x, h, mapOf(r['supplier']), logo: logo));
            }), color: C.blue),
        if (k.buyer && open && sites)
          _act('po-edit-$site-$no', 'Change', () async {
            final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PoFormScreen(k: k, site: site, po: p)));
            if (saved == true) await reload();
          }, color: C.blue),
        if (k.buyer && open && !lines.any((l) => nOf(l['received']) > 0))
          _act('po-cancel-$site-$no', 'Cancel', () async {
            if (!await ask(context, 'Cancel PO $no?', 'Nothing of it has come – it is cancelled.', yes: 'Cancel the PO', no: 'No', danger: true)) return;
            await run(() async {
              await k.call('poCancel', {if (site.isNotEmpty) 'site': site, 'no': no});
              if (context.mounted) toast(context, 'PO $no cancelled.');
              await reload();
            });
          }, color: C.red),
        if ((k.buyer || k.admin) && open && p['state'] != 'Received')
          _act('po-close-$site-$no', 'Close', () async {
            if (!await ask(context, 'Close PO $no?', 'The rest of it will not come.', yes: 'Close', no: 'No')) return;
            await run(() async {
              await k.call('poClose', {if (site.isNotEmpty) 'site': site, 'no': no});
              if (context.mounted) toast(context, 'PO $no closed.');
              await reload();
            });
          }, color: C.slate),
      ]),
    ]);
  }
}

/// (3.62.0) Where a paper of the Store goes instead of its print screen (a test reads it back) – null: the print screen.
void Function(String html, String title)? storePaperSink;

/// (3.62.0, 28-10-2026 – his formats) A paper of the Store – the Purchase Order, the Purchase Requisition Form – as the web prints it
/// (lib/core/store_papers.dart), to the phone's printing (a printer, or "Save as PDF"). The logo as the web's: the company's own from
/// the Portal, else the app's own Rachana logo when the site's company is Rachana's, else its name.
Future<void> printStorePaper(BuildContext context, Map heading, String title, String Function(String logo) html) async {
  var logo = '';
  if ('${heading['logo'] ?? ''}'.isEmpty && '${heading['company'] ?? ''}'.toLowerCase().contains('rachana')) {
    try {
      logo = 'data:image/png;base64,${base64Encode((await rootBundle.load('assets/brand/rachana_logo.png')).buffer.asUint8List())}';
    } catch (_) {/* the company's own logo, or its name */}
  }
  final page = html(logo);
  if (storePaperSink != null) {
    storePaperSink!(page, title);
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrintView(html: page, title: title)));
}

class PoFormScreen extends StatefulWidget {
  const PoFormScreen({super.key, required this.k, required this.site, this.po, this.picked = const []});
  final StoreKit k;
  final String site;
  final Map<String, dynamic>? po;

  /// the requirement lines ticked ({req, line}) – a new PO
  final List<Map<String, dynamic>> picked;
  @override
  State<PoFormScreen> createState() => _PoFormScreenState();
}

class _PoFormScreenState extends State<PoFormScreen> {
  List<Map<String, dynamic>> items = [];
  List<String> vendors = [];
  Map<String, dynamic> gstMap = {};
  late String date = '${widget.po?['date'] ?? widget.k.today}', deliver = '${widget.po?['deliver_by'] ?? ''}';
  late final vendor = TextEditingController(text: '${widget.po?['vendor'] ?? ''}'), vgst = TextEditingController(text: '${widget.po?['vendor_gst'] ?? ''}');
  late final terms = TextEditingController(text: '${widget.po?['terms'] ?? ''}'), rem = TextEditingController(text: '${widget.po?['remark'] ?? ''}');
  // (3.62.0, the Store's step 5 – his Diesel PO's format) the PO Details: Credit Period, Site Contact, Shipping Address; Freight,
  // Load / Unload (a new PO starts with the site's Shipping Address, Site Contact and Terms of the Store's settings)
  late final credit = TextEditingController(text: widget.po?['credit_days'] == null ? '' : plainN(widget.po!['credit_days']));
  late final siteContact = TextEditingController(text: '${widget.po?['site_contact'] ?? ''}'), shipTo = TextEditingController(text: '${widget.po?['ship_to'] ?? ''}');
  late final freight = TextEditingController(text: _nz(widget.po?['freight'])), loadUnload = TextEditingController(text: _nz(widget.po?['load_unload']));
  final lines = <SLine>[];
  bool busy = false, loading = true, step5 = false;
  String err = '';

  /// a PO's amount as the web shows it: none when 0
  static String _nz(Object? v) => v == null || nOf(v) == 0 ? '' : plainN(v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [vendor, vgst, terms, rem, credit, siteContact, shipTo, freight, loadUnload]) {
      c.dispose();
    }
    for (final l in lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await widget.k.call('purItems', {'site': widget.site});
      if (!mounted) return;
      setState(() {
        items = listOf(r['items']);
        vendors = [for (final v in (r['vendors'] as List? ?? const [])) '$v'];
        gstMap = mapOf(r['gst']);
        step5 = r['step5'] == true;
        if (widget.po != null) {
          for (final l in listOf(widget.po!['lines'])) {
            final rq = l['req_no'] == null ? null : nOf(l['req_no']).toInt();
            lines.add(SLine(code: '${l['code']}', name: '${l['name']}', unit: '${l['unit']}', qty: plainN(l['qty']), rate: plainN(l['rate']), gst: plainN(l['gst_pct']), brand: '${l['brand'] ?? ''}', spec: '${l['spec'] ?? ''}', disc: _nz(l['disc_pct']), hsn: '${l['hsn'] ?? ''}', reqNo: rq, reqLine: l['req_line'] == null ? null : nOf(l['req_line']).toInt(), info: rq == null ? '' : 'REQ $rq'));
          }
        } else {
          final pp = mapOf(r['papers']);
          siteContact.text = '${pp['site_contact'] ?? ''}';
          shipTo.text = '${pp['ship_to'] ?? ''}';
          terms.text = '${pp['terms'] ?? ''}';
          for (final p in widget.picked) {
            final r = mapOf(p['req']), l = mapOf(p['line']), it = items.where((i) => i['code'] == l['code']).firstOrNull ?? const <String, dynamic>{};
            lines.add(SLine(code: '${l['code']}', name: '${l['name']}', unit: '${l['unit']}', qty: plainN(l['left']), gst: plainN(it['gst_pct']), brand: '${l['brand'] ?? ''}', spec: '${l['spec'] ?? ''}', hsn: '${it['hsn'] ?? ''}', reqNo: nOf(r['no']).toInt(), reqLine: nOf(l['line']).toInt(), info: 'REQ ${r['no']}'));
          }
        }
        loading = false;
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

  Future<void> _save() async {
    if (lines.isEmpty) return toast(context, 'Add at least one item.', bad: true);
    setState(() => busy = true);
    try {
      final x = <String, dynamic>{
        'site': widget.site,
        if (widget.po != null) 'no': widget.po!['no'],
        'po': <String, dynamic>{
          'date': date,
          'vendor': vendor.text,
          'vendor_gst': vgst.text,
          'deliver_by': deliver,
          'terms': terms.text,
          'remark': rem.text,
          'credit_days': credit.text,
          'site_contact': siteContact.text,
          'ship_to': shipTo.text,
          'freight': freight.text,
          'load_unload': loadUnload.text,
          'lines': [for (final l in lines) {'code': l.code, 'qty': l.qty.text, 'rate': l.rate.text, 'disc_pct': l.disc.text, 'hsn': l.hsn.text, 'gst_pct': l.gst.text, if (l.reqNo != null) 'req_no': l.reqNo, if (l.reqLine != null) 'req_line': l.reqLine, 'brand': l.brand.text, 'spec': l.spec.text}],
        },
      };
      final r = await storeSaveAsk(context, widget.k.call, 'poSave', x);
      if (r == null || !mounted) return;
      toast(context, 'PO ${r['no']} of ${r['site']} saved – ${rs(r['total'])}${r['appr'] == 'Waiting' ? ' – it waits for its approval.' : '.'}');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = linesMoney(lines), fr = step5 ? r2(_d(freight.text)) : 0.0, lu = step5 ? r2(_d(loadUnload.text)) : 0.0;
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: Text(widget.po != null ? 'Change PO ${widget.po!['no']} – ${widget.site}' : 'New purchase order – ${widget.site}')),
      bottomNavigationBar: loading ? null : _saveBar('po-save', 'Save PO', busy, _save),
      body: loading
          ? _loading()
          : ListView(key: const Key('pof'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
              if (err.isNotEmpty) InfoLine(err, bad: true),
              Row(children: [
                Expanded(child: DateField(key: const Key('pof-date'), label: 'PO date *', value: date, clear: false, onChanged: (v) => setState(() => date = v))),
                const SizedBox(width: 8),
                Expanded(child: DateField(key: const Key('pof-del'), label: 'Delivery by', value: deliver, onChanged: (v) => setState(() => deliver = v))),
              ]),
              const SizedBox(height: 8),
              TextBox(
                key: const Key('pof-ven'),
                label: 'Vendor (supplier) *',
                controller: vendor,
                options: vendors,
                onChanged: (v) {
                  final g = gstMap[v.trim()];
                  if (g != null && vgst.text.trim().isEmpty) vgst.text = '$g';
                },
              ),
              const SizedBox(height: 8),
              TextBox(key: const Key('pof-gst'), label: 'Vendor GST no.', controller: vgst, upper: true),
              if (step5) ...[
                const SizedBox(height: 8),
                TextBox(key: const Key('pof-cr'), label: 'Credit Period (days)', hint: 'e.g. 0 or 30', controller: credit, kb: TextInputType.number),
                const SizedBox(height: 8),
                TextBox(key: const Key('pof-sc'), label: 'Site Contact', hint: 'Name : mobile', controller: siteContact),
                const SizedBox(height: 8),
                TextBox(key: const Key('pof-ship'), label: 'Shipping Address', controller: shipTo, maxLines: 2),
                const SizedBox(height: 8),
                TextBox(key: const Key('pof-fr'), label: 'Total Freight Charges ₹', controller: freight, kb: _dec, onChanged: (_) => setState(() {})),
                const SizedBox(height: 8),
                TextBox(key: const Key('pof-lu'), label: 'Total Load / Unload Amount ₹', controller: loadUnload, kb: _dec, onChanged: (_) => setState(() {})),
              ],
              const SizedBox(height: 8),
              TextBox(key: const Key('pof-terms'), label: 'Terms And Conditions (one a line)', controller: terms, maxLines: 4),
              const SizedBox(height: 8),
              TextBox(key: const Key('pof-rem'), label: 'Remark', controller: rem),
              const SizedBox(height: 14),
              Text('Items', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              SLinesEditor(k: widget.k, lines: lines, items: items, tag: 'pol', rateLabel: 'Rate ₹ *', gst: true, gstFill: true, money: true, brandSpec: true, discHsn: true, onChanged: () => setState(() {})),
              const SizedBox(height: 10),
              Text('Taxable ${rs(m.t)} · GST ${rs(m.g)}${fr > 0 ? ' · Freight ${rs(fr)}' : ''}${lu > 0 ? ' · Load / Unload ${rs(lu)}' : ''} · Total ${rs(r2(m.all + fr + lu))}', key: const Key('pof-total'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              if (!step5) Padding(padding: const EdgeInsets.only(top: 8), child: Text('The Credit Period, Site Contact, Shipping Address, Freight, Load / Unload and the PO\'s approval come after the Store\'s database step 5 (sql/store_step5_po_format.sql) is run at this site.', key: const Key('pof-step5'), style: _muted)),
            ]),
    );
  }
}

/* ======================== PURCHASE ORDERS OF THIS SITE ======================== */
class PoListScreen extends StatefulWidget {
  const PoListScreen({super.key, required this.k});
  final StoreKit k;
  @override
  State<PoListScreen> createState() => _PoListScreenState();
}

class _PoListScreenState extends State<PoListScreen> {
  List<Map<String, dynamic>> pos = [];
  bool pending = false, loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.k.call('poList');
      if (!mounted) return;
      setState(() {
        pos = listOf(r['pos']);
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

  @override
  Widget build(BuildContext context) {
    final list = pending ? pos.where((p) => p['status'] == 'Open' && p['state'] != 'Received').toList() : pos;
    return Scaffold(
      appBar: _bar('Purchase Orders', 'खरेदी ऑर्डर', refresh: _load),
      body: loading
          ? _loading()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('pol-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), children: [
                Text('Made by HO Purchase; what has come is from the GRNs against each.', style: _muted),
                if (err.isNotEmpty) InfoLine(err, bad: true),
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(key: const Key('pol-pend'), contentPadding: EdgeInsets.zero, value: pending, onChanged: (v) => setState(() => pending = v), title: Text('Only what is still to come', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
                ),
                Row(children: [
                  Expanded(child: Text('${list.length} PO(s)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                  _small('pol-xl', 'Export to Excel', () => storeExcel(context, widget.k, {'kind': 'po', 'pending': pending})),
                ]),
                const SizedBox(height: 8),
                if (list.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No purchase order.', textAlign: TextAlign.center, style: _muted)),
                for (final p in list) PoCard(k: widget.k, po: p, sites: false, reload: _load),
              ]),
            ),
    );
  }
}

/* ======================== INWARD (GRN) ======================== */
/// A GRN as its paper (the web's GRN print).
/// (3.57.0) the GRN No as shown: an old register's GRN No ("342-A") – else its number
String grnRef(Map g) => '${g['ref'] ?? ''}'.isNotEmpty ? '${g['ref']}' : '${g['no']}';

RDoc grnDoc(Map<String, dynamic> g) {
  final lines = listOf(g['lines']);
  return RDoc(
    title: 'Goods Received Note – GRN ${grnRef(g)}',
    file: 'GRN_${grnRef(g).replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '_')}',
    meta: [
      dmy(g['date']),
      'Supplier: ${g['supplier'] ?? ''}',
      [
        if ('${g['invoice_no'] ?? ''}'.isNotEmpty) 'Invoice ${g['invoice_no']} ${dmy(g['invoice_date'])}'.trim(),
        if ('${g['challan_no'] ?? ''}'.isNotEmpty) 'Challan ${g['challan_no']}',
        if ('${g['vehicle_no'] ?? ''}'.isNotEmpty) 'Vehicle ${g['vehicle_no']}',
        if (g['po_no'] != null) 'PO ${g['po_no']}',
      ].join(' · '),
    ].where((x) => x.isNotEmpty).join('\n'),
    blocks: [
      RTable(
        sheet: 'GRN ${grnRef(g)}',
        head: const ['#', 'Material', 'Received Qty', 'UOM', 'Basic Rate', 'Taxable', 'GST %', 'GST', 'Gross', 'Remark'],
        numCols: const {2, 4, 5, 6, 7, 8},
        rows: [
          for (final (i, l) in lines.indexed)
            RRow([sc(i + 1), tc(l['name']), RCell(q3(l['qty']), n: true, value: nOf(l['qty'])), tc(l['unit']), mc(l['rate']), mc(l['taxable']), RCell(q3(l['gst_pct']), n: true, value: nOf(l['gst_pct'])), mc(l['gst']), mc(l['gross']), tc(l['remark'] ?? '')]),
        ],
        foot: [
          if (nOf(g['tcs']) != 0) RRow([RCell('TCS', span: 8), mc(g['tcs']), tc('')]),
          RRow([RCell('Gross', bold: true, span: 8), mc(g['gross'], bold: true), tc('')], kind: RKind.grand),
        ],
      ),
      if ('${g['remark'] ?? ''}'.isNotEmpty) RNote('${g['remark']}'),
    ],
    signs: [('Received by', '${g['created_name'] ?? ''}'), ('Store in-charge', '')],
  );
}

class GrnListScreen extends StatefulWidget {
  const GrnListScreen({super.key, required this.k});
  final StoreKit k;
  @override
  State<GrnListScreen> createState() => _GrnListScreenState();
}

class _GrnListScreenState extends State<GrnListScreen> {
  List<Map<String, dynamic>> grns = [];
  late String from = widget.k.monthStart, to = widget.k.today;
  bool loading = true;
  String err = '';
  StoreKit get k => widget.k;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await k.boot();
      if (mounted) {
        setState(() {
          from = k.monthStart;
          to = k.today;
        });
      }
    } catch (_) {/* the list says why */}
    await _load();
  }

  Future<void> _load() async {
    try {
      final r = await k.call('grnList', {'from': from, 'to': to});
      if (!mounted) return;
      setState(() {
        grns = listOf(r['grns']);
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

  Future<void> _form(Map<String, dynamic>? g) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => GrnFormScreen(k: k, grn: g)));
    if (saved == true) {
      await k.boot().catchError((_) {});
      await _load();
    }
  }

  Future<void> _delete(Map g) async {
    if (!await ask(context, 'Delete GRN ${grnRef(g)}?', bi('Its material goes out of the stock (refused if it was issued already).', 'हा GRN डिलीट होईल.'), yes: 'Delete', danger: true)) return;
    try {
      await k.call('grnDelete', {'no': g['no']});
      if (!mounted) return;
      toast(context, 'GRN ${grnRef(g)} deleted.');
      await k.boot().catchError((_) {});
      await _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  /// (3.57.0, "ji excel diley tech column mala GRN / inward madhe de") a GRN in the columns of his inward register: GRN No, GRN Date,
  /// Challan No, Invoice No., Invoice Date, Vehicle No, Supplier Name; each material its Received Qty, UOM, Basic Rate, Taxable Amount,
  /// GST Amount, Gross Amount, Remark; TCS, PO No
  Widget _tile(Map<String, dynamic> g) {
    final no = nOf(g['no']).toInt();
    return _card(key: Key('gr-$no'), children: [
      Row(children: [Expanded(child: Text('GRN ${grnRef(g)} · ${dmy(g['date'])}', style: _bold)), Text(rs(g['gross']), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))]),
      Text('${g['supplier'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      Text(
          [
            if ('${g['challan_no'] ?? ''}'.isNotEmpty) 'Challan No ${g['challan_no']}',
            if ('${g['invoice_no'] ?? ''}'.isNotEmpty) 'Invoice No. ${g['invoice_no']}',
            if ('${g['invoice_date'] ?? ''}'.isNotEmpty) 'Invoice Date ${dmy(g['invoice_date'])}',
            if ('${g['vehicle_no'] ?? ''}'.isNotEmpty) 'Vehicle No ${g['vehicle_no']}',
            if (nOf(g['tcs']) != 0) 'TCS ${rs(g['tcs'])}',
            if (g['po_no'] != null) 'PO No ${g['po_no']}',
          ].join(' · '),
          style: _faint),
      for (final l in listOf(g['lines']))
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text('• ${l['name']} – ${q3(l['qty'])} ${l['unit']} @ ${q3(l['rate'])} · Taxable ${rs(l['taxable'])} · GST ${rs(l['gst'])} · Gross ${rs(l['gross'])}${'${l['remark'] ?? ''}'.isNotEmpty ? ' · ${l['remark']}' : ''}',
              style: const TextStyle(fontSize: 13.5)),
        ),
      Wrap(spacing: 2, children: [
        _act('gr-print-$no', 'Print', () => printDoc(context, SessionScope.read(context), grnDoc(g)), color: C.blue),
        if (k.admin) ...[_act('gr-edit-$no', 'Change', () => _form(g), color: C.blue), _act('gr-del-$no', 'Delete', () => _delete(g), color: C.red)],
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final total = grns.fold<num>(0, (a, g) => a + nOf(g['gross']));
    return Scaffold(
      appBar: _bar('Inward (GRN)', 'आवक (GRN)', refresh: _load),
      floatingActionButton: !loading && k.edit('grn') ? _fab('gr-new', 'New GRN', () => _form(null)) : null,
      body: loading
          ? _loading()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('gr-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 90), children: [
                Text('Material received: against a purchase order or direct (a bill). Its basic rate makes the item\'s average rate.', style: _muted),
                const SizedBox(height: 8),
                _dates('gr', from, to, (v) => setState(() => from = v), (v) => setState(() => to = v), _load),
                if (err.isNotEmpty) InfoLine(err, bad: true),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _small('gr-xl', 'GRN register (Excel)', () => storeExcel(context, k, {'kind': 'grn', 'from': from, 'to': to})),
                  if (k.admin) ...[
                    _small('gr-imp', 'Import from Excel', () => storeRegImport(context, k, _load), icon: Icons.upload_file_rounded), // (3.57.0) his inward register – the check first
                    _small('gr-tpl', 'Import format', () => storeDocTemplate(context, 'grn'), icon: Icons.download_rounded),
                  ],
                ]),
                const SizedBox(height: 8),
                Text('${grns.length} GRN(s) · ${rs(total)}', key: const Key('gr-count'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (grns.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No GRN in these dates.', textAlign: TextAlign.center, style: _muted)),
                for (final g in grns) _tile(g),
              ]),
            ),
    );
  }
}

class GrnFormScreen extends StatefulWidget {
  const GrnFormScreen({super.key, required this.k, this.grn});
  final StoreKit k;
  final Map<String, dynamic>? grn;
  @override
  State<GrnFormScreen> createState() => _GrnFormScreenState();
}

class _GrnFormScreenState extends State<GrnFormScreen> {
  List<Map<String, dynamic>> pos = [];
  String po = '', date = '', invDate = '';
  final sup = TextEditingController(), ch = TextEditingController(), inv = TextEditingController(), veh = TextEditingController(), tcs = TextEditingController(), rem = TextEditingController();

  /// (3.58.0, the web's 28-10-2026) a new GRN's GRN No: the next by itself (grnNext), changed by hand where the site has the Store's step 4
  final ref = TextEditingController();
  bool step4 = false, refTyped = false;
  final lines = <SLine>[];
  bool busy = false, loading = true;

  @override
  void initState() {
    super.initState();
    _fill();
    _load();
  }

  /// the form as it opens: a new GRN empty, a GRN being changed as it is saved (also what Clear does)
  void _fill() {
    final g = widget.grn;
    po = g?['po_no'] == null ? '' : '${g!['po_no']}';
    date = '${g?['date'] ?? widget.k.today}';
    invDate = '${g?['invoice_date'] ?? ''}';
    sup.text = '${g?['supplier'] ?? ''}';
    ch.text = '${g?['challan_no'] ?? ''}';
    inv.text = '${g?['invoice_no'] ?? ''}';
    veh.text = '${g?['vehicle_no'] ?? ''}';
    tcs.text = plainN(g?['tcs']);
    rem.text = '${g?['remark'] ?? ''}';
    if (g != null) ref.text = grnRef(g);
    final old = [...lines];
    lines.clear();
    for (final l in listOf(g?['lines'])) {
      final pl = l['po_line'] == null ? null : nOf(l['po_line']).toInt();
      lines.add(SLine(code: '${l['code']}', name: '${l['name']}', unit: '${l['unit']}', qty: plainN(l['qty']), rate: plainN(l['rate']), gst: plainN(l['gst_pct']), note: '${l['remark'] ?? ''}', poLine: pl, info: pl == null ? '' : 'PO line $pl'));
    }
    if (old.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final l in old) {
          l.dispose();
        }
      });
    }
  }

  /// (28-10-2026, as the web's GRN form) Clear: asked first when something is typed; nothing saved is changed
  Future<void> _clear() async {
    final typed = lines.isNotEmpty || sup.text.trim().isNotEmpty;
    if (typed && !await ask(context, 'Clear the form?', bi(widget.grn != null ? 'The GRN comes back as it is saved – what is typed here goes. Nothing saved is changed.' : 'What is typed here goes. Nothing saved is changed.', 'फॉर्म मध्ये टाइप केलेले जाईल – save केलेले काहीही बदलत नाही.'), yes: 'Clear')) return;
    if (!mounted) return;
    setState(_fill);
    if (widget.grn == null) {      // (3.58.0, as the web's form drawn again) the next GRN No again
      refTyped = false;
      await _next();
    }
  }

  @override
  void dispose() {
    for (final c in [sup, ch, inv, veh, tcs, rem, ref]) {
      c.dispose();
    }
    for (final l in lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    var l = <Map<String, dynamic>>[];
    try {
      l = listOf((await widget.k.call('poOpen'))['pos']);
    } catch (_) {/* no open PO to pick */}
    final g = widget.grn;
    if (g != null && g['po_no'] != null && !l.any((p) => nOf(p['no']) == nOf(g['po_no']))) l.add({'no': g['po_no'], 'vendor': g['supplier'], 'lines': const []});
    if (g == null) await _next();
    if (mounted) {
      setState(() {
        pos = l;
        loading = false;
      });
    }
  }

  /// the next GRN No (a new GRN) – not when he typed one
  Future<void> _next() async {
    try {
      final r = await widget.k.call('grnNext');
      if (!mounted || refTyped) return;
      setState(() {
        ref.text = '${r['next'] ?? ''}';
        step4 = r['step4'] == true;
      });
    } catch (_) {/* the server gives the number when it is left empty */}
  }

  /// another PO picked: its lines still to come (the GRN being changed: its own lines)
  void _pickPo(String v) {
    final p = pos.where((x) => '${x['no']}' == v).firstOrNull, g = widget.grn;
    lines.clear();
    if (g != null && '${g['po_no'] ?? ''}' == v) {
      for (final l in listOf(g['lines'])) {
        final pl = l['po_line'] == null ? null : nOf(l['po_line']).toInt();
        lines.add(SLine(code: '${l['code']}', name: '${l['name']}', unit: '${l['unit']}', qty: plainN(l['qty']), rate: plainN(l['rate']), gst: plainN(l['gst_pct']), note: '${l['remark'] ?? ''}', poLine: pl, info: pl == null ? '' : 'PO line $pl'));
      }
    } else if (p != null) {
      for (final l in listOf(p['lines'])) {
        if (nOf(l['left']) <= 0) continue;
        lines.add(SLine(code: '${l['code']}', name: '${l['name']}', unit: '${l['unit']}', qty: plainN(l['left']), rate: plainN(l['rate']), gst: plainN(l['gst_pct']), poLine: nOf(l['line']).toInt(), info: 'PO line ${l['line']}'));
      }
      if (g == null && sup.text.trim().isEmpty) sup.text = '${p['vendor'] ?? ''}';
    }
    setState(() => po = v);
  }

  Future<void> _save() async {
    if (lines.isEmpty) return toast(context, 'Add at least one item.', bad: true);
    setState(() => busy = true);
    try {
      final x = <String, dynamic>{
        if (widget.grn != null) 'no': widget.grn!['no'],
        'grn': <String, dynamic>{
          if (widget.grn == null) 'ref': ref.text.trim(),
          if (po.isNotEmpty) 'po_no': int.tryParse(po) ?? po,
          'date': date,
          'supplier': sup.text,
          'challan_no': ch.text,
          'invoice_no': inv.text,
          'invoice_date': invDate,
          'vehicle_no': veh.text,
          'tcs': tcs.text,
          'remark': rem.text,
          'lines': [for (final l in lines) {'code': l.code, 'qty': l.qty.text, 'rate': l.rate.text, 'gst_pct': l.gst.text, if (l.poLine != null) 'po_line': l.poLine, 'remark': l.note.text}],
        },
      };
      final r = await storeSaveAsk(context, widget.k.call, 'grnSave', x);
      if (r == null || !mounted) return;
      toast(context, 'GRN ${r['ref'] ?? r['no']} saved – ${rs(r['gross'])}.');
      Navigator.pop(context, true);
    } catch (e) {
      // (3.58.0) a GRN No already used: the next free one in its box (the server says it)
      if (e is ApiError && e.code == 'refused' && e.data['next'] != null && mounted) {
        ref.text = '${e.data['next']}';
        refTyped = false;
      }
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = linesMoney(lines), t = _d(tcs.text);
    final poLabels = {
      for (final p in pos)
        '${p['no']}': 'PO ${p['no']} – ${p['vendor'] ?? ''}${listOf(p['lines']).isEmpty ? '' : ' (${listOf(p['lines']).where((l) => nOf(l['left']) > 0).map((l) => '${l['name']} ${q3(l['left'])}').join(', ')})'}',
    };
    return Scaffold(
      appBar: AppBar(actions: withAsk([IconButton(key: const Key('grf-clear'), tooltip: tr('Clear'), onPressed: loading || busy ? null : _clear, icon: const Icon(Icons.restart_alt_rounded))]), title: Text(widget.grn != null ? 'Change GRN ${grnRef(widget.grn!)}' : 'New GRN')),
      bottomNavigationBar: loading ? null : _saveBar('gr-save', 'Save GRN', busy, _save),
      body: loading
          ? _loading()
          : ListView(key: const Key('grf'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
              PickField(key: const Key('grf-po'), label: 'Against PO', value: po, items: poLabels.keys.toList(), labels: poLabels, blank: 'Direct (no PO)', onChanged: _pickPo),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextBox(
                        key: const Key('grf-ref'),
                        label: 'GRN No',
                        controller: ref,
                        enabled: widget.grn == null && step4,
                        hint: widget.grn == null && !step4 ? 'the next number' : '',
                        onChanged: (_) => refTyped = true)),
                const SizedBox(width: 8),
                Expanded(child: DateField(key: const Key('grf-date'), label: 'GRN date *', value: date, clear: false, onChanged: (v) => setState(() => date = v))),
              ]),
              const SizedBox(height: 8),
              DateField(key: const Key('grf-invd'), label: 'Invoice date', value: invDate, onChanged: (v) => setState(() => invDate = v)),
              const SizedBox(height: 8),
              TextBox(key: const Key('grf-sup'), label: 'Supplier *', controller: sup, options: widget.k.names('suppliers')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextBox(key: const Key('grf-inv'), label: 'Invoice No', controller: inv)),
                const SizedBox(width: 8),
                Expanded(child: TextBox(key: const Key('grf-ch'), label: 'Challan No', controller: ch)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextBox(key: const Key('grf-veh'), label: 'Vehicle No', controller: veh, upper: true)),
                const SizedBox(width: 8),
                Expanded(child: TextBox(key: const Key('grf-tcs'), label: 'TCS ₹', controller: tcs, kb: _dec, onChanged: (_) => setState(() {}))),
              ]),
              const SizedBox(height: 8),
              TextBox(key: const Key('grf-rem'), label: 'Remark', controller: rem),
              const SizedBox(height: 14),
              Text('Items', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              SLinesEditor(k: widget.k, lines: lines, tag: 'grl', qtyLabel: 'Received Qty *', rateLabel: 'Basic Rate ₹', gst: true, gstFill: true, money: true, noteLabel: 'Remark', onChanged: () => setState(() {})),
              const SizedBox(height: 10),
              Text('Taxable ${rs(m.t)} · GST ${rs(m.g)}${t != 0 ? ' · TCS ${rs(t)}' : ''} · Gross ${rs(r2(m.all + t))}', key: const Key('grf-total'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
    );
  }
}

/* ======================== ISSUE (OUTWARD) & RETURN ======================== */
/// An issue as its paper (the web's Outward print).
RDoc issueDoc(Map<String, dynamic> i) {
  final lines = listOf(i['lines']);
  return RDoc(
    title: 'Issue (Outward) – ${i['no']}',
    file: 'Outward_${i['no']}',
    meta: [
      dmy(i['date']),
      'Issued to: ${storeToWho(i)}',
      [
        if ('${i['location'] ?? ''}'.isNotEmpty) 'Location ${i['location']}',
        if ('${i['side'] ?? ''}'.isNotEmpty) '${i['side']}',
        if ('${i['use_for'] ?? ''}'.isNotEmpty) 'Use for: ${i['use_for']}',
        if ('${i['receiver'] ?? ''}'.isNotEmpty) 'Receiver: ${i['receiver']}',
      ].join(' · '),
    ].where((x) => x.isNotEmpty).join('\n'),
    blocks: [
      RTable(
        sheet: 'Outward ${i['no']}',
        head: const ['#', 'Material', 'Qty', 'UOM', 'Rate', 'Amount', 'Returnable', 'Serial No'],
        numCols: const {2, 4, 5},
        rows: [
          for (final (n, l) in lines.indexed)
            RRow([sc(n + 1), tc(l['name']), RCell(q3(l['qty']), n: true, value: nOf(l['qty'])), tc(l['unit']), mc(l['rate']), mc(r2(nOf(l['amount']) + nOf(l['gst']))), tc(l['returnable'] == true ? 'Yes' : ''), tc(l['serial'] ?? '')]),
        ],
      ),
    ],
    signs: [('Issued by', '${i['created_name'] ?? ''}'), ('Received by', '${i['receiver'] ?? ''}')],
  );
}

class IssueListScreen extends StatefulWidget {
  const IssueListScreen({super.key, required this.k});
  final StoreKit k;
  @override
  State<IssueListScreen> createState() => _IssueListScreenState();
}

class _IssueListScreenState extends State<IssueListScreen> {
  List<Map<String, dynamic>> issues = [];
  late String from = widget.k.monthStart, to = widget.k.today;
  bool loading = true;
  String err = '';
  StoreKit get k => widget.k;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await k.boot();
      if (mounted) {
        setState(() {
          from = k.monthStart;
          to = k.today;
        });
      }
    } catch (_) {/* the list says why */}
    await _load();
  }

  Future<void> _load() async {
    try {
      final r = await k.call('issueList', {'from': from, 'to': to});
      if (!mounted) return;
      setState(() {
        issues = listOf(r['issues']);
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

  Future<void> _after(bool? saved) async {
    if (saved != true) return;
    await k.boot().catchError((_) {});
    await _load();
  }

  Future<void> _form(Map<String, dynamic>? i) async => _after(await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => IssueFormScreen(k: k, issue: i))));

  Future<void> _ret(Map<String, dynamic> i) async {
    if (!listOf(i['lines']).any((l) => nOf(l['qty']) - nOf(l['back']) > 0.0005)) return toast(context, 'Everything of outward ${i['no']} has come back.', bad: true);
    await _after(await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ReturnFormScreen(k: k, issue: i))));
  }

  Future<void> _del(String what, String action, Object no, String body) async {
    if (!await ask(context, 'Delete $what $no?', body, yes: 'Delete', danger: true)) return;
    try {
      await k.call(action, {'no': no});
      if (!mounted) return;
      toast(context, '${what[0].toUpperCase()}${what.substring(1)} $no deleted.');
      await _after(true);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  Widget _tile(Map<String, dynamic> i) {
    final no = nOf(i['no']).toInt(), lines = listOf(i['lines']), rets = listOf(i['returns']);
    final out = lines.where((l) => l['returnable'] == true && nOf(l['qty']) - nOf(l['back']) > 0.0005).length;
    return _card(key: Key('is-$no'), children: [
      Row(children: [
        Expanded(child: Text('Outward $no · ${dmy(i['date'])}', style: _bold)),
        if (i['debit'] == true) const Padding(padding: EdgeInsets.only(right: 6), child: Pill('Debit', color: C.amber, bg: C.amberSoft)),
        Text(rs(i['amount']), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
      ]),
      Text(storeToWho(i), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      Text(
          [
            if ('${i['receiver'] ?? ''}'.isNotEmpty) 'Receiver ${i['receiver']}',
            if (i['reading'] != null) 'Reading ${q3(i['reading'])}',
            if ('${i['location'] ?? ''}'.isNotEmpty) '${i['location']}',
            if ('${i['side'] ?? ''}'.isNotEmpty) '${i['side']}',
            if ('${i['use_for'] ?? ''}'.isNotEmpty) '${i['use_for']}',
          ].join(' · '),
          style: _faint),
      for (final l in lines) Text('• ${l['name']} ${q3(l['qty'])} ${l['unit']}${l['returnable'] == true ? ' (returnable${nOf(l['back']) > 0 ? ', ${q3(l['back'])} back' : ''})' : nOf(l['back']) > 0 ? ' (${q3(l['back'])} back)' : ''}', style: const TextStyle(fontSize: 13.5)),
      for (final r in rets)
        Row(children: [
          Expanded(child: Text('Return ${r['no']} · ${dmy(r['date'])}', style: const TextStyle(fontSize: 13, color: C.blue, fontWeight: FontWeight.w600))),
          if (k.admin) _act('is-rdel-${r['no']}', 'Delete', () => _del('return', 'retDelete', r['no'] as Object, 'What came back goes out of the stock again.'), color: C.red),
        ]),
      if (out > 0) Text('$out returnable item(s) out', style: const TextStyle(fontSize: 12.5, color: C.amber, fontWeight: FontWeight.w600)),
      Wrap(spacing: 2, children: [
        if (k.edit('issue')) _act('is-ret-$no', 'Return', () => _ret(i)),
        _act('is-print-$no', 'Print', () => printDoc(context, SessionScope.read(context), issueDoc(i)), color: C.blue),
        if (k.admin) ...[
          _act('is-edit-$no', 'Change', () => _form(i), color: C.blue),
          _act('is-del-$no', 'Delete', () => _del('outward', 'issueDelete', no, bi('Its material comes back into the stock.', 'हे issue डिलीट होईल.')), color: C.red),
        ],
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final total = issues.fold<num>(0, (a, i) => a + nOf(i['amount']));
    return Scaffold(
      appBar: _bar('Issue & Return', 'इश्यू आणि परत', refresh: _load),
      floatingActionButton: !loading && k.edit('issue') ? _fab('is-new', 'New issue', () => _form(null)) : null,
      body: loading
          ? _loading()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('is-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 90), children: [
                Text('Material given out: to site work, a sub-contractor, a machinery (it goes into its maintenance log book in Mechanical) or the office; what comes back – Return.', style: _muted),
                const SizedBox(height: 8),
                _dates('is', from, to, (v) => setState(() => from = v), (v) => setState(() => to = v), _load),
                if (err.isNotEmpty) InfoLine(err, bad: true),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _small('is-xl', 'Issue register (Excel)', () => storeExcel(context, k, {'kind': 'issue', 'from': from, 'to': to})),
                  if (k.admin) ...[
                    _small('is-imp', 'Import from Excel', () => storeDocImport(context, k, 'issue', _load), icon: Icons.upload_file_rounded),
                    _small('is-tpl', 'Import format', () => storeDocTemplate(context, 'issue'), icon: Icons.download_rounded),
                  ],
                ]),
                const SizedBox(height: 8),
                Text('${issues.length} issue(s) · ${rs(total)}', key: const Key('is-count'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (issues.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No issue in these dates.', textAlign: TextAlign.center, style: _muted)),
                for (final i in issues) _tile(i),
              ]),
            ),
    );
  }
}

class IssueFormScreen extends StatefulWidget {
  const IssueFormScreen({super.key, required this.k, this.issue});
  final StoreKit k;
  final Map<String, dynamic>? issue;
  @override
  State<IssueFormScreen> createState() => _IssueFormScreenState();
}

class _IssueFormScreenState extends State<IssueFormScreen> {
  late final Map<String, dynamic> i0 = widget.issue ?? const <String, dynamic>{};
  late String date = '${i0['date'] ?? widget.k.today}', kind = '${i0['to_kind'] ?? 'Site work'}', mach = '${i0['machinery'] ?? ''}', side = '${i0['side'] ?? ''}';
  late bool debit = i0['debit'] == true;
  late final party = TextEditingController(text: '${i0['party'] ?? ''}'), reading = TextEditingController(text: plainN(i0['reading'])), loc = TextEditingController(text: '${i0['location'] ?? ''}');
  late final use = TextEditingController(text: '${i0['use_for'] ?? ''}'), rcv = TextEditingController(text: '${i0['receiver'] ?? ''}'), rem = TextEditingController(text: '${i0['remark'] ?? ''}');
  final lines = <SLine>[];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    for (final l in listOf(i0['lines'])) {
      lines.add(SLine(code: '${l['code']}', name: '${l['name']}', unit: '${l['unit']}', qty: plainN(l['qty']), returnable: l['returnable'] == true, serial: '${l['serial'] ?? ''}', rate: debit ? plainN(l['rate']) : '', gst: debit ? plainN(l['gst_pct']) : '', note: '${l['remark'] ?? ''}'));
    }
  }

  @override
  void dispose() {
    for (final c in [party, reading, loc, use, rcv, rem]) {
      c.dispose();
    }
    for (final l in lines) {
      l.dispose();
    }
    super.dispose();
  }

  bool get _mayDebit => kind == 'Sub-contractor' || kind == 'Machinery';

  Future<void> _save() async {
    if (lines.isEmpty) return toast(context, 'Add at least one item.', bad: true);
    setState(() => busy = true);
    try {
      final x = <String, dynamic>{
        if (widget.issue != null) 'no': widget.issue!['no'],
        'issue': <String, dynamic>{
          'date': date,
          'to_kind': kind,
          'party': kind == 'Sub-contractor' ? party.text : '',
          'machinery': kind == 'Machinery' ? mach : '',
          'reading': kind == 'Machinery' ? reading.text : '',
          'location': loc.text,
          'side': side,
          'use_for': use.text,
          'receiver': rcv.text,
          'debit': debit && _mayDebit,
          'remark': rem.text,
          'lines': [
            for (final l in lines) {'code': l.code, 'qty': l.qty.text, 'returnable': l.returnable, 'serial': l.serial.text, 'rate': debit && _mayDebit ? l.rate.text : '', 'gst_pct': debit && _mayDebit ? l.gst.text : '', 'remark': l.note.text},
          ],
        },
      };
      final r = await storeSaveAsk(context, widget.k.call, 'issueSave', x);
      if (r == null || !mounted) return;
      toast(context, 'Outward ${r['no']} saved – ${rs(r['amount'])}.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.k, ml = k.machLabels, deb = debit && _mayDebit;
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: Text(widget.issue != null ? 'Change outward ${widget.issue!['no']}' : 'New issue')),
      bottomNavigationBar: _saveBar('is-save', 'Save issue', busy, _save),
      body: ListView(key: const Key('isf'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        Row(children: [
          Expanded(child: DateField(key: const Key('isf-date'), label: 'Date *', value: date, clear: false, onChanged: (v) => setState(() => date = v))),
          const SizedBox(width: 8),
          Expanded(child: PickField(key: const Key('isf-kind'), label: 'Issued to *', value: kind, items: k.kinds('to'), onChanged: (v) => setState(() => kind = v))),
        ]),
        const SizedBox(height: 8),
        if (kind == 'Sub-contractor') TextBox(key: const Key('isf-party'), label: 'Sub-contractor *', controller: party, options: k.names('subs')),
        if (kind == 'Machinery')
          Row(children: [
            Expanded(flex: 2, child: PickField(key: const Key('isf-mach'), label: 'Machinery *', value: mach, items: ml.keys.toList(), labels: ml, blank: 'Pick…', onChanged: (v) => setState(() => mach = v))),
            const SizedBox(width: 8),
            Expanded(child: TextBox(key: const Key('isf-read'), label: 'Reading (KM / Hrs)', controller: reading, kb: _dec)),
          ]),
        if (kind == 'Sub-contractor' || kind == 'Machinery') const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 2, child: TextBox(key: const Key('isf-loc'), label: 'Location (chainage)', controller: loc, hint: 'e.g. 540+450 to 540+480')),
          const SizedBox(width: 8),
          Expanded(child: PickField(key: const Key('isf-side'), label: 'Side', value: side, items: k.kinds('sides'), blank: '–', onChanged: (v) => setState(() => side = v))),
        ]),
        const SizedBox(height: 8),
        TextBox(key: const Key('isf-use'), label: 'Use for (work)', controller: use, hint: 'e.g. Toe wall, BC, Consumable'),
        const SizedBox(height: 8),
        TextBox(key: const Key('isf-rcv'), label: 'Receiver', controller: rcv),
        if (_mayDebit)
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: const Key('isf-deb'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: debit,
              onChanged: (v) => setState(() {
                debit = v == true;
                if (debit) {
                  for (final l in lines) {
                    final it = k.item(l.code);
                    if (l.gst.text.isEmpty && it != null && it['gst_pct'] != null) l.gst.text = plainN(it['gst_pct']);
                  }
                }
              }),
              title: Text('On debit (charged to them, with GST)', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(height: 8),
        TextBox(key: const Key('isf-rem'), label: 'Remark', controller: rem),
        const SizedBox(height: 14),
        Text('Items', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        SLinesEditor(k: k, lines: lines, tag: 'isl', stock: true, returnable: true, serial: true, rateLabel: deb ? 'Debit rate ₹ (blank = average)' : '', gst: deb, gstFill: deb, noteLabel: 'Remark', onChanged: () => setState(() {})),
      ]),
    );
  }
}

class ReturnFormScreen extends StatefulWidget {
  const ReturnFormScreen({super.key, required this.k, required this.issue});
  final StoreKit k;
  final Map<String, dynamic> issue;
  @override
  State<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends State<ReturnFormScreen> {
  late String date = widget.k.today;
  final rem = TextEditingController();
  late final left = [for (final l in listOf(widget.issue['lines'])) if (nOf(l['qty']) - nOf(l['back']) > 0.0005) l];
  late final qty = [for (final _ in left) TextEditingController()], why = [for (final _ in left) TextEditingController()];
  bool busy = false;

  @override
  void dispose() {
    rem.dispose();
    for (final c in [...qty, ...why]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final ls = [
      for (var n = 0; n < left.length; n++)
        if (qty[n].text.trim().isNotEmpty) {'issue_line': left[n]['id'], 'qty': qty[n].text.trim(), 'remark': why[n].text},
    ];
    if (ls.isEmpty) return toast(context, 'Type what came back of at least one item.', bad: true);
    setState(() => busy = true);
    try {
      final r = await widget.k.call('retSave', {'ret': {'issue_no': widget.issue['no'], 'date': date, 'remark': rem.text, 'lines': ls}});
      if (!mounted) return;
      toast(context, 'Return ${r['no']} saved.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.issue;
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: Text('Return – outward ${i['no']}')),
      bottomNavigationBar: _saveBar('rt-save', 'Save return', busy, _save),
      body: ListView(key: const Key('rtf'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        Text('Back to the store from ${storeToWho(i)} – outward ${i['no']} of ${dmy(i['date'])}', style: _muted),
        const SizedBox(height: 8),
        DateField(key: const Key('rtf-date'), label: 'Return date *', value: date, clear: false, onChanged: (v) => setState(() => date = v)),
        const SizedBox(height: 8),
        TextBox(key: const Key('rtf-rem'), label: 'Remark', controller: rem),
        const SizedBox(height: 12),
        for (var n = 0; n < left.length; n++)
          _card(key: Key('rt-$n'), children: [
            Row(children: [
              Expanded(child: Text('${left[n]['name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              if (left[n]['returnable'] == true) const Pill('returnable', color: C.blue, bg: C.blueSoft),
            ]),
            Text('Issued ${q3(left[n]['qty'])} ${left[n]['unit']} · back before ${q3(left[n]['back'] ?? 0)} · still out ${q3(r2(nOf(left[n]['qty']) - nOf(left[n]['back'])))}', style: _muted),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextBox(key: Key('rt-q-$n'), label: 'Back now', controller: qty[n], kb: _dec)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: TextBox(key: Key('rt-r-$n'), label: 'Remark (condition)', controller: why[n])),
            ]),
            const SizedBox(height: 6),
          ]),
      ]),
    );
  }
}

/* ======================== EXCEL IMPORT (the Store Admin): his INWARD / OUTWORD columns ======================== */
const kDocImpHead = <String, List<String>>{
  'grn': grnRegHead, // (3.57.0) his inward register's columns – read by the register's import (store_reg.dart)
  'issue': ['Date', 'Outward No', 'Party Name', 'Sub Contractor Name', 'Machinery', 'Reading', 'Material', 'Qty', 'UOM', 'Location', 'Side', 'Use For', 'Receiver Name', 'Returnable', 'Serial No', 'Remark'],
};
final _kDocImpMap = <String, Map<String, RegExp>>{
  'issue': {
    'date': RegExp(r'^date$|issue\s*date'), 'ref': RegExp(r'out\s*w(o|a)rd\s*no|outward\s*no'), 'party': RegExp(r'sub\s*contractor'), 'party0': RegExp('^party'), 'machinery': RegExp('machinery|vehicle'),
    'reading': RegExp('reading'), 'item': RegExp(r'^material|item'), 'qty': RegExp(r'^qty|issued?\s*qty'), 'location': RegExp('location'), 'side': RegExp('^side'), 'use_for': RegExp(r'use\s*for|work\s*desc'),
    'receiver': RegExp('receiver'), 'returnable': RegExp('returnable'), 'serial': RegExp(r'serial|battery\s*no|tyre\s*no'), 'remark': RegExp('remark'),
  },
};

/// A cell of his sheet as text (a date as yyyy-mm-dd – Excel keeps a date as its day number).
String _cellText(Object? v, bool date) {
  if (v == null) return '';
  if (v is num) {
    if (v.isNaN) return '';
    if (date && v > 20000 && v < 80000) return dateKey(DateTime.utc(1899, 12, 30).add(Duration(days: v.floor())));
    return generalText(v);
  }
  if (v is bool) return v ? 'TRUE' : 'FALSE';
  return '$v'.trim();
}

/// The rows of his GRN / Issue register (the web's importFile): the heading row found by "Material", each column by its name.
List<Map<String, Object?>> storeDocRows(String kind, List<SheetTab> tabs) {
  final aoa = tabs.isEmpty ? const <List<Object?>>[] : tabs.first.rows;
  final hi = aoa.indexWhere((r) => r.any((c) => RegExp('material|item', caseSensitive: false).hasMatch('${c ?? ''}')));
  if (hi < 0) throw SheetError('The file has no "Material" heading – use the Import format.');
  final h = [for (final c in aoa[hi]) '${c ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase()];
  final m = _kDocImpMap[kind]!, col = {for (final e in m.entries) e.key: h.indexWhere(e.value.hasMatch)};
  final rows = <Map<String, Object?>>[];
  for (final (n, r) in aoa.sublist(hi + 1).indexed) {
    String g(String k) {
      final i = col[k] ?? -1;
      return i < 0 || i >= r.length ? '' : _cellText(r[i], k == 'date' || k == 'invoice_date');
    }

    final x = <String, Object?>{'line': hi + n + 2, for (final k in m.keys) k: g(k)};
    if (kind == 'issue' && '${x['party']}'.isEmpty && '${x['party0']}'.isNotEmpty) x['party'] = x['party0'];
    x.remove('party0');
    if ('${x['item']}'.isNotEmpty && '${x['qty']}'.isNotEmpty) rows.add(x);
  }
  if (rows.isEmpty) throw SheetError('The file has no rows with a material and its quantity.');
  return rows;
}

Future<void> storeDocTemplate(BuildContext context, String kind) async {
  try {
    await shareXlsx(sheetsXlsx([XSheet(kind == 'grn' ? 'Inward' : 'Outward', [kDocImpHead[kind]!], head: 1)]), kind == 'grn' ? 'GRN_import_format.xlsx' : 'Issue_import_format.xlsx');
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
  }
}

Future<void> storeDocImport(BuildContext context, StoreKit k, String kind, Future<void> Function() reload) async {
  final f = await pickSheetFile();
  if (f == null || !context.mounted) return;
  List<Map<String, Object?>> rows;
  try {
    rows = storeDocRows(kind, readSheets(f.bytes));
  } on SheetError catch (e) {
    toast(context, e.message, bad: true);
    return;
  } catch (_) {
    toast(context, 'Could not read the file.', bad: true);
    return;
  }
  final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => StoreDocImportScreen(k: k, kind: kind, rows: rows)));
  if (done == true) {
    await k.boot().catchError((_) {});
    await reload();
  }
}

/// Import from Excel – check (the web's import box): every row and what will happen to it; nothing while a mistake is left.
class StoreDocImportScreen extends StatefulWidget {
  const StoreDocImportScreen({super.key, required this.k, required this.kind, required this.rows});
  final StoreKit k;
  final String kind;
  final List<Map<String, Object?>> rows;
  @override
  State<StoreDocImportScreen> createState() => _StoreDocImportScreenState();
}

class _StoreDocImportScreenState extends State<StoreDocImportScreen> {
  Map<String, dynamic>? r;
  String err = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final x = await widget.k.call('importDocs', {'kind': widget.kind, 'rows': widget.rows, 'check': true});
      if (mounted) setState(() => r = x);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  Future<void> _go() async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final z = await widget.k.call('importDocs', {'kind': widget.kind, 'rows': widget.rows, 'check': false});
      if (!mounted) return;
      toast(context, '${z['saved']} imported (${widget.kind == 'grn' ? 'GRN' : 'Outward'} ${(z['nos'] as List? ?? const []).join(', ')}).');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        err = errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rr = r, list = listOf(rr?['rows']), errors = nOf(rr?['errors']).toInt(), docs = nOf(rr?['docs']).toInt();
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: Text('Import from Excel – check')),
      body: rr == null
          ? (err.isEmpty ? _loading() : ListView(padding: const EdgeInsets.all(16), children: [InfoLine(err, bad: true)]))
          : ListView(key: const Key('sdi-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
              Text('${widget.rows.length} rows → $docs ${widget.kind == 'grn' ? 'GRN(s)' : 'issue(s)'}, $errors with a mistake.${errors > 0 ? ' Correct them in the file and choose it again – nothing is imported while one is left.' : ''}',
                  key: const Key('sdi-sum'), style: TextStyle(fontSize: 13.5, color: errors > 0 ? C.red : C.muted, height: 1.35)),
              if (err.isNotEmpty) InfoLine(err, bad: true),
              const SizedBox(height: 10),
              for (final x in list)
                _card(key: Key('sdi-${x['line']}'), border: x['status'] == 'error' ? C.red : C.line, children: [
                  Row(children: [
                    Expanded(child: Text('Line ${x['line']}${'${x['ref'] ?? ''}'.isNotEmpty ? ' · No ${x['ref']}' : ''} · ${x['item'] ?? ''}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
                    x['status'] == 'ok' ? const Pill('OK') : const Pill('Mistake', color: C.red, bg: C.redSoft),
                  ]),
                  if ('${x['msg'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: Text('${x['msg']}', style: TextStyle(fontSize: 13, color: x['status'] == 'error' ? C.red : C.muted))),
                ]),
            ]),
      bottomNavigationBar: rr == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: Row(children: [
                  Expanded(child: OutlinedButton(key: const Key('sdi-x'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: busy ? null : () => Navigator.pop(context, false), child: Text('Cancel'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(key: const Key('sdi-go'), style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: busy || errors > 0 || docs == 0 ? null : _go, child: Text(busy ? 'Importing…' : 'Import $docs'))),
                ]),
              ),
            ),
    );
  }
}

/* ======================== STOCK & REPORTS ======================== */
const kStoreReps = [
  ('stock', 'Stock'),
  ('statement', 'Stock statement (day / month / period)'),
  ('ledger', 'Item ledger'),
  ('grn', 'GRN register'),
  ('issue', 'Issue register'),
  ('consumption', 'Consumption'),
  ('returnable', 'Returnable out'),
  ('req', 'Requirements'),
  ('po', 'Purchase orders'),
];

class StoreReportsScreen extends StatefulWidget {
  const StoreReportsScreen({super.key, required this.k});
  final StoreKit k;
  @override
  State<StoreReportsScreen> createState() => _StoreReportsScreenState();
}

class _StoreReportsScreenState extends State<StoreReportsScreen> {
  String kind = 'stock', err = '', asOn = '', cat = '', toKind = '', mach = '', by = 'party', reqSt = 'To order';
  late String from = widget.k.monthStart, to = widget.k.today;
  bool below = false, all = false, pending = true, allSites = false, busy = false, booted = false;
  Map<String, dynamic>? item, item2;
  final sup = TextEditingController(), party = TextEditingController(), loc = TextEditingController();
  RDoc? doc;
  StoreKit get k => widget.k;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    for (final c in [sup, party, loc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await k.boot();
    } catch (e) {
      err = errText(e);
    }
    if (!mounted) return;
    setState(() {
      booted = true;
      asOn = k.today;
      from = k.monthStart;
      to = k.today;
    });
    _show();
  }

  bool get _dated => const ['statement', 'ledger', 'grn', 'issue', 'consumption'].contains(kind);

  void _quick(String q) {
    final t = parseKey(k.today);
    setState(() {
      if (q == 'day') {
        from = to = k.today;
      } else if (q == 'month') {
        from = k.monthStart;
        to = k.today;
      } else {
        final last = DateTime(t.year, t.month, 0);
        from = dateKey(DateTime(last.year, last.month, 1));
        to = dateKey(last);
      }
    });
  }

  Future<void> _show() async {
    final x = <String, dynamic>{'kind': kind};
    if (kind == 'stock') x.addAll({'date': asOn, 'cat': cat, 'below': below, 'all': all});
    if (_dated) x.addAll({'from': from, 'to': to});
    if (kind == 'ledger') {
      if (item == null) return toast(context, 'Pick the item.', bad: true);
      x['code'] = item!['code'];
    }
    if (kind == 'grn') x['supplier'] = sup.text.trim();
    if (kind == 'issue' || kind == 'consumption') x.addAll({'toKind': toKind, 'party': party.text.trim(), 'machinery': mach, 'location': loc.text.trim(), 'code': kind == 'issue' && item2 != null ? item2!['code'] : '', 'by': by});
    if (kind == 'returnable') x['party'] = party.text.trim();
    if (kind == 'req') x['status'] = reqSt;
    if (kind == 'po') x.addAll({'pending': pending, 'all': allSites && k.buyer});
    setState(() => busy = true);
    try {
      final rep = await k.call('report', x);
      if (!mounted) return;
      setState(() {
        doc = storeRepDoc(rep);
        err = '';
      });
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _itemBox(String key, String label, Map<String, dynamic>? v, ValueChanged<Map<String, dynamic>?> set) => Press(
        key: Key(key),
        radius: 16,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        onTap: () async {
          final i = await pickStoreItem(context, k.items);
          if (i != null) set(i);
        },
        child: Row(children: [
          const Icon(Icons.inventory_2_rounded, color: C.blue, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(v == null ? label : storeItemLabel(v), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: v == null ? C.muted : C.ink))),
          if (v != null) InkWell(onTap: () => set(null), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 16, color: C.muted))),
        ]),
      );

  List<Widget> _filters() {
    const gap = SizedBox(height: 8);
    final ml = k.machLabels;
    return [
      if (kind == 'stock') ...[
        Row(children: [
          Expanded(child: DateField(key: const Key('sr-date'), label: 'As on', value: asOn, clear: false, onChanged: (v) => setState(() => asOn = v))),
          const SizedBox(width: 8),
          Expanded(child: PickField(key: const Key('sr-cat'), label: 'Category', value: cat, items: k.cats, blank: 'All', onChanged: (v) => setState(() => cat = v))),
        ]),
        Material(type: MaterialType.transparency, child: SwitchListTile(key: const Key('sr-below'), dense: true, contentPadding: EdgeInsets.zero, value: below, onChanged: (v) => setState(() => below = v), title: Text('Only below min stock'))),
        Material(type: MaterialType.transparency, child: SwitchListTile(key: const Key('sr-all'), dense: true, contentPadding: EdgeInsets.zero, value: all, onChanged: (v) => setState(() => all = v), title: Text('Every item (also with no stock)'))),
      ],
      if (_dated) ...[
        Wrap(spacing: 6, children: [
          for (final q in const [('day', 'Today'), ('month', 'This month'), ('last', 'Last month')]) ActionChip(key: Key('sr-q-${q.$1}'), label: Text(q.$2), onPressed: () => _quick(q.$1)),
        ]),
        Row(children: [
          Expanded(child: DateField(key: const Key('sr-from'), label: 'From', value: from, clear: false, onChanged: (v) => setState(() => from = v))),
          const SizedBox(width: 8),
          Expanded(child: DateField(key: const Key('sr-to'), label: 'To', value: to, clear: false, onChanged: (v) => setState(() => to = v))),
        ]),
        gap,
      ],
      if (kind == 'ledger') ...[_itemBox('sr-item', 'Item * – tap to pick', item, (v) => setState(() => item = v)), gap],
      if (kind == 'grn') ...[TextBox(key: const Key('sr-sup'), label: 'Supplier', controller: sup, options: k.names('suppliers')), gap],
      if (kind == 'issue' || kind == 'consumption') ...[
        Row(children: [
          Expanded(child: PickField(key: const Key('sr-tk'), label: 'Issued to', value: toKind, items: k.kinds('to'), blank: 'All', onChanged: (v) => setState(() => toKind = v))),
          const SizedBox(width: 8),
          Expanded(child: PickField(key: const Key('sr-mach'), label: 'Machinery', value: mach, items: ml.keys.toList(), blank: 'All', onChanged: (v) => setState(() => mach = v))),
        ]),
        gap,
        TextBox(key: const Key('sr-party'), label: 'Party / sub-contractor', controller: party, options: k.names('subs')),
        gap,
        TextBox(key: const Key('sr-loc'), label: 'Location has', controller: loc),
        gap,
        if (kind == 'issue') ...[_itemBox('sr-item2', 'Item – tap to pick (all when none)', item2, (v) => setState(() => item2 = v)), gap],
        if (kind == 'consumption') ...[
          PickField(key: const Key('sr-by'), label: 'By', value: by, items: const ['party', 'machinery', 'use_for', 'location', 'item'], labels: const {'party': 'Party / sub-contractor', 'machinery': 'Machinery', 'use_for': 'Use for', 'location': 'Location', 'item': 'Item'}, onChanged: (v) => setState(() => by = v)),
          gap,
        ],
      ],
      if (kind == 'returnable') ...[TextBox(key: const Key('sr-rparty'), label: 'Party', controller: party, options: k.names('subs')), gap],
      if (kind == 'req') ...[PickField(key: const Key('sr-st'), label: 'State', value: reqSt, items: const ['To order', 'Pending', 'Approved', 'Rejected', 'Closed', 'Cancelled'], blank: 'All', onChanged: (v) => setState(() => reqSt = v)), gap],
      if (kind == 'po') ...[
        Material(type: MaterialType.transparency, child: SwitchListTile(key: const Key('sr-pend'), dense: true, contentPadding: EdgeInsets.zero, value: pending, onChanged: (v) => setState(() => pending = v), title: Text('Only what is still to come'))),
        if (k.buyer) Material(type: MaterialType.transparency, child: SwitchListTile(key: const Key('sr-sites'), dense: true, contentPadding: EdgeInsets.zero, value: allSites, onChanged: (v) => setState(() => allSites = v), title: Text('Every site'))),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), d = doc;
    return Scaffold(
      appBar: _bar('Stock & Reports', 'स्टॉक आणि रिपोर्ट'),
      body: !booted
          ? _loading()
          : ListView(key: const Key('sr-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final r in kStoreReps)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: Key('sr-k-${r.$1}'),
                        label: Text(r.$2),
                        selected: kind == r.$1,
                        onSelected: (_) => setState(() {
                          kind = r.$1;
                          doc = null;
                        }),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              ..._filters(),
              Row(children: [
                Expanded(child: FilledButton(key: const Key('sr-go'), style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: busy ? null : _show, child: Text(busy ? 'Working…' : 'Show'))),
                const SizedBox(width: 8),
                IconButton.filledTonal(key: const Key('sr-xl'), tooltip: tr('Export to Excel'), onPressed: d == null ? null : () => shareDocXlsx(s, d), icon: const Icon(Icons.table_view_rounded)),
                IconButton.filledTonal(key: const Key('sr-pr'), tooltip: tr('Print'), onPressed: d == null ? null : () => printDoc(context, s, d), icon: const Icon(Icons.print_rounded)),
              ]),
              if (err.isNotEmpty) InfoLine(err, bad: true),
              if (d != null) Padding(padding: const EdgeInsets.only(top: 14), child: ReportView(d)),
            ]),
    );
  }
}

/* ======================== OPENING STOCK & NUMBERS (the Store Admin) ======================== */
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key, required this.k});
  final StoreKit k;
  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen> {
  final have = <String, Map<String, dynamic>>{};
  final qc = <String, TextEditingController>{}, rc = <String, TextEditingController>{};
  final gNo = TextEditingController(), oNo = TextEditingController();
  // (3.62.0, his formats) the papers of this site: the numbers' prefix (RCL/VTR → RCL/VTR/PO/2026/0128), the heading's e-mail,
  // contact, CIN, web; what a new PO starts with – its Site Contact, Shipping Address, Terms And Conditions
  static const _pk = ['prefix', 'email', 'phone', 'cin', 'web', 'site_contact', 'ship_to', 'terms'];
  final pc = {for (final f in _pk) f: TextEditingController()};
  String prefixNow = '';
  bool step5 = true;
  Map<String, dynamic> used = {};
  late String asOn = widget.k.monthStart;
  String q = '', err = '';
  bool loading = true, busy = false;
  StoreKit get k => widget.k;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [...qc.values, ...rc.values, ...pc.values, gNo, oNo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await k.boot();
      final r = await k.call('openingList'), n = await k.call('numbers');
      if (!mounted) return;
      setState(() {
        have
          ..clear()
          ..addAll({for (final x in listOf(r['rows'])) '${x['code']}': x});
        for (final i in k.items) {
          final c = '${i['code']}', o = have[c];
          (qc[c] ??= TextEditingController()).text = o == null ? '' : plainN(o['qty']);
          (rc[c] ??= TextEditingController()).text = o == null ? '' : plainN(o['rate']);
        }
        gNo.text = '${mapOf(n['next'])['GRN'] ?? ''}';
        oNo.text = '${mapOf(n['next'])['OUT'] ?? ''}';
        used = mapOf(n['used']);
        _papers(n);
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

  Future<void> _save() async {
    final ch = <Map<String, dynamic>>[];
    for (final i in k.items) {
      final c = '${i['code']}', o = have[c], qv = (qc[c]?.text ?? '').trim(), rv = (rc[c]?.text ?? '').trim();
      final changed = o != null ? (_d(qv) != nOf(o['qty']) || _d(rv) != nOf(o['rate'])) : qv.isNotEmpty;
      if (changed) ch.add({'code': c, 'qty': qv, 'rate': rv, 'date': o != null ? o['date'] : asOn});
    }
    if (ch.isEmpty) return toast(context, 'Nothing changed.');
    await _send(ch, 'Opening stock saved');
  }

  Future<void> _send(List<Map<String, dynamic>> rows, String said) async {
    setState(() => busy = true);
    try {
      final r = await k.call('openingSave', {'date': asOn, 'rows': rows});
      if (!mounted) return;
      toast(context, '$said – ${r['rows']} item(s).');
      await _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// an item typed in his file: its code ("ITM-0001 …" or the name as it is in the Item Master)
  String _codeOf(String v) {
    final m = RegExp(r'^\s*(ITM-\d+)', caseSensitive: false).firstMatch(v);
    if (m != null) return m.group(1)!.toUpperCase();
    String key(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final kk = key(v);
    return kk.isEmpty ? '' : '${k.items.where((i) => key('${i['name']}') == kk).firstOrNull?['code'] ?? ''}';
  }

  Future<void> _template() async {
    try {
      await shareXlsx(sheetsXlsx([XSheet('Opening stock', [const ['Item', 'Qty', 'Rate', 'Date'], for (final i in k.items) ['${i['name']}', '', '', '']], head: 1, widths: const [40, 10, 10, 12])]), 'Opening_stock_format.xlsx');
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  Future<void> _import() async {
    final f = await pickSheetFile();
    if (f == null || !mounted) return;
    final out = <Map<String, dynamic>>[], bad = <String>[];
    try {
      final tabs = readSheets(f.bytes), aoa = tabs.isEmpty ? const <List<Object?>>[] : tabs.first.rows;
      final hi = aoa.indexWhere((r) => r.any((c) => RegExp('item|material', caseSensitive: false).hasMatch('${c ?? ''}')));
      if (hi < 0) throw SheetError('The file has no "Item" heading – use the Import format.');
      final h = [for (final c in aoa[hi]) '${c ?? ''}'.trim().toLowerCase()];
      int ci(String re) => h.indexWhere(RegExp(re).hasMatch);
      final cItem = ci('item|material'), cQty = ci('qty|quantity|stock'), cRate = ci('rate'), cDate = ci('date');
      for (final (n, r) in aoa.sublist(hi + 1).indexed) {
        String g(int i, [bool date = false]) => i < 0 || i >= r.length ? '' : _cellText(r[i], date);
        final it = g(cItem), qv = g(cQty);
        if (it.isEmpty || qv.isEmpty) continue;
        final c = _codeOf(it);
        if (c.isEmpty) {
          bad.add('line ${hi + n + 2}: $it');
        } else {
          out.add({'code': c, 'qty': qv, 'rate': g(cRate), 'date': g(cDate, true)});
        }
      }
      if (bad.isNotEmpty) throw SheetError('Not in the Item Master (write them as there): ${bad.take(8).join('; ')}${bad.length > 8 ? ' …' : ''}. Nothing was imported.');
      if (out.isEmpty) throw SheetError('The file has no rows with an item and its quantity.');
    } on SheetError catch (e) {
      toast(context, e.message, bad: true);
      return;
    } catch (_) {
      toast(context, 'Could not read the file.', bad: true);
      return;
    }
    if (!await ask(context, 'Import the opening stock?', '${out.length} item(s) – their opening stock is set as in the file.', yes: 'Import')) return;
    await _send(out, 'Opening stock imported');
  }

  void _papers(Map n) {
    final pp = mapOf(n['papers']);
    for (final f in _pk) {
      pc[f]!.text = '${pp[f] ?? ''}';
    }
    prefixNow = '${n['prefixNow'] ?? ''}';
    step5 = n['step5'] != false;
  }

  Future<void> _papersSave() async {
    setState(() => busy = true);
    try {
      final r = await k.call('papersSave', {for (final f in _pk) f: pc[f]!.text});
      if (!mounted) return;
      toast(context, 'The papers are saved.');
      setState(() => _papers(r));
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _numbers() async {
    setState(() => busy = true);
    try {
      final r = await k.call('numbersSave', {'GRN': gNo.text.trim(), 'OUT': oNo.text.trim()});
      if (!mounted) return;
      toast(context, 'Next GRN ${mapOf(r['next'])['GRN']}, next Outward ${mapOf(r['next'])['OUT']}.');
      await _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = q.toLowerCase();
    final list = k.items.where((i) => x.isEmpty || '${i['code']} ${i['name']} ${i['category']}'.toLowerCase().contains(x)).toList();
    return Scaffold(
      appBar: _bar('Opening stock & Numbers', 'ओपनिंग स्टॉक आणि नंबर', refresh: _load),
      body: loading
          ? _loading()
          : ListView(key: const Key('op-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), children: [
              if (err.isNotEmpty) InfoLine(err, bad: true),
              Text('Numbers', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text('Where the GRN and Outward numbers go on from (e.g. after the old register\'s last number). Only higher than the last one used.', style: _muted),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextBox(key: const Key('nm-grn'), label: 'Next GRN No (last used ${used['GRN'] ?? 0})', controller: gNo, kb: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextBox(key: const Key('nm-out'), label: 'Next Outward No (last used ${used['OUT'] ?? 0})', controller: oNo, kb: TextInputType.number)),
              ]),
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerRight, child: _small('nm-save', 'Save the numbers', busy ? null : _numbers, icon: Icons.save_rounded)),
              const Divider(height: 28),
              // (3.62.0) the papers – closed until tapped (the opening stock's list stays where it was)
              Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  key: const Key('pp-open'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 6),
                  title: Text('Papers – Purchase Order and Requirement', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  subtitle: Text('Printed on the PO and the Purchase Requisition Form of this site. The company\'s name, address, GST, PAN and logo come from the site\'s company (Portal).', style: _muted),
                  children: [
                    TextBox(key: const Key('pp-prefix'), label: 'Numbers start with', hint: prefixNow.isEmpty ? 'RCL/VTR' : prefixNow, controller: pc['prefix']!, onChanged: (_) => setState(() {})),
                    const SizedBox(height: 8),
                    TextBox(key: const Key('pp-email'), label: 'Email ID', controller: pc['email']!, kb: TextInputType.emailAddress),
                    const SizedBox(height: 8),
                    TextBox(key: const Key('pp-phone'), label: 'Contact', controller: pc['phone']!, kb: TextInputType.phone),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextBox(key: const Key('pp-cin'), label: 'CIN No', controller: pc['cin']!, upper: true)),
                      const SizedBox(width: 8),
                      Expanded(child: TextBox(key: const Key('pp-web'), label: 'Web', controller: pc['web']!)),
                    ]),
                    const SizedBox(height: 8),
                    TextBox(key: const Key('pp-sc'), label: 'Site Contact (a new PO)', hint: 'Name : mobile', controller: pc['site_contact']!),
                    const SizedBox(height: 8),
                    TextBox(key: const Key('pp-ship'), label: 'Shipping Address (a new PO)', controller: pc['ship_to']!, maxLines: 3),
                    const SizedBox(height: 8),
                    TextBox(key: const Key('pp-terms'), label: 'Terms And Conditions (a new PO – one a line)', controller: pc['terms']!, maxLines: 4),
                    const SizedBox(height: 6),
                    Builder(builder: (_) {
                      final pre = pc['prefix']!.text.trim().isNotEmpty ? pc['prefix']!.text.trim() : prefixNow, y = k.today.length >= 4 ? k.today.substring(0, 4) : '';
                      return Align(alignment: Alignment.centerLeft, child: Text('PO No: $pre/PO/$y/0001 · Indent No: $pre/PR/$y/0001', key: const Key('pp-nos'), style: const TextStyle(fontSize: 12.5, color: C.blue, fontWeight: FontWeight.w600)));
                    }),
                    if (!step5) Text('The PO\'s Credit Period, Site Contact, Shipping Address, Freight, Load / Unload and its approval need the Store\'s step 5 (sql/store_step5_po_format.sql) at this site.', key: const Key('pp-step5'), style: const TextStyle(fontSize: 12.5, color: C.red, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: _small('pp-save', 'Save the papers', busy ? null : _papersSave, icon: Icons.save_rounded)),
                  ],
                ),
              ),
              const Divider(height: 28),
              Text('Opening stock', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text('The stock of each item when the Store starts here (as on a date) and its rate. Change a row and Save; 0 takes it out. Or import an Excel (Item, Qty, Rate, Date).', style: _muted),
              const SizedBox(height: 8),
              DateField(key: const Key('op-date'), label: 'As on (for new rows)', value: asOn, clear: false, onChanged: (v) => setState(() => asOn = v)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _small('op-imp', 'Import from Excel', busy ? null : _import, icon: Icons.upload_file_rounded),
                _small('op-tpl', 'Import format', _template, icon: Icons.download_rounded),
              ]),
              const SizedBox(height: 8),
              TextField(key: const Key('op-q'), onChanged: (v) => setState(() => q = v.trim()), decoration: InputDecoration(hintText: tr('Item, code, category'), prefixIcon: const Icon(Icons.search_rounded), isDense: true)),
              const SizedBox(height: 8),
              for (final i in list)
                _card(key: Key('op-${i['code']}'), children: [
                  Text('${i['name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('${i['code']} · ${i['unit']} · ${i['category']}${have['${i['code']}'] != null ? ' · as on ${dmy(have['${i['code']}']!['date'])}' : ''}', style: _faint),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: TextBox(key: Key('op-q-${i['code']}'), label: 'Opening qty', controller: qc['${i['code']}'] ??= TextEditingController(), kb: _dec)),
                    const SizedBox(width: 8),
                    Expanded(child: TextBox(key: Key('op-r-${i['code']}'), label: 'Rate ₹', controller: rc['${i['code']}'] ??= TextEditingController(), kb: _dec)),
                  ]),
                  const SizedBox(height: 6),
                ]),
            ]),
      bottomNavigationBar: loading ? null : _saveBar('op-save', 'Save the changed rows', busy, _save),
    );
  }
}
