/* THE MONEY OF THE BILLS – the app's own screens (3.8.0) of the web's Bill Summary, Machinery Payments, Vendor Ledger and Vendor
 * Outstanding: the same filters and the same server answers (billSummary, getPayments / savePayment / deletePayment,
 * vendorLedger, vendorOutstanding), laid out as the web (core/bill_reports.dart) – Print and Excel made on the phone; a bill
 * opens with its papers and Log Book (View); a vendor of the Outstanding opens its ledger. */
import 'package:flutter/material.dart' hide Text;

import '../core/bill_reports.dart';
import '../core/format.dart';
import '../core/lb_print.dart' show n2;
import '../core/rdoc.dart' show RDoc;
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/report_view.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'bill_print.dart';
import 'billing.dart' show openBillPage;
import '../ui/help.dart' show GuideButton;

String _today(Session s) => s.today.isNotEmpty ? s.today : dateKey(DateTime.now());

/// A month box ('2026-09'), the months of the last five years to this one.
class MonthField extends StatelessWidget {
  const MonthField({super.key, required this.label, required this.value, required this.today, required this.onChanged});
  final String label, value, today;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final y = int.parse(today.substring(0, 4)), m = int.parse(today.substring(5, 7));
    final ms = brMonths('${y - 5}-${today.substring(5, 7)}', '$y-${m.toString().padLeft(2, '0')}').reversed.toList();
    if (value.isNotEmpty && !ms.contains(value)) ms.insert(0, value);
    return PickField(label: label, value: brMonthName(value), items: [for (final x in ms) brMonthName(x)], onChanged: (v) => onChanged(ms.firstWhere((x) => brMonthName(x) == v, orElse: () => value)));
  }
}

/// (a button in a row: its own width – the theme's buttons are as wide as the screen)
final _sm = OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12));

Widget _bar(List<Widget> kids) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final k in kids) Padding(padding: const EdgeInsets.only(right: 6), child: k)]));

// =====================================================================================================================
//  BILL SUMMARY
// =====================================================================================================================
class BillSummaryScreen extends StatefulWidget {
  const BillSummaryScreen({super.key});
  @override
  State<BillSummaryScreen> createState() => _BillSummaryScreenState();
}

