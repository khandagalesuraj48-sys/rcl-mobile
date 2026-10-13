/* The screens on a phone (360 × 780) with the pretend server: what a person sees and does.
 * The tests tagged "golden" also make pictures of the screens (test/goldens/, one picture per screen) – for looking at, in the build's files. */
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

Future<Session> readySession(FakeServer srv) async {
  final s = Session(Api(portalUrl: 'https://erp.test/portal', mechUrl: 'https://erp.test', keep: MemoryKeep(), client: srv.client));
  await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
  await s.switchSite('S1');
  return s;
}

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadFonts);
  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  testWidgets('Home: the stock, today\'s issue, and only the tiles he may open', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await t.runAsync(() => readySession(srv));
    await t.pumpWidget(RclApp(session: s!));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect(find.text('Namaskar, Sujit'), findsOneWidget);
    expect(find.text('813 L'), findsOneWidget);
    expect(find.textContaining('Issued today 350 L'), findsOneWidget);
    expect(find.text('Diesel Issue'), findsOneWidget);
    expect(find.text('Diesel Inward'), findsOneWidget, reason: 'View access: the tile is there (it opens the list)');
    expect(find.text('Transfer'), findsNothing, reason: 'No access: no tile');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/1_home.png'));
  }, tags: ['golden']);

  testWidgets('Diesel Issue: pick the machinery, litres, save → saved; the stock goes down', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await t.runAsync(() => readySession(srv));
    await t.pumpWidget(RclApp(session: s!));
    await settle(t);
    await t.tap(find.text('Diesel Issue'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect(find.textContaining('Stock at Dispenser'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/2_issue_empty.png'));
    await t.tap(find.text('Pick the machinery'));
    await settle(t);
    expect(find.text('OLD-9'), findsNothing, reason: 'an Inactive machinery is not offered');
    await t.enterText(find.byType(TextField).first, 'pc210');
    await settle(t, 300);
    await t.tap(find.text('MH-04-KU-3331'));
    await settle(t);
    await t.tap(find.text('120'));
    await settle(t, 300);
    expect(find.text('Hour meter'), findsOneWidget, reason: 'this machinery works on hours');
    expect(find.text('KM reading'), findsNothing);
    expect(find.text('Stock after this issue: 693 L'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/3_issue_filled.png'));
    await t.tap(find.text('Save'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect(find.textContaining('DI-000104'), findsOneWidget);
    expect(srv.saved.single['no'], 'MH-04-KU-3331');
    expect(srv.saved.single['qty'], 120);
    expect(srv.saved.single['shift'], 'Day');
    expect(srv.saved.single['source'], 'Dispenser');
    expect(s.stockTotal, 693);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/4_issue_saved.png'));
  }, tags: ['golden']);

  testWidgets('Entries: today\'s issues with the total', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await t.runAsync(() => readySession(srv));
    await t.pumpWidget(RclApp(session: s!));
    await settle(t);
    await t.tap(find.text('Entries'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect(find.text('MH-04-KU-3331'), findsOneWidget);
    expect(find.textContaining('3 entries · 350 L'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/5_entries.png'));
  }, tags: ['golden']);

  testWidgets('Sign-in screen', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = Session(Api(portalUrl: 'https://erp.test/portal', mechUrl: 'https://erp.test', keep: MemoryKeep(), client: srv.client));
    await t.runAsync(s.start);
    await t.pumpWidget(RclApp(session: s));
    await settle(t);
    expect(find.text('Sign in'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/0_sign_in.png'));
  }, tags: ['golden']);
}
