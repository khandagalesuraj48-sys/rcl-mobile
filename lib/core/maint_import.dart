/* (3.53.0, Mechanical update-173: "jewde active aahet own rachana vehicle te mala import karaych aahe as it is jas asel tr") THE OLD
 * MAINTENANCE LOG BOOK, READ AS THE WEB READS IT (App.html mliSheet): his Excel "All Machinery Maintenance Logbook" – a sheet a
 * machinery, its name above the heading (ROLLER NO-03), the heading Sr No · Date · Party Name · Current Reading · Particulars · Qty ·
 * Uom · Basic Rate · Amount · GST Amount · Amount With GST · Total.
 *   – its machinery found among the Own ones on the site today by that name, or the sheet's (ROLLER NO-03 = ROLLER-03 = Roller No.03);
 *   – a bill = the rows one under another of one date and party (a reading only on its first row is the bill's; a date left empty – a
 *     merged cell – is the row's above); each line as it is: Qty, Uom, Rate, Amount and its GST % from its GST Amount (18 % when 18 % of
 *     the amount makes it to ₹1 – an old file shows whole rupees); a ₹0 line stays ₹0 (the server keeps it as FOC).
 * The server checks and imports (checkMaintImport / importMaint – one machinery a call, a bill already there left out). Proven against
 * the web's own code: test/fixtures/sheets/maint_logbook.{xlsx,json}.
 * (28-10-2026, his answers: "PDF import – Claude AI वाचेल", "यादी दाखव, मी पाहून ✓ करेन") also: the lines that do not add up (warn – to
 * look at, imported as they are); a PDF / photo read by the AI (readMaintLog – its tables as sheets, "Line n" = its n-th row); the
 * names written in more than one way (maintImportNames – the Admin ticks; mliBills sends the ticked names). */
import 'dart:typed_data';

import 'imports.dart' show xlDate;
import 'lb_io.dart' show XSheet;
import 'rdoc.dart' show r2;
import 'sheet_read.dart';
import 'xlsx.dart' show sheetsXlsx;

String _sp(Object? v) => jsS(v).replaceAll(RegExp(r'\s+'), ' ').trim();

/* (3.56.0, Mechanical update-180, asked 28-10-2026: "kahi pdf madhe heading maghe pudhe aahet tr aple systeam ni auto identify krun te
 * sagla banwayla haw") THE HEADINGS IN ANY ORDER, NAMED IN MANY WAYS – each column found by the words of its heading (Bill Date,
 * Supplier, KM, Item Description, Taxable Value, CGST 9%, SGST 9%, Net Amount …), not by its place; a bill number, a remark, a
 * discount, an HSN code left out. The web's mliField / mliRows (and the server's maintLogField_ / maintLogRows_, a PDF read by the AI)
 * rule for rule – the tests run the same headings through both. */

