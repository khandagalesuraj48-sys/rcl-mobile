/* THE LOG BOOK IN EXCEL (3.12.0) – the web's own working (App.html "LOG BOOK – import / export (two layouts …)"):
 *   – the exports: "one date – many machinery" (a Date-wise tab) and "one machinery – many dates" (a Summary tab and a tab per
 *     machinery) – every date of the period for every machinery of the filter, the saved entries filled in and the missing dates
 *     blank to fill; only the columns the machinery uses; Total KM / Hrs as Excel formulas; the drop-down lists (Shift, Measured
 *     by – the machinery's own ways, Work type …) on the cells;
 *   – the two templates (200 lines with the drop-downs, the machinery of the site on a hidden "Lists" tab);
 *   – the import: every tab, either layout; a row is read as the web reads it (times, Status, the way in any letters, item work,
 *     Work type and the item columns, Debit to), blank rows left out, a water tanker's lines as trips, each row's problems.
 * Proven against the web's code: test/fixtures/lbio/web_lbio.json (made by running App.html's own functions in node). */
import 'format.dart';
import 'imports.dart';
import 'session.dart' show Machine, hasKm, hasHr, kNoReading;
import 'sheet_read.dart';
import 'assets.dart' show worksOf;

const kDayStatusL = ['Idle', 'Holiday', 'Breakdown'];
const kWaysAll = ['KM', 'Hrs', 'KM + Hrs', 'Time', 'Trip', 'Day'];
const kLbStatus = ['Working', 'Idle', 'Holiday', 'Breakdown'];
const kItemWord = {'hr': 'hr', 'km': 'km', 'trip': 'trips'};
const _fmtNeeds = <String, Set<String>>{
  'A': {},
  'B': {'tripAll'},
  'C': {'noCh'},
  'D': {},
  'E': {'challan', 'part'},
  'F': {'challan', 'part'},
  'G': {'challan', 'part'},
  'H': {'challan', 'tripTime'},
  'I': {'challan', 'tripTime'},
};

String itemKind(Object? basis) => basis == 'Per Hour' ? 'hr' : basis == 'Per KM' ? 'km' : basis == 'Per Trip' ? 'trip' : 'day';

double _r2(num v) => (v * 100).roundToDouble() / 100; // Math.round(n*100)/100 (the figures here are never negative halves)
double _n0(Object? v) {
  // Number(v) || 0
  final n = v is num ? v.toDouble() : v == null ? double.nan : v is bool ? (v ? 1.0 : 0.0) : jsNumber('$v');
  return n.isNaN ? 0 : n;
}

bool _isDay(Object? v) => kDayStatusL.contains(v);

List<String> modesOfM(Map<String, dynamic>? m) => m == null ? const [] : Machine(m).modes;

/// "Breaker=3; Rock=1" (the typed items; a Day item by its name) – the web's itemWorkText.
String itemWorkText(Object? o) {
  if (o is! Map) return '';
  return [
    for (final e in o.entries)
      if (e.key == '_day' ? jsTrue(e.value) : _n0(e.value) > 0) e.key == '_day' ? jsS(e.value) : '${e.key}=${jsS(e.value)}',
  ].join('; ');
}

/// The web's itemWorkRead: "Breaker=3; Rock: 1,5" → {Breaker: 3, Rock: 15}; a text without a figure = the Day item.
Map<String, Object> itemWorkRead(Object? txt) {
  final o = <String, Object>{};
  for (final part in (jsTrue(txt) ? jsS(txt) : '').split(RegExp(r'[;\n]+')).map((x) => x.trim()).where((x) => x.isNotEmpty)) {
    final q = RegExp(r'^(.*?)\s*[=:]\s*([0-9.,]+)\s*[a-zA-Z]*$').firstMatch(part);
    if (q != null) {
      o[q[1]!.trim()] = jsNumber(q[2]!.replaceAll(',', ''));
    } else {
      o['_day'] = part;
    }
  }
  return o;
}

double partsGap(Object? ps) {
  if (ps is! List) return 0;
  var a = 0.0;
  for (final p in ps) {
    if (p is Map && p['m'] == 'T') {
      a += -_n0(p['q']);
    } else {
      final g = p is Map ? _n0(p['g']) : 0.0;
      a += g > 0 ? g : 0;
    }
  }
  return _r2(a);
}

/// A water tanker's entry as its trips (the web's tripsOfRow) – null when it is not one.
List<Map<String, String>>? tripsOfRow(Map r, Iterable<Map<String, dynamic>> master) {
  final m = findMachine(master, r['no']);
  if (m == null || m['lbFormat'] != 'I' || r['unit'] != 'Trip') return null;
  final iw = r['itemWork'];
  final tr = iw is Map && iw['_trips'] is List ? iw['_trips'] as List : null;
  String s(Object? v) => jsTrue(v) ? jsS(v) : '';
  if (tr != null && tr.isNotEmpty) return [for (final t in tr.whereType<Map>()) {'c': s(t['c']), 'a': s(t['a']), 'b': s(t['b']), 'ch': s(t['ch']), 'u': s(t['u'])}];
  final tripN = _jsRound(_n0(r['trip']));
  final n = tripN > 1 ? tripN : 1;
  final list = s(r['challan']).split(RegExp(r'\s*[,;]\s*')).where((x) => x.isNotEmpty).toList();
  final cnt = n > list.length ? n : list.length;
  final ch = jsTrue(r['chainage']) ? s(r['chainage']) : [r['chFrom'], r['chTo']].where(jsTrue).map(jsS).join(' – ');
  return [
    for (var i = 0; i < cnt; i++) {'c': i < list.length ? list[i] : '', 'a': cnt == 1 ? s(r['tStart']) : '', 'b': cnt == 1 ? s(r['tEnd']) : '', 'ch': ch, 'u': s(r['work']), 'old': '1'},
  ];
}

