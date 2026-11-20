/* (3.149.0, rcl-hr step 20 – asked 20-11-2026: "saglet main location tracking pratek employee ch karaych aahe … bydefault saglenche on
 * asel"; his answer: "duety in zzal ki out prynt track aasel tya nantr nahi") HIS LOCATION, SHARED WITH HR WHILE HE IS ON DUTY.
 *   – Only from his IN to his OUT: HR's server says when (myTrack – on duty and not switched off for him today); Home asks it after
 *     every IN / OUT and whenever it is opened. The server keeps a point only inside a duty time – a point of before IN or after OUT is
 *     thrown away there too.
 *   – A point every 5 minutes; they wait on the phone (also with no network – a file of the app) and go in one call about every 5
 *     minutes (trackSend; each with its own number – sent twice, kept once).
 *   – Android: a foreground service with its own notification ("On duty – location shared with HR") keeps the place coming while the
 *     app is in the background; an iPhone: the app's "location" background mode (iOS shows its blue bar).
 *   – A driver with a vehicle (the Smart Log Book's GPS – vl_gps.dart – running): no second GPS; its places are used (the phone
 *     gives ONE stream of places to the whole app – ours lets go before the vehicle's starts, VlGps.before), and – as the vehicle's
 *     GPS sends only when the vehicle moves – a standing vehicle's place is asked once in 5 minutes.
 *   – Kept 30 days by HR, then deleted; never in a backup. Stopped at OUT, at sign-out, or when HR switches it off for him. */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'vl_gps.dart';

/// The HR call of his sign-in (hr_shell's hrCall): { action, … } → the answer.
typedef HrAsk = Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

/// One point as HR's server takes it (rcl-hr trackSend).
Map<String, dynamic> trackPoint(Position p) => {
      'seq': p.timestamp.millisecondsSinceEpoch ~/ 1000,
      't': p.timestamp.toUtc().toIso8601String(),
      'lat': p.latitude,
      'lng': p.longitude,
      'acc': p.accuracy.isFinite ? double.parse(p.accuracy.toStringAsFixed(1)) : null,
      'speed': p.speed.isFinite && p.speed >= 0 ? double.parse(p.speed.toStringAsFixed(2)) : null,
      'mock': p.isMocked,
    };

/// Kept or not: one point in [every] (a little less, so that a point that comes a second early is not lost).
bool trackKeep(DateTime? lastKept, DateTime now, {Duration every = const Duration(minutes: 5)}) =>
    lastKept == null || now.difference(lastKept) >= every - const Duration(seconds: 15);

class HrTrack extends ChangeNotifier {
  HrTrack._();
  static final i = HrTrack._();

  /// (a test) no real GPS on a test computer: nothing is started, nothing is kept in a file
  @visibleForTesting
  static bool off = false;

  HrAsk? _ask;
  StreamSubscription<Position>? _sub;
  Timer? _send, _tick;
  DateTime? _lastKept;
  final List<Map<String, dynamic>> _q = [];
  bool _sending = false, _asked = false;
  Duration every = const Duration(minutes: 5);

  /// What Home shows: shared now or not; the last time places were sent; how many wait on the phone
  bool on = false;
  String state = 'off'; // off · on · no-permission · gps-off
  DateTime? sentAt;
  int waiting = 0;

