/* DELETE ENTRIES – SUPER ADMIN (3.25.0, Mechanical update-134, asked 19-10-2026: "super admin user ni kelelI konti hi entry mg ti
 * save aso approval madhe aso ki retuen aso ki reject aso konti hi entry delet kru shakel jas ki koni diesel issue kel aasel super admin
 * ti entry delet kru shakel single date or ya period wise"; his choices: Diesel Issue first, an entry in a submitted bill is not
 * deleted, a deleted entry can be brought back, picked from a list with ticks) – the web's Diesel Issue → "Delete entries – Super
 * Admin" as the app's own screen (Diesel Issue ⋮ → Delete entries – Super Admin, for the Super Admin only):
 *   – a date (or From – To), who entered it, a machinery → "Show entries";
 *   – Saved entries and the ones waiting for verification / returned / rejected, each with a tick (one of a submitted bill or a
 *     closed month cannot be ticked, it says why) → "Delete ticked" (all together or none – every refusal said);
 *   – Deleted entries (kept whole) → "Bring back ticked" (the same entry, checked again).
 * Server: superDelList, superDelete, superRestore (the same actions and checks as the web's). */
import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

List<Map<String, dynamic>> _maps(dynamic l) => [for (final x in (l as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];

class SuperDeleteScreen extends StatefulWidget {
  const SuperDeleteScreen({super.key});
  @override
  State<SuperDeleteScreen> createState() => _SuperDeleteScreenState();
}

class _SuperDeleteScreenState extends State<SuperDeleteScreen> {
  String from = '', to = '', by = '', err = '';
  final no = TextEditingController();
  bool busy = false;
  Map<String, dynamic>? d;
  final ticked = <String>{}, tickedF = <String>{}, tickedD = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (from.isEmpty) {
      final s = SessionScope.read(context);
      from = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    }
  }

  @override
  void dispose() {
    no.dispose();
    super.dispose();
  }

  Session get _s => SessionScope.read(context);

  Future<void> _show() async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final r = (await _s.api.call('superDelList', [{'from': from, 'to': to, 'by': by, 'no': no.text.trim()}]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        d = r;
        if (!((r['users'] as List?) ?? const []).contains(by)) by = '';
        ticked.clear();
        tickedF.clear();
        tickedD.clear();
      });
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _n(int n) => n == 1 ? '1 entry' : '$n entries';

  Future<void> _delete() async {
    final n = ticked.length + tickedF.length;
    if (n == 0) return;
    final ok = await ask(context, 'Delete ${n == 1 ? '1 entry' : '$n entries'}?',
        '${[...ticked, ...tickedF].join(', ')}\n\nThey go out of the stock, the Log Book and the lists. Each one is kept whole in "Deleted entries" – it can be brought back.',
        yes: 'Delete', danger: true);
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      final r = (await _s.api.call('superDelete', [{'ids': ticked.toList(), 'flows': tickedF.toList()}]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (r['ok'] != true) {
        setState(() => busy = false);
        await tellLines(context, 'Nothing deleted', [for (final e in (r['errors'] as List? ?? const [])) '$e']);
        return;
      }
      if (r['stock'] != null) _s.setStock(r['stock']);
      toast(context, '${_n((r['deleted'] as num?)?.toInt() ?? n)} deleted – kept in Deleted entries (${_maps(r['kept']).map((k) => k['del']).join(', ')}).');
      await _show();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _back() async {
    final n = tickedD.length;
    if (n == 0) return;
    final ok = await ask(context, 'Bring back ${n == 1 ? '1 entry' : '$n entries'}?',
        '${tickedD.join(', ')}\n\nEach comes back as it was – a saved entry with its ID (checked again: the month open, not in a submitted bill, the diesel in stock on its date); a request waits, is returned or rejected as before.',
        yes: 'Bring back');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      final r = (await _s.api.call('superRestore', [{'ids': tickedD.toList()}]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (r['ok'] != true) {
        setState(() => busy = false);
        await tellLines(context, 'Nothing brought back', [for (final e in (r['errors'] as List? ?? const [])) '$e']);
        return;
      }
      if (r['stock'] != null) _s.setStock(r['stock']);
      toast(context, '${_n((r['restored'] as num?)?.toInt() ?? n)} brought back: ${((r['ids'] as List?) ?? const []).join(', ')}.');
      await _show();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _head(String en, int n, Set<String> set, List<String> all) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 0, 6),
        child: Row(children: [
          Expanded(child: Text('$en ($n)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          if (all.isNotEmpty)
            TextButton(
              key: Key('sd-all-$en'),
              onPressed: busy ? null : () => setState(() => set.length == all.length ? set.clear() : set.addAll(all)),
              child: Text(set.length == all.length ? 'Untick all' : 'Tick all'),
            ),
        ]),
      );

  Widget _tick(String key, String id, Set<String> set, String title, List<String> lines, {String why = ''}) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: CheckboxListTile(
          key: Key(key),
          value: set.contains(id),
          onChanged: why.isNotEmpty || busy ? null : (v) => setState(() => v == true ? set.add(id) : set.remove(id)),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: C.red,
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final l in lines.where((l) => l.isNotEmpty)) Text(l, style: const TextStyle(fontSize: 13.5, color: C.muted, height: 1.35)),
            if (why.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(why, style: const TextStyle(fontSize: 13, color: C.red, fontWeight: FontWeight.w600))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final saved = _maps(d?['saved']), waiting = _maps(d?['waiting']), deleted = _maps(d?['deleted']);
    final users = [for (final u in (d?['users'] as List? ?? const [])) '$u'];
    String dates(dynamic l) => [for (final x in (l as List? ?? const [])) showDate('$x')].join(', ');
    String qty(dynamic q) => '$q'.isEmpty ? '' : '${fmtNum(asNum(q))} L';
    final canTick = [for (final r in saved) if ('${r['bill'] ?? ''}'.isEmpty && r['closed'] != true) '${r['id']}'];
    final n = ticked.length + tickedF.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete entries – Super Admin')),
      body: !s.superAdmin
          ? const EmptyState('Only the Super Admin', 'Only the Super Admin deletes entries here or brings them back.', pic: 'locked_with_key')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), children: [
              const Text('Any Diesel Issue entry – saved, waiting for verification, returned or rejected – of one date or a period: tick and delete. An entry in a submitted RA Bill or of a closed month is not deleted. Deleted entries are kept below and can be brought back.',
                  style: TextStyle(fontSize: 14, color: C.muted, height: 1.35)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: DateField(key: const Key('sd-from'), label: 'Date / From', value: from, clear: false, onChanged: (v) => setState(() => from = v))),
                const SizedBox(width: 10),
                Expanded(child: DateField(key: const Key('sd-to'), label: 'To (blank = the same day)', value: to, onChanged: (v) => setState(() => to = v))),
              ]),
              const SizedBox(height: 10),
              PickField(key: const Key('sd-by'), label: 'Entered by', value: by, items: users, blank: 'Everyone', onChanged: (v) => setState(() => by = v)),
              const SizedBox(height: 10),
              TextBox(key: const Key('sd-no'), label: 'Machinery Number', controller: no, upper: true, hint: 'all'),
              const SizedBox(height: 12),
              FilledButton.icon(key: const Key('sd-show'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: busy ? null : _show, icon: const Icon(Icons.search_rounded), label: const Text('Show entries')),
              if (err.isNotEmpty) InfoLine(err, bad: true),
              if (d != null) ...[
                _head('Saved entries', saved.length, ticked, canTick),
                if (saved.isEmpty) const Text('No saved Diesel Issue entry for these dates.', style: TextStyle(color: C.muted)),
                for (final r in saved)
                  _tick('sd-s-${r['id']}', '${r['id']}', ticked, '${r['id']} · ${r['no']} · ${qty(r['qty'])}', [
                    '${showDate('${r['date']}')}, ${r['shift']} · ${r['source']}',
                    [if ('${r['kmReading']}'.isNotEmpty) 'KM ${fmtNum(asNum(r['kmReading']))}', if ('${r['hrReading']}'.isNotEmpty) 'Hrs ${fmtNum(asNum(r['hrReading']))}'].join(' · '),
                    if ('${r['by'] ?? ''}'.isNotEmpty) 'Entered by ${r['by']}',
                  ], why: '${r['bill'] ?? ''}'.isNotEmpty ? 'In the submitted RA Bill ${r['bill']} – delete that bill first' : r['closed'] == true ? 'Month closed' : ''),
                _head('Waiting for verification, returned or rejected', waiting.length, tickedF, [for (final r in waiting) '${r['id']}']),
                if (waiting.isEmpty) const Text('None for these dates.', style: TextStyle(color: C.muted)),
                for (final r in waiting)
                  _tick('sd-f-${r['id']}', '${r['id']}', tickedF, '${r['id']} · ${r['label']}', [
                    '${dates(r['dates'])} · ${r['nos']}${'${r['qty']}'.isEmpty ? '' : ' · ${qty(r['qty'])}'}',
                    'Sent by ${r['by']} · ${r['what']}',
                    ...[for (final l in (r['lines'] as List? ?? const [])) '$l'],
                    if ((asNum(r['more']) ?? 0) > 0) '+${r['more']} more',
                  ]),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('sd-delete'),
                  style: FilledButton.styleFrom(backgroundColor: C.red, minimumSize: const Size.fromHeight(50)),
                  onPressed: busy || n == 0 ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(n == 0 ? 'Delete ticked' : 'Delete ticked ($n)'),
                ),
                _head('Deleted entries', deleted.length, tickedD, [for (final r in deleted) '${r['id']}']),
                if (deleted.isEmpty) const Text('No deleted entry of these dates.', style: TextStyle(color: C.muted)),
                for (final r in deleted)
                  _tick('sd-d-${r['id']}', '${r['id']}', tickedD, '${r['entry']} · ${r['was']}', [
                    'Kept as ${r['id']} · ${dates(r['dates'])} · ${r['nos']}${'${r['qty']}'.isEmpty ? '' : ' · ${qty(r['qty'])}'}',
                    if ('${r['by'] ?? ''}'.isNotEmpty) 'Entered by ${r['by']}',
                    'Deleted by ${r['deletedBy']} · ${whenText('${r['deletedAt'] ?? ''}')}',
                    ...[for (final l in (r['lines'] as List? ?? const [])) '$l'],
                  ]),
                if (deleted.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const Key('sd-back'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: busy || tickedD.isEmpty ? null : _back,
                    icon: const Icon(Icons.restore_rounded),
                    label: Text(tickedD.isEmpty ? 'Bring back ticked' : 'Bring back ticked (${tickedD.length})'),
                  ),
                ],
              ],
            ]),
    );
  }
}
