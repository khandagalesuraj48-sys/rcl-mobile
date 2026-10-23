/* (3.6.0) Edit Log Book – the web's rules (App.html "EDIT LOG BOOK") worked out in the app's own code: what is worked out live,
 * the Close that moves the next Start, the red rows and "Use it", a machinery on hours only (update-77), a row for each work in a
 * shift (saved as one entry with its rows), + Add row / Add all missing dates / Delete, dates of a submitted bill, what saveLogBulk
 * is sent; a water tanker's trips; and the Log Book print – the SAME sheets as the web's own code makes (web_sheets.json is made
 * by running the web's logSheetsBuild on the same rows: scratchpad lbweb/gen.js). */
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/lb_print.dart';
import 'package:rcl_mobile/core/log_edit.dart';

Map<String, dynamic> fx(String n) => (jsonDecode(File('test/fixtures/logedit/$n.json').readAsStringSync()) as Map).cast<String, dynamic>();

/// A KM machinery (the test server's GAPX-1) with three days.
Map<String, dynamic> kmData() {
  final m = fx('gapx')['machine'];
  Map<String, dynamic> row(String d, num a, num b) => {
        'key': 'GAPX-1|$d|Full Day', 'date': d, 'shift': 'Full Day', 'unit': 'KM', 'mode': 'KM', 'okm': a, 'ckm': b, 'ohr': '', 'chr': '', 'tStart': '', 'tEnd': '', 'tBrk': '', 'trip': '',
        'challan': '', 'remark': '', 'chFrom': '', 'chTo': '', 'work': '', 'odsl': '', 'odSet': '', 'itemWork': {}, 'half': false,
      };
  return {
    'machine': m, 'from': '2026-09-28', 'to': '2026-09-30', 'boqItems': {},
    'rows': [row('2026-09-28', 1000, 1100), row('2026-09-29', 1100, 1150), row('2026-09-30', 1150, 1200)],
    'prev': {'date': '2026-09-27', 'shift': 'Full Day', 'okm': 990, 'ckm': 1000, 'ohr': '', 'chr': '', 'stock': 50},
    'next': {'date': '2026-10-01', 'shift': 'Full Day', 'okm': 1200, 'ohr': '', 'stock': 0},
    'diesel': {'2026-09-29': {'Day': 20, 'Night': 0}}, 'prevKm': 1000, 'prevHr': '', 'locks': [], 'nextHr': null, 'hrsOnly': false,
  };
}

String diffAt(String a, String b) {
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  if (i == a.length && i == b.length) return '';
  final s = i > 70 ? i - 70 : 0;
  return 'at $i: web «${a.substring(s, min(a.length, i + 90))}» app «${b.substring(s, min(b.length, i + 90))}»';
}