/// what a heading is: (f: sr · date · party · reading · work · qty · uom · rate · amount · gstAmt · gstPct · withGst · total, or '-' =
/// left out; p: the part of a GST – c (CGST), s (SGST / UTGST), i (IGST) or ''); null = not known
({String f, String p})? mliField(Object? h) {
  final s = jsS(h ?? '')
      .toLowerCase()
      .replaceAll('₹', ' ')
      .replaceAll(RegExp(r'[^a-z0-9%+]+'), ' ')
      .replaceAll(RegExp(r'\b(rs|inr)\b'), ' ')
      .replaceAllMapped(RegExp(r'\b([a-z]) (?=[a-z]\b)'), (x) => x[1]!)      // ("C.G.S.T" = cgst, "U.O.M" = uom)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (s.isEmpty) return null;
  bool m(String re) => RegExp(re).hasMatch(s);
  ({String f, String p}) a(String f, [String p = '']) => (f: f, p: p);
  if (m(r'\b(bill|invoice|inv|challan|voucher|job ?card|order|grn|ref|receipt|part|item)\b') && m(r'\b(no|nos|number|num|code)\b')) return a('-');
  if (m(r'\b(remarks?|notes?|comments?|narration|sign|signature|discount|disc|hsn|sac)\b')) return a('-');
  final part = m(r'\bcgst\b') ? 'c' : m(r'\b(sgst|utgst)\b') ? 's' : m(r'\bigst\b') ? 'i' : '';
  if (m(r'\b(c|s|i|ut)?gst\b|\btax\b|\bvat\b')) {
    if (m(r'\b(with|incl|including|inclusive|after|plus)\b( of)?( the)? (gst|tax|vat)\b|\+ ?(gst|tax|vat)\b|\b(gst|tax|vat) (incl|included|inclusive)\b')) return a('withGst');
    if (m(r'%|\bpercent|\brate\b') && !m(r'\d ?%')) return a('gstPct', part);      // ("GST %", "CGST Rate" – a rate; "CGST 9%" – its ₹)
    return a('gstAmt', part);
  }
  if (m(r'\bgross\b|\bnet (amount|amt|value|total|payable)\b|^net$|\b(bill|invoice) (amount|amt|value)\b|\btotal (amount|amt|value)\b|\bpayable\b|\bfinal (amount|amt)\b')) return a('withGst');
  if (m(r'^sub ?total$')) return a('amount');
  if (m(r'^(grand |bill |net )?total$')) return a('total');
  if (m(r'\b(date|dt|dated)\b')) return a('date');
  if (m(r'^(sr|s|sl|ser|serial)( no| number)?$|^(sno|srno|slno|no)$')) return a('sr');
  if (m(r'reading|\b(km|kms|hmr|smr|hr|hrs|hours?|odometer|odo|meter)\b')) return a('reading');
  if (m(r'\b(rate|price|mrp)\b|\bper (unit|no|nos|pc|pcs|piece|ltr|litre|kg)\b|\bunit cost\b')) return a('rate');
  if (m(r'\b(qty|qnty|qnt|qtty|quantity|quantities)\b|^(nos|pcs)$|\bno of (nos|pcs|units|items|pieces)\b')) return a('qty');
  if (m(r'\b(uom|units?)\b|\bmeasure')) return a('uom');
  if (m(r'\b(amount|amt|value|taxable|cost|charges?|basic)\b')) return a('amount');
  if (m(r'party|garage|supplier|vendor|dealer|workshop|\b(shop|mechanic|firm|agency|store|company|from|by|centre|center)\b')) return a('party');
  if (m(r'particular|descri|\bworks?\b|\bparts?\b|\bspares?\b|material|\bitems?\b|detail|repair|\bjobs?\b|nature|\bservices?\b|product|\bgoods\b')) return a('work');
  return null;
}

