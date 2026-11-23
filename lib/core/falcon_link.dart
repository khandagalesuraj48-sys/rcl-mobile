/* FALCON – THE SITE MESS – FROM HR (23-11-2026, his decision: "falcon la erp madhe nahi hr madhe jodaych karan erp main aahe erp madhe
 * hr aahe ani falcon hr madhe asel … erp sathi pn jas apan attendance sathi keley te ethe pn ek asel"; the pictures N6 – the HR Home's
 * "Mess" card – and N7 – the ERP Home's "Mess" strip under Mark IN – approved: "ho banaw").
 * FALCON (Food & Site Operations, Sketchline Industries) is its own app with its own database. HR only vouches for the person:
 *   * [FalconMess.card] – HR's `falconCard`: his site's messes, where they are, the meal on now (FALCON's clock), today's dishes;
 *     kept 5 minutes on this phone. Not connected / no mess: no card at all.
 *   * [FalconMess.open] – HR's `falconPass` (2 minutes, once): FALCON's own app is opened with it (Android, the explicit package
 *     si.sketchline.falcon – no other app can take it); not on the phone (or an iPhone): FALCON's web in the browser.
 *   * [messNow] – the nearest mess and whether he is at it (inside its metres – the phone's own uncertainty counted up to 50 m).
 * The phone's place is the attendance's own reading (core/attend.dart AttendWhere) – nothing of it is sent anywhere. */
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'session.dart';

typedef HrAsk = Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

class FalconMess {
  static Map<String, dynamic>? _card;
  static int _at = 0;
  static String _who = '';
  static const _keep = 5 * 60 * 1000;
  static const _ch = MethodChannel('rcl/falcon');
  /// (tests) how the web is opened when FALCON's app is not there – the phone's browser otherwise
  static Future<bool> Function(Uri u)? launchHook;

  /// (3.169.0, asked 23-11-2026: "ajun mala ERP and HR madhe FALCON connect disat nahiye") why there is no card – HR's words (not
  /// connected, FALCON did not answer …) or "no mess at this site yet"; '' when the card is there. Shown to the Super Admin only.
  static String why = '';

  /// The Mess card of his site, or null (not connected, no mess, no answer) – asked again after 5 minutes.
  static Future<Map<String, dynamic>?> card(Session s, HrAsk ask, {bool fresh = false}) async {
    final who = s.email, now = DateTime.now().millisecondsSinceEpoch;
    if (!fresh && who == _who && _card != null && now - _at < _keep) return _card;
    try {
      final r = await ask({'action': 'falconCard'});
      final list = (r['messes'] as List? ?? const []).whereType<Map>().toList();
      _card = list.isEmpty ? null : r;
      why = list.isEmpty ? 'FALCON is connected – no mess of ${r['site'] ?? 'this site'} is in FALCON yet (FALCON web → Mess and contractors).' : '';
    } catch (e) {
      _card = null;
      final m = '$e'.replaceFirst(RegExp(r'^[A-Za-z]*(Exception|Error): ?'), '');
      why = m.isEmpty || m == 'none' ? '' : m;
    }
    _who = who;
    _at = now;
    return _card;
  }

  static void forget() {
    _card = null;
    why = '';
    _who = '';
    _at = 0;
  }

  /// Opens FALCON signed in as him. Returns '' when opened, else the words of the problem (shown by the caller).
  /// (3.171.0, his word of 23-11-2026: "app nasel tr ji app aahe tyatch open hoyla haw … falcon seprate pn chalayla pahije ani erp hr
  /// madeh pn") [inside]: FALCON's own screens inside THIS app when the FALCON app is not on the phone (true = opened); the web
  /// stays only for a phone where that cannot be (an app built without FALCON's settings, an iPhone).
  static Future<String> open(HrAsk ask, {Future<bool> Function(Uri u)? launch, Future<bool> Function(String pass)? inside}) async {
    Map<String, dynamic> r;
    try {
      r = await ask({'action': 'falconPass'});
    } catch (e) {
      final m = '$e'.replaceFirst(RegExp(r'^[A-Za-z]*(Exception|Error): ?'), '');
      return m.isEmpty ? 'FALCON could not be opened – try again.' : m;
    }
    final pass = '${r['pass'] ?? ''}', web = '${r['web'] ?? ''}';
    if (!RegExp(r'^v1\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]{43}$').hasMatch(pass)) return 'FALCON could not be opened – try again.';
    try {
      if (await _ch.invokeMethod<bool>('open', {'pass': pass}) == true) return '';
    } catch (_) {/* not Android / not there: inside this app, else the web */}
    if (inside != null) {
      try {
        if (await inside(pass)) return '';
      } catch (_) {/* FALCON could not start here: the web */}
    }
    if (!RegExp(r'^https://[A-Za-z0-9.-]+(:\d+)?$').hasMatch(web)) return 'FALCON is not on this phone.';
    final u = Uri.parse('$web/#hrpass=${Uri.encodeComponent(pass)}');
    final ok = await (launch ?? launchHook ?? (x) => launchUrl(x, mode: LaunchMode.externalApplication))(u);
    return ok ? '' : 'FALCON could not be opened – try again.';
  }
}

/// The mess for him now: the nearest one with a place (else the first), how far, whether he is at it, its meal.
class MessNow {
  MessNow(this.name, this.metres, this.at, this.meal, this.from, this.to, this.now, this.dishes);
  final String name;
  final int? metres; // null – his place or the mess's place is not known
  final bool at;
  final String meal, from, to; // meal '' – nothing more today
  final bool now; // the meal is being served now
  final List<String> dishes;
}

int metresBetween(double aLat, double aLng, double bLat, double bLng) {
  const r = 6371000.0, d = math.pi / 180;
  final dLat = (bLat - aLat) * d, dLng = (bLng - aLng) * d;
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(aLat * d) * math.cos(bLat * d) * math.pow(math.sin(dLng / 2), 2);
  return (2 * r * math.asin(math.min(1, math.sqrt(h)))).round();
}

String distText(int m) => m < 1000 ? '$m m' : '${(m / 1000).toStringAsFixed(m < 10000 ? 1 : 0)} km';

MessNow? messNow(Map<String, dynamic>? card, {double? lat, double? lng, double acc = 0}) {
  final list = (card?['messes'] as List? ?? const []).whereType<Map>().toList();
  if (list.isEmpty) return null;
  double? n(Object? v) => v is num ? v.toDouble() : null;
  Map best = list.first;
  int? bestM;
  if (lat != null && lng != null) {
    for (final m in list) {
      final la = n(m['lat']), ln = n(m['lng']);
      if (la == null || ln == null) continue;
      final d = metresBetween(lat, lng, la, ln);
      if (bestM == null || d < bestM) {
        bestM = d;
        best = m;
      }
    }
  }
  final r = n(best['radius_m']) ?? 100;
  final at = bestM != null && bestM - math.min(acc, 50) <= r;
  final meal = best['meal'] is Map ? best['meal'] as Map : const {};
  return MessNow('${best['name'] ?? 'Mess'}', bestM, at, '${meal['meal'] ?? ''}', '${meal['from'] ?? ''}', '${meal['to'] ?? ''}', meal['now'] == true,
      [for (final d in (best['dishes'] as List? ?? const [])) '$d']);
}

String mealWord(String m) => m.isEmpty ? '' : m[0].toUpperCase() + m.substring(1);
