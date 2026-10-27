/* (3.53.0, Mechanical update-173: "jewde active aahet own rachana vehicle te mala import karaych aahe as it is jas asel tr") THE OLD
 * MAINTENANCE LOG BOOK, READ AS THE WEB READS IT (App.html mliSheet): his Excel "All Machinery Maintenance Logbook" – a sheet a
 * machinery, its name above the heading (ROLLER NO-03), the heading Sr No · Date · Party Name · Current Reading · Particulars · Qty ·
 * Uom · Basic Rate · Amount · GST Amount · Amount With GST · Total.
 *   – its machinery found among the Own ones on the site today by that name, or the sheet's (ROLLER NO-03 = ROLLER-03 = Roller No.03);
 *   – a bill = the rows one under another of one date and party (a reading only on its first row is the bill's; a date left empty – a
 *     merged cell – is the row's above); each line as it is: Qty, Uom, Rate, Amount and its GST % from its GST Amount (18 % when 18 % of
 *     the amount makes it to ₹1 – an old file shows whole rupees); a ₹0 line stays ₹0 (the server keeps it as FOC).
 * The server checks and imports (checkMaintImport / importMaint – one machinery a call, a bill already there left out). Proven against
 * the web's own code: test/fixtures/sheets/maint_logbook.{xlsx,json}. */
import 'imports.dart' show xlDate, onSiteOn;
import 'rdoc.dart' show r2;
import 'sheet_read.dart';

const _cols = <(String, String)>[
  ('date', r'^date$'),
  ('party', r'^(party name|party|garage|supplier name|supplier)$'),
  ('km', r'^(current reading|reading|km reading|hrs reading)$'),
  ('work', r'^(particulars|particular|work \/ part|material description|description)$'),
  ('qty', r'^(qty|quantity)$'),
  ('uom', r'^(uom|unit)$'),
  ('rate', r'^(basic rate|rate)$'),
  ('amount', r'^(amount|basic amount|taxable amount)$'),
  ('gstAmt', r'^(gst amount|gst)$'),
  ('withGst', r'^(amount with gst|gross amount)$'),
  ('total', r'^total$'),
];

String _sp(Object? v) => jsS(v).replaceAll(RegExp(r'\s+'), ' ').trim();
String mliNorm(Object? h) => jsS(h).replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase().replaceFirst(RegExp(r'[.:*\s]+$'), '');

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

/// The Own machinery on the site today – the ones an old log book is imported for
List<Map<String, dynamic>> mliOwn(List<Map<String, dynamic>> master, String today) => [for (final m in master) if (m['ownership'] == 'Own' && onSiteOn(m, today)) m];

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
  MliSheet({required this.sheet, required this.label, required this.no, required this.bills, required this.rows, required this.fileTotal, required this.total, required this.bad});
  final String sheet, label;
  String no;
  final List<Map<String, dynamic>> bills;
  final int rows;
  final num fileTotal, total;
  final List<String> bad;
  Map<String, dynamic>? res, done;
  String err = '';
  bool twice = false;
  Map<String, dynamic> toJson() => {'sheet': sheet, 'label': label, 'no': no, 'bills': bills, 'rows': rows, 'fileTotal': fileTotal, 'total': total, 'bad': bad};
}

MliSheet? mliSheet(String name, List<List<Object?>> all, List<Map<String, dynamic>> own) {
  final hi = all.indexWhere((r) {
    final n = r.map(mliNorm).toList();
    return n.any((h) => RegExp(r'^(particulars|particular)$').hasMatch(h)) && n.any((h) => RegExp(r'^(amount|basic rate)$').hasMatch(h));
  });
  if (hi == -1) return null;
  final idx = <String, int>{};
  for (final (k, h) in all[hi].map(mliNorm).indexed) {
    for (final c in _cols) {
      if (!idx.containsKey(c.$1) && RegExp(c.$2).hasMatch(h)) idx[c.$1] = k;
    }
  }
  var label = '';
  for (final r in all.take(hi)) {
    for (final v in r) {
      final t = _sp(v);
      if (t.isNotEmpty && !RegExp(r'rachana|log\s*book|limited|maint[ae]n', caseSensitive: false).hasMatch(t)) label = t;
    }
  }
  final bills = <Map<String, dynamic>>[], bad = <String>[];
  Map<String, dynamic>? cur;
  var last = <String, Object>{'date': '', 'party': '', 'km': ''};
  num ftotal = 0;
  var nrows = 0;
  final from = <Map<String, dynamic>, (int, int)>{};
  for (final (k, r) in all.skip(hi + 1).indexed) {
    Object? g(String f) => idx[f] == null || idx[f]! >= r.length ? '' : r[idx[f]!];
    final work = _sp(g('work')), line = hi + k + 2;
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
  return MliSheet(sheet: name, label: label, no: mliMatch(label, name, own), bills: out, rows: nrows, fileTotal: r2(ftotal), total: r2(total), bad: bad);
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
