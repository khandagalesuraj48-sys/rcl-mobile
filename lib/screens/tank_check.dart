/* TANK CHECK – the app's own screen (3.5.0), the web's "Tank check – system vs physical": the system keeps each machinery's tank
 * as per the Standard Average; the real tank is checked and recorded here. The date and machinery bring what the system says
 * (from the last check or Log Book, the diesel given after it, the tank size); "measured the diesel in the tank" or "filled the
 * tank to full" (the litres it took); the difference (more than 10% – ask why); Save (from the end of this day the system tank
 * starts again from what was found). The checks (dates, machinery), each with its difference; Delete.
 * Server: getTankSystem, saveTankCheck (saved once), getTankChecks, deleteTankCheck. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart' show MachinePicker;
import '../ui/help.dart' show GuideButton;

Future<void> openTankCheck(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TankCheckScreen()));

num r2t(num v) => (v * 100).round() / 100;

/// What was found: measured, or the tank size less the litres it took to fill ('' = not yet).
num? tankFound(String method, num? cap, String phys, String fill) {
  if (method == 'full') {
    final f = num.tryParse(fill.trim());
    return (cap ?? 0) > 0 && f != null ? r2t(cap! - f) : null;
  }
  return num.tryParse(phys.trim());
}

/// The difference and its words (as the web's tcCalc): (difference, note, big).
(num, String, bool) tankDiff(num found, num system) {
  final d = r2t(found - system), big = d.abs() > [5, system.abs() * .1].reduce((a, b) => a > b ? a : b);
  final note = d == 0
      ? 'Matches the system'
      : '${d < 0 ? 'Less than the system' : 'More than the system'}${system != 0 ? ' (${d > 0 ? '+' : ''}${fmtNum(r2t(d / system * 100))}%)' : ''}${big ? ' – ask why' : ' – within 10%'}';
  return (d, note, big);
}

class TankCheckScreen extends StatefulWidget {
  const TankCheckScreen({super.key, this.no = '', this.date = ''});

  /// (3.14.0) opened by the search: the list of this machinery on this date (the web's gsOpenTank)
  final String no, date;
  @override
  State<TankCheckScreen> createState() => _TankCheckScreenState();
}

class _TankCheckScreenState extends State<TankCheckScreen> {
  String date = '', no = '', method = 'measure';
  final phys = TextEditingController(), fill = TextEditingController(), reason = TextEditingController(), by = TextEditingController();
  Map<String, dynamic>? sys;
  bool busy = false;
  // the list
  String fFrom = '', fTo = '', fNo = '';
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = SessionScope.read(context);
      setState(() {
        date = s.today;
        by.text = s.name;
        if (widget.no.isNotEmpty) fNo = widget.no;
        if (widget.date.isNotEmpty) fFrom = fTo = widget.date;
      });
      _list();
    });
  }

  @override
  void dispose() {
    for (final c in [phys, fill, reason, by]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _system() async {
    final s = SessionScope.read(context);
    setState(() => sys = null);
    if (no.isEmpty || date.isEmpty) return;
    try {
      final r = (await s.api.call('getTankSystem', [no, date]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        sys = r;
        if (!((asNum(r['cap']) ?? 0) > 0) && method == 'full') method = 'measure';
      });
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  Future<void> _list() async {
    final s = SessionScope.read(context), seq = ++_seq;
    try {
      final r = (await s.api.call('getTankChecks', [{'from': fFrom, 'to': fTo, 'no': fNo}]) as Map).cast<String, dynamic>();
      if (!mounted || seq != _seq) return; // (a newer filter is loading: an older answer is not shown – as the web)
      setState(() {
        rows = [for (final x in (r['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      toast(context, tr(errText(e)), bad: true);
    }
  }

  void _clear() {
    final s = SessionScope.read(context);
    setState(() {
      no = '';
      date = s.today;
      sys = null;
      for (final c in [phys, fill, reason]) {
        c.clear();
      }
      by.text = s.name;
    });
  }

  Future<void> _pick() async {
    final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => MachinePicker(date: date));
    if (m == null || !mounted) return;
    setState(() => no = m.id);
    _system();
  }

  Future<void> _save() async {
    final s = SessionScope.read(context), x = sys;
    if (x == null) {
      toast(context, 'Pick the date and machinery first.', bad: true);
      return;
    }
    final f = tankFound(method, asNum(x['cap']), phys.text, fill.text);
    if (f == null) {
      toast(context, method == 'full' ? 'Enter the litres it took to fill.' : 'Enter the diesel found in the tank.', bad: true);
      return;
    }
    final d = r2t(f - (asNum(x['system']) ?? 0));
    if (!await askLines(context, 'Save tank check?', ['${(x['machine'] as Map?)?['id'] ?? no} on ${showDate(date)}', 'System: ${fmtNum(asNum(x['system']))} L', 'Found: ${fmtNum(f)} L', 'Difference: ${d > 0 ? '+' : ''}${fmtNum(d)} L'],
        note: 'From the end of this day the system tank of this machinery starts again from ${fmtNum(f)} L.', yes: 'Save')) {
      return;
    }
    setState(() => busy = true);
    try {
      await s.api.call('saveTankCheck', [
        {'date': date, 'no': (x['machine'] as Map?)?['id'] ?? no, 'method': method, 'physical': num.tryParse(phys.text.trim()) ?? '', 'toFill': num.tryParse(fill.text.trim()) ?? '', 'reason': reason.text.trim(), 'by': by.text.trim()}
      ], true);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      toast(context, 'Tank check saved.');
      _clear();
      _list();
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final s = SessionScope.read(context);
    if (!await ask(context, 'Delete tank check ${r['id']}?', 'The system tank of this machinery will be worked out again without this check.', yes: 'Delete', danger: true)) return;
    try {
      await s.api.call('deleteTankCheck', ['${r['id']}'], true);
      if (!mounted) return;
      toast(context, 'Tank check deleted.');
      _list();
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final can = s.canEdit('Log Book');
    final x = sys;
    final cap = asNum(x?['cap']) ?? 0;
    final f = x == null ? null : tankFound(method, cap, phys.text, fill.text);
    final diff = x == null || f == null ? null : tankDiff(f, asNum(x['system']) ?? 0);
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Tank Check', 'टँक तपासणी', size: 20, weight: FontWeight.w700), actions: [const GuideButton('tankcheck')]),
      body: RefreshIndicator(
        onRefresh: _list,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('The system keeps each machinery\'s tank as per the Standard Average. Check the real tank and record it here.', style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
          const SizedBox(height: 10),
          if (!can)
            InfoLine('View only – you can see the checks, but cannot add or delete them.', icon: Icons.visibility_outlined)
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: DateField(key: const Key('tc-date'), label: 'Date *', value: date, clear: false, last: s.today.isEmpty ? null : parseKey(s.today), onChanged: (v) {
                    setState(() => date = v);
                    _system();
                  })),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Press(
                      key: const Key('tc-no'),
                      radius: 16,
                      shadow: false,
                      padding: const EdgeInsets.all(12),
                      onTap: _pick,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Machinery *', style: const TextStyle(fontSize: 12, color: C.muted)),
                        Text(no.isEmpty ? 'Type or pick' : no, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: no.isEmpty ? C.faint : C.ink)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                PickField(
                  key: const Key('tc-method'),
                  label: 'How was it checked? *',
                  value: method == 'full' ? 'Filled the tank to full' : 'Measured the diesel in the tank',
                  items: [ 'Measured the diesel in the tank', if (x == null || cap > 0) 'Filled the tank to full'],
                  onChanged: (v) => setState(() => method = v == 'Filled the tank to full' ? 'full' : 'measure'),
                ),
                const SizedBox(height: 10),
                if (method == 'full')
                  TextBox(key: const Key('tc-fill'), label: 'Litres it took to fill to full *', controller: fill, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))
                else
                  TextBox(key: const Key('tc-phys'), label: 'Diesel found in the tank (Ltr) *', controller: phys, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                const SizedBox(height: 10),
                TextBox(key: const Key('tc-by'), label: 'Checked by', controller: by),
                const SizedBox(height: 10),
                TextBox(key: const Key('tc-reason'), label: 'Reason for the difference', controller: reason, hint: 'Needed when the difference is more than 10%'),
                if (x != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('tc-cmp'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: diff == null ? C.slateSoft : diff.$3 ? C.redSoft : C.greenSoft, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _cmp('System says (as per standard)', '${fmtNum(asNum(x['system']))} Ltr', [
                        if (x['fromCheck'] is Map) 'from the check of ${showDate('${(x['fromCheck'] as Map)['date']}')} (${fmtNum(asNum((x['fromCheck'] as Map)['physical']))} L)' else if (x['fromLog'] is Map) 'Log Book ${showDate('${(x['fromLog'] as Map)['date']}')} (${(x['fromLog'] as Map)['shift']})' else 'no Log Book yet',
                        if ((asNum(x['addedAfter']) ?? 0) != 0) '+ ${fmtNum(asNum(x['addedAfter']))} L given after that',
                        if (cap > 0) 'tank ${fmtNum(cap)} L',
                      ].join(' · '), over: cap > 0 && (asNum(x['system']) ?? 0) > cap),
                      const SizedBox(height: 8),
                      _cmp('Found in the tank', f == null ? '–' : '${fmtNum(f)} Ltr', method == 'full' && f != null ? '${fmtNum(cap)} L tank − ${fmtNum(num.tryParse(fill.text.trim()))} L to fill' : ''),
                      const SizedBox(height: 8),
                      _cmp('Difference', diff == null ? '–' : '${diff.$1 > 0 ? '+' : ''}${fmtNum(diff.$1)} Ltr', diff?.$2 ?? '', bad: diff?.$3 ?? false),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton(key: const Key('tc-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save tank check')),
                const SizedBox(height: 6),
                OutlinedButton(onPressed: _clear, child: Text('Clear')),
              ]),
            ),
          FormHead('Tank checks'),
          Row(children: [
            Expanded(child: DateField(label: 'From', value: fFrom, onChanged: (v) {
              setState(() => fFrom = v);
              _list();
            })),
            const SizedBox(width: 8),
            Expanded(child: DateField(label: 'To', value: fTo, onChanged: (v) {
              setState(() => fTo = v);
              _list();
            })),
          ]),
          const SizedBox(height: 8),
          Press(
            radius: 16,
            shadow: false,
            padding: const EdgeInsets.all(12),
            onTap: () async {
              final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => MachinePicker(only: s.machines));
              if (m != null && mounted) {
                setState(() => fNo = m.id);
                _list();
              }
            },
            child: Row(children: [
              Expanded(child: Text(fNo.isEmpty ? 'Machinery: All' : 'Machinery: $fNo', style: const TextStyle(fontWeight: FontWeight.w700))),
              if (fNo.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => fNo = '');
                    _list();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          if (loading)
            const Shimmer(height: 90)
          else if (rows.isEmpty)
            EmptyState('No tank checks yet.', '', pic: 'oil_drum')
          else
            for (final r in rows)
              (() {
                final dv = asNum(r['diff']) ?? 0, sv = asNum(r['system']) ?? 0;
                final big = dv.abs() > [5, sv.abs() * .1].reduce((a, b) => a > b ? a : b);
                return Container(
                  key: Key('tcr-${r['id']}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: big ? C.red.withValues(alpha: .4) : C.line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text('${r['no']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                      Text(showDate('${r['date']}'), style: const TextStyle(color: C.muted, fontSize: 12.5)),
                    ]),
                    Text('${r['id']} · ${r['method']}${'${r['toFill'] ?? ''}'.isNotEmpty ? ' (${fmtNum(asNum(r['toFill']))} L)' : ''}', style: const TextStyle(fontSize: 12, color: C.faint)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      Pill('System ${fmtNum(sv)} L', color: C.slate, bg: C.slateSoft),
                      Pill('Found ${fmtNum(asNum(r['physical']))} L', color: C.blue, bg: C.blueSoft),
                      Pill('${dv > 0 ? '+' : ''}${fmtNum(dv)} L${'${r['pct'] ?? ''}'.isEmpty ? '' : ' (${(asNum(r['pct']) ?? 0) > 0 ? '+' : ''}${fmtNum(asNum(r['pct']))}%)'}', color: big ? C.red : C.greenDark, bg: big ? C.redSoft : C.greenSoft),
                    ]),
                    if ('${r['reason'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Reason: ${r['reason']}', style: const TextStyle(fontSize: 13))),
                    Text(['Checked by ${r['by'] ?? ''}', if ('${r['enteredBy'] ?? ''}'.isNotEmpty) 'entered by ${r['enteredBy']}'].join(' · '), style: const TextStyle(fontSize: 12, color: C.muted)),
                    if (can)
                      Align(alignment: Alignment.centerRight, child: TextButton(key: Key('tcd-${r['id']}'), style: TextButton.styleFrom(foregroundColor: C.red), onPressed: () => _delete(r), child: Text('Delete'))),
                  ]),
                );
              })(),
        ])),
      ),
    );
  }

  Widget _cmp(String label, String value, String note, {bool over = false, bool bad = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: over || bad ? C.red : C.ink)),
        if (note.isNotEmpty) Text(note, style: const TextStyle(fontSize: 12, color: C.muted)),
      ]);
}
