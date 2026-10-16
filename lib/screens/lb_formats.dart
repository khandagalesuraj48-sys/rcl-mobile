/* LOG BOOK FORMAT – the app's own screen (3.4.0), the same as the web's page: the Log Book of a machinery prints in the format
 * set here (A … I). The formats with their names (a name can be changed) and how many machinery have each; the machinery
 * (search, ownership, owner, type, format) each with its format; tick several and "Set selected to …"; Save sends the changes.
 * "View format" (3.6.0): that format printed with SAMPLE lines (the Log Book print of the app).
 * Server: getLbFormatNames, saveLbFormatName, saveLbFormats. */
import 'package:flutter/material.dart' hide Text;

import '../core/assets.dart' show worksOf;
import '../core/format.dart' show dateKey;
import '../core/masters.dart';
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../core/lb_print.dart' show lbSampleRows;
import 'log_print.dart';
import 'machinery.dart' show uniqOf;
import '../ui/help.dart' show GuideButton;

Future<void> openLbFormats(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LbFormatScreen()));

class LbFormatScreen extends StatefulWidget {
  const LbFormatScreen({super.key});
  @override
  State<LbFormatScreen> createState() => _LbFormatScreenState();
}

class _LbFormatScreenState extends State<LbFormatScreen> {
  Map<String, dynamic> names = {};
  final ch = <String, String>{}, sel = <String>{};
  String q = '', own = '', owner = '', type = '', fmt = '', setTo = 'A';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final r = await SessionScope.read(context).api.call('getLbFormatNames');
        if (mounted && r is Map) setState(() => names = r.cast<String, dynamic>());
      } catch (_) {/* the default names */}
    });
  }

  String _of(Machine m) => ch[m.id] ?? m.lbFormat;
  LbFormat _f(String id) => kLbFormats.firstWhere((f) => f.id == id, orElse: () => kLbFormats.first);

  void _set(Machine m, String f) {
    if (m.lbFormat == f) {
      ch.remove(m.id);
    } else {
      ch[m.id] = f;
    }
  }

  List<Machine> _list(Session s) {
    final qq = q.trim().toUpperCase(), ow = owner.trim().toUpperCase(), ty = type.trim().toUpperCase();
    return s.machines
        .where((m) =>
            (qq.isEmpty || '${m.id} ${m.name} ${m.owner} ${m.type}'.toUpperCase().contains(qq)) &&
            (own.isEmpty || m.ownership == own) &&
            (ow.isEmpty || m.owner.toUpperCase() == ow) &&
            (ty.isEmpty || m.type.toUpperCase() == ty) &&
            (fmt.isEmpty || _of(m) == fmt))
        .toList()
      ..sort((a, b) {
        final o = a.owner.compareTo(b.owner);
        return o != 0 ? o : a.id.compareTo(b.id);
      });
  }

  Future<void> _rename(LbFormat f) async {
    final s = SessionScope.read(context);
    final c = TextEditingController(text: lbName(f, names));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text('Name of Format ${f.id}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Leave blank to go back to the default name (${f.name}).', style: const TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(key: const Key('lbf-name'), controller: c, maxLength: 80),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Cancel')),
          FilledButton(key: const Key('lbf-name-ok'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(dc, true), child: Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final r = (await s.api.call('saveLbFormatName', [{'id': f.id, 'name': c.text}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => names = ((r['names'] as Map?) ?? names).cast<String, dynamic>());
      toast(context, 'Format ${f.id} name saved.');
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    if (ch.isEmpty) return;
    setState(() => busy = true);
    try {
      final r = (await s.api.call('saveLbFormats', [Map<String, String>.from(ch)], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (r['master'] != null) s.setMaster(r['master']);
      setState(() {
        ch.clear();
        sel.clear();
      });
      toast(context, 'Log Book format saved for ${r['count']} machinery.');
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// "View format": that format with SAMPLE lines (asks the name on top like every print).
  Future<void> _view(LbFormat f) {
    final s = SessionScope.read(context), today = s.today.isNotEmpty ? s.today : dateKey(DateTime.now()), d0 = today.substring(0, 8);
    return printLogBook(context, s, rows: lbSampleRows(f.id, today), from: '${d0}01', to: '${d0}06', fmt: f.id, sample: lbName(f, names));
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final can = s.canEdit('Master');
    final list = _list(s);
    final fmts = [for (final f in kLbFormats) f.id];
    String label(String id) => lbName(_f(id), names);
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Log Book Format', 'लॉगबुक फॉरमॅट', size: 20, weight: FontWeight.w700), actions: [const GuideButton('lbf')]),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('The Log Book of a machinery prints in the format set here. The top (Rachana / Sketchline, site, owner, machinery) is the same in every format.', style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
        const SizedBox(height: 10),
        SizedBox(
          height: 178,
          child: ListView(key: const Key('lbf-strip'), scrollDirection: Axis.horizontal, children: [
            for (final f in kLbFormats)
              Container(
                key: Key('lbf-${f.id}'),
                width: 230,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lbName(f, names), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  Expanded(child: Text(f.about, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.muted, height: 1.3))),
                  Text('${s.machines.where((m) => _of(m) == f.id).length} machinery', style: const TextStyle(fontWeight: FontWeight.w700, color: C.greenDark, fontSize: 13)),
                  Row(children: [
                    TextButton(key: Key('lbf-view-${f.id}'), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)), onPressed: () => _view(f), child: Text('View format')),
                    if (can) TextButton(key: Key('lbf-ren-${f.id}'), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)), onPressed: () => _rename(f), child: Text('Edit name')),
                  ]),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        TextField(key: const Key('lbf-q'), onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: tr('Search machinery / owner / type…'), prefixIcon: const Icon(Icons.search_rounded), contentPadding: const EdgeInsets.symmetric(vertical: 12))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: PickField(label: 'Ownership', value: own, items: const ['Own', 'Rental', 'Hired', 'Other'], blank: 'All ownership', onChanged: (v) => setState(() => own = v))),
          const SizedBox(width: 8),
          Expanded(child: PickField(key: const Key('lbf-fmt'), label: 'Format', value: fmt, items: fmts, blank: 'All formats', onChanged: (v) => setState(() => fmt = v))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: PickField(label: 'Owner', value: owner, items: uniqOf(s.machines, 'owner'), blank: 'All owners', onChanged: (v) => setState(() => owner = v))),
          const SizedBox(width: 8),
          Expanded(child: PickField(label: 'Type', value: type, items: uniqOf(s.machines, 'type'), blank: 'All types', onChanged: (v) => setState(() => type = v))),
        ]),
        if (can) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('${sel.length} selected', key: const Key('lbf-selinfo'), style: const TextStyle(fontWeight: FontWeight.w800))),
                TextButton(
                  key: const Key('lbf-all'),
                  onPressed: () => setState(() {
                    final ids = list.map((m) => m.id);
                    if (ids.every(sel.contains)) {
                      sel.removeAll(ids);
                    } else {
                      sel.addAll(ids);
                    }
                  }),
                  child: Text('Select all shown'),
                ),
              ]),
              Row(children: [
                Expanded(child: PickField(key: const Key('lbf-set'), label: 'Set selected to', value: setTo, items: fmts, onChanged: (v) => setState(() => setTo = v))),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const Key('lbf-apply'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: () {
                    if (sel.isEmpty) {
                      toast(context, 'Tick the machinery first.', bad: true);
                      return;
                    }
                    setState(() {
                      for (final id in sel) {
                        final m = s.machine(id);
                        if (m != null) _set(m, setTo);
                      }
                    });
                    toast(context, '${sel.length} machinery set to Format $setTo – press Save.');
                  },
                  child: Text('Apply'),
                ),
              ]),
              Text(label(setTo), style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        if (list.isEmpty) EmptyState('No machinery for these filters.', '', pic: 'notebook'),
        for (final (i, m) in list.indexed)
          Container(
            key: Key('lbm-${m.id}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            decoration: BoxDecoration(color: ch[m.id] != null ? C.amberSoft : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
            child: Row(children: [
              if (can) Checkbox(key: Key('lbt-${m.id}'), value: sel.contains(m.id), onChanged: (v) => setState(() => v == true ? sel.add(m.id) : sel.remove(m.id))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i + 1}. ${m.id}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text([m.type, m.owner, m.ownership, worksOf(m.m).join(', ')].where((x) => x.isNotEmpty).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              if (can)
                SizedBox(
                  key: Key('lbo-${m.id}'),
                  width: 74,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('lbo-${m.id}-${_of(m)}'),
                    initialValue: _of(m),
                    isExpanded: true,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                    items: [for (final f in fmts) DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontWeight: FontWeight.w800)))],
                    onChanged: (v) => setState(() => _set(m, v ?? 'A')),
                  ),
                )
              else
                Pill(_of(m), color: C.blue, bg: C.blueSoft),
            ]),
          ),
      ])),
      bottomNavigationBar: !can
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  key: const Key('lbf-save'),
                  onPressed: busy || ch.isEmpty ? null : _save,
                  child: Text(busy ? 'Saving…' : ch.isEmpty ? 'Save' : 'Save (${ch.length} change${ch.length == 1 ? '' : 's'} not saved)'),
                ),
              ),
            ),
    );
  }
}
