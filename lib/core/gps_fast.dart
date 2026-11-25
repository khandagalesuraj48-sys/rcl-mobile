/* (3.171.0 patch 1, his word of 25-11-2026: "erp aso attendace app aso ki hr app aso … location fetching la time ghetey location on
 * asla tri sudha he khup fast hoyla haw … ha app la user updet kryar nhi") THE PHONE'S PLACE, FAST – for attendance (attend.dart) and
 * the photos of the ERP (photo.dart). Dart only, so it reaches the phones as a Shorebird patch, without a new app file.
 *   1. the phone's own reading of the last [young] seconds (another app or our own reading of a moment ago) is taken AT ONCE;
 *   2. else a new reading, asked EVERY SECOND (the plugin asked once in 5 s when no interval was given – the first answer could
 *      wait for it); on Android 13 and newer the phone may also give its reading of the last [young] seconds at once;
 *   3. [want] > 0 (attendance: the site's "exact to … m"): a reading less exact is not the end – only NEW readings are asked for
 *      until one is exact enough, within the same time limit; at the end the most exact one is given (the caller then says
 *      "not exact enough" as before). A made-up location is given back at once – the caller refuses it as before.
 * A reading is never older than [young]: a punch is still for where he stands now (the read-ahead's own rule is 20 s).
 * Not used for the background places (hr_track.dart, vl_gps.dart): their streams are as before.
 * The pieces that touch the phone are in [FastGps] – a test puts its own in [FastGps.gps]. */
import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

class FastGps {
  static FastGps gps = FastGps();

  bool get android => Platform.isAndroid;
  DateTime now() => DateTime.now();
  Future<Position?> last() => Geolocator.getLastKnownPosition();
  Future<Position> current(LocationSettings s) => Geolocator.getCurrentPosition(locationSettings: s);
  Future<void> pause(Duration d) => Future<void>.delayed(d);

  /// The settings of one reading: Android – every second, and a reading of the last [age] may come at once (Android 13+);
  /// elsewhere as before.
  LocationSettings settings(LocationAccuracy accuracy, Duration limit, Duration age) => android
      ? AndroidSettings(accuracy: accuracy, intervalDuration: const Duration(seconds: 1), maxUpdateAge: age, timeLimit: limit)
      : LocationSettings(accuracy: accuracy, timeLimit: limit);

  /// How old [p] is by the phone's clock (never below 0, never above [young] – a phone whose clock is wrong gets no more).
  Duration age(Position p, Duration young) {
    final a = now().difference(p.timestamp);
    return a.isNegative ? Duration.zero : (a > young ? young : a);
  }

  /// [p] is of the last [young] seconds (a time ahead of the phone's clock by more than 2 s: no).
  bool isYoung(Position p, Duration young) {
    final a = now().difference(p.timestamp);
    return a >= const Duration(seconds: -2) && a <= young;
  }

  /// Where the phone is – fast (above). null: no reading within [limit]. Any other trouble of the phone (location off, not
  /// allowed) is thrown as before, unless a reading is already there.
  Future<Position?> fix({LocationAccuracy accuracy = LocationAccuracy.best, double want = 0, Duration young = const Duration(seconds: 15), Duration limit = const Duration(seconds: 25)}) async {
    bool good(Position p) => p.isMocked || want <= 0 || (p.accuracy >= 0 && p.accuracy <= want);
    Position? best;
    void keep(Position p) {
      final b = best;
      if (b == null || (p.accuracy >= 0 && (b.accuracy < 0 || p.accuracy < b.accuracy))) best = p;
    }

    final end = now().add(limit);
    // 1. the phone's own reading of a moment ago
    try {
      final l = await last();
      if (l != null && isYoung(l, young)) {
        if (good(l)) return l;
        keep(l);
      }
    } catch (_) {/* this phone gives none: a new reading below */}
    // 2. / 3. a new reading – again (only new ones) while it is not exact enough
    var maxAge = young;
    Position? before;
    while (true) {
      final left = end.difference(now());
      if (left <= Duration.zero) break;
      try {
        final p = await current(settings(accuracy, left, maxAge));
        if (good(p)) return p;
        keep(p);
        maxAge = Duration.zero;
        // the same reading again (a phone that gives its last one at once): a moment's wait, not a loop that only asks
        if (before != null && p.timestamp == before.timestamp) await pause(const Duration(milliseconds: 700));
        before = p;
      } on TimeoutException {
        break;
      } catch (_) {
        if (best == null) rethrow;
        break;
      }
    }
    return best;
  }
}
