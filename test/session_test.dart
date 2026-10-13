import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/web/files.dart';
import 'package:rcl_mobile/web/web_shell.dart';

import 'fake_server.dart';

void main() {
  late FakeServer srv;
  late MemoryKeep keep;
  Session make() => Session(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client));
  setUp(() {
    srv = FakeServer();
    keep = MemoryKeep();
  });

  test('sign in ONCE on the Portal → his sites (with their modules) → the ERP of the chosen site opens with a fresh ticket', () async {
    final s = make();
    await s.start();
    expect(s.stage, Stage.signedOut);
    await s.signIn('sujit@rcl.test', 'wrong-one');
    expect(s.stage, Stage.signedOut);
    expect(s.error, 'Email or password is wrong.');
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s.stage, Stage.pickSite);
    expect(s.sites.map((x) => x.code).toList(), ['S1', 'T2'], reason: 'a module address that is not https is never opened');
    expect(s.sites.first.modules.map((m) => m.name).toList(), ['Mechanical', 'Store']);
    await s.chooseSite('S1');
    expect(s.stage, Stage.ready);
    expect(await s.startUrl(), 'https://erp.test/#sso=tk1', reason: 'Mechanical – the ERP\'s screen; the Store is inside it');
    expect(srv.calls, ['portal:login', 'portal:login', 'portal:me', 'portal:go:mechanical:S1']);
    expect(keep.data['portal_cookie'], 'rcl_portal=abc123');
    expect(s.api.cookieValue, 'abc123', reason: 'the same sign-in is given to the web view');
    expect(keep.data['site'], 'S1');
  });

  test('the app opens again later: the kept sign-in and the last site are used – nothing to type', () async {
    final s1 = make();
    await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s1.chooseSite('T2');
    final s2 = make();
    await s2.start();
    expect(s2.stage, Stage.ready);
    expect(s2.site!.code, 'T2');
    expect(await s2.startUrl(), endsWith('#sso=tk1'));
  });

  test('a site changed inside the web ("Change site") opens next time', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    var notified = 0;
    s.addListener(() => notified++);
    await s.rememberSite('T2');
    await s.rememberSite('NOPE');
    expect(s.site!.code, 'T2');
    expect(keep.data['site'], 'T2');
    expect(notified, 0, reason: 'the open ERP is not reloaded');
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

  test('the sign-in ends while the ERP is being opened: back to the sign-in screen with a message', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    srv.portalSignedIn = false;
    await expectLater(s.startUrl(), throwsA(isA<ApiError>()));
    expect(s.stage, Stage.signedOut);
    expect(s.error, contains('sign in again'));
  });

  test('the Super Admin and a password still to be set are sent to the Portal (web)', () async {
    srv.superAdmin = true;
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s.stage, Stage.signedOut);
    expect(s.error, contains('Super Admin'));
    srv
      ..superAdmin = false
      ..mustChange = true;
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s.stage, Stage.signedOut);
    expect(s.error, contains('Set your own password'));
  });

  test('sign out: the Portal is told, nothing kept on the phone', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    await s.signOut();
    expect(s.stage, Stage.signedOut);
    expect(srv.calls.last, 'portal:logout');
    expect(keep.data, isEmpty);
  });

  test('where a link goes: the ERP and its modules stay in the app; other sites outside; the web\'s Logout = the app\'s sign-out', () async {
    final s = make();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    Go go(String u, [bool main = true]) => whereTo(Uri.parse(u), main, s);
    expect(go('https://erp.test/#sso=tk9'), Go.stay);
    expect(go('https://erp.test/portal/api/go?module=mechanical&site=T2'), Go.stay, reason: 'Change site');
    expect(go('https://erp.test/portal/?menu=1'), Go.stay, reason: 'All my modules');
    expect(go('https://erp.test/portal/?signout=1'), Go.signOut);
    expect(go('https://oneclicksolution-erp.vercel.app/store/?embed=1'), Go.stay);
    expect(go('https://www.google.com/maps?q=17.6,74.0'), Go.outside);
    expect(go('https://abc.supabase.co/storage/v1/object/photo.jpg'), Go.outside);
    expect(go('https://www.google.com/recaptcha', false), Go.stay, reason: 'a frame inside the page is the page\'s own business');
    expect(go('tel:+919800000000'), Go.outside);
    expect(go('whatsapp://send?text=x'), Go.outside);
    expect(go('blob:https://erp.test/1234'), Go.stay);
    expect(go('about:blank'), Go.stay);
  });

  test('a file from the web: a safe name and its type', () {
    expect(safeFileName('Diesel Issue 2026/10.xlsx'), 'Diesel Issue 2026_10.xlsx');
    expect(safeFileName('../../etc/passwd'), '_.._etc_passwd');
    expect(safeFileName('   '), 'RCL_file');
    final long = safeFileName('${'A' * 200}.xlsx');
    expect(long.length, 120);
    expect(long, endsWith('.xlsx'));
    expect(mimeOf('a.xlsx', ''), contains('spreadsheetml'));
    expect(mimeOf('a.csv', 'text/csv;charset=utf-8'), 'text/csv');
    expect(mimeOf('a.bin', ''), 'application/octet-stream');
  });

  test('the script given to the web view is in the app and answers what the app asks', () {
    final js = File('assets/web_bridge.js').readAsStringSync();
    for (final h in ["'saveFile'", "'print'", "'openUrl'", "'saveFailed'", '__rclAppBack', '__rclAppReady', 'rclBack']) {
      expect(js, contains(h), reason: h);
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/web_bridge.js'));
  });
}
