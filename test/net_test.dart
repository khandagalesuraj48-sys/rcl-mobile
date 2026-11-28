// (3.171.0 patch 4 – SNI, his approval of 25-11-2026) the network as MEASURED – core/net.dart: the rules from the app's own requests,
// the internet told apart from our server, the hold against flicker, every request of our servers measured by Api's client (and
// nothing else), and the indicator, its sheet and the line under the header (ui/net_chip.dart).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/net.dart';
import 'package:rcl_mobile/ui/net_chip.dart';
import 'package:rcl_mobile/ui/theme.dart';

void main() {
  late NetMonitor m;
  late DateTime t;
  setUp(() {
    t = DateTime.utc(2026, 11, 25, 12);
    m = NetMonitor()
      ..on = true
      ..now = (() => t)
      ..internetCheck = () async => 140;
    NetMonitor.i = m;
  });
  tearDown(() => NetMonitor.i = NetMonitor());

  void ok(String s, int ms) => m.record(s, ms, NetEnd.ok);

  test('nothing measured: Checking – never a state that was not measured', () {
    expect(m.state, NetState.checking);
    expect(m.worst.$1, NetState.checking);
    expect(m.middleAll, isNull);
  });

  test('the middle time of the last 10 answers of the last 2 minutes: under 800 ms GOOD; 800 ms or more, or one answer over 5 s: SLOW (the server) – not the network', () {
    for (final x in [200, 240, 260]) {
      ok('mech', x);
    }
    expect(m.stateOf('mech'), NetState.good);
    expect(m.middleMs('mech'), 240);
    expect(m.state, NetState.good, reason: 'the first state shows at once');
    for (final x in [900, 1200, 1800, 2000]) {
      ok('hr', x);
    }
    expect(m.stateOf('hr'), NetState.slow, reason: '(3.174.1) a slow answer is the server\'s work until the internet itself is measured slow');
    ok('portal', 300);
    ok('portal', 5200);
    ok('portal', 310);
    expect(m.stateOf('portal'), NetState.slow, reason: 'one answer over 5 s');
    expect(m.worst, (NetState.slow, 'hr'));
    // only the last 10 count, and only those of the last 2 minutes
    for (var i = 0; i < 10; i++) {
      ok('hr', 150);
    }
    expect(m.stateOf('hr'), NetState.good);
    t = t.add(const Duration(minutes: 3));
    expect(m.servers, isEmpty, reason: 'older than 2 minutes: not counted');
    expect(m.stateOf('hr'), NetState.checking);
  });

  test('two failures among the last 10: UNSTABLE; a server error twice in a row: SERVER DOWN', () {
    ok('mech', 200);
    m.record('mech', 900, NetEnd.serverError);
    ok('mech', 210);
    m.record('mech', 15000, NetEnd.timeout);
    ok('mech', 220);
    expect(m.stateOf('mech'), NetState.unstable);
    m.record('store', 300, NetEnd.serverError);
    m.record('store', 300, NetEnd.serverError);
    expect(m.stateOf('store'), NetState.serverDown);
  });

  test('no answer: RECONNECTING while Android\'s check is asked; it answers → SERVER DOWN, it fails too → OFFLINE', () async {
    final asked = Completer<int?>();
    var n = 0;
    m.internetCheck = () {
      n++;
      return asked.future;
    };
    ok('mech', 200);
    m.record('mech', 40000, NetEnd.timeout);
    expect(m.state, NetState.reconnecting, reason: 'at once – no 3 s hold for a failure');
    expect(n, 1, reason: 'the check is asked once');
    m.record('mech', 100, NetEnd.noConnection);
    expect(n, 1, reason: 'at most once in 10 s');
    asked.complete(140);
    await Future<void>.delayed(Duration.zero);
    expect(m.internet, true);
    expect(m.stateOf('mech'), NetState.serverDown);
    expect(m.state, NetState.serverDown);
    // later: no internet at all
    t = t.add(const Duration(seconds: 20));
    m.internetCheck = () async => null;
    m.record('mech', 100, NetEnd.noConnection);
    await Future<void>.delayed(Duration.zero);
    expect(m.internet, false);
    expect(m.state, NetState.offline);
    // the network back: the next answer counts again (the failures stay among the last 10: unstable for a while)
    t = t.add(const Duration(seconds: 5));
    ok('mech', 230);
    expect(m.stateOf('mech'), NetState.unstable);
  });

  testWidgets('a better state shows after it held 3 s (no flicker); a worse one at once', (tester) async {
    for (final x in [200, 210, 220]) {
      ok('mech', x);
    }
    expect(m.state, NetState.good);
    for (final x in [3000, 3100, 3200, 3300, 3400]) {
      ok('mech', x);
    }
    expect(m.worst.$1, NetState.slow);
    expect(m.state, NetState.good, reason: 'not yet – it must hold 3 s');
    await tester.pump(const Duration(seconds: 3));
    expect(m.state, NetState.slow);
    expect(m.changedFrom, NetState.good);
  });

  /* (3.174.1 – his audit brief of 28-11-2026: "Do not falsely blame the internet when backend performance is the actual problem") */
  test('(3.174.1) his screenshot: Mechanical 3.8 s, Store 2.1 s, Engineering 1.7 s, Purchase 1.5 s, nothing failed, the internet quick → SERVER SLOW, never "Weak"', () async {
    var checks = 0;
    m.internetCheck = () async {
      checks++;
      return 180;
    };
    ok('portal', 400);
    ok('mech', 3800);
    ok('store', 2100);
    ok('eng', 1700);
    ok('pur', 1500);
    await Future<void>.delayed(Duration.zero);
    expect(checks, 1, reason: 'one check of the internet tells the server\'s work from a weak network');
    expect(m.worst, (NetState.slow, 'mech'));
    expect(m.linkWeak, isFalse);
    expect(m.internetWorks, isTrue);
    // … and no second check while that one is fresh (2 minutes), however many slow answers come
    for (var i = 0; i < 20; i++) {
      t = t.add(const Duration(seconds: 5));
      ok('mech', 3000);
      m.tick();
    }
    await Future<void>.delayed(Duration.zero);
    expect(checks, 1);
  });

  test('(3.174.1) the same slow answers with the internet check itself slow (1.2 s or more) or unanswered → INTERNET WEAK', () async {
    m.internetCheck = () async => 2100;
    ok('mech', 1500);
    ok('mech', 1600);
    await Future<void>.delayed(Duration.zero);
    expect(m.stateOf('mech'), NetState.weak);
    expect(m.linkWeak, isTrue);
    // quick answers: good, whatever the check said
    for (var i = 0; i < 10; i++) {
      ok('mech', 200);
    }
    expect(m.stateOf('mech'), NetState.good);
    m.reset();
    m.internetCheck = () async => null;
    ok('store', 1500);
    await Future<void>.delayed(Duration.zero);
    expect(m.stateOf('store'), NetState.weak, reason: 'slow answers and the check unanswered');
  });

  test('(3.174.1) the Internet row follows the newest proof: a check that failed, then a server answers → the internet WORKS', () async {
    m.internetCheck = () async => null;
    await m.checkInternet(now0: true);
    expect(m.internetWorks, isFalse);
    t = t.add(const Duration(seconds: 30));
    ok('mech', 300);
    expect(m.internet, isFalse, reason: 'the check itself is not asked again for it');
    expect(m.internetWorks, isTrue, reason: 'a server answered after the check');
    expect(m.lastOkAt, t);
  });

  test('(3.174.1) idle in front: the request to the Portal backs off (30 s → 60 s → 2 minutes) while all is good; a real request starts at 30 s again', () async {
    final at = <int>[];
    final t0 = t;
    m.probe = () async {
      at.add(t.difference(t0).inSeconds);
      ok('portal', 200);
    };
    for (var i = 0; i < 120; i++) {
      t = t.add(const Duration(seconds: 5));
      m.tick();
      await Future<void>.delayed(Duration.zero);
    }
    expect(at, [5, 65, 185, 305, 425, 545], reason: 'the first at once (nothing measured yet), then 60 s, then every 2 minutes – it was every 30 s');
    // the app is used: back to 30 s
    ok('mech', 200);
    at.clear();
    final t1 = t;
    for (var i = 0; i < 14; i++) {
      t = t.add(const Duration(seconds: 5));
      m.tick();
      await Future<void>.delayed(Duration.zero);
    }
    expect([for (final x in at) x - t1.difference(t0).inSeconds], [30], reason: '30 s after the last real request, the next 60 s after that');
  });

  test('(3.174.1) one request on its way is shared: "Check now" pressed again and the rhythm beside it ask nothing more', () async {
    var probes = 0, checks = 0;
    final go = Completer<void>();
    m
      ..probe = () async {
        probes++;
        await go.future;
      }
      ..internetCheck = () async {
        checks++;
        await go.future;
        return 150;
      };
    final all = [for (var i = 0; i < 5; i++) m.checkNow()];
    m.tick();
    expect([probes, checks], [1, 1]);
    go.complete();
    await Future.wait(all);
    expect([probes, checks], [1, 1]);
  });

  testWidgets('(3.174.1) the sheet in the APP\'S OWN THEME on a 360 px phone: "Network" on one line beside "Check now" (it stood letter under letter); "Server slow" with the internet\'s own row', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    m.internetCheck = () async => 180;
    ok('mech', 3800);
    ok('store', 2100);
    await tester.pumpWidget(MaterialApp(theme: appTheme(), home: const Scaffold(body: NetSheet(site: 'S1'))));
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
    final title = tester.getSize(find.byKey(const Key('net-title')));
    expect(title.height, lessThan(40), reason: 'one line');
    expect(title.width, greaterThan(100));
    expect(tester.getSize(find.byKey(const Key('net-check'))).width, lessThan(180), reason: 'the button its own size, not the whole width');
    expect(find.text('Server slow'), findsOneWidget);
    expect(find.textContaining('not your network'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('net-internet')), matching: find.text('works')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('net-server-mech')), matching: find.textContaining('slow')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  // (3.174.2, his words: "kharach network problem asel tr as error dakhaw vinakaran nko realtime haw") the "slow network" line only
  // when Android's check, made the moment a request has waited 5 s, is slow or fails – a fast check = our server is late: no line
  testWidgets('a request waiting 5 s: the check at that moment; internet fast = our server is late – NO line; done: gone', (tester) async {
    var checks = 0;
    m.internetCheck = () async {
      checks++;
      return 140;
    };
    final c = Completer<int>();
    final f = m.watch<int>('mech', c.future, const Duration(seconds: 40));
    expect(m.slowest, isNull);
    expect(checks, 0, reason: 'nothing asked before 5 s');
    t = t.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    expect(m.slowest, const Duration(seconds: 6));
    expect(checks, 1, reason: 'the check at the 5th second – real time, not at the next tick');
    expect(m.netSlow, isFalse);
    expect(netLineKind(m), '', reason: 'the internet is fine (140 ms): the server is late – no "slow network" line');
    c.complete(1);
    await f;
    expect(m.slowest, isNull);
    expect(m.recent('mech').single.ms, 6000, reason: 'its real time');
  });

  testWidgets('a request waiting 5 s and the check slow (1.5 s or more) or failing: the "slow network" line – a real network problem', (tester) async {
    m.internetCheck = () async => 2300;
    final c = Completer<int>();
    unawaited(m.watch<int>('mech', c.future, const Duration(seconds: 40)));
    t = t.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    expect(m.netSlow, isTrue);
    expect(netLineKind(m), 'slow');
    c.complete(1);
    await tester.pump();
    expect(netLineKind(m), '', reason: 'the answer came: the line goes');

    m.internetCheck = () async => null;
    t = t.add(const Duration(seconds: 20));
    final c2 = Completer<int>();
    unawaited(m.watch<int>('hr', c2.future, const Duration(seconds: 40)));
    t = t.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    expect(m.netSlow, isTrue, reason: 'the check failed: no internet');
    expect(netLineKind(m), 'slow');
    c2.complete(1);
    await tester.pump();
  });

  testWidgets('the check\'s result counts for 15 s; before any check nothing is shown (not known yet)', (tester) async {
    final gate = Completer<int?>();
    m.internetCheck = () => gate.future;
    final c = Completer<int>();
    unawaited(m.watch<int>('mech', c.future, const Duration(seconds: 40)));
    t = t.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    expect(m.netSlow, isNull);
    expect(netLineKind(m), '', reason: 'the check is on its way: no line yet');
    gate.complete(3000);
    await tester.pump();
    expect(netLineKind(m), 'slow');
    t = t.add(const Duration(seconds: 16));
    expect(m.netSlow, isNull, reason: 'older than 15 s: not known again');
    c.complete(1);
    await tester.pump();
  });

  testWidgets('no answer within the limit: a timeout is counted then (a later answer is not counted again)', (tester) async {
    final c = Completer<int>();
    unawaited(m.watch<int>('hr', c.future, const Duration(seconds: 40)));
    await tester.pump(const Duration(seconds: 41));
    expect(m.recent('hr').single.end, NetEnd.timeout);
    c.complete(1);
    await tester.pump();
    expect(m.recent('hr').length, 1);
  });

  test('off (the tests of the other screens, the background alarm): nothing is recorded, nothing asked', () {
    var asked = 0;
    m
      ..on = false
      ..internetCheck = () async {
        asked++;
        return 1;
      };
    m.record('mech', 100, NetEnd.noConnection);
    expect(m.servers, isEmpty);
    expect(asked, 0);
  });

  test('Api: every request of OUR servers is measured under its name; a file\'s own link and the IFSC list are not', () async {
    final seen = <String>[];
    final api = Api(
        portalUrl: 'https://erp.test/portal',
        keep: MemoryKeep(),
        client: MockClient((r) async {
          seen.add('${r.url}');
          if (r.url.path.endsWith('/api/jwks')) return http.Response('{"keys":[]}', 200);
          if (r.url.path.endsWith('/api/auth')) return http.Response(jsonEncode({'error': 'Wrong password'}), 401);
          return http.Response('{}', 503);
        }))
      ..mechUrl = 'https://erp.test';
    expect(api.serverOf(Uri.parse('https://erp.test/portal/api/auth')), 'portal');
    expect(api.serverOf(Uri.parse('https://erp.test/api/rpc')), 'mech');
    expect(api.serverOf(Uri.parse('https://files.test/x.jpg?token=1')), '');
    await api.probe();
    expect(m.recent('portal').single.end, NetEnd.ok);
    await expectLater(api.auth({'action': 'login'}), throwsA(isA<ApiError>()));
    expect(m.recent('portal').length, 2, reason: 'a refusal (401) is an answer: the server is there');
    expect(m.recent('portal').last.end, NetEnd.ok);
    await api.ifsc('SBIN0000001');
    expect(m.servers, ['portal'], reason: 'the IFSC list is not ours');
    await expectLater(api.store('S1', 'https://erp.test/store', {'action': 'x'}), throwsA(anything));
    expect(m.recent('portal').map((x) => x.end), contains(NetEnd.serverError), reason: 'its ticket: 503 from the Portal');
    expect(api.serverOf(Uri.parse('https://erp.test/store/api/items')), 'store', reason: 'the Store\'s address, once used, is known');
    expect(api.serverOf(Uri.parse('https://erp.test/storefront')), 'mech', reason: 'a longer word is not the Store');
  });

  testWidgets('the chip says what was measured; a tap opens the sheet with each server; Check now asks the Portal and Android\'s check', (tester) async {
    var probes = 0, checks = 0;
    m
      ..probe = () async {
        probes++;
        ok('portal', 180);
      }
      ..internetCheck = () async {
        checks++;
        return 140;
      };
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: NetChip()))));
    expect(find.text('Checking'), findsOneWidget);
    ok('mech', 240);
    ok('mech', 260);
    ok('hr', 310);
    await tester.pump();
    expect(find.text('260 ms'), findsOneWidget, reason: 'the middle time of the answers of the last 2 minutes');
    await tester.tap(find.byKey(const Key('net-chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('net-server-mech')), findsOneWidget);
    expect(find.byKey(const Key('net-server-hr')), findsOneWidget);
    expect(find.byKey(const Key('net-server-store')), findsNothing, reason: 'a server not used is not listed with a made-up time');
    await tester.tap(find.byKey(const Key('net-check')));
    await tester.pumpAndSettle();
    expect([probes, checks], [1, 1]);
    expect(find.byKey(const Key('net-server-portal')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the line under the header: shown for no internet (through the app\'s message bar), × hides it until the state changes, gone when good again', (tester) async {
    await tester.pumpWidget(MaterialApp(scaffoldMessengerKey: netMessenger, home: const NetHost(child: Scaffold(appBar: null, body: SizedBox()))));
    ok('mech', 200);
    m.internetCheck = () async => null;
    m.record('mech', 100, NetEnd.noConnection);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('net-line-offline')), findsOneWidget);
    await tester.tap(find.byKey(const Key('net-line-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('net-line-offline')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('net-line-offline')), findsNothing, reason: 'hidden until the state changes');
    m.reset();
    for (final x in [200, 210, 220]) {
      ok('mech', x);
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a page from its saved copy says so with the time; the live answer: "Live · just now", then the line goes', (tester) async {
    final at = DateTime(2026, 11, 25, 10, 12);
    Widget page(String k) => MaterialApp(home: Scaffold(body: Column(children: [SavedLine(kind: k, at: at)])));
    await tester.pumpWidget(page('saved'));
    expect(find.textContaining('Saved 10:12 AM · refreshing'), findsOneWidget);
    await tester.pumpWidget(page(afterAnswer('saved')));
    expect(find.text('Live · just now'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Live · just now'), findsNothing);
    await tester.pumpWidget(page('stale'));
    expect(find.text('Saved 10:12 AM · not live'), findsOneWidget);
    expect(afterAnswer(''), '', reason: 'a first opening (no copy shown) shows no line');
  });

  testWidgets('a header with no room (withAsk, hrHead): the chip HANGS on its lower edge on the right – the title keeps its room; a box over the page: not shown', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: NetHost(
            child: Scaffold(
                appBar: AppBar(title: const Text('New Diesel Issue'), actions: const [NetPin(), SizedBox(width: 40)]),
                body: Builder(builder: (c) => TextButton(onPressed: () => showDialog<void>(context: c, builder: (_) => const AlertDialog(content: Text('box'))), child: const Text('open')))))));
    await tester.pump(const Duration(milliseconds: 300));
    final chip = find.byType(NetChip);
    expect(chip, findsOneWidget);
    final r = tester.getRect(chip), bar = tester.getRect(find.byType(AppBar));
    expect((r.center.dy - bar.bottom).abs() < 2, true, reason: 'on the header\'s lower edge (${r.center.dy} / ${bar.bottom})');
    expect((800 - r.right - 16).abs() < 1, true, reason: '16 from the right');
    expect(tester.getRect(find.text('New Diesel Issue')).width > 100, true, reason: 'the title keeps its room');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NetChip), findsNothing, reason: 'a box over the page');
    await tester.pumpWidget(const SizedBox());
  });
}

