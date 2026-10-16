/* EDIT LOG BOOK (3.6.0) – one machinery and a range of dates: all its entries open together, everything is worked out again while
 * typing, and one save sends the whole lot (getLogEditData → saveLogBulk). The web's rules word for word (App.html "EDIT LOG BOOK",
 * LX): a changed Close moves the Start of the next row that reads that meter; Start below the Close before it is red ("Use it");
 * one entry a shift and a Full Day entry stands alone; a machinery whose BOQ has two or more hour (or KM) works may have a row for
 * each work in one shift (saved as ONE entry with its rows, "_parts"); a machinery on hours only (update-77 / 78) may start a row
 * higher (the hours between are not counted) and have a row by Time among its rows by Hrs, and no other entry is moved by it;
 * dates of a submitted RA Bill are shown, not changed (the Super Admin changes them); "+ Add row" (the first free date, or the other
 * shift of the ticked dates), "Add all missing dates", "+ work in this shift", Delete; the opening diesel of the month on the 1st;
 * the Item-wise BOQ box (pick one work, or Split). Only the screen is the phone's own (screens/log_edit.dart). */
import 'assets.dart' show worksOf;
import 'dash.dart' show kDayStatus;
import 'format.dart';
import 'masters.dart' show itemKind;
import 'session.dart';

const kWaysAll = ['KM', 'Hrs', 'KM + Hrs', 'Time', 'Trip', 'Day'];
const kItemWords = {'hr': 'hr', 'km': 'km', 'trip': 'trips'};

/// As the web's Math.round(n * 100) / 100 (a half goes up, also below 0).
num r2(num n) => (n * 100 + .5).floor() / 100;

/// '' / null → '' (empty), else the number (as the web's lxN).
Object lxN(Object? v) => v == null || v == '' ? '' : (v is num ? v : (num.tryParse('$v'.trim()) ?? ''));

/// A value as the web writes it with String(): 1008 (not 1008.0), '' for nothing.
String js(Object? v) {
  if (v == null) return '';
  if (v is double && v.isFinite && v == v.truncateToDouble() && v.abs() < 1e15) return v.toInt().toString();
  return '$v';
}

num _n0(Object? v) => asNum(v) ?? 0;
String _s(Object? v) => v == null ? '' : '$v';

// ---------- times (as the web: tMin, slotMin, slotsParse, slotsGap, lgTimeHrs) ----------
int? tMin(String t) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(t);
  return m == null ? null : int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

int? slotMin(String a, String b) {
  final x = tMin(a), y = tMin(b);
  if (x == null || y == null) return null;
  var d = y - x;
  if (d <= 0) d += 1440;
  return d;
}

/// '11:00-13:00,14:00-17:00' → [[11:00, 13:00], [14:00, 17:00]]
List<List<String>> slotsParse(Object? v) => [
      for (final x in _s(v).split(','))
        if (RegExp(r'^\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*$').firstMatch(x) case final m?) [m.group(1)!, m.group(2)!],
    ];

/// Minutes between the times of a split.
int slotsGap(List<List<String>> sl) {
  int? cur, first;
  var mins = 0;
  for (final x in sl) {
    final a = tMin(x[0]), d = slotMin(x[0], x[1]);
    if (a == null || d == null) return 0;
    var at = a;
    if (cur != null) {
      while (at < cur) {
        at += 1440;
      }
    }
    first ??= at;
    cur = at + d;
    mins += d;
  }
  return first == null ? 0 : (cur! - first) - mins;
}

/// Hours of From – To less the break in minutes ('' when a time is missing).
Object lgTimeHrs(String a, String b, Object? brk) {
  if (a.isEmpty || b.isEmpty) return '';
  final x = tMin(a), y = tMin(b);
  if (x == null || y == null) return 0;
  num mins = y - x;
  if (mins <= 0) mins += 1440;
  final br = _n0(brk);
  mins -= br > 0 ? br : 0;
  return mins > 0 ? r2(mins / 60) : 0;
}

/// The typed items as one comparable text (blank / 0 left out, the first Day item is the default) – as the web's itemSig.
String itemSig(List<Map> items, Map<String, Object?> vals) {
  final days = items.where((it) => itemKind('${it['basis']}') == 'day').toList(), first = days.isEmpty ? '' : '${days.first['name']}';
  final keys = vals.keys.where((k) => k == '_day' ? days.length > 1 && _s(vals[k]).isNotEmpty && vals[k] != first : _n0(vals[k]) > 0).toList()..sort();
  return keys.map((k) => k == '_day' ? 'Day item: ${vals[k]}' : '$k ${js(_n0(vals[k]))}').join(', ');
}

// =====================================================================================================================
//  ONE ROW OF THE GRID
// =====================================================================================================================
class LxRow {
  String key = '', date = '', shift = 'Full Day', mode = '';
  bool isNew = false, half = false, sel = false;
  Object okm = '', ckm = '', ohr = '', chr = '', tBrk = '', trip = '', odsl0 = '', odSet = '';
  String tStart = '', tEnd = '', tSlots = '', challan = '', remark = '', chFrom = '', chTo = '', work = '', itemSig = '';
  Map<String, Object?> items = {};
  Map<String, String>? pick; // the work picked of each kind ('' = none yet, '_split') – as the web's r._pick
  Map<String, Object?>? orig; // as loaded (a new row: {})
  Map? lock; // the submitted bill that holds its date
  num? fixK, fixH; // "Use it": the Start it should have

  static const compared = ['shift', 'mode', 'half', 'okm', 'ckm', 'ohr', 'chr', 'tStart', 'tEnd', 'tBrk', 'trip', 'challan', 'remark', 'chFrom', 'chTo', 'work', 'odSet', 'itemSig'];

  Object? operator [](String f) => switch (f) {
        'key' => key,
        'date' => date,
        'shift' => shift,
        'mode' => mode,
        'half' => half,
        'okm' => okm,
        'ckm' => ckm,
        'ohr' => ohr,
        'chr' => chr,
        'tStart' => tStart,
        'tEnd' => tEnd,
        'tBrk' => tBrk,
        'tSlots' => tSlots,
        'trip' => trip,
        'challan' => challan,
        'remark' => remark,
        'chFrom' => chFrom,
        'chTo' => chTo,
        'work' => work,
        'odSet' => odSet,
        'itemSig' => itemSig,
        _ => null,
      };

  void operator []=(String f, Object? v) {
    switch (f) {
      case 'okm':
        okm = lxN(v);
      case 'ckm':
        ckm = lxN(v);
      case 'ohr':
        ohr = lxN(v);
      case 'chr':
        chr = lxN(v);
      case 'tBrk':
        tBrk = lxN(v);
      case 'trip':
        trip = lxN(v);
      case 'odSet':
        odSet = lxN(v);
      case 'tStart':
        tStart = _s(v);
      case 'tEnd':
        tEnd = _s(v);
      case 'challan':
        challan = _s(v);
      case 'remark':
        remark = _s(v);
      case 'chFrom':
        chFrom = _s(v);
      case 'chTo':
        chTo = _s(v);
      case 'work':
        work = _s(v);
    }
  }

  Map<String, Object?> snap() => {for (final k in [...compared, 'date', 'tSlots']) k: this[k]};

  LxRow copy() => LxRow()
    ..key = key
    ..date = date
    ..shift = shift
    ..mode = mode
    ..isNew = isNew
    ..half = half
    ..okm = okm
    ..ckm = ckm
    ..ohr = ohr
    ..chr = chr
    ..tStart = tStart
    ..tEnd = tEnd
    ..tBrk = tBrk
    ..tSlots = tSlots
    ..trip = trip
    ..challan = challan
    ..remark = remark
    ..chFrom = chFrom
    ..chTo = chTo
    ..work = work
    ..odsl0 = odsl0
    ..odSet = odSet
    ..items = {...items}
    ..itemSig = itemSig
    ..pick = pick == null ? null : {...pick!};
}

/// The item box of a row (the web's itemBoxHtml / itemBoxCalc): the works of each kind, the pick, what is left for the "rest" item.
class LxKind {
  LxKind(this.k, this.names, this.inputs, this.restName);
  final String k, restName;
  final List<String> names, inputs; // every work of the kind (the chips) · the works typed (not "rest")
  bool get group => names.length > 1; // a work to pick (or Split)
  String pick = '', say = '', restSay = '';
  bool restBad = false, need = false;
}

