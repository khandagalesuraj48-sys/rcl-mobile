/* (3.165.0, asked 21-11-2026: "play store war gel ki updet nit hotil … mala mazya user la app updet kra he sangat basaych nahiye …
 * in app updet sadh updet he tr lawaych aahech") THE PLAY STORE'S APP (built with --dart-define=PLAY=true, the package
 * si.sketchline.lion): its update comes from Google Play only – the app's own download of a file (core/update.dart, GitHub
 * Releases) is not used in it, as Play's rules ask.
 *
 *  · Play's own auto-update puts a new version in by itself (the phone's Play Store setting – no app can switch it on or off);
 *  · beside it, Google's "in-app update" (flexible): when the app is opened and Play has a newer version, Google's own sheet
 *    "Update available" comes once; Update → it downloads in the background while he works on;
 *  · the downloaded update is put in when the app is STARTED the next time (never in the middle of his work – an entry half
 *    typed is not lost), or at once from Me ("Install now").
 *
 * The app that is given by its file (the package in.rachana.rcl.rcl_mobile) is not changed by any of this: [onPlay] is false. */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// This app was built for Google Play.
const bool kPlay = bool.fromEnvironment('PLAY');

/// The same, as a function – a test puts its own here.
bool Function() onPlay = () => kPlay;

/// The Play Store's app.
const kPlayId = 'si.sketchline.lion';
const kPlayPage = 'https://play.google.com/store/apps/details?id=$kPlayId';

/// What Play has for this phone: nothing newer · a newer version · a newer version downloaded, waiting to be put in.
enum PlayHas { none, there, ready }

/// Google Play's part. A test puts its own in [PlayKit.kit].
class PlayKit {
  static PlayKit kit = PlayKit();

  Future<PlayHas> look() async {
    final i = await InAppUpdate.checkForUpdate();
    if (i.installStatus == InstallStatus.downloaded) return PlayHas.ready;
    if (i.updateAvailability == UpdateAvailability.updateAvailable && i.flexibleUpdateAllowed) return PlayHas.there;
    return PlayHas.none;
  }

  /// Google's sheet "Update available"; true: he said Update and it is downloaded (or downloading).
  Future<bool> fetch() async => (await InAppUpdate.startFlexibleUpdate()) == AppUpdateResult.success;

  /// The downloaded update is put in – the app starts again.
  Future<void> install() => InAppUpdate.completeFlexibleUpdate();

  /// The app's own page in the Play Store (its ⋮ menu has "Enable auto update").
  Future<bool> openStore() async {
    try {
      if (await launchUrl(Uri.parse('market://details?id=$kPlayId'), mode: LaunchMode.externalApplication)) return true;
    } catch (_) {/* no Play Store app: the web page below */}
    try {
      return await launchUrl(Uri.parse(kPlayPage), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

/// A downloaded update waits (Me shows "Install now").
final playReady = ValueNotifier<bool>(false);

/// Google's sheet is not shown again in the same opening (a new opening: back after this long, or a new start).
const kPlayAskAgain = Duration(minutes: 10);
bool _busy = false;
DateTime? _asked;

/// What Play has, or [PlayHas.none] when it cannot be asked (no Play Store, no network, not Play's app) – the app works on.
Future<PlayHas> playLook() async {
  if (!onPlay()) return PlayHas.none;
  try {
    final h = await PlayKit.kit.look();
    playReady.value = h == PlayHas.ready;
    return h;
  } catch (_) {
    return PlayHas.none;
  }
}

/// When the app is started ([start]) or comes back: a downloaded update is put in at the START only; a newer version is offered by
/// Google's sheet once in an opening ([asked]: he pressed "Check for update" – offered again).
Future<PlayHas> playWatch({bool start = false, bool asked = false, DateTime? now}) async {
  if (!onPlay() || _busy) return PlayHas.none;
  _busy = true;
  try {
    final h = await playLook();
    if (h == PlayHas.ready) {
      if (start) await PlayKit.kit.install();
      return h;
    }
    if (h != PlayHas.there) return h;
    final t = now ?? DateTime.now();
    if (!asked && _asked != null && t.difference(_asked!) < kPlayAskAgain) return h;
    _asked = t;
    if (await PlayKit.kit.fetch()) await playLook();
    return h;
  } catch (_) {
    return PlayHas.none;
  } finally {
    _busy = false;
  }
}

/// "Install now" (Me): the downloaded update is put in, the app starts again. False: nothing was waiting / it could not be done.
Future<bool> playInstall() async {
  if (!onPlay() || !playReady.value) return false;
  try {
    await PlayKit.kit.install();
    return true;
  } catch (_) {
    return false;
  }
}

/// (a test) as at a new start
void resetPlayUpdate() {
  _busy = false;
  _asked = null;
  playReady.value = false;
  onPlay = () => kPlay;
  PlayKit.kit = PlayKit();
}
