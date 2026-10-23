/* ONE REPORT (3.2.0) – the app's own screen for a report of the web: its filters (the same as the web page: dates, ownership,
 * vendor, rate, pump, location, machinery, months, source / shift / supply), "Generate report" (the same server report), the
 * report on the phone, and Excel / Print-PDF of it. The Debit Recovery Statement: the rates may be changed and saved, as on the web.
 * (3.31.7, Mechanical update-149) The Log Book Debit Statement: its party / machinery filters; the rates changed (one, or one for all
 * shown) and the party + rate of saved entries imported from Excel – the server's saveLogDebits, all or nothing, as on the web. */

import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/rdoc.dart';
import '../core/report_defs.dart';
import '../core/session.dart';
import '../ui/outputs.dart';
import '../ui/report_view.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart' show MachinePicker;
import '../ui/help.dart' show GuideButton;
import '../ui/ask_bot.dart';
import '../ui/pick_file.dart' show pickSheetFile;
import '../core/imports.dart' show readExcelRows, xlDate, Cols;
import '../core/sheet_read.dart' show jsS, readSheets;

Future<void> openReport(BuildContext context, ReportDef def, {String no = '', String owner = '', bool run = false}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReportScreen(def: def, no: no, owner: owner, run: run)));

/// The report of the web's page key ('rdaily', 'rp-ledger' …), null when it has no app screen yet.
ReportDef? reportOfPage(String page) {
  if (page == 'rdaily') return kDailyReport;
  if (page == 'rmonthly') return kMonthlyReport;
  if (page == 'ravg') return kAvgReport;
  if (page.startsWith('rp-')) {
    for (final d in kDieselReports) {
      if (d.key == page.substring(3)) return d;
    }
  }
  return null;
}

/// The server's filters of a report, from what is picked on the screen – as the web (rpFilters); a problem is said in words.
Map<String, dynamic> reportFilters(ReportDef def, ReportPick p) {
  final f = def.filters;
  final x = <String, dynamic>{};
  if (f.contains('range')) {
    if (p.from.isEmpty || p.to.isEmpty) throw ArgumentError('Select From and To dates.');
    x['from'] = p.from;
    x['to'] = p.to;
  }
  if (f.contains('vendor')) x['owner'] = p.owner.trim();
  if (f.contains('rate')) {
    x['rateMode'] = p.rateMode;
    x['fixedRate'] = p.fixedRate.trim();
  }
  if (f.contains('owns')) {
    if (p.owns.isEmpty) throw ArgumentError('Tick at least one Ownership.');
    x['ownerships'] = [for (final o in kOwns) if (p.owns.contains(o)) o];
  }
  if (f.contains('pump')) x['pump'] = p.pump.trim();
  if (f.contains('location') || f.contains('location1') || f.contains('dloc')) x['location'] = p.location;
  if (f.contains('machine')) {
    if (p.no.isEmpty) throw ArgumentError('Pick a machinery from Master.');
    x['no'] = p.no;
  }
  if (f.contains('party')) x['party'] = p.party.trim();      // (3.31.7) blank = all parties
  if (f.contains('machine0')) x['no'] = p.no.trim(); // blank = all machinery
  if (f.contains('months')) {
    x['monthA'] = p.monthA;
    x['monthB'] = p.monthB;
  }
  if (f.contains('monthly')) {
    if (p.pickSome && p.picked.isEmpty) throw ArgumentError('Select at least one machinery, or choose All machinery.');
    x['source'] = p.source;
    x['shift'] = p.shift;
    x['supply'] = p.supply;
    x['machines'] = p.pickSome ? (p.picked.toList()..sort()) : <String>[];
    x['includeZero'] = p.zero;
    x['withReadings'] = def.key == 'ravg';
  }
  return x;
}