class LxBox {
  final kinds = <LxKind>[];
  final days = <String>[]; // Day items to pick from (two or more)
  String day = '', bad = '';
  bool get empty => kinds.isEmpty && days.isEmpty;
}

/// The figures of a row (lxCalc).
class LxFig {
  Object wk = '', wh = '';
  num need = 0, open = 0, iss = 0, close = 0;
  bool bad = false, changed = false, odBox = false, odTyped = false, overCap = false, misK = false, misH = false, fixable = false;
  String total = '–', note = '', gapNote = '', slotNote = '', overNote = '';
  LxBox? box;
}

class LxCalc {
  final figs = <LxFig>[];
  num tk = 0, th = 0, ti = 0, tc = 0, closing = 0;
  int bad = 0, chg = 0, slots = 0, pbad = 0, mis = 0, entries = 0, deleted = 0;
  bool canSave = false;
  String sum = '', badSay = '';
  int get total => chg + deleted;
}

// =====================================================================================================================
//  THE GRID
// =====================================================================================================================
class LogEdit {
  LogEdit(Map<String, dynamic> data, {required this.superUser, required this.today, this.canEdit = true}) : d = data {
    _load();
  }
  final Map<String, dynamic> d;
  final bool superUser, canEdit;
  final String today;
  List<LxRow> rows = [];
  final deleted = <String>[];
  final odsl = '';
  final cut = <String, bool>{};
  final pc = <String, int>{};

  Map<String, dynamic> get m => (d['machine'] as Map? ?? {}).cast<String, dynamic>();
  Machine get mach => Machine(m);
  String get no => '${m['id'] ?? ''}';
  String get from => '${d['from'] ?? ''}';
  String get to => '${d['to'] ?? ''}';
  String get unit => '${m['unit'] ?? ''}';
  List<Map> get locks => (d['locks'] as List? ?? const []).whereType<Map>().toList();
  Map get boqItems => d['boqItems'] as Map? ?? const {};
  bool get itemCol => boqItems.isNotEmpty;
  List<Map> boqOf(String date) => (boqItems[date] as List? ?? const []).whereType<Map>().toList();
  List<String> get modes => mach.modes;
  List<String> get modesAll => [...modes, ...kDayStatus];
  bool get meterKm => Machine.fmtModes[mach.lbFormat]?.any(hasKm) ?? (worksOf(m).contains('KM') || worksOf(m).contains('KM + Hrs'));
  bool get meterHr => Machine.fmtModes[mach.lbFormat]?.any(hasHr) ?? (worksOf(m).contains('Hrs') || worksOf(m).contains('KM + Hrs'));
  bool get ho => meterHr && !meterKm; // update-77: read by the hour meter only

  String way(LxRow r) => r.mode.isNotEmpty ? r.mode : unit;
  String slot(LxRow r) => '${r.date}|${r.shift}';
  List<LxRow> slotRows(LxRow r) => rows.where((x) => x.date == r.date && x.shift == r.shift).toList();

  /// The submitted bill that holds a date (null = free; the Super Admin changes them – update-108).
  Map? lockOf(String dk) => superUser ? null : locks.where((l) => '${l['from']}'.compareTo(dk) <= 0 && dk.compareTo('${l['to']}') <= 0).firstOrNull;

  /// The kind of work that may have a row each on this row's date ('hr' / 'km'; '' = none).
  String partKind(LxRow r) {
    final its = boqOf(r.date), w = way(r);
    int n(String k) => its.where((it) => itemKind('${it['basis']}') == k).length;
    if (ho && (hasHr(w) || w == 'Time')) return 'hr';
    return hasHr(w) && n('hr') > 1 ? 'hr' : hasKm(w) && n('km') > 1 ? 'km' : '';
  }

  /// Its rows need no work picked when the BOQ has fewer than two hour works (just its times of work).
  bool plain(LxRow r) => ho && boqOf(r.date).where((it) => itemKind('${it['basis']}') == 'hr').length < 2;
  bool later(LxRow r) => partKind(r).isNotEmpty && slotRows(r).first != r;
  bool canMore(LxRow r) => partKind(r).isNotEmpty && r.lock == null && !kDayStatus.contains(way(r));

  num rowQty(LxRow r, String k) {
    if (k == 'hr' && way(r) == 'Time') return asNum(lgTimeHrs(r.tStart, r.tEnd, r.tBrk)) ?? 0;
    if (k == 'hr') return r.ohr != '' && r.chr != '' ? r2(_n0(r.chr) - _n0(r.ohr)) : 0;
    return r.okm != '' && r.ckm != '' ? r2(_n0(r.ckm) - _n0(r.okm)) : 0;
  }

  /// The ONE work of a row ('' = none picked yet, or Split).
  String pickOf(LxRow r, String k) {
    final its = boqOf(r.date).where((it) => itemKind('${it['basis']}') == k).toList(), pk = r.pick?[k];
    if (pk != null) return pk.isNotEmpty && pk != '_split' && its.any((it) => it['name'] == pk) ? pk : '';
    final typed = its.where((it) => it['qty'] != 'rest' && _n0(r.items['${it['name']}']) > 0).toList(), rest = its.where((it) => it['qty'] == 'rest').firstOrNull, tot = rowQty(r, k);
    if (typed.isEmpty) return rest == null ? '' : '${rest['name']}';
    return typed.length == 1 && (_n0(r.items['${typed.first['name']}']) - tot).abs() < .005 ? '${typed.first['name']}' : '';
  }

  Map<String, Object?> otherItems(List<LxRow> g, String kind) {
    final its = boqOf(g.first.date), o = <String, Object?>{};
    for (final x in g) {
      for (final n in x.items.keys) {
        final it = its.where((q) => q['name'] == n).firstOrNull, v = asNum(x.items[n]) ?? 0;
        if (it != null && itemKind('${it['basis']}') != kind && itemKind('${it['basis']}') != 'day' && v > 0) o[n] = r2(_n0(o[n]) + v);
      }
    }
    return o;
  }

  String sig(LxRow r) {
    final k = partKind(r);
    return itemSig(boqOf(r.date), r.items) + (k.isNotEmpty ? '|${pickOf(r, k)}' : '');
  }

  /// What is wrong with this row as one of several rows of its shift: null = this machinery cannot have several rows a shift, '' = fine.
  String? partsProblem(List<LxRow> grp, LxRow r) {
    final k = partKind(grp.first);
    if (k.isEmpty || grp.any((x) => kDayStatus.contains(way(x)) || way(x) == kNoReading)) return null;
    final mixOk = ho && grp.every((x) => hasHr(way(x)) || way(x) == 'Time');
    if (!mixOk && grp.any((x) => way(x) != way(grp.first))) return 'the rows of one shift must be measured the same way (${way(grp.first)}).';
    if (mixOk && !grp.any((x) => hasHr(way(x)))) return 'the rows of this shift are all by Time – keep one row and give it its times (or one row of the shift by Hrs).';
    final j = grp.indexOf(r), names = boqOf(r.date).where((it) => itemKind('${it['basis']}') == k).map((it) => '${it['name']}').join(' / ');
    if (!(rowQty(r, k) > 0)) return 'this row has no work yet – type its ${way(r) == 'Time' ? 'From and To' : 'Close'} (or delete the row).';
    if (plain(r)) return '';
    final p = pickOf(r, k);
    if (p.isEmpty) return 'each row of this shift is ONE work – press $names (not Split).';
    if (j > 0 && !ho && pickOf(grp[j - 1], k) == p) return 'same work as the row above ($p) – make them one row, or press the other work.';
    return '';
  }

  static const _ord = {'Day': 0, 'Full Day': 0, 'Night': 1};

  /// By date and shift; the rows of one shift keep their order (a stable sort, as the browser's).
  void sort() {
    final at = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    rows.sort((a, b) {
      final c = a.date.compareTo(b.date);
      if (c != 0) return c;
      final s = (_ord[a.shift] ?? 0) - (_ord[b.shift] ?? 0);
      return s != 0 ? s : at[a]! - at[b]!;
    });
  }

