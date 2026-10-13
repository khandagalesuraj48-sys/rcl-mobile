import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/kinds.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart';

/// ENTRIES: the issues / inwards / transfers of one day (a strip of the last days, or any date) – only the kinds he may see.
class EntriesTab extends StatefulWidget {
  const EntriesTab({super.key, this.kind = ''});
  final String kind;
  @override
  State<EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends State<EntriesTab> {
  String kind = '';
  String day = '';
  bool loading = false;
  String err = '';
  List<Map<String, dynamic>> rows = [];
  num? total;
  int seq = 0;

  @override
  void didUpdateWidget(covariant EntriesTab old) {
    super.didUpdateWidget(old);
    if (widget.kind.isNotEmpty && widget.kind != old.kind) {
      kind = widget.kind;
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SessionScope.read(context);
    if (day.isEmpty) day = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    if (kind.isEmpty) {
      final allowed = kKinds.where((k) => s.canSee(k.module)).toList();
      if (allowed.isNotEmpty) {
        kind = widget.kind.isNotEmpty ? widget.kind : allowed.first.key;
        WidgetsBinding.instance.addPostFrameCallback((_) => _load());
      }
    }
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), k = kindOf(kind), my = ++seq;
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = (await s.api.call(k.list, [{'from': day, 'to': day, 'all': true}]) as Map).cast<String, dynamic>();
      if (my != seq || !mounted) return;
      if (r['stock'] != null) s.setStock(r['stock']);
      setState(() {
        rows = (r['rows'] as List? ?? []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        total = asNum(r['totalQty'] ?? r['qty']);
        loading = false;
      });
    } catch (e) {
      if (my != seq || !mounted) return;
      setState(() {
        err = errText(e);
        loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final s = SessionScope.read(context);
    final last = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    final d = await showDatePicker(context: context, initialDate: parseKey(day), firstDate: DateTime(2024), lastDate: last);
    if (d != null) {
      day = dateKey(d);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final allowed = kKinds.where((k) => s.canSee(k.module)).toList();
    if (allowed.isEmpty) return const SafeArea(child: Padding(padding: EdgeInsets.all(16), child: InfoLine('Diesel pages are not given to you on this site – ask the Admin.', bad: true)));
    final k = kindOf(kind);
    final today = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    return Scaffold(
      appBar: AppBar(title: Text(k.en), actions: [IconButton(tooltip: 'Pick a date', onPressed: _pickDate, icon: const Icon(Icons.calendar_month_outlined))]),
      floatingActionButton: s.canEdit(k.module)
          ? FloatingActionButton.extended(
              backgroundColor: k.color,
              foregroundColor: Colors.white,
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EntryForm(kind: k)));
                if (saved == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('New'),
            )
          : null,
      body: Column(children: [
        if (allowed.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final x in allowed) ButtonSegment(value: x.key, label: Text(x.en, overflow: TextOverflow.ellipsis))],
              selected: {kind},
              onSelectionChanged: (v) {
                kind = v.first;
                _load();
              },
            ),
          ),
        SizedBox(
          height: 68,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final d in days)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Day(d: d, on: dateKey(d) == day, onTap: () {
                  day = dateKey(d);
                  _load();
                }),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
          child: Row(children: [
            Expanded(child: Text(showDate(day), style: const TextStyle(fontWeight: FontWeight.w600))),
            if (!loading && err.isEmpty) Text('${rows.length} ${rows.length == 1 ? 'entry' : 'entries'} · ${fmtNum(total ?? 0)} L', style: TextStyle(color: k.color, fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            color: k.color,
            onRefresh: _load,
            child: loading
                ? const Center(child: CircularProgressIndicator(color: C.green))
                : err.isNotEmpty
                    ? ListView(padding: const EdgeInsets.all(16), children: [InfoLine(err, bad: true)])
                    : rows.isEmpty
                        ? ListView(padding: const EdgeInsets.all(32), children: [Text('No ${k.en.toLowerCase()} on ${showDate(day)}.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))])
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            itemCount: rows.length,
                            itemBuilder: (_, i) => _Row(k: k, r: rows[i]),
                          ),
          ),
        ),
      ]),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.d, required this.on, required this.onTap});
  final DateTime d;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: on ? C.green : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            width: 56,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(weekDays[d.weekday - 1], style: TextStyle(fontSize: 12, color: on ? Colors.white : C.ink)),
              Text('${d.day}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: on ? Colors.white : C.ink)),
            ]),
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.k, required this.r});
  final Kind k;
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context) {
    final (title, sub) = switch (k.key) {
      'issue' => (r['no'].toString(), [r['type'], r['source'], r['shift'], r['driver']].where((e) => (e ?? '').toString().isNotEmpty).join(' · ')),
      'inward' => (r['pump'].toString(), [r['location'], if ((r['billNo'] ?? '') != '') 'Bill ${r['billNo']}', if (asNum(r['rate']) != null && asNum(r['rate'])! > 0) '₹${fmtNum(asNum(r['rate']))}/L'].join(' · ')),
      _ => ('${r['from']} → ${r['to']}', [r['shift'], r['remark']].where((e) => (e ?? '').toString().isNotEmpty).join(' · ')),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: k.soft, borderRadius: BorderRadius.circular(16)), child: Icon(k.icon, color: k.color, size: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            Text('${r['id']} · $sub', style: const TextStyle(fontSize: 12.5, color: C.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        Text('${fmtNum(asNum(r['qty']))} L', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: k.color)),
      ]),
    );
  }
}
