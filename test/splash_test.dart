/* (3.37.0) The start screen (screens/splash.dart): its bar shows the REAL opening (Session.boot), it fits every screen – a small
 * phone, a large one, a phone held across, a tablet – inside the status bar and the navigation bar, and
 * it changes nothing of the sign-in. The tests tagged "golden" draw it (test/goldens/) to be looked at against the design. */
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/main.dart';
import 'package:rcl_mobile/screens/splash.dart';

import 'fake_server.dart';

Future<void> _fonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final f in manifest) {
    final loader = FontLoader(f['family'] as String);
    for (final a in f['fonts'] as List) {
      loader.addFont(rootBundle.load(a['asset'] as String));
    }
    await loader.load();
  }
}

/// The pictures (the road, the mark) read before the screen is looked at.
Future<void> _pics(WidgetTester t) async {
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
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// A screen of [w] × [h] (logical) with a status bar of [top] and a navigation bar of [bottom].
void _screen(WidgetTester t, double w, double h, {double dpr = 3, double top = 24, double bottom = 24}) {
  t.view.physicalSize = Size(w * dpr, h * dpr);
  t.view.devicePixelRatio = dpr;
  t.view.padding = FakeViewPadding(top: top * dpr, bottom: bottom * dpr);
  t.view.viewPadding = FakeViewPadding(top: top * dpr, bottom: bottom * dpr);
  addTearDown(t.view.reset);
}

Widget _alone(double progress) => MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen(progress: progress));

void main() {
  setUpAll(_fonts);

  group('the opening, step by step (Session.boot)', () {
    late FakeServer srv;
    late MemoryKeep keep;
    Session make() => Session(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client));
    setUp(() {
      srv = FakeServer();
      keep = MemoryKeep();
    });

    test('the app opens with the kept sign-in: the kept sign-in read → his sites → the site → its lists; 100 % only when ready', () async {
      final s1 = make();
      await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
      await s1.chooseSite('S1');
      final s2 = make(), seen = <(double, Stage)>[];
      expect(s2.boot, 0);
      s2.addListener(() => seen.add((s2.boot, s2.stage)));
      await s2.start();
      expect(s2.stage, Stage.ready);
      final steps = <double>[];
      for (final x in seen) {
        if (steps.isEmpty || steps.last != x.$1) steps.add(x.$1);
      }
      expect(steps, [.15, .4, .5, .7, 1.0]);
      expect(seen.where((x) => x.$1 == 1.0).every((x) => x.$2 == Stage.ready), true, reason: 'the bar is full only when the app is open');
      expect(seen.where((x) => x.$1 < 1).every((x) => x.$2 == Stage.starting || x.$2 == Stage.opening), true);
    });

    test('signed in just now, or another site chosen later: the bar goes on from the site\'s opening', () async {
      final s = make(), seen = <double>[];
      s.addListener(() => seen.add(s.boot));
      await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
      await s.chooseSite('S1');
      expect(seen.toSet().toList(), containsAllInOrder([.5, .7, 1.0]));
      seen.clear();
      await s.chooseSite('T2');
      expect(s.stage, Stage.ready);
      expect(seen, containsAllInOrder([.5, .7, 1.0]), reason: 'not still 100 % from the site before');
      expect(seen.last, 1.0);
    });

    test('no network at the start: the app waits (still signed in) – the bar never says ready', () async {
      final s1 = make();
      await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
      await s1.chooseSite('S1');
      srv.down = true;
      final s2 = make();
      await s2.start();
      expect(s2.stage, Stage.waiting);
      expect(s2.boot, lessThan(1));
      s2.dispose();
    });
  });

  testWidgets('the screen shows the real figure and moves to the next one smoothly – never a made-up number', (t) async {
    _screen(t, 393, 852);
    await t.pumpWidget(_alone(.42));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('68%'), findsNothing);
    expect(find.text('Preparing your workspace...'), findsOneWidget);
    expect(find.text('INTEGRATED CONSTRUCTION MANAGEMENT'), findsOneWidget);
    expect(find.text('RCL'), findsOneWidget);
    expect(find.text(' ERP'), findsOneWidget);
    expect(find.byKey(const Key('splash-logo')), findsOneWidget);
    await t.pumpWidget(_alone(.7));
    await t.pump(const Duration(milliseconds: 100));
    final pct = t.widget<Text>(find.descendant(of: find.byKey(const Key('splash-pct')), matching: find.byType(Text)));
    final mid = int.parse((pct.data ?? '').replaceAll('%', ''));
    expect(mid, inInclusiveRange(43, 69), reason: 'on its way from 42 to 70');
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('70%'), findsOneWidget);
  });

  testWidgets('"Less motion" on the phone: the figure is there at once', (t) async {
    _screen(t, 393, 852);
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.pumpWidget(_alone(.2));
    await t.pump();
    await t.pumpWidget(_alone(.9));
    await t.pump();
    expect(find.text('90%'), findsOneWidget);
  });

  testWidgets('the app at its start shows this screen with the session\'s own figure (and the sign-in after it, as before)', (t) async {
    _screen(t, 393, 852);
    final s = Session(Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: FakeServer().client));
    await t.pumpWidget(RclApp(session: s));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    await t.runAsync(s.start);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100)); // (the screens change over in 350 ms)
    }
    expect(s.stage, Stage.signedOut);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
  });

  // every size: nothing overflows, the logo is below the status bar, the bar above the navigation bar, the words inside the screen
  for (final (name, w, h, top, bottom) in [
    ('small phone', 320.0, 568.0, 20.0, 0.0),
    ('phone', 360.0, 780.0, 24.0, 48.0),
    ('tall phone', 393.0, 873.0, 47.0, 34.0),
    ('large phone', 430.0, 932.0, 54.0, 24.0),
    ('phone held across', 800.0, 360.0, 24.0, 0.0),
    ('tablet', 800.0, 1280.0, 24.0, 48.0),
    ('tablet held across', 1280.0, 800.0, 24.0, 0.0),
  ]) {
    testWidgets('fits a $name ($w × $h)', (t) async {
      _screen(t, w, h, top: top, bottom: bottom);
      await t.pumpWidget(_alone(.68));
      await t.pump(const Duration(milliseconds: 600));
      expect(t.takeException(), isNull);
      final logo = t.getRect(find.byKey(const Key('splash-logo')));
      final bar = t.getRect(find.byKey(const Key('splash-pct')));
      final label = t.getRect(find.byKey(const Key('splash-label')));
      final sub = t.getRect(find.byKey(const Key('splash-sub')));
      expect(logo.top, greaterThanOrEqualTo(top), reason: 'below the status bar');
      expect(bar.bottom, lessThanOrEqualTo(h - bottom), reason: 'above the navigation bar');
      expect(sub.bottom, lessThan(label.top), reason: 'the words at the top and the bar at the bottom never meet');
      expect(label.left, greaterThanOrEqualTo(0));
      expect(bar.right, lessThanOrEqualTo(w));
      expect(sub.left, greaterThanOrEqualTo(0));
      expect(sub.right, lessThanOrEqualTo(w));
    });
  }

  for (final (file, w, h, dpr) in [
    ('00_splash.png', 393.0, 852.0, 3.0),
    ('00_splash_small.png', 360.0, 640.0, 2.0),
    ('00_splash_tablet.png', 800.0, 1280.0, 1.5),
  ]) {
    testWidgets('picture: $file', (t) async {
      _screen(t, w, h, dpr: dpr);
      await t.pumpWidget(_alone(.68));
      await _pics(t);
      await t.pump(const Duration(milliseconds: 600));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$file'));
    }, tags: ['golden']);
  }
}