int _jsRound(double v) => (v + 0.5).floor(); // Math.round

bool needsLogBook(Map<String, dynamic>? m) => m != null && m['supply'] != 'Debit Basis' && m['ownership'] != 'Debit' && m['ownership'] != 'Other';

String addDay(String d, int n) => dateKey(DateTime(int.parse(d.substring(0, 4)), int.parse(d.substring(5, 7)), int.parse(d.substring(8, 10)) + n));

/// JavaScript's a.localeCompare(b) for names (letters before case; digits as text) – [numeric]: 2 before 10.
int localeCmp(String a, String b, {bool numeric = false}) {
  if (!numeric) {
    final c = a.toLowerCase().compareTo(b.toLowerCase());
    return c != 0 ? c : -a.compareTo(b); // the small letter first, as the browser
  }
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a).map((m) => m[0]!).toList(), pb = re.allMatches(b).map((m) => m[0]!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final x = pa[i], y = pb[i];
    final dx = RegExp(r'^\d').hasMatch(x), dy = RegExp(r'^\d').hasMatch(y);
    final c = dx && dy ? BigInt.parse(x).compareTo(BigInt.parse(y)) : localeCmp(x, y);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

/* ---------------- a sheet: what the web gives ExcelJS ---------------- */

/// A cell: a text, a number, or a formula with its figure ([result] null = none yet).
class XFormula {
  const XFormula(this.formula, [this.result]);
  final String formula;
  final num? result;
  Map<String, Object?> toJson() => {'formula': formula, if (result != null) 'result': result};
}

/// A drop-down on a cell: an inline list ("a,b,c") or a range of another tab (Lists!$A$1:$A$9).
class XList {
  const XList(this.list, this.title, this.prompt, this.error);
  final String list, title, prompt, error;
  @override
  bool operator ==(Object o) => o is XList && o.list == list && o.title == title && o.prompt == prompt && o.error == error;
  @override
  int get hashCode => Object.hash(list, title, prompt, error);
}

class XSheet {
  XSheet(this.name, this.aoa, {this.widths = const [], this.head = 0, this.hidden = false, List<(int, int, XList, bool)>? validations}) : validations = validations ?? [];
  final String name;
  final List<List<Object>> aoa;
  final List<num> widths;
  final int head; // the heading row (1-based) – bold, grey, frozen; 0 = none
  final bool hidden;

  /// (row 1-based, column 1-based, the list, the cell is empty – a yellow box to fill)
  final List<(int, int, XList, bool)> validations;
}

/// A column of the web's lbColsFor.
class _Col {
  _Col(this.h, this.w, this.v, {this.list, this.title = '', this.prompt = '', this.sum, this.f});
  final String h;
  final num w;
  final Object? Function(Map r) v;
  final Object? list; // List<String> or List<String> Function(List<Object> row)
  final String title, prompt;
  final String? sum;
  final String Function(String Function(String) L, int n, Map? r)? f;
}

Object? _g(Map r, String k) => r[k];
bool _used(List<Map> rows, String k) => rows.any((r) => r['blank'] != true && r[k] != '' && r.containsKey(k) && r[k] != null);

List<_Col> _colsFor(List<Map<String, dynamic>> ms, List<Map> rows, Map itemBoq, Iterable<Map<String, dynamic>> master) {
  final ways = <String>{};
  for (final m in ms) {
    ways.addAll(modesOfM(m));
  }
  final needs = [for (final m in ms) _fmtNeeds['${m['lbFormat']}'] ?? const <String>{}];
  final km = ways.any(hasKm) || _used(rows, 'ckm'), hr = ways.any(hasHr) || _used(rows, 'chr');
  final tp = ways.contains('Trip') || needs.any((n) => n.contains('tripAll') || n.contains('tripTime')) || rows.any((r) => _n0(r['trip']) > 0);
  final tm = ways.contains('Time') || needs.any((n) => n.contains('tripTime')) || _used(rows, 'tStart');
  final ch = tp || needs.any((n) => n.contains('challan')) || _used(rows, 'challan');
  final noCh = ms.isNotEmpty && needs.every((n) => n.contains('noCh')) && !_used(rows, 'chFrom') && !_used(rows, 'chTo');
  final one = ms.length == 1 ? ms.first : null;
  final its = one == null ? const <Map>[] : [for (final x in (itemBoq[one['id']] as List? ?? const [])) x as Map];
  final way1 = one == null ? const <String>[] : Machine(one).modesMain;
  final typed = its.where((it) => it['qty'] != 'rest' && itemKind(it['basis']) != 'day').toList();
  final pick = ['hr', 'km', 'trip'].any((k) => its.where((it) => itemKind(it['basis']) == k).length > 1) ? [for (final it in its) if (itemKind(it['basis']) != 'day') '${it['name']}'] : <String>[];
  final anyItems = ms.any((m) => (itemBoq[m['id']] as List? ?? const []).isNotEmpty) || rows.any((r) => r['itemWork'] is Map && (r['itemWork'] as Map).isNotEmpty);
  List<Map> qtys(Map r) => [for (final x in (r['itemQty'] as List? ?? const []).whereType<Map>()) if (x['k'] != 'day' && _n0(x['q']) > 0) x];
  final c = <_Col>[];
  c.add(_Col('Date', 12, (r) => showDateJs(r['date'])));
  c.add(_Col('Shift', 9, (r) => r['shift'], list: const ['Full Day', 'Day', 'Night'], title: 'Shift', prompt: 'Full Day, Day or Night'));
  c.add(_Col('Machinery', 18, (r) => r['no']));
  c.add(_Col('Type', 13, (r) => r['type']));
  c.add(_Col('Measured by', 13, (r) => r['blank'] == true ? (one != null && way1.length == 1 && way1.first != 'Day' ? way1.first : '') : (jsTrue(r['mode']) ? r['mode'] : r['unit']),
      list: (List<Object> row) {
        final m = findMachine(master, jsS(row.length > 2 && row[2] != '' ? row[2] : ''));
        return m != null ? [...modesOfM(m), ...kDayStatusL] : kDayStatusL;
      },
      title: 'Measured by',
      prompt: 'How it worked that day – or Idle / Holiday / Breakdown (then nothing else is filled).'));
  _Col tot(String a, String b2) => _Col('Total $a', 10, (r) => r[b2], sum: b2, f: (L, n, r) {
        final g = b2 == 'whr' && r != null ? partsGap(r['itemParts']) : 0.0;
        return 'IF(AND(ISNUMBER(${L('Close $a')}$n),ISNUMBER(${L('Start $a')}$n)),${L('Close $a')}$n-${L('Start $a')}$n${g > 0 ? '-${jsNumS(g)}' : g < 0 ? '+${jsNumS(_r2(-g))}' : ''},"")';
      });
  if (km) c.addAll([_Col('Start KM', 11, (r) => r['okm']), _Col('Close KM', 11, (r) => r['ckm']), tot('KM', 'wkm')]);
  if (hr) c.addAll([_Col('Start Hrs', 11, (r) => r['ohr']), _Col('Close Hrs', 11, (r) => r['chr']), tot('Hrs', 'whr')]);
  if (tm) {
    c.addAll([
      _Col('From time', 10, (r) => jsTrue(r['tStart']) ? r['tStart'] : ''),
      _Col('To time', 10, (r) => jsTrue(r['tEnd']) ? r['tEnd'] : ''),
      _Col('Break (min)', 10, (r) => r.containsKey('tBrk') ? r['tBrk'] : ''),
    ]);
  }
  if (tp) c.add(_Col('Trips', 8, (r) => r.containsKey('trip') ? r['trip'] : '', sum: 'trip'));
  if (ch) c.add(_Col('Challan No', 14, (r) => jsTrue(r['challan']) ? r['challan'] : ''));
  if (pick.isNotEmpty) {
    c.add(_Col('Work type', 13, (r) {
      final q = qtys(r);
      return r['blank'] == true || _isDay(jsTrue(r['mode']) ? r['mode'] : r['unit']) ? '' : q.length > 1 ? 'Split' : q.length == 1 ? q.first['n'] : '';
    },
        list: [...pick, 'Split'],
        title: 'Work type',
        prompt: 'Pick the work of the day: ${pick.join(' / ')} (the whole entry) – or Split, then type the quantity of ${typed.isEmpty ? 'each' : typed.map((it) => it['name']).join(', ')} in its column.'));
  }
  if (one != null) {
    for (final it in typed) {
      c.add(_Col('${it['name']} (${kItemWord[itemKind(it['basis'])]})', 12, (r) {
        final q = qtys(r);
        final iw = r['itemWork'] is Map ? r['itemWork'] as Map : const {};
        return q.length > 1 || pick.isEmpty ? (iw.containsKey(it['name']) ? iw[it['name']] : '') : '';
      }));
    }
  } else if (anyItems) {
    c.add(_Col('Item work', 22, (r) => itemWorkText(r['itemWork'])));
  }
  if (!noCh) c.addAll([_Col('Chainage From', 13, (r) => r['chFrom']), _Col('Chainage To', 13, (r) => r['chTo'])]);
  c.addAll([_Col('Work Done', 26, (r) => r['work']), _Col('Driver Name', 16, (r) => r['driver']), _Col('Remark', 20, (r) => r['remark'])]);
  if (rows.any((r) => jsTrue(r['debitTo']))) {
    c.addAll([
      _Col('Debit to', 24, (r) => jsTrue(r['debitTo']) ? r['debitTo'] : ''),
      _Col('Debit rate', 11, (r) => jsTrue(r['debitTo']) ? (r['debitRate'] ?? '') : ''),
    ]);
  }
  return c;
}

/// The web's showDate (yyyy-mm-dd → dd-mm-yyyy; anything else turned round the same way).
String showDateJs(Object? dk) {
  if (!jsTrue(dk)) return '';
  final p = jsS(dk).split('-');
  String at(int i) => i < p.length ? p[i] : 'undefined';
  return '${at(2)}-${at(1)}-${at(0)}';
}

String _xl(int n) {
  var t = '';
  n++;
  while (n > 0) {
    t = String.fromCharCode(65 + (n - 1) % 26) + t;
    n = (n - 1) ~/ 26;
  }
  return t;
}

List<List<Object>> lbHeadRows(String title, String company, String site) => [
      [company],
      [site],
      [title],
      [],
    ];

Object _cellOf(Object? v) => v ?? '';

/// The web's lbSheet: title lines, headings, a row per entry (a formula where its column has one), an empty line, the totals.
XSheet _lbSheet(String name, String title, List<_Col> cols, List<Map> rows, bool gap, String company, String site) {
  String L(String h) => _xl(cols.indexWhere((x) => x.h == h));
  final aoa = <List<Object>>[...lbHeadRows(title, company, site), [for (final x in cols) x.h]];
  final heads = aoa.length;
  var cur = '';
  for (final r in rows) {
    if (gap && cur.isNotEmpty && r['date'] != cur) aoa.add([]);
    cur = '${r['date']}';
    final n = aoa.length + 1;
    final w = jsTrue(r['mode']) ? r['mode'] : r['unit'];
    aoa.add([
      for (final x in cols)
        () {
          final v = x.v(r);
          if (x.f == null || _isDay(w) || w == kNoReading) return _cellOf(v);
          return v == '' || v == null ? XFormula(x.f!(L, n, r)) : XFormula(x.f!(L, n, r), _n0OrNaN(v));
        }(),
    ]);
  }
  aoa.add([]);
  aoa.add([
    for (final (k, x) in cols.indexed)
      k == 0 ? 'Total – ${rows.where((r) => r['blank'] != true).length} entries' : x.sum != null ? _r2(rows.fold<double>(0, (a, r) => a + _n0(r[x.sum]))) : '',
  ]);
  final sh = XSheet(name, aoa, widths: [for (final x in cols) x.w], head: heads);
  bool skip(List<Object> row) => (row.length > 2 ? jsS(row[2]) : '').trim().isEmpty || RegExp(r'^total', caseSensitive: false).hasMatch(row.isEmpty ? '' : jsS(row[0]));
  for (final (k, x) in cols.indexed) {
    if (x.list == null) continue;
    _validate(sh, k, x.list!, x.title, x.prompt, skip);
  }
  return sh;
}

num _n0OrNaN(Object? v) => v is num ? v : jsNumber(jsS(v)); // Number(v)

/// The web's saveXlsxLists: the drop-down on every row under the headings (a row that is empty, or that [skip] leaves out, has none).
void _validate(XSheet sh, int col, Object list, String title, String prompt, bool Function(List<Object>)? skip, {String? ref}) {
  for (var r = sh.head + 1; r <= sh.aoa.length; r++) {
    final row = sh.aoa[r - 1];
    if (row.isEmpty || (skip != null && skip(row))) continue;
    final vals = ref != null ? null : list is List<String> Function(List<Object>) ? list(row) : list as List<String>;
    if (ref == null && (vals == null || vals.isEmpty)) continue;
    final cell = col < row.length ? row[col] : '';
    final xl = XList(ref ?? '"${vals!.join(',')}"', title, prompt, ref != null ? 'Pick from the list.' : 'Pick one of: ${vals!.join(', ')}');
    sh.validations.add((r, col + 1, xl, cell == '' || cell == false));
  }
}

/// The web's lbExport: (the file name, its tabs, what is said) – or an error to show. [rows], [itemBoq]: the server's answer to
/// getLogBookList for the filter [f] (made by [lbExportFilter]).
({String file, List<XSheet> sheets, String said}) lbExport({
  required String kind,
  required Map<String, Object> f,
  required Map<String, dynamic>? picked,
  required List<Map<String, dynamic>> rows0,
  required Map itemBoq,
  required List<Map<String, dynamic>> master,
  required String today,
  required String company,
  required String site,
}) {
  // a water tanker's entry: one line per trip (the entry's diesel on its first line only)
  final rows = <Map<String, dynamic>>[];
  for (final r in rows0) {
    final ts = tripsOfRow(r, master);
    if (ts == null || ts.isEmpty) {
      rows.add(r);
      continue;
    }
    for (final (k, t) in ts.indexed) {
      rows.add({...r, 'trip': 1, 'challan': t['c'], 'tStart': t['a'], 'tEnd': t['b'], 'chFrom': t['ch'], 'chTo': '', 'work': t['u'], if (k > 0) ...{'odsl': '', 'qty': '', 'stdUse': '', 'stock': ''}});
    }
  }
  final ft = '${f['to']}', ff = '${f['from']}';
  final to = ft.isNotEmpty && ft.compareTo(today) < 0 ? ft : today, from = ff.isNotEmpty ? ff : '${to.substring(0, 8)}01';
  if (from.compareTo(to) > 0) throw SheetError('From date is after To date.');
  final nDays = parseKey(to).difference(parseKey(from)).inDays + 1;
  if (nDays > 93) throw SheetError('Pick up to 3 months (From and To) to get the dates to fill.');
  final fno = '${f['no']}', fm = fno.isNotEmpty ? findMachine(master, fno) : null;
  String up(Object? v) => (jsTrue(v) ? jsS(v) : '').toUpperCase();
  final own = '${f['own'] ?? ''}', type = '${f['type'] ?? ''}', owner = '${f['owner'] ?? ''}';
  final ms = fm != null
      ? [fm]
      : master.where((m) => m['supply'] != 'Debit Basis' && (own.isEmpty || m['ownership'] == own) && (type.isEmpty || up(m['type']) == type.toUpperCase()) && (owner.isEmpty || up(m['owner']) == owner.toUpperCase())).toList();
  final have = {for (final r in rows) '${r['no']}|${r['date']}'};
  final real = rows.length;
  for (final m in ms) {
    for (var k = 0; k < nDays; k++) {
      final dk = addDay(from, k);
      if (!onSiteOn(m, dk) || have.contains('${m['id']}|$dk')) continue;
      rows.add({'date': dk, 'shift': 'Full Day', 'no': m['id'], 'type': jsTrue(m['type']) ? m['type'] : '', 'unit': '', 'mode': '', 'blank': true});
    }
  }
  if (rows.isEmpty) throw SheetError('No machinery for this filter.');
  final period = '${showDate(from)} to ${showDate(to)}';
  String ord(Map r) => '${r['date']}|${r['shift'] == 'Night' ? 1 : 0}';
  List<Map<String, dynamic>> machOf(List<Map> rs) => [for (final n in {for (final r in rs) '${r['no']}'}) findMachine(master, n)].whereType<Map<String, dynamic>>().toList();
  final sheets = <XSheet>[];
  const heads = 5; // lbHeadRows('x').length + 1
  if (kind == 'date') {
    final rs = [...rows]..sort((a, b) {
        final c = ord(a).compareTo(ord(b));
        return c != 0 ? c : localeCmp('${a['no']}', '${b['no']}');
      });
    sheets.add(_lbSheet('Date-wise', 'Log Book – date-wise – ${picked != null ? '${picked['id']} – ' : ''}$period', _colsFor(machOf(rs), rs, itemBoq, master), rs, picked == null, company, site));
  } else {
    final by = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      (by['${r['no']}'] ??= []).add(r);
    }
    final names = by.keys.toList()..sort((a, b) => localeCmp(a, b, numeric: true));
    final sum = <List<Object>>[
      ['Machinery', 'Type', 'Works on', 'Entries', 'Empty dates', 'Total KM', 'Total Hrs', 'Trips'],
    ];
    for (final n in names) {
      final rs = by[n]!;
      Object t(String k) {
        final v = _r2(rs.fold<double>(0, (a, r) => a + _n0(r[k])));
        return v == 0 ? '' : v;
      }

      final mm = findMachine(master, n);
      final wo = mm == null ? '' : worksOfJs(mm).join(', ');
      sum.add([n, _cellOf(rs.first['type']), wo.isNotEmpty ? wo : _cellOf(rs.first['unit']), rs.where((r) => r['blank'] != true).length, rs.where((r) => r['blank'] == true).length, t('wkm'), t('whr'), t('trip')]);
    }
    sheets.add(XSheet('Summary', [...lbHeadRows('Log Book – machinery-wise – $period', company, site), ...sum], widths: const [18, 14, 12, 9, 12, 10, 10, 8], head: heads));
    final used = <String>{};
    for (final n in names) {
      final rs = [...by[n]!];
      _stableSort(rs, (a, b) => ord(a).compareTo(ord(b)));
      var tab = n.replaceAll(RegExp(r'[\[\]:*?\/\\]'), '-');
      if (tab.length > 28) tab = tab.substring(0, 28);
      var k = 2;
      while (used.contains(tab.toLowerCase())) {
        tab = '${n.length > 25 ? n.substring(0, 25) : n} (${k++})';
      }
      used.add(tab.toLowerCase());
      sheets.add(_lbSheet(tab, 'Log Book – $n – $period', _colsFor(machOf(rs), rs, itemBoq, master), rs, false, company, site));
    }
  }
  final file = 'Log Book ${picked != null ? '${picked['id']} ' : kind == 'date' ? 'date-wise ' : 'machinery-wise '}${period.replaceAll('/', '-')}.xlsx';
  final said = picked != null
      ? '${picked['id']}: $real saved entr${real == 1 ? 'y' : 'ies'} and ${rows.length - real} empty date(s) to fill, $period. Fill the sheet and bring it back with "Import from Excel".'
      : '${rows.length} Log Book rows exported.';
  return (file: file, sheets: sheets, said: said);
}

