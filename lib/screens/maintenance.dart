/* (3.46.0, Mechanical update-165, asked 27-10-2026 – step 2 of HO: "Maintenance Log Book")
 * MAINTENANCE – the app's own screens of the web's page Maintenance, at a site on fuel cards (HO):
 *   MaintScreen – the bills of the dates (and of one car), newest first, their total; a bill opens with its lines, its files, Change,
 *                 Delete; "Car log book" – the car's Maintenance Log Book (report_defs.dart kMaintLog: screen, Excel, PDF).
 *   MaintForm   – one bill of a car: its date, car, garage, bill number, KM, Service (its KM is needed), remark; its lines (each work /
 *                 part with its ₹, a discount a minus line; the words typed before are offered); its files (PDF / photos, up to 10) –
 *                 "Read the bill (AI)" fills the empty boxes from the last file added (blue – the person checks every value).
 * The same server actions, checks and access as the web: getMaint, saveMaint, updateMaint, deleteMaint, maintFile, getMaintFiles,
 * readMaintBill, maintLog. */
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;

import '../core/attach.dart';
import '../core/format.dart';
import '../core/report_defs.dart' show kMaintLog;
import '../core/session.dart';
import '../ui/ask_bot.dart';
import '../ui/fields.dart';
import '../ui/help.dart' show GuideButton;
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'attach_box.dart' show AttachStrip, AttViewer;
import 'forms.dart' show MachinePicker;
import 'fuel_cards.dart' show rupees;
import 'report_screen.dart' show openReport;

/// A bill keeps at most this many files (the server's MNT_FILES_MAX_)
const kMaintFilesMax = 10;

String _key(String v) => v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// The lines of a bill as one short line: "Engine oil ₹1,200; Labour ₹500"
String maintLinesText(Object? lines) => [for (final l in (lines is List ? lines : const []).whereType<Map>()) '${l['work']} ₹${fmtNum(asNum(l['amount']))}'].join('; ');

class MaintScreen extends StatefulWidget {
  const MaintScreen({super.key});
  @override
  State<MaintScreen> createState() => _MaintScreenState();
}

