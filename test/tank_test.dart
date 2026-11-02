/* (3.72.2, Mechanical update-199) THE MONTH-END TANK CHECK DECIDES THE DIESEL DEBIT – the app's bills and Log Book sheets against
 * the web's OWN code (App.html: mbFill / tankMonthEnd, billSheets, logSheetsBuild), run in the web page on the test rig on the same
 * data (test/fixtures/bill/web_tank.json, made by the scratch script u199/gen.js): a check missing (the bill says so, nothing
 * debited), found less (the shortage debited), the tank smaller than the system figure (above it debited), a final bill (all
 * debited), the next period's opening (the check of the day before), and a bill before 31-10-2026 (the last-fill rule as before). */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/bill.dart';
import 'package:rcl_mobile/core/lb_print.dart';

final fx = jsonDecode(File('test/fixtures/bill/web_tank.json').readAsStringSync()) as Map<String, dynamic>;

/// The first place two JSON values differ ('' = the same): numbers by value (2 = 2.0), a missing key = null.
String differ(Object? a, Object? b, [String at = r'$']) {
  if (a is num && b is num) return a == b ? '' : '$at: $a ≠ $b';
  if (a is Map && b is Map) {
    for (final k in {...a.keys, ...b.keys}) {
      final d = differ(a[k], b[k], '$at.$k');
      if (d.isNotEmpty) return d;
    }
    return '';
  }
  if (a is List && b is List) {
    if (a.length != b.length) return '$at: ${a.length} items ≠ ${b.length} items';
    for (var i = 0; i < a.length; i++) {
      final d = differ(a[i], b[i], '$at[$i]');
      if (d.isNotEmpty) return d;
    }
    return '';
  }
  return a == b ? '' : '$at: ${jsonEncode(a)} ≠ ${jsonEncode(b)}';
}

String diffAt(String a, String b) {
  if (a == b) return '';
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  final s = i > 120 ? i - 120 : 0;
  return 'at $i of ${a.length}/${b.length}:\n app: …${a.substring(s, (i + 120).clamp(0, a.length))}\n web: …${b.substring(s, (i + 120).clamp(0, b.length))}';
}

void main() {
  for (final c0 in fx['cases'] as List) {
    final c = (c0 as Map).cast<String, dynamic>(), a = c['args'] as Map;
    final master = {for (final m in (c['master'] as List).cast<Map<String, dynamic>>()) '${m['id']}'.toUpperCase(): m};
    Map<String, dynamic>? machine(String no) => master[no.toUpperCase()];
    final rows = [for (final r in c['rows'] as List) (r as Map).cast<String, dynamic>()];
    test('Tank check "${c['name']}" (${a['from']} – ${a['to']}): the same bill and papers as the web', () {
      final got = buildBills(
        init: c['init'] as Map,
        picked: {for (final e in (a['picked'] as Map).entries) '${e.key}': [for (final x in e.value as List) '$x']},
        per: '${a['per']}',
        from: '${a['from']}',
        to: '${a['to']}',
        company: '${a['company']}',
        billDate: '${a['billDate']}',
        logs: BillLogs(rows, '${a['from']}', '${a['to']}', c['extra'] as Map),
        machine: machine,
        round: false, // (the web's bills before update-202 – the fixture's)
      );
      final want = (c['bills'] as List).cast<Map<String, dynamic>>(), sheets = (c['sheets'] as List).cast<String>();
      expect(got.length, want.length);
      for (var i = 0; i < want.length; i++) {
        expect(differ(jsonDecode(jsonEncode(got[i])), want[i]), '', reason: 'bill ${i + 1}');
        expect(diffAt(billSheets(got[i], ''), sheets[i]), '', reason: 'papers of bill ${i + 1}');
      }
    });
    test('Tank check "${c['name']}": the Log Book sheets (the daily opening / closing, the tank check) the same as the web', () {
      final lb = c['lb'] as Map;
      final p = logBookPrint(rows: rows, from: '${a['from']}', to: '${a['to']}', head: '${lb['head']}', site: '${lb['site']}', extra: c['extra'] as Map, machine: machine, fmtF: '', sample: '', dieselRate: 0, idle: null);
      final s = p.html.indexOf('<div class="sheet">') + '<div class="sheet">'.length, e = p.html.lastIndexOf('</div></body>');
      expect(diffAt(p.html.substring(s, e), '${lb['sheets']}'), '');
      expect(p.title, lb['title']);
    });
  }

  test('the cases are what they say (the web\'s figures)', () {
    final by = {for (final c in (fx['cases'] as List).cast<Map<String, dynamic>>()) '${c['name']}': ((c['bills'] as List).first as Map)};
    Map tc(String n) => ((by[n]!['machines'] as List).first as Map)['tc'] as Map;
    expect([tc('missing')['missing'], tc('missing')['expect'], by['missing']!['B']], [true, 150, 0]);
    expect([tc('found')['found'], tc('found')['short'], by['found']!['B']], [110, 40, 4000]);
    expect([tc('over')['over'], tc('over')['short'], tc('over')['debit']], [50, 0, 50]);
    expect([tc('over_short')['over'], tc('over_short')['short'], tc('over_short')['debit']], [30, 10, 40]);
    expect([tc('final')['final'], tc('final')['debit']], [true, 150]);
    expect([tc('opening')['open'], tc('opening')['openDate'], tc('opening')['system'], tc('opening')['missing']], [110, '2026-10-31', 135, true]);
    expect(((by['before']!['machines'] as List).first as Map)['tc'], null);
  });

  test('the words of the check: the web\'s tcText', () {
    expect(tcText({'open': 0, 'openDate': '', 'issued': 469.3, 'std': 344, 'system': 125.3, 'cap': 220, 'over': 0, 'expect': 125.3, 'need': true, 'found': 80, 'foundDate': '2026-10-31', 'short': 45.3, 'missing': false, 'final': false}, '2026-10-31'),
        'opening 0 + issued 469.3 − standard 344 = 125.3 L; found 80 L in the tank on 31-10-2026 → 45.3 L short – debited');
  });
}
