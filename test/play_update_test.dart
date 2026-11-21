// (3.165.0, asked 21-11-2026: "play store war gel ki updet nit hotil … in app updet sadh updet he tr lawaych aahech") The Play
// Store's app (lib/core/play_update.dart): its update is Google Play's – asked once in an opening, downloaded while he works, put in
// at the next START only (never in the middle of his work) or from Me; the app given by its file is not touched by any of it.
// Google Play's part is a stand-in here (PlayKit.kit).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/app_share.dart';
import 'package:rcl_mobile/core/play_update.dart';

class _Play extends PlayKit {
  PlayHas has = PlayHas.none;
  bool says = true, broken = false;
  final calls = <String>[];
  @override
  Future<PlayHas> look() async {
    calls.add('look');
    if (broken) throw StateError('no Play Store');
    return has;
  }

  @override
  Future<bool> fetch() async {
    calls.add('fetch');
    if (says) has = PlayHas.ready; // downloaded
    return says;
  }

  @override
  Future<void> install() async => calls.add('install');
  @override
  Future<bool> openStore() async {
    calls.add('store');
    return true;
  }
}

void main() {
  late _Play play;
  setUp(() {
    resetPlayUpdate();
    PlayKit.kit = play = _Play();
    onPlay = () => true;
  });
  tearDown(resetPlayUpdate);

  test('the app given by its file: Google Play is never asked', () async {
    onPlay = () => false;
    play.has = PlayHas.there;
    expect(await playWatch(start: true), PlayHas.none);
    expect(await playLook(), PlayHas.none);
    expect(await playInstall(), false);
    expect(play.calls, isEmpty);
  });

  test('a newer version: Google\'s sheet once in an opening – again when he asks, and after 10 minutes away', () async {
    play.has = PlayHas.there;
    play.says = false; // he closes Google's sheet
    final t0 = DateTime(2026, 11, 21, 10);
    expect(await playWatch(now: t0), PlayHas.there);
    expect(play.calls.where((c) => c == 'fetch').length, 1);
    await playWatch(now: t0.add(const Duration(minutes: 3)));
    expect(play.calls.where((c) => c == 'fetch').length, 1, reason: 'the same opening: not asked again');
    await playWatch(asked: true, now: t0.add(const Duration(minutes: 4)));
    expect(play.calls.where((c) => c == 'fetch').length, 2, reason: '"Check for update" asks again');
    await playWatch(now: t0.add(const Duration(minutes: 20)));
    expect(play.calls.where((c) => c == 'fetch').length, 3, reason: 'a new opening');
    expect(play.calls, isNot(contains('install')));
    expect(playReady.value, false);
  });

  test('Update: downloaded while he works – NOT put in while the app is in use; "Install now" does it', () async {
    play.has = PlayHas.there;
    await playWatch();
    expect(playReady.value, true);
    expect(play.calls, isNot(contains('install')));
    await playWatch(); // the app comes back: still not installed by itself
    expect(play.calls, isNot(contains('install')));
    expect(await playInstall(), true);
    expect(play.calls.last, 'install');
  });

  test('a downloaded update is put in when the app is STARTED the next time', () async {
    play.has = PlayHas.ready;
    expect(await playWatch(start: true), PlayHas.ready);
    expect(play.calls, ['look', 'install']);
  });

  test('Google Play cannot be asked (no Play Store, no network): the app works on, nothing is said', () async {
    play.broken = true;
    expect(await playWatch(start: true), PlayHas.none);
    expect(await playLook(), PlayHas.none);
    expect(playReady.value, false);
  });

  test('Share app: the Play Store\'s app shares its page in the Play Store, the app given by its file its own page', () {
    expect(appShareText(), contains('https://play.google.com/store/apps/details?id=si.sketchline.lion'));
    onPlay = () => false;
    expect(appShareText(), contains(kAppPage));
    expect(appShareText(), isNot(contains('play.google.com')));
  });

  test('the build: the Play package and name only with RCL_STORE=play; no "install a file" permission there; the own update is off', () {
    final g = File('android/app/build.gradle.kts').readAsStringSync(), o = File('android/app/src/play/AndroidManifest.xml').readAsStringSync();
    expect(g, contains('System.getenv("RCL_STORE") == "play"'));
    expect(g, contains('applicationId = if (playStore) "si.sketchline.lion" else "in.rachana.rcl.rcl_mobile"'));
    expect(g, contains('if (playStore) sourceSets.getByName("release").manifest.srcFile("src/play/AndroidManifest.xml")'));
    expect(g, contains('namespace = "si.sketchline.lion"'), reason: 'the code\'s own name is the new one for both');
    expect(Directory('android/app/src/main/kotlin/in').existsSync(), false, reason: 'no class under the old name');
    expect(File('android/app/src/main/kotlin/si/sketchline/lion/MainActivity.kt').readAsStringSync(), contains('package si.sketchline.lion'));
    expect(o, contains('<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" tools:node="remove"/>'));
    expect(o, contains('android:label="Sketchline Lion" tools:replace="android:label"'), reason: 'his correction of 21-11-2026: the application\'s name is Sketchline Lion');
    expect(o, contains('sk.fourq.otaupdate.OtaUpdateFileProvider'));
    // the app of today keeps its permission and its name
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
    expect(m, contains('android:label="Sketchline"'));
    final u = File('lib/core/update.dart').readAsStringSync();
    expect(u, contains('if (onPlay()) return null;'), reason: 'no file of ours is looked for in the Play Store\'s app');
    expect(u, contains('Platform.isAndroid && !onComputer && !onPlay()'), reason: 'no background download of a file there');
    final w = File('.github/workflows/play.yml').readAsStringSync();
    expect(w, contains('flutter build appbundle --release'));
    expect(w, contains('--dart-define=PLAY=true'));
    expect(w, contains('RCL_STORE: play'));
    expect(w, isNot(contains('gh release')), reason: 'the Play build makes no release – the phones of today are not touched');
  });
}
