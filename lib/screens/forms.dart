/* THE THREE ENTRIES – the same fields and the same server checks as the web pages (Diesel Issue, Diesel Inward, Diesel
 * Transfer). The server decides everything (stock, closed month, bill lock, an active machinery, readings); the app shows its
 * answer. A reading that looks wrong comes back as a question – "Save anyway?" – as on the web. */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/kinds.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class EntryForm extends StatefulWidget {
  const EntryForm({super.key, required this.kind});
  final Kind kind;
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  String date = '', shift = 'Day', source = '', from = '', to = '';
  Machine? machine;
  final qty = TextEditingController(), km = TextEditingController(), hr = TextEditingController(), driver = TextEditingController(), remark = TextEditingController();
  final pump = TextEditingController(), rate = TextEditingController(), billNo = TextEditingController();
  String billDate = '';
  Map<String, dynamic>? bal; // stock at the source for this date + shift (issue)
  bool busy = false, savedOne = false;
  String err = '';
  int balSeq = 0;

  Kind get k => widget.kind;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SessionScope.read(context);
    if (source.isEmpty) {
      date = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
      source = s.locations.isNotEmpty ? s.locations.first : 'Dispenser';
      from = source;
      to = s.locations.length > 1 ? s.locations[1] : '';
      if (k.key == 'issue') WidgetsBinding.instance.addPostFrameCallback((_) => _balance());
    }
  }

  @override
  void dispose() {
    for (final c in [qty, km, hr, driver, remark, pump, rate, billNo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _balance() async {
    if (k.key != 'issue') return;
    final s = SessionScope.read(context), my = ++balSeq;
    setState(() => bal = null);
    try {
      final r = (await s.api.call('getIssueBalance', [date, shift, '', source]) as Map).cast<String, dynamic>();
      if (my == balSeq && mounted) setState(() => bal = r);
    } catch (_) {/* the server checks the stock at the save anyway */}
  }

  Future<void> _pickDate({bool bill = false}) async {
    final s = SessionScope.read(context);
    final last = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    final cur = bill ? (billDate.isEmpty ? date : billDate) : date;
    final d = await showDatePicker(context: context, initialDate: parseKey(cur), firstDate: DateTime(2024), lastDate: last);
    if (d == null) return;
    setState(() {
      if (bill) {
        billDate = dateKey(d);
      } else {
        date = dateKey(d);
      }
    });
    if (!bill) _balance();
  }

  Future<void> _pickMachine() async {
    final m = await Navigator.of(context).push<Machine>(MaterialPageRoute(builder: (_) => const MachinePicker()));
    if (m != null) setState(() => machine = m);
  }

  Map<String, dynamic> _data() => switch (k.key) {
        'issue' => {
            'date': date, 'shift': shift, 'no': machine?.id ?? '', 'qty': asNum(qty.text) ?? '', 'kmReading': asNum(km.text) ?? '', 'hrReading': asNum(hr.text) ?? '',
            'driver': driver.text.trim(), 'remark': remark.text.trim(), 'source': source, 'force': false, 'mode': '',
          },
        'inward' => {'date': date, 'location': source, 'pump': pump.text.trim(), 'qty': asNum(qty.text) ?? '', 'rate': asNum(rate.text) ?? '', 'billNo': billNo.text.trim(), 'billDate': billDate},
        _ => {'date': date, 'shift': shift, 'from': from, 'to': to, 'qty': asNum(qty.text) ?? '', 'remark': remark.text.trim()},
      };

  String? _check() {
    if (k.key == 'issue' && machine == null) return 'Pick the machinery.';
    if (k.key == 'inward' && pump.text.trim().isEmpty) return 'Enter the Pump Name.';
    if (k.key == 'transfer' && from == to) return 'From and To cannot be the same.';
    if (!((asNum(qty.text) ?? 0) > 0)) return 'Enter the litres.';
    return null;
  }

  Future<void> _save({bool force = false}) async {
    final s = SessionScope.read(context);
    final bad = _check();
    if (bad != null) {
      setState(() => err = bad);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final d = _data();
      if (force) d['force'] = true;
      final r = (await s.api.call(k.save, [d], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (r['warning'] != null) {
        setState(() => busy = false);
        if (await ask(context, 'Please check the reading', r['warning'].toString(), yes: 'Save anyway')) await _save(force: true);
        return;
      }
      if (r['stock'] != null) s.setStock(r['stock']);
      if (k.key == 'issue' && driver.text.trim().isNotEmpty && !s.drivers.contains(driver.text.trim())) s.drivers.add(driver.text.trim());
      savedOne = true;
      await _savedSheet(r['id']?.toString() ?? '', d);
      if (!mounted) return;
      setState(() {
        busy = false;
        machine = null;
        for (final c in [qty, km, hr, remark, rate, billNo]) {
          c.clear();
        }
      });
      _balance();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _savedSheet(String id, Map<String, dynamic> d) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (c) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: k.soft, shape: BoxShape.circle), child: Icon(Icons.check_rounded, color: k.color, size: 28)),
              const SizedBox(width: 12),
              Expanded(child: TwoLang('${k.en} saved', 'नोंद झाली', size: 19)),
            ]),
            const SizedBox(height: 14),
            Text([id, if (machine != null) machine!.id, '${fmtNum(asNum(d['qty']))} L', showDate(d['date']?.toString())].where((e) => e.isNotEmpty).join('  ·  '), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()), onPressed: () {
                    Navigator.pop(c);
                    Navigator.pop(context, true);
                  }, child: const Text('Done'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: k.color, minimumSize: const Size.fromHeight(52)), onPressed: () => Navigator.pop(c), child: const Text('One more'))),
            ]),
          ]),
        ),
      );

  Widget _qtyField() => TextField(
        controller: qty,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: '0', suffixText: 'L'),
      );

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final q = asNum(qty.text);
    return PopScope(
      canPop: false, // the system Back too says whether something was saved (the list then loads again)
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, savedOne);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.pop(context, savedOne)),
          title: Row(children: [Flexible(child: Text(k.en, overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Text('· ${k.mr}', style: const TextStyle(fontFamily: 'NotoDeva', fontSize: 17, color: C.muted))]),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), children: [
          const FieldLabel('Date'),
          PickBox(text: showDate(date), icon: Icons.calendar_month_outlined, onTap: _pickDate),
          if (k.key != 'inward') ...[
            const FieldLabel('Shift'),
            Choice<String>(items: const [('Day', 'Day'), ('Night', 'Night')], value: shift, onPick: (v) {
                setState(() => shift = v);
                _balance();
              }),
          ],
          // ---------- Diesel Issue ----------
          if (k.key == 'issue') ...[
            if (s.locations.length > 1) ...[
              const FieldLabel('Diesel from'),
              Choice<String>(items: [for (final l in s.locations) (l, l)], value: source, onPick: (v) {
                  setState(() => source = v);
                  _balance();
                }),
            ],
            const FieldLabel('Machinery'),
            PickBox(text: machine?.label ?? 'Pick the machinery', hint: machine == null, onTap: _pickMachine),
            const FieldLabel('Litres'),
            Choice<num>(items: const [(50, '50'), (100, '100'), (120, '120'), (150, '150'), (200, '200')], value: q, onPick: (v) => setState(() => qty.text = '$v')),
            const SizedBox(height: 10),
            _qtyField(),
            if (machine != null && machine!.km) ...[const FieldLabel('KM reading'), TextField(controller: km, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'Odometer km'))],
            if (machine != null && machine!.hr) ...[const FieldLabel('Hour meter'), TextField(controller: hr, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'Hours'))],
            const FieldLabel('Driver'),
            Autocomplete<String>(
              optionsBuilder: (v) => v.text.isEmpty ? const Iterable<String>.empty() : s.drivers.where((d) => d.toLowerCase().contains(v.text.toLowerCase())).take(8),
              onSelected: (v) => driver.text = v,
              fieldViewBuilder: (c, ctl, f, sub) => TextField(controller: ctl, focusNode: f, onChanged: (v) => driver.text = v, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Driver name (optional)')),
            ),
            if (bal != null)
              InfoLine(q == null || q == 0
                  ? 'Stock at $source for ${showDate(date)} ($shift): ${fmtNum(asNum(bal!['balance']))} L'
                  : (q > (asNum(bal!['available']) ?? double.infinity)
                      ? 'Not enough stock at $source: you can issue up to ${fmtNum(asNum(bal!['available']))} L.'
                      : 'Stock after this issue: ${fmtNum((asNum(bal!['balance']) ?? 0) - q)} L'),
                  bad: q != null && q > (asNum(bal!['available']) ?? double.infinity)),
          ],
          // ---------- Diesel Inward ----------
          if (k.key == 'inward') ...[
            if (s.locations.length > 1) ...[const FieldLabel('Received at'), Choice<String>(items: [for (final l in s.locations) (l, l)], value: source, onPick: (v) => setState(() => source = v))],
            const FieldLabel('Pump name'),
            Autocomplete<String>(
              optionsBuilder: (v) => v.text.isEmpty ? s.pumps.take(8) : s.pumps.where((p) => p.toLowerCase().contains(v.text.toLowerCase())).take(8),
              onSelected: (v) => pump.text = v,
              fieldViewBuilder: (c, ctl, f, sub) => TextField(controller: ctl, focusNode: f, onChanged: (v) => pump.text = v, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Petrol pump')),
            ),
            const FieldLabel('Litres'),
            _qtyField(),
            const FieldLabel('Rate (₹ per litre)'),
            TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: '0.00', prefixText: '₹ ')),
            if ((asNum(rate.text) ?? 0) > 0 && (q ?? 0) > 0) InfoLine('Amount ₹ ${fmtNum((asNum(rate.text) ?? 0) * (q ?? 0))}', icon: Icons.currency_rupee),
            const FieldLabel('Bill number'),
            TextField(controller: billNo, decoration: const InputDecoration(hintText: 'Optional')),
            const FieldLabel('Bill date'),
            PickBox(text: billDate.isEmpty ? 'Optional' : showDate(billDate), hint: billDate.isEmpty, icon: Icons.calendar_month_outlined, onTap: () => _pickDate(bill: true)),
          ],
          // ---------- Diesel Transfer ----------
          if (k.key == 'transfer') ...[
            const FieldLabel('From'),
            Choice<String>(items: [for (final l in s.locations) (l, l)], value: from, onPick: (v) => setState(() => from = v)),
            const FieldLabel('To'),
            Choice<String>(items: [for (final l in s.locations) (l, l)], value: to, onPick: (v) => setState(() => to = v)),
            const FieldLabel('Litres'),
            _qtyField(),
          ],
          if (k.key != 'inward') ...[const FieldLabel('Remark'), TextField(controller: remark, decoration: const InputDecoration(hintText: 'Optional'))],
          if (err.isNotEmpty) InfoLine(err, bad: true),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: k.color),
              onPressed: busy ? null : _save,
              icon: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.check_rounded),
              label: Text(busy ? 'Saving…' : 'Save'),
            ),
          ),
        ),
      ),
    );
  }
}

/// The machinery of the site (Active only) – search by number, name, type or owner; the last picked come first.
class MachinePicker extends StatefulWidget {
  const MachinePicker({super.key});
  @override
  State<MachinePicker> createState() => _MachinePickerState();
}

class _MachinePickerState extends State<MachinePicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = s.machines.where((m) => m.active && (q.isEmpty || m.matches(q))).take(80).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Pick the machinery')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: TextField(autofocus: true, onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: 'Number, name, type or owner', prefixIcon: Icon(Icons.search))),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Nothing found – try a part of the number.', style: TextStyle(color: C.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = list[i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.local_shipping_outlined, color: C.green)),
                        title: Text(m.id, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text([if (m.name.isNotEmpty && m.name != m.id) m.name, m.type, m.owner].where((e) => e.isNotEmpty).join(' · ')),
                        onTap: () => Navigator.pop(context, m),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
