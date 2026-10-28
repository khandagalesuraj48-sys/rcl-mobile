/* (3.46.0, Mechanical update-165, asked 27-10-2026 – step 2 of HO: "Maintenance Log Book")
 * MAINTENANCE – the app's own screens of the web's page Maintenance, at a site on fuel cards (HO):
 *   MaintScreen – the bills of the dates (and of one car), newest first, their total; a bill opens with its lines, its files, Change,
 *                 Delete; "Car log book" – the car's Maintenance Log Book (report_defs.dart kMaintLog: screen, Excel, PDF).
 *   MaintForm   – one bill of a car: its date, car, garage, bill number, KM, Service (its KM is needed), remark; its lines (each work /
 *                 part with its ₹, a discount a minus line; the words typed before are offered); its files (PDF / photos, up to 10) –
 *                 "Read the bill (AI)" fills the empty boxes from the last file added (blue – the person checks every value).
 * The same server actions, checks and access as the web: getMaint, saveMaint, updateMaint, deleteMaint, maintFile, getMaintFiles,
 * readMaintBill, maintLog.
 * (3.49.0, Mechanical update-168, asked 27-10-2026 with 9 of his bills: "kahi material warranty madhe aste kahi paid aste kahi
 *  discount deun aste tr sagle kahi yeyla hawa ok and type pn krta yayla hawa") a line = its work / part, its KIND (Paid / Warranty /
 *  FOC / Service Plan), Qty, Rate, Disc % and ₹ (a Paid line: Qty × Rate − Discount, worked out as on the web; a free line: ₹ 0,
 *  its worth shown); an insurance claim: the company, the claim no., what the insurance paid – the car's cost is what WE paid. The
 *  AI reads every line with its kind, the car from the bill's number, the insurance.
 * (3.50.0, Mechanical update-170, asked 27-10-2026 with the Maintenance Log Book of Roller No-03: "mala log book as hawa aahe ya
 *  format madhe") at EVERY site, for every machinery: the party of a direct bill, the current reading (KM / Hrs), each line its Uom;
 *  the log book in his format (report_defs.dart kMaintLog).
 * (3.51.0, Mechanical update-171: "gst row madhe nko heading madhe ghe 9 9 18 … koni paid kel insurance claim aahe nahi service ch bill ahe
 *  ka") each line its GST % (one number – CGST and SGST half each, each rounded) and its Paid by: RCL ('Paid'), Insurance ('By
 *  Insurance' – its ₹ is the insurance's part of the bill), Warranty, FOC, Service Plan; the log book: the GST rates in its heading,
 *  Paid by, Insurance claim, Service on every line. */
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
import '../core/maint_import.dart' show MliSheet, mliRead, mliOwn, mliFormatXlsx;
import '../core/sheet_read.dart' show readSheets, SheetError;
import '../ui/pick_file.dart';
import '../ui/outputs.dart' show shareXlsx;
import 'attach_box.dart' show AttachStrip, AttViewer, pickAttFiles;
import 'maint_import.dart' show MaintImportScreen;
import 'forms.dart' show MachinePicker;
import 'fuel_cards.dart' show rupees;
import 'report_screen.dart' show openReport;

/// A bill keeps at most this many files (the server's MNT_FILES_MAX_)
const kMaintFilesMax = 10;

String _key(String v) => v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// (3.49.0) the kinds of a bill's line (the server's MNT_TYPES_): Paid is charged; the others are free (₹ 0)
/// (3.51.0) "Paid by": RCL ('Paid'), Insurance ('By Insurance' – charged, paid by the insurance), Warranty, FOC, Service Plan
const kMaintKinds = ['Paid', 'By Insurance', 'Warranty', 'FOC', 'Service Plan'];
const kMaintPaidBy = {'Paid': 'RCL', 'By Insurance': 'Insurance'};
String maintPaidBy(Object? t) => kMaintPaidBy['${t ?? ''}'.isEmpty ? 'Paid' : '$t'] ?? '$t';
bool maintCharged(Object? t) => '${t ?? ''}'.isEmpty || t == 'Paid' || t == 'By Insurance';

