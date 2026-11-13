/* MY ATTENDANCE AS A PDF (3.117.0, his word of 13-11-2026: "user application madhun attednnce pdf download kru shakel proper …
 * company name … site … heading madhe month … period … sr no date eka khali ek … khali ek mast design madhe kiti diwas present
 * absent late mark … kontya hi month chi"): one month of one person – the company and the site in the head, the month and its
 * period, every day in a row (Sr · Date · Day · Status · IN · OUT · Hours · Remark) and, under it, the month's count in boxes.
 * Made on the phone from what the HR server said for the month (myMonth) – nothing is counted here except the hours between
 * a day's IN and OUT. */
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _status = {'P': 'Present', 'HD': 'Half day', 'A': 'Absent', 'L': 'Leave', 'WO': 'Weekly off', 'H': 'Holiday', 'WOP': 'Worked on weekly off', 'HP': 'Worked on holiday', 'IN': 'At work', 'MIS': 'OUT not marked'};
const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _week = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The letters the PDF's own type has (Latin); any other letter is left out so that the page is always made.
String pdfWords(Object? v) => String.fromCharCodes('${v ?? ''}'.replaceAll('–', '-').replaceAll('·', '-').runes.where((r) => r >= 0x20 && r <= 0xFF)).trim();

String _dmy(String day) => day.length >= 10 ? '${day.substring(8, 10)}-${day.substring(5, 7)}-${day.substring(0, 4)}' : day;

int? _min(Object? v) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${v ?? ''}');
  return m == null ? null : int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

/// "8 h 05 m" between a day's IN and OUT (past midnight when OUT is before IN); '' when one of them is not there.
String pdfHours(Object? a, Object? b) {
  final x = _min(a), y = _min(b);
  if (x == null || y == null) return '';
  final d = y >= x ? y - x : y + 1440 - x;
  return '${d ~/ 60} h ${(d % 60).toString().padLeft(2, '0')} m';
}

/// The month's name and its period: ("November 2026", "01-11-2026 to 30-11-2026").
(String, String) pdfMonth(String month) {
  final y = int.tryParse(month.length >= 4 ? month.substring(0, 4) : '') ?? 2000, mo = int.tryParse(month.length >= 7 ? month.substring(5, 7) : '') ?? 1;
  final last = DateTime.utc(y, mo + 1, 0).day, mm = mo.toString().padLeft(2, '0');
  return ('${_months[(mo - 1).clamp(0, 11)]} $y', '01-$mm-$y to ${last.toString().padLeft(2, '0')}-$mm-$y');
}

