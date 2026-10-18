/* MACHINERY BILLING (3.8.0) – the web's own rules (App.html "MACHINERY BILLING"), line by line: one bill per vendor (or per
 * machinery) for a period, built from the Log Book and the diesel / BOQ of the dates (mbMachine, mbFill, mbTotals); the warnings
 * to check before submitting; and the papers of a bill – Abstract of Bill, Tax Invoice, Declaration of GST non-enrolment, Debit
 * Note (diesel) – and a saved debit note (billHtml, taxInvoiceHtml, gstDeclHtml, debitNoteHtml, debitNoteDocHtml). A bill is
 * kept as the same map the web keeps (it is what verifyBills / submitBills are sent and what is saved). */
import 'dash.dart' show kDayStatus;
import 'format.dart' show showDate;
import 'lb_print.dart' show fmt, n2, tankLeft, tankText, itemDaySegs, dayPart;
import 'log_edit.dart' show r2, js;
import 'print_css.dart';
import 'session.dart' show hasKm, hasHr, kNoReading;

const kLogoUrl = 'https://i.ibb.co/CpSfBqXX/RCL-LOGO-PDF.png';
const kSketchlineLogo = 'https://i.ibb.co/hF8CPrw3/sketchline.jpg';
const kItemWord = {'hr': 'hr', 'km': 'km', 'trip': 'trips'};

