/* THE EXCEL IMPORTS OF THE DIESEL PAGES (3.11.0) – the web's own working (App.html "DIESEL INWARD – IMPORT / EXPORT", "DIESEL
 * TRANSFER – multiple entries, import, export", "DIESEL ISSUE – import / export"): the heading row found by its words, each row
 * read into an entry, the problems of each row (✗) – nothing is sent while one row has a problem – and the server's own check
 * on importing (importInward / saveTransferBulk / importDiesel: all rows or none). The templates and the exports are the web's
 * files. The reading of the file itself: sheet_read.dart. Proven against the web's code: test/fixtures/sheets/web_imports.json. */
import 'assets.dart' show periodsOf, dayBefore;
import 'format.dart';
import 'sheet_read.dart';

/* ---------------- a date of a cell (Excel's day number, or a text dd-mm-yyyy / yyyy-mm-dd) ---------------- */

/// SheetJS SSF.parse_date_code (the 1900 date system, as the web calls it): (y, m, d) – null when out of range.
(int, int, int)? parseDateCode(num v) {
  if (v > 2958465 || v < 0) return null;
  if (v.isNaN) return (1900, 1, 0); // JS: (NaN|0) = 0 → "1900-01-00"
  var date = v.truncate();
  var time = (86400 * (v - date)).floor();
  var u = 86400 * (v - date) - time;
  if (u.abs() < 1e-6) u = 0;
  if (u > 0.9999) {
    if (++time == 86400) {
      time = 0;
      ++date;
    }
  }
  if (date == 60) return (1900, 2, 29);
  if (date == 0) return (1900, 1, 0);
  if (date > 60) --date;
  final d = DateTime.utc(1900, 1, date);
  return (d.year, d.month, d.day);
}

String _p2(int n) => n.toString().padLeft(2, '0');

/// The web's xlDate: a cell → yyyy-mm-dd (anything else is given back as it is – the check shows it as a problem).
String xlDate(Object? v) {
  if (v == '' || v == null) return '';
  if (v is num) {
    final d = parseDateCode(v);
    if (d != null) return '${d.$1}-${_p2(d.$2)}-${_p2(d.$3)}';
  }
  final t = jsS(v).trim();
  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(t);
  if (m != null) return '${m[1]}-${m[2]!.padLeft(2, '0')}-${m[3]!.padLeft(2, '0')}';
  m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$').firstMatch(t);
  if (m != null) {
    final y = m[3]!.length == 2 ? '20${m[3]}' : m[3]!;
    return '$y-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}';
  }
  return t;
}

/* ---------------- the columns of each import (the web's IMP_COLS / TR_COLS / DI_COLS) ---------------- */
typedef Cols = List<(String, RegExp)>;

final Cols kInwardCols = [
  ('date', RegExp(r'^(date|inward date|entry date)$')),
  ('location', RegExp(r'^(received at|location|store|received)$')),
  ('pump', RegExp(r'^(pump|pump name|supplier|vendor)$')),
  ('qty', RegExp(r'^(qty|qty \(ltr\)|quantity|litres|liters|ltr)$')),
  ('rate', RegExp(r'^(rate|rate \(₹\/ltr\)|rate \(rs\/ltr\)|rate\/ltr)$')),
  ('billNo', RegExp(r'^(bill|bill no|bill number|bill no\.|invoice|invoice no)$')),
  ('billDate', RegExp(r'^(bill date|invoice date)$')),
];
final Cols kTransferCols = [
  ('date', RegExp(r'^(date|transfer date)$')),
  ('shift', RegExp(r'^shift$')),
  ('from', RegExp(r'^(from|from location|from stock point)$')),
  ('to', RegExp(r'^(to|to location|to stock point)$')),
  ('qty', RegExp(r'^(qty|qty \(ltr\)|quantity|litres|liters|ltr)$')),
  ('remark', RegExp(r'^(remark|remarks|note)$')),
];
final Cols kIssueCols = [
  ('date', RegExp(r'^(date|issue date)$')),
  ('shift', RegExp(r'^shift$')),
  ('source', RegExp(r'^(diesel source|source|from)$')),
  ('no', RegExp(r'^(machinery|machinery number|machinery number \/ name|machine|machine number|vehicle|vehicle number|machinery no)$')),
  ('qty', RegExp(r'^(qty|diesel qty|diesel qty \(ltr\)|qty \(ltr\)|litres|liters|ltr)$')),
  ('km', RegExp(r'^(km|km reading)$')),
  ('hr', RegExp(r'^(hrs|hr|hrs reading|hr reading|hours)$')),
  ('driver', RegExp(r'^(driver|driver name|operator)$')),
  ('remark', RegExp(r'^(remark|remarks|note)$')),
];

