/* The app's own screens on a phone (360 × 780) with the pretend Portal: what a person sees and does.
 * The tests tagged "golden" also make pictures of the screens (test/goldens/) – for looking at, in the build's files.
 * (The ERP itself is the web page inside the app; a web view cannot run in a test – a stand-in shows where it opens.) */
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/main.dart';

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

Session make(FakeServer srv) => Session(Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: srv.client));

Widget app(Session s) => RclApp(session: s, web: (c) => const Scaffold(body: Center(child: Text('THE WEB ERP'))));

void main() {
  setUpAll(loadFonts);
  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  testWidgets('Opening: the RCL mark while the kept sign-in is checked', (t) async {
    phone(t);
    final s = make(FakeServer());
    await t.pumpWidget(app(s));
    await settle(t, 600);
    expect(find.text('RCL ERP'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/0_opening.png'));
  }, tags: ['golden']);

  testWidgets('Sign-in: the card comes in; a wrong password says so; the right one goes on', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = make(srv);
    await t.runAsync(s.start);
    await t.pumpWidget(app(s));
    await settle(t);
    expect(find.text('Namaskar'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/1_sign_in.png'));
    await t.enterText(find.byType(TextField).at(0), 'sujit@rcl.test');
    await t.enterText(find.byType(TextField).at(1), 'wrong');
    await t.tap(find.text('Sign in'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(t, 1000);
    expect(find.text('Email or password is wrong.'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/2_sign_in_wrong.png'));
    await t.enterText(find.byType(TextField).at(1), 'Nashik#Road848!');
    await t.tap(find.text('Sign in'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(t);
    expect(s.stage, Stage.pickSite);
    expect(find.text('Namaskar, Sujit'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('Sites: each with its modules; a tap opens the ERP of that site', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = make(srv);
    await t.runAsync(() => s.signIn('sujit@rcl.test', 'Nashik#Road848!'));
    await t.pumpWidget(app(s));
    await settle(t);
    expect(find.text('VTR – NH 848'), findsOneWidget);
    expect(find.text('18B Kolhapur'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/3_sites.png'));
    await t.tap(find.text('18B Kolhapur'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(t, 800);
    expect(find.text('THE WEB ERP'), findsOneWidget);
    expect(s.site!.code, 'T2');
  }, tags: ['golden']);

  testWidgets('Less motion asked on the phone: the sign-in screen is complete at once', (t) async {
    phone(t);
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final s = make(FakeServer());
    await t.runAsync(s.start);
    await t.pumpWidget(app(s));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Sign in'), findsOneWidget);
    final op = t.widget<Opacity>(find.ancestor(of: find.text('RCL ERP'), matching: find.byType(Opacity)).first);
    expect(op.opacity, 1);
  });
}
