/* BILLS' REPORTS (3.8.0) – the web's own working of the Bill Summary (Report 2 Net Payable month-wise, Report 1 Detail), the
 * Vendor Ledger, the Vendor Outstanding, the payments' list and a new debit note's sums (App.html "BILL SUMMARY", "MACHINERY
 * PAYMENTS / VENDOR LEDGER / OUTSTANDING", "DEBIT NOTES"): every figure is the server's (billSummary, vendorLedger,
 * vendorOutstanding, getPayments); here it is only added up and laid out as the web does – for the screen, Print and Excel. */
import 'format.dart' show showDate;
import 'lb_print.dart' show fmt, n2;
import 'log_edit.dart' show r2;
import 'rdoc.dart' show RCell, RDoc, RKind, RNote, RRow, RTable;

num _n(Object? v) => v is num ? v : (num.tryParse('${v ?? ''}'.trim()) ?? 0);
String _s(Object? v) => v == null ? '' : '$v';
List<Map<String, dynamic>> maps(Object? l) => [for (final x in (l as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// '2026-09' → 'Sep 2026'
String brMonthName(String m) {
  final p = m.split('-');
  if (p.length < 2) return m;
  final i = int.tryParse(p[1]) ?? 0;
  return '${i >= 1 && i <= 12 ? _mon[i - 1] : p[1]} ${p[0]}';
}

String _mk(int y, int m) {
  while (m < 1) {
    m += 12;
    y--;
  }
  while (m > 12) {
    m -= 12;
    y++;
  }
  return '$y-${m.toString().padLeft(2, '0')}';
}

/// The months from [a] to [b] ('2026-08' … '2026-10'), at most 61.
List<String> brMonths(String a, String b) {
  final out = <String>[];
  if (a.length < 7 || b.length < 7) return out;
  var y = int.parse(a.substring(0, 4)), m = int.parse(a.substring(5, 7));
  final y2 = int.parse(b.substring(0, 4)), m2 = int.parse(b.substring(5, 7));
  while (y < y2 || (y == y2 && m <= m2)) {
    out.add('$y-${m.toString().padLeft(2, '0')}');
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
    if (out.length > 60) break;
  }
  return out;
}

/// This month / last month / the last 3 months / this financial year (April on) – as months.
(String, String) brRange(String k, String today) {
  final y = int.parse(today.substring(0, 4)), m = int.parse(today.substring(5, 7));
  if (k == 'this') return (_mk(y, m), _mk(y, m));
  if (k == 'last') return (_mk(y, m - 1), _mk(y, m - 1));
  if (k == '3') return (_mk(y, m - 2), _mk(y, m));
  final fy = m >= 4 ? y : y - 1;
  return ('$fy-04', _mk(y, m));
}

/// 1 April of this financial year.
String fyStart(String today) {
  final y = int.parse(today.substring(0, 4)), m = int.parse(today.substring(5, 7));
  return '${m >= 4 ? y : y - 1}-04-01';
}

/// The last day of a month '2026-02' → '2026-02-28'.
String monthEnd(String ym) {
  final d = DateTime(int.parse(ym.substring(0, 4)), int.parse(ym.substring(5, 7)) + 1, 0);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// A balance: positive = still to pay the vendor; negative = advance (the vendor owes).
String balTxt(Object? v) {
  final x = _n(v);
  return x.abs() < 0.005 ? '0.00' : x > 0 ? n2(x) : '${n2(-x)} Adv';
}

String brAmt(Object? x) => _n(x) != 0 ? n2(x) : '–';
String _less(Object? x) => _n(x) != 0 ? '− ${n2(x)}' : '–';

// ---------------------------------------------------------------------------------------------------------------------
//  BILL SUMMARY
// ---------------------------------------------------------------------------------------------------------------------
List<String> brVendors(List<Map<String, dynamic>> rows) {
  final out = <String>[];
  for (final r in rows) {
    final v = _s(r['vendor']);
    if (!out.contains(v)) out.add(v);
  }
  return out;
}

num _sum(List<Map<String, dynamic>> rows, bool Function(Map<String, dynamic>) f, [String k = 'net']) => rows.where(f).fold<num>(0, (a, r) => a + _n(r[k]));

String brSub(List<String> months, String company, String vendor) =>
    '${brMonthName(months.first)}${months.length > 1 ? ' to ${brMonthName(months.last)}' : ''}${company.isNotEmpty ? ' · $company' : ''}${vendor.isNotEmpty ? ' · $vendor' : ''}';

/// Report 2 – vendors × months, the net payable.
RTable brNetTable(List<Map<String, dynamic>> rows, List<String> months) {
  final vendors = brVendors(rows);
  return RTable(
    sheet: 'Net Payable',
    head: ['#', 'Vendor', for (final m in months) brMonthName(m), 'Total'],
    numCols: {for (var i = 2; i < months.length + 3; i++) i},
    rows: [
      for (var i = 0; i < vendors.length; i++)
        RRow([
          RCell('${i + 1}'),
          RCell(vendors[i], bold: true),
          for (final m in months) _numCell(_sum(rows, (r) => r['vendor'] == vendors[i] && r['month'] == m)),
          _numCell(_sum(rows, (r) => r['vendor'] == vendors[i]), bold: true),
        ]),
    ],
    foot: [
      RRow([const RCell(''), const RCell('Total', bold: true), for (final m in months) _numCell(_sum(rows, (r) => r['month'] == m), bold: true), _numCell(_sum(rows, (_) => true), bold: true)], kind: RKind.grand),
    ],
  );
}

RCell _numCell(num v, {bool bold = false}) => RCell(brAmt(v), n: true, bold: bold, value: r2(v));
RCell _lessCell(Object? v, {bool bold = false}) => RCell(_less(v), n: true, bold: bold, value: _n(v) != 0 ? -r2(_n(v)) : null);

const kBrFields = ['basic', 'diesel', 'other', 'gst', 'tds', 'net'];

List<RCell> _brTot(List<Map<String, dynamic>> list) {
  final t = [for (final f in kBrFields) list.fold<num>(0, (a, r) => a + _n(r[f]))];
  return [for (var k = 0; k < t.length; k++) k == 1 || k == 2 || k == 4 ? _lessCell(t[k], bold: true) : _numCell(t[k], bold: true)];
}

/// Report 1 – every bill: Basic, the deductions, GST, TDS and the net payable, vendor by vendor.
RTable brDetailTable(List<Map<String, dynamic>> rows) {
  final vendors = brVendors(rows), out = <RRow>[];
  for (final vn in vendors) {
    final list = rows.where((r) => r['vendor'] == vn).toList();
    out.add(RRow([RCell(vn, bold: true, span: 11)], kind: RKind.group));
    for (final r in list) {
      out.add(RRow([
        RCell(brMonthName(_s(r['month']))),
        RCell('${_s(r['billNo'])}${_n(r['rev']) != 0 ? ' rev ${r['rev']}' : ''}'),
        RCell(_s(r['company'])),
        RCell('${showDate(_s(r['from']))} – ${showDate(_s(r['to']))}'),
        RCell(showDate(_s(r['billDate']))),
        _numCell(_n(r['basic'])),
        _lessCell(r['diesel']),
        _lessCell(r['other']),
        RCell('${brAmt(r['gst'])}${_n(r['gstPct']) != 0 ? ' ${fmt(r['gstPct'])}%' : ''}', n: true, value: r2(_n(r['gst']))),
        RCell('${_less(r['tds'])}${_n(r['tdsPct']) != 0 ? ' ${fmt(r['tdsPct'])}%' : ''}', n: true, value: _n(r['tds']) != 0 ? -r2(_n(r['tds'])) : null),
        RCell(brAmt(r['net']), n: true, bold: true, value: r2(_n(r['net']))),
      ]));
    }
    if (vendors.length > 1 || list.length > 1) out.add(RRow([RCell('Total – $vn', bold: true, span: 5), ..._brTot(list)], kind: RKind.sub));
  }
  return RTable(
    sheet: 'Detail',
    head: const ['Month', 'RA Bill No', 'Name on bill', 'Work Period', 'Bill Date', 'Basic (A)', 'Diesel Deduction (B)', 'Other Deduction (C)', 'GST', 'TDS', 'Net Payable'],
    numCols: const {5, 6, 7, 8, 9, 10},
    rows: out,
    foot: [if (vendors.length > 1) RRow([const RCell('Grand Total', bold: true, span: 5), ..._brTot(rows)], kind: RKind.grand)],
  );
}

RDoc brDoc(List<Map<String, dynamic>> rows, List<String> months, String view, {String company = '', String vendor = ''}) => RDoc(
      title: 'Bill Summary – ${view == 'net' ? 'Net Payable (month-wise)' : 'Detail'}',
      period: brSub(months, company, vendor),
      portrait: false,
      blocks: [view == 'net' ? brNetTable(rows, months) : brDetailTable(rows)],
      file: 'Bill_Summary_${view == 'net' ? 'Net_Payable_' : 'Detail_'}${months.first}_to_${months.last}',
    );

// ---------------------------------------------------------------------------------------------------------------------
//  VENDOR LEDGER
// ---------------------------------------------------------------------------------------------------------------------
/// The particulars of a ledger line (as the web's vlPart, as plain text: the first line, the small line under it).
(String, String) vlPart(Map r) {
  final k = r['kind'], remark = _s(r['remark']);
  if (k == 'opening') return ('Opening balance – ${r['side'] == 'Advance' ? 'advance paid' : 'payable'}', remark);
  if (k == 'dn' || k == 'cn') return ('${k == 'cn' ? 'Credit' : 'Debit'} Note ${_s(r['dnNo'])}${_s(r['company']).isNotEmpty ? ' – ${r['company']}' : ''}', remark);
  if (k == 'payment') return ('Payment – ${_s(r['mode'])}${_s(r['ref']).isNotEmpty ? ' · ${r['ref']}' : ''}${_s(r['against']).isNotEmpty ? ' · against ${r['against']}' : ''}', remark);
  return (
    'RA Bill ${_s(r['billNo'])}${_n(r['rev']) != 0 ? ' (Rev ${r['rev']})' : ''} – work ${showDate(_s(r['from']))} to ${showDate(_s(r['to']))}',
    'Basic ${n2(r['basic'])}${_n(r['diesel']) != 0 ? ' · Diesel ded. − ${n2(r['diesel'])}' : ''}${_n(r['other']) != 0 ? ' · Other ded. − ${n2(r['other'])}' : ''}${_n(r['gst']) != 0 ? ' · GST + ${n2(r['gst'])}' : ''}${_n(r['tds']) != 0 ? ' · TDS − ${n2(r['tds'])}' : ''} · Net ${n2(r['bill'])}'
  );
}

String vlPeriod(Map d) => '${_s(d['from']).isNotEmpty ? showDate(_s(d['from'])) : 'the start'} to ${_s(d['to']).isNotEmpty ? showDate(_s(d['to'])) : 'today'}';

/// The opening line's note (the old balance entered, and / or what came before the From date).
String vlOpenNote(Map d) {
  final oe = d['openEntry'] as Map?, from = _s(d['from']);
  if (oe != null) return '(old balance as on ${showDate(_s(oe['date']))}: ${oe['side'] == 'Advance' ? 'advance ' : 'payable '}${n2(oe['amount'])}${from.isNotEmpty ? ', plus bills and payments before ${showDate(from)}' : ''})';
  return from.isNotEmpty ? '(bills and payments before ${showDate(from)})' : '(no old balance entered)';
}

RDoc vlDoc(Map d, String today) {
  final from = _s(d['from']), to = _s(d['to']), oe = d['openEntry'] as Map?, vendor = _s(d['vendor']);
  return RDoc(
    title: 'Vendor Ledger – ${vendor.toUpperCase()}',
    period: '${from.isNotEmpty ? showDate(from) : 'from the start'} to ${to.isNotEmpty ? showDate(to) : showDate(today)}',
    kpis: [('Opening', balTxt(d['opening'])), ('Bills', n2(d['totalBill'])), ('Paid', n2(d['totalPaid'])), ('Balance ${_n(d['closing']) < 0 ? '(advance)' : 'to pay'}', '₹ ${balTxt(d['closing'])}')],
    blocks: [
      RTable(
        sheet: 'Ledger',
        head: const ['Date', 'Particulars', 'Name on bill', 'Bill Amount', 'Paid', 'Balance'],
        numCols: const {3, 4, 5},
        rows: [
          RRow([RCell(from.isNotEmpty ? showDate(from) : oe != null ? showDate(_s(oe['date'])) : ''), RCell('Opening balance ${vlOpenNote(d)}', bold: true, span: 4), RCell(balTxt(d['opening']), n: true, bold: true, value: _n(d['opening']))]),
          for (final r in maps(d['rows']))
            RRow([
              RCell(showDate(_s(r['date']))),
              RCell([vlPart(r).$1, if (vlPart(r).$2.isNotEmpty) vlPart(r).$2].join('\n')),
              RCell(_s(r['company'])),
              RCell(_n(r['bill']) != 0 ? n2(r['bill']) : '', n: true, value: _n(r['bill']) != 0 ? _n(r['bill']) : null),
              RCell(_n(r['paid']) != 0 ? n2(r['paid']) : '', n: true, value: _n(r['paid']) != 0 ? _n(r['paid']) : null),
              RCell(balTxt(r['balance']), n: true, bold: true, value: _n(r['balance'])),
            ]),
        ],
        foot: [
          RRow([const RCell(''), RCell('Total – ${vlPeriod(d)}', bold: true, span: 2), RCell(n2(d['totalBill']), n: true, bold: true, value: _n(d['totalBill'])), RCell(n2(d['totalPaid']), n: true, bold: true, value: _n(d['totalPaid'])), RCell(balTxt(d['closing']), n: true, bold: true, value: _n(d['closing']))], kind: RKind.grand),
        ],
      ),
    ],
    signs: const [('Prepared by', ''), ('Checked by', ''), ('Accounts', ''), ('Vendor', '')],
    file: 'Vendor_Ledger_${vendor.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}',
  );
}

// ---------------------------------------------------------------------------------------------------------------------
//  VENDOR OUTSTANDING
// ---------------------------------------------------------------------------------------------------------------------
String voMonths(Map d) {
  final ms = [for (final m in (d['months'] as List? ?? const [])) '$m'];
  if (ms.isEmpty) return '';
  return '${brMonthName(ms.first)}${ms.length > 1 ? ' to ${brMonthName(ms.last)}' : ''}';
}

RDoc voDoc(Map d) {
  final rows = maps(d['rows']), ms = [for (final m in (d['months'] as List? ?? const [])) '$m'];
  num sum(num Function(Map r) f) => rows.fold<num>(0, (a, r) => a + f(r));
  RCell bal(num v, {bool bold = false}) => RCell(balTxt(v), n: true, bold: bold, value: r2(v));
  return RDoc(
    title: 'Vendor Outstanding',
    period: voMonths(d),
    portrait: ms.length <= 6,
    blocks: [
      RNote('Balance – ${voMonths(d)}', heading: true),
      RTable(
        sheet: 'Outstanding',
        head: const ['#', 'Vendor', 'Opening', 'Bills', 'Paid', 'Balance to pay', 'Last payment'],
        numCols: const {2, 3, 4, 5},
        rows: [
          for (var i = 0; i < rows.length; i++)
            RRow([
              RCell('${i + 1}'),
              RCell(_s(rows[i]['vendor']), bold: true),
              bal(_n(rows[i]['opening'])),
              _numCell(_n(rows[i]['bills'])),
              _numCell(_n(rows[i]['paid'])),
              RCell(balTxt(rows[i]['closing']), n: true, bold: true, tone: _n(rows[i]['closing']) > 0 ? 'bad' : 'good', value: _n(rows[i]['closing'])),
              RCell(_s(rows[i]['lastPay']).isNotEmpty ? showDate(_s(rows[i]['lastPay'])) : '–'),
            ]),
        ],
        foot: [
          RRow([const RCell(''), const RCell('Total', bold: true), bal(sum((r) => _n(r['opening'])), bold: true), RCell(n2(sum((r) => _n(r['bills']))), n: true, bold: true, value: r2(sum((r) => _n(r['bills'])))), RCell(n2(sum((r) => _n(r['paid']))), n: true, bold: true, value: r2(sum((r) => _n(r['paid'])))), bal(sum((r) => _n(r['closing'])), bold: true), const RCell('')], kind: RKind.grand),
        ],
      ),
      const RNote('Balance at the end of each month', heading: true),
      RTable(
        sheet: 'Month-end balance',
        head: ['#', 'Vendor', for (final m in ms) brMonthName(m)],
        numCols: {for (var k = 0; k < ms.length; k++) k + 2},
        rows: [
          for (var i = 0; i < rows.length; i++) RRow([RCell('${i + 1}'), RCell(_s(rows[i]['vendor']), bold: true), for (var k = 0; k < ms.length; k++) bal(_n((rows[i]['monthEnd'] as List? ?? const []).elementAtOrNull(k)))]),
        ],
        foot: [
          RRow([const RCell(''), const RCell('Total', bold: true), for (var k = 0; k < ms.length; k++) bal(sum((r) => _n((r['monthEnd'] as List? ?? const []).elementAtOrNull(k))), bold: true)], kind: RKind.grand),
        ],
      ),
    ],
    file: 'Vendor_Outstanding_${ms.isNotEmpty ? ms.first : ''}_to_${ms.isNotEmpty ? ms.last : ''}',
  );
}

// ---------------------------------------------------------------------------------------------------------------------
//  A NEW DEBIT NOTE: the sums (the server works them out again on saving)
// ---------------------------------------------------------------------------------------------------------------------
num dnLineAmt(Map l) => r2(_n(l['qty']) * _n(l['rate']));

({num amount, num gst, num tds, num total}) dnTotals(List<Map> lines, Object? gstPct, Object? tdsPct) {
  final amount = r2(lines.fold<num>(0, (a, l) => a + dnLineAmt(l)));
  final gst = r2(amount * _n(gstPct) / 100), tds = r2(amount * _n(tdsPct) / 100);
  return (amount: amount, gst: gst, tds: tds, total: r2(amount + gst - tds));
}

String dnSumText(({num amount, num gst, num tds, num total}) t) => 'Amount ${n2(t.amount)} + GST ${n2(t.gst)} − TDS ${n2(t.tds)} = Total ₹ ${n2(t.total)}';

/// A Log Book entry charged to the party, as a line of the note (getDebitPending's rows).
Map<String, dynamic> dnLineOf(Map r) => {
      'logId': r['logId'],
      'machinery': '${_s(r['no'])}${_s(r['type']).isNotEmpty ? ' ${r['type']}' : ''}',
      'particular': '${showDate(_s(r['date']))}${_s(r['shift']).isNotEmpty && r['shift'] != 'Full Day' ? ' ${r['shift']}' : ''}${_s(r['work']).isNotEmpty ? ' – ${r['work']}' : ''}',
      'qty': r['qty'],
      'unit': r['unit'],
      'rate': r['rate'],
    };

/// The payments list's note: "3 entries · payments ₹ 14,000.00".
String pyNote(List<Map<String, dynamic>> list) => '${list.length} entries · payments ₹ ${n2(list.where((p) => p['type'] == 'Payment').fold<num>(0, (a, p) => a + _n(p['amount'])))}';
