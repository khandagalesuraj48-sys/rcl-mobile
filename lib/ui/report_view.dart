/* A REPORT ON THE PHONE (3.2.0): the title and dates, the figures on top as tiles, then each table of the report – its heading
 * row stays on top, it slides sideways when it is wider than the phone and up / down inside its box when it is long; group lines
 * (Own / Rental …) green, totals grey, the colour of a sign / status as on the web. */
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../core/rdoc.dart';
import 'theme.dart';
import 't.dart';

Color toneColor(String tone) => switch (tone) { 'bad' => C.red, 'warn' => C.amber, 'good' => C.greenDark, 'info' => C.blue, 'muted' => C.muted, _ => C.ink };

class ReportView extends StatelessWidget {
  const ReportView(this.doc, {super.key});
  final RDoc doc;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(doc.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        if (doc.meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(doc.meta, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35))),
        if (doc.kpis.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < doc.kpis.length; i++)
              Container(
                key: Key('kpi-$i'),
                constraints: const BoxConstraints(minWidth: 96),
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                decoration: BoxDecoration(color: i == 0 ? C.greenSoft : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(doc.kpis[i].$1, style: const TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(doc.kpis[i].$2, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: i == 0 ? C.greenDark : C.ink)),
                ]),
              ),
          ]),
        ],
        for (final b in doc.blocks)
          if (b is RNote)
            Padding(
              padding: EdgeInsets.only(top: b.heading ? 18 : 8, bottom: b.heading ? 2 : 0),
              child: Text(b.text, style: b.heading ? const TextStyle(fontSize: 16, fontWeight: FontWeight.w800) : const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
            )
          else if (b is RTable)
            Padding(padding: const EdgeInsets.only(top: 12), child: RTableView(b)),
      ]);
}

class RTableView extends StatelessWidget {
  const RTableView(this.tb, {super.key});
  final RTable tb;

  @override
  Widget build(BuildContext context) {
    final units = colUnits(tb);
    final w = [for (var i = 0; i < units.length; i++) math.max(math.max(48.0, math.min(tb.head[i].length, 12) * 8.0 + 18), math.min(300.0, units[i] * 8.8 + 20))];
    final total = w.fold<double>(0, (s, x) => s + x);
    final lines = [...tb.rows, ...tb.foot];
    final tall = lines.length > 14;
    final boxH = math.min(MediaQuery.of(context).size.height * .62, 40.0 + lines.length * 36);
    Widget row(List<RCell> cells, {RKind kind = RKind.normal, bool head = false}) {
      var c = 0;
      final kids = <Widget>[];
      for (final cell in cells) {
        var width = 0.0;
        for (var i = c; i < c + cell.span && i < w.length; i++) {
          width += w[i];
        }
        final right = cell.n || (cell.span == 1 && !head && tb.numCols.contains(c));
        kids.add(Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(cell.text,
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: TextStyle(fontSize: head ? 12 : 13, height: 1.25, fontWeight: head || cell.bold || kind == RKind.grand || kind == RKind.group ? FontWeight.w700 : FontWeight.w400, color: head ? C.muted : toneColor(cell.tone))),
        ));
        c += cell.span;
      }
      if (c < w.length) kids.add(SizedBox(width: w.sublist(c).fold<double>(0, (s, x) => s + x)));
      final bg = head
          ? C.slateSoft
          : switch (kind) { RKind.group => C.greenSoft, RKind.sub => const Color(0xFFF6F7F9), RKind.grand => const Color(0xFFEDEFF3), RKind.sunday => const Color(0xFFFFF8EE), _ => Colors.white };
      return DecoratedBox(decoration: BoxDecoration(color: bg, border: const Border(bottom: BorderSide(color: C.line))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: kids));
    }

    final header = row([for (final h in tb.head) RCell(h)], head: true);
    final body = lines.isEmpty
        ? Container(width: total, padding: const EdgeInsets.all(16), child: Text(tb.empty.isEmpty ? 'Nothing to show.' : tb.empty, style: const TextStyle(color: C.muted)))
        : tall
            ? SizedBox(
                height: boxH,
                width: total,
                child: ListView.builder(
                  itemCount: lines.length,
                  itemBuilder: (_, i) => row(lines[i].cells, kind: i >= tb.rows.length ? RKind.grand : lines[i].kind),
                ),
              )
            : Column(children: [for (var i = 0; i < lines.length; i++) row(lines[i].cells, kind: i >= tb.rows.length ? RKind.grand : lines[i].kind)]);
    return Container(
      key: Key('rtable-${tb.sheet}'),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: total, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, body])),
      ),
    );
  }
}
