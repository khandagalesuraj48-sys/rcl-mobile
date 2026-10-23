/* THE LOG BOOK PRINT (3.6.0) – the site's monthly Log Book + bill, one page per machinery, as the web prints it (App.html
 * "LOG BOOK PRINT": logSheetsBuild, lbWorkRows, lbPrintWork, lbMarks, tankLeft, dualAvg, itemDaySegs, LB_FMT_COLS): the centred
 * capital heading with the period, the readings and diesel of every entry (an entry with two or more works – a row for each), the
 * machinery's own Log Book format (A–I), and the bill part (working days and nights, BOQ rates, excess diesel, TDS, GST, net
 * payable) with the five signatures. "View format" (Log Book Format) prints the same with SAMPLE lines. The phone prints it. */
import 'dash.dart' show itemQtyText, kDayStatus;
import 'format.dart' show showDate;
import 'log_edit.dart' show r2, js, slotsParse, slotsGap, slotMin, tMin;
import 'session.dart' show hasKm, hasHr, kNoReading;

/// As the web's esc(): & < > " ' only.
String _e(Object? s) => (s == null ? '' : '$s').replaceAllMapped(RegExp('[&<>"\']'), (m) => const {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[m[0]]!);
String _s(Object? v) => v == null ? '' : '$v';
bool _blank(Object? v) => v == null || v == '';
num _n(Object? v) => v is num ? v : (num.tryParse(_s(v).trim()) ?? 0);
String _up(Object? t) => _s(t).toUpperCase();
String _key(Object? no) => _s(no).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Indian grouping (1,23,456.5) with [minD]–[maxD] decimals – as the web's toLocaleString('en-IN').
String grp(num v, {int minD = 0, int maxD = 2}) {
  var s = v.abs().toStringAsFixed(maxD);
  if (s.contains('.')) {
    final w = s.split('.')[0];
    var f = s.split('.')[1];
    while (f.length > minD && f.endsWith('0')) {
      f = f.substring(0, f.length - 1);
    }
    s = f.isEmpty ? w : '$w.$f';
  }
  final parts = s.split('.');
  var whole = parts[0];
  if (whole.length > 3) {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final g = <String>[];
    while (rest.length > 2) {
      g.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) g.insert(0, rest);
    whole = '${g.join(',')},$last3';
  }
  final out = whole + (parts.length > 1 ? '.${parts[1]}' : '');
  return v < 0 && RegExp(r'[1-9]').hasMatch(out) ? '-$out' : out;
}

/// The web's fmt: '' for nothing, else 1,234.5.
String fmt(Object? v) => _blank(v) ? '' : grp(_n(v));
String n2(Object? v) => grp(_n(v), minD: 2, maxD: 2);

/// Meter readings without commas, as on the meter.
String plain(Object? v) => _blank(v) ? '' : js(r2(_n(v)));

/// The keys of a map in the order the browser gives them (whole numbers first, in order; then the others as they came).
List<String> jsKeys(Map m) {
  final ks = m.keys.map((k) => '$k').toList(), idx = ks.where((k) => RegExp(r'^(0|[1-9]\d{0,8})$').hasMatch(k)).toList()..sort((a, b) => int.parse(a) - int.parse(b));
  return [...idx, ...ks.where((k) => !idx.contains(k))];
}

/// A natural order of machinery numbers ("EX-2" before "EX-10").
int natCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final x = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList(), y = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final p = int.tryParse(x[i]), q = int.tryParse(y[i]);
    final c = p != null && q != null ? p.compareTo(q) : x[i].compareTo(y[i]);
    if (c != 0) return c;
  }
  return x.length - y.length;
}

String _dateAdd(String dk, int n) {
  final p = dk.split('-').map(int.parse).toList(), d = DateTime(p[0], p[1], p[2] + n);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

int _dim(String d) => DateTime(int.parse(d.substring(0, 4)), int.parse(d.substring(5, 7)) + 1, 0).day;
const _months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];

String _mode(Map r) => _s(r['mode']).isNotEmpty ? _s(r['mode']) : _s(r['unit']);
num dayPart(Map r) => r['half'] == true || _n(r['half']) == .5 ? .5 : 1;
bool _isHol(Map r) => _mode(r) == 'Holiday' || _mode(r) == 'Breakdown';

// ---------- times of an entry ----------
List<List<String>> slotsOf(Map r) {
  final sp = slotsParse(r['tSlots']);
  return sp.isNotEmpty ? sp : (_s(r['tStart']).isNotEmpty || _s(r['tEnd']).isNotEmpty ? [[_s(r['tStart']), _s(r['tEnd'])]] : []);
}

/// The break typed (a split's saved break holds the gaps between its times too).
Object slotsBreak(Map r) {
  if (_blank(r['tBrk'])) return '';
  final b = _n(r['tBrk']), sl = slotsParse(r['tSlots']), typed = b - slotsGap(sl) > 0 ? b - slotsGap(sl) : 0;
  return sl.length > 1 && typed == 0 ? '' : typed;
}

Object slotsHrs(List<List<String>> sl, num brk) {
  if (sl.isEmpty) return '';
  var mins = 0;
  for (final x in sl) {
    final d = slotMin(x[0], x[1]);
    if (d == null) return '';
    mins += d;
  }
  mins -= (brk > 0 ? brk : 0).toInt();
  return mins > 0 ? r2(mins / 60) : 0;
}

/// Who the work is debited to and the meter note, in front of the work description.
String lbMarks(Map r) {
  final t = [if (_s(r['meter']).isNotEmpty) _up(r['meter']), if (_s(r['debitTo']).isNotEmpty) 'DEBIT TO ${_up(r['debitTo'])}${!_blank(r['debitRate']) ? ' @ ${fmt(r['debitRate'])}' : ''}'];
  return t.isEmpty ? '' : '<b>${_e(t.join(' · '))}</b>${_s(r['work']).isNotEmpty || _s(r['remark']).isNotEmpty ? ' – ' : ''}';
}

/// Start / Closed / Total of one entry, by the way it was measured.
String lbPrintWork(Map r, String w) {
  String c(String a, String b, String t) => '<td class="n">$a</td><td class="n">$b</td><td class="n"><b>$t</b></td>';
  if (w == 'Holiday' || w == 'Idle' || w == 'Breakdown') return c('–', '–', '<b>${w.toUpperCase()}</b>');
  if (w == 'Time') {
    final sl = slotsOf(r), br = slotsBreak(r);
    final a = sl.isNotEmpty ? sl.map((x) => _e(x[0])).join('<br>') : _e(r['tStart']), b = sl.isNotEmpty ? sl.map((x) => _e(x[1])).join('<br>') : _e(r['tEnd']);
    return c(a, b + (br != '' && br != 0 ? '<br><small>BREAK ${fmt(br)} MIN</small>' : ''), '${_blank(r['whr']) ? '' : fmt(r['whr'])} <small>HR</small>');
  }
  if (w == 'Trip') return c('–', _s(r['challan']).isNotEmpty ? '<small style="display:block;white-space:normal;word-break:break-word;text-align:left;line-height:1.15">CH. ${_e(r['challan'])}</small>' : '', '${fmt(_blank(r['trip']) ? 0 : r['trip'])} <small>TRIPS</small>');
  if (w == 'Day') return c('–', '–', '<small>DAY</small>');
  if (w == 'KM + Hrs') {
    return c('${plain(r['okm'])}<br>${plain(r['ohr'])}', '${plain(r['ckm'])}<br>${plain(r['chr'])}', '${_blank(r['wkm']) ? '' : '${fmt(r['wkm'])} <small>KM</small>'}<br>${_blank(r['whr']) ? '' : '${fmt(r['whr'])} <small>HR</small>'}');
  }
  if (w == 'Hrs') return c(plain(r['ohr']), plain(r['chr']), _blank(r['whr']) ? '' : '${fmt(r['whr'])} <small>HR</small>');
  return c(plain(r['okm']), plain(r['ckm']), _blank(r['wkm']) ? '' : '${fmt(r['wkm'])} <small>KM</small>');
}

