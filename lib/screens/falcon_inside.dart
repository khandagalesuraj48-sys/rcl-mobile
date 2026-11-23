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

/// (tests) instead of the phone's platform
bool? falconInsideOnForTest;

/// (tests) instead of starting FALCON's database, settings and clock (its clock keeps a timer)
Future<void> Function()? falconStartForTest;

/// May FALCON open inside this app here?
bool get falconInsideOn => falconInsideOnForTest ?? (!kIsWeb && Platform.isAndroid && falcon.falconReady);

/// Opens FALCON's screens as a page of this app with HR's pass. false = it cannot here (the caller opens the web).
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
