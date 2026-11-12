/* (3.103.0, asked 12-11-2026) HR ATTENDANCE on the phone – what the screen (screens/attendance.dart) stands on. The server
 * (rcl-hr, lib/act_attend.js) decides everything again; the phone only never offers what the server would refuse:
 *   • each person for himself, TODAY only;
 *   • only INSIDE one of his work places ("GEOFENCE BAHER KAHICH NHI HONAR") – a point with its metres, an area, or along the road;
 *   • from ONE phone (this phone's own number goes with every punch);
 *   • not with Developer Options ON, not with a made-up location – only attendance is stopped, the rest of the app works;
 *   • a selfie with every punch – proof only, nothing reads it;
 *   • no network: the punch is KEPT ON THE PHONE exactly as taken (place, the phone's clocks, the photo) and sent when the network
 *     is back, with its own number – sent twice, saved once. The punch is never made again from new readings.
 * The pieces that touch the phone itself (its number, Developer Options, its counter since switch-on, GPS, files) are in AttendKit –
 * a test puts its own in its place. */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

const _rad = math.pi / 180, _earth = 6371008.8;

/// Metres between two points.
double geoDist(double aLat, double aLng, double bLat, double bLng) {
  final dLat = (bLat - aLat) * _rad, dLng = (bLng - aLng) * _rad;
  final s = math.pow(math.sin(dLat / 2), 2) + math.cos(aLat * _rad) * math.cos(bLat * _rad) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earth * math.asin(math.min(1.0, math.sqrt(s)));
}

List<double> _xy(double oLat, double oLng, double lat, double lng) => [(lng - oLng) * _rad * _earth * math.cos(oLat * _rad), (lat - oLat) * _rad * _earth];

/// Metres from a point to the piece of line a–b.
double geoDistSeg(double lat, double lng, List<double> a, List<double> b) {
  final e = _xy(a[0], a[1], b[0], b[1]), p = _xy(a[0], a[1], lat, lng), len = e[0] * e[0] + e[1] * e[1];
  final t = len == 0 ? 0.0 : math.max(0.0, math.min(1.0, (p[0] * e[0] + p[1] * e[1]) / len));
  final dx = p[0] - t * e[0], dy = p[1] - t * e[1];
  return math.sqrt(dx * dx + dy * dy);
}

