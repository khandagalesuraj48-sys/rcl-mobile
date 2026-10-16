/* (3.5.0) The Dashboard's and Tank Check's rules as the web works them out – from the real answers of the test server
 * (test/fixtures/dash: getDashboard, getStockLedger, logDashboard, pendingLog …; user names replaced). */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/dash.dart';
import 'package:rcl_mobile/screens/tank_check.dart' show tankFound, tankDiff;

dynamic fx(String n) => jsonDecode(File('test/fixtures/dash/$n.json').readAsStringSync());
Map<String, dynamic> mfx(String n) => (fx(n) as Map).cast<String, dynamic>();

void main() {
  test('The dates: the quick ranges, which one is on, the words', () {
    expect(dashRange('today', '2026-10-16'), ('2026-10-16', '2026-10-16'));
    expect(dashRange('yesterday', '2026-10-01'), ('2026-09-30', '2026-09-30'));
    expect(dashRange('month', '2026-10-16'), ('2026-10-01', '2026-10-16'));
    expect(dashRange('lastmonth', '2026-01-10'), ('2025-12-01', '2025-12-31'));
    expect(dashRange('all', '2026-10-16'), ('', ''));
    expect(dashWhich('2026-10-01', '2026-10-16', '2026-10-16'), 'month');
    expect(dashWhich('2026-10-02', '2026-10-16', '2026-10-16'), '');
    expect(rangeText('', ''), 'All dates');
    expect(rangeText('2026-10-01', '2026-10-01'), '01-10-2026');
    expect(rangeText('2026-10-01', ''), 'From 01-10-2026');
    expect(lbRange('7', '2026-10-16'), ('2026-10-10', '2026-10-16'));
  });

  test('The stock of each place and combined – each adds up (Opening + Received − Sent − Issued = Closing)', () {
    final d = mfx('getDashboard');
    final cards = locationCards(mapsOf(d['locations']), '2026-10-01', '2026-10-16', ['Dispenser', 'VTR Store']);
    expect(cards.map((c) => c.title), ['Combined – all locations', 'Dispenser', 'VTR Store']);
    expect(cards.every((c) => c.ok), true);
    expect(cards.first.lines.first, ('Opening stock on 01-10-2026', 19895, ''));
    expect(cards.first.lines[3], ('= Closing stock on 16-10-2026', 20014, 'tot'));
    expect(cards.first.lines.last.$1, startsWith('Moved Dispenser ↔ VTR Store'));
    expect(cards[1].lines[2].$1, '+ Received from VTR Store');
    final bad = locationCards([{'loc': 'X', 'opening': 10, 'inward': 5, 'issued': 1, 'closing': 99, 'current': 0}], '', '', ['X']);
    expect(bad[1].ok, false);
    expect(bad[1].check, 'Does not add up: 14 vs 99');
  });

  test('The day-wise stock: newest first, the whole period at the foot; a place has its transfers', () {
    final l = mfx('getStockLedger');
    final all = ledgerTable(l, '', ['Dispenser', 'VTR Store']);
    expect(all.head, ['Date', 'Opening stock', '+ Received from pump', '− Issued to machinery', 'Closing stock']);
    expect(all.rows.first.cells.first.text, '16-10-2026');
    expect(all.foot.single.cells.map((c) => c.text).toList(), ['Whole period', '19,895', '121', '2', '20,014']);
    final one = ledgerTable(l, 'Dispenser', ['Dispenser', 'VTR Store']);
    expect(one.head, contains('+ Received from VTR Store'));
    expect(ledgerHelp('', ['Dispenser', 'VTR Store']), contains('Dispenser and VTR Store'));
  });

  test('A tank: how full, low below the level', () {
    final t = tankOf({'Dispenser': 800}, {'caps': {'Dispenser': 10000}, 'low': 1000}, 'Dispenser', 0);
    expect((t.qty, t.cap, t.low, t.chip), (800, 10000, true, 'Low stock'));
    expect(t.note, 'Below 1,000 Ltr – refill soon');
    expect(tankOf({'VTR Store': 1500}, {'caps': {}, 'low': 1000}, 'VTR Store', 1).cap, 2000, reason: 'no size set: the store holds 2,000 (as the web)');
    expect(tankOf({'VTR Store': 1500}, {'caps': {}, 'low': 1000}, 'VTR Store', 1).chip, 'Good');
  });

  test('The Log Book dashboard: status, the chips, the most used first; compared with the days before', () {
    final d = mfx('logDashboard');
    final all = lbMachines(d, 'all');
    expect(all.length, 48);
    expect(all.first['no'], 'EX-200');
    expect(lbMachines(d, 'idle').length, 48);
    expect(lbMachines(d, 'diesel'), isEmpty);
    expect(lbStatus({'workDays': 0}).$2, 'No work');
    expect(lbStatus({'workDays': 3, 'idleFor': 4}).$2, 'Idle 4 days');
    expect(lbStatus({'workDays': 3, 'idleFor': 1}).$2, 'Working');
    expect(lbCmp(0.26, 0.91, true), ('▼ 71% vs the period before', false));
    expect(lbCmp(5, 0, true).$1, '');
    expect(lbWork({'hrs': 16, 'km': 0, 'trips': 2}, ' · '), '16 hrs · 2 trips');
  });

  test('Pending Log Book: one card per machinery, the oldest first; the chips count the days by age', () {
    final p = mfx('pendingLog');
    final r = pendingCards(p, ownOf: (_) => 'Own');
    expect(r.counts, {'all': 126, 'today': 8, 'd1': 8, 'd7': 48, 'old': 62});
    expect(r.cards.length, 8);
    expect((r.cards.first.no, r.cards.first.dates.first, r.cards.first.dates.length), ('MH-15-AB-0001', '2026-10-01', 16));
    expect(pendingCards(p, chip: 'today', ownOf: (_) => 'Own').cards.every((c) => c.oldest == 0), true);
    expect(pendingCards(p, own: 'Rental,Hired', ownOf: (_) => 'Own').counts['all'], 0, reason: 'ownership of Asset Master');
    expect(pendingCards(p, q: 'ex-200', ownOf: (_) => 'Own').cards.single.no, 'EX-200');
  });

  test('Own vehicle papers: expired and due within 30 days, the soonest first', () {
    final l = ownPapersDue({
      'docs': ['Tax', 'PUC'],
      'machines': [
        {'no': 'A', 'type': 'Tipper', 'ownership': 'Own', 'docs': {'Tax': {'s': 'due', 'v': '2026-10-20', 'days': 4}, 'PUC': {'s': 'expired', 'v': '2026-10-01', 'days': -15}}},
        {'no': 'B', 'type': 'Tipper', 'ownership': 'Rental', 'docs': {'Tax': {'s': 'expired', 'v': '2026-09-01', 'days': -45}}},
      ],
    });
    expect(l.map((x) => '${x['no']} ${x['doc']}'), ['A PUC', 'A Tax']);
  });

  test('The ownership list\'s print and the Daily report', () {
    final o = ownershipDoc({'ownership': 'Own', 'from': '2026-10-01', 'to': '2026-10-16', 'rows': [{'no': 'A', 'type': 'Tipper', 'owner': 'RCL', 'entries': 2, 'first': '2026-10-02', 'last': '2026-10-05', 'qty': 40}], 'total': {'qty': 40, 'entries': 2}});
    expect(o.title, 'Diesel Issue Report – Own');
    expect(o.tables.single.foot.single.cells.last.text, '40 Ltr');
    final html = dailyReportHtml(
      day: '2026-10-16', company: 'Rachana Construction Limited', site: 'VTR', madeAt: '16-10-2026 12:00', madeBy: 'Tester',
      dash: mfx('getDashboard'),
      issues: [{'no': 'MH-15-AB-0002', 'type': 'Tipper', 'qty': 2, 'shift': 'Day', 'source': 'Dispenser', 'kmReading': 1200, 'hrReading': ''}],
      inwards: [{'location': 'Dispenser', 'pump': 'IOC', 'billNo': 'B1', 'qty': 22, 'rate': 90, 'amount': 1980}],
      logs: [{'no': 'EX-200', 'shift': 'Full Day', 'mode': 'Hrs', 'ohr': 1000, 'chr': 1008, 'whr': 8, 'qty': 0, 'work': 'Excavation', 'itemQty': [{'n': 'Bucket', 'k': 'hr', 'q': 8}]}],
      breakdowns: const {},
      activeMachines: [{'id': 'EX-200'}, {'id': 'MH-15-AB-0001'}],
    );
    expect(html, contains('Rachana Construction Limited – Daily Report'));
    expect(html, contains('Diesel issued but no Log Book entry (1):</b> MH-15-AB-0002'));
    expect(html, contains('Active machinery without a Log Book entry (1 of 2):</b> MH-15-AB-0001'));
    expect(html, contains('1,000 → 1,008'));
    expect(html, contains('<b>Bucket 8 hr</b> Excavation'));
    expect(html, contains('worked 1 · idle 0 · holiday 0 · breakdown 0'));
  });

  test('Tank check: what was found, measured or by filling to full; the difference and when to ask why', () {
    expect(tankFound('measure', 400, '150', ''), 150);
    expect(tankFound('full', 400, '', '250'), 150);
    expect(tankFound('full', 0, '', '250'), isNull, reason: 'no tank size');
    expect(tankFound('measure', 400, '', ''), isNull);
    expect(tankDiff(150, 200), (-50, 'Less than the system (−25%) – ask why', true));
    expect(tankDiff(204, 200).$3, false, reason: 'within 10% / 5 L');
    expect(tankDiff(200, 200).$2, 'Matches the system');
  });
}