/// Every row under [head] in the log book's 12 columns (mliHead): the GST of its parts added (CGST + SGST, IGST); a GST % made ₹; a book
/// without an Amount column: its amount with GST less the GST (or Qty × Rate when it has no amount at all); every other cell as it is
List<List<Object?>> mliRows(List<Object?> head, List<List<Object?>> rows) {
  final fs = [for (final h in head) mliField(h)];
  List<int> cols(String f) => [for (final (k, x) in fs.indexed) if (x != null && x.f == f) k];
  if (cols('amount').isEmpty && cols('withGst').length > 1) fs[cols('withGst').first] = (f: 'amount', p: '');      // (Total Amount · GST · Net Amount)
  final am = cols('amount').isNotEmpty, wg = cols('withGst').isNotEmpty, ga = cols('gstAmt'), gp = cols('gstPct');
  bool has(Object? v) => !(v == null || jsS(v).trim().isEmpty || RegExp(r'^null$', caseSensitive: false).hasMatch(jsS(v).trim()));
  num? n(Object? v) {
    if (!has(v)) return null;
    if (v is num) return v.isFinite ? v : null;
    final t = jsS(v).replaceAll(RegExp(r'[,₹\s%]|rs\.?', caseSensitive: false), '');
    return RegExp(r'^[-+]?(\d+\.?\d*|\.\d+)$').hasMatch(t) ? num.tryParse(t) ?? double.tryParse(t) : null;
  }
  List<Object?> row(List<Object?> r) {
    Object? at(int k) => k < r.length ? r[k] : null;
    Object? one(String f) {
      for (final k in cols(f)) {
        if (has(at(k))) return at(k);
      }
      return '';
    }
    Object sum(List<int> ks) {
      num s = 0;
      var any = false;
      for (final k in ks) {
        final v = n(at(k));
        if (v != null) {
          s += v;
          any = true;
        }
      }
      return any ? r2(s) : '';
    }
    // the GST (₹ or %) of a row: its "GST" column; else its parts added; two columns of no part: added
    Object? tax(List<int> ks) {
      final p = [for (final k in ks) if (fs[k]!.p.isEmpty) k], q = [for (final k in ks) if (fs[k]!.p.isNotEmpty) k];
      if (q.isNotEmpty) {
        final v = p.isNotEmpty ? sum(p.take(1).toList()) : '';
        return v != '' ? v : sum(q);
      }
      return p.length > 1 ? sum(p) : p.isNotEmpty && has(at(p.first)) ? at(p.first) : '';
    }
    Object? amount = one('amount'), gst = tax(ga);
    final pct = n(tax(gp)), qty = one('qty'), rate = one('rate'), withGst = one('withGst');
    if (!am) {
      final w = n(withGst), g = n(gst);
      if (wg && w != null) {
        if (g != null) {
          amount = r2(w - g);
        } else if (pct != null && pct > 0) {
          final b = r2(w / (1 + pct / 100));
          amount = b;
          gst = r2(w - b);
        } else {
          amount = w;
        }
      } else if (!wg && n(qty) != null && n(rate) != null) {
        amount = r2(n(qty)! * n(rate)!);
      }
    }
    if (gst == '' && pct != null && pct > 0 && n(amount) != null) gst = r2(n(amount)! * pct / 100);
    return <Object?>[one('sr'), one('date'), one('party'), one('reading'), one('work'), qty, one('uom'), rate, amount, gst, withGst, one('total')];
  }
  return [for (final r in rows) row(r)];
}

/// a name as a key: capitals and digits only, "NO" before a number and the zeros before a number left out – ROLLER NO-03 = ROLLER-03
String mliKey(Object? v) => jsS(v ?? '')
    .toUpperCase()
    .replaceAll(RegExp(r'\bNO\b\.?\s*(?=[-\s.]*\d)'), '')
    .replaceAll(RegExp(r'[^A-Z0-9]'), '')
    .replaceAllMapped(RegExp(r'(^|\D)0+(?=\d)'), (m) => m[1]!);

/// a number of a cell ('' when empty or not a number) – the web's mliNum
Object mliNum(Object? v) {
  if (v == null || v == '') return '';
  if (v is num) return v.isFinite ? v : '';
  final n = num.tryParse(jsS(v).replaceAll(RegExp(r'[,₹\s]'), ''));
  return n != null && n.isFinite ? n : '';
}

num _n(Object v) => v is num ? v : 0;

/// a line's GST (CGST and SGST each rounded – the web's mtGst)
num mtGst(Object a, Object g) => 2 * r2(_n(a) * _n(g) / 200);

/// its GST % from its GST Amount: a usual rate when it makes it to ₹1, else the % itself
Object mliGst(Object a, Object g) {
  if (_n(a) == 0 || _n(g) == 0) return '';
  for (final r in const [5, 12, 18, 28]) {
    if ((mtGst(a, r) - _n(g)).abs() <= 1) return r;
  }
  return r2(_n(g) / _n(a) * 100);
}

/// The Own machinery – the ones an old log book is imported for (28-10-2026, Mechanical update-175: on the site now or not – "फक्त Own –
/// active असो वा नसो"; [today] kept for the screens' "(not on the site now)")
List<Map<String, dynamic>> mliOwn(List<Map<String, dynamic>> master, String today) => [for (final m in master) if (m['ownership'] == 'Own') m];

String mliMatch(String label, String sheet, List<Map<String, dynamic>> own) {
  for (final k in [label, sheet].map(mliKey).where((k) => k.isNotEmpty)) {
    for (final m in own) {
      if (mliKey(m['id']) == k || (jsS(m['name'] ?? '').isNotEmpty && mliKey(m['name']) == k)) return '${m['id']}';
    }
  }
  return '';
}

