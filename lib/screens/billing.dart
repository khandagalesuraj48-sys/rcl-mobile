/* BILLING – the app's own screens (3.8.0) of the web's billing pages (Home → Billing): Machinery Billing (build the bills of a
 * period from the Log Book, the diesel and the BOQ – one bill per vendor or per machinery –, check them, Verify & Submit; the
 * company details on the bills; the month close of the Admin), RCL Drive (the saved bills and debit notes), Bill Summary,
 * Machinery Payments, Vendor Ledger and Vendor Outstanding – each by its access, as the web's tabs. The bills are the web's own
 * working (core/bill.dart); the server checks and saves them (billInit, billCorrections, verifyBills, submitBills …). */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../core/bill.dart';
import '../core/format.dart';
import '../core/lb_print.dart' show n2, fmt;
import '../core/log_edit.dart' show r2;
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'bill_drive.dart';
import 'bill_money.dart';
import 'bill_print.dart';
import 'log_print.dart';
import '../ui/help.dart' show GuideButton;

/// The billing pages and their access (as the web's tabs).
const kBillPages = [
  ('Machinery Billing', 'यंत्र बिलिंग', 'Machinery Billing', 'receipt', 'Build the bills of a period, check, submit'),
  ('RCL Drive', 'RCL ड्राइव्ह', 'Saved Bills', 'clipboard', 'Saved bills and debit notes – view, print'),
  ('Bill Summary', 'बिल सारांश', 'Bill Summary', 'bar_chart', 'Net payable month-wise, the detail of every bill'),
  ('Machinery Payments', 'यंत्र पेमेंट', 'Machinery Payments', 'ledger', 'Payments and opening balances of vendors'),
  ('Vendor Ledger', 'vendor खाते', 'Vendor Ledger', 'ledger', 'One vendor: bills, notes, payments, balance'),
  ('Vendor Outstanding', 'vendor बाकी', 'Vendor Outstanding', 'office_building', 'Every vendor\'s balance and the month-end balances'),
];

bool seesBilling(Session s) => kBillPages.any((p) => s.canSee(p.$3));

Future<void> openBilling(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BillingHub()));

void openBillPage(BuildContext context, String access, {String vendor = '', String from = '', String to = ''}) {
  final Widget w = switch (access) {
    'Machinery Billing' => const BillMakeScreen(),
    'Saved Bills' => const DriveScreen(),
    'Bill Summary' => const BillSummaryScreen(),
    'Machinery Payments' => const PaymentsScreen(),
    'Vendor Ledger' => LedgerScreen(vendor: vendor, from: from, to: to),
    _ => const OutstandingScreen(),
  };
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
}

class BillingHub extends StatelessWidget {
  const BillingHub({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = kBillPages.where((p) => s.canSee(p.$3)).toList();
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Billing', 'बिलिंग', size: 20, weight: FontWeight.w700)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        Text(s.siteName, style: const TextStyle(fontSize: 15, color: C.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (list.isEmpty) const EmptyState('No billing page for you yet', 'Ask the Admin for access to Machinery Billing.', pic: 'receipt'),
        for (final p in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Press(
              key: Key('bh-${p.$3}'),
              onTap: () => openBillPage(context, p.$3),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 58, height: 58, decoration: BoxDecoration(color: C.purpleSoft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(p.$4, size: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TwoLang(p.$1, p.$2, size: 17, weight: FontWeight.w700),
                    const SizedBox(height: 2),
                    Text(p.$5, style: const TextStyle(fontSize: 12.5, color: C.muted)),
                  ]),
                ),
                if (!s.canEdit(p.$3)) Pill('View', color: C.slate, bg: C.slateSoft),
                const Icon(Icons.chevron_right_rounded, color: C.faint),
              ]),
            ),
          ),
      ]),
    );
  }
}

String _lastMonthFrom(String today) {
  final t = parseKey(today);
  return dateKey(DateTime(t.year, t.month - 1, 1));
}

String _lastMonthTo(String today) {
  final t = parseKey(today);
  return dateKey(DateTime(t.year, t.month, 0));
}

const kBillNames = ['Sketchline Industries', 'Rachana Construction Limited'];

// =====================================================================================================================
//  MACHINERY BILLING
// =====================================================================================================================
class BillMakeScreen extends StatefulWidget {
  const BillMakeScreen({super.key});
  @override
  State<BillMakeScreen> createState() => _BillMakeScreenState();
}

