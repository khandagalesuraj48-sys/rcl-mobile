/* ONE MACHINERY – add / edit (3.4.0), the web's Asset Master form in the app's own screen: Number, Name, Type, Make, what it works
 * on (the standards asked only for KM / Hrs), Tank, Vendor (Ownership picked by itself from it, unless picked by hand), Ownership
 * (Debit = diesel on debit basis, no readings), Status, Active From / Inactive From, its earlier periods on site (it left and came
 * back – "did it come back?" when it is made Active again), Engine / Chassis / Engine Make, the papers (a date, Lifetime, N/A).
 * An edit shows what will change (and, when the Number changes, what moves with it) before saveMaster.
 * ADD MULTIPLE – several machinery at once (saveMasterBulk): nothing is saved while one row has a problem, the rows are told. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/assets.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'machinery.dart' show uniqOf, vendorNames;
import '../ui/help.dart' show GuideButton;

class MachineFormScreen extends StatefulWidget {
  const MachineFormScreen({super.key, this.edit, this.vendors = const []});
  final Machine? edit;
  final List<String> vendors;
  @override
  State<MachineFormScreen> createState() => _MachineFormScreenState();
}

class _MachineFormScreenState extends State<MachineFormScreen> {
  final t = <String, TextEditingController>{for (final k in ['no', 'name', 'type', 'make', 'kmStd', 'hrStd', 'tankCap', 'owner', 'engineNo', 'chassisNo', 'engineMake']) k: TextEditingController()};
  final works = <String>{};
  String ownership = '', supply = 'Company', status = 'Active', activeFrom = '', inactiveFrom = '';
  bool ownAuto = false, supplyTouched = false;
  String wasOwn = '';
  final docs = <String, String>{for (final d in kDocs) d.$1: ''}; // a date · 'NA' · 'LIFETIME' · ''
  List<({String from, String until})> earlier = [];
  List<String> vendors = [];
  bool busy = false;
  String err = '';
  Map<String, dynamic>? get before => widget.edit?.m;
  String get editId => widget.edit?.id ?? '';

  @override
  void initState() {
    super.initState();
    vendors = widget.vendors;
    final m = before;
    if (m != null) {
      String v(String k) => '${m[k] ?? ''}';
      for (final k in t.keys) {
        t[k]!.text = v(k);
      }
      works.addAll(worksOf(m));
      ownership = kOwnerships.contains(v('ownership')) ? v('ownership') : '';
      wasOwn = ownership;
      supply = v('supply').isEmpty ? 'Company' : v('supply');
      supplyTouched = true;
      status = v('status').isEmpty ? 'Active' : v('status');
      activeFrom = v('activeFrom').length >= 10 ? v('activeFrom').substring(0, 10) : '';
      inactiveFrom = v('inactiveFrom').length >= 10 ? v('inactiveFrom').substring(0, 10) : '';
      for (final d in kDocs) {
        final x = v(d.$3);
        docs[d.$1] = x == 'NA' || x == 'LIFETIME' || RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(x) ? x : '';
      }
      earlier = [for (final p in (m['earlier'] as List? ?? const []).whereType<Map>()) (from: '${p['from'] ?? ''}', until: '${p['until'] ?? ''}')];
    }
    if (vendors.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final l = await vendorNames(SessionScope.read(context));
        if (mounted) setState(() => vendors = l);
      });
    }
  }

  @override
  void dispose() {
    for (final c in t.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get unit => unitFromWorks(works.toList());
  List<String> get worksList => [for (final w in kWorks) if (works.contains(w)) w];

  void _ownership(String v) {
    ownership = v;
    /* Diesel Supply follows Ownership: Debit = Debit Basis, always. A machinery taken OUT of Debit goes back to Company
     * (a Rental machinery with diesel on debit is decided in its BOQ, not here). Otherwise what it has is kept. */
    if (v == 'Debit') {
      supply = 'Debit Basis';
    } else if (wasOwn == 'Debit' || !supplyTouched) {
      supply = 'Company';
    }
    wasOwn = v;
  }

  void _ownerChanged(String v) {
    if (v.trim().isEmpty) return;
    if (ownership.isNotEmpty && !ownAuto) return; // picked by hand: left as it is
    setState(() {
      _ownership(autoOwnership(v));
      ownAuto = true;
    });
  }

  Future<void> _statusChanged(String v) async {
    final s = SessionScope.read(context);
    setState(() {
      status = v;
      if (v == 'Inactive' && inactiveFrom.isEmpty) inactiveFrom = s.today;
    });
    // (update-119) a machinery that left on a date is made Active again: did it come back? its new Active From = the day it came back
    final was = before;
    if (was == null || !(was['status'] == 'Inactive' && '${was['inactiveFrom'] ?? ''}'.isNotEmpty) || v != 'Active') return;
    final left = '${was['inactiveFrom']}'.substring(0, 10), af0 = '${was['activeFrom'] ?? ''}'.length >= 10 ? '${was['activeFrom']}'.substring(0, 10) : '';
    var back = s.today.compareTo(left) > 0 ? s.today : left;
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('Did $editId come back to the site?'),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('$editId left the site on ${showDate(left)} (Inactive From).', style: const TextStyle(fontSize: 14.5)),
            const SizedBox(height: 10),
            DateField(key: const Key('m-back'), label: 'It came back on', value: back, clear: false, first: parseKey(left), onChanged: (d) => set(() => back = d)),
            const SizedBox(height: 10),
            Text('Its time on site until then is kept as an earlier period. From this date its Log Book and diesel go on; the days between: not on site.', style: const TextStyle(fontSize: 13.5, height: 1.35)),
            const SizedBox(height: 6),
            Text('"It never left": the Inactive was a mistake – it counts as on site for every day.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
          ]),
          actions: [
            TextButton(key: const Key('m-never'), onPressed: () => Navigator.pop(c, false), child: Text('It never left')),
            FilledButton(key: const Key('m-cameback'), style: FilledButton.styleFrom(minimumSize: const Size(0, 46)), onPressed: () => Navigator.pop(c, true), child: Text('It came back on this date')),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => activeFrom = res == true ? (back.compareTo(left) >= 0 ? back : (s.today.compareTo(left) > 0 ? s.today : left)) : af0);
  }

  String _num(String k) => t[k]!.text.trim();

  /// What is sent – the same object as the web's save.
  Map<String, dynamic> _payload() {
    dynamic nv(String k) {
      final v = _num(k);
      return v.isEmpty ? '' : (num.tryParse(v) ?? v);
    }

    final m = <String, dynamic>{
      'no': t['no']!.text.trim(), 'name': t['name']!.text.trim(), 'type': t['type']!.text.trim(), 'make': t['make']!.text.trim(),
      'unit': unit, 'worksOn': worksList.join(', '),
      'kmStd': hasKm(unit) ? nv('kmStd') : '', 'hrStd': hasHr(unit) ? nv('hrStd') : '', 'tankCap': nv('tankCap'), 'owner': t['owner']!.text.trim(), 'ownership': ownership,
      'engineNo': t['engineNo']!.text.trim(), 'chassisNo': t['chassisNo']!.text.trim(), 'engineMake': t['engineMake']!.text.trim(),
      for (final d in kDocs) d.$3: docs[d.$1] ?? '',
      'supply': supply, 'status': status, 'activeFrom': activeFrom, 'inactiveFrom': status == 'Inactive' ? inactiveFrom : '',
    };
    if (widget.edit != null) m['earlier'] = [for (final p in earlier) if (p.from.isNotEmpty || p.until.isNotEmpty) {'from': p.from, 'until': p.until}];
    return m;
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    final m = _payload();
    final mode = widget.edit == null ? 'add' : 'edit';
    if (mode == 'edit') {
      final changes = masterChanges(before!, m);
      if (changes.isEmpty) {
        toast(context, 'Nothing changed.');
        return;
      }
      final newId = idOf('${m['no']}', '${m['name']}'), idChange = newId.isNotEmpty && newId != editId;
      if (newId.isEmpty) {
        setState(() => err = 'Enter the Machinery Number, or the Machinery Name if it has no number.');
        return;
      }
      final ok = await askChanges(context, 'Update $editId?', changes,
          beforeHead: idChange ? 'The machinery is known as $editId today and will be known as $newId.' : '', before: idChange ? kRenameNote : const [], yes: idChange ? 'Change the number' : 'Update');
      if (!ok) return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final res = (await s.api.call('saveMaster', [m, mode, widget.edit == null ? null : editId], true) as Map).cast<String, dynamic>();
      s.setMaster(res['master']);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      toast(context, tr(savedWords(mode, res)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final debit = ownership == 'Debit';
    Widget gap([double h = 10]) => SizedBox(height: h);
    return Scaffold(
      appBar: AppBar(title: Text(widget.edit == null ? 'Add machinery' : 'Edit $editId'), actions: [const GuideButton('master')]),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Focus(
          onFocusChange: (f) {
            if (!f) t['no']!.text = formatNo(t['no']!.text); // MH12AB1234 → MH-12-AB-1234, as the web
          },
          child: TextBox(key: const Key('mf-no'), label: 'Machinery Number', controller: t['no']!, upper: true),
        ),
        gap(),
        TextBox(key: const Key('mf-name'), label: 'Machinery Name (needed if there is no number)', controller: t['name']!),
        gap(),
        TextBox(key: const Key('mf-type'), label: 'Type of Machinery', controller: t['type']!, options: uniqOf(s.machines, 'type')),
        gap(),
        TextBox(key: const Key('mf-make'), label: 'Make', controller: t['make']!, options: uniqOf(s.machines, 'make')),
        FormHead('Works on${debit ? '' : ' *'}', sub: 'Tick all that apply'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final w in kWorks)
            FilterChip(
              key: Key('mw-$w'),
              label: Text(kWorksHint[w] == null ? w : '$w (${tr(kWorksHint[w]!)})'),
              selected: works.contains(w),
              onSelected: (v) => setState(() => v ? works.add(w) : works.remove(w)),
            ),
        ]),
        gap(12),
        TextBox(key: const Key('mf-kmstd'), label: 'Standard Average (KM/Ltr)', controller: t['kmStd']!, enabled: hasKm(unit), kb: const TextInputType.numberWithOptions(decimal: true)),
        gap(),
        TextBox(key: const Key('mf-hrstd'), label: 'Standard Average (Ltr/Hr)', controller: t['hrStd']!, enabled: hasHr(unit), kb: const TextInputType.numberWithOptions(decimal: true)),
        gap(),
        TextBox(key: const Key('mf-tcap'), label: 'Tank Capacity (Ltr)', controller: t['tankCap']!, hint: 'Optional – for reference', kb: TextInputType.number),
        gap(),
        TextBox(key: const Key('mf-owner'), label: 'Vendor (Owner Name)', controller: t['owner']!, options: vendors, hint: 'Pick from Vendor Master', onChanged: _ownerChanged),
        gap(),
        PickField(
          key: const Key('mf-ownership'),
          label: 'Ownership *',
          value: ownership,
          items: kOwnerships,
          blank: 'Select',
          onChanged: (v) => setState(() {
            ownAuto = false;
            _ownership(v);
          }),
        ),
        if (debit)
          InfoLine('Debit: takes diesel on debit basis – all its diesel is debited, no meter reading is asked, it is not in the Log Book. "Works on" and the standard average are not needed.', icon: Icons.info_outline_rounded),
        gap(),
        PickField(key: const Key('mf-status'), label: 'Status', value: status, items: const ['Active', 'Inactive'], onChanged: _statusChanged),
        gap(),
        Row(children: [
          Expanded(child: DateField(key: const Key('mf-afrom'), label: 'Active From (blank = always)', value: activeFrom, onChanged: (v) => setState(() => activeFrom = v))),
          if (status == 'Inactive') ...[
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('mf-ifrom'), label: 'Inactive From *', value: inactiveFrom, onChanged: (v) => setState(() => inactiveFrom = v))),
          ],
        ]),
        if (widget.edit != null) ...[
          FormHead('Earlier periods on site', sub: 'It left and came back – kept by itself when it comes back'),
          if (earlier.isEmpty) Text('None – on site in one period.', style: const TextStyle(color: C.muted)),
          for (final (i, p) in earlier.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: DateField(key: Key('mp-from-$i'), label: 'From', value: p.from, onChanged: (v) => setState(() => earlier[i] = (from: v, until: p.until)))),
                const SizedBox(width: 6),
                Expanded(child: DateField(key: Key('mp-until-$i'), label: 'Inactive From (it left)', value: p.until, onChanged: (v) => setState(() => earlier[i] = (from: p.from, until: v)))),
                IconButton(key: Key('mp-del-$i'), tooltip: tr('Remove'), onPressed: () => setState(() => earlier.removeAt(i)), icon: const Icon(Icons.delete_outline_rounded, color: C.red)),
              ]),
            ),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('mp-add'), onPressed: () => setState(() => earlier.add((from: '', until: ''))), icon: const Icon(Icons.add_rounded), label: Text('+ Add an earlier period'))),
        ],
        gap(),
        TextBox(key: const Key('mf-engno'), label: 'Engine Number', controller: t['engineNo']!, upper: true),
        gap(),
        TextBox(key: const Key('mf-chassis'), label: 'Chassis Number', controller: t['chassisNo']!, upper: true),
        gap(),
        TextBox(key: const Key('mf-engmake'), label: 'Engine Make (company)', controller: t['engineMake']!, options: uniqOf(s.machines, 'engineMake'), hint: 'e.g. Cummins, Tata'),
        FormHead('Papers – valid upto', sub: 'Tick N/A where it does not apply to this asset'),
        for (final d in kDocs) _doc(d.$1, d.$2),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        gap(16),
        FilledButton(key: const Key('mf-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : widget.edit == null ? 'Save machinery' : 'Update machinery')),
      ])),
    );
  }

  Widget _doc(String k, String label) {
    final v = docs[k] ?? '', na = v == 'NA', lt = v == 'LIFETIME';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      child: Row(children: [
        Expanded(child: DateField(key: Key('md-$k'), label: label, value: na || lt ? '' : v, enabled: !na && !lt, onChanged: (x) => setState(() => docs[k] = x))),
        if (k == 'tax') _tick('Lifetime', lt, (x) => setState(() => docs[k] = x ? 'LIFETIME' : ''), Key('mlt-$k')),
        _tick('N/A', na, (x) => setState(() => docs[k] = x ? 'NA' : ''), Key('mna-$k')),
      ]),
    );
  }

  Widget _tick(String label, bool v, ValueChanged<bool> on, Key key) => InkWell(
        key: key,
        onTap: () => on(!v),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Checkbox(value: v, onChanged: (x) => on(x == true), visualDensity: VisualDensity.compact), Text(label, style: const TextStyle(fontSize: 13))]),
        ),
      );
}

