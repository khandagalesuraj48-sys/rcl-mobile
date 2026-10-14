import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/kinds.dart';
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/web/files.dart';
import 'package:rcl_mobile/web/web_host.dart';

import 'fake_server.dart';

void main() {
  late FakeServer srv;
  late MemoryKeep keep;
  Session make() => Session(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client));
  setUp(() {
    srv = FakeServer();
    keep = MemoryKeep();
  });

  test('sign in ONCE on the Portal → his sites with Mechanical → a ticket → Mechanical on that site → its lists', () async {
    final s = make();
    await s.start();
    expect(s.stage, Stage.signedOut);
    await s.signIn('sujit@rcl.test', 'wrong-one');
    expect(s.stage, Stage.signedOut);
    expect(s.error, 'Email or password is wrong.');
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s.stage, Stage.pickSite);
    expect(s.sites.map((x) => x.code).toList(), ['S1', 'T2'], reason: 'not a https address, not a site without Mechanical');
    await s.chooseSite('S1');
    expect(s.stage, Stage.ready);
    expect(srv.calls, containsAllInOrder(['portal:login', 'portal:me', 'portal:go:mechanical:S1', 'mech:ssoLogin:tk1', 'mech:getInit']));
    expect(keep.data['portal_cookie'], 'rcl_portal=abc123');
    expect(keep.data['mech_token'], 'tok-tk1');
    expect(s.stockTotal, 1133);
    expect(s.stockByLoc, {'Dispenser': 813, 'VTR Store': 320});
    expect(s.machines.length, 3);
    expect(s.hasModule('store'), true);
  });

  test('the same access as on the web: Edit / View / None', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    expect(s.canEdit('Diesel Issue'), true);
    expect(s.canSee('Diesel Inward'), true);
    expect(s.canEdit('Diesel Inward'), false);
    expect(s.canSee('Diesel Transfer'), false, reason: 'None: not shown');
    expect(s.admin, false);
  });

  test('the app opens again later: the kept sign-in and site are used – no sign-in, no new Mechanical sign-in', () async {
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s1.chooseSite('T2');
    srv.calls.clear();
    final s2 = make();
    await s2.start();
    expect(s2.stage, Stage.ready);
    expect(s2.site!.code, 'T2');
    expect(srv.calls.where((c) => c != 'mech:getMyPrefs'), ['portal:me', 'mech:getInit']);
    expect(s2.canEdit('Diesel Issue'), true, reason: 'the access comes with getInit too');
  });

  test('a Mechanical sign-in that ended is renewed by itself (a new ticket) and the action goes on', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    srv.calls.clear();
    srv.expireOnce = 'getDieselIssues';
    final r = await s.api.call('getDieselIssues', [{'from': '2026-10-14', 'to': '2026-10-14'}]) as Map;
    expect(r['count'], 4);
    expect(srv.calls.where((c) => c != 'mech:getMyPrefs'), ['mech:getDieselIssues', 'portal:go:mechanical:S1', 'mech:ssoLogin:tk2', 'mech:getDieselIssues']);
  });

  test('another site: its own Mechanical sign-in', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    s.pickAnotherSite();
    expect(s.stage, Stage.pickSite);
    await s.chooseSite('T2');
    expect(s.stage, Stage.ready);
    expect(srv.calls.where((c) => c.startsWith('mech:ssoLogin')).length, 2);
  });

  test('(14-10-2026) an entry of a submitted bill: the change is sent to the Super Admin with a reason, as on the web; the Super Admin saves it', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    srv.billLock = true;
    final asked = <String>[];
    // no answer (Cancel): nothing is sent, the refusal stays as it was
    s.api.askApproval = (m) async { asked.add(m); return null; };
    await expectLater(s.api.call('updateLogRow', ['MH-25-AJ-2169|2026-10-14|Full Day', {'closingKm': 15250}], true), throwsA(predicate((e) => e is ApiError && e.message.contains('submitted RA Bill 9'))));
    expect(srv.requests, isEmpty);
    // a reason: exactly that save goes to the Super Admin; the screen hears "Sent …" (nothing saved)
    s.api.askApproval = (m) async { asked.add(m); return '  meter photo shows 15250 '; };
    await expectLater(s.api.call('updateLogRow', ['MH-25-AJ-2169|2026-10-14|Full Day', {'closingKm': 15250}], true), throwsA(predicate((e) => e is ApiError && e.message == Api.crSent)));
    expect(srv.requests.single, {'fn': 'updateLogRow', 'args': ['MH-25-AJ-2169|2026-10-14|Full Day', {'closingKm': 15250}], 'reason': 'meter photo shows 15250'});
    // a save that answers "not saved" with a refused line (saveLogRows) is offered the same way
    await expectLater(s.api.call('saveLogRows', [{'rows': [{'no': 'MH-25-AJ-2169', 'date': '2026-10-14'}]}], true), throwsA(predicate((e) => e is ApiError && e.message == Api.crSent)));
    expect(srv.requests.length, 2);
    expect(asked.length, 3);
    expect(srv.logSaved, isEmpty, reason: 'nothing is saved by the phone');
    // a question, not a save, is never offered
    expect(s.superAdmin, false);
  });

  test('(14-10-2026) the Super Admin (his ticket says so): his change of a billed entry is saved, nothing is asked', () async {
    srv.superAdmin = true;
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    expect(s.superAdmin, true);
    srv.billLock = true;
    s.api.askApproval = (m) async => fail('the Super Admin is not asked');
    final r = await s.api.call('updateLogRow', ['MH-25-AJ-2169|2026-10-14|Full Day', {'closingKm': 15250}], true) as Map;
    expect(r['ok'], true);
    expect(srv.requests, isEmpty);
  });

  test('a save carries its own number (rid); a reading warning comes back as a question', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    final w = await s.api.call('saveDieselIssue', [{'no': 'Sany 210 (No.1)', 'qty': 50, 'hrReading': 1, 'force': false}], true) as Map;
    expect(w['warning'], contains('Save anyway'));
    final ok = await s.api.call('saveDieselIssue', [{'no': 'Sany 210 (No.1)', 'qty': 50, 'hrReading': 1, 'force': true}], true) as Map;
    expect(ok['id'], 'DI-000526');
    expect(srv.calls.where((c) => c == 'mech:saveDieselIssue+rid').length, 2);
  });

  test('a page of the web opens signed in, straight on its page', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    expect(await s.webUrl('log'), 'https://erp.test/#sso=tk2&page=log');
    expect(await s.webUrl('store__dashboard'), 'https://erp.test/#sso=tk3&page=store__dashboard');
  });

  test('the Portal does not know him any more: the sign-in screen, the old sign-in forgotten', () async {
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s1.chooseSite('S1');
    srv.portalSignedIn = false;
    final s2 = make();
    await s2.start();
    expect(s2.stage, Stage.signedOut);
    expect(keep.data.containsKey('portal_cookie'), false);
  });

  test('the Super Admin opens his sites too (14-10-2026); a password still to be set is sent to the Portal (web)', () async {
    srv.superAdmin = true;
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s.stage, isNot(Stage.signedOut));
    expect(s.sites.map((x) => x.code), contains('S1'));
    await s.signOut();
    srv
      ..superAdmin = false
      ..mustChange = true;
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s.stage, Stage.signedOut);
    expect(s.error, contains('Set your own password'));
  });

  test('sign out: Mechanical and the Portal, nothing kept on the phone', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    await s.signOut();
    expect(s.stage, Stage.signedOut);
    expect(srv.calls, containsAll(['mech:logout', 'portal:logout']));
    expect(keep.data, isEmpty);
  });

  test('the ways a machinery is measured by (as the web): one usual way is picked by itself', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    final sany = s.machine('sany 210 (no.1)')!;
    expect(sany.modesMain, ['Hrs']);
    expect(sany.wayAuto, 'Hrs');
    expect(sany.hasMeter, true);
    expect(hasHr('KM + Hrs') && hasKm('KM + Hrs'), true);
    expect(picOfType('Excavator'), 'building_construction');
    expect(picOfType('Tipper 10 W'), 'articulated_lorry');
    expect(picOfType('Bolero'), 'sport_utility_vehicle');
    expect(picOfType('400 KVA DG'), 'oil_drum');
  });

  test('where a link goes in a web page: the ERP stays in the app; other sites outside; the web\'s Logout = the app\'s sign-out', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    Go go(String u, [bool main = true]) => whereTo(Uri.parse(u), main, s);
    expect(go('https://erp.test/#sso=tk9'), Go.stay);
    expect(go('https://erp.test/portal/?signout=1'), Go.signOut);
    expect(go('https://www.google.com/maps?q=17.6,74.0'), Go.outside);
    expect(go('tel:+919800000000'), Go.outside);
    expect(go('blob:https://erp.test/1234'), Go.stay);
  });

  test('a file from the web: a safe name and its type', () {
    expect(safeFileName('Diesel Issue 2026/10.xlsx'), 'Diesel Issue 2026_10.xlsx');
    expect(safeFileName('   '), 'RCL_file');
    expect(mimeOf('RCL_Master.xlsx', 'application/octet-stream'), contains('spreadsheetml'));
  });

  test('the script for the web pages: answers the app, and hides the One Click film', () {
    final js = File('assets/web_bridge.js').readAsStringSync();
    for (final h in ["'saveFile'", "'print'", "'openUrl'", '__rclAppBack', '__rclAppReady', '#oc_intro{display:none!important}']) {
      expect(js, contains(h), reason: h);
    }
    final pub = File('pubspec.yaml').readAsStringSync();
    expect(pub, contains('- assets/icons3d/'));
    expect(File('assets/brand/rachana_logo.png').existsSync() && File('assets/brand/rachana_mark.png').existsSync(), true);
  });

  test('my settings: his own (Mechanical), his default site (Portal) – it opens at the next sign-in; his password', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    await s.loadPrefs();
    await s.savePrefs({'shift': 'Night', 'loc': 'VTR Store', 'text': 'large'});
    expect(s.pref('shift'), 'Night');
    expect(s.textScale, 1.1);
    expect(srv.calls, contains('mech:saveMyPrefs+rid'));
    await s.setDefaultSite('T2');
    expect(s.defaultSite, 'T2');
    await s.signOut();
    final s2 = make();
    await s2.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s2.stage, Stage.ready, reason: 'the default site opens at once – no list of sites');
    expect(s2.site!.code, 'T2');
    await expectLater(s2.changePassword('wrong', 'New#Pass12345'), throwsA(isA<ApiError>()));
    await s2.changePassword('Nashik#Road848!', 'New#Pass12345');
  });

  test('a machinery\'s ways as the web: its Log Book format fixes them; an hours machinery may also have Time', () {
    expect(Machine({'id': 'X', 'lbFormat': 'F'}).modes, ['Time']);
    expect(Machine({'id': 'X', 'lbFormat': 'C'}).modes, ['KM']);
    expect(Machine({'id': 'X', 'worksOn': ['Hrs']}).modes, ['Hrs', 'Time']);
    expect(Machine({'id': 'X', 'worksOn': ['Hrs']}).wayAuto, 'Hrs');
    expect(Machine({'id': 'X', 'worksOn': ['KM', 'Hrs']}).modes, ['KM', 'Hrs', 'KM + Hrs', 'Time']);
    expect(Machine({'id': 'X', 'lbFormat': 'I'}).waterTanker, true);
  });
}
