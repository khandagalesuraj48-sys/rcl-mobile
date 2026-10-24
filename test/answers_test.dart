/* (Mechanical update-155) "the same as you have" / only what changed: the app ends with exactly the server's answer every time.
 * test/fixtures/answers155.json was made from Mechanical's own server code (server/delta.js of update-155): what the server
 * answers, step by step, to a page that keeps its answers – whole, "the same", only the changes, a change that does not rebuild
 * the answer (tampered) and what follows it. The app's requests are checked against it (the fingerprint it sends). */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rcl_mobile/core/answers.dart';
import 'package:rcl_mobile/core/alerts.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/session.dart';

import 'fake_server.dart';

void main() {
  final fx = jsonDecode(File('test/fixtures/answers155.json').readAsStringSync()) as Map<String, dynamic>;
  final steps = (fx['steps'] as List).cast<Map<String, dynamic>>();

  test('the pieces and the patch are the server\'s: every step\'s changes rebuild exactly its answer', () {
    var base = '';
    for (final st in steps) {
      final j = jsonDecode(st['response'] as String) as Map<String, dynamic>;
      if (st['kind'] == 'delta' && !(st['label'] as String).contains('tampered')) {
        final t = rclPatch(base, j['delta']);
        expect(t, st['answer'], reason: st['label'] as String);
        expect(fingerprint(t!), j['h']);
      }
      if (st['kind'] != 'delta' || !(st['label'] as String).contains('tampered')) base = st['answer'] as String;
    }
    expect(rclSplit('[{"a":1},{"b":[1,2],"c":3}]'), ['[{"a":1},', '{"b":[1,2],', '"c":3}]']);
    expect(rclPatch('[{"a":1},{"b":2}]', [[5, 1]]), isNull, reason: 'a piece the base does not have');
    expect(rclPatch('[{"a":1},{"b":2}]', 'x'), isNull);
    expect(fingerprint('{"x":"मराठी"}'), '78f177a9280d98607bdd5f117db50848', reason: 'the same as Node\'s sha256 of the UTF-8 text');
  });

  test('Api: asks with the fingerprint it has, rebuilds, checks, and asks whole again when a change does not fit', () async {
    var n = 0;
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((r) async {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      bodies.add(b);
      if (n >= steps.length) {
        // (after the recorded steps) the same answer again: "the same"
        final last = steps.last['answer'] as String;
        expect(b['have'], fingerprint(last));
        return http.Response('{"h":"${fingerprint(last)}","same":1}', 200);
      }
      final st = steps[n++];
      expect(b['have'], st['have'], reason: 'request ${n - 1} (${st['label']}): the fingerprint the app has');
      expect(b['m'], 1);
      return http.Response.bytes(utf8.encode(st['response'] as String), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final api = Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: client)
      ..mechUrl = 'https://erp.test'
      ..token = 'tok-155'
      ..site = fx['site'] as String;
    final args = (fx['args'] as List)[2] as List;
    var i = 0;
    while (n < steps.length) {
      final st = steps[n];
      final got = await api.call('getDieselIssues', args);
      // the step answered is the last one the server sent (after a tampered change: the whole answer that followed)
      expect(got, jsonDecode(steps[n - 1]['answer'] as String), reason: 'call $i (${st['label']})');
      i++;
    }
    expect(api.answers.same, 2);
    expect(api.answers.delta, 3);
    expect(api.answers.mismatch, 1);
    expect(bodies.where((b) => b['dx'] == 1).length, bodies.where((b) => b['have'] != null).length);
    // every caller gets its own copy
    final a1 = await _again(api, args, steps), a2 = await _again(api, args, steps);
    (a1 as Map)['rows'] = [];
    expect((a2 as Map)['rows'], isNotEmpty);
  });

  test('Api: a save never goes this way; a refusal, sign-out and another site drop what was kept', () async {
    final sent = <Map<String, dynamic>>[];
    var refuse = false;
    final client = MockClient((r) async {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      sent.add(b);
      if (refuse) return http.Response(jsonEncode({'error': 'You do not have access to Diesel Issue. Ask Admin.'}), 403);
      if (b['m'] == 1) return http.Response('{"h":"${fingerprint('{"rows":[1,2,3]}')}","result":{"rows":[1,2,3]}}', 200);
      return http.Response('{"result":{"ok":true}}', 200);
    });
    final api = Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: client)
      ..mechUrl = 'https://erp.test'
      ..token = 'tok'
      ..site = 'S1';
    await api.call('saveDieselIssue', [{'qty': 1}], true);
    expect(sent.last.containsKey('m'), isFalse);
    expect(sent.last.containsKey('have'), isFalse);
    expect('${sent.last['rid']}', startsWith('m'));
    await api.call('getDieselIssues', [{}]);
    expect(api.answers.length, 1);
    refuse = true;
    await expectLater(api.call('getDieselIssues', [{}]), throwsA(isA<ApiError>()));
    expect(api.answers.length, 0, reason: 'refused: nothing of it is kept');
    refuse = false;
    await api.call('getDieselIssues', [{}]);
    expect(sent.last.containsKey('have'), isFalse);
    await api.call('getDieselIssues', [{}]);
    expect(sent.last['have'], isNotNull);
    await api.keepSite('S2');
    expect(api.answers.length, 0, reason: 'another site');
    api.token = 'tok';
    await api.call('getDieselIssues', [{}]);
    await api.forget();
    expect(api.answers.length, 0, reason: 'signed out');
  });

  test('Session: the live rhythm follows the tab (Home / Entries 2 s, Reports / Me 5 s); sign-out and another site empty the memory', () async {
    final srv = FakeServer(), keep = MemoryKeep();
    final s = Session(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client));
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    s.screen = 'home';
    expect(s.liveGap(), const Duration(seconds: 2));
    s.showing('entries');
    expect(s.liveGap(), const Duration(seconds: 2));
    s.showing('reports');
    expect(s.liveGap(), const Duration(seconds: 5));
    s.showing('me');
    expect(s.liveGap(), const Duration(seconds: 5));
    var cleared = 0;
    void f() => cleared++;
    Session.memoryClears.add(f);
    await s.liveTick();
    expect(await keep.read(kLiveAt), isNotNull, reason: 'the app marks that it is open and asking (the alarm does not ask then)');
    await s.signOut();
    expect(cleared, 1, reason: 'sign-out: what the screens kept is emptied');
    expect(s.api.answers.length, 0);
    expect(await keep.read(kLiveAt), isNull);
    Session.memoryClears.remove(f);
  });

  test('alarm: with the app open and asking, the background alarm does not fetch the Approvals list again', () async {
    final srv = FakeServer(), keep = MemoryKeep();
    final s = Session(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client));
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    await s.liveTick();
    srv.calls.clear();
    await backgroundAlerts(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client));
    expect(srv.calls.where((c) => c.contains('getChangeRequests')), isEmpty, reason: 'the app is open: its own sync tells');
    await keep.write(kLiveAt, '${DateTime.now().millisecondsSinceEpoch - 600000}');
    await backgroundAlerts(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client));
    expect(srv.calls.where((c) => c.contains('getChangeRequests')), isNotEmpty, reason: 'the app closed for 10 minutes: the alarm asks as before');
  });

  test('Api: no answer at all – a question and a numbered save are sent again; a change without a number is not', () async {
    final tries = <String, int>{};
    final client = MockClient((r) async {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      final fn = '${(b['args'] as List)[1]}';
      tries[fn] = (tries[fn] ?? 0) + 1;
      if (tries[fn] == 1) throw http.ClientException('connection reset');
      return http.Response('{"result":{"ok":true}}', 200);
    });
    final api = Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: client)
      ..mechUrl = 'https://erp.test'
      ..token = 'tok'
      ..site = 'S1';
    await api.call('getDieselIssues', [{}]);
    await api.call('saveDieselIssue', [{'qty': 1}], true);
    await expectLater(api.call('sendChangeRequest', [{'fn': 'x'}]), throwsA(isA<ApiError>().having((e) => e.noConnection, 'no connection', true)));
    expect(tries, {'getDieselIssues': 2, 'saveDieselIssue': 2, 'sendChangeRequest': 1});
  });
}

Future<dynamic> _again(Api api, List args, List<Map<String, dynamic>> steps) => api.call('getDieselIssues', args);
