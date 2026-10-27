/* (3.11.0) The Excel imports – proven against the web's own code:
 *   – web_read.json: what the web's library (SheetJS 0.18.5, the web's own copy) reads from each test file in fixtures/sheets
 *     (made as Excel and other tools write them: shared / rich / inline text, dates, formulas, errors, a range from B3, cells
 *     without a reference, two tabs, CSV with ; and tab, quotes, "2,000", 50 %, a UTF-8 mark …);
 *   – web_imports.json: what the web's own import code (App.html readInwardFile / readExcelRows / xlDate / impProblems /
 *     trProblems / diProblems / activeProblem …) makes of those files, row by row, with each row's problems.
 * Made by the scratchpad's fix.js / imp.js from the web's files (run in node). */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/imports.dart';
import 'package:rcl_mobile/core/sheet_read.dart';

const dir = 'test/fixtures/sheets';
final webRead = jsonDecode(File('$dir/web_read.json').readAsStringSync()) as Map<String, dynamic>;
final webImp = jsonDecode(File('$dir/web_imports.json').readAsStringSync()) as Map<String, dynamic>;
List<SheetTab> tabsOf(String f) => readSheets(Uint8List.fromList(File('$dir/$f').readAsBytesSync()));

/// The first place two JSON values differ ('' = the same): numbers by value, a text is not a number, '' is not null.
String differ(Object? a, Object? b, [String at = r'$']) {
  if (a is num && b is num) return a == b ? '' : '$at: $a ≠ $b';
  if (a is Map && b is Map) {
    for (final k in {...a.keys, ...b.keys}) {
      if (a.containsKey(k) != b.containsKey(k)) return '$at.$k: only on one side';
      final d = differ(a[k], b[k], '$at.$k');
      if (d.isNotEmpty) return d;
    }
    return '';
  }
  if (a is List && b is List) {
    if (a.length != b.length) return '$at: ${a.length} items ≠ ${b.length} items (${jsonEncode(a)} ≠ ${jsonEncode(b)})';
    for (var i = 0; i < a.length; i++) {
      final d = differ(a[i], b[i], '$at[$i]');
      if (d.isNotEmpty) return d;
    }
    return '';
  }
  return a == b ? '' : '$at: ${jsonEncode(a)} ≠ ${jsonEncode(b)}';
}

