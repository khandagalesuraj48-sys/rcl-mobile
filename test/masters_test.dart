/* (3.4.0) The masters' rules as the web works them out – from the real answers of the test server (test/fixtures/masters: getInit's
 * machinery, getVendors, getBoqs, getCompliance, exportMaster, boqMissing; user names replaced) and a few machinery made here. */
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/assets.dart';
import 'package:rcl_mobile/core/masters.dart';
import 'package:rcl_mobile/core/rdoc.dart' show RNote;
import 'package:rcl_mobile/core/rprint.dart';
import 'package:rcl_mobile/core/xlsx.dart';
import 'package:rcl_mobile/screens/boq.dart' show boqDoc;
import 'package:rcl_mobile/screens/compliance.dart' show complianceExportDoc;

dynamic fx(String n) => jsonDecode(File('test/fixtures/masters/$n.json').readAsStringSync());
List<Map<String, dynamic>> maps(dynamic l) => [for (final x in (l as List).whereType<Map>()) x.cast<String, dynamic>()];

/// The sheets of an .xlsx: name → its cells' texts (inline strings and numbers), row by row.
Map<String, List<String>> sheets(List<int> bytes) {
  final z = ZipDecoder().decodeBytes(bytes);
  final wb = utf8.decode(z.findFile('xl/workbook.xml')!.content as List<int>);
  final names = RegExp(r'<sheet name="([^"]*)"').allMatches(wb).map((m) => m.group(1)!).toList();
  return {
    for (final (i, n) in names.indexed)
      n: RegExp(r'<row r="\d+">(.*?)</row>').allMatches(utf8.decode(z.findFile('xl/worksheets/sheet${i + 1}.xml')!.content as List<int>)).map((r) => RegExp(r'<t xml:space="preserve">([^<]*)</t>|<v>([^<]*)</v>').allMatches(r.group(1)!).map((c) => c.group(1) ?? c.group(2)).join('|')).toList(),
  };
}

