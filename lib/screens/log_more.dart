/* THE REST OF THE WEB'S LOG BOOK PAGE (3.12.0) – in the app's own screens (Log Book → ⋮):
 *   – All dates & Export: the web's list of the Log Book with its filters (dates – Today / Yesterday / Last 2 days / Last 7 days /
 *     This month, opening on the last days as set in My settings; machinery, shift, ownership, type, owner, chainage / work /
 *     driver), the server's totals, the period total machinery-wise, the entries (a water tanker trip by trip), Print Log Book,
 *     and the two Excel exports (one date – many machinery · one machinery – many dates – the empty dates to fill);
 *   – Import from Excel (either layout, every tab): each row checked as the web; then the server compares with the Log Book
 *     (checkLogImport / checkTankerImport) – already there, different (overwrite or keep), new – and imports (importLogBook,
 *     importTankerTrips);
 *   – the two templates. Every rule: core/lb_io.dart (the web's own code). */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/imports.dart' show findMachine;
import '../core/lb_io.dart';
import '../core/rdoc.dart' show fmt, r2;
import '../core/session.dart';
import '../core/sheet_read.dart';
import '../core/xlsx.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/pick_file.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'log_print.dart';
import 'logbook.dart' show LogCard, tripsOfRow;

final _sm = OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12));
String _today(Session s) => s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
String _company(Session s) => s.printNames.isEmpty ? 'Rachana Construction Limited' : s.printNames.first;
List<Map<String, dynamic>> _master(Session s) => [for (final m in s.machines) m.m];

/// The Log Book's two templates (Log Book → ⋮).
Future<void> logTemplate(BuildContext context, String kind) async {
  final s = SessionScope.read(context);
  final t = lbTemplate(kind, _master(s), _today(s));
  try {
    await shareXlsx(sheetsXlsx(t.sheets), t.file);
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
  }
}

// =====================================================================================================================
//  ALL DATES & EXPORT
// =====================================================================================================================
class LogFindScreen extends StatefulWidget {
  const LogFindScreen({super.key});
  @override
  State<LogFindScreen> createState() => _LogFindScreenState();
}

class _LogFindScreenState extends State<LogFindScreen> {
  String from = '', to = '', shift = '', own = '', err = '';
  final no = TextEditingController(), type = TextEditingController(), owner = TextEditingController(), q = TextEditingController();
  Map<String, dynamic>? res;
  bool loading = true, moreF = false, busy = false;
  int _seq = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastDays();
      _load();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    for (final c in [no, type, owner, q]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The list opens on the last days: 2 as the app comes, or his own choice (My settings: 2 / 7 / 30) – as the web's lfTwoDays.
  void _lastDays() {
    final s = SessionScope.read(context), t = parseKey(_today(s));
    final n0 = num.tryParse(s.pref('lbDays')) ?? 2, n = n0 > 2 ? n0.toInt() : 2;
    from = dateKey(DateTime(t.year, t.month, t.day - (n - 1)));
    to = _today(s);
  }

  Map<String, Object> _filter() => {'from': from, 'to': to, 'no': no.text.trim(), 'shift': shift, 'ownership': own, 'type': type.text.trim(), 'owner': owner.text.trim(), 'q': q.text.trim()};

  void _set(VoidCallback f) {
    setState(f);
    _load();
  }

  void _soon() {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = (await s.api.call('getLogBookList', [_filter()]) as Map).cast<String, dynamic>();
      if (my != _seq || !mounted) return;
      setState(() {
        res = r;
        loading = false;
      });
    } catch (e) {
      if (my != _seq || !mounted) return;
      setState(() {
        err = errText(e);
        loading = false;
      });
    }
  }

  void _range(String w) {
    final s = SessionScope.read(context), t = parseKey(_today(s));
    _set(() {
      switch (w) {
        case 'today':
          from = to = _today(s);
        case 'yesterday':
          from = to = dateKey(DateTime(t.year, t.month, t.day - 1));
        case '2':
          _lastDays(); // the web's "Last 2 days" = his own number of days (My settings), 2 as the app comes
        case '7':
          from = dateKey(DateTime(t.year, t.month, t.day - 6));
          to = _today(s);
        default:
          from = '${_today(s).substring(0, 8)}01';
          to = _today(s);
      }
    });
  }

