import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/session.dart';

import 'fake_server.dart';

void main() {
  late FakeServer srv;
  late MemoryKeep keep;
  Session make() => Session(Api(portalUrl: 'https://erp.test/portal', mechUrl: 'https://erp.test', keep: keep, client: srv.client));
  setUp(() {
    srv = FakeServer();
    keep = MemoryKeep();
  });

  test('sign in ONCE on the Portal → his Mechanical sites → a ticket → Mechanical on that site (nothing else typed)', () async {
    final s = make();
    await s.start();
    expect(s.stage, Stage.signedOut);
    await s.signIn('sujit@rcl.test', 'wrong-one');
    expect(s.stage, Stage.signedOut);
    expect(s.error, 'Email or password is wrong.');
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s.stage, Stage.pickSite, reason: 'two sites with Mechanical: he picks one (the Store item is not a site of the app)');
    expect(s.sites.map((x) => x.code).toList(), ['S1', 'T2']);
    await s.switchSite('S1');
    expect(s.stage, Stage.ready);
    expect(srv.calls, containsAllInOrder(['portal:login', 'portal:me', 'portal:go:S1', 'mech:ssoLogin:tk1', 'mech:getInit']));
    expect(keep.data['portal_cookie'], 'rcl_portal=abc123');
    expect(keep.data['mech_token'], 'tok-tk1');
    expect(s.stockTotal, 813);
    expect(s.machines.length, 3);
  });

  test('the same access as on the web: Edit / View / None', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.switchSite('S1');
    expect(s.canEdit('Diesel Issue'), true);
    expect(s.canSee('Diesel Inward'), true);
    expect(s.canEdit('Diesel Inward'), false);
    expect(s.canSee('Diesel Transfer'), false, reason: 'None: the tile and the list are not shown');
  });

  test('the app opens again later: the kept sign-in is used – no sign-in screen', () async {
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s1.switchSite('T2');
    srv.calls.clear();
    final s2 = make();
    await s2.start();
    expect(s2.stage, Stage.ready);
    expect(s2.siteCode, 'T2', reason: 'the site last opened');
  });

  test('a Mechanical sign-in that ended is renewed by itself (a new ticket) and the action goes on', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.switchSite('S1');
    srv.calls.clear();
    srv.expireOnce = 'getDieselIssues';
    final r = await s.api.call('getDieselIssues', [{'from': '2026-10-13', 'to': '2026-10-13'}]) as Map;
    expect(r['count'], 3);
    expect(srv.calls, ['mech:getDieselIssues', 'portal:go:S1', 'mech:ssoLogin:tk2', 'mech:getDieselIssues']);
  });

  test('the Portal does not know him any more: back to the sign-in screen', () async {
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s1.switchSite('S1');
    srv.portalSignedIn = false;
    final s2 = make();
    await s2.start();
    expect(s2.stage, Stage.signedOut);
    expect(keep.data.containsKey('portal_cookie'), false, reason: 'the old sign-in is forgotten');
  });

  test('a save carries its own number (rid); a reading warning comes back as a question', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.switchSite('S1');
    final w = await s.api.call('saveDieselIssue', [{'no': 'MH-04-KU-3331', 'qty': 50, 'hrReading': 1, 'force': false}], true) as Map;
    expect(w['warning'], contains('Save anyway'));
    final ok = await s.api.call('saveDieselIssue', [{'no': 'MH-04-KU-3331', 'qty': 50, 'hrReading': 1, 'force': true}], true) as Map;
    expect(ok['id'], 'DI-000104');
    expect(srv.calls.where((c) => c == 'mech:saveDieselIssue+rid').length, 2);
  });

  test('sign out: Mechanical and the Portal, and nothing kept on the phone', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.switchSite('S1');
    await s.signOut();
    expect(s.stage, Stage.signedOut);
    expect(srv.calls, containsAll(['mech:logout', 'portal:logout']));
    expect(keep.data, isEmpty);
  });
}