  bool changed(LxRow r) {
    if (r.isNew || (r.key.isNotEmpty && cut[r.key] == true)) return true;
    final o = r.orig ?? const {};
    return LxRow.compared.any((k) => js(r[k]) != js(o[k]));
  }

  bool get dirty => deleted.isNotEmpty || rows.any((r) => r.isNew || changed(r));

  /// The Close of the last row before [i] that read that meter (else the entry before these dates).
  num? prevRead(int i, String f) {
    for (var k = i - 1; k >= 0; k--) {
      final r = rows[k];
      if ((f == 'ckm' ? hasKm(way(r)) : hasHr(way(r))) && r[f] != '') return _n0(r[f]);
    }
    final v = f == 'ckm' ? d['prevKm'] : d['prevHr'];
    return v == null || v == '' ? null : asNum(v);
  }

  int nextReader(int i, String f) {
    for (var k = i + 1; k < rows.length; k++) {
      if (f == 'ckm' ? hasKm(way(rows[k])) : hasHr(way(rows[k]))) return k;
    }
    return -1;
  }

  /// Diesel issued for a row, from the day's Diesel Issue (Full Day = both shifts; a later row of its shift: 0).
  num issued(LxRow r) {
    if (later(r)) return 0;
    final x = ((d['diesel'] as Map?)?[r.date] as Map?) ?? const {};
    final day = _n0(x['Day']), night = _n0(x['Night']);
    return r.shift == 'Full Day' ? r2(day + night) : r.shift == 'Night' ? night : day;
  }

  // ---------------------------------------------------------------------------------------------------------------
  //  OPEN
  // ---------------------------------------------------------------------------------------------------------------
  void _load() {
    final md0 = modesAll;
    for (final r0 in (d['rows'] as List? ?? const []).whereType<Map>()) {
      final r = r0.cast<String, dynamic>();
      final x = LxRow()
        ..key = _s(r['key'])
        ..half = r['half'] == true || r['half'] == 1
        ..date = _s(r['date'])
        ..shift = _s(r['shift']).isEmpty ? 'Full Day' : _s(r['shift']);
      final mo = _s(r['mode']), un = _s(r['unit']);
      x.mode = md0.contains(mo) ? mo : md0.contains(un) ? un : kWaysAll.contains(un) ? un : (md0.isNotEmpty ? md0.first : un);
      x
        ..okm = lxN(r['okm'])
        ..ckm = lxN(r['ckm'])
        ..ohr = lxN(r['ohr'])
        ..chr = lxN(r['chr'])
        ..tStart = _s(r['tStart'])
        ..tEnd = _s(r['tEnd'])
        ..tBrk = lxN(r['tBrk'])
        ..tSlots = _s(r['tSlots'])
        ..trip = lxN(r['trip'])
        ..challan = _s(r['challan'])
        ..remark = _s(r['remark'])
        ..chFrom = _s(r['chFrom'])
        ..chTo = _s(r['chTo'])
        ..work = _s(r['work']).isNotEmpty ? _s(r['work']) : _s(r['remark'])
        ..odsl0 = lxN(r['odsl'])
        ..odSet = lxN(r['odSet'])
        ..items = {...((r['itemWork'] as Map?) ?? const {}).cast<String, Object?>()};
      x.items.remove('_parts');
      x.itemSig = sig(x);
      final ps0 = (r['itemParts'] as List?)?.whereType<Map>().toList();
      final ps = ps0 != null && ps0.length > 1 ? ps0 : null, its = boqOf(x.date);
      pc[x.key] = ps?.length ?? 1;
      if (ps == null) {
        x.orig = x.snap();
        x.lock = lockOf(x.date);
        rows.add(x);
        continue;
      }
      // the entry holds the rows of its shift: one grid row for each work, its Start / Close worked out from the entry's Start
      var at = _n0(ps.first['k'] == 'hr' ? r['ohr'] : r['okm']);
      final lastR = [for (var j = 0; j < ps.length; j++) if (ps[j]['m'] != 'T') j].lastOrNull;
      for (var j = 0; j < ps.length; j++) {
        final p = ps[j], y = x.copy(), it = its.where((q) => q['name'] == p['n']).firstOrNull ?? const {};
        final k = _s(p['k']);
        if (p['m'] == 'T') {
          // update-78: a row by Time – its From / To and break, no reading
          final sl = slotsParse(_s(p['ts']).replaceAll(',', ', '));
          y
            ..mode = 'Time'
            ..ohr = ''
            ..chr = ''
            ..okm = ''
            ..ckm = '';
          y.tStart = sl.isEmpty ? '' : sl.first[0];
          y.tEnd = sl.isEmpty ? '' : sl.last[1];
          y.tSlots = sl.length > 1 ? sl.map((t) => '${t[0]}-${t[1]}').join(',') : '';
          final b = r2(_n0(p['tb']) + slotsGap(sl));
          y.tBrk = b == 0 ? '' : b;
        } else {
          final a = r2(at + _n0(p['g'])), b = r2(a + _n0(p['q']));
          at = b;
          if (k == 'hr') {
            y
              ..ohr = a
              ..chr = b;
            if (j > 0) {
              y
                ..okm = lxN(r['ckm'])
                ..ckm = lxN(r['ckm']);
            }
          } else {
            y
              ..okm = a
              ..ckm = b;
            if (j > 0) {
              y
                ..ohr = lxN(r['chr'])
                ..chr = lxN(r['chr']);
            }
          }
          if (j == lastR) {
            if (k == 'hr') {
              y.chr = lxN(r['chr']);
            } else {
              y.ckm = lxN(r['ckm']);
            }
          }
        }
        final others = <String, Object?>{};
        if (j == 0) {
          for (final n in x.items.keys) {
            final o = its.where((q) => q['name'] == n).firstOrNull;
            if (o != null && itemKind('${o['basis']}') != k) others[n] = x.items[n];
          }
        }
        final pn = _s(p['n']);
        y.items = {if (_s(x.items['_day']).isNotEmpty) '_day': x.items['_day'], ...others, if (pn.isNotEmpty && it['qty'] != 'rest') pn: p['q']};
        y.pick = {k: pn};
        y.itemSig = sig(y);
        y
          ..challan = _s(p['c'])
          ..remark = _s(p['p'])
          ..chFrom = _s(p['f'])
          ..chTo = _s(p['t'])
          ..work = _s(p['w']);
        if (j > 0) y.trip = '';
        y.orig = y.snap();
        y.lock = lockOf(y.date);
        rows.add(y);
      }
    }
    sort();
  }

