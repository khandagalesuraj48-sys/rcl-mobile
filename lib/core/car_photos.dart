/* (3.86.0, Mechanical update-212, asked 08-11-2026: "HEAD OFFICE VEHICLE GALLERY & INTERACTIVE VEHICLE MANAGEMENT … Android App –
 * Vehicle Gallery, Details Screen and Camera Photo Upload") THE PHOTOS OF HO'S CARS on the phone – as on the web:
 *   – a photo is kept by HO's Mechanical in the site's private file store; the server gives each car { t (small), f (whole), exp, v }:
 *     two links of 15 minutes and the photo's own mark (v). The phone keeps the PICTURES in memory by that mark (the same photo is
 *     never downloaded twice, even with a new link) and asks for new links (getCarPhotoLinks) by itself when a link ends within a
 *     minute and a half, or when a picture does not open – the screen is never opened again for it.
 *   – a photo taken (the phone's camera) or picked (the gallery; a computer: a file) is turned upright, made a JPG of at most
 *     1600 px (and a small one of 480 px for the gallery) HERE, shown first, and sent only by "Save photo" (carPhotoSet) – the
 *     Admin and the Super Admin only (the server checks it too). Removed: carPhotoRemove (the file stays in the store). */
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'session.dart';

class CarPhoto {
  const CarPhoto({required this.t, required this.f, required this.exp, required this.v, this.err = false});
  /// the small picture's link, the whole picture's link, when they end (ms), the photo's own mark; err = no link now (asked again)
  final String t, f, v;
  final int exp;
  final bool err;
  static CarPhoto? of(Object? x) => x is Map
      ? CarPhoto(t: '${x['t'] ?? ''}', f: '${x['f'] ?? ''}', exp: (x['exp'] is num) ? (x['exp'] as num).toInt() : 0, v: '${x['v'] ?? ''}', err: x['err'] == true)
      : null;
  /// its links end within a minute and a half (or there are none now)
  bool get ending => err || t.isEmpty || exp - DateTime.now().millisecondsSinceEpoch < 90000;
}

/// The cars' photos of this site: their links (renewed by themselves) and their pictures (in memory, by the photo's mark).
class CarPhotos extends ChangeNotifier {
  CarPhotos._();
  static final CarPhotos i = CarPhotos._();
  /// (tests) how a picture is read from its link
  static Future<http.Response> Function(Uri) fetch = (u) => http.get(u).timeout(const Duration(seconds: 40));
  final Map<String, CarPhoto?> links = {};
  final Map<String, Uint8List> _pics = {};
  final List<String> _order = [];
  Future<void>? _fresh;
  int _freshAt = 0;

  CarPhoto? of(String no) => links[no];
  /// one car's photo as the server gives it now (null = none)
  void put(String no, Object? x) {
    final p = CarPhoto.of(x), was = links[no];
    links[no] = p;
    if (was?.v != p?.v || was?.t != p?.t || was?.err != p?.err) notifyListeners();
  }

  /// every car of an answer (the Dashboard's): the list as the server has it
  void putAll(Iterable<Map<String, dynamic>> cars) {
    for (final c in cars) {
      links['${c['no']}'] = CarPhoto.of(c['photo']);
    }
    notifyListeners();
  }

  void clear() {
    links.clear();
    _pics.clear();
    _order.clear();
  }

