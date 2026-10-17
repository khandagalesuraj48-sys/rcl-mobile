/* THE ASSET MASTER'S RULES (3.4.0, part 3 of the whole web in the app) – the same as the web's Asset Master (Mechanical
 * App.html: masterFiltered, docState, mPeriods / onSiteIn, worksOf / unitFromWorks, formatNo, the "Update …?" changes, Edit
 * selected). The server checks and saves everything (saveMaster, saveMasterBulk, editMasterMany, deleteMaster(Many),
 * assignVendors, vendorsFromOwners); here only what the page itself works out, so the phone shows and sends the same. */
import 'format.dart';
import 'rdoc.dart';

export 'session.dart' show hasKm, hasHr;

const kOwnerships = ['Own', 'Rental', 'Hired', 'Debit', 'Other'];
const kWorks = ['Day', 'Trip', 'KM', 'Hrs', 'KM + Hrs', 'Time'];
const kWorksHint = {'Hrs': 'hour meter', 'KM + Hrs': 'both readings', 'Time': 'from – to'};
const kSupplies = ['Company', 'Debit Basis', 'Other'];
const kUnits = ['KM', 'Hrs', 'KM + Hrs'];


/// The unit the ticks of "Works on" give (as the web's unitFromWorks).
String unitFromWorks(List<String> w) {
  final both = w.contains('KM + Hrs'), km = w.contains('KM') || both, hr = w.contains('Hrs') || w.contains('Time') || both;
  return km && hr ? 'KM + Hrs' : km ? 'KM' : hr ? 'Hrs' : w.isNotEmpty ? 'Day' : '';
}

/// What it works on (its ticks; an older machinery: from its unit).
List<String> worksOf(Map<String, dynamic> m) {
  final w = m['worksOn'];
  if (w is List && w.isNotEmpty) return w.map((e) => '$e').toList();
  if (w is String && w.trim().isNotEmpty) return w.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  return switch ('${m['unit'] ?? ''}') { 'KM' => ['KM'], 'Hrs' => ['Hrs'], 'KM + Hrs' => ['KM', 'Hrs'], 'Day' => ['Day'], _ => <String>[] };
}

String noKey(String v) => v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// A vehicle number as the server writes it: MH12AB1234 → MH-12-AB-1234 (anything else as typed, spaces tidied).
String formatNo(String v) {
  final s = v.replaceAll(RegExp(r'\s+'), ' ').trim();
  final m = RegExp(r'^([A-Z]{2})(\d{2})([A-Z]{0,3})(\d{4})$').firstMatch(noKey(s));
  return m == null ? s : [m.group(1), m.group(2), m.group(3), m.group(4)].where((x) => (x ?? '').isNotEmpty).join('-');
}