class _MaintScreenState extends State<MaintScreen> {
  bool loading = true, missing = false;
  String err = '', from = '', to = '', no = '';
  List<Map<String, dynamic>> rows = [];
  List<String> works = [], garages = [];
  num total = 0;
  int count = 0, _seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (from.isNotEmpty) return;
    final s = SessionScope.read(context);
    to = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    from = '${to.substring(0, 8)}01';
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = (await s.api.call('getMaint', [{'from': from, 'to': to, 'no': no}]) as Map).cast<String, dynamic>();
      if (my != _seq || !mounted) return;
      setState(() {
        rows = [for (final x in (r['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
        total = asNum(r['total']) ?? 0;
        count = (asNum(r['count']) ?? rows.length).toInt();
        works = [for (final w in (r['works'] as List? ?? const [])) '$w'];
        garages = [for (final g in (r['garages'] as List? ?? const [])) '$g'];
        missing = r['missing'] == true;
        loading = false;
      });
    } catch (e) {
      if (my != _seq || !mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  Future<void> _open(Widget page) async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (r == true && mounted) _load();
  }

  Future<void> _pickCar() async {
    final s = SessionScope.read(context);
    final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => MachinePicker(only: s.machines));
    if (m == null || !mounted) return;
    setState(() => no = m.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), can = s.canEdit('Maintenance');
    return Scaffold(
      appBar: AppBar(
        title: const TwoLang('Maintenance', 'मेंटेनन्स', size: 20, weight: FontWeight.w700),
        actions: withAsk([const GuideButton('mnt'), IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      ),
      floatingActionButton: can && !missing ? FloatingActionButton.extended(key: const Key('mt-add'), onPressed: () => _open(MaintForm(works: works, garages: garages)), icon: const Icon(Icons.add_rounded), label: Text('Bill')) : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('mt-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 100), children: [
          Text('One bill of a car: each work / part with its ₹. Add the bill (PDF or photo) – the AI can read it for you; check every value, then save.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
          const SizedBox(height: 10),
          if (missing) const Padding(padding: EdgeInsets.only(bottom: 10), child: InfoLine('Maintenance bills cannot be kept yet. This needs one database step first: the Admin runs sql/supabase_step1zi_maintenance.sql once in Supabase → SQL Editor.', bad: true)),
          if (!can) const Padding(padding: EdgeInsets.only(bottom: 10), child: InfoLine('View only – you can see the bills, their files and the car log books here, but you cannot add or change them. Ask Admin for Edit access.', help: false)),
          Press(
            key: const Key('mt-log'),
            onTap: () => openReport(context, kMaintLog, no: no, run: no.isNotEmpty),
            radius: 18,
            color: C.blueSoft,
            border: C.blueSoft,
            shadow: false,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.menu_book_rounded, color: C.blue),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Maintenance Log Book of a car', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.blue)),
                Text('Its fills and bills by date – fuel, maintenance, all costs, ₹ per KM', style: const TextStyle(fontSize: 12.5, color: C.muted)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: C.blue),
            ]),
          ),
          FormHead('Maintenance bills', sub: '${showDate(from)} – ${showDate(to)} · $count · ${rupees(total)}'),
          Row(children: [
            Expanded(child: DateField(key: const Key('mt-from'), label: 'From', value: from, clear: false, onChanged: (v) { setState(() => from = v); _load(); })),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('mt-to'), label: 'To', value: to, clear: false, onChanged: (v) { setState(() => to = v); _load(); })),
          ]),
          const SizedBox(height: 8),
          Press(
            key: const Key('mt-car'),
            onTap: _pickCar,
            radius: 16,
            shadow: false,
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(children: [
              const Icon(Icons.directions_car_rounded, color: C.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Car', style: const TextStyle(fontSize: 12, color: C.muted)),
                Text(no.isEmpty ? 'Blank = all cars' : no, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: no.isEmpty ? C.faint : C.ink)),
              ])),
              if (no.isNotEmpty)
                IconButton(key: const Key('mt-car-x'), tooltip: tr('Clear'), onPressed: () { setState(() => no = ''); _load(); }, icon: const Icon(Icons.close_rounded, size: 18, color: C.muted)),
            ]),
          ),
          const SizedBox(height: 6),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          if (!loading && rows.isEmpty && err.isEmpty) const EmptyState('No maintenance bill in these dates.', 'A bill of a car: its work / parts and its ₹, with the bill PDF or photo.', pic: 'wrench'),
          for (final r in rows) Padding(padding: const EdgeInsets.only(top: 8), child: _tile(r, can)),
        ]),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> r, bool can) {
    final files = (r['files'] as List? ?? const []).length;
    return Press(
      key: Key('mt-r-${r['id']}'),
      onTap: () => _sheet(r, can),
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.build_rounded, color: C.blue)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text('${r['no']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
            if (r['service'] == true) const Padding(padding: EdgeInsets.only(left: 6), child: Pill('✔ Service', color: C.blue, bg: C.blueSoft)),
          ]),
          Text([showDate('${r['date']}'), '${r['id']}', if ('${r['garage'] ?? ''}'.isNotEmpty) '${r['garage']}', if ('${r['billNo'] ?? ''}'.isNotEmpty) 'bill ${r['billNo']}', if (files > 0) '📎 $files'].join(' · '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
          Text(maintLinesText(r['lines']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.ink)),
        ])),
        const SizedBox(width: 8),
        Text(rupees(asNum(r['total'])), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.greenDark)),
      ]),
    );
  }

  Future<void> _sheet(Map<String, dynamic> r, bool can) async {
    final files = (r['files'] as List? ?? const []).length;
    final lines = [for (final l in (r['lines'] as List? ?? const []).whereType<Map>()) l];
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (bc) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(bc).size.height * .85),
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${r['id']} · ${rupees(asNum(r['total']))}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            InfoRow('Car', '${r['no']}'),
            InfoRow('Date', showDate('${r['date']}')),
            InfoRow('Garage', '${r['garage'] ?? ''}'),
            InfoRow('Bill no.', '${r['billNo'] ?? ''}'),
            InfoRow('KM', _blank(r['km']) ? '' : fmtNum(asNum(r['km']))),
            InfoRow('Service', r['service'] == true ? tr('Yes') : ''),
            InfoRow('Remark', '${r['remark'] ?? ''}'),
            InfoRow('Entered by', '${r['enteredBy'] ?? ''}'),
            FormHead('Work / parts'),
            for (final l in lines) InfoRow('${l['work']}', rupees(asNum(l['amount'])), tone: (asNum(l['amount']) ?? 0) < 0 ? C.red : C.ink),
            InfoRow('Total', rupees(asNum(r['total'])), bold: true, tone: C.greenDark),
            const SizedBox(height: 12),
            if (files > 0) OutlinedButton.icon(key: const Key('mt-files'), onPressed: () => Navigator.pop(bc, 'files'), icon: const Icon(Icons.attach_file_rounded), label: Text('Bill files ($files)')),
            if (can) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(key: const Key('mt-edit'), onPressed: () => Navigator.pop(bc, 'edit'), icon: const Icon(Icons.edit_rounded), label: Text('Change')),
              const SizedBox(height: 8),
              OutlinedButton.icon(key: const Key('mt-del'), style: OutlinedButton.styleFrom(foregroundColor: C.red), onPressed: () => Navigator.pop(bc, 'del'), icon: const Icon(Icons.delete_outline_rounded), label: Text('Delete')),
            ],
          ])),
        ),
      ),
    );
    if (!mounted || v == null) return;
    final s = SessionScope.read(context);
    if (v == 'edit') return _open(MaintForm(edit: r, works: works, garages: garages));
    if (v == 'files') {
      try {
        final f = (await s.api.call('getMaintFiles', ['${r['id']}']) as Map).cast<String, dynamic>();
        if (!mounted) return;
        final list = attList(f['files']);
        if (list.isEmpty) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttViewer(files: list, title: 'Bill files – ${r['id']}')));
      } catch (e) {
        if (mounted) toast(context, errText(e), bad: true);
      }
      return;
    }
    if (v == 'del') {
      if (!await ask(context, 'Delete ${r['id']}?', '${r['no']} – ${rupees(asNum(r['total']))} · ${showDate('${r['date']}')}${'${r['garage'] ?? ''}'.isNotEmpty ? ' · ${r['garage']}' : ''}. Its files stay kept.', yes: 'Delete', danger: true)) return;
      try {
        await s.api.call('deleteMaint', ['${r['id']}'], true);
        if (mounted) toast(context, '${r['id']} deleted.');
        _load();
      } catch (e) {
        if (mounted) toast(context, errText(e), bad: !isSent(e));
        if (isSent(e)) _load();
      }
    }
  }
}

