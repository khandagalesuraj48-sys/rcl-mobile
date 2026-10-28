/* (3.59.0, Mechanical update-183, asked 28-10-2026: "mala samjay la haw konte vichle / asset ch maintanace log book add aahe kadhi prynt
 * updeted aahe konte ch baki aahe mhanje tas mi te kam karun ghein") THE LOG BOOK STATUS – the app's own screen of the web's "Log book
 * status": every Own machinery of the Asset Master (and any other machinery that has a bill) – its bills, its first bill, its last bill
 * (the log book is filled up to that date), what we paid; none yet: "Not added yet" (first). Show: All / Not added yet / Added. A machinery
 * with bills opens its Maintenance Log Book, Start to end. The same server action and access as the web (maintStatus – it only reads). */
import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/rdoc.dart' show money;
import '../core/report_defs.dart' show kMaintLog;
import '../ui/ask_bot.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'report_screen.dart' show openReport;

class MaintStatusScreen extends StatefulWidget {
  const MaintStatusScreen({super.key});
  @override
  State<MaintStatusScreen> createState() => _MaintStatusScreenState();
}

class _MaintStatusScreenState extends State<MaintStatusScreen> {
  Map<String, dynamic>? d;
  String err = '', show = 'all';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = (await SessionScope.read(context).api.call('maintStatus') as Map).cast<String, dynamic>();
      if (mounted) {
        setState(() {
          d = r;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dd = d, all = [for (final r in (dd?['rows'] as List? ?? const []).whereType<Map>()) r];
    final rows = [for (final r in all) if (show == 'all' || (show == 'none' ? (asNum(r['bills']) ?? 0) == 0 : (asNum(r['bills']) ?? 0) > 0)) r];
    return Scaffold(
      appBar: AppBar(actions: withAsk([IconButton(tooltip: tr('Refresh'), onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]), title: Text('Log book status')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('mst-list'), padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          if (dd != null)
            Text(dd['missing'] == true ? 'Maintenance bills cannot be kept yet at this site (its database step).' : '${dd['added'] ?? 0} added · ${dd['none'] ?? 0} not added yet (Own machinery of the Asset Master)',
                key: const Key('mst-sum'), style: const TextStyle(fontSize: 13.5, color: C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final x in const [('all', 'All'), ('none', 'Not added yet'), ('added', 'Added')]) ChoiceChip(key: Key('mst-f-${x.$1}'), selected: show == x.$1, onSelected: (_) => setState(() => show = x.$1), label: Text(x.$2)),
          ]),
          const SizedBox(height: 8),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading && dd == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (dd != null && rows.isEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Text('Nothing to show.', style: const TextStyle(color: C.muted))),
          for (final (i, r) in rows.indexed) Padding(padding: const EdgeInsets.only(bottom: 8), child: _row(i, r)),
        ]),
      ),
    );
  }

  Widget _row(int i, Map r) {
    final n = (asNum(r['bills']) ?? 0).toInt(), no = '${r['no'] ?? ''}', name = '${r['name'] ?? ''}';
    final what = [if (name.isNotEmpty && name != no) name, if ('${r['type'] ?? ''}'.isNotEmpty) '${r['type']}'].join(' · ');
    return Press(
      key: Key('mst-$no'),
      onTap: n > 0 ? () => openReport(context, kMaintLog, no: no, run: true, all: true) : null,
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 26, child: Text('${i + 1}', style: const TextStyle(fontSize: 13, color: C.muted))),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(no, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            if (what.isNotEmpty || r['onSite'] != true) Text('$what${r['onSite'] == true ? '' : '${what.isEmpty ? '' : ' '}${tr('(not on the site now)')}'}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            const SizedBox(height: 4),
            n > 0
                ? Text('✓ Up to ${showDate('${r['upTo']}')}', key: Key('mst-st-$no'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.greenDark))
                : Text('Not added yet', key: Key('mst-st-$no'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.red)),
            if (n > 0) Text('$n bill(s) · ${showDate('${r['from']}')} – ${showDate('${r['upTo']}')} · ₹${money(r['amount'])}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          ]),
        ),
        if (n > 0) const Icon(Icons.chevron_right_rounded, color: C.blue),
      ]),
    );
  }
}
