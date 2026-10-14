/* The app's screens on a phone (360 × 780) with the pretend servers: what a person sees and does.
 * The tests tagged "golden" also make pictures of the screens (test/goldens/) – for looking at, in the build's files. */
import 'dart:async';
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

/// Lets the pretend servers answer (real time), then draws.
Future<void> net(WidgetTester t, [int ms = 1200]) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await settle(t, ms);
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await settle(t, 400);
}

Session make(FakeServer srv) => Session(Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: srv.client));

Future<Session> ready(WidgetTester t, FakeServer srv) async {
  final s = make(srv);
  await t.runAsync(() async {
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
  });
  return s;
}

/// Pictures (the 3D icons, the logo) are read before the picture of the screen is taken.
Future<void> pics(WidgetTester t) async {
  await t.runAsync(() async {
    for (final e in t.widgetList<Image>(find.byType(Image))) {
      final img = e.image;
      final c = Completer<void>();
      final st = img.resolve(ImageConfiguration.empty);
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

void main() {
  setUpAll(loadFonts);
  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  testWidgets('Sign-in: the Rachana logo; a wrong password says so; the right one goes on', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = make(srv);
    await t.runAsync(s.start);
    await t.pumpWidget(RclApp(session: s));
    await settle(t);
    await pics(t);
    expect(find.text('Namaskar'), findsOneWidget);
    expect(find.image(const AssetImage('assets/brand/rachana_logo.png')), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/1_sign_in.png'));
    await t.enterText(find.byType(TextField).at(0), 'sujit@rcl.test');
    await t.enterText(find.byType(TextField).at(1), 'wrong');
    await t.tap(find.text('Sign in'));
    await net(t);
    expect(find.text('Email or password is wrong.'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(1), 'Nashik#Road848!');
    await t.tap(find.text('Sign in'));
    await net(t);
    expect(s.stage, Stage.pickSite);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/2_sites.png'));
  }, tags: ['golden']);

  testWidgets('Home: stock, each place, machines working, today\'s Log Book, modules he may open, today\'s activity', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await pics(t);
    expect(find.text('Namaskar, Sujit'), findsOneWidget);
    expect(find.text('1,133 L'), findsOneWidget);
    expect(find.text('813 L'), findsOneWidget);
    expect(find.text('320 L'), findsOneWidget);
    expect(find.text('5 / 2'), findsOneWidget, reason: '5 machinery worked today (Idle not counted) / 2 active');
    expect(find.text('6'), findsOneWidget, reason: 'Log Book entries today');
    expect(find.text('Machinery'), findsOneWidget);
    expect(find.text('Billing'), findsNothing, reason: 'no access to Machinery Billing: no tile');
    expect(find.text('Administration'), findsNothing, reason: 'not an Admin');
    expect(find.text('Store'), findsOneWidget, reason: 'he has the Store on this site');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/3_home.png'));
    await t.drag(find.byType(ListView).first, const Offset(0, -900));
    await settle(t, 600);
    await pics(t);
    expect(find.text("Today's Activity"), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/4_home_activity.png'));
  }, tags: ['golden']);

  testWidgets('Entries: the day\'s diesel issues as cards; Transfer (no access) is not a tab', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await pics(t);
    expect(find.text('Sany 210 (No.1)'), findsOneWidget);
    expect(find.text('4 entries · 240 L'), findsOneWidget);
    expect(find.text('Transfer'), findsNothing);
    expect(find.text('New Entry'), findsOneWidget, reason: 'Edit access on Diesel Issue');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/5_entries.png'));
    await t.enterText(find.byType(TextField).first, 'maruti');
    await settle(t, 400);
    expect(find.text('MH-12-SY-6216'), findsOneWidget);
    expect(find.text('Sany 210 (No.1)'), findsNothing);
  }, tags: ['golden']);

  testWidgets('New Diesel Issue: machinery, its way (Hrs by itself), litres, the stock after, the 4 photo tiles; save', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.text('New Entry'));
    await net(t);
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    expect(find.text('OLD-9'), findsNothing, reason: 'an Inactive machinery is not offered');
    await t.tap(find.text('Sany 210 (No.1)'));
    await settle(t, 800);
    expect(find.text('Hour meter'), findsOneWidget, reason: 'measured by Hrs – picked by itself');
    await t.enterText(find.byType(TextField).at(1), '60');
    await settle(t, 300);
    expect(find.text('Stock after this issue: 753 L'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/6_issue_form.png'));
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -700));
    await settle(t, 500);
    await pics(t);
    expect(find.text('Dispenser litres'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/7_issue_photos.png'));
    await t.tap(find.text('Save Diesel Issue'));
    await net(t);
    expect(srv.saved.single['no'], 'Sany 210 (No.1)');
    expect(srv.saved.single['qty'], 60);
    expect(srv.saved.single['mode'], 'Hrs');
    expect(find.textContaining('DI-000526'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/8_issue_saved.png'));
  }, tags: ['golden']);

  testWidgets('Me: name, role, site, version, sign out', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Me'));
    await net(t);
    await pics(t);
    expect(find.text('Sujit Mule'), findsOneWidget);
    expect(find.text('Check Update'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9_me.png'));
    await t.tap(find.text('Reports'));
    await net(t);
    expect(find.text('Monthly Diesel Issue'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('Less motion asked on the phone: the sign-in screen is complete at once', (t) async {
    phone(t);
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final s = make(FakeServer());
    await t.runAsync(s.start);
    await t.pumpWidget(RclApp(session: s));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Sign in'), findsOneWidget);
    final op = t.widget<Opacity>(find.ancestor(of: find.text('Mechanical Management ERP'), matching: find.byType(Opacity)).first);
    expect(op.opacity, 1);
  });
}
