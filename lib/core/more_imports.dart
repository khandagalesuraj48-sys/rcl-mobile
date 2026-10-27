/* THE OTHER EXCEL IMPORTS AND THE QR LABELS (3.13.0) – the web's own working:
 *   – Asset Master "Import from Excel" (App.html m_file: the tab "Master" or the first; the columns by their names – IMP_MAP; a
 *     paper's N/A and Lifetime; dates) → importMaster (check, then save);
 *   – Vehicle Compliance "Import Excel" (cp_file: the tab "Compliance"; Machinery No and the paper columns) → importCompliance;
 *   – a water tanker's trips (Edit Log Book → tanker → Import Excel, lt_file: the Water Tanker Report layout, every tab; times) →
 *     checkTankerImport / importTankerTrips, and its Export (the web's file, with the Shift drop-down); (3.18.1, update-121) the
 *     file is of EVERY water tanker of every agency – VEHICLE NO picked from the list of tankers, the agency by itself – and
 *     each imported line goes to its own VEHICLE NO (none is filled in for it);
 *   – the Store's Item Master "Import from Excel" (rcl-store f_file: the cells as the sheet SHOWS them – raw: false);
 *   – the QR labels of the Asset Master (8 on an A4 page, update-150): the web's QR code (qrcode-generator 1.4.4, type auto, level M) of the app's link with
 *     the machinery, drawn as the web's SVG.
 * Proven against the web's code: test/fixtures/more/web_more.json, test/fixtures/qr/web_qr.json. */
import 'dart:convert';
import 'dart:math' as math;

import 'package:qr/qr.dart';

import 'imports.dart' show readExcelRows, xlDate, Cols, findMachine;
import 'lb_io.dart' show XSheet, XList, XFormula, lbTripsOf, localeCmp;
import 'log_edit.dart' show wtSpan;
import 'print_css.dart' show kPrintCss, kOrientP;
import 'sheet_read.dart';