/// What is picked on a report's screen.
class ReportPick {
  String from = '', to = '', owner = '', party = '', rateMode = 'last', fixedRate = '', pump = '', location = '', no = '', monthA = '', monthB = '';
  String source = '', shift = '', supply = '';
  bool zero = false, pickSome = false;
  final owns = {...kOwns};
  final picked = <String>{};

  /// The usual start: this month (the 1st to today); months: last month and this month; the first place for one location.
  void start(String today, List<String> locations, ReportDef def) {
    final t = DateTime.tryParse(today) ?? DateTime.now();
    from = '${today.length >= 8 ? today.substring(0, 8) : dateKey(t).substring(0, 8)}01';
    to = today.isEmpty ? dateKey(t) : today;
    final last = DateTime(t.year, t.month - 1, 1);
    monthA = '${last.year}-${last.month.toString().padLeft(2, '0')}';
    monthB = '${t.year}-${t.month.toString().padLeft(2, '0')}';
    if (def.filters.contains('location1') && locations.isNotEmpty) location = locations.first;
  }
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.def, this.no = '', this.owner = '', this.run = false});
  final ReportDef def;

  /// (3.14.0) opened for one machinery / owner and made at once (a scanned label's "Its diesel ledger", the search) – the web's gsLedger
  final String no, owner;
  final bool run;
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final p = ReportPick();
  final owner = TextEditingController(), fixed = TextEditingController(), pump = TextEditingController(), party = TextEditingController();
  List<String> parties = [];      // (3.31.7) the Vendor Master's parties, for "Debit to"
  RDoc? doc;
  Map<String, dynamic>? data;
  bool busy = false, open = true;
  String err = '', out = '';

  ReportDef get def => widget.def;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = SessionScope.read(context);
      setState(() {
        p.start(s.today, s.locations, def);
        if (widget.no.isNotEmpty) p.no = widget.no;
        if (widget.owner.isNotEmpty) owner.text = widget.owner;
      });
      if (widget.run) _go();
      if (def.filters.contains('party')) _parties(s);
    });
  }

  Future<void> _parties(Session s) async {
    try {
      final l = (await s.api.call('getLookups')) as Map;
      if (mounted) setState(() => parties = ((l['vendors'] as List?) ?? const []).map((e) => '$e').toList());
    } catch (_) {/* typed by hand then */}
  }

  @override
  void dispose() {
    owner.dispose();
    party.dispose();
    fixed.dispose();
    pump.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final s = SessionScope.read(context);
    p.owner = owner.text;
    p.party = party.text;
    p.fixedRate = fixed.text;
    p.pump = pump.text;
    Map<String, dynamic> f;
    try {
      f = reportFilters(def, p);
    } on ArgumentError catch (e) {
      setState(() => err = '${e.message}');
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final d = (await s.api.call(def.fn, [f]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        data = d;
        doc = def.build(d);
        open = false;
        busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        err = errText(e);
      });
    }
  }

  Future<void> _excel() async {
    final s = SessionScope.read(context), d = doc;
    if (d == null) return;
    setState(() => out = 'x');
    try {
      await shareDocXlsx(s, d);
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => out = '');
    }
  }

  Future<void> _pdf() async {
    final s = SessionScope.read(context), d = doc;
    if (d == null) return;
    setState(() => out = 'p');
    try {
      await printDoc(context, s, d, printed: '${data?['generated'] ?? whenText(DateTime.now().toIso8601String())}');
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => out = '');
    }
  }

  Future<void> _date(bool isFrom) async {
    final s = SessionScope.read(context);
    final last = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    final cur = isFrom ? p.from : p.to;
    final d = await showDatePicker(context: context, initialDate: cur.isEmpty ? last : parseKey(cur), firstDate: DateTime(2024), lastDate: last.add(const Duration(days: 1)));
    if (d == null) return;
    setState(() {
      if (isFrom) {
        p.from = dateKey(d);
      } else {
        p.to = dateKey(d);
      }
    });
  }

  Future<void> _month(bool isA) async {
    final s = SessionScope.read(context);
    final now = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    final cur = isA ? p.monthA : p.monthB;
    final d = await showDatePicker(context: context, initialDate: cur.length == 7 ? DateTime(int.parse(cur.substring(0, 4)), int.parse(cur.substring(5, 7))) : now, firstDate: DateTime(2024), lastDate: now, initialDatePickerMode: DatePickerMode.year);
    if (d == null) return;
    final v = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    setState(() {
      if (isA) {
        p.monthA = v;
      } else {
        p.monthB = v;
      }
    });
  }

  void _range(String w) {
    final s = SessionScope.read(context);
    final t = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    setState(() {
      if (w == 'yday') {
        final y = t.subtract(const Duration(days: 1));
        p.from = dateKey(y);
        p.to = dateKey(y);
      } else if (w == 'this') {
        p.from = '${dateKey(t).substring(0, 8)}01';
        p.to = dateKey(t);
      } else {
        p.from = dateKey(DateTime(t.year, t.month - 1, 1));
        p.to = dateKey(DateTime(t.year, t.month, 0));
      }
    });
  }

  Future<void> _pickMachine() async {
    final s = SessionScope.read(context);
    final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => MachinePicker(only: s.machines));
    if (m != null) setState(() => p.no = m.id);
  }

  Future<void> _pickMany() async {
    final s = SessionScope.read(context);
    final got = await showModalBottomSheet<Set<String>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _ManyPicker(machines: s.machines, picked: p.picked, owns: p.owns));
    if (got != null) {
      setState(() {
        p.picked
          ..clear()
          ..addAll(got);
      });
    }
  }

  Widget _box(String label, String value, VoidCallback onTap, {IconData icon = Icons.event_rounded}) => Press(
        onTap: onTap,
        radius: 16,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(children: [
          Icon(icon, color: C.blue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: C.muted)),
              Text(value.isEmpty ? '–' : value, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );

  Widget _drop(String label, String value, List<(String, String)> items, ValueChanged<String> on) => DropdownButtonFormField<String>(
        initialValue: items.any((x) => x.$1 == value) ? value : items.first.$1,
        isExpanded: true,
        decoration: InputDecoration(labelText: tr(label)),
        items: [for (final x in items) DropdownMenuItem(value: x.$1, child: Text(x.$2))],
        onChanged: (v) => on(v ?? ''),
      );

  List<Widget> _filters(Session s) {
    final f = def.filters;
    final kids = <Widget>[];
    void gap() => kids.add(const SizedBox(height: 10));
    if (f.contains('machine')) {
      kids.add(_box('Machinery Number / Name', p.no, _pickMachine, icon: Icons.precision_manufacturing_outlined));
      gap();
    }
    if (f.contains('party')) {
      kids.add(Autocomplete<String>(
        key: const Key('rep-party'),
        optionsBuilder: (v) => v.text.isEmpty ? parties : parties.where((x) => x.toLowerCase().contains(v.text.toLowerCase())),
        onSelected: (v) => party.text = v,
        fieldViewBuilder: (c, ctl, fn, _) => TextField(controller: ctl, focusNode: fn, onChanged: (v) => party.text = v, decoration: InputDecoration(labelText: tr('Party (Debit to)'), hintText: tr('Blank = all parties'))),
      ));
      gap();
    }
    if (f.contains('machine0')) {
      kids.add(Row(children: [
        Expanded(child: _box('Machinery', p.no.isEmpty ? tr('Blank = all machinery') : p.no, _pickMachine, icon: Icons.precision_manufacturing_outlined)),
        if (p.no.isNotEmpty) IconButton(key: const Key('rep-mno-clear'), tooltip: tr('All machinery'), onPressed: () => setState(() => p.no = ''), icon: const Icon(Icons.close_rounded)),
      ]));
      gap();
    }
    if (f.contains('location1')) {
      kids.add(_drop('Location', p.location, [for (final l in s.locations) (l, l)], (v) => setState(() => p.location = v)));
      gap();
    }
    if (f.contains('range')) {
      kids.add(Row(children: [Expanded(child: _box('From', showDate(p.from), () => _date(true))), const SizedBox(width: 8), Expanded(child: _box('To', showDate(p.to), () => _date(false)))]));
      kids.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(spacing: 6, children: [
          ActionChip(label: Text('Yesterday'), onPressed: () => _range('yday')),
          ActionChip(label: Text('This month'), onPressed: () => _range('this')),
          ActionChip(label: Text('Last month'), onPressed: () => _range('last')),
        ]),
      ));
      gap();
    }
    if (f.contains('months')) {
      kids.add(Row(children: [Expanded(child: _box('First month', p.monthA, () => _month(true), icon: Icons.calendar_month_rounded)), const SizedBox(width: 8), Expanded(child: _box('Second month', p.monthB, () => _month(false), icon: Icons.calendar_month_rounded))]));
      gap();
    }
    if (f.contains('dloc') || f.contains('location')) {
      kids.add(_drop(f.contains('dloc') ? 'Stock location' : 'Location', p.location, [('', f.contains('dloc') ? 'All locations' : 'All locations'), for (final l in s.locations) (l, l)], (v) => setState(() => p.location = v)));
      gap();
    }
    if (f.contains('monthly')) {
      kids.add(_drop('Diesel Source', p.source, [('', 'All'), for (final l in s.locations) (l, l)], (v) => setState(() => p.source = v)));
      gap();
      kids.add(Row(children: [
        Expanded(child: _drop('Shift', p.shift, const [('', 'All'), ('Day', 'Day'), ('Night', 'Night')], (v) => setState(() => p.shift = v))),
        const SizedBox(width: 8),
        Expanded(child: _drop('Diesel Supply', p.supply, const [('', 'All'), ('Company', 'Company'), ('Debit Basis', 'Debit Basis'), ('Other', 'Other')], (v) => setState(() => p.supply = v))),
      ]));
      gap();
    }
    if (f.contains('vendor')) {
      final vendors = {for (final m in s.machines) if (m.debit || m.ownership == 'Debit') m.owner}.where((e) => e.isNotEmpty).toList()..sort();
      kids.add(Autocomplete<String>(
        optionsBuilder: (v) => v.text.isEmpty ? vendors : vendors.where((x) => x.toLowerCase().contains(v.text.toLowerCase())),
        onSelected: (v) => owner.text = v,
        fieldViewBuilder: (c, ctl, fn, _) => TextField(controller: ctl, focusNode: fn, onChanged: (v) => owner.text = v, decoration: InputDecoration(labelText: tr('Vendor (Owner Name)'), hintText: tr('Blank = all vendors'))),
      ));
      gap();
    }
    if (f.contains('pump')) {
      kids.add(Autocomplete<String>(
        optionsBuilder: (v) => v.text.isEmpty ? s.pumps : s.pumps.where((x) => x.toLowerCase().contains(v.text.toLowerCase())),
        onSelected: (v) => pump.text = v,
        fieldViewBuilder: (c, ctl, fn, _) => TextField(controller: ctl, focusNode: fn, onChanged: (v) => pump.text = v, decoration: InputDecoration(labelText: tr('Pump'), hintText: tr('Blank = all pumps'))),
      ));
      gap();
    }
    if (f.contains('rate')) {
      kids.add(_drop('Diesel rate', p.rateMode, const [('last', 'Rate of the day'), ('avg', 'Weighted average (stock)'), ('fixed', 'Fixed rate')], (v) => setState(() => p.rateMode = v)));
      if (p.rateMode == 'fixed') {
        gap();
        kids.add(TextField(controller: fixed, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Fixed rate (₹/Ltr)'))));
      }
      gap();
    }
    if (f.contains('owns')) {
      kids.add(Text('Ownership', style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600)));
      kids.add(Wrap(spacing: 6, children: [
        for (final o in kOwns) FilterChip(label: Text(o), selected: p.owns.contains(o), onSelected: (v) => setState(() => v ? p.owns.add(o) : p.owns.remove(o))),
      ]));
      gap();
    }
    if (f.contains('monthly')) {
      kids.add(Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ChoiceChip(label: Text('All machinery'), selected: !p.pickSome, onSelected: (_) => setState(() => p.pickSome = false)),
        ChoiceChip(label: Text('Selected machinery${p.picked.isEmpty ? '' : ' (${p.picked.length})'}'), selected: p.pickSome, onSelected: (_) => setState(() => p.pickSome = true)),
        if (p.pickSome) TextButton(onPressed: _pickMany, child: Text('Pick')),
      ]));
      kids.add(CheckboxListTile(contentPadding: EdgeInsets.zero, value: p.zero, onChanged: (v) => setState(() => p.zero = v == true), title: Text('Show machinery with no diesel'), controlAffinity: ListTileControlAffinity.leading));
    }
    return kids;
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final d = doc;
    return Scaffold(
      appBar: AppBar(
        title: TwoLang(def.label, def.mr, size: 18, weight: FontWeight.w700),
        actions: withAsk([GuideButton(const ['rdaily', 'rmonthly', 'ravg'].contains(def.key) ? def.key : 'rp-${def.key}'), 
          if (d != null) IconButton(key: const Key('rep-xlsx'), tooltip: tr('Export to Excel'), onPressed: out.isEmpty ? _excel : null, icon: out == 'x' ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : const Icon(Icons.grid_on_rounded)),
          if (d != null) IconButton(key: const Key('rep-pdf'), tooltip: tr('Print'), onPressed: out.isEmpty ? _pdf : null, icon: out == 'p' ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : const Icon(Icons.print_rounded)),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        Text(def.note, style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
          child: Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              key: ValueKey('filters-$open'),
              initiallyExpanded: open,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(d == null ? 'Filters' : _summary(s), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                const SizedBox(height: 8), // the first box's label is not cut
                ..._filters(s),
                const SizedBox(height: 6),
                FilledButton.icon(
                  key: const Key('rep-go'),
                  onPressed: busy ? null : _go,
                  icon: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.play_arrow_rounded),
                  label: Text(busy ? 'Generating…' : 'Generate report'),
                ),
              ],
            ),
          ),
        ),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        if (d != null) ...[
          const SizedBox(height: 16),
          if (def.key == 'debit' && s.canEdit('Diesel Issue') && data != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(key: const Key('debit-rates'), onPressed: () => _rates(s), icon: const Icon(Icons.edit_rounded), label: const Text('Change rates')),
            ),
          if (def.key == 'ldebit' && s.canEdit('Log Book') && data != null)      // (3.31.7)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(key: const Key('ldebit-rates'), onPressed: () => _ldRates(s), icon: const Icon(Icons.edit_rounded), label: const Text('Change rates')),
                OutlinedButton.icon(key: const Key('ldebit-import'), onPressed: () => _ldImport(s), icon: const Icon(Icons.upload_file_rounded), label: const Text('Import party + rate (Excel)')),
              ]),
            ),
          ReportView(d),
        ],
      ]),
    );
  }

  String _summary(Session s) => [
        if (p.from.isNotEmpty && def.filters.contains('range')) '${showDate(p.from)} – ${showDate(p.to)}',
        if (def.filters.contains('months')) '${p.monthA} vs ${p.monthB}',
        if (p.no.isNotEmpty) p.no,
        if (p.location.isNotEmpty) p.location,
        if (def.filters.contains('owns') && p.owns.length < kOwns.length) p.owns.join(', '),
      ].join('  ·  ');

  /// (3.31.7) the Log Book Debit Statement: the rate of an entry (one, or one rate for all shown) – an entry in a Debit Note keeps its rate.
  Future<void> _ldRates(Session s) async {
    final rows = [for (final g in listOf(data?['parties'])) ...listOf(g['rows']).where((r) => '${r['note'] ?? ''}'.isEmpty)];
    if (rows.isEmpty) {
      toast(context, tr('No entry to change – every one shown is in a Debit Note.'), bad: true);
      return;
    }
    final changed = await showModalBottomSheet<List<Map<String, dynamic>>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _LdRates(rows: rows));
    if (changed == null || changed.isEmpty || !mounted) return;
    final who = {for (final r in rows) '${r['logId']}': '${r['no']} · ${dmy(r['date'])} · ${r['shift']}'};
    final was = {for (final r in rows) '${r['logId']}': r['rate']};
    await _ldSave(s, changed, 'report', 'Save ${changed.length} changed rate${changed.length == 1 ? '' : 's'}?', [for (final x in changed) '${who[x['logId']]}: ₹${money(was[x['logId']])} → ₹${money(x['rate'])}']);
  }

  /// (3.31.7) the party and rate of saved entries from an Excel file: Date, Shift, Machinery, Debit to, Rate.
  Future<void> _ldImport(Session s) async {
    final f = await pickSheetFile();
    if (f == null || !mounted) return;
    List<Map<String, dynamic>> rows;
    try {
      rows = ldImportRows(readExcelRows(readSheets(f.bytes), kLdCols, const ['date', 'no', 'rate']));
    } catch (e) {
      toast(context, tr(errText(e)), bad: true);
      return;
    }
    if (rows.isEmpty) {
      toast(context, tr('The file has no lines under its heading.'), bad: true);
      return;
    }
    await _ldSave(s, rows, 'import', 'Import ${rows.length} line${rows.length == 1 ? '' : 's'} – party and rate?',
        [for (final x in rows) 'Row ${x['line']}: ${x['no']} · ${showDate('${x['date']}')}${'${x['shift']}'.isEmpty ? '' : ' · ${x['shift']}'} → ${x.containsKey('to') ? x['to'] : '(its party)'} @ ₹${x['rate']}']);
  }

  Future<void> _ldSave(Session s, List<Map<String, dynamic>> rows, String from, String title, List<String> lines) async {
    if (!await askLines(context, title, [...lines.take(40), if (lines.length > 40) '… ${lines.length - 40} more'],
        note: 'Each one is checked as a change of its Log Book entry: the party in the Vendor Master, a rate above 0, the month open, a submitted bill (Super Admin only), not in a Debit Note. One that cannot be changed is said – then nothing is saved.', yes: 'Save')) return;
    try {
      final r = (await s.api.call('saveLogDebits', [{'rows': rows, 'from': from}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final n = asNum(r['count']) ?? 0, same = asNum(r['same']) ?? 0;
      toast(context, tr('$n entr${n == 1 ? 'y' : 'ies'} saved${same > 0 ? ', $same already as given' : ''}.'));
      s.dataTick.value++;
      await _go();
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  /// (as the web) the rate of any debit entry changed: only for recovering from the vendor; empty = the rate of the day again.
  Future<void> _rates(Session s) async {
    final rows = [for (final v in listOf(data?['vendors'])) ...listOf(v['rows'])];
    if (rows.isEmpty) return;
    final changed = await showModalBottomSheet<List<Map<String, dynamic>>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _DebitRates(rows: rows));
    if (changed == null || changed.isEmpty || !mounted) return;
    if (!await askLines(context, 'Save ${changed.length} changed rate${changed.length == 1 ? '' : 's'}?', [for (final x in changed) '${x['id']}: ${x['rate'] == '' ? 'back to rate of the day' : '₹${money(x['rate'])}'}'], yes: 'Save')) return;
    try {
      final r = (await s.api.call('saveDebitRates', [changed], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      toast(context, tr('${r['count']} rate${r['count'] == 1 ? '' : 's'} saved.'));
      await _go();
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }
}

/// (3.31.7) the Excel columns of the party + rate of Log Book entries – the web's LD_COLS.
final Cols kLdCols = [
  ('date', RegExp(r'^(date|entry date)$')),
  ('shift', RegExp(r'^shift$')),
  ('no', RegExp(r'^(machinery|machinery number|machinery no|machine|vehicle|vehicle no|asset)$')),
  ('to', RegExp(r'^(debit to|party|debit to \(party\)|party \(debit to\))$')),
  ('rate', RegExp(r'^(rate|debit rate|rate \(₹\)|rate \(rs\))$')),
];

/// The lines of a party + rate file for saveLogDebits (the web's rpldebit_file handler); the server checks each one.
List<Map<String, dynamic>> ldImportRows(List<Map<String, Object?>> x) {
  String t(Object? v) => v == null ? '' : jsS(v).trim(); // String(v) of the web: 1050, not 1050.0
  return [
    for (final r in x)
      {
        'line': '${r['line']}',
        'date': xlDate(r['date']),
        'shift': t(r['shift']),
        'no': t(r['no']),
        if (((r['_has'] as Map?) ?? const {}).containsKey('to') && t(r['to']).isNotEmpty) 'to': t(r['to']), // blank: the entry keeps its party
        'rate': t(r['rate']).replaceAll(RegExp(r'[,₹\s]'), ''),
      },
  ];
}

/// Several machinery picked for the monthly reports (within the ownerships ticked).
class _ManyPicker extends StatefulWidget {
  const _ManyPicker({required this.machines, required this.picked, required this.owns});
  final List<Machine> machines;
  final Set<String> picked, owns;
  @override
  State<_ManyPicker> createState() => _ManyPickerState();
}

class _ManyPickerState extends State<_ManyPicker> {
  late final sel = {...widget.picked};
  String q = '';
  @override
  Widget build(BuildContext context) {
    bool okOwn(Machine m) => widget.owns.contains(kOwns.contains(m.ownership) ? m.ownership : 'Other');
    final list = widget.machines.where((m) => okOwn(m) && (q.isEmpty || m.matches(q))).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * .86,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(child: TwoLang('Selected machinery (${sel.length})', 'निवडलेली यंत्रे', size: 18, weight: FontWeight.w700)),
            TextButton(onPressed: () => setState(() => sel.addAll(list.map((m) => m.id))), child: Text('All')),
            TextButton(onPressed: () => setState(sel.clear), child: Text('None')),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: tr('Number, name, type or owner'), prefixIcon: const Icon(Icons.search_rounded)))),
        Expanded(
          child: ListView(children: [
            for (final m in list)
              CheckboxListTile(
                value: sel.contains(m.id),
                onChanged: (v) => setState(() => v == true ? sel.add(m.id) : sel.remove(m.id)),
                title: Text(m.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([m.type, m.ownership].where((e) => e.isNotEmpty).join(', ')),
              ),
          ]),
        ),
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), child: FilledButton(onPressed: () => Navigator.pop(context, sel), child: Text('Use ${sel.length} machinery')))),
      ]),
    );
  }
}