/// One sheet of the file as it will be sent
class MliSheet {
  MliSheet({required this.sheet, required this.label, required this.no, required this.bills, required this.rows, required this.fileTotal, required this.total, required this.bad, this.warn = const []});
  final String sheet, label;
  String no;
  final List<Map<String, dynamic>> bills;
  final int rows;
  final num fileTotal, total;
  final List<String> bad;
  /// (28-10-2026) the lines that do not add up: {line, work, k: 'qr' (Qty × Rate ≠ Amount) / 'ag' (Amount + GST ≠ With GST) / 'gp' (an odd GST %), a, b}
  final List<Map<String, Object>> warn;
  Map<String, dynamic>? res, done;
  String err = '';
  bool twice = false;
  Map<String, dynamic> toJson() => {'sheet': sheet, 'label': label, 'no': no, 'bills': bills, 'rows': rows, 'fileTotal': fileTotal, 'total': total, 'bad': bad, 'warn': warn};
}

/// The log book's heading – a PDF's rows read by the AI go under it, and the format (Excel) has it
const mliHead = ['Sr No', 'Date', 'Party Name', 'Current Reading', 'Particulars', 'Qty', 'Uom', 'Basic Rate', 'Amount', 'GST Amount', 'Amount With GST', 'Total'];

/// [ai]: rows read by the AI from a PDF / photo – "Line n" = its n-th row
MliSheet? mliSheet(String name, List<List<Object?>> all, List<Map<String, dynamic>> own, {bool ai = false}) {
  // (3.56.0, update-180) the heading row: the first with a Particulars column and an amount (or a rate) – by their words, in any order
  final hi = all.indexWhere((r) {
    final f = [for (final h in r) mliField(h)?.f];
    return f.contains('work') && ['amount', 'withGst', 'rate'].any(f.contains);
  });
  if (hi == -1) return null;
  const idx = <String, int>{'date': 1, 'party': 2, 'km': 3, 'work': 4, 'qty': 5, 'uom': 6, 'rate': 7, 'amount': 8, 'gstAmt': 9, 'withGst': 10, 'total': 11};
  final rows = mliRows(all[hi], all.skip(hi + 1).toList());
  var label = '';
  for (final r in all.take(hi)) {
    for (final v in r) {
      final t = _sp(v);
      if (t.isNotEmpty && !RegExp(r'rachana|log\s*book|limited|maint[ae]n', caseSensitive: false).hasMatch(t)) label = t;
    }
  }
  final bills = <Map<String, dynamic>>[], bad = <String>[], warn = <Map<String, Object>>[];
  Map<String, dynamic>? cur;
  var last = <String, Object>{'date': '', 'party': '', 'km': ''};
  num ftotal = 0;
  var nrows = 0;
  final from = <Map<String, dynamic>, (int, int)>{};
  for (final (k, r) in rows.indexed) {
    Object? g(String f) => r[idx[f]!] ?? '';
    final work = _sp(g('work')), line = ai ? k + 1 : hi + k + 2;
    if (work.isEmpty || (RegExp(r'^(grand )?total\b', caseSensitive: false).hasMatch(work) && jsS(g('date')).trim().isEmpty)) continue;      // an empty line, the total line
    var date = xlDate(g('date')), party = _sp(g('party'));
    Object km = mliNum(g('km'));
    if (date.isEmpty) {
      date = '${last['date']}';
      if (party.isEmpty) party = '${last['party']}';
      if (km == '') km = last['km']!;
    } else if (party.isEmpty && date == last['date']) {
      party = '${last['party']}';
    }
    final amount = mliNum(g('amount')), gstAmt = mliNum(g('gstAmt')), wt0 = mliNum(g('withGst')), wt = wt0 != '' ? wt0 : mliNum(g('total'));
    nrows++;
    ftotal += wt != '' ? _n(wt) : _n(amount) + _n(gstAmt);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) bad.add('Line $line: the date "${jsS(g('date'))}"');
    final l = <String, Object>{'work': work.length > 120 ? work.substring(0, 120) : work, 'qty': mliNum(g('qty')), 'uom': _cut(jsS(g('uom')).trim(), 12), 'rate': mliNum(g('rate')), 'amount': amount == '' ? 0 : amount, 'gst': mliGst(amount, gstAmt)};
    // (28-10-2026, "full scan … sagle kahi find krun") what does not add up – shown to look at; the line is imported as it is
    if (warn.length < 300) {
      final w = _cut(work, 40), q = l['qty']!, rt = l['rate']!, gp = l['gst']!;
      if (q is num && rt is num && amount is num && q > 0 && rt > 0 && (r2(q * rt) - amount).abs() > 1) warn.add({'line': line, 'work': w, 'k': 'qr', 'a': r2(q * rt), 'b': amount});
      if (amount is num && gstAmt is num && wt0 is num && (r2(amount + gstAmt) - wt0).abs() > 1) warn.add({'line': line, 'work': w, 'k': 'ag', 'a': r2(amount + gstAmt), 'b': wt0});
      if (gp is num && !const [5, 12, 18, 28].contains(gp)) warn.add({'line': line, 'work': w, 'k': 'gp', 'a': gp, 'b': ''});
    }
    final same = cur != null && cur['date'] == date && '${cur['garage']}'.toUpperCase() == party.toUpperCase() && (km == '' || cur['km'] == '' || _eq(cur['km'], km));
    if (!same) {
      cur = {'date': date, 'garage': party, 'km': km, 'lines': <Map<String, Object>>[]};
      bills.add(cur);
      from[cur] = (line, line);
    }
    final c = cur;
    if (c['km'] == '' && km != '') c['km'] = km;
    from[c] = (from[c]!.$1, line);
    (c['lines'] as List<Map<String, Object>>).add(l);
    last = {'date': date, 'party': party, 'km': km};
  }
  final out = [
    for (final b in bills) {'date': b['date'], 'garage': b['garage'], 'km': b['km'], 'lines': b['lines'], 'rows': 'Line ${from[b]!.$1}${from[b]!.$2 > from[b]!.$1 ? '–${from[b]!.$2}' : ''}'},
  ];
  num total = 0;
  for (final b in out) {
    for (final l in b['lines'] as List<Map<String, Object>>) {
      total += _n(l['amount']!) + mtGst(l['amount']!, l['gst']!);
    }
  }
  return MliSheet(sheet: name, label: label, no: mliMatch(label, name, own), bills: out, rows: nrows, fileTotal: r2(ftotal), total: r2(total), bad: bad, warn: warn);
}

