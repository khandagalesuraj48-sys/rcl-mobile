/* BREAKDOWN – daily machinery status (3.7.0), the web's rules (App.html "BREAKDOWN – daily machinery status" and "period report"):
 * every machinery on site on a date is Working or Breakdown (a reason is needed for a breakdown); the date's saved status, else the
 * breakdowns carried from the last saved day; since when and for how many days; the saved days; and the period report – breakdown
 * days of each machinery (or owner) in From – To, with when and why. Server: getBreakdowns, submitBdReport, deleteBdReport. */
import 'assets.dart' show onSiteIn, siteSpan, dayBefore;
import 'format.dart';
import 'lb_print.dart' show natCompare;
import 'rdoc.dart';

const kBkReasons = ['Tyre puncture', 'Engine problem', 'Hydraulic problem', 'Electrical problem', 'Battery problem', 'Accident', 'Service / maintenance', 'Waiting for spare parts', 'Operator not available'];
const kBkOwns = ['Own', 'Rental', 'Hired', 'Other'];

String bkKey(Object? no) => '${no ?? ''}'.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
String _s(Object? v) => v == null ? '' : '$v';
int _days(String a, String b) => parseKey(b).difference(parseKey(a)).inDays + 1;

class BkState {
  BkState({this.status = 'Working', this.reason = '', this.remark = ''});
  String status, reason, remark;
  bool get bd => status == 'Breakdown';
}

class BkDay {
  BkDay(Map<String, dynamic> data) : d = data {
    (d['status'] as Map? ?? const {}).forEach((k, v) {
      final x = (v as Map?) ?? const {};
      rows['$k'] = BkState(status: _s(x['status']).isEmpty ? 'Working' : _s(x['status']), reason: _s(x['reason']), remark: _s(x['remark']));
    });
  }
  final Map<String, dynamic> d;
  final rows = <String, BkState>{};

  String get date => _s(d['date']);
  String get today => _s(d['today']);
  Map? get report => d['report'] as Map?;
  String get carried => _s(d['carried']);
  List<Map> get onDate => (d['onDate'] as List? ?? const []).whereType<Map>().toList();
  List<Map> get history => (d['history'] as List? ?? const []).whereType<Map>().toList();
  List<Map> get reports => (d['reports'] as List? ?? const []).whereType<Map>().toList();

  /// The machinery on site on the date, of the ownerships ticked, matching the search – by ownership, owner, number.
  List<Map<String, dynamic>> list(List<Map<String, dynamic>> master, Set<String> owns, String q) {
    final qq = q.trim().toUpperCase();
    return master
        .where((m) => onSiteIn(m, date, date) && owns.contains(_s(m['ownership']).isEmpty ? 'Other' : _s(m['ownership'])) && (qq.isEmpty || '${m['id']} ${m['owner'] ?? ''} ${m['type'] ?? ''} ${m['name'] ?? ''}'.toUpperCase().contains(qq)))
        .toList()
      ..sort((a, b) {
        final c = _s(a['ownership']).toLowerCase().compareTo(_s(b['ownership']).toLowerCase());
        if (c != 0) return c;
        final o = _s(a['owner']).toLowerCase().compareTo(_s(b['owner']).toLowerCase());
        return o != 0 ? o : natCompare(_s(a['id']), _s(b['id']));
      });
  }

  BkState state(Map m) => rows[bkKey(m['id'])] ?? BkState();

  /// Set Working / Breakdown (or a reason / remark) of a machinery.
  BkState edit(Map m) => rows.putIfAbsent(bkKey(m['id']), BkState.new);

  /// Under breakdown since (its run of breakdown days up to this date) and for how many days.
  ({String from, int days})? since(Map m) {
    if (!state(m).bd) return null;
    final x = onDate.where((y) => bkKey(y['no']) == bkKey(m['id'])).firstOrNull;
    final from = x != null ? _s(x['from']) : date;
    return (from: from, days: _days(from, date));
  }

  String get statusText => report != null
      ? '✔ Submitted${_s(report!['by']).isNotEmpty ? ' by ${report!['by']}' : ''} at ${report!['at']} – ${(report!['rows'] as List? ?? const []).length} machinery, ${report!['count']} breakdown'
      : 'Status of ${showDate(date)} not submitted yet${carried.isNotEmpty ? ' · breakdowns carried from ${showDate(carried)}' : ''}';

