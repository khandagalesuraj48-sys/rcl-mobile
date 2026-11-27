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

  test('the middle time of the last 10 answers of the last 2 minutes: under 800 ms GOOD, 800 ms or more WEAK, one answer over 5 s WEAK', () {
    for (final x in [200, 240, 260]) {
      ok('mech', x);
    }
    expect(m.stateOf('mech'), NetState.good);
    expect(m.middleMs('mech'), 240);
    expect(m.state, NetState.good, reason: 'the first state shows at once');
    for (final x in [900, 1200, 1800, 2000]) {
      ok('hr', x);
    }
    expect(m.stateOf('hr'), NetState.weak);
    ok('portal', 300);
    ok('portal', 5200);
    ok('portal', 310);
    expect(m.stateOf('portal'), NetState.weak, reason: 'one answer over 5 s');
    expect(m.worst, (NetState.weak, 'hr'));
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
    expect(m.worst.$1, NetState.weak);
    expect(m.state, NetState.good, reason: 'not yet – it must hold 3 s');
    await tester.pump(const Duration(seconds: 3));
    expect(m.state, NetState.weak);
    expect(m.changedFrom, NetState.good);
  });

  test('a request on its way for more than 5 s: the "slow network" line; done: gone', () async {
    final c = Completer<int>();
    final f = m.watch<int>('mech', c.future, const Duration(seconds: 40));
    expect(m.slowest, isNull);
    t = t.add(const Duration(seconds: 6));
    expect(m.slowest, const Duration(seconds: 6));
    expect(netLineKind(m), 'slow');
    c.complete(1);
    await f;
    expect(m.slowest, isNull);
    expect(m.recent('mech').single.ms, 6000, reason: 'its real time');
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

