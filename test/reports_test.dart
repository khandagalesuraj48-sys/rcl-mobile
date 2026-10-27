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
    expect(kDieselReports.map((d) => d.key).toList(), ['debit', 'ldebit', 'mcost', 'cost', 'purchase', 'ledger', 'watch', 'owner', 'type', 'stock', 'compare', 'tank', 'average']);
    for (final p in ['rdaily', 'rmonthly', 'ravg', 'rp-average', 'rp-ledger', 'rp-stock', 'rp-purchase', 'rp-cost', 'rp-mcost', 'rp-owner', 'rp-type', 'rp-compare', 'rp-watch', 'rp-tank', 'rp-debit', 'rp-ldebit']) {
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

  test('(3.31.7) the Log Book Debit Statement: party by party, each entry, the totals, its Debit Note (the real answer of the server)', () {
    final doc = kDieselReports.firstWhere((x) => x.key == 'ldebit').build(fx('rptLogDebit'));
    final sum = doc.tables.firstWhere((t) => t.sheet == 'Summary'), det = doc.tables.firstWhere((t) => t.sheet == 'Details');
    String row(RRow r) => r.cells.map((c) => c.text).join('|');
    expect(sum.rows.map(row).toList(), ['1|Chalke Enterprises|1|2|100 KM|1|5,500.00', '2|I E Enterprises|1|2|12.5 Hrs|–|13,750.00']);
    expect(row(sum.foot.single), 'Total – 2 parties|2|4|100 KM, 12.5 Hrs|1|19,250.00');
    expect(det.rows.map(row).first, 'Chalke Enterprises  |  1 machinery  |  2 entries');
    expect(row(det.rows[1]), startsWith('1|14-10-2026|Day|MH-25-LD-2169|Tipper|KM|42|KM|Murum carting for Chalke|RCL/'));
    expect(row(det.rows[1]), endsWith('|55.00|2,310.00'));
    expect(doc.kpis.map((k) => k.$2).toList(), ['2', '4', '100 KM, 12.5 Hrs', '₹19,250.00']);
    // the Excel lines of an import, as the web reads them
    final rows = ldImportRows([
      {'line': '2', 'date': '15-10-2026', 'shift': 'Day', 'no': 'MH-25-LD-2169', 'to': 'I E Enterprises', 'rate': '₹ 1,050', '_has': {'date': 0, 'shift': 1, 'no': 2, 'to': 3, 'rate': 4}},
      {'line': '3', 'date': 46310, 'shift': '', 'no': 'MH-25-LD-0210', 'to': '', 'rate': 60, '_has': {'date': 0, 'no': 2, 'rate': 4}},
      {'line': '4', 'date': '2026-10-14', 'shift': 'Night', 'no': 'MH-25-LD-0210', 'to': '  ', 'rate': 61, '_has': {'date': 0, 'shift': 1, 'no': 2, 'to': 3, 'rate': 4}},
    ]);
    expect(rows.first, {'line': '2', 'date': '2026-10-15', 'shift': 'Day', 'no': 'MH-25-LD-2169', 'to': 'I E Enterprises', 'rate': '1050'});
    expect(rows[1].containsKey('to'), false, reason: 'no "Debit to" column: the entry keeps its party');
    expect(rows[1]['shift'], '');
    expect(rows[2].containsKey('to'), false, reason: 'a blank "Debit to" cell: the entry keeps its party (as the web)');
  });

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
    // (3.31.7) the Log Book Debit Statement: a party and one machinery – both may be blank (all)
    final ld = kDieselReports.firstWhere((x) => x.key == 'ldebit');
    final lp = ReportPick()..start('2026-10-16', [], ld);
    expect(reportFilters(ld, lp), {'from': '2026-10-01', 'to': '2026-10-16', 'party': '', 'no': ''});
    lp
      ..party = ' Chalke Enterprises '
      ..no = 'MH-25-LD-2169';
    expect(reportFilters(ld, lp), {'from': '2026-10-01', 'to': '2026-10-16', 'party': 'Chalke Enterprises', 'no': 'MH-25-LD-2169'});
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

  test('(3.38.0 – Mechanical update-159) the daily report at 18B: a "Received from" and a "Sent to" column for EACH other stock point', () {
    const cp = 'CAMP PUMP', ze = 'DISPENSER - MH12ZE-1739', wj = 'DISPENSER - MH12WJ-1381';
    final doc = kDailyReport.build(<String, dynamic>{
      'company': 'Rachana Construction Limited', 'from': '2026-10-25', 'to': '2026-10-25', 'location': wj, 'byLocation': true, 'otherLocations': [cp, ze], 'groups': ['Own', 'Rental', 'Debit'],
      'rows': [
        {'date': '2026-10-25', 'opening': 0, 'inward': 0, 'tin': 1800, 'tout': 0, 'tinBy': {cp: 1500, ze: 300}, 'toutBy': {}, 'issue': {'Own': 150}, 'issued': 150, 'closing': 1650},
      ],
      'totals': {'opening': 0, 'inward': 0, 'tin': 1800, 'tout': 0, 'tinBy': {cp: 1500, ze: 300}, 'toutBy': {}, 'issued': 150, 'issue': {'Own': 150}, 'closing': 1650},
      'generated': '25-10-2026 13:00',
    });
    final t = doc.blocks.whereType<RTable>().single;
    expect(t.head.sublist(0, 7), ['Date', 'Opening stock', 'Inward (pump)', 'Received from $cp', 'Received from $ze', 'Sent to $cp', 'Sent to $ze']);
    expect(t.head.any((h) => h.contains(' / ')), false, reason: 'never "A / B" together');
    expect(t.rows.single.cells.sublist(3, 7).map((c) => c.text).toList(), ['1,500', '300', '–', '–']);
    expect(t.foot.single.cells.sublist(3, 7).map((c) => c.text).toList(), ['1,500', '300', '0', '0']);
    expect(doc.meta, contains('+ Received 1,800 − Sent 0 − Issued 150 = Closing 1,650'));
    // a server before update-159 (no tinBy): one column for the other places together, as the app showed before
    final old = kDailyReport.build(<String, dynamic>{'from': '2026-10-25', 'to': '2026-10-25', 'location': wj, 'byLocation': true, 'otherLocations': [cp, ze], 'groups': ['Own'],
      'rows': [{'date': '2026-10-25', 'opening': 0, 'inward': 0, 'tin': 1800, 'tout': 0, 'issue': {}, 'issued': 0, 'closing': 1800}], 'totals': {'opening': 0, 'inward': 0, 'tin': 1800, 'tout': 0, 'issued': 0, 'issue': {}, 'closing': 1800}});
    final ot = old.blocks.whereType<RTable>().single;
    expect(ot.head.sublist(3, 5), ['Received from $cp / $ze', 'Sent to $cp / $ze']);
    expect(ot.rows.single.cells[3].text, '1,800');
    // all locations: no transfer columns, as before
    expect(kDailyReport.build(fx('getDailyInwardIssueReport')).blocks.whereType<RTable>().single.head.sublist(0, 4), ['Date', 'Opening stock', 'Inward (pump)', 'Issued – Own']);
  });

  test('(3.44.0, Mechanical update-163) a report of one fuel in its words – the screen, the print and Excel (fuelDoc); Diesel as it is', () {
    final d = RDoc(title: 'Diesel Cost Report', meta: 'Rate of the day', kpis: [('Total diesel', '240 Ltr')], blocks: [
      RTable(sheet: 'Diesel', head: ['Machinery', 'Diesel (Ltr)'], rows: [const RRow([RCell('MH-12-HO-2163'), RCell('8', n: true, value: 8)])], foot: [const RRow([RCell('Total diesel'), RCell('8', n: true)])]),
      const RNote('Every diesel issue of the dates.'),
    ]);
    expect(identical(fuelDoc(d, 'Diesel'), d), true);
    final c = fuelDoc(d, 'CNG');
    expect([c.title, c.kpis.single, c.tables.single.head, c.tables.single.foot.single.cells.first.text, (c.blocks.last as RNote).text],
        ['CNG Cost Report', ('Total CNG', '240 kg'), ['Machinery', 'CNG (kg)'], 'Total CNG', 'Every CNG issue of the dates.']);
    expect(c.tables.single.rows.single.cells.last.value, 8, reason: 'the numbers stay as they are');
    expect(fuelDoc(d, 'Petrol').title, 'Petrol Cost Report');
  });
}