class _BillSummaryScreenState extends State<BillSummaryScreen> {
  String fromM = '', toM = '', co = '', vendor = '', view = 'net', err = '';
  List<Map<String, dynamic>> all = [];
  bool loading = true;
  int _seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (fromM.isNotEmpty) return;
    final r = brRange('3', _today(SessionScope.read(context)));
    fromM = r.$1;
    toM = r.$2;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (fromM.compareTo(toM) > 0) return toast(context, 'From month is after To month.', bad: true);
    final s = SessionScope.read(context), my = ++_seq;
    setState(() => loading = true);
    try {
      final d = (await s.api.call('billSummary', [
        {'fromM': fromM, 'toM': toM, 'company': co}
      ])) as Map;
      if (my != _seq || !mounted) return;
      setState(() {
        all = maps(d['rows']);
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
    final r = brRange(k, _today(SessionScope.read(context)));
    setState(() {
      fromM = r.$1;
      toM = r.$2;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), t = _today(s);
    final names = {for (final r in all) '${r['vendor']}'}.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (vendor.isNotEmpty && !names.contains(vendor)) names.add(vendor);
    final rows = all.where((r) => vendor.isEmpty || r['vendor'] == vendor).toList(), months = brMonths(fromM, toM);
    final RDoc? doc = rows.isEmpty || months.isEmpty ? null : brDoc(rows, months, view, company: co, vendor: vendor);
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Bill Summary', 'बिल सारांश', size: 20, weight: FontWeight.w700), actions: [const GuideButton('breg'), IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('br-list'), padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
          Text('Only submitted bills that are in force (a bill replaced by a revision is not counted twice). A bill is shown in the month its work period starts.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: MonthField(key: const Key('br-from'), label: 'From month', value: fromM, today: t, onChanged: (v) {
              setState(() => fromM = v);
              _load();
            })),
            const SizedBox(width: 8),
            Expanded(child: MonthField(key: const Key('br-to'), label: 'To month', value: toM, today: t, onChanged: (v) {
              setState(() => toM = v);
              _load();
            })),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: PickField(key: const Key('br-co'), label: 'Name on the bill', value: co, items: const ['Sketchline Industries', 'Rachana Construction Limited'], blank: 'Both', onChanged: (v) {
              setState(() => co = v);
              _load();
            })),
            const SizedBox(width: 8),
            Expanded(child: PickField(key: const Key('br-vendor'), label: 'Vendor', value: vendor, items: names, blank: 'All vendors', onChanged: (v) => setState(() => vendor = v))),
          ]),
          const SizedBox(height: 4),
          _bar([
            ActionChip(key: const Key('br-this'), label: Text('This month'), onPressed: () => _range('this')),
            ActionChip(key: const Key('br-last'), label: Text('Last month'), onPressed: () => _range('last')),
            ActionChip(key: const Key('br-3'), label: Text('Last 3 months'), onPressed: () => _range('3')),
            ActionChip(key: const Key('br-fy'), label: Text('This FY'), onPressed: () => _range('fy')),
            ActionChip(
              key: const Key('br-clear'),
              label: Text('Clear filters'),
              onPressed: () {
                setState(() => vendor = co = '');
                _range('3');
              },
            ),
          ]),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            key: const Key('br-view'),
            segments: [
              ButtonSegment(value: 'net', label: Text('Net Payable (month-wise)')),
              ButtonSegment(value: 'detail', label: Text('Detail')),
            ],
            selected: {view},
            onSelectionChanged: (v) => setState(() => view = v.first),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text('${rows.length} bill${rows.length == 1 ? '' : 's'}${months.isEmpty ? '' : ' · ${brMonthName(months.first)}${months.length > 1 ? ' – ${brMonthName(months.last)}' : ''}'}', key: const Key('br-note'), style: const TextStyle(fontSize: 13, color: C.muted))),
            OutlinedButton.icon(key: const Key('br-print'), style: _sm, onPressed: doc == null ? () => toast(context, 'Nothing to print.', bad: true) : () => printDoc(context, s, doc), icon: const Icon(Icons.print_rounded), label: Text('Print')),
            const SizedBox(width: 6),
            OutlinedButton.icon(key: const Key('br-xls'), style: _sm, onPressed: doc == null ? () => toast(context, 'Nothing to export.', bad: true) : () => shareDocXlsx(s, doc), icon: const Icon(Icons.table_view_rounded), label: Text('Excel')),
          ]),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 8),
          if (loading && all.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (!loading && rows.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No submitted bills for these filters.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
          if (doc != null) ReportView(doc),
          if (doc != null && view == 'net') ...[
            const SizedBox(height: 10),
            Text('Tap a vendor for the detail of its bills:', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final v in brVendors(rows))
                ActionChip(
                  key: Key('brv-$v'),
                  label: Text(v),
                  onPressed: () => setState(() {
                    vendor = v;
                    view = 'detail';
                  }),
                ),
            ]),
          ],
          if (doc != null && view == 'detail') ...[
            const SizedBox(height: 10),
            Text('View a bill (its papers and Log Book):', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in rows) ActionChip(key: Key('brb-${r['id']}'), avatar: const Icon(Icons.receipt_long_rounded, size: 18), label: Text('RA ${r['billNo']} · ${r['vendor']}'), onPressed: () => viewSavedBill(context, s, '${r['id']}')),
            ]),
          ],
        ]),
      ),
    );
  }
}