/// An entry with two or more works printed as a row for each (as entered – own Start / Close, challan, chainage, description);
/// an entry made with "Split": its rows follow each other in the order of the BOQ. null = the entry is one row.
List<Map<String, dynamic>>? lbWorkRows(Map<String, dynamic> r) {
  final mode = _mode(r);
  if (kDayStatus.contains(mode) || mode == kNoReading) return null;
  final q0 = (r['itemQty'] as List? ?? const []).whereType<Map>().toList(), parts = (r['itemParts'] as List? ?? const []).whereType<Map>().toList();
  final kept = parts.length > 1;
  var k = '';
  List<Map> ws;
  if (kept) {
    k = _s(parts.first['k']);
    ws = parts;
  } else {
    k = ['hr', 'km', 'trip'].where((kk) => q0.where((x) => x['k'] == kk && _n(x['q']) > 0).length > 1).firstOrNull ?? '';
    if (k.isEmpty) return null;
    final order = (r['boqItems'] as List? ?? const []).whereType<Map>().map((it) => _s(it['name'])).toList();
    ws = q0.where((x) => x['k'] == k && _n(x['q']) > 0).toList();
    final at = {for (var i = 0; i < ws.length; i++) ws[i]: i};
    ws.sort((a, b) {
      final c = order.indexOf(_s(a['n'])) - order.indexOf(_s(b['n']));
      return c != 0 ? c : at[a]! - at[b]!;
    });
  }
  final others = q0.where((x) => x['k'] != k).toList();
  final f = k == 'hr' ? ['ohr', 'chr', 'whr'] : k == 'km' ? ['okm', 'ckm', 'wkm'] : null;
  final o = k == 'hr' ? ['okm', 'ckm', 'wkm'] : k == 'km' ? ['ohr', 'chr', 'whr'] : ['okm', 'ckm', 'wkm', 'ohr', 'chr', 'whr'];
  final reads = f != null && !_blank(r[f[0]]) && !_blank(r[f[1]]) && (k == 'hr' ? hasHr(mode) : hasKm(mode));
  num at = reads ? _n(r[f[0]]) : 0;
  final later = r2(ws.skip(1).fold<num>(0, (a, p) => a + _n(p['q'])));
  bool isT(Map p) => kept && p['m'] == 'T';
  final lastR = [for (var j = 0; j < ws.length; j++) if (!isT(ws[j])) j].lastOrNull;
  // (Mechanical update-146) rows read in KM + Hrs keep their other meter (o) – each row prints both
  final two = kept && f != null && ws.where((p) => !isT(p)).every((p) => p['o'] != null) && !_blank(r[o[0]]) && !_blank(r[o[1]]);
  num at2 = two ? _n(r[o[0]]) : 0;
  final out = <Map<String, dynamic>>[];
  for (var j = 0; j < ws.length; j++) {
    final p = ws[j];
    final y = <String, dynamic>{...r, '_ent': r, '_sub': j, '_part': _s(p['n']), '_prt': kept ? _s(p['p']) : '', 'itemQty': [{'n': p['n'], 'q': p['q'], 'k': k}, if (j == 0) ...others], 'itemParts': null};
    if (k == 'trip') {
      y['trip'] = p['q'];
    } else if (k == 'day') {
      y['itemQty'] = j == 0 ? q0 : const []; // (update-146: a row of a day's works – the day is paid once, on its first row)
    } else {
      y[f![2]] = p['q'];
      if (isT(p)) {
        y[f[0]] = '';
        y[f[1]] = '';
      } else if (reads) {
        final a = r2(at + _n(p['g'])), b = j == lastR ? _n(r[f[1]]) : r2(a + _n(p['q']));
        at = b;
        y[f[0]] = a;
        y[f[1]] = b;
      }
    }
    if (j > 0) {
      for (final x in o) {
        y[x] = '';
      }
      if (k != 'trip') y['trip'] = '';
      for (final x in ['tStart', 'tEnd', 'tSlots', 'tBrk', 'debitTo', 'meter']) {
        y[x] = '';
      }
      if (k == 'hr') y['_gross'] = p['q'];
    } else if (k == 'hr') {
      y['_grossLess'] = later;
    }
    if (kept) {
      y['challan'] = _s(p['c']);
      y['remark'] = _s(p['p']);
      y['chFrom'] = _s(p['f']);
      y['chTo'] = _s(p['t']);
      y['work'] = _s(p['w']);
      if (j > 0 || _s(p['f']).isNotEmpty || _s(p['t']).isNotEmpty) y['chainage'] = '';
    }
    if (two && !isT(p)) {
      final a2 = at2, b2 = j == lastR ? _n(r[o[1]]) : r2(a2 + _n(p['o']));
      at2 = b2;
      y[o[0]] = a2;
      y[o[1]] = b2;
      y[o[2]] = r2(b2 - a2);
    }
    if (k == 'trip' && _s(p['ti']).isNotEmpty) {
      final ti = _s(p['ti']).split('-');
      y['tStart'] = ti.first;
      y['tEnd'] = ti.length > 1 ? ti[1] : '';
    }
    if (isT(p)) {
      final sl = slotsParse(p['ts']);
      y['mode'] = 'Time';
      y['tStart'] = sl.isEmpty ? '' : sl.first[0];
      y['tEnd'] = sl.isEmpty ? '' : sl.last[1];
      y['tSlots'] = sl.length > 1 ? p['ts'] : '';
      final b = r2(_n(p['tb']) + slotsGap(sl));
      y['tBrk'] = b == 0 ? '' : b;
      y['_gross'] = p['q'];
      y.remove('_grossLess');
    }
    out.add(y);
  }
  return out;
}

/// KM + Hrs (two engines, one tank): the drum at its standard, the rest of the diesel is the vehicle engine's.
({String how, num kmpl, num lph, num hrDiesel, num kmDiesel}) dualAvg(num diesel, num km, num hr, num kmStd, num hrStd) {
  if (!(diesel > 0) || !(km > 0 || hr > 0)) return (how: '', kmpl: 0, lph: 0, hrDiesel: 0, kmDiesel: 0);
  if (!(km > 0)) return (how: 'hr', kmpl: 0, lph: r2(diesel / hr), hrDiesel: diesel, kmDiesel: 0);
  if (!(hr > 0) || !(hrStd > 0)) return (how: 'km', kmpl: r2(km / diesel), lph: 0, hrDiesel: 0, kmDiesel: diesel);
  final dHr = r2(hr * hrStd), dKm = r2(diesel - dHr);
  if (!(dKm > 0)) return (how: 'short', kmpl: 0, lph: 0, hrDiesel: dHr, kmDiesel: dKm);
  return (how: 'split', kmpl: r2(km / dKm), lph: hrStd, hrDiesel: dHr, kmDiesel: dKm);
}

/// The last fill of the period is partly still in the tank (as the bill: tankLeft).
Map<String, dynamic>? tankLeft(Map m, String u, List<Map> own, Map iss0, bool Function(String) isDebit, num raw) {
  final kmStd = _n(m['kmStd']), hrStd = _n(m['hrStd']);
  final days = iss0.keys.map((k) => '$k').where((d) => !isDebit(d) && _n((iss0[d] as Map?)?['qty']) > 0).toList()..sort();
  if (days.isEmpty || !(raw > 0)) return null;
  final d = days.last, x = iss0[d] as Map;
  bool num0(Object? v) => !_blank(v) && num.tryParse('$v') != null;
  final qty = r2(_n(x.containsKey('lastQty') ? x['lastQty'] : x['qty'])), fk = x.containsKey('lastKm') ? x['lastKm'] : x['km'], fh = x.containsKey('lastHr') ? x['lastHr'] : x['hr'];
  String ord(Map r) => '${r['date']}|${r['shift'] == 'Night' ? 1 : 0}';
  final onAfter = own.where((r) => _s(r['date']).compareTo(d) >= 0).toList()..sort((a, b) => ord(a).compareTo(ord(b)));
  final after = own.where((r) => _s(r['date']).compareTo(d) > 0).toList();
  (num, String) part(bool has, num std, Object? fill, String cl, String w) {
    if (!has || std == 0) return (0, '');
    if (num0(fill)) {
      final ends = onAfter.where((r) => num0(r[cl])).map((r) => _n(r[cl])).toList();
      if (ends.isEmpty) return (0, 'reading');
      if (ends.last >= _n(fill)) return (r2(ends.last - _n(fill)), 'reading');
    }
    return (r2(after.fold<num>(0, (a, r) => a + _n(r[w]))), 'days');
  }

  final k = part(hasKm(u), kmStd, fk, 'ckm', 'wkm'), h = part(hasHr(u), hrStd, fh, 'chr', 'whr');
  final used = r2((k.$2.isNotEmpty ? k.$1 / kmStd : 0) + (h.$2.isNotEmpty ? h.$1 * hrStd : 0));
  var left = qty - used > 0 ? r2(qty - used) : 0;
  final cap = _n(m['tankCap']);
  if (cap > 0 && left > cap) left = cap;
  final applied = r2(left < raw ? (left > 0 ? left : 0) : raw);
  return {'date': d, 'qty': qty, 'km': k.$2 == 'reading' ? _n(fk) : '', 'hr': h.$2 == 'reading' ? _n(fh) : '', 'kmAfter': k.$1, 'hrAfter': h.$1, 'by': k.$2 == 'reading' || h.$2 == 'reading' ? 'reading' : 'days', 'used': used, 'left': left, 'applied': applied};
}

String tankText(Map? t) {
  if (t == null || !(_n(t['applied']) > 0)) return '';
  final run = [if (_n(t['kmAfter']) != 0) '${fmt(t['kmAfter'])} km', if (_n(t['hrAfter']) != 0) '${fmt(t['hrAfter'])} hr'].join(' + ');
  return 'last fill ${fmt(t['qty'])} L on ${showDate(_s(t['date']))}${t['km'] != '' ? ' at ${fmt(t['km'])} km' : ''}${t['hr'] != '' ? ' at ${fmt(t['hr'])} hr' : ''}; '
      '${run.isNotEmpty ? 'run after it $run = ${fmt(t['used'])} L by standard' : 'no work after it'}; ${fmt(t['applied'])} L taken as still in the tank – not debited';
}