  // ---------------------------------------------------------------------------------------------------------------
  //  THE ITEM BOX OF A ROW (itemBoxHtml + itemBoxCalc + itemBoxRead)
  // ---------------------------------------------------------------------------------------------------------------
  /// [tot]: hr / km / trip of the row. The pick of each kind and the values it puts in; the problem (box.bad).
  LxBox? _box(LxRow r, Map<String, num> tot) {
    final its = boqOf(r.date), w = way(r);
    if (its.isEmpty || w == 'Holiday' || w == 'Breakdown') return null;
    final box = LxBox();
    if (w != 'Idle') {
      for (final k in const ['hr', 'km', 'trip']) {
        final of = its.where((it) => itemKind('${it['basis']}') == k).toList();
        if (of.isEmpty) continue;
        final rest = of.where((it) => it['qty'] == 'rest').firstOrNull;
        box.kinds.add(LxKind(k, [for (final it in of) '${it['name']}'], [for (final it in of) if (it['qty'] != 'rest') '${it['name']}'], rest == null ? '' : '${rest['name']}'));
      }
    }
    final days = its.where((it) => itemKind('${it['basis']}') == 'day').map((it) => '${it['name']}').toList();
    if (days.length > 1) {
      box.days.addAll(days);
      box.day = days.contains(_s(r.items['_day'])) ? _s(r.items['_day']) : days.first;
    }
    final vals = <String, Object?>{for (final x in box.kinds) for (final n in x.inputs) n: lxN(r.items[n])};
    var bad = '';
    for (final x in box.kinds.where((x) => x.group)) {
      final total = (tot[x.k] ?? 0) > 0 ? tot[x.k]! : 0;
      final typed = x.inputs.where((n) => _n0(vals[n]) > 0).toList();
      var p = r.pick?[x.k];
      if (p == null) {
        p = typed.isEmpty ? (x.restName.isNotEmpty ? x.restName : '_split') : typed.length == 1 && total > 0 && (_n0(vals[typed.first]) - total).abs() < .005 ? typed.first : '_split';
        (r.pick ??= {})[x.k] = p;
      }
      if (p.isEmpty && typed.isNotEmpty) {
        p = '_split';
        r.pick![x.k] = p;
      }
      if (p.isNotEmpty && p != '_split') {
        for (final n in x.inputs) {
          vals[n] = n == p && total > 0 ? total : '';
        }
      }
      x.pick = p;
      x.say = p.isNotEmpty && p != '_split' ? (total > 0 ? '${fmtNum(total)} ${kItemWords[x.k]}' : '') : p.isEmpty ? '← pick' : '';
      x.need = p.isEmpty;
      if (p.isEmpty && total > 0) bad = 'Pick the work of this entry: ${[...x.names, 'Split'].join(' / ')}.';
    }
    for (final x in box.kinds) {
      final total = (tot[x.k] ?? 0) > 0 ? tot[x.k]! : 0;
      final sum = x.inputs.fold<num>(0, (a, n) => a + _n0(vals[n])), left = r2(total - sum);
      if (left < -.005) {
        bad = 'Items have ${fmtNum(r2(sum))} ${kItemWords[x.k]} but the entry has only ${fmtNum(total)} ${kItemWords[x.k]}.';
        x.restSay = '${fmtNum(r2(-left))} ${kItemWords[x.k]} too many';
        x.restBad = true;
      } else if (x.restName.isNotEmpty) {
        x.restSay = '${x.restName} ${fmtNum(left)} ${kItemWords[x.k]}';
      } else {
        x.restSay = left > .005 ? '${fmtNum(left)} ${kItemWords[x.k]} not given to an item' : '';
      }
    }
    box.bad = bad;
    // a picked work follows the entry's total: the row's items are what the box now holds
    if (box.kinds.any((x) => x.group)) {
      r.items = {...vals, if (box.days.isNotEmpty) '_day': box.day};
    }
    return box;
  }

  /// What the box holds now (after a typed item / a Day item picked) – the web's itemBoxRead.
  Map<String, Object?> boxRead(LxRow r) {
    final its = boqOf(r.date), w = way(r), o = <String, Object?>{};
    if (its.isEmpty || w == 'Holiday' || w == 'Breakdown') return {...r.items};
    if (w != 'Idle') {
      for (final k in const ['hr', 'km', 'trip']) {
        for (final it in its.where((it) => itemKind('${it['basis']}') == k && it['qty'] != 'rest')) {
          o['${it['name']}'] = lxN(r.items['${it['name']}']);
        }
      }
    }
    final days = its.where((it) => itemKind('${it['basis']}') == 'day').map((it) => '${it['name']}').toList();
    if (days.length > 1) o['_day'] = days.contains(_s(r.items['_day'])) ? r.items['_day'] : days.first;
    return o;
  }

  /// A work pressed in the item box of a row ('_split' = Split).
  void pressWork(LxRow r, String k, String p) {
    final was = r.pick?[k];
    (r.pick ??= {})[k] = p;
    if (p == '_split' && was != null && was.isNotEmpty && was != '_split') {
      for (final it in boqOf(r.date).where((it) => itemKind('${it['basis']}') == k)) {
        if (r.items.containsKey('${it['name']}')) r.items['${it['name']}'] = '';
      }
    }
    r.items = boxRead(r);
  }

  /// A quantity typed for one work (Split) – or the Day item picked ('_day').
  void typeItem(LxRow r, String name, Object? v) {
    r.items[name] = name == '_day' ? v : lxN(v);
    r.items = boxRead(r);
  }