/// A heading as the web compares it: trimmed, small letters, a "*" at the end dropped, spaces as one.
String headNorm(Object? h) => jsS(h).trim().toLowerCase().replaceFirst(RegExp(r'\s*\*\s*$'), '').replaceAll(RegExp(r'\s+'), ' ');

bool _blankRow(List<Object?> r) => !r.any((v) => jsS(v).trim() != '');

String _str(Object? v) => jsTrue(v) ? jsS(v) : '';

/// Number(String(v).replace(/,/g, '')) of the web.
double _numText(Object? v, [String drop = ',']) => jsNumber(jsS(v).replaceAll(RegExp('[$drop]'), ''));

/// The web's readInwardFile: the first tab; the heading row = the first with a Date and a Qty column.
List<Map<String, Object?>> readInward(List<SheetTab> tabs, List<String> locations) {
  final all = tabs.isEmpty ? const <List<Object?>>[] : tabs.first.rows;
  final hi = all.indexWhere((r) => r.map(headNorm).any(kInwardCols[0].$2.hasMatch) && r.map(headNorm).any(kInwardCols[3].$2.hasMatch));
  if (hi == -1) throw SheetError('Could not find the heading row. The file needs at least "Date" and "Qty" columns – use "Download template".');
  final idx = <String, int>{};
  for (final (k, h) in all[hi].map(headNorm).indexed) {
    for (final c in kInwardCols) {
      if (!idx.containsKey(c.$1) && c.$2.hasMatch(h)) idx[c.$1] = k;
    }
  }
  final rows = <Map<String, Object?>>[];
  for (final (k, r) in all.sublist(hi + 1).indexed) {
    if (_blankRow(r)) continue;
    Object? g(String f) => idx[f] == null ? '' : r[idx[f]!];
    final loc = _str(g('location')).trim();
    rows.add({
      'line': hi + k + 2,
      'date': xlDate(g('date')),
      'location': loc.isNotEmpty ? loc : (locations.isNotEmpty ? locations.first : 'Dispenser'),
      'pump': jsS(g('pump')).trim(),
      'qty': g('qty') == '' ? '' : _numText(g('qty')),
      'rate': g('rate') == '' ? '' : _numText(g('rate'), ',₹'),
      'billNo': jsS(g('billNo')).trim(),
      'billDate': xlDate(g('billDate')),
    });
  }
  return rows;
}

final _day = RegExp(r'^\d{4}-\d{2}-\d{2}$');
bool _pos(Object? v) => v is num && v > 0;
bool _posNum(Object? v) => (v is num ? v : (v == '' ? 0 : jsNumber(jsS(v)))) > 0; // !(Number(v) > 0)

/// The web's impProblems.
List<String> inwardProblems(Map r, String today, List<String> locations) {
  final p = <String>[];
  final d = '${r['date']}';
  if (!_day.hasMatch(d)) {
    p.add('date');
  } else if (d.compareTo(today) > 0) {
    p.add('date after today');
  }
  if (!locations.contains(r['location'])) p.add('Received at must be ${locations.join(' / ')}');
  if (!jsTrue(r['pump'])) p.add('pump');
  if (!_pos(r['qty'])) p.add('qty');
  if (!_pos(r['rate'])) p.add('rate');
  if (jsTrue(r['billDate']) && !_day.hasMatch('${r['billDate']}')) p.add('bill date');
  return p;
}

