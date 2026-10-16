/* EDIT LOG BOOK – the app's own screen (3.6.0) of the web's "Edit Log Book": a machinery and dates (Yesterday / This month /
 * Last month), all its entries open together as cards; change any reading – everything is worked out again at once (total,
 * opening / issued / consumed / closing diesel); a changed Close moves the next Start; red cards tell what is wrong ("Use it");
 * + Add row (the first free date, or the other shift of the ticked dates), Add all missing dates, + work in this shift, Delete;
 * Save changes sends the whole lot once (saveLogBulk). A water tanker (Format I) opens as its trips, one card each
 * (getTankerRange → saveTankerRange), with Export Excel. Print Log Book prints what is saved. The rules: core/log_edit.dart. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/log_edit.dart';
import '../core/rdoc.dart' show RDoc, RTable, RRow, RCell;
import '../core/session.dart';
import '../core/xlsx.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart' show shareXlsx;
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart' show MachinePicker;
import 'log_print.dart';
import 'logbook.dart' show needsOf, kLogShifts;
import '../core/dash.dart' show kDayStatus;

Future<void> openLogEdit(BuildContext context, {String no = ''}) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LogEditScreen(no: no)));

const _numF = {'okm', 'ckm', 'ohr', 'chr', 'tBrk', 'trip', 'odSet'};
String _txt(Object? v) => v == null || v == '' ? '' : js(v);
String _two(int n) => n.toString().padLeft(2, '0');

class LogEditScreen extends StatefulWidget {
  const LogEditScreen({super.key, this.no = ''});
  final String no;
  @override
  State<LogEditScreen> createState() => _LogEditScreenState();
}

class _LogEditScreenState extends State<LogEditScreen> {
  String no = '', from = '', to = '', err = '', ltErr = '';
  LogEdit? ed;
  LtEdit? lt;
  LxCalc? fig;
  bool busy = false, started = false;
  final _ctl = <Object, Map<String, TextEditingController>>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    no = widget.no;
  }

  @override
  void dispose() {
    _drop(now: true);
    _list.dispose();
    super.dispose();
  }

  /// The boxes' controllers let go (after the frame: a box on the screen may still hold one until it is drawn again).
  void _drop({bool now = false}) {
    final old = [for (final m in _ctl.values) ...m.values];
    _ctl.clear();
    _later(old, now: now);
  }

  void _later(List<TextEditingController> old, {bool now = false}) {
    if (now) {
      for (final c in old) {
        c.dispose();
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in old) {
        c.dispose();
      }
    });
  }

  bool get _dirty => (ed?.dirty ?? false) || (lt?.dirty ?? false);

  // ---------- the boxes of a row: one controller each, kept in step with the grid ----------
  TextEditingController _c(Object row, String f, String Function() now) => _ctl.putIfAbsent(row, () => {}).putIfAbsent(f, () => TextEditingController(text: now()));

  Object? _val(LxRow r, String f) => f.startsWith('it:') ? r.items[f.substring(3)] : r[f];

  /// After the grid moved figures by itself (a Start that follows, a pick, Use it …): the boxes show them.
  void _sync() {
    final e = ed;
    if (e == null) return;
    final live = e.rows.toSet();
    for (final row in _ctl.keys.toList()) {
      if (row is LxRow && !live.contains(row)) _later(_ctl.remove(row)!.values.toList());
    }
    for (final r in e.rows) {
      final m = _ctl[r];
      if (m == null) continue;
      m.forEach((f, c) {
        final want = _val(r, f), isNum = _numF.contains(f) || f.startsWith('it:');
        final same = isNum ? js(lxN(c.text)) == js(want) : c.text == '${want ?? ''}';
        if (!same) c.text = _txt(want);
      });
    }
  }

  void _re() {
    final e = ed;
    if (e == null) return;
    setState(() {
      fig = e.calc();
      _sync();
    });
  }

  // ---------- open ----------
  Future<void> _pick() async {
    final s = SessionScope.read(context);
    final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => MachinePicker(only: s.machines));
    if (m != null && mounted) setState(() => no = m.id);
  }

  void _quick(String which) {
    final s = SessionScope.read(context);
    final t = parseKey(s.today.isNotEmpty ? s.today : dateKey(DateTime.now()));
    setState(() {
      if (which == 'yday') {
        from = to = dateKey(DateTime(t.year, t.month, t.day - 1));
      } else if (which == 'this') {
        from = dateKey(DateTime(t.year, t.month, 1));
        to = dateKey(t);
      } else {
        from = dateKey(DateTime(t.year, t.month - 1, 1));
        to = dateKey(DateTime(t.year, t.month, 0));
      }
    });
  }

  Future<bool> _discardOk() async => !_dirty || await ask(context, 'Discard unsaved changes?', 'Changes in the grid are not saved yet.', yes: 'Discard', danger: true);

  Future<void> _open({bool ask = true}) async {
    final s = SessionScope.read(context), m = s.machine(no);
    if (m == null) {
      setState(() => err = 'Pick a machinery from the list.');
      return;
    }
    if (from.isEmpty || to.isEmpty) {
      setState(() => err = 'Select From and To dates.');
      return;
    }
    if (ask && !await _discardOk()) return;
    setState(() {
      busy = true;
      err = '';
    });
    try {
      if (m.waterTanker) {
        final d = ((await s.api.call('getTankerRange', [m.id, from, to])) as Map).cast<String, dynamic>();
        if (!mounted) return;
        _drop();
        setState(() {
          ed = null;
          fig = null;
          lt = LtEdit(d, superUser: s.superAdmin, today: s.today);
          ltErr = '';
          no = '${(d['machine'] as Map?)?['id'] ?? m.id}';
          busy = false;
        });
        return;
      }
      final d = ((await s.api.call('getLogEditData', [m.id, from, to])) as Map).cast<String, dynamic>();
      if (!mounted) return;
      _drop();
      final e = LogEdit(d, superUser: s.superAdmin, today: s.today, canEdit: s.canEdit('Log Book'));
      setState(() {
        lt = null;
        ed = e;
        fig = e.calc();
        no = e.no;
        busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  // ---------- changes ----------
  void _type(LxRow r, String f, String v) {
    final e = ed!;
    if (f.startsWith('it:')) {
      e.typeItem(r, f.substring(3), v);
    } else {
      e.type(r, f, _numF.contains(f) ? lxN(v) : v);
    }
    _re();
  }

  void _change(LxRow r, String f, String v) {
    final no2 = ed!.change(r, f, v);
    if (no2 != null) {
      toast(context, no2, bad: true);
      return;
    }
    _re();
  }

  Future<void> _time(LxRow r, String f) async {
    final cur = tMin(f == 'tStart' ? r.tStart : r.tEnd);
    final t = await showTimePicker(context: context, initialTime: cur == null ? const TimeOfDay(hour: 8, minute: 0) : TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t == null || !mounted) return;
    ed!.type(r, f, '${_two(t.hour)}:${_two(t.minute)}');
    _re();
  }

  Future<void> _remove(List<LxRow> list, {bool ask = true}) async {
    final e = ed!;
    if (ask) {
      final saved = list.where((r) => !r.isNew).length;
      final ok = await askLines(context, 'Delete ${list.length} row${list.length == 1 ? '' : 's'}?', [
        list.take(20).map((r) => '${showDate(r.date)} (${r.shift})').join(', ') + (list.length > 20 ? ' …' : ''),
      ], note: '${saved > 0 ? '$saved saved entr${saved == 1 ? 'y is' : 'ies are'} removed when you press Save changes. ' : ''}The row after each removed row starts where the row before it closed.', yes: 'Delete', danger: true);
      if (!ok) return;
    }
    e.remove(list);
    _re();
  }

  /// Delete selected: the rows ticked (asked first), or the trips ticked.
  void _delSel() {
    final e = ed, l = lt;
    if (e != null) {
      _remove(e.rows.where((r) => r.sel).toList());
    } else if (l != null) {
      setState(() => l.remove(l.trips.where((t) => t.sel).toList()));
    }
  }

  void _addRow() {
    final e = ed!;
    final (say, bad, row) = e.addRow();
    _re();
    if (say.isNotEmpty) toast(context, say, bad: bad);
    if (row != null) _show(row);
  }

  void _fill() {
    final (say, bad) = ed!.fillGaps();
    _re();
    toast(context, say, bad: bad);
  }

  void _more(LxRow of) {
    final e = ed!, r = e.addWork(of);
    if (r == null) return;
    _re();
    toast(context, e.addWorkSay(r));
    _show(r);
  }

  final _list = ScrollController();

  /// Brings a row into view (a row just added).
  void _show(LxRow r) {
    final i = ed?.rows.indexOf(r) ?? -1;
    if (i < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_list.hasClients) return;
      final at = (_list.position.maxScrollExtent * (i + 1) / ((ed?.rows.length ?? 1) + 2)).clamp(0.0, _list.position.maxScrollExtent).toDouble();
      _list.animateTo(at, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _save() async {
    final e = ed!, s = SessionScope.read(context);
    final plan = e.save();
    if (plan.problem.isNotEmpty) {
      toast(context, plan.problem, bad: true);
      return;
    }
    if (!await askLines(context, 'Save Log Book of ${e.no}?', plan.ask, note: plan.notes.join('\n'), yes: 'Save')) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final res = ((await s.api.call('saveLogBulk', [plan.body], true)) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (res['ok'] == false) {
        setState(() => busy = false);
        final msgs = (res['errors'] as List? ?? const []).map((x) => x is Map ? '${x['msg'] ?? ''}' : '$x').join(' | ');
        toast(context, 'Nothing saved: $msgs', bad: true);
        return;
      }
      toast(context, 'Log Book saved – ${res['changed'] ?? 0} changed, ${res['added'] ?? 0} added, ${res['deleted'] ?? 0} deleted.');
      await _open(ask: false);
    } catch (er) {
      if (!mounted) return;
      setState(() => busy = false);
      if (isSent(er)) {
        toast(context, errText(er));
        await _open(ask: false);
        return;
      }
      toast(context, errText(er), bad: true);
    }
  }

  Future<void> _print() async {
    final s = SessionScope.read(context);
    final mach = ed?.no ?? lt?.no ?? '';
    final f = ed?.from ?? lt?.from ?? '', t = ed?.to ?? lt?.to ?? '';
    if (mach.isEmpty) {
      toast(context, 'Open a machinery first.', bad: true);
      return;
    }
    if (_dirty) {
      toast(context, 'Save the changes first – the print shows what is saved.', bad: true);
      return;
    }
    setState(() => busy = true);
    try {
      final res = ((await s.api.call('getLogBookList', [
        {'no': mach, 'from': f, 'to': t, 'all': true}
      ])) as Map);
      if (!mounted) return;
      setState(() => busy = false);
      final rows = (res['rows'] as List? ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).where((r) => r['no'] == mach).toList();
      await printLogBook(context, s, rows: rows, from: f, to: t);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, errText(e), bad: true);
      }
    }
  }

  // ---------- a water tanker ----------
  Future<void> _ltTime(LtTrip t, bool first) async {
    final cur = tMin(first ? t.a : t.b);
    final tm = await showTimePicker(context: context, initialTime: cur == null ? TimeOfDay.now() : TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (tm == null || !mounted) return;
    setState(() {
      if (first) {
        t.a = '${_two(tm.hour)}:${_two(tm.minute)}';
      } else {
        t.b = '${_two(tm.hour)}:${_two(tm.minute)}';
      }
    });
  }

  Future<void> _ltSave() async {
    final l = lt!, s = SessionScope.read(context);
    final bad = l.problems();
    if (bad.isNotEmpty) {
      setState(() => ltErr = '${bad.map((x) => x.$2).join('\n')}\nNothing was saved.');
      toast(context, bad.first.$2, bad: true);
      return;
    }
    setState(() {
      busy = true;
      ltErr = '';
    });
    try {
      final r = ((await s.api.call('saveTankerRange', [l.body()], true)) as Map).cast<String, dynamic>();
      if (!mounted) return;
      _drop();
      setState(() {
        lt = LtEdit(r, superUser: s.superAdmin, today: s.today);
        busy = false;
      });
      final n = asNum(r['changed']) ?? 0, a = asNum(r['added']) ?? 0;
      toast(context, n > 0 ? 'Saved – $a trip${a == 1 ? '' : 's'} added, ${r['removed'] ?? 0} taken out ($n date${n == 1 ? '' : 's'}).' : 'Nothing changed.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        ltErr = isSent(e) ? errText(e) : '${errText(e)}\nNothing was saved.';
      });
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  /// Export: the Water Tanker Report layout with empty lines to fill.
  Future<void> _ltExport() async {
    final l = lt!, s = SessionScope.read(context);
    final owner = '${l.machine['owner'] ?? ''}';
    const head = ['SR. NO.', 'DATE', 'SHIFT', 'NAME OF AGENCY', 'VEHICLE NO', 'CHALLAN NO', 'DISPATCH TIME', 'UNLOAD TIME', 'TRIP', 'CHAINAGE NO', 'USE FOR'];
    final saved = (l.d['trips'] as List? ?? const []).whereType<Map>().toList();
    final rows = <RRow>[
      for (var i = 0; i < saved.length; i++)
        RRow([
          RCell('${i + 1}', n: true, value: i + 1),
          RCell(showDate('${saved[i]['date']}')),
          RCell('${saved[i]['shift']}'),
          RCell(owner),
          RCell(l.no),
          RCell('${saved[i]['c'] ?? ''}'),
          RCell('${saved[i]['a'] ?? ''}'),
          RCell('${saved[i]['b'] ?? ''}'),
          const RCell('1', n: true, value: 1),
          RCell('${saved[i]['ch'] ?? ''}'),
          RCell('${saved[i]['u'] ?? ''}'),
        ]),
      for (var k = 0; k < 100; k++) RRow([const RCell(''), const RCell(''), const RCell(''), RCell(owner), RCell(l.no)]),
    ];
    final title = 'WATER TANKER REPORT – ${l.no} – ${showDate(l.from)} to ${showDate(l.to)}';
    final doc = RDoc(title: title, blocks: [RTable(sheet: 'Trips', head: head, rows: rows, numCols: const {0, 8})]);
    try {
      await shareXlsx(reportXlsx(doc, [s.printNames.isEmpty ? 'Rachana Construction Limited' : s.printNames.first, s.siteLabel, title]), 'Water tanker ${l.no} ${showDate(l.from)} to ${showDate(l.to)}.xlsx');
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  // =================================================================================================================
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final e = ed, l = lt, c = fig;
    final can = s.canEdit('Log Book');
    final nSel = e?.rows.where((r) => r.sel).length ?? l?.trips.where((t) => t.sel).length ?? 0;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        if (await _discardOk() && context.mounted) {
          _drop();
          setState(() {
            ed = null;
            lt = null;
          });
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: const TwoLang('Edit Log Book', 'लॉग बुक दुरुस्ती', size: 19, weight: FontWeight.w700),
          actions: [
            if (e != null || l != null)
              PopupMenuButton<String>(
                key: const Key('lx-menu'),
                onSelected: (v) async {
                  if (v == 'add') {
                    if (e != null) {
                      _addRow();
                    } else {
                      setState(() => l!.add());
                    }
                  }
                  if (v == 'fill') _fill();
                  if (v == 'all') {
                    final on = nSel == 0;
                    setState(() {
                      if (e != null) {
                        e.selectAll(on);
                        fig = e.calc();
                      } else {
                        for (final t in l!.trips) {
                          t.sel = on && l.lockOf(t.date) == null && can;
                        }
                      }
                    });
                  }
                  if (v == 'del') _delSel();
                  if (v == 'reload' && await _discardOk()) {
                    _drop();
                    setState(() {
                      ed = null;
                      lt = null;
                    });
                    await _open(ask: false);
                  }
                  if (v == 'print') _print();
                  if (v == 'export') _ltExport();
                },
                itemBuilder: (_) => [
                  if (can) PopupMenuItem(key: const Key('lx-add'), value: 'add', child: Text('+ Add row')),
                  if (can && e != null) PopupMenuItem(key: const Key('lx-fill'), value: 'fill', child: Text('Add all missing dates')),
                  PopupMenuItem(key: const Key('lx-selall'), value: 'all', child: Text(nSel == 0 ? 'Select all rows' : 'Clear the ticks')),
                  if (nSel > 0) PopupMenuItem(key: const Key('lx-delsel'), value: 'del', child: Text('Delete selected ($nSel)')),
                  PopupMenuItem(key: const Key('lx-reload'), value: 'reload', child: Text('Undo all (reload)')),
                  if (l != null) PopupMenuItem(key: const Key('lt-export'), value: 'export', child: Text('Export Excel')),
                  PopupMenuItem(key: const Key('lx-print'), value: 'print', child: Text('Print Log Book')),
                ],
              ),
          ],
        ),
        body: ListView.builder(
          key: const Key('lx-list'),
          controller: _list,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
          itemCount: 1 + (e != null ? 2 + e.rows.length : 0) + (l != null ? 2 + l.trips.length : 0),
          itemBuilder: (_, i) {
            if (i == 0) return _filter(s);
            if (e != null && c != null) {
              if (i == 1) return _head(e, c);
              if (i - 2 < e.rows.length) return _rowCard(e, c, i - 2, can);
              return _foot(e, c, can);
            }
            if (l != null) {
              if (i == 1) return _ltHead(l);
              if (i - 2 < l.trips.length) return _ltCard(l, i - 2, can);
              return _ltFoot(l, can);
            }
            return const SizedBox();
          },
        ),
        bottomNavigationBar: e == null && l == null
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
                  child: Row(children: [
                    Expanded(
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (e != null && c != null) ...[
                          Text(c.sum, key: const Key('lx-sum'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25)),
                          if (c.badSay.isNotEmpty) Text(c.badSay, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.red, height: 1.25)),
                        ],
                        if (l != null) Text(l.dirty ? 'Not saved yet' : 'No changes yet', key: const Key('lt-sum'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        if (nSel > 0)
                          TextButton(
                            key: const Key('lx-delsel-b'),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30), foregroundColor: C.red),
                            onPressed: _delSel,
                            child: Text('Delete selected ($nSel)'),
                          ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      key: Key(e != null ? 'lx-save' : 'lt-save'),
                      style: FilledButton.styleFrom(minimumSize: const Size(130, 50)),
                      onPressed: busy || !can ? null : (e != null ? (c?.canSave ?? false ? _save : null) : (l!.dirty ? _ltSave : null)),
                      child: Text(e != null && (c?.total ?? 0) > 0 ? 'Save changes (${c!.total})' : 'Save changes'),
                    ),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _box({required Widget child, Color? color, Color? edge, Key? key}) => Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color ?? Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: edge ?? C.line, width: edge == null ? 1 : 1.6)),
        child: child,
      );

  Widget _filter(Session s) => _box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pick a machinery and dates – all its entries open together', style: const TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 10),
          Press(
            key: const Key('lx-no'),
            radius: 16,
            shadow: false,
            padding: const EdgeInsets.all(12),
            onTap: _pick,
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Machinery *', style: const TextStyle(fontSize: 12, color: C.muted)),
                  Text(no.isEmpty ? 'Type or pick' : no, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: no.isEmpty ? C.faint : C.ink)),
                ]),
              ),
              const Icon(Icons.search_rounded, color: C.muted),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DateField(key: const Key('lx-from'), label: 'From *', value: from, onChanged: (v) => setState(() => from = v))),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('lx-to'), label: 'To *', value: to, onChanged: (v) => setState(() => to = v))),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final q in const [('yday', 'Yesterday'), ('this', 'This month'), ('last', 'Last month')])
              ActionChip(key: Key('lx-q-${q.$1}'), label: Text(q.$2), onPressed: () => _quick(q.$1)),
          ]),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('lx-load'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
            onPressed: busy ? null : () => _open(),
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.folder_open_rounded),
            label: Text(busy ? 'Opening…' : 'Open entries'),
          ),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (ed == null && lt == null) ...[
            const SizedBox(height: 10),
            Text('Change any reading – everything updates live. When you change a Close, the next row\'s Start follows it. Add missing dates or delete rows, then press Save changes. Nothing is saved until then.\n'
                'A Night entry for a date that already has its entry: tick that row and press + Add row; tick ½ for a half night.',
                style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.4)),
          ],
        ]),
      );

  Widget _head(LogEdit e, LxCalc c) => _box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.title, key: const Key('lx-title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(e.info, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
          for (final x in e.lockTexts)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(12)),
              child: Text(x, style: const TextStyle(fontSize: 12.5, color: C.amber, height: 1.35)),
            ),
          const SizedBox(height: 8),
          Text(e.prevText, style: const TextStyle(fontSize: 13, height: 1.35)),
          const SizedBox(height: 6),
          Text('Change a Close – the next row\'s Start follows it. Nothing is saved until Save changes.', style: const TextStyle(fontSize: 12, color: C.muted, height: 1.35)),
          if (e.rows.isEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('No entries in these dates – use "+ Add row" or "Add all missing dates".', style: const TextStyle(color: C.muted))),
        ]),
      );

  Widget _foot(LogEdit e, LxCalc c, bool can) {
    final fmtL = e.mach.lbFormat, noDsl = fmtL == 'F' || fmtL == 'G', onlyIss = fmtL == 'H';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (e.rows.isNotEmpty)
        _box(
          key: const Key('lx-foot'),
          color: C.slateSoft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total – ${c.entries} entries${c.entries != e.rows.length ? ' (${e.rows.length} rows)' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 14, runSpacing: 4, children: [
              if (c.tk != 0) _fig('Work', '${fmtNum(c.tk)} km'),
              if (c.th != 0) _fig('Work', '${fmtNum(c.th)} hr'),
              if (!noDsl) _fig('Issued', fmtNum(c.ti)),
              if (!noDsl && !onlyIss) _fig('Consumed', fmtNum(c.tc)),
              if (!noDsl && !onlyIss) _fig('Closing diesel (est.)', fmtNum(c.closing)),
            ]),
          ]),
        ),
      if (e.nextText.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 10), child: Text(e.nextText, style: const TextStyle(fontSize: 13, height: 1.35))),
      if (can)
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(key: const Key('lx-add-b'), onPressed: _addRow, child: Text('+ Add row')),
          OutlinedButton.icon(key: const Key('lx-fill-b'), onPressed: _fill, icon: const Icon(Icons.playlist_add_rounded), label: Text('Add all missing dates')),
          OutlinedButton.icon(key: const Key('lx-print-b'), onPressed: _print, icon: const Icon(Icons.print_rounded), label: Text('Print Log Book')),
        ])
      else
        OutlinedButton.icon(key: const Key('lx-print-b'), onPressed: _print, icon: const Icon(Icons.print_rounded), label: Text('Print Log Book')),
    ]);
  }

  Widget _fig(String l, String v, {Color tone = C.ink, Key? key}) => Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(l, style: const TextStyle(fontSize: 11.5, color: C.muted)),
        Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tone)),
      ]);

  Widget _note(String t, {Color tone = C.red, Widget? action}) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(color: tone == C.red ? C.redSoft : C.slateSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Text(t, style: TextStyle(fontSize: 13, color: tone, height: 1.35))),
          if (action != null) action,
        ]),
      );

  Widget _numBox(LxRow r, String f, String label, int i, {bool enabled = true, bool bad = false, String hint = ''}) => TextField(
        key: Key('lx-$f-$i'),
        controller: _c(r, f, () => _txt(_val(r, f))),
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onChanged: (v) => _type(r, f, v),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: bad ? C.red : C.ink),
        decoration: InputDecoration(
          labelText: tr(label),
          hintText: hint.isEmpty ? null : hint,
          isDense: true,
          enabledBorder: bad ? OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.red, width: 1.5)) : null,
        ),
      );

  Widget _textBox(LxRow r, String f, String label, int i, {bool enabled = true}) => TextField(
        key: Key('lx-$f-$i'),
        controller: _c(r, f, () => '${r[f] ?? ''}'),
        enabled: enabled,
        onChanged: (v) => _type(r, f, v),
        decoration: InputDecoration(labelText: tr(label), isDense: true),
      );

  Widget _timeBox(LxRow r, String f, String label, int i, bool enabled) => Press(
        key: Key('lxt-$f-$i'),
        radius: 14,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        onTap: enabled ? () => _time(r, f) : null,
        child: Row(children: [
          const Icon(Icons.schedule_rounded, size: 18, color: C.blue),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: C.muted)),
              Text(('${r[f] ?? ''}').isEmpty ? '–' : '${r[f]}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );

  Widget _rowCard(LogEdit e, LxCalc c, int i, bool can) {
    final r = e.rows[i], f = c.figs[i], w = e.way(r), m = e.mach, need = needsOf(m.lbFormat), st = kDayStatus.contains(w);
    final on = can && r.lock == null, later = e.later(r);
    final noDsl = m.lbFormat == 'F' || m.lbFormat == 'G', onlyIss = m.lbFormat == 'H';
    final tone = f.bad ? C.red : r.isNew ? C.green : f.changed ? C.amber : null;
    final bg = r.lock != null ? C.slateSoft : f.bad ? const Color(0xFFFFF8F7) : r.sel ? C.blueSoft : Colors.white;
    final ways = e.waysOf(r);
    return _box(
      key: ValueKey('lxr-$i'),
      color: bg,
      edge: tone,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // the line on top: tick, number, date, tags, delete
        Row(children: [
          SizedBox(
            width: 34,
            height: 34,
            child: Checkbox(key: Key('lxs-$i'), value: r.sel, onChanged: r.lock != null ? null : (v) => setState(() => r.sel = v ?? false)),
          ),
          Text('${i + 1}', style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: r.isNew && on
                ? DateField(
                    key: Key('lxdt-$i'),
                    label: 'Date',
                    value: r.date,
                    clear: false,
                    first: parseKey(e.from),
                    last: parseKey(e.to.compareTo(e.today) < 0 || e.today.isEmpty ? e.to : e.today),
                    onChanged: (v) => _change(r, 'date', v),
                  )
                : Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(showDate(r.date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(weekDays[parseKey(r.date).weekday - 1], style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    if (r.isNew) const Pill('NEW', color: C.greenDark, bg: C.greenChip),
                    if (!r.isNew && f.changed) const Pill('CHANGED', color: C.amber, bg: C.amberSoft),
                    if (r.lock != null) Pill('RA Bill ${r.lock!['billNo']}', color: C.slate, bg: Colors.white),
                  ]),
          ),
          if (r.lock == null && can) IconButton(key: Key('lxd-$i'), tooltip: tr('Delete this row'), onPressed: () => _remove([r], ask: false), icon: const Icon(Icons.close_rounded, color: C.red)),
        ]),
        if (r.isNew && on) const Align(alignment: Alignment.centerLeft, child: Pill('NEW', color: C.greenDark, bg: C.greenChip)),
        const SizedBox(height: 8),
        // shift, ½ day, measured by
        Row(children: [
          Expanded(
            child: PickField(key: Key('lxsh-$i'), label: 'Shift', value: r.shift, items: kLogShifts, enabled: on, onChanged: (v) => _change(r, 'shift', v)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: later
                ? Padding(padding: const EdgeInsets.only(left: 4), child: Text(e.partWord(r), style: const TextStyle(fontSize: 13, color: C.blue, fontWeight: FontWeight.w600)))
                : InkWell(
                    key: Key('lxh-$i'),
                    onTap: on
                        ? () {
                            r.half = !r.half;
                            _re();
                          }
                        : null,
                    child: Row(children: [
                      Checkbox(value: r.half, onChanged: on
                          ? (v) {
                              r.half = v ?? false;
                              _re();
                            }
                          : null),
                      Flexible(child: Text('½ ${r.shift == 'Night' ? 'night' : 'day'}', style: const TextStyle(fontSize: 14))),
                    ]),
                  ),
          ),
        ]),
        const SizedBox(height: 8),
        PickField(key: Key('lxm-$i'), label: 'Measured by', value: w, items: ways, enabled: on, onChanged: (v) => _change(r, 'mode', v)),
        if (f.slotNote.isNotEmpty) _note(f.slotNote),
        // the readings
        if (hasKm(w)) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _numBox(r, 'okm', 'Start KM', i, enabled: on, bad: f.misK)),
            const SizedBox(width: 8),
            Expanded(child: _numBox(r, 'ckm', 'Close KM', i, enabled: on, bad: r.ckm == '' || (f.wk is num && (f.wk as num) < 0))),
          ]),
        ],
        if (hasHr(w)) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _numBox(r, 'ohr', 'Start Hrs', i, enabled: on, bad: f.misH)),
            const SizedBox(width: 8),
            Expanded(child: _numBox(r, 'chr', 'Close Hrs', i, enabled: on, bad: r.chr == '' || (f.wh is num && (f.wh as num) < 0) || f.overNote.isNotEmpty)),
          ]),
        ],
        if (f.note.isNotEmpty)
          _note(f.note,
              action: f.fixable
                  ? TextButton(
                      key: Key('lxfix-$i'),
                      onPressed: () {
                        e.useFix(r);
                        _re();
                      },
                      child: Text('Use it'))
                  : null),
        if (f.gapNote.isNotEmpty) _note(f.gapNote, tone: C.muted),
        if (f.overNote.isNotEmpty) _note(f.overNote),
        // time / trips / day
        if (w == 'Time') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _timeBox(r, 'tStart', 'From', i, on)),
            const SizedBox(width: 8),
            Expanded(child: _timeBox(r, 'tEnd', 'To', i, on)),
            const SizedBox(width: 8),
            SizedBox(width: 92, child: _numBox(r, 'tBrk', 'Break (min)', i, enabled: on)),
          ]),
          if (e.splitText(r).isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('split: ${e.splitText(r)} – changing From, To or Break makes it one From – To (the split itself: Log Book → Edit).', style: const TextStyle(fontSize: 12, color: C.muted, height: 1.3))),
          if (!need.challan) ...[const SizedBox(height: 8), _textBox(r, 'challan', 'Challan No', i, enabled: on)],
        ] else if (w == 'Trip') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _numBox(r, 'trip', 'Trips', i, enabled: on, bad: !(asNum(r.trip) != null && asNum(r.trip)! > 0))),
            if (need.tripTime) ...[const SizedBox(width: 8), Expanded(child: _timeBox(r, 'tStart', 'In time', i, on)), const SizedBox(width: 8), Expanded(child: _timeBox(r, 'tEnd', 'Out time', i, on))],
          ]),
          if (!need.challan) ...[const SizedBox(height: 8), _textBox(r, 'challan', 'Challan No', i, enabled: on)],
        ] else if (m.lbFormat == 'B' && !st) ...[
          const SizedBox(height: 10),
          _numBox(r, 'trip', 'Trips', i, enabled: on),
        ] else if (w == 'Day')
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('worked (Day)', style: const TextStyle(color: C.muted)))
        else if (st)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('$w${w == 'Idle' ? ' – no work' : ' – not paid'}', style: const TextStyle(color: C.amber, fontWeight: FontWeight.w600))),
        // the Item-wise BOQ box
        if (f.box != null && !f.box!.empty) _items(e, r, f.box!, i, on),
        if (e.canMore(r) && can)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(key: Key('lxmore-$i'), onPressed: () => _more(r), icon: const Icon(Icons.add_rounded, size: 18), label: Text('+ work in this shift')),
          ),
        // opening diesel of the month (the 1st)
        if (f.odBox && !noDsl && !onlyIss) ...[
          const SizedBox(height: 10),
          _numBox(r, 'odSet', 'Opening diesel of the month (blank = worked out)', i, enabled: on, hint: fmtNum(f.open)),
        ],
        // challan, particular, chainage, work
        if (need.challan && !st && w != 'Day') ...[const SizedBox(height: 10), _textBox(r, 'challan', 'Challan No', i, enabled: on)],
        if (need.part && !st) ...[const SizedBox(height: 10), _textBox(r, 'remark', 'Particular', i, enabled: on)],
        if (!need.noCh) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _textBox(r, 'chFrom', 'Chainage From', i, enabled: on)),
            const SizedBox(width: 8),
            Expanded(child: _textBox(r, 'chTo', 'To', i, enabled: on)),
          ]),
        ],
        const SizedBox(height: 10),
        _textBox(r, 'work', 'Work description', i, enabled: on),
        // the figures
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
          child: Wrap(spacing: 14, runSpacing: 6, children: [
            _fig('Total', f.total.replaceAll('\n', ' · '), key: Key('lxtot-$i')),
            if (!noDsl && !onlyIss) _fig('Opening', fmtNum(f.open)),
            if (!noDsl) _fig('Issued', fmtNum(f.iss)),
            if (!noDsl && !onlyIss) _fig('Consumed', fmtNum(f.need)),
            if (!noDsl && !onlyIss) _fig('Closing (est.)', fmtNum(f.close), tone: f.overCap ? C.red : C.ink, key: Key('lxcl-$i')),
          ]),
        ),
        if (f.overCap) Padding(padding: const EdgeInsets.only(top: 4), child: Text('more than the ${fmtNum(asNum(m.m['tankCap']) ?? 0)} L tank', style: const TextStyle(fontSize: 12, color: C.red))),
      ]),
    );
  }

  Widget _items(LogEdit e, LxRow r, LxBox b, int i, bool on) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: b.bad.isNotEmpty ? C.redSoft : C.blueSoft, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Items (BOQ)', style: const TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600)),
          for (final k in b.kinds) ...[
            if (k.group) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('Work:', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                for (final n in [...k.names, '_split'])
                  ChoiceChip(
                    key: Key('lxi-$i-${k.k}-$n'),
                    label: Text(n == '_split' ? 'Split' : n),
                    selected: k.pick == n,
                    onSelected: on
                        ? (_) {
                            e.pressWork(r, k.k, n);
                            _re();
                          }
                        : null,
                  ),
                if (k.say.isNotEmpty) Text(k.say, style: TextStyle(fontWeight: FontWeight.w700, color: k.need ? C.red : C.greenDark)),
              ]),
            ],
            if (!k.group || k.pick == '_split')
              for (final n in k.inputs)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    key: Key('lxit-$i-$n'),
                    controller: _c(r, 'it:$n', () => _txt(r.items[n])),
                    enabled: on,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (v) => _type(r, 'it:$n', v),
                    decoration: InputDecoration(labelText: n, hintText: kItemWords[k.k], isDense: true, fillColor: Colors.white),
                  ),
                ),
            if (k.restSay.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(k.restSay, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: k.restBad ? C.red : C.ink))),
          ],
          if (b.days.isNotEmpty) ...[
            const SizedBox(height: 8),
            PickField(key: Key('lxday-$i'), label: 'Day item', value: b.day, items: b.days, enabled: on, onChanged: (v) {
              e.typeItem(r, '_day', v);
              _re();
            }),
          ],
          if (b.bad.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(b.bad, style: const TextStyle(fontSize: 12.5, color: C.red, height: 1.3))),
        ]),
      );

  // ---------- a water tanker: one card a trip ----------
  Widget _ltHead(LtEdit l) => _box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${l.no}${'${l.machine['type'] ?? ''}'.isNotEmpty ? ' – ${l.machine['type']}' : ''}', key: const Key('lt-title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(l.info, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
          for (final x in l.lockTexts)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(12)),
              child: Text(x, style: const TextStyle(fontSize: 12.5, color: C.amber, height: 1.35)),
            ),
          const SizedBox(height: 6),
          Text('One card a trip. + Add row = one more trip (the date and shift of the row above). Save sends all the trips of these dates.', style: const TextStyle(fontSize: 12, color: C.muted, height: 1.35)),
        ]),
      );

  TextEditingController _ltc(LtTrip t, String f) => _c(t, f, () => switch (f) { 'c' => t.c, 'ch' => t.ch, _ => t.u });

  Widget _ltCard(LtEdit l, int i, bool can) {
    final t = l.trips[i], lock = l.lockOf(t.date), on = can && lock == null;
    final shifts = t.shift == 'Full Day' ? const ['Full Day', 'Day', 'Night'] : const ['Day', 'Night'];
    return _box(
      key: ValueKey('ltr-$i'),
      color: lock != null ? C.slateSoft : t.sel ? C.blueSoft : Colors.white,
      edge: t.orig.isEmpty && !t.blank ? C.green : t.changed ? C.amber : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(width: 34, height: 34, child: Checkbox(key: Key('lt-sel-$i'), value: t.sel, onChanged: on ? (v) => setState(() => t.sel = v ?? false) : null)),
          Text('${i + 1}', style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: DateField(
              key: Key('lt-date-$i'),
              label: 'Date *',
              value: t.date,
              clear: false,
              enabled: on,
              first: parseKey(l.from),
              last: parseKey(l.top),
              onChanged: (v) => setState(() => t.date = v),
            ),
          ),
          if (on) IconButton(key: Key('lt-del-$i'), tooltip: tr('Take out this row'), onPressed: () => setState(() => l.remove([t])), icon: const Icon(Icons.close_rounded, color: C.red)),
        ]),
        if (t.old == 1) Padding(padding: const EdgeInsets.only(top: 4), child: Text('entered before trip by trip', style: const TextStyle(fontSize: 12, color: C.muted))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: PickField(key: Key('lt-shift-$i'), label: 'Shift *', value: t.shift, items: shifts, enabled: on, onChanged: (v) => setState(() => t.shift = v))),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(key: Key('lt-c-$i'), controller: _ltc(t, 'c'), enabled: on, maxLength: 40, onChanged: (v) => setState(() => t.c = v.trim()), decoration: InputDecoration(labelText: tr('Challan No *'), isDense: true, counterText: '')),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _ltTimeBox(t, true, i, on)),
          const SizedBox(width: 8),
          Expanded(child: _ltTimeBox(t, false, i, on)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(key: Key('lt-ch-$i'), controller: _ltc(t, 'ch'), enabled: on, maxLength: 60, onChanged: (v) => setState(() => t.ch = v), decoration: InputDecoration(labelText: tr('Chainage No'), hintText: 'e.g. 12+500', isDense: true, counterText: ''))),
          const SizedBox(width: 8),
          Expanded(child: TextField(key: Key('lt-u-$i'), controller: _ltc(t, 'u'), enabled: on, maxLength: 80, onChanged: (v) => setState(() => t.u = v), decoration: InputDecoration(labelText: tr('Use For'), hintText: tr('e.g. Curing'), isDense: true, counterText: ''))),
        ]),
      ]),
    );
  }

  Widget _ltTimeBox(LtTrip t, bool first, int i, bool on) => Press(
        key: Key('lt-${first ? 'a' : 'b'}-$i'),
        radius: 14,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        onTap: on ? () => _ltTime(t, first) : null,
        child: Row(children: [
          const Icon(Icons.schedule_rounded, size: 18, color: C.blue),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(first ? 'Dispatch Time *' : 'Unload Time *', style: const TextStyle(fontSize: 11.5, color: C.muted)),
              Text((first ? t.a : t.b).isEmpty ? '–' : (first ? t.a : t.b), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );

  Widget _ltFoot(LtEdit l, bool can) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (ltErr.isNotEmpty) InfoLine(ltErr, bad: true),
        _box(
          key: const Key('lt-tot'),
          color: C.slateSoft,
          child: Wrap(spacing: 18, runSpacing: 4, children: [
            _fig('Day trips', '${l.real.length - l.nightTrips}'),
            _fig('Night trips', '${l.nightTrips}'),
            _fig('Total trips', '${l.real.length}'),
          ]),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (can) OutlinedButton(key: const Key('lt-add'), onPressed: () => setState(() => l.add()), child: Text('+ Add row')),
          OutlinedButton.icon(key: const Key('lt-export-b'), onPressed: _ltExport, icon: const Icon(Icons.table_view_rounded), label: Text('Export Excel')),
          OutlinedButton.icon(key: const Key('lx-print-b'), onPressed: _print, icon: const Icon(Icons.print_rounded), label: Text('Print Log Book')),
        ]),
      ]);
}