  // ---------------------------------------------------------------------------------------------------------------
  //  WORKED OUT LIVE (lxCalc)
  // ---------------------------------------------------------------------------------------------------------------
  LxCalc calc() {
    final c = LxCalc(), kmStd = _n0(m['kmStd']), hrStd = _n0(m['hrStd']), capX = _n0(m['tankCap']) > 0 ? _n0(m['tankCap']) : 0;
    final prev = d['prev'] as Map?;
    num open = prev != null ? _n0(prev['stock']) : (odsl != '' ? _n0(odsl) : (rows.isNotEmpty && rows.first.odsl0 != '' ? _n0(rows.first.odsl0) : 0));
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i], f = LxFig(), w = way(r), km = hasKm(w), hr = hasHr(w), tm = w == 'Time', tp = w == 'Trip';
      f.wk = km && r.okm != '' && r.ckm != '' ? r2(_n0(r.ckm) - _n0(r.okm)) : '';
      f.wh = hr && r.ohr != '' && r.chr != '' ? r2(_n0(r.chr) - _n0(r.ohr)) : tm ? lgTimeHrs(r.tStart, r.tEnd, r.tBrk) : '';
      final wk = f.wk is num ? f.wk as num : null, wh = f.wh is num ? f.wh as num : null;
      f.need = r2((km && (wk ?? 0) > 0 && kmStd > 0 ? wk! / kmStd : 0) + ((hr || tm) && (wh ?? 0) > 0 && hrStd > 0 ? wh! * hrStd : 0));
      f.odBox = r.date.endsWith('-01') && !later(r);
      f.odTyped = f.odBox && r.odSet != '';
      if (f.odTyped) open = _n0(r.odSet);
      f.open = open;
      f.iss = issued(r);
      f.close = r2(open + f.iss - f.need);
      // Start must be the Close just before it (the row above, or the entry before these dates)
      final expK = km ? prevRead(i, 'ckm') : null, expH = hr ? prevRead(i, 'chr') : null;
      final grp = slotRows(r), inShift = later(r) && (!ho || grp.sublist(0, grp.indexOf(r)).any((x) => hasHr(way(x))));
      final okm = r.okm, ohr = r.ohr;
      final misK = expK != null && (okm == '' || _n0(okm) < expK || (inShift && _n0(okm) > expK));
      final misH = expH != null && (ohr == '' || _n0(ohr) < expH || (inShift && !ho && _n0(ohr) > expH));
      final gapK = expK != null && !misK && _n0(okm) > expK ? r2(_n0(okm) - expK) : 0, gapH = expH != null && !misH && _n0(ohr) > expH ? r2(_n0(ohr) - expH) : 0;
      r.fixK = misK ? expK : null;
      r.fixH = misH ? expH : null;
      f.misK = misK;
      f.misH = misH;
      if (misK || misH) {
        final what = [if (misK) '${fmtNum(expK)}${hr ? ' km' : ''}', if (misH) '${fmtNum(expH)}${km ? ' hr' : ''}'].join(' / ');
        f.note = '${inShift && !ho ? 'This work starts where the row above closed: ' : 'Start cannot be less than '}$what (Close of ${inShift ? 'the row above' : 'the last reading before it'})'
            '${r.lock != null ? ' – this entry is in RA Bill ${r.lock!['billNo']}: lower the Close before it' : ''}';
        f.fixable = r.lock == null;
      } else if (gapK > 0 || gapH > 0) {
        f.gapNote = [if (gapK > 0) '${fmtNum(gapK)} km', if (gapH > 0) '${fmtNum(gapH)} hr'].join(' + ') + (inShift ? ' not worked between the rows – not counted' : ' ran elsewhere before this entry – not counted');
      }
      String itemBad = '';
      if (itemCol) {
        f.box = _box(r, {'hr': wh ?? 0, 'km': wk ?? 0, 'trip': _n0(r.trip)});
        itemBad = f.box?.bad ?? '';
        r.itemSig = sig(r);
      }
      // one entry per shift on a date, and a Full Day entry stands alone (a row for each work: see partsProblem)
      final oth = rows.where((x) => x != r && x.date == r.date && x.shift != r.shift).toList();
      final partBad = grp.length > 1 ? partsProblem(grp, r) : '';
      final slotBad = partBad == null ? 'two entries on ${r.shift}' : oth.isNotEmpty && (r.shift == 'Full Day' || oth.any((x) => x.shift == 'Full Day')) ? 'a Full Day entry stands alone' : '';
      if (slotBad.isNotEmpty) {
        f.slotNote = '${showDate(r.date)}: $slotBad – make one Day and the other Night.';
        c.slots++;
      } else if ((partBad ?? '').isNotEmpty) {
        f.slotNote = '${showDate(r.date)} ${r.shift}: $partBad';
        c.pbad++;
      }
      final nh = d['nextHr'] as Map?;
      final overNext = ho && hr && nh != null && lxN(nh['ohr']) != '' && r.chr != '' && nextReader(i, 'chr') == -1 && _n0(r.chr) > _n0(nh['ohr']) + .005;
      if (overNext) f.overNote = 'Close cannot be more than ${fmtNum(_n0(nh['ohr']))} – the Start of the entry of ${showDate(_s(nh['date']))} (${nh['shift']}), which is not changed by itself. Correct one of them.';
      f.bad = slotBad.isNotEmpty || (partBad ?? '').isNotEmpty || misK || misH || overNext || (wk != null && wk < 0) || (wh != null && wh < 0) || (km && r.ckm == '') || (hr && r.chr == '') ||
          (tm && (r.tStart.isEmpty || r.tEnd.isEmpty || !((wh ?? 0) > 0))) || (tp && !(_n0(r.trip) > 0)) || itemBad.isNotEmpty;
      final tot = [if (wk != null) '${fmtNum(wk)} km', if (wh != null) '${fmtNum(wh)} hr', if (tp) '${fmtNum(_n0(r.trip))} trips', if (w == 'Day') 'day'].join('\n');
      f.total = tot.isEmpty ? '–' : tot;
      f.overCap = capX > 0 && f.close > capX;
      f.changed = changed(r);
      if (f.bad) c.bad++;
      if (f.changed) c.chg++;
      c.tk += (wk ?? 0) > 0 ? wk! : 0;
      c.th += (wh ?? 0) > 0 ? wh! : 0;
      c.ti += f.iss;
      c.tc += f.need;
      open = f.close;
      c.figs.add(f);
    }
    c.closing = open;
    c.tk = r2(c.tk);
    c.th = r2(c.th);
    c.ti = r2(c.ti);
    c.tc = r2(c.tc);
    c.entries = rows.map(slot).toSet().length;
    c.deleted = deleted.length;
    c.mis = rows.where((r) => r.fixK != null || r.fixH != null).length;
    c.sum = c.total > 0 ? '${c.chg} changed / new, ${c.deleted} deleted' : 'No changes yet';
    if (c.bad > 0) {
      c.badSay = '${c.bad} row(s) in red${c.slots > 0 ? ' – a date has two entries on the same shift' : c.mis > 0 ? ' – Start must be the Close before it' : c.pbad > 0 ? ' – a shift with a row for each work is not complete (see the note on the row)' : ' need a correct Close'}';
    }
    c.canSave = c.total > 0 && canEdit && c.bad == 0; // nothing wrong can be saved
    return c;
  }

  // ---------------------------------------------------------------------------------------------------------------
  //  TYPING AND CHANGING
  // ---------------------------------------------------------------------------------------------------------------
  /// A box typed in: a changed Close moves the next row's Start (the only automatic link). → the row moved (to show), or null.
  LxRow? type(LxRow r, String f, Object? v) {
    final was = r[f];
    r[f] = v;
    if (f != 'ckm' && f != 'chr') return null;
    final i = rows.indexOf(r), ni = nextReader(i, f);
    // update-77: a machinery on hours – another ENTRY never moves; only the next row of the SAME shift, while it starts where this row closed
    final hoStop = f == 'chr' && ho && ni > -1 && (slot(rows[ni]) != slot(r) || js(rows[ni].ohr) != js(was));
    final nx = ni > -1 && rows[ni].lock == null && !hoStop ? rows[ni] : null;
    if (nx == null) return null;
    nx[f == 'ckm' ? 'okm' : 'ohr'] = r[f];
    return nx;
  }

  /// A date / shift / way changed: the row moves to its place and takes its Start from the row before. A date of a submitted
  /// bill is refused (→ the words to show).
  String? change(LxRow r, String f, String v) {
    if (f == 'date') {
      final l = lockOf(v);
      if (l != null) return lockText(l, no, v, 'Log Book entry');
      r.date = v;
    } else if (f == 'shift') {
      r.shift = v;
    } else if (f == 'mode') {
      r.mode = v;
      if (!hasKm(v)) {
        r.okm = '';
        r.ckm = '';
      }
      if (!hasHr(v)) {
        r.ohr = '';
        r.chr = '';
      }
    }
    if (f != 'mode') fullToDay(r);
    place(r);
    return null;
  }

  void fullToDay(LxRow r) {
    if (r.shift != 'Night') return;
    for (final x in rows) {
      if (x != r && x.date == r.date && x.shift == 'Full Day') x.shift = 'Day';
    }
  }

  void place(LxRow r) {
    sort();
    final i = rows.indexOf(r), pk = prevRead(i, 'ckm'), ph = prevRead(i, 'chr');
    if (hasKm(way(r)) && pk != null) r.okm = pk;
    if (hasHr(way(r)) && ph != null && (!ho || r.isNew || r.ohr == '')) r.ohr = ph; // (a machinery on hours: a saved entry keeps its own Start)
    final nk = nextReader(i, 'ckm'), nh = nextReader(i, 'chr');
    if (nk > -1 && rows[nk].lock == null && hasKm(way(r)) && r.ckm != '') rows[nk].okm = r.ckm;
    if (!ho && nh > -1 && rows[nh].lock == null && hasHr(way(r)) && r.chr != '') rows[nh].ohr = r.chr;
  }

  /// "Use it": the suggested Start (the Close before it).
  void useFix(LxRow r) {
    if (r.lock != null) return;
    if (r.fixK != null) r.okm = r.fixK!;
    if (r.fixH != null) r.ohr = r.fixH!;
  }

  /// Rows taken out (× or Delete selected): the row after each gap starts where the row before it closed.
  void remove(List<LxRow> list) {
    final gone = list.where((r) => r.lock == null).toSet();
    final stay = <String>{for (final r in rows) if (!gone.contains(r) && r.key.isNotEmpty) r.key};
    for (final r in rows) {
      if (!gone.contains(r) || r.isNew || r.key.isEmpty) continue;
      if (stay.contains(r.key)) {
        cut[r.key] = true;
      } else if (!deleted.contains(r.key)) {
        deleted.add(r.key);
      }
    }
    rows = rows.where((r) => !gone.contains(r)).toList();
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r.lock != null) continue;
      final pk = prevRead(i, 'ckm'), ph = prevRead(i, 'chr');
      if (hasKm(way(r)) && pk != null) r.okm = pk;
      if (hasHr(way(r)) && ph != null && !ho) r.ohr = ph;
    }
  }

  void selectAll(bool on) {
    for (final r in rows) {
      r.sel = on && r.lock == null;
    }
  }

  /// Dates in the range without an entry (not today's future, not a date of a submitted bill).
  List<String> missing() {
    final have = {for (final r in rows) r.date}, out = <String>[], end = to.compareTo(today) < 0 ? to : today;
    var t = parseKey(from);
    for (var k = 0; k < 100; k++) {
      final dk = dateKey(t);
      if (dk.compareTo(end) > 0) break;
      if (!have.contains(dk) && lockOf(dk) == null) out.add(dk);
      t = DateTime(t.year, t.month, t.day + 1);
    }
    return out;
  }

  LxRow _blank(String dk, String shift, String mode) => LxRow()
    ..isNew = true
    ..date = dk
    ..shift = shift
    ..mode = mode
    ..orig = {};

  LxRow add(String dk) {
    final md = modes, last = rows.lastOrNull;
    final mode = last != null && md.contains(last.mode) && !mach.modesX.contains(last.mode) ? last.mode : (md.contains(unit) ? unit : (md.isNotEmpty ? md.first : unit));
    final r = _blank(dk, 'Full Day', mode);
    rows.add(r);
    place(r);
    return r;
  }

  /// The other shift of a date that has its entry (a Night under a Day; a Full Day becomes Day). null = not possible.
  LxRow? addShift(String dk) {
    final md = modes, same = rows.where((x) => x.date == dk).toList();
    bool has(String sh) => same.any((x) => x.shift == sh);
    if (same.isEmpty || (has('Day') && has('Night')) || lockOf(dk) != null) return null;
    final like = same.first;
    final r = _blank(dk, has('Night') ? 'Day' : 'Night', md.contains(way(like)) ? way(like) : (md.contains(unit) ? unit : (md.isNotEmpty ? md.first : unit)))
      ..chFrom = like.chFrom
      ..chTo = like.chTo;
    rows.add(r);
    fullToDay(r);
    place(r);
    if (hasKm(way(r)) && r.okm != '') r.ckm = r.okm; // closes where it starts, until a reading is typed
    if (hasHr(way(r)) && r.ohr != '') r.chr = r.ohr;
    return r;
  }

  /// "+ work in this shift": a row under this one, same date and shift.
  LxRow? addWork(LxRow of) {
    if (of.lock != null || partKind(of).isEmpty) return null;
    final r = _blank(of.date, of.shift, way(of))
      ..chFrom = of.chFrom
      ..chTo = of.chTo
      ..pick = {partKind(of): ''};
    rows.add(r);
    place(r);
    if (hasKm(way(r)) && r.okm != '') r.ckm = r.okm;
    if (hasHr(way(r)) && r.ohr != '') r.chr = r.ohr;
    return r;
  }

  String addWorkSay(LxRow r) => ho
      ? 'Row added in ${showDate(r.date)} (${r.shift}): type its Start (the Close of the row above, or higher – the hours between are not counted) and its Close${plain(r) ? '.' : ', and press its work.'}'
      : 'Row added for another work of ${showDate(r.date)} (${r.shift}): press its work, then type its Close – or lower the Close of the row above, its Start follows.';

  /// "+ Add row": the ticked dates get their other shift; nothing ticked – the first free date. → (words, bad?, the row added).
  (String, bool, LxRow?) addRow() {
    final ticked = <String>[];
    for (final r in rows.where((r) => r.sel)) {
      if (!ticked.contains(r.date)) ticked.add(r.date);
    }
    if (ticked.isNotEmpty) {
      final added = ticked.map(addShift).whereType<LxRow>().toList();
      for (final r in rows) {
        r.sel = false;
      }
      if (added.isEmpty) return ('The ticked date(s) already have a Day and a Night entry.', true, null);
      return (
        '${added.length} row(s) added: ${added.take(6).map((r) => '${showDate(r.date)} ${r.shift}').join(', ')}${added.length > 6 ? ' …' : ''} – type the readings if the meter moved, tick "½" for a half, then Save.'
            '${added.length < ticked.length ? ' (${ticked.length - added.length} date(s) already have Day and Night.)' : ''}',
        false,
        added.first
      );
    }
    final miss = missing();
    if (miss.isEmpty) {
      return (
        locks.isNotEmpty
            ? 'No date is free in this range: every date has its entry or is in a submitted bill (see the note above – a date of a submitted bill takes no new entry). To add a Night (or Day) entry to a free date: tick its row, then press "+ Add row".'
            : 'Every date in this range has an entry. To add a Night (or Day) entry to a date: tick its row, then press "+ Add row".',
        true,
        null
      );
    }
    final first = rows.isNotEmpty ? rows.first.date : '';
    final r = add(miss.where((dk) => dk.compareTo(first) > 0).firstOrNull ?? miss.first);
    sort();
    return ('', false, r);
  }

  /// "Add all missing dates" – the gaps between the entries.
  (String, bool) fillGaps() {
    var miss = missing();
    if (rows.isNotEmpty) {
      final a = rows.first.date, b = rows.last.date;
      miss = miss.where((dk) => dk.compareTo(a) > 0 && dk.compareTo(b) < 0).toList();
    }
    if (miss.isEmpty) return ('No gaps between the entries.', true);
    for (final dk in miss) {
      add(dk);
    }
    sort();
    return ('${miss.length} row(s) added for ${showDate(miss.first)}${miss.length > 1 ? ' to ${showDate(miss.last)}' : ''} – type their Close readings.', false);
  }

  // ---------------------------------------------------------------------------------------------------------------
  //  SAVE (the payload of saveLogBulk, as the web builds it)
  // ---------------------------------------------------------------------------------------------------------------
  /// → the problem (nothing saved), or the plan: what is asked before saving and what is sent.
  LxSave save() {
    final bad = rows.where((r) {
      final w = way(r), km = hasKm(w), hr = hasHr(w);
      return (km && (r.ckm == '' || r.okm == '' || _n0(r.ckm) < _n0(r.okm))) || (hr && (r.chr == '' || r.ohr == '' || _n0(r.chr) < _n0(r.ohr))) ||
          (w == 'Time' && !(_n0(lgTimeHrs(r.tStart, r.tEnd, r.tBrk)) > 0)) || (w == 'Trip' && !(_n0(r.trip) > 0));
    }).toList();
    if (bad.isNotEmpty) return LxSave.no('Fix the rows in red first: every row needs its readings (Close not less than Start), its From / To time or its trips (${bad.map((r) => showDate(r.date)).join(', ')}).');
    // the rows of one date + shift are ONE entry: the one saved on that date + shift; else an entry whose rows all moved here; else new
    final groups = <List<LxRow>>[], bySlot = <String, List<LxRow>>{};
    for (final r in rows) {
      final k = slot(r);
      if (!bySlot.containsKey(k)) groups.add(bySlot[k] = []);
      bySlot[k]!.add(r);
    }
    final home = <String, String>{for (final r in rows) if (r.key.isNotEmpty && (r.orig?['date'] ?? '') != '') r.key: '${r.orig!['date']}|${r.orig!['shift']}'};
    final used = <String>{}, owner = <List<LxRow>, String>{};
    for (final g in groups) {
      final k = g.map((r) => r.key).where((k) => k.isNotEmpty && home[k] == slot(g.first)).firstOrNull;
      if (k != null) {
        owner[g] = k;
        used.add(k);
      }
    }
    for (final g in groups) {
      if (owner.containsKey(g)) continue;
      final k = g.map((r) => r.key).where((k) => k.isNotEmpty && !used.contains(k)).firstOrNull;
      owner[g] = k ?? '';
      if (k != null) used.add(k);
    }
    final del = [...deleted, ...{for (final r in rows) if (r.key.isNotEmpty && !used.contains(r.key) && !deleted.contains(r.key)) r.key}];
    for (final g in groups.where((g) => g.length > 1)) {
      for (final r in g) {
        final pb = partsProblem(g, r);
        if (pb == null) return LxSave.no('${showDate(r.date)}: two entries on ${r.shift} – make one Day and the other Night.');
        if (pb.isNotEmpty) return LxSave.no('${showDate(r.date)} ${r.shift}: $pb');
      }
    }
    final ch = rows.where((r) => !r.isNew && changed(r)).length, nw = rows.where((r) => r.isNew).length;
    final moved = del.where((k) => !deleted.contains(k)).map((k) {
      final q = k.split('|');
      return '${showDate(q.length > 1 ? q[1] : '')} ${q.length > 2 ? q[2] : ''}';
    }).toList();
    final nextHr = d['nextHr'] as Map?, next = d['next'] as Map?;
    final ask = [
      '$ch entr${ch == 1 ? 'y' : 'ies'} changed',
      '$nw new entr${nw == 1 ? 'y' : 'ies'} added',
      '${del.length} entr${del.length == 1 ? 'y' : 'ies'} deleted${moved.isNotEmpty ? ' (${moved.join(', ')}: its rows were moved into another entry of that date – it becomes part of that entry)' : ''}',
    ];
    final notes = [
      if (d['hrsOnly'] == true && nextHr != null) 'The entry after (${showDate(_s(nextHr['date']))}) is not changed – its Start stays ${fmtNum(_n0(nextHr['ohr']))}.',
      if (d['hrsOnly'] != true && next != null) 'The entry after (${showDate(_s(next['date']))}) will start at the last Close here.',
      'Totals, diesel Opening / Closing and averages are worked out again for this machinery.',
    ];
    String joinTxt(Iterable<String> a) {
      final o = <String>[];
      for (final x in a.map((x) => x.trim()).where((x) => x.isNotEmpty)) {
        if (!o.contains(x)) o.add(x);
      }
      return o.join(' / ');
    }

    final fmtB = mach.lbFormat == 'B';
    final out = <Map<String, dynamic>>[];
    for (final g in groups) {
      final r = g.first, own = owner[g] ?? '', hg = g.where((x) => hasHr(way(x))).toList(), mix = g.length > 1 && ho && hg.isNotEmpty && hg.length < g.length;
      final rr = mix ? hg.first : r, z = mix ? hg.last : g.last, w = way(rr), k = hasKm(w), h = hasHr(w);
      final odSet = r.date.endsWith('-01') ? r.odSet : '';
      if (g.length > 1) {
        final kind = partKind(r), parts = <Map<String, Object?>>[];
        for (var j = 0; j < g.length; j++) {
          final x = g[j], ph = g.sublist(0, j).where((y) => hasHr(way(y))).lastOrNull;
          final p = <String, Object?>{'n': plain(x) ? '' : pickOf(x, kind), 'q': rowQty(x, kind), 'c': x.challan, 'p': x.remark, 'f': x.chFrom, 't': x.chTo, 'w': x.work};
          if (way(x) == 'Time') {
            p.addAll(timePart(x));
          } else if (ph != null && kind == 'hr' && ho && _n0(x.ohr) > _n0(ph.chr)) {
            p['g'] = r2(_n0(x.ohr) - _n0(ph.chr)); // (update-77: hours not worked before this row)
          }
          parts.add(p);
        }
        final trips = g.fold<num>(0, (a, x) => a + _n0(x.trip));
        out.add({
          'key': own,
          'same': g.every((x) => !x.isNew && !changed(x) && x.key == own) && pc[own] == g.length,
          'half': r.half, 'date': r.date, 'shift': r.shift, 'mode': w,
          'openingKm': k ? rr.okm : '', 'closingKm': k ? z.ckm : '', 'openingHr': h ? rr.ohr : '', 'closingHr': h ? z.chr : '',
          'tStart': '', 'tEnd': '', 'tBreak': '', 'remark': joinTxt(g.map((x) => x.remark)),
          'trip': fmtB && trips != 0 ? trips : '',
          'challan': joinTxt(g.map((x) => x.challan)),
          'chFrom': g.where((x) => x.chFrom.trim().isNotEmpty).firstOrNull?.chFrom ?? '',
          'chTo': g.reversed.where((x) => x.chTo.trim().isNotEmpty).firstOrNull?.chTo ?? '',
          'work': joinTxt(g.map((x) => x.work)), 'odSet': odSet,
          'items': {
            if (_s(r.items['_day']).isNotEmpty) '_day': r.items['_day'],
            ...otherItems(g, plain(r) ? '' : kind),
            '_parts': parts,
          },
        });
        continue;
      }
      final one = (pc[own] ?? 1) > 1;
      out.add({
        'key': own,
        if (one) 'joinRows': true,
        'same': !r.isNew && !changed(r) && r.key == own && !one,
        'half': r.half, 'date': r.date, 'shift': r.shift, 'mode': w,
        'openingKm': k ? r.okm : '', 'closingKm': k ? r.ckm : '', 'openingHr': h ? r.ohr : '', 'closingHr': h ? r.chr : '',
        'tStart': w == 'Time' || w == 'Trip' ? r.tStart : '', 'tEnd': w == 'Time' || w == 'Trip' ? r.tEnd : '', 'tBreak': w == 'Time' ? r.tBrk : '',
        'remark': r.remark, 'trip': w == 'Trip' || (fmtB && !kDayStatus.contains(w)) ? r.trip : '', 'challan': r.challan,
        'chFrom': r.chFrom, 'chTo': r.chTo, 'work': r.work, 'odSet': odSet,
        if (boqOf(r.date).isNotEmpty) 'items': r.items else if (d['hrsOnly'] == true && one) 'items': <String, Object?>{}, // (an entry that had rows and has one now: its rows go)
      });
    }
    return LxSave(ask, notes, {'no': no, 'from': from, 'to': to, 'rows': out, 'deleted': del, 'openingDiesel': odsl});
  }

  /// update-78: a row by Time among the rows by Hrs – its times (a split kept while From, To and Break are as loaded) and the break.
  Map<String, Object> timePart(LxRow x) {
    final sl = slotsParse(x.tSlots), o = x.orig ?? const {};
    final keep = sl.length > 1 && x.tStart == o['tStart'] && x.tEnd == o['tEnd'] && js(x.tBrk) == js(o['tBrk']);
    if (keep) {
      final b = r2(_n0(x.tBrk) - slotsGap(sl));
      return {'m': 'T', 'ts': sl.map((t) => '${t[0]}-${t[1]}').join(','), 'tb': b > 0 ? b : 0};
    }
    final b = _n0(x.tBrk);
    return {'m': 'T', 'ts': '${x.tStart}-${x.tEnd}', 'tb': b > 0 ? b : 0};
  }

  // ---------------------------------------------------------------------------------------------------------------
  //  WORDS ABOVE THE GRID
  // ---------------------------------------------------------------------------------------------------------------
  String get title => no + (_s(m['type']).isNotEmpty ? ' – ${m['type']}' : '');

  String get info {
    final std = [if (meterKmCol && _n0(m['kmStd']) > 0) '${js(m['kmStd'])} km/L', if (meterHrCol && _n0(m['hrStd']) > 0) '${js(m['hrStd'])} L/hr'].join(' + ');
    return 'Works on ${worksOf(m).join(', ')}  |  Standard $std  |  ${showDate(from)} to ${showDate(to)}';
  }

  bool get meterKmCol => meterKm || rows.any((r) => hasKm(way(r)));
  bool get meterHrCol => meterHr || rows.any((r) => hasHr(way(r)));

  String _two(Object? a, Object? b) {
    final km = meterKmCol, hr = meterHrCol;
    return [if (km && lxN(a) != '') '${fmtNum(_n0(a))}${hr ? ' km' : ''}', if (hr && lxN(b) != '') '${fmtNum(_n0(b))}${km ? ' hr' : ''}'].join(' / ');
  }

  String get prevText {
    final p = d['prev'] as Map?;
    return p != null
        ? 'Entry before: ${showDate(_s(p['date']))} (${p['shift']}) closed at ${_two(p['ckm'], p['chr'])}, diesel left ${fmtNum(_n0(p['stock']))} L.'
        : 'No entry before ${showDate(from)} – the first row is the first entry of this machinery.';
  }

  String get nextText {
    final p = d['next'] as Map?;
    return p == null ? '' : 'Entry after: ${showDate(_s(p['date']))} (${p['shift']}) starts at ${_two(p['okm'], p['ohr'])} – it follows the last Close here when it was joined to it, or when that Close passes it.';
  }

  List<String> get lockTexts => [
        for (final l in locks)
          '${showDate('${l['from']}'.compareTo(from) < 0 ? from : '${l['from']}')} to ${showDate('${l['to']}'.compareTo(to) > 0 ? to : '${l['to']}')} are in the submitted RA Bill ${l['billNo']}${_s(l['rev']).isNotEmpty && l['rev'] != 0 ? ' rev ${l['rev']}' : ''}'
              ' of ${l['vendor']} (${l['company']}, ${showDate(_s(l['from']))} to ${showDate(_s(l['to']))}) – '
              '${superUser ? 'you are the Super Admin: you can change them here; the difference is taken in the next bill of the vendor.' : 'the entries of those dates are shown but cannot be changed here. To correct one: Log Book list → Edit / Delete on that entry – the change goes to the Super Admin for approval. (Or the Admin deletes that bill, the correction is made, and the bill is built and submitted again.)'}',
      ];

  /// The ways a row may be put in (a saved entry keeps a way the format no longer offers).
  List<String> waysOf(LxRow r) {
    final o = _s(r.orig?['mode']);
    return kWaysAll.contains(o) && !modesAll.contains(o) ? [o, ...modesAll] : modesAll;
  }

  /// The words of "work 2 of this day".
  String partWord(LxRow r) => 'work ${slotRows(r).indexOf(r) + 1} of this ${r.shift == 'Night' ? 'night' : 'day'}';

  /// What a split of times shows while From, To and Break are as loaded.
  String splitText(LxRow r) {
    final sl = slotsParse(r.tSlots), o = r.orig ?? const {};
    if (sl.length < 2 || r.tStart != o['tStart'] || r.tEnd != o['tEnd'] || js(r.tBrk) != js(o['tBrk'])) return '';
    return sl.map((x) => '${x[0]} – ${x[1]} (${fmtNum(_n0(slotMin(x[0], x[1])) / 60)})').join(' + ');
  }
}

