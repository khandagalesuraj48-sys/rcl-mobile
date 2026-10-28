/* THE OLD INWARD REGISTER (3.57.0, the Store's import – rcl-store public/grnreg.js, 28-10-2026), read on the phone exactly as the web
 * reads it: his "INWARD UPTO GRN … .xlsx" ("ata auto vendor and item banayla hawet … duplicate entry mala dakhaw mi swata delete krel …
 * je GRN number chalu aahet tech continue hotil … ji excel diley tech column GRN / inward madhe de"). Pure – no screen, no network:
 *   pickSheet – the sheet with the register's heading (GRN No · Material · Qty …) and the most rows (not the Summary)
 *   readRows  – every row in his columns; a GRN's date, supplier, invoice, challan, vehicle on its first row only: the rows under it
 *   plan      – with the names he ticked, the rows he deleted, what he typed into a row: the GRNs (GRN No + date + supplier + invoice),
 *               the rows to look at, the same row twice, those already in the Store, the new suppliers and items, the notes, the next GRN
 * Word for word the web's code (the same JavaScript rules: the order of an object's keys, Math.round, String(number)); proven against
 * it: test/fixtures/sheets/grn_reg.{xlsx,json} (tool/grnreg_fixture.js runs the web's file). The server checks every part again.
 * One difference: a sheet whose range does not start at row 1 – its rows are counted from row 1 (the web: from the range's first row;
 * his file starts at row 1). */
import 'dart:convert';

import 'format.dart' show fmtNum;
import 'sheet_read.dart' show jsS, jsNumS, SheetTab;

String _keyOf(Object? s) => (s == null ? '' : jsS(s)).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
String grnKeyOf(Object? s) => _keyOf(s);
String _clean(Object? v, [int n = 200]) {
  final s = (v == null ? '' : jsS(v)).replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.length > n ? s.substring(0, n) : s;
}

/// Math.round of JavaScript: half up (toward +∞)
double _jsRound(double x) => (x + 0.5).floorToDouble();
double _r2(num n) => _jsRound((n.toDouble() + 2.220446049250313e-16) * 100) / 100;
String _n(num? v) => v == null ? 'null' : jsNumS(v);

/// Object.keys of JavaScript: the keys that are array indexes first, from the lowest, then the others in the order they came.
List<String> _jsKeys(Map<String, Object?> m) {
  bool idx(String k) => RegExp(r'^(0|[1-9]\d{0,9})$').hasMatch(k) && int.parse(k) < 4294967295;
  final a = m.keys.where(idx).toList()..sort((x, y) => int.parse(x).compareTo(int.parse(y)));
  return [...a, ...m.keys.where((k) => !idx(k))];
}

String _most(Map<String, int> m) {
  var b = '';
  var n = -1;
  for (final k in _jsKeys(m)) {
    if (m[k]! > n) {
      b = k;
      n = m[k]!;
    }
  }
  return b;
}

/// The columns of his register (a heading of two lines – "Received\nQty" – read as one).
final grnCols = <(String, RegExp)>[
  ('sr', RegExp(r'^(sr|s)\.?\s*no\b')), ('ref', RegExp(r'^grn\s*\.?\s*no')), ('date', RegExp(r'^grn\s*date|^date$')), ('challan_no', RegExp(r'challan')),
  ('invoice_no', RegExp(r'^(invoice|inv|bill)\.?\s*no')), ('invoice_date', RegExp(r'^(invoice|inv|bill)\.?\s*date|^invoive')), ('vehicle_no', RegExp(r'vehicle')),
  ('party', RegExp(r'supplier|party|vendor')), ('item', RegExp(r'material|^item|particular|description')), ('qty', RegExp(r'received\s*qty|^qty|quantity|inw(a|o)rd\s*qty')),
  ('uom', RegExp(r'^uom$|^unit$')), ('rate', RegExp(r'basic\s*rate|^rate')), ('taxable', RegExp(r'taxable|basic\s*amount')), ('gst', RegExp(r'gst\s*(amount|amt)|^gst$')),
  ('gst_pct', RegExp(r'gst\s*%|gst\s*rate')), ('tcs', RegExp(r'^tcs')), ('gross', RegExp(r'gross|total\s*amount|net\s*amount')), ('remark', RegExp(r'remark')),
];

/// The register's headings (the Import format, the Excel of the check).
const grnRegHead = ['Sr No', 'GRN No', 'GRN Date', 'Challan No', 'Invoice No.', 'Invoice Date', 'Vehicle No', 'Supplier Name', 'Material Description', 'Received Qty', 'UOM',
  'Basic Rate', 'Taxable Amount', 'GST Amount', 'TCS', 'Gross Amount', 'Remark'];