// =====================================================================================================================
//  MACHINERY PAYMENTS
// =====================================================================================================================
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, this.vendor = '', this.date = ''});

  /// (3.14.0) opened by the search: this vendor's payments of this date (the web's gsOpenPay)
  final String vendor, date;
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String type = 'Payment', date = '', vendor = '', side = 'Payable', mode = '', bill = '', editId = '', bal = '';
  String fVendor = '', fFrom = '', fTo = '', fType = '', err = '';
  final amount = TextEditingController(), ref = TextEditingController(), remark = TextEditingController();
  List<String> vendors = [], modes = [], billOpts = [];
  List<Map<String, dynamic>> list = [];
  bool loading = true, busy = false, started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    date = _today(SessionScope.read(context));
    fVendor = widget.vendor;
    if (widget.date.isNotEmpty) fFrom = fTo = widget.date;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    for (final c in [amount, ref, remark]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    final s = SessionScope.read(context);
    try {
      final v = await s.api.call('getVendors');
      if (mounted) setState(() => vendors = [for (final x in (v as List? ?? const []).whereType<Map>()) '${x['name']}']);
    } catch (_) {/* the vendors stay empty */}
    await _load();
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    setState(() => loading = true);
    try {
      final d = (await s.api.call('getPayments', [
        {'vendor': fVendor, 'from': fFrom, 'to': fTo, 'type': fType}
      ])) as Map;
      if (!mounted) return;
      setState(() {
        list = maps(d['payments']);
        if (modes.isEmpty) modes = [for (final m in (d['modes'] as List? ?? const [])) '$m'];
        loading = false;
        err = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  /// The vendor picked: its balance now and its bills for "Against RA Bill".
  Future<void> _vendorInfo() async {
    final s = SessionScope.read(context), v = vendor, keep = bill;
    if (v.isEmpty) {
      setState(() {
        bal = '';
        billOpts = [];
      });
      return;
    }
    try {
      final d = (await s.api.call('vendorLedger', [
        {'vendor': v}
      ])) as Map;
      if (!mounted || vendor != v) return;
      final bills = maps(d['rows']).where((r) => r['kind'] == 'bill').toList().reversed;
      final opts = [for (final b in bills) 'RA ${b['billNo']}${(num.tryParse('${b['rev'] ?? 0}') ?? 0) != 0 ? ' rev ${b['rev']}' : ''} (${showDate('${b['from']}')} – ${showDate('${b['to']}')})'];
      if (keep.isNotEmpty && !opts.contains(keep)) opts.add(keep);
      setState(() {
        billOpts = opts;
        bal = 'Balance of $v now: ₹ ${balTxt(d['closing'])} (opening ₹ ${balTxt(d['opening'])} + bills ₹ ${n2(d['totalBill'])} − paid ₹ ${n2(d['totalPaid'])})';
      });
    } catch (_) {
      if (mounted) setState(() => bal = '');
    }
  }

  void _clear() {
    setState(() {
      editId = '';
      type = 'Payment';
      for (final c in [amount, ref, remark]) {
        c.clear();
      }
      mode = '';
      bill = '';
      side = 'Payable';
      date = _today(SessionScope.read(context));
    });
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    final x = {'id': editId.isEmpty ? null : editId, 'type': type, 'date': date, 'vendor': vendor, 'amount': amount.text, 'side': side, 'mode': mode, 'ref': ref.text, 'bill': bill, 'remark': remark.text};
    if (editId.isNotEmpty && !await ask(context, 'Save the changes?', 'Entry $editId of $vendor will be changed.', yes: 'Save changes')) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final r = (await s.api.call('savePayment', [x, editId.isNotEmpty ? 'edit' : 'add'], true)) as Map;
      if (!mounted) return;
      toast(context, '${type == 'Opening' ? 'Opening balance' : 'Payment'} saved: $vendor – ₹ ${n2(r['amount'])}');
      final v = vendor;
      _clear();
      setState(() {
        vendor = v;
        busy = false;
      });
      await _load();
      _vendorInfo();
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  Future<void> _edit(Map p) async {
    setState(() {
      editId = '${p['id']}';
      type = '${p['type']}' == 'Opening' ? 'Opening' : 'Payment';
      date = '${p['date'] ?? ''}';
      vendor = '${p['vendor'] ?? ''}';
      amount.text = '${p['amount'] ?? ''}';
      side = '${p['side'] ?? ''}' == 'Advance' ? 'Advance' : 'Payable';
      mode = '${p['mode'] ?? ''}';
      ref.text = '${p['ref'] ?? ''}';
      remark.text = '${p['remark'] ?? ''}';
      bill = '${p['bill'] ?? ''}';
    });
    await _vendorInfo();
  }

  Future<void> _delete(Map p) async {
    final s = SessionScope.read(context);
    if (!await ask(context, 'Delete this entry?', '${p['type'] == 'Opening' ? 'Opening balance' : 'Payment'} of ${p['vendor']} – ₹ ${n2(p['amount'])} on ${showDate('${p['date']}')}. The vendor balance will change.', yes: 'Delete', danger: true)) return;
    if (!mounted) return;
    try {
      await s.api.call('deletePayment', [p['id']], true);
      if (!mounted) return;
      toast(context, 'Deleted.');
      if (editId == '${p['id']}') _clear();
      await _load();
      _vendorInfo();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: !isSent(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), can = s.canEdit('Machinery Payments'), open = type == 'Opening';
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Machinery Payments', 'यंत्र पेमेंट', size: 20, weight: FontWeight.w700), actions: [const GuideButton('pay'), IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('py-list'), padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
          if (!can) InfoLine('View only – you can see payments, but you cannot add, change or delete. Ask Admin for Edit access.', bad: true),
          if (can)
            Container(
              key: const Key('py-form'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(editId.isNotEmpty ? 'Change entry $editId' : open ? 'Opening balance' : 'New payment', key: const Key('py-title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('A payment lowers the vendor\'s balance at once. Submitted bills come into the ledger by themselves.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  key: const Key('py-type'),
                  segments: [ButtonSegment(value: 'Payment', label: Text('Payment to vendor')), ButtonSegment(value: 'Opening', label: Text('Opening balance'))],
                  selected: {type},
                  onSelectionChanged: (v) => setState(() => type = v.first),
                ),
                if (open) Padding(padding: const EdgeInsets.only(top: 4), child: Text('(old balance before the bills in this app – once per vendor)', style: const TextStyle(fontSize: 12, color: C.muted))),
                const SizedBox(height: 8),
                DateField(key: const Key('py-date'), label: open ? 'Balance as on' : 'Payment date', value: date, onChanged: (v) => setState(() => date = v)),
                const SizedBox(height: 8),
                PickField(key: const Key('py-vendor'), label: 'Vendor', value: vendor, items: vendors, blank: '– pick –', onChanged: (v) {
                  setState(() {
                    vendor = v;
                    bill = '';
                  });
                  _vendorInfo();
                }),
                const SizedBox(height: 8),
                TextBox(key: const Key('py-amount'), label: 'Amount (₹)', controller: amount, kb: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 8),
                if (open)
                  PickField(key: const Key('py-side'), label: 'Opening balance is', value: side == 'Advance' ? 'Advance paid (vendor owes)' : 'Payable to vendor (we owe)', items: const ['Payable to vendor (we owe)', 'Advance paid (vendor owes)'], onChanged: (v) => setState(() => side = v.startsWith('Advance') ? 'Advance' : 'Payable'))
                else ...[
                  PickField(key: const Key('py-mode'), label: 'Paid by', value: mode, items: modes, blank: '– pick –', onChanged: (v) => setState(() => mode = v)),
                  const SizedBox(height: 8),
                  TextBox(key: const Key('py-ref'), label: 'UTR / Cheque No', controller: ref),
                  const SizedBox(height: 8),
                  PickField(key: const Key('py-bill'), label: 'Against RA Bill (optional)', value: bill, items: billOpts, blank: '–', onChanged: (v) => setState(() => bill = v)),
                ],
                const SizedBox(height: 8),
                TextBox(key: const Key('py-remark'), label: 'Remark', controller: remark),
                if (bal.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(bal, key: const Key('py-bal'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  FilledButton(key: const Key('py-save'), onPressed: busy ? null : _save, child: Text(editId.isNotEmpty ? 'Save changes' : open ? 'Save opening balance' : 'Save payment')),
                  OutlinedButton(key: const Key('py-clear'), onPressed: _clear, child: Text('Clear')),
                ]),
              ]),
            ),
          const SizedBox(height: 16),
          Text('Payments & opening balances', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(pyNote(list), key: const Key('py-note'), style: const TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: PickField(key: const Key('pyf-vendor'), label: 'Vendor', value: fVendor, items: vendors, blank: 'All vendors', onChanged: (v) {
              setState(() => fVendor = v);
              _load();
            })),
            const SizedBox(width: 8),
            Expanded(child: PickField(key: const Key('pyf-type'), label: 'Type', value: fType == 'Payment' ? 'Payments' : fType == 'Opening' ? 'Opening balances' : 'All', items: const ['All', 'Payments', 'Opening balances'], onChanged: (v) {
              setState(() => fType = v == 'Payments' ? 'Payment' : v == 'Opening balances' ? 'Opening' : '');
              _load();
            })),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: DateField(key: const Key('pyf-from'), label: 'From', value: fFrom, onChanged: (v) {
              setState(() => fFrom = v);
              _load();
            })),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('pyf-to'), label: 'To', value: fTo, onChanged: (v) {
              setState(() => fTo = v);
              _load();
            })),
          ]),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 8),
          if (loading && list.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (!loading && list.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No payments for these filters.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
          for (final p in list) _tile(p, can),
        ]),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> p, bool can) {
    final open = p['type'] == 'Opening';
    final sub = [
      if (!open) '${'${p['mode'] ?? ''}'.isNotEmpty ? p['mode'] : '–'}${'${p['ref'] ?? ''}'.isNotEmpty ? ' · ${p['ref']}' : ''}',
      if ('${p['bill'] ?? ''}'.isNotEmpty) 'against ${p['bill']}',
      if ('${p['remark'] ?? ''}'.isNotEmpty) '${p['remark']}',
    ].join(' · ');
    final by = [p['enteredBy'], if ('${p['updatedBy'] ?? ''}'.isNotEmpty) 'changed: ${p['updatedBy']}'].where((x) => '${x ?? ''}'.isNotEmpty).join(' · ');
    return Container(
      key: Key('py-${p['id']}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: editId == '${p['id']}' ? C.green : C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['vendor']}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              Text('${showDate('${p['date']}')} · ${open ? 'Opening – ${p['side']}' : 'Payment'}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
              if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12.5, color: C.muted)),
              if (by.isNotEmpty) Text(by, style: const TextStyle(fontSize: 12, color: C.faint)),
            ]),
          ),
          Text('₹${n2(p['amount'])}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: open ? C.amber : C.greenDark)),
        ]),
        if (can)
          Wrap(spacing: 8, children: [
            TextButton(key: Key('pye-${p['id']}'), onPressed: () => _edit(p), child: Text('Edit')),
            TextButton(key: Key('pyd-${p['id']}'), onPressed: () => _delete(p), child: Text('Delete', style: const TextStyle(color: C.red))),
          ]),
      ]),
    );
  }
}