/// Item-wise BOQ, one day: each item on its own quantity and rate (→ the lines of the bill part). → the quantity billed that day.
num itemDaySegs(Map b, String bk, String d, List<Map> dayRows, Map<String, num> itemHrs, Map<String, dynamic> Function(String, Map<String, dynamic>) seg) {
  final items = (b['items'] as List? ?? const []).whereType<Map>().toList();
  num any = 0;
  for (var j = 0; j < items.length; j++) {
    final it = items[j];
    final q = dayRows.fold<num>(0, (a, r) => a + (r['itemQty'] as List? ?? const []).whereType<Map>().where((x) => x['n'] == it['name']).fold<num>(0, (a2, x) => a2 + _n(x['q'])));
    if (!(q > 0)) continue;
    any += q;
    final ik = '$bk|I$j', rate = _n(it['rate']), basis = _s(it['basis']);
    void add(Map<String, dynamic> s1, num qty, num amt) {
      s1['qty'] = _n(s1['qty']) + qty;
      s1['amount'] = _n(s1['amount']) + amt;
    }

    if (basis == 'Monthly') {
      add(seg('$ik|M|${_dim(d)}', {'item': it['name'], 'unit': 'Days', 'rate': rate / _dim(d), 'monthly': rate}), q, rate / _dim(d) * q);
    } else if (basis == 'Per Day') {
      add(seg('$ik|D', {'item': it['name'], 'unit': 'Days', 'rate': rate}), q, rate * q);
    } else if (basis == 'Per KM') {
      add(seg('$ik|K', {'item': it['name'], 'unit': 'KM', 'rate': rate}), q, rate * q);
    } else if (basis == 'Per Trip') {
      add(seg('$ik|T', {'item': it['name'], 'unit': 'Trips', 'rate': rate}), q, rate * q);
    } else if (basis == 'Per Hour') {
      final slabs = (it['slabs'] as List? ?? const []).whereType<Map>().toList();
      if (slabs.isNotEmpty) {
        num from2 = it['slabOn'] == 'Period' ? (itemHrs[ik] ?? 0) : 0, left = q;
        for (var k = 0; k < slabs.length; k++) {
          final sl = slabs[k];
          if (left <= 0) continue;
          final cap = _blank(sl['upTo']) ? double.infinity : _n(sl['upTo']);
          if (from2 >= cap) continue;
          final take = left < cap - from2 ? left : cap - from2;
          add(seg('$ik|S$k', {'item': it['name'], 'unit': 'Hrs', 'rate': _n(sl['rate']), 'note': _blank(sl['upTo']) ? 'after ${k > 0 ? _s(slabs[k - 1]['upTo']) : '0'} hr' : 'up to ${sl['upTo']} hr'}), take, take * _n(sl['rate']));
          left -= take;
          from2 += take;
        }
        itemHrs[ik] = (itemHrs[ik] ?? 0) + q;
      } else {
        add(seg('$ik|H', {'item': it['name'], 'unit': 'Hrs', 'rate': rate}), q, rate * q);
      }
    }
  }
  return any;
}

/// The columns of each Log Book format (A = the standard sheet).
const kLbFmtCols = {
  'B': ['sr', 'date', 'shift', 'kmS', 'kmC', 'kmT', 'hrS', 'hrC', 'hrT', 'dO', 'dI', 'dT', 'dU', 'dC', 'trip', 'ch', 'work'],
  'C': ['sr', 'date', 'shift', 'kmS', 'kmC', 'kmT', 'dO', 'dI', 'dR', 'dT', 'dU', 'dC', 'avg', 'work'],
  'D': ['sr', 'date', 'shift', 'hrS', 'hrC', 'hrT', 'dO', 'dI', 'dR', 'dT', 'dU', 'dC', 'avg', 'ch', 'work'],
  'E': ['sr', 'date', 'particular', 'challan', 'rS', 'rC', 'rT', 'dO', 'dI', 'dT', 'dU', 'dC', 'avg', 'ch', 'work'],
  'F': ['sr', 'date', 'regno', 'particular', 'challan', 'tS', 'tE', 'tG', 'tN', 'ch', 'work'],
  'G': ['sr', 'date', 'regno', 'particular', 'challan', 'tS', 'tE', 'tG', 'hr1', 'hr2', 'ch', 'work'],
  'H': ['sr', 'date', 'shift', 'vehno', 'challan', 'dQ', 'inT', 'outT', 'trip', 'ch', 'work'],
  'I': ['sr', 'date', 'shift', 'agency', 'vehno', 'challan', 'dspT', 'unlT', 'trip', 'chno', 'usefor'],
};

class _Col {
  const _Col(this.h, this.v, {this.g = '', this.c = '', this.wrap = false, this.t});
  final String h, g, c;
  final bool wrap;
  final String Function(Map<String, dynamic> x) v;
  final String Function()? t;
  _Col group(String g2) => _Col(h, v, g: g2, c: c, wrap: wrap, t: t);
}

class LbPrint {
  LbPrint(this.title, this.html, [this.sheets = '']);
  final String title, html;
  /// (3.8.0) the sheets alone (a bill's papers carry its Log Book after them)
  final String sheets;
}