void main() {
  final master = maps(fx('getInit')['master']);

  group('Asset Master', () {
    test('Works on → unit; a vehicle number written as the server writes it; the id', () {
      expect(unitFromWorks(['KM']), 'KM');
      expect(unitFromWorks(['Hrs', 'KM']), 'KM + Hrs');
      expect(unitFromWorks(['Time']), 'Hrs');
      expect(unitFromWorks(['Day', 'Trip']), 'Day');
      expect(unitFromWorks([]), '');
      expect(formatNo('mh12ab1234'), 'MH-12-AB-1234');
      expect(formatNo('MH 04 J 9844'), 'MH-04-J-9844');
      expect(formatNo('  Sany   210 '), 'Sany 210');
      expect(idOf('', ' JCB  3DX '), 'JCB 3DX');
      expect(worksOf({'unit': 'KM + Hrs'}), ['KM', 'Hrs']);
      expect(worksOf(master.first), ['Hrs']);
    });

    test('On site by dates: its earlier periods count too (update-119); the days of a month', () {
      final m = {'id': 'X', 'status': 'Active', 'activeFrom': '2026-10-10', 'earlier': [{'from': '2026-08-01', 'until': '2026-09-01'}]};
      expect(onSiteIn(m, '2026-08-15', '2026-08-15'), true);
      expect(onSiteIn(m, '2026-09-05', '2026-10-01'), false, reason: 'away between the periods');
      expect(onSiteIn(m, '2026-10-12', '2026-10-12'), true);
      final off = {'id': 'Y', 'status': 'Inactive', 'inactiveFrom': '2026-10-05'};
      expect(onSiteIn(off, '2026-10-04', '2026-10-04'), true);
      expect(onSiteIn(off, '2026-10-05', '2026-10-31'), false);
      expect(siteSpan(m, '2026-08-01', '2026-10-31').days, 31 + 22);
      expect(periodText(const Period('2026-08-01', '2026-09-01')), '01-08-2026 – 31-08-2026');
      expect(earlierText(m), 'earlier: 01-08-2026 – 31-08-2026');
      expect(statusText(off), 'Inactive from 05-10-2026');
    });

    test('The list\'s filters and vendor chips (the test server\'s machinery)', () {
      final f = AssetFilter()..from = '2026-08-15'..to = '2026-08-15';
      final onAug = master.where((m) => f.test(m)).length;
      expect(onAug, master.where((m) => '${m['activeFrom'] ?? ''}'.isEmpty).length, reason: 'those from 01-09-2026 were not on site yet');
      f
        ..from = ''
        ..to = ''
        ..own = 'Rental';
      expect(master.where((m) => f.test(m)).length, 9);
      f
        ..own = ''
        ..q = 'ex-2';
      expect(master.where((m) => f.test(m)).map((m) => m['id']), ['EX-200']);
      expect(f.summary(1, 53), 'Machinery: 1 of 53');
      f
        ..q = ''
        ..from = '2026-10-14'
        ..to = '2026-10-14';
      expect(f.summary(5, 5), 'Machinery: 5 · on site on 14-10-2026');
      f.vc = 'none';
      expect(master.where((m) => f.test(m)).every((m) => '${m['owner']}'.isEmpty), true);
    });

    test('Papers: expired / due within 30 days / OK; the words of each', () {
      final m = {'taxUpto': 'LIFETIME', 'pucUpto': '2026-09-30', 'insuranceUpto': '2026-10-20', 'fitnessUpto': '2027-01-01'};
      final d = docState(m, '2026-10-14');
      expect(d.given, 3);
      expect(d.expired, ['PUC 30-09-2026']);
      expect(d.due, ['Insurance 20-10-2026']);
      expect(d.text, '1 expired');
      expect(d.tone, 'bad');
      expect(docShow('NA'), 'N/A');
      expect(docShow('LIFETIME'), 'Lifetime');
      expect(docShow(''), '–');
      expect(docState({}, '2026-10-14').text, '–');
    });

    test('An edit: what changes (as the web\'s "Update …?"), came back / never left', () {
      final before = {'no': 'MH-25-AJ-2169', 'name': '', 'worksOn': ['KM'], 'kmStd': 3.5, 'ownership': 'Rental', 'status': 'Inactive', 'inactiveFrom': '2026-10-01', 'activeFrom': '', 'earlier': []};
      final after = {'no': 'MH-25-AJ-2169', 'name': '', 'worksOn': 'KM', 'kmStd': 3.5, 'ownership': 'Rental', 'status': 'Active', 'inactiveFrom': '', 'activeFrom': '2026-10-12', 'earlier': []};
      final ch = masterChanges(before, after);
      expect(ch.map((c) => c.$1), ['Status', 'Active From', 'Inactive From', 'It came back']);
      expect(ch.last.$3, 'back on 12-10-2026 (until then kept as an earlier period)');
      final never = masterChanges(before, {...after, 'activeFrom': ''});
      expect(never.last.$1, 'It never left');
      expect(masterChanges(before, {...before, 'worksOn': 'KM'}), isEmpty, reason: 'nothing changed');
      expect(masterChanges({...before, 'earlier': []}, {...before, 'worksOn': 'KM', 'earlier': [{'from': '2026-06-01', 'until': '2026-08-01'}]}).single.$1, 'Earlier periods on site');
      expect(savedWords('edit', {'renamed': {'from': 'A-1', 'to': 'B-2', 'text': '3 diesel issues'}}), 'Machinery updated – A-1 is now B-2 (moved with it: 3 diesel issues).');
      expect(savedWords('add', {}), 'Machinery saved.');
    });

    test('Edit selected: a shared value is filled in; only what was changed is sent', () {
      final list = [
        {'type': 'Tipper', 'ownership': 'Rental', 'status': 'Active', 'kmStd': 3.5},
        {'type': 'Tipper', 'ownership': 'Hired', 'status': 'Active', 'kmStd': 4},
      ];
      final c = meCommon(list);
      expect(c['type'], (same: true, v: 'Tipper'));
      expect(c['ownership']!.same, false);
      expect(meChanges(c, {}, '2026-10-14'), isEmpty);
      expect(meChanges(c, {'ownership': 'Rental', 'type': 'Tipper'}, '2026-10-14'), {'ownership': 'Rental'});
      expect(meChanges(c, {'type': ''}, '2026-10-14'), {'type': ''}, reason: 'a shared value cleared');
      expect(meChanges(c, {'status': 'Inactive'}, '2026-10-14'), {'status': 'Inactive', 'inactiveFrom': '2026-10-14'});
    });

    test('Print list and Asset list (date / month): columns, the days on site, the summary by type', () {
      final d = masterListDoc(master, 'none');
      expect(d.title, 'Asset Master – vendor not assigned');
      expect(d.tables.single.head.length, 16);
      expect(d.tables.single.rows.length, master.length);
      final a = AssetListAsk()
        ..kind = 'month'
        ..month = '2026-10'
        ..papers = true;
      final (from, to, problem) = a.range();
      expect((from, to, problem), ('2026-10-01', '2026-10-31', ''));
      final doc = assetListDoc(master, a, from, to, null);
      expect(doc.title, 'Asset List – October 2026');
      final t = doc.tables.first;
      expect(t.head, containsAll(['Tax', 'PUC', 'Permit', 'Fitness', 'Insurance', 'Days on site']));
      expect(t.rows.length, master.where((m) => onSiteIn(m, from, to)).length);
      final sum = doc.tables.last;
      expect(sum.sheet, 'Summary by type');
      expect(sum.foot.single.cells.last.text, '${t.rows.length}');
      expect((AssetListAsk()
            ..kind = 'period'
            ..from = '2026-10-10'
            ..to = '2026-10-01')
          .range()
          .$3, 'From date is after To date.');
    });

    test('Export to Excel: the server\'s columns, the heading line first (it can be imported back)', () {
      final ex = (fx('exportMaster') as Map).cast<String, dynamic>();
      final x = sheets(reportXlsx(masterExportDoc(ex, '2026-10-16'), const []));
      expect(x.keys, ['Master']);
      expect(x['Master']!.first, startsWith('Machinery Number|Machinery Name|Type of Machinery'));
      expect(x['Master']!.length, (ex['rows'] as List).length + 1);
    });
  });

  group('Vendors', () {
    final vs = maps(fx('getVendors'));
    test('How complete; search and the Details filter; the bank as the web shows it', () {
      expect(vs.map((v) => vendorState(v).$1).toSet(), isNotEmpty);
      expect(vendorState({'saved': false, 'machines': [{'ownership': 'Own'}]}), ('Own company', 'good'));
      expect(vendorState({'saved': true, 'complete': false}), ('Incomplete', 'warn'));
      expect(vendorState({'saved': false, 'complete': false}), ('Not filled', 'bad'));
      expect(vendorsShown(vs, 'item', '').map((v) => v['name']), ['Item Vendor']);
      expect(vendorsShown(vs, '', 'done').every((v) => v['complete'] == true), true);
      expect(bankText({'bank': 'SBI', 'account': '1234567890'}), 'SBI · ••••7890');
      expect(bankText({}), '–');
    });

    test('A GST number: its check letter, State, the PAN inside it; a mistyped one is caught', () {
      final g14 = '27ABCDE1234F1Z';
      final g = g14 + gstCheckLetter(g14);
      final r = gstRead(g)!;
      expect(r.bad, '');
      expect(r.pan, 'ABCDE1234F');
      expect(r.state, 'Maharashtra');
      expect(r.kind, '');
      final wrong = g14 + (gstCheckLetter(g14) == 'A' ? 'B' : 'A');
      expect(gstRead(wrong)!.bad, contains('one character is mistyped'));
      expect(gstRead('27ABCDE1234F1Z')?.bad, isNull, reason: 'not 15 characters yet');
      expect(gstRead('99ABCDE12341ZZZ')!.bad, contains('not in the right format'));
      expect(gstRead('27ABCPE1234F1Z${gstCheckLetter('27ABCPE1234F1Z')}')!.kind, 'Individual / Proprietor');
    });
  });

  group('BOQ', () {
    final b = (fx('getBoqs') as Map).cast<String, dynamic>();
    final boqs = maps(b['boqs']), vendors = maps(b['vendors']);
    test('A line in words (as the web): Item-wise, slabs, a night trip rate, no rent', () {
      final iw = maps(boqs.first['lines']).first;
      expect(boqLineText(iw), 'Item-wise: Bucket – Per Hour ₹1,200; Breaker – Per Hour ₹1,500 [typed in Log Book]');
      expect(boqLineText({'basis': 'Per Hour', 'rate': '', 'slabs': [{'upTo': 1, 'rate': 1000}, {'upTo': '', 'rate': 2000}], 'slabOn': 'Day'}), 'Per Hour: first 1 hr ₹1,000, after that ₹2,000 (each day)');
      expect(boqLineText({'basis': 'Per Trip', 'rate': 500, 'nightRate': 650}), 'Per Trip ₹500, Night trip ₹650');
      expect(boqLineText({'basis': 'No rent – diesel only'}), 'No rent – diesel only (all diesel debited)');
      expect(boqDieselText({'diesel': 'Debit Basis'}), 'diesel: debit basis');
    });

    test('The next number; machinery already in another BOQ of the vendor for these dates', () {
      expect(boqNextNo(boqs, 'Item Vendor'), '2');
      expect(boqNextNo(boqs, 'Nobody'), '1');
      final tk = boqTaken(boqs, vendor: 'Multi Vendor', from: '2026-10-01', to: '', mode: 'new');
      expect(tk.keys, containsAll(['MV-1', 'MV-2', 'MV-3', 'MV-4']));
      expect(boqTaken(boqs, vendor: 'Multi Vendor', from: '2026-10-01', to: '', mode: 'amend'), isEmpty, reason: 'an amendment changes machinery that are in the BOQ');
      expect(boqTaken(boqs, vendor: 'Multi Vendor', from: '2026-10-01', to: '', mode: 'edit', editId: 'BOQ-0038'), isEmpty, reason: 'its own lines');
      expect(boqTaken(boqs, vendor: 'Multi Vendor', from: '2025-01-01', to: '2025-12-31', mode: 'new'), isEmpty, reason: 'other dates');
    });

    test('A saved line back into the form and out again – the same shape; the form\'s rules', () {
      for (final bq in boqs) {
        for (final l in maps(bq['lines'])) {
          final j = BoqLine.of(l).toJson();
          expect(j['no'], l['no']);
          expect(j['basis'], l['basis']);
          expect(j['diesel'], l['diesel']);
          expect((j['items'] as List).length, maps(l['items'] ?? []).length);
        }
      }
      final l = BoqLine(basis: 'No rent – diesel only', rate: '500')..tidy();
      expect((l.rate, l.diesel), ('', 'Debit Basis'));
      final iw = BoqLine(basis: 'Item-wise', rate: '9')..tidy();
      expect(iw.items.map((it) => it.qty), ['rest', 'typed']);
      final ph = BoqLine(basis: 'Per Hour', rate: '1000', slabs: [BoqSlab('1', '1000'), BoqSlab('', '2000')])..tidy();
      expect(ph.rate, '');
      expect(ph.toJson()['slabOn'], 'Day');
      final same = ph.sameFor('MV-9');
      expect((same.no, same.slabs.length, same.remark), ('MV-9', 2, ''));
      expect(ph.termsText, 'Per Hour – up to 1 hr ₹1000, after that ₹2000 · company diesel');
    });

    test('The BOQ print: the vendor\'s facts, the rates, signed by the vendor, billing and the PM', () {
      final d = boqDoc(boqs.first, vendors, boqs);
      expect(d.title, 'BOQ / Rate Contract – BOQ 1');
      expect(d.kpis.first, ('Vendor', 'Item Vendor'));
      expect(d.tables.first.rows.single.cells[4].text, 'Bucket – Per Hour ₹1,200\nBreaker – Per Hour ₹1,500');
      final html = reportHtml(d, company: 'Rachana Construction Limited', site: 'VTR', printed: '16-10-2026 12:00');
      expect(html, contains('PROJECT MANAGER'));
      expect(html, isNot(contains('Checked by')));
    });
  });

  group('BOQ print (3.24.0, Mechanical update-133)', () {
    final vs = [
      {'name': 'VP Vendor', 'address': 'At Post Lonad, Tal Bhiwandi', 'phone': '9800000133', 'pan': 'ABCDE1234J', 'gstReg': 'No', 'bank': 'HDFC Bank', 'account': '12345671', 'ifsc': 'HDFC0009218'},
    ];
    final l1 = {'no': 'VP-1', 'type': 'Water Tanker', 'basis': 'Per Trip', 'rate': 1000, 'diesel': 'Debit Basis'}, l2 = {'no': 'VP-2', 'type': 'Water Tanker', 'basis': 'Per Trip', 'rate': 500, 'diesel': 'Debit Basis'};
    final n1 = {'no': 'VP-1', 'type': 'Water Tanker', 'basis': 'Per Trip', 'rate': 1200, 'diesel': 'Debit Basis'};
    final b1 = <String, dynamic>{'id': 'BOQ-0038', 'no': '1', 'vendor': 'VP Vendor', 'from': '2026-08-01', 'to': '2026-08-31', 'amendOf': '', 'amendNo': 0, 'woNo': 'SLI/VTR-Office/WO/2024-2025/73', 'woDate': '2024-05-01', 'tdsPct': 2, 'lines': [l1, l2]};
    final a1 = <String, dynamic>{'id': 'BOQ-0039', 'no': '2', 'vendor': 'VP Vendor', 'from': '2026-09-01', 'to': '', 'amendOf': 'BOQ-0038', 'amendNo': 1, 'woNo': '', 'woDate': '', 'tdsPct': 2, 'lines': [n1]};
    final hist = [
      {'vendor': 'VP Vendor', 'no': 'VP-1', 'periods': [
        {'from': '2026-08-01', 'to': '2026-08-31', 'boq': 'BOQ-0038', 'boqNo': '1', 'amendNo': 0, 'of': '', 'line': l1},
        {'from': '2026-09-01', 'to': '', 'boq': 'BOQ-0039', 'boqNo': '2', 'amendNo': 1, 'of': '1', 'line': n1},
      ]},
      {'vendor': 'VP Vendor', 'no': 'VP-2', 'periods': [{'from': '2026-08-01', 'to': '2026-08-31', 'boq': 'BOQ-0038', 'boqNo': '1', 'amendNo': 0, 'of': '', 'line': l2}]},
    ];
    test('the work order number and date on top of a BOQ', () {
      final d = boqDoc(b1, vs, [b1, a1], hist: hist);
      expect(d.title, 'BOQ / Rate Contract – BOQ 1');
      expect(d.meta, 'BOQ ID: BOQ-0038 · Work Order No: SLI/VTR-Office/WO/2024-2025/73 · Work Order Date: 01-05-2024');
      expect(d.signs.first, ('VENDOR', 'SIGN & STAMP'));
      expect(d.onBehalf, false);
    });
    test('an amendment = an amendment letter: To, Subject, Reference (the work order of its BOQ), with effect from, the earlier and the new rate', () {
      final d = boqDoc(a1, vs, [b1, a1], hist: hist);
      expect(d.title, 'Amendment Letter – Amendment 1 of BOQ 1');
      expect(d.meta, 'BOQ ID: BOQ-0039 (BOQ 2) · Work Order No: SLI/VTR-Office/WO/2024-2025/73 · Work Order Date: 01-05-2024 · With effect from: 01-09-2026');
      expect(d.blocks.whereType<RNote>().where((x) => x.letter).map((x) => x.text).toList(), [
        'To,\nVP Vendor\nAt Post Lonad, Tal Bhiwandi\nContact No. 9800000133',
        'Subject: Amendment 1 of BOQ 1 – change of rate for 01 Nos Water Tanker.',
        'Reference: Work Order No. SLI/VTR-Office/WO/2024-2025/73 dated 01-05-2024; BOQ 1 (BOQ-0038) from 01-08-2026 to 31-08-2026.',
        'Dear Sir,\nWith reference to the above work order, we are changing the rate of the machinery given below (Annexure-I) with effect from 01-09-2026. The other machinery of BOQ 1 and all other terms and conditions remain the same.',
      ]);
      expect(d.tables.first.head[5], 'New rate from 01-09-2026');
      expect(d.tables.first.rows.single.cells.map((c) => c.text).toList(), ['1', 'VP-1', 'Water Tanker', 'Per Trip', '₹1,000 per trip\ntill 31-08-2026', '₹1,200 per trip', 'Debit basis', '']);
      expect(d.kpis, isEmpty, reason: 'the vendor\'s details go under the annexure');
      expect(d.tables[1].head, ['GST Number', 'PAN', 'TDS % (this BOQ)', 'Bank', 'Account No', 'IFSC']);
      expect(d.signs.first, ('ACCEPTED BY VENDOR', 'SIGN & STAMP'));
      final html = reportHtml(d, company: 'Sketchline Industries', site: 'VTR', printed: '19-10-2026 19:30');
      expect(html, contains('<p class="l">Subject: Amendment 1 of BOQ 1'));
      expect(html, contains('For and on behalf of SKETCHLINE INDUSTRIES.'));
      expect(boqDoc(a1, vs, [b1, a1]).tables.first.rows.single.cells[4].text, '–', reason: 'no rate history: no earlier rate said');
    });
  });

  group('Vehicle Compliance', () {
    final d = (fx('getCompliance') as Map).cast<String, dynamic>();
    test('The chips, the counts, the worst first; a paper\'s words', () {
      final base = cmpBase(d, '', '');
      expect(base.length, maps(d['machines']).length);
      final att = cmpRows(d, base, 'attention');
      expect(att.isNotEmpty, true);
      final n = cmpCounts(d, base);
      expect(n['missing'], greaterThan(0));
      expect(cmpBase(d, 'Own', '').every((m) => m['ownership'] == 'Own'), true);
      expect(cmpBase(d, 'Rental,Hired', '').every((m) => ['Rental', 'Hired'].contains(m['ownership'])), true);
      expect(cmpCellText({'s': 'expired', 'v': '2026-10-01', 'days': -13}), ('01-10-2026', 'expired 13 days ago'));
      expect(cmpCellText({'s': 'due', 'v': '2026-10-14', 'days': 0}), ('14-10-2026', 'expires today'));
      expect(cmpCellText({'s': 'notreq'}), ('—', 'not needed'));
      expect(cmpCellText({'s': 'life', 'v': 'LIFETIME'}).$1, 'Lifetime');
    });

    test('Export Excel: what is on the screen, the web\'s columns and its "How to fill" sheet', () {
      final rows = cmpRows(d, cmpBase(d, '', ''), 'all');
      final x = sheets(reportXlsx(complianceExportDoc(d, rows, '2026-10-16', 'All machinery'), const []));
      expect(x.keys, ['Compliance', 'How to fill']);
      expect(x['Compliance']!.first, 'Machinery No|Type|Ownership|Owner|Tax|PUC|Permit|Fitness|Insurance|Status (not imported)');
      expect(x['Compliance']!.length, rows.length + 1);
      expect(x['How to fill']!.last, contains('Filter: All machinery'));
    });
  });

  test('Log Book formats: A … I, a name given in the app', () {
    expect(kLbFormats.map((f) => f.id).join(), 'ABCDEFGHI');
    expect(lbName(kLbFormats[2], {'C': 'KM book'}), 'KM book');
    expect(lbName(kLbFormats[2], {}), 'Format C – KM');
  });
}