// =====================================================================================================================
//  VENDOR LEDGER
// =====================================================================================================================
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key, this.vendor = '', this.from = '', this.to = ''});
  final String vendor, from, to;
  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String vendor = '', from = '', to = '', err = '';
  List<String> vendors = [];
  Map<String, dynamic>? d;
  bool loading = false, started = false;
  int _seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    vendor = widget.vendor;
    from = widget.from;
    to = widget.to;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = SessionScope.read(context);
      try {
        final v = await s.api.call('getVendors');
        if (mounted) setState(() => vendors = [for (final x in (v as List? ?? const []).whereType<Map>()) '${x['name']}']);
      } catch (_) {/* the vendors stay empty */}
      if (vendor.isNotEmpty) _load();
    });
  }

  Future<void> _load() async {
    if (vendor.isEmpty) {
      setState(() => d = null);
      return;
    }
    final s = SessionScope.read(context), my = ++_seq;
    setState(() => loading = true);
    try {
      final r = ((await s.api.call('vendorLedger', [
        {'vendor': vendor, 'from': from, 'to': to}
      ])) as Map).cast<String, dynamic>();
      if (my != _seq || !mounted) return;
      setState(() {
        d = r;
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

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), x = d, names = [...vendors, if (vendor.isNotEmpty && !vendors.contains(vendor)) vendor];
    final doc = x == null ? null : vlDoc(x, _today(s));
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Vendor Ledger', 'vendor खाते', size: 20, weight: FontWeight.w700), actions: [const GuideButton('vled'), IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('vl-list'), padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
          Text('One ledger per vendor – bills of both names (Sketchline / Rachana) and all payments together. Balance = what is still to be paid.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 8),
          PickField(key: const Key('vl-vendor'), label: 'Vendor', value: vendor, items: names, blank: '– pick –', onChanged: (v) {
            setState(() => vendor = v);
            _load();
          }),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: DateField(key: const Key('vl-from'), label: 'From', value: from, onChanged: (v) {
              setState(() => from = v);
              _load();
            })),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('vl-to'), label: 'To', value: to, onChanged: (v) {
              setState(() => to = v);
              _load();
            })),
          ]),
          const SizedBox(height: 4),
          _bar([
            ActionChip(key: const Key('vl-fy'), label: Text('This FY'), onPressed: () {
              setState(() {
                from = fyStart(_today(s));
                to = '';
              });
              _load();
            }),
            ActionChip(key: const Key('vl-all'), label: Text('From the start'), onPressed: () {
              setState(() => from = to = '');
              _load();
            }),
            ActionChip(key: const Key('vl-clear'), label: Text('Clear'), onPressed: () => setState(() {
                  vendor = from = to = '';
                  d = null;
                })),
            OutlinedButton.icon(key: const Key('vl-print'), style: _sm, onPressed: doc == null ? () => toast(context, 'Pick a vendor.', bad: true) : () => printDoc(context, s, doc), icon: const Icon(Icons.print_rounded), label: Text('Print')),
            OutlinedButton.icon(key: const Key('vl-xls'), style: _sm, onPressed: doc == null ? () => toast(context, 'Pick a vendor.', bad: true) : () => shareDocXlsx(s, doc), icon: const Icon(Icons.table_view_rounded), label: Text('Excel')),
          ]),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 8),
          if (loading && x == null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (x == null && !loading) Padding(padding: const EdgeInsets.all(20), child: Text('Pick a vendor.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
          if (doc != null) ReportView(doc),
          if (x != null && maps(x['rows']).any((r) => r['kind'] == 'bill')) ...[
            const SizedBox(height: 10),
            Text('View a bill (its papers and Log Book):', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in maps(x['rows']).where((r) => r['kind'] == 'bill'))
                ActionChip(key: Key('vlb-${r['id']}'), avatar: const Icon(Icons.receipt_long_rounded, size: 18), label: Text('RA Bill ${r['billNo']}${(num.tryParse('${r['rev'] ?? 0}') ?? 0) != 0 ? ' (Rev ${r['rev']})' : ''}'), onPressed: () => viewSavedBill(context, s, '${r['id']}')),
            ]),
          ],
        ]),
      ),
    );
  }
}

