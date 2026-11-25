/* (3.171.0, his word of 23-11-2026: "app nasel tr ji app aahe tyatch open hoyla haw"; "jas ki bgh erp app madhe apan mark in button
 * diley te dable ki hr pn tya madhech open hot"; "falcon seprate pn chalayla pahije ani erp hr madeh pn chalayla pahije") FALCON
 * INSIDE THIS APP. The Mess card opens the FALCON app when it is on the phone (as before); when it is not, FALCON's own screens
 * open here as a page of this app – the FALCON app's own code (package "falcon", its lib/embed.dart), signed in with HR's pass
 * (no second sign-in), on FALCON's database and server with their own rules. Back on FALCON's home (or "Back to RCL app") returns
 * here. Android only, and only in a build that carries FALCON's settings (FALCON_SUPABASE_URL / _KEY / FALCON_SERVER) – else the
 * Mess card opens FALCON's web as before. */
import 'dart:async';
import 'dart:io' show Platform;

import 'package:falcon/embed.dart' as falcon;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/session.dart';

/// (tests) instead of the phone's platform
bool? falconInsideOnForTest;

/// (tests) instead of starting FALCON's database, settings and clock (its clock keeps a timer)
Future<void> Function()? falconStartForTest;

/// (tests) instead of FALCON's warm start / "made ready for him"
Future<bool> Function(String pass, String who)? falconWarmForTest;
bool Function(String who)? falconReadyForTest;

String _warming = '';
bool _forgetOn = false;

/// (3.171.0 patch 2, his word of 25-11-2026: "hr aso erp aso app open zalel zale tyache maghe auto falcon pn on hoil jene krun user jewa
/// hr or erp madhun mess order kade jato tya weli ek screen yete falcon opening chi ti yenar nahi") FALCON made ready BEHIND this app as
/// it opens (the Mess card is there): HR's pass → FALCON started, signed in as him, his home read. Once a person a run of the app;
/// nothing is shown; it ends with his sign-out here. [pass]: HR's pass (null – none).
Future<void> warmFalconInside(String who, Future<String?> Function() pass) async {
  if (!falconInsideOn || who.isEmpty || _warming == who) return;
  _warming = who;
  if (!_forgetOn) {
    _forgetOn = true;
    Session.signOutAlso.add(forgetFalconInside);
  }
  try {
    final p = await pass();
    if (p == null || !await (falconWarmForTest ?? falcon.falconWarm)(p, who)) _warming = '';
  } catch (_) {
    _warming = '';
  }
}

/// FALCON is ready for him (made ready behind this app): Mess opens straight on its home.
bool falconReadyFor(String who) => falconInsideOn && (falconReadyForTest ?? falcon.falconWarmFor)(who);

/// He signed out here: FALCON's sign-in on this phone ends too.
Future<void> forgetFalconInside() async {
  _warming = '';
  if (falconInsideOn && falconWarmForTest == null) await falcon.falconForget();
}

/// May FALCON open inside this app here?
bool get falconInsideOn => falconInsideOnForTest ?? (!kIsWeb && Platform.isAndroid && falcon.falconReady);

/// Opens FALCON's screens as a page of this app with HR's pass ('' – made ready: on its home). false = it cannot here.
Future<bool> openFalconInside(BuildContext context, String pass) async {
  if (!falconInsideOn) return false;
  await (falconStartForTest ?? falcon.falconStart)();
  if (!context.mounted) return false;
  final nav = Navigator.of(context);
  unawaited(nav.push(MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'falcon'),
    builder: (c) => falcon.FalconInApp(key: const Key('falcon-inside'), pass: pass, onLeave: () => Navigator.of(c).pop()),
  )));
  return true;
}