/// The web's worksOf (its ticks; else from its unit).
List<String> worksOfJs(Map<String, dynamic> m) {
  final w = m['worksOn'];
  if (w is List && w.isNotEmpty) return [for (final x in w) '$x'];
  return worksOf({...m, 'worksOn': null});
}

void _stableSort<T>(List<T> l, int Function(T, T) cmp) {
  final ix = [for (var i = 0; i < l.length; i++) i];
  final copy = [...l];
  ix.sort((a, b) {
    final c = cmp(copy[a], copy[b]);
    return c != 0 ? c : a.compareTo(b);
  });
  for (var i = 0; i < l.length; i++) {
    l[i] = copy[ix[i]];
  }
}

/// The filter sent for an export (the web's: the machinery picked wins over type / owner / text).
Map<String, Object> lbExportFilter({required String from, required String to, required String no, required Map<String, dynamic>? picked, String shift = '', String own = '', String type = '', String owner = '', String q = ''}) => {
      'from': from,
      'to': to,
      'no': picked != null ? '${picked['id']}' : no,
      'shift': shift,
      'ownership': own,
      'own': own,
      'type': picked != null ? '' : type,
      'owner': picked != null ? '' : owner,
      'q': picked != null ? '' : q,
      'all': true,
    };

/// The web's lbTemplate: (file name, the Log Book tab with 200 lines and its drop-downs, the hidden Lists tab).
({String file, List<XSheet> sheets}) lbTemplate(String kind, List<Map<String, dynamic>> master, String today) {
  final act = master.where((m) => onSiteOn(m, today) && needsLogBook(m)).toList();
  Map<String, dynamic>? first(Iterable<Map<String, dynamic>> l, bool Function(Map<String, dynamic>) t) {
    for (final m in l) {
      if (t(m)) return m;
    }
    return null;
  }

  final km = first(act, (m) => m['unit'] == 'KM'), hr = first(act, (m) => m['unit'] == 'Hrs') ?? km;
  const head = ['Date', 'Shift', 'Machinery', 'Measured by', 'Start KM', 'Close KM', 'Start Hrs', 'Close Hrs', 'From time', 'To time', 'Break (min)', 'Trips', 'Challan No', 'Opening diesel (L)', 'Chainage From', 'Chainage To', 'Work Done', 'Driver Name', 'Remark', 'Status', 'Item work'];
  List<Object> ins(List<Object> r) => [...r.sublist(0, 3), '', ...r.sublist(3, 7), '', '', '', '', '', ...r.sublist(7)];
  final d0 = showDate(today), d1 = showDate(addDay(today, -2)), d2 = showDate(addDay(today, -1));
  final kmId = km != null ? '${km['id']}' : 'MH-25-AJ-3232', hrId = hr != null ? '${hr['id']}' : '400 KVA DG';
  final rows = kind == 'date'
      ? <List<Object>>[
          [d0, 'Full Day', kmId, '', 1260, '', '', '', '12+500', '13+000', 'Soil carting', '', ''],
          [d0, 'Full Day', hrId, '', '', '', 118, '', '', '', 'Excavation', '', ''],
        ]
      : <List<Object>>[
          [d1, 'Full Day', kmId, '', 1240, '', '', '', '', '', 'Soil carting', '', ''],
          [d2, 'Full Day', kmId, '', 1260, '', '', '', '', '', 'Soil carting', '', ''],
          [d0, 'Full Day', kmId, '', 1285, '', '', '', '', '', 'Soil carting', '', ''],
        ];
  final tm = first(master, (m) => modesOfM(m).contains('Time')), tp = first(master, (m) => modesOfM(m).contains('Trip'));
  final extra = <List<Object>>[
    if (tm != null) [d0, 'Full Day', '${tm['id']}', 'Time', '', '', '', '', '08:00', '13:00', 30, '', '', '', '', '', 'Dewatering', '', ''],
    if (tp != null) [d0, 'Full Day', '${tp['id']}', 'Trip', '', '', '', '', '', '', '', 12, 'CH-1041, CH-1042', '', '', '', 'Murum carting', '', ''],
  ];
  final idleEx = <List<Object>>[
    if (km != null) [d0, 'Night', '${km['id']}', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'Idle'],
  ];
  final body = <List<Object>>[head, ...rows.map(ins), ...extra, ...idleEx];
  while (body.length < 201) {
    body.add(['', '', '']);
  }
  final names = [for (final m in act) '${m['id']}'];
  final sh = XSheet('Log Book', body, widths: const [12, 9, 20, 12, 9, 9, 9, 9, 9, 9, 9, 7, 16, 14, 12, 12, 22, 16, 18, 12, 22], head: 1);
  _validate(sh, 1, const ['Full Day', 'Day', 'Night'], 'Shift', 'Full Day, Day or Night', null);
  _validate(sh, 2, const <String>[], 'Machinery', 'Pick the machinery', null, ref: 'Lists!\$A\$1:\$A\$${names.length > 1 ? names.length : 1}');
  _validate(sh, 3, [...kWaysAll, ...kDayStatusL], 'Measured by', 'A way ticked for this machinery in Asset Master – or Idle (paid or not: chosen in the bill) / Holiday / Breakdown (not paid).', null);
  _validate(sh, head.indexOf('Status'), kLbStatus, 'Status', 'Working = fill Measured by and readings. Idle / Holiday / Breakdown = nothing else to fill.', null);
  return (
    file: 'Log Book – import template (${kind == 'date' ? 'one date – many machinery' : 'one machinery – many dates'}).xlsx',
    sheets: [sh, XSheet('Lists', [for (final n in names) [n]], hidden: true)],
  );
}