/// (3.51.0) a line's GST: its CGST and its SGST, each half its GST % and each rounded – as the bills print them (the server's maintGstOf_)
num maintGst(num? amount, num? gst) => 2 * (((amount ?? 0) * (gst ?? 0) / 200) * 100).round() / 100;

/// (3.50.0) the usual units of a line, offered (as the web's list): any other can be typed
const kMaintUoms = ['Nos', 'Ltr', 'Kg', 'Set', 'Bkt', 'Mtr', 'Pair', 'Gram', 'Box'];

bool _free(Map l) => !maintCharged(l['type']);

/// what a free line is worth: Qty × Rate (no Qty: 1) – as the web's mtWorth
num maintWorth(Map l) => _free(l) ? (asNum(l['qty']) ?? 1) * (asNum(l['rate']) ?? 0) : 0;

/// The lines of a bill as one short line: "Engine oil ₹1,200; Oil filter (Warranty)" – a free line with its kind (as the web's mtLinesText)
String maintLinesText(Object? lines) => [
      for (final l in (lines is List ? lines : const []).whereType<Map>())
        _free(l) ? '${l['work']} (${l['type']})' : '${l['work']} ₹${fmtNum((asNum(l['amount']) ?? 0) + maintGst(asNum(l['amount']), asNum(l['gst'])))}${l['type'] == 'By Insurance' ? ' (Insurance)' : ''}',
    ].join('; ');

/// (3.49.0) under a bill's ₹ (what we paid): the bill and the insurance of a claim, the worth of its free lines (as the web's mtBillNote)
List<String> maintBillNote(Map r) {
  final ins = r['insurance'] is Map ? r['insurance'] as Map : null, free = asNum(r['free']) ?? 0;
  return [
    if (ins != null) ...['bill ₹${fmtNum(asNum(r['billTotal']))}', 'insurance ₹${fmtNum(asNum(ins['paid']))}${'${ins['company'] ?? ''}'.isNotEmpty ? ' (${ins['company']})' : ''}'],
    if (free > 0) 'free worth ₹${fmtNum(free)}',
  ];
}

/// a number for a box: 2 decimals at most, no ".0"
String _n(num? v) => v == null ? '' : '${(v * 100).round() / 100}'.replaceAll(RegExp(r'\.0$'), '');

class MaintScreen extends StatefulWidget {
  const MaintScreen({super.key});
  @override
  State<MaintScreen> createState() => _MaintScreenState();
}

class _MaintScreenState extends State<MaintScreen> {
  bool loading = true, missing = false;
  /// (3.53.0, Mechanical update-175) the bills of every date ("Start to end")
  bool all = false;
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
      final r = (await s.api.call('getMaint', [{'from': all ? '' : from, 'to': all ? '' : to, 'no': no}]) as Map).cast<String, dynamic>();
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

