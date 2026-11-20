/* (3.132.0, Mechanical update-263 – the Smart Log Book; the plan approved 15/16-11-2026) THE GPS OF A VEHICLE WITH THE DRIVER.
 * While a vehicle is with him (an open custody – vl_sessions) his phone sends where it is:
 *   – Android: a foreground service with its own notification ("On duty with … – location shared") keeps the place coming while the
 *     app is in the background (geolocator's own service; FOREGROUND_SERVICE_LOCATION). An iPhone: also in the background (the
 *     app's "location" background mode – Info.plist; iOS shows its blue bar).
 *   – moving: a point about every 20 seconds; standing: one every 3 minutes (a place that has not changed is not kept again);
 *   – the points wait on the phone (also with no network – kept in a file of the app) and go in ONE call about every minute
 *     (vlGps). Each point carries its own number (its second): sent twice, the server keeps it once;
 *   – the GPS switched off on the phone: the piece of time it was off (from, to, the last place) goes with the next batch, and the
 *     phone reminds the driver every 5 minutes to switch it on (a notification of the phone – no server needed).
 * Started by the Smart Log Book / Home when they see the vehicle with him; stopped at the closing or the handover. */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import 'alerts.dart';
import 'api.dart';

/// One point as the server takes it (Mechanical vlGpsPush_).
Map<String, dynamic> gpsPoint(Position p, {required bool moving}) => {
      'seq': p.timestamp.millisecondsSinceEpoch ~/ 1000,
      't': p.timestamp.toUtc().toIso8601String(),
      'lat': p.latitude,
      'lng': p.longitude,
      'acc': p.accuracy.isFinite ? double.parse(p.accuracy.toStringAsFixed(1)) : null,
      'speed': p.speed.isFinite && p.speed >= 0 ? double.parse(p.speed.toStringAsFixed(2)) : null,
      'heading': p.heading.isFinite && p.heading >= 0 ? p.heading.round() : null,
      'moving': moving,
    };

/// Kept or not: moving (more than 15 m since the last point kept) – every point that comes (about 20 s); standing – one in 3 minutes.
bool gpsKeep(Position? last, Position now) {
  if (last == null) return true;
  final d = Geolocator.distanceBetween(last.latitude, last.longitude, now.latitude, now.longitude);
  final gap = now.timestamp.difference(last.timestamp);
  return d > 15 || gap >= const Duration(minutes: 3);
}

class VlGps extends ChangeNotifier {
  VlGps._();
  static final i = VlGps._();

  /// (a test) no real GPS on a test computer: what would start the stream / where the queue is kept
  @visibleForTesting
  static bool off = false;

  /// (3.149.0, rcl-hr step 20) others who use the same places (HR's location while on duty – hr_track.dart): no second GPS
  static final List<void Function(Position)> taps = [];

  /// (3.149.0) asked to let go of their own GPS before this one starts: the phone's GPS gives ONE stream to the whole app (the
  /// first one's settings) – the vehicle's must be its own (every 20 seconds), not HR's (every 5 minutes)
  static final List<Future<void> Function()> before = [];

  Api? _api;
  String session = '';
  String no = '';
  StreamSubscription<Position>? _sub;
  StreamSubscription<ServiceStatus>? _svc;
  Timer? _send, _remind;
  Position? _last;
  final List<Map<String, dynamic>> _q = [];
  final List<Map<String, dynamic>> _offs = [];
  Map<String, dynamic>? _offNow;
  bool _sending = false;

  /// What the driver's screen shows: on / off / no permission; the last point sent
  String state = 'off';
  DateTime? sentAt;
  int waiting = 0;

  bool get on => session.isNotEmpty;

  Future<File?> _file() async {
    if (off) return null;
    try {
      final d = await getApplicationSupportDirectory();
      return File('${d.path}/vl_gps_queue.json');
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
      await f.writeAsString(jsonEncode({'session': session, 'points': _q, 'off': _offs}));
    } catch (_) {/* the points stay in memory */}
  }

  Future<void> _load() async {
    final f = await _file();
    if (f == null || !await f.exists()) return;
    try {
      final j = jsonDecode(await f.readAsString()) as Map;
      if ('${j['session']}' != session) return;      // another custody's points: sent with it before, or let go
      for (final p in (j['points'] as List? ?? const [])) {
        if (p is Map) _q.add(p.cast<String, dynamic>());
      }
      for (final o in (j['off'] as List? ?? const [])) {
        if (o is Map) _offs.add(o.cast<String, dynamic>());
      }
    } catch (_) {}
  }

