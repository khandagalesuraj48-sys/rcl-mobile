/* The app's screens on a phone (360 × 780) with the pretend servers: what a person sees and does.
 * The tests tagged "golden" also make pictures of the screens (test/goldens/) – for looking at, in the build's files. */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ComputeCallback;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/applock.dart';
import 'package:rcl_mobile/core/lang.dart';
import 'package:rcl_mobile/core/masters.dart' show gstCheckLetter;
import 'package:rcl_mobile/core/scan_link.dart';
import 'package:rcl_mobile/core/push.dart' show PushTap;
import 'package:rcl_mobile/screens/approvals.dart' show ApprovalsScreen;
import 'package:rcl_mobile/screens/call.dart' show CallPickScreen;
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/core/sheet_read.dart';
import 'package:rcl_mobile/main.dart';
import 'package:rcl_mobile/screens/label_scan.dart' show QrScanScreen;
import 'package:rcl_mobile/core/voice.dart' as voice;
import 'package:rcl_mobile/screens/assistant.dart' show AssistantScreen, forgetChat;
import 'package:rcl_mobile/screens/logbook.dart' show LogForm, LogBookScreen;
import 'package:rcl_mobile/core/attach.dart' show attCompute;
import 'package:rcl_mobile/screens/attach_box.dart' show pickAttFiles, CaptureScreen;
import 'package:image/image.dart' as img;
import 'package:rcl_mobile/screens/super_delete.dart' show SuperDeleteScreen;
import 'package:rcl_mobile/ui/help.dart' show helpPicked;
import 'package:rcl_mobile/ui/outputs.dart' show fileSink;
import 'package:rcl_mobile/ui/pick_file.dart';

