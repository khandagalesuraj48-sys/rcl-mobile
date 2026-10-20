/* (3.19.0, asked 17-10-2026: "windows ... app banaw direct app ya windows war chaltil browser open krnechi garaj nahi updet pn in
 * app ch yeil") THE COMPUTER APP (Windows): the same screens; the phone's camera tools (QR scanner, number plate) are not
 * offered, a photo is chosen from a file; a made file is saved in Downloads ("a (2).xlsx" when one is there); the update is the
 * Windows setup of the newest release – downloaded, its fingerprint checked, then run (it closes the app and opens the new one). */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/device.dart';
import 'package:rcl_mobile/core/lang.dart';
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/core/update.dart';
import 'package:rcl_mobile/main.dart';
import 'package:rcl_mobile/web/files.dart' show freeFile;

import 'fake_server.dart';

Future<void> loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final f in manifest) {
    final loader = FontLoader(f['family'] as String);
    for (final a in f['fonts'] as List) {
      loader.addFont(rootBundle.load(a['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> settle(WidgetTester t, [int ms = 1800]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> net(WidgetTester t, [int ms = 1200]) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await settle(t, ms);
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await settle(t, 400);
}

Future<Session> ready(WidgetTester t, FakeServer srv) async {
  final s = Session(Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: srv.client))..clock = () => DateTime(2026, 10, 14, 10, 30);
  await t.runAsync(() async {
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
  });
  return s;
}

Future<void> pics(WidgetTester t) async {
  await t.runAsync(() async {
    for (final e in t.widgetList<Image>(find.byType(Image))) {
      final c = Completer<void>();
      final st = e.image.resolve(ImageConfiguration.empty);
      late ImageStreamListener l;
      l = ImageStreamListener((_, __) {
        if (!c.isCompleted) c.complete();
        st.removeListener(l);
      }, onError: (_, __) {
        if (!c.isCompleted) c.complete();
      });
      st.addListener(l);
      await c.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    }
  });
  await t.pump();
}

/// The window the computer app opens with (windows/runner/main.cpp): 560 × 900, at 125 % (a usual laptop).
void window(WidgetTester t) {
  t.view.physicalSize = const Size(700, 1125);
  t.view.devicePixelRatio = 1.25;
  addTearDown(t.view.reset);
}

void main() {
  setUpAll(loadFonts);
  setUp(() => computerForTest = true);
  tearDown(() {
    computerForTest = null;
    return Lang.i.set('');
  });

  group('the release', () {
    final apkSha = 'a' * 64, winSha = 'b' * 64;
    Map<String, dynamic> rel({String? meta, List<Map<String, dynamic>>? assets}) => {
          'name': 'RCL ERP 3.19.0 (122)',
          'draft': false,
          'prerelease': false,
          'body': 'New.\n\n${meta ?? '<!-- rcl:{"build":122,"version":"3.19.0","sha256":"$apkSha","win":"$winSha"} -->'}',
          'assets': assets ??
              [
                {'name': 'rcl-erp-3.19.0-122.apk', 'browser_download_url': 'https://github.com/khandagalesuraj48-sys/rcl-mobile/releases/download/v3.19.0-122/rcl-erp-3.19.0-122.apk'},
                {'name': 'RCL-ERP-Setup-3.19.0-122.exe', 'browser_download_url': 'https://github.com/khandagalesuraj48-sys/rcl-mobile/releases/download/v3.19.0-122/RCL-ERP-Setup-3.19.0-122.exe'},
              ],
        };

    test('a computer takes the Windows setup and its own fingerprint; a phone the APK and its own', () {
      final w = parseRelease(rel(), 121, computer: true)!;
      expect(w.url, endsWith('/RCL-ERP-Setup-3.19.0-122.exe'));
      expect(w.sha256, winSha);
      expect(w.build, 122);
      final a = parseRelease(rel(), 121)!;
      expect(a.url, endsWith('/rcl-erp-3.19.0-122.apk'));
      expect(a.sha256, apkSha);
    });
    test('(3.24.0) what is new: the notes between <!-- rcl-new --> and <!-- /rcl-new --> – English, मराठी, हिंदी as written; else the name', () {
      const n = 'What is new in 3.19.0:\n• Vendor BOQ: the amendment letter\n\nनवीन काय (3.19.0):\n• Vendor BOQ: amendment पत्र\n\nनया क्या है (3.19.0):\n• Vendor BOQ: संशोधन पत्र';
      final r = rel()..['body'] = '<!-- rcl-new -->\n$n\n<!-- /rcl-new -->\n\nRCL ERP 3.19.0 (122) – Android and Windows.\n\n<!-- rcl:{"build":122,"version":"3.19.0","sha256":"$apkSha","win":"$winSha"} -->';
      expect(parseRelease(r, 121)!.notes, n);
      expect(parseRelease(r, 121, computer: true)!.notes, n);
      expect(parseRelease(rel(), 121)!.notes, 'RCL ERP 3.19.0 (122)', reason: 'a release without them: its name, as before');
    });
    test('a computer takes nothing from a release without the setup or without its fingerprint (an Android-only release)', () {
      expect(parseRelease(rel(meta: '<!-- rcl:{"build":122,"version":"3.19.0","sha256":"$apkSha"} -->'), 121, computer: true), isNull);
      expect(parseRelease(rel(assets: [{'name': 'rcl-erp-3.19.0-122.apk', 'browser_download_url': 'https://github.com/x/rcl.apk'}]), 121, computer: true), isNull);
      expect(parseRelease(rel(assets: [{'name': 'RCL-ERP-Setup.exe', 'browser_download_url': 'https://evil.example/RCL-ERP-Setup.exe'}]), 121, computer: true), isNull, reason: 'a file from another site');
      expect(parseRelease(rel(), 122, computer: true), isNull, reason: 'the same build');
    });
  });

  group('the setup downloaded', () {
    final body = List<int>.generate(4000, (i) => i * 7 % 256);
    final good = sha256.convert(body).toString();
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('rcl_up'));
    tearDown(() {
      updateClient = http.Client.new;
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    AppUpdate up(String sha) => AppUpdate(build: 122, version: '3.19.0', url: 'https://github.com/x/RCL-ERP-Setup-3.19.0-122.exe', sha256: sha);
    void serve(int code) => updateClient = () => MockClient.streaming((req, _) async {
          expect(req.url.toString(), 'https://github.com/x/RCL-ERP-Setup-3.19.0-122.exe');
          return http.StreamedResponse(Stream.fromIterable([for (var i = 0; i < 4; i++) body.sublist(i * 1000, i * 1000 + 1000)]), code, contentLength: body.length);
        });

    test('genuine: kept (the older setup taken out), the percent told as it comes', () async {
      File('${dir.path}/RCL-ERP-Setup-3.18.9-120.exe').writeAsBytesSync([1, 2, 3]);
      serve(200);
      final seen = <int>[];
      final path = await downloadSetup(up(good), dir, seen.add);
      expect(path, endsWith('RCL-ERP-Setup-3.19.0-122.exe'));
      expect(File(path).readAsBytesSync(), body);
      expect(seen, [25, 50, 75, 100]);
      expect(dir.listSync().length, 1, reason: 'the setup of before is gone');
    });
    test('not genuine (another fingerprint): nothing kept, nothing run – said so', () async {
      serve(200);
      await expectLater(downloadSetup(up('c' * 64), dir, (_) {}), throwsA(isA<UpdateProblem>().having((e) => e.message, 'message', 'The download was not complete or not genuine – nothing was installed. Try again.')));
      expect(dir.listSync(), isEmpty);
    });
    test('the server says no: said so', () async {
      serve(404);
      await expectLater(downloadSetup(up(good), dir, (_) {}), throwsA(isA<UpdateProblem>().having((e) => e.message, 'message', 'The update could not be downloaded – check the internet and try again.')));
    });
  });

  test('a made file in Downloads: its own name, else "name (2)", "name (3)" – as a browser', () {
    final d = Directory.systemTemp.createTempSync('rcl_dl');
    addTearDown(() => d.deleteSync(recursive: true));
    expect(freeFile(d.path, 'Water tankers.xlsx').path, endsWith('Water tankers.xlsx'));
    File('${d.path}/Water tankers.xlsx').writeAsStringSync('x');
    expect(freeFile(d.path, 'Water tankers.xlsx').path, endsWith('Water tankers (2).xlsx'));
    File('${d.path}/Water tankers (2).xlsx').writeAsStringSync('x');
    expect(freeFile(d.path, 'Water tankers.xlsx').path, endsWith('Water tankers (3).xlsx'));
    expect(freeFile(d.path, 'README').path, endsWith('README'));
  });

  testWidgets('the update on a computer: asked, downloaded, checked, the setup run (it closes the app and opens the new one)', (t) async {
    final body = utf8.encode('the setup');
    final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}rcl_update');
    final run = <String>[];
    final before = startSetup;
    startSetup = (p) async => run.add(p);
    updateClient = () => MockClient((_) async => http.Response.bytes(body, 200));
    addTearDown(() {
      startSetup = before;
      updateClient = http.Client.new;
    });
    final u = AppUpdate(build: 122, version: '3.19.0', notes: 'RCL ERP 3.19.0 (122)', url: 'https://github.com/x/RCL-ERP-Setup-3.19.0-122.exe', sha256: sha256.convert(body).toString());
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => runUpdate(c, u), child: const Text('go')))))));
    await t.tap(find.text('go'));
    await settle(t, 600);
    expect(find.text('Update to 3.19.0?'), findsOneWidget);
    expect(find.textContaining('closes, installs it and opens again'), findsOneWidget);
    await t.tap(find.text('Update'));
    // the download writes a real file: real time and the screen in turns until the setup is run
    for (var i = 0; i < 60 && run.isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 50));
    }
    await settle(t, 600);
    expect(run.length, 1, reason: 'the setup is run once');
    expect(run.single, endsWith('RCL-ERP-Setup-3.19.0-122.exe'));
    expect(File(run.single).readAsBytesSync(), body);
    expect(find.text('Updating'), findsNothing);
    await t.runAsync(() async {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  });

  testWidgets('(3.24.0) the update question shows what is new – English, मराठी, हिंदी – as written, also with Marathi chosen', (t) async {
    const n = 'What is new in 3.24.0:\n• Vendor BOQ: the amendment letter\n\nनवीन काय (3.24.0):\n• Vendor BOQ: amendment पत्र\n\nनया क्या है (3.24.0):\n• Vendor BOQ: संशोधन पत्र';
    await t.runAsync(() => Lang.i.set('mr', read: (p) async => jsonEncode(p.contains('web_') ? {'• Vendor BOQ: the amendment letter': 'बदललेले'} : <String, String>{})));
    expect(tr('• Vendor BOQ: the amendment letter'), 'बदललेले', reason: 'the app would turn this line …');
    final u = AppUpdate(build: 131, version: '3.24.0', notes: n, url: 'https://github.com/x/RCL-ERP-Setup-3.24.0-131.exe', sha256: 'c' * 64);
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => runUpdate(c, u), child: const Text('go')))))));
    await t.tap(find.text('go'));
    await settle(t, 600);
    expect(t.widget<Text>(find.byKey(const Key('ask-plain'))).data, n, reason: '… but what is new is shown as written');
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextButton)).first);
    await settle(t, 300);
    expect(find.byKey(const Key('ask-plain')), findsNothing);
  });

  testWidgets('Home on a computer: no QR scanner (the phone\'s camera), the search and refresh are there; the mouse drags a list', (t) async {
    window(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.byKey(const Key('home-scan')), findsNothing);
    expect(find.byKey(const Key('home-search')), findsOneWidget);
    expect(find.text('Sujit'), findsOneWidget);
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.scrollBehavior?.dragDevices, contains(PointerDeviceKind.mouse));
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/50_computer_home.png'));
  }, tags: ['golden']);

  testWidgets('a phone keeps its scanner and the usual scrolling', (t) async {
    computerForTest = false;
    window(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.byKey(const Key('home-scan')), findsOneWidget);
    expect(t.widget<MaterialApp>(find.byType(MaterialApp)).scrollBehavior, isNull);
  });

  testWidgets('Diesel Issue on a computer: no number plate photo; the 4 photos are chosen from files', (t) async {
    window(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await t.tap(find.text('New Entry'));
    await net(t);
    expect(find.byKey(const Key('scan-plate')), findsNothing);
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    await t.tap(find.text('Sany 210 (No.1)'));
    await settle(t, 800);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -700));
    await settle(t, 500);
    expect(find.text('Choose photo'), findsNWidgets(4));
    expect(find.text('Take photo'), findsNothing);
    expect(find.text('Chosen from a file of this computer – date, time and place are printed on each photo.'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/51_computer_issue_photos.png'));
  }, tags: ['golden']);

  testWidgets('Diesel Inward on a computer: the bill copies only from files (no camera tile)', (t) async {
    window(t);
    final srv = FakeServer()..perms['Diesel Inward'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Inward')));
    await net(t);
    await t.tap(find.text('New Entry'));
    await net(t);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -900));
    await settle(t, 600);
    expect(find.byKey(const Key('bill-camera')), findsNothing);
    expect(find.byKey(const Key('bill-gallery')), findsOneWidget);
    expect(find.text('Photos of the bill – pick several at once from the files of this computer (up to 10).'), findsOneWidget);
  });
}
