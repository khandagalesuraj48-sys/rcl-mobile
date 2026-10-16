// (3.2.0) The reports of the web in the app: every report built from the REAL answer of the test server (test/fixtures/reports),
// its tables as the web draws them, the Excel file (a real .xlsx: a zip with a sheet per table) and the PDF; the filters as the web.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/rdoc.dart';
import 'package:rcl_mobile/core/report_defs.dart';
import 'package:rcl_mobile/core/rprint.dart';
import 'package:rcl_mobile/core/xlsx.dart';
import 'package:rcl_mobile/screens/report_screen.dart';

Map<String, dynamic> fx(String fn) => (jsonDecode(File('test/fixtures/reports/$fn.json').readAsStringSync()) as Map).cast<String, dynamic>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final all = [...kDieselReports, kDailyReport, kMonthlyReport, kAvgReport];

  test('every report of the web is here, each from its own server report', () {
    expect(kDieselReports.map((d) => d.key).toList(), ['debit', 'mcost', 'cost', 'purchase', 'ledger', 'watch', 'owner', 'type', 'stock', 'compare', 'tank', 'average']);
    for (final p in ['rdaily', 'rmonthly', 'ravg', 'rp-average', 'rp-ledger', 'rp-stock', 'rp-purchase', 'rp-cost', 'rp-mcost', 'rp-owner', 'rp-type', 'rp-compare', 'rp-watch', 'rp-tank', 'rp-debit']) {
      expect(reportOfPage(p), isNotNull, reason: p);
    }
    expect(reportOfPage('dash'), isNull, reason: 'the Dashboard is its own screen');
  });

  for (final def in all) {
    test('${def.key}: built from the server\'s answer – tables, totals, Excel', () {
      final d = fx(def.fn);
      final doc = def.build(d);
      expect(doc.title, isNotEmpty);
      expect(doc.tables, isNotEmpty);
      for (final tb in doc.tables) {
        for (final r in [...tb.rows, ...tb.foot]) {
          final width = r.cells.fold<int>(0, (s, c) => s + c.span);
          expect(width <= tb.head.length, true, reason: '${def.key} ${tb.sheet}: a line of $width cells under ${tb.head.length} headings');
        }
      }
      final x = reportXlsx(doc, ['Rachana Construction Limited', 'VTR Site – NH 848', doc.title, doc.period]);
      final z = ZipDecoder().decodeBytes(x);
      final names = z.files.map((f) => f.name).toSet();
      expect(names.containsAll(['[Content_Types].xml', 'xl/workbook.xml', 'xl/styles.xml', 'xl/worksheets/sheet1.xml']), true);
      expect(names.where((n) => n.startsWith('xl/worksheets/')).length, doc.tables.length);
      final sheet1 = utf8.decode(z.files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml').content as List<int>);
      expect(sheet1, contains(doc.tables.first.head.first.replaceAll('&', '&amp;')));
      expect(sheet1, contains('Rachana Construction Limited'));
    });
  }

  test('the Stock Register: opening, every movement with its balance, the closing (as the web)', () {
    final d = fx('rptStock'), doc = kDieselReports.firstWhere((x) => x.key == 'stock').build(d);
    final tb = doc.tables.single;
    expect(tb.head, ['Sr', 'Date', 'Shift', 'Ref. ID', 'Particulars', 'In (Ltr)', 'Out (Ltr)', 'Balance (Ltr)']);
    expect(tb.rows.first.cells[4].text, 'Opening balance');
    expect(tb.rows.length, (d['rows'] as List).length + 1);
    expect(tb.foot.single.cells.first.text, startsWith('Total  |  Closing balance on'));
    expect(doc.kpis.map((k) => k.$1).toList(), ['Opening', 'In', 'Out', 'Closing']);
  });

  test('the web\'s numbers: 12,34,567.5 · money 2 decimals · – for nothing · +% ', () {
    expect(fmt(1234567.5), '12,34,567.5');
    expect(money(1387.5), '1,387.50');
    expect(z(0), '–');
    expect(pct(12.5), '+12.5%');
    expect(dmy('2026-10-16'), '16-10-2026');
  });

  test('the filters as the web: dates needed, an ownership, a machinery', () {
    final p = ReportPick()..start('2026-10-16', ['Dispenser', 'VTR Store'], kDieselReports.firstWhere((x) => x.key == 'stock'));
    expect([p.from, p.to, p.monthA, p.monthB, p.location], ['2026-10-01', '2026-10-16', '2026-09', '2026-10', 'Dispenser']);
    final cost = kDieselReports.firstWhere((x) => x.key == 'cost');
    expect(reportFilters(cost, p), {'from': '2026-10-01', 'to': '2026-10-16', 'rateMode': 'last', 'fixedRate': '', 'ownerships': kOwns});
    p.owns.clear();
    expect(() => reportFilters(cost, p), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'Tick at least one Ownership.')));
    final ledger = kDieselReports.firstWhere((x) => x.key == 'ledger');
    expect(() => reportFilters(ledger, ReportPick()..start('2026-10-16', [], ledger)), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'Pick a machinery from Master.')));
    final m = ReportPick()..start('2026-10-16', [], kAvgReport);
    expect(reportFilters(kAvgReport, m)['withReadings'], true);
    expect(reportFilters(kMonthlyReport, m)['withReadings'], false);
  });

  test('the print: A4 as the web (landscape for the wide ones), the company on top, every table, the signatures', () {
    final doc = kAvgReport.build(fx('getMonthlyAvgReport'));
    final h = reportHtml(doc, company: 'Sketchline Industries', site: 'VTR Site – NH 848', printed: '16-10-2026 16:16');
    expect(h, contains('size:A4 landscape'));
    expect(h, contains('<h1>SKETCHLINE INDUSTRIES</h1>'));
    expect(h, contains('<th>Total diesel (Ltr)</th>'));
    expect(h, contains('Prepared by'));
    expect(reportHtml(kDailyReport.build(fx('getDailyInwardIssueReport')), company: 'Rachana Construction Limited', site: '', printed: ''), contains('size:A4 portrait'));
  });
}