class LxSave {
  LxSave(this.ask, this.notes, this.body) : problem = '';
  LxSave.no(this.problem)
      : ask = const [],
        notes = const [],
        body = const {};
  final String problem;
  final List<String> ask, notes;
  final Map<String, dynamic> body;
}

/// The words when a date of a submitted RA Bill is picked (as the web's lockText).
String lockText(Map l, String no, String dk, String what) =>
    '$what of $no on ${showDate(dk)}: this machinery is in the submitted RA Bill ${l['billNo']}${_s(l['rev']).isNotEmpty && l['rev'] != 0 ? ' rev ${l['rev']}' : ''} of ${l['vendor']} (${l['company']}, ${showDate(_s(l['from']))} to ${showDate(_s(l['to']))})'
    ' – its Log Book and diesel entries of those dates cannot be added, changed or deleted without the Super Admin. To correct them: change the entry and send it to the Super Admin for approval (the page asks) – approved, it is saved and the difference is taken in the next bill of this vendor; or the Admin deletes that bill, the correction is made, and the bill is built and submitted again.';

// =====================================================================================================================
//  A WATER TANKER (Log Book Format I): its trips, one row each (update-104) – getTankerRange → saveTankerRange
// =====================================================================================================================
class LtTrip {
  String date = '', shift = 'Day', c = '', a = '', b = '', ch = '', u = '', orig = '';
  int old = 0;
  bool sel = false;
  String get sig => [wtKey(c), a, b, ch.trim(), u.trim(), date, shift].join('|');
  bool get blank => orig.isEmpty && c.isEmpty && a.isEmpty && b.isEmpty && ch.isEmpty && u.isEmpty;
  bool get changed => orig.isNotEmpty && sig != orig;
  Map<String, dynamic> get out => {'date': date, 'shift': shift, 'c': c.trim(), 'a': a, 'b': b, 'ch': ch.trim(), 'u': u.trim(), 'old': old};
}