bool _blank(Object? v) => v == null || '$v'.trim().isEmpty;

/// A box the AI filled (blue) – [on] false: the same box without the colour
class AiBox extends StatelessWidget {
  const AiBox({super.key, required this.on, required this.child});
  final bool on;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: on ? C.blueSoft : null, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? C.blue.withValues(alpha: .55) : Colors.transparent, width: 1.5)),
        child: Material(type: MaterialType.transparency, child: child),      // (the switch's row draws on it, over the colour)
      );
}

/// One line of the bill being typed: its work / part and its ₹; [ai] = read by the AI (blue) until the person changes it
class _Line {
  _Line([String work = '', String amount = '', this.ai = false])
      : work = TextEditingController(text: work),
        amount = TextEditingController(text: amount);
  final TextEditingController work, amount;
  bool ai;
  void dispose() {
    work.dispose();
    amount.dispose();
  }
}

/// A maintenance bill: new, or one being changed ([edit])
class MaintForm extends StatefulWidget {
  const MaintForm({super.key, this.edit, this.works = const [], this.garages = const []});
  final Map<String, dynamic>? edit;
  final List<String> works, garages;
  @override
  State<MaintForm> createState() => _MaintFormState();
}

class _MaintFormState extends State<MaintForm> {
  final garage = TextEditingController(), billNo = TextEditingController(), km = TextEditingController(), remark = TextEditingController();
  final lines = <_Line>[];
  final files = <AttFile>[];
  final ai = <String>{};      // the boxes the AI filled (blue): date, garage, billNo, km, service
  String date = '', err = '', readMsg = '';
  bool service = false, busy = false, reading = false, dateTyped = false, _started = false;
  Machine? car;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final s = SessionScope.read(context), e = widget.edit;
    date = s.today;
    if (e != null) {
      date = '${e['date']}';
      dateTyped = true;
      car = s.machine('${e['no']}');
      garage.text = '${e['garage'] ?? ''}';
      billNo.text = '${e['billNo'] ?? ''}';
      km.text = _blank(e['km']) ? '' : '${asNum(e['km'])}'.replaceAll(RegExp(r'\.0$'), '');
      remark.text = '${e['remark'] ?? ''}';
      service = e['service'] == true;
      for (final l in (e['lines'] as List? ?? const []).whereType<Map>()) {
        lines.add(_Line('${l['work']}', '${asNum(l['amount'])}'.replaceAll(RegExp(r'\.0$'), '')));
      }
      if ((e['files'] as List? ?? const []).isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _loadFiles());
    }
    if (lines.isEmpty) lines.add(_Line());
  }

  Future<void> _loadFiles() async {
    try {
      final r = (await SessionScope.read(context).api.call('getMaintFiles', ['${widget.edit!['id']}']) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => files.insertAll(0, attList(r['files'])));
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  @override
  void dispose() {
    for (final c in [garage, billNo, km, remark]) {
      c.dispose();
    }
    for (final l in lines) {
      l.dispose();
    }
    super.dispose();
  }

  List<Map<String, Object>> get _typed => [
        for (final l in lines)
          if (l.work.text.trim().isNotEmpty || l.amount.text.trim().isNotEmpty) {'work': l.work.text.trim(), 'amount': asNum(l.amount.text.replaceAll(',', '')) ?? l.amount.text.trim()},
      ];
  num get _total => lines.fold<num>(0, (t, l) => t + (asNum(l.amount.text.replaceAll(',', '')) ?? 0));

  /// the last file added here (not one the bill kept) – what the AI reads
  AttFile? get _readable {
    for (final f in files.reversed) {
      if (f.bytes != null) return f;
    }
    return null;
  }

  Future<void> _read() async {
    final f = _readable;
    if (f == null || reading) return;
    final s = SessionScope.read(context);
    setState(() {
      reading = true;
      readMsg = 'The AI is reading the bill…';
    });
    try {
      final r = (await s.api.call('readMaintBill', [{'data': 'data:${f.mime};base64,${base64Encode(f.bytes!)}'}]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (r['off'] == true) {
        setState(() => readMsg = 'The AI is not set up on this site – type the bill.');
        return;
      }
      var n = 0;
      bool put(String k, TextEditingController c, Object? v) {
        if (_blank(v) || c.text.trim().isNotEmpty) return false;
        c.text = '$v'.replaceAll(RegExp(r'\.0$'), '');
        ai.add(k);
        return true;
      }
      setState(() {
        if (!_blank(r['date']) && (!dateTyped || date.isEmpty)) {
          date = '${r['date']}';
          ai.add('date');
          n++;
        }
        if (put('billNo', billNo, r['billNo'])) n++;
        if (put('garage', garage, r['garage'])) n++;
        if (put('km', km, r['km'])) n++;
        if (r['service'] == true && !service) {
          service = true;
          ai.add('service');
          n++;
        }
      });
      final got = [for (final l in (r['lines'] as List? ?? const []).whereType<Map>()) l];
      final had = _typed;
      if (got.isNotEmpty && (had.isEmpty || await ask(context, 'Replace the lines?', 'The AI read ${got.length} line(s) on the bill. Replace the ${had.length} line(s) typed with them?', yes: 'Replace'))) {
        if (!mounted) return;
        setState(() {
          final old = [...lines];
          WidgetsBinding.instance.addPostFrameCallback((_) => _drop(old));
          lines
            ..clear()
            ..addAll([for (final l in got) _Line('${l['work']}', '${asNum(l['amount'])}'.replaceAll(RegExp(r'\.0$'), ''), true)]);
          n += got.length;
        });
      }
      final v = '${r['vehicle'] ?? ''}', c = car;
      final carNote = v.isNotEmpty && c != null && _key(v) != _key(c.id) ? ' ${tr('The bill says the vehicle $v – check the car.')}' : '';
      final check = '${r['check'] ?? ''}';
      setState(() => readMsg = '${tr(n > 0 ? 'Read by the AI (blue) – check every value before saving.' : 'The AI read nothing new from this bill – type it.')}${check.isNotEmpty ? ' ${tr('Check')}: ${tr(check)}.' : ''}$carNote');
    } catch (e) {
      if (mounted) setState(() => readMsg = errText(e));
    } finally {
      if (mounted) setState(() => reading = false);
    }
  }

  Future<void> _pickCar() async {
    final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => MachinePicker(date: date));
    if (m != null && mounted) setState(() => car = m);
  }

  Future<void> _save({bool force = false}) async {
    final s = SessionScope.read(context), e = widget.edit, c = car;
    if (c == null) {
      setState(() => err = 'Pick the car of the bill.');
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final bad = await attSendAll(s.api, files, () { if (mounted) setState(() {}); }, action: 'maintFile');
      if (bad.isNotEmpty) {
        if (mounted) setState(() {
            busy = false;
            err = bad;
          });
        return;
      }
      final x = <String, Object>{
        'date': date, 'no': c.id, 'garage': garage.text.trim(), 'billNo': billNo.text.trim(), 'km': asNum(km.text.replaceAll(',', '')) ?? '', 'service': service, 'remark': remark.text.trim(),
        'lines': _typed, 'files': [for (final f in files) f.ref], if (force) 'force': true,
      };
      final r = (await (e == null ? s.api.call('saveMaint', [x], true) : s.api.call('updateMaint', ['${e['id']}', x], true)) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (r['ok'] == false && '${r['warning'] ?? ''}'.isNotEmpty) {
        setState(() => busy = false);
        if (await ask(context, 'Saved before?', '${r['warning']}', yes: 'Save again')) await _save(force: true);
        return;
      }
      toast(context, e == null ? 'Bill ${r['id']} saved – ${rupees(asNum(r['total']))}.' : 'Bill ${r['id']} saved.');
      Navigator.pop(context, true);
    } catch (x) {
      if (!mounted) return;
      if (isSent(x)) {
        toast(context, errText(x));
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        busy = false;
        err = errText(x);
      });
    }
  }

  /// the lines taken out: their boxes are let go after the screen has drawn without them
  void _drop(List<_Line> gone) {
    for (final l in gone) {
      l.dispose();
    }
  }

  /// a box the AI filled: blue until the person changes it (always the same wrapper – the box being typed in keeps its keyboard)
  Widget _blue(bool on, Widget child) => AiBox(on: on, child: child);

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), e = widget.edit, rd = _readable;
    final canRead = rd != null && !reading && !busy;
    return Scaffold(
      appBar: AppBar(title: TwoLang(e == null ? 'Maintenance bill' : 'Change bill ${e['id']}', 'मेंटेनन्स बिल', size: 18, weight: FontWeight.w700)),
      body: SingleChildScrollView(key: const Key('mf-list'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _blue(ai.contains('date'), DateField(key: const Key('mf-date'), label: 'Bill date', value: date, clear: false, last: s.today.isEmpty ? null : parseKey(s.today), onChanged: (v) => setState(() {
              date = v;
              dateTyped = true;
              ai.remove('date');
            }))),
        const SizedBox(height: 10),
        Press(
          key: const Key('mf-car'),
          onTap: busy ? null : _pickCar,
          radius: 16,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(children: [
            const Icon(Icons.directions_car_rounded, color: C.blue, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr('Car')} *', style: const TextStyle(fontSize: 12, color: C.muted)),
              Text(car == null ? 'Pick the car of the bill.' : [car!.id, if (car!.name.isNotEmpty && car!.name != car!.id) car!.name].join(' · '), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: car == null ? C.faint : C.ink)),
            ])),
            const Icon(Icons.expand_more_rounded, color: C.muted),
          ]),
        ),
        const SizedBox(height: 10),
        _blue(ai.contains('garage'), TextBox(key: const Key('mf-garage'), label: 'Garage / vendor', controller: garage, options: widget.garages, hint: 'e.g. Toyota service centre', onChanged: (_) => setState(() => ai.remove('garage')))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _blue(ai.contains('billNo'), TextBox(key: const Key('mf-billno'), label: 'Bill number', controller: billNo, onChanged: (_) => setState(() => ai.remove('billNo'))))),
          const SizedBox(width: 8),
          Expanded(child: _blue(ai.contains('km'), TextBox(key: const Key('mf-km'), label: 'KM reading', controller: km, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() => ai.remove('km'))))),
        ]),
        _blue(
          ai.contains('service'),
          SwitchListTile(
            key: const Key('mf-service'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text('This bill is a service', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('(its KM is needed)'),
            value: service,
            onChanged: (v) => setState(() {
              service = v;
              ai.remove('service');
            }),
          ),
        ),
        TextBox(key: const Key('mf-remark'), label: 'Remark', controller: remark),
        FormHead('Bill files', sub: '(PDF / photos) · up to $kMaintFilesMax'),
        AttachStrip(files: files, max: kMaintFilesMax, enabled: !busy, onChanged: () => setState(() {})),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('mf-read'),
          onPressed: canRead ? _read : null,
          icon: reading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)) : const Icon(Icons.auto_awesome_rounded),
          label: Text('📄 Read the bill (AI)'),
        ),
        if (readMsg.isNotEmpty)
          Container(
            key: const Key('mf-readmsg'),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.auto_awesome_rounded, color: C.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(readMsg, style: const TextStyle(fontSize: 13.5, color: C.blue, height: 1.35, fontWeight: FontWeight.w500))),
            ]),
          )
        else if (rd != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('Press "Read the bill (AI)" to fill the form from it – then check every value.', style: const TextStyle(fontSize: 12.5, color: C.muted))),
        FormHead('Work / parts of the bill', sub: 'A discount is a minus amount.'),
        for (final (i, l) in lines.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _blue(
              l.ai,
              Row(children: [
                Expanded(flex: 3, child: TextBox(key: Key('mf-w-$i'), label: 'Work / part', controller: l.work, options: widget.works, hint: 'e.g. Engine oil, Air filter, Labour', onChanged: (_) => setState(() => l.ai = false))),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: TextBox(key: Key('mf-a-$i'), label: 'Amount (₹)', controller: l.amount, kb: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() => l.ai = false))),
                IconButton(
                  key: Key('mf-x-$i'),
                  tooltip: tr('Remove'),
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            final gone = lines.removeAt(i);
                            WidgetsBinding.instance.addPostFrameCallback((_) => _drop([gone]));
                            if (lines.isEmpty) lines.add(_Line());
                          }),
                  icon: const Icon(Icons.close_rounded, color: C.muted),
                ),
              ]),
            ),
          ),
        Row(children: [
          OutlinedButton.icon(key: const Key('mf-addl'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: busy ? null : () => setState(() => lines.add(_Line())), icon: const Icon(Icons.add_rounded), label: Text('+ Line')),
          const Spacer(),
          Text('Total ', style: const TextStyle(color: C.muted)),
          Text(rupees(_total), key: const Key('mf-total'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.greenDark)),
        ]),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: InfoLine(err, bad: true)),
        const SizedBox(height: 18),
        FilledButton(key: const Key('mf-save'), onPressed: busy || reading ? null : _save, child: Text(busy ? 'Saving…' : e == null ? 'Save bill' : 'Save changes')),
      ])),
    );
  }
}
