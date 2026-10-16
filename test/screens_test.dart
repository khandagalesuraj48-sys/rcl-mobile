/* The app's screens on a phone (360 × 780) with the pretend servers: what a person sees and does.
 * The tests tagged "golden" also make pictures of the screens (test/goldens/) – for looking at, in the build's files. */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/lang.dart';
import 'package:rcl_mobile/core/masters.dart' show gstCheckLetter;
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/core/sheet_read.dart';
import 'package:rcl_mobile/main.dart';
import 'package:rcl_mobile/screens/logbook.dart' show LogForm;
import 'package:rcl_mobile/ui/outputs.dart' show fileSink;
import 'package:rcl_mobile/ui/pick_file.dart';
import 'package:rcl_mobile/web/web_host.dart';

import 'fake_server.dart';

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

Session make(FakeServer srv) => Session(Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: srv.client))..clock = () => DateTime(2026, 10, 14, 10, 30); // (a Day-shift time: the screens are the same every run)

Future<Session> ready(WidgetTester t, FakeServer srv) async {
  final s = make(srv);
  await t.runAsync(() async {
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
  });
  return s;
}

/// Pictures (the 3D icons, the logo) are read before the picture of the screen is taken.
Future<void> pics(WidgetTester t) async {
  await t.runAsync(() async {
    for (final e in t.widgetList<Image>(find.byType(Image))) {
      final img = e.image;
      final c = Completer<void>();
      final st = img.resolve(ImageConfiguration.empty);
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
  await t.pump();
}

/// (3.2.0) Taps a widget by its key, brought into view first (a list may hold it below the screen).
/// (3.4.0) A typed box is let go first (its "show the caret" scroll would still be running and the tap would be ignored).
Future<void> tapK(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 150));
  await t.ensureVisible(f);
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.tap(f);
}

void main() {
  setUpAll(loadFonts);
  setUp(() => webHost.enabled = false); // a web view cannot run in a test
  tearDown(() => Lang.i.set('')); // (15-10-2026) every test starts in the app's usual language
  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  testWidgets('Sign-in: the Rachana logo; a wrong password says so; the right one goes on', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = make(srv);
    await t.runAsync(s.start);
    await t.pumpWidget(RclApp(session: s));
    await settle(t);
    await pics(t);
    expect(find.text('Namaskar'), findsOneWidget);
    expect(find.image(const AssetImage('assets/brand/rachana_logo.png')), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/1_sign_in.png'));
    await t.enterText(find.byType(TextField).at(0), 'sujit@rcl.test');
    await t.enterText(find.byType(TextField).at(1), 'wrong');
    await t.tap(find.text('Sign in'));
    await net(t);
    expect(find.text('Email or password is wrong.'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(1), 'Nashik#Road848!');
    await t.tap(find.text('Sign in'));
    await net(t);
    expect(s.stage, Stage.pickSite);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/2_sites.png'));
  }, tags: ['golden']);

  testWidgets('Home: stock, each place, machines working, today\'s Log Book, modules he may open, today\'s activity', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await pics(t);
    expect(find.text('Namaskar, Sujit'), findsOneWidget);
    expect(find.text('1,133 L'), findsOneWidget);
    expect(find.text('813 L'), findsOneWidget);
    expect(find.text('320 L'), findsOneWidget);
    expect(find.text('5 / 2'), findsOneWidget, reason: '5 machinery worked today (Idle not counted) / 2 active');
    expect(find.text('6'), findsOneWidget, reason: 'Log Book entries today');
    expect(find.text('Machinery'), findsOneWidget);
    expect(find.text('Billing'), findsNothing, reason: 'no access to Machinery Billing: no tile');
    expect(find.text('Administration'), findsNothing, reason: 'not an Admin');
    expect(find.text('Store'), findsOneWidget, reason: 'he has the Store on this site');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/3_home.png'));
    await t.drag(find.byType(ListView).first, const Offset(0, -900));
    await settle(t, 600);
    await pics(t);
    expect(find.text("Today's Activity"), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/4_home_activity.png'));
  }, tags: ['golden']);

  testWidgets('(3.1.11) Home: his entries in verification – Waiting / Approved; the list; "Remind" tells the approver', (t) async {
    phone(t);
    final srv = FakeServer();
    final now = DateTime.now().toUtc().toIso8601String();
    srv.flowReqs.addAll([
      {'kind': 'Flow', 'mine': true, 'id': 'VF-00009', 'm': 'Diesel Issue', 'task': 'Diesel Issue', 'status': 'Pending', 'at': now, 'waitSince': now, 'waitingFor': ['Shubham'], 'level': 1, 'levels': 1, 'canRemind': true, 'reminds': 0, 'summary': ['Diesel issue MH-25-AJ-2169 · 60 L']},
      {'kind': 'Flow', 'mine': true, 'id': 'VF-00008', 'm': 'Diesel Issue', 'task': 'Diesel Issue', 'status': 'Approved', 'at': now, 'decidedAt': now, 'decidedBy': 'Shubham', 'summary': ['Diesel issue MH-12-SY-6216 · 20 L']},
    ]);
    final s = await ready(t, srv);
    await t.runAsync(() => s.loadApprovals());
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.byKey(const Key('verify-strip')), findsOneWidget);
    expect(find.text('Waiting 1'), findsOneWidget);
    expect(find.text('Approved 1'), findsOneWidget);
    await t.tap(find.byKey(const Key('verify-strip')));
    await settle(t, 800);
    expect(find.byKey(const Key('verify-VF-00009')), findsOneWidget);
    expect(find.text('Approved – saved'), findsOneWidget);
    expect(find.textContaining('at Shubham'), findsOneWidget);
    await t.tap(find.byKey(const Key('verify-remind-VF-00009')));
    await net(t);
    expect(srv.reminded, [['VF-00009']]);
    expect(find.text('Reminder sent: VF-00009.'), findsOneWidget);
    expect(find.textContaining('reminded 1×'), findsOneWidget);
  });

  testWidgets('(3.2.0) Approvals – the app\'s own screen: the counts, the requests; Approve, Reject (a reason), several at once', (t) async {
    phone(t);
    final srv = FakeServer()..crForMe = 3;
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> req(String id, String what) => {'kind': 'Flow', 'mine': false, 'id': id, 'm': 'Diesel Issue', 'task': 'Diesel Issue', 'status': 'Pending', 'at': now, 'waitSince': now, 'by': 'Mahesh Jadhav', 'waitingFor': ['Sujit Mule'], 'level': 1, 'levels': 1, 'canDecide': true, 'qty': 100, 'summary': [what],
          'history': [{'step': 'Sent', 'by': 'Mahesh Jadhav', 'at': now}]};
    srv.flowReqs.addAll([
      req('VF-00003', 'Delete diesel issue DI-000003: DLC PAVER-RCL · 16-10-2026 · Day (saved now: Litres 100)'),
      req('VF-00004', 'Add: MH-25-AJ-2169 · 16-10-2026 · Day: Litres 60'),
      req('VF-00005', 'Add: Sany 210 (No.1) · 16-10-2026 · Day: Litres 80'),
    ]);
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Me'));
    await net(t);
    await t.ensureVisible(find.text('Approvals').first);
    await settle(t, 300);
    await t.tap(find.text('Approvals').first);
    await net(t);
    expect(find.byKey(const Key('cr-forme')), findsOneWidget);
    expect(find.byKey(const Key('cr-VF-00003')), findsOneWidget);
    expect(find.textContaining('Delete diesel issue DI-000003'), findsOneWidget);
    expect(find.text('level 1 of 1: Sujit Mule'), findsWidgets);
    expect(srv.calls.where((c) => c.startsWith('mech:getChangeRequests')).isNotEmpty, true);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/13_approvals.png'));
    // one: Approve → asked → saved
    await tapK(t, 'ok:VF-00003');
    await settle(t, 600);
    expect(find.text('Approve this entry?'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    expect(srv.decided.last, {'id': 'VF-00003', 'approve': true, 'note': ''});
    expect(find.text('VF-00003 approved – saved.'), findsOneWidget);
    // Reject needs a reason
    await tapK(t, 'no:VF-00004');
    await settle(t, 600);
    await t.tap(find.byKey(const Key('note-ok')));
    await settle(t, 300);
    expect(find.text('Write why the change is rejected.'), findsOneWidget, reason: 'nothing sent without a reason');
    expect(srv.decided.length, 1);
    await t.enterText(find.byKey(const Key('note-box')), 'Wrong litres');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(srv.decided.last, {'id': 'VF-00004', 'approve': false, 'note': 'Wrong litres'});
    // several at once
    await tapK(t, 'tick-VF-00005');
    await settle(t, 300);
    expect(find.byKey(const Key('bulk-ok')), findsOneWidget);
    await tapK(t, 'bulk-ok');
    await settle(t, 600);
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(srv.decided.last['ids'], ['VF-00005']);
    expect(srv.decided.last['approve'], true);
    expect(find.text('1 done.'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.2.0) Approvals: the sender answers an entry sent back, or takes it back; the Super Admin\'s rules', (t) async {
    phone(t);
    final srv = FakeServer()..superAdmin = true;
    final now = DateTime.now().toUtc().toIso8601String();
    srv.flowReqs.add({'kind': 'Flow', 'mine': true, 'id': 'VF-00007', 'm': 'Diesel Issue', 'task': 'Diesel Issue', 'status': 'Reverted', 'at': now, 'by': 'Sujit Mule', 'canAnswer': true, 'summary': ['Add: MH-25-AJ-2169 · 60 L'],
      'reverted': {'by': 'Shubham', 'note': 'Which tank?', 'at': now}});
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Me'));
    await net(t);
    await t.ensureVisible(find.text('Approvals').first);
    await settle(t, 300);
    await t.tap(find.text('Approvals').first);
    await net(t);
    expect(find.text('Which tank?'), findsOneWidget);
    await tapK(t, 'ans:VF-00007');
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('note-box')), 'Dispenser');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(srv.decided.last, {'answer': true, 'id': 'VF-00007', 'note': 'Dispenser', 'withdraw': false});
    // the rules
    await tapK(t, 'flow-rules');
    await net(t);
    expect(find.byKey(const Key('fr-Diesel Issue')), findsOneWidget);
    expect(find.text('Mahesh Jadhav'), findsWidgets);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/14_flow_rules.png'));
    await tapK(t, 'fr-save');
    await net(t);
    final saved = srv.rulesSaved.single;
    expect((saved['tasks'] as Map)['Diesel Issue'], {'on': true, 'levels': [['mahesh@rcl.test']], 'daysBack': '', 'qtyAbove': '200'});
    expect((saved['tasks'] as Map)['Log Book'], {'on': false, 'levels': [[]], 'daysBack': '', 'qtyAbove': ''});
    expect(saved['remindHours'], '4');
  }, tags: ['golden']);

  testWidgets('(3.2.0) Reports – the app\'s own screens: the list, a report\'s filters, Generate, its tables and figures', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Reports').last);
    await net(t);
    await t.scrollUntilVisible(find.text('Stock Register'), 300, scrollable: find.ancestor(of: find.text('Daily Inward & Issue'), matching: find.byType(Scrollable)).first);
    await settle(t, 300);
    await t.tap(find.text('Stock Register'));
    await net(t);
    expect(find.byKey(const Key('rep-go')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/15_report_filters.png'));
    await tapK(t, 'rep-go');
    await net(t);
    expect(srv.reportAsked.single['fn'], 'rptStock');
    expect(srv.reportAsked.single['from'], '2026-10-01');
    expect(srv.reportAsked.single['location'], 'Dispenser');
    expect(find.byKey(const Key('rtable-Stock register')), findsOneWidget);
    expect(find.text('Opening balance'), findsOneWidget);
    expect(find.byKey(const Key('rep-xlsx')), findsOneWidget);
    expect(find.byKey(const Key('rep-pdf')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/16_report_stock.png'));
  }, tags: ['golden']);

  testWidgets('(3.2.0) Monthly Diesel & Average: the day-by-day table with its status, sideways on the phone', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Reports').last);
    await net(t);
    await t.tap(find.text('Monthly Diesel & Average'));
    await net(t);
    await tapK(t, 'rep-go');
    await net(t);
    expect(srv.reportAsked.single['fn'], 'getMonthlyAvgReport');
    expect(srv.reportAsked.single['withReadings'], true);
    expect(find.byKey(const Key('rtable-Diesel & Average')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/17_report_monthly_avg.png'));
  }, tags: ['golden']);

  testWidgets('Entries: the day\'s diesel issues as cards; Transfer (no access) is not a tab', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await pics(t);
    // (3.1.8) a list one under the other: only the pages he may open (Transfer: no access)
    expect(find.byKey(const Key('entries-Diesel Issue')), findsOneWidget);
    expect(find.byKey(const Key('entries-Diesel Inward')), findsOneWidget);
    expect(find.byKey(const Key('entries-Transfer')), findsNothing);
    expect(find.byKey(const Key('entries-Log Book')), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/5a_entries_list.png'));
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await pics(t);
    expect(find.text('Sany 210 (No.1)'), findsOneWidget);
    expect(find.text('4 entries · 240 L'), findsOneWidget);
    expect(find.text('Transfer'), findsNothing);
    expect(find.text('New Entry'), findsOneWidget, reason: 'Edit access on Diesel Issue');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/5_entries.png'));
    await t.enterText(find.byType(TextField).first, 'maruti');
    await settle(t, 400);
    expect(find.text('MH-12-SY-6216'), findsOneWidget);
    expect(find.text('Sany 210 (No.1)'), findsNothing);
  }, tags: ['golden']);

  testWidgets('New Diesel Issue: machinery, its way (Hrs by itself), litres, the stock after, the 4 photo tiles; save', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await t.tap(find.text('New Entry'));
    await net(t);
    expect(find.byKey(const Key('scan-plate')), findsOneWidget, reason: '(3.1.8) the photo of the number plate');
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    expect(find.text('OLD-9'), findsNothing, reason: 'an Inactive machinery is not offered');
    await t.tap(find.text('Sany 210 (No.1)'));
    await settle(t, 800);
    expect(find.text('Hour meter'), findsOneWidget, reason: 'measured by Hrs – picked by itself');
    expect(find.text('Hrs · Asset Master'), findsOneWidget, reason: '(3.1.8) from the Asset Master – nothing to pick');
    expect(find.text('Meter not working'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(1), '60');
    await settle(t, 300);
    expect(find.text('Stock after this issue: 753 L'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/6_issue_form.png'));
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -700));
    await settle(t, 500);
    await pics(t);
    expect(find.text('Dispenser litres'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/7_issue_photos.png'));
    await t.tap(find.text('Save Diesel Issue'));
    await net(t);
    expect(srv.saved.single['no'], 'Sany 210 (No.1)');
    expect(srv.saved.single['qty'], 60);
    expect(srv.saved.single['mode'], 'Hrs');
    expect(find.textContaining('DI-000526'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/8_issue_saved.png'));
  }, tags: ['golden']);

  testWidgets('(3.1.13, update-120) Diesel Inward: the bill copies – "Take photo" / "Choose photos"; an edit shows its copies, one taken out is saved', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Diesel Inward'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Inward')));
    await net(t);
    // the details: how many copies
    await t.tap(find.text('IOC Bunk').first);
    await settle(t, 800);
    expect(find.text('Bill copy'), findsOneWidget);
    expect(find.text('2 photos'), findsOneWidget);
    await t.tap(find.text('Change'));
    await net(t);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -900));
    await settle(t, 600);
    expect(find.byKey(const Key('bills')), findsOneWidget);
    expect(find.byKey(const Key('bill-0')), findsOneWidget, reason: 'its 2 copies, read from the server');
    expect(find.byKey(const Key('bill-1')), findsOneWidget);
    expect(find.byKey(const Key('bill-camera')), findsOneWidget);
    expect(find.byKey(const Key('bill-gallery')), findsOneWidget);
    expect(srv.calls.where((c) => c == 'mech:getInwardPhotos').length, 1);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/12_inward_bills.png'));
    await t.tap(find.byKey(const Key('bill-x-1')));
    await settle(t, 400);
    expect(find.byKey(const Key('bill-1')), findsNothing, reason: 'taken out');
    await t.tap(find.text('Save the change'));
    await net(t);
    expect(srv.saved.last['update'], 'IN-000050');
    expect(srv.saved.last['photos'], [{'p': 'inward/2026-10/00000000-0000-0000-0000-000000000001.jpg'}], reason: 'the list as it is now');
  }, tags: ['golden']);

  testWidgets('(3.1.13) a new Diesel Inward: the bill copy box; saved without copies – nothing about them sent (as before)', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Diesel Inward'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Inward')));
    await net(t);
    await t.tap(find.text('New Entry'));
    await net(t);
    await t.enterText(find.byType(TextField).at(0), 'IOC Bunk');
    await t.enterText(find.byType(TextField).at(1), '500');
    await t.enterText(find.byType(TextField).at(2), '90');
    await settle(t, 300);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -900));
    await settle(t, 600);
    expect(find.byKey(const Key('bill-camera')), findsOneWidget);
    expect(find.byKey(const Key('bill-gallery')), findsOneWidget);
    expect(find.byKey(const Key('bill-0')), findsNothing);
    await t.tap(find.text('Save Diesel Inward'));
    await net(t);
    expect(srv.saved.single['pump'], 'IOC Bunk');
    expect(srv.saved.single.containsKey('photos'), false);
  });

  testWidgets('Me: name, role, site, version, sign out', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Me'));
    await net(t);
    await pics(t);
    expect(find.text('Sujit Mule'), findsOneWidget);
    expect(find.text('Check Update'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9_me.png'));
    await t.tap(find.text('Reports'));
    await net(t);
    expect(find.text('Monthly Diesel Issue'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(15-10-2026) a new user: his own password set right here – the three boxes, the two new ones must match, then the app opens', (t) async {
    phone(t);
    final srv = FakeServer()..mustChange = true;
    final s = make(srv);
    await t.runAsync(s.start);
    await t.pumpWidget(RclApp(session: s));
    await settle(t);
    await t.enterText(find.byType(TextField).at(0), 'sujit@rcl.test');
    await t.enterText(find.byType(TextField).at(1), 'Nashik#Road848!');
    await t.tap(find.text('Sign in'));
    await net(t);
    expect(s.stage, Stage.setPassword);
    expect(find.text('Set your own password'), findsOneWidget);
    expect(find.text('तुमचा स्वतःचा password बनवा'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/1b_own_password.png'));
    await t.enterText(find.byType(TextField).at(0), 'Nashik#Road848!');
    await t.enterText(find.byType(TextField).at(1), 'Mule#2026x');
    await t.enterText(find.byType(TextField).at(2), 'Mule#2026y');
    await t.ensureVisible(find.text('Save and open'));
    await settle(t, 400);
    await t.tap(find.text('Save and open'));
    await settle(t, 600);
    expect(find.textContaining('The two new passwords are not the same.'), findsOneWidget);
    expect(srv.calls, isNot(contains('portal:changePassword')));
    await t.enterText(find.byType(TextField).at(2), 'Mule#2026x');
    await settle(t, 600);
    await t.ensureVisible(find.text('Save and open'));      // (on a small phone the button may be below the screen's end)
    await settle(t, 400);
    await t.tap(find.text('Save and open'));
    await net(t);
    expect(srv.newPassword, 'Mule#2026x');
    expect(s.stage, Stage.pickSite);
  }, tags: ['golden']);

  testWidgets('Less motion asked on the phone: the sign-in screen is complete at once', (t) async {
    phone(t);
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final s = make(FakeServer());
    await t.runAsync(s.start);
    await t.pumpWidget(RclApp(session: s));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Sign in'), findsOneWidget);
    final op = t.widget<Opacity>(find.ancestor(of: find.text('Mechanical Management ERP'), matching: find.byType(Opacity)).first);
    expect(op.opacity, 1);
  });

  testWidgets('Log Book (native): the day\'s entries, the machinery still without one; a new entry – Start from the last one, Close typed – saved', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook'));
    await net(t);
    await pics(t);
    expect(find.text('Log Book'), findsOneWidget);
    expect(find.text('130 km'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('2 machinery without Log Book'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/10_logbook.png'));
    await t.tap(find.text('New Entry'));
    await net(t);
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    await t.tap(find.text('MH-25-AJ-2169'));
    await net(t);
    expect(find.text('KM reading'), findsOneWidget, reason: 'its one way (KM) is picked by itself');
    expect(find.widgetWithText(TextField, 'Start'), findsOneWidget);
    expect((t.widget<TextField>(find.widgetWithText(TextField, 'Start')).controller!).text, '15230', reason: 'the Start comes from its last entry');
    await t.enterText(find.widgetWithText(TextField, 'Close'), '15350');
    await settle(t, 300);
    expect(find.text('Work: 120 km'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/11_log_form.png'));
    await t.tap(find.text('Save Log Book'));
    await net(t);
    final row = srv.logSaved.single;
    expect([row['no'], row['date'], row['shift'], row['mode'], row['openingKm'], row['closingKm']], ['MH-25-AJ-2169', '2026-10-14', 'Day', 'KM', 15230, 15350]); // (14-10-2026: Day / Night by the time – 10:30 is Day)
    expect(find.text('Log Book saved'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('Log Book: a water tanker\'s entry is a card per trip (Trip 1, Trip 2), each with Change / Delete; Change opens that trip on the tanker screen', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms['Log Book'] = 'Edit'
      ..tanker = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook'));
    await net(t);
    await pics(t);
    await t.scrollUntilVisible(find.text('10:30 – 10:36'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Challan 123'), findsOneWidget, reason: 'the first trip, its own card');
    expect(find.text('07:35 – 07:50'), findsOneWidget);
    expect(find.text('Challan 18522'), findsOneWidget);
    expect(find.text('Trip 1'), findsOneWidget);
    expect(find.text('Trip 2'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/13_tanker_trips.png'));
    await t.tap(find.text('Challan 123'));
    await settle(t, 800);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await t.tap(find.text('Change'));
    await net(t);
    await pics(t);
    expect(find.text('Changing trip 1 of Day – challan 123'), findsOneWidget);
    expect(find.text('Save change'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/14_tanker_change.png'));
    await t.tap(find.text('Save change'));
    await net(t);
    final call = srv.tankerCalls.single;
    expect([call['action'], call['no'], call['shift'], call['n'], call['c'], (call['trip'] as Map)['c'], (call['trip'] as Map)['a'], call['to']], ['updateTankerTrip', 'MH-04-J-9844', 'Day', 1, '123', '123', '07:35', 'Day']);
  }, tags: ['golden']);

  testWidgets('My settings: default site, usual shift, diesel place, Log Book way, text size, mobile, photo, password', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Me'));
    await net(t);
    await t.tap(find.text('My settings'));
    await net(t);
    expect(find.text('Default site'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Change password'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Change password'), findsOneWidget);
    await t.scrollUntilVisible(find.text('My usual shift'), -200, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('My usual shift'));
    await settle(t, 600);
    await t.tap(find.text('Night').last);
    await net(t);
    expect(srv.prefs['shift'], 'Night');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/12_settings.png'));
  }, tags: ['golden']);

  testWidgets('(15-10-2026) App language: मराठी chosen in My settings – saved with his account, the whole app in Marathi; then हिंदी', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Me'));
    await net(t);
    await t.tap(find.text('My settings'));
    await net(t);
    await t.scrollUntilVisible(find.text('App language'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('ॲपची भाषा'), findsOneWidget, reason: 'nothing chosen yet: English with the Marathi line, as before');
    await t.tap(find.text('App language'));
    await settle(t, 600);
    await t.tap(find.text('मराठी').last);
    for (var i = 0; i < 60 && Lang.i.code != 'mr'; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await t.pump(const Duration(milliseconds: 50)); // (the words are read from the app's files; what follows runs on a pump)
    }
    expect(Lang.i.code, 'mr');
    await net(t);
    expect(srv.prefs['appLang'], 'mr');
    expect(srv.prefs['lang'], 'mr', reason: 'the help of the web follows');
    expect(Lang.i.code, 'mr');
    expect(find.text('App language'), findsNothing);
    expect(find.text('ॲपची भाषा'), findsOneWidget, reason: 'the row in Marathi – once, no English line');
    expect(find.text('माझ्या सेटिंग्ज'), findsOneWidget);
    expect(find.text('My settings'), findsNothing);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/13_settings_marathi.png'));
    await t.pageBack();
    await net(t);
    await t.tap(find.text(tr('Home')));
    await net(t);
    await pics(t);
    expect(find.text('Machinery'), findsNothing);
    expect(find.text('यंत्रे'), findsOneWidget, reason: 'the module tile in the app\'s own Marathi');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/14_home_marathi.png'));
    // हिंदी
    unawaited(s.setLanguage('hi'));
    for (var i = 0; i < 60 && Lang.i.code != 'hi'; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await t.pump(const Duration(milliseconds: 50)); // (the words are read from the app's files; what follows runs on a pump)
    }
    expect(Lang.i.code, 'hi');
    await net(t);
    expect(srv.prefs['appLang'], 'hi');
    expect(find.text('यंत्रे'), findsNothing, reason: 'not the Marathi words in Hindi');
    expect(find.text(tr('Machinery')), findsWidgets);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/15_home_hindi.png'));
  }, tags: ['golden']);

  /* ---------------- (3.4.0) Machinery: Asset Master and the other masters – the app's own screens ---------------- */
  FakeServer editor() => FakeServer()..perms.addAll({'Master': 'Edit', 'Vendor Master': 'Edit', 'Vendor BOQ': 'Edit', 'Vehicle Compliance': 'Edit'});
  Finder box(String k) => find.descendant(of: find.byKey(Key(k)), matching: find.byType(TextField));
  Future<void> openMaster(WidgetTester t, Session s, String page) async {
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Machinery').first);
    await net(t);
    await t.tap(find.byKey(Key('mp-$page')));
    await net(t);
  }

  testWidgets('(3.4.0) Machinery → Asset Master: on site today, the vendor chips, papers; all dates; a machinery\'s details', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Machinery').first);
    await net(t);
    for (final p in ['Asset Master', 'Vendor Master', 'Vendor BOQ', 'Vehicle Compliance', 'Log Book Format']) {
      expect(find.byKey(Key('mp-$p')), findsOneWidget);
    }
    await t.tap(find.byKey(const Key('mp-Asset Master')));
    await net(t);
    expect(find.text('Machinery: 2 of 3 · on site on 14-10-2026'), findsOneWidget, reason: 'OLD-9 left on 01-10-2026');
    expect(find.byKey(const Key('m-OLD-9')), findsNothing);
    expect(find.text('Papers: 1 expired'), findsOneWidget);
    expect(find.text('earlier: 01-06-2026 – 31-07-2026'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/18_asset_master.png'));
    await t.tap(find.byKey(const Key('m-alldates')));
    await settle(t, 300);
    expect(find.byKey(const Key('m-OLD-9')), findsOneWidget);
    await t.tap(find.byKey(const Key('vc-none')));
    await settle(t, 300);
    expect(find.byKey(const Key('m-OLD-9')), findsOneWidget);
    expect(find.byKey(const Key('m-MH-25-AJ-2169')), findsNothing);
    await t.tap(find.byKey(const Key('vc-all')));
    await settle(t, 300);
    await t.tap(find.text('MH-25-AJ-2169'));
    await settle(t, 800);
    expect(find.text('Engine Number'), findsOneWidget);
    expect(find.text('Lifetime'), findsOneWidget);
    expect(find.byKey(const Key('md-edit')), findsOneWidget);
    expect(find.byKey(const Key('md-del')), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.4.0) Asset Master read-only (View): no add, no ticks, no Edit / Delete', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Machinery').first);
    await net(t);
    expect(find.byKey(const Key('mp-Vendor BOQ')), findsNothing, reason: 'no access to Vendor BOQ');
    expect(find.byKey(const Key('mp-Log Book Format')), findsOneWidget, reason: 'Log Book Format is Master');
    await t.tap(find.byKey(const Key('mp-Asset Master')));
    await net(t);
    expect(find.byKey(const Key('m-add')), findsNothing);
    expect(find.byKey(const Key('mt-MH-25-AJ-2169')), findsNothing);
    await t.tap(find.text('MH-25-AJ-2169'));
    await settle(t, 800);
    expect(find.byKey(const Key('md-edit')), findsNothing);
  });

  testWidgets('(3.4.0) Add machinery: the number written as the server does, KM asks its standard, Ownership from the vendor, a paper N/A – saveMaster', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Asset Master');
    await t.tap(find.byKey(const Key('m-add')));
    await net(t);
    await t.enterText(box('mf-no'), 'mh12ab1234');
    await t.enterText(box('mf-type'), 'Tipper');
    await settle(t, 300);
    expect(find.text('MH-12-AB-1234'), findsOneWidget);
    expect(t.widget<TextField>(box('mf-kmstd')).enabled, false, reason: 'no KM ticked yet');
    await tapK(t, 'mw-KM');
    await settle(t, 300);
    await t.enterText(box('mf-kmstd'), '3.2');
    await t.enterText(box('mf-owner'), 'I E Enterprises');
    await settle(t, 300);
    expect(find.text('Rental'), findsWidgets, reason: 'Ownership picked by itself from the vendor');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/19_machine_form.png'));
    await tapK(t, 'mna-permit');
    await settle(t, 300);
    await tapK(t, 'mf-save');
    await net(t);
    final c = srv.masterCalls.last;
    expect((c['fn'], c['mode']), ('saveMaster', 'add'));
    final m = c['m'] as Map;
    expect(m['no'], 'MH-12-AB-1234');
    expect((m['worksOn'], m['unit'], m['kmStd'], m['hrStd']), ('KM', 'KM', 3.2, ''));
    expect((m['ownership'], m['supply'], m['status']), ('Rental', 'Company', 'Active'));
    expect((m['permitUpto'], m['taxUpto']), ('NA', ''));
    expect(m.containsKey('earlier'), false, reason: 'a new machinery has no earlier periods');
    expect(s.machine('MH-12-AB-1234'), isNotNull, reason: 'the app has the new list at once');
    expect(find.text('Machinery saved.'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.4.0) Edit: what changes is shown first; a machinery made Active again – "did it come back?" – its earlier period kept', (t) async {
    phone(t);
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Asset Master');
    await t.tap(find.text('MH-25-AJ-2169'));
    await settle(t, 800);
    await tapK(t, 'md-edit');
    await net(t);
    await t.enterText(box('mf-kmstd'), '4');
    await tapK(t, 'mf-save');
    await settle(t, 600);
    expect(find.text('Update MH-25-AJ-2169?'), findsOneWidget);
    expect(find.text('Standard Average (KM/Ltr)'), findsWidgets);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    var c = srv.masterCalls.last;
    expect((c['mode'], c['id']), ('edit', 'MH-25-AJ-2169'));
    expect((c['m'] as Map)['kmStd'], 4);
    expect((c['m'] as Map)['earlier'], [{'from': '2026-06-01', 'until': '2026-08-01'}]);
    // OLD-9 (left on 01-10-2026) made Active again
    await t.tap(find.byKey(const Key('m-alldates')));
    await settle(t, 300);
    await t.tap(find.text('OLD-9'));
    await settle(t, 800);
    await tapK(t, 'md-edit');
    await net(t);
    await tapK(t, 'mf-status');
    await settle(t, 400);
    await t.tap(find.text('Active').last);
    await settle(t, 600);
    expect(find.text('Did OLD-9 come back to the site?'), findsOneWidget);
    await t.tap(find.byKey(const Key('m-cameback')));
    await settle(t, 400);
    await tapK(t, 'mf-save');
    await settle(t, 600);
    expect(find.text('It came back'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    c = srv.masterCalls.last;
    expect(((c['m'] as Map)['status'], (c['m'] as Map)['activeFrom'], (c['m'] as Map)['inactiveFrom']), ('Active', '2026-10-14', ''));
  });

  testWidgets('(3.4.0) Several ticked: Edit selected sends only what was changed; Delete selected – they have entries – asked again', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Asset Master');
    await t.longPress(find.text('Sany 210 (No.1)'));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('mt-MH-25-AJ-2169')));
    await settle(t, 300);
    expect(find.text('2 selected'), findsOneWidget);
    await t.tap(find.byKey(const Key('m-seledit')));
    await net(t);
    expect(find.text('Ownership – different'), findsOneWidget);
    await tapK(t, 'me-ownership');
    await settle(t, 400);
    await t.tap(find.text('Hired').last);
    await settle(t, 400);
    await t.tap(find.byKey(const Key('me-save')));
    await net(t);
    var c = srv.masterCalls.last;
    expect(c['fn'], 'editMasterMany');
    expect(c['changes'], {'ownership': 'Hired'});
    expect((c['ids'] as List).toSet(), {'Sany 210 (No.1)', 'MH-25-AJ-2169'});
    expect(find.text('2 machinery updated.'), findsOneWidget);
    await t.tap(find.byKey(const Key('mt-MH-25-AJ-2169')));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('m-seldel')));
    await settle(t, 500);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    expect(find.text('1 of them already have entries'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    c = srv.masterCalls.last;
    expect((c['fn'], c['force']), ('deleteMasterMany', true));
    expect(s.machine('MH-25-AJ-2169'), isNull);
  });

  testWidgets('(3.4.0) Vendor Master: the list; a new vendor – the GST number gives the State and the PAN, the IFSC the bank and branch – saveVendor', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Vendor Master');
    expect(find.text('I E Enterprises'), findsOneWidget);
    expect(find.text('Incomplete'), findsOneWidget);
    expect(find.text('Bank: State Bank of India · ••••4321'), findsOneWidget);
    expect(find.byKey(const Key('v-mkall')), findsOneWidget, reason: 'RCL is an owner not yet saved as a vendor');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/20_vendors.png'));
    await t.tap(find.byKey(const Key('v-new')));
    await net(t);
    await t.enterText(box('vf-name'), 'Shree Ganesh Transport');
    await tapK(t, 'vf-gstreg');
    await settle(t, 400);
    await t.tap(find.text('Yes').last);
    await settle(t, 400);
    const g14 = '27ABCPE1234F1Z';
    await t.enterText(box('vf-gst'), g14 + gstCheckLetter(g14));
    await settle(t, 300);
    expect(find.textContaining('Maharashtra (27) · Individual / Proprietor · PAN ABCPE1234F filled in'), findsOneWidget);
    await t.enterText(box('vf-ifsc'), 'SBIN0001234');
    await net(t);
    expect(find.textContaining('State Bank of India – Nashik Road, Nashik, Maharashtra'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/21_vendor_form.png'));
    await tapK(t, 'vf-save');
    await net(t);
    final c = srv.masterCalls.last;
    expect((c['fn'], c['mode']), ('saveVendor', 'add'));
    final v = c['v'] as Map;
    expect((v['name'], v['gstReg'], v['pan'], v['bank'], v['branch'], v['ifsc'], v['oldName']), ('Shree Ganesh Transport', 'Yes', 'ABCPE1234F', 'State Bank of India', 'Nashik Road', 'SBIN0001234', ''));
    expect(find.text('Vendor saved: Shree Ganesh Transport'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.4.0) Vendor BOQ: the list; a new BOQ – the vendor\'s machinery ticked, Per Trip with a Night trip rate – saveBoq', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Vendor BOQ');
    expect(find.byKey(const Key('boq-BOQ-0001')), findsOneWidget);
    expect(find.textContaining('Monthly ₹45,000'), findsOneWidget);
    await t.tap(find.byKey(const Key('b-new')));
    await net(t);
    await tapK(t, 'bq-vendor');
    await settle(t, 400);
    await t.tap(find.text('Chalke Enterprises').last);
    await settle(t, 400);
    expect(t.widget<TextField>(box('bq-no')).controller!.text, '1');
    expect(t.widget<TextField>(box('bq-gst')).controller!.text, '18', reason: 'a GST-registered vendor: 18% at first');
    await tapK(t, 'bq-tick-MH-04-J-9844');
    await settle(t, 400);
    expect(find.byKey(const Key('bl-0')), findsOneWidget);
    await tapK(t, 'bl-basis-0-Monthly');
    await settle(t, 400);
    await t.tap(find.text('Per trip').last);
    await settle(t, 400);
    await t.enterText(find.descendant(of: find.byKey(const Key('bl-rate-0')), matching: find.byType(TextField)), '900');
    await t.enterText(find.descendant(of: find.byKey(const Key('bl-night-0')), matching: find.byType(TextField)), '1100');
    await settle(t, 300);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/22_boq_form.png'));
    await tapK(t, 'bq-save');
    await net(t);
    final c = srv.masterCalls.last;
    expect((c['fn'], c['mode']), ('saveBoq', 'add'));
    final b = c['b'] as Map;
    expect((b['vendor'], b['no'], b['from'], b['gstPct']), ('Chalke Enterprises', '1', '2026-10-01', '18'));
    final l = (b['lines'] as List).single as Map;
    expect((l['no'], l['basis'], l['rate'], l['nightRate'], l['diesel']), ('MH-04-J-9844', 'Per Trip', '900', '1100', 'Company'));
  }, tags: ['golden']);

  testWidgets('(3.4.0) Vehicle Compliance: the counts and chips; a paper renewed (N/A) – renewDoc; Papers per type', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Vehicle Compliance');
    expect(find.byKey(const Key('cp-MH-25-AJ-2169')), findsOneWidget);
    expect(find.byKey(const Key('cp-Sany 210 (No.1)')), findsNothing, reason: 'its papers are fine: not in "Needs attention"');
    expect(find.text('expired 14 days ago'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/23_compliance.png'));
    await tapK(t, 'cpr-MH-25-AJ-2169-Permit');
    await settle(t, 600);
    expect(find.text('Enter Permit'), findsOneWidget);
    await t.tap(find.byKey(const Key('cp-na')));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('cp-save')));
    await net(t);
    final c = srv.masterCalls.firstWhere((x) => x['fn'] == 'renewDoc');
    expect((c['x'] as Map)['to'], 'NA');
    expect(((c['x'] as Map)['no'], (c['x'] as Map)['doc'], (c['x'] as Map)['on']), ('MH-25-AJ-2169', 'Permit', '2026-10-14'));
    await t.ensureVisible(find.byKey(const Key('cp-chips')));
    await settle(t, 300);
    await t.scrollUntilVisible(find.byKey(const Key('cpc-all')), 150, scrollable: find.descendant(of: find.byKey(const Key('cp-chips')), matching: find.byType(Scrollable)).first);
    await settle(t, 300);
    await t.tap(find.byKey(const Key('cpc-all')));
    await settle(t, 300);
    expect(find.byKey(const Key('cp-Sany 210 (No.1)')), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.4.0) Log Book Format: a machinery set to Format C, Save – saveLbFormats; a format renamed', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Log Book Format');
    expect(find.byKey(const Key('lbm-MH-25-AJ-2169')), findsOneWidget);
    expect(find.byKey(const Key('lbo-MH-25-AJ-2169')), findsOneWidget, reason: 'its format box');
    await tapK(t, 'lbo-MH-25-AJ-2169');
    await settle(t, 400);
    await t.tap(find.text('C').last);
    await settle(t, 400);
    expect(find.text('Save (1 change not saved)'), findsOneWidget);
    await t.tap(find.byKey(const Key('lbf-save')));
    await net(t);
    expect(srv.masterCalls.last['ch'], {'MH-25-AJ-2169': 'C'});
    expect(s.machine('MH-25-AJ-2169')!.lbFormat, 'C');
    await t.ensureVisible(find.byKey(const Key('lbf-strip')));
    await settle(t, 300);
    await t.scrollUntilVisible(find.byKey(const Key('lbf-ren-C')), 200, scrollable: find.descendant(of: find.byKey(const Key('lbf-strip')), matching: find.byType(Scrollable)).first);
    await settle(t, 300);
    await t.tap(find.byKey(const Key('lbf-ren-C')));
    await settle(t, 400);
    await t.enterText(find.byKey(const Key('lbf-name')), 'KM book');
    await t.tap(find.byKey(const Key('lbf-name-ok')));
    await net(t);
    expect(srv.lbNames, {'C': 'KM book'});
    expect(find.text('KM book'), findsWidgets);
  });

  /* ---------------- (3.5.0) Dashboard and Tank Check – the app's own screens ---------------- */
  testWidgets('(3.5.0) Dashboard – Diesel: the figures, the tanks, ownership, stock of each place; Tank size saved; the ownership list', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Reports').last);
    await net(t);
    await t.tap(find.text('Dashboard'));
    await net(t);
    expect(srv.dashAsked.first['fn'], 'getDashboard');
    expect((srv.dashAsked.first['args'] as List).first, {'from': '2026-10-14', 'to': '2026-10-14'}, reason: 'it opens on Today, as the web');
    expect(find.byKey(const Key('k-open')), findsOneWidget);
    expect(find.text('19,895 Ltr'), findsOneWidget);
    expect(find.text('20,014 Ltr'), findsWidgets);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/24_dashboard.png'));
    await t.scrollUntilVisible(find.byKey(const Key('tank-set')), 300, scrollable: find.descendant(of: find.byKey(const Key('dash-diesel')), matching: find.byType(Scrollable)).first);
    await tapK(t, 'tank-set');
    await settle(t, 500);
    await t.enterText(find.descendant(of: find.byKey(const Key('tcap-low')), matching: find.byType(TextField)), '1500');
    await t.tap(find.byKey(const Key('tcap-save')));
    await net(t);
    expect(srv.masterCalls.last['fn'], 'saveTankSettings');
    expect((srv.masterCalls.last['x'] as Map)['low'], 1500);
    await t.scrollUntilVisible(find.byKey(const Key('own-Own')), 300, scrollable: find.descendant(of: find.byKey(const Key('dash-diesel')), matching: find.byType(Scrollable)).first);
    await tapK(t, 'own-Own');
    await net(t);
    expect(find.text('Own – Diesel issued'), findsOneWidget);
    expect(srv.dashAsked.last['fn'], 'getOwnershipDetail');
  }, tags: ['golden']);

  testWidgets('(3.5.0) Dashboard – Log Book: the four figures, machine-wise work, pending dates – a date opens its new entry', (t) async {
    phone(t);
    final srv = editor()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Reports').last);
    await net(t);
    await t.tap(find.text('Dashboard'));
    await net(t);
    await t.tap(find.byKey(const Key('dt-log')));
    await net(t);
    expect(srv.dashAsked.any((x) => x['fn'] == 'logDashboard'), true);
    expect(srv.dashAsked.any((x) => x['fn'] == 'pendingLog'), true);
    expect(find.byKey(const Key('lc-1')), findsOneWidget);
    expect(find.text('1 of 48'), findsOneWidget);
    expect(find.text('126 days'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/25_dash_log.png'));
    await t.scrollUntilVisible(find.byKey(const Key('pfo-MH-15-AB-0001')), 800, scrollable: find.descendant(of: find.byKey(const Key('dash-log')), matching: find.byType(Scrollable)).first);
    await tapK(t, 'pfo-MH-15-AB-0001');
    await net(t);
    expect(find.byType(LogForm), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.5.0) Tank Check: the system says, found, the difference – saved once (saveTankCheck); the checks, Delete', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook'));
    await net(t);
    await t.tap(find.byKey(const Key('lb-menu')));
    await settle(t, 500);
    await t.tap(find.text('Tank Check').last);
    await net(t);
    expect(find.byKey(const Key('tcr-TC-0001')), findsOneWidget);
    expect(find.text('Reason: Leak at the hose'), findsOneWidget);
    await t.tap(find.byKey(const Key('tc-no')));
    await net(t);
    await t.tap(find.text('Sany 210 (No.1)').last);
    await net(t);
    expect(find.text('120 Ltr'), findsOneWidget);
    expect(find.text('Log Book 13-10-2026 (Day) · + 60 L given after that · tank 400 L'), findsOneWidget);
    await t.enterText(box('tc-phys'), '100');
    await settle(t, 300);
    expect(find.text('−20 Ltr'), findsOneWidget);
    expect(find.text('Less than the system (−16.67%) – ask why'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/26_tank_check.png'));
    await tapK(t, 'tc-save');
    await settle(t, 600);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    final c = srv.masterCalls.firstWhere((x) => x['fn'] == 'saveTankCheck');
    expect((c['x'] as Map)['no'], 'Sany 210 (No.1)');
    expect(((c['x'] as Map)['method'], (c['x'] as Map)['physical'], (c['x'] as Map)['date']), ('measure', 100, '2026-10-14'));
    expect(srv.rids.any((r) => r.startsWith('saveTankCheck:')), true, reason: 'saved once, with its own number');
    await tapK(t, 'tcd-TC-0001');
    await settle(t, 500);
    await t.tap(find.text('Delete').last);
    await net(t);
    expect(srv.masterCalls.last, {'fn': 'deleteTankCheck', 'id': 'TC-0001'});
  }, tags: ['golden']);

  testWidgets('(3.6.0) Edit Log Book: a machinery and dates – the entries as cards; a Close moves the next Start; Save sends the whole lot once', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook'));
    await net(t);
    await t.tap(find.byKey(const Key('lb-menu')));
    await settle(t, 500);
    await t.tap(find.text('Edit Log Book').last);
    await net(t);
    await tapK(t, 'lx-no');
    await net(t);
    await t.tap(find.text('MH-25-AJ-2169').last);
    await net(t);
    await tapK(t, 'lx-q-this');
    await settle(t, 300);
    await tapK(t, 'lx-load');
    await net(t);
    expect(srv.logBulk.first, {'fn': 'getLogEditData', 'args': ['MH-25-AJ-2169', '2026-10-01', '2026-10-14']});
    expect(find.text('MH-25-AJ-2169 – Tipper'), findsOneWidget);
    expect(find.text('No changes yet'), findsOneWidget);
    final list = find.descendant(of: find.byKey(const Key('lx-list')), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.byKey(const Key('lx-ckm-0')), 300, scrollable: list);
    await t.enterText(find.byKey(const Key('lx-ckm-0')), '15050');
    await settle(t, 500);
    expect(find.text('2 changed / new, 0 deleted'), findsOneWidget, reason: 'the next row\'s Start followed the Close');
    await t.scrollUntilVisible(find.byKey(const Key('lx-okm-1')), 300, scrollable: list);
    expect(t.widget<TextField>(find.byKey(const Key('lx-okm-1'))).controller!.text, '15050');
    await t.scrollUntilVisible(find.byKey(const Key('lxr-0')), -300, scrollable: list);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/27_log_edit.png'));
    await t.tap(find.byKey(const Key('lx-save')));
    await settle(t, 600);
    expect(find.text('Save Log Book of MH-25-AJ-2169?'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    final x = srv.logBulk.firstWhere((c) => c['fn'] == 'saveLogBulk')['x'] as Map;
    final rows = (x['rows'] as List).cast<Map>();
    expect((x['no'], x['from'], x['to']), ('MH-25-AJ-2169', '2026-10-01', '2026-10-14'));
    expect(x['deleted'], isEmpty);
    expect([for (final r in rows) '${r['date']} ${r['openingKm']}-${r['closingKm']} ${r['same']}'], ['2026-10-12 15000-15050 false', '2026-10-13 15050-15100 false', '2026-10-14 15100-15230 true']);
    expect(srv.rids.any((r) => r.startsWith('saveLogBulk:')), true, reason: 'saved once, with its own number');
    expect(srv.logBulk.where((c) => c['fn'] == 'getLogEditData').length, 2, reason: 'opened again after the save');
  }, tags: ['golden']);

  testWidgets('(3.6.0) Edit Log Book of a water tanker: its trips, one card each; a challan changed – saveTankerRange', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms['Log Book'] = 'Edit'
      ..tanker = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook'));
    await net(t);
    await t.tap(find.byKey(const Key('lb-menu')));
    await settle(t, 500);
    await t.tap(find.text('Edit Log Book').last);
    await net(t);
    await tapK(t, 'lx-no');
    await net(t);
    await t.tap(find.text('MH-04-J-9844').last);
    await net(t);
    await tapK(t, 'lx-q-this');
    await settle(t, 300);
    await tapK(t, 'lx-load');
    await net(t);
    expect(srv.logBulk.first, {'fn': 'getTankerRange', 'args': ['MH-04-J-9844', '2026-10-01', '2026-10-14']});
    await t.scrollUntilVisible(find.byKey(const Key('lt-c-1')), 300, scrollable: find.descendant(of: find.byKey(const Key('lx-list')), matching: find.byType(Scrollable)).first);
    expect(find.byKey(const Key('ltr-1')), findsOneWidget);
    expect(find.text('No changes yet'), findsOneWidget);
    await t.enterText(find.byKey(const Key('lt-c-1')), '18523');
    await settle(t, 400);
    expect(find.text('Not saved yet'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/28_log_edit_tanker.png'));
    await t.tap(find.byKey(const Key('lt-save')));
    await net(t);
    final x = srv.logBulk.firstWhere((c) => c['fn'] == 'saveTankerRange')['x'] as Map;
    expect([for (final tr in (x['trips'] as List).cast<Map>()) '${tr['date']} ${tr['shift']} ${tr['c']} ${tr['a']}-${tr['b']}'], ['2026-10-14 Day 123 07:35-07:50', '2026-10-14 Day 18523 10:30-10:36']);
    expect(find.text('No changes yet'), findsOneWidget, reason: 'opened again from what was saved');
  }, tags: ['golden']);

  testWidgets('(3.7.0) Maintenance → Breakdown: the day – a breakdown carried with its days; a breakdown needs its reason; Submit; the period report', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms['Breakdown'] = 'Edit'
      ..bdRich = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Maintenance'));
    await net(t);
    expect(srv.bdSent.first, {'fn': 'getBreakdowns', 'args': [{'date': '2026-10-14'}]});
    expect(find.text('Status of 14-10-2026 not submitted yet · breakdowns carried from 13-10-2026'), findsOneWidget);
    final list = find.descendant(of: find.byKey(const Key('bk-list')), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.byKey(const Key('bk-days-MH-25-AJ-2169')), 300, scrollable: list);
    expect(find.text('5 days'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('bk-sw-Sany 210 (No.1)')), -300, scrollable: list);
    await t.tap(find.descendant(of: find.byKey(const Key('bk-sw-Sany 210 (No.1)')), matching: find.text('Breakdown')));
    await settle(t, 400);
    await t.scrollUntilVisible(find.byKey(const Key('bk-submit')), -300, scrollable: list);
    await tapK(t, 'bk-submit');
    await settle(t, 600);
    expect(find.text('Write the reason for: Sany 210 (No.1).'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('bk-reason-Sany 210 (No.1)')), 300, scrollable: list);
    await t.enterText(box('bk-reason-Sany 210 (No.1)'), 'Hydraulic problem');
    ScaffoldMessenger.of(t.element(find.byKey(const Key('bk-list')))).clearSnackBars();
    await settle(t, 600);
    await t.scrollUntilVisible(find.byKey(const Key('bk-status')), -300, scrollable: list);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 300);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/29_breakdown.png'));
    await tapK(t, 'bk-submit');
    await settle(t, 600);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    final x = srv.bdSent.firstWhere((c) => c['fn'] == 'submitBdReport')['x'] as Map;
    expect(x['date'], '2026-10-14');
    expect([for (final r in (x['rows'] as List).cast<Map>()) '${r['no']} ${r['status']} ${r['reason']}'], ['Sany 210 (No.1) Breakdown Hydraulic problem', 'MH-25-AJ-2169 Breakdown Tyre puncture']);
    expect(srv.rids.any((r) => r.startsWith('submitBdReport:')), true, reason: 'saved once, with its own number');
    expect(find.text('✔ Submitted by Tester at 14-10-2026 18:05 – 2 machinery, 2 breakdown'), findsOneWidget);
    await t.tap(find.byKey(const Key('bt-period')));
    await settle(t, 800);
    expect(find.byKey(const Key('bpm-MH-25-AJ-2169')), findsOneWidget);
    expect(find.text('10-10 →: Tyre puncture (5 d)'), findsOneWidget);
    await t.tap(find.byKey(const Key('bt-days')));
    await settle(t, 800);
    expect(find.byKey(const Key('bkd-2026-10-13')), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.8.0) Billing → Machinery Billing: a vendor picked, Build bills (the web\'s working), Idle paid, a debit note ticked, Verify & Submit; RCL Drive', (t) async {
    phone(t);
    final srv = FakeServer()..billing = true;
    srv.perms.addAll({'Machinery Billing': 'Edit', 'Saved Bills': 'Edit', 'Bill Summary': 'View', 'Machinery Payments': 'Edit', 'Vendor Ledger': 'View', 'Vendor Outstanding': 'View'});
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Billing'));
    await net(t);
    for (final k in ['Machinery Billing', 'Saved Bills', 'Bill Summary', 'Machinery Payments', 'Vendor Ledger', 'Vendor Outstanding']) {
      expect(find.byKey(Key('bh-$k')), findsOneWidget, reason: k);
    }
    await tapK(t, 'bh-Machinery Billing');
    await net(t);
    expect(find.text('01-09-2026'), findsOneWidget, reason: 'last month, as the web');
    await tapK(t, 'mb-vendors');
    await settle(t, 600);
    await t.tap(find.descendant(of: find.byKey(const Key('mbv-I E Enterprises')), matching: find.byType(Checkbox)));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('mbv-done')));
    await settle(t, 600);
    await tapK(t, 'mb-build');
    await net(t);
    expect({for (final c in srv.billSent) c['fn']}, {'getLogBookList', 'logPrintExtra', 'billCorrections'});
    final list = find.descendant(of: find.byKey(const Key('mb-list')), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.byKey(const Key('mb-warn-0')), 300, scrollable: list);
    expect(find.textContaining('1 Idle day(s) – choose Paid / Not paid'), findsOneWidget);
    expect(find.text('5,431.42'), findsOneWidget, reason: 'A 9,000.00 − B 3,457.73 (37.14 L above the standard × ₹93.10) − TDS 2 % 110.85');
    await t.scrollUntilVisible(find.byKey(const Key('mb-idle-0')), 300, scrollable: list);
    await tapK(t, 'mb-idle-0');
    await settle(t, 600);
    await t.tap(find.text('Paid').last);
    await settle(t, 600);
    expect(find.byKey(const Key('mb-warn-0')), findsNothing, reason: 'nothing to check once Idle is chosen');
    await t.scrollUntilVisible(find.byKey(const Key('mb-dn-0-DN-0003')), -300, scrollable: list);
    await tapK(t, 'mb-dn-0-DN-0003');
    await settle(t, 600);
    await t.scrollUntilVisible(find.byKey(const Key('mb-no-0')), 300, scrollable: list);
    expect(find.text('3,931.42'), findsOneWidget, reason: 'the debit note of 1,500.00 off the net payable');
    await t.scrollUntilVisible(find.byKey(const Key('mb-title')), -300, scrollable: list);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/30_bill_make.png'));
    await tapK(t, 'mb-submit');
    await net(t);
    expect(find.text('Verification – 1 of 1 bill ready'), findsOneWidget);
    await t.tap(find.byKey(const Key('vf-ok')));
    await net(t);
    final x = srv.billSent.firstWhere((c) => c['fn'] == 'submitBills')['x'] as Map, b = ((x['bills'] as List).single as Map);
    expect([b['vendor'], b['company'], b['billNo'], b['from'], b['to'], b['net']], ['I E Enterprises', 'Sketchline Industries', '8', '2026-09-01', '2026-09-30', 5431.42]);
    final data = b['data'] as Map;
    expect([data['idlePaid'], data['A'], data['B'], data['K'], (data['dns'] as List).length, data['edited']], [true, 9000, 3457.73, 3931.42, 1, false]);
    expect(srv.rids.any((r) => r.startsWith('submitBills:')), true, reason: 'saved once, with its own number');
    expect(find.text('1 bill(s) verified and submitted.'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await tapK(t, 'bh-Saved Bills');
    await net(t);
    expect(find.byKey(const Key('sb-BILL-00001')), findsOneWidget);
    expect(find.text('Superseded'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/31_bill_drive.png'));
    await t.tap(find.byKey(const Key('drv-dn')));
    await settle(t, 800);
    expect(find.byKey(const Key('dnn-DN-0003')), findsOneWidget);
    expect(find.byKey(const Key('dnb-BILL-00001')), findsOneWidget, reason: 'the diesel debit note of the bill');
  }, tags: ['golden']);

  testWidgets('(3.8.0) Billing: a new debit note from the Log Book entries charged to the party; Vendor Ledger; a payment saved', (t) async {
    phone(t);
    final srv = FakeServer()..billing = true;
    srv.perms.addAll({'Machinery Billing': 'Edit', 'Saved Bills': 'Edit', 'Machinery Payments': 'Edit', 'Vendor Ledger': 'View'});
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Billing'));
    await net(t);
    await tapK(t, 'bh-Saved Bills');
    await net(t);
    await t.tap(find.byKey(const Key('drv-dn')));
    await settle(t, 800);
    await tapK(t, 'dn-open');
    await net(t);
    await t.enterText(box('dn-vendor'), 'I E Enterprises');
    await tapK(t, 'dn-fetch');
    await net(t);
    expect(srv.billSent.last['args'], [{'vendor': 'I E Enterprises', 'from': '2026-10-01', 'to': '2026-10-14'}]);
    expect(find.text('Amount 6,600.00'), findsOneWidget);
    await t.enterText(box('dn-gst'), '18');
    await settle(t, 300);
    expect(find.text('Amount 6,600.00 + GST 1,188.00 − TDS 0.00 = Total ₹ 7,788.00'), findsOneWidget);
    await tapK(t, 'dn-save');
    await settle(t, 600);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    final n = srv.billSent.firstWhere((c) => c['fn'] == 'saveDebitNote')['x'] as Map;
    expect([n['company'], n['vendor'], n['gstPct'], (n['lines'] as List).single], ['Rachana Construction Limited', 'I E Enterprises', '18',
      {'logId': 'MH-25-AJ-2169|2026-10-02|Day', 'machinery': 'MH-25-AJ-2169 Tipper', 'particular': '02-10-2026 Day – Carting for the party', 'qty': 6, 'unit': 'Hrs', 'rate': 1100}]);
    await t.pageBack();
    await net(t);
    await tapK(t, 'bh-Vendor Ledger');
    await net(t);
    await t.tap(find.byKey(const Key('vl-vendor')));
    await settle(t, 600);
    await t.tap(find.text('I E Enterprises').last);
    await net(t);
    expect(find.text('Vendor Ledger – I E ENTERPRISES'), findsOneWidget);
    expect(find.text('₹ 4,750.50'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await tapK(t, 'bh-Machinery Payments');
    await net(t);
    await t.tap(find.byKey(const Key('py-vendor')));
    await settle(t, 600);
    await t.tap(find.text('I E Enterprises').last);
    await net(t);
    expect(find.text('Balance of I E Enterprises now: ₹ 4,750.50 (opening ₹ 5,000.00 + bills ₹ 39,750.50 − paid ₹ 40,000.00)'), findsOneWidget);
    await t.enterText(box('py-amount'), '4750.50');
    await tapK(t, 'py-save');
    await net(t);
    final p = srv.billSent.firstWhere((c) => c['fn'] == 'savePayment');
    expect([(p['x'] as Map)['vendor'], (p['x'] as Map)['amount'], (p['x'] as Map)['type'], p['how']], ['I E Enterprises', '4750.50', 'Payment', 'add']);
  });

  testWidgets('(3.9.0) Administration: Users & Access – a user added with his access; the Activity Log; the Rules of the site; Read Me', (t) async {
    phone(t);
    final srv = FakeServer()..superAdmin = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.ensureVisible(find.text('Administration'));
    await settle(t, 400);
    await t.tap(find.text('Administration'));
    await net(t);
    await tapK(t, 'ad-Users & Access');
    await net(t);
    expect(find.text('2 users · 2 active'), findsOneWidget);
    expect(find.text('must set password'), findsOneWidget);
    await tapK(t, 'ua-new');
    await settle(t, 400);
    await t.enterText(box('ua-new-email'), 'driver@rcl.test');
    await t.enterText(box('ua-new-name'), 'New Driver');
    await tapK(t, 'ua-p-+new-Log Book');
    await settle(t, 600);
    await t.tap(find.text('Edit').last);
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('ua-new-pw')), 'Once#2026');
    await settle(t, 600);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/32_admin_users.png'));
    await tapK(t, 'ua-add');
    await net(t);
    final x = srv.adminSent.firstWhere((c) => c['fn'] == 'saveUserAdmin')['x'] as Map;
    expect([x['isNew'], x['email'], x['name'], x['active'], x['admin'], x['newPassword'], x['perms']], [true, 'driver@rcl.test', 'New Driver', true, false, 'Once#2026', {'Dashboard': 'None', 'Log Book': 'Edit', 'Machinery Billing': 'None'}]);
    expect(srv.rids.any((r) => r.startsWith('saveUserAdmin:')), true);
    expect(find.text('3 users · 3 active'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await tapK(t, 'ad-Activity Log');
    await net(t);
    expect(find.text('Entries: 2'), findsOneWidget);
    expect(find.textContaining('MH-25-AJ-2169|2026-10-13|Full Day'), findsOneWidget);
    await tapK(t, 'af-today');
    await net(t);
    expect(srv.adminSent.last['f'], {'from': '2026-10-14', 'to': '2026-10-14', 'user': '', 'module': '', 'action': '', 'q': ''});
    await t.pageBack();
    await net(t);
    await tapK(t, 'ad-Rules of this site');
    await net(t);
    await t.enterText(box('rule-back'), '3');
    await t.enterText(box('rule-note'), 'Fill the Log Book daily');
    await tapK(t, 'rule-save');
    await net(t);
    expect((srv.adminSent.last['x'] as Map)['backDays'], '3');
    expect(s.siteRules['backDays'], 3);
    await t.pageBack();
    await net(t);
    await tapK(t, 'ad-Read Me');
    await net(t);
    expect(find.text('1. हे app काय आहे'), findsWidgets);
    expect(find.textContaining('insert into public.app_users (id, email, name, password_hash, active, admin, perm_dashboard, mobile)'), findsOneWidget);
    await t.enterText(find.byKey(const Key('rm-in-rm_ad_email')), 'boss@site.com');
    await settle(t, 400);
    expect(find.textContaining("values ('boss@site.com', 'boss@site.com', 'Admin'"), findsOneWidget, reason: 'the SQL follows what is typed');
  }, tags: ['golden']);

  testWidgets('(3.10.0) Store: its own sign-in (a Portal ticket); the Dashboard; the Item Master – a near name asked, saved as a different item', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.ensureVisible(find.text('Store'));
    await settle(t, 400);
    await t.tap(find.text('Store'));
    await net(t);
    expect(srv.calls, contains('portal:go:store:S1'));
    expect(srv.storeSent.first, {'fn': 'sso', 'ticket': 'tk2'});
    expect(srv.storeSent[1]['cookie'], startsWith('rcl_store=S1.store1-'), reason: 'the Store\'s own sign-in, kept for its calls');
    expect(find.text('Added this month'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/33_store.png'));
    await t.tap(find.byKey(const Key('st-tab-items')));
    await settle(t, 800);
    expect(find.text('3 of 3 items'), findsOneWidget);
    await t.enterText(find.byKey(const Key('st-q')), 'filter');
    await settle(t, 400);
    expect(find.text('1 of 3 items'), findsOneWidget);
    await t.enterText(find.byKey(const Key('st-q')), '');
    await settle(t, 400);
    await t.tap(find.byKey(const Key('st-new')));
    await net(t);
    await t.enterText(box('it-name'), 'Sugaar');
    await net(t, 800);
    expect(find.text('Near: ITM-0002 Sugar'), findsOneWidget, reason: 'said while typing');
    await t.tap(find.byKey(const Key('it-unit')));
    await settle(t, 600);
    await t.tap(find.text('Kg').last);
    await settle(t, 400);
    await t.enterText(box('it-cat'), 'Canteen');
    await tapK(t, 'it-save');
    await net(t);
    expect(find.text('Is it the same item?'), findsOneWidget);
    await t.tap(find.byKey(const Key('itc-diff')));
    await net(t);
    final saves = srv.storeSent.where((x) => x['action'] == 'save').toList();
    expect([for (final x in saves) x['confirm']], [[], ['ITM-0002']]);
    expect((saves.last['item'] as Map)['name'], 'Sugaar');
    expect(find.text('4 of 4 items'), findsOneWidget, reason: 'the list read again');
  }, tags: ['golden']);

  // (3.11.0) the files made (Excel) are read back here; a file "picked" from the phone
  List<(String, Uint8List)> catchFiles() {
    final files = <(String, Uint8List)>[];
    fileSink = (b, n, m) async => files.add((n, b));
    addTearDown(() => fileSink = null);
    return files;
  }

  void pickThis(String name, List<int> bytes) {
    final orig = pickSheetFile;
    pickSheetFile = () async => (name: name, bytes: Uint8List.fromList(bytes));
    addTearDown(() => pickSheetFile = orig);
  }

  Future<void> more(WidgetTester t, String item) async {
    await t.tap(find.byKey(const Key('en-more')));
    await settle(t, 600);
    await t.tap(find.byKey(Key(item)));
    await net(t);
  }

  testWidgets('(3.11.0) Diesel Issue ⋮: Import from Excel – each row checked (Fix the file first / Import N rows) → importDiesel; the template; All dates & Export', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    final files = catchFiles();
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    // a file whose machinery is not in this site's Master: nothing can be imported
    pickThis('diesel_issue.xlsx', File('test/fixtures/sheets/diesel_issue.xlsx').readAsBytesSync());
    await more(t, 'en-import');
    expect(find.text('Fix the file first'), findsOneWidget);
    expect(find.textContaining('rows have a problem (marked ✗). Nothing was imported.'), findsOneWidget);
    expect(find.textContaining('machinery not in Master'), findsWidgets);
    await t.tap(find.byKey(const Key('imp-ok')));
    await net(t);
    expect(srv.importSent, isEmpty);
    // a good CSV: by number / name in other letters, the place in small letters, "1,250"
    pickThis('issues.csv', utf8.encode('Date,Shift,Diesel Source,Machinery Number / Name,Diesel Qty (Ltr),Hrs Reading\n14-10-2026,Day,dispenser,sany 210 (no.1),60,4712\n13-10-2026,night,VTR Store,MH-25-AJ-2169,"1,250",\n'));
    await more(t, 'en-import');
    expect(find.text('Import 2 diesel issues?'), findsOneWidget);
    expect(find.textContaining('Total 1,310 Ltr.'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/34_import_check.png'));
    await t.tap(find.byKey(const Key('imp-go')));
    await net(t);
    final sent = srv.importSent.single;
    expect(sent['fn'], 'importDiesel');
    expect(sent['rows'], [
      {'line': '2', 'date': '2026-10-14', 'shift': 'Day', 'source': 'Dispenser', 'no': 'Sany 210 (No.1)', 'qty': 60, 'kmReading': '', 'hrReading': 4712, 'driver': '', 'remark': ''},
      {'line': '3', 'date': '2026-10-13', 'shift': 'Night', 'source': 'VTR Store', 'no': 'MH-25-AJ-2169', 'qty': 1250, 'kmReading': '', 'hrReading': '', 'driver': '', 'remark': ''},
    ]);
    expect(find.text('2 diesel issues imported (1,310 Ltr).'), findsOneWidget);
    // the template: the web's headings, a machinery on site today
    await more(t, 'en-template');
    expect(files.last.$1, 'Diesel Issue – import template.xlsx');
    final tpl = readSheets(files.last.$2).single;
    expect(tpl.name, 'Diesel Issue');
    expect(tpl.rows.first, ['Date', 'Shift', 'Diesel Source', 'Machinery Number / Name', 'Diesel Qty (Ltr)', 'KM Reading', 'Hrs Reading', 'Driver Name', 'Remark']);
    expect(tpl.rows[1].take(3), ['14-10-2026', 'Day', 'Dispenser']);
    expect(tpl.rows[1][3], isIn(['Sany 210 (No.1)', 'MH-25-AJ-2169']));
    expect(tpl.rows[1][4], 60);
    // all dates: the web's filter; Today; the % of the total; % by machinery; Export – the web's file
    await more(t, 'en-find');
    expect(srv.listAsked.last, {'fn': 'getDieselIssues', 'from': '', 'to': '', 'no': '', 'shift': '', 'source': '', 'owner': '', 'driver': '', 'q': ''});
    expect(find.text('Entries: 4   Total diesel: 240 Ltr'), findsOneWidget);
    await t.tap(find.byKey(const Key('ef-r-today')));
    await net(t);
    expect(srv.listAsked.last['from'], '2026-10-14');
    expect(srv.listAsked.last['to'], '2026-10-14');
    expect(find.textContaining('25% of total'), findsOneWidget, reason: '60 of 240');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/35_entry_find.png'));
    await tapK(t, 'ef-share');
    await settle(t, 500);
    expect(find.text('Sany 210 (No.1)'), findsWidgets);
    expect(find.text('80 Ltr · 33.33%'), findsWidgets);
    await tapK(t, 'ef-export');
    await net(t);
    expect(srv.listAsked.last['all'], true);
    expect(files.last.$1, 'Diesel Issue 14-10-2026 to 14-10-2026.xlsx');
    final ex = readSheets(files.last.$2).single.rows;
    expect(ex[2].first, 'Diesel Issue – 14-10-2026 to 14-10-2026');
    expect(ex[4].take(5), ['Issue ID', 'Date', 'Shift', 'Diesel Source', 'Machinery Number']);
    expect([for (final r in ex.sublist(5, 9)) r.first], ['DI-000520', 'DI-000521', 'DI-000522', 'DI-000525'], reason: 'oldest first, as the web');
    expect(ex.last.first, 'Total');
    expect(ex.last[8], 240);
    expect(find.text('4 diesel issues exported.'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.11.0) Multiple entries: Transfer rows → saveTransferBulk; Diesel one date – many machinery (a warning: Save all anyway); one machinery – many dates', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Diesel Transfer'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Transfer')));
    await net(t);
    await more(t, 'en-many');
    expect(find.byKey(const Key('tm-row-1')), findsOneWidget, reason: 'two rows to start');
    await t.enterText(box('tm-qty-0'), '500');
    await t.enterText(box('tm-qty-1'), '300');
    await t.enterText(box('tm-remark-1'), 'For night work');
    await settle(t, 300);
    expect(find.text('Rows: 2  Qty: 800 Ltr'), findsOneWidget);
    await tapK(t, 'tm-add');
    await settle(t, 300);
    expect(find.byKey(const Key('tm-row-2')), findsOneWidget);
    await tapK(t, 'tm-save');
    await settle(t, 600);
    expect(find.text('Save 2 transfers?'), findsOneWidget);
    await t.tap(find.text('Save 2 transfers'));
    await net(t);
    expect(srv.importSent.single, {
      'fn': 'saveTransferBulk',
      'rows': [
        {'line': 1, 'date': '2026-10-14', 'shift': 'Day', 'from': 'Dispenser', 'to': 'VTR Store', 'qty': 500, 'remark': ''},
        {'line': 2, 'date': '2026-10-14', 'shift': 'Day', 'from': 'Dispenser', 'to': 'VTR Store', 'qty': 300, 'remark': 'For night work'},
      ],
    });
    expect(find.text('2 transfers saved (800 Ltr).'), findsOneWidget);
    await t.pageBack();
    await net(t);
    // Diesel Issue – one date, many machinery
    await t.tap(find.byTooltip('All entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await more(t, 'en-many');
    expect(find.textContaining('Dispenser stock on this date: 813 Ltr'), findsOneWidget);
    await tapK(t, 'im-row-0-pick');
    await settle(t, 800);
    await t.tap(find.text('Sany 210 (No.1)').last);
    await settle(t, 600);
    await t.enterText(box('im-row-0-qty'), '60');
    await t.enterText(box('im-row-0-hr'), '1');
    await settle(t, 300);
    expect(find.text('753 Ltr'), findsOneWidget, reason: 'the stock after this row');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/36_issue_many.png'));
    await tapK(t, 'im-save');
    await net(t);
    expect(find.text('Please check these rows'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    final bulk = [for (final x in srv.importSent.where((x) => x['fn'] == 'saveDieselBulk')) x['b'] as Map];
    expect([for (final b in bulk) b['force']], [false, true]);
    expect(bulk.first['rows'], [
      {'no': 'Sany 210 (No.1)', 'qty': '60', 'kmReading': '', 'hrReading': '1', 'driver': '', 'remark': '', 'mode': 'Hrs'},
      {'no': '', 'qty': '', 'kmReading': '', 'hrReading': '', 'driver': '', 'remark': '', 'mode': ''},
    ], reason: 'as the web: every row, the typed text');
    expect([bulk.first['date'], bulk.first['shift'], bulk.first['source']], ['2026-10-14', 'Day', 'Dispenser']);
    expect(find.text('1 diesel issues saved (DI-000527 to DI-000527).'), findsOneWidget);
    // one machinery, many dates: the next row is the next day; the KM its meter gives
    await tapK(t, 'im-t-mach');
    await settle(t, 500);
    await tapK(t, 'im-mach');
    await settle(t, 800);
    await t.tap(find.text('MH-25-AJ-2169').last);
    await settle(t, 600);
    await tapK(t, 'im-mrow-0-date');
    await settle(t, 600);
    await t.tap(find.text('13').last);
    await settle(t, 300);
    await t.tap(find.text('OK'));
    await settle(t, 600);
    await t.enterText(box('im-mrow-0-qty'), '50');
    await t.enterText(box('im-mrow-0-km'), '15130');
    await tapK(t, 'im-madd');
    await net(t);
    await t.enterText(box('im-mrow-1-qty'), '40');
    await t.enterText(box('im-mrow-1-km'), '15200');
    await settle(t, 300);
    expect(find.text('Rows: 2  Diesel: 90 Ltr'), findsOneWidget);
    await tapK(t, 'im-madd');
    await settle(t, 400);
    expect(find.text('Diesel can be entered only up to today (14-10-2026).'), findsOneWidget);
    await tapK(t, 'im-msave');
    await settle(t, 600);
    expect(find.text('Save 2 diesel issues of MH-25-AJ-2169?'), findsOneWidget);
    await t.tap(find.text('Save 2 entries'));
    await net(t);
    final imp = srv.importSent.lastWhere((x) => x['fn'] == 'importDiesel');
    expect(imp['rows'], [
      {'line': 1, 'date': '2026-10-13', 'shift': 'Day', 'source': 'Dispenser', 'no': 'MH-25-AJ-2169', 'qty': 50, 'kmReading': 15130, 'hrReading': '', 'driver': '', 'remark': ''},
      {'line': 2, 'date': '2026-10-14', 'shift': 'Day', 'source': 'Dispenser', 'no': 'MH-25-AJ-2169', 'qty': 40, 'kmReading': 15200, 'hrReading': '', 'driver': '', 'remark': ''},
    ]);
    expect(find.text('2 diesel issues saved for MH-25-AJ-2169 (90 Ltr).'), findsOneWidget);
  }, tags: ['golden']);
}
