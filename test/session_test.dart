import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/alerts.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/photo.dart';
import 'package:rcl_mobile/core/plate.dart';
import 'package:rcl_mobile/core/kinds.dart';
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/screens/verify.dart';
import 'package:rcl_mobile/web/files.dart';

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

  test('(3.39.0) the opening asks the Portal and the site\'s first lists AT THE SAME TIME; signed out at the Portal: nothing of it is used', () async {
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s1.chooseSite('T2');
    srv.calls.clear();
    srv.portalSignedIn = false; // (signed out elsewhere)
    final s2 = make();
    await s2.start();
    expect(s2.stage, Stage.signedOut);
    expect(s2.machines, isEmpty, reason: 'the site\'s answer asked ahead is dropped');
    expect(srv.calls, containsAll(['portal:me', 'mech:getInit']), reason: 'both were asked at once, before the Portal answered');
  });

  test('(3.39.0) a kept site the Portal no longer gives: the answer asked ahead is not used – Which site', () async {
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s1.chooseSite('T2');
    await keep.write('site', 'Q7');
    final s2 = make();
    await s2.start();
    expect(s2.stage, Stage.pickSite);
    expect(s2.machines, isEmpty);
  });

  test('(3.39.0) the answer asked ahead failed (an ended sign-in): asked again the normal way – renewed, the app opens', () async {
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s1.chooseSite('S1');
    srv.calls.clear();
    srv.expireOnce = 'getInit';
    final s2 = make();
    await s2.start();
    expect(s2.stage, Stage.ready);
    expect(s2.machines, isNotEmpty);
    expect(srv.calls.where((c) => c == 'mech:getInit').length, greaterThanOrEqualTo(2), reason: 'the first refused, then asked again');
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
    // (3.33.0 – Mechanical update-152) he gives his reason (the server asks: SA_REASON); the same save goes again with it, as a new save
    final asked = <String>[];
    s.api.askReason = (m) async { asked.add(m); return ' meter photo shows 15250 '; };
    final r = await s.api.call('updateLogRow', ['MH-25-AJ-2169|2026-10-14|Full Day', {'closingKm': 15250}], true) as Map;
    expect(r['ok'], true);
    expect(srv.requests, isEmpty);
    expect(asked.single, startsWith('Super Admin – this save changes 1 locked Log Book entry'));
    expect(srv.saReasons, ['meter photo shows 15250']);
    final ups = srv.rids.where((x) => x.startsWith('updateLogRow:')).toList();
    expect(ups.length, 1, reason: 'the refused try is not numbered as done (it was refused before the number was kept here)');
    // no reason (Cancel): not saved, said so
    s.api.askReason = (m) async => null;
    await expectLater(s.api.call('updateLogRow', ['MH-25-AJ-2169|2026-10-14|Full Day', {'closingKm': 15260}], true), throwsA(predicate((e) => e is ApiError && e.message == 'Not saved – no reason was given.')));
    expect(srv.saReasons.length, 1);
  });

  test('(3.33.0 – Mechanical update-152) an approved entry: a user\'s change is offered to the Super Admin (as for a billed one), with its own words', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    srv.apLock = true;
    final asked = <String>[];
    s.api.askApproval = (m) async { asked.add(m); return 'Close KM typed wrong'; };
    await expectLater(s.api.call('updateLogRow', ['MH-25-AJ-2169|2026-10-14|Full Day', {'closingKm': 15250}], true), throwsA(predicate((e) => e is ApiError && e.message == Api.crSent)));
    expect(Api.crApproved(asked.single), true);
    expect(Api.crLocked(asked.single), true);
    expect(srv.requests.single['reason'], 'Close KM typed wrong');
    expect(Api.saReason('SA_REASON: x'), true);
    expect(Api.saReason('Log Book entry of X'), false);
  });

  test('(14-10-2026) Day / Night by the time: the site\'s hours from getInit (8 AM / 8 PM unless set); his usual shift still wins', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    expect([s.dayFrom, s.nightFrom], ['08:00', '20:00']);
    expect([for (final h in [7, 8, 13, 19, 20, 23, 2]) s.autoShift(DateTime(2026, 10, 14, h, h == 7 ? 59 : 0))], ['Night', 'Day', 'Day', 'Day', 'Night', 'Night', 'Night']);
    s.dayFrom = '20:00';
    s.nightFrom = '06:00';
    expect([s.autoShift(DateTime(2026, 10, 14, 21)), s.autoShift(DateTime(2026, 10, 14, 12))], ['Day', 'Night'], reason: 'a "Day" over midnight');
    s.dayFrom = '08:00';
    s.nightFrom = '20:00';
    s.clock = () => DateTime(2026, 10, 14, 22);
    expect(s.myShift(const ['Day', 'Night']), 'Night');
    s.prefs['shift'] = 'Day';
    expect(s.myShift(const ['Day', 'Night']), 'Day', reason: 'his usual shift (Settings)');
    s.prefs['shift'] = 'Full Day';
    expect([s.myShift(const ['Full Day', 'Day', 'Night']), s.myShift(const ['Day', 'Night'])], ['Full Day', 'Night'], reason: 'Full Day only where the form has it');
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

  test('(3.20.1) no network when the app opens: STILL SIGNED IN – the waiting screen, never the sign-in; it opens by itself when the network is back', () async {
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s1.chooseSite('S1');
    srv.portalDown = true;
    srv.down = true;
    final s2 = make()..retryEvery = const Duration(milliseconds: 200);
    await s2.start();
    expect(s2.stage, Stage.waiting, reason: 'not Stage.signedOut – he did not sign out');
    expect(s2.error, contains('No connection'));
    expect(keep.data['portal_cookie'], 'rcl_portal=abc123', reason: 'the sign-in stays on the phone');
    expect(keep.data['mech_token'], isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(s2.stage, Stage.waiting, reason: 'tried again by itself – still no network: still waiting, still not the sign-in');
    srv.portalDown = false;
    srv.down = false;
    srv.calls.clear();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(s2.stage, Stage.ready, reason: 'the network is back: the app opens by itself, nothing typed');
    expect(s2.site!.code, 'S1');
    expect(srv.calls, isNot(contains('portal:login')));
    s2.dispose();
  });

  test('(3.20.1) "Try again" at once; the server not reached (503) is waited for too; only the Portal saying "not signed in" shows the sign-in', () async {
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s1.chooseSite('T2');
    srv.portalStatus = 503;
    final s2 = make()..retryEvery = const Duration(hours: 1);
    await s2.start();
    expect(s2.stage, Stage.waiting);
    await s2.tryAgain();
    expect(s2.stage, Stage.waiting, reason: 'still not reached');
    srv.portalStatus = 0;
    await s2.tryAgain();
    expect(s2.stage, Stage.ready);
    expect(s2.site!.code, 'T2');
    // a site opened with no network to Mechanical: waiting too, then the site
    srv.down = true;
    await s2.chooseSite('S1');
    expect(s2.stage, Stage.waiting);
    srv.down = false;
    await s2.tryAgain();
    expect(s2.stage, Stage.ready);
    expect(s2.site!.code, 'S1');
    // the Portal does not know him any more (Logout elsewhere, a new password from the Super Admin): the sign-in, as before
    srv.portalSignedIn = false;
    final s3 = make()..retryEvery = const Duration(hours: 1);
    await s3.start();
    expect(s3.stage, Stage.signedOut);
    expect(keep.data.containsKey('portal_cookie'), false);
    s2.dispose();
    s3.dispose();
  });

  test('the Super Admin opens his sites too (14-10-2026)', () async {
    srv.superAdmin = true;
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s.stage, isNot(Stage.signedOut));
    expect(s.sites.map((x) => x.code), contains('S1'));
  });

  test('(15-10-2026) a new user with the password the Super Admin gave sets his own password in the app – no browser', () async {
    srv.mustChange = true;
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s.stage, Stage.setPassword);
    expect(s.sites, isEmpty);
    // the given password wrong: said, still here
    await s.setOwnPassword('wrong', 'Mule#2026x');
    expect(s.stage, Stage.setPassword);
    expect(s.error, contains('Current password is wrong'));
    // too weak: the Portal's rule said
    await s.setOwnPassword('Nashik#Road848!', 'short');
    expect(s.stage, Stage.setPassword);
    expect(s.error, contains('at least 8'));
    expect(srv.mustChange, true);
    // right: set, and the app opens as after a sign-in
    await s.setOwnPassword('Nashik#Road848!', 'Mule#2026x');
    expect(srv.newPassword, 'Mule#2026x');
    expect(srv.mustChange, false);
    expect(s.stage, isNot(anyOf(Stage.signedOut, Stage.setPassword)));
    expect(s.sites.map((x) => x.code), contains('S1'));
    expect(srv.calls.where((c) => c == 'portal:changePassword').length, 3);
  });

  test('(15-10-2026) the app opened again before the own password was set: the same screen; "Back to sign in" signs out', () async {
    srv.mustChange = true;
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s1.stage, Stage.setPassword);
    final s2 = make();
    await s2.start();
    expect(s2.stage, Stage.setPassword);
    await s2.leaveSetPassword();
    expect(s2.stage, Stage.signedOut);
    expect(srv.calls, contains('portal:logout'));
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

  test('a file from the web: a safe name and its type', () {
    expect(safeFileName('Diesel Issue 2026/10.xlsx'), 'Diesel Issue 2026_10.xlsx');
    expect(safeFileName('   '), 'RCL_file');
    expect(mimeOf('RCL_Master.xlsx', 'application/octet-stream'), contains('spreadsheetml'));
  });

  test('(3.18.0) no web page in the app: no web view host, no script for web pages; the app\'s own pictures are there', () {
    expect(File('lib/web/web_host.dart').existsSync(), false);
    expect(File('assets/web_bridge.js').existsSync(), false);
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      expect(f.readAsStringSync(), isNot(contains('openWeb(')), reason: f.path);
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

  // ---------------- 3.1.7 ----------------
  test('(update-115) a machinery that left the site: on site until the day BEFORE its Inactive From (as the server)', () {
    final left = Machine({'id': 'L-1', 'status': 'Inactive', 'activeFrom': '2026-09-01', 'inactiveFrom': '2026-10-01'});
    expect(['2026-08-31', '2026-09-01', '2026-09-30', '2026-10-01', '2026-10-15'].map(left.onSite).toList(), [false, true, true, false, false]);
    expect(Machine({'status': 'Inactive', 'inactiveFrom': ''}).onSite('2026-10-15'), false, reason: 'Inactive with no date: not on site');
    expect(Machine({'status': 'Inactive', 'inactiveFrom': '2026-10-20'}).onSite('2026-10-15'), true, reason: 'leaving next week: still on site today');
    expect(Machine({'status': 'Active'}).onSite('2026-10-15'), true);
    expect(Machine({'status': 'Inactive'}).onSite(''), false, reason: 'no date: as before (Active only)');
    // (3.1.12, update-119) on site several times: 01-01 … 30-06, then again from 01-09
    final back = Machine({'status': 'Active', 'activeFrom': '2026-09-01', 'earlier': [{'from': '2026-01-01', 'until': '2026-07-01'}]});
    expect(['2025-12-31', '2026-01-01', '2026-06-30', '2026-07-01', '2026-08-31', '2026-09-01', '2026-10-15'].map(back.onSite).toList(), [false, true, true, false, false, true, true]);
  });

  test('(update-114) a work under verification: "Sent for verification …" is a sent entry (code sent), asked once – never sent again', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    srv.flowFor = 'saveDieselIssue';
    try {
      await s.api.call('saveDieselIssue', [{'no': 'Sany 210 (No.1)', 'qty': 300}], true);
      fail('should be sent');
    } on ApiError catch (e) {
      expect(e.code, 'sent');
      expect(e.message, startsWith('Sent for verification to Checker One – VF-00007'));
      expect(Api.isGood(e.message), true, reason: 'shown in green, not as an error');
    }
    expect(srv.calls.where((c) => c == 'mech:saveDieselIssue+rid').length, 1);
    expect(srv.saved, isEmpty);
  });

  test('(3.1.7) no network: the save keeps its number; kept on the phone, it is sent by itself later with the SAME number – once', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    srv.down = true;
    final d = {'no': 'Sany 210 (No.1)', 'qty': 40, 'hrReading': 4710, 'date': '2026-10-14'};
    ApiError? err;
    try {
      await s.api.call('saveDieselIssue', [d], true);
    } on ApiError catch (e) {
      err = e;
    }
    expect(err?.noConnection, true);
    expect(err!.rid, isNotEmpty);
    await s.keepEntry('saveDieselIssue', [d], err.rid, 'Diesel Issue · 14-10-2026 · Sany 210 (No.1) · 40 L');
    expect(s.kept.length, 1);
    expect(jsonDecode((await keep.read('kept_sujit@rcl.test'))!), hasLength(1), reason: 'kept on the phone (survives a restart)');
    await s.sendKept();
    expect(s.kept.length, 1, reason: 'still no network: it waits');
    srv.down = false;
    await s.sendKept();
    expect(s.kept, isEmpty);
    expect(srv.saved.length, 1);
    expect(srv.rids.where((r) => r == 'saveDieselIssue:${err!.rid}').length, 1, reason: 'sent with the number of the first try');
    // a kept entry the server refuses: kept with its words until the person deletes it
    srv.flowFor = '';
    await s.keepEntry('saveDieselIssue', [{'no': 'X', 'qty': 1, 'hrReading': 1}], 'rid-refused', 'Diesel Issue · X');
    await s.sendKept();
    expect(s.kept.single['state'], 'refused');
    expect('${s.kept.single['msg']}', contains('Save anyway'));
    expect(s.keptBad, 1);
    await s.dropKept('rid-refused');
    expect(s.kept, isEmpty);
    expect(await keep.read('kept_sujit@rcl.test'), isNull);
  });

  test('(3.1.7) live: a version that changes makes the screens load again; "flow" brings the Approvals count', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    srv.crPending = 2;
    srv.crForMe = 1;
    await s.liveTick();
    expect([s.crWaiting, s.crForMe], [2, 1], reason: 'the first tick: the count');
    final t0 = s.dataTick.value;
    await s.liveTick();
    expect(s.dataTick.value, t0, reason: 'nothing changed');
    srv.versions = {...srv.versions, 'log': '2', 'flow': '2'};
    srv.crForMe = 0;
    await s.liveTick();
    expect(s.dataTick.value, t0 + 1);
    expect(s.lastChanged, {'log', 'flow'});
    expect(s.crForMe, 0);
    srv.calls.clear();
    srv.versions = {...srv.versions, 'stock': '2'};
    await s.liveTick();
    expect(srv.calls, contains('mech:getStock'), reason: 'only the stock is asked again');
    expect(srv.calls, isNot(contains('mech:getInit')));
  });

  // ---------------- 3.1.8 ----------------
  test('(3.1.8) the number plate: the text read on the phone → the machinery of the Asset Master (exact, two lines, a letter mixed up)', () {
    final ms = [
      Machine({'id': 'MH-25-AJ-2169', 'type': 'Tipper'}),
      Machine({'id': 'MH-12-SY-6216', 'type': 'Bolero'}),
      Machine({'id': 'Sany 210 (No.1)', 'no': '', 'type': 'Excavator'}),
      Machine({'id': 'JCB-3', 'no': 'MH 14 GH 1010', 'type': 'JCB'}),
    ];
    expect(plateMatches('IND\nMH 25 AJ 2169', ms).map((m) => m.id), ['MH-25-AJ-2169']);
    expect(plateMatches('MH 25\nAJ 2169', ms).map((m) => m.id), ['MH-25-AJ-2169'], reason: 'a plate on two lines');
    expect(plateMatches('MH12 SY 62I6', ms).map((m) => m.id), ['MH-12-SY-6216'], reason: 'I read for 1 – the same');
    expect(plateMatches('MH 25 AJ 2168', ms).map((m) => m.id), ['MH-25-AJ-2169'], reason: 'one letter different: still offered');
    expect(plateMatches('MH14GH1010', ms).map((m) => m.id), ['JCB-3'], reason: 'by its number (the machinery is named otherwise)');
    expect(plateMatches('KA 01 AB 9999', ms), isEmpty, reason: 'not in the Asset Master');
    expect(plateMatches('', ms), isEmpty);
  });

  test('(3.1.8) diesel: KM / Hrs / KM + Hrs by itself from the Asset Master', () {
    expect(Machine({'unit': 'KM', 'worksOn': ['KM']}).dieselWay, 'KM');
    expect(Machine({'modes': ['Hrs', 'Time'], 'modesX': ['Time']}).dieselWay, 'Hrs');
    expect(Machine({'unit': 'KM + Hrs', 'worksOn': ['KM', 'Hrs']}).dieselWay, 'KM + Hrs');
    expect(Machine({'lbFormat': 'H'}).dieselWay, '', reason: 'trips only: no meter, no reading');
  });

  test('(3.1.8, update-116) "Send to verification": his rules from Mechanical, with "only when"', () async {
    srv.flowMine = {'Diesel Issue': {'daysBack': '', 'qtyAbove': 50, 'to': ['Shubham'], 'levels': 1}, 'Log Book': {'daysBack': 3, 'qtyAbove': '', 'to': ['Shubham'], 'levels': 1}};
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    expect(s.flowWill('Diesel Issue', qty: 40), false);
    expect(s.flowWill('Diesel Issue', qty: 60), true);
    expect(s.flowWill('Log Book', dates: ['2026-10-13']), false, reason: 'today is 14-10 in the fake server: 1 day back');
    expect(s.flowWill('Log Book', dates: ['2026-10-01']), true);
    expect(s.flowWill('Diesel Inward'), false, reason: 'no rule: Save');
    expect(s.flowTo('Diesel Issue'), 'Shubham');
  });

  test('(3.1.8) notifications: new for him once; sent back to him – again every 30 minutes until he answers', () {
    final seen = <String, int>{};
    Map d(List<Map> r) => {'requests': r};
    final w = {'id': 'VF-00001', 'canDecide': true, 'task': 'Diesel Issue', 'by': 'Mahesh', 'summary': ['300 L MH-25']};
    var out = alertsFrom(d([w]), seen, 0);
    expect(out.single.$2, 'Waiting for your approval – Diesel Issue (Mahesh)');
    expect(alertsFrom(d([w]), seen, 60000), isEmpty, reason: 'told once');
    final b = {'id': 'VF-00002', 'canAnswer': true, 'summary': ['Vendor X'], 'reverted': {'by': 'Shubham', 'note': 'Which PAN?'}};
    out = alertsFrom(d([w, b]), seen, 100000);
    expect(out.single.$3, 'Shubham: Which PAN?');
    expect(alertsFrom(d([w, b]), seen, 100000 + 29 * 60000), isEmpty);
    expect(alertsFrom(d([w, b]), seen, 100000 + 31 * 60000).single.$2, startsWith('Sent back to you'));
    alertsFrom(d([]), seen, 200000000);
    expect(seen, isEmpty, reason: 'decided: forgotten');
  });

  test('(3.1.9) Log Book: the way picked by itself – its last entry\'s way, else the Asset Master unit, else its first', () {
    final m = Machine({'id': 'TM-1', 'unit': 'KM + Hrs', 'worksOn': ['KM', 'Hrs', 'Trip']});
    expect(m.wayAuto, '', reason: 'several ways: before 3.1.9 nothing was picked');
    expect(m.logWay(), 'KM + Hrs', reason: 'the Asset Master unit');
    expect(m.logWay('Trip'), 'Trip', reason: 'the way of its last entry');
    expect(m.logWay('Holiday'), 'KM + Hrs', reason: 'a day status of the last entry is not carried over');
    expect(Machine({'modes': ['Hrs', 'Time'], 'modesX': ['Time']}).logWay('Time'), 'Hrs', reason: 'a Time day is only for a day the meter gave no reading');
    expect(Machine({'lbFormat': 'H'}).logWay(), 'Trip');
  });

  test('(3.1.10) the Marathi word under each diesel place on Home: the first site as before; 18B\'s pump and dispensers their own', () {
    expect([placeMr('Dispenser'), placeMr('VTR Store')], ['डिस्पेन्सर', 'स्टोअर'], reason: 'the first site: as before');
    expect([placeMr('Camp Pump'), placeMr('MH12ZE1739'), placeMr('MH12WJ1381'), placeMr('MH 12 ZE 1739')], ['पंप', 'डिस्पेन्सर', 'डिस्पेन्सर', 'डिस्पेन्सर']);
    expect(placeMr('Tank 2'), 'डिझेल जागा', reason: 'any other place');
  });

  test('(3.1.11) his entries in verification: waiting and sent back always, decided ones of the last days; counts; the words of a reminder', () {
    final now = DateTime.utc(2026, 10, 16, 12);
    final d = {'requests': [
      {'kind': 'Flow', 'mine': true, 'id': 'VF-1', 'm': 'Diesel Issue', 'status': 'Pending', 'at': '2026-10-01T10:00:00Z'},
      {'kind': 'Flow', 'mine': true, 'id': 'VF-2', 'm': 'Diesel Issue', 'status': 'Approved', 'at': '2026-10-16T09:00:00Z', 'decidedAt': '2026-10-16T10:00:00Z'},
      {'kind': 'Flow', 'mine': true, 'id': 'VF-3', 'm': 'Diesel Issue', 'status': 'Rejected', 'at': '2026-10-01T09:00:00Z', 'decidedAt': '2026-10-02T10:00:00Z'},
      {'kind': 'Flow', 'mine': true, 'id': 'VF-4', 'm': 'Diesel Inward', 'status': 'Reverted', 'at': '2026-09-01T09:00:00Z'},
      {'kind': 'Flow', 'mine': false, 'id': 'VF-5', 'status': 'Pending'},
      {'kind': 'Request', 'mine': true, 'id': 'CR-1', 'status': 'Pending'},
    ]};
    final l = Session.mineOf(d, now: now);
    expect(l.map((r) => r['id']), ['VF-1', 'VF-2', 'VF-4']);
    expect(Session.mineOf(d, days: 1, now: now).map((r) => r['id']), ['VF-1', 'VF-2', 'VF-4']);
    expect(verifyCounts(l), (1, 1, 1, 0));
    expect(remindWords({'reminded': ['VF-1'], 'later': [{'id': 'VF-7', 'at': '12:41', 'next': '12:46'}]}), 'Reminder sent: VF-1. VF-7 was reminded at 12:41 – again after 12:46');
  });

  test('(3.1.11) the approver: a reminder of the sender is a notification – once for each press', () {
    final seen = <String, int>{};
    Map d(Map r) => {'requests': [r]};
    final w = <String, dynamic>{'id': 'VF-00009', 'canDecide': true, 'task': 'Diesel Issue', 'by': 'Mahesh', 'summary': ['60 L MH-25']};
    expect(alertsFrom(d(w), seen, 1000).single.$2, startsWith('Waiting for your approval'));
    final t1 = DateTime.utc(2026, 10, 16, 12, 0).millisecondsSinceEpoch;
    w['remindedAt'] = DateTime.fromMillisecondsSinceEpoch(t1, isUtc: true).toIso8601String();
    var out = alertsFrom(d(w), seen, t1 + 60000);
    expect(out.single.$2, 'Reminder from Mahesh – Diesel Issue waits for your approval');
    expect(out.single.$3, 'VF-00009: 60 L MH-25');
    expect(alertsFrom(d(w), seen, t1 + 120000), isEmpty, reason: 'the same reminder: told once');
    w['remindedAt'] = DateTime.fromMillisecondsSinceEpoch(t1 + 6 * 60000, isUtc: true).toIso8601String();
    expect(alertsFrom(d(w), seen, t1 + 7 * 60000).single.$2, startsWith('Reminder from Mahesh'), reason: 'pressed again');
    final fresh = <String, int>{};
    expect(alertsFrom(d(w), fresh, t1 + 7 * 60000).single.$2, startsWith('Waiting for your approval'), reason: 'first seen with a reminder: one notification, not two');
  });

  test('(3.1.13, update-120) what a save sends for the bill copies – as the web', () {
    const a = 'inward/2026-10/a.jpg', b = 'inward/2026-10/b.jpg';
    expect(billsForSave(isEdit: false, mode: 'new', changed: false, paths: []), null, reason: 'a new inward without copies: nothing (as before)');
    expect(billsForSave(isEdit: false, mode: 'new', changed: true, paths: [a, b]), [{'p': a}, {'p': b}]);
    expect(billsForSave(isEdit: true, mode: 'edit', changed: false, paths: [a]), null, reason: 'not changed: the inward keeps its own');
    expect(billsForSave(isEdit: true, mode: 'edit', changed: true, paths: []), <Map<String, String>>[], reason: 'all taken out');
    expect(billsForSave(isEdit: true, mode: 'fail', changed: true, paths: [b]), null, reason: 'they could not be read: nothing changes them');
    expect(billsForSave(isEdit: true, mode: 'loading', changed: true, paths: [b]), null);
    expect(kBillMax, 10, reason: 'as the server (BILL_MAX_)');
  });

  test('(3.62.1, Mechanical update-187) the first day a person may date an entry: a user today (the Log Book also yesterday), the site\'s rule only stricter; the Admin and the Super Admin any day', () {
    final s = make()..today = '2026-10-29';
    expect(s.entryFirst(), DateTime(2026, 10, 29), reason: 'a user: today');
    expect(s.entryFirst(log: true), DateTime(2026, 10, 28), reason: 'the Log Book: also yesterday');
    expect([s.entryDayOk('2026-10-29'), s.entryDayOk('2026-10-28'), s.entryDayOk('2026-10-28', log: true), s.entryDayOk('2026-10-27', log: true)], [true, false, true, false]);
    s.siteRules = {'backDays': 0};
    expect(s.entryFirst(log: true), DateTime(2026, 10, 29), reason: 'the site\'s "0 days": the Log Book too only today');
    s.siteRules = {'backDays': 5};
    expect(s.entryFirst(log: true), DateTime(2026, 10, 28), reason: 'never more than fixed');
    s.siteRules = {'backDays': ''};
    expect(s.entryFirst(), DateTime(2026, 10, 29));
    expect((make()..today = '2026-11-01').entryFirst(log: true), DateTime(2026, 10, 31), reason: 'across a month');
    s.admin = true;
    expect([s.entryFirst(), s.entryFirst(log: true), s.entryDayOk('2026-01-01')], [null, null, true], reason: 'the Admin: any day');
    s.admin = false;
    s.superAdmin = true;
    expect(s.entryFirst(), null, reason: 'the Super Admin: any day');
  });

  test('(3.62.1) the app left open past midnight: the live sync moves "today" on – a user\'s entry dates with it', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    final d0 = s.today;
    await s.liveTick();
    expect(s.today, d0, reason: 'no day given: as it was');
    srv.syncToday = '2026-10-15';
    var told = 0;
    s.addListener(() => told++);
    await s.liveTick();
    expect(s.today, '2026-10-15');
    expect(told, greaterThan(0), reason: 'the screens are told');
    expect(s.admin || s.superAdmin ? null : s.entryFirst(), s.admin || s.superAdmin ? null : DateTime(2026, 10, 15));
    srv.syncToday = 'not a day';
    await s.liveTick();
    expect(s.today, '2026-10-15', reason: 'only a real day');
  });
}
