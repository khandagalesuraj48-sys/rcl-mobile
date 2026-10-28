/* (3.56.0, Mechanical update-180, asked 28-10-2026: "kontya hi gadichi log book maintanace wala ek ek entry mala edit or delet krta yawi";
 * his answer: each line on its own – the bill's Change / Delete stay) ONE LINE OF A BILL OF THE MAINTENANCE LOG BOOK, changed or deleted
 * on the phone – the app's own screens of the web's log book (its Edit · Delete on each line):
 *   MaintLinesScreen – the bills of the log book shown (any machinery, its dates or start to end), each with its lines; each line its
 *                      Edit and Delete (Maintenance Edit – the Store's issues and the fuel are not lines of a bill); after a change the
 *                      log book is read again.
 *   MaintLineForm    – one line: Particulars, Paid by, Qty, Uom, Rate, Disc %, Amount, GST % (as a line of the bill's form: a Paid line's
 *                      ₹ from Qty × Rate − Disc %, a free line ₹ 0) → updateMaintLine; the rest of the bill stays as it is.
 * Delete → deleteMaintLine; the only line of a bill: the whole bill is deleted (deleteMaint), said first. The same server actions, checks
 * and access as the web – the server checks the line is still the one shown (changed by someone meanwhile: refused).
 * (3.59.0, Mechanical update-183) a line of the old log book (its GST ₹ as in the file, no GST %): "GST ₹ (as in the old log book)" – kept
 * as it is (changed only by typing it); a GST % typed takes its place (as the web's mll_ga). */
import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/rdoc.dart' show listOf, money;
import '../ui/ask_bot.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'fuel_cards.dart' show rupees;
import '../core/maint_import.dart' show mtHasGa, mtLineGst;
import 'maintenance.dart' show kMaintKinds, kMaintPaidBy, kMaintUoms, maintCharged, maintGst, maintLineGst, maintPaidBy;

/// The bills of a log book (maintLog) with lines of their own: its Maintenance bills (not the Store's issues, not the fuel)
List<Map<String, dynamic>> maintLineBills(Map<String, dynamic> log) => [
      for (final x in listOf(log['lines']))
        if (x['kind'] == 'Maintenance' && '${x['id'] ?? ''}'.isNotEmpty) x,
    ];

/// A line in words: its ₹ with GST (a free line: its kind) – as the web's mlLineSay
String maintLineSay(Map l) => '${l['work']} – ${maintCharged(l['type']) ? rupees((asNum(l['amount']) ?? 0) + maintLineGst(l)) : tr(maintPaidBy(l['type']))}';

/// A bill in words: "Bill MT-000002 · 05-01-2023 · Store · bill no. B-1" – as the web's mlBillSay
String maintBillSay(Map b) =>
    'Bill ${b['id']} · ${showDate('${b['date']}')}${'${b['garage'] ?? ''}'.isNotEmpty ? ' · ${b['garage']}' : ''}${'${b['billNo'] ?? ''}'.isNotEmpty ? ' · bill no. ${b['billNo']}' : ''}';

/// what a line sends as it was shown – the server refuses it when the bill was changed meanwhile
Map<String, Object?> maintLineWas(Map b, int i) {
  final l = listOf(b['lines'])[i];
  return {'i': i, 'date': '${b['date']}', 'was': {'work': l['work'], 'amount': l['amount']}};
}

class MaintLinesScreen extends StatefulWidget {
  const MaintLinesScreen({super.key, required this.log, required this.filter});

  /// the log book as shown (maintLog's answer) and what it was made with (read again after a change)
  final Map<String, dynamic> log, filter;
  @override
  State<MaintLinesScreen> createState() => _MaintLinesScreenState();
}

class _MaintLinesScreenState extends State<MaintLinesScreen> {
  late Map<String, dynamic> log = widget.log;
  bool busy = false;
  String err = '';