  void _clear() => _set(() {
        shift = own = '';
        for (final c in [no, type, owner, q]) {
          c.clear();
        }
        _lastDays();
      });

  List<Map<String, dynamic>> get _rows => [for (final r in (res?['rows'] as List? ?? const []).whereType<Map>()) r.cast<String, dynamic>()];

  Future<void> _print() async {
    final s = SessionScope.read(context), rows = _rows;
    if (rows.isEmpty) {
      toast(context, 'No Log Book entries to print – pick a Machinery and dates first.', bad: true);
      return;
    }
    final dates = [for (final r in rows) '${r['date']}']..sort();
    await printLogBook(context, s, rows: rows, from: from.isNotEmpty ? from : dates.first, to: to.isNotEmpty ? to : _today(s));
  }

  /// The web's lbExport: every date of the period for every machinery of the filter (or the one picked).
  Future<void> _export(String kind) async {
    final s = SessionScope.read(context), master = _master(s);
    final typed = no.text.trim(), picked = typed.isEmpty ? null : findMachine(master, typed);
    if (typed.isNotEmpty && picked == null) {
      toast(context, '"$typed" is not in Master. Pick a machinery from the list.', bad: true);
      return;
    }
    setState(() => busy = true);
    try {
      final f = lbExportFilter(from: from, to: to, no: typed, picked: picked, shift: shift, own: own, type: type.text.trim(), owner: owner.text.trim(), q: q.text.trim());
      final d = (await s.api.call('getLogBookList', [f]) as Map).cast<String, dynamic>();
      final x = lbExport(
        kind: kind,
        f: f,
        picked: picked,
        rows0: [for (final r in (d['rows'] as List? ?? const []).whereType<Map>()) r.cast<String, dynamic>()],
        itemBoq: (d['itemBoq'] as Map?) ?? const {},
        master: master,
        today: _today(s),
        company: _company(s),
        site: s.siteLabel,
      );
      await shareXlsx(sheetsXlsx(x.sheets), x.file);
      if (mounted) toast(context, x.said);
    } on SheetError catch (e) {
      if (mounted) toast(context, e.message, bad: true);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  int get _setCount => [shift, own, for (final c in [no, type, owner, q]) c.text.trim()].where((x) => x.isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), today = _today(s), last = parseKey(today);
    final rows = _rows;
    final t = (res?['totals'] as Map?) ?? const {};
    final count = asNum(res?['count']) ?? 0;
    final sum = 'Entries: ${fmt(count)}   Machinery: ${fmt(t['machines'])}${(asNum(t['km']) ?? 0) != 0 ? '   KM: ${fmt(t['km'])}' : ''}${(asNum(t['hr']) ?? 0) != 0 ? '   Hrs: ${fmt(t['hr'])}' : ''}'
        '   Issued: ${fmt(t['issued'])} L   Consumed: ${fmt(t['consumed'])} L${count > rows.length ? '   (showing latest ${rows.length})' : ''}';
    // the period total machinery-wise: when the list has more than one date (as the web)
    final days = {for (final r in rows) r['date']}.length;
    final multi = (from.isNotEmpty && to.isNotEmpty && from != to) || from.isEmpty || to.isEmpty ? days > 1 : false;
    final summary = [for (final x in (res?['summary'] as List? ?? const []).whereType<Map>()) x];
    final view = [
      for (final r in rows)
        if (tripsOfRow(s, r) case final ts?)
          for (final (i, tr) in ts.indexed) {...r, '_t': tr, '_n': i + 1, if (i > 0) 'qty': null}
        else
          r
    ];
    Widget box(String label, TextEditingController c, String key, {List<String> options = const []}) => TextBox(key: Key(key), label: label, controller: c, options: options, onChanged: (_) => _soon());
    return Scaffold(
      appBar: AppBar(
        title: const TwoLang('Log Book – all dates', 'लॉग बुक – सर्व तारखा', size: 19, weight: FontWeight.w700),
        actions: [IconButton(key: const Key('lf-reload'), tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('lf-list'), padding: const EdgeInsets.fromLTRB(14, 8, 14, 40), children: [
          Row(children: [
            Expanded(child: DateField(key: const Key('lf-from'), label: 'From (blank = from start)', value: from, last: last, onChanged: (v) => _set(() => from = v))),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('lf-to'), label: 'To (blank = till today)', value: to, last: last, onChanged: (v) => _set(() => to = v))),
          ]),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('lf-more'),
              onPressed: () => setState(() => moreF = !moreF),
              icon: Icon(moreF ? Icons.expand_less_rounded : Icons.tune_rounded),
              label: Text(moreF ? 'Fewer filters' : (_setCount == 0 ? 'More filters' : 'More filters ($_setCount set)')),
            ),
          ),
          if (moreF) ...[
            box('Machinery', no, 'lf-no', options: [for (final m in s.machines) m.id]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: PickField(key: const Key('lf-shift'), label: 'Shift', value: shift, items: const ['Full Day', 'Day', 'Night'], blank: 'All', onChanged: (v) => _set(() => shift = v))),
              const SizedBox(width: 8),
              Expanded(child: PickField(key: const Key('lf-own'), label: 'Ownership', value: own, items: const ['Own', 'Rental', 'Hired', 'Other', 'Debit'], blank: 'All', onChanged: (v) => _set(() => own = v))),
            ]),
            const SizedBox(height: 8),
            box('Type of Machinery', type, 'lf-type', options: {for (final m in s.machines) if (m.type.isNotEmpty) m.type}.toList()..sort()),
            const SizedBox(height: 8),
            box('Owner Name', owner, 'lf-owner', options: {for (final m in s.machines) if (m.owner.isNotEmpty) m.owner}.toList()..sort()),
            const SizedBox(height: 8),
            box('Chainage / Work / Driver', q, 'lf-q'),
            const SizedBox(height: 8),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final x in [('today', 'Today'), ('yesterday', 'Yesterday'), ('2', 'Last 2 days'), ('7', 'Last 7 days'), ('month', 'This month')])
                Padding(padding: const EdgeInsets.only(right: 6), child: OutlinedButton(key: Key('lf-r-${x.$1}'), style: _sm, onPressed: () => _range(x.$1), child: Text(x.$2))),
              OutlinedButton(key: const Key('lf-clear'), style: _sm, onPressed: _clear, child: const Text('Clear filters')),
            ]),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            FilledButton.icon(
              key: const Key('lf-print'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14), backgroundColor: C.blue),
              onPressed: _print,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Print Log Book'),
            ),
            OutlinedButton.icon(key: const Key('lf-exp-date'), style: _sm, onPressed: busy ? null : () => _export('date'), icon: const Icon(Icons.table_view_rounded, size: 18), label: const Text('Export: one date – many machinery')),
            OutlinedButton.icon(key: const Key('lf-exp-mach'), style: _sm, onPressed: busy ? null : () => _export('mach'), icon: const Icon(Icons.table_view_rounded, size: 18), label: const Text('Export: one machinery – many dates')),
          ]),
          const SizedBox(height: 12),
          if (loading && res == null)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          else if (err.isNotEmpty)
            InfoLine(err, bad: true)
          else ...[
            Text(sum, key: const Key('lf-sum'), style: const TextStyle(fontWeight: FontWeight.w800, color: C.blue, fontSize: 14.5)),
            if (multi && summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Period total – machinery-wise (${showDate(from.isNotEmpty ? from : (rows.isEmpty ? '' : '${rows.last['date']}'))} to ${showDate(to.isNotEmpty ? to : today)})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 6),
              for (final (i, x) in summary.indexed) _sumCard(i, x, s),
              _sumTotal(summary),
              const SizedBox(height: 12),
              const Text('Day-wise entries', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            ],
            const SizedBox(height: 8),
            if (view.isEmpty) const EmptyState('No Log Book entries match this filter.', 'Change the dates or the filter.', pic: 'notebook'),
            for (final r in view)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(left: 4, bottom: 3), child: Text('${showDate('${r['date']}')} · ${r['shift'] ?? ''}', style: const TextStyle(color: C.muted, fontWeight: FontWeight.w700, fontSize: 13))),
                  LogCard(r: r, onChanged: _load),
                ]),
              ),
          ],
        ]),
      ),
    );
  }

  /// One machinery of the period total (the web's logSumHtml).
  Widget _sumCard(int i, Map x, Session s) {
    final unit = '${x['unit'] ?? ''}';
    String two(Object? a, Object? b) => [
          if (unit != 'Hrs' && a != '' && a != null) '${fmt(a)}${unit == 'KM + Hrs' ? ' km' : ''}',
          if (unit != 'KM' && b != '' && b != null) '${fmt(b)}${unit == 'KM + Hrs' ? ' hr' : ''}',
        ].join(' · ');
    final std = [if (jsTrue(x['kmStd'])) '${x['kmStd']} km/L', if (jsTrue(x['hrStd'])) '${x['hrStd']} L/hr'].join(' + ');
    final m = s.machine('${x['no']}');
    final works = m == null ? '' : worksOfJs(m.m).join(', ');
    final diff = x['diff'];
    return Container(
      key: Key('lf-sm-$i'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${x['no']}${jsTrue(x['type']) ? ' · ${x['type']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('${fmt(x['days'])} ${asNum(x['days']) == 1 ? 'day' : 'days'}', style: const TextStyle(color: C.muted, fontWeight: FontWeight.w700)),
        ]),
        Text(works.isNotEmpty ? works : unit, style: const TextStyle(color: C.muted, fontSize: 12.5)),
        const SizedBox(height: 4),
        Text('Start ${two(x['okm'], x['ohr'])} (${showDate('${x['firstDate'] ?? ''}')}) → Close ${two(x['ckm'], x['chr'])} (${showDate('${x['lastDate'] ?? ''}')})', style: const TextStyle(fontSize: 13)),
        Text([if ((asNum(x['km']) ?? 0) != 0) 'KM ${fmt(x['km'])}', if ((asNum(x['hr']) ?? 0) != 0) 'Hrs ${fmt(x['hr'])}', 'Issued ${fmt(x['issued'])} L', 'As per standard ${fmt(x['consumed'])} L'].join(' · '),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text(
          'More / (Less): ${diff == '' || diff == null ? '–' : '${(asNum(diff) ?? 0) > 0 ? '+' : ''}${fmt(diff)} L'} · Average: ${jsTrue(x['average']) ? x['average'] : '–'} · Standard: ${std.isEmpty ? '–' : std}',
          style: TextStyle(fontSize: 13, color: (asNum(diff) ?? 0) > 0 ? C.red : C.ink),
        ),
      ]),
    );
  }

  Widget _sumTotal(List<Map> list) {
    double t(String k) => r2(list.fold<num>(0, (a, x) => a + (asNum(x[k]) ?? 0)));
    final v = r2(t('issued') - t('consumed'));
    return Text('Total – ${list.length} machinery: KM ${fmt(t('km'))} · Hrs ${fmt(t('hr'))} · Issued ${fmt(t('issued'))} L · As per standard ${fmt(t('consumed'))} L · ${v > 0 ? '+' : ''}${fmt(v)} L',
        key: const Key('lf-sum-total'), style: const TextStyle(fontWeight: FontWeight.w800));
  }
}

