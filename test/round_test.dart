/* (3.75.0, Mechanical update-202) A BILL IN WHOLE RUPEES – the app's bills, papers and Log Book sheets against the web's OWN code
 * (App.html: mbFill / mbTotals, billSheets, logSheetsBuild with the bill's own figures), run in the web page on the rig on the same
 * data (test/fixtures/bill/web_round.json, made by the scratch script u202/app/gen.js): every line, the diesel debit, GST and TDS in
 * rupees (below 50 paise down, 50 paise and above up), the totals add up; the Abstract without "Checked By – Billing Dept" and with
 * the Head Office (Checked By, then Verified By – HO Accounts); an other deduction typed with paise. A bill before keeps its own
 * (bill_test / tank_test: round: false). */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/bill.dart';
import 'package:rcl_mobile/core/lb_print.dart';

final fx = jsonDecode(File('test/fixtures/bill/web_round.json').readAsStringSync()) as Map<String, dynamic>;

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
  test('the rule: 12.3 → 12, 122.6 → 123, .5 up, a minus amount the same way from 0; an amount of a bill in rupees without paise', () {
    expect([12.3, 122.6, 122.5, 102712.5, 0.49, 1140.7695, -12.5, -12.4, 15557.58].map(r0).toList(), [12, 123, 123, 102713, 0, 1141, -13, -12, 15558]);
    expect([mbA({'round': true}, 174003), mbA({'round': true}, 2767), mbA({}, 174003), mbA({'round': true}, 1500.5), mbA(null, 9)], ['1,74,003', '2,767', '1,74,003.00', '1,500.50', '9.00']);
  });

  for (final c0 in fx['cases'] as List) {
    final c = (c0 as Map).cast<String, dynamic>(), a = c['args'] as Map, more = c['more'] as Map?;
    final master = {for (final m in (c['master'] as List).cast<Map<String, dynamic>>()) '${m['id']}'.toUpperCase(): m};
    Map<String, dynamic>? machine(String no) => master[no.toUpperCase()];
    final rows = [for (final r in c['rows'] as List) (r as Map).cast<String, dynamic>()];
    test('Whole rupees "${c['name']}" (${a['from']} – ${a['to']}): the same bill and papers as the web', () {
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
      );
      if (more != null) {
        got[0]['C'] = more['C'];
        got[0]['cReason'] = more['cReason'];
        mbTotals(got[0]);
      }
      final want = (c['bills'] as List).cast<Map<String, dynamic>>(), sheets = (c['sheets'] as List).cast<String>();
      expect(got.length, want.length);
      for (var i = 0; i < want.length; i++) {
        expect(differ(jsonDecode(jsonEncode(got[i])), want[i]), '', reason: 'bill ${i + 1}');
        expect(diffAt(billSheets(got[i], ''), sheets[i]), '', reason: 'papers of bill ${i + 1}');
      }
      final lb = c['lb'] as Map, fg = lbFig(got);
      expect([fg.round, differ(jsonDecode(jsonEncode(fg.figBy)), lb['figBy'])], [true, '']);
      final p = logBookPrint(rows: rows, from: '${a['from']}', to: '${a['to']}', head: '${lb['head']}', site: '${lb['site']}', extra: c['extra'] as Map, machine: machine, fmtF: '', sample: '', dieselRate: 0, idle: null, round: fg.round, figBy: fg.figBy);
      final s = p.html.indexOf('<div class="sheet">') + '<div class="sheet">'.length, e = p.html.lastIndexOf('</div></body>');
      expect(diffAt(p.html.substring(s, e), '${lb['sheets']}'), '', reason: 'the Log Book sheets of the bill');
    });
  }

  test('the cases are what they say (the bill he was shown, 02-11-2026)', () {
    final by = {for (final c in (fx['cases'] as List).cast<Map<String, dynamic>>()) '${c['name']}': ((c['bills'] as List).first as Map)};
    List<Object?> fig(String n) => [for (final k in ['A', 'B', 'C', 'D', 'E', 'G', 'H', 'I', 'round']) by[n]![k]];
    expect(fig('round'), [174003, 2767, 0, 171236, 15411, 202058, 1712, 200346, true]);
    expect(fig('round_c'), [174003, 2767, 251, 170985, 15389, 201763, 1710, 200053, true]);
    final sheet = '${((fx['cases'] as List).first as Map)['sheets'][0]}';
    expect(sheet.contains('Billing Dept'), false);
    expect(sheet.contains('<div class="bl-ho"><div class="bl-ho-t">HEAD OFFICE</div><div><span></span><b>Checked By</b><small>HO Accounts</small></div><div><span></span><b>Verified By</b><small>HO Accounts</small></div></div>'), true);
  });
}