  Future<void> _again() async {
    final s = SessionScope.read(context);
    try {
      final d = (await s.api.call('maintLog', [widget.filter]) as Map).cast<String, dynamic>();
      if (mounted) setState(() => log = d);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  Future<void> _edit(Map<String, dynamic> b, int i) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => MaintLineForm(bill: b, i: i, no: '${log['machine']?['id'] ?? ''}')));
    if (done == true && mounted) await _again();
  }

  Future<void> _delete(Map<String, dynamic> b, int i) async {
    final s = SessionScope.read(context), lines = listOf(b['lines']), l = lines[i], id = '${b['id']}';
    final only = lines.length == 1;
    final yes = only
        ? await ask(context, tr('Delete bill $id?'), '${tr('"${l['work']}" is the only line of this bill – the whole bill is deleted.')}\n${maintBillSay(b)}\n${b['no'] ?? ''} – ${rupees(asNum(b['total']))}', yes: 'Delete the bill', danger: true)
        : await ask(context, tr('Delete this line?'), '${maintLineSay(l)}\n${maintBillSay(b)}\n${tr('The other lines of the bill stay as they are.')}', yes: 'Delete', danger: true);
    if (!yes || !mounted) return;
    setState(() {
      busy = true;
      err = '';
    });
    try {
      if (only) {
        await s.api.call('deleteMaint', [id], true);
        if (mounted) toast(context, tr('$id deleted.'));
      } else {
        final r = (await s.api.call('deleteMaintLine', [id, maintLineWas(b, i)], true) as Map).cast<String, dynamic>();
        if (mounted) toast(context, tr('Line deleted – bill $id is now ₹${money(r['total'])}.'));
      }
      s.dataTick.value++;
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: !isSent(e));
    }
    if (!mounted) return;
    setState(() => busy = false);
    await _again();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), bills = maintLineBills(log), can = s.canEdit('Maintenance');
    final m = (log['machine'] as Map?) ?? const {};
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: Text('Edit / delete a line – ${m['id'] ?? ''}')),
      body: ListView(key: const Key('ml-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        Text('Each line of a bill on its own – the other lines of the bill stay as they are. The bill itself: Change / Delete on the Maintenance screen.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
        const SizedBox(height: 10),
        if (!can) const Padding(padding: EdgeInsets.only(bottom: 10), child: InfoLine('View only – you can see the bills, their files and the car log books here, but you cannot add or change them. Ask Admin for Edit access.', help: false)),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: InfoLine(err, bad: true)),
        if (bills.isEmpty) InfoLine('No maintenance bill of this machinery in these dates.', help: false),
        for (final b in bills) _bill(b, can),
      ]),
    );
  }

  Widget _bill(Map<String, dynamic> b, bool can) {
    final lines = listOf(b['lines']), id = '${b['id']}';
    return Container(
      key: Key('ml-b-$id'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${showDate('${b['date']}')} · ${b['garage'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text('$id${'${b['billNo'] ?? ''}'.isNotEmpty ? ' · bill no. ${b['billNo']}' : ''}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ]),
          ),
          Padding(padding: const EdgeInsets.only(right: 8), child: Text(rupees(asNum(b['total'])), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: C.greenDark))),
        ]),
        const SizedBox(height: 6),
        for (final (i, l) in lines.indexed) _line(b, i, l, can),
      ]),
    );
  }

  Widget _line(Map<String, dynamic> b, int i, Map<String, dynamic> l, bool can) {
    final free = !maintCharged(l['type']), a = asNum(l['amount']) ?? 0, g = asNum(l['gst']) ?? 0, q = asNum(l['qty']), r = asNum(l['rate']), ga = mtHasGa(l);
    final id = '${b['id']}';
    final what = [
      if (q != null) '${fmtNum(q)}${'${l['uom'] ?? ''}'.isEmpty ? '' : ' ${l['uom']}'}${r != null ? ' × ${fmtNum(r)}' : ''}',
      if (g > 0) 'GST ${fmtNum(g)} %' else if (ga && !free) 'GST ₹${fmtNum(maintLineGst(l))}',
      tr(maintPaidBy(l['type'])),
    ].join(' · ');
    return Container(
      key: Key('ml-l-$id-$i'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${l['work']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(what, style: const TextStyle(fontSize: 12, color: C.muted)),
          ]),
        ),
        Text(free ? '₹ 0' : rupees(a + maintLineGst(l)), style: TextStyle(fontWeight: FontWeight.w700, color: a < 0 ? C.red : C.ink)),
        if (can) ...[
          IconButton(key: Key('ml-e-$id-$i'), tooltip: tr('Edit'), onPressed: busy ? null : () => _edit(b, i), icon: const Icon(Icons.edit_rounded, color: C.blue, size: 21)),
          IconButton(key: Key('ml-d-$id-$i'), tooltip: tr('Delete'), onPressed: busy ? null : () => _delete(b, i), icon: const Icon(Icons.delete_outline_rounded, color: C.red, size: 21)),
        ],
      ]),
    );
  }
}

/// One line of a bill, changed: its box as a line of the bill's form (the web's mlLineEdit)
class MaintLineForm extends StatefulWidget {
  const MaintLineForm({super.key, required this.bill, required this.i, this.no = ''});
  final Map<String, dynamic> bill;
  final int i;
  final String no;
  @override
  State<MaintLineForm> createState() => _MaintLineFormState();
}

String _n(num? v) => v == null ? '' : '${(v * 100).round() / 100}'.replaceAll(RegExp(r'\.0$'), '');

class _MaintLineFormState extends State<MaintLineForm> {
  late final Map<String, dynamic> l0 = listOf(widget.bill['lines'])[widget.i];
  late String type = kMaintKinds.contains(l0['type']) ? '${l0['type']}' : 'Paid';
  late final work = TextEditingController(text: '${l0['work'] ?? ''}'), qty = TextEditingController(text: _n(asNum(l0['qty']))), uom = TextEditingController(text: '${l0['uom'] ?? ''}');
  late final rate = TextEditingController(text: _n(asNum(l0['rate']))), disc = TextEditingController(text: _n(asNum(l0['disc']))), gst = TextEditingController(text: _n(asNum(l0['gst'])));
  late final amount = TextEditingController(text: maintCharged(type) ? _n(asNum(l0['amount'])) : '0');
  /// (3.59.0, Mechanical update-183) its GST ₹ as in the old log book (only for such a line)
  late final bool hasGa = mtHasGa(l0);
  late final ga = TextEditingController(text: hasGa ? _n(mtLineGst(l0)) : '');
  bool busy = false;
  String err = '';

