/* THE REMINDERS OF ATTENDANCE (3.113.0 – asked 12-11-2026: "sign in and out ch notification ardha tas adhi user la den he ek mast
 * idea aahe"). Made on the phone itself, from what the HR server said last (his shift, where his day stands, the free days):
 *   IN  – half an hour before his shift starts: today (when IN is not marked yet) and the coming six days – not on a weekly off
 *         or a holiday;
 *   OUT – only while his IN of today is open: half an hour before the day is closed by itself (the shift's "closed by itself
 *         at" – without OUT it counts as absent); a shift without that time: half an hour before the shift ends.
 * Every time the app reads his day the reminders are set again (the old ones are taken away first), so a marked IN or OUT takes
 * its reminder away. Nothing is sent anywhere; no shift = no reminder. He switches them off in Me. The phone gives them at about
 * that time (Android may hold one back a few minutes when it saves battery). */
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'alerts.dart';
import 'attend.dart' show AttendKit;
import 'lang.dart';

const _ist = Duration(hours: 5, minutes: 30);
const kRemindBefore = Duration(minutes: 30);
const _file = 'remind.off', _base = 7100, _days = 7;

class Remind {
  const Remind(this.id, this.at, this.kind, this.en, this.mr);
  final int id;

  /// the moment (UTC)
  final DateTime at;

  /// 'in' | 'out'
  final String kind;
  final String en, mr;
}

int? _min(Object? hm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${hm ?? ''}');
  if (m == null) return null;
  final h = int.parse(m.group(1)!), n = int.parse(m.group(2)!);
  return h < 24 && n < 60 ? h * 60 + n : null;
}

/// What to remind and when, from the server's answer [day] (myAttend) at the moment [now] (UTC). Plain numbers – tested without a phone.
List<Remind> remindPlan(Map? day, DateTime now) {
  final shift = day?['shift'];
  if (day == null || shift is! Map) return const [];
  final start = _min(shift['start']), end = _min(shift['end']), auto = _min(shift['auto_out']), today = DateTime.tryParse('${day['day'] ?? ''}T00:00:00Z');
  if (start == null || today == null) return const [];
  final name = '${shift['name'] ?? ''}', hm = (int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  final off = {for (final w in (day['week_off'] as List? ?? const [])) (w is num ? w.toInt() : int.tryParse('$w') ?? -1)}, hol = {for (final h in (day['days_off'] as List? ?? const [])) '$h'};
  // an India time of a day (minutes from its midnight; more than a day = the next morning) as the moment in UTC
  DateTime at(DateTime d, int minutes) => d.add(Duration(minutes: minutes)).subtract(_ist);
  final next = '${day['next'] ?? ''}', out = <Remind>[];
  for (var i = 0; i < _days; i++) {
    final d = today.add(Duration(days: i)), ymd = d.toIso8601String().substring(0, 10);
    if (off.contains(d.weekday % 7) || hol.contains(ymd)) continue; // (0 = Sunday … 6 = Saturday, as the rules keep them)
    if (i == 0 && next != 'in') continue; // today's IN is marked (or the day is done)
    final t = at(d, start).subtract(kRemindBefore);
    if (t.isAfter(now)) out.add(Remind(_base + i * 2, t, 'in', 'Mark IN – your shift${name.isEmpty ? '' : ' ($name)'} starts at ${hm(start)}', 'IN लावा – तुमची shift${name.isEmpty ? '' : ' ($name)'} ${hm(start)} ला सुरू होते'));
  }
  if (next == 'out') {
    // the open IN: today's – or yesterday evening's of a night shift (then its closing times are today's morning)
    final ins = (day['punches'] as List? ?? const []).whereType<Map>().where((p) => '${p['kind']}' == 'in').toList(), inAt = ins.isEmpty ? null : DateTime.tryParse('${ins.last['at'] ?? ''}')?.toUtc().add(_ist);
    final inDay = inAt == null ? today : DateTime.utc(inAt.year, inAt.month, inAt.day);
    DateTime? t;
    String en = '', mr = '';
    if (auto != null) {
      t = at(inDay, auto <= start ? auto + 1440 : auto).subtract(kRemindBefore);
      en = 'Mark OUT – at ${hm(auto)} today is closed by itself and counts as absent';
      mr = 'OUT लावा – ${hm(auto)} ला आजचा दिवस आपोआप बंद होऊन गैरहजर धरला जाईल';
    } else if (end != null) {
      t = at(inDay, end <= start ? end + 1440 : end).subtract(kRemindBefore);
      en = 'Mark OUT – your shift ends at ${hm(end)}';
      mr = 'OUT लावा – तुमची shift ${hm(end)} ला संपते';
    }
    if (t != null && t.isAfter(now)) out.add(Remind(_base + 1, t, 'out', en, mr));
  }
  return out;
}

class AttendRemind {
  static final _n = FlutterLocalNotificationsPlugin();

  /// Has he switched the reminders off (Me)?
  static Future<bool> isOff() async => ((await AttendKit.kit.readText(_file)) ?? '').trim() == '1';

  static Future<void> setOff(bool off) async {
    await AttendKit.kit.writeText(_file, off ? '1' : '0');
    if (off) await _clear();
  }

  static Future<void> _clear() async {
    try {
      for (var i = 0; i < _days * 2; i++) {
        await _n.cancel(_base + i);
      }
    } catch (_) {/* no notifications on this phone (or in the tests) */}
  }

  /// Set the reminders again from the server's answer [day] – called every time his day is read or changes.
  static Future<void> set(Map? day) async {
    try {
      if (await isOff()) return;
      await Alerts.init(ask: true);
      await _clear();
      for (final r in remindPlan(day, DateTime.now().toUtc())) {
        await _n.zonedSchedule(
          r.id,
          Lang.i.pair('Attendance', 'हजेरी'),
          Lang.i.pair(r.en, r.mr),
          tz.TZDateTime.from(r.at, tz.UTC),
          NotificationDetails(
            android: AndroidNotificationDetails('rcl_attendance', Lang.i.pair('Attendance reminders', 'हजेरीची आठवण'), channelDescription: 'Half an hour before your shift starts, and before your day is closed', importance: Importance.high, priority: Priority.high),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {/* the app works without reminders */}
  }
}