void main() {
  test('Times: past midnight, the break, the gaps of a split', () {
    expect(lgTimeHrs('22:00', '02:00', ''), 4);
    expect(lgTimeHrs('08:00', '13:30', 30), 5);
    expect(lgTimeHrs('08:00', '', 30), '');
    expect(slotsGap(slotsParse('11:00-13:00,14:00-17:00')), 60);
    expect(r2(-1.005), -1, reason: 'a half goes up, as the browser');
    expect(js(1008.0), '1008');
  });

  test('Open: an hour machinery on an Item-wise BOQ – the figures, the work picked by itself, nothing changed', () {
    final e = LogEdit(fx('ex200'), superUser: false, today: '2026-10-16');
    expect(e.ho, true, reason: 'read by the hour meter only');
    expect(e.rows.map((r) => '${r.date} ${r.shift} ${r.mode} ${js(r.ohr)}-${js(r.chr)}'), ['2026-10-01 Full Day Hrs 1008-1016', '2026-10-02 Full Day Hrs 1016-1024']);
    final c = e.calc();
    expect(c.figs[0].total, '8 hr');
    expect((c.figs[0].open, c.figs[0].need, c.figs[0].close), (-96, 96, -192));
    expect(c.figs[1].close, -288);
    final b0 = c.figs[0].box!, b1 = c.figs[1].box!;
    expect((b0.kinds.single.pick, b0.kinds.single.say, b0.kinds.single.restSay), ('Bucket', '8 hr', 'Bucket 8 hr'));
    expect((b1.kinds.single.pick, b1.kinds.single.restSay), ('_split', 'Bucket 5 hr'));
    expect((c.chg, c.bad, c.canSave, c.sum), (0, 0, false, 'No changes yet'));
    expect(e.prevText, 'Entry before: 30-09-2026 (Full Day) closed at 1,008, diesel left −96 L.');
  });

  test('A machinery on hours: a Close moves no other entry; the Start below it is red – "Use it"; then saved as the web sends it', () {
    final e = LogEdit(fx('ex200'), superUser: false, today: '2026-10-16');
    e.calc();
    expect(e.type(e.rows[0], 'chr', 1020), isNull, reason: 'update-77: another entry never moves');
    expect(e.rows[1].ohr, 1016);
    var c = e.calc();
    expect(c.figs[1].misH, true);
    expect(c.figs[1].note, 'Start cannot be less than 1,020 (Close of the last reading before it)');
    expect(c.figs[1].fixable, true);
    expect((c.bad, c.canSave, c.badSay), (1, false, '1 row(s) in red – Start must be the Close before it'));
    e.useFix(e.rows[1]);
    c = e.calc();
    expect((c.bad, c.chg, c.canSave, c.sum), (0, 2, true, '2 changed / new, 0 deleted'));
    expect(c.figs[1].total, '4 hr');
    expect(c.figs[1].box!.kinds.single.restSay, 'Bucket 1 hr');
    final p = e.save();
    expect(p.problem, '');
    expect(p.ask, ['2 entries changed', '0 new entries added', '0 entries deleted']);
    expect(p.notes, ['Totals, diesel Opening / Closing and averages are worked out again for this machinery.']);
    final rows = p.body['rows'] as List;
    expect(rows.first, containsPair('key', 'EX-200|2026-10-01|Full Day'));
    expect(rows.first, containsPair('closingHr', 1020));
    expect(rows.first, containsPair('same', false));
    expect(rows.first.containsKey('joinRows'), false);
    expect(rows.first['items'], {'Breaker': ''});
    expect(rows[1]['items'], {'Breaker': 3});
    expect(p.body['deleted'], isEmpty);
  });

  test('The Close cannot pass the Start of the next entry of an hours machinery', () {
    final d = fx('ex200')..['nextHr'] = {'date': '2026-10-17', 'shift': 'Full Day', 'ohr': 1030};
    final e = LogEdit(d, superUser: false, today: '2026-10-16');
    e.type(e.rows[1], 'chr', 1040);
    final c = e.calc();
    expect(c.figs[1].overNote, 'Close cannot be more than 1,030 – the Start of the entry of 17-10-2026 (Full Day), which is not changed by itself. Correct one of them.');
    expect(c.figs[1].bad, true);
  });

  test('A KM machinery: the next Start follows; Use it; the other shift of a ticked date; a Full Day stands alone; delete', () {
    final e = LogEdit(kmData(), superUser: false, today: '2026-10-16');
    var c = e.calc();
    expect([for (final f in c.figs) (f.open, f.iss, f.need, f.close)], [(50, 0, 25, 25), (25, 20, 12.5, 32.5), (32.5, 0, 12.5, 20)]);
    expect(e.type(e.rows[0], 'ckm', 1090), same(e.rows[1]));
    expect(e.rows[1].okm, 1090);
    e.type(e.rows[1], 'okm', 1080);
    c = e.calc();
    expect(c.figs[1].note, 'Start cannot be less than 1,090 (Close of the last reading before it)');
    e.useFix(e.rows[1]);
    expect(e.calc().bad, 0);
    // a Night for the 28th
    e.rows[0].sel = true;
    final (say, bad, row) = e.addRow();
    expect(bad, false);
    expect(say, '1 row(s) added: 28-09-2026 Night – type the readings if the meter moved, tick "½" for a half, then Save.');
    expect(e.rows.map((r) => '${r.date} ${r.shift}'), ['2026-09-28 Day', '2026-09-28 Night', '2026-09-29 Full Day', '2026-09-30 Full Day']);
    expect((row!.okm, row.ckm), (1090, 1090), reason: 'it starts and closes where the Day closed');
    expect(e.addRow().$1, 'Every date in this range has an entry. To add a Night (or Day) entry to a date: tick its row, then press "+ Add row".');
    // a Full Day entry stands alone
    e.change(e.rows[1], 'shift', 'Full Day');
    c = e.calc();
    expect(c.figs[0].slotNote, '28-09-2026: a Full Day entry stands alone – make one Day and the other Night.');
    expect(c.badSay, '2 row(s) in red – a date has two entries on the same shift');
    e.change(e.rows[1], 'shift', 'Night');
    expect(e.calc().bad, 0);
    // delete the 29th: the 30th starts where the row before closed
    e.remove([e.rows[2]]);
    expect(e.deleted, ['GAPX-1|2026-09-29|Full Day']);
    expect(e.rows.last.okm, 1090);
    final p = e.save();
    expect(p.ask, ['2 entries changed', '1 new entry added', '1 entry deleted']);
    expect(p.notes.first, 'The entry after (01-10-2026) will start at the last Close here.');
    expect(p.body['deleted'], ['GAPX-1|2026-09-29|Full Day']);
    expect((p.body['rows'] as List).map((r) => '${r['key']}|${r['date']}|${r['shift']}'), ['GAPX-1|2026-09-28|Full Day|2026-09-28|Day', '|2026-09-28|Night', 'GAPX-1|2026-09-30|Full Day|2026-09-30|Full Day']);
  });

  test('Missing dates (not after today, not of a submitted bill), Add all missing dates, + Add row; locks', () {
    final d = kmData()
      ..['from'] = '2026-10-10'
      ..['to'] = '2026-10-20';
    final rows = d['rows'] as List;
    rows[0]['date'] = '2026-10-11';
    rows[0]['key'] = 'GAPX-1|2026-10-11|Full Day';
    rows[1]['date'] = '2026-10-14';
    rows[1]['key'] = 'GAPX-1|2026-10-14|Full Day';
    rows.removeLast();
    final e = LogEdit(d, superUser: false, today: '2026-10-16');
    expect(e.missing(), ['2026-10-10', '2026-10-12', '2026-10-13', '2026-10-15', '2026-10-16']);
    expect(e.fillGaps(), ('2 row(s) added for 12-10-2026 to 13-10-2026 – type their Close readings.', false));
    final (_, _, r) = e.addRow();
    expect(r!.date, '2026-10-15', reason: 'the first free date after the first entry');
    final d2 = kmData()
      ..['locks'] = [
        {'from': '2026-09-29', 'to': '2026-09-30', 'billNo': 'RA-3', 'rev': 0, 'vendor': 'Vendor 5', 'company': 'RCL'}
      ];
    final l = LogEdit(d2, superUser: false, today: '2026-10-16');
    expect(l.rows.map((r) => r.lock?['billNo']), [null, 'RA-3', 'RA-3']);
    expect(l.lockTexts.single, startsWith('29-09-2026 to 30-09-2026 are in the submitted RA Bill RA-3 of Vendor 5 (RCL, 29-09-2026 to 30-09-2026) – the entries of those dates are shown but cannot be changed here.'));
    expect(l.change(l.rows[0], 'date', '2026-09-29'), startsWith('Log Book entry of GAPX-1 on 29-09-2026: this machinery is in the submitted RA Bill RA-3 of Vendor 5'));
    expect(LogEdit(d2, superUser: true, today: '2026-10-16').rows.every((r) => r.lock == null), true, reason: 'update-108: the Super Admin changes them');
  });

  test('A row for each work in a shift: opened as its rows, saved back as the same entry; + work in this shift', () {
    final d = fx('ex200');
    final r0 = (d['rows'] as List)[0] as Map;
    r0['whr'] = 8;
    r0['itemWork'] = {'Breaker': 3};
    r0['itemParts'] = [
      {'n': 'Bucket', 'q': 5, 'k': 'hr', 'c': 'C1', 'p': '', 'f': '', 't': '', 'w': 'Dig'},
      {'n': 'Breaker', 'q': 3, 'k': 'hr', 'c': 'C2', 'p': '', 'f': '', 't': '', 'w': 'Break'},
    ];
    final e = LogEdit(d, superUser: false, today: '2026-10-16');
    expect(e.rows.map((r) => '${js(r.ohr)}-${js(r.chr)} ${e.pickOf(r, 'hr')} ${r.challan} ${r.work}'), ['1008-1013 Bucket C1 Dig', '1013-1016 Breaker C2 Break', '1016-1024   ']);
    expect(e.later(e.rows[1]), true);
    expect(e.partWord(e.rows[1]), 'work 2 of this day');
    var c = e.calc();
    expect((c.bad, c.chg, c.entries), (0, 0, 2));
    expect(c.figs[1].iss, 0, reason: 'the shift takes its diesel once');
    final rows = e.save().body['rows'] as List;
    expect(rows.first['same'], true);
    expect((rows.first['items'] as Map)['_parts'], [
      {'n': 'Bucket', 'q': 5, 'c': 'C1', 'p': '', 'f': '', 't': '', 'w': 'Dig'},
      {'n': 'Breaker', 'q': 3, 'c': 'C2', 'p': '', 'f': '', 't': '', 'w': 'Break'},
    ]);
    expect((rows.first['openingHr'], rows.first['closingHr']), (1008, 1016));
    // one more work in that shift
    final n = e.addWork(e.rows[1])!;
    expect((n.date, n.shift, n.ohr, n.chr), ('2026-10-01', 'Full Day', 1016, 1016));
    c = e.calc();
    expect(c.figs[2].slotNote, '01-10-2026 Full Day: this row has no work yet – type its Close (or delete the row).');
    e.type(n, 'chr', 1018);
    c = e.calc();
    expect(c.figs[2].slotNote, '01-10-2026 Full Day: each row of this shift is ONE work – press Bucket / Breaker (not Split).');
    e.pressWork(n, 'hr', 'Bucket');
    c = e.calc();
    expect(c.figs[2].slotNote, '');
    expect(c.figs[3].note, 'Start cannot be less than 1,018 (Close of the last reading before it)', reason: 'the next entry is not moved (update-77)');
  });

  test('(update-144) every row of a shift by Time: his screen – Bucket 14:00 – 18:00, + work Breaker 09:00 – 13:00: no red; saved as ONE entry by Time in the order of the day; two rows at the same time red', () {
    final d = fx('ex200');
    final r0 = (d['rows'] as List)[0] as Map<String, dynamic>;
    r0.addAll({'mode': 'Time', 'unit': 'Time', 'ohr': '', 'chr': '', 'whr': 4, 'tStart': '14:00', 'tEnd': '18:00', 'tBrk': '', 'tSlots': '', 'itemWork': <String, Object?>{}, 'work': 'LOADING'});
    final e = LogEdit(d, superUser: false, today: '2026-10-16');
    expect('${e.rows[0].mode} ${e.rows[0].tStart}-${e.rows[0].tEnd} ${e.pickOf(e.rows[0], 'hr')}', 'Time 14:00-18:00 Bucket');
    final n = e.addWork(e.rows[0])!;
    expect(e.change(n, 'mode', 'Time'), isNull);
    e.type(n, 'tStart', '09:00');
    e.type(n, 'tEnd', '13:00');
    e.pressWork(n, 'hr', 'Breaker');
    e.type(n, 'work', 'BREAKING');
    var c = e.calc();
    expect(c.figs[0].slotNote, '');
    expect(c.figs[1].slotNote, '', reason: 'no "the rows of this shift are all by Time" any more');
    expect(c.bad, 0);
    final p = e.save();
    expect(p.problem, '');
    final row = (p.body['rows'] as List).first as Map;
    expect((row['mode'], row['tStart'], row['tEnd'], row['tBreak']), ('Time', '09:00', '18:00', ''));
    expect(row['tSlots'], [['09:00', '13:00'], ['14:00', '18:00']]);
    expect(((row['items'] as Map)['_parts'] as List).map((q) => '${q['n']} ${q['ts']} ${(q['q'] as num).round()} ${q['m']}'), ['Breaker 09:00-13:00 4 T', 'Bucket 14:00-18:00 4 T'], reason: 'the rows in the order of the day');
    expect(row['work'], 'BREAKING / LOADING', reason: 'the entry\'s texts in the order of the day');
    // the Breaker row into the Bucket time: both red with the reason
    e.type(n, 'tEnd', '15:00');
    c = e.calc();
    expect(c.figs[1].slotNote, '01-10-2026 Full Day: this row (09:00 – 15:00) is at the same time as row 1 of this shift (14:00 – 18:00) – a machinery does one work at a time: correct the From – To.');
    expect(c.bad > 0, true);
  });

  test('A water tanker: the trips, what is wrong before saving, what is sent', () {
    final t = LtEdit({
      'machine': {'id': 'WT-1', 'owner': 'Jal Agency', 'type': 'Water Tanker'},
      'from': '2026-10-01', 'to': '2026-10-31',
      'trips': [
        {'date': '2026-10-02', 'shift': 'Day', 'c': 'W-1', 'a': '08:00', 'b': '08:40', 'ch': '12+500', 'u': 'Curing', 'old': 0},
      ],
      'days': [{'date': '2026-10-03', 'shift': 'Day', 'status': 'Breakdown'}], 'locks': [],
    }, superUser: false, today: '2026-10-16');
    expect(t.info, 'Agency: Jal Agency  |  01-10-2026 to 31-10-2026  |  Without trips: 03-10-2026 Day (Breakdown)');
    expect(t.dirty, false);
    final n = t.add();
    expect((n.date, n.shift), ('2026-10-02', 'Day'));
    expect(t.dirty, false, reason: 'an empty row is nothing');
    n
      ..c = 'w-1'
      ..a = '08:20'
      ..b = '09:00';
    expect(t.dirty, true);
    expect(t.problems().map((x) => x.$2), ['Row 2: DUPLICATE challan w-1 – also in row 1.', 'Row 2: DUPLICATE time – 08:20–09:00 falls on row 1 (08:00–08:40).']);
    n
      ..c = 'W-2'
      ..a = '09:00'
      ..b = '';
    expect(t.problems().map((x) => x.$2), ['Row 2: enter the Unload time.']);
    n.b = '09:30';
    expect(t.problems(), isEmpty);
    expect((t.body()['trips'] as List).last, {'date': '2026-10-02', 'shift': 'Day', 'c': 'W-2', 'a': '09:00', 'b': '09:30', 'ch': '', 'u': '', 'old': 0});
    expect(t.nightTrips, 0);
  });

  // ---------- the Log Book print: the same sheets as the web ----------
  final cases = jsonDecode(File('test/fixtures/lbprint/web_sheets.json').readAsStringSync()) as List;
  for (final c0 in cases) {
    final c = (c0 as Map).cast<String, dynamic>();
    test('Log Book print "${c['name']}" – the same sheets as the web prints', () {
      final ms = (c['machines'] as Map).cast<String, dynamic>();
      final p = logBookPrint(
        rows: [for (final r in c['rows'] as List) (r as Map).cast<String, dynamic>()],
        from: '${c['from']}',
        to: '${c['to']}',
        head: '${c['head']}',
        site: '${c['site']}',
        extra: c['extra'] as Map,
        machine: (no) => (ms[no] as Map?)?.cast<String, dynamic>(),
        fmtF: '${c['fmt']}',
        sample: '${c['sample']}',
        dieselRate: c['dieselRate'] as num,
        idle: c['idle'] as Map?,
      );
      final a = p.html.indexOf('<div class="sheet">') + '<div class="sheet">'.length, b = p.html.lastIndexOf('</div></body>');
      expect(diffAt('${c['sheets']}', p.html.substring(a, b)), '');
      expect(p.title, c['title']);
    });
  }
}
