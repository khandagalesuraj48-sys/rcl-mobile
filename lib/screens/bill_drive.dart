/* RCL DRIVE – the app's own screen (3.8.0) of the web's RCL Drive: everything that was submitted, shown exactly as it was saved.
 * Saved Bills (View / Print with the Log Book, the Log Book alone, Delete – Admin, with the reason) and Saved Debit Notes (the
 * notes made from the Log Book – View / Print, Cancel by Admin – and the diesel debit note of every bill); + New Debit Note: work
 * charged to a party in "Debit to" of the Log Book, the lines corrected or added by hand, GST / TDS, saved with the next number.
 * Server: getBills, getDebitNotes, deleteBill, cancelDebitNote, getLookups (the parties), getDebitPending, saveDebitNote. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../core/bill_reports.dart';
import '../core/format.dart';
import '../core/lb_print.dart' show n2;
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'bill_print.dart';

const kNoteNames = ['Rachana Construction Limited', 'Sketchline Industries'];

class DriveScreen extends StatefulWidget {
  const DriveScreen({super.key});
  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  String from = '', to = '', vendor = '', co = '', err = '';
  List<String> vendors = [];
  List<Map<String, dynamic>> bills = [], notes = [];
  bool loading = true, started = false;
  int _seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vendors();
      _load();
    });
  }

  Future<void> _vendors() async {
    final s = SessionScope.read(context);
    try {
      final d = (await s.api.call('billInit')) as Map;
      if (!mounted) return;
      setState(() => vendors = [for (final v in (d['vendors'] as List? ?? const []).whereType<Map>()) '${v['name']}']);
    } catch (_) {/* the list stays "All vendors" */}
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    setState(() => loading = true);
    final f = {'from': from, 'to': to, 'vendor': vendor, 'company': co};
    try {
      final d = (await s.api.call('getBills', [f])) as Map;
      var n = <Map<String, dynamic>>[];
      try {
        n = maps(((await s.api.call('getDebitNotes', [f])) as Map)['notes']);
      } catch (_) {/* an empty list until their table is there */}
      if (my != _seq || !mounted) return;
      setState(() {
        bills = maps(d['bills']);
        notes = n;
        loading = false;
        err = '';
      });
    } catch (e) {
      if (my != _seq || !mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  void _range(String k) {
    final s = SessionScope.read(context), t = parseKey(s.today.isNotEmpty ? s.today : dateKey(DateTime.now()));
    setState(() {
      if (k == 'this') {
        from = dateKey(DateTime(t.year, t.month, 1));
        to = dateKey(t);
      } else {
        from = dateKey(DateTime(t.year, t.month - 1, 1));
        to = dateKey(DateTime(t.year, t.month, 0));
      }
    });
    _load();
  }

  Future<void> _delete(Map b) async {
    final s = SessionScope.read(context);
    final why = await askNote(context, 'Delete this bill?', body: [Text('Only Admin can delete a submitted bill. Write the reason:')], label: 'Reason', ok: 'Delete', danger: true, needed: false);
    if (why == null || !mounted) return;
    try {
      await s.api.call('deleteBill', [b['id'], why], true);
      if (!mounted) return;
      toast(context, 'Bill deleted.');
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: !isSent(e));
    }
  }

  Future<void> _cancel(Map n) async {
    final s = SessionScope.read(context);
    if (!await ask(context, 'Cancel this debit note?', 'The note stays in the list as Cancelled, leaves the Vendor Ledger, and its Log Book entries can be put in a new note. Its number is not used again.', yes: 'Cancel the note', danger: true)) return;
    if (!mounted) return;
    try {
      final r = (await s.api.call('cancelDebitNote', [n['id']], true)) as Map?;
      if (!mounted) return;
      toast(context, 'Debit note ${r?['no'] ?? n['no']} cancelled.');
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: !isSent(e));
    }
  }

  Future<void> _newNote() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const DebitNoteScreen()));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const TwoLang('RCL Drive', 'RCL ड्राइव्ह', size: 20, weight: FontWeight.w700),
          actions: [IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
          bottom: TabBar(labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5), tabs: [
            Tab(key: const Key('drv-bills'), child: Text('Saved Bills')),
            Tab(key: const Key('drv-dn'), child: Text('Saved Debit Notes')),
          ]),
        ),
        body: Column(children: [
          _filters(s),
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: InfoLine(err, bad: true)),
          Expanded(
            child: loading && bills.isEmpty && notes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [_bills(s), _notes(s)]),
          ),
        ]),
      ),
    );
  }

  Widget _filters(Session s) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Column(children: [
          Row(children: [
            Expanded(child: DateField(key: const Key('sb-from'), label: 'Period from', value: from, onChanged: (v) {
              setState(() => from = v);
              _load();
            })),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('sb-to'), label: 'Period to', value: to, onChanged: (v) {
              setState(() => to = v);
              _load();
            })),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: PickField(key: const Key('sb-vendor'), label: 'Vendor', value: vendor, items: vendors, blank: 'All vendors', onChanged: (v) {
              setState(() => vendor = v);
              _load();
            })),
            const SizedBox(width: 8),
            Expanded(child: PickField(key: const Key('sb-co'), label: 'Name on the bill', value: co, items: const ['Sketchline Industries', 'Rachana Construction Limited'], blank: 'Both', onChanged: (v) {
              setState(() => co = v);
              _load();
            })),
          ]),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ActionChip(key: const Key('sb-this'), label: Text('This month'), onPressed: () => _range('this')),
              const SizedBox(width: 6),
              ActionChip(key: const Key('sb-last'), label: Text('Last month'), onPressed: () => _range('last')),
              const SizedBox(width: 6),
              ActionChip(
                key: const Key('sb-clear'),
                label: Text('Clear'),
                onPressed: () {
                  setState(() => from = to = vendor = co = '');
                  _load();
                },
              ),
            ]),
          ),
        ]),
      );

  Widget _bills(Session s) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('sb-list'), padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
          Text('Everything that was submitted – shown exactly as it was saved: the Abstract, the Tax Invoice and the Debit Note of every bill.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 8),
          if (bills.isEmpty && !loading) Padding(padding: const EdgeInsets.all(20), child: Text('No submitted bills for these filters.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
          for (final b in bills) _billTile(s, b),
        ]),
      );

  Widget _billTile(Session s, Map<String, dynamic> b) {
    final old = b['status'] == 'Superseded', rev = num.tryParse('${b['rev'] ?? 0}') ?? 0;
    return Container(
      key: Key('sb-${b['id']}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: old ? C.slateSoft : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RA Bill ${b['billNo']}${rev != 0 ? ' rev ${b['rev']}' : ''} · ${b['vendor']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, decoration: old ? TextDecoration.lineThrough : null)),
              Text('${b['company']}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
              Text('${showDate('${b['from']}')} – ${showDate('${b['to']}')} · dated ${showDate('${b['billDate']}')}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
              Text('Submitted by ${'${b['enteredBy'] ?? ''}'.isNotEmpty ? b['enteredBy'] : '–'}', style: const TextStyle(fontSize: 12, color: C.faint)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${n2(b['net'])}', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            old ? Pill('Superseded', color: C.amber, bg: C.amberSoft) : Pill('Active', color: C.greenDark, bg: C.greenSoft),
          ]),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          OutlinedButton.icon(key: Key('sbv-${b['id']}'), onPressed: () => viewSavedBill(context, s, '${b['id']}'), icon: const Icon(Icons.print_rounded), label: Text('View / Print')),
          OutlinedButton.icon(key: Key('sbl-${b['id']}'), onPressed: () => printSavedBillLog(context, s, '${b['id']}'), icon: const Icon(Icons.menu_book_rounded), label: Text('Log Book')),
          if (s.admin) OutlinedButton.icon(key: Key('sbd-${b['id']}'), onPressed: () => _delete(b), icon: const Icon(Icons.delete_outline_rounded, color: C.red), label: Text('Delete')),
        ]),
      ]),
    );
  }

  Widget _notes(Session s) {
    final dnBills = bills.where((b) => (num.tryParse('${b['dnAmt'] ?? 0}') ?? 0) > 0).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(key: const Key('dn-list'), padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(key: const Key('dn-open'), style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: s.canEdit('Machinery Billing') ? _newNote : null, icon: const Icon(Icons.add_rounded), label: Text('New Debit Note')),
        ),
        const SizedBox(height: 4),
        Text('For work charged to a party: pick the party in "Debit to" of the Log Book entry (with the rate), then make the note here.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        const SizedBox(height: 8),
        if (notes.isEmpty && dnBills.isEmpty && !loading) Padding(padding: const EdgeInsets.all(20), child: Text('No debit notes for these filters.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
        for (final n in notes) _noteTile(s, n),
        for (final b in dnBills) _dieselTile(s, b),
      ]),
    );
  }

  Widget _noteTile(Session s, Map<String, dynamic> n) {
    final off = n['status'] == 'Cancelled', billed = '${n['billNo'] ?? ''}'.isNotEmpty;
    return Container(
      key: Key('dnn-${n['id']}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: off ? C.slateSoft : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${n['no']} · ${n['vendor']}', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, decoration: off ? TextDecoration.lineThrough : null)),
              Text('${showDate('${n['date']}')} · ${n['company']} · ${n['kind']}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
              Text('Against RA Bill ${billed ? n['billNo'] : '–'} · ${'${n['from'] ?? ''}'.isNotEmpty ? '${showDate('${n['from']}')} – ${showDate('${'${n['to'] ?? ''}'.isNotEmpty ? n['to'] : n['from']}')}' : '–'}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${n2(n['total'])}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            off ? Pill('Cancelled', color: C.amber, bg: C.amberSoft) : Pill(billed ? 'Deducted in RA Bill ${n['billNo']}' : 'In the Vendor Ledger', color: C.greenDark, bg: C.greenSoft),
          ]),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          OutlinedButton.icon(key: Key('dnv-${n['id']}'), onPressed: () => viewDebitNote(context, s, '${n['id']}'), icon: const Icon(Icons.print_rounded), label: Text('View / Print')),
          if (s.admin && !off && !billed) OutlinedButton.icon(key: Key('dnc-${n['id']}'), onPressed: () => _cancel(n), icon: const Icon(Icons.block_rounded, color: C.red), label: Text('Cancel')),
        ]),
      ]),
    );
  }

  Widget _dieselTile(Session s, Map<String, dynamic> b) {
    final old = b['status'] == 'Superseded', rev = num.tryParse('${b['rev'] ?? 0}') ?? 0;
    return Container(
      key: Key('dnb-${b['id']}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: old ? C.slateSoft : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${'${b['dnNo'] ?? ''}'.isNotEmpty ? b['dnNo'] : '–'} · ${b['vendor']}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              Text('${showDate('${b['billDate']}')} · ${b['company']} · Diesel', style: const TextStyle(fontSize: 12.5, color: C.muted)),
              Text('RA Bill ${b['billNo']}${rev != 0 ? ' rev ${b['rev']}' : ''} · ${showDate('${b['from']}')} – ${showDate('${b['to']}')}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${n2(b['dnAmt'])}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            old ? Pill('Superseded', color: C.amber, bg: C.amberSoft) : Pill('Deducted in the bill', color: C.greenDark, bg: C.greenSoft),
          ]),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          OutlinedButton.icon(key: Key('dnbv-${b['id']}'), onPressed: () => viewBillDebitNote(context, s, '${b['id']}'), icon: const Icon(Icons.print_rounded), label: Text('View / Print')),
          OutlinedButton.icon(key: Key('dnbb-${b['id']}'), onPressed: () => viewSavedBill(context, s, '${b['id']}'), icon: const Icon(Icons.receipt_long_rounded), label: Text('Bill')),
        ]),
      ]),
    );
  }
}