/// The debit entries with their rates: change any; empty = the rate of the day.
class _DebitRates extends StatefulWidget {
  const _DebitRates({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  State<_DebitRates> createState() => _DebitRatesState();
}

class _DebitRatesState extends State<_DebitRates> {
  late final ctl = {for (final r in widget.rows) '${r['id']}': TextEditingController(text: blankV(r['rate']) ? '' : '${r['rate']}')};
  @override
  void dispose() {
    for (final c in ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _changed() => [
        for (final r in widget.rows)
          if (ctl['${r['id']}']!.text.trim() != (blankV(r['rate']) ? '' : '${r['rate']}'))
            {'id': '${r['id']}', 'rate': ctl['${r['id']}']!.text.trim().isEmpty || num.tryParse(ctl['${r['id']}']!.text.trim()) == nOf(r['autoRate']) ? '' : num.tryParse(ctl['${r['id']}']!.text.trim()) ?? ''},
      ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.of(context).size.height * .86,
        child: Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 4), child: Align(alignment: Alignment.centerLeft, child: TwoLang('Change rates', 'दर बदला', size: 18, weight: FontWeight.w700))),
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('A changed rate is only for recovering from the vendor. Purchase (Inward) rates, stock value and other reports do not change. Clear a rate to go back to the rate of the day.', style: TextStyle(fontSize: 12.5, color: C.muted))),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = widget.rows[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['id']} · ${r['no']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${dmy(r['date'])} · ${fmt(r['qty'])} L · rate of the day ₹${money(r['autoRate'])}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                      ]),
                    ),
                    SizedBox(width: 110, child: TextField(controller: ctl['${r['id']}'], keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixText: '₹ ', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)))),
                  ]),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: FilledButton(onPressed: _changed().isEmpty ? null : () => Navigator.pop(context, _changed()), child: Text('Save changed rates (${_changed().length})')),
            ),
          ),
        ]),
      );
}