  String get submitWord => report != null ? 'Save changes' : 'Submit ${date == today ? "today's status" : 'status of ${showDate(date)}'}';

  /// What is sent (submitBdReport), and what is missing (a breakdown without its reason).
  List<Map<String, dynamic>> body(List<Map<String, dynamic>> list) => [
        for (final m in list) {'no': m['id'], 'status': state(m).status, 'reason': state(m).reason, 'remark': state(m).remark},
      ];
  String problem(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 'No machinery in the list – tick Own / Rental above.';
    final miss = rows.where((r) => r['status'] == 'Breakdown' && '${r['reason']}'.trim().isEmpty).map((r) => '${r['no']}').toList();
    return miss.isEmpty ? '' : 'Write the reason for: ${miss.join(', ')}.';
  }

  /// The Daily Machinery Status to print.
  RDoc dayDoc(List<Map<String, dynamic>> list, Set<String> owns) {
    final nb = list.where((m) => state(m).bd).length;
    return RDoc(
      title: 'Daily Machinery Status',
      period: showDate(date),
      file: 'Daily machinery status ${showDate(date)}',
      meta: '${kBkOwns.where(owns.contains).join(', ')}: ${list.length} machinery – Working ${list.length - nb}, Breakdown $nb${report != null ? ' · Submitted by ${report!['by'] ?? ''} at ${report!['at']}' : ' · NOT SUBMITTED'}',
      blocks: [
        RTable(
          sheet: 'Status',
          head: const ['#', 'Owner', 'Machinery', 'Type', 'Status', 'Reason', 'Since', 'Days', 'Remark'],
          numCols: const {0, 7},
          rows: [
            for (final (i, m) in list.indexed)
              RRow([
                RCell('${i + 1}', n: true, value: i + 1),
                RCell(_s(m['owner'])),
                RCell(_s(m['id']), bold: true),
                RCell(_s(m['type'])),
                RCell(state(m).status, bold: true, tone: state(m).bd ? 'bad' : ''),
                RCell(state(m).reason),
                RCell(since(m) != null ? showDate(since(m)!.from) : ''),
                RCell(since(m) != null ? '${since(m)!.days}' : '', n: true, value: since(m)?.days),
                RCell(state(m).remark),
              ]),
          ],
        ),
      ],
    );
  }
}

// =====================================================================================================================
//  THE PERIOD REPORT – breakdown days per machinery / owner
// =====================================================================================================================
class BpRow {
  BpRow(this.no, this.owner, this.ownership, this.type, this.site, this.bd, this.times, this.why);
  final String no, owner, ownership, type;
  final int site, bd, times;
  final List<String> why;
  int get work => site - bd > 0 ? site - bd : 0;
}

String bpPct(int bd, int site) => site > 0 ? '${(bd / site * 100 + .5).floor()}%' : '–';

/// [to] after [today]: up to today. [own] / [owner] / [no]: '' = all. [only]: only machinery with a breakdown.
List<BpRow> bpCalc(BkDay d, List<Map<String, dynamic>> master, String from, String to0, {String own = '', String owner = '', String no = '', bool only = false}) {
  final today = d.today, to = to0.compareTo(today) > 0 ? today : to0;
  final out = <BpRow>[];
  for (final m in master) {
    if (own.isNotEmpty && (_s(m['ownership']).isEmpty ? 'Other' : _s(m['ownership'])) != own) continue;
    if (owner.isNotEmpty && _s(m['owner']).toUpperCase() != owner.toUpperCase()) continue;
    if (no.isNotEmpty && bkKey(m['id']) != bkKey(no)) continue;
    final sp = siteSpan(m, from, to), a = sp.first.isNotEmpty ? sp.first : from, b = sp.last.isNotEmpty ? sp.last : dayBefore(from);
    var bd = 0, times = 0;
    final why = <String>[];
    for (final x in d.history.where((x) => x['no'] == m['id'])) {
      final f = _s(x['from']), back = _s(x['backOn']);
      final s1 = f.compareTo(a) > 0 ? f : a, e0 = back.isNotEmpty ? dayBefore(back) : today, e1 = e0.compareTo(b) < 0 ? e0 : b;
      if (e1.compareTo(s1) < 0) continue;
      final n = _days(s1, e1);
      bd += n;
      times++;
      why.add('${showDate(f).substring(0, 5)}${back.isNotEmpty ? '–${showDate(dayBefore(back)).substring(0, 5)}' : ' →'}: ${x['reason'] ?? ''} ($n d)');
    }
    final r = BpRow(_s(m['id']), _s(m['owner']), _s(m['ownership']), _s(m['type']), sp.days, bd, times, why);
    if (r.site > 0 && (!only || r.bd > 0)) out.add(r);
  }
  out.sort((p, q) {
    final c = q.bd - p.bd;
    if (c != 0) return c;
    final o = p.owner.toLowerCase().compareTo(q.owner.toLowerCase());
    return o != 0 ? o : natCompare(p.no, q.no);
  });
  return out;
}