Future<Uint8List> attendancePdf({required String company, required String site, required String name, required String code, required String month, required List<Map> days, required Map total, String made = ''}) async {
  const navy = PdfColor.fromInt(0xFF0F1F3D), gold = PdfColor.fromInt(0xFFB07C19), line = PdfColor.fromInt(0xFFDDE2EC), soft = PdfColor.fromInt(0xFFF4F6FB), muted = PdfColor.fromInt(0xFF59647E);
  const green = PdfColor.fromInt(0xFF146C2E), red = PdfColor.fromInt(0xFFC22A1B), amber = PdfColor.fromInt(0xFF8A5A00), purple = PdfColor.fromInt(0xFF6A3D8A);
  final (title, period) = pdfMonth(month);
  PdfColor hue(String c) => switch (c) { 'P' || 'WOP' || 'HP' || 'IN' => green, 'A' || 'MIS' => red, 'HD' => amber, 'L' => purple, _ => muted };
  pw.Widget cell(String t, {bool bold = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5), child: pw.Text(pdfWords(t), textAlign: align, style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)));
  final rows = <pw.TableRow>[
    pw.TableRow(repeat: true, decoration: const pw.BoxDecoration(color: navy), children: [
      for (final h in const ['Sr', 'Date', 'Day', 'Status', 'IN', 'OUT', 'Hours', 'Remark']) cell(h, bold: true, color: PdfColors.white),
    ]),
  ];
  var sr = 0;
  for (final d in days) {
    final day = '${d['day'] ?? ''}', c = '${d['code'] ?? ''}', dt = DateTime.tryParse('${day}T00:00:00Z');
    final late = d['late_min'] is num ? (d['late_min'] as num).round() : 0;
    final remark = [if (late > 0) 'Late $late min', if (d['late_half'] == true) 'Late - counted as half day', if (d['auto'] == true) 'OUT not marked - closed by itself'].join('; ');
    sr++;
    rows.add(pw.TableRow(decoration: sr.isEven ? const pw.BoxDecoration(color: soft) : null, children: [
      cell('$sr', align: pw.TextAlign.right),
      cell(_dmy(day)),
      cell(dt == null ? '' : _week[dt.weekday - 1], color: muted),
      cell(_status[c] ?? c, bold: c.isNotEmpty, color: hue(c)),
      cell('${d['in'] ?? ''}'),
      cell('${d['out'] ?? ''}'),
      cell(pdfHours(d['in'], d['out'])),
      cell(remark, color: muted),
    ]));
  }
  String n(Object? v) => v is num ? (v == v.roundToDouble() ? '${v.round()}' : '$v') : '0';
  pw.Widget box(String label, Object? v, PdfColor color) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 3),
          padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: pw.BoxDecoration(color: soft, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: line, width: .6)),
          child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
            pw.Text(n(v), style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: muted)),
          ]),
        ),
      );
  final doc = pw.Document(title: pdfWords('Attendance $title - $name'), author: pdfWords(company));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 30),
    footer: (c) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(pdfWords(made.isEmpty ? 'Made from the attendance app' : 'Made on $made from the attendance app'), style: const pw.TextStyle(fontSize: 8, color: muted)),
        pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: muted)),
      ]),
    ),
    build: (c) => [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: pw.BoxDecoration(color: navy, borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisSize: pw.MainAxisSize.min, children: [
              pw.Text(pdfWords(company), style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.SizedBox(height: 3),
              pw.Text(pdfWords(site), style: const pw.TextStyle(fontSize: 10.5, color: PdfColor.fromInt(0xFFD5DBEA))),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, mainAxisSize: pw.MainAxisSize.min, children: [
            pw.Text('ATTENDANCE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1.4, color: const PdfColor.fromInt(0xFFF1D58A))),
            pw.SizedBox(height: 2),
            pw.Text(title, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ]),
        ]),
      ),
      pw.SizedBox(height: 10),
      pw.Row(children: [
        pw.Expanded(child: pw.RichText(text: pw.TextSpan(style: const pw.TextStyle(fontSize: 10.5), children: [const pw.TextSpan(text: 'Employee: ', style: pw.TextStyle(color: muted)), pw.TextSpan(text: pdfWords(name), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.TextSpan(text: code.isEmpty ? '' : '   Code: ', style: const pw.TextStyle(color: muted)), pw.TextSpan(text: pdfWords(code), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]))),
        pw.Text('Period: $period', style: pw.TextStyle(fontSize: 10.5, color: gold, fontWeight: pw.FontWeight.bold)),
      ]),
      pw.SizedBox(height: 10),
      pw.Table(
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: line, width: .5), bottom: pw.BorderSide(color: line, width: .5)),
        columnWidths: const {0: pw.FixedColumnWidth(26), 1: pw.FixedColumnWidth(64), 2: pw.FixedColumnWidth(34), 3: pw.FlexColumnWidth(2.2), 4: pw.FixedColumnWidth(40), 5: pw.FixedColumnWidth(40), 6: pw.FixedColumnWidth(58), 7: pw.FlexColumnWidth(3)},
        children: rows,
      ),
      pw.SizedBox(height: 14),
      pw.Text('The month in numbers', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: navy)),
      pw.SizedBox(height: 6),
      pw.Row(children: [box('Present', total['P'], green), box('Half day', total['HD'], amber), box('Absent', total['A'], red), box('Leave', total['L'], purple)]),
      pw.SizedBox(height: 6),
      pw.Row(children: [box('Weekly off', total['WO'], muted), box('Holiday', total['H'], muted), box('Late marks', total['late'], amber), box('Days for pay', total['paid'], navy)]),
    ],
  ));
  return doc.save();
}