/// The web's readExcelRows: the heading row = the first with every [need] column; each row with its line ("Tab – 5" when every
/// tab is read and there are several), the known columns, and the other columns by their own heading (_more).
List<Map<String, Object?>> readExcelRows(List<SheetTab> tabs, Cols spec, List<String> need, {bool allSheets = false}) {
  final rows = <Map<String, Object?>>[];
  var found = false;
  bool hit(List<Object?> r, String f) {
    final re = spec.firstWhere((x) => x.$1 == f).$2;
    return r.map(headNorm).any(re.hasMatch);
  }

  for (final t in allSheets ? tabs : tabs.take(1)) {
    final all = t.rows;
    final hi = all.indexWhere((r) => need.every((f) => hit(r, f)));
    if (hi == -1) continue;
    found = true;
    final idx = <String, int>{};
    for (final (k, h) in all[hi].map(headNorm).indexed) {
      for (final c in spec) {
        if (!idx.containsKey(c.$1) && c.$2.hasMatch(h)) idx[c.$1] = k;
      }
    }
    final known = idx.values.toSet();
    for (final (k, r) in all.sublist(hi + 1).indexed) {
      if (_blankRow(r)) continue;
      if (RegExp(r'^total', caseSensitive: false).hasMatch(jsS(r.isEmpty ? null : r[0]).trim())) continue;
      final o = <String, Object?>{'line': '${allSheets && tabs.length > 1 ? '${t.name} – ' : ''}${hi + k + 2}'};
      for (final c in spec) {
        o[c.$1] = idx[c.$1] == null ? '' : r[idx[c.$1]!];
      }
      o['_has'] = Map<String, int>.of(idx);
      final more = <String, Object?>{};
      for (final (q, h) in all[hi].indexed) {
        final hn = jsS(h).trim();
        if (hn.isNotEmpty && !known.contains(q)) more[hn] = r[q];
      }
      o['_more'] = more;
      rows.add(o);
    }
  }
  if (!found) throw SheetError('Could not find the heading row – use "Download template".');
  return rows;
}

String shiftName(Object? v) => RegExp(r'^n', caseSensitive: false).hasMatch(_str(v).trim()) ? 'Night' : 'Day';

String locName(Object? v, List<String> locations) {
  final t = _str(v).trim().toLowerCase();
  for (final l in locations) {
    if (l.toLowerCase() == t) return l;
  }
  return _str(v).trim();
}

/// The transfers of a file (the web's t_file handler).
List<Map<String, Object?>> transferRows(List<SheetTab> tabs, List<String> locations) => [
      for (final x in readExcelRows(tabs, kTransferCols, const ['date', 'qty']))
        {
          'line': x['line'],
          'date': xlDate(x['date']),
          'shift': shiftName(x['shift']),
          'from': locName(x['from'], locations),
          'to': locName(x['to'], locations),
          'qty': x['qty'] == '' ? '' : _numText(x['qty']),
          'remark': _str(x['remark']).trim(),
        },
    ];

/// The web's trProblems (a file's row and a row of "Multiple entries"). [mine] (3.43.0, update-162): his own diesel sources for the
/// From (null = every place); the To may be any place.
/// (3.44.0, Mechanical update-163) [fuels] = the fuel of each place (given when the site has fuels to check): a fill only from a place of
/// the machinery's fuel, a transfer only between places of one fuel – the server refuses the rest
String _mFuel(Map m) => const ['Diesel', 'Petrol', 'CNG', 'Electric'].contains('${m['fuel'] ?? ''}') ? '${m['fuel']}' : 'Diesel';
List<String> transferProblems(Map r, String today, List<String> locations, {List<String>? mine, Map<String, String>? fuels}) {
  final p = <String>[];
  final d = '${r['date']}';
  if (!_day.hasMatch(d)) {
    p.add('date');
  } else if (d.compareTo(today) > 0) {
    p.add('date after today');
  }
  if (!locations.contains(r['from'])) {
    p.add('From');
  } else if (mine != null && !mine.contains(r['from'])) {
    p.add('From – not your diesel source');
  }
  if (!locations.contains(r['to'])) p.add('To');
  if (jsTrue(r['from']) && r['from'] == r['to']) p.add('From = To');
  if (fuels != null && locations.contains(r['from']) && locations.contains(r['to']) && r['from'] != r['to']) {
    final ff = fuels['${r['from']}'] ?? 'Diesel', tf = fuels['${r['to']}'] ?? 'Diesel';
    if (ff != tf) p.add('From $ff, To $tf – not the same fuel');
  }
  if (!_posNum(r['qty'])) p.add('qty');
  return p;
}