/// The Log Book print of [rows] (getLogBookList's rows) for [from] – [to]. [machine]: Asset Master of a machinery number.
/// [extra]: logPrintExtra (diesel issues, BOQ of each date, diesel rates). [fmtF] / [sample]: "View format".
/// [dieselRate]: typed for this print (0 = the automatic rate). [portrait]: the page turned.
LbPrint logBookPrint({
  required List<Map<String, dynamic>> rows,
  required String from,
  required String to,
  required String head,
  required String site,
  required Map extra,
  required Map<String, dynamic>? Function(String no) machine,
  String fmtF = '',
  String sample = '',
  num dieselRate = 0,
  Map? rateBy,
  Map? idle,
  String logo = '',
  bool portrait = true,
}) {
  const ord = {'Day': 0, 'Full Day': 0, 'Night': 1};
  final at0 = {for (var i = 0; i < rows.length; i++) rows[i]: i};
  final list0 = [...rows]..sort((a, b) {
      final c = natCompare(_s(a['no']), _s(b['no']));
      if (c != 0) return c;
      final d = _s(a['date']).compareTo(_s(b['date']));
      final sh = (ord[a['shift']] ?? 0) - (ord[b['shift']] ?? 0);
      return d != 0 ? d : sh != 0 ? sh : at0[a]! - at0[b]!;
    });
  final dates = list0.map((r) => _s(r['date'])).toList()..sort();
  if (from.isEmpty && dates.isNotEmpty) from = dates.first;
  final rateAll = dieselRate > 0 ? r2(dieselRate) : 0, rateBy0 = rateBy ?? const {}, rateX = _n(extra['manualRate']) > 0 ? r2(_n(extra['manualRate'])) : 0;
  final by = <String, List<Map<String, dynamic>>>{};
  for (final r in list0) {
    by.putIfAbsent(_s(r['no']), () => []).add(r);
  }
  final f0 = DateTime.parse(from), lastOfMonth = DateTime(f0.year, f0.month + 1, 0);
  final wholeMonth = f0.day == 1 && to == '${lastOfMonth.year.toString().padLeft(4, '0')}-${lastOfMonth.month.toString().padLeft(2, '0')}-${lastOfMonth.day.toString().padLeft(2, '0')}';
  final monthWord = '${_months[f0.month - 1]} ${f0.year}';
  final periodText = '${wholeMonth ? '$monthWord (' : ''}${showDate(from)} TO ${showDate(to)}${wholeMonth ? ')' : ''}';
  final hl = head.toLowerCase();
  final logoHtml = hl.contains('rachana') && logo.isNotEmpty
      ? '<span class="lb-logo-r"><img src="$logo" alt="" style="width:30mm;height:auto;display:block"></span>'
      : hl.contains('sketchline')
          ? '<span class="lb-logo-s"><img src="https://i.ibb.co/hF8CPrw3/sketchline.jpg" alt="" onerror="this.parentNode.remove()"></span>'
          : '';
  final printName = hl.contains('sketchline') ? head.toUpperCase() : head;
  final siteWord = site.replaceFirst(RegExp(r'^VTR Site\s*[–-]\s*', caseSensitive: false), 'VTR ');
  final nos = jsKeys(by);
  final sheets = StringBuffer();
  for (final no in nos) {
    final list = by[no]!, m = machine(no) ?? <String, dynamic>{}, u = _s(m['unit']).isNotEmpty ? _s(m['unit']) : (_s(list.first['unit']).isNotEmpty ? _s(list.first['unit']) : 'KM');
    final isHr = u == 'Hrs', dual = u == 'KM + Hrs', key = _key(no);
    final iss0 = ((extra['issues'] as Map?)?[key] as Map?) ?? const {};
    final byR = _n(rateBy0[key]) > 0 ? r2(_n(rateBy0[key])) : 0;
    final manRate = rateAll > 0 ? rateAll : byR > 0 ? byR : rateX;
    final seenDay = <String>{}, lines = <Map<String, dynamic>>[];
    for (var i = 0; i < list.length; i++) {
      final r = list[i], d = iss0[r['date']] as Map?, first = seenDay.add(_s(r['date']));
      final iss = first && d != null ? _n(d['qty']) : 0;
      final refill = first && d != null ? (isHr ? d['hr'] : dual ? [d['km'], d['hr']].where((x) => x != '' && x != null).map((x) => '$x').join(' / ') : d['km']) : '';
      final x = <String, dynamic>{'r': r, 'i': i, 'open': 0, 'iss': iss, 'refill': refill ?? '', 'total': iss, 'used': iss, 'close': 0, 'avg': ''};
      final ws = sample.isNotEmpty ? null : lbWorkRows(r);
      if (ws == null) {
        lines.add(x);
      } else {
        for (var j = 0; j < ws.length; j++) {
          lines.add({...x, 'r': ws[j], if (j > 0) ...{'iss': 0, 'refill': '', 'total': 0, 'used': 0}});
        }
      }
    }
    for (var i = 0; i < lines.length; i++) {
      lines[i]['i'] = i;
    }
    num sum(String k) => r2(lines.fold<num>(0, (s, x) => s + _n(x[k])));
    final tKm = r2(list.fold<num>(0, (s, r) => s + _n(r['wkm']))), tHr = r2(list.fold<num>(0, (s, r) => s + _n(r['whr'])));
    final tTrips = r2(list.fold<num>(0, (s, r) => s + (kDayStatus.contains(_mode(r)) ? 0 : _n(r['trip']))));
    final used = sum('used'), issuedRows = sum('iss');
    final issAll = r2(iss0.values.fold<num>(0, (s, x) => s + _n((x as Map?)?['qty']))), issued = issuedRows > issAll ? issuedRows : issAll;
    final inRows = <String, num>{};
    for (final x in lines) {
      final d0 = _s((x['r'] as Map)['date']);
      if (d0.isNotEmpty) inRows[d0] = r2((inRows[d0] ?? 0) + _n(x['iss']));
    }
    final noEntry = (iss0.keys.map((k) => '$k').toList()..sort()).map((d0) => (d0, r2(_n((iss0[d0] as Map?)?['qty']) - (inRows[d0] ?? 0)))).where((x) => x.$2 > .005).toList();
    final noEntryNote = noEntry.isNotEmpty ? '<small>${n2(issuedRows)} IN THE ENTRIES ABOVE + NOT IN AN ENTRY: ${noEntry.map((x) => '${showDate(x.$1)} ${fmt(x.$2)} L').join(', ')}</small>' : '';
    int daysOf(String w) => list.where((r) => _mode(r) == w).map((r) => r['date']).toSet().length;
    final holDays = daysOf('Holiday'), bdDaysP = daysOf('Breakdown'), idleDays = daysOf('Idle');
    final idleSet = idle != null && idle.containsKey(key), idlePaid = !(idleSet && idle[key] == false);
    final paidList = list.where((r) => !_isHol(r) && (idlePaid || _mode(r) != 'Idle')).toList();
    final units = <String, Map<String, num>>{};
    for (final r in paidList) {
      final x = units.putIfAbsent(_s(r['date']), () => {'day': 0, 'night': 0}), p = dayPart(r);
      if (r['shift'] == 'Night') {
        x['night'] = x['night']! > p ? x['night']! : p;
      } else {
        x['day'] = x['day']! > p ? x['day']! : p;
      }
    }
    final workDays = r2(units.values.fold<num>(0, (a, x) => a + x['day']!)), nights = r2(units.values.fold<num>(0, (a, x) => a + x['night']!)), net = r2(workDays + nights);
    final halfDays = paidList.where((r) => dayPart(r) == .5).length;
    String shiftText(Map r) {
      final x = units[_s(r['date'])] ?? const {};
      final both = (x['day'] ?? 0) != 0 && (x['night'] ?? 0) != 0 && list.where((y) => y['date'] == r['date']).length == 1;
      return (both ? 'Day+Night' : r['shift'] == 'Full Day' ? 'Day' : _s(r['shift'])) + (dayPart(r) == .5 ? ' ½' : '');
    }

    // the rate: the BOQ in force on each date (an amendment from a date takes over from that date)
    final bday = ((extra['boq'] as Map?)?[key] as Map?) ?? const {};
    num payable = 0, periodHrs = 0;
    final used2 = <String, Map>{}, itemSegs = <String, Map<String, dynamic>>{}, itemHrs = <String, num>{};
    Map<String, dynamic> itemSeg(String k, Map<String, dynamic> o) => itemSegs.putIfAbsent(k, () => {'qty': 0, 'amount': 0, ...o});
    final legacy = _n(m['monthlyRate']);
    for (final d in units.keys.toList()..sort()) {
      final x = units[d]!, n = x['day']! + x['night']!, b = bday[d] as Map?;
      final dayRows = paidList.where((r) => r['date'] == d).toList();
      final hrs = dayRows.fold<num>(0, (s, r) => s + _n(r['whr'])), km = dayRows.fold<num>(0, (s, r) => s + _n(r['wkm'])), trips = dayRows.fold<num>(0, (s, r) => s + _n(r['trip']));
      if (b == null) {
        if (legacy != 0) {
          payable += legacy / _dim(d) * n;
          used2['legacy'] = {'basis': 'Monthly', 'rate': legacy};
        }
        continue;
      }
      final bk = '${b['boq']}${_n(b['amendNo']) != 0 ? ' (amend ${b['amendNo']})' : ''}';
      used2[bk] = b;
      if ((b['items'] as List? ?? const []).isNotEmpty) {
        itemDaySegs(b, bk, d, dayRows, itemHrs, itemSeg);
        continue;
      }
      final rate = _n(b['rate']), basis = _s(b['basis']);
      if (basis == 'Monthly') {
        payable += rate / _dim(d) * n;
      } else if (basis == 'Per Day') {
        payable += rate * n;
      } else if (basis == 'Per KM') {
        payable += rate * km;
      } else if (basis == 'Per Trip' && _n(b['nightRate']) > 0) {
        final tN = dayRows.where((r) => r['shift'] == 'Night').fold<num>(0, (s, r) => s + _n(r['trip']));
        payable += rate * (trips - tN) + _n(b['nightRate']) * tN;
      } else if (basis == 'Per Trip') {
        payable += rate * trips;
      } else if (basis == 'Per Hour') {
        final slabs = (b['slabs'] as List? ?? const []).whereType<Map>().toList();
        if (slabs.isNotEmpty) {
          num from2 = b['slabOn'] == 'Period' ? periodHrs : 0, left = hrs;
          for (final sl in slabs) {
            if (left <= 0) continue;
            final cap = _blank(sl['upTo']) ? double.infinity : _n(sl['upTo']);
            if (from2 >= cap) continue;
            final take = left < cap - from2 ? left : cap - from2;
            payable += take * _n(sl['rate']);
            left -= take;
            from2 += take;
          }
          periodHrs += hrs;
        } else {
          payable += rate * hrs;
        }
      }
    }
    payable = r2(payable + itemSegs.values.fold<num>(0, (s, x) => s + r2(_n(x['amount']))));
    String itemRate(String k) => jsKeys(itemSegs).where((q) => q.startsWith('$k|I')).map((q) {
          final x = itemSegs[q]!;
          return '<b>${_e(_up(x['item']))}</b>${_s(x['note']).isNotEmpty ? ' <small>${_e(x['note'])}</small>' : ''}: ${fmt(r2(_n(x['qty'])))} ${_up(x['unit'])} × ₹ ${n2(x['rate'])} = ₹ ${n2(x['amount'])}';
        }).join('<br>');
    final bKeys = jsKeys(used2), last = bKeys.isEmpty ? null : used2[bKeys.last];
    String kindOf(String q) => q == 'Monthly' || q == 'Per Day' ? 'day' : q == 'Per Hour' ? 'hr' : q == 'Per KM' ? 'km' : q == 'Per Trip' ? 'trip' : '';
    final kinds = <String>{};
    for (final k in bKeys) {
      final q = used2[k]!, its = (q['items'] as List? ?? const []).whereType<Map>().toList();
      for (final z in its.isNotEmpty ? its.map((it) => _s(it['basis'])) : [_s(q['basis'])]) {
        if (kindOf(z).isNotEmpty) kinds.add(kindOf(z));
      }
    }
    final works = (m['worksOn'] as List? ?? const []).map((e) => '$e').toList().isNotEmpty
        ? (m['worksOn'] as List).map((e) => '$e').toList()
        : (switch (_s(m['unit'])) { 'KM' => ['KM'], 'Hrs' => ['Hrs'], 'KM + Hrs' => ['KM', 'Hrs'], 'Day' => ['Day'], _ => <String>[] });
    if (bKeys.isEmpty) {
      if (works.any((z) => z == 'Hrs' || z == 'Time')) kinds.add('hr');
      if (works.contains('Trip')) kinds.add('trip');
      if (works.any((z) => z == 'Day' || z == 'KM' || z == 'KM + Hrs')) kinds.add('day');
    }
    if (kinds.isEmpty) kinds.add('day');
    const unitWord = {'Monthly': '/ MONTH', 'Per Day': '/ DAY', 'Per Hour': '/ HR', 'Per KM': '/ KM', 'Per Trip': '/ TRIP'};
    final rateCell = last == null
        ? '–'
        : bKeys.map((k) {
            final b = used2[k]!, slabs = (b['slabs'] as List? ?? const []).whereType<Map>().toList();
            return (k == 'legacy' ? '' : '<small>BOQ ${_e(k)}:</small> ') +
                ((b['items'] as List? ?? const []).isNotEmpty
                    ? '<br>${itemRate(k).isNotEmpty ? itemRate(k) : 'ITEM-WISE – NO ITEM WORK'}'
                    : slabs.isNotEmpty
                        ? '${slabs.map((sl) => '${_blank(sl['upTo']) ? 'after' : 'up to ${sl['upTo']} hr'} ₹${n2(sl['rate'])}').join(', ')} / HR'
                        : '₹ ${n2(b['rate'])}${b['basis'] == 'Monthly' ? '' : ' ${unitWord[b['basis']] ?? ''}'}${b['basis'] == 'Per Trip' && _n(b['nightRate']) > 0 ? ', NIGHT ₹ ${n2(b['nightRate'])} / TRIP' : ''}');
          }).join('<br>');
    final monthly = bKeys.where((k) => used2[k]!['basis'] == 'Monthly').toList();
    final dailyCell = monthly.isNotEmpty ? monthly.map((k) => '₹ ${n2(_n(used2[k]!['rate']) / _dim(from))} <small>(÷ ${_dim(from)})</small>').join('<br>') : '–';
    // excess diesel: issued above what the standard average allows for the work done
    final kmStd = _n(m['kmStd']), hrStd = _n(m['hrStd']);
    bool isDebitD(String d) {
      final bd = bday[d] as Map?;
      return bd != null ? bd['diesel'] == 'Debit Basis' : m['supply'] == 'Debit Basis';
    }

    final debitQty = r2(iss0.keys.map((k) => '$k').where(isDebitD).fold<num>(0, (s, d) => s + _n((iss0[d] as Map?)?['qty'])));
    final ownRows = list.where((r) => !isDebitD(_s(r['date']))).toList();
    final tKmC = r2(ownRows.fold<num>(0, (s, r) => s + _n(r['wkm']))), tHrC = r2(ownRows.fold<num>(0, (s, r) => s + _n(r['whr'])));
    final stdQty = r2((hasKm(u) && kmStd != 0 ? tKmC / kmStd : 0) + (hasHr(u) && hrStd != 0 ? tHrC * hrStd : 0));
    final rawExcess = stdQty > 0 ? (issued - debitQty - stdQty > 0 ? r2(issued - debitQty - stdQty) : 0) : 0;
    final dayAfterP = _dateAdd(to, 1), inf = _s(m['inactiveFrom']);
    final leftP = (m['status'] == 'Inactive' && inf.isNotEmpty && (inf.length > 10 ? inf.substring(0, 10) : inf).compareTo(dayAfterP) <= 0) ||
        (m['earlier'] as List? ?? const []).whereType<Map>().any((p) => _s(p['until']).compareTo(from) > 0 && _s(p['until']).compareTo(dayAfterP) <= 0);
    final tank = leftP ? null : tankLeft(m, u, ownRows, iss0, isDebitD, rawExcess);
    final excessQty = r2(rawExcess - (tank != null ? _n(tank['applied']) : 0));
    final avgR = _n(extra['avgRate']), lastR = _n(extra['lastRate']), avgRate = manRate > 0 ? manRate : (avgR > lastR ? avgR : lastR), excessAmt = r2((debitQty + excessQty) * avgRate);
    final basic = r2(payable - excessAmt);
    final tdsP = last != null && !_blank(last['tdsPct']) ? _n(last['tdsPct']) : _n(m['tdsRate']);
    final gstP = last != null && !_blank(last['gstPct']) ? _n(last['gstPct']) : 0;
    final gst = basic > 0 ? r2(basic * gstP / 100) : 0, tds = basic > 0 ? r2(basic * tdsP / 100) : 0, netPay = r2(basic + gst - tds);
    final std = [if (_n(m['kmStd']) != 0) '${js(m['kmStd'])} KM/L', if (_n(m['hrStd']) != 0) '${js(m['hrStd'])} L/HR'].join(' + ');
    final fm = fmtF.isNotEmpty ? fmtF : (_s(m['lbFormat']).isNotEmpty ? _s(m['lbFormat']) : 'A');
    final headHtml = '<div class="lb-head">${logoHtml.isNotEmpty ? '<div class="lb-logo">$logoHtml</div>' : ''}'
        '<div class="lb-title"><div class="lb-co">${_e(_up(printName))}</div>'
        '<div class="lb-site">SITE :- ${_e(_up(siteWord))}</div>'
        '<div class="lb-name">${fm == 'I' ? 'WATER TANKER REPORT' : 'LOG BOOK'} – ${_e(_up(periodText))}</div>'
        '<div class="lb-owner">OWNER: ${_e(_up(_s(m['owner']).isNotEmpty ? m['owner'] : list.first['owner']))}</div>'
        '<div class="lb-mach">${_e(_up(no))}${_s(m['type']).isNotEmpty ? ' (${_e(_up(m['type']))})' : ''}</div></div>'
        '<div class="lb-meta">STANDARD AVG: <b>${_e(std.isEmpty ? '–' : std)}</b><br>WORKS ON: <b>${_e(_up(works.isNotEmpty ? works.join(', ') : u))}</b></div></div>';
    String refillTxt(Map x) => _blank(x['refill']) ? '' : (x['refill'] is String ? _s(x['refill']) : plain(x['refill']));
    final table = StringBuffer('<table class="lb-t lb-auto"><thead>'
        '<tr><th rowspan="2">SR.<br>NO.</th><th rowspan="2">DATE</th><th rowspan="2">SHIFT</th><th rowspan="2">UNIT</th><th colspan="3">READING / WORK</th>'
        '<th colspan="6">DIESEL (LTR)</th><th rowspan="2">AVG<br><small>LTR / ${isHr ? 'HR' : 'KM'}</small></th><th rowspan="2">CHAINAGE<br><small>FROM – TO</small></th><th rowspan="2">WORK DESCRIPTION</th></tr>'
        '<tr><th>START</th><th>CLOSED</th><th>TOTAL</th><th>OPENING<br>BALANCE</th><th>ISSUED<br>QTY</th><th>CURRENT DIESEL<br>REFILLING READING</th><th>TOTAL<br>DIESEL</th><th>CONSUMED<br>DIESEL</th><th>CLOSING<br>BALANCE</th></tr></thead><tbody>');
    for (final x in lines) {
      final r = x['r'] as Map<String, dynamic>, w = _mode(r).isNotEmpty ? _mode(r) : u, st = kDayStatus.contains(w);
      final items = itemQtyText(r);
      table.write('<tr${st ? ' class="lb-st"' : ''}><td class="c">${_n(x['i']) + 1}</td><td class="c">${_e(showDate(_s(r['date'])))}</td><td class="c">${_e(shiftText(r))}</td><td class="c">${st ? '–' : _e(_up(w))}</td>'
          '${st ? '<td class="n">–</td><td class="n">–</td><td class="n">–</td>' : w == kNoReading ? '<td class="n">–</td><td class="n">–</td><td class="n"><b>${[if (!_blank(r['wkm'])) '${fmt(r['wkm'])} KM', if (!_blank(r['whr'])) '${fmt(r['whr'])} HR'].join(' / ')}</b> <small>EST.</small></td>' : lbPrintWork(r, w)}'
          '<td class="n">${n2(x['open'])}</td><td class="n">${_n(x['iss']) != 0 ? '<b>${fmt(x['iss'])}</b>' : ''}</td><td class="n">${refillTxt(x)}</td>'
          '<td class="n">${n2(x['total'])}</td><td class="n">${n2(x['used'])}</td><td class="n">${n2(x['close'])}</td>'
          '<td class="n">${_s(x['avg'])}</td><td class="lb-ch" style="white-space:normal;word-break:break-word;font-size:0.9em;line-height:1.15">${_e(_up([r['chFrom'], r['chTo']].where((v) => _s(v).isNotEmpty).join(' – ')))}</td>'
          '<td>${st ? '<b>${_e(_up(w))}</b>${_s(r['work']).isNotEmpty || _s(r['remark']).isNotEmpty ? ' – ' : ''}' : ''}${lbMarks(r)}${!st && items.isNotEmpty ? '<b>${_e(_up(items))}</b>${_s(r['work']).isNotEmpty || _s(r['remark']).isNotEmpty ? ' – ' : ''}' : ''}${_e(_up(_s(r['work']).isNotEmpty ? r['work'] : r['remark']))}</td></tr>');
    }
    final totWork = [if (tKm != 0) '${fmt(tKm)} KM', if (tHr != 0) '${fmt(tHr)} HR', if (tTrips != 0) '${fmt(tTrips)} TRIPS'].join('<br>');
    table.write('</tbody><tfoot><tr><td colspan="6" class="c">TOTAL</td><td class="n">${totWork.isEmpty ? '0' : totWork}</td><td></td><td class="n">${fmt(issued)}</td><td></td><td class="n">${fmt(sum('total'))}</td><td class="n">${fmt(used)}</td><td></td><td></td><td></td><td></td></tr></tfoot></table>');
    String money(num v) => v != 0 ? '₹ ${n2(v)}' : '–';
    final allDebit = issued > 0 ? debitQty >= issued : m['supply'] == 'Debit Basis';
    final dA = dual ? dualAvg(issued, tKm, tHr, kmStd, hrStd) : null;
    final dualWord = dA == null
        ? ''
        : dA.how == 'split'
            ? '${dA.kmpl.toStringAsFixed(2)} KM / LTR<br>${fmt(dA.lph)} LTR / HR (STD)<br><small>DRUM ${fmt(tHr)} HR × ${fmt(hrStd)} = ${fmt(dA.hrDiesel)} L AT STANDARD · VEHICLE ${fmt(issued)} − ${fmt(dA.hrDiesel)} = ${fmt(dA.kmDiesel)} L → ${fmt(tKm)} KM ÷ ${fmt(dA.kmDiesel)} L</small>'
            : dA.how == 'short'
                ? '–<br><small>THE HOURS ALONE NEED ${fmt(dA.hrDiesel)} L (${fmt(tHr)} HR × ${fmt(hrStd)}), ${fmt(issued)} L GIVEN – CHECK THE READINGS</small>'
                : dA.how == 'km'
                    ? '${dA.kmpl.toStringAsFixed(2)} KM / LTR${tHr != 0 ? '' : '<br><small>NO HOURS IN THE LOG BOOK</small>'}'
                    : dA.how == 'hr'
                        ? '${dA.lph.toStringAsFixed(2)} LTR / HR<br><small>NO KM IN THE LOG BOOK</small>'
                        : '–';
    final avgWord = allDebit || issued == 0
        ? '–'
        : isHr
            ? (tHr != 0 ? '${(issued / tHr).toStringAsFixed(2)} LTR / HR' : '–')
            : dual
                ? dualWord
                : (tKm != 0 ? '${(tKm / issued).toStringAsFixed(2)} KM / LTR' : '–');
    final stdWord = [if (hasKm(u) && kmStd != 0) 'STD ${fmt(kmStd)} KM/L', if (hasHr(u) && hrStd != 0) 'STD ${fmt(hrStd)} L/HR'].join(' · ');
    final verdict = allDebit ? 'DIESEL ON DEBIT – ALL DIESEL IS DEBITED' : stdQty == 0 ? 'NO STANDARD IN ASSET MASTER' : excessQty > 0 ? 'WORSE THAN STANDARD → DEBIT' : 'WITHIN STANDARD → NO DEBIT';
    final nightHr = r2(list.where((r) => r['shift'] == 'Night').fold<num>(0, (s, r) => s + _n(r['whr'])));
    List<List<String>> onRows(String k) => k == 'hr'
        ? [
            ['TOTAL HOURS${nightHr != 0 ? '<small>DAY ${fmt(r2(tHr - nightHr))} HRS · NIGHT ${fmt(nightHr)} HRS</small>' : ''}', '${fmt(tHr)} HRS']
          ]
        : k == 'km'
            ? [
                ['TOTAL KM', '${fmt(tKm)} KM']
              ]
            : k == 'trip'
                ? [
                    ['TOTAL TRIPS', fmt(tTrips)]
                  ]
                : [];
    final notPaid = [if (holDays > 0) 'HOLIDAY $holDays', if (bdDaysP > 0) 'BREAKDOWN $bdDaysP'];
    final ld = [
      ['TOTAL WORKING DAYS${halfDays > 0 ? '<small>$halfDays HALF DAY${halfDays == 1 ? '' : 'S'} COUNTED AS ½</small>' : ''}', js(workDays)],
      ['TOTAL WORKING NIGHT', js(nights)],
      ['NET WORKING DAYS${notPaid.isNotEmpty ? '<small>NOT PAID – ${notPaid.join(', ')}</small>' : ''}${idleDays > 0 ? '<small>IDLE $idleDays${idlePaid ? ' – PAID${idleSet ? '' : ' HERE (FINAL IN THE BILL)'}' : ' – NOT PAID'}</small>' : ''}', js(net)],
    ];
    final lon = [if (kinds.contains('day')) ...ld, ...onRows(kinds.contains('hr') ? 'hr' : ''), ...onRows(kinds.contains('km') ? 'km' : ''), ...onRows(kinds.contains('trip') ? 'trip' : '')];
    final lz = [
      ['TOTAL DIESEL ISSUE$noEntryNote', '${n2(issued)} LTR'],
      ['DIESEL MONTHLY AVERAGE', avgWord],
      ['STANDARD AVERAGE<small>$verdict</small>', allDebit ? 'NOT CHECKED' : '${stdWord.isEmpty ? '–' : stdWord}${stdQty != 0 ? '<br><small>${fmt(stdQty)} L allowed for the work</small>' : ''}'],
    ];
    final tankApplied = tank != null && _n(tank['applied']) > 0;
    final rr = [
      [monthly.isNotEmpty ? 'MONTHLY RATE' : 'RATE', rateCell],
      if (kinds.contains('day')) ['DAILY RATE', dailyCell],
      ['PAYABLE AMOUNT', money(payable)],
      [
        '${debitQty != 0 ? 'DIESEL DEBIT' : 'EXCESS DIESEL – DEBIT AMT'}<small>${manRate > 0 ? 'rate = ₹${n2(manRate)} (fixed by hand)' : 'rate = higher of avg ₹${n2(avgR)} / last ₹${n2(lastR)}'}</small>',
        excessAmt != 0
            ? '<small>${[if (debitQty != 0) '${fmt(debitQty)} L debit', if (excessQty != 0) '${fmt(excessQty)} L extra'].join(' + ')} × ₹${n2(avgRate)}</small> − ₹ ${n2(excessAmt)}${tankApplied ? '<br><small>${_e(tankText(tank).toUpperCase())}</small>' : ''}'
            : '<small>${tankApplied ? _e(tankText(tank).toUpperCase()) : stdQty != 0 ? 'no extra diesel' : 'no standard'}</small> –'
      ],
      ['TDS ${tdsP != 0 ? '${fmt(tdsP)}% (on basic)' : ''}', tds != 0 ? '− ₹ ${n2(tds)}' : '–'],
      ['GST ${gstP != 0 ? '${fmt(gstP)}% (on basic)' : '– not applicable'}', gst != 0 ? '+ ₹ ${n2(gst)}' : '–'],
    ];
    var tableF = table.toString();
    var lf = [...lon, ...lz];
    // ---------- the format set for this machinery (Master → Log Book Format); A = the table above ----------
    final colsF = kLbFmtCols[fm];
    if (fm != 'A' && colsF != null) {
      bool stOf(Map r) => kDayStatus.contains(_mode(r));
      String wOf(Map r) => _mode(r).isNotEmpty ? _mode(r) : u;
      num gross(Map r) {
        if (r.containsKey('_gross')) return _n(r['_gross']);
        final a = tMin(_s(r['tStart'])), b = tMin(_s(r['tEnd']));
        if (a == null || b == null) return _n(r['whr']);
        final sl = slotsParse(r['tSlots']);
        if (sl.length > 1) return r2(_n(slotsHrs(sl, 0)) - _n(r['_grossLess']));
        var d = b - a;
        if (d <= 0) d += 1440;
        return r2(d / 60 - _n(r['_grossLess']));
      }

      String tFrom(Map r) => slotsOf(r).isNotEmpty ? slotsOf(r).map((x) => _e(x[0])).join('<br>') : _e(r['tStart']);
      String tTo(Map r) => slotsOf(r).isNotEmpty ? slotsOf(r).map((x) => _e(x[1])).join('<br>') : _e(r['tEnd']);
      num cap1(Map r) {
        final b = bday[r['date']] as Map?, sl = (b?['slabs'] as List? ?? const []).whereType<Map>().toList();
        return sl.isNotEmpty && !_blank(sl.first['upTo']) ? _n(sl.first['upTo']) : 1;
      }

      num hrs(Map r) => _n(r['whr']);
      num hr1(Map r) => stOf(r) ? 0 : r2(hrs(r) < cap1(r) ? hrs(r) : cap1(r));
      num hr2(Map r) => stOf(r) ? 0 : r2(hrs(r) - cap1(r) > 0 ? hrs(r) - cap1(r) : 0);
      bool km(Map r) => hasKm(wOf(r)) && !stOf(r);
      bool hrM(Map r) => hasHr(wOf(r)) && !stOf(r);
      bool tm(Map r) => wOf(r) == 'Time';
      const dash = '–';
      String numT(Object? v) => _blank(v) ? '' : fmt(v);
      Map<String, dynamic> rOf(Map<String, dynamic> x) => x['r'] as Map<String, dynamic>;
      Map? tOf(Map<String, dynamic> x) => x['t'] as Map?;
      final c = <String, _Col>{
        'sr': _Col('SR.<br>NO.', (x) => '${_n(x['i']) + 1}', c: 'c'),
        'date': _Col('DATE', (x) => _e(showDate(_s(rOf(x)['date']))), c: 'c'),
        'shift': _Col('SHIFT', (x) => _e(shiftText(rOf(x))), c: 'c'),
        'regno': _Col('REG NO', (x) => _e(_up(no)), c: 'c', wrap: true),
        'vehno': _Col('VEHICLE NO', (x) => _e(_up(no)), c: 'c', wrap: true),
        'particular': _Col('PARTICULAR', (x) {
          final r = rOf(x);
          return _e(_up(_s(r['_part']).isNotEmpty ? (_s(r['_prt']).isNotEmpty ? r['_prt'] : r['_part']) : (_s(r['remark']).isNotEmpty ? r['remark'] : _s(m['type']))));
        }),
        'challan': _Col('CHALLAN NO', (x) => _e(tOf(x) != null ? _s(tOf(x)!['c']) : _s(rOf(x)['challan'])), c: 'c', wrap: true),
        'kmS': _Col('START<br>KM', (x) => km(rOf(x)) ? plain(rOf(x)['okm']) : dash, g: 'KM READING', c: 'n'),
        'kmC': _Col('CLOSED<br>KM', (x) => km(rOf(x)) ? plain(rOf(x)['ckm']) : dash, g: 'KM READING', c: 'n'),
        'kmT': _Col('TOTAL<br>KM', (x) => km(rOf(x)) ? '<b>${numT(rOf(x)['wkm'])}</b>' : dash, g: 'KM READING', c: 'n', t: () => fmt(tKm)),
        'hrS': _Col('START<br>HRS', (x) => hrM(rOf(x)) ? plain(rOf(x)['ohr']) : tm(rOf(x)) ? tFrom(rOf(x)) : dash, g: 'HRS READING', c: 'n'),
        'hrC': _Col('CLOSED<br>HRS', (x) => hrM(rOf(x)) ? plain(rOf(x)['chr']) : tm(rOf(x)) ? tTo(rOf(x)) : dash, g: 'HRS READING', c: 'n'),
        'hrT': _Col('TOTAL<br>HRS', (x) => hrM(rOf(x)) || tm(rOf(x)) ? '<b>${numT(rOf(x)['whr'])}</b>' : dash, g: 'HRS READING', c: 'n', t: () => fmt(tHr)),
        'rS': _Col('START<br>READING', (x) => hrM(rOf(x)) ? plain(rOf(x)['ohr']) : tm(rOf(x)) ? tFrom(rOf(x)) : km(rOf(x)) ? plain(rOf(x)['okm']) : dash, g: 'READING', c: 'n'),
        'rC': _Col('CLOSED<br>READING', (x) => hrM(rOf(x)) ? plain(rOf(x)['chr']) : tm(rOf(x)) ? tTo(rOf(x)) : km(rOf(x)) ? plain(rOf(x)['ckm']) : dash, g: 'READING', c: 'n'),
        'rT': _Col('TOTAL<br>HRS', (x) => stOf(rOf(x)) ? dash : '<b>${numT(rOf(x)['whr'])}</b>', g: 'READING', c: 'n', t: () => fmt(tHr)),
        'tS': _Col('START<br>TIME', (x) => tm(rOf(x)) ? tFrom(rOf(x)) : dash, g: 'READING', c: 'c'),
        'tE': _Col('CLOSED<br>TIME', (x) => tm(rOf(x)) ? tTo(rOf(x)) : dash, g: 'READING', c: 'c'),
        'tG': _Col('TOTAL<br>HRS', (x) => stOf(rOf(x)) || !(tm(rOf(x)) || hrM(rOf(x))) ? dash : numT(gross(rOf(x))), g: 'READING', c: 'n',
            t: () => fmt(r2(list.where((r) => !stOf(r)).fold<num>(0, (s, r) => s + gross(r))))),
        'tN': _Col('TOTAL<br>HRS', (x) {
          final r = rOf(x), br = slotsBreak(r);
          return stOf(r) || hrs(r) == 0 ? dash : '<b>${numT(r['whr'])}</b>${br != '' && br != 0 ? '<br><small>break ${fmt(br)}m</small>' : ''}';
        }, c: 'n', t: () => fmt(tHr)),
        'hr1': _Col('1ST HR', (x) {
          final r = rOf(x);
          return stOf(r) || hrs(r) == 0 || r['_sub'] != null && r['_sub'] != 0 ? dash : numT(hr1((r['_ent'] as Map?) ?? r));
        }, c: 'n', t: () => fmt(r2(list.fold<num>(0, (s, r) => s + hr1(r))))),
        'hr2': _Col('2ND HRS', (x) {
          final r = rOf(x);
          return stOf(r) || hrs(r) == 0 || r['_sub'] != null && r['_sub'] != 0 ? dash : numT(hr2((r['_ent'] as Map?) ?? r));
        }, c: 'n', t: () => fmt(r2(list.fold<num>(0, (s, r) => s + hr2(r))))),
        'inT': _Col('IN TIME', (x) => tm(rOf(x)) ? tFrom(rOf(x)) : _e(rOf(x)['tStart']), c: 'c'),
        'outT': _Col('OUT TIME', (x) => tm(rOf(x)) ? tTo(rOf(x)) : _e(rOf(x)['tEnd']), c: 'c'),
        'dO': _Col('OPENING<br>BALANCE', (x) => n2(x['open']), g: 'DIESEL (LTR)', c: 'n'),
        'dI': _Col('ISSUED<br>QTY', (x) => _n(x['iss']) != 0 ? '<b>${fmt(x['iss'])}</b>' : '', g: 'DIESEL (LTR)', c: 'n', t: () => fmt(issued)),
        'dR': _Col('CURRENT DIESEL<br>REFILLING READING', (x) => refillTxt(x), g: 'DIESEL (LTR)', c: 'n'),
        'dT': _Col('TOTAL<br>DIESEL', (x) => n2(x['total']), g: 'DIESEL (LTR)', c: 'n', t: () => fmt(sum('total'))),
        'dU': _Col('CONSUMED<br>DIESEL', (x) => n2(x['used']), g: 'DIESEL (LTR)', c: 'n', t: () => fmt(used)),
        'dC': _Col('CLOSING<br>BALANCE', (x) => n2(x['close']), g: 'DIESEL (LTR)', c: 'n'),
        'dQ': _Col('DIESEL<br>QTY', (x) => _n(x['iss']) != 0 ? '<b>${fmt(x['iss'])}</b>' : '', c: 'n', t: () => fmt(issued)),
        'avg': _Col('AVG', (x) => _s(x['avg']), c: 'n'),
        'trip': _Col('TRIP', (x) => tOf(x) != null ? '<b>1</b>' : !stOf(rOf(x)) && _n(rOf(x)['trip']) > 0 ? '<b>${numT(rOf(x)['trip'])}</b>' : '', c: 'n', t: () => fmt(tTrips)),
        'ch': _Col('CHAINAGE', (x) => _e(_up([rOf(x)['chFrom'], rOf(x)['chTo']].where((v) => _s(v).isNotEmpty).join(' – '))), c: 'lb-sm', wrap: true),
        'agency': _Col('NAME OF AGENCY', (x) => _e(_up(_s(m['owner']).isNotEmpty ? m['owner'] : rOf(x)['owner'])), wrap: true),
        'dspT': _Col('DISPATCH<br>TIME', (x) => tOf(x) != null ? _e(tOf(x)!['a']) : dash, c: 'c'),
        'unlT': _Col('UNLOAD<br>TIME', (x) => tOf(x) != null ? _e(tOf(x)!['b']) : dash, c: 'c'),
        'chno': _Col('CHAINAGE NO', (x) => _e(_up(tOf(x) != null ? tOf(x)!['ch'] : rOf(x)['chainage'])), c: 'lb-sm', wrap: true),
        'usefor': _Col('USE FOR', (x) => tOf(x) != null ? _e(_up(tOf(x)!['u'])) : stOf(rOf(x)) ? '<b>${_e(_up(wOf(rOf(x))))}</b>' : _e(_up(rOf(x)['work'])), wrap: true),
        'work': _Col('WORK DESCRIPTION', (x) {
          final r = rOf(x), items = itemQtyText(r);
          return '${stOf(r) ? '<b>${_e(_up(wOf(r)))}</b>${_s(r['work']).isNotEmpty || _s(r['remark']).isNotEmpty ? ' – ' : ''}' : ''}${lbMarks(r)}${!stOf(r) && items.isNotEmpty ? '<b>${_e(_up(items))}</b> ' : ''}'
              '${_e(_up(_s(r['work']).isNotEmpty ? r['work'] : (fm == 'E' || fm == 'F' || fm == 'G' ? '' : r['remark'])))}';
        }, wrap: true),
      };
      final cols = [for (final k in colsF) (fm == 'C' || fm == 'D') && RegExp(r'^(km|hr)[SCT]$').hasMatch(k) ? c[k]!.group('READING') : c[k]!];
      // Format I: every trip of an entry is a line of its own
      final linesF = <Map<String, dynamic>>[];
      for (final x in lines) {
        final iw = (x['r'] as Map)['itemWork'], tr = fm == 'I' && iw is Map && iw['_trips'] is List ? (iw['_trips'] as List).whereType<Map>().toList() : null;
        if (fm != 'I') {
          linesF.add(x);
        } else if (tr != null && tr.isNotEmpty) {
          for (final t in tr) {
            linesF.add({...x, 'i': linesF.length, 't': t});
          }
        } else {
          linesF.add({...x, 'i': linesF.length, 't': null});
        }
      }
      var h1 = '', h2 = '';
      for (var k = 0; k < cols.length; k++) {
        final cc = cols[k];
        if (cc.g.isEmpty) {
          h1 += '<th rowspan="2">${cc.h}</th>';
          continue;
        }
        var n = 1;
        while (k + n < cols.length && cols[k + n].g == cc.g) {
          n++;
        }
        h1 += '<th colspan="$n">${cc.g}</th>';
        for (var j = 0; j < n; j++) {
          h2 += '<th>${cols[k + j].h}</th>';
        }
        k += n - 1;
      }
      final firstTot = cols.indexWhere((cc) => cc.t != null);
      String wrapTd(_Col cc) => cc.wrap ? ' style="white-space:normal;word-break:break-word;line-height:1.15"' : '';
      final t2 = StringBuffer('<table class="lb-t lb-auto"><thead><tr>$h1</tr>${h2.isNotEmpty ? '<tr>$h2</tr>' : ''}</thead><tbody>');
      for (final x in linesF) {
        t2.write('<tr>${cols.map((cc) => '<td class="${cc.c}${cc.h == 'WORK DESCRIPTION' ? ' lb-wk' : cc.h == 'CHAINAGE' ? ' lb-chx' : ''}"${wrapTd(cc)}>${cc.v(x)}</td>').join()}</tr>');
      }
      t2.write('</tbody><tfoot><tr>${firstTot > 0 ? '<td colspan="$firstTot" class="c">TOTAL</td>${cols.sublist(firstTot).map((cc) => '<td class="n">${cc.t != null ? '<b>${cc.t!()}</b>' : ''}</td>').join()}' : '<td colspan="${cols.length}" class="c">TOTAL – ${list.length} ENTRIES</td>'}</tr></tfoot></table>');
      tableF = t2.toString();
      // the summary on the left follows the format: days, the work it shows, and diesel only where the format has diesel
      bool has(String k) => colsF.contains(k);
      final hasDiesel = colsF.any((k) => RegExp(r'^d[OITUCR]$').hasMatch(k));
      final work = [
        if (has('kmT') && !kinds.contains('km')) ['TOTAL KM', '${fmt(tKm)} KM'],
        if ((has('hrT') || has('rT') || has('tN') || has('tG')) && !kinds.contains('hr')) ['TOTAL HOURS', '${fmt(tHr)} HRS'],
        if (has('hr1')) ['1ST HR / 2ND HRS', '${fmt(r2(list.fold<num>(0, (s, r) => s + hr1(r))))} / ${fmt(r2(list.fold<num>(0, (s, r) => s + hr2(r))))} HRS'],
        if (has('trip') && !kinds.contains('trip')) ['TOTAL TRIPS', fmt(tTrips)],
      ];
      if (fm == 'I') {
        final tN = r2(list.where((r) => r['shift'] == 'Night' && !kDayStatus.contains(_mode(r))).fold<num>(0, (s, r) => s + _n(r['trip'])));
        work.addAll([
          ['DAY TRIPS', fmt(r2(tTrips - tN))],
          ['NIGHT TRIPS', fmt(tN)]
        ]);
      }
      lf = [...lon, ...work, if (hasDiesel || has('dQ')) lz[0], if (hasDiesel) ...[lz[1], lz[2]]];
    }
    final nB = lf.length > rr.length ? lf.length : rr.length;
    final bill = StringBuffer('<table class="lb-bill"><tbody>');
    for (var k = 0; k < nB; k++) {
      final l = k < lf.length ? lf[k] : ['', ''], r = k < rr.length ? rr[k] : ['', ''];
      bill.write('<tr><th>${l[0]}</th><td>${l[1]}</td><th>${r[0]}</th><td>${r[1]}</td></tr>');
    }
    bill.write('<tr class="net"><th colspan="3">NET PAYABLE AMOUNT <small>(basic ₹ ${n2(basic)} = payable − excess diesel; + GST − TDS)</small></th><td>${payable != 0 ? '₹ ${n2(netPay)}' : '–'}</td></tr></tbody></table>'
        '${payable != 0 ? '' : '<p class="lb-note">No BOQ for this machinery in these dates – the amounts are left blank (make its BOQ in Vendor BOQ).</p>'}');
    const signs = [
      ['CONTRACTOR', 'SUBCONTRACTOR'],
      ['PREPARED & CHECKED BY', 'MECHANICAL DEPT'],
      ['CHECKED BY', 'BILLING DEPT'],
      ['VERIFIED BY', 'PROJECT MANAGER'],
      ['APPROVED BY', 'GENERAL MANAGER']
    ];
    final sign = '<div class="lb-sign">${signs.map((x) => '<div><span></span><b>${x[0]}</b><small>${x[1]}</small></div>').join()}</div>';
    sheets.write('<section class="lbsheet">${sample.isNotEmpty ? '<div style="font:700 10pt Arial;color:#B45309;margin:0 0 4px">SAMPLE – ${_e(_up(sample))}</div>' : ''}$headHtml$tableF$bill$sign</section>');
  }
  final title = 'Log Book${nos.length == 1 ? ' – ${nos.first}' : ''} – $periodText';
  final orient = portrait
      ? '@page { size: A4 portrait; margin: 10mm 9mm 12mm 9mm; } .sheet { width: 194mm; min-height: 275mm; } @media print { .sheet { width: auto; min-height: 0; } } @media screen { body.rep-lb .sheet { box-sizing: content-box; width: 192mm; padding: 10mm 9mm 12mm; } }'
      : '@page { size: A4 landscape; margin: 9mm 8mm 12mm 8mm; } .sheet { width: 281mm; min-height: 189mm; } @media print { .sheet { width: auto; min-height: 0; } .lbsheet { min-height: 180mm; } } @media screen { body.rep-lb .sheet { box-sizing: content-box; width: 281mm; padding: 9mm 8mm 12mm; } }';
  final foot = '@page { @bottom-left { content: "${printName.replaceAll(RegExp(r'["\\]'), '')}  |  Fleet ERP"; } }';
  final html = '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${_e(title)}</title>'
      '<style>$kLbCss $foot</style><style id="orient">$orient</style></head><body class="rep rep-lb"><div class="sheet">$sheets</div></body></html>';
  return LbPrint(title, html, '$sheets');
}