/* ---------------- Asset Master ---------------- */
const kMasterImpMap = {
  'machinerynumber': 'no', 'machineryname': 'name', 'typeofmachinery': 'type', 'make': 'make', 'unit': 'unit', 'workson': 'worksOn', //
  'standardaveragekmltr': 'kmStd', 'standardaverageltrhr': 'hrStd', 'ownername': 'owner', 'ownership': 'ownership',
  'dieselsupply': 'supply', 'status': 'status', 'activefrom': 'activeFrom', 'inactivefrom': 'inactiveFrom',
  'ownernamevendor': 'owner', 'vendor': 'owner', 'vendorname': 'owner',
  'enginenumber': 'engineNo', 'engineno': 'engineNo', 'chassisnumber': 'chassisNo', 'chassisno': 'chassisNo', 'enginemake': 'engineMake',
  'fuel': 'fuel', 'fueltype': 'fuel', // (3.44.0, update-163) Diesel / Petrol / CNG / Electric
  'taxvalidupto': 'taxUpto', 'pucvalidupto': 'pucUpto', 'permitvalidupto': 'permitUpto', 'fitnessvalidupto': 'fitnessUpto', 'insurancevalidupto': 'insuranceUpto',
};
String _hdrKey(Object? c) => (jsTrue(c) ? jsS(c) : '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
final _na = RegExp(r'^\s*(na|n\/a|not applicable)\s*$', caseSensitive: false);
final _life = RegExp(r'^\s*(life ?time|ltt|life ?time tax( paid)?|lifetime tax paid|one ?time tax( paid)?|ott)\s*$', caseSensitive: false);

/// The rows of an Asset Master file, every row under the headings (the server checks them).
List<Map<String, Object?>> masterImportRows(List<SheetTab> tabs) {
  if (tabs.isEmpty) throw SheetError('The file needs a "Machinery Number" or "Machinery Name" column. Use Export to get the right format.');
  final tab = tabs.where((t) => t.name.trim().toLowerCase() == 'master').firstOrNull ?? tabs.first;
  final grid = tab.rows;
  final hi = grid.indexWhere((r) => r.any((c) => kMasterImpMap[_hdrKey(c)] == 'no' || kMasterImpMap[_hdrKey(c)] == 'name'));
  if (hi == -1) throw SheetError('The file needs a "Machinery Number" or "Machinery Name" column. Use Export to get the right format.');
  final cols = [for (final c in grid[hi]) kMasterImpMap[_hdrKey(c)]];
  return [
    for (final (k, r) in grid.sublist(hi + 1).indexed)
      () {
        final o = <String, Object?>{'line': hi + k + 2};
        for (final (ci, f) in cols.indexed) {
          if (f == null) continue;
          final v = ci < r.length ? r[ci] : null;
          final upto = f.endsWith('Upto');
          o[f] = upto && _na.hasMatch(jsS(v))
              ? 'NA'
              : upto && _life.hasMatch(jsS(v))
                  ? 'LIFETIME'
                  : RegExp(r'From$|Upto$').hasMatch(f)
                      ? xlDate(v)
                      : v is num
                          ? v
                          : (v == null ? '' : jsS(v)).trim();
        }
        return o;
      }(),
  ];
}

/* ---------------- Vehicle Compliance ---------------- */
const kPapers = ['Tax', 'PUC', 'Permit', 'Fitness', 'Insurance'];
final _noHead = RegExp(r'^(machinery no|machinery number|machinery|vehicle no|no)$');

List<Map<String, Object?>> complianceImportRows(List<SheetTab> tabs) {
  if (tabs.isEmpty) throw SheetError('The file needs a "Machinery No" column. Use Export Excel to get the right format.');
  final tab = tabs.where((t) => t.name.trim().toLowerCase() == 'compliance').firstOrNull ?? tabs.first;
  final grid = tab.rows;
  String key(Object? c) => jsS(c).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final hi = grid.indexWhere((r) => r.any((c) => _noHead.hasMatch(key(c))));
  if (hi == -1) throw SheetError('The file needs a "Machinery No" column. Use Export Excel to get the right format.');
  final head = [for (final c in grid[hi]) key(c)], noCol = head.indexWhere(_noHead.hasMatch);
  final docCols = <String, int>{};
  for (final dn in kPapers) {
    final l = dn.toLowerCase();
    final i = head.indexWhere((h) => h == l || h == '$l valid upto' || h.startsWith(l));
    if (i > -1) docCols[dn] = i;
  }
  if (docCols.isEmpty) throw SheetError('No paper columns (Tax, PUC, Permit, Fitness, Insurance) in the file.');
  final out = <Map<String, Object?>>[];
  for (final (k, r) in grid.sublist(hi + 1).indexed) {
    final no = (jsTrue(r[noCol]) ? jsS(r[noCol]) : '').trim();
    final docs = <String, Object?>{}, raw = <String, Object?>{};
    for (final e in docCols.entries) {
      final v = r[e.value];
      final t = (v == null ? '' : jsS(v)).trim();
      raw[e.key] = v is num ? '' : t;
      docs[e.key] = t.isEmpty
          ? ''
          : RegExp(r'^(na|n\/a|not applicable)$', caseSensitive: false).hasMatch(t)
              ? 'NA'
              : RegExp(r'^(life ?time|ltt|life ?time tax( paid)?|lifetime tax paid|one ?time tax( paid)?|ott)$', caseSensitive: false).hasMatch(t)
                  ? 'LIFETIME'
                  : RegExp(r'^not needed$', caseSensitive: false).hasMatch(t)
                      ? 'NOT NEEDED'
                      : xlDate(v);
    }
    if (no.isEmpty && !docs.values.any(jsTrue)) continue;
    out.add({'line': hi + k + 2, 'no': no, 'docs': docs, 'raw': raw});
  }
  return out;
}

/* ---------------- a water tanker's trips ---------------- */
final Cols kTankerCols = [
  ('date', RegExp(r'^date$')),
  ('shift', RegExp(r'^shift$')),
  ('no', RegExp(r'^(vehicle no|vehicle|vehicle number|tanker|tanker no|machinery|machinery no)$')),
  ('c', RegExp(r'^(challan no|challan|challan number)$')),
  ('a', RegExp(r'^(dispatch time|dispatch)$')),
  ('b', RegExp(r'^(unload time|unload|unloading time)$')),
  ('ch', RegExp(r'^(chainage no|chainage|chainage no\.)$')),
  ('u', RegExp(r'^(use for|use|used for)$')),
];
const kTankerHead = ['SR. NO.', 'DATE', 'SHIFT', 'NAME OF AGENCY', 'VEHICLE NO', 'CHALLAN NO', 'DISPATCH TIME', 'UNLOAD TIME', 'TRIP', 'CHAINAGE NO', 'USE FOR'];

String _tm(Object? v) {
  if (v == '' || v == null) return '';
  if (v is num) {
    final t = (((v % 1) * 1440) + 0.5).floor() % 1440;
    return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
  }
  return jsS(v).trim();
}

/// The trips of a file (every tab). (3.18.1, update-121) Each line keeps its own VEHICLE NO – a line without one is not given to
/// the tanker open on the screen ([tankerNoVehicle] says which).
List<Map<String, Object?>> tankerImportRows(List<SheetTab> tabs) {
  final raw = readExcelRows(tabs, kTankerCols, const ['date', 'c'], allSheets: true);
  String s(Object? v) => (jsTrue(v) ? jsS(v) : '').trim();
  final rows = [
    for (final x in raw)
      if (jsS(x['c']).trim().isNotEmpty || jsS(x['a']).trim().isNotEmpty || jsS(x['b']).trim().isNotEmpty)
        <String, Object?>{
          'line': x['line'],
          'no': s(x['no']),
          'date': xlDate(x['date']),
          'shift': RegExp(r'^n', caseSensitive: false).hasMatch(jsTrue(x['shift']) ? jsS(x['shift']) : '') ? 'Night' : 'Day',
          'c': s(x['c']),
          'a': _tm(x['a']),
          'b': _tm(x['b']),
          'ch': s(x['ch']),
          'u': s(x['u']),
        },
  ];
  if (rows.isEmpty) throw SheetError('No trips in the file.');
  return rows;
}

/// (3.18.1) The web's "Fix the file first" for the lines without their VEHICLE NO (the first 50) – empty when every line has one.
List<String> tankerNoVehicle(List<Map<String, Object?>> rows) =>
    [for (final x in rows) if (jsS(x['no']).isEmpty) 'Line ${jsS(x['line'])}: pick the VEHICLE NO – the water tanker of this trip.'].take(50).toList();

/// The web's Export Excel of the water tankers (update-121): the trips of EVERY water tanker (Log Book Format I) of every agency in
/// the dates – [rows]: getLogBookList's rows for them – in the order date, shift, agency, vehicle, dispatch time; 100 empty lines
/// whose VEHICLE NO is picked from the list of tankers (the hidden tab "Lists") and whose NAME OF AGENCY comes by itself (a formula);
/// the Shift drop-down on every line.
({String file, List<XSheet> sheets, String said}) tankerExport({required List<Map<String, dynamic>> master, required List<Map> rows, required String from, required String to, required String company, required String site}) {
  String sd(String d) {
    final p = d.split('-');
    return p.length >= 3 ? '${p[2]}-${p[1]}-${p[0]}' : d;
  }

  String s(Object? v) => jsTrue(v) ? jsS(v) : '';
  // (JavaScript's sort keeps the order of equals: so does this, by the place in the list)
  List<T> stable<T>(List<T> l, int Function(T, T) cmp) {
    final ix = [for (var i = 0; i < l.length; i++) i]..sort((a, b) {
        final c = cmp(l[a], l[b]);
        return c != 0 ? c : a - b;
      });
    return [for (final i in ix) l[i]];
  }

  final tks = stable([for (final m in master) if (m['lbFormat'] == 'I') m], (a, b) {
    final c = localeCmp(s(a['owner']), s(b['owner']));
    return c != 0 ? c : localeCmp(jsS(a['id']), jsS(b['id']), numeric: true);
  });
  const ord = {'Full Day': 0, 'Day': 1, 'Night': 2};
  final all = <Map<String, String>>[];
  for (final r in rows) {
    final m = findMachine(master, r['no']);
    final ts = m != null && m['lbFormat'] == 'I' ? lbTripsOf(r, master) : null;
    if (ts == null) continue;
    for (final t in ts) {
      all.add({'date': jsS(r['date']), 'shift': jsTrue(r['shift']) ? jsS(r['shift']) : 'Full Day', 'no': jsS(m!['id']), 'owner': s(m['owner']), ...t});
    }
  }
  num at(Map<String, String> t) => wtSpan(t['a'] ?? '', t['b'] ?? '', t['shift'] ?? '')?.first ?? 1e9;
  final trips = stable(all, (x, y) {
    final d = x['date']!.compareTo(y['date']!);
    if (d != 0) return d < 0 ? -1 : 1;
    final o = (ord[x['shift']] ?? 0) - (ord[y['shift']] ?? 0);
    if (o != 0) return o;
    final a = localeCmp(x['owner']!, y['owner']!);
    if (a != 0) return a;
    final n = localeCmp(x['no']!, y['no']!, numeric: true);
    if (n != 0) return n;
    return (at(x) - at(y)).sign.toInt();
  });
  final head = <List<Object>>[[company], [site], ['WATER TANKER REPORT – all water tankers – ${sd(from)} to ${sd(to)}'], []];
  final body = <List<Object>>[
    kTankerHead,
    for (final (i, t) in trips.indexed) [i + 1, sd(t['date']!), t['shift']!, t['owner']!, t['no']!, t['c'] ?? '', t['a'] ?? '', t['b'] ?? '', 1, t['ch'] ?? '', t['u'] ?? ''],
  ];
  final last = tks.length > 1 ? tks.length : 1;
  for (var k = 0; k < 100; k++) {
    final n = head.length + body.length + 1; // an empty line to fill: its agency follows the VEHICLE NO picked
    body.add(['', '', '', XFormula('IF(E$n="","",IFERROR(VLOOKUP(E$n,Lists!\$A\$1:\$B\$$last,2,FALSE),""))')]);
  }
  final sh = XSheet('Trips', [...head, ...body], widths: const [8, 12, 10, 24, 16, 16, 13, 13, 7, 14, 22], head: head.length + 1);
  const shift = XList('"Day,Night"', 'Shift', 'Day or Night', 'Pick one of: Day, Night');
  final vehicle = XList('Lists!\$A\$1:\$A\$$last', 'Vehicle No', 'Pick the water tanker – its agency comes by itself.', 'Pick from the list.');
  for (final (col, xl) in [(3, shift), (5, vehicle)]) {
    for (var r = sh.head + 1; r <= sh.aoa.length; r++) {
      final row = sh.aoa[r - 1];
      if (row.isEmpty) continue;
      final cell = row.length >= col ? row[col - 1] : '';
      sh.validations.add((r, col, xl, cell == ''));
    }
  }
  final lists = XSheet('Lists', [for (final m in tks) <Object>[jsS(m['id']), s(m['owner'])]], hidden: true);
  final nt = {for (final t in trips) t['no']}.length;
  return (
    file: 'Water tankers ${sd(from)} to ${sd(to)}.xlsx',
    sheets: [sh, lists],
    said: '${trips.length} trip${trips.length == 1 ? '' : 's'} of $nt water tanker${nt == 1 ? '' : 's'} and 100 empty lines. Pick the VEHICLE NO of a line (its agency comes by itself), fill the date, shift, challan, dispatch, unload… and bring the file back with "Import Excel".',
  );
}

/* ---------------- the Store's items ---------------- */

/// The rows of an item file (the first tab; the cells as the sheet shows them).
List<Map<String, Object?>> storeImportRows(List<SheetTab> textTabs) {
  final aoa = textTabs.isEmpty ? const <List<Object?>>[] : textTabs.first.rows;
  final nameRe = RegExp(r'item\s*name|^name$', caseSensitive: false);
  final hi = aoa.indexWhere((r) => r.any((c) => nameRe.hasMatch(jsS(c).trim())));
  if (hi < 0) throw SheetError('The file has no "Item Name" heading – use the Import template (or an exported file).');
  final h = [for (final c in aoa[hi]) jsS(c).trim().toLowerCase()];
  int col(RegExp re) => h.indexWhere(re.hasMatch);
  final c = {'name': col(RegExp(r'item\s*name|^name$')), 'unit': col(RegExp(r'^unit')), 'category': col(RegExp(r'^categ')), 'hsn': col(RegExp('hsn')), 'gst': col(RegExp('gst')), 'minStock': col(RegExp('min'))};
  if (c['unit']! < 0 || c['category']! < 0) throw SheetError('The file needs the headings Item Name, Unit and Category.');
  final rows = <Map<String, Object?>>[];
  for (final (k, r) in aoa.sublist(hi + 1).indexed) {
    String g(int i) => i < 0 || i >= r.length ? '' : (r[i] == null ? '' : jsS(r[i])).trim();
    final x = <String, Object?>{'line': hi + k + 2, 'name': g(c['name']!), 'unit': g(c['unit']!), 'category': g(c['category']!), 'hsn': g(c['hsn']!), 'gst': g(c['gst']!), 'minStock': g(c['minStock']!)};
    if ('${x['name']}'.isNotEmpty || '${x['unit']}'.isNotEmpty || '${x['category']}'.isNotEmpty) rows.add(x);
  }
  if (rows.isEmpty) throw SheetError('The file has no item rows.');
  return rows;
}

/* ---------------- the QR labels ---------------- */

/// JavaScript's encodeURIComponent (it leaves A–Z a–z 0–9 - _ . ! ~ * ' ( ) as they are).
String jsEncodeUriComponent(String s) {
  final keep = RegExp(r"[A-Za-z0-9\-_.!~*'()]");
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    if (keep.hasMatch(ch)) {
      b.write(ch);
    } else {
      for (final x in utf8.encode(ch)) {
        b.write('%${x.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
  }
  return b.toString();
}

/// The link on a machinery's label: the Mechanical page with the machinery (…/?m=MH-25-AJ-8511) – as the web's qrLink.
String qrLink(String mechUrl, String id) => '${mechUrl.endsWith('/') ? mechUrl : '$mechUrl/'}?m=${jsEncodeUriComponent(id)}';

/// The web's qrSvg: qrcode(0, 'M') of [text] → createSvgTag({cellSize: 4, margin: 2, scalable: true}).
String qrSvg(String text) {
  final img = QrImage(QrCode.fromData(data: text, errorCorrectLevel: QrErrorCorrectLevel.M));
  const t = 4, r = 2;
  final n = img.moduleCount, g = n * t + 2 * r;
  final b = StringBuffer('<svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $g $g"  preserveAspectRatio="xMinYMin meet">'
      '<rect width="100%" height="100%" fill="white" cx="0" cy="0"/><path d="');
  for (var row = 0; row < n; row++) {
    final y = row * t + r;
    for (var c = 0; c < n; c++) {
      if (img.isDark(row, c)) b.write('M${c * t + r},${y}l$t,0 0,$t -$t,0 0,-${t}z ');
    }
  }
  b.write('" stroke="transparent" fill="black"/></svg>');
  return b.toString();
}

/// (3.31.8, Mechanical update-150) labels on one A4 page: 2 × 4.
const kQrPerPage = 8;

/// The line under the number: name · type, each once (the web's qrSub).
String qrSub(Map m) {
  final parts = [jsTrue(m['name']) && m['name'] != m['id'] ? '${m['name']}' : '', '${m['type'] ?? ''}'];
  final out = <String>[];
  for (final (i, x) in parts.indexed) {
    if (x.isEmpty) continue;
    if (parts.indexWhere((y) => y.toLowerCase() == x.toLowerCase()) != i) continue;
    out.add(x);
  }
  return out.join(' · ');
}

/// The A4 sheets of labels, 8 a page (2 × 4): the web's qrLabelsHtml (update-150) – the code on the left; the customer, the
/// number, name · type on its right; "Scan: …" under them.
String qrLabelsHtml(List<Map<String, dynamic>> list, String mechUrl, String customer) {
  String e(Object? v) => '${v ?? ''}'.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
  const css = '<style>.qrs{display:grid;grid-template-columns:1fr 1fr;grid-auto-rows:62mm;gap:5mm;break-after:page;page-break-after:always}.qrs:last-child{break-after:auto;page-break-after:auto}'
      '.qrl{border:1.4px solid #222;border-radius:3mm;padding:3mm;box-sizing:border-box;display:flex;flex-direction:column;justify-content:center;overflow:hidden;break-inside:avoid;page-break-inside:avoid}'
      '.qrl .qrw{display:flex;align-items:center;gap:3mm}.qrl svg{width:50mm;height:50mm;flex:none;display:block}.qrl .qrt{flex:1;min-width:0;text-align:left}'
      '.qrl b{display:block;font:800 14pt Arial,sans-serif;letter-spacing:.02em;word-break:break-word;line-height:1.15}.qrl span{display:block;font:9.5pt Arial,sans-serif;color:#333;margin-top:1.2mm;word-break:break-word}'
      '.qrl i{display:block;font:italic 8pt Arial,sans-serif;color:#555;margin-top:1.5mm;text-align:center}.qrl u{display:block;text-decoration:none;font:700 7pt Arial,sans-serif;letter-spacing:.12em;text-transform:uppercase;color:#777;margin-bottom:1.5mm;word-break:break-word}</style>';
  final pages = [for (var i = 0; i < list.length; i += kQrPerPage) list.sublist(i, i + kQrPerPage > list.length ? list.length : i + kQrPerPage)];
  return css +
      pages
          .map((pg) => '<div class="qrs">${pg.map((m) => '<div class="qrl"><div class="qrw">${qrSvg(qrLink(mechUrl, '${m['id']}'))}<div class="qrt"><u>${e(customer)}</u><b>${e(m['id'])}</b><span>${e(qrSub(m))}</span></div></div><i>Scan: diesel issue · Log Book entry</i></div>').join()}</div>')
          .join();
}

/// The page to print the labels on (A4 portrait, the customer at the foot of each page) – as the web's printDoc(…, 'qr-labels').
String qrPrintHtml(String title, String inner, String customer) {
  String e(String v) => v.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
  final name = RegExp('sketchline', caseSensitive: false).hasMatch(customer) ? customer.toUpperCase() : customer;
  final foot = customer.isEmpty ? '' : '@page { @bottom-left { content: "${name.replaceAll(RegExp(r'["\\]'), '')}  |  Fleet ERP"; } }';
  return '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${e(title)}</title>'
      '<style>$kPrintCss$foot</style><style id="orient">$kOrientP</style></head><body class="qr-labels"><div class="sheet">$inner</div></body></html>';
}

/* ---------------- a cell as the sheet shows it (SheetJS "General", for raw: false) ---------------- */

String _strip(String o) => !o.contains('.') ? o : o.replaceFirstMapped(RegExp(r'(?:\.0*|(\.\d*[1-9])0+)$'), (m) => m[1] ?? '');
String _normExp(String o) {
  if (!o.contains('E')) return o;
  return o.replaceFirstMapped(RegExp(r'(?:\.0*|(\.\d*[1-9])0+)[Ee]'), (m) => '${m[1] ?? ''}E').replaceFirstMapped(RegExp(r'(E[+-])(\d)$'), (m) => '${m[1]}0${m[2]}');
}

String _jsExp(String s) => s.replaceFirstMapped(RegExp(r'e([+-]?)(\d+)$'), (m) => 'e${m[1]!.isEmpty ? '+' : m[1]}${m[2]}');

/// SheetJS SSF_general for a number.
String generalText(num v) {
  final d = v.toDouble();
  if (d == d.truncateToDouble() && d.abs() <= 2147483647 && d >= -2147483648) return d.toInt().toString();
  final big = (math.log(d.abs()) * math.log10e).floor();
  String o;
  if (big >= -4 && big <= -1) {
    o = d.toStringAsPrecision(10 + big);
  } else if (big.abs() <= 9) {
    final w = d < 0 ? 12 : 11;
    o = _strip(d.toStringAsFixed(12));
    if (o.length > w) {
      o = d.toStringAsPrecision(10);
      if (o.length > w) o = _jsExp(d.toStringAsExponential(5));
    }
  } else if (big == 10) {
    final f = d.toStringAsFixed(10);
    o = f.length > 12 ? f.substring(0, 12) : f;
  } else {
    final f = _strip(d.toStringAsFixed(11));
    o = (f.length > (d < 0 ? 12 : 11) || f == '0' || f == '-0') ? _jsExp(d.toStringAsPrecision(6)) : f;
  }
  return _strip(_normExp(o.toUpperCase()));
}

/// The tabs of an .xlsx with every cell as text (sheet_to_json raw: false): a number in General, TRUE / FALSE.
List<SheetTab> asShown(List<SheetTab> tabs) => [
      for (final t in tabs)
        SheetTab(t.name, [
          for (final r in t.rows)
            [for (final v in r) v is num ? (v.isNaN ? '' : generalText(v)) : v is bool ? (v ? 'TRUE' : 'FALSE') : (v ?? '')],
        ]),
    ];