  /// Starts for the custody [id] of vehicle [vehicle] (again for the same: nothing changes).
  Future<String> start(Api api, String id, String vehicle) async {
    if (id.isEmpty) return 'none';
    if (session == id && _sub != null) return state;
    await stop(send: true);
    _api = api;
    session = id;
    no = vehicle;
    _q.clear();
    _offs.clear();
    await _load();
    if (off) {
      state = 'on';
      notifyListeners();
      return state;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = 'gps-off';
        _offNow = {'from': DateTime.now().toUtc().toIso8601String(), 'why': 'GPS off'};
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        state = 'no-permission';
        notifyListeners();
        return state;
      }
      final LocationSettings ls = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
              intervalDuration: const Duration(seconds: 20),
              foregroundNotificationConfig: ForegroundNotificationConfig(
                notificationTitle: 'On duty – $vehicle',
                notificationText: 'Sketchline shares the place of the vehicle while it is with you.',
                notificationChannelName: 'On duty – vehicle place',
                enableWakeLock: true,
                setOngoing: true,
              ),
            )
          : Platform.isIOS
              // (an iPhone: also in the background – the app's "location" background mode; iOS shows its blue bar while it is used)
              ? AppleSettings(accuracy: LocationAccuracy.high, distanceFilter: 10, activityType: ActivityType.automotiveNavigation, pauseLocationUpdatesAutomatically: false, allowBackgroundLocationUpdates: true, showBackgroundLocationIndicator: true)
              : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
      for (final f in List.of(before)) {
        try {
          await f();
        } catch (_) {/* the vehicle's GPS starts anyway */}
      }
      _sub = Geolocator.getPositionStream(locationSettings: ls).listen(_got, onError: (_) {
        state = 'gps-off';
        notifyListeners();
      });
      _svc = Geolocator.getServiceStatusStream().listen(_service, onError: (_) {});
      if (state != 'gps-off') state = 'on';
    } catch (_) {
      state = 'gps-off';
    }
    _send = Timer.periodic(const Duration(seconds: 60), (_) => flush());
    _remind = Timer.periodic(const Duration(minutes: 5), (_) {
      if (state == 'gps-off' && on) Alerts.show(7311, 'Switch on the GPS', 'The vehicle $no is with you – switch on the location (GPS) of the phone.');
    });
    notifyListeners();
    return state;
  }

  void _got(Position p) {
    for (final t in List.of(taps)) {
      try {
        t(p);
      } catch (_) {/* the vehicle's GPS goes on */}
    }
    if (_offNow != null) _offEnd();
    state = 'on';
    final moving = (p.speed.isFinite && p.speed > 1.5);
    if (!gpsKeep(_last, p)) return;
    _last = p;
    _q.add(gpsPoint(p, moving: moving));
    if (_q.length > 3000) _q.removeRange(0, _q.length - 3000);      // (a phone off the network for days: the newest kept)
    _save();
  }

  void _service(ServiceStatus st) {
    if (st == ServiceStatus.disabled) {
      state = 'gps-off';
      _offNow ??= {'from': DateTime.now().toUtc().toIso8601String(), 'lat': _last?.latitude, 'lng': _last?.longitude, 'why': 'GPS off'};
      notifyListeners();
      flush(stateOff: true);
    } else {
      state = 'on';
      notifyListeners();
    }
  }

  void _offEnd() {
    final o = _offNow!;
    _offNow = null;
    _offs.add({...o, 'to': DateTime.now().toUtc().toIso8601String()});
    _save();
  }

  /// Sends what waits (one call; at most 500 points – the rest at the next one). Nothing sent: kept for later.
  Future<void> flush({bool stateOff = false}) async {
    final api = _api;
    if (api == null || session.isEmpty || _sending) return;
    if (_q.isEmpty && _offs.isEmpty && !stateOff) return;
    _sending = true;
    final pts = _q.take(500).toList(), offs = [..._offs, if (stateOff && _offNow != null) {..._offNow!, 'to': null}];
    try {
      await api.call('vlGps', [{'session': session, 'points': pts, 'off': offs, if (stateOff) 'state': 'off'}]);
      _q.removeRange(0, pts.length);
      _offs.clear();
      sentAt = DateTime.now();
      await _save();
    } catch (e) {
      // no network: the points wait; the custody ended on the server (closed elsewhere): they are let go
      if (e is ApiError && !e.noConnection && RegExp(r'not with you|not yours|not with a driver').hasMatch(e.message)) {
        _q.clear();
        _offs.clear();
        await _save();
      }
    } finally {
      _sending = false;
    }
  }

  /// The custody ended (closing / handover / released): what waits is sent once more, then the GPS stops.
  Future<void> stop({bool send = true}) async {
    if (send) await flush();
    await _sub?.cancel();
    await _svc?.cancel();
    _sub = null;
    _svc = null;
    _send?.cancel();
    _remind?.cancel();
    _send = null;
    _remind = null;
    _last = null;
    _offNow = null;
    session = '';
    no = '';
    state = 'off';
    notifyListeners();
  }
}