/// "View format": the format with SAMPLE lines (as the web's Log Book Format page).
List<Map<String, dynamic>> lbSampleRows(String f, String today) {
  final d0 = today.substring(0, 8);
  String dd(int n) => '$d0${n.toString().padLeft(2, '0')}';
  const base = {'no': 'MH-00-XX-0000', 'type': 'SAMPLE', 'owner': 'SAMPLE VENDOR', 'shift': 'Day', 'odsl': 0, 'qty': '', 'stdUse': '', 'stock': ''};
  if (f == 'I') {
    Map<String, dynamic> tr(String sh, int d, List<List<String>> l) => {
          ...base, 'date': dd(d), 'shift': sh, 'mode': 'Trip', 'unit': 'Trip', 'trip': l.length,
          'itemWork': {'_trips': [for (final x in l) {'c': x[0], 'a': x[1], 'b': x[2], 'ch': x[3], 'u': x[4]}]},
        };
    return [
      tr('Day', 1, [
        ['WT-501', '08:10', '08:55', '12+500', 'Curing'],
        ['WT-502', '09:20', '10:05', '13+000', 'Dust suppression']
      ]),
      tr('Night', 1, [
        ['WT-503', '21:30', '22:15', '12+800', 'Compaction']
      ]),
      tr('Day', 2, [
        ['WT-504', '07:45', '08:30', '14+200', 'Curing']
      ]),
    ];
  }
  return [
    {...base, 'date': dd(1), 'mode': 'KM + Hrs', 'unit': 'KM + Hrs', 'okm': 1000, 'ckm': 1040, 'wkm': 40, 'ohr': 500, 'chr': 506, 'whr': 6, 'chFrom': 'KM 12+500', 'chTo': '13+000', 'work': 'Excavation', 'challan': 'CH-101', 'remark': 'JCB work'},
    {...base, 'date': dd(2), 'mode': 'Time', 'unit': 'Time', 'tStart': '08:00', 'tEnd': '13:30', 'tBrk': 30, 'whr': 5, 'wkm': '', 'challan': 'CH-102', 'work': 'Loading'},
    {...base, 'date': dd(3), 'mode': 'Trip', 'unit': 'Trip', 'trip': 12, 'challan': 'CH-103, CH-104', 'work': 'Murum carting'},
    {...base, 'date': dd(4), 'mode': 'KM', 'unit': 'KM', 'okm': 1040, 'ckm': 1075, 'wkm': 35, 'work': 'Shifting'},
    {...base, 'date': dd(5), 'mode': 'Holiday', 'unit': 'Holiday'},
    {...base, 'date': dd(6), 'mode': 'Idle', 'unit': 'Idle'},
  ];
}
const kLbCss = '@page { size: A4 portrait; margin: 9mm 8mm 12mm 8mm; @bottom-left { content: "Rachana Construction Limited  |  Fleet ERP"; font: 7.5pt Arial, sans-serif; color: #555; } @bottom-right { content: "Page " counter(page) " of " counter(pages); font: 7.5pt Arial, sans-serif; color: #555; } } * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; } html, body { margin: 0; background: #e5e7eb; font: 10pt Arial, sans-serif; color: #000; } .sheet { width: 281mm; min-height: 189mm; margin: 12px auto; padding: 9mm 8mm; background: #fff; box-shadow: 0 2px 10px rgba(0,0,0,.2); } .bar { position: relative; background: #22303A; color: #fff; padding: 8px 14px; display: flex; gap: 10px; align-items: center; font: 13px Arial; } body.rep-lb { font-family: Arial, sans-serif; } .lbsheet + .lbsheet, .billsheet + .lbsheet, .lbsheet + .billsheet { break-before: page; } .lbsheet { display: flex; flex-direction: column; min-height: 263mm; break-inside: avoid; } .lb-head { display: grid; grid-template-columns: 30mm 1fr 30mm; align-items: center; gap: 4mm; border-bottom: 2px solid #111; padding-bottom: 2mm; margin-bottom: 2mm; } .lb-logo { display: flex; align-items: center; } .lb-logo-s img { height: 19mm; width: auto; display: block; } .lb-logo-r { width: 30mm !important; } .lb-title { text-align: center; text-transform: uppercase; } .lb-co { font: 800 17pt Arial, sans-serif; letter-spacing: .04em; color: #111; } .lb-site { font: 700 9.5pt Arial, sans-serif; margin-top: 1mm; letter-spacing: .06em; } .lb-name { font: 700 10.5pt Arial, sans-serif; margin-top: 1mm; } .lb-owner { font: 700 9pt Arial, sans-serif; margin-top: 1.2mm; letter-spacing: .03em; } .lb-mach { display: inline-block; margin-top: 1.2mm; padding: .5mm 3mm; border: 1.3px solid #111; font: 800 10pt Arial, sans-serif; letter-spacing: .03em; } .lb-meta { font-size: 7pt; line-height: 1.55; text-align: right; } table.lb-t { width: 100%; border-collapse: collapse; font-size: 7pt; } table.lb-t th, table.lb-t td { border: 0.7px solid #333; padding: 0.4px 3px; } table.lb-t th { background: #E9ECEF; font-size: 6.8pt; text-align: center; font-weight: 700; line-height: 1.15; } table.lb-t td.n { text-align: right; } table.lb-t td.c { text-align: center; } table.lb-t { table-layout: fixed; } table.lb-t td { white-space: nowrap; overflow: hidden; line-height: 1.12; } table.lb-t td:last-child { white-space: normal; font-size: 6.6pt; } table.lb-t td.lb-sm { font-size: 6.6pt; } table.lb-t.lb-auto { table-layout: auto; } table.lb-t.lb-auto th { word-break: keep-all; overflow-wrap: normal; hyphens: none; padding: 1px 2px; } table.lb-t.lb-auto td { overflow: visible; padding: 0.4px 2px; } table.lb-t.lb-auto td.lb-wk { min-width: 30mm; white-space: normal; } table.lb-t.lb-auto td:last-child { min-width: 30mm; } table.lb-t.lb-auto td.lb-ch { min-width: 16mm; } table.lb-t.lb-auto td.lb-chx { min-width: 16mm; white-space: normal; } table.lb-t th, table.lb-t td { hyphens: none; } table.lb-t th small { font-size: 5.6pt; font-weight: 600; } table.lb-t thead th { font-size: 6pt; padding: 1.5px 1px; overflow-wrap: anywhere; text-align: center !important; vertical-align: middle; } table.lb-t tfoot td { background: #FFF3C4; font-weight: 700; } table.lb-bill { width: 100%; border-collapse: collapse; margin-top: 2.5mm; font-size: 7.8pt; } table.lb-bill th, table.lb-bill td { border: 0.7px solid #333; padding: 0.9px 5px; } table.lb-bill th { text-align: left; background: #F4F6F8; width: 26%; } table.lb-bill td { text-align: right; width: 24%; font-weight: 700; } table.lb-bill td.lb-rate { font-size: 7pt; font-weight: 600; white-space: normal; } table.lb-bill th small { display: block; font-size: 6.4pt; font-weight: 400; color: #444; text-transform: none; } table.lb-bill td small { font-size: 6.4pt; font-weight: 400; } table.lb-bill td small:last-child:not(:first-child) { display: block; } table.lb-bill tr.net th { text-align: right; } table.lb-bill tr.net th small { display: inline; margin-left: 6px; } table.lb-bill tr.net th, table.lb-bill tr.net td:first-of-type { background: #FFF3C4; font-size: 9pt; } .lb-note { font-size: 7pt; color: #B3261E; margin: 1mm 0 0; } .lb-sign { display: grid; grid-template-columns: repeat(5, 1fr); gap: 5mm; margin-top: auto; padding-top: 12mm; text-align: center; break-inside: avoid; } .lb-sign span { height: 0; } .lb-sign b { margin-top: 1mm; } .lb-sign span { display: block; border-top: 1px solid #111; margin-bottom: 1mm; } .lb-sign b { display: block; font-size: 7.5pt; } .lb-sign small { font-size: 6.8pt; color: #333; }';
