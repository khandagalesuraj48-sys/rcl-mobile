// (3.171.0 patch 1, his word of 25-11-2026: "location fetching la time ghetey … khup fast hoyla haw") the phone's place, fast –
// core/gps_fast.dart (attendance and the ERP's photos) and the attendance's read-ahead sharing a reading that is going on.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rcl_mobile/core/attend.dart';
import 'package:rcl_mobile/core/gps_fast.dart';

import 'fake_attend.dart';

/// The phone, for the test: its clock (moves 1 s at every reading), its last reading, the readings it gives in turn (a Position or
/// a trouble; none left: no answer within the time limit).
class FakeGps extends FastGps {
  FakeGps(this.t);
  DateTime t;
  bool isAndroid = true;
  Position? lastOne;
  final queue = <Object>[];
  final asked = <LocationSettings>[];
  final paused = <Duration>[];
  @override
  bool get android => isAndroid;
  @override
  DateTime now() => t;
  @override
  Future<Position?> last() async => lastOne;
  @override
  Future<Position> current(LocationSettings s) async {
    asked.add(s);
    if (queue.isEmpty) {
      t = t.add(s.timeLimit ?? const Duration(seconds: 25));
      throw TimeoutException('no reading', s.timeLimit);
    }
    t = t.add(const Duration(seconds: 1));
    final x = queue.removeAt(0);
    if (x is Position) return x;
    throw x;
  }

  @override
  Future<void> pause(Duration d) async {
    paused.add(d);
    t = t.add(d);
  }
}

Position pos(DateTime at, double acc, {bool mocked = false}) => Position.fromMap({'latitude': 18.52, 'longitude': 73.8567, 'timestamp': at.millisecondsSinceEpoch, 'accuracy': acc, 'is_mocked': mocked});

void main() {
  final t0 = DateTime.utc(2026, 11, 25, 5);

  test('a reading of the phone of the last 15 s is taken at once – no new reading is waited for', () async {
    final g = FakeGps(t0)..lastOne = pos(t0.subtract(const Duration(seconds: 10)), 8);
    final p = await g.fix(want: 100);
    expect([p?.accuracy, g.asked.length], [8, 0]);
    expect(g.age(p!, const Duration(seconds: 15)), const Duration(seconds: 10), reason: 'its own age goes with it');
  });

  test('an older one (20 s), or one with a time ahead of the clock: a new reading – asked every second; on Android 13+ one of the last 15 s may come at once', () async {
    for (final at in [t0.subtract(const Duration(seconds: 20)), t0.add(const Duration(seconds: 10))]) {
      final g = FakeGps(t0)
        ..lastOne = pos(at, 8)
        ..queue.add(pos(t0, 12));
      final p = await g.fix();
      expect([p?.accuracy, g.asked.length], [12, 1]);
      final s = g.asked.single as AndroidSettings;
      expect([s.accuracy, s.intervalDuration, s.maxUpdateAge, s.timeLimit], [LocationAccuracy.best, const Duration(seconds: 1), const Duration(seconds: 15), const Duration(seconds: 25)]);
    }
  });

  test('not Android (iPhone, a computer): the settings as before', () async {
    final g = FakeGps(t0)
      ..isAndroid = false
      ..queue.add(pos(t0, 12));
    await g.fix(accuracy: LocationAccuracy.high);
    final s = g.asked.single;
    expect([s is AndroidSettings, s.accuracy, s.timeLimit], [false, LocationAccuracy.high, const Duration(seconds: 25)]);
  });

  test('exact to 50 m asked: a reading of 120 m is not the end – only NEW readings are asked for, until one is exact enough', () async {
    final g = FakeGps(t0)
      ..lastOne = pos(t0.subtract(const Duration(seconds: 3)), 300)
      ..queue.addAll([pos(t0, 120), pos(t0.add(const Duration(seconds: 1)), 30)]);
    final p = await g.fix(want: 50);
    expect(p?.accuracy, 30);
    expect([for (final s in g.asked) (s as AndroidSettings).maxUpdateAge], [const Duration(seconds: 15), Duration.zero]);
    expect((g.asked[1] as AndroidSettings).timeLimit, const Duration(seconds: 24), reason: 'within the same 25 s');
  });

  test('none exact enough within the 25 s: the most exact one is given – the caller says "not exact enough" as before', () async {
    final g = FakeGps(t0)..queue.addAll([pos(t0, 120), pos(t0.add(const Duration(seconds: 1)), 80), pos(t0.add(const Duration(seconds: 2)), 90)]);
    final p = await g.fix(want: 50);
    expect([p?.accuracy, g.asked.length], [80, 4]);
  });

  test('a made-up location is given back at once (the caller refuses it as before)', () async {
    final g = FakeGps(t0)..queue.addAll([pos(t0, 200, mocked: true), pos(t0, 5)]);
    final p = await g.fix(want: 50);
    expect([p?.isMocked, g.asked.length], [true, 1]);
  });

  test('no reading within the 25 s: nothing (the caller says "could not be found" as before)', () async {
    final g = FakeGps(t0);
    expect(await g.fix(), isNull);
    expect(g.asked.length, 1);
  });

  test('the same reading given again: a moment\'s wait before asking again – not a loop that only asks', () async {
    final same = pos(t0, 150);
    final g = FakeGps(t0)..queue.addAll([same, same, same]);
    final p = await g.fix(want: 50);
    expect([p?.accuracy, g.paused], [150, [const Duration(milliseconds: 700), const Duration(milliseconds: 700)]]);
  });

  test('the location switched off / not allowed: said as before; after a first reading, that reading is given', () async {
    final g = FakeGps(t0)..queue.add(LocationServiceDisabledException());
    await expectLater(g.fix(), throwsA(isA<LocationServiceDisabledException>()));
    final g2 = FakeGps(t0)..queue.addAll([pos(t0, 120), LocationServiceDisabledException()]);
    expect((await g2.fix(want: 50))?.accuracy, 120);
  });

  test('the read-ahead: a reading going on is shared (no second one beside it); its time is the reading\'s own', () async {
    final kit = FakeAttendKit();
    AttendKit.kit = kit;
    addTearDown(() => AttendKit.kit = AttendKit());
    AttendWhere.i.clear();
    await Future.wait([AttendWhere.i.read(), AttendWhere.i.read()]);
    expect([kit.wants.length, AttendWhere.i.fresh()?.acc], [1, 12]);
    // a reading the phone gave 12 s old: young for 8 s more, not 20
    final old = _OldKit()..clock = kit.clock;
    AttendKit.kit = old;
    await AttendWhere.i.read();
    expect(AttendWhere.i.fresh(), isNotNull);
    old.clock += 9000;
    expect(AttendWhere.i.fresh(), isNull);
  });
}

class _OldKit extends FakeAttendKit {
  @override
  Future<AttendFix> where({double want = 0}) async => AttendFix(lat, lng, acc, age: 12000);
}
