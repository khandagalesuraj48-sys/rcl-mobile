/* (3.149.0, rcl-hr step 20) his location for HR while he is on duty: one point in 5 minutes, and a point as HR's server takes it
 * (trackSend). The screens' part (only from IN to OUT, told once, Home's card, the points sent, stopped at OUT): screens_test.dart. */
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:rcl_mobile/core/hr_track.dart';

void main() {
  test('(3.149.0) one point in 5 minutes – one that comes a few seconds early is not lost', () {
    final t0 = DateTime.utc(2026, 11, 20, 5);
    expect(trackKeep(null, t0), true, reason: 'the first one');
    expect(trackKeep(t0, t0.add(const Duration(minutes: 2))), false);
    expect(trackKeep(t0, t0.add(const Duration(minutes: 4, seconds: 50))), true);
    expect(trackKeep(t0, t0.add(const Duration(minutes: 5))), true);
    expect(trackKeep(t0, t0.add(const Duration(minutes: 1)), every: const Duration(minutes: 1)), true, reason: 'HR\'s own "every" is used');
  });

  test('(3.149.0) a point as HR takes it: its own number (the second), the time, the place, how exact, the speed, a made-up place', () {
    final at = DateTime.utc(2026, 11, 20, 5);
    final p = Position.fromMap({'latitude': 18.52, 'longitude': 73.85, 'timestamp': at.millisecondsSinceEpoch, 'accuracy': 7.26, 'speed': -1.0, 'is_mocked': true});
    final m = trackPoint(p);
    expect(m['seq'], at.millisecondsSinceEpoch ~/ 1000);
    expect(m['t'], '2026-11-20T05:00:00.000Z');
    expect([m['lat'], m['lng'], m['acc'], m['speed'], m['mock']], [18.52, 73.85, 7.3, null, true], reason: 'no speed known: none sent');
  });
}