/* ---------------- the import ---------------- */

/// The web's LB_COLS: the columns of a Log Book file (either layout, any order).
final Cols kLogCols = [
  ('date', RegExp(r'^(date|log date)$')),
  ('shift', RegExp(r'^shift$')),
  ('no', RegExp(r'^(machinery|machinery number|machinery number \/ name|machine|vehicle|vehicle number|machinery no)$')),
  ('okm', RegExp(r'^(start km|opening km)$')),
  ('ckm', RegExp(r'^(close km|closing km)$')),
  ('ohr', RegExp(r'^(start hrs|opening hrs|start hr)$')),
  ('chr', RegExp(r'^(close hrs|closing hrs|close hr)$')),
  ('odsl', RegExp(r'^(opening diesel|opening diesel \(l\)|opening diesel \(ltr\))$')),
  ('chFrom', RegExp(r'^(chainage from)$')),
  ('chTo', RegExp(r'^(chainage to)$')),
  ('work', RegExp(r'^(work done|work description|work)$')),
  ('driver', RegExp(r'^(driver|driver name|operator)$')),
  ('remark', RegExp(r'^(remark|remarks)$')),
  ('mode', RegExp(r'^(measured by|measured|unit)$')),
  ('tStart', RegExp(r'^(from time|start time|time from|from)$')),
  ('tEnd', RegExp(r'^(to time|end time|time to|to)$')),
  ('tBreak', RegExp(r'^(break|break \(min\)|break min|break \(minutes\))$')),
  ('trip', RegExp(r'^(trip|trips|no of trips|number of trips)$')),
  ('challan', RegExp(r'^(challan|challan no|challan number|challan nos)$')),
  ('status', RegExp(r'^(status|day status)$')),
  ('items', RegExp(r'^(item work|items|item)$')),
  ('workType', RegExp(r'^(work type)$')),
  ('debitTo', RegExp(r'^(debit to|debit party)$')),
  ('debitRate', RegExp(r'^(debit rate)$')),
];

