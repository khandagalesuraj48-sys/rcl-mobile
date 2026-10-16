/* THE DASHBOARD'S RULES (3.5.0, part 4 of the whole web in the app) – what the web's Dashboard works out on its page (Mechanical
 * App.html: setDashRange / rangeText, renderLocations, loadLedger, lbStatus / lbDieselHigh / lbTable, lbPending, dcRender,
 * dailyReport, openOwnership's print) from the server's answers (getDashboard, getStockLedger, logDashboard, pendingLog,
 * getOwnershipDetail …). The figures are the server's; here they are only laid out. */
import 'format.dart';
import 'rdoc.dart';

String _s(dynamic v) => v == null ? '' : '$v';
num _n(dynamic v) => asNum(v) ?? 0;
num r2n(num v) => (v * 100).round() / 100;
List<Map<String, dynamic>> mapsOf(dynamic l) => [for (final x in (l as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];

/// The quick ranges (as the web's setDashRange): today · yesterday · month · lastmonth · all.
(String, String) dashRange(String kind, String today) {
  final t = parseKey(today);
  return switch (kind) {
    'today' => (today, today),
    'yesterday' => (dateKey(t.subtract(const Duration(days: 1))), dateKey(t.subtract(const Duration(days: 1)))),
    'month' => (dateKey(DateTime(t.year, t.month, 1)), today),
    'lastmonth' => (dateKey(DateTime(t.year, t.month - 1, 1)), dateKey(DateTime(t.year, t.month, 0))),
    _ => ('', ''),
  };
}

/// Which quick range the dates are ('' = none).
String dashWhich(String from, String to, String today) {
  for (final k in ['all', 'today', 'yesterday', 'month', 'lastmonth']) {
    final r = dashRange(k, today);
    if (r.$1 == from && r.$2 == to) return k;
  }
  return '';
}

String rangeText(String from, String to) {
  if (from.isEmpty && to.isEmpty) return 'All dates';
  if (from.isNotEmpty && to.isNotEmpty) return from == to ? showDate(from) : '${showDate(from)} to ${showDate(to)}';
  return from.isNotEmpty ? 'From ${showDate(from)}' : 'Up to ${showDate(to)}';
}

/// The Log Book dashboard's quick ranges (as the web's lbRange): month · lastmonth · 7 (the last 7 days).
(String, String) lbRange(String kind, String today) {
  final t = parseKey(today);
  if (kind == 'month') return ('${today.substring(0, 8)}01', today);
  if (kind == 'lastmonth') return (dateKey(DateTime(t.year, t.month - 1, 1)), dateKey(DateTime(t.year, t.month, 0)));
  return (dateKey(t.subtract(const Duration(days: 6))), today);
}

const kOwnTone = {'Own': 0xFFF59E0B, 'Rental': 0xFF3B82F6, 'Hired': 0xFFA855F7, 'Debit': 0xFFEF4444, 'Other': 0xFF94A3B8, 'Not in Master': 0xFF64748B};

/* ---------------- stock by location ---------------- */
class LocCard {
  LocCard(this.title, this.now, this.lines, this.ok, this.check);
  final String title, check;
  final num now;
  final List<(String, num, String)> lines; // words, litres, kind: '' · plus · minus · tot · note
  final bool ok;
}

/// The cards of "Diesel stock – combined and by location" (as the web's renderLocations).
List<LocCard> locationCards(List<Map<String, dynamic>> list, String from, String to, List<String> places) {
  if (list.isEmpty) return [];
  final startTxt = from.isNotEmpty ? 'Opening stock on ${showDate(from)}' : 'Opening stock (at the very start)';
  final endTxt = 'Closing stock on ${to.isNotEmpty ? showDate(to) : 'today'}';
  num sum(String k) => r2n(list.fold<num>(0, (a, x) => a + _n(x[k])));
  final c = {'opening': sum('opening'), 'inward': sum('inward'), 'moved': sum('tout'), 'issued': sum('issued'), 'closing': sum('closing'), 'current': sum('current')};
  final cCalc = r2n(c['opening']! + c['inward']! - c['issued']!), cOk = (cCalc - c['closing']!).abs() < 0.01;
  final vtr = places.length == 2 && places.contains('Dispenser') && places.contains('VTR Store');
  String others(String l) => places.where((x) => x != l).join(' / ').isEmpty ? 'other location' : places.where((x) => x != l).join(' / ');
  return [
    LocCard('Combined – all locations', c['current']!, [
      (startTxt, c['opening']!, ''),
      ('+ Received from pump (inward)', c['inward']!, 'plus'),
      ('− Issued to machinery', c['issued']!, 'minus'),
      ('= $endTxt', c['closing']!, 'tot'),
      (vtr ? 'Moved Dispenser ↔ VTR Store (inside company, not added or removed)' : 'Moved between the diesel places (inside company, not added or removed)', c['moved']!, 'note'),
    ], cOk, cOk ? 'Opening + Received − Issued = Closing' : 'Does not add up: ${fmtNum(cCalc)} vs ${fmtNum(c['closing'])}'),
    for (final x in list)
      (() {
        final calc = r2n(_n(x['opening']) + _n(x['inward']) + _n(x['tin']) - _n(x['tout']) - _n(x['issued'])), ok = (calc - _n(x['closing'])).abs() < 0.01;
        return LocCard(_s(x['loc']), _n(x['current']), [
          (startTxt, _n(x['opening']), ''),
          ('+ Received from pump (inward)', _n(x['inward']), 'plus'),
          ('+ Received from ${others(_s(x['loc']))}', _n(x['tin']), 'plus'),
          ('− Sent to ${others(_s(x['loc']))}', _n(x['tout']), 'minus'),
          ('− Issued to machinery', _n(x['issued']), 'minus'),
          ('= $endTxt', _n(x['closing']), 'tot'),
        ], ok, ok ? 'Opening + Received − Sent − Issued = Closing' : 'Does not add up: ${fmtNum(calc)} vs ${fmtNum(x['closing'])}');
      })(),
  ];
}

/// The day-wise stock table (as the web's loadLedger): one location – with its transfers –, or all together.
RTable ledgerTable(Map<String, dynamic> l, String loc, List<String> places) {
  final other = loc.isEmpty ? '' : (places.where((x) => x != loc).join(' / ').isEmpty ? 'other location' : places.where((x) => x != loc).join(' / '));
  final cols = loc.isNotEmpty
      ? [('opening', 'Opening stock'), ('inward', '+ Received from pump'), ('tin', '+ Received from $other'), ('tout', '− Sent to $other'), ('issued', '− Issued to machinery'), ('closing', 'Closing stock')]
      : [('opening', 'Opening stock'), ('inward', '+ Received from pump'), ('issued', '− Issued to machinery'), ('closing', 'Closing stock')];
  final rows = mapsOf(l['rows']);
  num tot(String k) => k == 'opening' ? (rows.isEmpty ? 0 : _n(rows.first['opening'])) : k == 'closing' ? (rows.isEmpty ? 0 : _n(rows.last['closing'])) : r2n(rows.fold<num>(0, (s, x) => s + _n(x[k])));
  return RTable(
    sheet: 'Day-wise stock',
    head: ['Date', for (final c in cols) c.$2],
    numCols: {for (var i = 1; i <= cols.length; i++) i},
    rows: [
      for (final x in rows.reversed)
        RRow([RCell(showDate(_s(x['date']))), for (final c in cols) RCell(fmtNum(_n(x[c.$1])), n: true, bold: c.$1 == 'closing', tone: c.$1 == 'closing' && _n(x[c.$1]) < 0 ? 'bad' : '', value: _n(x[c.$1]))]),
    ],
    foot: rows.isEmpty ? const [] : [RRow([const RCell('Whole period'), for (final c in cols) RCell(fmtNum(tot(c.$1)), n: true, value: tot(c.$1))])],
  );
}

String ledgerHelp(String loc, List<String> places) {
  final vtr = places.length == 2 && places.contains('Dispenser') && places.contains('VTR Store');
  final other = places.where((x) => x != loc).join(' / ');
  if (loc.isNotEmpty) return 'Stock of $loc only. "Received from / Sent to" are diesel transfers between $loc and ${other.isEmpty ? 'other location' : other}. Opening + Received − Sent − Issued = Closing.';
  return vtr
      ? 'All locations together. Opening + Received from pump − Issued = Closing. Transfers between Dispenser and VTR Store are inside the company and do not change this total.'
      : 'All locations together. Opening + Received from pump − Issued = Closing. Transfers between the diesel places are inside the company and do not change this total.';
}

/// A tank: its stock, size, how full, low or not (as the web's renderTanks).
({num qty, num cap, double p, bool low, String chip, String note}) tankOf(Map<String, dynamic> byLoc, Map<String, dynamic> tanks, String place, int index) {
  final caps = (tanks['caps'] as Map?) ?? const {}, low = _n(tanks['low']);
  final qty = _n(byLoc[place]);
  final own = tanks['own'] == true;
  final cap = _n(caps[place]) > 0 ? _n(caps[place]) : (own || index == 0 ? 10000 : 2000);
  final p = cap > 0 ? (qty / cap).clamp(0, 1).toDouble() : 0.0;
  final isLow = qty < low;
  return (qty: qty, cap: cap, p: p, low: isLow, chip: isLow ? 'Low stock' : p >= .5 ? 'Good' : 'Normal', note: isLow ? 'Below ${fmtNum(low)} Ltr – refill soon' : 'Turns red below ${fmtNum(low)} Ltr');
}

/* ---------------- the Log Book dashboard ---------------- */
/// "Working" / "Idle n days" / "No work" (and its tone), as the web's lbStatus.
(String, String, String) lbStatus(Map<String, dynamic> m) {
  if (_n(m['workDays']) == 0) return ('none', 'No work', 'bad');
  if (_n(m['idleFor']) >= 3) return ('idle', 'Idle ${m['idleFor']} days', 'warn');
  return ('ok', 'Working', 'good');
}

bool lbDieselHigh(Map<String, dynamic> m) => _s(m['extraPct']).isNotEmpty && _n(m['extraPct']) > 10 && _n(m['extra']) > 10;

const kLbChips = [('all', 'All'), ('idle', 'Idle / no work'), ('diesel', 'Diesel high'), ('low', 'Worked less than half the days')];

bool lbChipHas(Map<String, dynamic> m, String chip) => switch (chip) {
      'idle' => lbStatus(m).$1 != 'ok',
      'diesel' => lbDieselHigh(m),
      'low' => _n(m['util']) < 50,
      _ => true,
    };

/// The machinery of a chip (only those that could work), the most used first.
List<Map<String, dynamic>> lbMachines(Map<String, dynamic> d, String chip) => mapsOf(d['machines']).where((m) => _n(m['avail']) > 0 && lbChipHas(m, chip)).toList()
  ..sort((a, b) {
    final u = _n(b['util']).compareTo(_n(a['util']));
    return u != 0 ? u : (_n(b['hrs']) + _n(b['km'])).compareTo(_n(a['hrs']) + _n(a['km']));
  });

String lbN(dynamic x, [int dp = 0]) => fmtNum(_n(x), maxDecimals: dp);

/// "▲ 12% vs the period before" ('' = nothing to compare), and whether it is good.
(String, bool) lbCmp(dynamic a, dynamic b, bool goodUp) {
  final x = _n(a), y = _n(b);
  if (y == 0) return ('', true);
  final pct = ((x - y) / y.abs() * 100).round();
  if (pct == 0) return ('same as the period before', true);
  return ('${pct > 0 ? '▲ ' : '▼ '}${pct.abs()}% vs the period before', goodUp ? pct > 0 : pct < 0);
}

String lbWork(Map<String, dynamic> m, String join) => [if (_n(m['hrs']) > 0) '${lbN(m['hrs'], 1)} hrs', if (_n(m['km']) > 0) '${lbN(m['km'])} km', if (_n(m['trips']) > 0) '${lbN(m['trips'])} trips'].join(join);
String lbPerDay(Map<String, dynamic> m) {
  final t = [if (_n(m['hrs']) > 0) '${lbN(m['hrsPerDay'], 1)} hrs', if (_n(m['km']) > 0) '${lbN(m['kmPerDay'])} km', if (_n(m['trips']) > 0) '${lbN(m['tripsPerDay'], 1)} trips'].join(' · ');
  return t.isEmpty ? '–' : t;
}

/* pending Log Book: one card per machinery with its dates */
const kPendChips = [('all', 'All'), ('today', 'Today'), ('d1', 'Yesterday'), ('d7', '2–7 days old'), ('old', 'More than 7 days old')];
String pendBand(int n) => n <= 0 ? 'today' : n == 1 ? 'd1' : n <= 7 ? 'd7' : 'old';

class PendCard {
  PendCard(this.no, this.type, this.owner);
  final String no, type, owner;
  final dates = <String>[];
  int oldest = 0;
}

/// The pending items of the filters (ownership of Asset Master, vendor, search), counted per band, and the cards of a chip.
({Map<String, int> counts, List<PendCard> cards}) pendingCards(Map<String, dynamic> p, {String own = '', String vendor = '', String q = '', String chip = 'all', required String Function(String no) ownOf}) {
  final today = _s(p['asOf']);
  int age(String d) => parseKey(today).difference(parseKey(d)).inDays;
  final ven = vendor.toUpperCase(), qq = q.trim().toUpperCase();
  final items = mapsOf(p['items'])
      .where((x) => (own.isEmpty || own.split(',').contains(ownOf(_s(x['no'])))) && (ven.isEmpty || _s(x['owner']).toUpperCase() == ven) && (qq.isEmpty || '${x['no']} ${x['owner'] ?? ''} ${x['type'] ?? ''}'.toUpperCase().contains(qq)))
      .toList();
  final counts = {for (final c in kPendChips) c.$1: items.where((x) => c.$1 == 'all' || pendBand(age(_s(x['date']))) == c.$1).length};
  final by = <String, PendCard>{};
  for (final x in items.where((x) => chip == 'all' || pendBand(age(_s(x['date']))) == chip)) {
    by.putIfAbsent(_s(x['no']), () => PendCard(_s(x['no']), _s(x['type']), _s(x['owner']))).dates.add(_s(x['date']));
  }
  final cards = by.values.toList();
  for (final c in cards) {
    c.dates.sort();
    c.oldest = age(c.dates.first);
  }
  cards.sort((a, b) => b.oldest != a.oldest ? b.oldest - a.oldest : b.dates.length - a.dates.length);
  return (counts: counts, cards: cards);
}

/* ---------------- Own vehicle compliance (the web's dcRender) ---------------- */
List<Map<String, dynamic>> ownPapersDue(Map<String, dynamic> cp) {
  final docs = [for (final x in (cp['docs'] as List? ?? const [])) '$x'];
  final out = <Map<String, dynamic>>[];
  for (final m in mapsOf(cp['machines']).where((m) => m['ownership'] == 'Own')) {
    for (final k in docs) {
      final x = ((m['docs'] as Map?)?[k] as Map?) ?? const {};
      if (x['s'] == 'expired' || x['s'] == 'due') out.add({'no': m['no'], 'type': m['type'], 'doc': k, 'v': x['v'], 's': x['s'], 'days': _n(x['days'])});
    }
  }
  out.sort((a, b) => (a['days'] as num).compareTo(b['days'] as num));
  return out;
}

/* ---------------- the prints ---------------- */
/// "Diesel Issue Report – <ownership>" (the ownership pop-up's print).
RDoc ownershipDoc(Map<String, dynamic> d) {
  final rows = mapsOf(d['rows']), total = (d['total'] as Map?) ?? const {};
  return RDoc(
    title: 'Diesel Issue Report – ${d['ownership']}',
    file: 'Diesel_Issue_${d['ownership']}',
    period: rangeText(_s(d['from']), _s(d['to'])),
    blocks: [
      RTable(sheet: 'Diesel issued', head: const ['Sr', 'Machinery Number / Name', 'Type of Machinery', 'Owner Name', 'Entries', 'First issue', 'Last issue', 'Diesel (Ltr)'], numCols: const {0, 4, 7}, empty: 'No diesel issued to ${d['ownership']} machinery in this period.', rows: [
        for (final (i, r) in rows.indexed)
          RRow([RCell('${i + 1}', n: true, value: i + 1), RCell(_s(r['no'])), RCell(_s(r['type'])), RCell(_s(r['owner'])), RCell('${r['entries']}', n: true, value: _n(r['entries'])), RCell(showDate(_s(r['first']))), RCell(showDate(_s(r['last']))), RCell(fmtNum(_n(r['qty'])), n: true, value: _n(r['qty']))]),
      ], foot: rows.isEmpty ? const [] : [
        RRow([RCell('Total – ${rows.length} machines', span: 4), RCell('${total['entries'] ?? 0}', n: true), const RCell('', span: 2), RCell('${fmtNum(_n(total['qty']))} Ltr', n: true, value: _n(total['qty']))]),
      ]),
    ],
  );
}

String _e(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

const kDayStatus = ['Idle', 'Holiday', 'Breakdown'];
bool needsLogBook(Map<String, dynamic> m) => m['supply'] != 'Debit Basis' && m['ownership'] != 'Debit' && m['ownership'] != 'Other';

/// The Daily Report – one day on one page (as the web's dailyReport): stock of each place, received, issued, the Log Book of the
/// day, what to look at (diesel but no Log Book, active machinery without an entry, breakdowns). An A4 page to print or keep as PDF.
String dailyReportHtml({
  required String day,
  required String company,
  required String site,
  required String madeAt,
  required String madeBy,
  required Map<String, dynamic> dash,
  required List<Map<String, dynamic>> issues,
  required List<Map<String, dynamic>> inwards,
  required List<Map<String, dynamic>> logs,
  required Map<String, dynamic> breakdowns,
  required List<Map<String, dynamic>> activeMachines, // on site that day and needing a Log Book
  String itemsOf(Map<String, dynamic> r) = itemQtyText,
}) {
  String n(dynamic v) => v == null || v == '' ? '' : fmtNum(_n(v));
  String dash0(dynamic v) => n(v).isEmpty ? '–' : n(v); // (as the web: a blank is –, a 0 is 0)
  num sum(List<Map<String, dynamic>> a, String k) => r2n(a.fold<num>(0, (t, x) => t + _n(x[k])));
  String th(List<(String, bool)> a) => '<tr>${a.map((x) => '<th${x.$2 ? ' class="n"' : ''}>${x.$1}</th>').join()}</tr>';
  String td(Object v, [bool num = false]) => '<td${num ? ' class="n"' : ''}>$v</td>';
  String sec(String title, String body, [String note = '']) => '<div class="dr-sec"><h3>$title${note.isNotEmpty ? ' <small>$note</small>' : ''}</h3>$body</div>';
  String none(String t) => '<p class="dr-none">$t</p>';
  int byNo(Map<String, dynamic> a, Map<String, dynamic> b) => _s(a['no']).compareTo(_s(b['no']));
  final iss = [...issues]..sort(byNo), lg = [...logs]..sort(byNo);
  // 1. diesel stock
  final locs = mapsOf(dash['locations']).where((x) => ['opening', 'inward', 'tin', 'tout', 'issued', 'closing'].any((k) => _n(x[k]) != 0)).toList();
  final stock = locs.isEmpty
      ? none('No diesel stock.')
      : '<table>${th([('Location', false), ('Opening', true), ('Received', true), ('Transfer in', true), ('Transfer out', true), ('Issued', true), ('Closing', true)])}'
          '${locs.map((x) => '<tr>${td(_e(_s(x['loc'])))}${td(n(x['opening']), true)}${td(dash0(x['inward']), true)}${td(dash0(x['tin']), true)}${td(dash0(x['tout']), true)}${td(dash0(x['issued']), true)}${td('<b>${n(x['closing'])}</b>', true)}</tr>').join()}'
          '<tr class="tot">${td('Total')}${td(n(sum(locs, 'opening')), true)}${td(n(sum(locs, 'inward')), true)}${td(n(sum(locs, 'tin')), true)}${td(n(sum(locs, 'tout')), true)}${td(n(sum(locs, 'issued')), true)}${td(n(sum(locs, 'closing')), true)}</tr></table>';
  // 2. received
  final rec = inwards.isEmpty
      ? none('No diesel received.')
      : '<table>${th([('Received at', false), ('Pump', false), ('Bill No', false), ('Qty (L)', true), ('Rate', true), ('Amount (₹)', true)])}'
          '${inwards.map((x) => '<tr>${td(_e(_s(x['location'])))}${td(_e(_s(x['pump']).isNotEmpty ? _s(x['pump']) : x['open'] == true ? 'Opening stock' : ''))}${td(_e(_s(x['billNo'])))}${td(n(x['qty']), true)}${td(n(x['rate']), true)}${td(n(x['amount']), true)}</tr>').join()}'
          '<tr class="tot">${td('Total')}${td('')}${td('')}${td(n(sum(inwards, 'qty')), true)}${td('')}${td(n(sum(inwards, 'amount')), true)}</tr></table>';
  // 3. issued
  String reading(Map<String, dynamic> x) {
    final t = [if (_s(x['kmReading']).isNotEmpty) '${n(x['kmReading'])} km', if (_s(x['hrReading']).isNotEmpty) '${n(x['hrReading'])} hr'].join(' / ');
    return t.isNotEmpty ? t : (_s(x['meter']).isNotEmpty ? _e(_s(x['meter'])) : '–');
  }

  final issT = iss.isEmpty
      ? none('No diesel issued.')
      : '<table>${th([('#', false), ('Machinery', false), ('Type', false), ('Owner', false), ('Shift', false), ('From', false), ('Qty (L)', true), ('Reading', true), ('Driver', false)])}'
          '${[for (final (i, x) in iss.indexed) '<tr>${td(i + 1)}${td('<b>${_e(_s(x['no']))}</b>')}${td(_e(_s(x['type'])))}${td(_e(_s(x['owner'])))}${td(_e(_s(x['shift'])))}${td(_e(_s(x['source'])))}${td(n(x['qty']), true)}${td(reading(x), true)}${td(_e(_s(x['driver'])))}</tr>'].join()}'
          '<tr class="tot">${td('')}${td('Total – ${iss.length} issue(s), ${iss.map((x) => x['no']).toSet().length} machinery')}${td('')}${td('')}${td('')}${td('')}${td(n(sum(iss, 'qty')), true)}${td('')}${td('')}</tr></table>';
  // 4. Log Book
  String st(Map<String, dynamic> r) => _s(r['mode']).isNotEmpty ? _s(r['mode']) : _s(r['unit']);
  bool isSt(Map<String, dynamic> r) => kDayStatus.contains(st(r));
  String work(Map<String, dynamic> r) => isSt(r)
      ? '<b>${_e(st(r))}</b>'
      : [if (_s(r['wkm']).isNotEmpty) '${n(r['wkm'])} km', if (_s(r['whr']).isNotEmpty) '${n(r['whr'])} hr', if (_n(r['trip']) > 0) '${n(r['trip'])} trips', if (st(r) == 'Day') 'day'].join(' / ') + (st(r) == 'No reading' ? ' <small>(est.)</small>' : '');
  String rd(Map<String, dynamic> r) {
    if (isSt(r) || st(r) == 'No reading') return '–';
    final t = [if (_s(r['okm']).isNotEmpty) '${n(r['okm'])} → ${n(r['ckm'])}', if (_s(r['ohr']).isNotEmpty) '${n(r['ohr'])} → ${n(r['chr'])}', if (_s(r['tStart']).isNotEmpty) '${_e(_s(r['tStart']))} – ${_e(_s(r['tEnd']))}'].join('<br>');
    return t.isEmpty ? '–' : t;
  }

  String marks(Map<String, dynamic> r) {
    final t = [if (_s(r['meter']).isNotEmpty) _s(r['meter']).toUpperCase(), if (_s(r['debitTo']).isNotEmpty) 'DEBIT TO ${_s(r['debitTo']).toUpperCase()}${_s(r['debitRate']).isNotEmpty ? ' @ ${fmtNum(_n(r['debitRate']))}' : ''}'];
    return t.isEmpty ? '' : '<b>${_e(t.join(' · '))}</b>${_s(r['work']).isNotEmpty || _s(r['remark']).isNotEmpty ? ' – ' : ''}';
  }

  final lbT = lg.isEmpty
      ? none('No Log Book entry for this day.')
      : '<table>${th([('#', false), ('Machinery', false), ('Type', false), ('Owner', false), ('Shift', false), ('Reading (Start → Close)', true), ('Work', true), ('Diesel (L)', true), ('Chainage', false), ('Work done', false)])}'
          '${[for (final (i, r) in lg.indexed) '<tr>${td(i + 1)}${td('<b>${_e(_s(r['no']))}</b>')}${td(_e(_s(r['type'])))}${td(_e(_s(r['owner'])))}${td(_e(_s(r['shift'])))}${td(rd(r), true)}${td(work(r), true)}${td(dash0(r['qty']), true)}${td(_e([r['chFrom'], r['chTo']].map(_s).where((x) => x.isNotEmpty).join(' – ')))}${td('${marks(r)}${itemsOf(r).isNotEmpty ? '<b>${_e(itemsOf(r))}</b> ' : ''}${_e(_s(r['work']).isNotEmpty ? _s(r['work']) : _s(r['remark']))}')}</tr>'].join()}</table>';
  int cnt(String k) => lg.where((r) => st(r) == k).length;
  final worked = lg.where((r) => !isSt(r)).length;
  final lbNote = lg.isEmpty ? '' : 'worked $worked · idle ${cnt('Idle')} · holiday ${cnt('Holiday')} · breakdown ${cnt('Breakdown')}';
  // 5. to look at
  final logged = lg.map((r) => _s(r['no'])).toSet();
  final fuelled = iss.map((x) => _s(x['no'])).toSet().toList();
  final noLog = fuelled.where((x) => !logged.contains(x)).toList();
  final noEntry = activeMachines.where((m) => !logged.contains(_s(m['id']))).map((m) => _s(m['id'])).toList();
  final brk = [
    for (final x in mapsOf(breakdowns['onDate'] ?? breakdowns['rows']))
      '<b>${_e(_s(x['no']).isNotEmpty ? _s(x['no']) : _s(x['machinery']))}</b>${_s(x['reason']).isNotEmpty || _s(x['remark']).isNotEmpty ? ' – ${_e(_s(x['reason']).isNotEmpty ? _s(x['reason']) : _s(x['remark']))}' : ''}${_s(x['since']).isNotEmpty || _s(x['from']).isNotEmpty ? ' <small>(since ${_e(showDate(_day10(_s(x['since']).isNotEmpty ? _s(x['since']) : _s(x['from']))))})</small>' : ''}',
  ];
  final look = '<ul class="dr-look">'
      '<li><b>Diesel issued but no Log Book entry (${noLog.length}):</b> ${noLog.isEmpty ? 'none' : _e(noLog.join(', '))}</li>'
      '<li><b>Active machinery without a Log Book entry (${noEntry.length} of ${activeMachines.length}):</b> ${noEntry.isEmpty ? 'none' : _e(noEntry.take(80).join(', ')) + (noEntry.length > 80 ? ' … +${noEntry.length - 80}' : '')}</li>'
      '<li><b>Under breakdown (${brk.length}):</b> ${brk.isEmpty ? 'none' : brk.join('; ')}</li></ul>';
  String kp(String v, String l) => '<div><b>$v</b><span>$l</span></div>';
  const css = '<style>@page{size:A4 portrait;margin:10mm}body{font-family:Arial,Helvetica,"Noto Sans Devanagari",sans-serif;color:#111;margin:0}'
      '.dr h2{margin:0 0 2px;font-size:17px}.dr .dr-sub{color:#555;font-size:11.5px;margin-bottom:8px}.dr-kpi{display:flex;gap:8px;margin:8px 0 4px}.dr-kpi div{flex:1;border:1px solid #bbb;border-radius:6px;padding:6px 8px}.dr-kpi b{display:block;font-size:15px}.dr-kpi span{font-size:10.5px;color:#555}'
      '.dr-sec{margin-top:10px;break-inside:auto}.dr-sec h3{font-size:12.5px;margin:0 0 4px;border-bottom:1.5px solid #222;padding-bottom:2px}.dr-sec h3 small{font-weight:400;color:#555}.dr table{width:100%;border-collapse:collapse;font-size:10.5px}.dr th,.dr td{border:1px solid #999;padding:2.5px 5px;text-align:left;vertical-align:top}'
      '.dr th{background:#eee}.dr .n{text-align:right;white-space:nowrap}.dr td:nth-child(2),.dr td:nth-child(5){white-space:nowrap}.dr tr.tot td{font-weight:700;background:#f4f4f4}.dr-none{color:#666;font-size:11px;margin:2px 0}.dr-look{margin:2px 0 0 16px;padding:0;font-size:11px}.dr-look li{margin:2px 0}'
      '.dr-sign{display:flex;justify-content:space-between;margin-top:34px;font-size:11px}.dr-sign span{border-top:1px solid #333;padding-top:3px;min-width:150px;text-align:center}</style>';
  return '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Daily Report ${showDate(day)}</title>$css</head><body><div class="dr">'
      '<h2>${_e(company)} – Daily Report</h2><div class="dr-sub">${_e(showDate(day))} · ${_e(site)} · made ${_e(madeAt)} by ${_e(madeBy)}</div>'
      '<div class="dr-kpi">${kp('${n(sum(locs, 'closing'))} L', 'Diesel stock at close')}${kp('${n(sum(inwards, 'qty'))} L', 'Diesel received')}${kp('${n(sum(iss, 'qty'))} L', 'Diesel issued (${iss.length})')}${kp('$worked / ${lg.length}', 'Machinery worked / entries')}${kp('${noLog.length + noEntry.length}', 'To look at')}</div>'
      '${sec('1. Diesel stock', stock)}${sec('2. Diesel received', rec)}${sec('3. Diesel issued', issT)}${sec('4. Log Book', lbT, lbNote)}${sec('5. To look at', look)}'
      '<div class="dr-sign"><span>Prepared by</span><span>Site In-charge</span><span>Project Manager</span></div></div></body></html>';
}

String _day10(String v) => v.length >= 10 ? v.substring(0, 10) : v;

/// The items of a saved entry as text: "Bucket 5 hr · Breaker 3 hr" (as the web's itemQtyText).
String itemQtyText(Map<String, dynamic> r) {
  String kind(String b) => b == 'Per Hour' ? 'hr' : b == 'Per KM' ? 'km' : b == 'Per Trip' ? 'trip' : 'day';
  const word = {'hr': 'hr', 'km': 'km', 'trip': 'trips'};
  final dayItems = mapsOf(r['boqItems']).where((it) => kind(_s(it['basis'])) == 'day').length;
  return mapsOf(r['itemQty']).where((x) => x['k'] != 'day' || dayItems > 1).map((x) => '${x['n']}${x['k'] == 'day' ? '' : ' ${fmtNum(_n(x['q']))} ${word[x['k']] ?? ''}'}').join(' · ');
}
