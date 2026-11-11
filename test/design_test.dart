// (3.97.0) THE NEW LOOK – his designs of 11-11-2026 ("all designs approved aahet te banwayla chalu kar"): the module's own colour
// and band, the chip tabs, the steps of an entry, the machinery saved last, the state strip, the grey shapes while loading, Site
// mode, Home's "Today's work", the badges, the small bar and the centre FAB bar. Look only – every call, check and answer as before.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/main.dart';
import 'package:rcl_mobile/ui/design.dart';
import 'package:rcl_mobile/ui/theme.dart';
import 'package:rcl_mobile/ui/widgets.dart' show Shimmer;

import 'fake_server.dart';

/// the app's own fonts (as the other screen tests) – the letters as wide as on the phone
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

Session make(FakeServer srv) => Session(Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: srv.client))..clock = () => DateTime(2026, 10, 14, 10, 30);

Future<Session> ready(WidgetTester t, FakeServer srv) async {
  final s = make(srv);
  await t.runAsync(() async {
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
  });
  return s;
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

/// (3.99.0) Brings [f] onto the screen where a finger can reach it: Home's small bar now stays at the top while the page is
/// scrolled, so a thing brought to the very top would be under it – the page is then pulled down a little.
Future<void> seen(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
    final bar = find.byWidgetPredicate((w) => w.key == const Key('home-mini') || w.key == const Key('me-mini')).hitTestable();
    if (bar.evaluate().isEmpty || t.getRect(f.first).top >= t.getRect(bar.first).bottom + 4) break;
    await t.drag(find.ancestor(of: f.first, matching: find.byType(Scrollable)).last, const Offset(0, 110));
  }
}