  /// (3.53.0, Mechanical update-173) the old log book of the machinery imported as it is (the Admin) – the web's "Import the old log
  /// book (Excel or PDF)": its Excel, its PDF / a photo of a page (read by the AI on the import's screen), or the format to fill
  Future<void> _importChoice() async {
    final how = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: TwoLang('Import the old log book', 'जुनी log book import करा', size: 17, weight: FontWeight.w700)),
          ListTile(key: const Key('mti-excel'), leading: const Icon(Icons.grid_on_rounded, color: C.green), title: Text('Excel file'), subtitle: Text('A sheet a machinery'), onTap: () => Navigator.pop(c, 'excel')),
          ListTile(key: const Key('mti-pdf'), leading: const Icon(Icons.picture_as_pdf_rounded, color: C.red), title: Text('PDF – read by the AI'), subtitle: Text('Row by row'), onTap: () => Navigator.pop(c, 'pdf')),
          ListTile(key: const Key('mti-photo'), leading: const Icon(Icons.photo_rounded, color: C.blue), title: Text('Photo of a page – read by the AI'), onTap: () => Navigator.pop(c, 'photo')),
          ListTile(key: const Key('mti-fmt'), leading: const Icon(Icons.download_rounded, color: C.muted), title: Text('Download the format (Excel)'), subtitle: Text('A sheet for each Own machinery'), onTap: () => Navigator.pop(c, 'fmt')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (how == null || !mounted) return;
    final s = SessionScope.read(context);
    if (how == 'fmt') {
      final own = mliOwn([for (final m in s.machines) m.m], s.today);
      if (own.isEmpty) {
        toast(context, 'No Own machinery is on this site today (Asset Master) – the format has a sheet for each.', bad: true);
        return;
      }
      await shareXlsx(mliFormatXlsx(own, s.company), 'Old Maintenance Log Book – format.xlsx');
      return;
    }
    if (how == 'excel') return _importOld();
    final f = await pickAttFiles(how == 'pdf' ? 'pdf' : 'gallery', 1);
    if (f.isEmpty || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MaintImportScreen(name: f.first.name, file: f.first.bytes)));
    if (mounted) _load();
  }

  /// (3.53.0, Mechanical update-175, "fetch outward … dable ki systeam outward fetch krel"; his answer: "Store module चे Issue झाल्यावर") the
  /// log book read again with what the Store issued to the machinery – the Store's Issue is not built yet: said so; then its log book
  Future<void> _fetchOut() async {
    if (no.isEmpty) await _pickCar();
    if (no.isEmpty || !mounted) return;
    final s = SessionScope.read(context);
    try {
      final d = (await s.api.call('maintLog', [{'no': no, 'all': true}]) as Map).cast<String, dynamic>(), st = (d['store'] as Map?) ?? const {};
      if (!mounted) return;
      toast(context, st['on'] == true ? '${st['lines'] ?? 0} line(s) of the Store\'s outward in this log book.' : "The Store's Issue (material given to a machinery) is not built yet – there is no outward to fetch. When it is, what the Store gives to this machinery comes into its log book by itself.");
      await openReport(context, kMaintLog, no: no, run: true, all: true);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  Future<void> _importOld() async {
    final s = SessionScope.read(context);
    final f = await pickSheetFile();
    if (f == null || !mounted) return;
    List<MliSheet> sheets;
    try {
      sheets = mliRead(readSheets(f.bytes), [for (final m in s.machines) m.m], s.today);
    } on SheetError catch (e) {
      toast(context, e.message, bad: true);
      return;
    } catch (_) {
      toast(context, 'Could not read the file.', bad: true);
      return;
    }
    if (sheets.isEmpty) {
      toast(context, "No sheet of this file has the log book's heading (Date · Particulars · Qty · Amount …).", bad: true);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MaintImportScreen(name: f.name, sheets: sheets)));
    if (mounted) _load();
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
          Text('One bill of a machinery: each work / part with its kind, Qty, Uom, Rate, Discount and ₹. Add the bill (PDF or photo) – the AI can read it for you; check every value, then save.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
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
                Text('Maintenance Log Book', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.blue)),
                Text('Every bill of a machinery, line by line – party, reading, Qty, Uom, rate, GST', style: const TextStyle(fontSize: 12.5, color: C.muted)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: C.blue),
            ]),
          ),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('mt-out'), onPressed: _fetchOut, icon: const Icon(Icons.move_to_inbox_rounded, size: 18), label: Text('Fetch outward (Store)'))),
          if (can && !missing) ...[      // (3.53.0) the old log book's import; ("user la pn disu de") everyone with Maintenance Edit
            const SizedBox(height: 8),
            OutlinedButton.icon(key: const Key('mt-import'), onPressed: _importChoice, icon: const Icon(Icons.upload_file_rounded), label: Text('Import the old log book (Excel or PDF)')),
          ],
          FormHead('Maintenance bills', sub: '${all ? tr('Start to end') : '${showDate(from)} – ${showDate(to)}'} · $count · ${rupees(total)}'),
          Row(children: [
            Expanded(child: DateField(key: const Key('mt-from'), label: 'From', value: from, clear: false, enabled: !all, onChanged: (v) { setState(() => from = v); _load(); })),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('mt-to'), label: 'To', value: to, clear: false, enabled: !all, onChanged: (v) { setState(() => to = v); _load(); })),
          ]),
          // (3.53.0, Mechanical update-175) every bill – the whole log book can be changed and deleted
          Align(alignment: Alignment.centerLeft, child: FilterChip(key: const Key('mt-all'), label: Text('Start to end'), selected: all, onSelected: (v) { setState(() => all = v); _load(); })),
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
                Text('Machinery', style: const TextStyle(fontSize: 12, color: C.muted)),
                Text(no.isEmpty ? 'Blank = all machinery' : no, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: no.isEmpty ? C.faint : C.ink)),
              ])),
              if (no.isNotEmpty)
                IconButton(key: const Key('mt-car-x'), tooltip: tr('Clear'), onPressed: () { setState(() => no = ''); _load(); }, icon: const Icon(Icons.close_rounded, size: 18, color: C.muted)),
            ]),
          ),
          const SizedBox(height: 6),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          if (!loading && rows.isEmpty && err.isEmpty) const EmptyState('No maintenance bill in these dates.', 'A bill of a machinery: its work / parts and its ₹, with the bill PDF or photo.', pic: 'wrench'),
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
          if (maintBillNote(r).isNotEmpty) Text(maintBillNote(r).map(tr).join(' · '), key: Key('mt-note-${r['id']}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted)),
        ])),
        const SizedBox(width: 8),
        Text(rupees(asNum(r['total'])), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.greenDark)),      // (3.49.0: what we paid)
      ]),
    );
  }

  Future<void> _sheet(Map<String, dynamic> r, bool can) async {
    final files = (r['files'] as List? ?? const []).length;
    final lines = [for (final l in (r['lines'] as List? ?? const []).whereType<Map>()) l];
    final ins = r['insurance'] is Map ? r['insurance'] as Map : null;
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (bc) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(bc).size.height * .85),
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${r['id']} · ${rupees(asNum(r['total']))}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            InfoRow('Machinery', '${r['no']}'),
            InfoRow('Date', showDate('${r['date']}')),
            InfoRow('Party', '${r['garage'] ?? ''}'),
            InfoRow('Bill no.', '${r['billNo'] ?? ''}'),
            InfoRow('Reading', _blank(r['km']) ? '' : fmtNum(asNum(r['km']))),
            InfoRow('Service', r['service'] == true ? tr('Yes') : ''),
            InfoRow('Remark', '${r['remark'] ?? ''}'),
            InfoRow('Entered by', '${r['enteredBy'] ?? ''}'),
            FormHead('Work / parts'),
            for (final l in lines)
              _free(l)
                  ? InfoRow('${l['work']}', '${tr('${l['type']}')} · ${tr('worth ₹${fmtNum(maintWorth(l))}')}', tone: C.greenDark)
                  : InfoRow('${l['work']}', [rupees((asNum(l['amount']) ?? 0) + maintGst(asNum(l['amount']), asNum(l['gst']))), if (!_blank(l['qty']) && !_blank(l['rate'])) '${fmtNum(asNum(l['qty']))}${_blank(l['uom']) ? '' : ' ${l['uom']}'} × ${fmtNum(asNum(l['rate']))}${(asNum(l['disc']) ?? 0) > 0 ? ' − ${fmtNum(asNum(l['disc']))} %' : ''}', if ((asNum(l['gst']) ?? 0) > 0) 'GST ${fmtNum(asNum(l['gst']))} %', tr(maintPaidBy(l['type']))].join(' · '),
                      tone: (asNum(l['amount']) ?? 0) < 0 ? C.red : C.ink),
            if (ins != null) ...[
              InfoRow('Bill total', rupees(asNum(r['billTotal']))),
              InfoRow('Paid by the insurance', '− ${rupees(asNum(ins['paid']))}${'${ins['company'] ?? ''}'.isNotEmpty ? ' · ${ins['company']}' : ''}${'${ins['claimNo'] ?? ''}'.isNotEmpty ? ' · ${tr('Claim no.')} ${ins['claimNo']}' : ''}'),
              InfoRow('We paid', rupees(asNum(r['total'])), bold: true, tone: C.greenDark),
            ] else
              InfoRow('Total', rupees(asNum(r['total'])), bold: true, tone: C.greenDark),
            if ((asNum(r['free']) ?? 0) > 0) InfoRow('Free lines worth', rupees(asNum(r['free'])), tone: C.greenDark),
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