/// (3.31.7) The Log Book entries charged to a party with their rates: change any, or one rate for all shown.
class _LdRates extends StatefulWidget {
  const _LdRates({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  State<_LdRates> createState() => _LdRatesState();
}

class _LdRatesState extends State<_LdRates> {
  late final ctl = {for (final r in widget.rows) '${r['logId']}': TextEditingController(text: blankV(r['rate']) ? '' : '${r['rate']}')};
  final all = TextEditingController();
  String err = '';
  @override
  void dispose() {
    for (final c in ctl.values) {
      c.dispose();
    }
    all.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _changed() => [
        for (final r in widget.rows)
          if (num.tryParse(ctl['${r['logId']}']!.text.trim()) != nOf(r['rate'])) {'logId': '${r['logId']}', 'rate': num.tryParse(ctl['${r['logId']}']!.text.trim()) ?? 0},
      ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.of(context).size.height * .86,
        child: Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 4), child: Align(alignment: Alignment.centerLeft, child: TwoLang('Change rates', 'दर बदला', size: 18, weight: FontWeight.w700))),
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('A changed rate is only for what the party pays (the Debit Note). The bills of the machinery are not changed. An entry already in a Debit Note keeps its rate (cancel that note first).', style: TextStyle(fontSize: 12.5, color: C.muted))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(child: TextField(key: const Key('ld-all'), controller: all, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Rate for all shown'), prefixText: '₹ '))),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('ld-apply'),
                onPressed: () => setState(() {
                  final v = num.tryParse(all.text.trim());
                  if (v == null || v <= 0) {
                    err = 'Type the rate first (more than 0).';
                    return;
                  }
                  err = '';
                  for (final c in ctl.values) {
                    c.text = all.text.trim();
                  }
                }),
                child: const Text('Put on all shown'),
              ),
            ]),
          ),
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 6), child: Text(err, style: const TextStyle(color: C.red, fontSize: 13))),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = widget.rows[i];
                final rate = num.tryParse(ctl['${r['logId']}']!.text.trim()) ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['no']} · ${dmy(r['date'])} · ${r['shift']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${fmt(r['qty'])} ${r['unit']} × ₹${money(rate)} = ₹${money(nOf(r['qty']) * rate)}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                      ]),
                    ),
                    SizedBox(width: 110, child: TextField(key: Key('ld-rate-$i'), controller: ctl['${r['logId']}'], keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixText: '₹ ', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)))),
                  ]),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: FilledButton(
                key: const Key('ld-save'),
                onPressed: _changed().isEmpty
                    ? null
                    : () {
                        final bad = _changed().where((x) => nOf(x['rate']) <= 0);
                        if (bad.isNotEmpty) {
                          setState(() => err = 'A rate must be more than 0.');
                          return;
                        }
                        Navigator.pop(context, _changed());
                      },
                child: Text('Save changed rates (${_changed().length})'),
              ),
            ),
          ),
        ]),
      );
}