// =====================================================================================================================
//  A NEW DEBIT NOTE
// =====================================================================================================================
class DebitNoteScreen extends StatefulWidget {
  const DebitNoteScreen({super.key});
  @override
  State<DebitNoteScreen> createState() => _DebitNoteScreenState();
}

class _DebitNoteScreenState extends State<DebitNoteScreen> {
  String co = kNoteNames.first, from = '', to = '', date = '';
  final party = TextEditingController(), gst = TextEditingController(), tds = TextEditingController(), remark = TextEditingController();
  List<String> parties = [];
  final lines = <Map<String, dynamic>>[];
  final _c = <String, TextEditingController>{};
  int _gen = 0;
  bool busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (date.isNotEmpty) return;
    final s = SessionScope.read(context), t = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    date = t;
    from = '${t.substring(0, 8)}01';
    to = t;
    WidgetsBinding.instance.addPostFrameCallback((_) => _parties());
  }

  @override
  void dispose() {
    for (final c in [party, gst, tds, remark, ..._c.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _parties() async {
    final s = SessionScope.read(context);
    try {
      final l = (await s.api.call('getLookups')) as Map;
      if (!mounted) return;
      setState(() => parties = [for (final v in (l['vendors'] as List? ?? const [])) '$v']);
    } catch (_) {/* typed by hand */}
  }

  TextEditingController _box(int i, String k) => _c.putIfAbsent('$_gen|$i|$k', () => TextEditingController(text: '${lines[i][k] ?? ''}'));

  void _again() {
    for (final c in _c.values) {
      c.dispose();
    }
    _c.clear();
    _gen++;
  }

  Future<void> _fetch() async {
    final s = SessionScope.read(context), v = party.text.trim();
    if (v.isEmpty) return toast(context, 'Pick the party (Debit to).', bad: true);
    if (from.isEmpty || to.isEmpty) return toast(context, 'Pick the dates of the work (From – To).', bad: true);
    setState(() => busy = true);
    try {
      final d = (await s.api.call('getDebitPending', [
        {'vendor': v, 'from': from, 'to': to}
      ])) as Map;
      if (!mounted) return;
      final rows = maps(d['rows']), kept = lines.where((l) => '${l['logId'] ?? ''}'.isEmpty).toList(), already = num.tryParse('${d['already'] ?? 0}') ?? 0;
      setState(() {
        lines
          ..clear()
          ..addAll([for (final r in rows) dnLineOf(r)])
          ..addAll(kept);
        _again();
        busy = false;
      });
      toast(
          context,
          rows.isNotEmpty
              ? '${rows.length} Log Book ${rows.length == 1 ? 'entry' : 'entries'} charged to ${d['vendor']}${already > 0 ? ' (${d['already']} more are already in a debit note)' : ''}.'
              : 'No Log Book entry is charged to ${d['vendor']} in these dates${already > 0 ? ' that is not already in a debit note (${d['already']} are).' : '. Pick the party in "Debit to" of the Log Book entry first.'}',
          bad: rows.isEmpty);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: true);
    }
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    if (lines.isEmpty) return toast(context, 'Add at least one line.', bad: true);
    final t = dnTotals(lines, gst.text, tds.text);
    if (!await askLines(context, 'Save this debit note?', ['$co → ${party.text.trim()}: ${lines.length} line(s), total ₹ ${n2(t.total)}.'],
        note: 'It gets the next debit note number and lowers what is payable to this party in the Vendor Ledger. A saved note cannot be changed – only cancelled by Admin.', yes: 'Save debit note')) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final r = (await s.api.call('saveDebitNote', [
        {
          'company': co,
          'vendor': party.text.trim(),
          'date': date,
          'from': from,
          'to': to,
          'gstPct': gst.text,
          'tdsPct': tds.text,
          'remark': remark.text.trim(),
          'lines': [
            for (final l in lines) {'logId': '${l['logId'] ?? ''}', 'machinery': l['machinery'], 'particular': l['particular'], 'qty': l['qty'], 'unit': l['unit'], 'rate': l['rate']}
          ],
        }
      ], true)) as Map;
      if (!mounted) return;
      toast(context, 'Debit note ${r['no']} saved – ${r['vendor']}, ₹ ${n2(r['total'])}.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  Future<void> _clear() async {
    if ((lines.isNotEmpty || party.text.isNotEmpty) && !await ask(context, 'Clear the debit note form?', 'What is typed here and not saved will be removed. Saved entries are not touched.', yes: 'Clear')) return;
    final s = SessionScope.read(context), t = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    setState(() {
      lines.clear();
      _again();
      for (final c in [party, gst, tds, remark]) {
        c.clear();
      }
      date = t;
      from = '${t.substring(0, 8)}01';
      to = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = dnTotals(lines, gst.text, tds.text);
    return Scaffold(
      appBar: AppBar(title: Text('New Debit Note')),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
          child: Row(children: [
            Expanded(child: Text(dnSumText(t), key: const Key('dn-sum'), maxLines: 2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            FilledButton(key: const Key('dn-save'), style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: busy ? null : _save, child: Text('Save Debit Note')),
          ]),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
        PickField(key: const Key('dn-co'), label: 'Name on the note', value: co, items: kNoteNames, onChanged: (v) => setState(() => co = v)),
        const SizedBox(height: 8),
        TextBox(key: const Key('dn-vendor'), label: 'Party (debit to)', controller: party, options: parties),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DateField(key: const Key('dn-from'), label: 'Work from', value: from, onChanged: (v) => setState(() => from = v))),
          const SizedBox(width: 8),
          Expanded(child: DateField(key: const Key('dn-to'), label: 'Work to', value: to, onChanged: (v) => setState(() => to = v))),
        ]),
        const SizedBox(height: 8),
        DateField(key: const Key('dn-date'), label: 'Date of the note', value: date, clear: false, onChanged: (v) => setState(() => date = v)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          FilledButton.icon(key: const Key('dn-fetch'), onPressed: busy ? null : _fetch, icon: const Icon(Icons.download_rounded), label: Text('Get Log Book entries')),
          OutlinedButton(key: const Key('dn-clear'), onPressed: busy ? null : _clear, child: Text('Clear')),
        ]),
        const SizedBox(height: 12),
        if (lines.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('No lines yet – pick the party and the dates and press "Get Log Book entries", or add a line by hand.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
        for (var i = 0; i < lines.length; i++) _line(i),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('dn-add'),
            onPressed: () => setState(() => lines.add({'logId': '', 'machinery': '', 'particular': '', 'qty': '', 'unit': '', 'rate': ''})),
            icon: const Icon(Icons.add_rounded),
            label: Text('Add a line'),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextBox(key: const Key('dn-gst'), label: 'GST %', controller: gst, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: TextBox(key: const Key('dn-tds'), label: 'TDS %', controller: tds, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 8),
        TextBox(key: const Key('dn-remark'), label: 'Remark', controller: remark),
      ]),
    );
  }

  Widget _line(int i) {
    final l = lines[i], byLog = '${l['logId'] ?? ''}'.isNotEmpty;
    Widget box(String k, String label, {bool isNum = false, bool ro = false}) => TextField(
          key: Key('dnl-$k-$i'),
          controller: _box(i, k),
          readOnly: ro,
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : null,
          inputFormatters: isNum ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
          onChanged: (v) => setState(() => l[k] = v),
          decoration: InputDecoration(isDense: true, labelText: tr(label)),
        );
    return Container(
      key: Key('dnl-$i'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      child: Column(children: [
        Row(children: [
          Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.muted)),
          const SizedBox(width: 8),
          Expanded(child: box('machinery', 'Machinery', ro: byLog)),
          IconButton(
            key: Key('dnl-del-$i'),
            tooltip: tr('Remove this line'),
            onPressed: () => setState(() {
              lines.removeAt(i);
              _again();
            }),
            icon: const Icon(Icons.close_rounded, color: C.red),
          ),
        ]),
        box('particular', 'Particular'),
        Row(children: [
          Expanded(child: box('qty', 'Qty', isNum: true)),
          const SizedBox(width: 6),
          Expanded(child: box('unit', 'Unit')),
          const SizedBox(width: 6),
          Expanded(child: box('rate', 'Rate', isNum: true)),
        ]),
        Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(top: 6), child: Text('Amount ${n2(dnLineAmt(l))}', key: Key('dnl-amt-$i'), style: const TextStyle(fontWeight: FontWeight.w800)))),
      ]),
    );
  }
}