/* ---------------- ADD MULTIPLE MACHINERY ---------------- */
class BulkMachineryScreen extends StatefulWidget {
  const BulkMachineryScreen({super.key, this.vendors = const []});
  final List<String> vendors;
  @override
  State<BulkMachineryScreen> createState() => _BulkMachineryScreenState();
}

class _BulkRow {
  final t = <String, TextEditingController>{for (final k in ['no', 'name', 'type', 'make', 'kmStd', 'hrStd', 'owner']) k: TextEditingController()};
  String unit = '', ownership = '', supply = '';
  String err = '';
  Map<String, dynamic> get value => {
        for (final k in kBulkFields) k: switch (k) { 'unit' => unit, 'ownership' => ownership, 'supply' => supply, 'no' => formatNo(t[k]!.text), _ => t[k]!.text.trim() },
      };
  void dispose() {
    for (final c in t.values) {
      c.dispose();
    }
  }
}

class _BulkMachineryScreenState extends State<BulkMachineryScreen> {
  final rows = <_BulkRow>[for (var i = 0; i < 5; i++) _BulkRow()];
  bool busy = false;
  String err = '';

  @override
  void dispose() {
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    setState(() {
      busy = true;
      err = '';
      for (final r in rows) {
        r.err = '';
      }
    });
    try {
      final res = (await s.api.call('saveMasterBulk', [rows.map((r) => r.value).toList()], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (res['ok'] != true) {
        setState(() {
          for (final e in (res['errors'] as List? ?? const []).whereType<Map>()) {
            final i = (asNum(e['row']) ?? 0).toInt() - 1;
            if (i >= 0 && i < rows.length) rows[i].err = '${e['msg']}'.replaceFirst(RegExp(r'^Error:\s*'), '');
          }
          err = 'Nothing saved. Fix the rows marked in red.';
        });
        return;
      }
      s.setMaster(res['master']);
      toast(context, '${res['count']} machinery saved.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final types = uniqOf(s.machines, 'type'), makes = uniqOf(s.machines, 'make'), owners = {...uniqOf(s.machines, 'owner'), ...widget.vendors}.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text('Add multiple machinery'), actions: [const GuideButton('master')]),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('For Debit machinery only Number or Name is needed.', style: const TextStyle(fontSize: 13.5, color: C.muted)),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 10),
        for (final (i, r) in rows.indexed)
          Container(
            key: Key('br-$i'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: r.err.isEmpty ? Colors.white : C.redSoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: r.err.isEmpty ? C.line : C.red)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                IconButton(
                  key: Key('br-x-$i'),
                  tooltip: tr('Remove row'),
                  onPressed: () {
                    final gone = rows[i];
                    setState(() {
                      rows.removeAt(i);
                      if (rows.isEmpty) rows.add(_BulkRow());
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) => gone.dispose()); // after its boxes are gone
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              if (r.err.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Row ${i + 1}: ${r.err}', style: const TextStyle(color: C.red, fontWeight: FontWeight.w600))),
              Row(children: [
                Expanded(child: TextBox(key: Key('br-no-$i'), label: 'Machinery Number', controller: r.t['no']!, upper: true)),
                const SizedBox(width: 8),
                Expanded(child: TextBox(key: Key('br-name-$i'), label: 'Machinery Name', controller: r.t['name']!)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextBox(label: 'Type of Machinery', controller: r.t['type']!, options: types)),
                const SizedBox(width: 8),
                Expanded(child: TextBox(label: 'Make', controller: r.t['make']!, options: makes)),
              ]),
              const SizedBox(height: 8),
              PickField(
                key: Key('br-unit-$i'),
                label: 'Unit',
                value: r.unit,
                items: kUnits,
                blank: '',
                onChanged: (v) => setState(() {
                  r.unit = v;
                  if (!hasKm(v)) r.t['kmStd']!.clear();
                  if (!hasHr(v)) r.t['hrStd']!.clear();
                }),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextBox(label: 'Std Avg (KM/Ltr)', controller: r.t['kmStd']!, enabled: hasKm(r.unit), kb: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 8),
                Expanded(child: TextBox(label: 'Std Avg (Ltr/Hr)', controller: r.t['hrStd']!, enabled: hasHr(r.unit), kb: const TextInputType.numberWithOptions(decimal: true))),
              ]),
              const SizedBox(height: 8),
              TextBox(label: 'Owner Name', controller: r.t['owner']!, options: owners),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: PickField(key: Key('br-own-$i'), label: 'Ownership *', value: r.ownership, items: kOwnerships, blank: '', onChanged: (v) => setState(() => r.ownership = v))),
                const SizedBox(width: 8),
                Expanded(child: PickField(label: 'Diesel Supply', value: r.supply, items: kSupplies, blank: 'Auto', onChanged: (v) => setState(() => r.supply = v))),
              ]),
            ]),
          ),
        OutlinedButton.icon(key: const Key('br-add'), onPressed: () => setState(() => rows.addAll([for (var i = 0; i < 5; i++) _BulkRow()])), icon: const Icon(Icons.add_rounded), label: Text('Add 5 rows')),
      ])),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(key: const Key('br-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save all machinery')),
        ),
      ),
    );
  }
}