String wtKey(String c) => c.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

/// Dispatch → unload in minutes of the day (a Night trip after midnight runs on).
List<int>? wtSpan(String a, String b, String sh) {
  var x = tMin(a), y = tMin(b);
  if (x == null || y == null) return null;
  if (sh == 'Night' && x < 720) x += 1440;
  while (y <= x) {
    y += 1440;
  }
  return [x, y];
}

class LtEdit {
  LtEdit(this.d, {required this.superUser, required this.today}) {
    trips = [
      for (final t in (d['trips'] as List? ?? const []).whereType<Map>())
        LtTrip()
          ..date = _s(t['date'])
          ..shift = _s(t['shift']).isEmpty ? 'Day' : _s(t['shift'])
          ..c = _s(t['c'])
          ..a = _s(t['a'])
          ..b = _s(t['b'])
          ..ch = _s(t['ch'])
          ..u = _s(t['u'])
          ..old = t['old'] == 1 || t['old'] == true ? 1 : 0,
    ];
    for (final t in trips) {
      t.orig = t.sig;
    }
    saved = trips.length;
    if (trips.isEmpty) add();
  }
  final Map<String, dynamic> d;
  final bool superUser;
  final String today;
  List<LtTrip> trips = [];
  int saved = 0;

  Map get machine => d['machine'] as Map? ?? const {};
  String get no => _s(machine['id']);
  String get from => _s(d['from']);
  String get to => _s(d['to']);
  List<Map> get locks => (d['locks'] as List? ?? const []).whereType<Map>().toList();
  Map? lockOf(String dk) => superUser ? null : locks.where((l) => '${l['from']}'.compareTo(dk) <= 0 && dk.compareTo('${l['to']}') <= 0).firstOrNull;
  String get top => to.compareTo(today) < 0 ? to : today;