void main() {
  setUpAll(loadFonts);

  test('design 9: a state and its colour – waiting yellow, done green, refused red, anything else grey', () {
    const wait = Color(0xFFE9A23B), ok = Color(0xFF2E8B5E), bad = Color(0xFFD9443A), grey = Color(0xFFB9C0BB);
    for (final s in ['Pending', 'Waiting', 'Open', 'Still on', 'Draft']) {
      expect(stateLook(s).strip, wait, reason: s);
    }
    for (final s in ['Approved', 'Verified', 'Received', 'Issued', 'Closed']) {
      expect(stateLook(s).strip, ok, reason: s);
    }
    for (final s in ['Rejected', 'Cancelled', 'Sent back']) {
      expect(stateLook(s).strip, bad, reason: s);
    }
    expect(stateLook('Taken back').strip, grey);
    expect(stateLook('').strip, grey);
    expect(stateLook('Pending').mr, 'थांबलेले');
    expect(stateLook('Approved').mr, 'मंजूर');
  });

  testWidgets('designs 1 and 2: the module band (white name, its picture, the site · role) and the chip tabs move with the pages', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: appTheme(),
      home: DefaultTabController(
        length: 3,
        child: Builder(
          builder: (c) => Scaffold(
            appBar: moduleBar(c, Tone.store, en: 'Store', mr: 'स्टोअर', pic: 'package', line: 'VTR Site · Store Admin'),
            body: Column(children: [
              ChipTabs(labels: const ['Dashboard', 'Work', 'Item Master'], tone: Tone.store, keys: const [Key('t0'), Key('t1'), Key('t2')]),
              const Expanded(child: TabBarView(children: [Text('page one'), Text('page two'), Text('page three')])),
            ]),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(t.widget<Text>(find.text('Store')).style?.color, Colors.white, reason: 'white on the Store\'s amber');
    // the Store's colour fills the whole band (not a box of nothing)
    final band = find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).gradient != null);
    expect(band, findsOneWidget);
    expect(t.getSize(band).height, greaterThan(90), reason: 'the bar with the site · role line');
    expect(t.getSize(band).width, 800);
    expect(find.text('VTR Site · Store Admin'), findsOneWidget);
    expect(find.text('page one'), findsOneWidget);
    await t.tap(find.byKey(const Key('t2')));
    await t.pumpAndSettle();
    expect(find.text('page three'), findsOneWidget);
    expect(DefaultTabController.of(t.element(find.text('page three'))).index, 2);
    // a swipe of the page moves the chip
    await t.fling(find.text('page three'), const Offset(400, 0), 1200);
    await t.pumpAndSettle();
    expect(DefaultTabController.of(t.element(find.text('page two'))).index, 1);
  });

  testWidgets('design 7: the steps – done ✓ (green), the next one now, the rest to come', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: StepBar(steps: const [('Machinery', 'यंत्र'), ('Meter', 'मीटर'), ('Litres', 'लिटर'), ('Save', 'सेव्ह')], done: 2))));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.text('Litres'), findsNothing, reason: 'drawn as a picture of text – not one more "Litres" of the form');
  });

  testWidgets('design 10: grey shapes while the answer comes – inside a list too', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: const [Text('above'), SkeletonList(tiles: 2, rows: 3)]))));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.byType(Shimmer), findsNWidgets(5));
  });

  testWidgets('design 12: Site mode – bigger buttons and lines, the letters ×1.15 – kept on this phone only', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    Size? btn() => Theme.of(t.element(find.byType(Scaffold).first)).filledButtonTheme.style!.minimumSize!.resolve(const {});
    expect(btn(), const Size.fromHeight(58));
    await t.runAsync(() => s.setSiteMode(true));
    await settle(t, 400);
    expect(btn(), const Size.fromHeight(68));
    expect(MediaQuery.textScalerOf(t.element(find.byType(Scaffold).first)).scale(10), closeTo(11.5, .001));
    expect(await t.runAsync(() => s.api.keep.read(Session.kSiteMode)), '1');
    await t.runAsync(() => s.setSiteMode(false));
    await settle(t, 400);
    expect(btn(), const Size.fromHeight(58));
    expect(await t.runAsync(() => s.api.keep.read(Session.kSiteMode)), isNull);
  });

  testWidgets("designs 3, 4, 5 and 13: Home – Today's work from the modules' own figures, the badge, the small bar past the picture, the centre FAB bar", (t) async {
    Session.moduleCounts = true;
    addTearDown(() => Session.moduleCounts = false);
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await net(t);
    expect(srv.storeWork.any((x) => x['action'] == 'dash'), isTrue, reason: 'the Store\'s own dashboard call');
    expect(find.byKey(const Key('home-today')), findsOneWidget);
    expect(find.byKey(const Key('today-store')), findsOneWidget, reason: '1 requirement waits for his approval');
    expect(find.byKey(const Key('today-below')), findsOneWidget, reason: '1 item below its minimum');
    expect(find.byKey(const Key('mod-badge-store')), findsOneWidget);
    expect(find.byKey(const Key('tab-bar-pill')), findsOneWidget);
    expect(find.byKey(const Key('tab-plus')), findsOneWidget);
    // the small bar (3.99.0): not while the site's picture is seen; there the whole time it is scrolled away – down or up; at the top
    // again: gone
    expect(find.byKey(const Key('home-mini')), findsNothing);
    await t.drag(find.byType(ListView).first, const Offset(0, -700));
    await settle(t, 600);
    expect(find.byKey(const Key('home-mini')), findsOneWidget, reason: 'scrolling down: the bar stays at the top');
    await t.drag(find.byType(ListView).first, const Offset(0, 120));
    await settle(t, 600);
    expect(find.byKey(const Key('home-mini')), findsOneWidget, reason: 'scrolling back up past the picture');
    await t.drag(find.byType(ListView).first, const Offset(0, 1200));
    await settle(t, 600);
    expect(find.byKey(const Key('home-mini')), findsNothing, reason: 'the site\'s picture is seen');
    await seen(t, find.byKey(const Key('today-store')));
    await settle(t, 400);
    // a row opens its work: the Store
    await t.tap(find.byKey(const Key('today-store')));
    await net(t);
    expect(find.text('Item Master'), findsWidgets);
  });

  testWidgets('3.98.0: the Pill tab bar – the chosen tab shows its name, the others their picture only; a tap changes the tab; the + as before', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    final bar = find.byKey(const Key('tab-bar-pill'));
    expect(bar, findsOneWidget);
    Finder name(String n) => find.descendant(of: bar, matching: find.text(n));
    expect(name('Home'), findsOneWidget);
    expect(name('Entries'), findsNothing);
    expect(name('Reports'), findsNothing);
    expect(name('Me'), findsNothing);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    expect(name('Entries'), findsOneWidget);
    expect(name('Home'), findsNothing);
    // the name is whole on this phone (360 wide) – not cut to "Entri…"
    final para = t.renderObject<RenderParagraph>(find.descendant(of: name('Entries'), matching: find.byType(RichText)));
    expect(para.didExceedMaxLines, isFalse, reason: 'the whole word fits');
    expect(t.takeException(), isNull);
    // the + is beside the pill, not over it
    expect(t.getRect(find.byKey(const Key('tab-plus'))).left, greaterThan(t.getRect(bar).right));
    await t.tap(find.byKey(const Key('tab-plus')));
    await settle(t, 600);
    expect(find.byKey(const Key('plus-Diesel Issue')), findsOneWidget);
  });

  testWidgets('designs 6 and 7: the machinery saved last is a chip – a tap picks it as the list does; the steps follow the entry', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.runAsync(() => s.api.keep.write('recent_mach|S1', jsonEncode(['Sany 210 (No.1)', 'NOT-ON-SITE'])));
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-plus')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('plus-Diesel Issue')));
    await net(t);
    expect(t.widget<StepBar>(find.byType(StepBar)).done, 0, reason: 'nothing yet – the machinery is next');
    expect(find.byKey(const Key('d-recent-Sany 210 (No.1)')), findsOneWidget);
    expect(find.byKey(const Key('d-recent-NOT-ON-SITE')), findsNothing, reason: 'only a machinery of this site');
    await t.tap(find.byKey(const Key('d-recent-Sany 210 (No.1)')));
    await net(t);
    expect(find.text('Sany 210 (No.1)'), findsOneWidget, reason: 'in the machinery box, as picked from the list');
    expect(find.text('Hour meter'), findsOneWidget, reason: 'its way from the Asset Master, as before');
    expect(t.widget<StepBar>(find.byType(StepBar)).done, 1, reason: 'Machinery ✓ – the meter is next');
    // (3.99.0) the steps stay at the top while the form scrolls
    final y = t.getTopLeft(find.byType(StepBar)).dy;
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
    await settle(t, 600);
    expect(find.byType(StepBar).hitTestable(), findsOneWidget, reason: 'still seen after scrolling down');
    expect(t.getTopLeft(find.byType(StepBar)).dy, y, reason: 'it has not moved');
  });

  testWidgets('3.99.0: the top of a tab stays while the page scrolls – Entries, Reports, Me', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    Future<void> stays(String tab, Finder head) async {
      await t.tap(find.byKey(Key('tab-$tab')));
      await net(t);
      expect(head.hitTestable(), findsOneWidget, reason: '$tab: its top');
      final y = t.getTopLeft(head).dy;
      await t.dragFrom(const Offset(180, 450), const Offset(0, -600));
      await settle(t, 600);
      expect(head.hitTestable(), findsOneWidget, reason: '$tab: still seen after scrolling');
      expect(t.getTopLeft(head).dy, y, reason: '$tab: it has not moved');
    }

    await stays('entries', find.byKey(const Key('entries-search')));
    await stays('reports', find.byKey(const Key('pin-top')));
    // Me: the big green part scrolls away – his name stays in a small bar (when the page is long enough to scroll that far)
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    expect(find.byKey(const Key('me-mini')), findsNothing);
    await t.dragFrom(const Offset(180, 450), const Offset(0, -600));
    await settle(t, 600);
    if (t.state<ScrollableState>(find.descendant(of: find.byType(TopOnScroll), matching: find.byType(Scrollable)).first).position.pixels > 120) expect(find.byKey(const Key('me-mini')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('3.100.0: the Advertise Corner on Home – the Portal\'s posts of this site; no post = nothing; its size is the post\'s; the next by a swipe; a video has the sound button', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(srv.adsAsked, isNotEmpty, reason: 'asked from the Portal');
    expect(srv.adsAsked.first, {'action': 'live', 'platform': 'app', 'site': s.api.site});
    expect(find.byKey(const Key('ad-corner')), findsNothing, reason: 'no post: Home is as before');
    // two posts: a strip (an image) and a banner (a video)
    srv.ads = [
      {'id': 'a1', 'title': 'Diwali', 'media': 'image', 'size': 'strip', 'seconds': 6, 'url': 'https://files.test/a1.jpg', 'poster': ''},
      {'id': 'a2', 'title': 'PQC', 'media': 'video', 'size': 'banner', 'seconds': 12, 'url': 'https://files.test/a2.mp4', 'poster': ''},
      {'id': 'bad', 'title': 'x', 'media': 'image', 'size': 'strip', 'seconds': 6, 'url': 'javascript:alert(1)', 'poster': ''},
    ];
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    final box = find.byKey(const Key('ad-corner'));
    expect(box, findsOneWidget);
    expect(t.getSize(box).height, 96, reason: 'a strip');
    expect(find.byKey(const Key('ad-mute')), findsNothing, reason: 'an image has no sound button');
    await t.fling(box, const Offset(-200, 0), 800);
    await settle(t, 600);
    expect(t.getSize(box).height, 164, reason: 'the next one: a banner');
    expect(find.byKey(const Key('ad-mute')), findsOneWidget, reason: 'a video: the sound button');
    await t.fling(box, const Offset(-200, 0), 800);
    await settle(t, 600);
    expect(t.getSize(box).height, 96, reason: 'only two are shown – the one with a wrong link is left out');
    await t.pumpWidget(const SizedBox());      // (its timer goes with it)
    await t.pump(const Duration(seconds: 1));
    t.takeException();
  });
}