  Future<File?> _file() async {
    if (off) return null;
    try {
      final d = await getApplicationSupportDirectory();
      return File('${d.path}/hr_track_queue.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    waiting = _q.length;
    notifyListeners();
    final f = await _file();
    if (f == null) return;
    try {
      await f.writeAsString(jsonEncode({'on': on, 'every_min': every.inMinutes, 'points': _q}));
    } catch (_) {/* the points stay in memory */}
  }

  Future<Map> _read() async {
    final f = await _file();
    if (f == null || !await f.exists()) return const {};
    try {
      return jsonDecode(await f.readAsString()) as Map;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _load() async {
    for (final p in ((await _read())['points'] as List? ?? const [])) {
      if (p is Map) _q.add(p.cast<String, dynamic>());
    }
  }

  /// The app opened again on the ERP's Home while he is on duty (by what this phone knows – ui/attend_strip.dart): sharing that
  /// was on when the app was closed goes on – no question to the server here (Home asks nothing); the first send's answer
  /// stops it if he is not on duty any more.
  Future<void> resume(HrAsk ask) async {
    if (on) {
      _ask = ask;
      return;
    }
    final j = await _read();
    if (j['on'] != true || on) return;
    _ask = ask;
    final m = j['every_min'];
    if (m is num && m >= 1) every = Duration(minutes: m.toInt());
    await _start();
  }

  /// Asks HR whether his place is to be shared now (on duty, not switched off for him today) – and starts or stops.
  /// No network: as it was (a phone already sharing goes on keeping the points; they go when the network is back).
  Future<void> sync(HrAsk ask) async {
    _ask = ask;
    Map<String, dynamic> r;
    try {
      r = await ask({'action': 'myTrack'});
    } catch (_) {
      return;
    }
    final m = r['every_min'];
    if (m is num && m >= 1) every = Duration(minutes: m.toInt());
    if (r['ready'] == true && r['on'] == true) {
      await _start();
    } else {
      await stop();
    }
  }

  Future<void> _start() async {
    if (on) return;
    on = true;
    _q.clear();
    await _load();
    await _save(); // (kept: on – for the app opened again, resume)
    if (off) {
      state = 'on';
      notifyListeners();
      return;
    }
    VlGps.taps.add(_got); // (a driver with a vehicle: the Smart Log Book's GPS gives the places)
    VlGps.before.add(_yield);
    if (!VlGps.i.on) await _stream();
    _send = Timer.periodic(every, (_) => flush());
    // every minute: the vehicle's GPS started / ended – no second GPS, or ours again
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    notifyListeners();
  }

  Future<void> _check() async {
    if (!on || off) return;
    if (VlGps.i.on) {
      await _yield();
      // the vehicle's GPS sends a place only when the vehicle moves (10 m): standing still, his place is asked once in 5 minutes
      final l = _lastKept;
      if (l == null || DateTime.now().difference(l) >= every - const Duration(seconds: 15)) {
        try {
          _got(await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 30))));
        } catch (_) {/* no place now: asked again in a minute */}
      }
    } else if (_sub == null || (state == 'gps-off' && await _gpsOn())) {
      // ours again (the vehicle's ended; the location was not allowed; the phone's location switched on again)
      await _yield();
      await _stream();
    }
  }

  Future<bool> _gpsOn() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Our own GPS lets go (the vehicle's starts – VlGps.before; or it runs already)
  Future<void> _yield() async {
    final x = _sub;
    _sub = null;
    await x?.cancel();
  }

  Future<void> _stream() async {
    try {
      final gps = await Geolocator.isLocationServiceEnabled();
      var p = await Geolocator.checkPermission();
      // (asked once a duty – not again every minute; allowed later in the phone's settings: found at the next minute)
      if (p == LocationPermission.denied && !_asked) {
        _asked = true;
        p = await Geolocator.requestPermission();
      }
      state = gps ? 'on' : 'gps-off';
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        state = 'no-permission';
        notifyListeners();
        return;
      }
      final LocationSettings ls = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: every,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'On duty – location shared with HR',
                notificationText: 'Every 5 minutes until your OUT. HR keeps it 30 days.',
                notificationChannelName: 'On duty – location for HR',
                enableWakeLock: false,
                setOngoing: true,
              ),
            )
          : Platform.isIOS
              ? AppleSettings(accuracy: LocationAccuracy.high, distanceFilter: 0, activityType: ActivityType.other, pauseLocationUpdatesAutomatically: false, allowBackgroundLocationUpdates: true, showBackgroundLocationIndicator: true)
              : const LocationSettings(accuracy: LocationAccuracy.high);
      _sub = Geolocator.getPositionStream(locationSettings: ls).listen(_got, onError: (_) {
        state = 'gps-off';
        notifyListeners();
      });
    } catch (_) {
      state = 'gps-off';
    }
    notifyListeners();
  }

  void _got(Position p) {
    if (!on) return;
    if (state != 'on') {
      state = 'on';
      notifyListeners();
    }
    if (!trackKeep(_lastKept, p.timestamp, every: every)) return;
    _lastKept = p.timestamp;
    _q.add(trackPoint(p));
    if (_q.length > 2000) _q.removeRange(0, _q.length - 2000); // (a phone off the network for days: the newest kept)
    _save();
  }

  /// (a test) a place from the phone, as the GPS would give it
  @visibleForTesting
  void take(Position p) => _got(p);

  /// Sends what waits (one call; at most 500 points – the rest at the next one). Nothing sent: kept for later.
  Future<void> flush() async {
    final ask = _ask;
    if (ask == null || _sending || _q.isEmpty) return;
    _sending = true;
    final pts = _q.take(500).toList();
    try {
      final r = await ask({'action': 'trackSend', 'points': pts});
      _q.removeRange(0, pts.length);
      sentAt = DateTime.now();
      await _save();
      if (r['on'] == false) await stop(send: false); // OUT marked (elsewhere), or HR switched it off for him today
    } catch (e) {
      // no network / the sign-in to renew / too many: they wait; the server refused them for good (not his any more): let go
      if (e is ApiError && !e.noConnection && e.status >= 400 && e.status < 500 && !const {401, 408, 429}.contains(e.status)) {
        _q.clear();
        await _save();
      }
    } finally {
      _sending = false;
    }
  }

  /// OUT, sign-out, or switched off: what waits is sent once more, then the GPS stops.
  Future<void> stop({bool send = true}) async {
    if (!on && _q.isEmpty) return;
    if (send) await flush();
    VlGps.taps.remove(_got);
    VlGps.before.remove(_yield);
    await _yield();
    _send?.cancel();
    _tick?.cancel();
    _send = null;
    _tick = null;
    _lastKept = null;
    _asked = false;
    on = false;
    state = 'off';
    await _save(); // (kept: off; what could not be sent waits for the next duty)
  }
}