String _normH(Object? h) => (h == null ? '' : jsS(h)).replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

({int hi, Map<String, int> col})? grnHeadOf(List<List<Object?>> aoa) {
  for (var i = 0; i < aoa.length && i < 25; i++) {
    final h = aoa[i].map(_normH).toList(), col = <String, int>{};
    for (final (k, re) in grnCols) {
      var j = -1;
      for (var n = 0; n < h.length; n++) {
        if (h[n].isNotEmpty && re.hasMatch(h[n]) && !col.values.contains(n)) {
          j = n;
          break;
        }
      }
      if (j > -1) col[k] = j;
    }
    if (col.containsKey('item') && col.containsKey('qty') && (col.containsKey('ref') || col.containsKey('date'))) return (hi: i, col: col);
  }
  return null;
}

class GrnSheet {
  GrnSheet(this.name, this.aoa, this.hi, this.col, this.n, this.others);
  final String name;
  final List<List<Object?>> aoa;
  final int hi, n;
  final Map<String, int> col;
  final List<String> others;
}

/// The sheet that is the register: its heading, the most rows with a material.
GrnSheet? grnPickSheet(List<SheetTab> sheets) {
  GrnSheet? best;
  final others = <String>[];
  for (final s in sheets) {
    final h = grnHeadOf(s.rows);
    var n = 0;
    if (h != null) {
      for (final r in s.rows.skip(h.hi + 1)) {
        if (_clean(h.col['item']! < r.length ? r[h.col['item']!] : null).isNotEmpty) n++;
      }
    }
    if (h != null && (best == null || n > best.n)) {
      if (best != null) others.add(best.name);
      best = GrnSheet(s.name, s.rows, h.hi, h.col, n, others);
    } else {
      others.add(s.name);
    }
  }
  return best;
}

/// A number of the file: 1,180.00 · ₹ 650 · "4.000" – what is not one: null.
double? grnNumIn(Object? v) {
  if (v == null) return null;
  if (v is num) return v.isFinite ? v.toDouble() : null;
  final s = jsS(v).replaceAll(RegExp(r'[,₹\s]'), '').replaceFirst(RegExp(r'^rs\.?', caseSensitive: false), '');
  return RegExp(r'^[-+]?(\d+\.?\d*|\.\d+)$').hasMatch(s) ? double.parse(s.replaceFirst(RegExp(r'\.$'), '')) : null;
}