  bool get free => !maintCharged(type);
  static num? _of(TextEditingController c) => asNum(c.text.replaceAll(',', ''));

  @override
  void dispose() {
    for (final c in [work, qty, uom, rate, disc, amount, gst, ga]) {
      c.dispose();
    }
    super.dispose();
  }

  /// a Paid line: its ₹ from Qty × Rate − Disc % (when Qty and Rate are there); a free line: ₹ 0 (as the bill's form)
  void _calc() {
    if (free) {
      amount.text = '0';
      return;
    }
    final q = _of(qty), r = _of(rate);
    if (q != null && r != null) {
      amount.text = _n(q * r * (1 - (_of(disc) ?? 0) / 100));
    } else if (amount.text == '0') {
      amount.text = '';
    }
  }

  Future<void> _save() async {
    final s = SessionScope.read(context), b = widget.bill, id = '${b['id']}';
    Object v(TextEditingController c) => _of(c) ?? c.text.trim();
    // (3.59.0) 'gstAmt' always sent – its GST ₹ of the old log book while no GST % is typed (an app that does not send it is refused)
    final line = {'work': work.text.replaceAll(RegExp(r'\s+'), ' ').trim(), 'type': type, 'qty': v(qty), 'uom': uom.text.trim(), 'rate': v(rate), 'disc': v(disc), 'amount': free ? 0 : v(amount), 'gst': v(gst),
      'gstAmt': hasGa && gst.text.trim().isEmpty ? v(ga) : ''};
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final r = (await s.api.call('updateMaintLine', [id, {...maintLineWas(b, widget.i), 'line': line}], true) as Map).cast<String, dynamic>();
      s.dataTick.value++;
      if (!mounted) return;
      toast(context, tr('Line saved – bill $id is now ₹${money(r['total'])}.'));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      if (isSent(e)) {
        toast(context, errText(e));
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        busy = false;
        err = errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill, n = listOf(b['lines']).length;
    final a = _of(amount), asIs = hasGa && gst.text.trim().isEmpty, gv = free || a == null ? 0 : asIs ? (_of(ga) ?? 0) : maintGst(a, _of(gst));
    const nkb = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: Text('Change this line – ${widget.no}')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: FilledButton.icon(key: const Key('mlf-save'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), onPressed: busy ? null : _save, icon: const Icon(Icons.check_rounded), label: Text(busy ? 'Saving…' : 'Save')),
        ),
      ),
      body: ListView(key: const Key('mlf-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        Text(tr('${maintBillSay(b)} – line ${widget.i + 1} of $n. The other lines of the bill stay as they are.'), style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
        const SizedBox(height: 12),
        TextBox(key: const Key('mlf-w'), label: 'Particulars', controller: work, enabled: !busy, onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        PickField(key: const Key('mlf-t'), label: 'Paid by', value: type, items: kMaintKinds, labels: kMaintPaidBy, enabled: !busy, onChanged: (v) => setState(() {
              type = v.isEmpty ? 'Paid' : v;
              _calc();
            })),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextBox(key: const Key('mlf-q'), label: 'Qty', controller: qty, kb: nkb, enabled: !busy, onChanged: (_) => setState(_calc))),
          const SizedBox(width: 8),
          Expanded(child: TextBox(key: const Key('mlf-u'), label: 'Uom', controller: uom, options: kMaintUoms, enabled: !busy)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextBox(key: const Key('mlf-r'), label: 'Rate (₹)', controller: rate, kb: nkb, enabled: !busy, onChanged: (_) => setState(_calc))),
          const SizedBox(width: 8),
          Expanded(child: TextBox(key: const Key('mlf-d'), label: 'Disc %', controller: disc, kb: nkb, enabled: !busy, onChanged: (_) => setState(_calc))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextBox(key: const Key('mlf-a'), label: 'Amount (₹)', controller: amount, enabled: !busy && !free, kb: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: TextBox(key: const Key('mlf-g'), label: 'GST %', controller: gst, enabled: !busy && !free, kb: nkb, onChanged: (_) => setState(() {}))),
        ]),
        if (hasGa) ...[      // (3.59.0) a GST % typed takes its place
          const SizedBox(height: 10),
          TextBox(key: const Key('mlf-ga'), label: 'GST ₹ (as in the old log book)', controller: ga, enabled: !busy && !free && gst.text.trim().isEmpty, kb: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {})),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 4),
          child: Text(free ? 'Not paid – ₹ 0 in the bill.' : a == null ? '' : tr('GST ₹${money(gv)} · Amount with GST ₹${money(a + gv)}'),
              key: const Key('mlf-sum'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
        ),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: InfoLine(err, bad: true)),
      ]),
    );
  }
}