String _s(Object? v) => v == null ? '' : '$v';
bool _blank(Object? v) => v == null || v == '';
num _n(Object? v) => v is num ? v : (num.tryParse(_s(v).trim()) ?? 0);
String _up(Object? t) => _s(t).toUpperCase();
String _key(Object? no) => _s(no).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
String _nodash(Object? no) => _s(no).replaceAll('-', '');
String _e(Object? s) => js(s).replaceAllMapped(RegExp('[&<>"\']'), (m) => const {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[m[0]]!);
String _mode(Map r) => _s(r['mode']).isNotEmpty ? _s(r['mode']) : _s(r['unit']);
bool _isHol(Map r) => _mode(r) == 'Holiday' || _mode(r) == 'Breakdown';
int _dim(String d) => DateTime(int.parse(d.substring(0, 4)), int.parse(d.substring(5, 7)) + 1, 0).day;
String _dateAdd(String dk, int n) {
  final p = dk.split('-').map(int.parse).toList(), d = DateTime(p[0], p[1], p[2] + n);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

List<Map<String, dynamic>> _maps(Object? l) => [for (final x in (l as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];

/// 28.05.2026 (the bill's way of writing a date).
String mbDot(Object? d) => _blank(d) ? '' : _e(_s(d).split('-').reversed.join('.'));

/// "+ ₹1,234.00" / "− ₹1,234.00"
String corrSgn(num v) => '${v < 0 ? '− ' : '+ '}₹${n2(v.abs())}';

/// What changed in an earlier bill, line by line (work at its rate, diesel debited at its rate).
String corrCalc(Map z) => [
      for (final w in _maps(z['work'])) '${_e(w['unit'])} ${fmt(w['from'])} → ${fmt(w['to'])}${w['rate'] != '' ? ' × ₹${n2(w['rate'])}' : ''} = ${corrSgn(_n(w['amount']))}',
      if (z['diesel'] is Map)
        'Diesel debited ${fmt((z['diesel'] as Map)['from'])} L → ${fmt((z['diesel'] as Map)['to'])} L × ₹${n2((z['diesel'] as Map)['rate'])} = ${corrSgn(-_n((z['diesel'] as Map)['amount']))} <small>(issued ${fmt((z['diesel'] as Map)['issuedFrom'])} → ${fmt((z['diesel'] as Map)['issuedTo'])} L)</small>',
    ].join('<br>');

String billTank(Map b) => _maps(b['machines']).where((m) => m['tank'] is Map && _n((m['tank'] as Map)['applied']) > 0).map((m) => '${_nodash(m['no'])}: ${tankText(m['tank'] as Map)}').join(' | ');
String billFinal(Map b) => _maps(b['machines']).where((m) => _s(m['final']).isNotEmpty).map((m) => '${_nodash(m['no'])}: FINAL BILL – left the site on ${showDate(_s(m['final']))}, the diesel in its tank is debited (nothing left out)').join(' | ');
String billEst(Map b) => _maps(b['machines']).where((m) => m['est'] is Map && _n((m['est'] as Map)['days']) != 0).map((m) {
      final x = m['est'] as Map;
      return '${_nodash(m['no'])} ${x['days']} day(s) ${[if (_n(x['km']) != 0) '${fmt(x['km'])} km', if (_n(x['hr']) != 0) '${fmt(x['hr'])} hr'].join(' + ')}';
    }).join(', ');
String billNoEntry(Map b) => [for (final m in _maps(b['machines'])) for (final x in _maps(m['noEntry'])) '${_nodash(m['no'])} ${showDate(_s(x['d']))} ${fmt(x['q'])} L'].join(', ');

// =====================================================================================================================
//  ONE MACHINERY'S BILL FOR THE DATES (mbMachine) – the same rules as the Log Book print
// =====================================================================================================================
Map<String, dynamic> mbMachine(String no, List<Map<String, dynamic>> list0, Map extra, String from, String to, Map<String, dynamic>? Function(String) machine, {String vt = '', bool idlePaid = true}) {
  final m = machine(no) ?? <String, dynamic>{'id': no};
  final u = _s(m['unit']).isNotEmpty ? _s(m['unit']) : (list0.isNotEmpty && _s(list0.first['unit']).isNotEmpty ? _s(list0.first['unit']) : 'KM');
  final key = _key(no);
  final bday = ((extra['boq'] as Map?)?[key] as Map?) ?? const {}, iss0 = ((extra['issues'] as Map?)?[key] as Map?) ?? const {};
  bool isIdle(Map r) => _mode(r) == 'Idle';
  final idleDays = list0.where(isIdle).map((r) => r['date']).toSet().length;
  final holidays = list0.where(_isHol).length;
  final list = list0.where((r) => !_isHol(r) && (idlePaid || !isIdle(r))).toList();
  final units = <String, Map<String, num>>{};
  for (final r in list) {
    final x = units.putIfAbsent(_s(r['date']), () => {'day': 0, 'night': 0}), p = dayPart(r);
    if (r['shift'] == 'Night') {
      x['night'] = x['night']! > p ? x['night']! : p;
    } else {
      x['day'] = x['day']! > p ? x['day']! : p;
    }
  }
  final workDays = r2(units.values.fold<num>(0, (a, x) => a + x['day']!)), nights = r2(units.values.fold<num>(0, (a, x) => a + x['night']!));
  final segs = <String, Map<String, dynamic>>{};
  num periodHrs = 0;
  Map? last;
  final zero = <String, List<String>>{}, itemHrs = <String, num>{}, itemNotes = <String>[];
  Map<String, dynamic> seg(String k, Map<String, dynamic> o) => segs.putIfAbsent(k, () => {'qty': 0, 'amount': 0, ...o});
  void add(Map<String, dynamic> s1, num q, num a) {
    s1['qty'] = _n(s1['qty']) + q;
    s1['amount'] = _n(s1['amount']) + a;
  }

  String ways(List<Map> rows) => rows.map(_mode).toSet().join('/');
  for (final d in units.keys.toList()..sort()) {
    final x = units[d]!, n = x['day']! + x['night']!, b = bday[d] as Map?;
    final dayRows = list.where((r) => r['date'] == d).toList();
    final hrs = dayRows.fold<num>(0, (s, r) => s + _n(r['whr'])), km = dayRows.fold<num>(0, (s, r) => s + _n(r['wkm'])), trips = dayRows.fold<num>(0, (s, r) => s + _n(r['trip']));
    final basis = _s(b?['basis']);
    // a BOQ paid per hour / KM / trip on a day whose Log Book has none of that → the day earns nothing: noted for checking
    if (b != null && ((basis == 'Per Hour' && !(hrs > 0)) || (basis == 'Per KM' && !(km > 0)) || (basis == 'Per Trip' && !(trips > 0)))) {
      zero.putIfAbsent(basis, () => []).add('${showDate(d).substring(0, 5)} (${ways(dayRows)})');
    }
    if (b == null) {
      final mr = _n(m['monthlyRate']);
      if (mr != 0) add(seg('legacy|${_dim(d)}', {'unit': 'Days', 'rate': mr / _dim(d), 'monthly': mr}), n, mr / _dim(d) * n);
      continue;
    }
    last = b;
    final bk = '${b['boq']}${_n(b['amendNo']) != 0 ? '/${b['amendNo']}' : ''}';
    if ((b['items'] as List? ?? const []).isNotEmpty) {
      for (final r in dayRows) {
        for (final t in (r['itemOver'] as List? ?? const [])) {
          itemNotes.add('${showDate(d).substring(0, 5)}: $t – correct the items in the Log Book');
        }
        for (final t in (r['itemUnknown'] as List? ?? const [])) {
          itemNotes.add('${showDate(d).substring(0, 5)}: item "$t" is not in the BOQ');
        }
        ((r['itemLeft'] as Map?) ?? const {}).forEach((k, v) => itemNotes.add('${showDate(d).substring(0, 5)}: ${fmt(v)} ${kItemWord[k]} given to no item (not billed)'));
      }
      if (!(itemDaySegs(b, bk, d, dayRows, itemHrs, seg) > 0) && dayRows.any((r) => _mode(r) != 'Idle')) zero.putIfAbsent('Item-wise', () => []).add('${showDate(d).substring(0, 5)} (${ways(dayRows)})');
      continue;
    }
    final rate = _n(b['rate']);
    if (basis == 'Monthly') {
      add(seg('$bk|M|${_dim(d)}', {'unit': 'Days', 'rate': rate / _dim(d), 'monthly': b['rate']}), n, rate / _dim(d) * n);
    } else if (basis == 'Per Day') {
      add(seg('$bk|D', {'unit': 'Days', 'rate': b['rate']}), n, rate * n);
    } else if (basis == 'Per KM') {
      add(seg('$bk|K', {'unit': 'KM', 'rate': b['rate']}), km, rate * km);
    } else if (basis == 'Per Trip' && _n(b['nightRate']) > 0) {
      final tN = dayRows.where((r) => r['shift'] == 'Night').fold<num>(0, (s, r) => s + _n(r['trip'])), tD = trips - tN;
      if (tD > 0) add(seg('$bk|T', {'unit': 'Trips', 'rate': b['rate']}), tD, rate * tD);
      if (tN > 0) add(seg('$bk|TN', {'unit': 'Night trips', 'rate': _n(b['nightRate'])}), tN, _n(b['nightRate']) * tN);
    } else if (basis == 'Per Trip') {
      add(seg('$bk|T', {'unit': 'Trips', 'rate': b['rate']}), trips, rate * trips);
    } else if (basis == 'Per Hour') {
      final slabs = _maps(b['slabs']);
      if (slabs.isNotEmpty) {
        num from2 = b['slabOn'] == 'Period' ? periodHrs : 0, left = hrs;
        for (var k = 0; k < slabs.length; k++) {
          final sl = slabs[k];
          if (left <= 0) continue;
          final cap = _blank(sl['upTo']) ? double.infinity : _n(sl['upTo']);
          if (from2 >= cap) continue;
          final take = left < cap - from2 ? left : cap - from2;
          add(seg('$bk|S$k', {'unit': 'Hrs', 'rate': sl['rate'], 'note': _blank(sl['upTo']) ? 'after ${k > 0 ? _s(slabs[k - 1]['upTo']) : '0'} hr' : 'up to ${sl['upTo']} hr'}), take, take * _n(sl['rate']));
          left -= take;
          from2 += take;
        }
        periodHrs += hrs;
      } else {
        add(seg('$bk|H', {'unit': 'Hrs', 'rate': b['rate']}), hrs, rate * hrs);
      }
    }
  }
  final lines = [
    for (final x in segs.values)
      {'unit': x['unit'], 'qty': r2(_n(x['qty'])), 'rate': r2(_n(x['rate'])), 'amount': r2(_n(x['amount'])), 'monthly': _blank(x['monthly']) || x['monthly'] == 0 ? '' : x['monthly'], 'note': _s(x['note']), 'item': _s(x['item'])},
  ].where((x) => _n(x['qty']) != 0 || _n(x['amount']) != 0).toList();
  final zeroWork = [for (final k in zero.keys) {'basis': k, 'days': zero[k]}];
  final amount = r2(lines.fold<num>(0, (s, x) => s + _n(x['amount'])));
  // diesel: on a debited day ALL of it is recovered; on a company day only what is above the standard average
  bool isDebit(String d) {
    final bd = bday[d] as Map?;
    if (vt == 'Full Debit' || vt == 'Rental – diesel debit') return true;
    if (vt == 'Rental – company diesel') return false;
    return bd != null ? bd['diesel'] == 'Debit Basis' : m['supply'] == 'Debit Basis';
  }

  final issued = r2(iss0.values.fold<num>(0, (s, x) => s + _n((x as Map?)?['qty'])));
  final debitQty = r2(iss0.keys.map((k) => '$k').where(isDebit).fold<num>(0, (s, d) => s + _n((iss0[d] as Map?)?['qty']))), companyQty = r2(issued - debitQty);
  final own = list.where((r) => !isDebit(_s(r['date']))).toList();
  final tKm = own.fold<num>(0, (s, r) => s + _n(r['wkm'])), tHr = own.fold<num>(0, (s, r) => s + _n(r['whr']));
  final kmStd = _n(m['kmStd']), hrStd = _n(m['hrStd']);
  final stdQty = r2((hasKm(u) && kmStd != 0 ? tKm / kmStd : 0) + (hasHr(u) && hrStd != 0 ? tHr * hrStd : 0));
  final rawExcess = stdQty > 0 ? (r2(companyQty - stdQty) > 0 ? r2(companyQty - stdQty) : 0) : 0;
  // final bill: the machinery left the site (Inactive from a date up to the day after the period) → no "still in the tank" allowance
  final dayAfter = _dateAdd(to, 1), inf = _s(m['inactiveFrom']), inf10 = inf.length > 10 ? inf.substring(0, 10) : inf;
  // (the server's leftOn_: the date it went Inactive – the web page names the same date)
  final leftOn = m['status'] == 'Inactive' && inf10.isNotEmpty ? inf10 : '';
  final fin = (m['status'] == 'Inactive' && inf10.isNotEmpty && inf10.compareTo(dayAfter) <= 0) || _maps(m['earlier']).any((p) => _s(p['until']).compareTo(from) > 0 && _s(p['until']).compareTo(dayAfter) <= 0);
  final tank = fin ? null : tankLeft(m, u, own, iss0, isDebit, rawExcess);
  final excessQty = r2(rawExcess - (tank != null ? _n(tank['applied']) : 0));
  final avg = _n(extra['avgRate']), lastR = _n(extra['lastRate']), autoRate = avg > lastR ? avg : lastR, manRate = _n(extra['manualRate']) > 0 ? r2(_n(extra['manualRate'])) : 0;
  final dRate = manRate > 0 ? manRate : autoRate, excessAmt = r2((debitQty + excessQty) * dRate);
  // diesel issued on a day that has no WORKING Log Book entry: counted in the bill, and the bill says so
  final worked = {for (final r in list) if (!kDayStatus.contains(_mode(r))) _s(r['date'])};
  final noEntry = [
    for (final d in iss0.keys.map((k) => '$k').toList()..sort())
      if (!worked.contains(d) && _n((iss0[d] as Map?)?['qty']) > 0) {'d': d, 'q': r2(_n((iss0[d] as Map?)?['qty']))},
  ];
  // days entered WITHOUT a reading (meter not working): their work is an estimate
  final offRows = list.where((r) => _mode(r) == kNoReading).toList();
  final est = {'days': offRows.map((r) => r['date']).toSet().length, 'km': r2(offRows.fold<num>(0, (s, r) => s + _n(r['wkm']))), 'hr': r2(offRows.fold<num>(0, (s, r) => s + _n(r['whr'])))};
  return {
    'final': fin ? leftOn : '', 'tank': tank != null && _n(tank['applied']) > 0 ? tank : null, 'rawExcess': rawExcess, 'est': est, 'noEntry': noEntry,
    'no': _s(m['id']).isNotEmpty ? m['id'] : no, 'type': _s(m['type']), 'name': _s(m['name']), 'unit': u, 'supply': _s(m['supply']),
    'workDays': workDays, 'nights': nights, 'holidays': holidays, 'idleDays': idleDays, 'itemNotes': itemNotes, 'lines': lines, 'amount': amount, 'zeroWork': zeroWork,
    'issued': issued, 'stdQty': stdQty, 'excessQty': excessQty, 'debitQty': debitQty, 'dieselRate': dRate, 'autoRate': autoRate, 'rateManual': manRate > 0, 'excessAmt': excessAmt, 'days': units.length,
    'gstPct': last != null && !_blank(last['gstPct']) ? _n(last['gstPct']) : 0,
    'tdsPct': last != null && !_blank(last['tdsPct']) ? _n(last['tdsPct']) : _n(m['tdsRate']),
    'woNo': last != null ? _s(last['woNo']) : '', 'woDate': last != null ? _s(last['woDate']) : '', 'hasBoq': last != null,
  };
}

/// The Log Book rows and the diesel / BOQ of the dates a bill is built from.
class BillLogs {
  BillLogs(this.rows, this.from, this.to, this.extra);
  final List<Map<String, dynamic>> rows;
  final String from, to;
  final Map extra;
}

/// The machinery, warnings and totals of a bill from the Log Book of the dates (again when the Idle choice or the rate changes).
Map<String, dynamic> mbFill(Map<String, dynamic> b, BillLogs l, Map<String, dynamic>? Function(String) machine) {
  final byNo = <String, List<Map<String, dynamic>>>{};
  for (final r in l.rows) {
    byNo.putIfAbsent(_up(r['no']), () => []).add(r);
  }
  final ex = _n(b['dieselRate']) > 0 ? {...l.extra, 'manualRate': _n(b['dieselRate'])} : l.extra;
  final idlePaid = b['idlePaid'] != false;
  final picked = [for (final x in (b['picked'] as List? ?? const [])) '$x'];
  final machines = [
    for (final id in picked) mbMachine(id, byNo[id.toUpperCase()] ?? [], ex, _s(b['from']), _s(b['to']), machine, idlePaid: idlePaid),
  ].where((x) => _n(x['days']) != 0 || _n(x['issued']) != 0 || _n(x['amount']) != 0 || _n(x['idleDays']) != 0).toList();
  final wo = machines.where((x) => _s(x['woNo']).isNotEmpty).firstOrNull ?? const {};
  b['machines'] = machines;
  b['txNet'] = true; // (3.20.0, Mechanical update-124) a bill made from now on: its Tax Invoice is of the value after the diesel debit
  b['woNo'] = _s(wo['woNo']);
  b['woDate'] = _s(wo['woDate']);
  b['idleDays'] = machines.fold<num>(0, (a, x) => a + _n(x['idleDays']));
  final w = <String>[];
  if (machines.isEmpty) w.add('no Log Book / diesel in these dates${picked.length == 1 ? ' for ${picked.first}' : ''}');
  for (final x in machines.where((x) => x['hasBoq'] != true && x['supply'] != 'Debit Basis')) {
    w.add('${x['no']}: no BOQ in these dates');
  }
  const what = {'Per Hour': 'hours', 'Per KM': 'KM', 'Per Trip': 'trips', 'Item-wise': 'work for its items'};
  for (final x in machines) {
    for (final z in _maps(x['zeroWork'])) {
      final days = [for (final d in (z['days'] as List? ?? const [])) '$d'];
      w.add('${x['no']}: BOQ ${z['basis']} but no ${what[z['basis']]} on ${days.length} day(s) – ${days.take(4).join(', ')}${days.length > 4 ? ' …' : ''} (not billed)');
    }
  }
  for (final x in machines) {
    for (final t in (x['itemNotes'] as List? ?? const []).take(6)) {
      w.add('${x['no']} – $t');
    }
  }
  for (final x in machines) {
    if (_s(x['final']).isNotEmpty) w.add('${x['no']}: FINAL BILL – the machinery left the site on ${showDate(_s(x['final']))}; the diesel in its tank is debited, and every open debit note of the vendor should be deducted');
  }
  for (final x in machines) {
    final t = x['tank'] as Map?;
    if (t != null && _n(t['applied']) > 0 && !(_n(machine(_s(x['no']))?['tankCap']) > 0)) {
      w.add('${x['no']}: ${fmt(t['applied'])} L of the last fill taken as still in the tank – Tank Capacity is not set in Asset Master, so this is not limited by the tank');
    }
  }
  for (final x in machines) {
    final est = x['est'] as Map?;
    if (est != null && _n(est['days']) != 0) w.add('${x['no']}: ${est['days']} day(s) without a reading (meter not working) – work estimated: ${[if (_n(est['km']) != 0) '${fmt(est['km'])} km', if (_n(est['hr']) != 0) '${fmt(est['hr'])} hr'].join(' + ')}');
  }
  if (_n(b['idleDays']) != 0 && !b.containsKey('idlePaid')) w.add('${b['idleDays']} Idle day(s) – choose Paid / Not paid (shown as paid until you choose)');
  final v = (b['vendor'] as Map?) ?? const {};
  if (_s(v['pan']).isEmpty) w.add('PAN missing in Vendor Master');
  if (_s(v['account']).isEmpty || _s(v['ifsc']).isEmpty) w.add('bank details missing');
  b['warnings'] = w;
  return mbTotals(b);
}

bool gstDeclNeed(Map? v, Object? gstPct) => _s(v?['gstReg']) != 'Yes' && _s(v?['gst']).trim().isEmpty && !(_n(gstPct) > 0);
bool gstDeclOn(Map b) {
  final v = (b['vendor'] as Map?) ?? const {};
  if (_s(v['name']).trim().isEmpty) return false;
  return b.containsKey('gstDecl') && b['gstDecl'] != null ? b['gstDecl'] == true : gstDeclNeed(v, b['gstPct']);
}

/// A–K of a bill.
Map<String, dynamic> mbTotals(Map<String, dynamic> b) {
  final ms = _maps(b['machines']);
  final a = r2(ms.fold<num>(0, (s, x) => s + _n(x['amount']))), bb = r2(ms.fold<num>(0, (s, x) => s + _n(x['excessAmt']))), c = r2(_n(b['C']));
  final d = r2(a - bb - c);
  num mx(String k) => ms.fold<num>(0, (m0, x) => _n(x[k]) > m0 ? _n(x[k]) : m0);
  final gstPct = mx('gstPct'), tdsPct = mx('tdsPct'), plus = d > 0;
  final ee = plus ? r2(d * gstPct / 200) : 0, g = r2(d + ee + ee), h = plus ? r2(d * tdsPct / 100) : 0, i = r2(g - h);
  final j = r2(_maps(b['dns']).fold<num>(0, (s, n) => s + _n(n['total'])) + _maps(b['corr']).fold<num>(0, (s, z) => s + (z['kind'] == 'Credit' ? -_n(z['total']) : _n(z['total']))));
  b
    ..['A'] = a
    ..['B'] = bb
    ..['C'] = c
    ..['D'] = d
    ..['gstPct'] = gstPct
    ..['tdsPct'] = tdsPct
    ..['E'] = ee
    ..['F'] = ee
    ..['G'] = g
    ..['H'] = h
    ..['I'] = i
    ..['J'] = j
    ..['K'] = r2(i - j)
    ..['gstDecl'] = gstDeclNeed(b['vendor'] as Map?, gstPct);
  return b;
}

/// The bills to make: one per vendor (its picked machinery) or one per machinery; the bill numbers go on from the last one.
List<Map<String, dynamic>> buildBills({
  required Map init,
  required Map<String, List<String>> picked,
  required String per,
  required String from,
  required String to,
  required String company,
  required String billDate,
  required BillLogs logs,
  required Map<String, dynamic>? Function(String) machine,
}) {
  final st = (init['settings'] as Map?) ?? const {};
  final vs = _maps(init['vendors']).where((v) => picked.containsKey(_s(v['name']))).toList();
  final nextNo = <String, num>{};
  final out = <Map<String, dynamic>>[];
  for (final v in vs) {
    final ids = picked[_s(v['name'])] ?? const [], ms = _maps(v['machines']).where((m) => ids.contains(_s(m['id']))).toList();
    final jobs = per == 'machine' ? [for (final m in ms) [m]] : [ms];
    for (final pick in jobs) {
      final nk = '${_up(v['name'])}|$company';
      nextNo[nk] ??= _n((init['lastNo'] as Map?)?[nk]);
      final lastNo = nextNo[nk]!;
      if (lastNo != 0) nextNo[nk] = lastNo + 1;
      final b = <String, dynamic>{
        'company': company, 'companyInfo': ((st['companies'] as Map?)?[company] as Map?) ?? <String, dynamic>{}, 'project': st['project'], 'siteAddress': _s(st['siteAddress']),
        'from': from, 'to': to, 'billDate': billDate,
        'vendor': {
          'name': v['name'], 'address': _s(v['address']), 'account': _s(v['account']), 'ifsc': _s(v['ifsc']), 'pan': _s(v['pan']), 'phone': _s(v['phone']), 'gst': _s(v['gst']),
          'gstReg': v['gstReg'] == 'Yes' ? 'Yes' : 'No', 'bank': _s(v['bank']), 'branch': _s(v['branch']),
        },
        'billNo': lastNo != 0 ? '${(lastNo + 1).toInt()}' : '', 'firstBill': lastNo == 0, 'woNo': '', 'woDate': '', 'machines': <Map<String, dynamic>>[], 'C': 0, 'cReason': '', 'edited': false,
        'picked': [for (final m in pick) m['id']], 'partial': pick.length < _maps(v['machines']).length,
        'dnOpen': [for (final n in _maps(init['pendingDn'])) if (_up(_s(n['vendor']).trim()) == _up(_s(v['name']).trim()) && n['company'] == company) n],
        'dns': <Map<String, dynamic>>[],
      };
      out.add(mbFill(b, logs, machine));
    }
  }
  return out;
}

// =====================================================================================================================
//  THE PAPERS OF A BILL
// =====================================================================================================================
/// The Abstract of Bill. [logo]: the Rachana logo as a data: address (empty = the web's own picture).
String billHtml(Map b, {String logo = ''}) {
  final co = _s(b['company']), ci = (b['companyInfo'] as Map?) ?? const {}, v = (b['vendor'] as Map?) ?? const {};
  final logoHtml = RegExp('rachana', caseSensitive: false).hasMatch(co)
      ? (logo.isNotEmpty ? '<span class="bl-logo-r"><img src="$logo" alt="" style="width:100%;height:auto;display:block"></span>' : '<span class="rlogo bl-logo-r"><img src="$kLogoUrl" alt="" onerror="this.parentNode.remove()"></span>')
      : '<span class="bl-logo-s"><img src="$kSketchlineLogo" alt="" onerror="this.parentNode.remove()"></span>';
  final machines = _maps(b['machines']);
  final monthly = <Object?>[];
  for (final m in machines) {
    final mo = _maps(m['lines']).where((l) => !_blank(l['monthly']) && l['monthly'] != 0).firstOrNull?['monthly'];
    if (mo != null && !_blank(mo) && mo != 0 && !monthly.any((x) => _n(x) == _n(mo))) monthly.add(mo);
  }
  final pmCol = monthly.length > 1;
  final rows = <String>[];
  for (final m in machines) {
    final lines = _maps(m['lines']);
    if (lines.isEmpty) {
      rows.add('<tr><td>${_e(_up(m['type']))}</td><td><b>${_e(_nodash(m['no']))}</b></td><td>${_e(_up(_s(m['name']).isNotEmpty ? m['name'] : m['type']))}</td>${pmCol ? '<td class="n">–</td>' : ''}<td class="c">–</td><td class="c">0</td><td class="n">–</td><td class="n">0.00</td></tr>');
      continue;
    }
    for (var k = 0; k < lines.length; k++) {
      final l = lines[k], item = _s(l['item']), unit = _s(l['unit']), note = _s(l['note']);
      final shift = unit == 'Days' ? (item.isNotEmpty ? 'DAY' : (_n(m['nights']) != 0 ? 'DAY + ${_e(m['nights'])} NIGHT' : 'DAY')) : _e(item.isNotEmpty ? note : (note.isNotEmpty ? note : unit.toUpperCase()));
      rows.add('<tr><td>${k > 0 ? '' : _e(_up(m['type']))}</td><td>${k > 0 ? '' : '<b>${_e(_nodash(m['no']))}</b>'}</td><td>${k > 0 ? '' : _e(_up(_s(m['name']).isNotEmpty ? m['name'] : m['type']))}'
          '${pmCol ? '</td><td class="n"><b>${!_blank(l['monthly']) && l['monthly'] != 0 ? n2(l['monthly']) : '–'}</b>' : ''}</td>'
          '<td class="c">${item.isNotEmpty ? '<b>${_e(item.toUpperCase())}</b>${unit == 'Days' || note.isNotEmpty ? ' – ' : ''}' : ''}$shift</td>'
          '<td class="c">${fmt(l['qty'])}${unit != 'Days' ? ' ${_e(unit)}' : ''}</td><td class="n">${n2(l['rate'])}</td><td class="n">${n2(l['amount'])}</td></tr>');
    }
  }
  final dq = machines.fold<num>(0, (a, x) => a + _n(x['debitQty'])), eq = machines.fold<num>(0, (a, x) => a + _n(x['excessQty']));
  final bNote = [if (dq != 0) 'diesel debit ${fmt(r2(dq))} L', if (eq != 0) 'excess diesel over standard ${fmt(r2(eq))} L'].join(' + ');
  final bNoEntry = billNoEntry(b), est = billEst(b), fin = billFinal(b), tank = billTank(b);
  final num bB = _n(b['B']), bC = _n(b['C']), bJ = _n(b['J']), gstPct = _n(b['gstPct']), tdsPct = _n(b['tdsPct']);
  final corr = _maps(b['corr']), dns = _maps(b['dns']);
  final rate0 = machines.isNotEmpty ? _n(machines.first['dieselRate']) : 0;
  final sum = <(String, String, Object, String)>[
    ('A', 'Workdone amount >>>${est.isNotEmpty ? '<small>incl. days without a reading (meter not working), work estimated: ${_e(est)}</small>' : ''}', _n(b['A']), ''),
    (
      'B',
      'Less- Diesel Deduction >>>${fin.isNotEmpty ? '<small>${_e(fin)}</small>' : ''}${tank.isNotEmpty ? '<small>${_e(tank)}</small>' : ''}${bB != 0 ? '<small>$bNote${rate0 != 0 ? ' @ ₹${fmt(rate0)}/L' : ''}</small>${bNoEntry.isNotEmpty ? '<small>incl. diesel issued on days with no Log Book entry: ${_e(bNoEntry)}</small>' : ''}' : ''}',
      bB != 0 ? -bB : '',
      ''
    ),
    ('C', 'Other Deduction >>>${bC != 0 && _s(b['cReason']).isNotEmpty ? '<small>${_e(b['cReason'])}</small>' : ''}', bC != 0 ? -bC : '', ''),
    ('D', 'Net Work Done Amount D=(A-B-C) >>>', _n(b['D']), ''),
    ('E', 'Add CGST >>>', gstPct != 0 ? _n(b['E']) : '', gstPct != 0 ? '${fmt(gstPct / 2)}%' : ''),
    ('F', 'Add SGST >>>', gstPct != 0 ? _n(b['F']) : '', gstPct != 0 ? '${fmt(gstPct / 2)}%' : ''),
    ('G', 'Total Amount (G=D+E+F)', _n(b['G']), ''),
    ('H', 'Less TDS >>>', _n(b['H']) != 0 ? -_n(b['H']) : '', tdsPct != 0 ? '${fmt(tdsPct)}%' : ''),
    ('I', 'Net Payable Amt I = (G-H) >>>>', _n(b['I']), ''),
    if (bJ != 0 || corr.isNotEmpty) ...[
      (
        'J',
        '${corr.isNotEmpty ? 'Less – Debit Note(s) / Add – Credit Note(s) >>>' : 'Less – Debit Note(s) >>>'}<small>${_e([...dns.map((n) => _s(n['no'])), ...corr.map((z) => '${z['kind'] == 'Credit' ? 'CN ' : 'DN '}${_s(z['noteNo']).isNotEmpty ? z['noteNo'] : '(number on submit)'}')].join(', '))}</small>',
        -bJ,
        ''
      ),
      ('K', 'Balance Payable K = (I-J) >>>>', _n(b['K']), ''),
    ],
  ];
  final netRow = bJ != 0 ? 'K' : 'I';
  String cell((String, String, Object, String) x) {
    if (x.$3 == '') return '–';
    final v0 = x.$3 as num;
    return '${v0 < 0 ? '− ' : x.$1 == 'J' ? '+ ' : ''}${n2(v0.abs())}';
  }

  final corrT = corr.isEmpty
      ? ''
      : '<table class="bl-t bl-corr"><thead><tr><th colspan="7">Corrections of earlier bills taken in this bill (at the earlier bill\'s rates)</th></tr><tr><th>Earlier RA Bill</th><th>Vehicle No</th><th>What changed</th><th class="n">Difference</th><th class="n">GST</th><th class="n">TDS</th><th class="n">Note</th></tr></thead><tbody>'
          '${corr.map((z) => '<tr><td>${_e(z['billNo'])}${_n(z['rev']) != 0 ? ' (Rev ${_e(z['rev'])})' : ''}<br><small>${mbDot(z['from'])} To ${mbDot(z['to'])}</small></td><td><b>${_e(_nodash(z['no']))}</b></td><td>${corrCalc(z)}</td><td class="n">${corrSgn(_n(z['net']))}</td>'
              '<td class="n">${_n(z['gst']) != 0 ? '${n2(z['gst'])}<small>${fmt(z['gstPct'])}%</small>' : '–'}</td><td class="n">${_n(z['tds']) != 0 ? '− ${n2(z['tds'])}<small>${fmt(z['tdsPct'])}%</small>' : '–'}</td>'
              '<td class="n"><b>${z['kind'] == 'Credit' ? 'Credit Note' : 'Debit Note'}</b><br>${_e(_s(z['noteNo']).isNotEmpty ? z['noteNo'] : 'on submit')}<br><b>${corrSgn(z['kind'] == 'Credit' ? _n(z['total']) : -_n(z['total']))}</b></td></tr>').join()}</tbody></table>';
  final rev = _n(b['rev']);
  const signs = [
    ['Accepted By', 'Sub Contractor'],
    ['Prepared & Checked By', 'Mechanical Dept'],
    ['Checked By', 'Site Incharge'],
    ['Checked By', 'Billing Dept'],
    ['Checked & Verified By', 'Acc. Dept'],
    ['Verified By', 'Project Manager'],
    ['Approved By', 'General Manager']
  ];
  return '<div class="bl"><div class="bl-frame">'
      '<div class="bl-top">$logoHtml<div class="bl-co">${_e(co.toUpperCase())}</div></div>'
      '<div class="bl-proj"><b>Project Name :-</b> ${_e(b['project'] ?? '')}</div>'
      '<div class="bl-title">Abstract of Bill</div>'
      '<table class="bl-head"><colgroup><col class="c1"><col class="c2"><col class="c3"></colgroup><tbody>'
      '<tr><td rowspan="4" class="bl-v"><b>${_e(_up(v['name']))}</b>${_s(v['address']).isNotEmpty ? '<br>${_e(v['address'])}' : ''}${_s(v['account']).isNotEmpty ? '<br>A/C NO :- ${_e(v['account'])}' : ''}${_s(v['ifsc']).isNotEmpty ? '<br>IFSC CODE :- ${_e(v['ifsc'])}' : ''}'
      '${_s(v['bank']).isNotEmpty ? '<br>BANK :- ${_e(v['bank'])}${_s(v['branch']).isNotEmpty ? ', ${_e(v['branch'])}' : ''}' : ''}'
      '${_s(v['pan']).isNotEmpty ? '<br>PAN NO :- ${_e(v['pan'])}' : ''}${_s(v['gst']).isNotEmpty ? '<br>GSTIN :- ${_e(v['gst'])}' : ''}${_s(v['phone']).isNotEmpty ? '<br>MOBILE NO :- ${_e(v['phone'])}' : ''}</td>'
      '<td class="k">RA BILL -</td><td class="val big"><b>${_e(b['billNo'] ?? '')}${rev != 0 ? ' (Rev ${b['rev']})' : ''}</b></td></tr>'
      '<tr><td class="k">Work Period -</td><td class="val big">${mbDot(b['from'])} To ${mbDot(b['to'])}</td></tr>'
      '<tr><td class="k">Dated -</td><td class="val">${mbDot(b['billDate'])}</td></tr>'
      '<tr><td class="k">Work Order No</td><td class="val">${_e(_s(b['woNo']).isNotEmpty ? b['woNo'] : '–')}${_s(b['woDate']).isNotEmpty ? '<br><small>Dated :- ${mbDot(b['woDate'])}</small>' : ''}</td></tr>'
      '<tr><td rowspan="2" class="bl-v"><b>${_e(co.toUpperCase())}.</b>${_s(ci['address']).isNotEmpty ? '<br>${_e(ci['address'])}' : ''}</td><td class="k">GSTIN NO -</td><td class="val">${_e(_s(ci['gstin']).isNotEmpty ? ci['gstin'] : '–')}</td></tr>'
      '<tr><td class="k">PAN NO -</td><td class="val">${_e(_s(ci['pan']).isNotEmpty ? ci['pan'] : '–')}</td></tr>'
      '${_s(b['siteAddress']).isNotEmpty ? '<tr class="bl-site"><td colspan="3"><b>SITE ADDRESS :-</b> ${_e(b['siteAddress'])}</td></tr>' : ''}'
      '</tbody></table>'
      '<div class="bl-wc"><span>Work Contract: Rent On Vehicle</span>${monthly.length == 1 ? '<span class="rpm">Rent Per Month : ₹ ${n2(monthly.first)}</span>' : monthly.length > 1 ? '<span class="rpm">Rent Per Month : as per vehicle</span>' : ''}</div>'
      '<table class="bl-t"><thead>'
      '<tr><th>Machine type</th><th>Vehicle No</th><th>Vehicle Type</th>${pmCol ? '<th class="n">Rent / Month</th>' : ''}<th>Shift</th><th>Qty</th><th>Rate</th><th>Amount</th></tr></thead><tbody>${rows.join()}</tbody></table>'
      '<table class="bl-sum"><tbody>${sum.map((x) => '<tr class="r${x.$1}"><td class="c l">${x.$1}</td><td class="t">${x.$2}</td><td class="p">${x.$4}</td><td class="n${x.$1 == netRow ? ' net' : ''}">${cell(x)}</td></tr>').join()}</tbody></table>$corrT</div>'
      '<div class="bl-sign">${signs.map((x) => '<div><span></span><b>${x[0]}</b><small>${x[1]}</small></div>').join()}</div>'
      '</div>';
}

const kDocCss = '<style>'
    '.tx, .dnp { font-family: Arial, sans-serif; color: #000; border: 1.6px solid #111; font-size: 10.5pt; line-height: 1.35; }'
    '.tx table, .dnp table { width: 100%; border-collapse: collapse; table-layout: fixed; } .tx td, .tx th, .dnp td, .dnp th { border: 1px solid #111; padding: 4px 7px; vertical-align: top; text-align: left; background: #fff; color: #000; font-size: inherit; font-weight: 400; white-space: normal; overflow-wrap: anywhere; letter-spacing: 0; text-transform: none; position: static; }'
    '.tx th, .dnp th, .tx td.k { font-weight: 700; }'
    '.tx .n, .dnp .n { text-align: right; white-space: nowrap; font-variant-numeric: tabular-nums; } .tx .c, .dnp .c { text-align: center; }'
    '.tx-name, .dnp-co { text-align: center; font-weight: 700; font-size: 17pt; padding: 7px 6px 5px; border-bottom: 1px solid #111; }'
    '.tx-title, .dnp-title { text-align: center; font-weight: 700; letter-spacing: .06em; padding: 3px; border-bottom: 1px solid #111; background: #EEF1F4; }'
    '.tx th, .dnp th { background: #EEF1F4; font-weight: 700; } .tx .k { font-weight: 700; white-space: nowrap; } .tx small, .dnp small { font-size: 8.5pt; color: #333; display: block; }'
    '.tx .foot .k { white-space: normal; } .tx .sum td { font-weight: 700; } .tx .foot td { border-top: 1.6px solid #111; } .tx-sign { height: 30mm; text-align: center; vertical-align: bottom !important; }'
    '.tx-decl { text-align: center; font-size: 9pt; padding: 5px; border-top: 1px solid #111; } .dnp-sign { display: flex; justify-content: space-between; padding: 22mm 10mm 6px; font-weight: 700; }'
    '.dnp-note { padding: 6px 8px; font-size: 9.5pt; border-top: 1px solid #111; }'
    '.gdn { font-family: Arial, sans-serif; color: #000; font-size: 11pt; line-height: 1.5; padding: 10mm 12mm 4mm; background: #fff; } .gdn p { margin: 0 0 4.5mm; } .gdn-title { font-weight: 700; font-size: 12.5pt; letter-spacing: .02em; margin: 0 0 12mm; }'
    '.gdn .gdn-pt { padding-left: 4mm; } .gdn-f { font-weight: 700; border-bottom: 1px solid #111; padding: 0 1.5mm; } .gdn-sign { margin-top: 10mm; } .gdn-sign p { margin: 0 0 5mm; } .gdn-room { height: 16mm; }'
    '.gdn-line { display: inline-block; min-width: 70mm; border-bottom: 1px solid #111; padding: 0 1.5mm; min-height: 1.3em; vertical-align: bottom; }'
    '</style>';

/// 40000 → "Rupees Forty Thousand Only" (Indian counting: thousand, lakh, crore).
String rupeesWords(Object? n0) {
  var n = r2(_n(n0));
  final neg = n < 0;
  n = n.abs();
  var r = (n + 1e-9).floor();
  var p = ((n - r) * 100 + .5).floor();
  if (p >= 100) {
    r += 1;
    p = 0;
  }
  const a = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  const t = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
  String two(int x) => x < 20 ? a[x] : t[x ~/ 10] + (x % 10 != 0 ? ' ${a[x % 10]}' : '');
  String three(int x) => (x >= 100 ? '${a[x ~/ 100]} Hundred${x % 100 != 0 ? ' ' : ''}' : '') + (x % 100 != 0 ? two(x % 100) : '');
  String words(int x) {
    if (x == 0) return '';
    final out = <String>[];
    final cr = x ~/ 10000000;
    x %= 10000000;
    final lk = x ~/ 100000;
    x %= 100000;
    final th = x ~/ 1000;
    x %= 1000;
    if (cr != 0) out.add('${words(cr)} Crore');
    if (lk != 0) out.add('${two(lk)} Lakh');
    if (th != 0) out.add('${two(th)} Thousand');
    if (x != 0) out.add(three(x));
    return out.join(' ');
  }

  final w = words(r);
  return '${neg ? 'Minus ' : ''}Rupees ${w.isEmpty ? 'Zero' : w}${p != 0 ? ' and ${two(p)} Paise' : ''} Only';
}

String docDash(Object? v) => _blank(v) || _n(v) == 0 ? '-' : n2(v);

/// (3.20.0, Mechanical update-124) The month of a bill ("FOR THE MONTH OF SEPTEMBER 2026") when it is one whole calendar month,
/// else its dates ("FOR THE PERIOD 01.09.2026 TO 15.09.2026") – the web's txPeriod.
String txPeriod(Map b) {
  final f = _s(b['from']), t = _s(b['to']);
  const months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
  final y = int.tryParse(f.length >= 4 ? f.substring(0, 4) : '') ?? 0, mo = int.tryParse(f.length >= 7 ? f.substring(5, 7) : '') ?? 0;
  final last = mo > 0 ? DateTime.utc(y, mo + 1, 0).day : 0;
  if (RegExp(r'^\d{4}-\d{2}-01$').hasMatch(f) && mo <= 12 && t == '${f.substring(0, 8)}${'$last'.padLeft(2, '0')}') return 'FOR THE MONTH OF ${months[mo - 1]} $y';
  return 'FOR THE PERIOD ${mbDot(f)} TO ${mbDot(t)}';
}

/// The party's Tax Invoice to the company – the same figures as the Abstract (no TDS on it).
/// (3.20.0, Mechanical update-124: "tax invoice war debit as nko … fkt month ani tya month chi amount") a bill made from now on
/// (txNet): each vehicle for the month and its amount AFTER its diesel debit – no hours / days / rate, no diesel line. A bill
/// made before keeps its paper as it was.
String taxInvoiceHtml(Map b) {
  final co = _s(b['company']), ci = (b['companyInfo'] as Map?) ?? const {}, v = (b['vendor'] as Map?) ?? const {}, gst = _n(b['gstPct']), half = gst / 2;
  final net = b['txNet'] == true;
  num amt(Map m) => net ? r2(_n(m['amount']) - _n(m['excessAmt'])) : _n(m['amount']);
  final Object? before = net ? r2(_n(b['A']) - _n(b['B'])) : b['A'];
  final less = (net ? 0 : _n(b['B'])) + _n(b['C']), rowTax = gst > 0 && less == 0 && _n(b['D']) > 0;
  final machines = _maps(b['machines']);
  final rows = <String>[];
  for (var i = 0; i < machines.length; i++) {
    final m = machines[i], ls = _maps(m['lines']);
    final lines = net ? <Map>[] : ls.where((l) => !(!_blank(l['monthly']) && l['monthly'] != 0 && ls.length == 1)).toList();
    final detail = net
        ? [txPeriod(b)]
        : lines.map((l) => '${_s(l['item']).isNotEmpty ? '${_up(l['item'])}${_s(l['note']).isNotEmpty ? ' – ${l['note']}' : ''}: ' : (_s(l['note']).isNotEmpty ? '${l['note']}: ' : '')}${fmt(l['qty'])} ${_s(l['unit'])} × ${n2(l['rate'])} = ${n2(l['amount'])}').toList();
    final a = amt(m), tax = rowTax ? r2(a * half / 100) : 0;
    rows.add('<tr><td class="c">${i + 1}</td><td><b>RENT ON VEHICLE ${_e(_nodash(m['no']).toUpperCase())}</b>${_s(m['type']).isNotEmpty ? ' <span>(${_e(_up(m['type']))})</span>' : ''}'
        '${detail.isNotEmpty ? '<small>${detail.map(_e).join('<br>')}</small>' : ''}</td><td class="n">${n2(net ? a : m['amount'])}</td><td class="n">${rowTax ? n2(tax) : '-'}</td><td class="n">${rowTax ? n2(tax) : '-'}</td><td class="n">${n2(r2(a + 2 * tax))}</td></tr>');
  }
  final pct = gst != 0 ? '${fmt(half)}%' : '';
  final sum = <(String, String)>[
    ('Total Amount Before Tax', n2(before)),
    if (_n(b['B']) != 0 && !net) ('Less: Diesel deduction${_s(b['dnNo']).isNotEmpty ? ' (Debit Note ${_e(b['dnNo'])})' : ''}', '− ${n2(b['B'])}'),
    if (_n(b['C']) != 0) ('Less: Other deduction${_s(b['cReason']).isNotEmpty ? ' (${_e(b['cReason'])})' : ''}', '− ${n2(b['C'])}'),
    ('Basic Value', n2(b['D'])),
    ('SGST $pct', docDash(b['F'])),
    ('CGST $pct', docDash(b['E'])),
    ('Total Billing Amt', n2(b['G'])),
    ('Net Cheque Amount', n2(b['G'])),
  ];
  final party = '<b>${_e(co.toUpperCase())}</b>', rev = _n(b['rev']);
  return '$kDocCss<div class="tx"><div class="tx-name">${_e(v['name'] ?? '')}</div><div class="tx-title">TAX INVOICE</div>'
      '<table><colgroup><col style="width:23%"><col style="width:27%"><col style="width:50%"></colgroup><tbody>'
      '<tr><td class="k">INVOICE NO:</td><td><b>${_e('${ci['invPrefix'] ?? ''}${b['billNo'] ?? ''}')}${rev != 0 ? ' (Rev ${b['rev']})' : ''}</b></td><td>${_e(b['woNo'] ?? '')}${_s(b['woDate']).isNotEmpty ? ' &nbsp; Dated :- ${mbDot(b['woDate'])}' : ''}</td></tr>'
      '<tr><td class="k">INVOICE DATE:</td><td><b>${mbDot(b['billDate'])}</b></td><td><b>Period of Service:</b> ${mbDot(b['from'])} To ${mbDot(b['to'])}</td></tr>'
      '<tr><td class="k">Reverse Charge (Y/N):</td><td>N</td><td rowspan="2"><b>Place of Service :</b> Rent On Vehicle</td></tr>'
      '<tr><td class="k">State :</td><td>MAHARASHTRA</td></tr></tbody></table>'
      '<table><colgroup><col style="width:50%"><col style="width:50%"></colgroup><tbody><tr><th class="c">Bill to Party</th><th class="c">Ship to Party</th></tr>'
      '<tr><td>To,<br>$party${_s(ci['address']).isNotEmpty ? '<br>Address : ${_e(ci['address'])}' : ''}<br><b>GST : ${_e(_s(ci['gstin']).isNotEmpty ? ci['gstin'] : '–')}</b></td>'
      '<td>To,<br>$party${_s(b['siteAddress']).isNotEmpty ? '<br>Address : ${_e(b['siteAddress'])}' : ''}<br><b>GST : ${_e(_s(ci['gstin']).isNotEmpty ? ci['gstin'] : '–')}</b></td></tr></tbody></table>'
      '<table><colgroup><col style="width:7%"><col style="width:43%"><col style="width:14%"><col style="width:11%"><col style="width:11%"><col style="width:14%"></colgroup><thead><tr><th class="c">Sr.No</th><th class="c">Description of Work</th><th class="c">Amount</th><th class="c">Add CGST $pct</th><th class="c">Add SGST $pct</th><th class="c">Total Amount</th></tr></thead><tbody>'
      '${rows.join()}<tr class="sum"><td colspan="2" class="c">Total Billing Amount</td><td class="n">${n2(before)}</td><td class="n">-</td><td class="n">-</td><td class="n">${n2(before)}</td></tr></tbody></table>'
      '<table class="foot"><colgroup><col style="width:50%"><col style="width:36%"><col style="width:14%"></colgroup><tbody>'
      '${[for (var i = 0; i < sum.length; i++) '<tr>${i == 0 ? '<td rowspan="${sum.length}"><b>In Word : ${_e(rupeesWords(b['G']))} /-</b></td>' : ''}<td class="k">${sum[i].$1}</td><td class="n"><b>${sum[i].$2}</b></td></tr>'].join()}'
      '<tr><td>${_e(v['name'] ?? '')}${_s(v['address']).isNotEmpty ? '<br>${_e(v['address'])}' : ''}${_s(v['account']).isNotEmpty ? '<br>AC.NO : - ${_e(v['account'])}' : ''}${_s(v['ifsc']).isNotEmpty ? '<br>IFSC CODE :${_e(v['ifsc'])}' : ''}${_s(v['bank']).isNotEmpty ? '<br>BANK : ${_e(v['bank'])}${_s(v['branch']).isNotEmpty ? ', ${_e(v['branch'])}' : ''}' : ''}'
      '${_s(v['pan']).isNotEmpty ? '<br>PAN NO :- ${_e(v['pan'])}' : ''}${_s(v['gst']).isNotEmpty ? '<br>GSTIN :- ${_e(v['gst'])}' : ''}</td><td colspan="2" class="tx-sign"><b>${_e(v['name'] ?? '')}</b><br>Authorised Signature</td></tr>'
      '</tbody></table><div class="tx-decl"><b>Declaration:</b><br>We declare that all particulars shown in the above Tax Invoice are true and correct.<br>All disputes subject to Jurisdiction of Pune</div></div>';
}

/// The Debit Note (diesel) of a bill – only when diesel is deducted (B).
String debitNoteHtml(Map b) {
  if (!(_n(b['B']) > 0)) return '';
  final co = _s(b['company']), ci = (b['companyInfo'] as Map?) ?? const {}, v = (b['vendor'] as Map?) ?? const {};
  var sr = 0;
  final rows = <String>[];
  for (final m in _maps(b['machines'])) {
    final amt = _n(m['excessAmt']);
    if (!(amt > 0)) continue;
    final rate = _n(m['dieselRate']), dq = _n(m['debitQty']), eq = _n(m['excessQty']), first = dq != 0 && eq != 0 ? r2(dq * rate) : amt;
    void add(String what, num q, num a) => rows.add('<tr><td class="c">${++sr}</td><td><b>${_e(_nodash(m['no']).toUpperCase())}</b>${_s(m['type']).isNotEmpty ? ' ${_e(_up(m['type']))}' : ''}</td><td>$what</td><td class="n">${fmt(r2(q))}</td><td class="n">${rate != 0 ? n2(rate) : '-'}</td><td class="n">${n2(a)}</td></tr>');
    if (dq != 0) add('Diesel issued – debit basis', dq, first);
    if (eq != 0) add('Diesel used over the standard average', eq, dq != 0 ? r2(amt - first) : amt);
    if (dq == 0 && eq == 0) add('Diesel deduction', 0, amt);
  }
  final rev = _n(b['rev']), ne = billNoEntry(b), tank = billTank(b);
  return '$kDocCss<div class="dnp"><div class="dnp-co">${_e(co.toUpperCase())}</div><div class="dnp-title">DEBIT NOTE – DIESEL</div>'
      '<table><colgroup><col style="width:50%"><col style="width:20%"><col style="width:30%"></colgroup><tbody>'
      '<tr><td rowspan="4">To,<br><b>${_e(_up(v['name']))}</b>${_s(v['address']).isNotEmpty ? '<br>${_e(v['address'])}' : ''}${_s(v['pan']).isNotEmpty ? '<br>PAN NO :- ${_e(v['pan'])}' : ''}${_s(v['gst']).isNotEmpty ? '<br>GSTIN :- ${_e(v['gst'])}' : ''}</td>'
      '<td><b>Debit Note No</b></td><td><b>${_s(b['dnNo']).isNotEmpty ? _e(b['dnNo']) : '(given when the bill is submitted)'}</b></td></tr>'
      '<tr><td><b>Date</b></td><td>${mbDot(b['billDate'])}</td></tr><tr><td><b>Against RA Bill</b></td><td>${_e(b['billNo'] ?? '')}${rev != 0 ? ' (Rev ${b['rev']})' : ''}</td></tr>'
      '<tr><td><b>Work Period</b></td><td>${mbDot(b['from'])} To ${mbDot(b['to'])}</td></tr>'
      '<tr><td colspan="3"><b>${_e(co.toUpperCase())}</b>${_s(ci['address']).isNotEmpty ? ', ${_e(ci['address'])}' : ''} &nbsp; <b>GSTIN :</b> ${_e(_s(ci['gstin']).isNotEmpty ? ci['gstin'] : '–')}${_s(b['woNo']).isNotEmpty ? ' &nbsp; <b>Work Order :</b> ${_e(b['woNo'])}' : ''}</td></tr></tbody></table>'
      '<table><colgroup><col style="width:7%"><col style="width:25%"><col style="width:32%"><col style="width:11%"><col style="width:11%"><col style="width:14%"></colgroup><thead><tr><th class="c">Sr.No</th><th>Machinery</th><th>Particular</th><th class="c">Qty (Ltr)</th><th class="c">Rate (₹/Ltr)</th><th class="c">Amount</th></tr></thead><tbody>'
      '${rows.join()}<tr><td colspan="5" class="n"><b>Total debit</b></td><td class="n"><b>${n2(b['B'])}</b></td></tr>'
      '<tr><td colspan="6"><b>In Word : ${_e(rupeesWords(b['B']))} /-</b></td></tr></tbody></table>'
      '<div class="dnp-note">This amount is deducted in RA Bill No <b>${_e(b['billNo'] ?? '')}</b> (line B of the Abstract of Bill, "Less – Diesel Deduction").${ne.isNotEmpty ? '<br>It includes diesel issued on days with no Log Book entry: ${_e(ne)}.' : ''}${tank.isNotEmpty ? '<br>Left out: ${_e(tank)}.' : ''}</div>'
      '<div class="dnp-sign"><span>Accepted by – ${_e(v['name'] ?? '')}</span><span>For ${_e(co)}</span></div></div>';
}

/// The Declaration of GST non-enrolment (a party without GST registration) – one of the bill's papers.
String gstDeclHtml(Map b) {
  if (!gstDeclOn(b)) return '';
  final v = (b['vendor'] as Map?) ?? const {}, name = _s(v['name']).trim(), co = _s(b['company']).trim();
  final nos = <String>[];
  for (final m in _maps(b['machines'])) {
    final x = _nodash(m['no']).toUpperCase();
    if (x.isNotEmpty && !nos.contains(x)) nos.add(x);
  }
  final what = 'Rent on vehicle${nos.length > 1 ? 's' : ''}${nos.isNotEmpty ? ' ${nos.join(', ')}' : ''}';
  final entity = RegExp(r'^[A-Z]{3}[CFHATBLJG][A-Z][0-9]{4}[A-Z]$').hasMatch(_s(v['pan']).trim().toUpperCase());
  String f(String t) => '<b class="gdn-f">${_e(t)}</b>';
  String line(String t) => '<span class="gdn-line">${t.isNotEmpty ? '<b>${_e(t)}</b>' : ''}</span>';
  return '$kDocCss<div class="gdn"><div class="gdn-title">DECLARATION OF GST NON-ENROLMENT</div>'
      '<p>Dear Sir/Madam,</p>'
      '<p>Sub: Declaration of non-requirement of registration under the Central/State/UT/Integrated Goods and Services Tax Act, 2017</p>'
      '<p>I/We ${f(name)}, do hereby declare that I/we am/are not registered under the Goods and Services Tax Act, 2017</p>'
      '<p class="gdn-pt">-I/We deal in/supply the category of goods or services ${f(what)} which are exempted under the Goods and Service Tax Act, 2017.</p>'
      '<p class="gdn-pt">-I/We have the annual aggregate turnover below the taxable limit as specified under the Goods and Services Tax Act, 2017.</p>'
      '<p class="gdn-pt">-I/We are yet to register ourselves under the Goods and Services Tax Act, 2017.</p>'
      '<p>I/We hereby also confirm that if anytime during any financial year I/we decide or require or become liable to register under the GST, I/we undertake to provide all the requisite documents and information.</p>'
      '<p>I/We request you to consider this communication as a declaration for not requiring to be registered under the Goods and Service Tax Act, 2017.</p>'
      '<p>I/We hereby also confirm ${f(co.toUpperCase())} that shall not be liable for any loss accrued to me/us, due to any registration default with the GST.</p>'
      '<div class="gdn-sign"><p>Signature of Authorised Signatory:</p><div class="gdn-room"></div>'
      '<p>Name of the Authorised Signatory: ${line(entity ? '' : name)}</p>'
      '<p>Name of Business: ${line(entity ? name : '')}</p>'
      '<p>Date: ${line(mbDot(b['billDate']))}</p>'
      '<p>Stamp/Seal of the business entity:</p><div class="gdn-room"></div></div></div>';
}

/// The papers of one bill as print pages: Abstract, Tax Invoice, GST declaration (a party without GST), Debit Note (when there is one).
String billSheets(Map b, String cls, {String logo = ''}) {
  final dn = debitNoteHtml(b), gd = gstDeclHtml(b);
  return [
    '<section class="billsheet$cls">${billHtml(b, logo: logo)}</section>',
    '<section class="billsheet$cls">${taxInvoiceHtml(b)}</section>',
    if (gd.isNotEmpty) '<section class="billsheet$cls">$gd</section>',
    if (dn.isNotEmpty) '<section class="billsheet$cls">$dn</section>',
  ].join();
}

/// A saved debit note (work charged to a party, or a correction) as printed.
String debitNoteDocHtml(Map n) {
  final ci = (n['companyInfo'] as Map?) ?? const {}, v = (n['vendorInfo'] as Map?) ?? {'name': n['vendor']};
  String pct(Object? x) => _n(x) != 0 ? '${fmt(x)}%' : '';
  final lines = _maps(n['lines']);
  final rows = [for (var i = 0; i < lines.length; i++) '<tr><td class="c">${i + 1}</td><td><b>${_e(lines[i]['machinery'] ?? '')}</b></td><td>${_e(lines[i]['particular'] ?? '')}</td><td class="n">${fmt(lines[i]['qty'])} ${_e(lines[i]['unit'] ?? '')}</td><td class="n">${n2(lines[i]['rate'])}</td><td class="n">${n2(lines[i]['amount'])}</td></tr>'];
  final cn = n['kind'] == 'Correction CN';
  final sum = <(String, String)>[
    ('Amount', n2(n['amount'])),
    if (_n(n['gst']) != 0) ('Add: GST ${pct(n['gstPct'])}', n2(n['gst'])),
    if (_n(n['tds']) != 0) ('Less: TDS ${pct(n['tdsPct'])}', '− ${n2(n['tds'])}'),
    (cn ? 'Total credit' : 'Total debit', n2(n['total'])),
  ];
  final vName = _s(v['name']).isNotEmpty ? v['name'] : n['vendor'];
  return '$kDocCss<div class="dnp"><div class="dnp-co">${_e(_up(n['company']))}</div><div class="dnp-title">${cn ? 'CREDIT NOTE' : 'DEBIT NOTE'}${n['status'] == 'Cancelled' ? ' – CANCELLED' : ''}</div>'
      '<table><colgroup><col style="width:50%"><col style="width:20%"><col style="width:30%"></colgroup><tbody>'
      '<tr><td rowspan="3">To,<br><b>${_e(_up(vName))}</b>${_s(v['address']).isNotEmpty ? '<br>${_e(v['address'])}' : ''}${_s(v['pan']).isNotEmpty ? '<br>PAN NO :- ${_e(v['pan'])}' : ''}${_s(v['gst']).isNotEmpty ? '<br>GSTIN :- ${_e(v['gst'])}' : ''}</td>'
      '<td><b>${cn ? 'Credit' : 'Debit'} Note No</b></td><td><b>${_e(n['no'])}</b></td></tr><tr><td><b>Date</b></td><td>${mbDot(n['date'])}</td></tr>'
      '<tr><td><b>Work Period</b></td><td>${_s(n['from']).isNotEmpty ? '${mbDot(n['from'])} To ${mbDot(_s(n['to']).isNotEmpty ? n['to'] : n['from'])}' : '–'}</td></tr>'
      '<tr><td colspan="3"><b>${_e(_up(n['company']))}</b>${_s(ci['address']).isNotEmpty ? ', ${_e(ci['address'])}' : ''} &nbsp; <b>GSTIN :</b> ${_e(_s(ci['gstin']).isNotEmpty ? ci['gstin'] : '–')}</td></tr></tbody></table>'
      '<table><colgroup><col style="width:7%"><col style="width:22%"><col style="width:33%"><col style="width:13%"><col style="width:11%"><col style="width:14%"></colgroup><thead><tr><th class="c">Sr.No</th><th>Machinery</th><th>Particular</th><th class="c">Qty</th><th class="c">Rate</th><th class="c">Amount</th></tr></thead><tbody>'
      '${rows.join()}${[for (var i = 0; i < sum.length; i++) '<tr><td colspan="5" class="n">${i == sum.length - 1 ? '<b>${sum[i].$1}</b>' : sum[i].$1}</td><td class="n">${i == sum.length - 1 ? '<b>${sum[i].$2}</b>' : sum[i].$2}</td></tr>'].join()}'
      '<tr><td colspan="6"><b>In Word : ${_e(rupeesWords(n['total']))} /-</b></td></tr></tbody></table>'
      '${_s(n['remark']).isNotEmpty ? '<div class="dnp-note">${_e(n['remark'])}</div>' : ''}'
      '<div class="dnp-sign"><span>Accepted by – ${_e(vName ?? '')}</span><span>For ${_e(n['company'] ?? '')}</span></div></div>';
}

/// The page to print: bills (and their Log Books) on A4, as the web's print window. [foot]: the name at the foot of each page.
String billPrintHtml(String title, String pages, {bool withLb = false, String foot = ''}) =>
    '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${_e(title)}</title>'
    '<style>$kPrintCss${foot.isNotEmpty ? '@page { @bottom-left { content: "${(RegExp('sketchline', caseSensitive: false).hasMatch(foot) ? foot.toUpperCase() : foot).replaceAll(RegExp(r'["\\]'), '')}  |  Fleet ERP"; } }' : ''}</style>'
    '<style id="orient">$kOrientP</style></head><body class="rep rep-bill${withLb ? ' rep-lb' : ''}"><div class="sheet">$pages</div></body></html>';