/* ---------------- a machinery: found by its number / name, on site on a date (the web's findMachine / activeProblem) ---------------- */
String _noKey(Object? v) => _str(v).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

Map<String, dynamic>? findMachine(Iterable<Map<String, dynamic>> master, Object? no) {
  final k = _noKey(no);
  if (k.isEmpty) return null;
  for (final m in master) {
    if (_noKey(m['id']) == k) return m;
  }
  return null;
}

String _mDay(Object? v) {
  final s = v == null ? '' : '$v';
  return s.length > 10 ? s.substring(0, 10) : s;
}

bool onSiteOn(Map<String, dynamic> m, String dk) =>
    periodsOf(m).any((p) => (p.from.isEmpty || p.from.compareTo(dk) <= 0) && (p.until.isEmpty || dk.compareTo(p.until) < 0));

String _show(String dk) {
  final p = dk.split('-');
  return p.length >= 3 ? '${p[2]}-${p[1]}-${p[0]}' : showDate(dk);
}

/// Why a machinery cannot have an entry on [dk] ('' = it can) – the web's activeProblem, word for word.
String activeProblem(Map<String, dynamic>? m, String dk) {
  if (m == null || dk.isEmpty) return '';
  if (onSiteOn(m, dk)) return '';
  final ps = periodsOf(m), first = ps.first.from, id = '${m['id'] ?? ''}';
  if (first.isNotEmpty && dk.compareTo(first) < 0) return '$id is active only from ${_show(first)}. Entry date ${_show(dk)} is before that.';
  final inf = _mDay(m['inactiveFrom']);
  if (m['status'] == 'Inactive' && (inf.isEmpty || dk.compareTo(inf) >= 0)) {
    return '$id is inactive${inf.isNotEmpty ? ' from ${_show(inf)}' : ''}. Activate it in Master to make entries.';
  }
  for (var k = 0; k + 1 < ps.length; k++) {
    final p = ps[k], q = ps[k + 1];
    if (p.until.isNotEmpty && dk.compareTo(p.until) >= 0 && q.from.isNotEmpty && dk.compareTo(q.from) < 0) {
      return '$id was not on this site from ${_show(p.until)} to ${_show(dayBefore(q.from))} (it came back on ${_show(q.from)}). Entry date ${_show(dk)} is in that time.';
    }
  }
  return '$id is not on this site on ${_show(dk)}.';
}

/// The diesel issues of a file (the web's d_file handler).
/// [mine] (3.43.0, update-162): his own diesel sources – a blank source takes the first of them.
/// [fuels] (3.44.0, update-163): the fuel of each place – a blank source takes the first place of the machinery's fuel.
List<Map<String, Object?>> issueRows(List<SheetTab> tabs, List<String> locations, Iterable<Map<String, dynamic>> master, {List<String>? mine, Map<String, String>? fuels}) {
  Object num0(Object? v) => v == '' || v == null ? '' : _numText(v);
  return [
    for (final x in readExcelRows(tabs, kIssueCols, const ['date', 'no', 'qty']))
      () {
        final m = findMachine(master, jsS(x['no']).trim());
        final src = locName(x['source'], locations);
        final fz = fuels, mf = m == null ? '' : _mFuel(m), own0 = mine ?? locations;
        final ownF = fz != null && mf.isNotEmpty ? own0.where((l) => (fz[l] ?? 'Diesel') == mf).toList() : own0, own = ownF.isNotEmpty ? ownF : own0;
        return <String, Object?>{
          'line': x['line'],
          'date': xlDate(x['date']),
          'shift': shiftName(x['shift']),
          'source': src.isNotEmpty ? src : (own.isNotEmpty ? own.first : locations.isNotEmpty ? locations.first : 'Dispenser'),
          'no': m != null ? '${m['id']}' : jsS(x['no']).trim(),
          'qty': num0(x['qty']),
          'kmReading': num0(x['km']),
          'hrReading': num0(x['hr']),
          'driver': _str(x['driver']).trim(),
          'remark': _str(x['remark']).trim(),
        };
      }(),
  ];
}