// =====================================================================================================================
//  IMPORT FROM EXCEL
// =====================================================================================================================

/// The web's Log Book "Import from Excel": true when something was imported.
Future<bool> importLog(BuildContext context) async {
  final s = SessionScope.read(context);
  final f = await pickSheetFile();
  if (f == null || !context.mounted) return false;
  try {
    final x = readLogFile(readSheets(f.bytes), _master(s));
    if (x.skipped > 0) toast(context, '${x.skipped} blank row(s) skipped (dates not filled).');
    return await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LogImportScreen(file: f.name, data: x))) ?? false;
  } on SheetError catch (e) {
    toast(context, e.message, bad: true);
  } catch (_) {
    toast(context, 'Could not read the file.', bad: true);
  }
  return false;
}

class LogImportScreen extends StatefulWidget {
  const LogImportScreen({super.key, required this.file, required this.data});
  final String file;
  final ({List<Map<String, Object?>> rows, int skipped, List<Map<String, Object?>> trips, List<Map<String, Object?>> tkBad, int tkStatus, String tkStatusNote}) data;
  @override
  State<LogImportScreen> createState() => _LogImportScreenState();
}

class _LogImportScreenState extends State<LogImportScreen> {
  bool busy = false;

  List<Map<String, Object?>> get _send => [for (final r in widget.data.rows) sendRow(r)];

