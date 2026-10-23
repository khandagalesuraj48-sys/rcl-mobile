// (3.31.4) The update in the background (lib/core/update.dart + UpdateKit.kt; asked 23-10-2026: "app madhun baher al ki updet hoych
// band hot … background la app updet chaluch asel ani complte al ki konte hi screen war aso mi install karaychi as ek pop up eil"):
// Android's Download Manager downloads it (it goes on when the app is left); a download already going is never started again from 0;
// when it is there and its fingerprint is right, "Install?" comes over whatever screen is open; "Later" – asked again when the app
// is opened again; a wrong file is never offered. The phone's side is a stand-in here (bgCall).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/update.dart';

void main() {
  final calls = <String>[];
  final args = <String, Map<String, Object?>>{};
  Map<String, Object?>? kept; // the download the phone keeps
  var good = 'a' * 64; // the fingerprint of the file on the phone
  final u = AppUpdate(build: 140, version: '3.31.4', notes: 'What is new', url: 'https://github.com/x/rcl-erp-3.31.4-140.arm64-v8a.apk', sha256: 'A' * 64);

  setUp(() {
    calls.clear();
    args.clear();
    kept = null;
    good = 'a' * 64;
    bgUpdates = () => true;
    appBuild = () async => 139;
    fileSha = (p) async => good;
    bgCall = (m, [a]) async {
      calls.add(m);
      if (a != null) args[m] = a;
      switch (m) {
        case 'state':
          return kept ?? <String, Object?>{};
        case 'start':
          kept = {'id': 1, 'path': '/phone/files/Download/${a!['file']}', 'version': a['version'], 'build': a['build'], 'sha': a['sha'], 'status': 'running', 'got': 0, 'total': 1000};
          return 1;
        case 'forget':
          kept = null;
          return true;
        case 'install':
          return 'ok';
        case 'clearNote':
          return true;
      }
      return null;
    };
  });
  tearDown(resetBgUpdate);

  Future<void> settle(WidgetTester t, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
  }

  test('Update starts Android\'s download with the release\'s file, build and fingerprint; pressed again while it goes: never again from 0', () async {
    expect(await startBgUpdate(u), 'started');
    expect(calls.where((c) => c == 'start').length, 1);
    expect(args['start'], {'url': u.url, 'file': 'rcl-erp-3.31.4-140.apk', 'version': '3.31.4', 'build': 140, 'sha': 'a' * 64});
    kept!['got'] = 400;
    expect(await startBgUpdate(u), 'going', reason: 'the same update is downloading: it goes on');
    expect(calls.where((c) => c == 'start').length, 1, reason: 'not started again from 0');
    expect(bgUpdateNow.value?.percent, 40);
  });

  test('a newer release than the one kept: the new one is downloaded; a phone without the Download Manager: as before (failed → the old way)', () async {
    kept = {'id': 1, 'path': '/p/old.apk', 'version': '3.31.3', 'build': 140, 'sha': 'b' * 64, 'status': 'running', 'got': 10, 'total': 100};
    final newer = AppUpdate(build: 141, version: '3.31.5', url: 'https://github.com/x/rcl-erp-3.31.5-141.apk', sha256: 'c' * 64);
    expect(await startBgUpdate(newer), 'started');
    expect(args['start']!['build'], 141);
    bgUpdates = () => false;
    expect(await startBgUpdate(newer), 'failed');
    resetBgUpdate();
    bgUpdates = () => true;
    bgCall = (m, [a]) async => m == 'start' ? throw Exception('Unknown URL content://downloads/my_downloads') : <String, Object?>{};
    expect(await startBgUpdate(newer), 'failed', reason: 'the Download Manager switched off on this phone');
  });

  test('installed (the app\'s build is the downloaded one): its file goes', () async {
    kept = {'id': 1, 'path': '/p/rcl.apk', 'version': '3.31.4', 'build': 140, 'sha': 'a' * 64, 'status': 'done', 'got': 100, 'total': 100};
    appBuild = () async => 140;
    await updateWatch(opened: true);
    expect(calls, contains('forget'));
    expect(kept, isNull);
    expect(bgUpdateNow.value, isNull);
  });

  testWidgets('downloaded while away: "Install?" over whatever screen is open – Install hands the file to Android', (t) async {
    final nav = GlobalKey<NavigatorState>();
    updateContext = () => nav.currentContext;
    addTearDown(() => updateContext = () => null);
    kept = {'id': 1, 'path': '/phone/files/Download/rcl-erp-3.31.4-140.apk', 'version': '3.31.4', 'build': 140, 'sha': 'a' * 64, 'status': 'done', 'got': 1000, 'total': 1000};
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: const Scaffold(body: Center(child: Text('any screen of the app')))));
    unawaited(updateWatch(opened: true));
    await settle(t);
    expect(find.text('Update 3.31.4 is ready'), findsOneWidget);
    expect(find.text('any screen of the app'), findsOneWidget, reason: 'over the screen that was open');
    expect(calls, contains('clearNote'), reason: 'the notification "Update ready" goes – the app asks itself');
    await t.tap(find.text('Install'));
    await settle(t);
    expect(args['install'], {'path': '/phone/files/Download/rcl-erp-3.31.4-140.apk'});
    expect(find.text('Update 3.31.4 is ready'), findsNothing);
    resetBgUpdate();
  });

  testWidgets('"Later": not asked again while the app stays on the screen; asked again when the app is opened again', (t) async {
    final nav = GlobalKey<NavigatorState>();
    updateContext = () => nav.currentContext;
    addTearDown(() => updateContext = () => null);
    kept = {'id': 1, 'path': '/p/rcl-erp-3.31.4-140.apk', 'version': '3.31.4', 'build': 140, 'sha': 'a' * 64, 'status': 'done', 'got': 1000, 'total': 1000};
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('home'))));
    unawaited(updateWatch(opened: true));
    await settle(t);
    await t.tap(find.text('Later'));
    await settle(t);
    expect(find.text('Update 3.31.4 is ready'), findsNothing);
    unawaited(updateWatch());
    await settle(t);
    expect(find.text('Update 3.31.4 is ready'), findsNothing, reason: 'Later: not again at once');
    expect(calls, isNot(contains('install')));
    unawaited(updateWatch(opened: true));
    await settle(t);
    expect(find.text('Update 3.31.4 is ready'), findsOneWidget, reason: 'the app opened again: asked again');
    resetBgUpdate();
  });

  testWidgets('a file whose fingerprint is not the release\'s: never offered – taken out, said', (t) async {
    final nav = GlobalKey<NavigatorState>();
    updateContext = () => nav.currentContext;
    addTearDown(() => updateContext = () => null);
    good = 'f' * 64;
    kept = {'id': 1, 'path': '/p/rcl.apk', 'version': '3.31.4', 'build': 140, 'sha': 'a' * 64, 'status': 'done', 'got': 1000, 'total': 1000};
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('home'))));
    unawaited(updateWatch(opened: true));
    await settle(t);
    expect(find.text('Update 3.31.4 is ready'), findsNothing);
    expect(calls, contains('forget'));
    expect(calls, isNot(contains('install')));
    expect(find.textContaining('not complete or not genuine'), findsOneWidget);
    resetBgUpdate();
  });

  testWidgets('Update: asked, downloading with its percent; "Keep working" closes the box – the download goes on; ready → "Install?"', (t) async {
    final nav = GlobalKey<NavigatorState>();
    updateContext = () => nav.currentContext;
    addTearDown(() => updateContext = () => null);
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => runUpdate(c, u), child: const Text('go')))))));
    await t.tap(find.text('go'));
    await settle(t);
    expect(find.text('Update to 3.31.4?'), findsOneWidget);
    expect(find.textContaining('downloads in the background'), findsOneWidget);
    await t.tap(find.text('Update'));
    await settle(t);
    expect(calls, contains('start'));
    expect(find.text('Updating'), findsOneWidget);
    kept!['got'] = 250;
    await t.pump(const Duration(seconds: 2)); // the watch every 2 s
    await settle(t, 4);
    expect(find.text('Downloading… 25%'), findsOneWidget);
    await t.tap(find.byKey(const Key('upd-bg-hide')));
    await settle(t);
    expect(find.text('Updating'), findsNothing);
    expect(calls, isNot(contains('forget')), reason: 'closing the box does not stop the download');
    kept!['status'] = 'done';
    kept!['got'] = 1000;
    await t.pump(const Duration(seconds: 2));
    await settle(t);
    expect(find.text('Update 3.31.4 is ready'), findsOneWidget);
    // pressed Update again later: no question, no new download – "Install?" again
    await t.tap(find.text('Later'));
    await settle(t);
    await t.tap(find.text('go'));
    await settle(t);
    expect(find.text('Update to 3.31.4?'), findsNothing);
    expect(calls.where((c) => c == 'start').length, 1);
    expect(find.text('Update 3.31.4 is ready'), findsOneWidget);
    resetBgUpdate();
  });
}
