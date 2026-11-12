// (3.113.0) the reminders of attendance – what is reminded and when, without a phone
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/attend_remind.dart';

Map<String, dynamic> day({String next = 'in', Map? shift, List week = const [], List hol = const [], List punches = const [], String d = '2026-11-12'}) =>
    {'day': d, 'next': next, 'shift': shift ?? {'name': 'General', 'start': '08:30', 'end': '17:30', 'auto_out': '23:50'}, 'week_off': week, 'days_off': hol, 'punches': punches};
String ist(DateTime t) => t.add(const Duration(hours: 5, minutes: 30)).toIso8601String().substring(0, 16).replaceFirst('T', ' ');

void main() {
  // Thursday 12-11-2026, 07:00 in India
  final now = DateTime.utc(2026, 11, 12, 1, 30);

  test('IN: half an hour before the shift – today while it is not marked, and the coming six days', () {
    final p = remindPlan(day(), now);
    expect(p.map((r) => r.kind).toSet(), {'in'});
    expect(p.map((r) => ist(r.at)).toList(), ['2026-11-12 08:00', '2026-11-13 08:00', '2026-11-14 08:00', '2026-11-15 08:00', '2026-11-16 08:00', '2026-11-17 08:00', '2026-11-18 08:00']);
    expect(p.first.en, 'Mark IN – your shift (General) starts at 08:30');
    expect(p.map((r) => r.id).toSet().length, 7, reason: 'each its own number');
  });

  test('no reminder on a weekly off or a holiday; none for a moment already gone; none without a shift', () {
    // Sunday (0) is 15-11, Saturday (6) is 14-11; a holiday on 16-11
    final p = remindPlan(day(week: [0, 6], hol: ['2026-11-16']), now);
    expect(p.map((r) => ist(r.at).substring(0, 10)).toList(), ['2026-11-12', '2026-11-13', '2026-11-17', '2026-11-18']);
    expect(remindPlan(day(), DateTime.utc(2026, 11, 12, 2, 31)).first.at, DateTime.utc(2026, 11, 13, 2, 30), reason: '08:01 – today\'s moment is gone');
    expect(remindPlan({'day': '2026-11-12', 'next': 'in', 'shift': null}, now), isEmpty);
    expect(remindPlan(null, now), isEmpty);
    expect(remindPlan(day(shift: {'name': 'x', 'start': '', 'end': ''}), now), isEmpty);
  });

  test('IN marked: today\'s IN reminder goes; OUT – half an hour before the day is closed by itself', () {
    final p = remindPlan(day(next: 'out', punches: [{'kind': 'in', 'at': '2026-11-12T03:05:00Z'}]), DateTime.utc(2026, 11, 12, 3, 6));
    expect(p.where((r) => r.kind == 'in').map((r) => ist(r.at).substring(0, 10)).first, '2026-11-13');
    final o = p.singleWhere((r) => r.kind == 'out');
    expect(ist(o.at), '2026-11-12 23:20');
    expect(o.en, contains('at 23:50 today is closed by itself and counts as absent'));
    // a shift without a closing time: half an hour before it ends
    final q = remindPlan(day(next: 'out', shift: {'name': 'General', 'start': '08:30', 'end': '17:30', 'auto_out': ''}, punches: [{'kind': 'in', 'at': '2026-11-12T03:05:00Z'}]), DateTime.utc(2026, 11, 12, 3, 6));
    expect(ist(q.singleWhere((r) => r.kind == 'out').at), '2026-11-12 17:00');
    // the day is done: nothing for today
    expect(remindPlan(day(next: 'done'), now).map((r) => ist(r.at).substring(0, 10)).first, '2026-11-13');
  });

  test('a night shift: the IN of the evening – its OUT reminder is the next morning', () {
    final night = {'name': 'Night', 'start': '20:00', 'end': '06:00', 'auto_out': '08:00'};
    // IN at 19:50 on the 12th; read at 01:00 of the 13th (the server's day is the 13th)
    final p = remindPlan(day(d: '2026-11-13', next: 'out', shift: night, punches: [{'kind': 'in', 'at': '2026-11-12T14:20:00Z'}]), DateTime.utc(2026, 11, 12, 19, 30));
    expect(ist(p.singleWhere((r) => r.kind == 'out').at), '2026-11-13 07:30');
    expect(ist(remindPlan(day(shift: night), now).first.at), '2026-11-12 19:30');
  });
}