  List<LtTrip> get real => trips.where((t) => !t.blank).toList();
  bool get dirty {
    final now = real;
    return now.length != saved || now.any((t) => t.orig.isEmpty || t.sig != t.orig);
  }

  int get nightTrips => real.where((t) => t.shift == 'Night').length;

  String get info {
    final days = (d['days'] as List? ?? const []).whereType<Map>().toList();
    return 'Agency: ${_s(machine['owner']).isEmpty ? '–' : machine['owner']}  |  ${showDate(from)} to ${showDate(to)}'
        '${days.isNotEmpty ? '  |  Without trips: ${days.map((x) => '${showDate(_s(x['date']))} ${x['shift']} (${x['status']})').join(', ')}' : ''}';
  }

  List<String> get lockTexts => [
        for (final l in locks)
          '${showDate(_s(l['from']))} to ${showDate(_s(l['to']))} are in the submitted RA Bill ${l['billNo']} of ${l['vendor']} – '
              '${superUser ? 'you are the Super Admin: you can change those trips; the difference is taken in the next bill.' : 'those trips are shown, not changed here (Log Book list → Edit on a trip: the change goes to the Super Admin for approval).'}',
      ];

  /// One more trip (the date and shift of the row above).
  LtTrip add() {
    final last = trips.lastOrNull;
    final t = LtTrip()
      ..date = last != null && last.date.isNotEmpty ? last.date : top
      ..shift = last != null && last.shift != 'Full Day' ? last.shift : 'Day';
    trips.add(t);
    return t;
  }

  void remove(Iterable<LtTrip> l) {
    final gone = l.toSet();
    trips = trips.where((t) => !gone.contains(t)).toList();
    if (trips.isEmpty) add();
  }

  /// What is wrong in the rows before anything is sent (the server checks all of it again) – [row index, words].
  List<(int, String)> problems() {
    final out = <(int, String)>[], keys = <String, int>{}, spans = <(String, List<int>, int, String, String)>[];
    final rows = real;
    for (var i = 0; i < rows.length; i++) {
      final t = rows[i], at = 'Row ${i + 1}: ', kept = t.orig.isNotEmpty && t.sig == t.orig;
      if (t.date.isEmpty) {
        out.add((i, '${at}select the Date.'));
        continue;
      }
      if (!kept) {
        if (t.c.trim().isEmpty) out.add((i, '${at}enter the Challan No.'));
        if (tMin(t.a) == null) out.add((i, '${at}enter the Dispatch time.'));
        if (tMin(t.b) == null) out.add((i, '${at}enter the Unload time.'));
        if (t.a.isNotEmpty && t.a == t.b) out.add((i, '${at}the Dispatch and Unload time are the same.'));
      }
      final k = wtKey(t.c);
      if (k.isNotEmpty) {
        if (keys.containsKey(t.date + k)) {
          out.add((i, '${at}DUPLICATE challan ${t.c.trim()} – also in row ${keys[t.date + k]}.'));
        } else {
          keys[t.date + k] = i + 1;
        }
      }
      final sp = wtSpan(t.a, t.b, t.shift);
      if (sp == null) continue;
      final hit = spans.where((x) => x.$1 == t.date && sp[0] < x.$2[1] && x.$2[0] < sp[1]).firstOrNull;
      if (hit != null) {
        out.add((i, '${at}DUPLICATE time – ${t.a}–${t.b} falls on row ${hit.$3} (${hit.$4}–${hit.$5}).'));
      } else {
        spans.add((t.date, sp, i + 1, t.a, t.b));
      }
    }
    return out;
  }

  Map<String, dynamic> body() => {'no': no, 'from': from, 'to': to, 'trips': [for (final t in real) t.out]};
}
