/* (3.91.0, Mechanical update-216, asked 08-11-2026 – the HO features, part 2: toll "हाताने + statement") VEHICLE EXPENSES – the app's own
 * screen of the web's page: toll, parking … of a vehicle, typed by hand, or the bank's FASTag statement (a PDF, a photo or the Excel
 * file) read by the AI – each toll put on the vehicle of its number, seen first, only the lines ticked saved (a line already saved is
 * never saved twice). Each vehicle's total of the dates. The same server actions, checks and access as the web: getVexp, saveVexp,
 * updateVexp, deleteVexp, readVexpStatement, importVexp. */
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/sheet_read.dart';
import '../ui/ask_bot.dart';
import '../ui/fields.dart';
import '../ui/pick_file.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'fuel_cards.dart' show rupees;

Future<void> openVexp(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VexpScreen()));

const kVxKinds = ['Toll', 'Parking', 'Other'], kVxPaid = ['FASTag', 'Cash', 'Card', 'UPI', 'Other'];

class VexpScreen extends StatefulWidget {
  const VexpScreen({super.key});
  @override
  State<VexpScreen> createState() => _VexpScreenState();
}

class _VexpScreenState extends State<VexpScreen> {
  List<Map<String, dynamic>> rows = [], cars = [];
  num total = 0;
  bool loading = true;
  String err = '', missing = '', from = '', to = '';
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final t = SessionScope.read(context).today;
      from = t.length >= 8 ? '${t.substring(0, 8)}01' : t;
      to = t;
      _load();
    });
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final d = (await s.api.call('getVexp', [{'from': from, 'to': to}]) as Map).cast<String, dynamic>();
      if (my != _seq || !mounted) return;
      setState(() {
        rows = [for (final x in (d['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
        cars = [for (final x in (d['cars'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
        total = asNum(d['total']) ?? 0;
        missing = '${d['missing'] ?? ''}';
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

  Future<void> _form([Map<String, dynamic>? r]) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => VexpForm(row: r)));
    if (ok == true && mounted) _load();
  }

  Future<void> _row(Map<String, dynamic> r) async {
    final s = SessionScope.read(context);
    if (!s.canEdit('Vehicle Expenses')) return;
    final a = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('${r['id']} · ${r['no']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${showDate('${r['date']}')} · ${r['kind']} ${r['place']} · ${rupees(asNum(r['amount']))}')),
          ListTile(key: const Key('vx-edit'), leading: const Icon(Icons.edit_rounded), title: Text('Change'), onTap: () => Navigator.pop(c, 'e')),
          ListTile(key: const Key('vx-del'), leading: const Icon(Icons.delete_outline_rounded, color: C.red), title: Text('Delete', style: const TextStyle(color: C.red)), onTap: () => Navigator.pop(c, 'd')),
        ]),
      ),
    );
    if (!mounted || a == null) return;
    if (a == 'e') return _form(r);
    if (!await ask(context, tr('Delete {0}?').replaceAll('{0}', '${r['id']}'), '${showDate('${r['date']}')} · ${r['no']} · ${r['kind']} · ${rupees(asNum(r['amount']))}', yes: 'Delete', danger: true)) return;
    try {
      await s.api.call('deleteVexp', ['${r['id']}'], true);
      if (!mounted) return;
      toast(context, tr('Deleted {0}.').replaceAll('{0}', '${r['id']}'));
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  Future<void> _statement() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const StatementScreen()));
    if (ok == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), ed = s.canEdit('Vehicle Expenses') && missing.isEmpty;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Vehicle Expenses', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: withAsk([if (ed) IconButton(key: const Key('vx-statement'), tooltip: tr('FASTag statement'), onPressed: _statement, icon: const Icon(Icons.receipt_long_rounded))]),
      ),
      floatingActionButton: ed ? FloatingActionButton.extended(key: const Key('vx-add'), onPressed: () => _form(), icon: const Icon(Icons.add_rounded), label: Text('Add')) : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('vx-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 90), children: [
          Row(children: [
            Expanded(child: DateField(key: const Key('vx-from'), label: 'From', value: from, clear: false, onChanged: (v) => setState(() { from = v; _load(); }))),
            const SizedBox(width: Sp.chips),
            Expanded(child: DateField(key: const Key('vx-to'), label: 'To', value: to, clear: false, onChanged: (v) => setState(() { to = v; _load(); }))),
          ]),
          const SizedBox(height: 10),
          if (loading && rows.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (err.isNotEmpty) Text(err, style: const TextStyle(color: C.red)),
          if (missing.isNotEmpty) Text(missing, style: const TextStyle(color: C.amber)),
          if (!loading && missing.isEmpty && rows.isEmpty) const EmptyState('No expense', 'Toll, parking … of a vehicle – add one, or read the FASTag statement.', pic: 'receipt'),
          if (rows.isNotEmpty)
            Container(
              key: const Key('vx-cars'),
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text('Total', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const Spacer(), Text(rupees(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: C.green))]),
                const Divider(),
                for (final c in cars)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(child: Text('${c['no']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${c['n']} · ', style: const TextStyle(color: C.muted)),
                      Text(rupees(asNum(c['amount'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
            ),
          for (final r in rows)
            Press(
              key: Key('vx-${r['id']}'),
              onTap: () => _row(r),
              radius: 16,
              shadow: false,
              color: Colors.white,
              border: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: r['kind'] == 'Toll' ? C.blueSoft : C.amberSoft, borderRadius: BorderRadius.circular(12)),
                    child: Icon(r['kind'] == 'Toll' ? Icons.toll_rounded : r['kind'] == 'Parking' ? Icons.local_parking_rounded : Icons.receipt_rounded, color: r['kind'] == 'Toll' ? C.blue : C.amber, size: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['no']} · ${tr('${r['kind']}')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${showDate('${r['date']}')}${'${r['place'] ?? ''}'.isEmpty ? '' : ' · ${r['place']}'} · ${r['paidBy']}${r['source'] == 'Statement' ? ' · ${tr('statement')}' : ''}', style: const TextStyle(color: C.muted, fontSize: 13)),
                  ]),
                ),
                Text(rupees(asNum(r['amount'])), style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// One expense typed, or changed.
class VexpForm extends StatefulWidget {
  const VexpForm({super.key, this.row});
  final Map<String, dynamic>? row;
  @override
  State<VexpForm> createState() => _VexpFormState();
}

class _VexpFormState extends State<VexpForm> {
  final place = TextEditingController(), amount = TextEditingController(), ref = TextEditingController(), remark = TextEditingController();
  String date = '', no = '', kind = 'Toll', paid = 'FASTag', err = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    if (r != null) {
      date = '${r['date']}';
      no = '${r['no']}';
      kind = '${r['kind']}';
      paid = '${r['paidBy']}';
      place.text = '${r['place'] ?? ''}';
      amount.text = '${r['amount'] ?? ''}';
      ref.text = '${r['ref'] ?? ''}';
      remark.text = '${r['remark'] ?? ''}';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (date.isEmpty) setState(() => date = SessionScope.read(context).today);
    });
  }

  Future<void> _save() async {
    final s = SessionScope.read(context), r = widget.row;
    setState(() {
      busy = true;
      err = '';
    });
    final x = {'date': date, 'no': no, 'kind': kind, 'place': place.text.trim(), 'amount': amount.text.trim(), 'paidBy': paid, 'ref': ref.text.trim(), 'remark': remark.text.trim()};
    try {
      final res = (await s.api.call(r == null ? 'saveVexp' : 'updateVexp', r == null ? [x] : ['${r['id']}', x], true) as Map);
      if (!mounted) return;
      toast(context, tr(r == null ? 'Saved {0}.' : 'Changed {0}.').replaceAll('{0}', '${res['id']}'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), fixed = '${widget.row?['txn'] ?? ''}'.isNotEmpty;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text(widget.row == null ? 'New expense' : '${tr('Change')} ${widget.row!['id']}', style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('vxf'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 30), children: [
        if (fixed) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('From the FASTag statement – its vehicle, date and ₹ stay.', style: const TextStyle(color: C.muted))),
        DateField(key: const Key('vxf-date'), label: 'Date', value: date, clear: false, enabled: !fixed, last: DateTime.tryParse(s.today), onChanged: (v) => setState(() => date = v)),
        const SizedBox(height: 8),
        Press(
          key: const Key('vxf-no'),
          onTap: fixed
              ? null
              : () async {
                  final p = await pickFromList(context, tr('Vehicle'), [for (final m in s.machines) m.id]);
                  if (p != null) setState(() => no = p);
                },
          radius: 14,
          shadow: false,
          border: C.line,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.directions_car_rounded, color: C.green),
            const SizedBox(width: 10),
            Expanded(child: Text(no.isEmpty ? tr('Pick the vehicle') : no, style: TextStyle(fontWeight: FontWeight.w700, color: no.isEmpty ? C.faint : C.ink))),
            const Icon(Icons.chevron_right_rounded, color: C.faint),
          ]),
        ),
        const SizedBox(height: 8),
        PickField(key: const Key('vxf-kind'), label: 'What', value: kind, items: kVxKinds, onChanged: (v) => setState(() => kind = v)),
        TextBox(key: const Key('vxf-place'), label: 'Place / toll plaza', controller: place),
        TextBox(key: const Key('vxf-amt'), label: 'Amount (₹) *', controller: amount, kb: const TextInputType.numberWithOptions(decimal: true), enabled: !fixed),
        PickField(key: const Key('vxf-paid'), label: 'Paid by', value: paid, items: kVxPaid, onChanged: (v) => setState(() => paid = v)),
        TextBox(key: const Key('vxf-ref'), label: 'Reference', controller: ref),
        TextBox(key: const Key('vxf-remark'), label: 'Remark', controller: remark),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: const TextStyle(color: C.red))),
        const SizedBox(height: 12),
        FilledButton(key: const Key('vxf-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save')),
      ]),
    );
  }
}

