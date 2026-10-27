/* (3.48.0, asked 27-10-2026: "a complete, production-grade performance optimization … Record baseline measurements before
 * optimization. Clearly distinguish measured bottlenecks from suspected ones") THE APP'S OWN WORK, MEASURED with the pretend
 * servers (they answer at once: what is measured is the phone's own work, never the network):
 *   – what the app asks the server (at sign-in, at a new opening, in an idle minute, after one change by another person),
 *   – how much of the screen is built again (every widget built again is counted – Flutter's debugOnRebuildDirtyWidget),
 *   – how long the app's own work takes (the build's computer, debug mode – compare runs with each other, not with a phone).
 * Each test writes its numbers into the build's notes ("::notice title=perf …"). */
// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rcl_mobile/core/answers.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/main.dart';
import 'package:rcl_mobile/screens/entries.dart' show EntriesTab, EntryCard;
import 'package:rcl_mobile/screens/home.dart' show HomeTab;
import 'package:rcl_mobile/screens/me.dart' show MeTab;
import 'package:rcl_mobile/screens/reports.dart' show ReportsTab;

import 'fake_server.dart';
import 'screens_test.dart' show loadFonts, net, ready, settle;

/// Every widget built again while [on]: how many, of which kind.
class Builds {
  final byType = <String, int>{};
  int n = 0;
  void start() {
    reset();
    debugOnRebuildDirtyWidget = (e, _) {
      n++;
      final k = '${e.widget.runtimeType}';
      byType[k] = (byType[k] ?? 0) + 1;
    };
  }

  void reset() {
    n = 0;
    byType.clear();
  }

  void stop() => debugOnRebuildDirtyWidget = null;
  int of(Type t) => byType['$t'] ?? 0;
  String top([int k = 6]) => (byType.entries.toList()..sort((x, y) => y.value - x.value)).take(k).map((e) => '${e.key} ${e.value}').join(', ');
  String get tabs => 'Home ${of(HomeTab)}, Entries ${of(EntriesTab)}, Reports ${of(ReportsTab)}, Me ${of(MeTab)}';
}

/// The calls since [from] (srv.calls), counted by name.
Map<String, int> countCalls(List<String> calls, [int from = 0]) {
  final m = <String, int>{};
  for (final c in calls.skip(from)) {
    m[c] = (m[c] ?? 0) + 1;
  }
  return m;
}

String callsText(Map<String, int> m) => m.entries.map((e) => '${e.key.replaceFirst('mech:', '')}×${e.value}').join(', ');

/// A note in the build's summary (GitHub's workflow command; % and new lines escaped as it asks).
void notice(String title, List<String> lines) =>
    print('::notice title=perf $title::${lines.map((l) => l.replaceAll('%', '%25')).join('%0A')}');

double ms(Duration d) => d.inMicroseconds / 1000;
String f1(num x) => x.toStringAsFixed(1);

/// The middle and the 95th of [xs] (ms).
String p50p95(List<double> xs) {
  final s = [...xs]..sort();
  if (s.isEmpty) return '–';
  return 'P50 ${f1(s[s.length ~/ 2])} ms, P95 ${f1(s[((s.length - 1) * .95).round()])} ms, max ${f1(s.last)} ms';
}