class BpOwner {
  BpOwner(this.owner, this.ownership);
  final String owner, ownership;
  int n = 0, site = 0, bd = 0, work = 0, times = 0;
}

/// By owner (the most breakdown days first).
List<BpOwner> bpOwners(List<BpRow> rows) {
  final by = <String, BpOwner>{};
  for (final x in rows) {
    final o = by.putIfAbsent(x.owner.isEmpty ? '–' : x.owner, () => BpOwner(x.owner.isEmpty ? '–' : x.owner, x.ownership));
    o
      ..n += 1
      ..site += x.site
      ..bd += x.bd
      ..work += x.work
      ..times += x.times;
  }
  return by.values.toList()
    ..sort((p, q) {
      final c = q.bd - p.bd;
      return c != 0 ? c : p.owner.toLowerCase().compareTo(q.owner.toLowerCase());
    });
}

const kBpViews = {'mach': 'Machinery-wise', 'owner': 'Owner-wise', 'both': 'Owner → Machinery'};

/// The period report in its view (print).
RDoc bpDoc(List<BpRow> rows, String view, String from, String to, {String own = '', String owner = ''}) {
  final tot = (site: rows.fold<int>(0, (a, x) => a + x.site), bd: rows.fold<int>(0, (a, x) => a + x.bd), work: rows.fold<int>(0, (a, x) => a + x.work), times: rows.fold<int>(0, (a, x) => a + x.times));
  RCell n(int v, {bool bold = false}) => RCell('$v', n: true, value: v, bold: bold);
  RRow mach(BpRow x, int i, {bool owner = true}) => RRow([
        RCell('${i + 1}', n: true, value: i + 1),
        RCell('${x.no}\n${x.type}'),
        if (owner) RCell('${x.owner}\n${x.ownership}'),
        n(x.site),
        RCell('${x.bd}', n: true, value: x.bd, bold: true, tone: x.bd > 0 ? 'bad' : ''),
        n(x.work),
        RCell(bpPct(x.bd, x.site), n: true),
        RCell(x.times > 0 ? '${x.times}' : '', n: true, value: x.times > 0 ? x.times : null),
        RCell(x.why.join(' · ')),
      ]);
  final meta = [if (own.isNotEmpty) own, if (owner.isNotEmpty) 'Owner: $owner'].join(' · ');
  RTable table;
  if (view == 'owner') {
    final l = bpOwners(rows);
    table = RTable(
      sheet: 'Breakdown',
      head: const ['#', 'Owner', 'Machinery', 'Days on site', 'Breakdown days', 'Working days', 'Breakdown %', 'Times'],
      numCols: const {0, 2, 3, 4, 5, 6, 7},
      empty: 'Nothing for these choices.',
      rows: [
        for (final (i, o) in l.indexed)
          RRow([RCell('${i + 1}', n: true, value: i + 1), RCell('${o.owner}\n${o.ownership}', bold: true), n(o.n), n(o.site), RCell('${o.bd}', n: true, value: o.bd, bold: true, tone: o.bd > 0 ? 'bad' : ''), n(o.work), RCell(bpPct(o.bd, o.site), n: true), RCell(o.times > 0 ? '${o.times}' : '', n: true)]),
      ],
      foot: [RRow([const RCell('Total', span: 2), n(rows.length), n(tot.site), n(tot.bd), n(tot.work), RCell(bpPct(tot.bd, tot.site), n: true), n(tot.times)], kind: RKind.grand)],
    );
  } else if (view == 'both') {
    final by = <String, List<BpRow>>{};
    for (final x in rows) {
      by.putIfAbsent(x.owner.isEmpty ? '–' : x.owner, () => []).add(x);
    }
    int sumBd(List<BpRow> g) => g.fold(0, (a, x) => a + x.bd);
    int sumT(List<BpRow> g) => g.fold(0, (a, x) => a + x.times);
    final keys = by.keys.toList()
      ..sort((p, q) {
        final c = sumBd(by[q]!) - sumBd(by[p]!);
        return c != 0 ? c : p.compareTo(q);
      });
    var k = 0;
    table = RTable(
      sheet: 'Breakdown',
      head: const ['#', 'Machinery', 'Days on site', 'Breakdown days', 'Working days', 'Breakdown %', 'Times', 'When and why'],
      numCols: const {0, 2, 3, 4, 5, 6},
      empty: 'Nothing for these choices.',
      rows: [
        for (final o in keys) ...[
          RRow([
            RCell('$o · ${by[o]!.length} machinery · ${by[o]!.first.ownership}', span: 2, bold: true),
            n(by[o]!.fold(0, (a, x) => a + x.site)),
            n(sumBd(by[o]!), bold: true),
            n(by[o]!.fold(0, (a, x) => a + x.work)),
            RCell(bpPct(sumBd(by[o]!), by[o]!.fold(0, (a, x) => a + x.site)), n: true),
            RCell(sumT(by[o]!) > 0 ? '${sumT(by[o]!)}' : '', n: true),
            const RCell(''),
          ], kind: RKind.group),
          for (final x in by[o]!) mach(x, k++, owner: false),
        ],
      ],
      foot: [RRow([RCell('Total – ${rows.length} machinery', span: 2), n(tot.site), n(tot.bd), n(tot.work), RCell(bpPct(tot.bd, tot.site), n: true), n(tot.times), const RCell('')], kind: RKind.grand)],
    );
  } else {
    table = RTable(
      sheet: 'Breakdown',
      head: const ['#', 'Machinery', 'Owner', 'Days on site', 'Breakdown days', 'Working days', 'Breakdown %', 'Times', 'When and why'],
      numCols: const {0, 3, 4, 5, 6, 7},
      empty: 'Nothing for these choices.',
      rows: [for (final (i, x) in rows.indexed) mach(x, i)],
      foot: [RRow([RCell('Total – ${rows.length} machinery', span: 3), n(tot.site), n(tot.bd), n(tot.work), RCell(bpPct(tot.bd, tot.site), n: true), n(tot.times), const RCell('')], kind: RKind.grand)],
    );
  }
  return RDoc(title: 'Breakdown Report – ${kBpViews[view]}', period: '${showDate(from)} to ${showDate(to)}', meta: meta, file: 'Breakdown $from to $to', portrait: false, blocks: [table]);
}

/// The Excel of the period report (the web's columns).
RDoc bpXlsDoc(List<BpRow> rows, String from, String to) => RDoc(
      title: 'Breakdown',
      file: 'Breakdown $from to $to',
      blocks: [
        RTable(
          sheet: 'Breakdown',
          head: const ['Machinery', 'Type', 'Owner', 'Ownership', 'Days on site', 'Breakdown days', 'Working days', 'Times', 'When and why'],
          numCols: const {4, 5, 6, 7},
          rows: [
            for (final x in rows)
              RRow([RCell(x.no), RCell(x.type), RCell(x.owner), RCell(x.ownership), RCell('${x.site}', n: true, value: x.site), RCell('${x.bd}', n: true, value: x.bd), RCell('${x.work}', n: true, value: x.work), RCell('${x.times}', n: true, value: x.times), RCell(x.why.join(' · '))]),
          ],
        ),
      ],
    );