  /// new links of every car with a photo – one ask at a time; not again within 20 seconds unless [force]
  Future<void> renew(Session s, {bool force = false}) {
    if (_fresh != null) return _fresh!;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _freshAt < 20000) return Future.value();
    final nos = [for (final e in links.entries) if (e.value != null) e.key];
    if (nos.isEmpty) return Future.value();
    _freshAt = now;
    return _fresh = () async {
      try {
        final r = await s.api.call('getCarPhotoLinks', [{'nos': nos}]);
        final p = (r is Map ? r['photos'] : null);
        if (p is Map) {
          for (final no in nos) {
            if (p[no] != null) links[no] = CarPhoto.of(p[no]);
          }
          notifyListeners();
        }
      } catch (_) {/* asked again the next time a picture is wanted */} finally {
        _fresh = null;
      }
    }();
  }

  /// the picture of a car (small, or [full]): from memory, or by its link – a link that ends soon, or does not open, is renewed first
  Future<Uint8List?> picture(Session s, String no, {bool full = false}) async {
    final p0 = links[no];
    if (p0 == null) return null;
    final key = '${p0.v}|${full ? 'f' : 't'}';
    final kept = _pics[key];
    if (kept != null) return kept;
    if (p0.ending) await renew(s, force: true);
    for (var n = 0; n < 2; n++) {
      final q = links[no];
      if (q == null) return null;
      final url = full ? q.f : q.t;
      if (url.isNotEmpty) {
        try {
          final r = await fetch(Uri.parse(url));
          if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) return _keep(key, r.bodyBytes);
        } catch (_) {/* renewed below */}
      }
      if (n == 0) await renew(s, force: true);
    }
    throw Exception('The photo could not open.');
  }

  Uint8List _keep(String key, Uint8List b) {
    _pics[key] = b;
    _order.remove(key);
    _order.add(key);
    while (_order.length > 60) {
      _pics.remove(_order.removeAt(0));
    }
    return b;
  }

  /// a photo just saved: its pictures are already on the phone (nothing downloaded again)
  void keepMade(CarPhoto p, CarJpegs m) {
    _keep('${p.v}|t', m.thumb);
    _keep('${p.v}|f', m.full);
  }
}

/// A photo made ready on the phone: the whole one (≤ 1600 px) and the small one (≤ 480 px), both JPG.
class CarJpegs {
  CarJpegs(this.full, this.thumb, this.w, this.h, this.from);
  final Uint8List full, thumb;
  final int w, h, from;
  String get fullUrl => 'data:image/jpeg;base64,${base64Encode(full)}';
  String get thumbUrl => 'data:image/jpeg;base64,${base64Encode(thumb)}';
}

/// Why a picture cannot be a car's photo – said as it is.
class CarPhotoProblem implements Exception {
  CarPhotoProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The background work of this file (Flutter's compute) – a test runs it at once.
Future<R> Function<M, R>(ComputeCallback<M, R> callback, M message, {String? debugLabel}) carCompute = compute;

/// A picture taken or picked (JPG, PNG or WebP) → upright, the two JPGs within the server's sizes (2 MB / 400 KB). Off the screen's thread.
Future<CarJpegs> makeCarJpegs(Uint8List raw) => carCompute(carJpegsOf, raw);

CarJpegs carJpegsOf(Uint8List raw) {
  final d = img.decodeImage(raw);
  if (d == null) throw CarPhotoProblem('This picture cannot be read – pick a JPG, PNG or WebP photo.');
  final im = img.bakeOrientation(d);
  Uint8List jpg(int lim, int q, int max) {
    final k = lim / (im.width > im.height ? im.width : im.height);
    final s = k < 1 ? img.copyResize(im, width: (im.width * k).round(), height: (im.height * k).round(), interpolation: img.Interpolation.average) : im;
    var out = img.encodeJpg(s, quality: q);
    while (out.length > max && q > 40) {
      q -= 10;
      out = img.encodeJpg(s, quality: q);
    }
    if (out.length > max) throw CarPhotoProblem('This photo could not be made small enough – pick another.');
    return out;
  }

  final full = jpg(1600, 82, 2 * 1024 * 1024 - 1024), thumb = jpg(480, 78, 400 * 1024 - 1024);
  final k = 1600 / (im.width > im.height ? im.width : im.height);
  return CarJpegs(full, thumb, k < 1 ? (im.width * k).round() : im.width, k < 1 ? (im.height * k).round() : im.height, raw.length);
}

/// Sizes as people read them.
String sizeText(int n) => n >= 1048576 ? '${(n / 1048576).toStringAsFixed(1)} MB' : '${(n / 1024).round() < 1 ? 1 : (n / 1024).round()} KB';