/// The web's diProblems. [mine] (3.43.0, update-162): his own diesel sources (null = every place).
List<String> issueProblems(Map r, String today, List<String> locations, Iterable<Map<String, dynamic>> master, {List<String>? mine, Map<String, String>? fuels}) {
  final p = <String>[];
  final d = '${r['date']}';
  if (!_day.hasMatch(d)) {
    p.add('date');
  } else if (d.compareTo(today) > 0) {
    p.add('date after today');
  }
  if (!locations.contains(r['source'])) {
    p.add('Diesel Source');
  } else if (mine != null && !mine.contains(r['source'])) {
    p.add('Diesel Source – not your diesel source');
  }
  final m = findMachine(master, r['no']);
  if (m == null) {
    p.add('machinery not in Master');
  } else if (activeProblem(m, d).isNotEmpty) {
    p.add('machinery not active on that date');
  } else if (fuels != null && locations.contains(r['source'])) {
    final mf = _mFuel(m), pf = fuels['${r['source']}'] ?? 'Diesel';
    if (mf == 'Electric') {
      p.add('runs on Electric – no fuel');
    } else if (mf != pf) {
      p.add('runs on $mf – not at ${r['source']}');
    }
  }
  if (!_posNum(r['qty'])) p.add('qty');
  return p;
}

/// A row as it is sent: JSON has no NaN (JavaScript sends it as null).
Map<String, Object?> sendable(Map<String, Object?> r) => {
      for (final e in r.entries)
        if (!e.key.startsWith('_')) e.key: e.value is double && ((e.value as double).isNaN || (e.value as double).isInfinite) ? null : e.value,
    };

/* ---------------- the templates (the web's "Download template" files) ---------------- */

/// The sheet, the file name and the rows (the first row the headings).
({String sheet, String file, List<List<Object>> rows}) importTemplate(String kind, String today, List<String> locations, List<String> onSite) {
  final l0 = locations.isNotEmpty ? locations[0] : 'Dispenser', l1 = locations.length > 1 ? locations[1] : (kind == 'transfer' ? l0 : 'VTR Store');
  final day = showDate(today);
  switch (kind) {
    case 'inward':
      return (
        sheet: 'Diesel Inward',
        file: 'Diesel Inward – import template',
        rows: [
          ['Date', 'Received at', 'Pump Name', 'Qty (Ltr)', 'Rate (₹/Ltr)', 'Bill Number', 'Bill Date'],
          [day, l0, 'HP Petrol Pump', 2000, 92.5, 'B-101', day],
          [day, locations.length > 1 ? locations[1] : 'VTR Store', 'IOCL Vasai', 500, 93, 'B-102', ''],
        ],
      );
    case 'transfer':
      return (
        sheet: 'Diesel Transfer',
        file: 'Diesel Transfer – import template',
        rows: [
          ['Date', 'Shift', 'From', 'To', 'Qty (Ltr)', 'Remark'],
          [day, 'Day', l0, locations.length > 1 ? locations[1] : l0, 500, ''],
          [day, 'Night', l0, locations.length > 1 ? locations[1] : l0, 300, 'For night work'],
        ],
      );
    default:
      return (
        sheet: 'Diesel Issue',
        file: 'Diesel Issue – import template',
        rows: [
          ['Date', 'Shift', 'Diesel Source', 'Machinery Number / Name', 'Diesel Qty (Ltr)', 'KM Reading', 'Hrs Reading', 'Driver Name', 'Remark'],
          [day, 'Day', l0, onSite.isNotEmpty ? onSite[0] : 'MH-25-AJ-3232', 60, '', '', '', ''],
          [day, 'Night', locations.length > 1 ? l1 : l0, onSite.length > 1 ? onSite[1] : '400 KVA DG', 40, '', '', '', ''],
        ],
      );
  }
}

/* ---------------- the lists (all dates): the filter and the period words of the web ---------------- */

/// "16-10-2026 to 31-10-2026" / "till 16-10-2026" – the web's export period.
String exportPeriod(String from, String to, String today) =>
    from.isNotEmpty ? '${showDate(from)} to ${to.isNotEmpty ? showDate(to) : showDate(today)}' : 'till ${to.isNotEmpty ? showDate(to) : showDate(today)}';