void main() {
  final today = '${webImp['S']['today']}';
  final locs = [for (final l in webImp['S']['locations'] as List) '$l'];
  final master = [for (final m in webImp['S']['master'] as List) (m as Map).cast<String, dynamic>()];

  test('Each test file is read as the web\'s library reads it – every tab, every row, every cell', () {
    for (final f in webRead.keys) {
      final mine = [for (final t in tabsOf(f)) {'name': t.name, 'rows': t.rows}];
      Object? want = webRead[f];
      if (f == 'csv_dates.csv') {
        // the one difference, on purpose: a date in a CSV stays as written. The web's reader lets the browser guess it –
        // 05/10/2026 became 10 May and 10-11-2026 became 11 Oct (Excel day numbers in its result) – a web bug, reported.
        final w = (want as List).first['rows'] as List;
        expect([w[1][2], w[2][0], w[2][2]], everyElement(isA<num>()));
        want = [
          {
            'name': 'Sheet1',
            'rows': [
              ['Date', 'Qty', 'Bill Date'],
              ['16-10-2026', 10, '05/10/2026'],
              ['2026-10-05', 20, '10-11-2026'],
            ],
          },
        ];
      }
      expect(differ(mine, want), '', reason: f);
    }
  });

  test('An old .xls file is refused with what to do', () {
    final xls = Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0, 0]);
    expect(() => readSheets(xls), throwsA(isA<SheetError>().having((e) => e.message, 'message', contains('.xlsx'))));
  });

  test('Excel dates: a day number (with its time) and the typed dates – as the web\'s xlDate', () {
    expect([xlDate(46311), xlDate(46311.75), xlDate(46311.99999999), xlDate(60), xlDate(61), xlDate(0), xlDate(-1)],
        ['2026-10-16', '2026-10-16', '2026-10-16', '1900-02-29', '1900-03-01', '1900-01-00', '-1']);
    expect([xlDate('16-10-2026'), xlDate('5/10/26'), xlDate('2026-10-5'), xlDate(' 2026.10.05 '), xlDate(''), xlDate(true), xlDate('Oct 5')],
        ['2026-10-16', '2026-10-05', '2026-10-05', '2026-10-05', '', 'true', 'Oct 5']);
  });

  test('Diesel Inward: each file\'s rows and their problems – as the web\'s readInwardFile and impProblems', () {
    for (final e in (webImp['inward'] as Map).entries) {
      final f = e.key as String;
      if (e.value is Map) {
        expect(() => readInward(tabsOf(f), locs), throwsA(isA<SheetError>().having((x) => x.message, 'message', (e.value as Map)['error'])), reason: f);
        continue;
      }
      final want = [for (final x in e.value as List) Map<String, dynamic>.of((x as Map).cast<String, dynamic>())];
      if (f == 'csv_dates.csv') {
        // the bill dates as written in the CSV (see above): the web took them as 10 May and 11 Oct
        expect([want[0]['row']['billDate'], want[1]['row']['billDate']], ['2026-05-10', '2026-10-11']);
        want[0]['row'] = {...want[0]['row'] as Map, 'billDate': '2026-10-05'};
        want[1]['row'] = {...want[1]['row'] as Map, 'billDate': '2026-11-10'};
      }
      final mine = [for (final r in readInward(tabsOf(f), locs)) {'row': r, 'problems': inwardProblems(r, today, locs)}];
      expect(differ(mine, want), '', reason: f);
    }
  });

  test('Diesel Transfer: each file\'s rows and their problems – as the web\'s readExcelRows, locName, shiftName, trProblems', () {
    for (final e in (webImp['transfer'] as Map).entries) {
      final f = e.key as String;
      final mine = [for (final r in transferRows(tabsOf(f), locs)) {'row': r, 'problems': transferProblems(r, today, locs)}];
      expect(differ(mine, e.value), '', reason: f);
    }
  });

  test('Diesel Issue: each file\'s rows (machinery found in Master, not on site …) – as the web\'s d_file and diProblems', () {
    for (final e in (webImp['diesel'] as Map).entries) {
      final f = e.key as String;
      if (e.value is Map) {
        expect(() => issueRows(tabsOf(f), locs, master), throwsA(isA<SheetError>().having((x) => x.message, 'message', (e.value as Map)['error'])), reason: f);
        continue;
      }
      final mine = [for (final r in issueRows(tabsOf(f), locs, master)) {'row': r, 'problems': issueProblems(r, today, locs, master)}];
      expect(differ(mine, e.value), '', reason: f);
    }
  });

  test('A machinery on site on a date – the web\'s activeProblem, word for word', () {
    for (final a in webImp['active'] as List) {
      final m = findMachine(master, a[0]);
      expect(activeProblem(m, '${a[1]}'), a[2], reason: '${a[0]} ${a[1]}');
    }
    expect(findMachine(master, 'mh 25 aj 3232')?['id'], 'MH-25-AJ-3232');
    expect(findMachine(master, ''), isNull);
  });

  test('The templates: the web\'s headings and example rows; a row is sent without NaN', () {
    final t = importTemplate('issue', today, locs, ['MH-25-AJ-3232']);
    expect(t.rows.first, ['Date', 'Shift', 'Diesel Source', 'Machinery Number / Name', 'Diesel Qty (Ltr)', 'KM Reading', 'Hrs Reading', 'Driver Name', 'Remark']);
    expect(t.rows[1], ['16-10-2026', 'Day', 'Dispenser', 'MH-25-AJ-3232', 60, '', '', '', '']);
    expect(t.rows[2].take(4), ['16-10-2026', 'Night', 'VTR Store', '400 KVA DG']);
    expect(importTemplate('transfer', today, locs, const []).rows[2], ['16-10-2026', 'Night', 'Dispenser', 'VTR Store', 300, 'For night work']);
    expect(importTemplate('inward', today, locs, const []).file, 'Diesel Inward – import template');
    expect(sendable({'qty': double.nan, 'line': '2', '_has': {}}), {'qty': null, 'line': '2'});
    expect(exportPeriod('', '', today), 'till 16-10-2026');
    expect(exportPeriod('2026-10-01', '', today), '01-10-2026 to 16-10-2026');
  });

  test('JavaScript\'s numbers and text, as the web\'s code uses them', () {
    expect([jsNumber('2000'), jsNumber(' 1e3 '), jsNumber('5.'), jsNumber('.5'), jsNumber('-.5'), jsNumber('0x10'), jsNumber('')], [2000, 1000, 5, .5, -.5, 16, 0]);
    expect([jsNumber('1,000').isNaN, jsNumber('-0x10').isNaN, jsNumber('abc').isNaN, jsNumber('Infinity').isInfinite], [true, true, true, true]);
    expect([fuzzyNum('1,250.5'), fuzzyNum(r'$1,234'), fuzzyNum('50%'), fuzzyNum('(100)'), fuzzyNum(' Infinity').isNaN], [1250.5, 1234, .5, -100, true]);
    expect([jsS(2000.0), jsS(92.5), jsS(1e21), jsS(0.0000001), jsS(true), jsS(null), jsS(12345678901234567.0)], ['2000', '92.5', '1e+21', '1e-7', 'true', 'null', '12345678901234568']);
    expect([jsTrue(0), jsTrue(''), jsTrue(double.nan), jsTrue('0'), jsTrue(false), jsTrue(null)], [false, false, false, true, false, false]);
    expect([jsParseFloat('12abc'), jsParseFloat(' -3.5e2x')], [12, -350]);
    expect(jsParseFloat('abc').isNaN, true);
  });

  test('(3.43.0, Mechanical update-162) his diesel sources: the web\'s diProblems / trProblems say "not your diesel source"; a blank source = his first', () {
    const locs = ['CAMP PUMP', 'DISPENSER - MH12ZE-1739', 'DISPENSER - MH12WJ-1381'], ze = 'DISPENSER - MH12ZE-1739';
    final master = [<String, dynamic>{'id': 'TP-1', 'name': 'Tipper', 'status': 'Active', 'activeFrom': '2026-01-01'}];
    Map<String, Object?> iss(String src) => {'line': 1, 'date': '2026-10-14', 'shift': 'Day', 'source': src, 'no': 'TP-1', 'qty': 10};
    expect(issueProblems(iss('CAMP PUMP'), '2026-10-14', locs, master), isNot(contains('Diesel Source – not your diesel source')), reason: 'nothing chosen: every place');
    expect(issueProblems(iss('CAMP PUMP'), '2026-10-14', locs, master, mine: [ze]), contains('Diesel Source – not your diesel source'));
    expect(issueProblems(iss(ze), '2026-10-14', locs, master, mine: [ze]).where((p) => p.startsWith('Diesel Source')), isEmpty);
    expect(issueProblems(iss('NOWHERE'), '2026-10-14', locs, master, mine: [ze]), contains('Diesel Source'), reason: 'not a place at all: as before');
    Map<String, Object?> tr(String f, String t) => {'line': 1, 'date': '2026-10-14', 'shift': 'Day', 'from': f, 'to': t, 'qty': 10};
    expect(transferProblems(tr('CAMP PUMP', ze), '2026-10-14', locs, mine: [ze]), ['From – not your diesel source']);
    expect(transferProblems(tr(ze, 'CAMP PUMP'), '2026-10-14', locs, mine: [ze]), isEmpty, reason: 'to any place');
    expect(transferProblems(tr('CAMP PUMP', ze), '2026-10-14', locs), isEmpty, reason: 'nothing chosen: every place');
  });

  test('(3.44.0, Mechanical update-163) fuel: an Excel row from a place of another fuel is marked (the web\'s diProblems / trProblems); a blank source = the first place of the car\'s fuel; a site without fuels as before', () {
    const locs = ['DIESEL CARD', 'PETROL CARD', 'PETROL CAN', 'CNG CARD'];
    const fuels = {'DIESEL CARD': 'Diesel', 'PETROL CARD': 'Petrol', 'PETROL CAN': 'Petrol', 'CNG CARD': 'CNG'};
    final master = [
      <String, dynamic>{'id': 'MH-12-HO-1163', 'status': 'Active', 'fuel': 'Petrol'},
      <String, dynamic>{'id': 'MH-12-HO-3163', 'status': 'Active', 'fuel': 'Electric'},
      <String, dynamic>{'id': 'TP-1', 'status': 'Active'},
    ];
    Map<String, Object?> iss(String no, String src) => {'line': 1, 'date': '2026-10-14', 'shift': 'Day', 'source': src, 'no': no, 'qty': 10};
    expect(issueProblems(iss('MH-12-HO-1163', 'DIESEL CARD'), '2026-10-14', locs, master, fuels: fuels), ['runs on Petrol – not at DIESEL CARD']);
    expect(issueProblems(iss('MH-12-HO-1163', 'PETROL CAN'), '2026-10-14', locs, master, fuels: fuels), isEmpty);
    expect(issueProblems(iss('MH-12-HO-3163', 'PETROL CARD'), '2026-10-14', locs, master, fuels: fuels), ['runs on Electric – no fuel']);
    expect(issueProblems(iss('TP-1', 'DIESEL CARD'), '2026-10-14', locs, master, fuels: fuels), isEmpty, reason: 'no fuel in the Master = Diesel');
    expect(issueProblems(iss('MH-12-HO-1163', 'DIESEL CARD'), '2026-10-14', locs, master), isEmpty, reason: 'no fuels given (a site of Diesel only): as before');
    Map<String, Object?> tr(String f, String t) => {'line': 1, 'date': '2026-10-14', 'shift': 'Day', 'from': f, 'to': t, 'qty': 10};
    expect(transferProblems(tr('PETROL CARD', 'DIESEL CARD'), '2026-10-14', locs, fuels: fuels), ['From Petrol, To Diesel – not the same fuel']);
    expect(transferProblems(tr('PETROL CARD', 'PETROL CAN'), '2026-10-14', locs, fuels: fuels), isEmpty);
    expect(transferProblems(tr('PETROL CARD', 'DIESEL CARD'), '2026-10-14', locs), isEmpty, reason: 'as before');
    final rows = issueRows([SheetTab('Diesel Issue', [
      ['Date', 'Shift', 'Diesel Source', 'Machinery Number / Name', 'Diesel Qty (Ltr)'],
      ['14/10/2026', 'Day', '', 'MH-12-HO-1163', 30],
      ['14/10/2026', 'Day', '', 'TP-1', 40],
    ])], locs, master, fuels: fuels);
    expect([rows[0]['source'], rows[1]['source']], ['PETROL CARD', 'DIESEL CARD'], reason: 'a blank source: the first place of its fuel');
  });
}
