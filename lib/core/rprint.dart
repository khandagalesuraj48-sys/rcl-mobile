/* A REPORT ON PAPER (3.2.0): the report as the web prints it – the company name chosen on top (Rachana with its logo, or another
 * name of the site's bills), the site, the title and the dates, the figures, the tables (portrait or landscape as the web), and
 * Prepared by / Checked by / Approved by under it – handed to the phone's printing (a printer, or "Save as PDF" to send it on). */
import 'rdoc.dart';

String _e(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const _tone = {'bad': '#C62828', 'warn': '#B45309', 'good': '#0E5A2A', 'info': '#1543B8', 'muted': '#6B7280'};

/// The page to print. [logo]: a data: address of the logo (empty = the name only).
String reportHtml(RDoc doc, {required String company, required String site, required String printed, String logo = ''}) {
  final name = company.toLowerCase().contains('sketchline') ? company.toUpperCase() : company;
  final b = StringBuffer();
  final big = doc.tables.fold<double>(0, (m, tb) {
    final u = colUnits(tb).fold<double>(0, (s, x) => s + x);
    return u > m ? u : m;
  });
  final fs = big > 220 ? 6.2 : big > 160 ? 7 : big > 110 ? 8 : 9;
  b.write('<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${_e(doc.title)}</title><style>'
      '@page{size:A4 ${doc.portrait ? 'portrait' : 'landscape'};margin:10mm 8mm 12mm}'
      'body{font-family:Arial,Helvetica,"Noto Sans Devanagari",sans-serif;color:#111827;margin:0;font-size:${fs}pt}'
      '.h{display:flex;align-items:flex-start;gap:10px;border-bottom:1.5px solid #111827;padding-bottom:6px;margin-bottom:6px}'
      '.h img{height:42px}.h .t{flex:1}.h h1{font-size:14pt;margin:0}.h h2{font-size:11pt;margin:2px 0 0}.h .s{color:#4B5563;font-size:9pt}.h .m{text-align:right;font-size:8.5pt}'
      '.meta{color:#4B5563;font-size:7.5pt;margin:2px 0 6px}.k{display:flex;flex-wrap:wrap;gap:5px;margin:4px 0 8px}.k div{border:1px solid #D1D5DB;border-radius:3px;padding:2px 6px}.k span{display:block;color:#4B5563;font-size:7pt}.k b{font-size:9pt}'
      'h3{font-size:10pt;margin:10px 0 3px}p.n{color:#4B5563;font-size:7.5pt;margin:3px 0}'
      'table{border-collapse:collapse;width:100%;margin:4px 0 8px}th,td{border:1px solid #CBD5E1;padding:2px 3px;vertical-align:top;white-space:pre-line}th{background:#E5E7EB;text-align:left}'
      'td.n{text-align:right;white-space:nowrap}tr.g td{background:#E6F4E8;font-weight:700}tr.s td{background:#F3F4F6;font-weight:700}tr.t td{background:#E5E7EB;font-weight:700}tr.u td{background:#FFF7ED}thead{display:table-header-group}tr{page-break-inside:avoid}'
      '.sign{display:flex;gap:30px;margin-top:40px}.sign div{flex:1;border-top:1px solid #111827;text-align:center;padding-top:3px;font-size:8.5pt}.sign small{display:block;color:#6B7280}'
      '</style></head><body>');
  b.write('<div class="h">${logo.isNotEmpty ? '<img src="$logo" alt="">' : ''}<div class="t"><h1>${_e(name)}</h1>${site.isNotEmpty ? '<div class="s">${_e(site)}</div>' : ''}<h2>${_e(doc.title)}</h2></div>'
      '<div class="m">${doc.period.isNotEmpty ? 'Period: <b>${_e(doc.period)}</b><br>' : ''}Printed: ${_e(printed)}</div></div>');
  if (doc.meta.isNotEmpty) b.write('<div class="meta">${_e(doc.meta)}</div>');
  if (doc.kpis.isNotEmpty) b.write('<div class="k">${doc.kpis.map((k) => '<div><span>${_e(k.$1)}</span><b>${_e(k.$2)}</b></div>').join()}</div>');
  for (final x in doc.blocks) {
    if (x is RNote) {
      b.write(x.heading ? '<h3>${_e(x.text)}</h3>' : '<p class="n">${_e(x.text)}</p>');
      continue;
    }
    if (x is! RTable) continue;
    b.write('<table><thead><tr>${x.head.map((h) => '<th>${_e(h)}</th>').join()}</tr></thead><tbody>');
    if (x.rows.isEmpty && x.empty.isNotEmpty) b.write('<tr><td colspan="${x.head.length}">${_e(x.empty)}</td></tr>');
    void line(RRow r, String cls) {
      var c = 0;
      b.write('<tr${cls.isEmpty ? '' : ' class="$cls"'}>');
      for (final cell in r.cells) {
        final right = cell.n || (cell.span == 1 && x.numCols.contains(c));
        final st = [if (cell.bold) 'font-weight:700', if (_tone[cell.tone] != null) 'color:${_tone[cell.tone]}'].join(';');
        b.write('<td${cell.span > 1 ? ' colspan="${cell.span}"' : ''}${right ? ' class="n"' : ''}${st.isEmpty ? '' : ' style="$st"'}>${_e(cell.text)}</td>');
        c += cell.span;
      }
      if (c < x.head.length) b.write('<td colspan="${x.head.length - c}"></td>');
      b.write('</tr>');
    }

    for (final r in x.rows) {
      line(r, switch (r.kind) { RKind.group => 'g', RKind.sub => 's', RKind.grand => 't', RKind.sunday => 'u', _ => '' });
    }
    for (final r in x.foot) {
      line(r, 't');
    }
    b.write('</tbody></table>');
  }
  final signs = doc.signs.isNotEmpty ? doc.signs : const [('Prepared by', 'Name, Sign & Date'), ('Checked by', 'Name, Sign & Date'), ('Approved by', 'Name, Sign & Date')];
  b.write('<div class="sign">${signs.map((s) => '<div><b>${_e(s.$1)}</b><small>${_e(s.$2)}</small></div>').join()}</div></body></html>');
  return b.toString();
}