  /// A row as the web sends it (JSON has no NaN: JavaScript sends null).
  static Map<String, Object?> sendRow(Map<String, Object?> r) => _clean(r) as Map<String, Object?>;
  static Object? _clean(Object? v) => v is double && !v.isFinite
      ? null
      : v is Map
          ? <String, Object?>{for (final e in v.entries) '${e.key}': _clean(e.value)}
          : v is List
              ? [for (final x in v) _clean(x)]
              : v;

  Future<void> _go() async {
    final s = SessionScope.read(context), rows = widget.data.rows, trips = widget.data.trips, note = widget.data.tkStatusNote;
    setState(() => busy = true);
    try {
      final chk = rows.isNotEmpty ? (await s.api.call('checkLogImport', [{'rows': _send}]) as Map).cast<String, dynamic>() : <String, dynamic>{'ok': true, 'errors': [], 'fresh': 0, 'same': 0, 'changed': []};
      final tchk = trips.isNotEmpty ? (await s.api.call('checkTankerImport', [{'rows': trips}]) as Map).cast<String, dynamic>() : <String, dynamic>{'ok': true, 'errors': [], 'added': 0, 'same': 0, 'tankers': 0};
      if (!mounted) return;
      List<Map> l(Object? v) => [for (final x in (v as List? ?? const []).whereType<Map>()) x];
      if (chk['ok'] != true || tchk['ok'] != true) {
        await tellLines(context, 'Fix the file first', [
          'Nothing was imported.',
          for (final x in l(chk['errors'])) 'Line ${x['row']}: ${x['msg']}',
          for (final x in l(tchk['errors'])) '${jsTrue(x['row']) ? 'Line ${x['row']}: ' : ''}${x['msg']}',
        ]);
        return;
      }
      final fresh = (asNum(chk['fresh']) ?? 0).toInt(), same = (asNum(chk['same']) ?? 0).toInt(), changed = l(chk['changed']);
      final tAdded = (asNum(tchk['added']) ?? 0).toInt(), tSame = (asNum(tchk['same']) ?? 0).toInt(), tankers = (asNum(tchk['tankers']) ?? 0).toInt();
      if (fresh == 0 && changed.isEmpty && tAdded == 0) {
        await tellLines(context, 'Already in the Log Book', [
          'All ${same + tSame} ${trips.isNotEmpty ? 'lines' : 'rows'} of this file are already in the Log Book${rows.isNotEmpty ? ' with the same readings' : ''}. Nothing to import.',
          if (note.isNotEmpty) '$note.',
        ]);
        return;
      }
      var overwrite = false;
      if (changed.isNotEmpty) {
        String fv(Object? v) => v == '' || v == null ? '–' : v is num ? fmt(v) : '$v';
        overwrite = await askLines(
          context,
          '${changed.length} entr${changed.length == 1 ? 'y is' : 'ies are'} already in the Log Book – but different',
          [
            for (final x in changed)
              'Line ${x['line']} · ${x['no']} · ${showDate('${x['date']}')} · ${x['shift']}: ${[for (final d in l(x['diffs'])) '${d['f']}: ${fv(d['from'])} → ${fv(d['to'])}'].join('; ')}',
          ],
          note: 'Yes, overwrite = the Log Book takes the file\'s figures (Start of the next entries and diesel are worked out again). Cancel = keep what is saved${fresh > 0 ? ' and import only the $fresh new row(s)' : ''}.',
          yes: 'Yes, overwrite',
        );
        if (!mounted) return;
        if (!overwrite && fresh == 0 && tAdded == 0) {
          toast(context, 'Nothing imported – the saved entries were kept.');
          return;
        }
      }
      final nm = {for (final r in rows) r['no']}.length;
      final ow = overwrite ? changed.length : 0;
      final ok = await askLines(context, 'Import into the Log Book?', [
        if (rows.isNotEmpty) ...[
          '$fresh new entr${fresh == 1 ? 'y' : 'ies'} will be added',
          '$ow existing entr${ow == 1 ? 'y' : 'ies'} will be overwritten',
          '$same${changed.isNotEmpty && !overwrite ? ' + ${changed.length}' : ''} already in the Log Book – skipped',
        ],
        if (trips.isNotEmpty) ...[
          '$tAdded water tanker trip${tAdded == 1 ? '' : 's'} will be added ($tankers tanker${tankers == 1 ? '' : 's'})',
          '$tSame water tanker trip${tSame == 1 ? '' : 's'} already saved – skipped',
        ],
        if (note.isNotEmpty) note,
      ], note: [
        if (rows.isNotEmpty) '$nm machinery. Start of each row = the Close before it. Diesel is taken from Diesel Issue. All rows are saved together, or none.',
        if (trips.isNotEmpty) 'Water tanker: one line = one trip; the trips of a date and shift go into that entry. All trips are saved together, or none.',
      ].join('\n'), yes: 'Import');
      if (!ok || !mounted) return;
      final doLog = fresh > 0 || (overwrite && changed.isNotEmpty);
      var res = <String, dynamic>{'ok': true, 'added': 0, 'overwritten': 0, 'same': same, 'changed': changed};
      if (doLog) {
        res = (await s.api.call('importLogBook', [{'rows': _send, 'overwrite': overwrite}], true) as Map).cast<String, dynamic>();
        if (!mounted) return;
        if (res['ok'] != true) {
          await tellLines(context, 'Nothing imported', [for (final x in l(res['errors'])) 'Line ${x['row']}: ${x['msg']}']);
          return;
        }
      }
      final said = <String>[
        if (rows.isNotEmpty) 'Log Book: ${res['added']} added, ${res['overwritten']} overwritten, ${(asNum(res['same']) ?? 0) + (overwrite ? 0 : l(res['changed']).length)} skipped',
      ];
      if (tAdded > 0) {
        Map<String, dynamic> tres;
        try {
          tres = (await s.api.call('importTankerTrips', [{'rows': trips}], true) as Map).cast<String, dynamic>();
        } catch (e) {
          tres = {'ok': false, 'errors': [{'msg': errText(e)}]};
        }
        if (!mounted) return;
        if (tres['ok'] != true) {
          await tellLines(context, 'Water tanker trips not imported', [
            if (doLog) '${said.first} – these are saved.',
            'The water tanker trips were NOT imported:',
            for (final x in l(tres['errors'])) '${jsTrue(x['row']) ? 'Line ${x['row']}: ' : ''}${x['msg']}',
          ]);
          if (mounted) Navigator.pop(context, true);
          return;
        }
        said.add('Water tanker: ${tres['added']} trip${tres['added'] == 1 ? '' : 's'} added, ${tres['same']} already saved');
      } else if (trips.isNotEmpty) {
        said.add('Water tanker: $tSame trip${tSame == 1 ? '' : 's'} already saved');
      }
      if (!mounted) return;
      toast(context, '${said.join(' · ')}.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), d = widget.data, master = _master(s), today = _today(s);
    final probs = [for (final r in d.rows) logProblems(r, today, master)];
    final bad = probs.where((p) => p.isNotEmpty).length;
    final stop = bad > 0 || d.tkBad.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(stop ? 'Fix the file first' : 'Import into the Log Book', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('li-list'), padding: const EdgeInsets.fromLTRB(14, 8, 14, 120), children: [
        Text(widget.file, style: const TextStyle(color: C.muted, fontSize: 13)),
        const SizedBox(height: 6),
        if (stop)
          InfoLine(bad > 0 ? '$bad of ${d.rows.length} rows have a problem (marked ✗). Nothing was imported.' : 'Nothing was imported.', bad: true, icon: Icons.error_outline_rounded)
        else
          InfoLine('${d.rows.length} row${d.rows.length == 1 ? '' : 's'}${d.trips.isNotEmpty ? ' and ${d.trips.length} water tanker trip${d.trips.length == 1 ? '' : 's'}' : ''} checked. The server compares them with the Log Book before anything is saved.',
              icon: Icons.fact_check_outlined),
        if (d.tkStatusNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: InfoLine('${d.tkStatusNote}.')),
        if (d.tkBad.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Water tanker – ${d.tkBad.length} line${d.tkBad.length == 1 ? '' : 's'}:', style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final x in d.tkBad) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Line ${x['line']}: ${x['msg']}', style: const TextStyle(color: C.red, fontWeight: FontWeight.w600))),
        ],
        const SizedBox(height: 10),
        for (final (i, r) in d.rows.indexed)
          Container(
            key: Key('li-row-$i'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: probs[i].isEmpty ? Colors.white : C.redSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: probs[i].isEmpty ? C.line : C.red.withValues(alpha: .4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Line ${r['line']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                Icon(probs[i].isEmpty ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 20, color: probs[i].isEmpty ? C.greenDark : C.red),
                const SizedBox(width: 6),
                if (probs[i].isNotEmpty) Expanded(child: Text(probs[i].join(', '), style: const TextStyle(fontWeight: FontWeight.w700, color: C.red))),
              ]),
              const SizedBox(height: 4),
              Text('${RegExp(r'^\d{4}-').hasMatch('${r['date']}') ? showDate('${r['date']}') : r['date']} · ${r['shift']} · ${r['no']}${jsTrue(r['unit']) ? ' · ${r['unit']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                [
                  if (jsTrue(r['mode'])) '${r['mode']}',
                  if (r['openingKm'] != '' || r['closingKm'] != '') 'KM ${fmt(r['openingKm'])} – ${fmt(r['closingKm'])}',
                  if (r['openingHr'] != '' || r['closingHr'] != '') 'Hrs ${fmt(r['openingHr'])} – ${fmt(r['closingHr'])}',
                  if (jsTrue(r['tStart'])) '${r['tStart']} – ${r['tEnd']}',
                  if (r['trip'] != '') '${fmt(r['trip'])} trips',
                  if (jsTrue(r['work'])) '${r['work']}',
                ].join(' · '),
                style: const TextStyle(color: C.muted, fontSize: 13),
              ),
            ]),
          ),
        if (d.trips.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('Water tanker trips', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final t in d.trips)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Line ${t['line']} · ${showDate('${t['date']}')} · ${t['shift']} · ${t['no']} · ${t['c']} ${t['a']}–${t['b']}', style: const TextStyle(fontSize: 13)),
            ),
        ],
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: stop
              ? FilledButton(key: const Key('li-ok'), onPressed: () => Navigator.pop(context, false), child: const Text('OK'))
              : FilledButton.icon(
                  key: const Key('li-go'),
                  style: FilledButton.styleFrom(backgroundColor: C.blue),
                  onPressed: busy ? null : _go,
                  icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload_file_rounded),
                  label: const Text('Import'),
                ),
        ),
      ),
    );
  }
}