String _hhmm(Object? v) {
  if (v == '' || v == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  if (v is num) {
    final t = _jsRound(((v % 1) * 1440).toDouble());
    return '${p(t ~/ 60)}:${p(t % 60)}';
  }
  final s = jsS(v).trim();
  final q = RegExp(r'^(\d{1,2})[:.](\d{2})\s*(am|pm)?$', caseSensitive: false).firstMatch(s);
  if (q == null) return s;
  var h = int.parse(q[1]!);
  if (q[3] != null) {
    final pm = q[3]!.toLowerCase() == 'pm';
    if (h == 12) {
      h = pm ? 12 : 0;
    } else if (pm) {
      h += 12;
    }
  }
  return '${p(h)}:${q[2]}';
}

Map<String, Object>? _itemsOf(Map x) {
  final wt = (jsTrue(x['workType']) ? jsS(x['workType']) : '').trim();
  if (wt.isNotEmpty && !RegExp(r'^split$', caseSensitive: false).hasMatch(wt)) return {'_all': wt};
  final o = <String, Object>{};
  final more = x['_more'] is Map ? x['_more'] as Map : const {};
  for (final e in more.entries) {
    final q = RegExp(r'^(.+?)\s*\((hr|hrs|km|trip|trips)\)$', caseSensitive: false).firstMatch('${e.key}');
    final v = e.value;
    if (q == null || v == '' || v == null) continue;
    final n = jsNumber(jsS(v).replaceAll(',', ''));
    if (n.isFinite) o[q[1]!.trim()] = n;
  }
  return o.isEmpty ? null : o;
}

/// Every row of a Log Book file as the web reads it, the blank ones left out and a water tanker's lines made trips.
({List<Map<String, Object?>> rows, int skipped, List<Map<String, Object?>> trips, List<Map<String, Object?>> tkBad, int tkStatus, String tkStatusNote}) readLogFile(
    List<SheetTab> tabs, List<Map<String, dynamic>> master) {
  final raw = readExcelRows(tabs, kLogCols, const ['date', 'no'], allSheets: true);
  if (raw.isEmpty) throw SheetError('No rows found under the heading row.');
  Object numv(Object? v) => v == '' || v == null ? '' : jsNumber(jsS(v).replaceAll(',', ''));
  String s(Object? v) => (jsTrue(v) ? jsS(v) : '').trim();
  final all = <Map<String, Object?>>[];
  for (final x in raw) {
    final m = findMachine(master, jsS(x['no']).trim());
    final sh = s(x['shift']);
    final md = modesOfM(m), want = s(x['mode']);
    String squash(String v) => v.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final hit = md.where((k) => squash(k) == squash(want)).firstOrNull;
    final st = s(x['status']);
    final stHit = kDayStatusL.where((k) => k.toLowerCase() == st.toLowerCase()).firstOrNull, wantSt = kDayStatusL.where((k) => k.toLowerCase() == want.toLowerCase()).firstOrNull;
    final items = s(x['items']).isNotEmpty ? itemWorkRead(x['items']) : _itemsOf(x);
    final has = x['_has'] is Map ? x['_has'] as Map : const {};
    all.add({
      'line': x['line'],
      'date': xlDate(x['date']),
      'shift': RegExp(r'^n', caseSensitive: false).hasMatch(sh) ? 'Night' : RegExp(r'^d', caseSensitive: false).hasMatch(sh) ? 'Day' : 'Full Day',
      'no': m != null ? '${m['id']}' : jsS(x['no']).trim(),
      if (m == null || m['unit'] != null) 'unit': m != null ? m['unit'] : '',
      'mode': stHit ?? wantSt ?? (want.isNotEmpty ? (hit ?? want) : ''),
      'tStart': _hhmm(x['tStart']),
      'tEnd': _hhmm(x['tEnd']),
      'tBreak': numv(x['tBreak']),
      'trip': numv(x['trip']),
      'challan': s(x['challan']),
      'openingKm': numv(x['okm']),
      'closingKm': numv(x['ckm']),
      'openingHr': numv(x['ohr']),
      'closingHr': numv(x['chr']),
      'openingDiesel': numv(x['odsl']),
      'chFrom': s(x['chFrom']),
      'chTo': s(x['chTo']),
      'work': s(x['work']),
      'driver': s(x['driver']),
      'remark': s(x['remark']),
      'debitTo': s(x['debitTo']),
      'debitRate': numv(x['debitRate']),
      if (items != null) 'items': items,
      'needWork': has.containsKey('workType'),
    });
  }
  bool filled(Map r) =>
      _isDay(r['mode']) ||
      r['mode'] == 'Day' ||
      ['openingKm', 'closingKm', 'openingHr', 'closingHr', 'openingDiesel', 'tBreak', 'trip'].any((k) => r[k] != '' && r.containsKey(k) && !(r[k] is double && (r[k] as double).isNaN)) ||
      ['tStart', 'tEnd', 'challan', 'chFrom', 'chTo', 'work', 'driver', 'remark'].any((k) => s(r[k]).isNotEmpty);
  final rows = all.where(filled).toList();
  final skipped = all.length - rows.length;
  if (rows.isEmpty) throw SheetError('Every row of the file is blank – fill Measured by and the readings, then import.');
  bool isTk(Map r) => findMachine(master, r['no'])?['lbFormat'] == 'I';
  final tkRows = rows.where(isTk).toList(), log = rows.where((r) => !isTk(r)).toList();
  final tkBad = <Map<String, Object?>>[], trips = <Map<String, Object?>>[];
  var tkStatus = 0;
  for (final r in tkRows) {
    if (_isDay(r['mode'])) {
      tkStatus++;
      continue;
    }
    final list = s(r['challan']).split(RegExp(r'\s*[,;\n]\s*')).where((x) => x.isNotEmpty).toList();
    final n = _n0(r['trip']);
    if (list.length > 1 || n > 1) {
      final c = list.length > n ? list.length : n;
      tkBad.add({'line': r['line'], 'msg': '${r['no']} is a water tanker – one line per trip (this line has ${jsNumS(c)} trips): each trip on its own line with its Challan No, From time (dispatch) and To time (unload).'});
      continue;
    }
    trips.add({'line': r['line'], 'no': r['no'], 'date': r['date'], 'shift': r['shift'] == 'Night' ? 'Night' : 'Day', 'c': r['challan'], 'a': r['tStart'], 'b': r['tEnd'], 'ch': [r['chFrom'], r['chTo']].where(jsTrue).map(jsS).join(' – '), 'u': r['work']});
  }
  final note = tkStatus > 0 ? '$tkStatus line${tkStatus == 1 ? '' : 's'} of a water tanker with Idle / Holiday / Breakdown – not imported (a water tanker is entered by its trips only)' : '';
  if (log.isEmpty && trips.isEmpty && tkBad.isEmpty) throw SheetError(note.isNotEmpty ? '$note. Nothing to import.' : 'Every row of the file is blank – fill Measured by and the readings, then import.');
  return (rows: log, skipped: skipped, trips: trips, tkBad: tkBad, tkStatus: tkStatus, tkStatusNote: note);
}

/// The web's lbProblems of a row of the file.
List<String> logProblems(Map r, String today, List<Map<String, dynamic>> master) {
  final p = <String>[];
  final d = '${r['date']}';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)) {
    p.add('date');
  } else if (d.compareTo(today) > 0) {
    p.add('date after today');
  }
  final m = findMachine(master, r['no']);
  if (m == null) {
    p.add('machinery not in Master');
    return p;
  }
  if (activeProblem(m, d).isNotEmpty) p.add('not active on that date');
  final md = [...modesOfM(m), ...kDayStatusL];
  if (md.length == kDayStatusL.length) {
    p.add('tick "Works on" in Asset Master');
    return p;
  }
  final w = jsTrue(r['mode']) ? jsS(r['mode']) : (md.contains(m['unit']) ? '${m['unit']}' : md.first);
  if (!md.contains(w)) {
    p.add('does not work on "$w"');
    return p;
  }
  if (hasKm(w) && r['closingKm'] == '') p.add('Close KM');
  if (hasHr(w) && r['closingHr'] == '') p.add('Close Hrs');
  if (w == 'Time' && (!jsTrue(r['tStart']) || !jsTrue(r['tEnd']))) p.add('From / To time');
  if (w == 'Trip' && !(_n0OrNaN(r['trip']) > 0)) p.add('Trips');
  if (r['needWork'] == true && !_isDay(w) && r['items'] == null) p.add('Work type');
  return p;
}
