/* (3.8.0) Machinery Billing – the app's bills against the web's OWN billing code (App.html "MACHINERY BILLING", run as it is
 * in node on the same data – test/fixtures/bill/web_bills.json, made by the scratch script billgen.js): the bills built for a
 * period (one per vendor or one per machinery, the bill numbers), every machinery's lines and diesel, the warnings, A – K, and the
 * papers to the character (Abstract of Bill, Tax Invoice, GST declaration, Debit Note, a saved debit / credit note), and the
 * amount in words. The data: the recorded test site and made-up machinery that go through every rule. */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/bill.dart';

final fx = jsonDecode(File('test/fixtures/bill/web_bills.json').readAsStringSync()) as Map<String, dynamic>;
final master = {for (final m in (fx['master'] as List).cast<Map<String, dynamic>>()) '${m['id']}'.toUpperCase(): m};
Map<String, dynamic>? machine(String no) => master[no.toUpperCase()];

BillLogs logsOf(String from, String to) {
  final p = (fx['periods'] as Map)['$from|$to'] as Map;
  return BillLogs((p['rows'] as List).cast<Map<String, dynamic>>(), from, to, p['extra'] as Map);
}

Map<String, dynamic> copy(Object? m) => (jsonDecode(jsonEncode(m)) as Map).cast<String, dynamic>();

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
    if (a.length != b.length) return '$at: ${a.length} items ≠ ${b.length} items (${jsonEncode(a)} ≠ ${jsonEncode(b)})';
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
  final builds = (fx['builds'] as List).cast<Map<String, dynamic>>();
  for (var n = 0; n < builds.length; n++) {
    final c = builds[n], a = c['args'] as Map;
    test('Build bills ${n + 1}: ${a['from']} – ${a['to']}, ${a['company']}, one bill per ${a['per']} – the same bills and papers as the web', () {
      final got = buildBills(
        init: fx['init'] as Map,
        picked: {for (final e in (a['picked'] as Map).entries) '${e.key}': [for (final x in e.value as List) '$x']},
        per: '${a['per']}',
        from: '${a['from']}',
        to: '${a['to']}',
        company: '${a['company']}',
        billDate: '${a['billDate']}',
        logs: logsOf('${a['from']}', '${a['to']}'),
        machine: machine,
      );
      final want = (c['bills'] as List).cast<Map<String, dynamic>>(), sheets = (c['sheets'] as List).cast<String>();
      expect(got.length, want.length);
      for (var i = 0; i < want.length; i++) {
        final d = differ(jsonDecode(jsonEncode(got[i])), want[i]);
        expect(d, '', reason: 'bill ${i + 1} (${want[i]['vendor']['name']})');
        final h = billSheets(got[i], '');
        expect(diffAt(h, sheets[i]), '', reason: 'papers of bill ${i + 1} (${want[i]['vendor']['name']})');
      }
    });
    // (3.20.0, Mechanical update-124) a new bill is marked (its Tax Invoice: the month, the amount after the diesel debit); the
    // same bill WITHOUT the mark – a bill made before, opened from RCL Drive – keeps its papers as they were (the web's, as they were)
    test('Build bills ${n + 1}: a bill made before (no mark) – its papers as they were, the same as the web\'s', () {
      final want = (c['bills'] as List).cast<Map<String, dynamic>>(), old = (c['old'] as List).cast<String>();
      for (var i = 0; i < want.length; i++) {
        expect(want[i]['txNet'], true, reason: 'the web marks a bill it builds');
        final b = copy(want[i])..remove('txNet');
        expect(diffAt(billSheets(b, ''), old[i]), '', reason: 'old papers of bill ${i + 1} (${want[i]['vendor']['name']})');
      }
    });
  }

  test('(3.20.0) the month of a bill on its Tax Invoice – a whole month by its name, else the dates (the web\'s txPeriod)', () {
    expect([
      for (final p in [
        ['2026-09-01', '2026-09-30'], ['2026-02-01', '2026-02-28'], ['2028-02-01', '2028-02-28'], ['2028-02-01', '2028-02-29'],
        ['2026-09-01', '2026-09-15'], ['2026-09-20', '2026-10-10'], ['2026-12-01', '2026-12-31'],
      ])
        txPeriod({'from': p[0], 'to': p[1]})
    ], [
      'FOR THE MONTH OF SEPTEMBER 2026', 'FOR THE MONTH OF FEBRUARY 2026', 'FOR THE PERIOD 01.02.2028 TO 28.02.2028', 'FOR THE MONTH OF FEBRUARY 2028',
      'FOR THE PERIOD 01.09.2026 TO 15.09.2026', 'FOR THE PERIOD 20.09.2026 TO 10.10.2026', 'FOR THE MONTH OF DECEMBER 2026',
    ]);
  });

  test('A built bill changed: Idle paid / not paid, a typed diesel rate, an other deduction, debit notes, corrections of earlier bills, a saved bill, a minus bill', () {
    final l = logsOf('2026-09-20', '2026-10-10');
    for (final c in (fx['refills'] as List).cast<Map<String, dynamic>>()) {
      final got = mbFill(copy(c['input']), l, machine);
      expect(differ(jsonDecode(jsonEncode(got)), c['bill']), '', reason: '${c['name']}');
      expect(diffAt(billSheets(got, ''), '${c['sheets']}'), '', reason: '${c['name']}: papers');
      expect(diffAt(debitNoteHtml(got), '${c['dn']}'), '', reason: '${c['name']}: debit note');
      expect(diffAt(gstDeclHtml(got), '${c['gd']}'), '', reason: '${c['name']}: GST declaration');
    }
  });

  test('A saved debit note / credit note as printed, and the amount in words', () {
    for (final c in (fx['notes'] as List).cast<Map<String, dynamic>>()) {
      expect(diffAt(debitNoteDocHtml(c['note'] as Map), '${c['html']}'), '', reason: '${(c['note'] as Map)['no']}');
    }
    for (final w in (fx['words'] as List).cast<List>()) {
      expect(rupeesWords(w[0] as num), w[1], reason: '${w[0]}');
    }
  });

  // (3.32.0 – the web's update-151) the note above a saved bill's Log Book: the web's billLogOf text, character for character
  // (test/fixtures/bill/web_ev_notes.json – made by running App.html's billLogOf in node on these getBillEvidence answers)
  final evCases = jsonDecode(File('test/fixtures/bill/web_ev_notes.json').readAsStringSync()) as List;
  for (final c0 in evCases) {
    final c = (c0 as Map).cast<String, dynamic>();
    test('(3.32.0) a saved bill\'s Log Book note "${c['name']}" – the same as the web', () {
      expect(evNoteHtml(c['b'] as Map, c['ev'] as Map?, DateTime.parse('${c['now']}')), c['note']);
    });
  }
  test('(3.32.0) the time of submission (kept in UTC by the database) is shown in the phone\'s time', () {
    final t = DateTime.parse('2026-10-05T08:37:31Z').toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final h = evNoteHtml({'billNo': '7'}, {'kind': 'submission', 'billNoThen': '7', 'submittedAt': '2026-10-05T08:37:31.120+00:00', 'count': 2, 'hash': 'ab', 'check': {'ok': true}}, DateTime(2026, 10, 24));
    expect(h, '<div class="ev-note">Log Book as submitted with RA Bill 7 on ${two(t.day)}-${two(t.month)}-${t.year} ${two(t.hour)}:${two(t.minute)} – kept with the bill, never changed afterwards. Evidence check ✔ (2 entries, SHA-256 ab…).</div>');
  });

  test('The bill print page: the papers on A4 under the company name, the Log Book after them', () {
    final h = billPrintHtml('Bill preview', '<section class="billsheet draft">x</section>', withLb: true, foot: 'Sketchline Industries');
    expect(h, contains('<body class="rep rep-bill rep-lb"><div class="sheet"><section class="billsheet draft">x</section></div>'));
    expect(h, contains('@bottom-left { content: "SKETCHLINE INDUSTRIES  |  Fleet ERP"; }'));
    expect(billPrintHtml('Bill', '', foot: 'Rachana Construction Limited'), contains('content: "Rachana Construction Limited  |  Fleet ERP"'));
  });
}
