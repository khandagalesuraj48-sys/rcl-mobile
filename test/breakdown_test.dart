/* (3.7.0) Breakdown – the daily machinery status and the period report as the web works them out (App.html "BREAKDOWN"), from an
 * answer shaped as the server's getBreakdowns (a breakdown carried from the last saved day, the history of breakdown runs). */
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/breakdown.dart';

final master = <Map<String, dynamic>>[
  {'id': 'Sany 210 (No.1)', 'name': 'Sany 210', 'type': 'Excavator', 'owner': 'RCL', 'ownership': 'Own', 'status': 'Active', 'activeFrom': '2026-09-01', 'inactiveFrom': '', 'earlier': []},
  {'id': 'MH-25-AJ-2169', 'no': 'MH-25-AJ-2169', 'name': '', 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Rental', 'status': 'Active', 'activeFrom': '', 'inactiveFrom': '', 'earlier': [{'from': '2026-06-01', 'until': '2026-08-01'}]},
  {'id': 'OLD-9', 'no': 'OLD-9', 'type': 'Roller', 'owner': '', 'ownership': 'Own', 'status': 'Inactive', 'inactiveFrom': '2026-10-01'},
];

Map<String, dynamic> answer({bool saved = false}) => {
      'today': '2026-10-14', 'date': '2026-10-14',
      'report': saved ? {'date': '2026-10-14', 'at': '14-10-2026 18:05', 'by': 'Tester', 'rows': [{'no': 'MH-25-AJ-2169', 'status': 'Breakdown', 'reason': 'Tyre puncture', 'remark': ''}, {'no': 'Sany 210 (No.1)', 'status': 'Working', 'reason': '', 'remark': ''}], 'count': 1} : null,
      'carried': saved ? '' : '2026-10-13',
      'status': {'MH25AJ2169': {'status': 'Breakdown', 'reason': 'Tyre puncture', 'remark': '', 'carried': true}},
      'onDate': [{'no': 'MH-25-AJ-2169', 'from': '2026-10-10', 'days': 5, 'reason': 'Tyre puncture', 'remark': '', 'id': 'MH-25-AJ-2169'}],
      'history': [
        {'no': 'MH-25-AJ-2169', 'from': '2026-10-10', 'backOn': '', 'reason': 'Tyre puncture', 'remark': '', 'days': 5},
        {'no': 'Sany 210 (No.1)', 'from': '2026-10-02', 'backOn': '2026-10-05', 'reason': 'Hydraulic problem', 'remark': '', 'days': 3},
      ],
      'reports': [{'date': '2026-10-13', 'at': '13-10-2026 18:00', 'by': 'Tester', 'total': 2, 'count': 1}],
    };

void main() {
  test('The day: the machinery on site, a breakdown carried with its days; what is sent and what is missing', () {
    final d = BkDay(answer());
    final list = d.list(master, {'Own', 'Rental', 'Hired'}, '');
    expect(list.map((m) => m['id']), ['Sany 210 (No.1)', 'MH-25-AJ-2169'], reason: 'OLD-9 left the site on 01-10-2026');
    expect(d.list(master, {'Rental'}, '').single['id'], 'MH-25-AJ-2169');
    expect(d.list(master, {'Own', 'Rental'}, 'sany').single['id'], 'Sany 210 (No.1)');
    final mh = list[1];
    expect(d.state(mh).bd, true);
    expect(d.since(mh), (from: '2026-10-10', days: 5));
    expect(d.since(list[0]), isNull);
    expect(d.statusText, 'Status of 14-10-2026 not submitted yet · breakdowns carried from 13-10-2026');
    expect(d.submitWord, "Submit today's status");
    var rows = d.body(list);
    expect(rows, [
      {'no': 'Sany 210 (No.1)', 'status': 'Working', 'reason': '', 'remark': ''},
      {'no': 'MH-25-AJ-2169', 'status': 'Breakdown', 'reason': 'Tyre puncture', 'remark': ''},
    ]);
    expect(d.problem(rows), '');
    d.edit(list[0])
      ..status = 'Breakdown'
      ..reason = ' ';
    rows = d.body(list);
    expect(d.problem(rows), 'Write the reason for: Sany 210 (No.1).');
    expect(d.since(list[0]), (from: '2026-10-14', days: 1), reason: 'a new breakdown starts today');
    expect(d.problem([]), 'No machinery in the list – tick Own / Rental above.');
    final doc = d.dayDoc(list, {'Own', 'Rental', 'Hired'});
    expect(doc.meta, 'Own, Rental, Hired: 2 machinery – Working 0, Breakdown 2 · NOT SUBMITTED');
    expect(doc.tables.single.rows[1].cells.map((c) => c.text), ['2', 'I E Enterprises', 'MH-25-AJ-2169', 'Tipper', 'Breakdown', 'Tyre puncture', '10-10-2026', '5', '']);
    final s = BkDay(answer(saved: true));
    expect(s.statusText, '✔ Submitted by Tester at 14-10-2026 18:05 – 2 machinery, 1 breakdown');
    expect(s.submitWord, 'Save changes');
  });

  test('The period: breakdown days in From – To, the days on site, when and why; by owner', () {
    final d = BkDay(answer());
    final rows = bpCalc(d, master, '2026-10-01', '2026-10-31');
    expect(rows.map((r) => '${r.no} ${r.site} ${r.bd} ${r.work} ${r.times}'), ['MH-25-AJ-2169 14 5 9 1', 'Sany 210 (No.1) 14 3 11 1'], reason: 'up to today; OLD-9 was not on site');
    expect(rows.first.why, ['10-10 →: Tyre puncture (5 d)']);
    expect(rows.last.why, ['02-10–04-10: Hydraulic problem (3 d)']);
    expect(bpPct(5, 14), '36%');
    expect(bpCalc(d, master, '2026-10-06', '2026-10-14', only: true).map((r) => r.no), ['MH-25-AJ-2169'], reason: 'only machinery with a breakdown in the dates');
    expect(bpCalc(d, master, '2026-10-01', '2026-10-14', own: 'Own').map((r) => r.no), ['Sany 210 (No.1)']);
    expect(bpOwners(rows).map((o) => '${o.owner} ${o.n} ${o.bd}'), ['I E Enterprises 1 5', 'RCL 1 3']);
    final m = bpDoc(rows, 'mach', '2026-10-01', '2026-10-14').tables.single;
    expect(m.head, ['#', 'Machinery', 'Owner', 'Days on site', 'Breakdown days', 'Working days', 'Breakdown %', 'Times', 'When and why']);
    expect(m.foot.single.cells.map((c) => c.text), ['Total – 2 machinery', '28', '8', '20', '29%', '2', '']);
    final b = bpDoc(rows, 'both', '2026-10-01', '2026-10-14').tables.single;
    expect(b.rows.first.cells.first.text, 'I E Enterprises · 1 machinery · Rental');
    expect(bpXlsDoc(rows, '2026-10-01', '2026-10-14').tables.single.rows.first.cells.map((c) => c.text), ['MH-25-AJ-2169', 'Tipper', 'I E Enterprises', 'Rental', '14', '5', '9', '1', '10-10 →: Tyre puncture (5 d)']);
  });
}