bool _eq(Object? a, Object? b) => a is num && b is num ? a == b : a == b;
String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

/// Every sheet of the file that has the log book's heading and a bill (the web's mliRead)
List<MliSheet> mliRead(List<SheetTab> tabs, List<Map<String, dynamic>> master, String today) {
  final own = mliOwn(master, today), out = <MliSheet>[];
  for (final t in tabs) {
    final x = mliSheet(t.name, t.rows, own);
    if (x != null && x.bills.isNotEmpty) out.add(x);
  }
  return out;
}

/// (28-10-2026) The tables the AI read from a PDF / photo (readMaintLog, page after page) as sheets – the web's mliAiSheets: a table
/// without its machinery goes on with the one before; each machinery's rows under the log book's heading, read as a sheet.
List<MliSheet> mliAiSheets(String fileName, List<Map> tables, List<Map<String, dynamic>> master, String today) {
  final groups = <({String key, String name, List<List<Object?>> rows})>[];
  for (final t in tables) {
    final m = jsS(t['machinery'] ?? ''), rows = [for (final r in (t['rows'] as List? ?? const [])) if (r is List) List<Object?>.from(r)];
    final g = groups.isEmpty ? null : groups.last;
    if (g != null && (m.isEmpty || mliKey(m) == g.key)) {
      g.rows.addAll(rows);
    } else {
      groups.add((key: mliKey(m), name: m, rows: rows));
    }
  }
  final own = mliOwn(master, today), out = <MliSheet>[];
  for (final (i, g) in groups.where((g) => g.rows.isNotEmpty).indexed) {
    final x = mliSheet(g.name.isNotEmpty ? g.name : '$fileName${groups.length > 1 ? ' (${i + 1})' : ''}', [[g.name], mliHead, ...g.rows], own, ai: true);
    if (x != null && x.bills.isNotEmpty) out.add(x);
  }
  return out;
}