const _mon = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12};
String _iso(DateTime t) {
  final y = t.year;
  final ys = y >= 0 && y <= 9999 ? y.toString().padLeft(4, '0') : (y < 0 ? '-' : '+') + y.abs().toString().padLeft(6, '0');
  return '$ys-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// A date of the file: Excel's day number, 30-Nov-2022, 30-11-2022, 30/11/2022, 2022-11-30 – what is not one: ''.
String grnDayIn(Object? v) {
  if (v == null || v == '') return '';
  String ok(int y, int m, int d) {
    if (y < 100) y += 2000;
    final t = DateTime.utc(y, m, d);
    return t.year == y && t.month == m && t.day == d ? _iso(t) : '';
  }

  if (v is num) {
    if (!(v > 0 && v < 2958466)) return '';
    return _iso(DateTime.fromMillisecondsSinceEpoch(_jsRound((v - 25569) * 86400000.0).toInt(), isUtc: true));
  }
  final s = jsS(v).trim();
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (m != null) return ok(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  m = RegExp(r'^(\d{1,2})[-/. ]([A-Za-z]{3,9})[-/. ,]*(\d{2,4})$').firstMatch(s);
  if (m != null) {
    final w = m[2]!.toLowerCase(), mm = _mon[w.substring(0, 3)];
    if (_mon[w.substring(0, w.length > 4 ? 4 : 3)] != null || mm != null) return mm == null ? '' : ok(int.parse(m[3]!), mm, int.parse(m[1]!));
  }
  m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$').firstMatch(s);
  if (m != null && (m[3]!.length == 4 || m[3]!.length == 2)) return ok(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  return '';
}

/// A GRN No of the file: 1 → "1", "8029`" → "8029", "342 B" → "342 B"; one with no digit in it: none.
String grnRefIn(Object? v) {
  if (v == null) return '';
  if (v is num) return v.isFinite ? jsNumS(_jsRound(v * 1000.0) / 1000) : '';
  final s = _clean(v, 30).replaceAll(RegExp(r'^[^0-9A-Za-z]+|[^0-9A-Za-z]+$'), '');
  return RegExp(r'\d').hasMatch(s) ? s : '';
}

/// Every row of the register in his columns (line = its row in Excel); a GRN's details on its first row only – the rows under it of the same GRN No.
List<Map<String, dynamic>> grnReadRows(GrnSheet sheet) {
  final c = sheet.col, out = <Map<String, dynamic>>[], last = <String, Map<String, dynamic>>{};
  const carry = ['date', 'party', 'invoice_no', 'invoice_date', 'challan_no', 'vehicle_no'];
  for (var n = 0; n + sheet.hi + 1 < sheet.aoa.length; n++) {
    final r = sheet.aoa[sheet.hi + 1 + n];
    Object? g(String k) => c[k] == null ? '' : (c[k]! < r.length ? r[c[k]!] : null);
    final o = <String, dynamic>{'line': sheet.hi + n + 2};
    for (final (k, _) in grnCols) {
      o[k] = g(k);
    }
    if (!['ref', 'date', 'party', 'item', 'qty', 'taxable', 'gross', 'invoice_no'].any((k) => _clean(o[k]).isNotEmpty)) continue; // an empty row
    o['refText'] = _clean(o['ref'], 30);
    o['ref'] = grnRefIn(o['ref']);
    o['dateText'] = _clean(o['date'], 20);
    o['date'] = grnDayIn(o['date']);
    o['invoice_date'] = grnDayIn(o['invoice_date']);
    for (final k in ['challan_no', 'invoice_no', 'vehicle_no', 'party', 'item', 'uom', 'remark']) {
      o[k] = _clean(o[k], k == 'item' ? 120 : 80);
    }
    final ref = o['ref'] as String;
    if (ref.isNotEmpty) {
      final l = last[ref];
      if (l != null) {
        for (final k in carry) {
          if ('${o[k]}'.isEmpty && '${l[k] ?? ''}'.isNotEmpty && !(k == 'date' && '${o['dateText']}'.isNotEmpty)) o[k] = l[k];
        }
      }
      final x = last[ref] ??= {};
      for (final k in carry) {
        if ('${o[k]}'.isNotEmpty) x[k] = o[k];
      }
    }
    out.add(o);
  }
  return out;
}

/* (as the server's lib/grnimport.js) a unit of the file → the Item Master's; a GST % from its amount */
final Map<String, String> grnUnitOf = () {
  final m = <String, String>{};
  for (final (u, ws) in const [
    ('Nos', 'nos no nos. no. each ea pcs pc pis psc piece pieces nis nios noss unit units item items qty number numbers 1 pos os'),
    ('Kg', 'kg kgs kilo kilogram kilograms'), ('Gram', 'gm gms grm gram grams g'), ('Ltr', 'ltr ltrs l litre litres liter liters'), ('Ml', 'ml'),
    ('Mtr', 'mtr mtrs m meter meters metre metres rmtr rmtrs rmt rm'), ('Feet', 'feet ft fit foot rft'), ('Sqm', 'sqm sqmtr sqmt sq m2 sqmeter'), ('Sqft', 'sqft sqf saft'),
    ('Cum', 'cum m3 cbm cumtr'), ('Brass', 'brass'), ('Ton', 'mt ton tons tonne'), ('Box', 'box boxes'), ('Pkt', 'pkt pkts packet packets pak pack'),
    ('Set', 'set sets'), ('Kit', 'kit kits'), ('Pair', 'pair pairs pr paire piar'), ('Roll', 'roll rolls'), ('Bag', 'bag bags'), ('Bundle', 'bundle bundles bandal bdl bnd bunddle boundle bls bals'),
    ('Book', 'book books'), ('Ream', 'ream rim rims'), ('Job', 'job jobs jab'), ('Trip', 'trip trips'), ('Month', 'month months'), ('Day', 'day days'), ('Hrs', 'hrs hr hour hours'),
    ('Jar', 'jar jars'), ('Bottle', 'bottle bottles botle'), ('Can', 'can cans tin tins teen'), ('Drum', 'drum drums barrel'), ('Bucket', 'bucket buckets bkt'),
    ('Cylinder', 'cylinder cyl cly cyle cy'), ('Coil', 'coil coils'), ('Lot', 'lot lots'), ('Case', 'case cases cuse'), ('Sheet', 'sheet sheets'), ('Yard', 'yard yrd yards'),
  ]) {
    for (final w in ws.split(' ')) {
      m[w] = u;
    }
  }
  return m;
}();

({String unit, String note}) grnUnit(Object? raw) {
  final k = (raw == null ? '' : jsS(raw)).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (k.isEmpty) return (unit: 'Nos', note: 'no unit in the file – Nos');
  final u = grnUnitOf[k] ?? grnUnitOf[k.replaceFirst(RegExp(r's$'), '')];
  return u != null ? (unit: u, note: '') : (unit: 'Nos', note: 'unit "${_clean(raw, 12)}" – taken as Nos');
}

double grnGstPctOf(num? taxable, num? gst) {
  final t = (taxable ?? 0).toDouble(), g = (gst ?? 0).toDouble();
  if (!(t > 0) || !(g > 0)) return 0;
  for (final p in const [5, 12, 18, 28, 3, 0.25]) {
    if ((_r2(t * p / 100) - g).abs() <= 1) return p.toDouble();
  }
  return _r2(g / t * 100);
}

final _notName = RegExp(r'^\s*(description|material|material description|item|items|item name|particulars|name)\s*$', caseSensitive: false);
const _stdGst = [0.25, 3, 5, 12, 18, 28];
String _inr(num v) => v < 0 ? '-${fmtNum(-v)}' : fmtNum(v);
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _dmy(String d) => d.split('-').reversed.join('-');
double _dn(String d) => DateTime.parse('${d}T00:00:00Z').millisecondsSinceEpoch / 864e5;

/// The GRN Nos whose date is more than 6 months from the dates of the 5 GRN Nos before and after it (a date he typed is his).
Map<String, ({String date, String near})> grnFarDates(List<({String ref, String date, bool typed})> list, String today) {
  final at = <String, ({String ref, String date, bool typed})>{};
  for (final x in list) {
    if (RegExp(r'^\d{1,9}$').hasMatch(x.ref) && x.date.isNotEmpty && x.date.compareTo('2000-01-01') >= 0 && x.date.compareTo(today) <= 0 && !at.containsKey(x.ref)) at[x.ref] = x;
  }
  final refs = at.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  final out = <String, ({String date, String near})>{};
  for (var i = 0; i < refs.length; i++) {
    final x = at[refs[i]]!;
    if (x.typed) continue;
    final around = [...refs.sublist(i - 5 < 0 ? 0 : i - 5, i), ...refs.sublist(i + 1, i + 6 > refs.length ? refs.length : i + 6)].map((m) => at[m]!.date).toList()..sort();
    if (around.length < 4) continue;
    final mid = around[around.length ~/ 2];
    if ((_dn(x.date) - _dn(mid)).abs() > 183) out[refs[i]] = (date: x.date, near: '${_months[int.parse(mid.substring(5, 7)) - 1]} ${mid.substring(0, 4)}');
  }
  return out;
}

String grnDocKey(Object? ref, Object? date, Object? supplier, Object? invoice) {
  final d = date == null ? '' : '$date';
  return [_clean(ref, 30).toUpperCase(), d.length > 10 ? d.substring(0, 10) : d, _keyOf(supplier), _keyOf(invoice)].join('|');
}

String _title(Object? s) => _clean(s, 40).toLowerCase().replaceAllMapped(RegExp(r'(^|[\s\-/&(])([a-z])'), (m) => '${m[1]}${m[2]!.toUpperCase()}');
String _sv(Object? v) => v == null ? '' : jsS(v);

/// What he chose: the names ticked ({party|item|category: {from: to}}), the rows deleted ({line: true}), what he typed into a row to look at.
class GrnChoice {
  GrnChoice({Map<String, Map<String, String>>? fix, Map<int, bool>? gone, Map<int, Map<String, String>>? edit})
      : fix = fix ?? {'party': {}, 'item': {}, 'category': {}},
        gone = gone ?? {},
        edit = edit ?? {};
  final Map<String, Map<String, String>> fix;
  final Map<int, bool> gone;
  final Map<int, Map<String, String>> edit;
  Map<String, dynamic> toJson() => {'fix': fix, 'gone': {for (final k in gone.keys) '$k': true}, 'edit': {for (final e in edit.entries) '${e.key}': e.value}};
  static GrnChoice fromJson(Map j) => GrnChoice(
        fix: {for (final l in ['party', 'item', 'category']) l: {for (final e in ((j['fix'] as Map?)?[l] as Map? ?? const {}).entries) '${e.key}': '${e.value}'}},
        gone: {for (final k in ((j['gone'] as Map?) ?? const {}).keys) int.parse('$k'): true},
        edit: {for (final e in ((j['edit'] as Map?) ?? const {}).entries) int.parse('${e.key}'): {for (final x in (e.value as Map).entries) '${x.key}': '${x.value}'}},
      );
}

/// THE PLAN – what the Import will do, from the rows and what he chose. info: the server's regInfo (items [[code, name, unit,
/// category]], vendors [names], grns [[key, ref, no, date, supplier]], next).
Map<String, dynamic> grnPlan(List<Map<String, dynamic>> rows, Map<String, dynamic> info, GrnChoice ch, String today) {
  final fix = ch.fix, gone = ch.gone, edit = ch.edit;
  String f(String k, String v) {
    var x = v;
    for (var i = 0; i < 5; i++) {
      final y = fix[k]?[x];
      if (y == null || y.isEmpty || y == x) break;
      x = y;
    }
    return x;
  }

  final look = <Map<String, dynamic>>[], notes = <Map<String, dynamic>>[], dups = <Map<String, dynamic>>[], seenRow = <String, int>{}, empty = <int>[];
  final t = today;
  final remarkN = <String, int>{};
  for (final r in rows) {
    final k = _keyOf(r['remark']);
    if (k.isNotEmpty) remarkN[k] = (remarkN[k] ?? 0) + 1;
  }
  final ok = <Map<String, dynamic>>[];
  final far = grnFarDates([for (final r0 in rows) (ref: '${r0['ref']}', date: (edit[r0['line']]?['date'] ?? '').isNotEmpty ? grnDayIn(edit[r0['line']]!['date']) : '${r0['date']}', typed: (edit[r0['line']]?['date'] ?? '').isNotEmpty)], t);
  for (final r0 in rows) {
    final e = edit[r0['line']] ?? const <String, String>{}, r = Map<String, dynamic>.of(r0);
    if ((e['date'] ?? '').isNotEmpty) r['date'] = grnDayIn(e['date']);
    if (e.containsKey('qty') && e['qty'] != '') r['qty'] = e['qty'];
    if ((e['party'] ?? '').isNotEmpty) r['party'] = _clean(e['party'], 80);
    if ((e['item'] ?? '').isNotEmpty) r['item'] = _clean(e['item'], 120);
    r['party'] = f('party', '${r['party']}');
    r['item'] = f('item', '${r['item']}');
    final line = r['line'] as int;
    // the same row twice in the file (every column the same, not its Sr No): shown – he deletes what he wants, the rest is imported as it is
    final dk = jsonEncode([for (final k in const ['ref', 'date', 'challan_no', 'invoice_no', 'invoice_date', 'vehicle_no', 'party', 'item', 'qty', 'uom', 'rate', 'taxable', 'gst', 'gst_pct', 'tcs', 'gross', 'remark']) _sv(r0[k])]);
    if (seenRow.containsKey(dk)) {
      dups.add({'line': line, 'first': seenRow[dk], 'row': r0, 'gone': gone[line] == true});
    } else {
      seenRow[dk] = line;
    }
    if (gone[line] == true) continue;
    // a row with only its GRN No, date or supplier: nothing to import – counted
    if (_clean(r['item']).isEmpty && _clean(r['qty']).isEmpty && ![r['rate'], r['taxable'], r['gst'], r['gross']].any((v) => (grnNumIn(v) ?? 0) != 0)) {
      empty.add(line);
      continue;
    }
    final why = <String>[];
    final item = '${r['item']}', date = '${r['date']}', ref = '${r['ref']}';
    if (_keyOf(item).length < 2 || !RegExp(r'[a-z]', caseSensitive: false).hasMatch(item) || _notName.hasMatch(item)) why.add(item.isNotEmpty ? 'material "$item" is not a name' : 'no material');
    if (date.isEmpty) {
      why.add('${r['dateText']}'.isNotEmpty ? 'GRN date "${r['dateText']}" is not a date' : 'no GRN date');
    } else if (date.compareTo(t) > 0) {
      why.add('GRN date ${_dmy(date)} is after today');
    } else if (date.compareTo('2000-01-01') < 0) {
      why.add('GRN date ${_dmy(date)} is too old');
    } else if (far[ref] != null && (e['date'] ?? '').isEmpty && far[ref]!.date == date) {
      why.add('GRN date ${_dmy(date)} – the GRNs around GRN No $ref are of ${far[ref]!.near}');
    }
    if (_keyOf(r['party']).length < 2) why.add('no supplier');
    var q = grnNumIn(r['qty']);
    final tx0 = grnNumIn(r['taxable']), gr0 = grnNumIn(r['gross']);
    final amt = (tx0 != null && tx0 != 0) ? tx0 : (gr0 != null && gr0 != 0) ? gr0 : 0.0;
    if ((q == null || q == 0) && _clean(r['qty']).isNotEmpty && grnNumIn(r['qty']) == null) {
      why.add('quantity "${_clean(r['qty'], 20)}" is not a number');
    } else if (q == null || q <= 0) {
      if (amt > 0 && (q == null || q == 0)) {
        q = 1;
        notes.add({'line': line, 'ref': ref, 'msg': 'no quantity – Qty 1 for its amount ₹${_n(amt)}'});
      } else {
        why.add('no quantity');
      }
    }
    if (why.isNotEmpty) {
      look.add({'line': line, 'ref': ref.isNotEmpty ? ref : r['refText'], 'date': date, 'party': r['party'], 'item': item, 'qty': _clean(r['qty'], 20), 'why': why});
      continue;
    }
    r['qtyN'] = q;
    ok.add(r);
  }
  // the GRNs: a GRN No + date + supplier + invoice is one GRN; a GRN without a GRN No – its date, supplier and invoice (as the server's)
  String noRef(String k) => '*${k.replaceFirst(RegExp(r'^[^|]*'), '')}';
  final there = <String, List>{}, refThere = <String, List>{};
  for (final g in (info['grns'] as List? ?? const []).whereType<List>()) {
    there['${g[0]}'] = g;
    there[noRef('${g[0]}')] = g;
    refThere['${g[1]}'.toUpperCase()] = g;
  }
  final byKey = <String, Map<String, dynamic>>{}, docs = <Map<String, dynamic>>[], already = <Map<String, dynamic>>[];
  final items = <String, Map<String, dynamic>>{}, sup = <String, Map<String, dynamic>>{}, itemsHave = <String, List>{}, supHave = <String, String>{};
  for (final i in (info['items'] as List? ?? const []).whereType<List>()) {
    itemsHave[_keyOf(i[1])] = i;
  }
  for (final v in (info['vendors'] as List? ?? const [])) {
    supHave[_keyOf(v)] = '$v';
  }
  // a row without a GRN No with the date, supplier and invoice (or none) of a GRN No of the file: a line of that GRN
  final numbered = <String, String>{};
  for (final r in ok) {
    if ('${r['ref']}'.isNotEmpty) numbered.putIfAbsent(noRef(grnDocKey(r['ref'], r['date'], r['party'], r['invoice_no'])), () => '${r['ref']}');
  }
  for (final r in ok) {
    final line = r['line'] as int;
    if ('${r['ref']}'.isEmpty) {
      final to = numbered[noRef(grnDocKey('', r['date'], r['party'], r['invoice_no']))];
      if (to != null) {
        r['ref'] = to;
        notes.add({'line': line, 'ref': to, 'msg': 'no GRN No – the date, supplier and invoice of GRN No $to: one of its lines'});
      }
    }
    final ref = '${r['ref']}', k = grnDocKey(ref, r['date'], r['party'], r['invoice_no']);
    var d = byKey[k];
    if (d == null) {
      d = byKey[k] = {'key': k, 'ref': ref, 'date': r['date'], 'supplier': r['party'], 'challan_no': r['challan_no'], 'invoice_no': r['invoice_no'], 'invoice_date': r['invoice_date'], 'vehicle_no': r['vehicle_no'], 'lines': <Map<String, dynamic>>[], 'first': line};
      final was = ref.isNotEmpty ? there[k] : there[noRef(k)];
      if (was != null) {
        d['there'] = was;
        already.add(d);
      } else {
        docs.add(d);
      }
    }
    final u = grnUnit(r['uom']);
    if (u.note.isNotEmpty) notes.add({'line': line, 'ref': ref, 'msg': u.note});
    final rate = grnNumIn(r['rate']), tx = grnNumIn(r['taxable']), gs = grnNumIn(r['gst']), tc = grnNumIn(r['tcs']), gr = grnNumIn(r['gross']), pct = grnNumIn(r['gst_pct']);
    final qn = (r['qtyN'] as num).toDouble();
    final taxable = tx ?? _r2(qn * (rate ?? 0)), gst = gs ?? ((pct ?? 0) > 0 ? _r2(taxable * pct! / 100) : 0.0);
    if (rate != null && tx != null && rate > 0 && (_r2(qn * rate) - tx).abs() > 1) notes.add({'line': line, 'ref': ref, 'msg': 'Qty × Rate = ₹${_n(_r2(qn * rate))}, Taxable Amount ₹${_n(tx)} (imported as the file)'});
    if (gr != null && (_r2(taxable + gst + (tc ?? 0)) - gr).abs() > 1) {
      notes.add({'line': line, 'ref': ref, 'msg': 'Taxable + GST${(tc ?? 0) != 0 ? ' + TCS' : ''} = ₹${_n(_r2(taxable + gst + (tc ?? 0)))}, Gross Amount ₹${_n(gr)} (imported as the file)'});
    }
    if (taxable + gst > 1e7) notes.add({'line': line, 'ref': ref, 'big': true, 'msg': 'Taxable ₹${_inr(taxable)} (${_n(qn)} ${r['uom'] ?? ''} × ₹${_inr(rate ?? 0)}) – above ₹1 crore: check the Qty, its unit and the Rate (imported as the file)'});
    (d['lines'] as List).add({'line': line, 'item': r['item'], 'qty': qn, 'unit': r['uom'], 'rate': rate, 'taxable': taxable, 'gst': gst, 'gst_pct': pct, 'tcs': tc, 'remark': r['remark']});
    if (d['there'] == null) {
      final ik = _keyOf(r['item']);
      final it = items[ik] ??= {'names': <String, int>{}, 'units': <String, int>{}, 'cats': <String, int>{}, 'pct': <String, int>{}, 'n': 0};
      it['n'] = (it['n'] as int) + 1;
      final names = it['names'] as Map<String, int>, units = it['units'] as Map<String, int>, cats = it['cats'] as Map<String, int>, pcts = it['pct'] as Map<String, int>;
      names['${r['item']}'] = (names['${r['item']}'] ?? 0) + 1;
      units[u.unit] = (units[u.unit] ?? 0) + 1;
      final ck = _keyOf(r['remark']);
      if (ck.isNotEmpty && (remarkN[ck] ?? 0) >= 20) {
        final c = _title(f('category', _title(r['remark'])));
        cats[c] = (cats[c] ?? 0) + 1;
      }
      final p = grnGstPctOf(taxable, gst);
      if (_stdGst.contains(p)) pcts[_n(p)] = (pcts[_n(p)] ?? 0) + 1;
      final sk = _keyOf(r['party']);
      final s = sup[sk] ??= {'names': <String, int>{}, 'n': 0};
      s['n'] = (s['n'] as int) + 1;
      final sn = s['names'] as Map<String, int>;
      sn['${r['party']}'] = (sn['${r['party']}'] ?? 0) + 1;
    }
  }
  // a GRN No used already by another GRN of the Store: imported too, said
  for (final d in docs) {
    final ref = '${d['ref']}', g = ref.isNotEmpty ? refThere[ref.toUpperCase()] : null;
    if (g != null && '${g[0]}' != d['key']) notes.add({'line': d['first'], 'ref': ref, 'msg': 'GRN No $ref is also the GRN No of the Store\'s GRN of ${_dmy('${g[3]}')} (${g[4]})'});
  }
  // each line its item's name as most rows write it
  final nameOf = <String, String>{};
  for (final k in _jsKeys(items)) {
    nameOf[k] = itemsHave[k] != null ? '${itemsHave[k]![1]}' : _most(items[k]!['names'] as Map<String, int>);
  }
  for (final d in docs) {
    for (final l in d['lines'] as List) {
      (l as Map)['item'] = nameOf[_keyOf(l['item'])] ?? l['item'];
    }
  }
  // a row in another unit than its item's – its quantity is counted as it is written
  final unitAt = <String, String>{};
  for (final k in _jsKeys(items)) {
    unitAt[k] = itemsHave[k] != null ? '${itemsHave[k]![2]}' : _most(items[k]!['units'] as Map<String, int>);
  }
  for (final d in docs) {
    for (final l in d['lines'] as List) {
      final u = grnUnit((l as Map)['unit']).unit, w = unitAt[_keyOf(l['item'])];
      if (w != null && w.isNotEmpty && u != w) notes.add({'line': l['line'], 'ref': d['ref'], 'msg': 'unit $u – the item\'s unit is $w (its quantity counted as written)'});
    }
  }
  final ni = [for (var i = 0; i < notes.length; i++) (i, notes[i])]..sort((a, b) {
      final x = (b.$2['big'] == true ? 1 : 0) - (a.$2['big'] == true ? 1 : 0);
      if (x != 0) return x;
      final y = (a.$2['line'] as int) - (b.$2['line'] as int);
      return y != 0 ? y : a.$1 - b.$1; // (the web's sort keeps the order of equal ones)
    });
  notes
    ..clear()
    ..addAll(ni.map((x) => x.$2));
  final supName = <String, String>{};
  for (final k in _jsKeys(sup)) {
    supName[k] = (supHave[k] ?? '').isNotEmpty ? supHave[k]! : _most(sup[k]!['names'] as Map<String, int>);
  }
  for (final d in docs) {
    d['supplier'] = supName[_keyOf(d['supplier'])] ?? d['supplier'];
  }
  final newItems = [
    for (final k in _jsKeys(items))
      if (itemsHave[k] == null)
        () {
          final it = items[k]!, p = _most(it['pct'] as Map<String, int>), un = _most(it['units'] as Map<String, int>), ca = _most(it['cats'] as Map<String, int>);
          return <String, dynamic>{'name': nameOf[k], 'unit': un.isEmpty ? 'Nos' : un, 'category': ca.isEmpty ? 'General' : ca, 'gst': p.isEmpty ? '' : double.parse(p), 'rows': it['n']};
        }(),
  ];
  final newSup = [for (final k in _jsKeys(sup)) if ((supHave[k] ?? '').isEmpty) <String, dynamic>{'name': supName[k], 'rows': sup[k]!['n']}];
  // numbered GRNs first (by their GRN No), then the GRNs without a GRN No (the next numbers after the file's last)
  double refN(Map d) {
    final ref = '${d['ref']}', m = RegExp(r'^\s*([+-]?\d+)').firstMatch(ref);
    if (ref.isNotEmpty && RegExp(r'^\d+$').hasMatch(ref)) return double.parse(ref);
    if (ref.isNotEmpty) return m == null ? 1e12 : double.parse(m[1]!) + 0.5;
    return 2e12;
  }

  docs.sort((a, b) {
    final x = refN(a) - refN(b);
    if (x != 0) return x < 0 ? -1 : 1;
    final y = '${a['date']}'.compareTo('${b['date']}');
    if (y != 0) return y;
    return (a['first'] as int) - (b['first'] as int);
  });
  final nums = [for (final d in docs) if (RegExp(r'^\d{1,9}$').hasMatch('${d['ref']}')) int.parse('${d['ref']}')];
  final maxRef = nums.isEmpty ? 0 : nums.reduce((a, b) => a > b ? a : b);
  var gross = 0.0;
  for (final d in docs) {
    for (final l in d['lines'] as List) {
      gross += ((l as Map)['taxable'] as num? ?? 0) + (l['gst'] as num? ?? 0) + (l['tcs'] as num? ?? 0);
    }
  }
  final days = [for (final d in docs) '${d['date']}']..sort();
  final nr = docs.where((d) => '${d['ref']}'.isEmpty).length, base = [((info['next'] as num?) ?? 1).toInt(), maxRef + 1].reduce((a, b) => a > b ? a : b);
  return {
    'docs': docs, 'already': already, 'look': look, 'dups': dups, 'notes': notes, 'empty': empty, 'newItems': newItems, 'newSup': newSup,
    'lines': docs.fold<int>(0, (a, d) => a + (d['lines'] as List).length), 'gross': _r2(gross), 'from': days.isEmpty ? '' : days.first, 'to': days.isEmpty ? '' : days.last,
    'maxRef': maxRef, 'first': base, 'noRef': nr, 'next': base + nr,
  };
}

/// The names of the file with their rows – for the AI's list: suppliers, items, categories (a remark of 20 rows or more).
Map<String, Map<String, int>> grnNamesOf(List<Map<String, dynamic>> rows) {
  final o = <String, Map<String, int>>{'party': {}, 'item': {}, 'category': {}}, remN = <String, int>{};
  for (final r in rows) {
    final k = _keyOf(r['remark']);
    if (k.isNotEmpty) remN[k] = (remN[k] ?? 0) + 1;
  }
  for (final r in rows) {
    final p = '${r['party']}', i = '${r['item']}', rm = '${r['remark']}';
    if (p.isNotEmpty) o['party']![p] = (o['party']![p] ?? 0) + 1;
    if (i.isNotEmpty) o['item']![i] = (o['item']![i] ?? 0) + 1;
    if (rm.isNotEmpty && (remN[_keyOf(rm)] ?? 0) >= 20) {
      final c = _title(rm);
      o['category']![c] = (o['category']![c] ?? 0) + 1;
    }
  }
  return o;
}

/// The names of a list in the order the web asks the AI: by their letters, then as the file has them (the web's stable sort).
List<(String, int)> grnNamesSorted(Map<String, int> m) {
  final ks = _jsKeys(m), ix = [for (var i = 0; i < ks.length; i++) i]
    ..sort((a, b) {
      final x = _keyOf(ks[a]).compareTo(_keyOf(ks[b]));
      return x != 0 ? x : a - b;
    });
  return [for (final i in ix) (ks[i], m[ks[i]]!)];
}