bool geoInPolygon(double lat, double lng, List<List<double>> pts) {
  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final yi = pts[i][0], xi = pts[i][1], yj = pts[j][0], xj = pts[j][1];
    if ((yi > lat) != (yj > lat) && lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? double.nan;

/// One of his work places, as the server gave it (myAttend).
class WorkPlace {
  WorkPlace(this.id, this.name, this.kind, this.shape, this.lat, this.lng, this.radius, this.points);
  final String id, name, kind, shape;
  final double lat, lng, radius;
  final List<List<double>> points;

  static WorkPlace? fromJson(Object? j) {
    if (j is! Map || '${j['id'] ?? ''}'.isEmpty) return null;
    final pts = <List<double>>[];
    for (final p in (j['points'] as List? ?? const [])) {
      if (p is List && p.length >= 2) pts.add([_num(p[0]), _num(p[1])]);
    }
    return WorkPlace('${j['id']}', '${j['name'] ?? ''}', '${j['kind'] ?? ''}', '${j['shape'] ?? 'circle'}', _num(j['lat']), _num(j['lng']), _num(j['radius_m']), pts);
  }

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'kind': kind, 'shape': shape, 'lat': lat.isNaN ? null : lat, 'lng': lng.isNaN ? null : lng, 'radius_m': radius.isNaN ? null : radius, 'points': points};
}

/// Where a point is for one place: inside, or how many metres outside its edge.
class PlaceHit {
  PlaceHit(this.place, this.inside, this.distance);
  final WorkPlace place;
  final bool inside;
  final int distance;
}

PlaceHit placeCheck(WorkPlace p, double lat, double lng) {
  if (p.shape == 'circle') {
    final d = geoDist(lat, lng, p.lat, p.lng);
    return PlaceHit(p, d <= p.radius, math.max(0, (d - p.radius).round()));
  }
  if (p.shape == 'polygon') {
    if (p.points.length < 3) return PlaceHit(p, false, 1 << 30);
    if (geoInPolygon(lat, lng, p.points)) return PlaceHit(p, true, 0);
    var m = double.infinity;
    for (var i = 0; i < p.points.length; i++) {
      m = math.min(m, geoDistSeg(lat, lng, p.points[i], p.points[(i + 1) % p.points.length]));
    }
    return PlaceHit(p, false, m.round());
  }
  if (p.points.length < 2) return PlaceHit(p, false, 1 << 30);
  var m = double.infinity;
  for (var i = 0; i + 1 < p.points.length; i++) {
    m = math.min(m, geoDistSeg(lat, lng, p.points[i], p.points[i + 1]));
  }
  return PlaceHit(p, m <= p.radius, math.max(0, (m - p.radius).round()));
}

/// The best of his places: the one he is inside, else the nearest edge; null = he has no place.
PlaceHit? nearestPlace(List<WorkPlace> places, double lat, double lng) {
  PlaceHit? best;
  for (final p in places) {
    final c = placeCheck(p, lat, lng);
    if (best == null || (c.inside && !best.inside) || (c.inside == best.inside && c.distance < best.distance)) best = c;
  }
  return best;
}

/// Where the phone says it is.
class AttendFix {
  AttendFix(this.lat, this.lng, this.acc, {this.mocked = false});
  final double lat, lng, acc;
  final bool mocked;
}

/// Why a punch cannot be taken now – said to the person as it is.
class AttendProblem implements Exception {
  AttendProblem(this.en, this.mr, [this.code = '']);
  final String en, mr, code;
  @override
  String toString() => en;
}

/// A punch number of the phone's own (24 letters and digits): the server keeps a punch with the same number once.
String newPunchId([math.Random? r]) {
  final rnd = r ?? math.Random.secure();
  const hex = '0123456789abcdef';
  return [for (var i = 0; i < 24; i++) hex[rnd.nextInt(16)]].join();
}

/// The camera's picture made small for the proof (the longer side 720, a JPEG well under 1 MB). null = not a picture.
Uint8List? smallJpg(Uint8List raw) {
  final im = img.decodeImage(raw);
  if (im == null) return null;
  final up = img.bakeOrientation(im);
  final big = math.max(up.width, up.height);
  final small = big > 720 ? img.copyResize(up, width: up.width >= up.height ? 720 : null, height: up.height > up.width ? 720 : null) : up;
  var out = img.encodeJpg(small, quality: 72);
  if (out.length > 900000) out = img.encodeJpg(small, quality: 45);
  return Uint8List.fromList(out);
}

/// A punch kept on the phone until the server has it (the photo beside it as <cid>.jpg).
class KeptPunch {
  KeptPunch({required this.cid, required this.kind, required this.lat, required this.lng, required this.acc, required this.atDevice, required this.place, this.elapsed, this.anchorServer, this.anchorElapsed, this.deviceId = '', this.model = '', this.os = ''});
  final String cid, kind, place, atDevice, deviceId, model, os;
  final double lat, lng, acc;
  final int? elapsed, anchorServer, anchorElapsed;

  Map<String, Object?> toJson() => {'cid': cid, 'kind': kind, 'lat': lat, 'lng': lng, 'acc': acc, 'at_device': atDevice, 'place': place, 'elapsed': elapsed, 'anchor_server': anchorServer, 'anchor_elapsed': anchorElapsed, 'device_id': deviceId, 'model': model, 'os': os};

  static KeptPunch? fromJson(Object? j) {
    if (j is! Map || '${j['cid'] ?? ''}'.length < 16) return null;
    int? n(Object? v) => v is num ? v.toInt() : null;
    return KeptPunch(cid: '${j['cid']}', kind: '${j['kind']}' == 'out' ? 'out' : 'in', lat: _num(j['lat']), lng: _num(j['lng']), acc: _num(j['acc']), atDevice: '${j['at_device'] ?? ''}', place: '${j['place'] ?? ''}',
        elapsed: n(j['elapsed']), anchorServer: n(j['anchor_server']), anchorElapsed: n(j['anchor_elapsed']), deviceId: '${j['device_id'] ?? ''}', model: '${j['model'] ?? ''}', os: '${j['os'] ?? ''}');
  }

  /// What the server is sent for it. [live]: taken with the network, sent at once – the server's own clock counts; else it was
  /// kept: the phone's clocks go with it and the server works out its moment (or keeps it for the HR Admin to look at).
  Map<String, Object?> body({required bool live}) => {
        'action': 'punch',
        'client_id': cid,
        'kind': kind,
        'lat': lat,
        'lng': lng,
        'accuracy_m': acc,
        'device': {'id': deviceId, 'model': model, 'os': os},
        'dev_options': false,
        'mock': false,
        'at_device': atDevice,
        if (!live) ...{'offline': true, 'anchor_server': anchorServer, 'anchor_elapsed': anchorElapsed, 'elapsed': elapsed},
      };
}

/// The phone's own part. A test puts its own in [AttendKit.kit].
class AttendKit {
  static AttendKit kit = AttendKit();
  static const _ch = MethodChannel('rcl/attend');
  Map<String, String>? _info;

  /// This phone's own number for the app, its make and its system. Android: ANDROID_ID (the same until the phone is reset);
  /// elsewhere a number made once and kept in the app's own files (gone when the app is removed).
  Future<Map<String, String>> info() async {
    if (_info != null) return _info!;
    var id = '', model = '', os = '';
    if (Platform.isAndroid) {
      try {
        final m = await _ch.invokeMapMethod<String, dynamic>('info');
        id = '${m?['id'] ?? ''}';
        model = '${m?['model'] ?? ''}';
        os = '${m?['os'] ?? ''}';
      } catch (_) {/* below: the app's own number */}
    }
    if (id.length < 8) {
      id = ((await readText('phone.id')) ?? '').trim();
      if (id.length < 8) {
        id = 'app-${newPunchId()}';
        await writeText('phone.id', id);
      }
    } else {
      id = 'and-$id';
    }
    if (model.isEmpty) model = Platform.isIOS ? 'iPhone' : Platform.operatingSystem;
    if (os.isEmpty) os = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.trim();
    if (os.length > 40) os = os.substring(0, 40);
    return _info = {'id': id, 'model': model, 'os': os};
  }

  /// Developer Options switched on (Android). Not known = false: the server still has the last word on everything else.
  Future<bool> devOptions() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('devOptions') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Milliseconds since the phone was switched on – a counter the person cannot set (Android). null = this phone gives none.
  Future<int?> elapsed() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _ch.invokeMethod<int>('elapsed');
    } catch (_) {
      return null;
    }
  }

  /// Where the phone is now – a fresh reading (never the last known one: a punch is for where he stands now).
  Future<AttendFix> where() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw AttendProblem('Turn on the location of the phone (GPS), then try again.', 'Phone चे location (GPS) चालू करा, मग पुन्हा करा.', 'gps');
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      throw AttendProblem('Allow the location for the app (Settings › Apps › RCL ERP › Permissions), then try again.', 'App ला location ची परवानगी द्या (Settings › Apps › RCL ERP › Permissions), मग पुन्हा करा.', 'gps');
    }
    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 25)));
      return AttendFix(pos.latitude, pos.longitude, pos.accuracy, mocked: pos.isMocked);
    } on TimeoutException {
      throw AttendProblem('Your location could not be found – stand in the open and try again.', 'तुमचे location मिळाले नाही – मोकळ्या जागेत उभे राहून पुन्हा करा.', 'gps');
    }
  }

  /// The app's own folder for attendance (what is kept until sent; what was read last).
  Future<Directory> dir() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/attend');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  int now() => DateTime.now().millisecondsSinceEpoch;

  // ---- the app's own files of attendance, by name (a test keeps them in memory)
  Future<String?> readText(String name) async {
    try {
      final f = File('${(await dir()).path}/$name');
      return await f.exists() ? await f.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeText(String name, String v) async {
    await File('${(await dir()).path}/$name').writeAsString(v, flush: true);
  }

  Future<Uint8List?> readBytes(String name) async {
    try {
      final f = File('${(await dir()).path}/$name');
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBytes(String name, Uint8List b) async {
    await File('${(await dir()).path}/$name').writeAsBytes(b, flush: true);
  }

  Future<void> delete(String name) async {
    try {
      final f = File('${(await dir()).path}/$name');
      if (await f.exists()) await f.delete();
    } catch (_) {/* it is asked again and answered "already saved" */}
  }

  Future<List<String>> names() async {
    final out = <String>[];
    try {
      await for (final e in (await dir()).list()) {
        if (e is File) out.add(e.uri.pathSegments.last);
      }
    } catch (_) {/* nothing kept */}
    return out;
  }
}

/// What the phone keeps for attendance: the answer read last (his places, the day, IN or OUT next, the server's time with the
/// phone's counter at that moment) and the punches not sent yet. One folder a person and a site.
class AttendStore {
  AttendStore(this.who);

  /// the person and the site (a file name's part)
  final String who;

  String get _tag => who.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');

  Future<Map<String, dynamic>?> last() async {
    try {
      final t = await AttendKit.kit.readText('${_tag}_last.json');
      if (t == null) return null;
      final j = jsonDecode(t);
      return j is Map ? j.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// The server's answer (myAttend) with the phone's counter at that moment – the anchor of a punch taken without a network.
  Future<void> keep(Map<String, dynamic> answer, int? elapsed) =>
      AttendKit.kit.writeText('${_tag}_last.json', jsonEncode({...answer, 'anchor_elapsed': elapsed, 'read_at': AttendKit.kit.now()}));

  /// After a punch the server took: its list of today and what comes next are kept too (the anchor stays as it was read).
  Future<void> patch(Map<String, dynamic> changes) async {
    final l = await last();
    if (l != null) await AttendKit.kit.writeText('${_tag}_last.json', jsonEncode({...l, ...changes}));
  }

  Future<List<KeptPunch>> kept() async {
    final out = <KeptPunch>[];
    for (final n in await AttendKit.kit.names()) {
      if (!n.startsWith('${_tag}_q_') || !n.endsWith('.json')) continue;
      try {
        final k = KeptPunch.fromJson(jsonDecode(await AttendKit.kit.readText(n) ?? ''));
        if (k != null) out.add(k);
      } catch (_) {/* a broken file is left where it is */}
    }
    out.sort((a, b) => a.atDevice.compareTo(b.atDevice));
    return out;
  }

  Future<Uint8List?> photo(String cid) => AttendKit.kit.readBytes('${_tag}_q_$cid.jpg');

  /// Written BEFORE anything is sent: whatever happens to the network, the punch as taken is on the phone.
  Future<void> add(KeptPunch p, Uint8List jpg) async {
    await AttendKit.kit.writeBytes('${_tag}_q_${p.cid}.jpg', jpg);
    await AttendKit.kit.writeText('${_tag}_q_${p.cid}.json', jsonEncode(p.toJson()));
  }

  Future<void> remove(String cid) async {
    await AttendKit.kit.delete('${_tag}_q_$cid.json');
    await AttendKit.kit.delete('${_tag}_q_$cid.jpg');
  }
}

/// IN or OUT next, from what the server said last and what is still kept on the phone.
String nextKind(String serverNext, List<KeptPunch> kept) => kept.isEmpty ? (serverNext == 'out' ? 'out' : 'in') : (kept.last.kind == 'in' ? 'out' : 'in');

/// The day in India (yyyy-MM-dd) of a moment.
String indiaDay(int ms) => DateTime.fromMillisecondsSinceEpoch(ms + 19800000, isUtc: true).toIso8601String().substring(0, 10);

/// HH:mm in India of a moment written as the server writes it.
String indiaTime(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  return t.toUtc().add(const Duration(hours: 5, minutes: 30)).toIso8601String().substring(11, 16);
}