/// The id the server will give: the Number, or the Name when there is no number.
String idOf(String no, String name) {
  final n = formatNo(no);
  return n.isNotEmpty ? n : name.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _s(dynamic v) => v == null ? '' : '$v';
String _day(dynamic v) {
  final s = _s(v);
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/* ---------------- papers ---------------- */
const kDocs = [('tax', 'Tax', 'taxUpto'), ('puc', 'PUC', 'pucUpto'), ('permit', 'Permit', 'permitUpto'), ('fitness', 'Fitness', 'fitnessUpto'), ('ins', 'Insurance', 'insuranceUpto')];

String docShow(dynamic v) {
  final s = _s(v);
  return s == 'NA' ? 'N/A' : s == 'LIFETIME' ? 'Lifetime' : RegExp(r'^\d{4}-').hasMatch(s) ? showDate(s) : '–';
}

class DocState {
  final expired = <String>[], due = <String>[];
  int ok = 0, given = 0;
  /// '' (no date given) · 'bad' · 'warn' · 'good'
  String get tone => given == 0 ? '' : expired.isNotEmpty ? 'bad' : due.isNotEmpty ? 'warn' : 'good';
  String get text => given == 0 ? '–' : expired.isNotEmpty ? '${expired.length} expired' : due.isNotEmpty ? '${due.length} due soon' : 'OK';
}

/// Expired / due within 30 days / OK (as the web's docState).
DocState docState(Map<String, dynamic> m, String today) {
  final soon = dateKey(parseKey(today).add(const Duration(days: 30)));
  final out = DocState();
  for (final d in kDocs) {
    final v = _s(m[d.$3]);
    if (!RegExp(r'^\d{4}-').hasMatch(v)) continue;
    out.given++;
    if (v.compareTo(today) < 0) {
      out.expired.add('${d.$2} ${showDate(v)}');
    } else if (v.compareTo(soon) <= 0) {
      out.due.add('${d.$2} ${showDate(v)}');
    } else {
      out.ok++;
    }
  }
  return out;
}

/* ---------------- on site: its periods (update-119) ---------------- */
class Period {
  const Period(this.from, this.until);
  final String from, until; // until = the first day away ('' = still on site)
}

String dayBefore(String d) => dateKey(parseKey(d).subtract(const Duration(days: 1)));

/// Its earlier periods (it left and came back) and its current one.
List<Period> periodsOf(Map<String, dynamic> m) => [
      for (final p in (m['earlier'] as List? ?? const []).whereType<Map>()) Period(_s(p['from']), _s(p['until'])),
      Period(_day(m['activeFrom']), m['status'] == 'Inactive' ? (_day(m['inactiveFrom']).isNotEmpty ? _day(m['inactiveFrom']) : '0000-01-01') : ''),
    ];

/// On site on at least one day of a … b.
bool onSiteIn(Map<String, dynamic> m, String a, String b) =>
    periodsOf(m).any((p) => (p.from.isEmpty || p.from.compareTo(b) <= 0) && (p.until.isEmpty || a.compareTo(p.until) < 0));

/// "01-09-2026 – 30-09-2026" (an earlier period: from … the day before it left).
String periodText(Period p) => '${p.from.isNotEmpty ? showDate(p.from) : 'start'} – ${showDate(dayBefore(p.until))}';

/// The days of a … b it was on site, its first and last day of them.
({int days, String first, String last}) siteSpan(Map<String, dynamic> m, String from, String to) {
  var n = 0;
  var a = '', b = '';
  for (final p in periodsOf(m)) {
    if (p.until == '0000-01-01') continue;
    final s0 = p.from.isNotEmpty && p.from.compareTo(from) > 0 ? p.from : from;
    final e0 = p.until.isNotEmpty ? dayBefore(p.until) : to;
    final e = e0.compareTo(to) < 0 ? e0 : to;
    if (e.compareTo(s0) < 0) continue;
    n += parseKey(e).difference(parseKey(s0)).inDays + 1;
    if (a.isEmpty || s0.compareTo(a) < 0) a = s0;
    if (b.isEmpty || e.compareTo(b) > 0) b = e;
  }
  return (days: n, first: a, last: b);
}

/// "Active from 01-09-2026" / "Inactive from 01-10-2026" (the badge of the list).
String statusText(Map<String, dynamic> m) {
  if (m['status'] == 'Inactive') return 'Inactive${_s(m['inactiveFrom']).isNotEmpty ? ' from ${showDate(_s(m['inactiveFrom']))}' : ''}';
  return 'Active${_s(m['activeFrom']).isNotEmpty ? ' from ${showDate(_s(m['activeFrom']))}' : ''}';
}

String earlierText(Map<String, dynamic> m) {
  final l = (m['earlier'] as List? ?? const []).whereType<Map>().map((p) => periodText(Period(_s(p['from']), _s(p['until'])))).toList();
  return l.isEmpty ? '' : 'earlier: ${l.join('; ')}';
}

/* ---------------- the list's filters (as the web's masterFiltered) ---------------- */
bool vendorAssigned(Map<String, dynamic> m) => _s(m['owner']).trim().isNotEmpty;

class AssetFilter {
  String q = '', own = '', type = '', unit = '', owner = '', supply = '', status = '', from = '', to = '';
  /// the vendor chips: '' all · 'none' not assigned · 'done' assigned
  String vc = '';
  int get count => [own, type, unit, owner, supply, status].where((x) => x.isNotEmpty).length + (from.isNotEmpty || to.isNotEmpty ? 1 : 0);
  void clear() {
    q = own = type = unit = owner = supply = status = from = to = '';
  }

  bool test(Map<String, dynamic> m, {bool noVc = false}) {
    final qq = q.toUpperCase(), ft = type.toUpperCase(), fw = owner.toUpperCase();
    final ra = from.isNotEmpty ? from : '0000-01-01', rb = to.isNotEmpty ? to : '9999-12-31';
    final v = noVc ? '' : vc;
    return (qq.isEmpty || [m['id'], m['no'], m['name'], m['type'], m['owner'], m['ownership']].map(_s).join(' ').toUpperCase().contains(qq)) &&
        (own.isEmpty || m['ownership'] == own) &&
        (unit.isEmpty || m['unit'] == unit) &&
        (status.isEmpty || m['status'] == status) &&
        (supply.isEmpty || m['supply'] == supply) &&
        (ft.isEmpty || _s(m['type']).toUpperCase().contains(ft)) &&
        (fw.isEmpty || _s(m['owner']).toUpperCase().contains(fw)) &&
        (v.isEmpty || (v == 'done' ? vendorAssigned(m) : !vendorAssigned(m))) &&
        (from.isEmpty && to.isEmpty || onSiteIn(m, ra.compareTo(rb) < 0 ? ra : rb, ra.compareTo(rb) < 0 ? rb : ra));
  }

  /// "Machinery: 12 of 53 · on site on 14-10-2026"
  String summary(int shown, int all) => 'Machinery: $shown${shown != all ? ' of $all' : ''}'
      '${from.isNotEmpty || to.isNotEmpty ? ' · on site ${from == to ? 'on ${showDate(from)}' : '${from.isNotEmpty ? 'from ${showDate(from)} ' : ''}${to.isNotEmpty ? 'to ${showDate(to)}' : ''}'.trim()}' : ''}';
}

/// The Owner Names on these assets that are not yet vendors (one tap makes them vendors – as the web).
List<String> ownersNotVendors(Iterable<Map<String, dynamic>> base) => {
      for (final m in base)
        if (!vendorAssigned(m) && _s(m['owner']).trim().isNotEmpty) _s(m['owner']).trim()
    }.toList();

/* ---------------- one machinery: the form's save ---------------- */
/// Ownership picked by itself from the Vendor (as the web's ownerAutoOwnership).
String autoOwnership(String owner) => RegExp(r'^rachana construction', caseSensitive: false).hasMatch(owner.trim()) ? 'Own' : 'Rental';

const kMasterDiff = [
  ('no', 'Machinery Number'), ('name', 'Machinery Name'), ('type', 'Type of Machinery'), ('make', 'Make'), ('worksOn', 'Works on'),
  ('kmStd', 'Standard Average (KM/Ltr)'), ('hrStd', 'Standard Average (Ltr/Hr)'), ('owner', 'Owner Name'), ('ownership', 'Ownership'),
  ('supply', 'Diesel Supply'), ('status', 'Status'), ('activeFrom', 'Active From'), ('inactiveFrom', 'Inactive From'),
];

/// What an edit changes: [field, now, new] – the same lines as the web's "Update …?" (and the earlier periods, came back / never left).
List<(String, String, String)> masterChanges(Map<String, dynamic> before, Map<String, dynamic> after) {
  final b = {...before, 'worksOn': worksOf(before).join(', ')};
  final out = <(String, String, String)>[
    for (final f in kMasterDiff)
      if (_s(b[f.$1]).trim() != _s(after[f.$1]).trim()) (f.$2, _s(b[f.$1]), _s(after[f.$1])),
  ];
  String pt(dynamic l) {
    final t = (l as List? ?? const []).whereType<Map>().map((p) => periodText(Period(_s(p['from']), _s(p['until']).isNotEmpty ? _s(p['until']) : _s(p['from'])))).join('; ');
    return t.isEmpty ? 'none' : t;
  }

  final a0 = pt(before['earlier']), a1 = pt(after['earlier']);
  if (a0 != a1) out.add(('Earlier periods on site', a0, a1));
  if (before['status'] == 'Inactive' && _s(before['inactiveFrom']).isNotEmpty && after['status'] == 'Active') {
    out.add(_s(after['activeFrom']) != _s(before['activeFrom'])
        ? ('It came back', 'left on ${showDate(_day(before['inactiveFrom']))}', 'back on ${showDate(_s(after['activeFrom']))} (until then kept as an earlier period)')
        : ('It never left', 'Inactive from ${showDate(_day(before['inactiveFrom']))}', 'on site every day'));
  }
  return out;
}

/// When the Number (or the Name of one without a number) changes – said plainly before the save, as the web.
const kRenameNote = [
  'Everything entered for it moves to the new number: Log Book, diesel issues, tank checks, breakdown and papers records, and its BOQ.',
  'No reading, diesel figure or amount changes.',
  'Bills and debit notes already saved keep the number they were issued with.',
  'A QR label printed with the old number will not open this machinery any more – print its label again.',
];

/// The words after a save (as the web's toast).
String savedWords(String mode, Map res) {
  if (mode != 'edit') return 'Machinery saved.';
  final r = res['renamed'];
  if (r is Map) return 'Machinery updated – ${r['from']} is now ${r['to']}${_s(r['text']).isNotEmpty ? ' (moved with it: ${r['text']})' : ''}.';
  return 'Machinery updated.';
}

/* ---------------- several machinery: Edit selected (as the web's ME_FIELDS) ---------------- */
class MeField {
  const MeField(this.key, this.label, this.kind, [this.options = const []]);
  final String key, label, kind; // kind: text · number · date · pick
  final List<String> options;
}

const kMeFields = [
  MeField('type', 'Type of Machinery', 'text'), MeField('make', 'Make', 'text'), MeField('unit', 'Unit', 'pick', kUnits),
  MeField('kmStd', 'Standard (KM/Ltr)', 'number'), MeField('hrStd', 'Standard (Ltr/Hr)', 'number'), MeField('tankCap', 'Tank Capacity (Ltr)', 'number'),
  MeField('owner', 'Vendor (Owner Name)', 'text'), MeField('ownership', 'Ownership', 'pick', kOwnerships),
  MeField('supply', 'Diesel Supply', 'pick', kSupplies), MeField('status', 'Status', 'pick', ['Active', 'Inactive']),
  MeField('activeFrom', 'Active From (made Active again: the day it came back)', 'date'), MeField('inactiveFrom', 'Inactive From (when Inactive)', 'date'),
  MeField('monthlyRate', 'Monthly Rate (₹) – Rental / Hired', 'number'), MeField('tdsRate', 'TDS Rate (%) – Rental / Hired', 'number'),
];

/// Per field: the value all the picked machinery share (same = true), or different.
Map<String, ({bool same, String v})> meCommon(List<Map<String, dynamic>> list) => {
      for (final f in kMeFields)
        f.key: (() {
          final vals = list.map((m) => _s(m[f.key])).toSet();
          return vals.length == 1 ? (same: true, v: vals.first) : (same: false, v: '');
        })(),
    };

/// Only what was really changed: a shared value changed (also cleared); a different one only when a new value is given.
Map<String, String> meChanges(Map<String, ({bool same, String v})> common, Map<String, String> typed, String today) {
  final ch = <String, String>{};
  for (final f in kMeFields) {
    final nv = (typed[f.key] ?? (common[f.key]!.same ? common[f.key]!.v : '')).trim(), c = common[f.key]!;
    if (c.same ? nv != c.v : nv.isNotEmpty) ch[f.key] = nv;
  }
  if (ch['status'] == 'Inactive' && (ch['inactiveFrom'] ?? '').isEmpty && !(common['inactiveFrom']!.same && common['inactiveFrom']!.v.isNotEmpty)) ch['inactiveFrom'] = today;
  return ch;
}

/* ---------------- several machinery at once (Add multiple) ---------------- */
const kBulkFields = ['no', 'name', 'type', 'make', 'unit', 'kmStd', 'hrStd', 'owner', 'ownership', 'supply'];

/* ---------------- the prints (as the web's Print list / Asset list) ---------------- */
String _dShow(dynamic v) => docShow(v);
String _std(Map<String, dynamic> m, String join) => [if (asNum(m['kmStd']) != null && asNum(m['kmStd'])! > 0) '${m['kmStd']} km/L', if (asNum(m['hrStd']) != null && asNum(m['hrStd'])! > 0) '${m['hrStd']} L/hr'].join(join);

/// "Print list": the list on screen with its filters.
RDoc masterListDoc(List<Map<String, dynamic>> rows, String vc) {
  final title = 'Asset Master${vc == 'none' ? ' – vendor not assigned' : vc == 'done' ? ' – vendor assigned' : ''}';
  return RDoc(title: title, portrait: false, file: 'RCL_Asset_Master', kpis: [('Assets', '${rows.length}')], blocks: [
    RTable(
      sheet: 'Asset Master',
      head: const ['Sr', 'Asset No / Name', 'Type', 'Make', 'Vendor', 'Ownership', 'Diesel', 'Engine No', 'Chassis No', 'Std Avg', 'Tax', 'PUC', 'Permit', 'Fitness', 'Insurance', 'Status'],
      numCols: const {0},
      rows: [
        for (final (i, m) in rows.indexed)
          RRow([
            RCell('${i + 1}', n: true, value: i + 1), RCell(_s(m['id']), bold: true), RCell(_s(m['type'])), RCell(_s(m['make'])),
            RCell('${_s(m['owner']).isEmpty ? '–' : _s(m['owner'])}${vendorAssigned(m) ? '' : ' (not in Vendor Master)'}'),
            RCell(_s(m['ownership'])), RCell(_s(m['supply'])), RCell(_s(m['engineNo'])), RCell(_s(m['chassisNo'])), RCell(_std(m, ', ')),
            for (final d in kDocs) RCell(_dShow(m[d.$3])),
            RCell(_s(m['status'])),
          ]),
      ],
    ),
  ]);
}

class AssetListAsk {
  String kind = 'date', date = '', month = '', from = '', to = '', own = '';
  bool std = false, papers = false, make = false, eng = false, chs = false;
  /// the dates of the list, or the problem ('' = fine)
  (String, String, String) range() {
    if (kind == 'date') return date.isEmpty ? ('', '', 'Pick the dates.') : (date, date, '');
    if (kind == 'month') {
      if (month.length != 7) return ('', '', 'Pick the dates.');
      final y = int.parse(month.substring(0, 4)), mo = int.parse(month.substring(5, 7));
      return ('$month-01', dateKey(DateTime(y, mo + 1, 0)), '');
    }
    if (from.isEmpty || to.isEmpty) return ('', '', 'Pick the dates.');
    if (from.compareTo(to) > 0) return ('', '', 'From date is after To date.');
    return (from, to, '');
  }
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// "Asset list (date / month) – print": the machinery on site then, its condition / days, and the summary by type.
/// [bd] = getBreakdowns {date: to} (null when he may not see Breakdown).
RDoc assetListDoc(List<Map<String, dynamic>> master, AssetListAsk a, String from, String to, Map<String, dynamic>? bd) {
  final ms = master.where((m) => onSiteIn(m, from, to) && (a.own.isEmpty || m['ownership'] == a.own)).toList()
    ..sort((x, y) {
      final o = _s(x['ownership']).compareTo(_s(y['ownership']));
      if (o != 0) return o;
      final t = _s(x['type']).compareTo(_s(y['type']));
      return t != 0 ? t : _natural(_s(x['id']), _s(y['id']));
    });
  final oneDay = a.kind == 'date';
  final hist = (bd?['history'] as List? ?? const []).whereType<Map>().toList(), onDate = (bd?['onDate'] as List? ?? const []).whereType<Map>().toList();
  int bdDays(Map<String, dynamic> m) {
    var n = 0;
    for (final x in hist.where((x) => x['no'] == m['id'])) {
      final st = _s(x['from']).compareTo(from) > 0 ? _s(x['from']) : from;
      final e0 = _s(x['backOn']).isNotEmpty ? dayBefore(_s(x['backOn'])) : to;
      final e = e0.compareTo(to) < 0 ? e0 : to;
      if (e.compareTo(st) >= 0) n += parseKey(e).difference(parseKey(st)).inDays + 1;
    }
    return n;
  }

  String bdNow(Map<String, dynamic> m) {
    for (final x in onDate) {
      if (x['no'] == m['id']) return 'Breakdown since ${showDate(_s(x['from']))} (${x['days']} d) – ${x['reason']}';
    }
    return 'Working';
  }

  final cols = <(String, RCell Function(Map<String, dynamic>), bool)>[
    ('Machinery', (m) => RCell('${m['id']}${_s(m['no']).isNotEmpty && _s(m['name']).isNotEmpty ? ' ${m['name']}' : ''}', bold: true), false),
    ('Type', (m) => RCell(_s(m['type'])), false),
    if (a.make) ('Make', (m) => RCell(_s(m['make'])), false),
    ('Owner / Vendor', (m) => RCell(_s(m['owner'])), false),
    ('Ownership', (m) => RCell(_s(m['ownership'])), false),
    ('Diesel', (m) => RCell(m['supply'] == 'Debit Basis' ? 'Debit' : 'Company'), false),
    ('Works on', (m) => RCell(worksOf(m).join(', ')), false),
    if (a.std) ('Std Average', (m) => RCell(_std(m, ' + ').isEmpty ? '–' : _std(m, ' + ')), false),
    if (a.eng) ('Engine No', (m) => RCell(_s(m['engineNo'])), false),
    if (a.chs) ('Chassis No', (m) => RCell(_s(m['chassisNo'])), false),
    if (a.papers) for (final d in kDocs) (d.$2, (m) => RCell(_dShow(m[d.$3])), false),
    ('On site from', (m) => RCell(_s(m['activeFrom']).isNotEmpty ? showDate(_s(m['activeFrom'])) : '–'), false),
    if (oneDay && bd != null) ('Condition on ${showDate(to)}', (m) => RCell(bdNow(m)), false),
    if (!oneDay) ('Days on site', (m) => RCell('${siteSpan(m, from, to).days}', n: true, value: siteSpan(m, from, to).days), true),
    if (!oneDay && bd != null) ('Breakdown days', (m) => RCell(bdDays(m) == 0 ? '–' : '${bdDays(m)}', n: true, value: bdDays(m)), true),
  ];
  final owns = kOwnerships.where((o) => ms.any((m) => (_s(m['ownership']).isEmpty ? 'Other' : _s(m['ownership'])) == o)).toList();
  final types = <String, ({String name, List<Map<String, dynamic>> ms})>{};
  for (final m in ms) {
    final k = (_s(m['type']).isEmpty ? '–' : _s(m['type'])).trim().toUpperCase();
    types.putIfAbsent(k, () => (name: _s(m['type']).isEmpty ? '–' : _s(m['type']), ms: <Map<String, dynamic>>[])).ms.add(m);
  }
  final tl = types.values.toList()..sort((x, y) => y.ms.length != x.ms.length ? y.ms.length - x.ms.length : x.name.compareTo(y.name));
  String ownOf(Map<String, dynamic> m) => _s(m['ownership']).isEmpty ? 'Other' : _s(m['ownership']);
  final title = oneDay
      ? 'Asset List – ${showDate(to)}'
      : a.kind == 'month'
          ? 'Asset List – ${_months[int.parse(from.substring(5, 7)) - 1]} ${from.substring(0, 4)}'
          : 'Asset List – ${showDate(from)} to ${showDate(to)}';
  return RDoc(
    title: title,
    portrait: false,
    file: 'RCL_Asset_List',
    period: oneDay ? showDate(to) : '${showDate(from)} to ${showDate(to)}',
    meta: '${oneDay ? 'Date: ${showDate(to)}' : 'Period: ${showDate(from)} to ${showDate(to)}'} | ${ms.length} machinery${a.own.isNotEmpty ? ' – ${a.own}' : ''}',
    blocks: [
      RTable(
        sheet: 'Asset list',
        head: ['#', for (final c in cols) c.$1],
        numCols: {0, for (final (i, c) in cols.indexed) if (c.$3) i + 1},
        empty: 'No machinery on site.',
        rows: [for (final (i, m) in ms.indexed) RRow([RCell('${i + 1}', n: true, value: i + 1), for (final c in cols) c.$2(m)])],
      ),
      if (ms.isNotEmpty) ...[
        const RNote('Summary – machinery by type', heading: true),
        RTable(
          sheet: 'Summary by type',
          head: ['#', 'Type of machinery', ...owns, 'Diesel on Debit', 'Total'],
          numCols: {0, for (var i = 0; i < owns.length + 2; i++) i + 2},
          rows: [
            for (final (i, x) in tl.indexed)
              RRow([
                RCell('${i + 1}', n: true, value: i + 1), RCell(x.name, bold: true),
                for (final o in owns) (() { final n = x.ms.where((m) => ownOf(m) == o).length; return RCell(n == 0 ? '–' : '$n', n: true, value: n); })(),
                (() { final n = x.ms.where((m) => m['supply'] == 'Debit Basis').length; return RCell(n == 0 ? '–' : '$n', n: true, value: n); })(),
                RCell('${x.ms.length}', n: true, bold: true, value: x.ms.length),
              ]),
          ],
          foot: [
            RRow([
              const RCell('Total', span: 2),
              for (final o in owns) (() { final n = ms.where((m) => ownOf(m) == o).length; return RCell('$n', n: true, value: n); })(),
              (() { final n = ms.where((m) => m['supply'] == 'Debit Basis').length; return RCell('$n', n: true, value: n); })(),
              RCell('${ms.length}', n: true, value: ms.length),
            ]),
          ],
        ),
      ],
    ],
  );
}

/// Machinery ids in the order a person reads them (LD-2 before LD-10), as the web's localeCompare(numeric).
int _natural(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final x = re.allMatches(a.toLowerCase()).toList(), y = re.allMatches(b.toLowerCase()).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final p = x[i].group(0)!, q = y[i].group(0)!;
    final pn = int.tryParse(p), qn = int.tryParse(q);
    final c = pn != null && qn != null ? pn.compareTo(qn) : p.compareTo(q);
    if (c != 0) return c;
  }
  return x.length - y.length;
}

/// The export of the server (exportMaster: headers + rows) as a sheet "Master" – the same file the web gives (it can be imported back).
RDoc masterExportDoc(Map<String, dynamic> data, String today) {
  final heads = (data['headers'] as List? ?? const []).map((e) => '$e').toList();
  return RDoc(title: 'Master', file: 'RCL_Master_$today', blocks: [
    RTable(sheet: 'Master', head: heads, rows: [
      for (final r in (data['rows'] as List? ?? const []).whereType<List>()) RRow([for (final v in r) v is num ? RCell(fmtPlain(v), n: true, value: v) : RCell(_s(v))]),
    ]),
  ]);
}

String fmtPlain(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