class _BillMakeScreenState extends State<BillMakeScreen> {
  String from = '', to = '', billDate = '', co = kBillNames.first, per = 'vendor', err = '', lkDate = '';
  Map<String, dynamic>? init;
  final picked = <String, Set<String>>{};
  BillLogs? logs;
  List<Map<String, dynamic>> bills = [];
  String builtFrom = '', builtTo = '', builtCo = '';
  bool busy = false, showCo = false, loading = true;
  final _c = <String, TextEditingController>{};
  final _co = <String, TextEditingController>{};
  int _gen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (from.isNotEmpty) return;
    final s = SessionScope.read(context), t = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    from = _lastMonthFrom(t);
    to = _lastMonthTo(t);
    billDate = t;
    lkDate = s.closedUpto;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInit());
  }

  @override
  void dispose() {
    for (final c in [..._c.values, ..._co.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInit() async {
    final s = SessionScope.read(context);
    try {
      final d = ((await s.api.call('billInit')) as Map).cast<String, dynamic>();
      if (!mounted) return;
      d['vendors'] = d['vendors'] ?? [];
      d['lastNo'] = d['lastNo'] ?? {};
      setState(() {
        init = d;
        loading = false;
        err = '';
      });
      _fillCo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  List<Map<String, dynamic>> get _vendors => [for (final v in (init?['vendors'] as List? ?? const []).whereType<Map>()) v.cast<String, dynamic>()];
  List<String> _ids(Map v) => [for (final m in (v['machines'] as List? ?? const []).whereType<Map>()) '${m['id']}'];

  Map get _settings => (init?['settings'] as Map?) ?? const {};

  void _fillCo() {
    final st = _settings, cos = (st['companies'] as Map?) ?? const {};
    TextEditingController c(String k, Object? v) {
      final x = _co.putIfAbsent(k, () => TextEditingController());
      x.text = '${v ?? ''}';
      return x;
    }

    c('project', st['project']);
    c('site', st['siteAddress']);
    for (final n in cos.keys) {
      final x = (cos[n] as Map?) ?? const {};
      for (final k in const ['address', 'gstin', 'pan', 'invPrefix', 'dnPrefix']) {
        c('$n|$k', x[k]);
      }
    }
  }

  // ---------- the vendors picked ----------
  String _pickText() {
    final names = picked.keys.where((n) => picked[n]!.isNotEmpty).toList(), all = _vendors.length;
    if (names.isEmpty) return 'Pick vendors';
    final part = names.where((n) => picked[n]!.length < _ids(_vendors.firstWhere((v) => v['name'] == n, orElse: () => const {})).length).toList();
    final nM = names.fold<int>(0, (a, n) => a + picked[n]!.length);
    if (names.length == 1) return '${names.first}${part.isNotEmpty ? ' – ${picked[names.first]!.join(', ')}' : ''}';
    if (names.length == all && part.isEmpty) return 'All vendors ($all)';
    return '${names.length} vendors, $nM machinery: ${names.join(', ')}';
  }

  Future<void> _pickVendors() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _VendorSheet(vendors: _vendors, picked: picked));
    if (mounted) setState(() {});
  }

  // ---------- build ----------
  Future<void> _build() async {
    final s = SessionScope.read(context);
    if (from.isEmpty || to.isEmpty) return toast(context, 'Pick the period (From – To).', bad: true);
    if (to.compareTo(from) < 0) return toast(context, '"To" must be on or after "From".', bad: true);
    final p = {for (final e in picked.entries) if (e.value.isNotEmpty) e.key: [for (final v in _vendors) if (v['name'] == e.key) ..._ids(v).where(e.value.contains)]};
    p.removeWhere((k, v) => v.isEmpty);
    if (p.isEmpty) return toast(context, 'Pick at least one vendor / machinery (Vendors drop-down).', bad: true);
    if (init == null) await _loadInit();
    if (init == null || !mounted) return;
    setState(() => busy = true);
    try {
      final nos = [for (final v in _vendors) if (p.containsKey(v['name'])) ..._ids(v)];
      final res = await Future.wait([
        s.api.call('getLogBookList', [
          {'from': from, 'to': to, 'all': true}
        ]),
        s.api.call('logPrintExtra', [
          {'from': from, 'to': to, 'nos': nos}
        ]),
      ]);
      final l = BillLogs([for (final r in ((res[0] as Map)['rows'] as List? ?? const []).whereType<Map>()) r.cast<String, dynamic>()], from, to, (res[1] as Map?) ?? const {});
      final made = buildBills(init: init!, picked: p, per: per, from: from, to: to, company: co, billDate: billDate.isNotEmpty ? billDate : s.today, logs: l, machine: (no) => s.machine(no)?.m);
      await _corrLoad(s, made);
      if (!mounted) return;
      for (final c in _c.values) {
        c.dispose();
      }
      _c.clear();
      setState(() {
        logs = l;
        bills = made;
        builtFrom = from;
        builtTo = to;
        builtCo = co;
        busy = false;
        _gen++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: true);
    }
  }

  /// The differences of earlier bills (an entry of a submitted bill was changed): on the vendor's first bill of this batch.
  Future<void> _corrLoad(Session s, List<Map<String, dynamic>> list) async {
    final seen = <String>{};
    for (final b in list) {
      b['corr'] = <Map<String, dynamic>>[];
      b.remove('corrErr');
    }
    for (final b in list) {
      final g = '${(b['vendor'] as Map)['name']}'.toUpperCase() + '|${b['company']}';
      if (!seen.add(g)) continue;
      final grp = list.where((z) => '${(z['vendor'] as Map)['name']}'.toUpperCase() + '|${z['company']}' == g).toList();
      try {
        final r = (await s.api.call('billCorrections', [
          {
            'vendor': (b['vendor'] as Map)['name'],
            'company': b['company'],
            'bills': [
              for (final z in grp) {'from': z['from'], 'to': z['to'], 'machines': [for (final x in (z['machines'] as List).whereType<Map>()) x['no']]}
            ],
          }
        ])) as Map?;
        b['corr'] = [for (final z in ((r?['items'] as List?) ?? const []).whereType<Map>()) {...z.cast<String, dynamic>(), 'checked': false}];
      } catch (e) {
        b['corrErr'] = errText(e);
      }
      mbTotals(b);
    }
  }

  void _refill(Map<String, dynamic> b) => setState(() => mbFill(b, logs!, (no) => SessionScope.read(context).machine(no)?.m));

  TextEditingController _box(int i, String f, String v) => _c.putIfAbsent('$_gen|$i|$f', () => TextEditingController(text: v));

  Future<void> _clear() async {
    if (bills.isNotEmpty && !await ask(context, 'Clear the bills built on this page?', 'What is typed here and not saved will be removed. Saved entries are not touched.', yes: 'Clear')) return;
    setState(() {
      picked.clear();
      bills = [];
      logs = null;
    });
  }

  // ---------- print ----------
  Future<String> _sheets(Map<String, dynamic> b, String cls, String logo) async {
    final s = SessionScope.read(context), l = logs;
    final lb = l == null ? '' : billLogSheets(s, b, l.rows, l.from, l.to, l.extra, logo: logo);
    return billSheets(b, cls, logo: logo) + lb;
  }

  Future<void> _preview([int? one]) async {
    if (bills.isEmpty) return;
    final logo = await logoFor(builtCo);
    final list = one == null ? bills : [bills[one]];
    final pages = StringBuffer();
    var anyLb = false;
    for (final b in list) {
      final p = await _sheets(b, ' draft', logo);
      if (p.contains('class="lbsheet"')) anyLb = true;
      pages.write(p);
    }
    if (!mounted) return;
    await showBillPrint(context, 'Bill preview – ${showDate(builtFrom)} to ${showDate(builtTo)}', '$pages', withLb: anyLb, foot: builtCo);
  }

  Future<void> _logPrint(List<Map<String, dynamic>> list) async {
    final l = logs, s = SessionScope.read(context);
    if (l == null) return;
    final nos = {for (final b in list) for (final m in (b['machines'] as List).whereType<Map>()) '${m['no']}'.toUpperCase()};
    final rows = l.rows.where((r) => nos.contains('${r['no']}'.toUpperCase())).toList();
    if (rows.isEmpty) return toast(context, 'No Log Book entries for these machinery in these dates.', bad: true);
    String k(Object? no) => '$no'.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final idle = {for (final b in list) for (final m in (b['machines'] as List).whereType<Map>()) k(m['no']): b['idlePaid'] != false};
    final rateBy = {
      for (final b in list)
        if ((num.tryParse('${b['dieselRate'] ?? ''}') ?? 0) > 0)
          for (final m in (b['machines'] as List).whereType<Map>()) k(m['no']): num.parse('${b['dieselRate']}')
    };
    final one = list.length == 1 ? (num.tryParse('${list.first['dieselRate'] ?? ''}') ?? 0) : 0;
    await printLogBook(context, s, rows: rows, from: l.from, to: l.to, idle: idle, rateBy: rateBy, dieselRate: one > 0 ? one : 0);
  }

  // ---------- Verify & Submit ----------
  Future<void> _submit() async {
    final s = SessionScope.read(context);
    if (bills.isEmpty) return;
    if (!s.canEdit('Machinery Billing')) return toast(context, 'You have View access only for Machinery Billing.', bad: true);
    final noIdle = bills.where((b) => (num.tryParse('${b['idleDays']}') ?? 0) > 0 && !b.containsKey('idlePaid')).toList();
    if (noIdle.isNotEmpty) {
      await tellLines(context, 'Idle days – Paid or Not paid?', [
        'These bills have Idle days in the Log Book. Choose Paid or Not paid in the Idle days of each bill, then verify again:',
        for (final b in noIdle) '${(b['vendor'] as Map)['name']}${b['partial'] == true ? ' (${(b['picked'] as List).join(', ')})' : ''} – ${b['idleDays']} Idle day(s)',
      ]);
      return;
    }
    setState(() => busy = true);
    try {
      final v = (await s.api.call('verifyBills', [
        {'bills': bills}
      ])) as Map;
      final res = [for (final x in (v['bills'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
      if (!mounted) return;
      setState(() => busy = false);
      final good = res.where((x) => !_bad(x)).length, bad = res.where(_bad).toList();
      if (good == 0) {
        await _checks('Cannot submit – please correct', res, top: 'Correct the ✖ points (Log Book, Diesel, BOQ, Master, bill details), then Build bills again and verify.', alert: true);
        return;
      }
      final okBills = [for (var i = 0; i < bills.length && i < res.length; i++) if (!_bad(res[i])) bills[i]];
      final go = await _checks('Verification – $good of ${res.length} bill${res.length == 1 ? '' : 's'} ready', res,
          foot: [if (bad.isNotEmpty) '${bad.length} bill(s) with ✖ will not be submitted: ${bad.map((x) => x['vendor']).join(', ')}.', 'Submitted bills are saved exactly as they are and cannot be changed later.'], yes: 'Submit $good bill${good == 1 ? '' : 's'}');
      if (!go || !mounted) return;
      await _send(s, okBills);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: true);
    }
  }

  bool _bad(Map x) => (num.tryParse('${x['bad'] ?? 0}') ?? 0) > 0 || x['bad'] == true;

  Map<String, dynamic> _pack(List<Map<String, dynamic>> ok, bool? keep) => {
        'bills': [
          for (final b in ok) {'vendor': (b['vendor'] as Map)['name'], 'company': b['company'], 'billNo': b['billNo'], 'from': b['from'], 'to': b['to'], 'billDate': b['billDate'], 'net': b['I'], 'data': {...b, 'edited': false}}
        ],
        'confirm': keep != null,
      };

  Future<void> _send(Session s, List<Map<String, dynamic>> ok) async {
    setState(() => busy = true);
    try {
      var res = ((await s.api.call('submitBills', [_pack(ok, null)], true)) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (res['ok'] != true && res['errors'] is List) {
        setState(() => busy = false);
        await tellLines(context, 'Not submitted', [for (final e in res['errors'] as List) '$e']);
        return;
      }
      if (res['ok'] != true && res['duplicates'] is List) {
        setState(() => busy = false);
        final dups = [for (final d in (res['duplicates'] as List).whereType<Map>()) d];
        final keep = await _askDup(dups);
        if (keep == null || !mounted) return;
        if (!keep) {
          final dupIdx = [for (final d in dups) d['i']];
          final nx = <String, num>{};
          for (var k = 0; k < ok.length; k++) {
            if (!dupIdx.contains(k)) continue;
            final b = ok[k], nk = '${(b['vendor'] as Map)['name']}'.toUpperCase() + '|${b['company']}';
            nx[nk] = (nx[nk] ?? (num.tryParse('${(init?['lastNo'] as Map?)?[nk] ?? 0}') ?? 0)) + 1;
            b['billNo'] = '${nx[nk]!.toInt()}';
          }
          setState(() => _gen++);
        }
        setState(() => busy = true);
        res = ((await s.api.call('submitBills', [_pack(ok, keep)], true)) as Map).cast<String, dynamic>();
        if (!mounted) return;
        if (res['ok'] != true) {
          setState(() => busy = false);
          await tellLines(context, 'Not submitted', [for (final e in (res['errors'] as List? ?? const ['Try again.'])) '$e']);
          return;
        }
      }
      final saved = [for (final x in (res['saved'] as List? ?? const []).whereType<Map>()) x];
      for (var k = 0; k < saved.length && k < ok.length; k++) {
        ok[k]['rev'] = saved[k]['rev'];
        ok[k]['billId'] = saved[k]['id'];
      }
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, '${saved.length} bill(s) verified and submitted.');
      _loadInit();
      // the submitted bills exactly as saved – with Print
      final got = await Future.wait([
        for (final x in saved)
          s.api
              .call('getBills', [
                {'id': x['id']}
              ])
              .then<Map?>((r) => ((r as Map)['bills'] as List).first as Map)
              .catchError((Object _) => null)
      ]);
      final logo = await logoFor(builtCo);
      final pages = StringBuffer();
      var anyLb = false;
      for (final b in got.whereType<Map>()) {
        final data = <String, dynamic>{'dnNo': b['dnNo'], ...((b['data'] as Map?) ?? const {}).cast<String, dynamic>(), 'billNo': b['billNo'], 'rev': b['rev']};
        final l = logs;
        final lb = l == null ? '' : billLogSheets(s, {...data, 'company': b['company']}, l.rows, l.from, l.to, l.extra, logo: logo);
        if (lb.isNotEmpty) anyLb = true;
        pages.write(billSheets(data, '', logo: logo) + lb);
      }
      if (pages.isEmpty || !mounted) return;
      await showBillPrint(context, 'Submitted bill${got.length == 1 ? '' : 's'} – ${showDate(builtFrom)} to ${showDate(builtTo)}', '$pages', withLb: anyLb, foot: builtCo);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  Future<bool?> _askDup(List<Map> dups) {
    var keep = true;
    return showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, set) => AlertDialog(
          title: Text('Already submitted'),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('These vendors already have a submitted bill for the same period:'),
            const SizedBox(height: 6),
            for (final d in dups)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${d['vendor']}: ${[for (final x in (d['existing'] as List? ?? const []).whereType<Map>()) 'RA Bill ${x['billNo']}${(num.tryParse('${x['rev']}') ?? 0) != 0 ? ' rev ${x['rev']}' : ''} of ${showDate('${x['billDate']}')} (₹${n2(x['net'])}, ${x['status']})'].join('; ')}', style: const TextStyle(fontSize: 14)),
              ),
            const SizedBox(height: 6),
            Text('The new bill will also be saved and the older one marked Superseded.', style: const TextStyle(color: C.muted)),
            for (final o in const [(true, 'Keep the same bill number (saved as a revision)'), (false, 'Give a new bill number')])
              ListTile(
                key: Key('dup-${o.$1 ? 'keep' : 'new'}'),
                contentPadding: EdgeInsets.zero,
                onTap: () => set(() => keep = o.$1),
                leading: Icon(keep == o.$1 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: keep == o.$1 ? C.green : C.faint),
                title: Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc), child: Text('Cancel')),
            FilledButton(key: const Key('dup-ok'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(dc, keep), child: Text('Submit')),
          ],
        ),
      ),
    );
  }

  /// The server's checks of every bill (✔ ⚠ ✖).
  Future<bool> _checks(String title, List<Map<String, dynamic>> res, {String top = '', List<String> foot = const [], String yes = 'OK', bool alert = false}) async =>
      await showDialog<bool>(
        context: context,
        builder: (dc) => AlertDialog(
          title: Text(title),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (top.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(top)),
            for (var i = 0; i < res.length; i++) _checkCard(res[i], i < bills.length ? bills[i] : const {}),
            for (final f in foot) Padding(padding: const EdgeInsets.only(top: 6), child: Text(f, style: TextStyle(fontSize: 13.5, color: f.contains('✖') ? C.red : C.muted))),
          ]),
          actions: [
            if (!alert) TextButton(onPressed: () => Navigator.pop(dc, false), child: Text('Cancel')),
            FilledButton(key: const Key('vf-ok'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(dc, !alert), child: Text(yes)),
          ],
        ),
      ) ??
      false;

  Widget _checkCard(Map x, Map b) {
    final bad = num.tryParse('${x['bad'] ?? 0}') ?? 0, warn = num.tryParse('${x['warn'] ?? 0}') ?? 0;
    final col = bad > 0 ? C.red : warn > 0 ? C.amber : C.greenDark, bg = bad > 0 ? C.redSoft : warn > 0 ? C.amberSoft : C.greenSoft;
    const icon = {'ok': '✔', 'warn': '⚠', 'bad': '✖'};
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${x['vendor']}${b['partial'] == true ? ' (${(b['picked'] as List).join(', ')})' : ''} – RA Bill ${'${x['billNo'] ?? ''}'.isNotEmpty ? x['billNo'] : '–'} – Net ₹${n2(x['net'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(bad > 0 ? '✖ ${fmt(bad)} problem${bad == 1 ? '' : 's'} – cannot submit' : warn > 0 ? '⚠ OK with ${fmt(warn)} note${warn == 1 ? '' : 's'}' : '✔ All correct', style: TextStyle(color: col, fontWeight: FontWeight.w700)),
        for (final c in (x['checks'] as List? ?? const []).whereType<Map>())
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('${icon[c['s']] ?? '•'} ${c['t']}', style: TextStyle(fontSize: 13, color: c['s'] == 'bad' ? C.red : c['s'] == 'warn' ? C.amber : C.ink)),
          ),
      ]),
    );
  }

  // ---------- company details / month close ----------
  Future<void> _saveCo() async {
    final s = SessionScope.read(context), cos = <String, Map<String, String>>{};
    for (final n in ((_settings['companies'] as Map?) ?? const {}).keys) {
      cos['$n'] = {for (final k in const ['address', 'gstin', 'pan', 'invPrefix', 'dnPrefix']) k: _co['$n|$k']?.text.trim() ?? ''};
    }
    setState(() => busy = true);
    try {
      final st = await s.api.call('saveBillSettings', [
        {'project': _co['project']?.text.trim() ?? '', 'siteAddress': _co['site']?.text.trim() ?? '', 'companies': cos}
      ], true);
      if (!mounted) return;
      setState(() {
        busy = false;
        init?['settings'] = st;
      });
      _fillCo();
      toast(context, 'Company details saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  Future<void> _lock(bool close) async {
    final s = SessionScope.read(context);
    if (close && lkDate.isEmpty) return toast(context, 'Select a Date.', bad: true);
    final ok = close
        ? await ask(context, 'Close entries up to ${showDate(lkDate)}?', 'No diesel, Log Book, tank-check or breakdown entry dated on or before ${showDate(lkDate)} can then be added, changed or deleted by anyone – until you reopen it here. Submit the bills of that period first.', yes: 'Close')
        : await ask(context, 'Reopen the closed period?', 'Entries of every date can be changed again${s.closedUpto.isNotEmpty ? ' (now closed up to ${showDate(s.closedUpto)})' : ''}. A bill that was submitted may then no longer match its entries – build it again after the correction.', yes: 'Reopen');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      final r = (await s.api.call('saveBooksLock', [
        {'upto': close ? lkDate : ''}
      ], true)) as Map;
      s.closedUpto = '${r['upto'] ?? ''}';
      if (!mounted) return;
      setState(() {
        busy = false;
        lkDate = s.closedUpto;
      });
      toast(context, close ? 'Entries up to ${showDate(s.closedUpto)} are closed.' : 'Reopened – nothing is closed now.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), can = s.canEdit('Machinery Billing');
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Machinery Billing', 'यंत्र बिलिंग', size: 20, weight: FontWeight.w700), actions: [const GuideButton('bill'), IconButton(tooltip: tr('Refresh'), onPressed: _loadInit, icon: const Icon(Icons.refresh_rounded))]),
      bottomNavigationBar: bills.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(key: const Key('mb-preview'), style: kSmallBtn, onPressed: busy ? null : () => _preview(), icon: const Icon(Icons.visibility_outlined, size: 20), label: Text('Preview', maxLines: 1))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(key: const Key('mb-logbook'), style: kSmallBtn, onPressed: busy ? null : () => _logPrint(bills), icon: const Icon(Icons.menu_book_rounded, size: 20), label: Text('Log Book', maxLines: 1))),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: FilledButton.icon(key: const Key('mb-submit'), style: FilledButton.styleFrom(minimumSize: const Size(0, 50)), onPressed: busy || !can ? null : _submit, icon: const Icon(Icons.verified_rounded), label: Text('Verify & Submit', maxLines: 1))),
                ]),
              ),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(key: const Key('mb-list'), padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
              if (err.isNotEmpty) InfoLine(err, bad: true),
              if (s.admin) _lockCard(s),
              _filters(s, can),
              if (showCo && can) _coCard(),
              if (bills.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Bills – ${bills.length} vendor${bills.length == 1 ? '' : 's'}', key: const Key('mb-title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('${showDate(builtFrom)} to ${showDate(builtTo)} · $builtCo', style: const TextStyle(fontSize: 13, color: C.muted)),
                const SizedBox(height: 8),
                for (var i = 0; i < bills.length; i++) _billCard(i, bills[i]),
              ],
            ]),
    );
  }

  Widget _card(List<Widget> children, {Key? key, Color? bg}) => Container(
        key: key,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg ?? Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _lockCard(Session s) => _card(key: const Key('lk-card'), bg: C.slateSoft, [
        Text('Month close', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Text('Admin only. After the bills of a month are submitted, close the month: no diesel, Log Book, tank-check or breakdown entry dated on or before the date can then be added, changed or deleted – by anyone. Bills, debit notes and payments are not closed.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
        const SizedBox(height: 8),
        DateField(key: const Key('lk-date'), label: 'Entries are closed up to', value: lkDate, onChanged: (v) => setState(() => lkDate = v)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(key: const Key('lk-save'), onPressed: busy ? null : () => _lock(true), child: Text('Close up to this date')),
          OutlinedButton(key: const Key('lk-open'), style: kSmallBtn, onPressed: busy ? null : () => _lock(false), child: Text('Reopen (close nothing)')),
        ]),
        const SizedBox(height: 6),
        Text(s.closedUpto.isNotEmpty ? 'Now closed up to ${showDate(s.closedUpto)}.' : 'Nothing is closed now.', key: const Key('lk-now'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]);

  Widget _filters(Session s, bool can) {
    final t = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    return _card([
      Text('Pick the period and the vendors – one bill (one page) per vendor, all its machinery in it. Preview to check; Verify & Submit – the system checks each bill against the Log Book, diesel and BOQ, then submits and opens it to print.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: DateField(key: const Key('mb-from'), label: 'From', value: from, clear: false, onChanged: (v) => setState(() => from = v))),
        const SizedBox(width: 8),
        Expanded(child: DateField(key: const Key('mb-to'), label: 'To', value: to, clear: false, onChanged: (v) => setState(() => to = v))),
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        ActionChip(key: const Key('mb-this'), label: Text('This month'), onPressed: () => setState(() {
              from = '${t.substring(0, 8)}01';
              to = t;
            })),
        ActionChip(key: const Key('mb-last'), label: Text('Last month'), onPressed: () => setState(() {
              from = _lastMonthFrom(t);
              to = _lastMonthTo(t);
            })),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: DateField(key: const Key('mb-date'), label: 'Bill Date', value: billDate, onChanged: (v) => setState(() => billDate = v))),
        const SizedBox(width: 8),
        Expanded(child: PickField(key: const Key('mb-co'), label: 'Name on the bill', value: co, items: kBillNames, onChanged: (v) => setState(() => co = v))),
      ]),
      const SizedBox(height: 10),
      Text('Vendors (Rental / Hired / Debit)', style: const TextStyle(fontSize: 12.5, color: C.muted)),
      const SizedBox(height: 4),
      Press(
        key: const Key('mb-vendors'),
        radius: 14,
        shadow: false,
        padding: const EdgeInsets.all(12),
        onTap: _vendors.isEmpty ? null : _pickVendors,
        child: Row(children: [
          Expanded(child: Text(_vendors.isEmpty ? 'No Rental / Hired / Debit vendor with machinery yet.' : _pickText(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: picked.values.any((x) => x.isNotEmpty) ? C.ink : C.muted))),
          const Icon(Icons.expand_more_rounded, color: C.muted),
        ]),
      ),
      const SizedBox(height: 8),
      PickField(
        key: const Key('mb-per'),
        label: 'One bill per',
        value: per == 'vendor' ? 'Vendor – its picked machinery in one bill' : 'Machinery – a separate bill for each',
        items: const ['Vendor – its picked machinery in one bill', 'Machinery – a separate bill for each'],
        onChanged: (v) => setState(() => per = v.startsWith('Vendor') ? 'vendor' : 'machine'),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(key: const Key('mb-build'), onPressed: busy ? null : _build, icon: const Icon(Icons.receipt_long_rounded), label: Text(busy ? 'Building…' : 'Build bills')),
        OutlinedButton(key: const Key('mb-clear'), style: kSmallBtn, onPressed: busy ? null : _clear, child: Text('Clear')),
        if (can) OutlinedButton(key: const Key('mb-co-btn'), style: kSmallBtn, onPressed: () => setState(() => showCo = !showCo), child: Text('Company details')),
      ]),
    ]);
  }

  Widget _coCard() {
    final cos = ((_settings['companies'] as Map?) ?? const {}).keys.map((k) => '$k').toList();
    TextEditingController c(String k) => _co.putIfAbsent(k, () => TextEditingController());
    return _card(key: const Key('mb-co-card'), [
      TextBox(label: 'Project Name (printed on every bill)', controller: c('project'), maxLines: 3),
      const SizedBox(height: 8),
      TextBox(label: 'Site Address (a separate line on every bill – same for Sketchline and Rachana)', controller: c('site'), maxLines: 3),
      for (final n in cos) ...[
        const SizedBox(height: 12),
        Text(n, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TextBox(label: 'Address (as per GST)', controller: c('$n|address'), maxLines: 2),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextBox(label: 'GSTIN', controller: c('$n|gstin'), upper: true)),
          const SizedBox(width: 8),
          Expanded(child: TextBox(label: 'PAN', controller: c('$n|pan'), upper: true)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextBox(label: 'Tax Invoice no. starts with', controller: c('$n|invPrefix'), hint: 'e.g. SLI/VTR/RA-')),
          const SizedBox(width: 8),
          Expanded(child: TextBox(label: 'Debit Note no. starts with', controller: c('$n|dnPrefix'), hint: 'e.g. SLI/VTR/DN-')),
        ]),
      ],
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerLeft, child: FilledButton(key: const Key('mbs-save'), onPressed: busy ? null : _saveCo, child: Text('Save company details'))),
    ]);
  }

  // ---------- one bill ----------
  Widget _billCard(int i, Map<String, dynamic> b) {
    final v = (b['vendor'] as Map?) ?? const {}, warns = [for (final w in (b['warnings'] as List? ?? const [])) '$w'];
    final ne = billNoEntry(b), corr = [for (final z in (b['corr'] as List? ?? const []).whereType<Map>()) z], dnOpen = [for (final n in (b['dnOpen'] as List? ?? const []).whereType<Map>()) n];
    final dns = [for (final n in (b['dns'] as List? ?? const []).whereType<Map>()) n];
    final ms = [for (final m in (b['machines'] as List? ?? const []).whereType<Map>()) m];
    final idleDays = num.tryParse('${b['idleDays'] ?? 0}') ?? 0, hasDiesel = ms.any((x) => (num.tryParse('${x['debitQty'] ?? 0}') ?? 0) + (num.tryParse('${x['excessQty'] ?? 0}') ?? 0) > 0);
    final auto = ms.isNotEmpty ? ms.first['autoRate'] : 0, j = num.tryParse('${b['J'] ?? 0}') ?? 0;
    Widget fig(String k, String v, {bool strong = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(fontSize: 13.5, color: strong ? C.ink : C.muted, fontWeight: strong ? FontWeight.w700 : FontWeight.w500))),
            Text(v, style: TextStyle(fontSize: strong ? 17 : 14.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w700, color: color ?? C.ink)),
          ]),
        );
    return Padding(
      key: Key('mb-bill-$i'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: warns.isEmpty ? C.line : C.amber)),
      child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${v['name']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (b['partial'] == true) Text((b['picked'] as List).join(', '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
              Text('${ms.length} machinery', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ]),
          ),
          warns.isEmpty ? Pill('OK', color: C.greenDark, bg: C.greenSoft) : Pill('${warns.length} to check', color: C.amber, bg: C.amberSoft),
        ]),
        if (ne.isNotEmpty) _note('⚠ Diesel issued on a day with no Log Book entry: $ne. It is counted in this bill.', C.amber, C.amberSoft),
        if (warns.isNotEmpty) _note(['⚠ To check before submitting:', for (final w in warns) '• $w'].join('\n'), C.amber, C.amberSoft, key: Key('mb-warn-$i')),
        if ('${b['corrErr'] ?? ''}'.isNotEmpty) _note('⚠ Earlier bills could not be checked: ${b['corrErr']}', C.red, C.redSoft),
        if (corr.isNotEmpty) ...[
          _note('Earlier bills changed – tick each one after checking (it is taken in this bill; without it the bill is not submitted):', C.blue, C.blueSoft),
          for (final z in corr)
            CheckboxListTile(
              key: Key('mb-corr-$i-${z['key']}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: z['checked'] == true,
              onChanged: (on) => setState(() => z['checked'] = on == true),
              title: Text('RA Bill ${z['billNo']}${(num.tryParse('${z['rev']}') ?? 0) != 0 ? ' rev ${z['rev']}' : ''} · ${z['no']} (${showDate('${z['from']}')} to ${showDate('${z['to']}')})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(
                  '${corrCalc(z).replaceAll('<br>', '\n').replaceAll(RegExp(r'<[^>]+>'), '')} → ${z['kind'] == 'Credit' ? 'Credit Note' : 'Debit Note'} ${corrSgn(z['kind'] == 'Credit' ? (num.tryParse('${z['total']}') ?? 0) : -(num.tryParse('${z['total']}') ?? 0))}${(num.tryParse('${z['gst'] ?? 0}') ?? 0) != 0 || (num.tryParse('${z['tds'] ?? 0}') ?? 0) != 0 ? ' (incl. GST ${fmt(z['gstPct'])}%, TDS ${fmt(z['tdsPct'])}%)' : ''}',
                  style: const TextStyle(fontSize: 12.5)),
            ),
        ],
        if (dnOpen.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Debit notes to deduct:', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          for (final n in dnOpen)
            CheckboxListTile(
              key: Key('mb-dn-$i-${n['id']}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: dns.any((z) => z['id'] == n['id']),
              onChanged: (on) => setState(() {
                final keep = [for (final z in dns) if (z['id'] != n['id']) z];
                if (on == true) keep.add({'id': n['id'], 'no': n['no'], 'date': n['date'], 'total': n['total']});
                b['dns'] = keep;
                mbTotals(b);
              }),
              title: Text('${n['no']} · ₹${n2(n['total'])}', style: const TextStyle(fontSize: 13.5)),
            ),
        ],
        const Divider(height: 18),
        if (idleDays > 0)
          Row(children: [
            Expanded(child: Text('Idle days: ${fmt(idleDays)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
            SizedBox(
              width: 170,
              child: PickField(
                key: Key('mb-idle-$i'),
                label: 'Pay them in this bill?',
                value: !b.containsKey('idlePaid') ? 'choose…' : b['idlePaid'] == true ? 'Paid' : 'Not paid',
                items: const ['choose…', 'Paid', 'Not paid'],
                onChanged: (x) {
                  if (x == 'choose…') {
                    b.remove('idlePaid');
                  } else {
                    b['idlePaid'] = x == 'Paid';
                  }
                  _refill(b);
                },
              ),
            ),
          ]),
        fig('Workdone (A)', n2(b['A'])),
        fig('Diesel ded. (B)', n2(b['B'])),
        if (hasDiesel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Focus(
              onFocusChange: (on) {
                if (!on) _rate(b, _box(i, 'dr', ''));
              },
              child: TextField(
                key: Key('mb-dr-$i'),
                controller: _box(i, 'dr', (num.tryParse('${b['dieselRate'] ?? ''}') ?? 0) > 0 ? '${b['dieselRate']}' : ''),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onSubmitted: (_) => _rate(b, _box(i, 'dr', '')),
                decoration: InputDecoration(isDense: true, labelText: tr('Diesel rate ₹/L of this bill'), hintText: '${n2(auto)} auto', helperText: tr('Empty = automatic: the higher of the average rate of the period and the last purchase rate.'), helperMaxLines: 3),
              ),
            ),
          ),
        Row(children: [
          Expanded(
            child: TextField(
              key: Key('mb-c-$i'),
              controller: _box(i, 'c', (num.tryParse('${b['C'] ?? 0}') ?? 0) != 0 ? '${b['C']}' : ''),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onChanged: (x) => setState(() {
                b['C'] = num.tryParse(x) ?? 0;
                mbTotals(b);
              }),
              decoration: InputDecoration(isDense: true, labelText: tr('Other ded. (C)'), hintText: '0'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('mb-cr-$i'),
              controller: _box(i, 'cr', '${b['cReason'] ?? ''}'),
              onChanged: (x) => setState(() => b['cReason'] = x),
              decoration: InputDecoration(isDense: true, labelText: tr('Reason for C'), hintText: tr('reason')),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        fig('GST', (num.tryParse('${b['gstPct'] ?? 0}') ?? 0) != 0 ? n2(r2((num.tryParse('${b['E']}') ?? 0) + (num.tryParse('${b['F']}') ?? 0))) : '–'),
        fig('TDS', n2(b['H'])),
        fig('Net Payable', n2(b['I']), strong: true, color: C.greenDark),
        if (j != 0) fig('${j > 0 ? 'less' : 'add'} notes ${n2(j.abs())} · balance', n2(b['K']), strong: true),
        const SizedBox(height: 6),
        TextField(
          key: Key('mb-no-$i'),
          controller: _box(i, 'no', '${b['billNo'] ?? ''}'),
          onChanged: (x) => setState(() => b['billNo'] = x.trim()),
          decoration: InputDecoration(
            isDense: true,
            labelText: tr('RA Bill No'),
            hintText: b['firstBill'] == true ? tr('first bill – type no.') : null,
            helperText: b['firstBill'] == true ? tr('First bill of this vendor under this name – type its RA bill number; after this the next number comes by itself') : null,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          OutlinedButton.icon(key: Key('mb-papers-$i'), style: kSmallBtn, onPressed: () => _preview(i), icon: const Icon(Icons.description_outlined), label: Text('Papers')),
          OutlinedButton.icon(key: Key('mb-lb-$i'), style: kSmallBtn, onPressed: () => _logPrint([b]), icon: const Icon(Icons.menu_book_rounded), label: Text('Log Book')),
        ]),
      ]),
      ),
      ),
    );
  }

  void _rate(Map<String, dynamic> b, TextEditingController c) {
    final t = c.text.trim(), v = t.isEmpty ? null : num.tryParse(t);
    final now = num.tryParse('${b['dieselRate'] ?? ''}') ?? 0;
    if (t.isNotEmpty && (v == null || !(r2(v) >= 0.01 && v < 1000))) {
      toast(context, 'Diesel rate: type ₹ per litre (for example 95.50), or leave it empty for the automatic rate.', bad: true);
      c.text = now > 0 ? '$now' : '';
      return;
    }
    if ((v == null && now == 0) || (v != null && r2(v) == now)) return;
    b['dieselRate'] = v == null ? '' : r2(v);
    _refill(b);
    toast(context, v == null ? 'Diesel rate of this bill: automatic again.' : 'Diesel of this bill is debited at ₹${n2(v)} per litre.');
  }

  Widget _note(String t, Color c, Color bg, {Key? key}) => Container(
        key: key,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: TextStyle(fontSize: 13, color: c, height: 1.35, fontWeight: FontWeight.w600)),
      );
}

/// The vendors and their machinery to bill: search, a vendor ticks all its machinery, Select all / Clear the vendors shown.
class _VendorSheet extends StatefulWidget {
  const _VendorSheet({required this.vendors, required this.picked});
  final List<Map<String, dynamic>> vendors;
  final Map<String, Set<String>> picked;
  @override
  State<_VendorSheet> createState() => _VendorSheetState();
}

class _VendorSheetState extends State<_VendorSheet> {
  String q = '';
  final open = <String>{};

  List<Map> _ms(Map v) => [for (final m in (v['machines'] as List? ?? const []).whereType<Map>()) m];

  bool _hit(Map v) {
    if (q.isEmpty) return true;
    final x = q.toLowerCase();
    return '${v['name']}'.toLowerCase().contains(x) || _ms(v).any((m) => '${m['id']} ${m['type'] ?? ''} ${m['ownership'] ?? ''}'.toLowerCase().contains(x));
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.vendors.where(_hit).toList(), p = widget.picked;
    final nV = p.values.where((x) => x.isNotEmpty).length, nM = p.values.fold<int>(0, (a, x) => a + x.length);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .82,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: TextField(key: const Key('mbv-q'), autofocus: false, onChanged: (v) => setState(() => q = v.trim()), decoration: InputDecoration(hintText: tr('Search vendor…'), prefixIcon: const Icon(Icons.search_rounded), isDense: true)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                TextButton(
                  key: const Key('mbv-all'),
                  onPressed: () => setState(() {
                    for (final v in shown) {
                      p['${v['name']}'] = {for (final m in _ms(v)) '${m['id']}'};
                    }
                  }),
                  child: Text('Select all'),
                ),
                TextButton(
                  key: const Key('mbv-none'),
                  onPressed: () => setState(() {
                    for (final v in shown) {
                      p.remove('${v['name']}');
                    }
                  }),
                  child: Text('Clear'),
                ),
                const Spacer(),
                Text('$nV of ${widget.vendors.length} vendors · $nM machinery', style: const TextStyle(fontSize: 12.5, color: C.muted)),
              ]),
            ),
            Expanded(
              child: ListView(children: [
                for (final v in shown) ..._vendor(v),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(width: double.infinity, child: FilledButton(key: const Key('mbv-done'), onPressed: () => Navigator.pop(context), child: Text('Done'))),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _vendor(Map v) {
    final name = '${v['name']}', ms = _ms(v), got = widget.picked[name] ?? <String>{};
    final n = ms.where((m) => got.contains('${m['id']}')).length;
    final mHit = q.isNotEmpty && !name.toLowerCase().contains(q.toLowerCase());
    final isOpen = open.contains(name) || mHit;
    return [
      ListTile(
        key: Key('mbv-$name'),
        leading: Checkbox(
          tristate: true,
          value: n == 0 ? false : n == ms.length ? true : null,
          onChanged: (_) => setState(() {
            if (n == ms.length) {
              widget.picked.remove(name);
            } else {
              widget.picked[name] = {for (final m in ms) '${m['id']}'};
            }
          }),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: TextButton.icon(
          key: Key('mbv-exp-$name'),
          onPressed: () => setState(() => open.contains(name) ? open.remove(name) : open.add(name)),
          icon: Icon(isOpen ? Icons.expand_less_rounded : Icons.chevron_right_rounded),
          label: Text('${n > 0 && n < ms.length ? '$n of ' : ''}${ms.length} machinery'),
        ),
      ),
      if (isOpen)
        for (final m in ms)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: CheckboxListTile(
              key: Key('mbv-m-${m['id']}'),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: got.contains('${m['id']}'),
              onChanged: (on) => setState(() {
                final s = widget.picked.putIfAbsent(name, () => <String>{});
                on == true ? s.add('${m['id']}') : s.remove('${m['id']}');
              }),
              title: Text('${m['id']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text([m['type'], m['ownership']].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12)),
            ),
          ),
    ];
  }
}