import 'fake_rtc.dart';
import 'lock_test.dart' show FakeGate;
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
    expect(find.text('Welcome Back'), findsOneWidget);
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
    expect(find.text('Sujit'), findsOneWidget); // (3.31.0) "Good Morning, Sujit 👋"
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

  testWidgets('(3.21.1, Mechanical update-128) his rejected / returned entries: why, "Send again" one or all – with a remark, nothing typed again', (t) async {
    phone(t);
    final srv = FakeServer();
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> no(String id, String st, Map<String, dynamic> x) => {'kind': 'Flow', 'mine': true, 'id': id, 'm': 'Diesel Issue', 'task': 'Diesel Issue', 'status': st, 'at': now, 'decidedAt': now, 'decidedBy': 'suraj khandagale', 'levels': 1, 'canResend': true, 'summary': ['Add: MH-25-AJ-5091 · 05-10-2026 – Litres 100'], ...x};
    srv.flowReqs.addAll([
      no('VF-00011', 'Returned', {'note': 'approved', 'result': 'Not saved: KM reading 48409.3 is less than the last one (48500)'}),
      no('VF-00010', 'Rejected', {'note': 'wrong litres'}),
      no('VF-00009', 'Rejected', {'note': 'later'}),
    ]);
    final s = await ready(t, srv);
    await t.runAsync(() => s.loadApprovals());
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.text('Not saved 3'), findsOneWidget);
    await t.tap(find.byKey(const Key('verify-strip')));
    await settle(t, 800);
    expect(find.byKey(const Key('verify-why-VF-00011')), findsOneWidget, reason: 'why the save refused it');
    expect(find.text('Not saved: KM reading 48409.3 is less than the last one (48500)'), findsOneWidget);
    expect(find.text('suraj khandagale: wrong litres'), findsOneWidget, reason: 'the approver\'s reason');
    expect(find.text('Send all again (3)'), findsOneWidget);
    expect(find.byKey(const Key('verify-again-VF-00010')), findsOneWidget);
    // one: the box says why and asks a remark; without one: asked again
    await t.tap(find.byKey(const Key('verify-again-VF-00011')));
    await settle(t, 600);
    expect(find.text('Send VF-00011 again?'), findsOneWidget);
    expect(find.textContaining('exactly as it was sent'), findsOneWidget);
    await t.tap(find.byKey(const Key('note-ok')));
    await settle(t, 300);
    expect(find.text('Write why it is sent again.'), findsOneWidget);
    expect(srv.resent, isEmpty);
    await t.enterText(find.byKey(const Key('note-box')), 'Reading checked on the meter');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(srv.resent, [{'id': 'VF-00011', 'note': 'Reading checked on the meter'}]);
    expect(find.text('VF-00011 sent again for verification (level 1) – saved when approved.'), findsOneWidget);
    expect(find.text('Send all again (2)'), findsOneWidget);
    // all (one refused again by the save: told, it stays)
    srv.resendRefuse['VF-00009'] = 'MH-25-AJ-5091 is inactive from 01-10-2026';
    await t.tap(find.byKey(const Key('verify-again-all')));
    await settle(t, 600);
    expect(find.text('Send 2 entries again?'), findsOneWidget);
    await t.enterText(find.byKey(const Key('note-box')), 'Litres corrected by the pump man');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(srv.resent.last, {'ids': ['VF-00010', 'VF-00009'], 'note': 'Litres corrected by the pump man'});
    expect(find.textContaining('VF-00010 sent again for verification (level 1)'), findsOneWidget);
    expect(find.textContaining('Not sent: VF-00009 – Not sent again: MH-25-AJ-5091 is inactive'), findsOneWidget);
    expect(find.byKey(const Key('verify-again-VF-00009')), findsOneWidget, reason: 'nothing lost: it can be sent again later');
    expect(find.byKey(const Key('verify-again-VF-00010')), findsNothing);
  });

  testWidgets('(3.22.1, Mechanical update-131) a reading that does not fit is a mistake for approval: Send again says it in full – no "Send again anyway"; corrected first (Open & correct)', (t) async {
    phone(t);
    final srv = FakeServer();
    final now = DateTime.now().toUtc().toIso8601String();
    Finder tf(String k) => find.descendant(of: find.byKey(Key(k)), matching: find.byType(TextField));
    const why = 'Line 2: MH-25-AJ-2169: KM Reading 5150 is more than the later KM Reading 5120 (fill of 19-10-2026, Day).';
    srv.flowReqs.add({'kind': 'Flow', 'mine': true, 'id': 'VF-00011', 'm': 'Diesel Issue', 'task': 'Diesel Issue', 'status': 'Returned', 'at': now, 'decidedAt': now, 'decidedBy': 'suraj khandagale', 'levels': 1, 'canResend': true, 'canFix': true,
        'summary': ['Add: MH-25-AJ-2169 · 18-10-2026 – Litres 10 (+1)'], 'note': 'approved', 'result': 'Not saved: $why'});
    srv.resendRefuse['VF-00011'] = why;
    srv.fixOf['VF-00011'] = {
      'fn': 'saveDieselBulk',
      'form': 'date',
      'args': [
        {'date': '2026-10-14', 'shift': 'Day', 'source': 'Dispenser', 'force': false, 'rows': [
          {'no': 'MH-25-AJ-2169', 'qty': '10', 'kmReading': '5100', 'hrReading': '', 'driver': '', 'remark': '', 'mode': 'KM'},
          {'no': 'MH-25-AJ-2169', 'qty': '6', 'kmReading': '5150', 'hrReading': '', 'driver': '', 'remark': '', 'mode': 'KM'},
        ]},
      ],
      'check': {'ok': false, 'errors': [{'row': 2, 'msg': 'MH-25-AJ-2169: KM Reading 5150 is more than the later KM Reading 5120 (fill of 19-10-2026, Day).'}]},
    };
    srv.editRefuse['VF-00011'] = {'warnings': [{'row': 2, 'msg': 'MH-25-AJ-2169: KM Reading 5150 is more than the later KM Reading 5120 (fill of 19-10-2026, Day).'}]};
    final s = await ready(t, srv);
    await t.runAsync(() => s.loadApprovals());
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('verify-strip')));
    await settle(t, 800);
    // Send again: refused – said in full; nothing to confirm "anyway"
    await t.tap(find.byKey(const Key('verify-again-VF-00011')));
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('note-box')), 'please');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(srv.resent, [{'id': 'VF-00011', 'note': 'please'}], reason: 'no force');
    expect(find.textContaining('Not sent: VF-00011 – Not sent again: $why'), findsOneWidget);
    expect(find.text('Send again anyway'), findsNothing);
    expect(find.text('Please check – warnings, not mistakes'), findsNothing);
    // Open & correct: still not fitting → not sent, no "anyway"; corrected → sent
    await settle(t, 4500);
    await t.tap(find.byKey(const Key('verify-fix-VF-00011')));
    await net(t);
    await tapK(t, 'im-save');
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('note-box')), 'reading 5110');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(srv.edited.length, 1);
    expect(find.textContaining('Not sent. Correct the rows marked.'), findsOneWidget);
    expect(find.text('Save all anyway'), findsNothing);
    expect(find.text('Send again anyway'), findsNothing);
    srv.editRefuse.remove('VF-00011');
    await t.scrollUntilVisible(find.byKey(const Key('im-row-1-del')), 200, scrollable: find.descendant(of: find.byKey(const Key('im-list')), matching: find.byType(Scrollable)).first);
    await settle(t, 400);
    await t.enterText(tf('im-row-1-km'), '5110');
    await settle(t, 300);
    await tapK(t, 'im-save');
    await net(t);
    expect(srv.edited.length, 2);
    expect((((srv.edited.last['args'] as List).single as Map)['rows'] as List)[1]['kmReading'], '5110');
    expect(find.text('VF-00011 corrected and sent again for verification (level 1) – saved when approved.'), findsOneWidget);
  });

  testWidgets('(3.22.0, Mechanical update-130) Open & correct: his returned Multiple entries opens in its own form – why, the wrong row; corrected → sent again; one entry too; the approver sees what changed', (t) async {
    phone(t);
    final srv = FakeServer();
    final now = DateTime.now().toUtc().toIso8601String();
    Finder tf(String k) => find.descendant(of: find.byKey(Key(k)), matching: find.byType(TextField));
    String val(String k) => t.widget<TextField>(tf(k)).controller!.text;
    Map<String, dynamic> req(String id, String st, Map<String, dynamic> x) => {'kind': 'Flow', 'mine': true, 'id': id, 'm': 'Diesel Issue', 'task': 'Diesel Issue', 'status': st, 'at': now, 'decidedAt': now, 'decidedBy': 'suraj khandagale', 'levels': 1, 'canResend': true, 'canFix': true, 'summary': ['Add: MH-25-AJ-2169 · 14-10-2026 – Litres 10'], ...x};
    srv.flowReqs.addAll([
      req('VF-00006', 'Returned', {'note': 'approved', 'result': 'Not saved: Line 2: "KDX-130B" is not in Master.'}),
      req('VF-00007', 'Rejected', {'note': 'litres are 12'}),
    ]);
    srv.fixOf['VF-00006'] = {
      'fn': 'saveDieselBulk',
      'form': 'date',
      'args': [
        {'date': '2026-10-14', 'shift': 'Day', 'source': 'Dispenser', 'force': false, 'rows': [
          {'no': 'MH-25-AJ-2169', 'qty': '10', 'kmReading': '5100', 'hrReading': '', 'driver': 'Ravi', 'remark': '', 'mode': 'KM'},
          {'no': 'KDX-130B', 'qty': '6', 'kmReading': '', 'hrReading': '', 'driver': '', 'remark': '', 'mode': ''},
        ]},
      ],
      'check': {'ok': false, 'errors': [{'row': 2, 'msg': '"KDX-130B" is not in Master.'}]},
    };
    srv.fixOf['VF-00007'] = {
      'fn': 'saveDieselIssue',
      'form': 'one',
      'args': [{'date': '2026-10-14', 'shift': 'Day', 'source': 'Dispenser', 'no': 'MH-25-AJ-2169', 'qty': 10, 'kmReading': 5200, 'hrReading': '', 'driver': 'Ravi', 'remark': '', 'force': false, 'mode': 'KM', 'photos': [{'k': 'dash', 'p': 'x/dash.jpg'}]}],
      'check': {'ok': true},
    };
    srv.editRefuse['VF-00006'] = {'errors': [{'row': 2, 'msg': '"KDX-130B" is not in Master.'}]};
    final s = await ready(t, srv);
    await t.runAsync(() => s.loadApprovals());
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('verify-strip')));
    await settle(t, 800);
    expect(find.byKey(const Key('verify-fix-VF-00006')), findsOneWidget);
    expect(find.byKey(const Key('verify-again-VF-00006')), findsOneWidget, reason: '"Send again" stays');
    // Multiple entries: opens as it was sent – why, what is wrong now, the row marked
    await t.tap(find.byKey(const Key('verify-fix-VF-00006')));
    await net(t);
    expect(find.byKey(const Key('fix-bar')), findsOneWidget);
    expect(find.text('Correcting VF-00006 – Returned, not saved'), findsOneWidget);
    expect(find.text('Not saved: Line 2: "KDX-130B" is not in Master.'), findsOneWidget);
    expect(find.text('Now: the rows in red are wrong – correct them (the list is under the rows).'), findsOneWidget);
    expect(find.text('Send again (VF-00006)'), findsOneWidget);
    expect(find.byKey(const Key('im-type')), findsNothing, reason: 'its own form only');
    expect([val('im-row-0-qty'), val('im-row-0-km'), val('im-row-0-driver')], ['10', '5100', 'Ravi']);
    await t.scrollUntilVisible(find.byKey(const Key('im-row-1-del')), 200, scrollable: find.descendant(of: find.byKey(const Key('im-list')), matching: find.byType(Scrollable)).first);
    await settle(t, 400);
    expect(find.text('"KDX-130B" – not in Master: pick the machinery'), findsOneWidget);
    expect(find.text('"KDX-130B" is not in Master.'), findsOneWidget, reason: 'the row says why');
    expect(val('im-row-1-qty'), '6');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/52_fix_many.png'));
    // still wrong: the remark is asked once; the save's answer marks the row – nothing sent
    await tapK(t, 'im-save');
    await settle(t, 600);
    expect(find.text('Send VF-00006 again, corrected?'), findsOneWidget);
    await t.enterText(find.byKey(const Key('note-box')), 'KDX-130B was a typing mistake');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(srv.edited.length, 1);
    expect(((srv.edited.single['args'] as List).single as Map)['rows'][1]['no'], 'KDX-130B', reason: 'as it was sent – the save says why');
    expect(find.textContaining('Nothing saved. Fix the rows marked in red.'), findsOneWidget);
    // corrected: row 2 → MH-25-AJ-2169, its reading → sent again (the remark kept)
    srv.editRefuse.remove('VF-00006');
    await tapK(t, 'im-row-1-pick');
    await settle(t, 800);
    await t.tap(find.text('MH-25-AJ-2169').last);
    await settle(t, 600);
    await t.enterText(tf('im-row-1-km'), '5150');
    await settle(t, 300);
    await tapK(t, 'im-save');
    await net(t);
    expect(srv.edited.length, 2);
    expect(srv.edited.last['note'], 'KDX-130B was a typing mistake');
    expect(((srv.edited.last['args'] as List).single as Map)['rows'], [
      {'no': 'MH-25-AJ-2169', 'qty': '10', 'kmReading': '5100', 'hrReading': '', 'driver': 'Ravi', 'remark': '', 'mode': 'KM'},
      {'no': 'MH-25-AJ-2169', 'qty': '6', 'kmReading': '5150', 'hrReading': '', 'driver': '', 'remark': '', 'mode': 'KM'},
    ]);
    expect(find.text('VF-00006 corrected and sent again for verification (level 1) – saved when approved.'), findsOneWidget);
    expect(find.byKey(const Key('verify-fix-VF-00006')), findsNothing, reason: 'waiting again');
    // one entry: opens in the one-entry form as it was sent; litres corrected → sent
    await t.tap(find.byKey(const Key('verify-fix-VF-00007')));
    await net(t);
    expect(find.text('Correcting VF-00007 – Rejected, not saved'), findsOneWidget);
    expect(find.text('Rejected by suraj khandagale: litres are 12'), findsOneWidget);
    expect(find.text('Photos sent with it: 1 – they stay with it; a new photo of the same kind takes its place.'), findsOneWidget);
    final litres = find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '10');
    expect(litres, findsOneWidget);
    await t.enterText(litres, '12');
    await settle(t, 300);
    await t.ensureVisible(find.text('Send again (VF-00007)'));
    await t.tap(find.text('Send again (VF-00007)'));
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('note-box')), 'Litres 12');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    final one = (srv.edited.last['args'] as List).single as Map;
    expect([srv.edited.last['id'], one['qty'], one['kmReading'], one['no'], one['mode'], one.containsKey('photos')], ['VF-00007', 12, 5200, 'MH-25-AJ-2169', 'KM', false], reason: 'the photos sent with it stay on the server');
    expect(find.text('VF-00007 corrected and sent again for verification (level 1) – saved when approved.'), findsOneWidget);
    // the approver's Approvals: what was corrected
    await t.tap(find.text('Open Approvals'));
    await net(t);
    expect(find.byKey(const Key('cr-fixed-VF-00006')), findsOneWidget);
    expect(find.text('Corrected by Mahesh Jadhav: KDX-130B was a typing mistake'), findsOneWidget);
    expect(find.text('• Row 2 – Machinery: KDX-130B → KDX-130'), findsWidgets);
  }, tags: ['golden']);

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

  testWidgets('(3.31.5, update-147) Approvals: "Details" – the entry in full under its card; "Details of all"; several ticked – each in full before the decision', (t) async {
    // a phone's width, a long screen: every card stays built while the details open (a list builds only what is near the screen)
    t.view.physicalSize = const Size(1080, 9000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final srv = FakeServer()..crForMe = 2;
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> req(String id, String what) => {'kind': 'Flow', 'mine': false, 'id': id, 'm': 'Diesel Issue', 'task': 'Diesel Issue', 'status': 'Pending', 'at': now, 'waitSince': now, 'by': 'Mahesh Jadhav', 'waitingFor': ['Sujit Mule'], 'level': 1, 'levels': 1, 'canDecide': true, 'summary': [what],
          'history': [{'step': 'Sent', 'by': 'Mahesh Jadhav', 'at': now}]};
    srv.flowReqs.addAll([req('VF-00011', 'Add: MH-25-AJ-2169 · 16-10-2026 · Day: Litres 60'), req('VF-00012', 'Add: Sany 210 (No.1) · 16-10-2026 · Night: Litres 30')]);
    srv.flowDetails['VF-00011'] = {'id': 'VF-00011', 'kind': 'Flow', 'task': 'Diesel Issue', 'action': 'New diesel issue – one entry', 'by': 'Mahesh Jadhav', 'at': now, 'status': 'Pending',
      'fields': [['Machinery', 'MH-25-AJ-2169 – Tipper · Tipper'], ['Litres', '60'], ['KM reading', '48409'], ['Driver', 'Ramesh Pawar'], ['Remark', 'night trip'], ['Date', '16-10-2026'], ['Shift', 'Day'], ['Diesel source', 'Dispenser']], 'tables': [], 'photos': 2, 'savedNow': [],
      'pics': [{'label': 'Dashboard', 'url': 'https://photos.test/a.jpg'}, {'label': 'Dispenser litres', 'url': ''}]};      // (3.31.6) the pictures
    srv.flowDetails['VF-00012'] = {'id': 'VF-00012', 'kind': 'Flow', 'task': 'Diesel Issue', 'action': 'New diesel issue – multiple entries', 'by': 'Mahesh Jadhav', 'at': now, 'status': 'Pending',
      'fields': [['Date', '16-10-2026'], ['Shift', 'Night'], ['Diesel source', 'Dispenser']],
      'tables': [{'title': 'Rows', 'cols': ['#', 'Machinery', 'Litres', 'KM reading', 'Driver'], 'rows': [['1', 'Sany 210 (No.1) – Excavator', '30', '', 'Suresh Kale'], ['2', 'JCB-07 – Backhoe', '25', '5260', '']], 'more': 0}], 'photos': 0, 'savedNow': []};
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Me'));
    await net(t);
    await t.ensureVisible(find.text('Approvals').first);
    await settle(t, 300);
    await t.tap(find.text('Approvals').first);
    await net(t);
    expect(find.byKey(const Key('det-VF-00011')), findsOneWidget, reason: 'every request has its Details');
    expect(find.text('Ramesh Pawar'), findsNothing, reason: 'closed at first');
    await tapK(t, 'det-VF-00011');
    await net(t);
    expect(srv.detAsked.last, ['VF-00011']);
    expect(find.text('Ramesh Pawar'), findsOneWidget);
    expect(find.text('MH-25-AJ-2169 – Tipper · Tipper'), findsOneWidget);
    expect(find.text('Hide details'), findsOneWidget);
    // (3.31.6, update-148) its photos: the pictures, named – never a list of file names
    expect(find.byKey(const Key('det-pic-VF-00011-0')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('det-pic-VF-00011-0')), matching: find.text('Dashboard')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('det-pic-VF-00011-1')), matching: find.text('The picture was not found.')), findsOneWidget);
    // closed again – and opened again: not asked again (the same version of the request)
    await tapK(t, 'det-VF-00011');
    await settle(t, 400);
    expect(find.text('Ramesh Pawar'), findsNothing);
    await tapK(t, 'det-VF-00011');
    await net(t);
    expect(srv.detAsked.length, 1, reason: 'kept, not asked again');
    // Details of all: the Multiple entries as a table
    await tapK(t, 'det-all');
    await net(t);
    expect(srv.detAsked.last, ['VF-00012']);
    expect(find.text('Suresh Kale'), findsOneWidget);
    expect(find.text('JCB-07 – Backhoe'), findsOneWidget);
    expect(find.text('Hide all details'), findsOneWidget);
    // several ticked: each one in full in the question
    await tapK(t, 'tick-VF-00011');
    await tapK(t, 'tick-VF-00012');
    await settle(t, 300);
    await tapK(t, 'bulk-ok');
    await net(t);
    expect(find.byKey(const Key('bulk-det-VF-00011')), findsOneWidget);
    expect(find.byKey(const Key('bulk-det-VF-00012')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('bulk-det-VF-00012')), matching: find.text('Suresh Kale')), findsOneWidget);
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(srv.decided.last['ids'], ['VF-00011', 'VF-00012']);
    expect(srv.decided.last['approve'], true);
  });

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
    await t.tap(find.byKey(const Key('rt-diesel'))); // (3.31.0) the reports are under Diesel (Overview first)
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
    await t.tap(find.byKey(const Key('rt-diesel'))); // (3.31.0) the reports are under Diesel (Overview first)
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

  testWidgets('(3.29.0, update-139) A machinery measured by KM and Hrs: a 5th photo, the Hour meter; one with one reading: the 4 photos', (t) async {
    phone(t);
    final srv = FakeServer();
    srv.master.add({'id': 'MH-46-TM-1001', 'no': 'MH-46-TM-1001', 'name': 'Transit Mixer', 'type': 'Transit Mixer', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company', 'status': 'Active',
      'modes': ['KM', 'Hrs', 'KM + Hrs'], 'modesX': [], 'meterKm': true, 'meterHr': true, 'worksOn': ['KM', 'Hrs'], 'unit': 'KM + Hrs', 'kmStd': 3, 'hrStd': 4, 'activeFrom': '2026-09-01', 'inactiveFrom': ''});
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await t.tap(find.text('New Entry'));
    await net(t);
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    await t.tap(find.text('MH-46-TM-1001'));
    await settle(t, 800);
    expect(find.text('KM + Hrs · Asset Master'), findsOneWidget);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -900));
    await settle(t, 500);
    for (final k in ['dash', 'hrs', 'veh', 'pump', 'reg']) {
      expect(find.byKey(Key('photo-$k')), findsOneWidget, reason: k);
    }
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 1400));
    await settle(t, 500);
    await t.tap(find.text('MH-46-TM-1001').first);
    await settle(t, 800);
    await t.tap(find.text('Sany 210 (No.1)'));
    await settle(t, 800);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -900));
    await settle(t, 500);
    expect(find.byKey(const Key('photo-dash')), findsOneWidget);
    expect(find.byKey(const Key('photo-hrs')), findsNothing, reason: 'measured by Hrs only: its hour meter is the dashboard photo');
  });

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

  testWidgets('(Mechanical update-145) a Diesel Issue opened for a change sends back the version it had when it was opened', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Diesel Issue'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await t.tap(find.text('MH-25-AJ-2169').first);      // (a machinery of this site's Master: the form can be saved)
    await settle(t, 800);
    await t.tap(find.text('Change'));
    await net(t);
    await t.ensureVisible(find.text('Save the change'));
    await settle(t, 600);
    await t.tap(find.text('Save the change'));
    await net(t);
    expect(srv.saved.last['update'], 'DI-000520');
    expect(srv.saved.last['ver'], 'v520', reason: 'changed by someone else since it was opened → the server refuses it');
  });

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
    expect(find.text('Super Admin'), findsNothing, reason: '(3.17.0) the console is the Super Admin\'s only');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9_me.png'));
    await t.tap(find.text('Reports'));
    await net(t);
    await t.tap(find.byKey(const Key('rt-diesel')));
    await net(t);
    expect(find.text('Monthly Diesel Issue'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.20.1) no network when the app opens: "No connection – you are still signed in", Try again – never the sign-in', (t) async {
    phone(t);
    final srv = FakeServer()
      ..portalSignedIn = true
      ..portalDown = true;
    final keep = MemoryKeep()..data['portal_cookie'] = 'rcl_portal=abc123';
    final s = Session(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client))
      ..retryEvery = const Duration(hours: 1)
      ..clock = (() => DateTime(2026, 10, 14, 10, 30));
    await t.runAsync(s.start);
    await t.pumpWidget(RclApp(session: s));
    await settle(t);
    expect(s.stage, Stage.waiting);
    expect(find.byKey(const Key('wait-title')), findsOneWidget);
    expect(find.textContaining('You are still signed in'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing, reason: 'not the sign-in screen');
    await pics(t);
    await t.pump(const Duration(milliseconds: 400)); // (3.39.0) the road photo comes in softly (260 ms)
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/0_no_network.png'));
    srv.portalDown = false;
    await t.tap(find.byKey(const Key('wait-again')));
    await net(t);
    expect(s.stage, Stage.pickSite, reason: 'the network is back: his sites, nothing typed');
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
    final op = t.widget<Opacity>(find.ancestor(of: find.text('Fleet & Diesel Management'), matching: find.byType(Opacity)).first);
    expect(op.opacity, 1);
  });

  testWidgets('Log Book (native): the day\'s entries, the machinery still without one; a new entry – Start from the last one, Close typed – saved', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook').last); // (3.31.0) the module (the tile of today's entries is Logbook too)
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

  testWidgets('(3.31.2 – update-143) a shift already saved: the new entry is added to it as its next work – said on the form, Start at its Close, no ½ day; saved', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms['Log Book'] = 'Edit'
      ..addTo = {'rows': 1, 'kind': 'hr', 'mode': 'Hrs', 'closeKm': '', 'closeHr': 4712, 'stock': 40, 'lastWork': '', 'sameOk': true};
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook').last);
    await net(t);
    await t.tap(find.text('New Entry'));
    await net(t);
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    await t.tap(find.text('Sany 210 (No.1)'));
    await net(t);
    expect(find.textContaining('is already saved – this entry is added to it as work 2'), findsOneWidget);
    expect(find.textContaining('already on the saved entry'), findsOneWidget, reason: 'the diesel of the shift is on the saved entry');
    expect((t.widget<TextField>(find.widgetWithText(TextField, 'Start')).controller!).text, '4712', reason: 'it starts at the saved Close');
    expect(t.widget<FilterChip>(find.widgetWithText(FilterChip, '½ day')).onSelected, isNull, reason: 'the ½ day stays on the saved entry');
    await t.enterText(find.widgetWithText(TextField, 'Close'), '4715');
    await settle(t, 300);
    await t.tap(find.text('Save Log Book'));
    await net(t);
    final row = srv.logSaved.single;
    expect([row['no'], row['mode'], row['openingHr'], row['closingHr'], row['half'], row['add']], ['Sany 210 (No.1)', 'Hrs', 4712, 4715, false, 1], reason: 'marked "add": the server adds it to the saved entry');
    expect(find.text('Added to the entry already saved for this shift'), findsOneWidget);
  });

  testWidgets('Log Book: a water tanker\'s entry is a card per trip (Trip 1, Trip 2), each with Change / Delete; Change opens that trip on the tanker screen', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms['Log Book'] = 'Edit'
      ..tanker = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook').last); // (3.31.0) the module (the tile of today's entries is Logbook too)
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

  testWidgets('(3.23.0, Mechanical update-132) Vendor BOQ: the rate history machinery-wise – which rate from which date, which amendment changed it', (t) async {
    phone(t);
    final srv = editor();
    Map<String, dynamic> per(String from, String to, int amendNo, num rate) => {'from': from, 'to': to, 'boq': amendNo > 0 ? 'BOQ-0002' : 'BOQ-0001', 'boqNo': amendNo > 0 ? '2' : '1', 'amendNo': amendNo, 'of': amendNo > 0 ? '1' : '',
          'line': {'no': 'MH-25-AJ-2169', 'basis': 'Monthly', 'rate': rate, 'diesel': 'Company'}, 'woNo': 'WO-12'};
    srv.boqHist.add({'vendor': 'I E Enterprises', 'no': 'MH-25-AJ-2169', 'periods': [per('2026-09-01', '2026-09-30', 0, 45000), per('2026-10-01', '', 1, 50000)]});
    final s = await ready(t, srv);
    await openMaster(t, s, 'Vendor BOQ');
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.byKey(const Key('bh-pick')), 200, scrollable: list);
    expect(find.text('Pick a vendor to see the rate history of each machinery – which rate from which date, and which amendment changed it.'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('bf-vendor')), -200, scrollable: list);
    await tapK(t, 'bf-vendor');
    await settle(t, 400);
    await t.tap(find.text('I E Enterprises').last);
    await settle(t, 600);
    await t.scrollUntilVisible(find.byKey(const Key('bh-MH-25-AJ-2169-1')), 200, scrollable: list);
    await settle(t, 300);
    expect(find.text('Rate history – machinery-wise'), findsOneWidget);
    expect(find.text('01-09-2026 – 30-09-2026'), findsOneWidget);
    expect(find.text('BOQ 1 – Original · WO WO-12'), findsOneWidget);
    expect(find.text('First rate'), findsOneWidget);
    expect(find.text('01-10-2026 – open'), findsOneWidget);
    expect(find.text('Amendment 1 of BOQ 1 · WO WO-12'), findsOneWidget);
    expect(find.textContaining('Changed – was Monthly ₹45,000'), findsOneWidget);
    expect(find.textContaining('Monthly ₹50,000'), findsWidgets);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/53_boq_history.png'));
  }, tags: ['golden']);

  testWidgets('(3.25.0, Mechanical update-134) Diesel Issue ⋮ → Delete entries – Super Admin: a date → saved and waiting ticked → deleted (kept); one of a submitted bill cannot be ticked; Deleted entries → a refusal said, then brought back', (t) async {
    phone(t);
    final srv = FakeServer()..superAdmin = true;
    srv.sdSaved.addAll([
      {'id': 'DI-000101', 'date': '2026-10-14', 'shift': 'Day', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'qty': 10, 'kmReading': 5100, 'hrReading': '', 'source': 'Dispenser', 'by': 'Mahesh Jadhav', 'bill': '', 'closed': false},
      {'id': 'DI-000102', 'date': '2026-10-14', 'shift': 'Day', 'no': 'SANY-210', 'type': 'Excavator', 'qty': 40, 'kmReading': '', 'hrReading': 1220, 'source': 'Dispenser', 'by': 'Sujit Mule', 'bill': 'RA-7', 'closed': false},
    ]);
    srv.sdWaiting.add({'id': 'VF-00009', 'status': 'Pending', 'label': 'Waiting for verification', 'what': 'Save Diesel Bulk', 'dates': ['2026-10-14'], 'nos': 'MH-25-AJ-2169', 'qty': 5, 'by': 'Mahesh Jadhav',
      'at': '2026-10-14T04:30:00.000Z', 'lines': ['Add: MH-25-AJ-2169 · 14-10-2026, Day – Litres 5, KM reading 5150'], 'more': 0});
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await t.tap(find.byKey(const Key('en-more')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('en-sdel')));
    await net(t);
    expect(find.text('Delete entries – Super Admin'), findsOneWidget);
    await tapK(t, 'sd-show');
    await net(t);
    expect(srv.sdAsked.last, {'fn': 'superDelList', 'from': '2026-10-14', 'to': '', 'by': '', 'no': ''});
    expect(find.text('Saved entries (2)'), findsOneWidget);
    expect(find.text('Waiting for verification, returned or rejected (1)'), findsOneWidget);
    expect(find.text('In the submitted RA Bill RA-7 – delete that bill first'), findsOneWidget);
    expect(t.widget<CheckboxListTile>(find.byKey(const Key('sd-s-DI-000102'))).onChanged, isNull, reason: 'an entry of a submitted bill cannot be ticked');
    await tapK(t, 'sd-s-DI-000101');
    await tapK(t, 'sd-f-VF-00009');
    await settle(t, 300);
    expect(find.text('Delete ticked (2)'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('sd-show')));
    await settle(t, 300);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/54_super_delete.png'));
    await tapK(t, 'sd-delete');
    await settle(t, 600);
    expect(find.text('Delete 2 entries?'), findsOneWidget);
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await net(t);
    final del = srv.sdAsked.firstWhere((x) => x['fn'] == 'superDelete');
    expect(del['ids'], ['DI-000101']);
    expect(del['flows'], ['VF-00009']);
    expect(find.text('Saved entries (1)'), findsOneWidget);
    expect(find.text('Deleted entries (2)'), findsOneWidget);
    ScaffoldMessenger.of(t.element(find.byType(SuperDeleteScreen))).hideCurrentSnackBar();      // (the "deleted" message would lie over the list)
    await settle(t, 600);
    // brought back: one the server refuses → said, nothing back; then brought back
    srv.sdRefuse['DEL-00001'] = 'DI-000101 (MH-25-AJ-2169, 14-10-2026): that date is now in the submitted RA Bill RA-8 of I E Enterprises – it is not brought back into a submitted bill.';
    await tapK(t, 'sd-d-DEL-00001');
    await tapK(t, 'sd-back');
    await settle(t, 600);
    expect(find.text('Bring back 1 entry?'), findsOneWidget);
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await net(t);
    expect(find.text('Nothing brought back'), findsOneWidget);
    expect(find.textContaining('it is not brought back into a submitted bill'), findsOneWidget);
    await t.tap(find.byKey(const Key('tell-ok')));
    await settle(t, 400);
    srv.sdRefuse.clear();
    await tapK(t, 'sd-back');
    await settle(t, 600);
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await net(t);
    expect(srv.sdAsked.where((x) => x['fn'] == 'superRestore').last['ids'], ['DEL-00001']);
    expect(find.text('Deleted entries (1)'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.25.0) Delete entries – Super Admin is not in the menu of anybody else', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await t.tap(find.byKey(const Key('en-more')));
    await settle(t, 600);
    expect(find.byKey(const Key('en-find')), findsOneWidget);
    expect(find.byKey(const Key('en-sdel')), findsNothing);
  });

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
    await t.tap(find.byKey(const Key('rt-diesel'))); // (3.31.0) the reports are under Diesel (Overview first)
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
    // (3.21.0, Mechanical update-126) a number → the entries behind it, in a big sheet – only shown
    await t.tap(find.byKey(const Key('k-out')));
    await net(t);
    expect(find.byKey(const Key('num-sheet')), findsOneWidget);
    expect(srv.listAsked.last, {'fn': 'getDieselIssues', 'from': '2026-10-14', 'to': '2026-10-14'}, reason: 'the Dashboard\'s dates');
    expect(find.descendant(of: find.byKey(const Key('num-sheet')), matching: find.text('Issued to machinery')), findsOneWidget);
    expect(find.byKey(const Key('num-big')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('num-sheet')), matching: find.byType(TextField)), findsNothing, reason: 'only shown');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/24b_dashboard_entries.png'));
    await t.tap(find.descendant(of: find.byKey(const Key('num-sheet')), matching: find.byTooltip('Close')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('k-open')));
    await net(t);
    expect(find.descendant(of: find.byKey(const Key('num-sheet')), matching: find.text('Dispenser')), findsWidgets);
    expect(find.descendant(of: find.byKey(const Key('num-sheet')), matching: find.text('19,895 Ltr')), findsOneWidget, reason: 'the sheet\'s number is the card\'s');
    await t.tap(find.descendant(of: find.byKey(const Key('num-sheet')), matching: find.byTooltip('Close')));
    await settle(t, 600);
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
    await t.tap(find.byKey(const Key('rt-diesel'))); // (3.31.0) the reports are under Diesel (Overview first)
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
    await t.tap(find.text('Logbook').last); // (3.31.0) the module (the tile of today's entries is Logbook too)
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
    await t.tap(find.text('Logbook').last); // (3.31.0) the module (the tile of today's entries is Logbook too)
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
    await t.tap(find.text('Logbook').last); // (3.31.0) the module (the tile of today's entries is Logbook too)
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
    // (3.19.1, Mechanical update-123: the opening film is gone) Company & site: nothing about a film to set; what the server
    // keeps for it goes back unchanged
    s.org = {'customer': 'Rachana Construction Limited', 'site': 'VTR Site – NH 848', 'billNames': ['Rachana Construction Limited'], 'video': 'https://film.test/f.mp4', 'intro': false};
    await tapK(t, 'ad-Company & site');
    await net(t);
    expect(find.byKey(const Key('org-customer')), findsOneWidget);
    expect(find.byKey(const Key('org-video')), findsNothing);
    expect(find.byKey(const Key('org-intro')), findsNothing);
    expect(find.text('Play the opening when the app is opened'), findsNothing);
    await tapK(t, 'org-save');
    await net(t);
    final org = srv.adminSent.last['x'] as Map;
    expect([srv.adminSent.last['fn'], org['customer'], org['billNames'], org['video'], org['intro']], ['saveOrgSettings', 'Rachana Construction Limited', ['Rachana Construction Limited'], 'https://film.test/f.mp4', false]);
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

  /// A widget of a long list brought into the list first (a list builds only what is near the screen).
  Future<void> reach(WidgetTester t, String key, String list) async {
    final f = find.byKey(Key(key));
    final sc = find.descendant(of: find.byKey(Key(list)), matching: find.byType(Scrollable)).first;
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 200);
    if (f.evaluate().isEmpty) {
      await t.drag(sc, const Offset(0, 3000));
      await settle(t, 400);
      if (f.evaluate().isEmpty) await t.scrollUntilVisible(f, 250, scrollable: sc);
    }
    await settle(t, 300);
  }

  Future<void> more(WidgetTester t, String item) async {
    await t.tap(find.byKey(const Key('en-more')));
    await settle(t, 600);
    await t.tap(find.byKey(Key(item)));
    await net(t);
  }

  // (3.31.7, Mechanical update-149) the Log Book Debit Statement: the statement, Change rates (one / all shown), Import party + rate
  Future<void> openLdebit(WidgetTester t) async {
    await t.tap(find.text('Reports').last);
    await net(t);
    await t.tap(find.byKey(const Key('rt-financial')));
    await net(t);
    await t.scrollUntilVisible(find.text('Log Book Debit Statement'), 300, scrollable: find.ancestor(of: find.text('Debit Recovery Statement'), matching: find.byType(Scrollable)).first);
    await settle(t, 300);
    await t.tap(find.text('Log Book Debit Statement'));
    await net(t);
  }

  testWidgets('(3.31.7) Log Book Debit Statement: a party / one machinery (blank = all), the statement; Change rates – one, or one for all shown; Import party + rate → saveLogDebits', (t) async {
    phone(t);
    final srv = FakeServer();
    srv.perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await openLdebit(t);
    expect(find.byKey(const Key('rep-party')), findsOneWidget);
    await tapK(t, 'rep-go');
    await net(t);
    expect(srv.reportAsked.single['fn'], 'rptLogDebit');
    expect(srv.reportAsked.single['party'], '', reason: 'blank = all parties');
    expect(srv.reportAsked.single['no'], '', reason: 'blank = all machinery');
    expect(find.byKey(const Key('rtable-Summary')), findsOneWidget);
    expect(find.byKey(const Key('rtable-Details')), findsOneWidget);
    // one rate changed, then one rate for all shown (the entry in a Debit Note is not there)
    await tapK(t, 'ldebit-rates');
    await net(t);
    expect(find.byKey(const Key('ld-rate-2')), findsOneWidget);
    expect(find.byKey(const Key('ld-rate-3')), findsNothing, reason: 'the entry in RCL/VTR/DN-001 keeps its rate');
    await t.enterText(find.byKey(const Key('ld-rate-0')), '60');
    await settle(t, 300);
    expect(find.text('Save changed rates (1)'), findsOneWidget);
    expect(find.text('58 KM × ₹60.00 = ₹3,480.00'), findsOneWidget);
    await t.enterText(find.byKey(const Key('ld-all')), '1200');
    await tapK(t, 'ld-apply');
    await settle(t, 300);
    expect(find.text('Save changed rates (3)'), findsOneWidget);
    await tapK(t, 'ld-save');
    await net(t);
    expect(find.text('Save 3 changed rates?'), findsOneWidget);
    expect(find.textContaining('MH-25-LD-2169 · 15-10-2026 · Day: ₹55.00 → ₹1,200.00'), findsOneWidget);
    await tapK(t, 'ask-yes');
    await net(t);
    expect(srv.ldSaved.single, {
      'rows': [
        {'logId': 'MH-25-LD-2169|2026-10-15|Day', 'rate': 1200},
        {'logId': 'MH-25-LD-0210|2026-10-14|Day', 'rate': 1200},
        {'logId': 'MH-25-LD-0210|2026-10-14|Night', 'rate': 1200},
      ],
      'from': 'report',
    });
    expect(srv.reportAsked.length, 2, reason: 'the statement made again');
    // the party and rate of saved entries from a file: a blank "Debit to" keeps its party
    pickThis('debit_to.csv', utf8.encode('Date,Shift,Machinery,Debit to,Rate\n15-10-2026,Day,MH-25-LD-2169,I E Enterprises,"1,050"\n14-10-2026,,MH-25-LD-0210,,60\n'));
    await tapK(t, 'ldebit-import');
    await net(t);
    expect(find.text('Import 2 lines – party and rate?'), findsOneWidget);
    expect(find.textContaining('Row 2: MH-25-LD-2169 · 15-10-2026 · Day → I E Enterprises @ ₹1050'), findsOneWidget);
    expect(find.textContaining('Row 3: MH-25-LD-0210 · 14-10-2026 → (its party) @ ₹60'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/63_ldebit_import.png'));
    await tapK(t, 'ask-yes');
    await net(t);
    expect(srv.ldSaved.last, {
      'rows': [
        {'line': '2', 'date': '2026-10-15', 'shift': 'Day', 'no': 'MH-25-LD-2169', 'to': 'I E Enterprises', 'rate': '1050'},
        {'line': '3', 'date': '2026-10-14', 'shift': '', 'no': 'MH-25-LD-0210', 'rate': '60'},
      ],
      'from': 'import',
    });
  }, tags: ['golden']);

  testWidgets('(3.31.7) Log Book Debit Statement with Log Book View access: the statement, no Change rates / Import', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await openLdebit(t);
    await tapK(t, 'rep-go');
    await net(t);
    expect(find.byKey(const Key('rtable-Summary')), findsOneWidget);
    expect(find.byKey(const Key('ldebit-rates')), findsNothing);
    expect(find.byKey(const Key('ldebit-import')), findsNothing);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/64_ldebit_statement.png'));
  }, tags: ['golden']);

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
    await reach(t, 'ef-share', 'ef-list');
    await tapK(t, 'ef-share');
    await settle(t, 500);
    await reach(t, 'ef-sh-3', 'ef-list');
    expect(find.text('Sany 210 (No.1)'), findsWidgets);
    expect(find.text('80 Ltr · 33.33%'), findsWidgets);
    await reach(t, 'ef-export', 'ef-list');
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
    await reach(t, 'im-t-mach', 'im-list');
    await tapK(t, 'im-t-mach');
    await settle(t, 500);
    await reach(t, 'im-mach', 'im-list');
    await tapK(t, 'im-mach');
    await settle(t, 800);
    await t.tap(find.text('MH-25-AJ-2169').last);
    await settle(t, 600);
    await reach(t, 'im-mrow-0-date', 'im-list');
    await tapK(t, 'im-mrow-0-date');
    await settle(t, 600);
    await t.tap(find.text('13').last);
    await settle(t, 300);
    await t.tap(find.text('OK'));
    await settle(t, 600);
    await reach(t, 'im-mrow-0-qty', 'im-list');
    await t.enterText(box('im-mrow-0-qty'), '50');
    await reach(t, 'im-mrow-0-km', 'im-list');
    await t.enterText(box('im-mrow-0-km'), '15130');
    await reach(t, 'im-madd', 'im-list');
    await tapK(t, 'im-madd');
    await net(t);
    await reach(t, 'im-mrow-1-qty', 'im-list');
    await t.enterText(box('im-mrow-1-qty'), '40');
    await reach(t, 'im-mrow-1-km', 'im-list');
    await t.enterText(box('im-mrow-1-km'), '15200');
    await settle(t, 300);
    expect(find.text('Rows: 2  Diesel: 90 Ltr'), findsOneWidget);
    await reach(t, 'im-madd', 'im-list');
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

  testWidgets('(3.12.0) Log Book ⋮: All dates – the web\'s filter, the totals, the period total; Export date-wise read back; Import from Excel – a changed entry overwritten', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Log Book'] = 'Edit'; // Import from Excel and the templates: Edit only, as on the web
    final s = await ready(t, srv);
    final files = catchFiles();
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Log Book')));
    await net(t);
    await t.tap(find.byKey(const Key('lb-menu')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('lb-find')));
    await net(t);
    expect(srv.listAsked.last, {'fn': 'getLogBookList', 'from': '2026-10-13', 'to': '2026-10-14', 'no': '', 'shift': '', 'ownership': '', 'type': '', 'owner': '', 'q': ''},
        reason: 'the last 2 days, as the web opens its list');
    expect(find.text('Entries: 3   Machinery: 2   KM: 260   Hrs: 8   Issued: 140 L   Consumed: 186.29 L'), findsOneWidget);
    expect(find.textContaining('Period total – machinery-wise (13-10-2026 to 14-10-2026)'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/37_log_find.png'));
    await reach(t, 'lf-exp-date', 'lf-list');
    await tapK(t, 'lf-exp-date');
    await net(t);
    expect(srv.listAsked.last['all'], true);
    expect(srv.listAsked.last['own'], '');
    expect(files.last.$1, 'Log Book date-wise 13-10-2026 to 14-10-2026.xlsx');
    final tab = readSheets(files.last.$2).single;
    expect(tab.name, 'Date-wise');
    expect(tab.rows[2].first, 'Log Book – date-wise – 13-10-2026 to 14-10-2026');
    expect(tab.rows[4].take(5), ['Date', 'Shift', 'Machinery', 'Type', 'Measured by']);
    expect(tab.rows[5].take(5), ['13-10-2026', 'Full Day', 'MH-25-AJ-2169', 'Tipper', 'KM']);
    expect(tab.rows[6].take(3), ['13-10-2026', 'Full Day', 'Sany 210 (No.1)'], reason: 'a date without its entry: blank to fill');
    expect(tab.rows.last.first, 'Total – 3 entries');
    expect(find.text('4 Log Book rows exported.'), findsOneWidget);
    await t.pageBack();
    await net(t);
    // Import from Excel: a blank row left out; the server says one entry is already there, different – overwrite
    pickThis('log.csv', utf8.encode('Date,Shift,Machinery,Measured by,Close KM,Close Hrs,Work Done\n13-10-2026,Full Day,MH-25-AJ-2169,km,15100,,Carting\n14-10-2026,,sany 210 (no.1),,,4712,Excavation\n15-10-2026,,MH-25-AJ-2169,,,,\n'));
    await t.tap(find.byKey(const Key('lb-menu')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('lb-import')));
    await net(t);
    expect(find.text('Import into the Log Book'), findsOneWidget);
    expect(find.byKey(const Key('li-row-1')), findsOneWidget);
    await tapK(t, 'li-go');
    await net(t);
    expect(find.text('1 entry is already in the Log Book – but different'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    expect(find.text('Import into the Log Book?'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    final chk = srv.importSent.firstWhere((x) => x['fn'] == 'checkLogImport')['x'] as Map;
    expect((chk['rows'] as List).first, {
      'line': '2', 'date': '2026-10-13', 'shift': 'Full Day', 'no': 'MH-25-AJ-2169', 'unit': 'KM', 'mode': 'KM', 'tStart': '', 'tEnd': '', 'tBreak': '', 'trip': '', 'challan': '',
      'openingKm': '', 'closingKm': 15100, 'openingHr': '', 'closingHr': '', 'openingDiesel': '', 'chFrom': '', 'chTo': '', 'work': 'Carting', 'driver': '', 'remark': '', 'debitTo': '', 'debitRate': '', 'needWork': false,
    });
    final imp = srv.importSent.lastWhere((x) => x['fn'] == 'importLogBook')['x'] as Map;
    expect(imp['overwrite'], true);
    expect([for (final r in imp['rows'] as List) (r as Map)['no']], ['MH-25-AJ-2169', 'Sany 210 (No.1)']);
    expect(find.text('Log Book: 1 added, 1 overwritten, 0 skipped.'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.13.0) Asset Master ⋮: QR labels – all on site or one; Import from Excel – a mistake listed, then checked, asked and saved (importMaster)', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Asset Master');
    await t.tap(find.byKey(const Key('m-menu')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('m-qr')));
    await settle(t, 800);
    // (3.31.8, update-150) by owner, or the machinery ticked – one or many; 8 on an A4 page
    expect(find.text('2 ticked – 1 page'), findsOneWidget, reason: 'the machinery on site today (OLD-9 left), all ticked');
    expect(find.byKey(const Key('qr-MH-25-AJ-2169')), findsOneWidget);
    expect(find.byKey(const Key('qr-OLD-9')), findsNothing);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/39_qr_labels.png'));
    await t.tap(find.byKey(const Key('qr-owner')));
    await settle(t, 600);
    await t.tap(find.text('I E Enterprises (1)').last);
    await settle(t, 600);
    expect(find.text('1 ticked – 1 page'), findsOneWidget, reason: 'an owner: all its machinery ticked');
    expect(find.byKey(const Key('qr-Sany 210 (No.1)')), findsNothing);
    await t.tap(find.byKey(const Key('qr-untick')));
    await settle(t, 300);
    expect(find.text('Nothing ticked'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const Key('qr-make'))).onPressed, isNull, reason: 'nothing to make');
    await t.tap(find.byKey(const Key('qr-MH-25-AJ-2169')));
    await settle(t, 300);
    expect(find.text('1 ticked – 1 page'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const Key('qr-make'))).onPressed, isNotNull);
    Navigator.of(t.element(find.byKey(const Key('qr-make')))).pop();
    await settle(t, 600);
    // a mistake in the file: nothing imported, the rows listed
    pickThis('master.csv', utf8.encode('Machinery Number,Machinery Name,Type of Machinery\n,BAD,\n'));
    await t.tap(find.byKey(const Key('m-menu')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('m-import')));
    await net(t);
    expect(find.text('Nothing imported'), findsOneWidget);
    expect(find.text('• Excel row 2: Type of Machinery is required.'), findsOneWidget);
    await t.tap(find.byKey(const Key('tell-ok')));
    await settle(t, 400);
    pickThis('master.csv', utf8.encode('Notes\nMachinery Number,Machinery Name,Type of Machinery,Standard Average (KM/Ltr),PUC Valid Upto\nMH-25-AJ-2169,,Tipper,3.6,n/a\n,Roller 1,Roller,,30-09-2027\n'));
    await t.tap(find.byKey(const Key('m-menu')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('m-import')));
    await net(t);
    expect(find.text('Import this file?'), findsOneWidget);
    expect(find.text('• New machinery: 1'), findsOneWidget);
    expect(find.text('• Existing machinery that will be updated: 1'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    final calls = srv.masterCalls.where((c) => c['fn'] == 'importMaster').toList();
    expect([for (final c in calls) c['save']], [false, false, true]);
    expect(calls.last['rows'], [
      {'line': 3, 'no': 'MH-25-AJ-2169', 'name': '', 'type': 'Tipper', 'kmStd': 3.6, 'pucUpto': 'NA'},
      {'line': 4, 'no': '', 'name': 'Roller 1', 'type': 'Roller', 'kmStd': '', 'pucUpto': '2027-09-30'},
    ]);
    expect(find.text('Imported: 1 new, 1 updated.'), findsOneWidget);
    expect(find.byKey(const Key('m-NEW-1')), findsOneWidget, reason: 'the Master the server sent back');
  }, tags: ['golden']);

  testWidgets('(3.13.0) Vehicle Compliance ⋮: Import Excel – the papers read, the dates it changes asked, saved (importCompliance)', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Vehicle Compliance');
    pickThis('papers.csv', utf8.encode('Machinery No,Type,PUC Valid Upto,Permit,Status (not imported)\nMH-25-AJ-2169,Tipper,30-09-2027,NA,Expired\n,,,,\n'));
    await t.tap(find.byKey(const Key('cp-menu')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('cp-import')));
    await net(t);
    expect(find.text('Import 2 dates?'), findsOneWidget);
    expect(find.text('• MH-25-AJ-2169 – PUC: 01-10-2026 → 30-09-2027'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    final calls = srv.masterCalls.where((c) => c['fn'] == 'importCompliance').toList();
    expect([for (final c in calls) c['save']], [false, true]);
    expect(calls.first['rows'], [
      {'line': 2, 'no': 'MH-25-AJ-2169', 'docs': {'PUC': '2027-09-30', 'Permit': 'NA'}, 'raw': {'PUC': '30-09-2027', 'Permit': 'NA'}},
    ]);
    expect(find.text('Imported: 2 date(s) on 1 machinery.'), findsOneWidget);
  });

  testWidgets('(3.13.0 / 3.18.1) Edit Log Book of a water tanker: Export Excel – every water tanker of every agency, VEHICLE NO picked from the list; Import Excel – each line its own tanker (none: "Fix the file first"), checked, asked, imported, the tanker read again', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms['Log Book'] = 'Edit'
      ..tanker = true
      ..tanker2 = true;
    final s = await ready(t, srv);
    final files = catchFiles();
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook').last); // (3.31.0) the module (the tile of today's entries is Logbook too)
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
    await reach(t, 'lt-export-b', 'lx-list');
    await tapK(t, 'lt-export-b');
    await net(t);
    expect(files.last.$1, 'Water tankers 01-10-2026 to 14-10-2026.xlsx');
    expect(srv.calls, contains('mech:getLogBookList'), reason: 'every tanker\'s trips of these dates');
    final tabs = readSheets(files.last.$2), tab = tabs.first;
    expect(tab.name, 'Trips');
    expect(tab.rows[2].first, 'WATER TANKER REPORT – all water tankers – 01-10-2026 to 14-10-2026');
    expect(tab.rows[4], ['SR. NO.', 'DATE', 'SHIFT', 'NAME OF AGENCY', 'VEHICLE NO', 'CHALLAN NO', 'DISPATCH TIME', 'UNLOAD TIME', 'TRIP', 'CHAINAGE NO', 'USE FOR']);
    expect([for (final r in tab.rows.sublist(5, 8)) [(r[0] as num).toInt(), for (final c in r.skip(1).take(5)) '$c']], [
      [1, '13-10-2026', 'Night', 'Patil Water Supply', 'MH-12-AB-1001', 'P-7'],
      [2, '14-10-2026', 'Day', 'Chalke Enterprises', 'MH-04-J-9844', '123'],
      [3, '14-10-2026', 'Day', 'Chalke Enterprises', 'MH-04-J-9844', '18522'],
    ], reason: 'both agencies\' tankers, date by date');
    expect(tab.rows.skip(8).every((r) => r.take(5).every((c) => c == '')), true, reason: 'no tanker fixed in the empty lines (the agency is a formula; the 100 lines and their cells: the unit test)');
    expect(tabs[1].name, 'Lists');
    expect(tabs[1].rows, [['MH-04-J-9844', 'Chalke Enterprises'], ['MH-12-AB-1001', 'Patil Water Supply']], reason: 'the VEHICLE NO drop-down: every water tanker');
    expect(find.textContaining('3 trips of 2 water tankers and 100 empty lines.'), findsOneWidget);
    await settle(t, 4500); // (the message – three lines now – gone from over the buttons)
    // a line without its VEHICLE NO: not given to the tanker open – nothing sent
    pickThis('trips.csv', utf8.encode('DATE,SHIFT,VEHICLE NO,CHALLAN NO,DISPATCH TIME,UNLOAD TIME,USE FOR\n13-10-2026,night,,WT-9,21:00,21:30,Curing\n13-10-2026,,MH-04-J-0001,WT-10,08:00,08:20,\n'));
    await reach(t, 'lt-import-b', 'lx-list');
    await tapK(t, 'lt-import-b');
    await net(t);
    expect(find.text('Fix the file first'), findsOneWidget);
    expect(find.text('• Line 2: pick the VEHICLE NO – the water tanker of this trip.'), findsOneWidget);
    expect(srv.logBulk.where((c) => c['fn'] == 'checkTankerImport'), isEmpty);
    await t.tap(find.byKey(const Key('tell-ok')));
    await net(t);
    pickThis('trips.csv', utf8.encode('DATE,SHIFT,VEHICLE NO,CHALLAN NO,DISPATCH TIME,UNLOAD TIME,USE FOR\n13-10-2026,night,MH-04-J-9844,WT-9,21:00,21:30,Curing\n13-10-2026,,MH-04-J-0001,WT-10,08:00,08:20,\n'));
    await reach(t, 'lt-import-b', 'lx-list');
    await tapK(t, 'lt-import-b');
    await net(t);
    expect(find.text('Import the trips?'), findsOneWidget);
    expect(find.text('• 2 trips will be added (1 tanker)'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    final chk = srv.logBulk.firstWhere((c) => c['fn'] == 'checkTankerImport')['x'] as Map;
    expect(chk['rows'], [
      {'line': '2', 'no': 'MH-04-J-9844', 'date': '2026-10-13', 'shift': 'Night', 'c': 'WT-9', 'a': '21:00', 'b': '21:30', 'ch': '', 'u': 'Curing'},
      {'line': '3', 'no': 'MH-04-J-0001', 'date': '2026-10-13', 'shift': 'Day', 'c': 'WT-10', 'a': '08:00', 'b': '08:20', 'ch': '', 'u': ''},
    ]);
    expect(srv.logBulk.where((c) => c['fn'] == 'importTankerTrips').length, 1);
    expect(find.text('Water tanker: 2 trips added, 1 already saved.'), findsOneWidget);
    expect(srv.logBulk.where((c) => c['fn'] == 'getTankerRange').length, 2, reason: 'the tanker read again');
  });

  testWidgets('(3.13.0) Store – Import from Excel: every row checked (new / already there / near name); a near name added only when ticked; the template', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    final files = catchFiles();
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.ensureVisible(find.text('Store'));
    await settle(t, 400);
    await t.tap(find.text('Store'));
    await net(t);
    await t.tap(find.byKey(const Key('st-tab-items')));
    await settle(t, 800);
    await tapK(t, 'st-tpl');
    await net(t);
    expect(files.last.$1, 'Items_template.xlsx');
    final tpl = readSheets(files.last.$2).single;
    expect(tpl.name, 'Items');
    expect(tpl.rows, [
      ['Item Code', 'Item Name', 'Unit', 'Category', 'HSN Code', 'GST %', 'Min Stock', 'Status'],
      ['', 'Hydraulic Hose 1/2 inch', 'Mtr', 'Spare Parts', '40092100', 18, 10, ''],
    ]);
    pickThis('items.csv', utf8.encode('Item Name,Unit,Category,GST %\nSugar,Kg,Canteen,5\nSugaar,Kg,Canteen,"1,000"\nGrease,Kg,Spare Parts,18\n\n'));
    await tapK(t, 'st-import');
    await net(t);
    expect(find.text('Import from Excel – check'), findsOneWidget);
    expect(find.text('3 rows: 1 new, 1 already there (left out), 1 near names to confirm, 0 with a mistake.'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/38_store_import.png'));
    await tapK(t, 'si-go');
    await net(t);
    expect(find.text('Confirm the near names first.'), findsWidgets, reason: 'not ticked: the server refuses, the check is read again');
    await tapK(t, 'si-ok-3');
    await settle(t, 300);
    await tapK(t, 'si-go');
    await net(t);
    final imps = srv.storeSent.where((x) => x['action'] == 'import').toList();
    expect([for (final x in imps) jsonEncode([x['check'], x['confirm']])], ['[true,{}]', '[null,{}]', '[true,{}]', '[null,{"3":["ITM-0002"]}]']);
    expect((imps.first['rows'] as List)[1], {'line': 3, 'name': 'Sugaar', 'unit': 'Kg', 'category': 'Canteen', 'hsn': '', 'gst': '1,000', 'minStock': ''});
    expect(find.text('2 items imported, 1 already there (left out).'), findsOneWidget);
    expect(find.text('5 of 5 items'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.14.0) Diesel Issue: the machinery\'s diesel history (last fill, the reading as the hint, the last driver); the photos of a saved fill', (t) async {
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
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    await t.tap(find.text('MH-25-AJ-2169').last);
    await net(t);
    expect(srv.extraCalls.firstWhere((c) => c['fn'] == 'dieselHistory')['x'], {'no': 'MH-25-AJ-2169', 'date': '2026-10-14', 'limit': 5});
    expect(find.text('Diesel history – MH-25-AJ-2169'), findsOneWidget);
    expect(find.text('Last fill 13-10-2026 (yesterday) · 80 L · Last reading KM 15,100 (13-10-2026) · This month 520 L in 7 fills'), findsOneWidget);
    expect(find.text('Last 1 of 7 fills.'), findsOneWidget);
    expect(find.text('last 15,100'), findsOneWidget, reason: 'the last reading is the hint of the KM box');
    expect(t.widget<TextField>(find.byKey(const Key('d-driver'))).controller!.text, 'Ramesh', reason: 'the driver of the last fill');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/40_issue_history.png'));
    await t.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await net(t);
    // the photos of a saved fill
    await t.tap(find.text('Sany 210 (No.1)').first);
    await settle(t, 800);
    await t.tap(find.byKey(const Key('ed-photos')));
    await net(t);
    expect(srv.extraCalls.last, {'fn': 'getDieselPhotos', 'id': 'DI-000525'});
    expect(find.text('Photos – DI-000525 · Sany 210 (No.1) · 14-10-2026 Day · 60 L'), findsOneWidget);
    expect(find.text('Dashboard (reading)'), findsOneWidget);
    expect(find.text('Map (± 12 m)'), findsOneWidget);
    expect(find.text('The picture was not found.'), findsNWidgets(2));
  }, tags: ['golden']);

  testWidgets('(3.14.0) Diesel Transfer: the stock of From and To at the date, after the litres (getTransferBalance)', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Diesel Transfer'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Transfer')));
    await net(t);
    await t.tap(find.text('New Entry').last);
    await net(t);
    final a = srv.extraCalls.firstWhere((c) => c['fn'] == 'getTransferBalance')['args'] as List;
    expect([a[0], a[4]], ['2026-10-14', '']);
    expect(a[2] == a[3], false, reason: 'From and To are two places');
    await t.enterText(find.byType(TextField).first, '100');
    await settle(t, 400);
    expect(find.text('after 800 Ltr'), findsOneWidget);
    expect(find.text('after 400 Ltr'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '870');
    await settle(t, 400);
    expect(find.text('Can transfer up to 850 Ltr'), findsOneWidget);
  });

  testWidgets('(3.43.0, Mechanical update-162) his diesel sources: Diesel Issue and the From of a transfer offer only them (To and Inward: every place); none given: a red line; changed in the Portal: at the next sync', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms['Diesel Transfer'] = 'Edit'
      ..dsrc = {'Diesel Issue': ['VTR Store'], 'Diesel Transfer': ['VTR Store']}
      ..userInSync = true;
    final s = await ready(t, srv);
    expect([s.mySources('Diesel Issue'), s.mySources('Diesel Transfer'), s.locations], [['VTR Store'], ['VTR Store'], ['Dispenser', 'VTR Store']]);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    Finder chip(String l) => find.widgetWithText(ChoiceChip, l);
    // from the grid of Entries: a page's list, its New Entry
    Future<void> newEntry(String page) async {
      await t.tap(find.byKey(Key('entries-$page')));
      await net(t);
      await t.tap(find.text('New Entry').last);
      await net(t);
    }
    // back from the form to the grid
    Future<void> toGrid() async {
      await t.pageBack();
      await net(t);
      await t.tap(find.byTooltip('All entries'));
      await net(t);
    }
    await t.tap(find.text('Entries'));
    await net(t);
    // Diesel Issue: only VTR Store – shown although one (he sees where the diesel comes from), chosen
    await newEntry('Diesel Issue');
    expect(find.text('Diesel from'), findsOneWidget);
    expect(chip('VTR Store'), findsOneWidget);
    expect(chip('Dispenser'), findsNothing);
    expect(t.widget<ChoiceChip>(chip('VTR Store')).selected, true);
    expect(srv.issueBal.last.last, 'VTR Store', reason: 'the stock of his source');
    await toGrid();
    // Diesel Transfer: From only VTR Store; To every place, ready on the other one
    await newEntry('Transfer');
    expect(chip('VTR Store'), findsNWidgets(2), reason: 'From and To');
    expect(chip('Dispenser'), findsOneWidget, reason: 'To only');
    expect(t.widget<ChoiceChip>(chip('Dispenser')).selected, true);
    final a = srv.extraCalls.lastWhere((c) => c['fn'] == 'getTransferBalance')['args'] as List;
    expect([a[2], a[3]], ['VTR Store', 'Dispenser']);
    await t.pageBack();
    await net(t);
    // "Multiple entries" of transfers: From only his
    await more(t, 'en-many');
    final f0 = t.widget(find.byKey(const Key('tm-from-0'))) as dynamic, t0 = t.widget(find.byKey(const Key('tm-to-0'))) as dynamic;
    expect([f0.items, f0.value, t0.items, t0.value], [['VTR Store'], 'VTR Store', ['Dispenser', 'VTR Store'], 'Dispenser']);
    await toGrid();
    // the Super Admin takes every Issue source away in the Portal: the next sync – a red line, no chip
    srv.dsrc = {'Diesel Issue': [], 'Diesel Transfer': ['VTR Store']};
    await t.runAsync(() => s.liveTick());
    await net(t);
    expect(s.mySources('Diesel Issue'), isEmpty);
    await newEntry('Diesel Issue');
    expect(find.text('No diesel source is given to you – ask the Super Admin (Portal → Users & Access → Pages).'), findsOneWidget);
    expect(chip('VTR Store'), findsNothing);
    expect(chip('Dispenser'), findsNothing);
    await toGrid();
    // every place ticked again (nothing kept for him): every source, as before – both places
    srv.dsrc = null;
    await t.runAsync(() => s.liveTick());
    await net(t);
    expect([s.mySources('Diesel Issue'), s.mySources('Diesel Transfer')], [['Dispenser', 'VTR Store'], ['Dispenser', 'VTR Store']]);
    await newEntry('Diesel Issue');
    expect(chip('Dispenser'), findsOneWidget);
    expect(chip('VTR Store'), findsOneWidget);
  });

  testWidgets('(3.14.0) My settings: Log Book list shows, the page to open after sign-in, my last sign-ins, back to the usual settings', (t) async {
    phone(t);
    final srv = FakeServer();
    srv.prefs['photo'] = '';
    srv.prefs['mobile'] = '9800000000';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Me'));
    await net(t);
    await t.tap(find.text('My settings'));
    await net(t);
    await t.scrollUntilVisible(find.text('Log Book list shows'), 200, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('Log Book list shows'));
    await settle(t, 600);
    await t.tap(find.text('Last 7 days').last);
    await net(t);
    expect(srv.prefs['lbDays'], '7');
    await t.tap(find.text('Page to open after sign-in'));
    await settle(t, 600);
    expect(find.text('Diesel Issue'), findsOneWidget);
    expect(find.text('Log Book'), findsOneWidget);
    expect(find.text('Diesel Transfer'), findsNothing, reason: 'no access to it');
    expect(find.text('Users & Access'), findsNothing, reason: 'Admin only');
    await t.tap(find.text('Log Book'));
    await net(t);
    expect(srv.prefs['start'], 'log');
    await t.scrollUntilVisible(find.byKey(const Key('set-reset')), 200, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Oct 2026, '), findsNWidgets(2), reason: 'his last two sign-ins');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/41_settings_more.png'));
    await t.tap(find.byKey(const Key('set-reset')));
    await settle(t, 600);
    await t.tap(find.text('Reset'));
    await net(t);
    expect([srv.prefs['lbDays'], srv.prefs['start'], srv.prefs['mobile']], ['2', '', '9800000000'], reason: 'his mobile number stays');
  }, tags: ['golden']);

  testWidgets('(3.14.0) The page to open after sign-in opens by itself (Log Book); the notice of the site on Home', (t) async {
    phone(t);
    final srv = FakeServer()..notice = 'Diesel inward only till 6 PM today.';
    srv.prefs['start'] = 'log';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await net(t);
    expect(find.byType(LogBookScreen), findsOneWidget);
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await net(t);
    expect(find.text('Diesel inward only till 6 PM today.'), findsOneWidget);
  });

  testWidgets('(3.14.0 / 3.18.2) A machinery label scanned: the app\'s own scanner opens (live camera, the square, nothing to press); Diesel Issue with the machinery in it; not a label; not in the Master', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    // the camera's place: a picture that "sees" the code put in [code] when it is touched
    var code = '';
    QrScanScreen.cameraForTest = (found) => GestureDetector(key: const Key('qr-cam'), onTap: () => found(code), child: const ColoredBox(color: Color(0xFF3B4A40)));
    addTearDown(() => QrScanScreen.cameraForTest = null);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    Future<void> scan(String c) async {
      code = c;
      await t.tap(find.byKey(const Key('home-scan')));
      await net(t);
      expect(find.byType(QrScanScreen), findsOneWidget, reason: 'the scanner opens – not the camera app');
      await t.tap(find.byKey(const Key('qr-cam')));
      await net(t);
      expect(find.byType(QrScanScreen), findsNothing, reason: 'a code seen: the scanner closes by itself');
    }

    // the scanner itself: its square and its words
    code = '';
    await t.tap(find.byKey(const Key('home-scan')));
    await net(t);
    expect(find.text('Scan the machinery label'), findsOneWidget);
    expect(find.text('Hold the QR label inside the square – it is read by itself.'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/49_qr_scanner.png'));
    await t.tap(find.byKey(const Key('qr-cam')));
    await net(t);
    expect(find.byType(QrScanScreen), findsOneWidget, reason: 'an empty code is not taken');
    await t.pageBack();
    await net(t);
    expect(find.byType(QrScanScreen), findsNothing, reason: 'Back closes it – nothing happens');
    await scan('https://www.google.com/');
    expect(find.text('This QR code is not a machinery label of the ERP.'), findsOneWidget);
    await settle(t, 4000);
    await scan('https://rcl-erp.example.app/?m=XX-99');
    expect(find.text('The machinery of this label (XX-99) is not in the Master.'), findsOneWidget);
    await settle(t, 4000);
    await scan('https://rcl-erp.example.app/?m=mh25aj2169');
    expect(find.descendant(of: find.byKey(const Key('ql-no')), matching: find.text('MH-25-AJ-2169')), findsOneWidget, reason: 'found as the web\'s findMachine finds it');
    expect(find.byKey(const Key('ql-diesel')), findsOneWidget);
    expect(find.byKey(const Key('ql-log')), findsNothing, reason: 'Log Book is View only here');
    expect(find.byKey(const Key('ql-ledger')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/42_label_scanned.png'));
    await t.tap(find.byKey(const Key('ql-diesel')));
    await net(t);
    expect(find.text('New Diesel Issue'), findsOneWidget);
    expect(find.text('Diesel history – MH-25-AJ-2169'), findsOneWidget, reason: 'the machinery is in the box already');
  }, tags: ['golden']);

  testWidgets('(3.14.0) Administration: the faults of the app – listed, emptied; the backup to Google Sheet', (t) async {
    phone(t);
    final srv = FakeServer()..superAdmin = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.ensureVisible(find.text('Administration'));
    await settle(t, 400);
    await t.tap(find.text('Administration'));
    await net(t);
    await t.scrollUntilVisible(find.byKey(const Key('ad-faults')), 200, scrollable: find.byType(Scrollable).last);
    await tapK(t, 'ad-faults');
    await net(t);
    expect(find.text('x is undefined'), findsOneWidget);
    expect(find.textContaining('clerk@rcl.test · on the server · getStock'), findsOneWidget);
    await tapK(t, 'flt-empty');
    await settle(t, 600);
    await t.tap(find.text('Empty'));
    await net(t);
    expect(srv.extraCalls.any((c) => c['fn'] == 'clearErrors'), true);
    expect(find.text('No fault has been reported.'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await t.scrollUntilVisible(find.byKey(const Key('ad-backup')), 200, scrollable: find.byType(Scrollable).last);
    await tapK(t, 'ad-backup');
    await net(t);
    expect(find.text('New data copied to the Google Sheet now.'), findsOneWidget);
    expect(find.text('diesel_issue: 3 rows'), findsOneWidget);
    expect(find.text('Open the backup Google Sheet'), findsOneWidget);
  });

  testWidgets('(3.14.0) Search: a spelling mistake – "Did you mean"; the owner who is also a vendor once; an issue ID – Edit; a machinery – its Log Book', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('home-search')));
    await net(t);
    expect(find.text('Pages'), findsOneWidget, reason: 'nothing typed: the pages and the quick actions');
    expect(find.text('New diesel issue'), findsOneWidget);
    await t.enterText(find.byKey(const Key('gs-in')), 'enterprize');
    await net(t, 1500);
    expect(srv.extraCalls.lastWhere((c) => c['fn'] == 'globalSearch')['q'], 'enterprize');
    expect(find.text('enterprises'), findsOneWidget, reason: 'did you mean');
    expect(find.text('I E Enterprises'), findsOneWidget, reason: 'the owner and the vendor: one result');
    expect(find.byKey(const Key('gs-chip-I E Enterprises-Vendor')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/43_search.png'));
    await t.enterText(find.byKey(const Key('gs-in')), '525');
    await net(t, 1500);
    expect(find.text('Diesel issues  (3 found – the best 1)'), findsOneWidget);
    await t.tap(find.byKey(const Key('gs-chip-DI-000525  –  Sany 210 (No.1)-Edit')));
    await net(t);
    expect(find.text('Change DI-000525'), findsOneWidget);
    await t.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await net(t);
    await t.enterText(find.byKey(const Key('gs-in')), 'sany');
    await net(t, 1500);
    expect(find.byKey(const Key('gs-mach-Sany 210 (No.1)')), findsOneWidget);
    await t.tap(find.byKey(const Key('gs-chip-Sany 210 (No.1)-Log Book')));
    await net(t);
    expect(srv.listAsked.last['no'], 'Sany 210 (No.1)');
    expect([srv.listAsked.last['from'], srv.listAsked.last['to']], ['', ''], reason: 'all dates, as the web\'s gsOpenLog');
  }, tags: ['golden']);

  testWidgets('(3.15.0) Ask the app: the daily summary waits (a red dot) and comes by itself; a ⚡ question; an entry from words – shown, Open in the form, saved only by "हो"; the Log Book needs Edit', (t) async {
    phone(t);
    forgetChat();
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await net(t);
    expect(s.briefDue.value, true, reason: 'once a day: the summary waits on Home (a red dot on Ask)');
    await tapK(t, 'home-ask');
    await net(t);
    await net(t);
    expect(find.textContaining('सुप्रभात, Sujit Mule. काल (13-10-2026):'), findsOneWidget, reason: 'the summary came by itself, in his help language');
    expect(find.textContaining('गाड्यांचे कागद: 1 संपलेले, 1 30 दिवसांत संपणारे – MH-25-AJ-2169 PUC.'), findsOneWidget);
    expect(s.briefDue.value, false);
    expect(srv.calls.where((c) => c == 'mech:getBrief').length, 1);
    await tapK(t, 'ai-ready-pending');
    await net(t);
    expect(find.textContaining('14-10-2026 साठी 2 गाड्यांची Log Book entry बाकी आहे:'), findsOneWidget, reason: 'answered by the app itself');
    expect(find.text('⚡ app कडून थेट, आत्ता'), findsWidgets);
    // an entry from words: shown – nothing saved
    await t.enterText(find.byKey(const Key('ai-in')), 'MH-25-AJ-2169 la 50 litre diesel de km 15300');
    await tapK(t, 'ai-send');
    await net(t);
    expect(find.text('MH-25-AJ-2169 · Tipper · I E Enterprises'), findsOneWidget);
    expect(find.text('14-10-2026 · Day'), findsOneWidget);
    expect(find.text('50 L  ←  Dispenser'), findsOneWidget);
    expect(find.text('15,300 km'), findsOneWidget);
    expect(srv.saved, isEmpty, reason: 'nothing is saved by itself');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/44_ask_entry.png'));
    // Open in the form: the app's own form, the machinery, date, shift and litres in it
    await tapK(t, 'ai-form');
    await net(t);
    expect(find.text('New Diesel Issue'), findsOneWidget);
    expect(find.text('Diesel history – MH-25-AJ-2169'), findsOneWidget);
    expect(find.text('50'), findsWidgets, reason: 'the litres in the box');
    await t.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await net(t);
    expect(srv.saved, isEmpty);
    // again, then "हो": saved through the app's save
    await t.enterText(find.byKey(const Key('ai-in')), 'MH-25-AJ-2169 la 50 litre diesel de km 15300');
    await tapK(t, 'ai-send');
    await net(t);
    await t.enterText(find.byKey(const Key('ai-in')), 'हो');
    await tapK(t, 'ai-send');
    await net(t);
    expect(srv.saved.single['no'], 'MH-25-AJ-2169');
    expect(srv.saved.single['qty'], 50);
    expect(srv.saved.single['kmReading'], 15300);
    expect(srv.saved.single['source'], 'Dispenser');
    expect(find.textContaining('Save झाले ✔ Diesel Issue DI-000526 – MH-25-AJ-2169'), findsOneWidget);
    expect(s.stockTotal, 1083, reason: 'the stock the server sent back');
    // the Log Book is View only here: the same access as the form
    await t.enterText(find.byKey(const Key('ai-in')), 'Sany 210 आज idle');
    await tapK(t, 'ai-send');
    await net(t);
    expect(find.text('Log Book entry करण्याची परवानगी तुम्हाला नाही.'), findsOneWidget);
    expect(srv.logSaved, isEmpty);
    // My settings: the daily summary – No
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await net(t);
    await t.tap(find.text('Me'));
    await net(t);
    await t.tap(find.text('My settings'));
    await net(t);
    await t.scrollUntilVisible(find.text('Daily summary when I open the app'), 200, scrollable: find.byType(Scrollable).last);
    await t.ensureVisible(find.text('Daily summary when I open the app'));
    await settle(t, 600);
    await t.tap(find.text('Daily summary when I open the app'));
    await settle(t, 600);
    await t.tap(find.text('No').last);
    await net(t);
    expect(srv.prefs['brief'], false);
  }, tags: ['golden']);

  testWidgets('(3.15.0) Ask the app – the AI service: the snapshot goes with the question, its look-up runs with his sign-in, "Looked up", a page button; the service fails → the app\'s own answer; Admin: Test the AI service', (t) async {
    phone(t);
    forgetChat();
    final srv = FakeServer()
      ..superAdmin = true
      ..aiOn = true;
    srv.prefs['brief'] = false;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await net(t);
    expect(s.briefDue.value, false, reason: 'his settings: no daily summary');
    await tapK(t, 'home-ask');
    await net(t);
    expect(find.textContaining('AI key'), findsNothing, reason: 'the AI service is set up');
    srv.aiScript.addAll([
      {'parts': [{'functionCall': {'name': 'diesel_issues', 'args': {'from': '2026-10-14', 'to': '2026-10-14'}}}], 'model': 'gemini-test-flash'},
      {'parts': [{'text': 'Kobelco Sk 220 and MH-25-AJ-2169 took the most today: **80 L** each. [[open:diesel|Diesel Issue]]'}], 'model': 'gemini-test-flash'},
    ]);
    await t.enterText(find.byKey(const Key('ai-in')), 'who took the most diesel today and why');
    await tapK(t, 'ai-send');
    await net(t);
    await net(t);
    expect(srv.aiAsked.length, 2);
    final ctx = srv.aiAsked.first['context'] as Map;
    expect((ctx['dieselIssuedToday'] as Map)['entries'], 4, reason: 'the snapshot of the day goes with the question');
    expect((ctx['page'] as Map)['tab'], 'dash');
    expect((srv.aiAsked.first['contents'] as List).single, {'role': 'user', 'parts': [{'text': 'who took the most diesel today and why'}]});
    final back = (srv.aiAsked.last['contents'] as List).last as Map;
    final resp = ((back['parts'] as List).single as Map)['functionResponse'] as Map;
    expect([back['role'], resp['name'], (resp['response'] as Map)['entries'], (resp['response'] as Map)['totalLitres']], ['user', 'diesel_issues', 4, 240]);
    expect(find.text('Looked up:'), findsOneWidget);
    expect(find.text('Diesel issues 14-10-2026'), findsOneWidget);
    expect(find.textContaining('took the most today: 80 L each.'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/45_ask_ai.png'));
    // the page button: the app's own Diesel Issue entries
    await tapK(t, 'ai-go-diesel');
    await net(t);
    expect(find.byType(AssistantScreen), findsNothing);
    await t.tap(find.text('Home'));
    await net(t);
    await tapK(t, 'home-ask');
    await net(t);
    expect(find.text('Looked up:'), findsOneWidget, reason: 'the conversation is kept');
    // the AI service fails: the app answers as well as it can, and says so
    srv.aiOn = false;
    await t.enterText(find.byKey(const Key('ai-in')), 'why so much diesel today');
    await tapK(t, 'ai-send');
    await net(t);
    expect(find.text('⚡ The AI service is not set up – from the app itself, now'), findsOneWidget);
    expect(find.textContaining('14-10-2026: 240 L in 4 entries.'), findsOneWidget);
    // Admin: which model answers
    srv.aiOn = true;
    await tapK(t, 'ai-test');
    await net(t);
    expect(find.textContaining('✓ gemini-3.8-flash – answered in 1.2 s'), findsOneWidget);
    expect(find.textContaining('✗ gemini-3.7-flash – 503: The model is overloaded.'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.15.0) Ask the app by voice: he speaks, it answers aloud, it listens again; "हो" saves the entry heard; 3 silences end the talk; 🔊 of an answer', (t) async {
    phone(t);
    forgetChat();
    final srv = FakeServer();
    srv.prefs['brief'] = false;
    final s = await ready(t, srv);
    final heard = <String>['MH-25-AJ-2169 la 40 litre diesel de km 15280', 'हो', '', '', ''];
    final said = <List<String>>[];
    final oL = voice.listenOnce, oS = voice.sayAloud, oSL = voice.stopListening, oSS = voice.stopSaying;
    addTearDown(() {
      voice.listenOnce = oL;
      voice.sayAloud = oS;
      voice.stopListening = oSL;
      voice.stopSaying = oSS;
    });
    voice.listenOnce = (lang, h) async {
      expect(lang, 'mr', reason: 'he is heard in his help language');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final w = heard.isEmpty ? '' : heard.removeAt(0);
      h(w);
      return w;
    };
    voice.sayAloud = (text, lang) async => said.add([text, lang]);
    voice.stopListening = () async {};
    voice.stopSaying = () async {};
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await tapK(t, 'home-ask');
    await net(t);
    await tapK(t, 'ai-mic');
    for (var i = 0; i < 5; i++) {
      await net(t);
    }
    expect(srv.saved.single['qty'], 40, reason: '"हो" said: saved through the app\'s save');
    expect(srv.saved.single['kmReading'], 15280);
    expect(said.first, ['MH-25-AJ-2169 ला 40 लिटर diesel, Dispenser मधून, 14-10-2026 Day. Save करू का?', 'mr'], reason: 'the entry said aloud, asking for the yes');
    expect(said[1][0], startsWith('Save झाले ✔ Diesel Issue DI-000526 – MH-25-AJ-2169'));
    expect(heard, isEmpty);
    expect(find.byKey(const Key('ai-live')), findsNothing, reason: '3 silences: the talk ends');
    await t.tap(find.byIcon(Icons.volume_up_rounded).last);
    await net(t);
    expect(said.last[1], 'mr');
    expect(said.last[0], startsWith('Save झाले ✔'));
  });

  testWidgets('(3.16.0) Help for a red message – what is wrong and what to do (मराठी, English); "Ask the assistant about this"; the "?" of a page', (t) async {
    phone(t);
    forgetChat();
    addTearDown(() => helpPicked = null);
    final srv = FakeServer()..aiOn = true;
    srv.prefs['brief'] = false;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Reports').last);
    await net(t);
    await t.tap(find.byKey(const Key('rt-diesel'))); // (3.31.0) the reports are under Diesel (Overview first)
    await net(t);
    await t.scrollUntilVisible(find.text('Machinery Diesel Ledger'), 300, scrollable: find.ancestor(of: find.text('Daily Inward & Issue'), matching: find.byType(Scrollable)).first);
    await settle(t, 300);
    await t.tap(find.text('Machinery Diesel Ledger'));
    await net(t);
    await tapK(t, 'rep-go');
    await net(t);
    expect(find.text('Pick a machinery from Master.'), findsOneWidget);
    await tapK(t, 'fix-help');
    await net(t);
    expect(find.byKey(const Key('fix-sheet')), findsOneWidget);
    expect(find.text('मदत'), findsOneWidget, reason: 'his help language: Marathi');
    expect(find.textContaining('काय चुकले: '), findsWidgets);
    expect(find.textContaining('काय करायचे: '), findsWidgets);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/46_fix_help.png'));
    await t.tap(find.byKey(const Key('help-lang-en')));
    await settle(t, 400);
    expect(find.textContaining('What is wrong: This machinery number / name is not in the Asset Master'), findsOneWidget);
    // Ask the assistant about this: the message and the page go to the AI service
    srv.aiScript.add({'parts': [{'text': 'Pick the machinery from the list – type part of its number.'}], 'model': 'gemini-test-flash'});
    await tapK(t, 'fix-ai');
    await net(t);
    await net(t);
    expect(find.byType(AssistantScreen), findsOneWidget);
    final asked = ((srv.aiAsked.single['contents'] as List).single as Map)['parts'] as List;
    expect((asked.single as Map)['text'], 'On the page "Machinery Diesel Ledger" I got this message: "Pick a machinery from Master.". What went wrong, and what should I do?');
    expect(find.textContaining('Pick the machinery from the list'), findsOneWidget);
    await t.pageBack();
    await net(t);
    // the "?" of the page: what it is, and how its figures come
    await tapK(t, 'guide-rp-ledger');
    await net(t);
    expect(find.byKey(const Key('guide-sheet')), findsOneWidget);
    expect(find.text('About this page'), findsOneWidget);
    expect(find.textContaining('What it is: The diesel account of one machinery, fill by fill.'), findsOneWidget);
    await t.tap(find.byKey(const Key('help-lang-mr')));
    await settle(t, 400);
    expect(find.text('या page बद्दल'), findsOneWidget);
  }, tags: ['golden']);

  /* (3.17.0) The Super Admin's console of the whole system (the Portal's "Super Admin") in the app's own screens. */
  Future<FakeServer> openConsole(WidgetTester t) async {
    final srv = FakeServer()..superAdmin = true;
    srv.prefs['brief'] = false;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Me'));
    await net(t);
    await tapK(t, 'me-super'); // (3.31.0) his role is also on Me now
    await net(t);
    return srv;
  }

  /// A choice of a row of choices (a role, a page): brought into view, then tapped.
  Future<void> tapIn(WidgetTester t, String key, String text) async {
    final f = find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
    FocusManager.instance.primaryFocus?.unfocus();
    await t.ensureVisible(f);
    await settle(t, 400);
    await t.tap(f);
    await t.pump();
  }

  List<Map<String, dynamic>> saves(FakeServer srv) => srv.portalAdminSent.where((x) => x['action'] != 'overview').toList();

  testWidgets('(3.17.0) Super Admin – Users & Access: each user\'s modules on a site; a role and a one-time password; a user added (a refusal in the Portal\'s words); his pages in Mechanical and the Store', (t) async {
    phone(t);
    final srv = await openConsole(t);
    expect(srv.calls, contains('admin:overview'));
    expect(find.byKey(const Key('sa-u-amol@rcl.test')), findsOneWidget);
    expect(find.byKey(const Key('sa-u-sujit@rcl.test')), findsNothing, reason: 'the Super Admin himself is not in the list');
    expect(find.text('2 users · 1 active'), findsOneWidget);
    expect(find.textContaining('must set password'), findsOneWidget);
    expect(find.text('Switched off'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/47_super_admin.png'));
    // Amol: the Store made Admin, a new one-time password – only the role that changed is sent
    await tapK(t, 'sa-u-amol@rcl.test');
    await net(t);
    expect(find.byKey(const Key('sa-pages-mechanical')), findsOneWidget);
    await tapIn(t, 'sa-role-store', 'Admin');
    await t.pump();
    await t.enterText(find.byKey(const Key('sa-u-pw')), 'Temp1234');
    await tapK(t, 'sa-u-save');
    await net(t);
    expect(saves(srv), [
      {'action': 'userSave', 'isNew': false, 'email': 'amol@rcl.test', 'name': 'Amol Patil', 'active': true, 'newPassword': 'Temp1234'},
      {'action': 'accessSet', 'email': 'amol@rcl.test', 'site': 'S1', 'module': 'store', 'role': 'admin'},
    ]);
    expect(find.text('Saved: amol@rcl.test – tell him the one-time password.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'back on the list');
    // a new user: a one-time password too short – the Portal\'s words, the screen stays; then added with Mechanical (User)
    await tapK(t, 'sa-u-new');
    await net(t);
    await t.enterText(find.byKey(const Key('sa-u-email')), 'Nitin@RCL.test');
    await t.enterText(find.byKey(const Key('sa-u-name')), 'Nitin Jadhav');
    await t.enterText(find.byKey(const Key('sa-u-pw')), 'abc');
    await tapIn(t, 'sa-role-mechanical', 'User');
    await t.pump();
    await tapK(t, 'sa-u-save');
    await net(t);
    expect(find.text('Give a one-time password of at least 6 characters – the user must change it at the first sign-in.'), findsOneWidget);
    expect(find.byKey(const Key('sa-u-email')), findsOneWidget);
    await t.enterText(find.byKey(const Key('sa-u-pw')), 'Start123');
    await tapK(t, 'sa-u-save');
    await net(t);
    expect(saves(srv).skip(3).toList(), [
      {'action': 'userSave', 'isNew': true, 'email': 'nitin@rcl.test', 'name': 'Nitin Jadhav', 'active': true, 'newPassword': 'Start123'},
      {'action': 'accessSet', 'email': 'nitin@rcl.test', 'site': 'S1', 'module': 'mechanical', 'role': 'user'},
    ]);
    expect(find.text('User added: nitin@rcl.test – tell him the one-time password.'), findsOneWidget);
    expect(find.byKey(const Key('sa-u-nitin@rcl.test')), findsOneWidget);
    // Amol's pages in Mechanical (kept in Mechanical): Log Book made Edit
    await tapK(t, 'sa-u-amol@rcl.test');
    await net(t);
    await tapK(t, 'sa-pages-mechanical');
    await net(t);
    expect(saves(srv).last, {'action': 'mechPages', 'site': 'S1'});
    expect(find.text('Diesel Issue'), findsOneWidget);
    await tapIn(t, 'sa-pg-log', 'Edit');
    await t.pump();
    await tapK(t, 'sa-pg-save');
    await net(t);
    expect(saves(srv).last, {'action': 'mechPagesSave', 'site': 'S1', 'email': 'amol@rcl.test', 'perms': {'diesel': 'Edit', 'log': 'Edit', 'reports': 'None'}});
    expect(find.text('Pages saved in Mechanical.'), findsOneWidget);
    // the Store: he is its Admin now – every page, nothing to give
    await tapK(t, 'sa-pages-store');
    await net(t);
    expect(find.textContaining('Store Admin has every page'), findsOneWidget);
    expect(find.byKey(const Key('sa-spg-save')), findsNothing);
  }, tags: ['golden']);

  testWidgets('(3.17.0) Super Admin – Sites: a site\'s diesel places; New site – the checklist until Ready (the SQL copied); a closed site deleted with its code typed', (t) async {
    phone(t);
    var copied = '';
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'Clipboard.setData') copied = '${(c.arguments as Map)['text']}';
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final srv = await openConsole(t);
    await t.tap(find.byKey(const Key('sa-t-sites')));
    await net(t);
    expect(find.byKey(const Key('sa-st-K7')), findsOneWidget);
    await tapK(t, 'sa-st-S1');
    await net(t);
    expect(find.byKey(const Key('sa-st-del')), findsNothing, reason: 'an Active site is not deleted');
    await tapK(t, 'sa-st-places');
    await net(t);
    expect(saves(srv).last, {'action': 'placesGet', 'site': 'S1'});
    expect(find.text('Camp Pump'), findsOneWidget);
    expect(find.text('Stock now: 12,450.5 Ltr'), findsOneWidget);
    expect(find.byKey(const Key('pl-del-0')), findsNothing, reason: 'a place with entries stays');
    expect(find.byKey(const Key('pl-del-1')), findsOneWidget);
    await tapK(t, 'pl-add');
    await t.pump();
    await t.enterText(find.byKey(const Key('pl-name-2')), 'VTR Store');
    await t.enterText(find.byKey(const Key('pl-cap-2')), '5000');
    await tapK(t, 'pl-save');
    await net(t);
    expect(saves(srv).last, {
      'action': 'placesSave', 'site': 'S1',
      'places': [{'name': 'Camp Pump', 'cap': 18000}, {'name': 'MH12ZE1739', 'cap': 2650}, {'name': 'VTR Store', 'cap': 5000}],
    });
    expect(find.text('Diesel places of S1 saved: Camp Pump, MH12ZE1739, VTR Store.'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // New site: the key is not in Vercel yet → the tables are not there → Ready
    await tapK(t, 'sa-st-new');
    await net(t);
    await t.enterText(find.byKey(const Key('ns-code')), 'PN4');
    await t.enterText(find.byKey(const Key('ns-name')), 'Pune Ring Road');
    await t.enterText(find.byKey(const Key('ns-url')), 'https://abcdefghijklmnopqrst.supabase.co');
    await t.enterText(find.byKey(const Key('pl-name-0')), 'Camp Pump');
    await t.enterText(find.byKey(const Key('pl-cap-0')), '18000');
    await tapK(t, 'ns-check');
    await net(t);
    expect(saves(srv).last, {
      'action': 'siteSetup', 'code': 'PN4', 'name': 'Pune Ring Road', 'company': '', 'url': 'https://abcdefghijklmnopqrst.supabase.co', 'sheet': '',
      'places': [{'name': 'Camp Pump', 'cap': 18000}],
    });
    expect(find.textContaining('add SITE_PN4_KEY = this project'), findsOneWidget);
    expect(find.byKey(const Key('ns-keys')), findsOneWidget);
    srv.siteKey = true;
    await tapK(t, 'ns-check');
    await net(t);
    await tapK(t, 'ns-sql');
    await net(t);
    expect(copied, startsWith('-- Mechanical'));
    expect(find.textContaining('The SQL is copied ('), findsOneWidget);
    srv.siteTables = true;
    await tapK(t, 'ns-check');
    await net(t);
    expect(find.text('Site PN4 is ready.'), findsOneWidget);
    expect(find.textContaining('The site is Active.'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('ns-step-ready')));
    await settle(t, 400);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/48_new_site.png'));
    await t.pageBack();
    await net(t);
    expect(find.byKey(const Key('sa-st-PN4')), findsOneWidget);
    // K7 is Closed: deleted with its code typed – its data stays in its own database
    await tapK(t, 'sa-st-K7');
    await net(t);
    await tapK(t, 'sa-st-del');
    await net(t);
    await t.enterText(find.byKey(const Key('note-box')), 'k7');
    await tapK(t, 'note-ok');
    await net(t);
    expect(saves(srv).last, {'action': 'siteDelete', 'code': 'K7', 'confirm': 'k7'});
    expect(find.text('Site K7 deleted. Its data stays in its own database.'), findsOneWidget);
    expect(find.byKey(const Key('sa-st-K7')), findsNothing);
  }, tags: ['golden']);

  testWidgets('(3.17.0) Super Admin – Companies, Modules, Activity; the Portal\'s refusals in its words; a sign-in that ended goes to the sign-in', (t) async {
    phone(t);
    final srv = await openConsole(t);
    await t.tap(find.byKey(const Key('sa-t-companies')));
    await net(t);
    expect(find.byKey(const Key('sa-co-RACHANA')), findsOneWidget);
    await tapK(t, 'sa-co-new');
    await net(t);
    await t.enterText(find.byKey(const Key('co-name')), 'Mule Infra');
    await t.enterText(find.byKey(const Key('co-gstin')), '27ABC');
    await tapK(t, 'co-save');
    await net(t);
    expect(find.text('GST Number "27ABC" is not in the right format (15 characters, e.g. 27ABCDE1234F1Z5).'), findsOneWidget);
    await t.enterText(find.byKey(const Key('co-gstin')), '');
    await tapK(t, 'co-save');
    await net(t);
    expect(find.text('Company saved.'), findsOneWidget);
    expect(srv.saCompanies.map((c) => c['name']), contains('Mule Infra'));
    await tapK(t, 'sa-co-RACHANA');
    await net(t);
    expect(find.byKey(const Key('co-del')), findsNothing, reason: 'sites belong to it');
    await t.pageBack();
    await net(t);
    await tapK(t, 'sa-co-SKETCHLINE');
    await net(t);
    await tapK(t, 'co-del');
    await net(t);
    await t.tap(find.text('Delete').last);
    await net(t);
    expect(saves(srv).last, {'action': 'companyDelete', 'id': 'SKETCHLINE'});
    expect(find.text('Company deleted.'), findsOneWidget);
    // Modules: Mechanical is never deleted; HR (Off) – Live without a link is refused; deleted with its key typed
    await t.tap(find.byKey(const Key('sa-t-modules')));
    await net(t);
    await tapK(t, 'sa-m-mechanical');
    await net(t);
    expect(find.byKey(const Key('m-del')), findsNothing);
    await t.pageBack();
    await net(t);
    await tapK(t, 'sa-m-hr');
    await net(t);
    await tapIn(t, 'm-status', 'Live');
    await t.pump();
    await tapK(t, 'm-save');
    await net(t);
    expect(find.text('A module can be Live only with its link.'), findsOneWidget);
    await tapK(t, 'm-del');
    await net(t);
    await t.enterText(find.byKey(const Key('note-box')), 'hr');
    await tapK(t, 'note-ok');
    await net(t);
    expect(saves(srv).last, {'action': 'moduleDelete', 'key': 'hr', 'confirm': 'hr'});
    expect(find.text('Module deleted.'), findsOneWidget);
    expect(find.byKey(const Key('sa-m-hr')), findsNothing);
    // Activity: the last 200
    await t.tap(find.byKey(const Key('sa-t-audit')));
    await net(t);
    expect(srv.calls.where((c) => c == 'admin:audit').length, 1);
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('sujit@rcl.test → amol@rcl.test'), findsOneWidget);
    // his sign-in on the Portal ended: back to the sign-in, with the Portal's words
    srv.portalSignedIn = false;
    await t.tap(find.byKey(const Key('sa-reload')));
    await net(t);
    expect(find.byKey(const Key('sa-users')), findsNothing);
    expect(find.textContaining('तुमचा login संपला आहे'), findsOneWidget);
  });

  // ---------------- (3.26.0) calls with the web ----------------
  /// A note of the web (Mechanical's rtcBeat_ gives it with the heartbeat).
  Map<String, dynamic> rtcNote(String id, String t, String from, String name, String call, Map<String, dynamic> d) =>
      {'id': id, 'n': 50, 'from': from, 'name': name, 't': t, 'call': call, 'd': jsonEncode(d), 'age': 200};

  testWidgets('(3.26.0) Calls with the web: Home → Call – who is at the app, missed calls; a video call to a web user rings, his web answers → his screen big, his face and mine at the side; chat; Back → the green bar; End', (t) async {
    phone(t);
    final kit = FakeKit();
    Session.callKit = () => kit;
    addTearDown(() => Session.callKit = null);
    final srv = FakeServer()..rtcMissed = [{'call': 'c0', 'from': 'u-office', 'name': 'Office Admin', 'at': DateTime(2026, 10, 14, 9, 5).millisecondsSinceEpoch, 'can': true}];
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    final rtc = s.rtc!;
    var clock = DateTime(2026, 10, 14, 10, 30).millisecondsSinceEpoch;
    rtc.now = () => clock;
    expect(srv.rtcBeats.first, isNull, reason: 'the first heartbeat: "just opened" – the rings still waiting come');
    await t.tap(find.byKey(const Key('home-menu'))); // (3.31.0) Call is in the menu (≡)
    await settle(t, 600);
    await t.tap(find.byKey(const Key('home-call')));
    await net(t);
    await settle(t, 1600);
    expect(srv.rtcSent.where((m) => m['t'] == 'who'), isNotEmpty, reason: '"who is at the app?" – as the web asks');
    expect(srv.rtcBeats, contains(40), reason: 'then the heartbeat says up to which note it has read');
    rtc.inbox({'r': 41, 'top': 41, 'm': [rtcNote('h1', 'here', 'u-mahesh', 'Mahesh Jadhav', '', {'busy': false, 'share': true, 'dev': 'dM'})]});
    clock += 6000;
    await settle(t, 1200);
    expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('call-st-u-mahesh')), matching: find.byType(Text))).data, 'at the app now');
    expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('call-st-u-office')), matching: find.byType(Text))).data, 'not at the app now – the ring waits a minute');
    expect(find.text('Missed calls'), findsOneWidget);
    expect(find.byKey(const Key('call-back-u-office')), findsOneWidget);
    await tapK(t, 'call-u-u-mahesh');
    await tapK(t, 'call-mode-video');
    await settle(t, 300);
    expect(find.text('Call Mahesh Jadhav'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/55_call_pick.png'));

    await t.tap(find.byKey(const Key('call-go')));
    await net(t);
    final ring = srv.rtcSent.lastWhere((m) => m['t'] == 'ring');
    expect(ring['to'], ['u-mahesh']);
    expect((ring['d'] as Map)['mode'], 'video');
    expect((ring['d'] as Map)['sdp'], 'v=0 app-offer');
    expect(find.byKey(const Key('call-status')), findsOneWidget, reason: 'the call\'s screen');
    expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('call-status')), matching: find.byType(Text))).data, 'Ringing…');
    final pc = kit.pcs.single;
    // his web page answers; connected; he shows his screen and his camera
    rtc.inbox({'r': 42, 'top': 42, 'm': [rtcNote('a1', 'answer', 'u-mahesh', 'Mahesh Jadhav', rtc.call!.id, {'sdp': 'v=0 web-answer', 'todev': rtc.dev, 'dev': 'dM'})]});
    await net(t, 400);
    expect(pc.remotes.single, {'type': 'answer', 'sdp': 'v=0 web-answer'});
    pc.connect();
    pc.dc!.recv({'t': 'share', 'on': true, 'sid': 'S1', 'uid': 'u-mahesh', 'name': 'Mahesh Jadhav', 'ptr': false, 'kind': 'screen'});
    pc.picture('S1');
    pc.dc!.recv({'t': 'share', 'on': true, 'sid': 'face-1', 'uid': 'u-mahesh', 'name': 'Mahesh Jadhav', 'ptr': false, 'kind': 'cam', 'face': true});
    pc.picture('face-1');
    await settle(t, 600);
    expect(find.byKey(const ValueKey('fake-view-S1')), findsOneWidget, reason: 'his screen big');
    expect(find.byKey(const Key('call-face-face-1')), findsOneWidget, reason: 'his face at the side');
    expect(find.byKey(const Key('call-face-me')), findsOneWidget, reason: 'mine ("You")');
    expect(find.text('Screen of Mahesh Jadhav'), findsOneWidget);
    expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('call-status')), matching: find.byType(Text))).data, '00:00 · direct connection');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/57_call.png'));

    // chat
    await t.tap(find.byKey(const Key('call-chat')));
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('chat-txt')), 'Can you see the dispenser?');
    await t.tap(find.byKey(const Key('chat-send')));
    await settle(t, 300);
    expect(pc.dc!.of('chat').single['txt'], 'Can you see the dispenser?');
    expect(find.text('Can you see the dispenser?'), findsOneWidget);
    Navigator.of(t.element(find.byKey(const Key('chat-txt')))).pop();
    await settle(t, 600);
    // Back: the call goes on – the green bar over the app
    await t.tap(find.byKey(const Key('call-min')));
    await settle(t, 800);
    expect(find.byKey(const Key('call-bar')), findsOneWidget);
    expect(find.byKey(const Key('call-status')), findsNothing);
    await t.tap(find.byKey(const Key('call-bar')));
    await settle(t, 800);
    expect(find.byKey(const Key('call-status')), findsOneWidget, reason: 'the bar goes back to the call');
    await t.tap(find.byKey(const Key('call-end')));
    await net(t);
    expect(rtc.call, isNull);
    expect(pc.dc!.of('bye').single, {'t': 'bye', 'end': true});
    expect(srv.rtcSent.where((m) => m['t'] == 'end').single['to'], ['u-mahesh'], reason: 'one line for the Activity Log');
    expect(find.byKey(const Key('call-status')), findsNothing);
    expect(find.byKey(const Key('call-bar')), findsNothing);
    expect(kit.keeps.last, 'off');
  }, tags: ['golden']);

  testWidgets('(3.26.0) A call of the web comes in: its own screen over the app (the ringtone) → Accept → the answer to the web page that rang → Back → the green bar; the web ends it', (t) async {
    phone(t);
    final kit = FakeKit();
    Session.callKit = () => kit;
    addTearDown(() => Session.callKit = null);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    final rtc = s.rtc!;
    rtc.inbox({'r': 41, 'top': 41, 'm': [rtcNote('r1', 'ring', 'u-office', 'Office Admin', 'cW1', {'sdp': 'v=0 web-offer', 'people': ['Sujit Mule'], 'mode': 'screen', 'dev': 'dO'})]});
    await settle(t, 900);
    expect(kit.rings, [true]);
    expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('ring-name')), matching: find.byType(Text))).data, 'Office Admin');
    expect(find.text('wants to show you a screen'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/56_ring.png'));
    await t.tap(find.byKey(const Key('ring-accept')));
    await net(t);
    expect(kit.rings.last, false);
    final ans = srv.rtcSent.lastWhere((m) => m['t'] == 'answer');
    expect(ans['to'], ['u-office']);
    expect((ans['d'] as Map)['todev'], 'dO');
    expect((ans['d'] as Map)['sdp'], 'v=0 app-answer');
    expect(find.byKey(const Key('ring-name')), findsNothing);
    final pc = kit.pcs.single;
    expect(pc.remotes.first, {'type': 'offer', 'sdp': 'v=0 web-offer'});
    pc.connect(channelFromOther: true);
    await settle(t, 400);
    expect(find.text('Leave'), findsOneWidget, reason: 'a guest leaves; the host ends');
    await t.tap(find.byKey(const Key('call-min')));
    await settle(t, 800);
    expect(find.byKey(const Key('call-bar')), findsOneWidget);
    await t.tap(find.byKey(const Key('call-bar-mic')));
    await settle(t, 300);
    expect(rtc.call!.micOn, false, reason: 'mute from the bar');
    pc.dc!.recv({'t': 'bye', 'end': true});
    await settle(t, 800);
    expect(rtc.call, isNull);
    expect(find.byKey(const Key('call-bar')), findsNothing);
    expect(find.text('Office Admin ended the call.'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.26.0) A call declined with a short reply; one the caller stopped is missed – the number on the call button', (t) async {
    phone(t);
    final kit = FakeKit();
    Session.callKit = () => kit;
    addTearDown(() => Session.callKit = null);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    final rtc = s.rtc!;
    rtc.inbox({'r': 41, 'top': 41, 'm': [rtcNote('r1', 'ring', 'u-mahesh', 'Mahesh Jadhav', 'cW2', {'sdp': 'v=0', 'mode': 'voice', 'dev': 'dM'})]});
    await settle(t, 900);
    expect(find.text('Voice call'), findsOneWidget);
    await t.tap(find.byKey(const Key('ring-reply')));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('ring-reply-3')));
    await net(t);
    final dec = srv.rtcSent.lastWhere((m) => m['t'] == 'decline');
    expect((dec['d'] as Map)['reply'], 3);
    expect((dec['d'] as Map)['todev'], 'dM');
    expect(find.text('Sent to Mahesh Jadhav: "Please call me on the phone."'), findsOneWidget);
    expect(find.byKey(const Key('ring-name')), findsNothing);
    rtc.inbox({'r': 42, 'top': 42, 'm': [rtcNote('r2', 'ring', 'u-mahesh', 'Mahesh Jadhav', 'cW3', {'sdp': 'v=0', 'mode': 'video', 'dev': 'dM'})]});
    await settle(t, 600);
    rtc.inbox({'r': 43, 'top': 43, 'm': [rtcNote('x2', 'cancel', 'u-mahesh', 'Mahesh Jadhav', 'cW3', {'dev': 'dM'})]});
    await settle(t, 900);
    expect(find.byKey(const Key('ring-name')), findsNothing);
    expect(find.text('Missed call from Mahesh Jadhav.'), findsOneWidget);
    expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsWidgets);
  });

  // ---------------- (3.27.0) the app lock ----------------
  testWidgets('(3.27.0) The app lock: the app opens locked – the phone is asked by itself; not him → still locked; Unlock → the app; more than a minute away → locked again', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    final g = FakeGate()..answers.add(const LockAnswer(LockOutcome.no));
    final lock = AppLock(g);
    var now = DateTime(2026, 10, 14, 10, 30);
    lock.clock = () => now;
    await t.pumpWidget(RclApp(session: s, lock: lock));
    await net(t);
    expect(g.asked, 1, reason: 'the phone\'s box comes by itself');
    expect(find.byKey(const Key('lock-screen')), findsOneWidget);
    expect(find.text('RCL ERP is locked'), findsOneWidget);
    expect(find.text('Not unlocked – press Unlock and try again.'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/58_lock.png'));
    await t.tap(find.byKey(const Key('lock-unlock')));
    await settle(t, 600);
    expect(g.asked, 2);
    expect(find.byKey(const Key('lock-screen')), findsNothing);
    expect(find.text('Home'), findsWidgets, reason: 'the app');
    // 30 s away: still open; 2 minutes away: locked, asked again by itself
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 30));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t, 600);
    expect(find.byKey(const Key('lock-screen')), findsNothing);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2));
    g.answers.add(const LockAnswer(LockOutcome.no));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t, 600);
    expect(find.byKey(const Key('lock-screen')), findsOneWidget);
    expect(g.asked, 3);
    await t.tap(find.byKey(const Key('lock-unlock')));
    await settle(t, 600);
    expect(find.byKey(const Key('lock-screen')), findsNothing);
  }, tags: ['golden']);

  testWidgets('(3.27.0) A phone with no screen lock: the app opens, with a red line to set one; signed out: no lock screen', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    final g = FakeGate()..answers.add(const LockAnswer(LockOutcome.noLock));
    await t.pumpWidget(RclApp(session: s, lock: AppLock(g)));
    await net(t);
    expect(find.byKey(const Key('lock-screen')), findsNothing);
    expect(find.textContaining('This phone has no screen lock'), findsOneWidget);
    final s2 = make(FakeServer());
    await t.runAsync(s2.start);
    final g2 = FakeGate();
    await t.pumpWidget(RclApp(session: s2, lock: AppLock(g2)));
    await net(t);
    expect(find.byKey(const Key('lock-screen')), findsNothing, reason: 'nothing of the ERP is open before a sign-in');
    expect(g2.asked, 0);
  });

  // ---------------- (3.31.0) the new look from his picture ----------------
  testWidgets('(3.31.0) ≡ the menu (every module, Call, Help); the + (only what he may add); a half-filled Diesel Issue brought back, Start new; Back one step; Reports – Overview', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await pics(t);
    expect(find.text('Good Morning,'), findsOneWidget, reason: '10:30 in the morning');
    // ≡
    await t.tap(find.byKey(const Key('home-menu')));
    await settle(t, 600);
    expect(find.byKey(const Key('menu-Machinery')), findsOneWidget);
    expect(find.byKey(const Key('menu-Billing')), findsNothing, reason: 'no access – not in the menu either');
    expect(find.byKey(const Key('menu-help')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/59_menu.png'));
    await t.tapAt(const Offset(350, 400));
    await settle(t, 600);
    // the +
    await t.tap(find.byKey(const Key('tab-plus')));
    await settle(t, 600);
    expect(find.byKey(const Key('plus-Diesel Issue')), findsOneWidget);
    expect(find.byKey(const Key('plus-Diesel Inward')), findsNothing, reason: 'Diesel Inward: View only');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/60_plus.png'));
    await t.tap(find.byKey(const Key('plus-Diesel Issue')));
    await net(t);
    // half filled, then the form closed (the phone's Back)
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    await t.tap(find.text('Sany 210 (No.1)'));
    await settle(t, 800);
    await t.enterText(find.byType(TextField).at(1), '45');
    await settle(t, 900);
    expect(find.byKey(const Key('draft-back')), findsNothing, reason: 'nothing brought back the first time');
    await t.binding.handlePopRoute();
    await net(t);
    expect(find.text('Pick the machinery'), findsNothing);
    // opened again: brought back
    await t.tap(find.byKey(const Key('tab-plus')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('plus-Diesel Issue')));
    await net(t);
    expect(find.byKey(const Key('draft-back')), findsOneWidget);
    expect(find.text('Sany 210 (No.1)'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/61_draft.png'));
    await t.tap(find.byKey(const Key('draft-new')));
    await settle(t, 900);
    expect(find.byKey(const Key('draft-back')), findsNothing);
    expect(find.text('Pick the machinery'), findsOneWidget, reason: 'Start new: the boxes emptied');
    await t.binding.handlePopRoute();
    await net(t);
    await t.tap(find.byKey(const Key('tab-plus')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('plus-Diesel Issue')));
    await net(t);
    expect(find.byKey(const Key('draft-back')), findsNothing, reason: 'Start new: nothing kept');
    await t.binding.handlePopRoute();
    await net(t);
    // Back one step: Entries → Diesel Issue → (Back) the Entries list → (Back) Home → (Back) "Press Back again"
    await t.tap(find.text('Entries'));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    expect(find.text('4 entries · 240 L'), findsOneWidget);
    await t.binding.handlePopRoute();
    await net(t);
    expect(find.byKey(const Key('entries-Diesel Inward')), findsOneWidget, reason: 'back to the list of entries – not out of it');
    await t.binding.handlePopRoute();
    await net(t);
    expect(find.byKey(const Key('home-menu')), findsOneWidget, reason: 'then Home');
    await t.binding.handlePopRoute();
    await settle(t, 400);
    expect(find.text('Press Back again to leave the app.'), findsOneWidget);
    await settle(t, 4500);
    // Reports – Overview: the figures of the month from the server's answers
    srv.dashAsked.clear();
    await t.tap(find.text('Reports').last);
    await net(t, 2500);
    expect(srv.dashAsked.where((x) => x['fn'] == 'getDashboard').map((x) => (x['args'] as List).first), contains(equals({'from': '2026-10-01', 'to': '2026-10-14'})), reason: 'this month');
    expect(srv.dashAsked.where((x) => x['fn'] == 'getDashboard').map((x) => (x['args'] as List).first), contains(equals({'from': '2026-09-17', 'to': '2026-09-30'})), reason: 'the same 14 days just before');
    expect(srv.dashAsked.any((x) => x['fn'] == 'logDashboard'), true);
    expect(find.byKey(const Key('ov-used')), findsOneWidget);
    expect(find.byKey(const Key('ov-trend')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/62_reports_overview.png'));
  }, tags: ['golden']);


  // ---------- (3.34.0, Mechanical update-153) attachments of a Log Book entry ----------
  Uint8List attPhoto() {
    final im = img.Image(width: 320, height: 240);
    img.fill(im, color: img.ColorRgb8(30, 41, 59));
    img.fillRect(im, x1: 64, y1: 36, x2: 256, y2: 204, color: img.ColorRgb8(248, 250, 252));
    return Uint8List.fromList(img.encodeJpg(im, quality: 90));
  }
  final attPdf = Uint8List.fromList(utf8.encode('%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'));
  void attHooks() {
    final p0 = pickAttFiles, c0 = attCompute;
    attCompute = <M, R>(ComputeCallback<M, R> cb, M m, {String? debugLabel}) async => await cb(m);      // (the photo is made at once)
    addTearDown(() {
      pickAttFiles = p0;
      attCompute = c0;
    });
  }

  testWidgets('(3.34.0 – update-153) attachments: a photo from the gallery and a PDF on a new Log Book entry – sent when it is saved; the entry keeps their fingerprints; the same photo twice is refused', (t) async {
    phone(t);
    attHooks();
    final photo = attPhoto();
    pickAttFiles = (how, room) async => how == 'pdf' ? [(name: 'challan.pdf', bytes: attPdf)] : [(name: 'meter.jpg', bytes: photo)];
    final srv = FakeServer()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook').last);
    await net(t);
    await t.tap(find.text('New Entry'));
    await net(t);
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    await t.tap(find.text('MH-25-AJ-2169'));
    await net(t);
    await t.enterText(find.widgetWithText(TextField, 'Close'), '15350');
    await settle(t, 300);
    await t.ensureVisible(find.byKey(const Key('att-gal')));
    await settle(t, 300);
    expect(find.text('None yet – optional.'), findsOneWidget);
    await t.tap(find.byKey(const Key('att-gal')));
    await net(t);
    await t.tap(find.byKey(const Key('att-pdf')));
    await net(t);
    expect(find.byKey(const Key('att-tile-0')), findsOneWidget);
    expect(find.byKey(const Key('att-tile-1')), findsOneWidget);
    expect(find.textContaining('2 of 10'), findsOneWidget, reason: 'the site\'s number: 10 unless set');
    expect(srv.uploads, isEmpty, reason: 'nothing is sent before the entry is saved');
    await t.tap(find.byKey(const Key('att-gal')));
    await net(t);
    expect(find.textContaining('is already attached – it is not added twice'), findsOneWidget);
    expect(find.byKey(const Key('att-tile-2')), findsNothing);
    await t.tap(find.text('Save Log Book'));
    await net(t);
    expect(srv.uploads.map((u) => '${u['mime']} ${u['name']}').toList(), ['image/jpeg meter.jpg', 'application/pdf challan.pdf']);
    final row = srv.logSaved.single;
    expect(row['attachments'], [{'sha': srv.uploads[0]['sha']}, {'sha': srv.uploads[1]['sha']}]);
    expect(find.text('Log Book saved'), findsOneWidget);
  });

  testWidgets('(3.34.0 – update-153) a change: the entry\'s files shown; one taken out – sent with what it had when opened (attWas); nothing else is changed', (t) async {
    phone(t);
    attHooks();
    final srv = FakeServer()
      ..perms['Log Book'] = 'Edit'
      ..entryAtt = [
        {'sha': 'a' * 64, 'p': 'log/aa/${'a' * 64}.jpg', 'mime': 'image/jpeg', 'size': 120000, 'name': 'meter.jpg', 'by': 'Op', 'at': '2026-10-14T03:00:00Z'},
        {'sha': 'b' * 64, 'p': 'log/bb/${'b' * 64}.pdf', 'mime': 'application/pdf', 'size': 30000, 'name': 'challan.pdf', 'by': 'Op', 'at': '2026-10-14T03:00:00Z'},
      ];
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.push(MaterialPageRoute<bool>(builder: (_) => const LogForm(editKey: 'MH-25-AJ-2169|2026-10-14|Full Day'))));
    await net(t);
    await t.ensureVisible(find.byKey(const Key('att-tile-1')));
    await settle(t, 300);
    expect(find.byKey(const Key('att-tile-0')), findsOneWidget);
    await t.tap(find.byKey(const Key('att-rm-1')));
    await settle(t, 300);
    expect(find.textContaining('nothing is deleted'), findsOneWidget);
    await t.tap(find.text('Save the change'));
    await net(t);
    final ch = srv.logSaved.single;
    expect(ch['update'], 'MH-25-AJ-2169|2026-10-14|Full Day');
    expect(ch['attachments'], [{'sha': 'a' * 64}]);
    expect(ch['attWas'], ['a' * 64, 'b' * 64]);
    expect(srv.uploads, isEmpty, reason: 'the kept files are not sent again');
  });

  testWidgets('(3.34.0 – update-153) Scan with Mobile: the computer\'s QR code → the same person\'s phone takes a photo and sends it (uploadAttachment, then capAdd with the code and this phone); a code that is not valid says so', (t) async {
    phone(t);
    attHooks();
    final photo = attPhoto();
    pickAttFiles = (how, room) async => [(name: 'phone.jpg', bytes: photo)];
    final srv = FakeServer()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => CaptureScreen(code: srv.capCodeOk))));
    await net(t);
    expect(find.text('MH-25-AJ-2169 · 14-10-2026 · Day'), findsOneWidget);
    await t.tap(find.byKey(const Key('att-cam')));
    await net(t);
    expect(find.byKey(const Key('att-tile-0')), findsOneWidget);
    await t.tap(find.byKey(const Key('cap-send')));
    await net(t);
    expect(srv.uploads.length, 1);
    final add = srv.capAdds.single;
    expect([add['code'], add['shas'], RegExp(r'^p-[0-9a-f]{24}$').hasMatch('${add['phone']}')], [srv.capCodeOk, [srv.uploads[0]['sha']], true]);
    expect(find.textContaining('1 sent ✓'), findsOneWidget);
    nav.pop();
    await net(t);
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => CaptureScreen(code: '${'c' * 32}.${'d' * 64}'))));
    await net(t);
    expect(find.textContaining('This QR code is not valid'), findsOneWidget);
    expect(find.byKey(const Key('cap-send')), findsNothing);
  });

  // ---------------- (3.41.0 – update-160) the QR code of "Scan with Mobile" read by the phone's camera / Google Lens ----------------
  testWidgets('(3.41.0) A "Scan with Mobile" QR code read by the phone\'s camera / Google Lens opens in the app: at another of his sites → that site is opened by itself, then the photos screen; the same link again: once; a site not given to him: said; the app\'s own Scan the same way', (t) async {
    phone(t);
    ScanLink.i.reset();
    addTearDown(ScanLink.i.reset);
    final srv = FakeServer()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(s.site!.code, 'S1');
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.push(MaterialPageRoute<bool>(builder: (_) => const LogForm(editKey: 'MH-25-AJ-2169|2026-10-14|Full Day'))));
    await net(t);
    // the link as Android gives it to the app (the QR code made at the computer of site T2)
    final u = 'https://oneclicksolution-erp.vercel.app/scan?cap=${srv.capCodeOk}&site=T2';
    ScanLink.i.take(u);
    await net(t);
    await net(t);
    expect(s.site!.code, 'T2', reason: 'his other site opened by itself – nothing to choose');
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.text('MH-25-AJ-2169 · 14-10-2026 · Day'), findsOneWidget);
    expect(find.byType(LogForm), findsNothing, reason: 'the screen of the site before is not left open under it');
    expect(ScanLink.i.code, '');
    nav.pop();
    await net(t);
    ScanLink.i.take(u);
    await net(t);
    expect(find.byType(CaptureScreen), findsNothing, reason: 'the same link again: opened once');
    // a site that is not given to him: said, nothing opened, his site stays
    ScanLink.i.take('https://oneclicksolution-erp.vercel.app/scan?cap=${'e' * 32}.${'f' * 64}&site=ZZ9');
    await net(t);
    expect(find.textContaining('This QR code is for site ZZ9 – that site is not given to you.'), findsOneWidget);
    expect(find.byType(CaptureScreen), findsNothing);
    expect([s.site!.code, ScanLink.i.code], ['T2', '']);
    await settle(t, 4000);
    // the app's own Scan: the same way (a QR code of site S1: S1 opened again first)
    QrScanScreen.cameraForTest = (found) => GestureDetector(key: const Key('qr-cam'), onTap: () => found('https://oneclicksolution-erp.vercel.app/scan?cap=${'c' * 32}.${'d' * 64}&site=S1'), child: const ColoredBox(color: Color(0xFF3B4A40)));
    addTearDown(() => QrScanScreen.cameraForTest = null);
    await t.tap(find.byKey(const Key('home-scan')));
    await net(t);
    await t.tap(find.byKey(const Key('qr-cam')));
    await net(t);
    await net(t);
    expect(s.site!.code, 'S1');
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.textContaining('This QR code is not valid'), findsOneWidget, reason: 'the server checks the code, as before');
  });

  // ---------------- (3.42.0) a notification of Firebase pressed (core/push.dart PushTap) ----------------
  testWidgets('(3.42.0) A notification pressed: Approvals at ITS site (another of his sites opened by itself, the screen before closed); a missed call → Call with its missed calls', (t) async {
    phone(t);
    ScanLink.i.reset();
    addTearDown(ScanLink.i.reset);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(s.site!.code, 'S1');
    ScanLink.i.open(const PushTap('cr', 'T2', id: 'VF-1'));
    await net(t);
    await net(t);
    expect(s.site!.code, 'T2', reason: 'the approval is at T2: that site opened by itself');
    expect(find.byType(ApprovalsScreen), findsOneWidget);
    expect(ScanLink.i.tap, isNull, reason: 'opened once');
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await net(t);
    ScanLink.i.open(const PushTap('missed', 'T2', call: 'k1'));
    await net(t);
    expect(find.byType(CallPickScreen), findsOneWidget);
  });

  testWidgets('(3.41.0) The QR code\'s link waits – nothing is lost: the app locked → opened after the fingerprint; signed out → opened after the sign-in (at the QR code\'s site)', (t) async {
    phone(t);
    ScanLink.i.reset();
    addTearDown(ScanLink.i.reset);
    final srv = FakeServer()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    final g = FakeGate()..answers.add(const LockAnswer(LockOutcome.no));
    ScanLink.i.take('https://oneclicksolution-erp.vercel.app/scan?cap=${srv.capCodeOk}&site=S1'); // (the link the app was opened with)
    await t.pumpWidget(RclApp(session: s, lock: AppLock(g)));
    await net(t);
    expect(find.byKey(const Key('lock-screen')), findsOneWidget);
    expect(find.byType(CaptureScreen), findsNothing, reason: 'nothing of the ERP before the fingerprint');
    expect(ScanLink.i.code, srv.capCodeOk, reason: 'kept');
    await t.tap(find.byKey(const Key('lock-unlock')));
    await net(t);
    expect(find.byKey(const Key('lock-screen')), findsNothing);
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.text('MH-25-AJ-2169 · 14-10-2026 · Day'), findsOneWidget);
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await net(t);
    expect(find.byType(CaptureScreen), findsNothing);
    // signed out: kept until the sign-in, then his site of the QR code (T2) – not the list of sites
    ScanLink.i.reset();
    final srv2 = FakeServer()..perms['Log Book'] = 'Edit';
    final s2 = make(srv2);
    await t.runAsync(s2.start);
    await t.pumpWidget(RclApp(session: s2));
    await net(t);
    expect(s2.stage, Stage.signedOut);
    ScanLink.i.take('https://oneclicksolution-erp.vercel.app/scan?cap=${srv2.capCodeOk}&site=T2');
    await net(t);
    expect(find.byType(CaptureScreen), findsNothing);
    expect(ScanLink.i.code, srv2.capCodeOk, reason: 'kept until he is signed in');
    await t.runAsync(() => s2.signIn('sujit@rcl.test', 'Nashik#Road848!'));
    await net(t);
    await net(t);
    expect(s2.site?.code, 'T2');
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.text('MH-25-AJ-2169 · 14-10-2026 · Day'), findsOneWidget);
  });
}