// =====================================================================================================================
//  VENDOR OUTSTANDING
// =====================================================================================================================
class OutstandingScreen extends StatefulWidget {
  const OutstandingScreen({super.key});
  @override
  State<OutstandingScreen> createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends State<OutstandingScreen> {
  String fromM = '', toM = '', err = '';
  Map<String, dynamic>? d;
  bool loading = true;
  int _seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (fromM.isNotEmpty) return;
    final r = brRange('3', _today(SessionScope.read(context)));
    fromM = r.$1;
    toM = r.$2;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    setState(() => loading = true);
    try {
      final r = ((await s.api.call('vendorOutstanding', [
        {'fromM': fromM, 'toM': toM}
      ])) as Map).cast<String, dynamic>();
      if (my != _seq || !mounted) return;
      setState(() {
        d = r;
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
    final r = brRange(k, _today(SessionScope.read(context)));
    setState(() {
      fromM = r.$1;
      toM = r.$2;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), t = _today(s), x = d, rows = x == null ? const <Map<String, dynamic>>[] : maps(x['rows']);
    final doc = x == null || rows.isEmpty ? null : voDoc(x);
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Vendor Outstanding', 'vendor बाकी', size: 20, weight: FontWeight.w700), actions: [const GuideButton('vout'), IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('vo-list'), padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
          Text('Every vendor\'s balance: opening, bills, payments and what is still to be paid – and the balance at the end of each month. Tap a vendor for the ledger.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: MonthField(key: const Key('vo-from'), label: 'From month', value: fromM, today: t, onChanged: (v) {
              setState(() => fromM = v);
              _load();
            })),
            const SizedBox(width: 8),
            Expanded(child: MonthField(key: const Key('vo-to'), label: 'To month', value: toM, today: t, onChanged: (v) {
              setState(() => toM = v);
              _load();
            })),
          ]),
          const SizedBox(height: 4),
          _bar([
            ActionChip(key: const Key('vo-this'), label: Text('This month'), onPressed: () => _range('this')),
            ActionChip(key: const Key('vo-3'), label: Text('Last 3 months'), onPressed: () => _range('3')),
            ActionChip(key: const Key('vo-fy'), label: Text('This FY'), onPressed: () => _range('fy')),
            ActionChip(key: const Key('vo-clear'), label: Text('Clear filters'), onPressed: () => _range('3')),
            OutlinedButton.icon(key: const Key('vo-print'), style: _sm, onPressed: doc == null ? () => toast(context, 'Nothing to print.', bad: true) : () => printDoc(context, s, doc), icon: const Icon(Icons.print_rounded), label: Text('Print')),
            OutlinedButton.icon(key: const Key('vo-xls'), style: _sm, onPressed: doc == null ? () => toast(context, 'Nothing to export.', bad: true) : () => shareDocXlsx(s, doc), icon: const Icon(Icons.table_view_rounded), label: Text('Excel')),
          ]),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 8),
          if (loading && x == null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (x != null && rows.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No bills, payments or opening balances yet.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
          if (doc != null) ReportView(doc),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Tap a vendor for the ledger:', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in rows)
                ActionChip(
                  key: Key('vov-${r['vendor']}'),
                  label: Text('${r['vendor']}'),
                  onPressed: () {
                    if (!s.canSee('Vendor Ledger')) return toast(context, 'You do not have access to the Vendor Ledger.', bad: true);
                    openBillPage(context, 'Vendor Ledger', vendor: '${r['vendor']}', from: '$fromM-01', to: monthEnd(toM));
                  },
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