/// (28-10-2026, "यादी दाखव, मी पाहून ✓ करेन") a name the AI found written in more than one way – ticked by the Admin
class MliFix {
  MliFix(this.f, this.from, this.to, this.n);
  final String f, from;      // f: party / work / uom
  String to;
  final int n;
  bool on = false;
}

/// The names of the file – Party Name, Particulars, Uom – each with its rows (the web's mliNamesOf)
Map<String, Map<String, int>> mliNamesOf(List<MliSheet> sheets) {
  final o = <String, Map<String, int>>{'party': {}, 'work': {}, 'uom': {}};
  void add(String f, Object? v, int n) {
    final k = jsS(v ?? '');
    if (k.isNotEmpty) o[f]![k] = (o[f]![k] ?? 0) + n;
  }

  for (final x in sheets) {
    for (final b in x.bills) {
      final ls = (b['lines'] as List).cast<Map>();
      add('party', b['garage'], ls.length);
      for (final l in ls) {
        add('work', l['work'], 1);
        add('uom', l['uom'], 1);
      }
    }
  }
  return o;
}

/// The bills as they are sent: the ticked names (with a name) in place of the file's; the rest as in the file (the web's mliBills)
List<Map<String, dynamic>> mliBills(MliSheet x, List<MliFix> fixes) {
  final on = [for (final z in fixes) if (z.on && z.to.trim().isNotEmpty) z];
  if (on.isEmpty) return x.bills;
  final map = <String, Map<String, String>>{'party': {}, 'work': {}, 'uom': {}};
  for (final z in on) {
    map[z.f]?[z.from] = z.to.trim();
  }
  return [
    for (final b in x.bills)
      {
        ...b,
        'garage': map['party']![b['garage']] ?? b['garage'],
        'lines': [for (final l in (b['lines'] as List).cast<Map>()) {...l, 'work': map['work']![l['work']] ?? l['work'], 'uom': map['uom']![l['uom']] ?? l['uom']}],
      },
  ];
}

/// (28-10-2026, "Excel format (template) download") the format of the old log book – the web's mliFormat: how to fill it, then a sheet
/// for each Own machinery on the site today, its number in row 3 (the sheet is put to it by that), the heading ready
Uint8List mliFormatXlsx(List<Map<String, dynamic>> own, String company) => sheetsXlsx([
      XSheet('How to fill', const [
        ['Old Maintenance Log Book – how to fill'],
        [''],
        ['• One sheet = one machinery: its number is in row 3 – leave it. Delete the sheets of the machinery without an old log book.'],
        ['• A row for each work / part / material: Date, Party Name, Current Reading (KM / Hrs), Particulars, Qty, Uom, Basic Rate, Amount, GST Amount, Amount With GST.'],
        ['• A bill of several rows: its Date, Party Name and Current Reading on its first row (the rows under it, left empty, are the same bill).'],
        ['• Amount = before GST; GST Amount = its CGST + SGST in ₹; a free line: Amount 0.'],
        ['• Then: Maintenance → Import the old log book → choose this file → tick the names → Check → Import.'],
      ]),
      for (final m in own)
        XSheet('${m['id']}'.replaceAll(RegExp(r'[:\\/?*\[\]]'), '-'), [
          [company.isNotEmpty ? company : 'Rachana Construction Limited'],
          ['Maintenance Log Book${'${m['name'] ?? ''}'.isNotEmpty && m['name'] != m['id'] ? ' – ${m['name']}' : ''}'],
          ['${m['id']}'],
          mliHead,
        ], widths: const [6, 11, 24, 10, 34, 7, 7, 10, 11, 11, 13, 11], head: 4),
    ]);