void main() {
  setUpAll(loadFonts);
  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  /// [secs] seconds of the app's own clock (its timers, the live sync), the answers let in every half second
  Future<void> wait(WidgetTester t, int secs, {void Function(int tenth)? each}) async {
    for (var i = 0; i < secs * 10; i++) {
      if (i % 5 == 0) await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await t.pump(const Duration(milliseconds: 100));
      each?.call(i + 1);
    }
  }

  testWidgets('perf: sign-in, a new opening, an idle minute on Home, one change by another person, one redraw of the session', (t) async {
    phone(t);
    final srv = FakeServer(), b = Builds();
    // 1. the first sign-in (Portal → site → Home shown)
    final sw = Stopwatch()..start();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    final firstMs = sw.elapsedMilliseconds;
    final first = countCalls(srv.calls);
    final firstDup = first.entries.where((e) => e.value > 1 && !e.key.contains('sync')).map((e) => '${e.key}×${e.value}').toList();

    // 2. an idle minute on Home: what is asked, what is built again
    var from = srv.calls.length;
    b.start();
    var frames = 0;
    await wait(t, 60, each: (_) {
      if (t.binding.hasScheduledFrame) frames++;
    });
    b.stop();
    final idle = countCalls(srv.calls, from), idleBuilds = b.n, idleTop = (b.byType.entries.toList()..sort((x, y) => y.value - x.value)).take(5).map((e) => '${e.key} ${e.value}').join(', ');

    // 3. another person issues 40 L at the Dispenser: the next sync tells; how soon Home shows it, what is asked, what is built
    from = srv.calls.length;
    var notes = 0, shownAt = -1;
    void note() => notes++;
    s.addListener(note);
    srv.stockNow = {'stock': 1093, 'byLoc': {'Dispenser': 773, 'VTR Store': 320}};
    srv.versions['stock'] = '2';
    srv.versions['log'] = '2';
    b.start();
    final cw = Stopwatch()..start();
    await wait(t, 4, each: (tenth) {
      if (shownAt < 0 && find.text('773 L').evaluate().isNotEmpty) shownAt = tenth * 100;
    });
    cw.stop();
    b.stop();
    s.removeListener(note);
    final change = countCalls(srv.calls, from), changeBuilds = b.n, changeTabs = b.tabs;
    expect(s.stockByLoc['Dispenser'], 773, reason: 'the session has the new stock');

    // 4. one redraw of the whole session (any notifyListeners: a stock, a count of approvals …) – how much is built for it:
    // the same stock again (a save's answer …), then a stock that changed
    b.start();
    final rw = Stopwatch()..start();
    s.setStock({'stock': s.stockTotal, 'byLoc': {...s.stockByLoc}});
    await t.pump();
    rw.stop();
    b.stop();
    final sameBuilds = b.n;
    b.start();
    final rw2 = Stopwatch()..start();
    s.setStock({'stock': 1092, 'byLoc': {'Dispenser': 772, 'VTR Store': 320}});
    await t.pump();
    rw2.stop();
    b.stop();
    final oneBuilds = b.n, oneTabs = b.tabs, oneTop = b.top();
    expect(find.text('772 L'), findsOneWidget);

    // 5. a new opening of the app (his sign-in kept on the phone): what is asked until Home is shown
    await t.pumpWidget(const SizedBox());
    await settle(t, 300);
    from = srv.calls.length;
    final s2 = Session(Api(portalUrl: 'https://erp.test/portal', keep: s.api.keep, client: srv.client))..clock = s.clock;
    final ow = Stopwatch()..start();
    await t.runAsync(s2.start);
    await t.pumpWidget(RclApp(session: s2));
    await net(t);
    ow.stop();
    final open = countCalls(srv.calls, from);
    final openDup = open.entries.where((e) => e.value > 1 && !e.key.contains('sync')).map((e) => '${e.key}×${e.value}').toList();
    await t.pumpWidget(const SizedBox());
    await settle(t, 300);

    notice('A sign-in and a new opening', [
      'first sign-in → Home: ${first.values.fold<int>(0, (a, x) => a + x)} calls (${callsText(first)}) · ${firstMs} ms of the app\'s own work (no network)',
      'asked twice or more: ${firstDup.isEmpty ? 'none' : firstDup.join(', ')}',
      'new opening (sign-in kept) → Home: ${open.values.fold<int>(0, (a, x) => a + x)} calls (${callsText(open)}) · ${ow.elapsedMilliseconds} ms',
      'asked twice or more: ${openDup.isEmpty ? 'none' : openDup.join(', ')}',
    ]);
    notice('An idle minute on Home', [
      'calls: ${callsText(idle)}',
      'widgets built again: $idleBuilds${idleTop.isEmpty ? '' : ' ($idleTop)'} · frames asked: $frames of 600 tenths',
    ]);
    notice('One change by another person (stock + Log Book)', [
      'shown on Home after ${shownAt < 0 ? 'NOT within 4 s' : '$shownAt ms'} (the 2 s sync)',
      'calls: ${callsText(change)}',
      'session redraws (notifyListeners): $notes · widgets built again: $changeBuilds · tabs built: $changeTabs',
      'the same stock again (a save\'s answer): $sameBuilds widgets built again · its frame ${f1(ms(rw.elapsed))} ms',
      'a stock that changed: $oneBuilds widgets built again (tabs: $oneTabs) · its frame ${f1(ms(rw2.elapsed))} ms',
      '  most built: $oneTop',
    ]);
    expect(srv.calls.where((c) => c == 'mech:sync').length, greaterThan(10), reason: 'the live sync ran in the measured minute');
    expect(shownAt, greaterThan(0), reason: 'another person\'s change is shown on Home');
  });

  testWidgets('perf: a big site – 300 machinery, 300 diesel issues and 300 Log Book lines today: Home, the Entries list, its scroll', (t) async {
    phone(t);
    final srv = FakeServer()..big = 300, b = Builds();
    final sw = Stopwatch()..start();
    final s = await ready(t, srv);
    final signIn = sw.elapsedMilliseconds;
    expect(s.machines.length, greaterThan(300));
    b.start();
    final hw = Stopwatch()..start();
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    hw.stop();
    b.stop();
    final homeBuilds = b.n;
    // one redraw of the session on this big site (a stock that changed)
    b.start();
    final rw = Stopwatch()..start();
    s.setStock({'stock': 1092, 'byLoc': {'Dispenser': 772, 'VTR Store': 320}});
    await t.pump();
    rw.stop();
    b.stop();
    final oneBuilds = b.n, oneTabs = b.tabs;
    // the Entries tab → Diesel Issue: 300 entries
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    b.start();
    final ew = Stopwatch()..start();
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    ew.stop();
    b.stop();
    final cards = b.of(EntryCard);
    expect(find.textContaining('300 entries'), findsOneWidget);
    // its scroll: 120 frames of a finger moving up (16 ms each) – the time of each frame
    final times = <double>[];
    b.start();
    final g = await t.startGesture(t.getCenter(find.byType(CustomScrollView).first));
    for (var i = 0; i < 120; i++) {
      final fw = Stopwatch()..start();
      await g.moveBy(const Offset(0, -40));
      await t.pump(const Duration(milliseconds: 16));
      times.add(ms(fw.elapsed));
    }
    await g.up();
    await settle(t, 600);
    b.stop();
    final scrollCards = b.of(EntryCard);
    // back to the top (the search box scrolled away with the list)
    await t.fling(find.byType(CustomScrollView).first, const Offset(0, 8000), 6000);
    await settle(t, 1200);
    // typing in its search box: each letter
    final typed = <double>[];
    b.start();
    for (final q in ['M', 'MH', 'MH-1', 'MH-12-BG-11']) {
      final tw = Stopwatch()..start();
      await t.enterText(find.byType(TextField).first, q);
      await t.pump();
      typed.add(ms(tw.elapsed));
    }
    b.stop();
    final typedN = b.n ~/ 4, typedTop = b.top();
    // a machinery looked up by its number (each entry card, each form, the Log Book rows …): 300 looks among the Master
    final ids = [for (var i = 0; i < 300; i++) 'MH 12 BG ${1000 + (i * 7) % 300}'];
    String lookOld() {
      final w = Stopwatch()..start();
      for (final id in ids) {
        final k = id.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        for (final m in s.machines) {
          if (m.id.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '') == k) break;
        }
      }
      return f1(ms(w.elapsed));
    }
    String lookNow() {
      final w = Stopwatch()..start();
      for (final id in ids) {
        s.machine(id);
      }
      return f1(ms(w.elapsed));
    }
    final looks = 'one by one through the list (as before 3.48.0) ${lookOld()} ms · s.machine() ${lookNow()} ms';
    for (final id in ids.take(20)) {
      final k = id.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      expect(s.machine(id), same(s.machines.firstWhere((m) => m.id.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '') == k)), reason: 'the same machinery as before');
    }
    expect(s.machine('NO SUCH'), isNull);
    notice('A big site (300 machinery, 300 issues, 300 Log Book lines today)', [
      'sign-in + site: $signIn ms · Home shown in ${hw.elapsedMilliseconds} ms (with the pretend server\'s answers), $homeBuilds widgets built',
      'one session redraw: $oneBuilds widgets built again (tabs: $oneTabs), its frame ${f1(ms(rw.elapsed))} ms',
      'Entries → Diesel Issue (300): ${ew.elapsedMilliseconds} ms, $cards entry cards built (the list builds only what is seen)',
      'scroll, 120 frames: ${p50p95(times)} · $scrollCards cards built while scrolling',
      'search, each letter: ${p50p95(typed)} · $typedN widgets built a letter ($typedTop)',
      '300 machinery looked up: $looks',
    ]);
  });

  testWidgets('(3.48.0) a hidden tab is not built again for the session\'s redraws – and shows the change the moment it is seen', (t) async {
    phone(t);
    final srv = FakeServer(), b = Builds();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    // another person issues 40 L while he is on Me: Home is under it
    srv.stockNow = {'stock': 1093, 'byLoc': {'Dispenser': 773, 'VTR Store': 320}};
    srv.versions['stock'] = '2';
    b.start();
    await wait(t, 7); // (on Me the sync asks every 5 s)
    b.stop();
    expect(s.stockByLoc['Dispenser'], 773, reason: 'the session has the new stock');
    final hidden = b.of(HomeTab) + b.of(EntriesTab) + b.of(ReportsTab);
    notice('A redraw while on Me', ['tabs built: ${b.tabs} · widgets built again: ${b.n}']);
    expect(hidden, 0, reason: 'the hidden tabs are not built again');
    await t.tap(find.byKey(const Key('tab-home')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('773 L'), findsOneWidget, reason: 'Home seen again: the new stock at once');
    expect(find.text('813 L'), findsNothing);
  });

  testWidgets('(3.48.0) Home: an older answer that comes after a newer one is not shown over it', (t) async {
    phone(t);
    final srv = FakeServer()..big = 5;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.textContaining(RegExp(r'^5 / ')), findsOneWidget, reason: '5 machinery worked today');
    // 1. a Log Book entry by another person: Home asks again – this answer is slow (5 s, a weak network)
    srv.slowOnce['getLogBookList'] = const Duration(seconds: 5);
    srv.versions['log'] = '2';
    await wait(t, 3);
    // 2. two more entries: Home asks again – this answer comes at once: 7
    srv.big = 7;
    srv.versions['log'] = '3';
    await wait(t, 3);
    expect(find.textContaining(RegExp(r'^7 / ')), findsOneWidget, reason: 'the newest answer');
    // 3. the slow, older answer (5) comes now
    await wait(t, 3);
    expect(find.textContaining(RegExp(r'^7 / ')), findsOneWidget, reason: 'the older answer does not take the place of the newer one');
    expect(find.textContaining(RegExp(r'^5 / ')), findsNothing);
    expect(s.stage, Stage.ready);
  });

  test('perf: the phone\'s own work on big answers – read, decode, fingerprint; an answer "the same" again', () async {
    final srv = FakeServer()..big = 800;
    String timeOf(void Function() f, [int n = 9]) {
      final xs = <double>[];
      for (var i = 0; i < n; i++) {
        final w = Stopwatch()..start();
        f();
        xs.add(ms(w.elapsed));
      }
      xs.sort();
      return f1(xs[n ~/ 2]);
    }

    final lines = <String>[];
    for (final (name, res) in [
      ('getInit master of 800 machinery', {'master': srv.bigMaster, 'today': '2026-10-14'}),
      ('2,400 diesel issues', {'rows': [for (var i = 0; i < 3; i++) ...srv.bigIssues], 'count': 2400}),
    ]) {
      final text = jsonEncode(res), body = '{"h":"${fingerprint(text)}","result":$text}', bytes = utf8.encode(body);
      lines.add('$name: ${(bytes.length / 1024).round()} KB · utf8 ${timeOf(() => utf8.decode(bytes))} ms · json ${timeOf(() => jsonDecode(text))} ms · '
          'fingerprint ${timeOf(() => fingerprint(text))} ms');
      // through the app's Api: the whole answer, then "the same" (a few bytes) – the time of each call on the phone
      final h = fingerprint(text);
      var n = 0;
      final client = MockClient((r) async {
        final b = jsonDecode(r.body) as Map;
        if (n++ > 0 && b['have'] == h) return http.Response('{"h":"$h","same":1}', 200);
        return http.Response.bytes(bytes, 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final api = Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: client)
        ..mechUrl = 'https://erp.test'
        ..token = 'tok'
        ..site = 'S1';
      final whole = <double>[], same = <double>[];
      for (var i = 0; i < 9; i++) {
        api.answers.clear();
        n = 0;
        var w = Stopwatch()..start();
        await api.call('getDieselIssues', [{}]);
        whole.add(ms(w.elapsed));
        w = Stopwatch()..start();
        final again = await api.call('getDieselIssues', [{}]);
        same.add(ms(w.elapsed));
        expect(jsonEncode(again), text, reason: '"the same" gives exactly the answer');
      }
      whole.sort();
      same.sort();
      lines.add('  Api call: whole ${f1(whole[4])} ms · "the same" ${f1(same[4])} ms');
    }
    // the machinery of getInit made into the app's own (loadInit)
    lines.add('800 machinery made the app\'s own (Machine): ${timeOf(() => srv.bigMaster.map((m) => Machine(m)).toList())} ms');
    notice('Big answers on the phone (decode, fingerprint)', lines);
  });
}
