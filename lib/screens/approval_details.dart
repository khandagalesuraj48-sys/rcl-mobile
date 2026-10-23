/* (3.31.5, with Mechanical's update-147 – asked 23-10-2026: "approval detna details madhe sagle bghta yaw ki entry mdhe ky ahe fkt
 * diesel nhi sagle approval mdhe … bulk approval asel tri") AN ENTRY IN APPROVALS IN FULL – the app's own view of the server's
 * "approvalDetails" (the same as the web page's "Details"): who sent it and what it does, every field with its name, its rows as a
 * table (every column; the machinery with its name), the photos / bill copies counted and – for a change of a saved entry – what
 * is saved now. The server decides who may see it (the Super Admin, the sender, the people of its levels). It only reads. */
import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/session.dart';
import '../ui/t.dart';
import '../ui/theme.dart';

/// The version of a request its details belong to: corrected and sent again, or decided → asked again.
String detailsKey(Map<String, dynamic> r) => '${r['id']}|${r['status']}|${((r['history'] as List?) ?? const []).length}';

/// The details of these requests, from the server (60 at a time), in the order asked.
Future<List<Map<String, dynamic>>> loadApprovalDetails(Session s, List<String> ids) async {
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < ids.length; i += 60) {
    final part = ids.sublist(i, i + 60 > ids.length ? ids.length : i + 60);
    final r = await s.api.call('approvalDetails', [{'ids': part}]);
    out.addAll(((r is Map ? r['details'] : null) as List? ?? const []).whereType<Map>().map((d) => d.cast<String, dynamic>()));
  }
  return out;
}

class ApprovalDetailsView extends StatelessWidget {
  const ApprovalDetailsView(this.d, {super.key, this.head = true});
  final Map<String, dynamic> d;
  final bool head;

  @override
  Widget build(BuildContext context) {
    final id = '${d['id'] ?? ''}';
    if ('${d['error'] ?? ''}'.isNotEmpty) return Text('$id: ${tr('${d['error']}')}', style: const TextStyle(color: C.red, fontSize: 13.5));
    final fields = ((d['fields'] as List?) ?? const []).whereType<List>().toList();
    final tables = ((d['tables'] as List?) ?? const []).whereType<Map>().map((t) => t.cast<String, dynamic>()).toList();
    final now = ((d['savedNow'] as List?) ?? const []).map((e) => '$e').toList();
    final photos = asNum(d['photos']) ?? 0;
    return Container(
      key: Key('det-view-$id'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: C.blueSoft.withValues(alpha: .45), borderRadius: BorderRadius.circular(14), border: const Border(left: BorderSide(color: C.blue, width: 3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (head) ...[
          Text('$id · ${tr('${d['action'] ?? ''}')}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text('${tr('${d['task'] ?? ''}')} · ${d['by'] ?? ''} · ${whenText('${d['at'] ?? ''}')}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 8),
        ],
        for (final f in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 118, child: Text('${f.isNotEmpty ? f[0] : ''}', style: const TextStyle(fontSize: 13, color: C.muted))),
              Expanded(child: Text('${f.length > 1 ? f[1] : ''}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
            ]),
          ),
        for (final t in tables) ...[
          const SizedBox(height: 6),
          _DetTable(t),
          if ((asNum(t['more']) ?? 0) > 0) Text(tr('… {0} more rows').replaceFirst('{0}', '${t['more']}'), style: const TextStyle(fontSize: 12.5, color: C.muted)),
        ],
        if (photos > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${tr('Photos / bill copies with it:')} ${photos.toInt()}', style: const TextStyle(fontSize: 13, color: C.muted))),
        if (now.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${tr('Saved now (before this change):')} ${now.join('; ')}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        if ('${d['reason'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${tr('Reason:')} ${d['reason']}', style: const TextStyle(fontSize: 13, color: C.muted))),
        if (fields.isEmpty && tables.isEmpty) const Text('Nothing more than the line above was sent.', style: TextStyle(fontSize: 13, color: C.muted)),
      ]),
    );
  }
}

/// A table of the entry's rows – it scrolls sideways inside its own box (the screen does not get wider).
class _DetTable extends StatelessWidget {
  const _DetTable(this.t);
  final Map<String, dynamic> t;

  @override
  Widget build(BuildContext context) {
    final cols = ((t['cols'] as List?) ?? const []).map((e) => '$e').toList();
    final rows = ((t['rows'] as List?) ?? const []).whereType<List>().toList();
    if (cols.isEmpty) return const SizedBox.shrink();
    Widget cell(String v, {bool h = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(v, style: TextStyle(fontSize: 12.5, fontWeight: h ? FontWeight.w700 : FontWeight.w500, color: h ? C.slate : C.ink)));
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: const TableBorder(horizontalInside: BorderSide(color: C.line)),
          children: [
            TableRow(decoration: const BoxDecoration(color: C.slateSoft), children: [for (final c in cols) cell(c, h: true)]),
            for (final r in rows) TableRow(children: [for (var i = 0; i < cols.length; i++) cell(i < r.length ? '${r[i]}' : '')]),
          ],
        ),
      ),
    );
  }
}
