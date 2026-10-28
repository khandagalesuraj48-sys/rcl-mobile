/* PRINT – PENDING LOG BOOK (3.54.0, Mechanical update-179; asked 28-10-2026: "pending log book je aahet te mala period wise print krta
 * yawet dashboard warun pn ani log book netry madhun jith diste pending tithun pn"). The web's box, as the app's own screen: one date,
 * a month or a period (from – to); all machinery or an Ownership, an Owner / Vendor, one machinery – then Print (the phone's printing)
 * or Excel. Each machinery with its pending days and their dates – the same list as the Dashboard's Pending Log Book (pendingLog,
 * Dashboard access); from the Log Book screen logPending (Log Book access) – the same server actions as the web. */
import 'package:flutter/material.dart' hide Text;

import '../core/dash.dart';
import '../core/format.dart';
import '../core/rdoc.dart' show RDoc;
import '../ui/ask_bot.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The first day the Pending Log Book counts (as the web's LB_PFROM).
const kPendFrom = '2026-09-01';

Future<void> openPendPrint(BuildContext context, {bool entry = false, String kind = 'period', String from = '', String to = '', String date = '', String own = '', String vendor = '', String no = ''}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PendPrintScreen(entry: entry, kind: kind, from: from, to: to, date: date, own: own, vendor: vendor, no: no)));

class PendPrintScreen extends StatefulWidget {
  const PendPrintScreen({super.key, this.entry = false, this.kind = 'period', this.from = '', this.to = '', this.date = '', this.own = '', this.vendor = '', this.no = ''});

  /// from the Log Book screen (logPending – Log Book access); else the Dashboard's list (pendingLog)
  final bool entry;
  final String kind, from, to, date, own, vendor, no;
  @override
  State<PendPrintScreen> createState() => _PendPrintScreenState();
}

class _PendPrintScreenState extends State<PendPrintScreen> {
  late String kind = const ['date', 'month', 'period'].contains(widget.kind) ? widget.kind : 'period', from = widget.from, to = widget.to, date = widget.date, month = '', own = widget.own, vendor = widget.vendor, no = widget.no;
  bool busy = false, started = false;
  String err = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final t = SessionScope.read(context).today, today = t.isNotEmpty ? t : dateKey(DateTime.now());
    if (from.isEmpty) from = kPendFrom;
    if (to.isEmpty) to = today;
    if (date.isEmpty) date = today;
    month = date.substring(0, 7);
  }

  /// the period asked: (from, to) – null when it is not right (said)
  (String, String)? _period(String today) {
    var f = from, t = to;
    if (kind == 'date') f = t = date;
    if (kind == 'month') {
      final y = int.parse(month.substring(0, 4)), m = int.parse(month.substring(5, 7));
      f = '$month-01';
      t = dateKey(DateTime(y, m + 1, 0));
    }
    final why = f.isEmpty || t.isEmpty
        ? 'Pick the dates.'
        : f.compareTo(t) > 0
            ? 'From date is after To date.'
            : f.compareTo(today) > 0
                ? 'Nothing is pending after today – pick dates up to today.'
                : '';
    if (why.isNotEmpty) {
      toast(context, why, bad: true);
      return null;
    }
    return (f, t);
  }

  Future<RDoc?> _doc() async {
    final s = SessionScope.read(context), today = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    final p = _period(today);
    if (p == null) return null;
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final r = (await s.api.call(widget.entry ? 'logPending' : 'pendingLog', [{'from': p.$1, 'to': p.$2}]) as Map).cast<String, dynamic>();
      final upTo = '${r['to'] ?? ''}'.length == 10 ? '${r['to']}' : (p.$2.compareTo(today) > 0 ? today : p.$2);
      return pendPrintDoc(
        items: r['items'] as List? ?? const [],
        kind: kind,
        from: p.$1,
        to: p.$2,
        upTo: upTo,
        own: own,
        vendor: vendor,
        no: no,
        info: (n) {
          final m = s.machine(n);
          return m == null ? null : {'id': m.id, 'name': m.name, 'type': m.type, 'owner': m.owner, 'ownership': m.ownership};
        },
      );
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
      return null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _print() async {
    final d = await _doc();
    if (d == null || !mounted) return;
    await printDoc(context, SessionScope.read(context), d);
  }

  Future<void> _excel() async {
    final d = await _doc();
    if (d == null || !mounted) return;
    await shareDocXlsx(SessionScope.read(context), d);
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), today = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    final ms = s.machines.where((m) => !m.debit && m.ownership != 'Debit' && m.ownership != 'Other').toList();
    final owners = ({for (final m in ms) m.owner.trim()}..remove('')).toList()..sort();
    final nos = [for (final m in ms) m.id]..sort();
    // the months that can be picked: this one and the 12 before it
    final t0 = parseKey(today), months = [for (var i = 0; i < 13; i++) dateKey(DateTime(t0.year, t0.month - i, 1)).substring(0, 7)];
    if (!months.contains(month)) months.add(month);
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: Text('Print – Pending Log Book')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(key: const Key('pp-xl'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)), onPressed: busy ? null : _excel, icon: const Icon(Icons.table_view_rounded), label: Text('Excel'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(key: const Key('pp-print'), style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), onPressed: busy ? null : _print, icon: const Icon(Icons.print_rounded), label: Text(busy ? 'Working…' : 'Print'))),
          ]),
        ),
      ),
      body: ListView(key: const Key('pp-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        Text('Each machinery with its pending days – a day it was on the site with no Log Book entry in any shift. Debit-basis parties and Ownership "Other" need no Log Book.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
        const SizedBox(height: 10),
        PickField(key: const Key('pp-kind'), label: 'List for', value: kind, items: const ['date', 'month', 'period'], labels: const {'date': 'One date', 'month': 'A month', 'period': 'A period (from – to)'}, onChanged: (v) => setState(() => kind = v)),
        const SizedBox(height: 8),
        if (kind == 'date') DateField(key: const Key('pp-date'), label: 'Date', value: date, clear: false, onChanged: (v) => setState(() => date = v)),
        if (kind == 'month') PickField(key: const Key('pp-month'), label: 'Month', value: month, items: months, labels: {for (final m in months) m: monthLong(m)}, onChanged: (v) => setState(() => month = v)),
        if (kind == 'period')
          Row(children: [
            Expanded(child: DateField(key: const Key('pp-from'), label: 'From', value: from, clear: false, onChanged: (v) => setState(() => from = v))),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('pp-to'), label: 'To', value: to, clear: false, onChanged: (v) => setState(() => to = v))),
          ]),
        const SizedBox(height: 8),
        PickField(key: const Key('pp-own'), label: 'Ownership', value: own, items: const ['Own', 'Rental,Hired', 'Rental', 'Hired'], labels: const {'Rental,Hired': 'Rental + Hired'}, blank: 'All machinery', onChanged: (v) => setState(() => own = v)),
        const SizedBox(height: 8),
        PickField(key: const Key('pp-ven'), label: 'Owner / Vendor', value: owners.any((o) => o.toUpperCase() == vendor.toUpperCase()) ? owners.firstWhere((o) => o.toUpperCase() == vendor.toUpperCase()) : '', items: owners, blank: 'All vendors', onChanged: (v) => setState(() => vendor = v)),
        const SizedBox(height: 8),
        PickField(key: const Key('pp-no'), label: 'Machinery', value: nos.contains(no) ? no : '', items: nos, blank: 'All machinery', onChanged: (v) => setState(() => no = v)),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(err, bad: true)),
      ]),
    );
  }
}