/// The FASTag statement: picked, read by the AI, seen line by line (each on the vehicle of its number), the ticked lines saved.
class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});
  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  List<Map<String, dynamic>> lines = [];
  final ticked = <int>{};
  String msg = '', err = '';
  bool busy = false;

  Future<void> _pick() async {
    final s = SessionScope.read(context), f = await pickStatementFile();
    if (f == null || !mounted) return;
    setState(() {
      busy = true;
      err = '';
      msg = tr('Reading {0} – the AI reads each toll (up to a minute)…').replaceAll('{0}', f.name);
      lines = [];
      ticked.clear();
    });
    try {
      final n = f.name.toLowerCase();
      final Map<String, dynamic> x;
      if (n.endsWith('.xlsx') || n.endsWith('.csv')) {
        final rows = readSheets(f.bytes, shown: true).first.rows.where((r) => r.any((c) => '${c ?? ''}'.trim().isNotEmpty));
        x = {'text': rows.map((r) => r.map((c) => '${c ?? ''}'.trim()).join(' | ')).join('\n')};
      } else {
        final mime = n.endsWith('.pdf') ? 'application/pdf' : n.endsWith('.png') ? 'image/png' : 'image/jpeg';
        x = {'data': 'data:$mime;base64,${base64Encode(f.bytes)}'};
      }
      final d = (await s.api.call('readVexpStatement', [x], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (d['off'] == true) {
        setState(() {
          busy = false;
          msg = tr('The AI is not set up for this site – type the expenses by hand.');
        });
        return;
      }
      final got = [for (final r in (d['rows'] as List? ?? const []).whereType<Map>()) r.cast<String, dynamic>()];
      setState(() {
        busy = false;
        lines = got;
        for (var i = 0; i < got.length; i++) {
          if ('${got[i]['saved'] ?? ''}'.isEmpty && '${got[i]['no'] ?? ''}'.isNotEmpty) ticked.add(i);
        }
        msg = '${got.length} ${tr('toll line(s) read')} · ${d['matched']} ${tr('put on a vehicle')} · ${d['saved']} ${tr('already saved')}';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          msg = '';
          err = errText(e);
        });
      }
    }
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final r = (await s.api.call('importVexp', [{'rows': [for (final i in ticked.toList()..sort()) lines[i]]}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (r['ok'] == false) {
        setState(() {
          busy = false;
          err = (r['errors'] as List? ?? const []).join('\n');
        });
        return;
      }
      toast(context, '${r['added']} ${tr('line(s) saved')}${(asNum(r['skipped']) ?? 0) > 0 ? ', ${r['skipped']} ${tr('already there')}' : ''}');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text('FASTag statement', style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('vxs'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 30), children: [
        Text('The bank\'s statement – a PDF, a photo or the Excel file. The AI reads each toll; each goes on the vehicle of its number. You see them first; only the lines ticked are saved, a line already saved is left out.', style: const TextStyle(color: C.muted)),
        const SizedBox(height: 10),
        OutlinedButton.icon(key: const Key('vxs-pick'), onPressed: busy ? null : _pick, icon: const Icon(Icons.upload_file_rounded), label: Text('Choose the statement')),
        if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: const TextStyle(color: C.red))),
        const SizedBox(height: 8),
        for (var i = 0; i < lines.length; i++)
          Builder(builder: (_) {
            final r = lines[i], saved = '${r['saved'] ?? ''}'.isNotEmpty;
            return Container(
              key: Key('vxs-$i'),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: CheckboxListTile(
                value: ticked.contains(i),
                onChanged: saved ? null : (v) => setState(() => v == true ? ticked.add(i) : ticked.remove(i)),
                title: Text('${showDate('${r['date']}')} ${r['time'] ?? ''} · ${rupees(asNum(r['amount']))}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['place'] ?? ''}${'${r['txn'] ?? ''}'.isEmpty ? '' : ' · ${r['txn']}'}'),
                  if (saved)
                    Text('${tr('already saved')} (${r['saved']})', style: const TextStyle(color: C.faint))
                  else
                    InkWell(
                      key: Key('vxs-no-$i'),
                      onTap: () async {
                        final p = await pickFromList(context, tr('Vehicle'), [for (final m in s.machines) m.id]);
                        if (p != null) {
                          setState(() {
                            lines[i] = {...r, 'no': p};
                            ticked.add(i);
                          });
                        }
                      },
                      child: Text('${r['vehicle'] ?? ''} → ${'${r['no'] ?? ''}'.isEmpty ? tr('pick the vehicle') : r['no']}', style: TextStyle(fontWeight: FontWeight.w700, color: '${r['no'] ?? ''}'.isEmpty ? C.amber : C.green)),
                    ),
                ]),
              ),
            );
          }),
        if (lines.isNotEmpty) FilledButton(key: const Key('vxs-save'), onPressed: busy || ticked.isEmpty ? null : _save, child: Text('${tr('Save the ticked lines')} (${ticked.length})')),
      ]),
    );
  }
}