/// One line of the bill being typed: its work / part, its kind, Qty, Rate, Disc % and ₹; [ai] = read by the AI (blue) until the
/// person changes it
class _Line {
  _Line({String work = '', this.type = 'Paid', String qty = '', String uom = '', String rate = '', String disc = '', String amount = '', String gst = '', this.ai = false})
      : gst = TextEditingController(text: gst),
        work = TextEditingController(text: work),
        qty = TextEditingController(text: qty),
        uom = TextEditingController(text: uom),
        rate = TextEditingController(text: rate),
        disc = TextEditingController(text: disc),
        amount = TextEditingController(text: amount);
  /// a line of the server (a line of before has no kind: Paid)
  factory _Line.of(Map l, {bool ai = false}) {
    final t = kMaintKinds.contains(l['type']) ? '${l['type']}' : 'Paid';
    return _Line(work: '${l['work'] ?? ''}', type: t, qty: _n(asNum(l['qty'])), uom: _blank(l['uom']) ? '' : '${l['uom']}', rate: _n(asNum(l['rate'])), disc: _n(asNum(l['disc'])), gst: _n(asNum(l['gst'])), amount: maintCharged(t) ? _n(asNum(l['amount'])) : '0', ai: ai);
  }
  final TextEditingController work, qty, uom, rate, disc, amount, gst;
  String type;
  bool ai;
  bool get free => !maintCharged(type);
  /// (3.51.0) its GST ₹ and its amount with GST (a free line: 0)
  num get gstAmt => free ? 0 : maintGst(_of(amount), _of(gst));
  num get withGst => free ? 0 : (_of(amount) ?? 0) + gstAmt;
  bool get empty => work.text.trim().isEmpty && amount.text.trim().isEmpty && qty.text.trim().isEmpty && rate.text.trim().isEmpty && uom.text.trim().isEmpty;
  static num? _of(TextEditingController c) => asNum(c.text.replaceAll(',', ''));
  num get worth => free ? (_of(qty) ?? 1) * (_of(rate) ?? 0) : 0;
  /// a Paid line: its ₹ from Qty × Rate − Disc % (when Qty and Rate are there); a free line: ₹ 0 (as the web's mtRowCalc)
  void calc() {
    if (free) {
      amount.text = '0';
      return;
    }
    final q = _of(qty), r = _of(rate);
    if (q != null && r != null) {
      amount.text = _n(q * r * (1 - (_of(disc) ?? 0) / 100));
    } else if (amount.text == '0') {
      amount.text = '';      // (back to Paid from a free kind: its ₹ to be typed)
    }
  }
  Map<String, Object> get value {
    Object v(TextEditingController c) => _of(c) ?? c.text.trim();
    return {'work': work.text.trim(), 'type': type, 'qty': v(qty), 'uom': uom.text.trim(), 'rate': v(rate), 'disc': v(disc), 'amount': free ? 0 : v(amount), 'gst': v(gst)};
  }
  void dispose() {
    for (final c in [work, qty, uom, rate, disc, amount, gst]) {
      c.dispose();
    }
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
  final insCo = TextEditingController(), insClaim = TextEditingController(), insPaid = TextEditingController();
  final lines = <_Line>[];
  final files = <AttFile>[];
  final ai = <String>{};      // the boxes the AI filled (blue): date, car, garage, billNo, km, service, insurance
  String date = '', err = '', readMsg = '';
  bool service = false, busy = false, reading = false, dateTyped = false, _started = false;
  bool ins = false;      // (3.49.0) an insurance claim
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
        lines.add(_Line.of(l));
      }
      _insPut(e['insurance']);
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
    for (final c in [garage, billNo, km, remark, insCo, insClaim, insPaid]) {
      c.dispose();
    }
    for (final l in lines) {
      l.dispose();
    }
    super.dispose();
  }

  List<Map<String, Object>> get _typed => [for (final l in lines) if (!l.empty) l.value];
  /// the bill's total: its Paid lines; what its free lines are worth; what we paid (the bill less the insurance's part)
  num get _total => lines.fold<num>(0, (t, l) => t + l.withGst);      // (3.51.0) with the GST of its lines
  /// (3.51.0) the lines paid by the insurance: the insurance's part of the bill (with their GST) – the claim on, its ₹ not typed
  num get _byIns => lines.fold<num>(0, (t, l) => t + (l.type == 'By Insurance' ? l.withGst : 0));
  num get _freeWorth => lines.fold<num>(0, (t, l) => t + (l.work.text.trim().isEmpty ? 0 : l.worth));
  num get _wePaid => _total - (ins ? (asNum(insPaid.text.replaceAll(',', '')) ?? 0) : 0);

  /// (3.51.0) lines paid by the insurance: the claim is on and "Paid by the insurance" is theirs, not typed (as the web's mtTotal) –
  /// called after every change of the lines
  void _syncIns() {
    final b = _byIns;
    if (b <= 0) return;
    ins = true;
    final t = _n(b);
    if (insPaid.text != t) insPaid.text = t;
  }

  /// the insurance part of a bill into the boxes (null: none)
  void _insPut(Object? x) {
    final m = x is Map ? x : null;
    ins = m != null;
    insCo.text = '${m?['company'] ?? ''}';
    insClaim.text = '${m?['claimNo'] ?? ''}';
    insPaid.text = m == null ? '' : _n(asNum(m['paid']));
  }

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
        // (3.49.0) the car of the bill's number, when it is in the Asset Master and none is picked yet
        final vm = '${r['vehicle'] ?? ''}'.isEmpty ? null : s.machine('${r['vehicle']}');
        if (vm != null && car == null) {
          car = vm;
          ai.add('car');
          n++;
        }
        // an insurance claim: the company, the claim no., what it paid (blue – check it with the insurance's papers)
        final ri = r['insurance'] is Map ? r['insurance'] as Map : null;
        if (ri != null && '${ri['company'] ?? ''}'.isNotEmpty && !ins) {
          _insPut(ri);
          ai.addAll(['ins', 'insco', if (insClaim.text.isNotEmpty) 'insclaim', if (insPaid.text.isNotEmpty) 'inspaid']);
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
            ..addAll([for (final l in got) _Line.of(l, ai: true)]);
          n += got.length;
          _syncIns();
        });
      }
      final v = '${r['vehicle'] ?? ''}', c = car;
      final carNote = v.isNotEmpty && c != null && _key(v) != _key(c.id) ? ' ${tr('The bill says the vehicle $v – check the car.')}'
          : v.isNotEmpty && c == null ? ' ${tr('The bill says the vehicle $v – it is not in the Asset Master: pick the car.')}' : '';
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
    if (m != null && mounted) {
      setState(() {
        car = m;
        ai.remove('car');
      });
    }
  }

  Future<void> _save({bool force = false}) async {
    final s = SessionScope.read(context), e = widget.edit, c = car;
    if (c == null) {
      setState(() => err = 'Pick the machinery of the bill.');
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
      final x = <String, Object?>{
        'date': date, 'no': c.id, 'garage': garage.text.trim(), 'billNo': billNo.text.trim(), 'km': asNum(km.text.replaceAll(',', '')) ?? '', 'service': service, 'remark': remark.text.trim(),
        'lines': _typed, 'files': [for (final f in files) f.ref],
        'insurance': ins ? {'company': insCo.text.trim(), 'claimNo': insClaim.text.trim(), 'paid': asNum(insPaid.text.replaceAll(',', '')) ?? insPaid.text.trim()} : null,      // (3.49.0)
        if (force) 'force': true,
      };
      final r = (await (e == null ? s.api.call('saveMaint', [x], true) : s.api.call('updateMaint', ['${e['id']}', x], true)) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (r['ok'] == false && '${r['warning'] ?? ''}'.isNotEmpty) {
        setState(() => busy = false);
        if (await ask(context, 'Saved before?', '${r['warning']}', yes: 'Save again')) await _save(force: true);
        return;
      }
      final paid = asNum(r['total']), bill = asNum(r['billTotal']);
      toast(context, '${tr(e == null ? 'Bill ${r['id']} saved – ${rupees(paid)}.' : 'Bill ${r['id']} saved.')}${bill != null && bill != paid ? ' ${tr('(We paid ₹${fmtNum(paid)} of ₹${fmtNum(bill)}.)')}' : ''}');
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

  /// (3.49.0) one line of the bill: its work / part (×), its kind, then Qty · Rate · Disc % · ₹ – a free line: ₹ 0 and its worth (green)
  Widget _lineCard(int i, _Line l) {
    void typed() => setState(() {
          l.ai = false;
          l.calc();
          _syncIns();
        });
    const nkb = TextInputType.numberWithOptions(decimal: true);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
      decoration: BoxDecoration(color: l.free ? C.greenSoft : l.type == 'By Insurance' ? const Color(0xFFEFF6FF) : null, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: TextBox(key: Key('mf-w-$i'), label: 'Work / part', controller: l.work, options: widget.works, hint: 'e.g. Engine oil, Air filter, Labour', onChanged: (_) => setState(() => l.ai = false))),
          IconButton(
            key: Key('mf-x-$i'),
            tooltip: tr('Remove'),
            onPressed: busy
                ? null
                : () => setState(() {
                      final gone = lines.removeAt(i);
                      WidgetsBinding.instance.addPostFrameCallback((_) => _drop([gone]));
                      if (lines.isEmpty) lines.add(_Line());
                      _syncIns();
                    }),
            icon: const Icon(Icons.close_rounded, color: C.muted),
          ),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          // (3.51.0) who paid it: RCL, Insurance, Warranty, FOC, Service Plan (the kinds kept in English)
          child: PickField(key: Key('mf-t-$i'), label: 'Paid by', value: l.type, items: kMaintKinds, labels: kMaintPaidBy, enabled: !busy, onChanged: (v) => setState(() {
                l.type = v.isEmpty ? 'Paid' : v;
                l.ai = false;
                l.calc();
                _syncIns();
              })),
        ),
        const SizedBox(height: 8),
        // two boxes a row – a phone's width keeps every name and number whole (4.5, 100, 18000)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(children: [
            Expanded(child: TextBox(key: Key('mf-q-$i'), label: 'Qty', controller: l.qty, kb: nkb, onChanged: (_) => typed())),
            const SizedBox(width: 8),
            // (3.50.0, update-170) its unit – the usual ones offered
            Expanded(child: TextBox(key: Key('mf-u-$i'), label: 'Uom', controller: l.uom, options: kMaintUoms, onChanged: (_) => setState(() => l.ai = false))),
          ]),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(children: [
            Expanded(child: TextBox(key: Key('mf-r-$i'), label: 'Rate (₹)', controller: l.rate, kb: nkb, onChanged: (_) => typed())),
            const SizedBox(width: 8),
            Expanded(child: TextBox(key: Key('mf-d-$i'), label: 'Disc %', controller: l.disc, kb: nkb, onChanged: (_) => typed())),
          ]),
        ),
        const SizedBox(height: 8),
        // (3.51.0) its ₹ before GST and its GST % (CGST and SGST half each)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(children: [
            Expanded(child: TextBox(key: Key('mf-a-$i'), label: 'Amount (₹)', controller: l.amount, enabled: !l.free, kb: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {
                  l.ai = false;
                  _syncIns();
                }))),
            const SizedBox(width: 8),
            Expanded(child: TextBox(key: Key('mf-g-$i'), label: 'GST %', controller: l.gst, enabled: !l.free, kb: nkb, onChanged: (_) => setState(() {
                  l.ai = false;
                  _syncIns();
                }))),
          ]),
        ),
        if (!l.free && l.amount.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Text('${l.gstAmt != 0 ? '${tr('GST')} ₹${fmtNum(l.gstAmt)} · ' : ''}${tr('With GST')} ₹${fmtNum(l.withGst)}', key: Key('mf-gv-$i'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
          ),
        if (l.free)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Text(l.worth > 0 ? 'worth ₹${fmtNum(l.worth)}' : 'free', key: Key('mf-worth-$i'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: C.greenDark, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

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
        _blue(
          ai.contains('car'),
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
                Text('${tr('Machinery')} *', style: const TextStyle(fontSize: 12, color: C.muted)),
                Text(car == null ? 'Pick the machinery of the bill.' : [car!.id, if (car!.name.isNotEmpty && car!.name != car!.id) car!.name].join(' · '), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: car == null ? C.faint : C.ink)),
              ])),
              const Icon(Icons.expand_more_rounded, color: C.muted),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        _blue(ai.contains('garage'), TextBox(key: const Key('mf-garage'), label: 'Party name', controller: garage, options: widget.garages, hint: 'e.g. East West Energy Systems', onChanged: (_) => setState(() => ai.remove('garage')))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _blue(ai.contains('billNo'), TextBox(key: const Key('mf-billno'), label: 'Bill number', controller: billNo, onChanged: (_) => setState(() => ai.remove('billNo'))))),
          const SizedBox(width: 8),
          Expanded(child: _blue(ai.contains('km'), TextBox(key: const Key('mf-km'), label: 'Current reading', controller: km, hint: '(KM / Hrs)', kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() => ai.remove('km'))))),
        ]),
        _blue(
          ai.contains('service'),
          SwitchListTile(
            key: const Key('mf-service'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text('This bill is a service', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('(its reading is needed)'),
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
        FormHead('Work / parts of the bill', sub: 'Amount = Qty × Rate − Discount, before GST. GST % of each item (CGST and SGST half each) – no tax lines; the round-off is a line of its own; a discount on the whole bill is a minus amount. Paid by: RCL (we paid), Insurance (the insurance paid it), Warranty / FOC / Service Plan (not paid, ₹ 0).'),
        for (final (i, l) in lines.indexed) Padding(padding: const EdgeInsets.only(bottom: 10), child: _blue(l.ai, _lineCard(i, l))),
        Row(children: [
          OutlinedButton.icon(key: const Key('mf-addl'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: busy ? null : () => setState(() => lines.add(_Line())), icon: const Icon(Icons.add_rounded), label: Text('+ Line')),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Bill total', style: const TextStyle(fontSize: 12, color: C.muted)),
            Text(rupees(_total), key: const Key('mf-total'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.greenDark)),
          ]),
        ]),
        if (_freeWorth > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Expanded(child: Text('Free lines (warranty / FOC / service plan) – not paid, worth', style: const TextStyle(fontSize: 12.5, color: C.greenDark))),
              Text(rupees(_freeWorth), key: const Key('mf-free'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.greenDark)),
            ]),
          ),
        // (3.49.0) an insurance claim: the whole bill above, what the insurance paid, we paid the rest (the car's cost)
        const SizedBox(height: 10),
        _blue(
          ai.contains('ins'),
          SwitchListTile(
            key: const Key('mf-ins'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text('Insurance claim', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('– the insurance paid part of this bill'),
            value: ins,
            onChanged: busy || _byIns > 0      // (3.51.0) lines paid by the insurance: the claim stays on
                ? null
                : (v) => setState(() {
                      ins = v;
                      ai.remove('ins');
                    }),
          ),
        ),
        if (ins) ...[
          const SizedBox(height: 8),
          _blue(ai.contains('insco'), TextBox(key: const Key('mf-insco'), label: 'Insurance company', controller: insCo, hint: 'e.g. Tata AIG General Insurance', onChanged: (_) => setState(() => ai.remove('insco')))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _blue(ai.contains('insclaim'), TextBox(key: const Key('mf-insclaim'), label: 'Claim no.', controller: insClaim, onChanged: (_) => setState(() => ai.remove('insclaim'))))),
            const SizedBox(width: 8),
            Expanded(child: _blue(ai.contains('inspaid'), TextBox(key: const Key('mf-inspaid'), label: 'Paid by the insurance (₹)', controller: insPaid, enabled: _byIns <= 0, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() => ai.remove('inspaid'))))),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('We paid (₹)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text("– the car's cost", style: const TextStyle(fontSize: 12.5, color: C.muted)),
              ])),
              Text(rupees(_wePaid), key: const Key('mf-wepaid'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _wePaid < 0 ? C.red : C.greenDark)),
            ]),
          ),
        ],
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: InfoLine(err, bad: true)),
        const SizedBox(height: 18),
        FilledButton(key: const Key('mf-save'), onPressed: busy || reading ? null : _save, child: Text(busy ? 'Saving…' : e == null ? 'Save bill' : 'Save changes')),
      ])),
    );
  }
}
