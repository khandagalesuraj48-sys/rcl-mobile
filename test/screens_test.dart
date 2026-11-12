/* The app's screens on a phone (360 × 780) with the pretend servers: what a person sees and does.
 * The tests tagged "golden" also make pictures of the screens (test/goldens/) – for looking at, in the build's files. */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ComputeCallback, TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/attend.dart' show AttendKit;
import 'package:rcl_mobile/screens/attendance.dart' show attendSelfieForTest;
import 'package:rcl_mobile/core/app_share.dart';
import 'package:rcl_mobile/ui/goo_toast.dart' show gooClear;
import 'package:rcl_mobile/core/applock.dart';
import 'package:rcl_mobile/core/lang.dart';
import 'package:rcl_mobile/core/masters.dart' show gstCheckLetter;
import 'package:rcl_mobile/core/scan_link.dart';
import 'package:rcl_mobile/core/push.dart' show PushTap;
import 'package:rcl_mobile/screens/approvals.dart' show ApprovalsScreen;
import 'package:rcl_mobile/screens/call.dart' show CallPickScreen;
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/core/sitewords.dart';
import 'package:rcl_mobile/core/sheet_read.dart';
import 'package:rcl_mobile/main.dart';
import 'package:rcl_mobile/screens/label_scan.dart' show QrScanScreen;
import 'package:rcl_mobile/core/voice.dart' as voice;
import 'package:rcl_mobile/screens/assistant.dart' show AiHistoryScreen, AiMemoryScreen, AssistantScreen, forgetChat, moduleLook;
import 'package:rcl_mobile/screens/logbook.dart' show LogForm, LogBookScreen;
import 'package:rcl_mobile/screens/home.dart' show reportsOf;
import 'package:rcl_mobile/screens/start_page.dart' show startPagesFor;
import 'package:rcl_mobile/core/attach.dart' show attCompute;
import 'package:rcl_mobile/screens/attach_box.dart' show pickAttFiles, CaptureScreen;
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:rcl_mobile/core/car_photos.dart';
import 'package:rcl_mobile/core/veh_alerts.dart';
import 'package:rcl_mobile/screens/car_detail.dart' show CarPhotoPick;
import 'package:rcl_mobile/screens/super_delete.dart' show SuperDeleteScreen;
import 'package:rcl_mobile/ui/help.dart' show helpPicked;
import 'package:rcl_mobile/ui/theme.dart' show C;
import 'package:rcl_mobile/ui/fields.dart' show TextBox, PickField, DateField;
import 'package:rcl_mobile/screens/maintenance.dart' show AiBox;
import 'package:rcl_mobile/ui/outputs.dart' show fileSink;
import 'package:rcl_mobile/ui/pick_file.dart';
import 'package:rcl_mobile/screens/pend_print.dart' show PendPrintScreen;
import 'package:rcl_mobile/screens/machinery.dart' show vendorNames;
import 'package:rcl_mobile/screens/store_work.dart' show storePaperSink, rs, PoDetailScreen;
import 'package:rcl_mobile/core/grn_reg.dart';

import 'package:rcl_mobile/screens/vehicle_booking.dart' show openBooking;
import 'package:rcl_mobile/screens/vehicle_expenses.dart' show openVexp;
import 'fake_rtc.dart';
import 'lock_test.dart' show FakeGate;
import 'fake_attend.dart';
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

/// (3.86.0) a drawn picture of a car (the tests' "photo"): sky, road, body, windows, wheels
Uint8List carPng({int w = 320, int h = 240, int r = 238, int g = 240, int b = 242}) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    final k = y / h;
    final c = y < h * .72 ? img.ColorRgb8((120 - 40 * k).round(), (150 - 40 * k).round(), (175 - 40 * k).round()) : img.ColorRgb8(60, 66, 72);
    img.drawLine(im, x1: 0, y1: y, x2: w - 1, y2: y, color: c);
  }
  double sx(double x) => x * w / 320;
  double sy(double y) => y * h / 200;
  img.fillPolygon(im, vertices: [for (final p in const [[52, 140], [70, 108], [96, 94], [206, 92], [236, 104], [262, 124], [278, 140], [278, 150], [52, 150]]) img.Point(sx(p[0].toDouble()), sy(p[1].toDouble()))], color: img.ColorRgb8(r, g, b));
  img.fillPolygon(im, vertices: [for (final p in const [[92, 106], [108, 98], [156, 97], [156, 120], [84, 121]]) img.Point(sx(p[0].toDouble()), sy(p[1].toDouble()))], color: img.ColorRgb8(40, 55, 68));
  img.fillPolygon(im, vertices: [for (final p in const [[164, 97], [204, 97], [226, 108], [236, 120], [164, 120]]) img.Point(sx(p[0].toDouble()), sy(p[1].toDouble()))], color: img.ColorRgb8(40, 55, 68));
  for (final cx in const [102.0, 234.0]) {
    img.fillCircle(im, x: sx(cx).round(), y: sy(150).round(), radius: sy(17).round(), color: img.ColorRgb8(27, 34, 40));
    img.fillCircle(im, x: sx(cx).round(), y: sy(150).round(), radius: sy(7).round(), color: img.ColorRgb8(154, 164, 172));
  }
  return Uint8List.fromList(img.encodePng(im));
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

/// (3.91.0) picks [v] in an open pickFromList sheet: its search box first (a long list builds only what is on the screen)
Future<void> pickIn(WidgetTester t, String v) async {
  final box = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
  if (box.evaluate().isNotEmpty) {
    await t.enterText(box.first, v);
    await settle(t, 400);
  }
  await t.tap(find.byKey(Key('pick-$v')));
  await settle(t, 600);
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
  await seen(t, f);
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.tap(f);
}

/// (3.99.0) Brings [f] onto the screen where a finger can reach it: Home's small bar now stays at the top while the page is
/// scrolled, so a thing brought to the very top would be under it – the page is then pulled down a little.
Future<void> seen(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
    final bar = find.byWidgetPredicate((w) => w.key == const Key('home-mini') || w.key == const Key('me-mini')).hitTestable();
    if (bar.evaluate().isEmpty || t.getRect(f.first).top >= t.getRect(bar.first).bottom + 4) break;
    await t.drag(find.ancestor(of: f.first, matching: find.byType(Scrollable)).last, const Offset(0, 110));
  }
}

void main() {
  setUpAll(loadFonts);
  tearDown(() => Lang.i.set('')); // (15-10-2026) every test starts in the app's usual language
  // (3.86.0) HO's cars: a picture is read from its link with no network in the tests (no timer left behind); every test starts with none kept
  setUp(() {
    CarPhotos.i.clear();
    VehAlerts.i.clear();      // (3.88.0) no test sees another's alerts
    CarPhotos.fetch = (u) async => http.Response.bytes(carPng(), 200);
  });
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
    await seen(t, find.text('Send again (VF-00007)'));
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
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    await seen(t, find.text('Approvals').first);
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
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    await seen(t, find.text('Approvals').first);
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
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    await seen(t, find.text('Approvals').first);
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
    await t.tap(find.byKey(const Key('tab-reports')));
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

  testWidgets('(3.89.0, Mechanical update-214) Reports → Machinery: the Driver-wise Report and the Machinery Cost Sheet with Maintenance', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-reports')));
    await net(t);
    await t.tap(find.byKey(const Key('rt-machinery')));
    await net(t);
    expect(find.text('Driver-wise Report'), findsOneWidget);
    await t.tap(find.text('Driver-wise Report'));
    await net(t);
    await tapK(t, 'rep-go');
    await net(t);
    expect(srv.reportAsked.last['fn'], 'rptDriver');
    expect(find.byKey(const Key('rtable-Summary')), findsOneWidget);
    expect(find.text('Ramesh Pawar'), findsWidgets);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9n_report_driver.png'));
  }, tags: ['golden']);

  testWidgets('(3.89.0, Mechanical update-214) the Machinery Cost Sheet with Maintenance (its bills + the Store\'s outward)', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-reports')));
    await net(t);
    await t.tap(find.byKey(const Key('rt-machinery')));
    await net(t);
    await t.tap(find.text('Machinery Cost Sheet'));
    await net(t);
    await tapK(t, 'rep-go');
    await net(t);
    expect(srv.reportAsked.last['fn'], 'rptMachineCost');
    expect(find.text('Maintenance (₹)'), findsWidgets);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9o_report_mcost.png'));
  }, tags: ['golden']);

  testWidgets('(3.91.0, Mechanical update-216) Vehicle Booking: asked (the form), decided with the vehicle and driver by one who approves, cancelled', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms['Vehicle Booking'] = 'Edit'
      ..perms['Booking Approve'] = 'Edit';
    srv.bookings.addAll([
      {'id': 'VB-000001', 'from': '2099-01-10T09:00', 'to': '2099-01-10T13:00', 'placeFrom': 'Head Office', 'placeTo': 'Pune site', 'purpose': 'Site visit', 'people': 3, 'no': '', 'driver': '', 'status': 'Requested', 'by': 'ram@rcl.test', 'byName': 'Ram Patil', 'reply': '', 'remark': ''},
      {'id': 'VB-000002', 'from': '2099-01-11T10:00', 'to': '2099-01-12T18:00', 'placeFrom': 'Head Office', 'placeTo': 'Mumbai', 'purpose': 'Bank meeting', 'people': 2, 'no': 'MH-25-AJ-2169', 'driver': 'Ganesh', 'status': 'Approved', 'by': 'sujit@rcl.test', 'byName': 'Sujit Mule', 'reply': 'OK', 'remark': ''},
    ]);
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    openBooking(t.element(find.byType(Scaffold).first));
    await net(t);
    expect(find.byKey(const Key('vb-VB-000001')), findsOneWidget);
    expect(find.byKey(const Key('vb-decide-VB-000001')), findsOneWidget, reason: 'one who approves decides a request');
    expect(find.byKey(const Key('vb-cancel-VB-000002')), findsOneWidget, reason: 'his own, not over: cancel');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9q_vehicle_booking.png'));
    // decided: the vehicle picked, the driver typed
    await tapK(t, 'vb-decide-VB-000001');
    await settle(t, 600);
    await tapK(t, 'vbd-no');
    await settle(t, 600);
    await pickIn(t, 'MH-25-AJ-2169');
    await t.enterText(find.descendant(of: find.byKey(const Key('vbd-driver')), matching: find.byType(TextField)), 'Suresh');
    await tapK(t, 'vbd-ok');
    await net(t);
    expect(srv.vbCalls.last, {'fn': 'decideBooking', 'id': 'VB-000001', 'x': {'approve': true, 'no': 'MH-25-AJ-2169', 'driver': 'Suresh', 'reply': ''}});
    // asked: the form
    await tapK(t, 'vb-ask');
    await net(t);
    await t.enterText(find.descendant(of: find.byKey(const Key('vbf-pto')), matching: find.byType(TextField)), 'Kolhapur 18B');
    await t.enterText(find.descendant(of: find.byKey(const Key('vbf-purpose')), matching: find.byType(TextField)), 'Inspection');
    await t.enterText(find.descendant(of: find.byKey(const Key('vbf-people')), matching: find.byType(TextField)), '4');
    await tapK(t, 'vbf-send');
    await net(t);
    final x = srv.vbCalls.last['x'] as Map;
    expect([srv.vbCalls.last['fn'], x['from'], x['to'], x['placeTo'], x['purpose'], x['people']], ['saveBooking', '2026-10-14T09:00', '2026-10-14T18:00', 'Kolhapur 18B', 'Inspection', '4']);
    expect(find.byKey(const Key('vb-VB-000003')), findsOneWidget, reason: 'back on the list, read again');
  }, tags: ['golden']);

  testWidgets('(3.91.0, Mechanical update-216) Vehicle Expenses: typed; the FASTag statement read, its lines on their vehicles, the ticked ones saved', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Vehicle Expenses'] = 'Edit';
    srv.vexp.addAll([
      {'id': 'VX-000001', 'date': '2026-10-05', 'no': 'MH-25-AJ-2169', 'kind': 'Toll', 'place': 'Khalapur toll', 'amount': 320, 'paidBy': 'FASTag', 'ref': '', 'txn': 'TX-1', 'source': 'Statement', 'remark': ''},
      {'id': 'VX-000002', 'date': '2026-10-09', 'no': 'MH-25-AJ-2169', 'kind': 'Parking', 'place': 'Phoenix Mall', 'amount': 80, 'paidBy': 'Cash', 'ref': '', 'txn': '', 'source': 'Hand', 'remark': ''},
    ]);
    srv.stmtAnswer = {'read': 3, 'matched': 2, 'saved': 1, 'rows': [
      {'date': '2026-10-05', 'time': '10:15', 'vehicle': 'MH25AJ2169', 'no': 'MH-25-AJ-2169', 'place': 'Khalapur toll', 'amount': 320, 'txn': 'TX-1', 'saved': 'VX-000001'},
      {'date': '2026-10-12', 'time': '11:40', 'vehicle': 'MH25AJ2169', 'no': 'MH-25-AJ-2169', 'place': 'Talegaon toll', 'amount': 1045, 'txn': 'TX-2', 'saved': ''},
      {'date': '2026-10-13', 'time': '12:00', 'vehicle': 'MH12ZZ0000', 'no': '', 'place': 'Urse toll', 'amount': 190, 'txn': 'TX-3', 'saved': ''},
    ]};
    pickStatementFile = () async => (name: 'fastag.csv', bytes: Uint8List.fromList(utf8.encode('Date,Vehicle,Plaza,Amount\n12-10-2026,MH25AJ2169,Talegaon,1045\n')));
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    openVexp(t.element(find.byType(Scaffold).first));
    await net(t);
    expect(find.byKey(const Key('vx-cars')), findsOneWidget);
    expect(find.byKey(const Key('vx-VX-000002')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9r_vehicle_expenses.png'));
    // typed
    await tapK(t, 'vx-add');
    await net(t);
    await tapK(t, 'vxf-no');
    await settle(t, 600);
    await pickIn(t, 'MH-25-AJ-2169');
    await t.enterText(find.descendant(of: find.byKey(const Key('vxf-place')), matching: find.byType(TextField)), 'Khed Shivapur toll');
    await t.enterText(find.descendant(of: find.byKey(const Key('vxf-amt')), matching: find.byType(TextField)), '245');
    await tapK(t, 'vxf-save');
    await net(t);
    expect(srv.vbCalls.last, {'fn': 'saveVexp', 'x': {'date': '2026-10-14', 'no': 'MH-25-AJ-2169', 'kind': 'Toll', 'place': 'Khed Shivapur toll', 'amount': '245', 'paidBy': 'FASTag', 'ref': '', 'remark': ''}});
    // the statement: an Excel / CSV sent as its rows; the line already saved not ticked, the one with no vehicle picked
    await tapK(t, 'vx-statement');
    await net(t);
    await tapK(t, 'vxs-pick');
    await net(t);
    expect((srv.vbCalls.last['x'] as Map)['text'], 'Date | Vehicle | Plaza | Amount\n12-10-2026 | MH25AJ2169 | Talegaon | 1045');
    expect(find.byKey(const Key('vxs-2')), findsOneWidget);
    await settle(t, 6500);      // (the toast "Saved …" of the form gone before the picture)
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9s_fastag_statement.png'));
    await tapK(t, 'vxs-no-2');
    await settle(t, 600);
    await pickIn(t, 'Sany 210 (No.1)');
    await tapK(t, 'vxs-save');
    await net(t);
    final rs = srv.vbCalls.last['rows'] as List;
    expect([srv.vbCalls.last['fn'], rs.map((r) => '${r['txn']}:${r['no']}').toList()], ['importVexp', ['TX-2:MH-25-AJ-2169', 'TX-3:Sany 210 (No.1)']], reason: 'the saved line not sent; the picked vehicle sent');
  }, tags: ['golden']);

  testWidgets('(3.2.0) Monthly Diesel & Average: the day-by-day table with its status, sideways on the phone', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-reports')));
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    await t.tap(find.byKey(const Key('tab-entries')));
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

  testWidgets('(3.85.0, asked 04-11-2026) NO NETWORK: the site opened before opens from this phone – Home says so; a Diesel Issue is kept on the phone at once (no question) with the stock as the phone knows it; the network back: sent by itself – kept as stock short when the stock cannot cover it', (t) async {
    phone(t);
    final srv = FakeServer(), keep = MemoryKeep();
    Session mk() => Session(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client))..clock = () => DateTime(2026, 10, 14, 10, 30);
    final s1 = mk();
    await t.runAsync(() async {
      await s1.signIn('sujit@rcl.test', 'Nashik#Road848!');
      await s1.chooseSite('S1');
    });
    srv
      ..portalDown = true
      ..down = true;
    final s = mk();
    await t.runAsync(s.start);
    expect([s.stage, s.offline], [Stage.ready, true]);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.textContaining('No network – working from this phone'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9a_offline_home.png'));
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await t.tap(find.text('New Entry').first);
    await net(t);
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    await t.tap(find.text('Sany 210 (No.1)'));
    await settle(t, 800);
    await t.enterText(find.byType(TextField).at(1), '60');
    await settle(t, 300);
    expect(find.textContaining('No network – stock at Dispenser as this phone knows it: 813 L → after this issue 753 L'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9b_offline_issue.png'));
    await t.tap(find.text('Save Diesel Issue'));
    await net(t);
    expect(srv.saved, isEmpty, reason: 'nothing reached the server');
    expect(s.kept.single['fn'], 'saveDieselIssue');
    expect(s.kept.single['made'], FakeServer.stamp, reason: 'with the server\'s last stamp');
    expect(find.textContaining('Kept on this phone'), findsWidgets);
    // the network is back: the live tick – the Portal and the site again, then the entry, as stock short
    srv
      ..portalDown = false
      ..down = false
      ..short = true;
    for (var i = 0; i < 6 && (s.offline || s.kept.isNotEmpty); i++) {      // (a tick of the live loop may be running: the next one)
      await t.runAsync(s.liveTick);
      await settle(t, 1000);
    }
    expect(s.offline, false);
    expect(s.kept, isEmpty);
    expect(srv.metas.lastWhere((m) => m['fn'] == 'saveDieselIssue'), {'fn': 'saveDieselIssue', 'made': FakeServer.stamp, 'short': true});
  }, tags: ['golden']);

  testWidgets('(3.76.0, Mechanical update-203) Diesel Issue: a tank check due with the fill – its box; not saved without it; saved with it', (t) async {
    phone(t);
    final srv = FakeServer()..tankDueAns = {'no': 'Sany 210 (No.1)', 'date': '2026-10-14', 'due': true, 'days': 7, 'last': '2026-10-05', 'start': '2026-10-06', 'cap': 300, 'gone': 8};
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await t.tap(find.text('New Entry'));
    await net(t);
    await t.tap(find.text('Pick the machinery'));
    await settle(t, 800);
    await t.tap(find.text('Sany 210 (No.1)'));
    await net(t);
    expect(srv.tankDueAsked.last, {'no': 'Sany 210 (No.1)', 'date': '2026-10-14'});
    await t.enterText(find.byType(TextField).at(1), '60');
    await settle(t, 300);
    await seen(t, find.byKey(const Key('f-tc')));
    await settle(t, 300);
    expect(find.text('the last one on 05-10-2026, a check every 7 days. Measure the tank before filling.'), findsOneWidget);
    await t.tap(find.text('Save Diesel Issue'));
    await net(t);
    expect(srv.saved, isEmpty, reason: 'not sent without the check');
    expect(find.text('Tank check due: type the diesel found in the tank before filling.'), findsOneWidget);
    await t.enterText(find.byKey(const Key('f-tc-ph')), '40');
    await t.enterText(find.byKey(const Key('f-tc-rs')), 'dip stick');
    await t.tap(find.text('Save Diesel Issue'));
    await net(t);
    expect(srv.saved.single['tc'], {'physical': 40, 'reason': 'dip stick'});
    expect(find.textContaining('DI-000526'), findsOneWidget);
  });

  testWidgets('(3.29.0, update-139) A machinery measured by KM and Hrs: a 5th photo, the Hour meter; one with one reading: the 4 photos', (t) async {
    phone(t);
    final srv = FakeServer();
    srv.master.add({'id': 'MH-46-TM-1001', 'no': 'MH-46-TM-1001', 'name': 'Transit Mixer', 'type': 'Transit Mixer', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company', 'status': 'Active',
      'modes': ['KM', 'Hrs', 'KM + Hrs'], 'modesX': [], 'meterKm': true, 'meterHr': true, 'worksOn': ['KM', 'Hrs'], 'unit': 'KM + Hrs', 'kmStd': 3, 'hrStd': 4, 'activeFrom': '2026-09-01', 'inactiveFrom': ''});
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
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
    expect(find.byKey(const Key('photo-bill')), findsNothing, reason: '(3.90.0) no Pump bill at a site with stock');
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    // (3.106.0) the bill's photos are the first thing of the form now – nothing to scroll to
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
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await t.tap(find.text('MH-25-AJ-2169').first);      // (a machinery of this site's Master: the form can be saved)
    await settle(t, 800);
    await t.tap(find.text('Change'));
    await net(t);
    await seen(t, find.text('Save the change'));
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    await pics(t);
    expect(find.text('Sujit Mule'), findsOneWidget);
    expect(find.text('Check Update'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Super Admin'), findsNothing, reason: '(3.17.0) the console is the Super Admin\'s only');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9_me.png'));
    await t.tap(find.byKey(const Key('tab-reports')));
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
    await seen(t, find.text('Save and open'));
    await settle(t, 400);
    await t.tap(find.text('Save and open'));
    await settle(t, 600);
    expect(find.textContaining('The two new passwords are not the same.'), findsOneWidget);
    expect(srv.calls, isNot(contains('portal:changePassword')));
    await t.enterText(find.byType(TextField).at(2), 'Mule#2026x');
    await settle(t, 600);
    await seen(t, find.text('Save and open'));      // (on a small phone the button may be below the screen's end)
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
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    await t.tap(find.text('My settings'));
    await net(t);
    expect(find.text('Default site'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Change password'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Change password'), findsOneWidget);
    await t.scrollUntilVisible(find.text('My usual shift'), -200, scrollable: find.byType(Scrollable).last);
    // (3.97.0) the list is a row longer (Site mode): the row brought clear of the bar at the top before the tap
    final list = find.ancestor(of: find.text('My usual shift'), matching: find.byType(Scrollable)).first;
    await t.drag(list, const Offset(0, 250));
    await settle(t, 400);
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
    await t.tap(find.byKey(const Key('tab-me')));
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
    await t.tap(find.byKey(const Key('tab-home')));
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
    // (3.59.0, Mechanical update-184: "asset master madhe papers fkt own mhanje rachana che ghenar") a Rental one: no papers
    expect(find.byKey(const Key('mna-permit')), findsNothing, reason: 'the papers only for Own machinery');
    await tapK(t, 'mf-ownership');
    await settle(t, 400);
    await t.tap(find.text('Own').last);
    await settle(t, 400);
    await tapK(t, 'mna-permit');
    await settle(t, 300);
    await tapK(t, 'mf-save');
    await net(t);
    final c = srv.masterCalls.last;
    expect((c['fn'], c['mode']), ('saveMaster', 'add'));
    final m = c['m'] as Map;
    expect(m['no'], 'MH-12-AB-1234');
    expect((m['worksOn'], m['unit'], m['kmStd'], m['hrStd']), ('KM', 'KM', 3.2, ''));
    expect((m['ownership'], m['supply'], m['status']), ('Own', 'Company', 'Active'));
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

  testWidgets('(3.57.0) Vendor Master: a Material Supplier (the Store\'s import) – marked, the Type filter, its type in the form; not offered for an asset\'s owner or a BOQ', (t) async {
    phone(t);
    final srv = editor();
    srv.vendors.add({'name': 'Om Hardware Bhiwandi', 'type': 'Material Supplier', 'saved': true, 'complete': false, 'machines': [], 'boqs': 0, 'gstReg': 'No', 'ver': 'v1'});
    final s = await ready(t, srv);
    await openMaster(t, s, 'Vendor Master');
    expect(find.textContaining('material suppliers: 1'), findsOneWidget);
    await tapK(t, 'vt-mat');
    await settle(t, 300);
    expect(find.text('I E Enterprises'), findsNothing);
    expect(find.text('Om Hardware Bhiwandi'), findsOneWidget);
    expect(find.byKey(const Key('vms-Om Hardware Bhiwandi')), findsOneWidget, reason: 'marked Material Supplier');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/67_vendors_material.png'));
    await tapK(t, 'vt-bill');
    await settle(t, 300);
    expect(find.text('Om Hardware Bhiwandi'), findsNothing);
    expect(find.text('I E Enterprises'), findsOneWidget);
    await tapK(t, 'vt-mat');
    await settle(t, 300);
    await tapK(t, 've-Om Hardware Bhiwandi');
    await net(t);
    expect(find.byKey(const Key('vf-type')), findsOneWidget);
    expect(find.text('Material Supplier (Store)'), findsOneWidget);
    await t.enterText(box('vf-pan'), 'ABCDE1234F');
    await tapK(t, 'vf-save');
    await net(t);
    final v = srv.masterCalls.last['v'] as Map;
    expect((v['name'], v['type'], v['pan']), ('Om Hardware Bhiwandi', 'Material Supplier', 'ABCDE1234F'));
    // not offered: the owner of an asset, a BOQ (the server's parties list leaves it out too)
    final names = await vendorNames(s);
    expect(names, isNot(contains('Om Hardware Bhiwandi')));
    expect(names, contains('I E Enterprises'));
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    await seen(t, find.byKey(const Key('sd-show')));
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    await seen(t, find.byKey(const Key('cp-chips')));
    await settle(t, 300);
    await t.scrollUntilVisible(find.byKey(const Key('cpc-all')), 150, scrollable: find.descendant(of: find.byKey(const Key('cp-chips')), matching: find.byType(Scrollable)).first);
    await settle(t, 300);
    await t.tap(find.byKey(const Key('cpc-all')));
    await settle(t, 300);
    expect(find.byKey(const Key('cp-Sany 210 (No.1)')), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.79.0, Mechanical update-205) Vehicle Compliance – 📎 Documents: the RC Book (the earlier one seen, a new one added – sent with cmpDoc, kept with cmpFiles); a renewal with its photo', (t) async {
    phone(t);
    final p0 = pickAttFiles, c0 = attCompute;
    attCompute = <M, R>(ComputeCallback<M, R> cb, M m, {String? debugLabel}) async => await cb(m);
    addTearDown(() {
      pickAttFiles = p0;
      attCompute = c0;
    });
    final shot = Uint8List.fromList(img.encodeJpg(img.fill(img.Image(width: 64, height: 48), color: img.ColorRgb8(40, 90, 200))));
    pickAttFiles = (h, room) async => [(name: 'rc new.jpg', bytes: shot)];
    final srv = editor()..cmpFilesOn = true;
    final s = await ready(t, srv);
    await openMaster(t, s, 'Vehicle Compliance');
    expect(find.text('Documents (1)'), findsOneWidget, reason: 'the machinery with its files');
    await tapK(t, 'cpd-MH-25-AJ-2169');
    await net(t);
    expect(find.text('Documents – MH-25-AJ-2169'), findsOneWidget);
    expect(find.text('Latest – added 01-09-2026'), findsOneWidget, reason: 'the RC Book kept before');
    expect(find.text('rc old.jpg'), findsOneWidget);
    expect(find.text('the invoice of buying the vehicle'), findsOneWidget);
    expect(find.text('Not added yet.'), findsOneWidget, reason: 'no Tax Invoice yet');
    // a new RC Book: its photo, its RC No; the earlier one stays
    await tapK(t, 'cpd-add-RC Book');
    await settle(t, 600);
    expect(find.text('A new RC Book – the earlier ones stay.'), findsOneWidget);
    await tapK(t, 'att-cam');
    await settle(t, 800);
    expect(find.byKey(const Key('att-tile-0')), findsOneWidget);
    await t.enterText(box('cpf-no'), 'MH25AJ2169-NEW');
    await tapK(t, 'cpf-done');
    await net(t);
    expect(srv.masterCalls.where((c) => c['fn'] == 'cmpDoc').length, 1, reason: 'the photo sent once');
    final c = srv.masterCalls.lastWhere((c) => c['fn'] == 'cmpFiles')['x'] as Map;
    expect([c['no'], c['doc'], c['id'], (c['files'] as List).length, c['docNo']], ['MH-25-AJ-2169', 'RC Book', '', 1, 'MH25AJ2169-NEW']);
    expect(find.text('1 file kept with the RC Book of MH-25-AJ-2169.'), findsOneWidget);
    await settle(t, 4200);
    expect(find.text('Latest – added 14-10-2026'), findsOneWidget);
    expect(find.text('Earlier – added 01-09-2026'), findsOneWidget, reason: 'the earlier RC Book stays');
    await t.pageBack();
    await net(t);
    // a renewal (Tax – lifetime) with its photo: the files screen after the dates, the renewal with its list
    await tapK(t, 'cpr-MH-25-AJ-2169-Tax');
    await settle(t, 600);
    await t.tap(find.byKey(const Key('cp-save')));
    await settle(t, 800);
    expect(find.text('The renewed paper (PDF / photo) – optional: press Done with no file to save the date only.'), findsOneWidget);
    await tapK(t, 'att-cam');
    await settle(t, 800);
    await tapK(t, 'cpf-done');
    await net(t);
    final r = srv.masterCalls.lastWhere((c) => c['fn'] == 'renewDoc')['x'] as Map;
    expect([r['no'], r['doc'], r['to'], (r['files'] as List).length], ['MH-25-AJ-2169', 'Tax', 'LIFETIME', 1]);
    expect(find.textContaining('with 1 file'), findsOneWidget);
  });

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
    await seen(t, find.byKey(const Key('lbf-strip')));
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
    await t.tap(find.byKey(const Key('tab-reports')));
    await net(t);
    await t.tap(find.byKey(const Key('rt-diesel'))); // (3.31.0) the reports are under Diesel (Overview first)
    await net(t);
    await t.tap(find.text('Dashboard'));
    await net(t);
    expect(srv.dashAsked.first['fn'], 'getDashboard');
    // (3.97.0) Home asks its figures "lite" (only the opening stock and the pending count); the Dashboard asks in full
    expect(((srv.dashAsked.first['args'] as List).first as Map)['lite'], 1, reason: 'Home\'s own call: light');
    expect([for (final x in srv.dashAsked) if (x['fn'] == 'getDashboard' && !((x['args'] as List).first as Map).containsKey('lite')) (x['args'] as List).first], contains(equals({'from': '2026-10-14', 'to': '2026-10-14'})), reason: 'it opens on Today, as the web');
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
    await t.tap(find.byKey(const Key('tab-reports')));
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
    expect(find.text('5,431'), findsOneWidget, reason: 'A 9,000 − B 3,458 (37.14 L above the standard × ₹93.10 = 3,457.73 → 3,458) − TDS 2 % 111 (3.75.0: whole rupees)');
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
    expect(find.text('3,931'), findsOneWidget, reason: 'the debit note of 1,500 off the net payable');
    await t.scrollUntilVisible(find.byKey(const Key('mb-title')), -300, scrollable: list);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/30_bill_make.png'));
    await tapK(t, 'mb-submit');
    await net(t);
    expect(find.text('Verification – 1 of 1 bill ready'), findsOneWidget);
    await t.tap(find.byKey(const Key('vf-ok')));
    await net(t);
    final x = srv.billSent.firstWhere((c) => c['fn'] == 'submitBills')['x'] as Map, b = ((x['bills'] as List).single as Map);
    // (3.75.0, Mechanical update-202) in whole rupees: B 3,457.73 → 3,458, D 5,542, TDS 2 % 110.84 → 111, Net 5,431, less the note 1,500 → 3,931
    expect([b['vendor'], b['company'], b['billNo'], b['from'], b['to'], b['net']], ['I E Enterprises', 'Sketchline Industries', '8', '2026-09-01', '2026-09-30', 5431]);
    final data = b['data'] as Map;
    expect([data['idlePaid'], data['A'], data['B'], data['D'], data['H'], data['I'], data['K'], (data['dns'] as List).length, data['edited'], data['round']], [true, 9000, 3458, 5542, 111, 5431, 3931, 1, false, true]);
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

  testWidgets('(3.72.2, Mechanical update-199) Machinery Billing: the month-end tank check – the bill says it is needed, the box (what should be in the tank), the diesel found saved (saveBillTankCheck, once), the shortage debited', (t) async {
    phone(t);
    final srv = FakeServer()
      ..billing = true
      ..tankRule = true;
    srv.perms.addAll({'Machinery Billing': 'Edit'});
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Billing'));
    await net(t);
    await tapK(t, 'bh-Machinery Billing');
    await net(t);
    await tapK(t, 'mb-vendors');
    await settle(t, 600);
    await t.tap(find.descendant(of: find.byKey(const Key('mbv-I E Enterprises')), matching: find.byType(Checkbox)));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('mbv-done')));
    await settle(t, 600);
    await tapK(t, 'mb-build');
    await net(t);
    final list = find.descendant(of: find.byKey(const Key('mb-list')), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.byKey(const Key('mb-warn-0')), 300, scrollable: list);
    // 180 L issued, 500 km ÷ 3.5 = 142.86 L standard → 37.14 L should be in the tank; no check yet: nothing debited, the bill says so
    expect(find.textContaining('MH-25-AJ-2169: tank check of 30-09-2026 needed – 37.14 L should be in the tank as per the standard'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('mb-tc-0')), 300, scrollable: list);
    expect(find.text('MH-25-AJ-2169: 37.14 L as per the standard'), findsOneWidget);
    expect(find.text('opening 0 + issued 180 − standard 142.86'), findsOneWidget);
    expect(find.text('0'), findsWidgets, reason: 'B = 0 until the check (3.75.0: whole rupees)');
    await t.enterText(find.byKey(const Key('mb-tcf-0-MH-25-AJ-2169')), '20');
    await tapK(t, 'mb-tcs-0-MH-25-AJ-2169');
    await net(t);
    final sent = srv.billSent.firstWhere((c) => c['fn'] == 'saveBillTankCheck')['x'] as Map;
    expect([sent['no'], sent['from'], sent['to'], sent['physical'], sent['replace']], ['MH-25-AJ-2169', '2026-09-01', '2026-09-30', 20, false]);
    expect(srv.rids.any((r) => r.startsWith('saveBillTankCheck:')), true, reason: 'saved once, with its own number');
    expect(srv.billSent.where((c) => c['fn'] == 'logPrintExtra').length, 2, reason: 'the dates read again after the save');
    await t.scrollUntilVisible(find.byKey(const Key('mb-tc-0')), 300, scrollable: list);
    expect(find.text('found 20 L (TC-00009) → 17.14 L short – debited'), findsOneWidget);
    expect(find.text('1,596'), findsWidgets, reason: 'B = 17.14 L × ₹93.10 = 1,595.73 → 1,596 (3.75.0, whole rupees)');
    expect(find.byKey(const Key('mb-tcc-0-MH-25-AJ-2169')), findsOneWidget, reason: 'Change');
  });

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
    // (3.77.0, Mechanical update-204) a deleted bill is not in Saved Bills: it is in Deleted Bills, under its month
    expect(find.byKey(const Key('sb-BILL-00001')), findsOneWidget);
    expect(find.byKey(const Key('sb-BILL-00003')), findsNothing);
    await t.tap(find.byKey(const Key('drv-del')));
    await settle(t, 800);
    expect(find.byKey(const Key('sbx-m-2026-07')), findsOneWidget);
    expect(find.text('July 2026 – 1 deleted bill'), findsOneWidget);
    expect(find.byKey(const Key('sb-BILL-00003')), findsOneWidget);
    expect(find.textContaining('Deleted by Super Admin on 05-08-2026 – wrong rate'), findsOneWidget);
    expect(find.byKey(const Key('sbv-BILL-00003')), findsOneWidget);
    expect(find.byKey(const Key('sbd-BILL-00003')), findsNothing, reason: 'already deleted');
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
    await seen(t, find.text('Administration'));
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
    // (3.64.0, Mechanical update-189) a page with a date offers Admin: Edit, and its entries of an earlier day
    expect(find.text('Admin'), findsWidgets);
    await t.tap(find.text('Admin').last);
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('ua-new-pw')), 'Once#2026');
    await settle(t, 600);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/32_admin_users.png'));
    await tapK(t, 'ua-add');
    await net(t);
    final x = srv.adminSent.firstWhere((c) => c['fn'] == 'saveUserAdmin')['x'] as Map;
    expect([x['isNew'], x['email'], x['name'], x['active'], x['admin'], x['newPassword'], x['perms']], [true, 'driver@rcl.test', 'New Driver', true, false, 'Once#2026', {'Dashboard': 'None', 'Log Book': 'Admin', 'Machinery Billing': 'None'}]);
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
    // (3.74.0, Mechanical update-201) voice typing – the site's own words: the Super Admin's list and the corrections learned
    // (a hand correction taken off); saved with saveVoiceWords and given to the voice typing at once
    srv.voiceFixes = [{'h': 'aryna nagar', 'f': 'Arihant City', 'n': 2}, {'h': 'two', 'f': 'three', 'n': 1}];
    await t.pageBack();
    await net(t);
    await tapK(t, 'ad-Rules of this site');
    await net(t);
    await t.scrollUntilVisible(find.byKey(const Key('vw-save')), 300, scrollable: find.ancestor(of: find.byKey(const Key('rule-save')), matching: find.byType(Scrollable)).first);
    await settle(t, 400);
    expect(find.text('“aryna nagar” → Arihant City  ×2'), findsOneWidget);
    expect(find.text('“two” → three'), findsOneWidget);
    expect(find.textContaining('Also known by themselves: 3 names'), findsOneWidget);
    await t.enterText(box('vw-words'), 'Arihant City\nYewai Naka\n ');
    await tapK(t, 'vw-del-1');
    await settle(t, 300);
    await tapK(t, 'vw-save');
    await net(t);
    expect(srv.voiceSent.last, {'fn': 'saveVoiceWords', 'x': {'words': ['Arihant City', 'Yewai Naka'], 'fixes': [{'h': 'aryna nagar', 'f': 'Arihant City'}]}});
    expect(srv.rids.any((r) => r.startsWith('saveVoiceWords:')), true, reason: 'saved once');
    expect(find.text('“two” → three'), findsNothing);
    expect(s.voiceWords['admin'], ['Arihant City', 'Yewai Naka']);
    expect(SiteWords.i.fix(['go to Yeway Naka']).text, 'go to Yewai Naka', reason: 'the voice typing has the new list at once');
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

  testWidgets('(3.72.0) Purchase (rcl-purchase): its tile only with Purchase on the site; its own sign-in (a Portal ticket for "purchase"); the Dashboard – his sites with Purchase, the one open now; in the search', (t) async {
    phone(t);
    final srv = FakeServer();
    var s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.text('Purchase'), findsNothing, reason: 'no Purchase on this site: no tile');
    srv.purSite = true;
    s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    // the search: Purchase's Dashboard (Home not scrolled yet – its search button at the top)
    await t.tap(find.byKey(const Key('home-search')));
    await net(t);
    await t.enterText(find.byKey(const Key('gs-in')), 'purchase');
    await net(t);
    final hit = find.ancestor(of: find.text('Purchase'), matching: find.byKey(const Key('gs-page-Dashboard')));
    expect(hit, findsOneWidget, reason: 'Purchase\'s Dashboard in the search');
    await t.tap(hit);
    await net(t);
    expect(find.byKey(const Key('pur-dash')), findsOneWidget);
    expect(srv.calls, contains('portal:go:purchase:S1'));
    expect([for (final x in srv.purSent) x['fn']], ['sso'], reason: 'its own sign-in by a ticket of the Portal');
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // Home → Purchase
    await seen(t, find.text('Purchase'));
    await settle(t, 400);
    await t.tap(find.text('Purchase'));
    await net(t);
    expect(srv.purSent.length, 2, reason: 'a fresh sign-in each time it is opened');
    expect(find.byKey(const Key('pur-dash')), findsOneWidget);
    expect(find.text('Purchase Department'), findsOneWidget);
    // (3.94.0) the cards of Purchase's work come first – his sites below them
    await t.scrollUntilVisible(find.byKey(const Key('pur-site-T2')), 200, scrollable: find.byType(Scrollable).first);
    await settle(t, 300);
    expect(find.descendant(of: find.byKey(const Key('pur-count')), matching: find.text('2')), findsOneWidget);
    expect(find.byKey(const Key('pur-site-S1')), findsOneWidget);
    expect(find.byKey(const Key('pur-site-T2')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('pur-site-S1')), matching: find.text('Open now')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('pur-site-T2')), matching: find.text('Open now')), findsNothing);
    expect(find.textContaining('Purchase Admin'), findsWidgets);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/74_purchase.png'));
    // a Purchase User: his one site
    await t.pageBack();
    await net(t);
    srv.purRole = 'user';
    await t.tap(find.text('Purchase'));
    await net(t);
    await t.scrollUntilVisible(find.byKey(const Key('pur-count')), 200, scrollable: find.byType(Scrollable).first);
    await settle(t, 300);
    expect(find.descendant(of: find.byKey(const Key('pur-count')), matching: find.text('1')), findsOneWidget);
    expect(find.byKey(const Key('pur-site-T2')), findsNothing);
    expect(find.textContaining('Purchase User'), findsWidgets);
  }, tags: ['golden']);

  testWidgets('(3.10.0) Store: its own sign-in (a Portal ticket); the Dashboard; the Item Master – a near name asked, saved as a different item', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await seen(t, find.text('Store'));
    await settle(t, 400);
    await t.tap(find.text('Store'));
    await net(t);
    expect(srv.calls, contains('portal:go:store:S1'));
    expect(srv.storeSent.first, {'fn': 'sso', 'ticket': 'tk2'});
    expect(srv.storeSent[1]['cookie'], startsWith('rcl_store=S1.store1-'), reason: 'the Store\'s own sign-in, kept for its calls');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/33_store.png'));
    // (3.97.0) the work's figures are bigger cards now: the Item Master's figures further down
    await t.scrollUntilVisible(find.text('Added this month'), 300, scrollable: find.descendant(of: find.byKey(const Key('st-dash')), matching: find.byType(Scrollable)).first);
    expect(find.text('Added this month'), findsOneWidget);
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

  // (3.54.0, Mechanical update-179) the Pending Log Book printed for a period – from the Dashboard and from the Log Book screen
  List<List<Object?>> sheetRows(Uint8List b) => readSheets(b).first.rows;

  testWidgets('(3.54.0 – Mechanical update-179) Pending Log Book – Print / Excel from the Dashboard: its period, Ownership, Vendor; each machinery with its days', (t) async {
    phone(t);
    final srv = editor()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-reports')));
    await net(t);
    await t.tap(find.byKey(const Key('rt-diesel')));
    await net(t);
    await t.tap(find.text('Dashboard'));
    await net(t);
    await t.tap(find.byKey(const Key('dt-log')));
    await net(t);
    await t.scrollUntilVisible(find.byKey(const Key('lb-pprint')), 600, scrollable: find.descendant(of: find.byKey(const Key('dash-log')), matching: find.byType(Scrollable)).first);
    await tapK(t, 'lb-pprint');
    await net(t);
    expect(find.byType(PendPrintScreen), findsOneWidget);
    expect((t.widget(find.byKey(const Key('pp-kind'))) as PickField).value, 'period');
    expect((t.widget(find.byKey(const Key('pp-from'))) as DateField).value, '2026-09-01', reason: 'the list\'s period');
    final to = (t.widget(find.byKey(const Key('pp-to'))) as DateField).value;
    expect(to.length, 10);
    final files = catchFiles();
    final before = srv.dashAsked.length;
    await tapK(t, 'pp-xl');
    await net(t);
    final asked = srv.dashAsked.sublist(before);
    expect(asked.map((x) => x['fn']), ['pendingLog'], reason: 'the Dashboard\'s list (its access)');
    expect((asked.single['args'] as List).first, {'from': '2026-09-01', 'to': to});
    expect(files.single.$1, 'Pending_Log_Book_2026-09-01_$to.xlsx');
    final rows = sheetRows(files.single.$2);
    expect(rows.any((r) => r.length > 1 && '${r[0]}' == '#' && '${r[1]}' == 'Machinery'), true);
    final mh = rows.firstWhere((r) => r.length > 6 && '${r[1]}'.startsWith('MH-15-AB-0001'));
    final fx = (jsonDecode(File('test/fixtures/dash/pendingLog.json').readAsStringSync()) as Map)['items'] as List;
    final n = fx.where((x) => x['no'] == 'MH-15-AB-0001' && '${x['date']}'.compareTo(to) <= 0).length;
    expect([mh[5], '${mh[6]}'.startsWith('01-10')], [n, true], reason: 'its pending days up to the To date, the first on 01-10');
  });

  testWidgets('(3.54.0 – Mechanical update-179) Pending Log Book – Print / Excel from the Log Book screen: that date (logPending – Log Book access)', (t) async {
    phone(t);
    final srv = FakeServer()..perms['Log Book'] = 'Edit';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.text('Logbook').last);
    await net(t);
    await t.tap(find.text('2 machinery without Log Book'));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('lb-pend-print')));
    await net(t);
    expect(find.byType(PendPrintScreen), findsOneWidget);
    expect((t.widget(find.byKey(const Key('pp-kind'))) as PickField).value, 'date');
    final day = (t.widget(find.byKey(const Key('pp-date'))) as DateField).value;
    final files = catchFiles();
    final before = srv.dashAsked.length;
    await tapK(t, 'pp-xl');
    await net(t);
    final asked = srv.dashAsked.sublist(before);
    expect(asked.map((x) => x['fn']), ['logPending']);
    expect((asked.single['args'] as List).first, {'from': day, 'to': day});
    expect(files.single.$1, 'Pending_Log_Book_${day}_$day.xlsx');
  });

  /* ---------------- (3.55.0) the Store's work – the app's own screens (rcl-store api/work) ---------------- */
  Future<FakeServer> openStoreWork(WidgetTester t, {FakeServer? server}) async {
    phone(t);
    final srv = server ?? FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await seen(t, find.text('Store'));
    await settle(t, 400);
    await t.tap(find.text('Store'));
    await net(t);
    await t.tap(find.byKey(const Key('st-tab-work')));
    await net(t);
    return srv;
  }

  List<Map<String, dynamic>> sent(FakeServer srv, String action) => srv.storeWork.where((x) => x['action'] == action).toList();

  testWidgets('(3.55.0) Store – the Work tab: the pages he was given; the Dashboard\'s figures; Material Requirements – approve one waiting for me, a new one saved', (t) async {
    final srv = await openStoreWork(t);
    for (final k in ['req', 'po', 'grn', 'issue', 'reports', 'settings']) {
      expect(find.byKey(Key('sw-$k')), findsOneWidget, reason: 'a Store Admin: $k');
    }
    expect(find.byKey(const Key('sw-purchase')), findsNothing, reason: 'Store Purchase only when given');
    expect(find.byKey(const Key('sw-req-mine')), findsOneWidget, reason: 'one waiting for my approval');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/33b_store_work.png'));
    await t.tap(find.byKey(const Key('st-tab-dashboard')));
    await net(t);
    expect(find.byKey(const Key('st-dwork')), findsOneWidget);
    expect(find.text('Waiting for my approval'), findsOneWidget);
    await t.tap(find.byKey(const Key('st-tab-work')));
    await net(t);
    await tapK(t, 'sw-req');
    await net(t);
    expect(sent(srv, 'boot').isNotEmpty, true);
    expect(find.byKey(const Key('rq-2')), findsOneWidget);
    expect(find.byKey(const Key('rq-1')), findsOneWidget, reason: 'open: pending and approved with some still to order');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/33c_store_req.png'));
    await tapK(t, 'rq-ok-2');
    await net(t);
    expect(sent(srv, 'reqDecide').single, {'action': 'reqDecide', 'nos': [2], 'ok': true});
    expect(find.text('Requirement 2 approved.'), findsOneWidget);
    // a new requirement: an item picked, its quantity
    await tapK(t, 'rq-new');
    await net(t);
    await tapK(t, 'rql-add');
    await settle(t, 800);
    await t.tap(find.byKey(const Key('pick-ITM-0002 · Sugar (Kg)')));
    await settle(t, 600);
    await t.enterText(box('rql-q-0'), '5');
    await settle(t, 300);
    expect(find.textContaining('stock now 10.5 Kg'), findsOneWidget);
    // (3.58.0) each item its Brand and Material specification
    await seen(t, box('rql-b-0'));
    await t.enterText(box('rql-b-0'), 'Madhur');
    await seen(t, box('rql-sp-0'));
    await t.enterText(box('rql-sp-0'), 'Refined, 50 kg bags');
    await settle(t, 300);
    await tapK(t, 'rq-save');
    await net(t);
    final r = sent(srv, 'reqSave').single['req'] as Map;
    expect([r['date'], r['for_kind'], r['lines']], ['2026-10-14', 'Site work', [{'code': 'ITM-0002', 'qty': '5', 'brand': 'Madhur', 'spec': 'Refined, 50 kg bags', 'note': ''}]]);
    expect(find.textContaining('Requirement 3 saved – it waits for Level 1.'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.68.0) Store – live: the Requirements list asks "what changed?" every 2 s; another person\'s save (the site\'s last change moved) shows by itself; nothing asked while another screen is over it', (t) async {
    final srv = await openStoreWork(t);
    await tapK(t, 'sw-req');
    await net(t);
    expect(find.byKey(const Key('rq-9')), findsNothing);
    await t.pump(const Duration(milliseconds: 2500));
    await net(t);
    final asked = sent(srv, 'live').length;
    expect(asked, greaterThanOrEqualTo(1), reason: 'asked after 2 s');
    // another person makes requirement 9 at the site
    srv.storeReqs.insert(0, {'no': 9, 'date': '2026-10-14', 'need_by': null, 'for_kind': 'Site work', 'for_text': 'Ch 548+200 drain', 'status': 'Pending', 'level': 1, 'approvals': [], 'created_by': 'amol@rcl.test', 'created_name': 'Amol Patil',
      'lines': [{'line': 1, 'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'qty': 3, 'note': '', 'ordered': 0, 'left': 0}], 'mayApprove': true, 'mine': false, 'waitFor': ['Sujit Mule']});
    srv.storeLive++;
    await t.pump(const Duration(milliseconds: 2500));
    await net(t);
    expect(find.byKey(const Key('rq-9')), findsOneWidget, reason: 'shown by itself – no pull to refresh');
    // a screen over the list: nothing asked
    await tapK(t, 'rq-new');
    await net(t);
    final before = sent(srv, 'live').length;
    await t.pump(const Duration(seconds: 5));
    await net(t);
    expect(sent(srv, 'live').length, before, reason: 'the list is under the form');
  });

  testWidgets('(3.66.0 – the Store\'s step 7) a requirement\'s photos: taken in its form and sent (reqPhotoUp), the save with their list and proofs; Photos of one made already – seen, one added (reqPhotoAdd); its print with the photos page; HO Purchase sees them', (t) async {
    final p0 = pickAttFiles, c0 = attCompute;
    attCompute = <M, R>(ComputeCallback<M, R> cb, M m, {String? debugLabel}) async => await cb(m);
    final papers = <(String, String)>[];
    storePaperSink = (h, title) => papers.add((title, h));
    addTearDown(() {
      pickAttFiles = p0;
      attCompute = c0;
      storePaperSink = null;
    });
    final shot = Uint8List.fromList(img.encodeJpg(img.fill(img.Image(width: 64, height: 48), color: img.ColorRgb8(200, 60, 40))));
    var how = '';
    pickAttFiles = (h, room) async {
      how = h;
      return [(name: 'material.jpg', bytes: shot)];
    };
    final h1 = 'a' * 64;
    final srv = FakeServer()..storePages = {...FakeServer().storePages, 'purchase': 'Edit'};
    srv.storeReqs[1]
      ..['mine'] = true
      ..['photos'] = [{'sha': h1, 'size': 1000, 'by': 'Amol Patil', 'at': '2026-10-13T20:00:00.000Z'}];
    await openStoreWork(t, server: srv);
    await tapK(t, 'sw-req');
    await net(t);
    expect(find.text('📷 1 photo'), findsOneWidget, reason: 'the requirement with a photo says so');
    expect(find.text('Photos (1)'), findsOneWidget);
    // a new requirement with a photo from the camera: sent at once when saved, then the requirement with its list
    await tapK(t, 'rq-new');
    await net(t);
    await tapK(t, 'rql-add');
    await settle(t, 800);
    await t.tap(find.byKey(const Key('pick-ITM-0002 · Sugar (Kg)')));
    await settle(t, 600);
    await t.enterText(box('rql-q-0'), '5');
    await settle(t, 300);
    await reach(t, 'rqf-photos', 'rqf');      // (below the items – the list builds it when it is reached)
    expect(find.text('Photos of the material'), findsOneWidget);
    expect(find.byKey(const Key('att-pdf')), findsNothing, reason: 'photos only – no PDF');
    await tapK(t, 'att-cam');
    await settle(t, 800);
    expect(how, 'camera');
    expect(find.byKey(const Key('att-tile-0')), findsOneWidget);
    await tapK(t, 'rq-save');
    await net(t);
    final up = sent(srv, 'reqPhotoUp');
    expect(up.length, 1);
    expect('${up.single['data']}'.startsWith('data:image/jpeg;base64,'), true, reason: 'a JPEG made here');
    final hs = srv.storePhotos.keys.single, sz = srv.storePhotos[hs];
    expect(sent(srv, 'reqSave').single['photos'], [{'sha': hs, 'size': sz, 't': 'proof-${hs.substring(0, 8)}'}], reason: 'its list with the new photo\'s proof');
    expect(find.textContaining('Requirement 3 saved'), findsOneWidget);
    await settle(t, 4200); // (the message at the foot goes – a tap there would land on it)
    // Photos of requirement 1 (made already, approved – he made it): seen, one added from the gallery
    await tapK(t, 'rq-ph-1');
    await net(t);
    expect(find.text('1 of 10 photos – a photo opens big.'), findsOneWidget);
    expect(find.byKey(const Key('rqp-0')), findsOneWidget);
    expect(find.text('Amol Patil · 14-10-2026'), findsOneWidget, reason: 'who added it, its day in India (20:00 UTC = 01:30 the next day)');
    await tapK(t, 'att-gal');
    await settle(t, 800);
    expect(how, 'gallery');
    await tapK(t, 'rqp-send');
    await net(t);
    final add = sent(srv, 'reqPhotoAdd').single;
    expect([add['no'], (add['photos'] as List).length, ((add['photos'] as List).single as Map)['t']], [1, 1, 'proof-${hs.substring(0, 8)}']);
    expect(find.textContaining('1 photo added to requirement RCL/VTR/PR/2026/0001 (2 now).'), findsOneWidget, reason: '(3.70.0) named by its Indent No.');
    expect(find.text('2 of 10 photos – a photo opens big.'), findsOneWidget);
    await settle(t, 4200);
    await t.pageBack();
    await net(t);
    // its print: the form, then "Photos of the material" with both
    await tapK(t, 'rq-print-1');
    await net(t);
    final pg = papers.last.$2;
    expect(pg, contains('Photos of the material – RCL/VTR/PR/2026/0001 (2)'));
    expect(pg, contains('<img src="https://erp.test/ph/$h1.jpg" alt="Photo 1">'));
    expect(pg, contains('Photo 1 · Amol Patil · 14-10-2026'));
    expect(pg, contains('Photo 2 · Sujit Mule · 14-10-2026'));
    // HO Purchase: the approved requirement's photos
    await t.pageBack();
    await net(t);
    await tapK(t, 'sw-purchase');
    await net(t);
    expect(find.text('REQ 1 – 📷 2 photos'), findsOneWidget);
    await tapK(t, 'pu-ph-S1-1');
    await net(t);
    expect(find.text('2 of 10 photos – a photo opens big.'), findsOneWidget);
    expect(find.byKey(const Key('rqp-send')), findsNothing, reason: 'HO Purchase only sees them');
    expect(sent(srv, 'reqPhotos').last['site'], 'S1');
  });

  testWidgets('(3.70.0 – the Store\'s step 8) the Indent No.; Change / Delete as the server says – never while a PO has it (the PO deleted first); the contact; a machinery\'s log book attached; a photo taken out; the print with the contact and the log book', (t) async {
    final papers = <(String, String)>[];
    storePaperSink = (h, title) => papers.add((title, h));
    addTearDown(() => storePaperSink = null);
    final h1 = 'b' * 64;
    final srv = FakeServer()
      ..storePages = {...FakeServer().storePages, 'purchase': 'Edit'}
      ..storeStep8 = true;
    srv.storeReqs[1]
      ..['mine'] = true
      ..['photos'] = [{'sha': h1, 'size': 1000, 'by': 'Amol Patil', 'at': '2026-10-13T05:00:00.000Z'}]
      ..['contact_name'] = 'Suresh More'
      ..['contact_phone'] = '90000 11111';
    await openStoreWork(t, server: srv);
    await tapK(t, 'sw-req');
    await net(t);
    // the Indent No. – RCL / VTR / the financial year / M (a machinery) or P / its number
    expect(find.text('RCL/VTR/2026-27/M/0002 · 14-10-2026'), findsOneWidget);
    expect(find.text('RCL/VTR/2026-27/P/0001 · 12-10-2026'), findsOneWidget);
    // requirement 1 is in PO 1: no Change, no Delete; requirement 2: both, and its machinery's Log book
    expect(find.byKey(const Key('rq-pos-1')), findsOneWidget);
    expect(find.byKey(const Key('rq-edit-1')), findsNothing);
    expect(find.byKey(const Key('rq-del-1')), findsNothing);
    expect(find.byKey(const Key('rq-edit-2')), findsOneWidget);
    expect(find.byKey(const Key('rq-del-2')), findsOneWidget);
    // the log book of requirement 2 (Sany 210): not attached – written up to 10-10-2026 → Attach
    await tapK(t, 'rq-lb-2');
    await net(t);
    expect(find.text('Not attached.'), findsOneWidget);
    expect(find.text('Written now up to 10-10-2026 · 12 bill(s)'), findsOneWidget);
    await tapK(t, 'rqlb-set');
    await net(t);
    expect(sent(srv, 'reqLogbook').single, {'action': 'reqLogbook', 'no': 2, 'attach': true});
    expect(find.text('Attached: up to 10-10-2026 · 12 bill(s) · by Sujit Mule'), findsOneWidget);
    await settle(t, 4200);
    await t.pageBack();
    await net(t);
    expect(find.text('📕 Log book up to 10-10-2026'), findsOneWidget);
    // its print: the form, then the log book as the Store draws it
    await tapK(t, 'rq-print-2');
    await net(t);
    expect(papers.last.$1, 'Requirement RCL/VTR/2026-27/M/0002');
    expect(papers.last.$2, contains('<div style="page-break-before:always"><div class="mlbw"><div class="mlbt">Maintenance Log Book – Sany 210 (No.1)</div>'));
    // requirement 1's print: its contact and the site's address
    await tapK(t, 'rq-print-1');
    await net(t);
    expect(papers.last.$2, contains('<tr><td>Contact Person :</td><td>Suresh More</td><td>Contact No. :</td><td>90000 11111</td></tr>'));
    expect(papers.last.$2, contains('<tr><td>Site Address :</td><td colspan="3">Site office, Valshind</td></tr>'));
    // a photo of requirement 1 taken out (the others stay)
    await tapK(t, 'rq-ph-1');
    await net(t);
    await tapK(t, 'rqp-out-0');
    await settle(t, 600);
    await t.tap(find.text('Take it out'));
    await net(t);
    expect(sent(srv, 'reqPhotoDel').single, {'action': 'reqPhotoDel', 'no': 1, 'sha': h1});
    expect(find.text('No photo yet.'), findsOneWidget);
    await settle(t, 4200);
    await t.pageBack();
    await net(t);
    // requirement 2 changed: its contact typed, its log book kept (ticked – attached up to 10-10-2026)
    await tapK(t, 'rq-edit-2');
    await net(t);
    expect(find.byKey(const Key('rqf-lb')), findsOneWidget);
    expect(find.text('attached up to 10-10-2026'), findsOneWidget);
    await t.enterText(box('rqf-cn'), 'Mahesh Jadhav');
    await t.enterText(box('rqf-cp'), '91234 56789');
    await settle(t, 300);
    await tapK(t, 'rq-save');
    await net(t);
    final ch = sent(srv, 'reqSave').single;
    expect([ch['no'], (ch['req'] as Map)['contact_name'], (ch['req'] as Map)['contact_phone'], ch['logbook']], [2, 'Mahesh Jadhav', '91234 56789', true]);
    expect(find.textContaining('Requirement RCL/VTR/2026-27/M/0002 saved – it waits for Level 1.'), findsOneWidget);
    await settle(t, 4200);
    // a new one starts with the site's contact (the Portal's)
    await tapK(t, 'rq-new');
    await net(t);
    expect(find.text('Ramesh Patil'), findsOneWidget);
    expect(find.text('98765 43210'), findsOneWidget);
    await t.pageBack();
    await net(t);
    // PO 1 deleted (nothing of it came… in the fake) – then requirement 1 may be changed and deleted
    await t.pageBack();
    await net(t);
    await reach(t, 'sw-po', 'st-work');
    await tapK(t, 'sw-po');
    await net(t);
    await tapK(t, 'po-del-S1-1');
    await settle(t, 600);
    await t.tap(find.text('Delete the PO'));
    await net(t);
    expect(sent(srv, 'poDelete').single, {'action': 'poDelete', 'site': 'S1', 'no': 1});
    await settle(t, 4200);
    await t.pageBack();
    await net(t);
    await reach(t, 'sw-req', 'st-work'); // (the Work tab scrolled to its PO page – its top again)
    await tapK(t, 'sw-req');
    await net(t);
    expect(find.byKey(const Key('rq-pos-1')), findsNothing);
    await tapK(t, 'rq-del-1');
    await settle(t, 600);
    await t.tap(find.text('Delete').last);      // (the box's button – over the list's)
    await net(t);
    expect(sent(srv, 'reqDelete').single, {'action': 'reqDelete', 'no': 1});
    expect(find.byKey(const Key('rq-1')), findsNothing);
  });

  testWidgets('(3.71.0 – the Store\'s workflow) what waits for me on each page; a requirement verified; Head Office: a site\'s bill (checked with its PO) ✓ Checked, a site that buys itself; a PO – its balance, its verification, its Details (every GRN checked with the PO); the site\'s own To order → its PO; a GRN verified (its bill not as per the PO); a return sent back (why)', (t) async {
    final srv = FakeServer()
      ..storeWf = true
      ..storePages = {...FakeServer().storePages, 'purchase': 'Edit'};
    Finder inK(String k, String text) => find.descendant(of: find.byKey(Key(k)), matching: find.text(text));
    await openStoreWork(t, server: srv);
    // the Work tab: on each page what waits for me (to verify or approve)
    for (final k in ['req', 'po', 'grn', 'issue']) {
      expect(find.byKey(Key('sw-$k-mine')), findsOneWidget, reason: k);
    }
    // the Dashboard's tiles
    await t.tap(find.byKey(const Key('st-tab-dashboard')));
    await net(t);
    for (final k in ['sd-wpo', 'sd-wgrn', 'sd-wiss']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    await t.tap(find.byKey(const Key('st-tab-work')));
    await net(t);
    // ---- Material Requirements: requirement 2 waits for MY verification – Verify
    await tapK(t, 'sw-req');
    await net(t);
    expect(find.byKey(const Key('rq-vf-2')), findsOneWidget);
    expect(find.text('Verification – Sujit Mule'), findsOneWidget);
    expect(find.textContaining('Verified by: Sujit Mule · Approved by: Level 1 – Sujit Mule'), findsOneWidget);
    expect(inK('rq-ok-2', 'Verify'), findsOneWidget);
    await tapK(t, 'rq-ok-2');
    await net(t);
    expect(sent(srv, 'reqDecide').single, {'action': 'reqDecide', 'nos': [2], 'ok': true});
    expect(find.text('Requirement 2 verified.'), findsOneWidget);
    await settle(t, 4200);
    await t.pageBack();
    await net(t);
    // ---- Purchase (Head Office): S1 buys itself; the bills S1 sent – GRN 4 checked with its PO → ✓ Checked; the issues: none sent
    await reach(t, 'sw-purchase', 'st-work');
    await tapK(t, 'sw-purchase');
    await net(t);
    expect(find.byKey(const Key('pu-own-S1')), findsOneWidget);
    expect(find.byKey(const Key('pu-t-T2-1-1')), findsOneWidget, reason: 'the other site\'s requirement to order here');
    expect([for (final x in sent(srv, 'hoInbox')) x['kind']], ['grn', 'iss']);
    await reach(t, 'ho-grn-S1-4', 'pu-list');
    expect(inK('ho-grn-S1-4', 'Bill with PO 1: ⚠ Sugar: rate 100.00 – PO 95.00'), findsOneWidget);
    expect(inK('ho-grn-S1-4', 'At Head Office'), findsOneWidget);
    expect(inK('ho-grn-S1-4', 'Asha Accounts · 14-10-2026'), findsOneWidget);
    await tapK(t, 'ho-ok-grn-S1-4');
    await settle(t, 600);
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(sent(srv, 'hoCheck').single, {'action': 'hoCheck', 'site': 'S1', 'kind': 'grn', 'no': 4, 'note': ''});
    expect(find.text('GRN 4 – checked.'), findsOneWidget);
    expect(find.byKey(const Key('ho-grn-S1-4')), findsNothing, reason: 'checked: out of the list to check');
    await reach(t, 'ho-done-grn', 'pu-list');
    await tapK(t, 'ho-done-grn');
    await net(t);
    expect(sent(srv, 'hoInbox').where((x) => x['kind'] == 'grn').last['done'], true);
    expect(inK('ho-grn-S1-4', '✓ Checked by HO'), findsOneWidget);
    expect(find.byKey(const Key('ho-ok-grn-S1-4')), findsNothing);
    // the issues & returns: no site sends them (Portal → Workflow); a site without the Store's step 9 said so
    final pu = find.descendant(of: find.byKey(const Key('pu-list')), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('No site sends its issues & returns to Head Office (Portal → Workflow).'), 200, scrollable: pu);
    expect(find.text('The Store\'s database step 9 is not run at T2 yet (sql/store_step9_workflow.sql).'), findsWidgets);
    await settle(t, 4200);
    await t.pageBack();
    await net(t);
    // ---- the site's Purchase Orders: PO 1 – ordered 20, came 5, BALANCE 15; open a day; it waits for my verification → Verify
    await reach(t, 'sw-po', 'st-work');
    await tapK(t, 'sw-po');
    await net(t);
    expect(sent(srv, 'purPending').last, {'action': 'purPending', 'mine': true});
    expect(find.byKey(const Key('pol-own')), findsOneWidget, reason: 'S1 buys its requirements itself: its Store Admin orders here');
    expect(inK('po-l-S1-1-1', '• Sugar 20 Kg · came 5'), findsOneWidget);
    expect(inK('po-l-S1-1-1', 'balance 15'), findsOneWidget);
    expect(find.text('1 day(s) open · 1 GRN'), findsOneWidget);
    expect(find.text('Waiting verification – Sujit Mule'), findsOneWidget);
    expect(inK('po-ok-S1-1', 'Verify'), findsOneWidget);
    await tapK(t, 'po-ok-S1-1');
    await net(t);
    expect(sent(srv, 'poDecide').single, {'action': 'poDecide', 'no': 1, 'ok': true});
    expect(find.text('PO 1 verified.'), findsOneWidget);
    await settle(t, 4200);
    // its Details: each line ordered / came / balance; its GRN checked with the PO
    await tapK(t, 'po-det-S1-1');
    await net(t);
    expect(sent(srv, 'poGrns').single, {'action': 'poGrns', 'site': 'S1', 'no': 1});
    expect(find.byType(PoDetailScreen), findsOneWidget);
    expect(find.text('Total (before GST): ordered ₹2,000.00 · came ₹500.00 · balance ₹1,500.00'), findsOneWidget);
    expect(inK('pod-g-4', '⚠ Sugar: rate 100.00 – PO 95.00'), findsOneWidget);
    expect(inK('pod-g-4', 'Waiting verification'), findsOneWidget);
    await t.pageBack();
    await net(t);
    // the site's own To order: requirement 1's Sugar (30 Kg) ticked → its PO made here
    await reach(t, 'pol-t-1-1', 'pol-list');
    await tapK(t, 'pol-t-1-1');
    await t.pump();
    await tapK(t, 'pol-mk');
    await net(t);
    expect(sent(srv, 'purItems').last['site'], 'S1');
    await reach(t, 'pol-q-0', 'pof');
    expect((t.widget<TextField>(box('pol-q-0')).controller!).text, '30', reason: 'what is still to order');
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // ---- Inward (GRN): GRN 4 waits for MY verification – its bill not as per its PO – Verify
    await reach(t, 'sw-grn', 'st-work');
    await tapK(t, 'sw-grn');
    await net(t);
    expect(find.byKey(const Key('gr-mine')), findsOneWidget);
    expect(inK('grm-ck-4', 'Bill with PO 1: ⚠ Sugar: rate 100.00 – PO 95.00'), findsOneWidget);
    expect(inK('grm-wf-4', 'Waiting verification'), findsOneWidget);
    expect(inK('mwf-ok-grn-4', 'Verify'), findsOneWidget);
    await tapK(t, 'mwf-ok-grn-4');
    await net(t);
    expect(sent(srv, 'wfDecide').single, {'action': 'wfDecide', 'kind': 'grn', 'no': 4, 'ok': true, 'note': ''});
    expect(find.text('GRN 4 verified – it waits for its approval.'), findsOneWidget);
    expect(find.byKey(const Key('gr-mine')), findsNothing, reason: 'nothing waits for me now');
    expect(inK('gr-wf-4', 'Waiting approval'), findsOneWidget);
    await settle(t, 4200);
    await t.pageBack();
    await net(t);
    // ---- Issue & Return: return 1 (of outward 7) waits for MY approval – sent back, saying why
    await reach(t, 'sw-issue', 'st-work');
    await tapK(t, 'sw-issue');
    await net(t);
    expect(find.byKey(const Key('is-mine')), findsOneWidget);
    expect(inK('mwf-ok-ret-1', 'Approve'), findsOneWidget);
    await tapK(t, 'mwf-no-ret-1');
    await settle(t, 600);
    expect(find.text('Send back Return 1?'), findsOneWidget);
    await t.tap(find.byKey(const Key('note-ok')));
    await settle(t, 400);
    expect(find.text('Say why it is sent back.'), findsOneWidget, reason: 'why is needed');
    await t.enterText(find.byKey(const Key('note-box')), '3 came back, not 1');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(sent(srv, 'wfDecide').last, {'action': 'wfDecide', 'kind': 'ret', 'no': 1, 'ok': false, 'note': '3 came back, not 1'});
    expect(find.text('Return 1 sent back.'), findsOneWidget);
    expect(find.byKey(const Key('is-mine')), findsNothing);
    await settle(t, 4200);
  });

  testWidgets('(3.55.0) Store – Purchase (every site): the ticked lines of a site → its PO; a vendor nearly one written before asked ("Use")', (t) async {
    final srv = FakeServer()..storePages = {...FakeServer().storePages, 'purchase': 'Edit'};
    ((srv.storeReqs[1]['lines'] as List)[0] as Map)['brand'] = 'Madhur';      // (3.58.0) the requirement's brand – carried to the PO
    await openStoreWork(t, server: srv);
    await tapK(t, 'sw-purchase');
    await net(t);
    expect(find.textContaining("The Store's step 2 is not run in this site's database yet."), findsOneWidget, reason: 'a site without it said so');
    expect(find.text('REQ 1 · Sugar – Madhur – to order 30 Kg'), findsOneWidget, reason: '(3.58.0) the brand after the item');
    await tapK(t, 'pu-t-S1-1-1');
    await t.pump();
    await tapK(t, 'pu-mk-S1');
    await net(t);
    expect(sent(srv, 'purItems').single['site'], 'S1');
    await t.enterText(box('pof-ven'), 'Shree Traders');
    // (3.62.0) the PO's own fields above the items now – each line reached first
    await reach(t, 'pol-q-0', 'pof');
    expect((t.widget<TextField>(box('pol-q-0')).controller!).text, '30', reason: 'what is still to order');
    await reach(t, 'pol-r-0', 'pof');
    await t.enterText(box('pol-r-0'), '50');
    await settle(t, 300);
    // (3.58.0) the line is taller now (its Brand and Material specification) – each total read by its own key
    final pof = find.descendant(of: find.byKey(const Key('pof')), matching: find.byType(Scrollable)).first;
    final totals = <String>[];
    for (final k in ['pol-m-0', 'pof-total']) {
      await t.dragUntilVisible(find.byKey(Key(k)), pof, const Offset(0, -120));
      totals.add((t.widget(find.byKey(Key(k))) as dynamic).data as String);
    }
    expect(totals, ['Taxable ₹1,500.00 · GST ₹75.00 · Total ₹1,575.00', 'Taxable ₹1,500.00 · GST ₹75.00 · Total ₹1,575.00'], reason: 'the line and the PO');
    await tapK(t, 'po-save');
    await net(t);
    expect(find.text('The same vendor?'), findsOneWidget);
    await t.tap(find.byKey(const Key('swc-Shri Traders')));
    await net(t);
    final ps = sent(srv, 'poSave');
    expect(ps.length, 2);
    expect((ps.last['po'] as Map)['vendor'], 'Shri Traders');
    expect((ps.last['po'] as Map)['lines'], [{'code': 'ITM-0002', 'qty': '30', 'rate': '50', 'disc_pct': '', 'hsn': '1701', 'gst_pct': '5', 'req_no': 1, 'req_line': 1, 'brand': 'Madhur', 'spec': ''}], reason: '(3.62.0) its Disc. % and HSN (the item\'s)');
    expect(ps.last['site'], 'S1');
    expect(find.textContaining('PO 2 of S1 saved'), findsOneWidget);
  });

  testWidgets('(3.62.0 – the Store\'s step 5) the PO in his Diesel PO\'s format: Disc. % and HSN in each line, Credit Period, Site Contact, Shipping Address, Freight, Load / Unload (a new PO starts with the site\'s papers); it waits for its approval – Reject (why) / Approve; Print in his format; the Purchase Requisition Form; the papers; before step 5 said so', (t) async {
    final srv = FakeServer()..storePages = {...FakeServer().storePages, 'purchase': 'Edit'};
    final papers = <(String, String)>[];
    storePaperSink = (h, title) => papers.add((title, h));
    addTearDown(() => storePaperSink = null);
    String txt(String k) => (t.widget<TextField>(box(k)).controller!).text;
    Object? data(String k) => (t.widget(find.byKey(Key(k))) as dynamic).data;
    await openStoreWork(t, server: srv);
    await tapK(t, 'sw-purchase');
    await net(t);
    await tapK(t, 'pu-t-S1-1-1');
    await t.pump();
    await tapK(t, 'pu-mk-S1');
    await net(t);
    expect([txt('pof-sc'), txt('pof-ship')], ['Store Keeper : 90000 00000', 'VTR Site Store\nNH 848'], reason: 'a new PO: the site\'s papers');
    await t.enterText(box('pof-ven'), 'Shri Traders');
    await t.enterText(box('pof-cr'), '30');
    await reach(t, 'pof-fr', 'pof');
    await t.enterText(box('pof-fr'), '100');
    await reach(t, 'pof-lu', 'pof');
    await t.enterText(box('pof-lu'), '50');
    await reach(t, 'pof-terms', 'pof');
    expect(txt('pof-terms'), '1. Payment within 30 days.\n2. Material as per the specification.');
    await reach(t, 'pol-r-0', 'pof');
    await t.enterText(box('pol-r-0'), '50');
    await reach(t, 'pol-d-0', 'pof');
    await t.enterText(box('pol-d-0'), '10');
    await settle(t, 300);
    await reach(t, 'pol-h-0', 'pof');
    expect(txt('pol-h-0'), '1701', reason: 'the item\'s HSN');
    await reach(t, 'pol-m-0', 'pof');
    expect(data('pol-m-0'), 'Taxable ₹1,350.00 · GST ₹67.50 · Total ₹1,417.50', reason: 'the line less its Disc. %, as the web');
    await reach(t, 'pof-total', 'pof');
    expect(data('pof-total'), 'Taxable ₹1,350.00 · GST ₹67.50 · Freight ₹100.00 · Load / Unload ₹50.00 · Total ₹1,567.50');
    await tapK(t, 'po-save');
    await net(t);
    final po = sent(srv, 'poSave').single['po'] as Map;
    expect([po['credit_days'], po['site_contact'], po['ship_to'], po['freight'], po['load_unload'], po['terms']],
        ['30', 'Store Keeper : 90000 00000', 'VTR Site Store\nNH 848', '100', '50', '1. Payment within 30 days.\n2. Material as per the specification.']);
    expect(po['lines'], [{'code': 'ITM-0002', 'qty': '30', 'rate': '50', 'disc_pct': '10', 'hsn': '1701', 'gst_pct': '5', 'req_no': 1, 'req_line': 1, 'brand': '', 'spec': ''}]);
    expect(find.text('PO 2 of S1 saved – ₹1,575.00 – it waits for its approval.'), findsOneWidget);
    // its approval: waiting for whom; Reject – why is needed
    await reach(t, 'po-appr-S1-1', 'pu-list');
    expect(data('po-appr-S1-1'), 'Waiting approval – Sujit Mule');
    await tapK(t, 'po-no-S1-1');
    await settle(t, 600);
    await t.tap(find.byKey(const Key('note-ok')));
    await settle(t, 400);
    expect(find.text('Say why the PO is rejected (the one who made it sees it).'), findsOneWidget);
    await t.enterText(find.byKey(const Key('note-box')), 'Rate too high');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    expect(sent(srv, 'poDecide').single, {'action': 'poDecide', 'no': 1, 'ok': false, 'note': 'Rate too high'});
    expect(find.text('PO 1 rejected.'), findsOneWidget);
    await reach(t, 'po-appr-S1-1', 'pu-list');
    expect(data('po-appr-S1-1'), 'Rejected – "Rate too high" – Sujit Mule');
    expect(find.byKey(const Key('po-ok-S1-1')), findsNothing);
    // Print – his format (the supplier from the Vendor Master, the PO's details, the totals, the terms, Prepared / Approved By)
    await tapK(t, 'po-print-S1-1');
    await net(t);
    expect(sent(srv, 'poGet').single, {'action': 'poGet', 'site': 'S1', 'no': 1});
    expect(papers.single.$1, 'PO RCL/VTR/PO/2026/0001');
    for (final w in ['Purchase Order', 'Supplier Details', 'Shri Traders', 'Nashik Road', 'PO Details', 'RCL/VTR/PO/2026/0001', '13-10-2026', '30 Days', 'Store Keeper : 90000 00000', 'VTR Site Store<br>NH 848', 'Sugar', '1701', '2,000.00',
      'Total Freight Charges', 'TOTAL AMOUNT (Rs.)', '2,100.00', 'Two Thousand One Hundred Rupees Only', '1. Payment within 30 days.', 'Prepared By', '(rejected)', 'This Purchase Order is computer generated it does not require signature.', 'data:image/png;base64,']) {
      expect(papers.single.$2, contains(w), reason: w);
    }
    Navigator.of(t.element(find.byKey(const Key('pu-list')))).pop();
    await net(t);
    // Purchase Orders of this site: one waiting again – Approve; his name after it
    srv.po1Appr = {'appr': 'Waiting', 'appr_name': null, 'appr_note': null};
    await reach(t, 'sw-po', 'st-work');      // (the Work tab's list was scrolled by the page opened before)
    await tapK(t, 'sw-po');
    await net(t);
    expect(data('po-appr-S1-1'), 'Waiting approval – Sujit Mule');
    await tapK(t, 'po-ok-S1-1');
    await net(t);
    expect(sent(srv, 'poDecide').last, {'action': 'poDecide', 'no': 1, 'ok': true});
    expect(find.text('PO 1 approved.'), findsOneWidget);
    expect(data('po-appr-S1-1'), 'Approved by Sujit Mule');
    Navigator.of(t.element(find.byKey(const Key('pol-list')))).pop();
    await net(t);
    // the requirement's Purchase Requisition Form
    await reach(t, 'sw-req', 'st-work');      // (the Work tab's list was scrolled by the page opened before)
    await tapK(t, 'sw-req');
    await net(t);
    await tapK(t, 'rq-print-1');
    await net(t);
    expect(papers.last.$1, 'Requirement RCL/VTR/PR/2026/0001');
    for (final w in ['Purchase Requisition Form', 'VTR Site – NH 848', 'Site work – Ch 540+450 toe wall', 'RCL/VTR/PR/2026/0001', '12/10/2026', 'ITM-0002', 'Sugar', 'canteen', '50.0', 'Amol Patil', 'Prepared By', 'Checked By', 'Sujit Mule', 'Approved By']) {
      expect(papers.last.$2, contains(w), reason: w);
    }
    Navigator.of(t.element(find.byKey(const Key('rq-list')))).pop();
    await net(t);
    // the papers of the site (Store Admin)
    await reach(t, 'sw-settings', 'st-work');      // (the Work tab's list was scrolled by the page opened before)
    await tapK(t, 'sw-settings');
    await net(t);
    await tapK(t, 'pp-open');
    await settle(t, 600);
    expect([txt('pp-email'), txt('pp-sc')], ['store@rcl.test', 'Store Keeper : 90000 00000']);
    await t.enterText(box('pp-prefix'), 'RCL/VTR');
    await t.enterText(box('pp-cin'), 'U00000MH0000PLC000000');
    await reach(t, 'pp-saddr', 'op-list');
    await t.enterText(box('pp-saddr'), 'Site office at Valshind\nBhiwandi'); // (3.65.0) the site's address on the papers
    await settle(t, 300);
    await reach(t, 'pp-nos', 'op-list');
    expect(data('pp-nos'), 'PO No: RCL/VTR/PO/2026/0001 · Indent No: RCL/VTR/PR/2026/0001');
    await tapK(t, 'pp-save');
    await net(t);
    expect(sent(srv, 'papersSave').single, {'action': 'papersSave', 'prefix': 'RCL/VTR', 'email': 'store@rcl.test', 'phone': '', 'cin': 'U00000MH0000PLC000000', 'web': '', 'site_contact': 'Store Keeper : 90000 00000', 'ship_to': 'VTR Site Store\nNH 848',
      'terms': '1. Payment within 30 days.\n2. Material as per the specification.', 'site_address': 'Site office at Valshind\nBhiwandi'});
    expect(find.text('The papers are saved.'), findsOneWidget);
    // a site before the Store's step 5: the PO's own fields are not asked – said why
    srv.storeStep5 = false;
    Navigator.of(t.element(find.byKey(const Key('op-list')))).pop();
    await net(t);
    await reach(t, 'sw-purchase', 'st-work');
    await tapK(t, 'sw-purchase');
    await net(t);
    await tapK(t, 'pu-t-S1-1-1');
    await t.pump();
    await tapK(t, 'pu-mk-S1');
    await net(t);
    expect(find.byKey(const Key('pof-cr')), findsNothing);
    await reach(t, 'pof-step5', 'pof');
    expect(find.byKey(const Key('pof-step5')), findsOneWidget);
  });

  testWidgets('(3.57.0) Store – Inward (GRN): his inward register – the check (a row corrected, a duplicate deleted, the AI\'s names ticked), Import in parts; the list in his columns', (t) async {
    final srv = await openStoreWork(t);
    final bytes = File('test/fixtures/sheets/grn_reg.xlsx').readAsBytesSync(), was = pickSheetFile;
    pickSheetFile = () async => (name: 'INWARD_test.xlsx', bytes: bytes);
    addTearDown(() => pickSheetFile = was);
    // what the check must show (core/grn_reg.dart – proven against the web's code in grn_reg_test.dart), with the Store's side as the fake's
    final rows = grnReadRows(grnPickSheet(readSheets(bytes))!), info0 = <String, dynamic>{'items': [], 'vendors': [], 'grns': [], 'next': 1};
    final p0 = grnPlan(rows, info0, GrnChoice(), '2026-10-28');
    Finder tileHas(String k, String v) => find.descendant(of: find.byKey(Key(k)), matching: find.text(v));
    final regList = find.descendant(of: find.byKey(const Key('rg-list')), matching: find.byType(Scrollable)).first;
    Future<void> top() async {
      await t.drag(find.byKey(const Key('rg-list')), const Offset(0, 9000));
      await settle(t, 600);
    }

    Future<void> downTo(Finder f, String what) async {
      for (var i = 0; i < 80 && f.evaluate().isEmpty; i++) {
        await t.drag(regList, const Offset(0, -300));
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(f, findsOneWidget, reason: 'scrolled down to $what');
      await seen(t, f);
      await settle(t, 300);
    }

    Future<void> down(String k) => downTo(find.byKey(Key(k)), '"$k"');

    await tapK(t, 'sw-grn');
    await net(t);
    // the list in his columns: the GRN No as in the file, Challan No, Invoice No., TCS, the line's Taxable / GST / Gross / Remark
    expect(find.textContaining('GRN 342-A · 13-10-2026'), findsOneWidget);
    expect(find.textContaining('Challan No CH-5 · Invoice No. OH-77 · Invoice Date 12-10-2026 · Vehicle No MH04AB1234 · TCS ₹12.50'), findsOneWidget);
    expect(find.textContaining('Taxable ₹1,000.00 · GST ₹180.00 · Gross ₹1,180.00 · Mechanical'), findsOneWidget);
    await tapK(t, 'gr-imp');
    await net(t);
    expect(find.byKey(const Key('rg-list')), findsOneWidget);
    expect(find.textContaining('sheet "MAIN SHEET INWARD1" – ${rows.length} rows (the other sheets – Summary, Binding Wire – are not the register)'), findsOneWidget);
    expect(tileHas('rg-t-docs', '${(p0['docs'] as List).length}'), findsOneWidget);
    expect(tileHas('rg-t-look', '${(p0['look'] as List).length}'), findsOneWidget);
    expect(tileHas('rg-t-dups', '${(p0['dups'] as List).length}'), findsOneWidget);
    expect(tileHas('rg-t-next', '${p0['next']}'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/68_grn_reg_check.png'));
    // a row to look at: its quantity typed – the row goes in
    final two = (p0['look'] as List).cast<Map>().firstWhere((l) => l['qty'] == 'two');
    await tapK(t, 'rg-lke-${two['line']}');
    await settle(t, 600);
    expect(find.byKey(const Key('rge-ok')), findsOneWidget, reason: 'the row\'s box is open');
    await t.enterText(box('rge-qty'), '2');
    await settle(t, 300);
    expect(t.widget<TextField>(box('rge-qty')).controller!.text, '2');
    await tapK(t, 'rge-ok');
    await settle(t, 800);
    String texts(String k) => t.widgetList<Text>(find.descendant(of: find.byKey(Key(k)), matching: find.byType(Text))).map((x) => x.data).join(' | ');
    expect(find.byKey(const Key('rge-ok')), findsNothing, reason: 'the row\'s box is closed by "Check this row again"');
    expect(find.byKey(Key('rg-lk-${two['line']}')), findsNothing, reason: 'the row corrected is no longer to look at – GRNs tile: ${texts('rg-t-docs')} · look tile: ${texts('rg-t-look')}');
    // (the list is built as it is scrolled: the tiles are at its top, the sections below)
    await top();
    expect(tileHas('rg-t-docs', '${(p0['docs'] as List).length + 1}'), findsOneWidget, reason: texts('rg-t-docs'));
    expect(tileHas('rg-t-look', '${(p0['look'] as List).length - 1}'), findsOneWidget);
    // a duplicate deleted (the others kept)
    final d0 = ((p0['dups'] as List).first as Map)['line'];
    await down('rg-dup-$d0');
    await tapK(t, 'rg-dup-$d0');
    await settle(t, 600);
    await top();
    expect(find.textContaining('${(p0['dups'] as List).length - 1} kept (imported) · 1 deleted'), findsOneWidget);
    // the AI (its part opened): the names written differently, none ticked until he ticks; "✓ all" – the items written in two ways one item
    final aiPart = find.byKey(const PageStorageKey<String>('rg-s-ai'));
    await downTo(aiPart, 'the AI\'s part');
    await t.tap(aiPart);
    await settle(t, 600);
    await down('rg-ai');
    await tapK(t, 'rg-ai');
    await net(t, 2500);
    await net(t, 1500);
    expect(sent(srv, 'regNames').map((x) => x['list']).toSet(), {'supplier', 'item', 'category'});
    await down('rg-ai-item-Air Fliter 16 No');
    expect(find.byKey(const Key('rg-ai-item-Air Fliter 16 No')), findsOneWidget);
    expect(t.widget<CheckboxListTile>(find.byKey(const Key('rg-ai-item-Air Fliter 16 No'))).value, false);
    final fixed = {
      for (final n in grnNamesOf(rows)['item']!.keys)
        if (RegExp('Hydrolic|Fliter|Bindding').hasMatch(n)) n: n.replaceAll('Hydrolic', 'Hydraulic').replaceAll('Fliter', 'Filter').replaceAll('Bindding', 'Binding'),
    };
    final ch = GrnChoice(gone: {d0 as int: true}, edit: {two['line'] as int: {'qty': '2'}});
    final before = (grnPlan(rows, info0, ch, '2026-10-28')['newItems'] as List).length;
    ch.fix['item'] = fixed;
    final after = (grnPlan(rows, info0, ch, '2026-10-28')['newItems'] as List).length;
    expect(after, lessThan(before));
    await top();
    await down('rg-aiall-item');
    await tapK(t, 'rg-aiall-item');
    await settle(t, 800);
    await down('rg-ai-item-Air Fliter 16 No');
    expect(t.widget<CheckboxListTile>(find.byKey(const Key('rg-ai-item-Air Fliter 16 No'))).value, true);
    await top();
    expect(tileHas('rg-t-items', '$after'), findsOneWidget, reason: 'the items written in two ways one item once ticked');
    // Import: asked first, then the parts – suppliers, items, GRNs (the file's GRN No)
    await tapK(t, 'rg-go');
    await settle(t, 800);
    expect(find.textContaining('the next new GRN: ${p0['next']}'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t, 2500);
    final docsSent = [for (final x in sent(srv, 'regGrns')) ...(x['docs'] as List)];
    expect(docsSent.length, (p0['docs'] as List).length + 1);
    expect(docsSent.any((d) => (d as Map)['ref'] == '342-A'), true);
    expect([sent(srv, 'regVendors').length, sent(srv, 'regItems').length], [1, 1]);
    await top();
    expect(find.textContaining('${docsSent.length} GRN saved'), findsOneWidget);
    expect(tileHas('rg-t-docs', '0'), findsOneWidget, reason: 'the check again: every GRN already in the Store');
    expect(tileHas('rg-t-have', '${docsSent.length}'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/69_grn_reg_done.png'));
  }, tags: ['golden']);

  testWidgets('(3.58.0 – the Store\'s step 4) a new GRN: its GRN No by itself (the next), changed by hand – one already used: refused, the next free one back in its box; "77" typed: saved with it; Clear: the next again; before step 4: the next, not to be changed', (t) async {
    final srv = await openStoreWork(t);
    await tapK(t, 'sw-grn');
    await net(t);
    await tapK(t, 'gr-new');
    await net(t);
    TextField refBox() => t.widget<TextField>(box('grf-ref'));
    expect([refBox().controller!.text, refBox().enabled], ['5', true], reason: 'the next GRN No; step 4 there – it can be changed');
    expect(sent(srv, 'grnNext').length, 1);
    await t.enterText(box('grf-sup'), 'Shri Traders');
    await tapK(t, 'grl-add');
    await settle(t, 800);
    await t.tap(find.byKey(const Key('pick-ITM-0002 · Sugar (Kg)')));
    await settle(t, 600);
    await t.enterText(box('grl-q-0'), '2');
    await t.enterText(box('grl-r-0'), '100');
    await t.enterText(box('grf-ref'), '342-A');
    await settle(t, 300);
    await tapK(t, 'gr-save');
    await net(t);
    expect(find.textContaining('GRN No 342-A is already used by another GRN – the next free number is 5. Nothing was saved.'), findsOneWidget);
    expect(refBox().controller!.text, '5', reason: 'the next free one in its box');
    await settle(t, 4000);
    // Clear: the next number again (as the web's form drawn again)
    await t.enterText(box('grf-ref'), '90');
    await tapK(t, 'grf-clear');
    await settle(t, 600);
    await t.tap(find.widgetWithText(FilledButton, 'Clear'));
    await net(t);
    expect([refBox().controller!.text, sent(srv, 'grnNext').length], ['5', 2]);
    await t.enterText(box('grf-sup'), 'Shri Traders');
    await tapK(t, 'grl-add');
    await settle(t, 800);
    await t.tap(find.byKey(const Key('pick-ITM-0002 · Sugar (Kg)')));
    await settle(t, 600);
    await t.enterText(box('grl-q-0'), '2');
    await t.enterText(box('grl-r-0'), '100');
    await t.enterText(box('grf-ref'), '77');
    await settle(t, 300);
    await tapK(t, 'gr-save');
    await net(t);
    expect((sent(srv, 'grnSave').last['grn'] as Map)['ref'], '77');
    expect(find.textContaining('GRN 77 saved'), findsOneWidget);
    // a site before the Store's step 4: the next number, not to be changed
    srv.storeStep4 = false;
    await settle(t, 4000);
    await tapK(t, 'gr-new');
    await net(t);
    expect([refBox().controller!.text, refBox().enabled], ['5', false]);
  });

  testWidgets('(3.63.0 – the Store\'s step 6) a GRN\'s discount on a line (10 % on Basic; ₹100 after GST) and on the whole bill (2 % on Basic) – the money as the server; the item\'s code apart; against a PO its Qty, received before, the shortage; without step 6: a note, no discount; the list shows the discount and the net rate', (t) async {
    final srv = FakeServer()..storeStep6 = true;
    await openStoreWork(t, server: srv);
    await tapK(t, 'sw-grn');
    await net(t);
    expect(find.textContaining('Disc. ${rs(118)} · Net rate 88.2'), findsOneWidget, reason: 'the GRN of step 6 in the list: what came off, its net rate');
    expect(find.textContaining('Bill discount 2% on Basic – ${rs(18)}'), findsOneWidget);
    await tapK(t, 'gr-new');
    await net(t);
    expect([find.byKey(const Key('grf-bd')), find.byKey(const Key('grf-nodisc'))].map((f) => f.evaluate().length), [1, 0]);
    await t.enterText(box('grf-sup'), 'Shri Traders');
    await tapK(t, 'grl-add');
    await settle(t, 800);
    await t.tap(find.byKey(const Key('pick-ITM-0002 · Sugar (Kg)')));
    await settle(t, 600);
    expect(find.text('Item Code ITM-0002'), findsOneWidget, reason: 'the code apart from the name');
    await t.enterText(box('grl-q-0'), '10');
    await t.enterText(box('grl-r-0'), '100');
    await t.enterText(box('grl-gd-0'), '10%');
    await tapK(t, 'grl-add');
    await settle(t, 800);
    await t.tap(find.byKey(const Key('pick-ITM-0001 · Hydraulic Hose 1/2 inch (Mtr)')));
    await settle(t, 600);
    await t.enterText(box('grl-q-1'), '4');
    await t.enterText(box('grl-r-1'), '250');
    await t.enterText(box('grl-gd-1'), '100');
    await seen(t, find.byKey(const Key('grl-go-1-gst')));
    await tapK(t, 'grl-go-1-gst');
    await seen(t, find.byKey(const Key('grf-bd')));
    await t.enterText(box('grf-bd'), '2%');
    await settle(t, 400);
    // the server's checkGrn: 1000 − 10 % = 900, 1000; the bill's 2 % of 1900 = 38 shared 18 / 20 → 882 / 980; GST 44.10 / 176.40; less ₹100 after GST
    String txt(String k) => ((t.widget(find.byKey(Key(k))) as dynamic).data as String?) ?? ''; // (the app's own Text – ui/t.dart)
    expect(txt('grl-m-0'), 'Basic ${rs(1000)} · Disc. ${rs(118)} · Taxable ${rs(882)} · GST ${rs(44.1)} · Gross ${rs(926.1)}');
    expect(txt('grl-m-1'), 'Basic ${rs(1000)} · Disc. ${rs(120)} · Taxable ${rs(980)} · GST ${rs(176.4)} · Gross ${rs(1056.4)}');
    expect(txt('grf-total'), 'Basic ${rs(2000)} · Discount ${rs(238)} (the bill ${rs(38)}) · Taxable ${rs(1862)} · GST ${rs(220.5)} · Gross ${rs(1982.5)}');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/73_grn_discount.png'));
    await tapK(t, 'gr-save');
    await net(t);
    final g = sent(srv, 'grnSave').last['grn'] as Map;
    expect([g['bill_disc'], g['bill_disc_on']], ['2%', 'basic']);
    expect([for (final l in g['lines'] as List) [(l as Map)['code'], l['disc'], l['disc_on']]], [['ITM-0002', '10%', 'basic'], ['ITM-0001', '100', 'gst']]);
    expect(find.textContaining('GRN 5 saved'), findsOneWidget);
    // against PO 1 (20 Kg of Sugar, 5 came before): its Qty, what came before, the shortage after this GRN
    await settle(t, 4000);
    await tapK(t, 'gr-new');
    await net(t);
    await tapK(t, 'grf-po');
    await settle(t, 600);
    await t.tap(find.textContaining('PO 1 – Shri Traders').last);
    await settle(t, 600);
    expect(txt('grl-po-0'), 'PO Qty 20 · Received before 5 · Shortage 0', reason: 'all that is still to come');
    await t.enterText(box('grl-q-0'), '10');
    await settle(t, 300);
    expect(txt('grl-po-0'), 'PO Qty 20 · Received before 5 · Shortage 5 Kg', reason: '"po qty ste 10 ania ahe 5" – the PO stays open for it');
    expect(sent(srv, 'poOpen').every((x) => x['grn'] == null), true, reason: 'a new GRN');
    Navigator.of(t.element(find.byKey(const Key('grf')))).pop();
    await net(t);
    // a site without step 6: no discount (a note), nothing of it sent
    srv.storeStep6 = false;
    await tapK(t, 'gr-new');
    await net(t);
    expect([find.byKey(const Key('grf-bd')), find.byKey(const Key('grf-nodisc'))].map((f) => f.evaluate().length), [0, 1]);
  }, tags: ['golden']);

  testWidgets('(3.55.0) Store – Inward (GRN) against a PO (its lines still to come; more than it asked first); Issue to a machinery; a Return', (t) async {
    final srv = await openStoreWork(t);
    await tapK(t, 'sw-grn');
    await net(t);
    expect(find.byKey(const Key('gr-4')), findsOneWidget);
    await tapK(t, 'gr-new');
    await net(t);
    // (as the web's GRN form) Clear: asked first, the form empty again
    await t.enterText(box('grf-sup'), 'Someone Typed');
    await tapK(t, 'grf-clear');
    await settle(t, 600);
    expect(find.text('Clear the form?'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Clear'));
    await settle(t, 600);
    expect(t.widget<TextField>(box('grf-sup')).controller!.text, '');
    await tapK(t, 'grf-po');
    await settle(t, 600);
    await t.tap(find.textContaining('PO 1 – Shri Traders').last);
    await settle(t, 600);
    expect((t.widget<TextField>(box('grl-q-0')).controller!).text, '15', reason: 'what is still to come of PO 1');
    expect((t.widget<TextField>(box('grf-sup')).controller!).text, 'Shri Traders');
    await t.enterText(box('grl-q-0'), '20');
    await settle(t, 300);
    await tapK(t, 'gr-save');
    await net(t);
    expect(find.text('More than the PO'), findsOneWidget);
    await t.tap(find.text('Take it in'));
    await net(t);
    final gs = sent(srv, 'grnSave');
    expect([gs.length, gs.last['confirmOver'], (gs.last['grn'] as Map)['po_no'], ((gs.last['grn'] as Map)['lines'] as List).single], [2, true, 1, {'code': 'ITM-0002', 'qty': '20', 'rate': '100', 'gst_pct': '5', 'po_line': 1, 'remark': ''}]);
    expect(find.textContaining('GRN 5 saved'), findsOneWidget);
    Navigator.of(t.element(find.byKey(const Key('gr-list')))).pop();
    await net(t);
    // Issue to a machinery, a returnable line
    await tapK(t, 'sw-issue');
    await net(t);
    await tapK(t, 'is-new');
    await net(t);
    await tapK(t, 'isf-kind');
    await settle(t, 600);
    await t.tap(find.text('Machinery').last);
    await settle(t, 600);
    await tapK(t, 'isf-mach');
    await settle(t, 600);
    await t.tap(find.text('Sany 210 (No.1) – Excavator').last);
    await settle(t, 600);
    await tapK(t, 'isl-add');
    await settle(t, 800);
    await t.tap(find.byKey(const Key('pick-ITM-0001 · Hydraulic Hose 1/2 inch (Mtr)')));
    await settle(t, 600);
    await t.enterText(box('isl-q-0'), '2');
    await tapK(t, 'isl-ret-0');
    await t.pump();
    await tapK(t, 'is-save');
    await net(t);
    final iss = sent(srv, 'issueSave').single['issue'] as Map;
    expect([iss['to_kind'], iss['machinery'], iss['party'], iss['debit']], ['Machinery', 'Sany 210 (No.1)', '', false]);
    expect((iss['lines'] as List).single, {'code': 'ITM-0001', 'qty': '2', 'returnable': true, 'serial': '', 'rate': '', 'gst_pct': '', 'remark': ''});
    expect(find.textContaining('Outward 8 saved'), findsOneWidget);
    // a return of outward 7 (3 of 4 still out)
    await tapK(t, 'is-ret-7');
    await net(t);
    expect(find.textContaining('still out 3'), findsOneWidget);
    await t.enterText(box('rt-q-0'), '1');
    await tapK(t, 'rt-save');
    await net(t);
    expect((sent(srv, 'retSave').single['ret'] as Map)['lines'], [{'issue_line': 71, 'qty': '1', 'remark': ''}]);
    expect(find.text('Return 2 saved.'), findsOneWidget);
  });

  testWidgets('(3.55.0) Store – Stock & Reports (shown, Excel); Opening stock (only the changed rows) and the numbers', (t) async {
    final srv = await openStoreWork(t);
    final files = catchFiles();
    await tapK(t, 'sw-reports');
    await net(t);
    expect(sent(srv, 'report').first, {'action': 'report', 'kind': 'stock', 'date': '2026-10-14', 'cat': '', 'below': false, 'all': false});
    expect(find.text('Hydraulic Hose 1/2 inch'), findsOneWidget);
    expect(find.text('3,550'), findsOneWidget, reason: 'the total');
    await tapK(t, 'sr-xl');
    await net(t);
    expect(files.single.$1, startsWith('Stock_'));
    final rows = readSheets(files.single.$2).first.rows;
    expect(rows.any((r) => r.length > 3 && r[0] == 'ITM-0002' && r[2] == 10.5), true, reason: 'numbers as numbers');
    Navigator.of(t.element(find.byKey(const Key('sr-list')))).pop();
    await net(t);
    await tapK(t, 'sw-settings');
    await net(t);
    // the numbers (on top)
    await t.enterText(box('nm-grn'), '101');
    await tapK(t, 'nm-save');
    await net(t);
    expect(sent(srv, 'numbersSave').single, {'action': 'numbersSave', 'GRN': '101', 'OUT': '8'});
    // the opening stock: only the changed rows
    expect((t.widget<TextField>(box('op-q-ITM-0001')).controller!).text, '20');
    await reach(t, 'op-q-ITM-0002', 'op-list');
    await t.enterText(box('op-q-ITM-0002'), '4');
    await t.enterText(box('op-r-ITM-0002'), '95');
    await tapK(t, 'op-save');
    await net(t);
    expect(sent(srv, 'openingSave').single, {'action': 'openingSave', 'date': '2026-10-01', 'rows': [{'code': 'ITM-0002', 'qty': '4', 'rate': '95', 'date': '2026-10-01'}]});
    expect(find.text('Opening stock saved – 1 item(s).'), findsOneWidget);
  });

  Future<void> more(WidgetTester t, String item) async {
    await t.tap(find.byKey(const Key('en-more')));
    await settle(t, 600);
    await t.tap(find.byKey(Key(item)));
    await net(t);
  }

  // (3.31.7, Mechanical update-149) the Log Book Debit Statement: the statement, Change rates (one / all shown), Import party + rate
  Future<void> openLdebit(WidgetTester t) async {
    await t.tap(find.byKey(const Key('tab-reports')));
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    // one machinery, many dates: the next row is the next day; the KM its meter gives (update-187: an earlier day is the Admin's – a
    // user dates only today)
    s.admin = true;
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    await seen(t, find.text('Store'));
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    expect(find.text('Can transfer up to 850 Ltr – saving asks to keep it as stock short'), findsOneWidget, reason: '(3.85.0) the save asks "keep it as stock short?"');
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
    // back from the form (its own back arrow) to the list
    Future<void> formBack() async {
      await t.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await net(t);
    }
    // from the list to the grid
    Future<void> toGrid() async {
      await t.tap(find.byTooltip('All entries'));
      await net(t);
    }
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    // Diesel Issue: only VTR Store – shown although one (he sees where the diesel comes from), chosen
    await newEntry('Diesel Issue');
    expect(find.text('Diesel from'), findsOneWidget);
    expect(chip('VTR Store'), findsOneWidget);
    expect(chip('Dispenser'), findsNothing);
    expect(t.widget<ChoiceChip>(chip('VTR Store')).selected, true);
    expect(srv.issueBal.last.last, 'VTR Store', reason: 'the stock of his source');
    await formBack();
    await toGrid();
    // Diesel Transfer: From only VTR Store; To every place, ready on the other one
    await newEntry('Transfer');
    expect(chip('VTR Store'), findsNWidgets(2), reason: 'From and To');
    expect(chip('Dispenser'), findsOneWidget, reason: 'To only');
    expect(t.widget<ChoiceChip>(chip('Dispenser')).selected, true);
    final a = srv.extraCalls.lastWhere((c) => c['fn'] == 'getTransferBalance')['args'] as List;
    expect([a[2], a[3]], ['VTR Store', 'Dispenser']);
    await formBack();
    // "Multiple entries" of transfers: From only his
    await more(t, 'en-many');
    final f0 = t.widget(find.byKey(const Key('tm-from-0'))) as dynamic, t0 = t.widget(find.byKey(const Key('tm-to-0'))) as dynamic;
    expect([f0.items, f0.value, t0.items, t0.value], [['VTR Store'], 'VTR Store', ['Dispenser', 'VTR Store'], 'Dispenser']);
    await t.pageBack();
    await net(t);
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
    await formBack();
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

  testWidgets('(3.44.0, Mechanical update-163) fuel: Home shows each fuel on its own; Diesel Issue offers the places of the car\'s fuel (CNG in kg, Electric: none); Transfer To of the From\'s fuel; the Dashboard of one fuel', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Diesel Transfer': 'Edit', 'Dashboard': 'View'})
      ..fuels = true;
    final s = await ready(t, srv);
    expect([s.multiFuel, s.siteFuels, s.placeFuel('PETROL CAN'), s.machine('MH-12-HO-2163')?.fuel, s.machine('MH-25-AJ-2169')?.fuel], [true, ['Diesel', 'Petrol', 'CNG'], 'Petrol', 'CNG', 'Diesel']);
    expect(s.fuelPlaces(s.locations, s.machine('MH-12-HO-1163')), ['PETROL CARD', 'PETROL CAN']);
    expect(s.fuelProblem(s.machine('MH-12-HO-1163'), 'DIESEL CARD'), 'DIESEL CARD holds Diesel and MH-12-HO-1163 runs on Petrol – pick a Petrol place (Asset Master → Fuel).');
    expect(s.fuelProblem(s.machine('MH-12-HO-3163'), 'PETROL CARD'), 'MH-12-HO-3163 runs on Electric – no fuel is issued to it (Asset Master → Fuel).');
    expect([fuelText('Diesel stock 40 L (Ltr)', 'CNG'), fuelText('डिझेल साठा', 'Petrol'), fuelText('Diesel summary', 'Diesel')], ['CNG stock 40 kg (kg)', 'पेट्रोल साठा', 'Diesel summary']);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    // Home: Diesel in big, Petrol and CNG under it – never added together
    expect((t.widget(find.byKey(const Key('home-stock'))) as dynamic).data, '150 L');
    expect((t.widget(find.descendant(of: find.byKey(const Key('home-fuel-Petrol')), matching: find.byType(Text))) as dynamic).data, 'Petrol 120 L');
    expect((t.widget(find.descendant(of: find.byKey(const Key('home-fuel-CNG')), matching: find.byType(Text))) as dynamic).data, 'CNG 32 kg');
    Finder chip(String l) => find.widgetWithText(ChoiceChip, l);
    Future<void> newEntry(String page) async {
      await t.tap(find.byKey(Key('entries-$page')));
      await net(t);
      await t.tap(find.text('New Entry').last);
      await net(t);
    }
    // back from the form (its own back arrow) to the list
    Future<void> formBack() async {
      await t.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await net(t);
    }
    // from the list to the grid
    Future<void> toGrid() async {
      await t.tap(find.byTooltip('All entries'));
      await net(t);
    }
    Future<void> pick(String no) async {
      await t.tap(find.byKey(const Key('d-machine')));
      await settle(t, 800);
      await t.tap(find.text(no).last);
      await net(t);
    }
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await newEntry('Diesel Issue');
    expect(find.text('Fuel from'), findsOneWidget, reason: 'a site with more than one fuel: the source is always shown');
    await pick('MH-12-HO-1163');
    expect([chip('PETROL CARD'), chip('PETROL CAN')].every((f) => f.evaluate().length == 1), true);
    expect(chip('DIESEL CARD'), findsNothing);
    expect(chip('CNG CARD'), findsNothing);
    expect(t.widget<ChoiceChip>(chip('PETROL CARD')).selected, true);
    expect(srv.issueBal.last.last, 'PETROL CARD', reason: 'the stock of the Petrol place');
    await pick('MH-12-HO-2163');
    expect(chip('CNG CARD'), findsOneWidget);
    expect(chip('PETROL CARD'), findsNothing);
    expect(t.widget<ChoiceChip>(chip('CNG CARD')).selected, true);
    expect(find.text('Kg'), findsOneWidget, reason: 'CNG in kg');
    expect(find.text('kg'), findsWidgets);
    await pick('MH-12-HO-3163');
    expect(find.text('MH-12-HO-3163 runs on Electric – no fuel is issued to it (Asset Master → Fuel).'), findsWidgets);
    await formBack();
    await toGrid();
    // Transfer: the To follows the From's fuel
    await newEntry('Transfer');
    await t.tap(chip('PETROL CARD').first);
    await net(t);
    expect(chip('PETROL CARD'), findsNWidgets(2), reason: 'From and To');
    expect(chip('PETROL CAN'), findsNWidgets(2), reason: 'From and To');
    expect(chip('DIESEL CARD'), findsOneWidget, reason: 'From only');
    expect(chip('CNG CARD'), findsOneWidget, reason: 'From only');
    expect(t.widget<ChoiceChip>(chip('PETROL CAN').last).selected, true, reason: 'To: the other Petrol place');
    await formBack();
    await more(t, 'en-many');
    await t.tap(find.byKey(const Key('tm-from-0')));
    await settle(t, 600);
    await t.tap(find.text('PETROL CARD').last);
    await net(t);
    final t0 = t.widget(find.byKey(const Key('tm-to-0'))) as dynamic;
    expect([t0.items, t0.value], [['PETROL CARD', 'PETROL CAN'], 'PETROL CAN']);
    await t.pageBack();
    await net(t);
    await toGrid();
    // the Dashboard: a Fuel chip each; the dashboard of one fuel – its words and unit; the site's stock is not changed by it
    srv.dashAsked.clear();
    await t.tap(find.byKey(const Key('tab-reports')));
    await net(t);
    await t.tap(find.byKey(const Key('rt-diesel')));
    await net(t);
    await t.tap(find.text('Dashboard'));
    await net(t);
    Iterable<dynamic> dashArgs() => srv.dashAsked.where((x) => x['fn'] == 'getDashboard').map((x) => (x['args'] as List).first);
    expect(dashArgs(), contains(equals({'from': '2026-10-01', 'to': '2026-10-14', 'fuel': 'Diesel'})), reason: 'Reports → Overview: the Diesel figures only');
    expect(dashArgs(), contains(equals({'from': '2026-10-14', 'to': '2026-10-14', 'fuel': 'Diesel'})), reason: 'the Dashboard opens on Diesel');
    expect(find.byKey(const Key('dfuel-CNG')), findsOneWidget);
    await t.tap(find.byKey(const Key('dfuel-CNG')));
    await net(t);
    expect(dashArgs().last, {'from': '2026-10-14', 'to': '2026-10-14', 'fuel': 'CNG'});
    expect((srv.dashAsked.lastWhere((x) => x['fn'] == 'getStockLedger')['args'] as List).first['fuel'], 'CNG');
    expect(find.text('CNG summary – all locations'), findsOneWidget);
    expect(find.text('19,895 kg'), findsOneWidget, reason: 'CNG: in kg');
    expect(find.text('19,895 Ltr'), findsNothing);
    expect(s.stockByLoc.keys.toList(), ['DIESEL CARD', 'PETROL CARD', 'PETROL CAN', 'CNG CARD'], reason: 'the site\'s stock stays every place');
  });

  testWidgets('(3.45.0 – Mechanical update-164) a site on fuel cards (HO): Home – the cards\' balances, no stock; no Inward / Transfer; a fill paid by its car\'s card or Cash with its ₹ (no Register photo); Fuel Cards – a payment, the statement; Reports – the fuel cost; the Dashboard – the cards and the cars', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Diesel Inward': 'Edit', 'Diesel Transfer': 'Edit', 'Fuel Cards': 'Edit', 'Dashboard': 'View'})
      ..card = true;
    final s = await ready(t, srv);
    expect([s.cardSite, s.locations, [for (final c in s.cards) c.name], s.siteFuels], [true, <String>[], ['HDFC FUEL', 'SBI CREDIT', 'OLD CARD'], ['Diesel', 'Petrol', 'CNG']]);
    expect(s.payFor(s.machine('MH-12-HO-1163')), ['HDFC FUEL', 'SBI CREDIT', 'Cash'], reason: 'the card of every car, its own card, Cash – never an Inactive card');
    expect(s.payFor(s.machine('MH-12-HO-2163')), ['HDFC FUEL', 'Cash']);
    expect(s.fuelProblem(s.machine('MH-12-HO-1163'), 'HDFC FUEL'), '', reason: 'a card is not a place of a fuel');
    expect(s.fuelProblem(s.machine('MH-12-HO-3163'), 'HDFC FUEL'), 'MH-12-HO-3163 runs on Electric – no fuel is issued to it (Asset Master → Fuel).');
    expect([for (final r in reportsOf(s)) r.$3].where((k) => const {'rdaily', 'rp-stock', 'rp-purchase'}.contains(k)), isEmpty, reason: 'no stock reports (as the web\'s menu)');
    expect([for (final p in startPagesFor(s)) p.$1].where((k) => const {'inward', 'transfer', 'rdaily'}.contains(k)), isEmpty);
    expect([for (final p in startPagesFor(s)) p.$1], contains('cards'));
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    // Home: the Active cards' balances – no stock
    expect(find.byKey(const Key('home-stock')), findsNothing);
    expect((t.widget(find.byKey(const Key('home-cards-total'))) as dynamic).data, '₹ 21,300', reason: '21,800 + (−500)');
    expect(find.text('SBI CREDIT ••9876  ₹ −500'), findsOneWidget);
    expect(find.byKey(const Key('home-card-OLD CARD')), findsNothing, reason: 'an Inactive card');
    // Entries: Diesel Issue and Fuel Cards – no Inward, no Transfer (even with Edit on them)
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    expect(find.byKey(const Key('entries-Diesel Issue')), findsOneWidget);
    expect(find.byKey(const Key('entries-Diesel Inward')), findsNothing);
    expect(find.byKey(const Key('entries-Transfer')), findsNothing);
    expect(find.byKey(const Key('entries-Fuel Cards')), findsOneWidget);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    await t.tap(find.byKey(const Key('en-more')));
    await settle(t, 600);
    expect([find.byKey(const Key('en-many')), find.byKey(const Key('en-import')), find.byKey(const Key('en-template'))].every((f) => f.evaluate().isEmpty), true, reason: 'one fill at a time (its card and ₹)');
    await t.tapAt(const Offset(20, 400));
    await settle(t, 600);
    await t.tap(find.text('New Entry').last);
    await net(t);
    Finder chip(String l) => find.widgetWithText(ChoiceChip, l);
    expect(find.text('Paid by'), findsOneWidget);
    expect(chip('HDFC FUEL · ₹21,800'), findsOneWidget);
    expect(chip('Cash'), findsOneWidget);
    expect(chip('SBI CREDIT · ₹−500'), findsNothing, reason: 'no car yet: only the card of every car');
    await t.tap(find.byKey(const Key('d-machine')));
    await settle(t, 800);
    await t.tap(find.text('MH-12-HO-1163').last);
    await net(t);
    expect(chip('SBI CREDIT · ₹−500'), findsOneWidget, reason: 'its own card');
    expect(find.byKey(const Key('photo-reg')), findsNothing, reason: 'no Register at a site on fuel cards');
    expect(find.byKey(const Key('photo-pump')), findsOneWidget);
    expect(find.byKey(const Key('photo-bill')), findsOneWidget, reason: '(3.90.0, update-215) the Pump bill at a site on fuel cards');
    await t.tap(chip('SBI CREDIT · ₹−500'));
    await settle(t, 400);
    await t.enterText(find.byKey(const Key('d-qty')), '15');
    await settle(t, 300);
    await tapK(t, 'd-amount');
    await t.enterText(find.byKey(const Key('d-amount')), '1500');
    await settle(t, 400);
    expect(find.textContaining('balance now ₹ −500 → after this fill ₹ −2,000 – not enough on the card (the fill is still saved)'), findsOneWidget);
    await seen(t, find.text('Save Diesel Issue'));
    await settle(t, 300);
    await t.tap(find.text('Save Diesel Issue'));
    await net(t);
    expect([srv.saved.last['no'], srv.saved.last['source'], srv.saved.last['qty'], srv.saved.last['amount'], srv.saved.last['rate']], ['MH-12-HO-1163', 'SBI CREDIT', 15, 1500, '']);
    expect(s.card('SBI CREDIT')!.balance, -2000, reason: 'the balances of the save\'s answer');
    expect(find.textContaining('DI-000531  ·  MH-12-HO-1163  ·  15 L  ·  ₹ 1,500 · SBI CREDIT'), findsOneWidget);
    await t.tap(find.text('Done'));
    await net(t);
    await t.tap(find.byTooltip('All entries'));
    await net(t);
    // Fuel Cards: the balances; a payment onto a card; the statement
    await t.tap(find.byKey(const Key('entries-Fuel Cards')));
    await net(t);
    expect((t.widget(find.byKey(const Key('fc-bal-SBI CREDIT'))) as dynamic).data, '₹ −2,000');
    expect(find.byKey(const Key('fc-p-CP-000001')), findsOneWidget);
    await t.tap(find.byKey(const Key('fc-pay')));
    await net(t);
    await t.enterText(find.byKey(const Key('pf-amount')), '2000');
    await t.enterText(find.byKey(const Key('pf-ref')), 'UTR 99');
    await settle(t, 300);
    await tapK(t, 'pf-save');
    await net(t);
    expect(srv.cardCalls.lastWhere((x) => x['fn'] == 'saveCardPayment')['x'], {'date': '2026-10-14', 'card': 'HDFC FUEL', 'amount': 2000, 'ref': 'UTR 99', 'remark': '', 'photos': <String>[]});
    expect((t.widget(find.byKey(const Key('fc-bal-HDFC FUEL'))) as dynamic).data, '₹ 23,800');
    await t.tap(find.byKey(const Key('fc-c-HDFC FUEL')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('fc-st')));
    await net(t);
    expect(srv.cardCalls.lastWhere((x) => x['fn'] == 'cardStatement')['x'], {'card': 'HDFC FUEL', 'from': '', 'to': ''});
    expect(find.text('Payment – UTR 1234 – recharge'), findsOneWidget);
    expect(find.text('Fill MH-12-HO-1163 · 30 L · Gupta'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // Reports: the cost of a site on fuel cards = the ₹ of its fills (card + cash); the Dashboard: the cards and the cars
    await t.tap(find.byKey(const Key('tab-reports')));
    await net(t);
    expect(find.text('Fuel Cost (card + cash)'), findsOneWidget);
    expect(find.text('₹4,300'), findsOneWidget);
    await t.tap(find.byKey(const Key('rt-diesel')));
    await net(t);
    expect(find.text('Stock Register'), findsNothing);
    await t.tap(find.text('Dashboard'));
    await net(t);
    expect(srv.cardCalls.where((x) => x['fn'] == 'getCardDash').last['x'], {'from': '2026-10-01', 'to': '2026-10-14'}, reason: 'this month to start with');
    expect(find.text('Fuel cards & cars'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('cd-car-MH-12-HO-1163')), 200, scrollable: find.descendant(of: find.byKey(const Key('dash-cards')), matching: find.byType(Scrollable)).first);
    expect(find.byKey(const Key('cd-car-MH-12-HO-1163')), findsOneWidget);
    expect(find.textContaining('Fuel Petrol 30 L · CNG 12 kg · ₹ 4,300 (by card ₹ 3,200, cash ₹ 1,100)'), findsOneWidget, reason: 'each fuel on its own');
  });

  testWidgets('(3.86.0 – Mechanical update-212) HO\'s cars: a gallery with their photos (a link that ended is renewed by itself, the picture kept by its mark), the search, Gallery / List; a car\'s details – its fills, Log Book, maintenance; the Admin: a photo from the camera or the gallery – made smaller here, shown first, saved; refused – said, nothing changed; Remove asks first', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Dashboard': 'View'})
      ..card = true
      ..superAdmin = true;
    final asked = <String>[], picks = <bool>[];
    final c0 = carCompute, p0 = CarPhotoPick.pick;
    CarPhotos.fetch = (u) async {
      asked.add('$u');
      final ended = u.query.contains('token=a');      // the first link of the Hycross has ended
      return http.Response.bytes(ended ? Uint8List(0) : carPng(), ended ? 400 : 200);
    };
    carCompute = <M, R>(ComputeCallback<M, R> cb, M m, {String? debugLabel}) async => await cb(m);
    final shot = Uint8List.fromList(img.encodeJpg(img.fill(img.Image(width: 2400, height: 1800), color: img.ColorRgb8(200, 40, 40))));
    CarPhotoPick.pick = (camera) async {
      picks.add(camera);
      return shot;
    };
    try {
      final s = await ready(t, srv);
      expect(s.admin, true);
      await t.pumpWidget(RclApp(session: s));
      await net(t);
      await t.tap(find.byKey(const Key('tab-reports')));
      await net(t);
      await t.tap(find.byKey(const Key('rt-diesel')));
      await net(t);
      await t.tap(find.text('Dashboard'));
      await net(t);
      final sc = find.descendant(of: find.byKey(const Key('dash-cards')), matching: find.byType(Scrollable)).first;
      await t.scrollUntilVisible(find.byKey(const Key('cd-car-MH-12-HO-1163')), 200, scrollable: sc);
      await net(t);
      // the gallery: the photo of the Hycross – its first link had ended: new links asked once, the picture shown; the Ertiga: "Add photo"
      expect(asked.first, 'https://store.test/car/t1?token=a');
      expect(srv.carCalls.where((x) => x['fn'] == 'getCarPhotoLinks').length, 1, reason: 'new links asked by itself – no reload');
      expect(asked.last, startsWith('https://store.test/car/t-v1hycross?token='));
      expect(find.byKey(const Key('car-pic-MH-12-HO-1163')), findsOneWidget);
      expect(find.byKey(const Key('cg-add-MH-12-HO-2163')), findsOneWidget);
      expect(find.byKey(const Key('cg-add-MH-12-HO-1163')), findsNothing);
      // the search: a part of the number, the model
      await t.enterText(find.byKey(const Key('cg-q')), 'ertiga');
      await settle(t, 400);
      expect([find.byKey(const Key('cd-car-MH-12-HO-1163')).evaluate().length, find.byKey(const Key('cd-car-MH-12-HO-2163')).evaluate().length], [0, 1]);
      await t.enterText(find.byKey(const Key('cg-q')), 'ho-11');
      await settle(t, 400);
      expect([find.byKey(const Key('cd-car-MH-12-HO-1163')).evaluate().length, find.byKey(const Key('cd-car-MH-12-HO-2163')).evaluate().length], [1, 0]);
      await t.enterText(find.byKey(const Key('cg-q')), 'zzz');
      await settle(t, 400);
      expect(find.text('No car matches "zzz".'), findsOneWidget);
      await t.enterText(find.byKey(const Key('cg-q')), '');
      await settle(t, 400);
      // the list as before, the search kept; back to the gallery
      await tapK(t, 'cg-view-list');
      await settle(t, 400);
      expect(find.textContaining('· HDFC FUEL · 45,210 km'), findsOneWidget, reason: 'the list as before');
      await tapK(t, 'cg-view-gal');
      await settle(t, 400);
      // a car's details
      await tapK(t, 'cd-car-MH-12-HO-1163');
      await net(t);
      expect(srv.carCalls.lastWhere((x) => x['fn'] == 'getCarDetail')['x'], {'no': 'MH-12-HO-1163', 'from': '2026-10-01', 'to': '2026-10-14'});
      expect(find.byKey(const Key('car-pic-MH-12-HO-1163-f')), findsOneWidget, reason: 'its whole photo');
      await tapK(t, 'cdt-fuel');      // (3.87.0) the car opens on its Overview
      await settle(t, 400);
      expect(find.textContaining('30 L · ₹ 3,200'), findsOneWidget);
      expect(find.byKey(const Key('cf-0')), findsOneWidget);
      await tapK(t, 'cdt-log');
      await settle(t, 400);
      expect(find.textContaining('44,520 → 45,210 · 690 km'), findsOneWidget);
      expect(find.textContaining('Gupta'), findsOneWidget);
      await tapK(t, 'cdt-maint');
      await settle(t, 400);
      expect(find.textContaining('Toyota Service · TS-101'), findsOneWidget);
      // the Admin: Change photo – the camera; made smaller here (2400 × 1800 → 1600 × 1200), shown first, saved
      final fetched = asked.length;
      await tapK(t, 'car-photo');
      await settle(t, 600);
      await t.tap(find.byKey(const Key('cp-camera')));
      await net(t);
      expect(picks, [true]);
      expect(find.byKey(const Key('cp-preview')), findsOneWidget);
      expect(find.textContaining('New photo – 1600 × 1200'), findsOneWidget);
      expect(find.text('Nothing is saved until you press Save photo.'), findsOneWidget);
      expect(srv.carCalls.where((x) => x['fn'] == 'carPhotoSet'), isEmpty, reason: 'nothing saved before Save photo');
      await t.tap(find.byKey(const Key('cp-save')));
      await net(t);
      final set1 = srv.carCalls.lastWhere((x) => x['fn'] == 'carPhotoSet')['x'] as Map;
      expect([set1['no'], set1['was'], '${set1['full']}'.substring(0, 27), '${set1['thumb']}'.substring(0, 27)], ['MH-12-HO-1163', 'v1hycross', 'data:image/jpeg;base64,/9j/', 'data:image/jpeg;base64,/9j/'], reason: 'two real JPGs');
      expect((set1['thumbLen'] as int) < (set1['fullLen'] as int), true);
      expect(find.byKey(const Key('cp-preview')), findsNothing);
      expect(CarPhotos.i.of('MH-12-HO-1163')!.v, startsWith('v'), reason: 'the new photo');
      expect(CarPhotos.i.of('MH-12-HO-1163')!.v, isNot('v1hycross'));
      expect(asked.length, fetched, reason: 'its pictures are on the phone already – nothing downloaded again');
      // refused by the server: said; nothing changed
      srv.carRefuse = 'Only Admin can open this.';
      final v1 = CarPhotos.i.of('MH-12-HO-1163')!.v;
      await tapK(t, 'car-photo');
      await settle(t, 600);
      await t.tap(find.byKey(const Key('cp-gallery')));
      await net(t);
      expect(picks, [true, false]);
      await t.tap(find.byKey(const Key('cp-save')));
      await net(t);
      expect(find.byKey(const Key('cp-preview')), findsOneWidget, reason: 'stays open – nothing saved');
      expect(CarPhotos.i.of('MH-12-HO-1163')!.v, v1);
      await t.tap(find.text('Cancel'));
      await settle(t, 600);
      srv.carRefuse = '';
      // Remove: asks first
      await tapK(t, 'car-remove');
      await settle(t, 600);
      expect(find.text('Remove the photo of MH-12-HO-1163?'), findsOneWidget);
      await t.tap(find.text('Remove photo'));
      await net(t);
      expect(srv.carCalls.lastWhere((x) => x['fn'] == 'carPhotoRemove')['x'], {'no': 'MH-12-HO-1163', 'was': v1});
      expect(CarPhotos.i.of('MH-12-HO-1163'), isNull);
      expect(find.text('No photo yet'), findsOneWidget);
      expect(find.byKey(const Key('car-remove')), findsNothing);
      await t.pageBack();
      await net(t);
      expect(find.byKey(const Key('cg-add-MH-12-HO-1163')), findsOneWidget, reason: 'the Dashboard at once');
      // "Add photo" on a card: the gallery
      await tapK(t, 'cg-add-MH-12-HO-2163');
      await settle(t, 600);
      await t.tap(find.byKey(const Key('cp-gallery')));
      await net(t);
      await t.tap(find.byKey(const Key('cp-save')));
      await net(t);
      final set2 = srv.carCalls.lastWhere((x) => x['fn'] == 'carPhotoSet')['x'] as Map;
      expect([set2['no'], set2['was']], ['MH-12-HO-2163', '']);
      expect(find.byKey(const Key('cg-add-MH-12-HO-2163')), findsNothing);
    } finally {
      carCompute = c0;
      CarPhotoPick.pick = p0;
    }
  });

  testWidgets('(3.86.0 – Mechanical update-212) HO\'s cars, a person without the right: the photos, no Add / Change / Remove; the Log Book "no access" (the server gives none)', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'View', 'Dashboard': 'View', 'Log Book': 'None'})
      ..card = true;
    final s = await ready(t, srv);
    expect(s.admin, false);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-reports')));
    await net(t);
    await t.tap(find.byKey(const Key('rt-diesel')));
    await net(t);
    await t.tap(find.text('Dashboard'));
    await net(t);
    final sc = find.descendant(of: find.byKey(const Key('dash-cards')), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.byKey(const Key('cd-car-MH-12-HO-2163')), 200, scrollable: sc);
    await net(t);
    expect(find.byKey(const Key('car-pic-MH-12-HO-1163')), findsOneWidget);
    expect(find.byKey(const Key('cg-add-MH-12-HO-2163')), findsNothing);
    await tapK(t, 'cd-car-MH-12-HO-1163');
    await net(t);
    expect([find.byKey(const Key('car-photo')).evaluate().length, find.byKey(const Key('car-remove')).evaluate().length], [0, 0]);
    await tapK(t, 'cdt-log');
    await settle(t, 400);
    expect(find.text('You have no access to the Log Book – ask the Admin.'), findsOneWidget);
  });

  testWidgets('(3.86.0) HO\'s cars – pictures: the gallery, a car\'s details', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Dashboard': 'View'})
      ..card = true
      ..superAdmin = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-reports')));
    await net(t);
    await t.tap(find.byKey(const Key('rt-diesel')));
    await net(t);
    await t.tap(find.text('Dashboard'));
    await net(t);
    final sc = find.descendant(of: find.byKey(const Key('dash-cards')), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.byKey(const Key('cg-q')), 300, scrollable: sc);
    await t.drag(sc, const Offset(0, -260));
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9c_ho_gallery.png'));
    await tapK(t, 'cd-car-MH-12-HO-1163');
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9d_ho_car.png'));
  }, tags: ['golden']);

  // (3.87.0, asked 08-11-2026: "RCL ERP – Premium Mobile App Redesign" Parts 1–3 with his picture; his answer: the new Home "fakt HO")
  Finder homeList() => find.ancestor(of: find.byKey(const Key('home-menu')), matching: find.byType(Scrollable)).first;

  testWidgets('(3.87.0 – Premium Mobile App Redesign, HO only) HO\'s Home: no site picture, no tiles, no Modules grid, no Today\'s Activity – My Fleet: each car its photo alone with its number under it, make, model, kind, fuel, KM now, Active; All / each kind; a list or a grid of two', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Dashboard': 'View', 'Diesel Issue': 'Edit', 'Log Book': 'Edit'})
      ..card = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    // a clean header – no site picture; the cards' balances; no tiles, no Modules, no Today's Activity
    expect(find.byKey(const Key('home-ho-head')), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/brand/site_home.jpg'), findsNothing);
    expect([find.byKey(const Key('home-menu')), find.byKey(const Key('home-search')), find.byKey(const Key('home-bell')), find.byKey(const Key('home-ask'))].every((f) => f.evaluate().length == 1), true, reason: 'menu, search, bell, AI');
    expect(find.byKey(const Key('home-cards')), findsOneWidget);
    expect(find.byKey(const Key('home-all')), findsNothing, reason: 'no Modules grid – the modules stay in ≡');
    expect(find.text('Running'), findsNothing, reason: 'no tiles');
    expect(find.text("Today's Activity"), findsNothing);
    expect(srv.cardCalls.where((x) => x['fn'] == 'getCardDash').map((x) => x['x']).toList(), [{'from': '2026-10-01', 'to': '2026-10-14'}], reason: 'the cars of this month – once');
    await t.scrollUntilVisible(find.byKey(const Key('hf-car-MH-12-HO-1163')), 200, scrollable: homeList());
    await net(t);
    // the car: its photo (the same as the web's) – the number UNDER it, nothing on it; make, model, kind, fuel, KM now, Active
    expect(find.byKey(const Key('car-pic-MH-12-HO-1163')), findsOneWidget);
    final pic = t.getRect(find.byKey(const Key('car-pic-MH-12-HO-1163'))), no = t.getRect(find.byKey(const Key('hf-no-MH-12-HO-1163')));
    expect(no.top >= pic.bottom, true, reason: 'the number under the photo');
    final row = find.byKey(const Key('hf-car-MH-12-HO-1163'));
    for (final w in ['Toyota', 'Hycross', 'Car', 'Petrol', '45,210 km', 'Active']) {
      expect(find.descendant(of: row, matching: find.text(w)), findsOneWidget, reason: w);
    }
    expect(find.descendant(of: find.byKey(const Key('hf-car-MH-12-HO-2163')), matching: find.text('Maruti Suzuki')), findsOneWidget, reason: 'the make the server gave');
    expect(find.text('Car (3)'), findsOneWidget);
    expect(find.byKey(const Key('hf-car-Sany 210 (No.1)')), findsOneWidget);
    // one kind
    await tapK(t, 'hf-kind-Car');
    await settle(t, 400);
    expect([find.byKey(const Key('hf-car-Sany 210 (No.1)')).evaluate().length, find.byKey(const Key('hf-car-MH-12-HO-3163')).evaluate().length], [0, 1]);
    await tapK(t, 'hf-kind-all');
    await settle(t, 400);
    expect(find.byKey(const Key('hf-car-Sany 210 (No.1)')), findsOneWidget);
    // a grid of two
    await tapK(t, 'hf-view-grid');
    await settle(t, 400);
    expect(t.getRect(find.byKey(const Key('hf-car-MH-12-HO-1163'))).top, t.getRect(find.byKey(const Key('hf-car-MH-12-HO-2163'))).top, reason: 'two in a row');
    final gp = t.getRect(find.byKey(const Key('car-pic-MH-12-HO-1163'))), gn = t.getRect(find.byKey(const Key('hf-no-MH-12-HO-1163')));
    expect(gn.top >= gp.bottom, true, reason: 'the number under the photo');
    await tapK(t, 'hf-view-list');
    await settle(t, 400);
  });

  testWidgets('(3.87.0) HO\'s Vehicle Details: the photo alone, the number under it; Fuel, KM now, kind, site; this month – fuel, running KM, average, ₹; the quick actions open their forms with THIS car chosen (only those he may make); Vehicle History – every kind, the newest first, by kind and by months', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Dashboard': 'View', 'Diesel Issue': 'Edit', 'Log Book': 'Edit', 'Maintenance': 'Edit'})
      ..card = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.scrollUntilVisible(find.byKey(const Key('hf-car-MH-12-HO-1163')), 200, scrollable: homeList());
    await net(t);
    await tapK(t, 'hf-car-MH-12-HO-1163');
    await net(t);
    expect(srv.carCalls.lastWhere((x) => x['fn'] == 'getCarDetail')['x'], {'no': 'MH-12-HO-1163', 'from': '2026-10-01', 'to': '2026-10-14'});
    expect(find.text('Vehicle Details'), findsOneWidget);
    final pic = t.getRect(find.byKey(const Key('car-pic-MH-12-HO-1163-f'))), no = t.getRect(find.byKey(const Key('car-no')));
    expect(no.top > pic.bottom, true, reason: 'nothing written on the photo');
    expect(find.descendant(of: find.byKey(const Key('car-status')), matching: find.text('Active')), findsOneWidget);
    for (final (i, w) in ['Petrol', '45,210 km', 'Car', s.siteName].indexed) {
      expect(find.descendant(of: find.byKey(Key('car-tile-$i')), matching: find.textContaining(w.split(' ').first)), findsWidgets, reason: w);
    }
    expect(find.byKey(const Key('car-photo')), findsNothing, reason: 'not the Admin');
    // this month
    final sum = find.byKey(const Key('car-sum'));
    for (final w in ['This month', '30 L', '690 km', '23 km/L', '₹ 3,200']) {
      expect(find.descendant(of: sum, matching: find.text(w)), findsOneWidget, reason: w);
    }
    // the quick actions: Diesel Issue – the form with this car already chosen
    expect(['qa-issue', 'qa-log', 'qa-maint', 'qa-hist'].every((k) => find.byKey(Key(k)).evaluate().length == 1), true);
    await tapK(t, 'qa-issue');
    await net(t);
    expect(find.descendant(of: find.byKey(const Key('d-machine')), matching: find.textContaining('MH-12-HO-1163')), findsWidgets, reason: 'the car is in the box already');
    Navigator.of(t.element(find.byKey(const Key('d-machine')))).pop();
    await net(t);
    // Log Book entry – this car
    await tapK(t, 'qa-log');
    await net(t);
    final lf = find.byWidgetPredicate((w) => w.runtimeType.toString() == 'LogForm');
    expect(lf, findsOneWidget);
    expect(find.descendant(of: lf, matching: find.textContaining('MH-12-HO-1163')), findsWidgets);
    Navigator.of(t.element(lf)).pop();
    await net(t);
    // Maintenance – a bill of this car (the words of earlier bills suggested)
    final mc = srv.maintCalls.length;
    await tapK(t, 'qa-maint');
    await net(t);
    expect(srv.maintCalls.skip(mc).first, {'fn': 'getMaint', 'x': {'from': '2026-10-01', 'to': '2026-10-14', 'no': ''}});
    expect(find.descendant(of: find.byKey(const Key('mf-car')), matching: find.textContaining('MH-12-HO-1163')), findsOneWidget);
    Navigator.of(t.element(find.byKey(const Key('mf-car')))).pop();
    await net(t);
    // the recent activity: every kind, the newest first
    await t.scrollUntilVisible(find.byKey(const Key('car-recent')), 200, scrollable: find.descendant(of: find.byKey(const Key('car-detail')), matching: find.byType(Scrollable)).first);
    expect(find.descendant(of: find.byKey(const Key('car-recent')), matching: find.byKey(const Key('ha-f0'))), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('car-recent')), matching: find.byKey(const Key('ha-m0'))), findsOneWidget);
    // Vehicle History: 3 months to start with, every kind; one kind; this month
    await tapK(t, 'qa-hist');
    await net(t);
    expect(srv.carCalls.lastWhere((x) => x['fn'] == 'getCarDetail')['x'], {'no': 'MH-12-HO-1163', 'from': '2026-08-01', 'to': '2026-10-14'});
    final ys = [for (final k in ['ha-f0', 'ha-l0', 'ha-m0']) t.getRect(find.byKey(Key(k))).top];
    expect(ys[0] < ys[2] && ys[1] < ys[2], true, reason: '13-10 (the fill, the Log Book day) before 05-10 (the bill)');
    await tapK(t, 'vh-k-fuel');
    await settle(t, 400);
    expect([find.byKey(const Key('ha-f0')).evaluate().length, find.byKey(const Key('ha-l0')).evaluate().length, find.byKey(const Key('ha-m0')).evaluate().length], [1, 0, 0]);
    await tapK(t, 'vh-p-1');
    await net(t);
    expect(srv.carCalls.lastWhere((x) => x['fn'] == 'getCarDetail')['x'], {'no': 'MH-12-HO-1163', 'from': '2026-10-01', 'to': '2026-10-14'});
  });

  testWidgets('(3.87.0) HO, a person without the Dashboard: My Fleet – his site\'s cars (no figures read); a car: its key information and only the quick actions he may make', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'View', 'Dashboard': 'None', 'Diesel Issue': 'Edit', 'Log Book': 'View', 'Maintenance': 'None'})
      ..card = true;
    final s = await ready(t, srv);
    expect(s.canSee('Dashboard'), false);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.scrollUntilVisible(find.byKey(const Key('hf-car-MH-12-HO-1163')), 200, scrollable: homeList());
    await net(t);
    expect(srv.cardCalls.where((x) => x['fn'] == 'getCardDash'), isEmpty, reason: 'the server gives the figures only with the Dashboard');
    expect(find.descendant(of: find.byKey(const Key('hf-car-MH-12-HO-1163')), matching: find.text('Hycross')), findsOneWidget);
    await tapK(t, 'hf-car-MH-12-HO-1163');
    await net(t);
    expect(srv.carCalls.where((x) => x['fn'] == 'getCarDetail'), isEmpty);
    expect(find.byKey(const Key('car-info')), findsOneWidget);
    expect([for (final k in ['qa-issue', 'qa-log', 'qa-maint', 'qa-hist']) find.byKey(Key(k)).evaluate().length], [1, 0, 0, 0]);
    expect(find.byKey(const Key('cdt-fuel')), findsNothing);
  });

  testWidgets('(3.87.0) a site NOT on fuel cards: Home as before – its picture, the tiles, the Modules; no My Fleet', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.byKey(const Key('home-ho-head')), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/brand/site_home.jpg'), findsOneWidget);
    expect(find.byKey(const Key('home-stock')), findsOneWidget);
    expect(find.byKey(const Key('home-all')), findsOneWidget);
    expect(find.byKey(const Key('ho-fleet')), findsNothing);
  });

  // (3.88.0, Mechanical update-213, asked 08-11-2026) the vehicle alerts – as the server gives them
  Map<String, dynamic> vaSample({bool ho = false}) => {
        'today': '2026-10-14',
        'cars': {
          if (ho)
            'MH-12-HO-1163': [
              {'k': 'paper', 'doc': 'Insurance', 's': 'due', 'upto': '2026-10-24', 'days': 10},
              {'k': 'svc', 's': 'soon', 'last': '2026-10-05', 'lastReading': 45210, 'unit': 'KM', 'parts': [{'by': 'KM', 'every': 10000, 'run': 9200, 'left': 800, 's': 'soon'}], 'rule': {'km': 10000, 'hrs': '', 'months': ''}},
            ],
          'MH-25-AJ-2169': [{'k': 'avg', 's': 'more', 'actual': '3 km/L', 'std': '3.5 km/L', 'pct': 17, 'used': 120}],
          'Sany 210 (No.1)': [{'k': 'svc', 's': 'over', 'last': '2026-08-01', 'lastReading': 1200, 'unit': 'Hrs', 'parts': [{'by': 'Hrs', 'every': 250, 'run': 270, 'left': -20, 's': 'over'}], 'rule': {'km': '', 'hrs': 250, 'months': ''}}],
        },
        'cards': ho ? [{'name': 'HDFC FUEL', 'last4': '4321', 'balance': 21800, 'lowAt': 25000}] : <dynamic>[],
        'n': ho ? 5 : 2,
        'count': {'paper': ho ? 1 : 0, 'svc': ho ? 2 : 1, 'avg': 1, 'card': ho ? 1 : 0},
      };

  testWidgets('(3.88.0 – Mechanical update-213) a site with stock: the vehicle alerts in the bell and at the top of the Dashboard – each machinery with its alerts (red: overdue, amber: more diesel); none = no line, no bell row', (t) async {
    phone(t);
    final srv = FakeServer()..perms.addAll({'Dashboard': 'View', 'Reports': 'View'});
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(srv.vaCalls, greaterThan(0), reason: 'read with Home');
    await tapK(t, 'home-bell');
    await settle(t, 800);
    expect(find.text('Vehicle alerts'), findsNothing, reason: 'none – no row');
    await t.tapAt(const Offset(20, 100));
    await settle(t, 600);
    srv.vehAlerts = vaSample();
    await t.runAsync(() => VehAlerts.i.load(s));      // (Home's next load reads them – as here)
    await settle(t, 600);
    await tapK(t, 'home-bell');
    await settle(t, 800);
    expect(find.text('Vehicle alerts'), findsOneWidget);
    expect(find.textContaining('2 to look at'), findsOneWidget);
    await t.tap(find.text('Vehicle alerts'));
    await net(t);
    expect(find.descendant(of: find.byKey(const Key('va-car-Sany 210 (No.1)')), matching: find.text('Service overdue: 20 Hrs over')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('va-car-MH-25-AJ-2169')), matching: find.text('More diesel: 3 km/L (standard 3.5 km/L), +17%')), findsOneWidget);
    final red = t.widget<Container>(find.byKey(const Key('va-Sany 210 (No.1)-0'))), amber = t.widget<Container>(find.byKey(const Key('va-MH-25-AJ-2169-0')));
    expect([(red.decoration as BoxDecoration).color, (amber.decoration as BoxDecoration).color], [C.redSoft, C.amberSoft]);
    await t.pageBack();
    await net(t);
    // the Dashboard: the line at its top – a tap opens the alerts
    await t.tap(find.byKey(const Key('tab-reports')));
    await net(t);
    await t.tap(find.byKey(const Key('rt-diesel')));
    await net(t);
    await t.tap(find.text('Dashboard'));
    await net(t);
    expect(find.descendant(of: find.byKey(const Key('dash-va')), matching: find.text('1 service · 1 more diesel')), findsOneWidget);
    await tapK(t, 'dash-va');
    await net(t);
    expect(find.byKey(const Key('va-list')), findsOneWidget);
  });

  testWidgets('(3.88.0 – Mechanical update-213) HO: a card below its "Alert below ₹" marked on Home and in Fuel Cards (its amount sent with the card); each car\'s alerts under it in My Fleet and on its Vehicle Details', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Dashboard': 'View', 'Diesel Issue': 'Edit', 'Log Book': 'Edit', 'Maintenance': 'Edit'})
      ..card = true;
    srv.cards.firstWhere((c) => c['name'] == 'HDFC FUEL')['lowAt'] = 25000;
    srv.vehAlerts = vaSample(ho: true);
    final s = await ready(t, srv);
    expect([s.card('HDFC FUEL')!.lowAt, s.card('HDFC FUEL')!.low, s.card('SBI CREDIT')!.low], [25000, true, false]);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.descendant(of: find.byKey(const Key('home-card-HDFC FUEL')), matching: find.byIcon(Icons.warning_amber_rounded)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('home-card-SBI CREDIT')), matching: find.byIcon(Icons.warning_amber_rounded)), findsNothing);
    await t.scrollUntilVisible(find.byKey(const Key('hf-car-MH-12-HO-1163')), 200, scrollable: homeList());
    await net(t);
    final va = find.byKey(const Key('hf-va-MH-12-HO-1163'));
    expect(find.descendant(of: va, matching: find.text('Insurance due 24-10-2026 (10 days)')), findsOneWidget);
    expect(find.descendant(of: va, matching: find.text('Service due: 800 KM left')), findsOneWidget);
    expect(find.byKey(const Key('hf-va-MH-12-HO-2163')), findsNothing, reason: 'no alert, no line');
    await tapK(t, 'hf-car-MH-12-HO-1163');
    await net(t);
    expect([find.byKey(const Key('car-va-0')).evaluate().length, find.byKey(const Key('car-va-1')).evaluate().length], [1, 1]);
    await t.pageBack();
    await net(t);
    // Fuel Cards: the mark, and its amount sent with the card
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Fuel Cards');
    await net(t);
    expect(find.descendant(of: find.byKey(const Key('fc-low-HDFC FUEL')), matching: find.text('Low – below ₹ 25,000')), findsOneWidget);
    await t.tap(find.byKey(const Key('fc-c-HDFC FUEL')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('fc-edit')));
    await net(t);
    expect((t.widget(find.byKey(const Key('cf-low'))) as TextBox).controller.text, '25000');
    await t.enterText(find.descendant(of: find.byKey(const Key('cf-low')), matching: find.byType(TextField)), '20000');
    await settle(t, 300);
    await tapK(t, 'cf-save');
    await net(t);
    expect((srv.cardCalls.lastWhere((c) => c['fn'] == 'saveCard')['x'] as Map)['lowAt'], '20000');
    expect(find.byKey(const Key('fc-low-HDFC FUEL')), findsNothing, reason: '21,800 is not below 20,000 any more');
  });

  testWidgets('(3.88.0 – Mechanical update-213) Asset Master: "Service every" – the boxes of the meter it runs on and months, shown as kept, compared before the save, sent with it', (t) async {
    phone(t);
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Asset Master');
    await t.tap(find.text('MH-25-AJ-2169'));
    await settle(t, 800);
    await tapK(t, 'md-edit');
    await net(t);
    expect([find.byKey(const Key('mf-svc-km')).evaluate().length, find.byKey(const Key('mf-svc-hrs')).evaluate().length, find.byKey(const Key('mf-svc-mon')).evaluate().length], [1, 0, 1], reason: 'it runs on KM');
    await t.enterText(box('mf-svc-km'), '10000');
    await t.enterText(box('mf-svc-mon'), '6');
    await tapK(t, 'mf-save');
    await settle(t, 600);
    expect(find.text('Service every KM'), findsWidgets);
    expect(find.text('Service every months'), findsWidgets);
    await t.tap(find.byKey(const Key('ask-yes')));
    await net(t);
    final m = srv.masterCalls.last['m'] as Map;
    expect([m['svcKm'], m['svcHrs'], m['svcMon']], ['10000', '', '6']);
    expect(s.machine('MH-25-AJ-2169')!.m['svc'], {'km': 10000, 'hrs': '', 'months': 6}, reason: 'kept as the server keeps it');
    await t.tap(find.text('MH-25-AJ-2169'));
    await settle(t, 800);
    await tapK(t, 'md-edit');
    await net(t);
    expect([(t.widget(find.byKey(const Key('mf-svc-km'))) as TextBox).controller.text, (t.widget(find.byKey(const Key('mf-svc-mon'))) as TextBox).controller.text], ['10000', '6']);
    await tapK(t, 'mf-save');
    await settle(t, 600);
    expect(find.text('Nothing changed.'), findsOneWidget, reason: 'the same values: nothing to save');
  });

  testWidgets('(3.88.0) the vehicle alerts – pictures', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Dashboard': 'View', 'Diesel Issue': 'Edit', 'Log Book': 'Edit', 'Maintenance': 'Edit'})
      ..card = true;
    srv.cards.firstWhere((c) => c['name'] == 'HDFC FUEL')['lowAt'] = 25000;
    srv.vehAlerts = vaSample(ho: true);
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.scrollUntilVisible(find.byKey(const Key('hf-car-MH-12-HO-1163')), 200, scrollable: homeList());
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9k_ho_fleet_alerts.png'));
    await tapK(t, 'hf-car-MH-12-HO-1163');
    await net(t);
    await t.scrollUntilVisible(find.byKey(const Key('car-va')), 200, scrollable: find.descendant(of: find.byKey(const Key('car-detail')), matching: find.byType(Scrollable)).first);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9l_ho_vehicle_alerts.png'));
  }, tags: ['golden']);

  testWidgets('(3.88.0) the vehicle alerts screen – picture', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Dashboard': 'View'})
      ..card = true;
    srv.vehAlerts = vaSample(ho: true);
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await tapK(t, 'home-bell');
    await settle(t, 800);
    await t.tap(find.text('Vehicle alerts'));
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9m_vehicle_alerts.png'));
  }, tags: ['golden']);

  testWidgets('(3.87.0) HO\'s new Home and Vehicle Details – pictures', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Dashboard': 'View', 'Diesel Issue': 'Edit', 'Log Book': 'Edit', 'Maintenance': 'Edit'})
      ..card = true
      ..superAdmin = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9e_ho_home.png'));
    await t.scrollUntilVisible(find.byKey(const Key('hf-car-MH-12-HO-2163')), 200, scrollable: homeList());
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9f_ho_fleet.png'));
    await tapK(t, 'hf-view-grid');
    await settle(t, 400);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9g_ho_fleet_grid.png'));
    await tapK(t, 'hf-view-list');
    await settle(t, 400);
    await tapK(t, 'hf-car-MH-12-HO-1163');
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9h_ho_vehicle.png'));
    await t.scrollUntilVisible(find.byKey(const Key('car-recent')), 300, scrollable: find.descendant(of: find.byKey(const Key('car-detail')), matching: find.byType(Scrollable)).first);
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9i_ho_vehicle_more.png'));
    await tapK(t, 'qa-hist');
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9j_ho_history.png'));
  }, tags: ['golden']);

  testWidgets('(3.47.0 – Mechanical update-166) a fuel card\'s details: bank / company, the name on it, its expiry (a mark when it ends within 30 days), the customer ID – shown on the tile and its sheet, sent with the card; the number stays its last 4 digits', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit'})
      ..card = true;
    final s = await ready(t, srv);
    final sbi = s.card('SBI CREDIT')!;
    expect([sbi.issuer, sbi.holder, sbi.expiry, sbi.expiryMY, sbi.custId, sbi.expDays], ['SBI Card', 'Rachana Construction Ltd', '2026-10', '10/2026', 'SBI-44120', 17]);
    expect(s.card('HDFC FUEL')!.expDays, isNull, reason: 'no expiry given: no mark');
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Fuel Cards');
    await net(t);
    expect((t.widget(find.byKey(const Key('fc-exp-SBI CREDIT'))) as dynamic).text, 'Expires 31-10-2026', reason: 'it ends this month – its last good day, amber');
    expect(find.byKey(const Key('fc-exp-HDFC FUEL')), findsNothing);
    expect(find.textContaining('Credit card · ···· 9876 · SBI Card'), findsOneWidget);
    await t.tap(find.byKey(const Key('fc-c-SBI CREDIT')));
    await settle(t, 800);
    expect(find.text('SBI Card'), findsOneWidget);
    expect(find.text('Rachana Construction Ltd'), findsOneWidget);
    expect(find.text('SBI-44120'), findsOneWidget);
    await t.tapAt(const Offset(20, 100));
    await settle(t, 800);
    // a card changed with its details
    await t.tap(find.byKey(const Key('fc-c-HDFC FUEL')));
    await settle(t, 800);
    await t.tap(find.byKey(const Key('fc-edit')));
    await net(t);
    await t.enterText(find.byKey(const Key('cf-issuer')), 'HDFC Bank');
    await t.enterText(find.byKey(const Key('cf-holder')), 'Sujit Mule');
    await t.enterText(find.byKey(const Key('cf-exp')), '08/2029');
    await t.enterText(find.byKey(const Key('cf-cust')), 'CUST 778899');
    await settle(t, 300);
    await tapK(t, 'cf-save');
    await net(t);
    final x = srv.cardCalls.lastWhere((c) => c['fn'] == 'saveCard')['x'] as Map;
    expect([x['was'], x['name'], x['last4'], x['issuer'], x['holder'], x['expiry'], x['custId']], ['HDFC FUEL', 'HDFC FUEL', '4321', 'HDFC Bank', 'Sujit Mule', '08/2029', 'CUST 778899'], reason: 'the server checks and keeps them (yyyy-MM)');
  });

  testWidgets('(3.46.0 – Mechanical update-165) Maintenance at a site on fuel cards (HO): the bills of the month; a bill with a PDF – "Read the bill (AI)" fills the empty boxes (blue), a line typed over, the file sent with maintFile, then saveMaint; the same bill again asks first; its files; Delete; the car\'s Maintenance Log Book (no fuel choice)', (t) async {
    phone(t);
    final p0 = pickAttFiles, c0 = attCompute;
    attCompute = <M, R>(ComputeCallback<M, R> cb, M m, {String? debugLabel}) async => await cb(m);
    addTearDown(() {
      pickAttFiles = p0;
      attCompute = c0;
    });
    final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'));
    pickAttFiles = (how, room) async => [(name: 'bill.pdf', bytes: pdf)];
    // (3.50.0, Mechanical update-170) a site not on fuel cards: Maintenance too when given (3.46.0: only on fuel cards); Fuel Cards not
    final s0 = await ready(t, FakeServer()..perms.addAll({'Maintenance': 'Edit', 'Fuel Cards': 'Edit'}));
    expect([for (final p in startPagesFor(s0)) p.$1], allOf(contains('mnt'), isNot(contains('cards'))));
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Maintenance': 'Edit'})
      ..card = true
      ..aiOn = true;
    final s = await ready(t, srv);
    expect([for (final p in startPagesFor(s)) p.$1], containsAll(['cards', 'mnt']));
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Maintenance');
    await net(t);
    expect(srv.maintCalls.first, {'fn': 'getMaint', 'x': {'from': '2026-10-01', 'to': '2026-10-14', 'no': ''}}, reason: 'this month to start with');
    expect(find.byKey(const Key('mt-r-MT-000002')), findsOneWidget);
    expect(find.byKey(const Key('mt-r-MT-000001')), findsOneWidget);
    expect(find.textContaining('· 2 · ₹ 8,660'), findsOneWidget);
    expect(find.byKey(const Key('mt-import')), findsOneWidget, reason: '(3.53.0, "user la pn disu de") everyone with Maintenance Edit imports the old log book');
    // a new bill: the car, a PDF, "Read the bill (AI)"
    await t.tap(find.byKey(const Key('mt-add')));
    await net(t);
    expect((t.widget(find.byKey(const Key('mf-read'))) as OutlinedButton).onPressed, isNull, reason: 'no file yet');
    await t.tap(find.byKey(const Key('mf-car')));
    await settle(t, 800);
    await t.tap(find.text('MH-12-HO-1163').last);
    await settle(t, 600);
    await tapK(t, 'att-pdf');
    await net(t);
    expect(find.text('bill.pdf'), findsOneWidget);
    s.admin = true; // (3.62.1, update-188) the Admin: the bill's own date of an earlier day is read too – a user's stays today (the insurance bill's test)
    await tapK(t, 'mf-read');
    await net(t);
    s.admin = false;
    expect(srv.maintCalls.last, {'fn': 'readMaintBill', 'mime': 'application/pdf'});
    expect([(t.widget(find.byKey(const Key('mf-garage'))) as TextBox).controller.text, (t.widget(find.byKey(const Key('mf-billno'))) as TextBox).controller.text, (t.widget(find.byKey(const Key('mf-km'))) as TextBox).controller.text], ['Maruti Service', 'MS-77', '46100']);
    expect((t.widget(find.byKey(const Key('mf-service'))) as SwitchListTile).value, true);
    expect([for (var i = 0; i < 3; i++) (t.widget(find.byKey(Key('mf-w-$i'))) as TextBox).controller.text], ['Service charge', 'Coolant', 'GST 18%']);
    expect(find.byWidgetPredicate((w) => w is AiBox && w.on), findsNWidgets(8), reason: 'the date, garage, bill no., KM, Service and the 3 lines – blue');
    expect(find.textContaining('Read by the AI (blue) – check every value before saving.'), findsOneWidget);
    expect(find.textContaining('check the car'), findsNothing, reason: 'the bill\'s vehicle is this car');
    expect((t.widget(find.byKey(const Key('mf-total'))) as dynamic).data, '₹ 3,540');
    await t.enterText(find.byKey(const Key('mf-a-1')), '600');
    await settle(t, 400);
    expect((t.widget(find.byKey(const Key('mf-total'))) as dynamic).data, '₹ 3,640');
    expect(find.byWidgetPredicate((w) => w is AiBox && w.on), findsNWidgets(7), reason: 'the line typed over is no longer blue');
    await tapK(t, 'mf-save');
    await net(t);
    final fi = srv.maintCalls.indexWhere((x) => x['fn'] == 'maintFile'), sv = srv.maintCalls.indexWhere((x) => x['fn'] == 'saveMaint');
    expect(fi >= 0 && sv > fi, true, reason: 'the file is sent first (maintFile), then the bill');
    final x = Map<String, dynamic>.from(srv.maintCalls[sv]['x'] as Map);
    expect((x.remove('files') as List).length, 1);
    // (3.49.0, update-168) every line with its kind, Qty, Rate, Disc % (blank: none on the bill); no insurance part
    const paidLine = {'type': 'Paid', 'qty': '', 'uom': '', 'rate': '', 'disc': '', 'gst': '', 'gstAmt': ''};      // (3.50.0: its Uom; 3.51.0: its GST %; 3.59.0: gstAmt always sent)
    expect(x, {'date': '2026-10-13', 'no': 'MH-12-HO-1163', 'garage': 'Maruti Service', 'billNo': 'MS-77', 'km': 46100, 'service': true, 'remark': '',
      'lines': [{'work': 'Service charge', ...paidLine, 'amount': 2500}, {'work': 'Coolant', ...paidLine, 'amount': 600}, {'work': 'GST 18%', ...paidLine, 'amount': 540}], 'insurance': null});
    expect(find.byKey(const Key('mt-r-MT-000003')), findsOneWidget);
    // the same bill number of the same garage for the car again: asked first
    await t.tap(find.byKey(const Key('mt-add')));
    await net(t);
    await t.tap(find.byKey(const Key('mf-car')));
    await settle(t, 800);
    await t.tap(find.text('MH-12-HO-1163').last);
    await settle(t, 600);
    await t.enterText(find.byKey(const Key('mf-garage')), 'Toyota Service');
    await t.enterText(find.byKey(const Key('mf-billno')), 'TS-101');
    await t.enterText(find.byKey(const Key('mf-w-0')), 'Wash');
    await t.enterText(find.byKey(const Key('mf-a-0')), '200');
    await settle(t, 300);
    await tapK(t, 'mf-save');
    await net(t);
    expect(find.text('Saved before?'), findsOneWidget);
    expect(find.textContaining('is already saved (MT-000001). Save it again?'), findsOneWidget);
    await t.tap(find.text('Save again'));
    await net(t);
    expect((srv.maintCalls.lastWhere((x) => x['fn'] == 'saveMaint')['x'] as Map)['force'], true);
    // a bill's files; Delete
    await reach(t, 'mt-r-MT-000001', 'mt-list');
    await tapK(t, 'mt-r-MT-000001');
    await settle(t, 800);
    expect(find.text('Oil filter'), findsOneWidget);
    await tapK(t, 'mt-files');
    await net(t);
    expect(srv.maintCalls.last, {'fn': 'getMaintFiles', 'id': 'MT-000001'});
    expect(find.textContaining('1 / 1 · bill.pdf'), findsOneWidget, reason: 'the bill\'s file in the viewer');
    await t.pageBack();
    await net(t);
    await reach(t, 'mt-r-MT-000002', 'mt-list');
    await tapK(t, 'mt-r-MT-000002');
    await settle(t, 800);
    await tapK(t, 'mt-del');
    await settle(t, 800);
    await t.tap(find.text('Delete').last);
    await net(t);
    expect(srv.maintCalls.any((x) => x['fn'] == 'deleteMaint' && x['id'] == 'MT-000002'), true);
    expect(find.byKey(const Key('mt-r-MT-000002')), findsNothing);
    // one car, then its Maintenance Log Book: the same report as the web – no fuel to choose (its car has its own)
    await tapK(t, 'mt-car');
    await settle(t, 800);
    await t.tap(find.text('MH-12-HO-1163').last);
    await net(t);
    expect(srv.maintCalls.lastWhere((x) => x['fn'] == 'getMaint')['x'], {'from': '2026-10-01', 'to': '2026-10-14', 'no': 'MH-12-HO-1163'});
    await reach(t, 'mt-log', 'mt-list');      // (3.53.0: the page is longer – the import, Fetch outward, Start to end)
    await tapK(t, 'mt-log');
    await net(t);
    expect(srv.maintCalls.lastWhere((x) => x['fn'] == 'maintLog')['x'], {'from': '2026-10-01', 'to': '2026-10-14', 'no': 'MH-12-HO-1163'}, reason: 'no fuel sent');
    expect(find.widgetWithText(DropdownButtonFormField<String>, 'Fuel'), findsNothing);
    expect(find.text('Maintenance Log Book – MH-12-HO-1163'), findsWidgets);
    // (3.50.0, update-170) his format: a row a line, the party (and bill no.) on the bill's first row; the fills apart (a site on fuel cards)
    expect(find.text('Toyota Service · Bill TS-101'), findsOneWidget);
    expect(find.text('Engine oil'), findsWidgets);
    expect(find.text('Amount With GST'), findsWidgets);
    expect(find.textContaining('Fuel – 2 fill(s) (by card ₹2,100'), findsOneWidget);
  });

  /// (3.53.0) the Admin at the page Maintenance, his old log book's file ready to be picked (RL-173 "Roller No.03" and MH-12-XW-0169
  /// Own, JCB-173 rented); the AI on – the names it finds: Ganesh Motors (GANESH MOTORS), FUEL WATER SEPRETOR
  Future<FakeServer> mliOpen(WidgetTester t) async {
    phone(t);
    final srv = FakeServer()
      ..superAdmin = true
      ..aiOn = true
      ..perms.addAll({'Maintenance': 'Edit'})
      ..mliNames = {
        'fixes': [
          ['party', 'Ganesh Motors', 'GANESH MOTORS'],
          ['work', 'FUEL WATER SEPRETOR', 'FUEL WATER SEPARATOR'],
          ['work', 'NOT IN THE FILE', 'X'],
        ]
      };
    srv.master.addAll([
      {'id': 'RL-173', 'no': '', 'name': 'Roller No.03', 'type': 'Roller', 'owner': 'RCL', 'ownership': 'Own', 'status': 'Active', 'activeFrom': '2025-09-01', 'modes': ['Hrs'], 'worksOn': ['Hrs'], 'unit': 'Hrs'},
      {'id': 'MH-12-XW-0169', 'no': 'MH-12-XW-0169', 'name': 'Hycross', 'type': 'Car', 'owner': 'RCL', 'ownership': 'Own', 'status': 'Active', 'modes': ['KM'], 'worksOn': ['KM'], 'unit': 'KM'},
      {'id': 'JCB-173', 'no': '', 'name': 'JCB 3DX', 'type': 'Backhoe', 'owner': 'Patil', 'ownership': 'Rental', 'status': 'Active', 'modes': ['Hrs'], 'worksOn': ['Hrs'], 'unit': 'Hrs'},
    ]);
    pickThis('All Machinery Maintenance Logbook.xlsx', File('test/fixtures/sheets/maint_logbook.xlsx').readAsBytesSync());
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Maintenance');
    await net(t);
    return srv;
  }

  /// (3.53.0) the import's screen: a key brought into view (the list builds only what is near the screen)
  Future<void> mliSee(WidgetTester t, String k) async {
    final f = find.byKey(Key(k)), list = find.descendant(of: find.byKey(const Key('mli-list')), matching: find.byType(Scrollable)).first;
    if (f.evaluate().isEmpty) {
      await t.drag(list, const Offset(0, 4000));
      await t.pump(const Duration(milliseconds: 300));
      if (f.evaluate().isEmpty) await t.scrollUntilVisible(f, 250, scrollable: list);
    }
    await seen(t, f);
    await t.pump(const Duration(milliseconds: 300));
  }

  /// (3.53.0) the import chosen on the Maintenance page: Excel, PDF, photo or the format
  Future<void> mliChoose(WidgetTester t, String how) async {
    await tapK(t, 'mt-import');
    await settle(t, 800);
    await t.tap(find.byKey(Key('mti-$how')));
    await net(t);
  }

  testWidgets('(3.53.0 – Mechanical update-173) the Admin imports the old maintenance log book (Excel) as it is: a card a sheet – its machinery found among the Own ones on the site (a rented one not); the names the AI finds written in more than one way, nothing ticked – a ticked one goes with the bills; the lines that do not add up; Check (nothing saved) – a sheet with a mistake is not imported; Import asks first; the same file again – the bill already there is left out and listed', (t) async {
    final srv = await mliOpen(t);
    Future<String> st(int i) async {
      await mliSee(t, 'mli-st-$i');
      return '${(t.widget(find.byKey(Key('mli-st-$i'))) as dynamic).data}';
    }

    bool on(String k) => (t.widget(find.byKey(Key(k))) as ButtonStyleButton).onPressed != null;
    expect(find.text('Import the old log book (Excel or PDF)'), findsOneWidget);
    await mliChoose(t, 'excel');
    expect(find.text('All Machinery Maintenance Logbook.xlsx – 3 sheet(s)'), findsOneWidget);
    expect([for (var i = 0; i < 3; i++) await () async { await mliSee(t, 'mli-no-$i'); return (t.widget(find.byKey(Key('mli-no-$i'))) as PickField).value; }()], ['RL-173', 'MH-12-XW-0169', ''], reason: 'ROLLER NO-03 = Roller No.03; MH12XW0169; the JCB is rented – not imported');
    await mliSee(t, 'mli-no-0');
    expect((t.widget(find.byKey(const Key('mli-no-0'))) as PickField).items, unorderedEquals(['Sany 210 (No.1)', 'RL-173', 'MH-12-XW-0169', 'OLD-9']), reason: '(update-175) every Own machinery – on the site now or not (OLD-9, Inactive); not the rented ones');
    expect((t.widget(find.byKey(const Key('mli-no-0'))) as PickField).labels['OLD-9'], 'OLD-9 (not on the site now)');
    expect(find.text('Name in the file: ROLLER NO-03'), findsOneWidget);
    // the names (AI): every name of the file with its rows asked once; its list – only names of the file – nothing ticked
    final nq = srv.maintCalls.where((x) => x['fn'] == 'maintImportNames').toList();
    expect(nq.length, 1);
    expect((nq.first['x'] as Map)['party'], [['Store', 7], ['Ganesh Motors', 2], ['Navnit Motors', 3]]);
    expect((nq.first['x'] as Map)['uom'], [['Ltr', 4], ['Nos', 6], ['Kg', 2]]);
    await mliSee(t, 'mlf-0');
    expect(find.text('Names written in more than one way (AI)'), findsOneWidget);
    expect(['${(t.widget(find.byKey(const Key('mlf-from-0'))) as dynamic).data}', '${(t.widget(find.byKey(const Key('mlf-from-1'))) as dynamic).data}'], ['Party Name: Ganesh Motors', 'Particulars: FUEL WATER SEPRETOR']);
    expect([(t.widget(find.byKey(const Key('mlf-0'))) as Checkbox).value, (t.widget(find.byKey(const Key('mlf-1'))) as Checkbox).value], [false, false], reason: 'he ticks what is to be changed');
    expect((t.widget(find.byKey(const Key('mlt-0'))) as TextField).controller!.text, 'GANESH MOTORS');
    expect(find.text('2 row(s)'), findsOneWidget);
    expect(find.byKey(const Key('mlf-2')), findsNothing, reason: '(the server keeps only names of the file)');
    expect(await st(0), '1 row(s) without a date – Line 12: the date "later"');
    expect([await st(1), await st(2)], ['Press Check', 'not imported']);
    // the lines that do not add up – shown, imported as they are
    await mliSee(t, 'mli-warn-1');
    expect(find.text('2 line(s) to look at – imported as they are'), findsOneWidget);
    await t.tap(find.byKey(const Key('mli-warn-1')));
    await settle(t, 400);
    expect(find.text('• Line 6 (Coolant): Qty × Rate = ₹500, Amount ₹450'), findsOneWidget);
    expect(find.text('• Line 6 (Coolant): Amount + GST = ₹531, Amount With GST ₹541'), findsOneWidget);
    expect([on('mli-check'), on('mli-go')], [true, false]);
    expect(srv.maintCalls.where((x) => x['fn'] == 'checkMaintImport' || x['fn'] == 'importMaint'), isEmpty, reason: 'nothing sent before Check');
    // Check: nothing saved; the roller's "later" is a mistake – nothing of that sheet goes
    final n0 = srv.maint.length;
    await tapK(t, 'mli-check');
    await net(t);
    expect([for (final x in srv.maintCalls.where((x) => x['fn'] == 'checkMaintImport' || x['fn'] == 'importMaint')) x], [
      {'fn': 'checkMaintImport', 'no': 'RL-173', 'bills': 5, 'garages': ['Store', 'Store', 'Ganesh Motors', 'Store', 'Store']},
      {'fn': 'checkMaintImport', 'no': 'MH-12-XW-0169', 'bills': 1, 'garages': ['Navnit Motors']},
    ]);
    expect(await st(0), startsWith('✗ 1 mistake(s) – nothing of this sheet is imported:\nLine 12: '));
    expect(await st(1), '✓ 1 new bill(s), 3 line(s), ₹2,312.8 (10-02-2026 – 10-02-2026)');
    expect(srv.maint.length, n0, reason: 'Check saves nothing');
    expect(on('mli-go'), false, reason: 'a sheet with a mistake – Import waits');
    // a name ticked: checked again with it
    await mliSee(t, 'mlf-0');
    await t.tap(find.byKey(const Key('mlf-0')));
    await settle(t, 400);
    expect((t.widget(find.byKey(const Key('mlf-0'))) as Checkbox).value, true);
    expect(await st(1), 'Press Check', reason: 'a name ticked: the sheets are checked again');
    await tapK(t, 'mli-check');
    await net(t);
    expect(srv.maintCalls.where((x) => x['fn'] == 'checkMaintImport').toList()[2]['garages'], ['Store', 'Store', 'GANESH MOTORS', 'Store', 'Store'], reason: 'the ticked name goes with the bills');
    // the roller: not imported now
    await mliSee(t, 'mli-no-0');
    await t.tap(find.byKey(const Key('mli-no-0')));
    await settle(t, 600);
    await t.tap(find.text('– not imported –').last);
    await settle(t, 600);
    expect([await st(0), on('mli-go')], ['not imported', true]);
    await tapK(t, 'mli-go');
    await settle(t, 600);
    expect(find.text('Import the old log book?'), findsOneWidget);
    expect(find.text('• MH-12-XW-0169: 1 bill(s), ₹2,312.8'), findsOneWidget);
    await tapK(t, 'ask-yes');
    await net(t);
    expect(srv.maintCalls.last, {'fn': 'importMaint', 'no': 'MH-12-XW-0169', 'bills': 1, 'garages': ['Navnit Motors']});
    expect(find.text('1 bill(s) imported.'), findsOneWidget);
    expect(await st(1), '✓ 1 bill(s) imported (MT-000003)');
    expect(find.text('Names written in more than one way (AI)'), findsNothing, reason: '(update-175) nothing left to import: the names\' list is gone');
    final b = srv.maint.firstWhere((r) => r['id'] == 'MT-000003');
    expect([b['no'], b['date'], b['garage'], b['km'], (b['lines'] as List).length, b['total']], ['MH-12-XW-0169', '2026-02-10', 'Navnit Motors', 13153, 3, 2312.8]);
    expect([on('mli-check'), on('mli-go')], [false, false], reason: 'imported – nothing left to do');
    // the same file again: the bill is already there – left out, and listed
    await t.pageBack();
    await net(t);
    await mliChoose(t, 'excel');
    await mliSee(t, 'mli-no-0');
    await t.tap(find.byKey(const Key('mli-no-0')));
    await settle(t, 600);
    await t.tap(find.text('– not imported –').last);
    await settle(t, 600);
    await tapK(t, 'mli-check');
    await net(t);
    expect(await st(1), '✓ 0 new bill(s), 0 line(s), ₹0');
    await mliSee(t, 'mli-same-1');
    expect(find.text('1 bill(s) already there – left out'), findsOneWidget);
    await t.tap(find.byKey(const Key('mli-same-1')));
    await settle(t, 400);
    expect(find.text('• Line 4–6 · 10-02-2026 · ₹2,312.8 – already saved as MT-000003'), findsOneWidget);
    expect(srv.maint.length, n0 + 1);
  });

  testWidgets('(3.53.0 – 28-10-2026; 3.59.0) the old log book as a PDF, read by the AI a page a call in parts of 25 rows (a cut answer: asked again of the quicker model in fewer rows) – each machinery\'s table a sheet; without the AI it says so; "Download the format (Excel)": a sheet for each Own machinery on the site, its number in row 3, the heading', (t) async {
    final srv = await mliOpen(t);
    final p0 = pickAttFiles;
    addTearDown(() => pickAttFiles = p0);
    pickAttFiles = (how, room) async => [(name: 'Old log book.pdf', bytes: Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF\n')))];
    final web = jsonDecode(File('test/fixtures/sheets/maint_logbook.json').readAsStringSync()) as Map<String, dynamic>, tb = web['aiTables'] as List;
    srv
      ..mliNames = {'fixes': []}
      ..mliPages.addAll([
        {'pages': 3, 'tables': [tb[0], tb[1]]},
        'cut',
        {'pages': 3, 'tables': [tb[2], tb[3]]},
        {'pages': 3, 'tables': []},
      ]);
    await mliChoose(t, 'pdf');
    await net(t);
    expect([for (final x in srv.maintCalls.where((x) => x['fn'] == 'readMaintLog')) '${x['from']}/${x['n']}/${x['max']}/${x['fast']}/${x['kind']}'],
        ['1/1/25/0/application/pdf', '2/1/25/0/application/pdf', '2/1/13/1/application/pdf', '3/1/25/0/application/pdf'], reason: 'a page a call, at most 25 rows; page 2 cut off: asked again of the quicker model, 13 rows');
    expect(find.text('Old log book.pdf – 2 sheet(s)'), findsOneWidget);
    await mliSee(t, 'mli-no-0');
    expect([(t.widget(find.byKey(const Key('mli-no-0'))) as PickField).value, find.text('Name in the file: ROLLER NO-03').evaluate().length], ['RL-173', 1]);
    await mliSee(t, 'mli-no-1');
    expect((t.widget(find.byKey(const Key('mli-no-1'))) as PickField).value, 'MH-12-XW-0169');
    await mliSee(t, 'mlf-state');
    expect('${(t.widget(find.byKey(const Key('mlf-state'))) as dynamic).data}', '✓ The AI found no name written in more than one way.');
    expect(find.byKey(const Key('mli-warn-0')), findsNothing, reason: '(3.59.0) BULB keeps its GST ₹10 as in the file – no "odd GST %" any more');
    await tapK(t, 'mli-check');
    await net(t);
    expect([for (final x in srv.maintCalls.where((x) => x['fn'] == 'checkMaintImport')) '${x['no']}:${x['bills']}'], ['RL-173:2', 'MH-12-XW-0169:1']);
    // the AI not set up: said so – nothing read
    await t.pageBack();
    await net(t);
    srv.aiOn = false;
    await mliChoose(t, 'pdf');
    await net(t);
    expect('${(t.widget(find.byKey(const Key('mli-read-err'))) as dynamic).data}', 'The AI is not set up – a PDF or a photo cannot be read now; import the Excel instead.');
    expect(find.byKey(const Key('mli-retry')), findsOneWidget);
    await t.pageBack();
    await net(t);
    // the format
    final files = catchFiles();
    await mliChoose(t, 'fmt');
    expect([for (final f in files) f.$1], ['Old Maintenance Log Book – format.xlsx']);
    final tabs = readSheets(files.first.$2);
    expect(tabs.first.name, 'How to fill');
    expect([for (final x in tabs) x.name], containsAll(['RL-173', 'MH-12-XW-0169', 'Sany 210 (No.1)']));
    expect([for (final x in tabs) x.name], isNot(contains('JCB-173')), reason: 'a rented machinery: no sheet');
    final rl = tabs.firstWhere((x) => x.name == 'RL-173').rows;
    expect([rl[1][0], rl[2][0], rl[3].join(' · ')], ['Maintenance Log Book – Roller No.03', 'RL-173', 'Sr No · Date · Party Name · Current Reading · Particulars · Qty · Uom · Basic Rate · Amount · GST Amount · Amount With GST · Total']);
  });

  testWidgets('(3.53.0 – "he admin la fkt nahi user la pn disu de") Maintenance View only: the import is not shown', (t) async {
    phone(t);
    final v = FakeServer()..perms.addAll({'Maintenance': 'View'});
    final sv = await ready(t, v);
    expect([sv.admin, sv.canEdit('Maintenance')], [false, false]);
    await t.pumpWidget(RclApp(session: sv));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Maintenance');
    await net(t);
    expect(find.byKey(const Key('mt-import')), findsNothing, reason: 'View only');
  });

  testWidgets('(3.53.0 – "he admin la fkt nahi user la pn disu de") the import for a user with Maintenance Edit (not the Admin); his Maintenance under verification: the import is sent, said as sent', (t) async {
    phone(t);
    final srv = FakeServer()
      ..aiOn = true
      ..perms.addAll({'Maintenance': 'Edit'})
      ..flowFor = 'importMaint';
    srv.master.add({'id': 'MH-12-XW-0169', 'no': 'MH-12-XW-0169', 'name': 'Hycross', 'type': 'Car', 'owner': 'RCL', 'ownership': 'Own', 'status': 'Active', 'modes': ['KM'], 'worksOn': ['KM'], 'unit': 'KM'});
    pickThis('All Machinery Maintenance Logbook.xlsx', File('test/fixtures/sheets/maint_logbook.xlsx').readAsBytesSync());
    final s = await ready(t, srv);
    expect([s.admin, s.canEdit('Maintenance')], [false, true]);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Maintenance');
    await net(t);
    await mliChoose(t, 'excel');
    expect(find.text('All Machinery Maintenance Logbook.xlsx – 3 sheet(s)'), findsOneWidget);
    await mliSee(t, 'mli-no-1');
    expect((t.widget(find.byKey(const Key('mli-no-1'))) as PickField).value, 'MH-12-XW-0169');
    for (final i in [0, 2]) {      // (an Own machinery of this test site matches no other sheet – only the car is imported)
      await mliSee(t, 'mli-no-$i');
      if ((t.widget(find.byKey(Key('mli-no-$i'))) as PickField).value.isNotEmpty) {
        await t.tap(find.byKey(Key('mli-no-$i')));
        await settle(t, 600);
        await t.tap(find.text('– not imported –').last);
        await settle(t, 600);
      }
    }
    await tapK(t, 'mli-check');
    await net(t);
    await tapK(t, 'mli-go');
    await settle(t, 600);
    await tapK(t, 'ask-yes');
    await net(t);
    await mliSee(t, 'mli-st-1');
    expect('${(t.widget(find.byKey(const Key('mli-st-1'))) as dynamic).data}', 'Sent for verification to Checker One – VF-00007. It is saved when it is approved; nothing is saved until then.');
    expect(srv.maint.any((r) => r['no'] == 'MH-12-XW-0169'), false, reason: 'nothing saved until it is approved');
  });

  testWidgets('(3.53.0 – Mechanical update-175) the bills "Start to end" (every date); the Maintenance Log Book "Start to end" (no dates sent); "Fetch outward (Store)" – the Store\'s Issue is not built yet: said so, then the log book start to end', (t) async {
    phone(t);
    final srv = FakeServer()..perms.addAll({'Maintenance': 'Edit'});
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Maintenance');
    await net(t);
    await tapK(t, 'mt-all');
    await net(t);
    expect(srv.maintCalls.lastWhere((x) => x['fn'] == 'getMaint')['x'], {'from': '', 'to': '', 'no': ''}, reason: 'every date');
    expect(find.textContaining('Start to end · 2 · '), findsOneWidget);
    expect((t.widget(find.byKey(const Key('mt-from'))) as DateField).enabled, false);
    // Fetch outward (Store): the machinery picked, the log book asked start to end; the Store's Issue not built: said so
    await tapK(t, 'mt-out');
    await settle(t, 800);
    await t.tap(find.text('Sany 210 (No.1)').last);
    await net(t);
    expect(srv.maintCalls.where((x) => x['fn'] == 'maintLog').first['x'], {'no': 'Sany 210 (No.1)', 'all': true});
    expect(find.textContaining("The Store's work is not set up at this site yet (its database step 2)"), findsOneWidget, reason: '(3.55.0) a site without the Store\'s step 2');
    await net(t);
    expect(srv.maintCalls.where((x) => x['fn'] == 'maintLog').last['x'], {'no': 'Sany 210 (No.1)', 'all': true}, reason: 'the log book opened start to end');
    expect(find.textContaining('Start to end'), findsWidgets, reason: 'the report says it is start to end');
  });

  testWidgets('(3.53.0) Picture: the old log book\'s import after Check – the names (AI), a sheet with a mistake, one to import, one rented (not imported)', (t) async {
    await mliOpen(t);
    await mliChoose(t, 'excel');
    await tapK(t, 'mli-check');
    await net(t);
    await t.drag(find.descendant(of: find.byKey(const Key('mli-list')), matching: find.byType(Scrollable)).first, const Offset(0, 4000));
    await settle(t, 400);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/63_maint_import.png'));
  }, tags: ['golden']);

  testWidgets('(3.49.0 – Mechanical update-168) a bill as his: every line with its kind (Paid / Warranty / FOC / Service Plan), Qty, Rate, Disc % and ₹; the free lines ₹ 0 with their worth; the car from the bill\'s number; an insurance claim – we paid the rest; the list, the sheet, Change and the car\'s log book; the kinds in मराठी', (t) async {
    phone(t);
    final p0 = pickAttFiles, c0 = attCompute;
    attCompute = <M, R>(ComputeCallback<M, R> cb, M m, {String? debugLabel}) async => await cb(m);
    addTearDown(() {
      pickAttFiles = p0;
      attCompute = c0;
    });
    final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n% 168\n'));
    pickAttFiles = (how, room) async => [(name: 'bill168.pdf', bytes: pdf)];
    const ins = 'Test General Insurance';
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Maintenance': 'Edit'})
      ..card = true
      ..aiOn = true
      // what the server gives from the AI's short lines (maintAnswer_): every line with its kind; the insurance = the bill less what we paid
      ..maintRead = {'date': '2026-10-13', 'billNo': '07668, 02040', 'garage': 'Test Toyota', 'vehicle': 'MH12HO2163', 'km': 61234, 'service': true, 'total': 2761, 'check': '',
        'lines': [
          {'work': 'Periodic maintenance labour', 'type': 'Paid', 'amount': 1800, 'qty': 1, 'rate': 1800, 'disc': 0},
          {'work': 'Wheel alignment', 'type': 'Paid', 'amount': 540, 'qty': 1, 'rate': 600, 'disc': 10},
          {'work': 'Engine oil', 'type': 'Service Plan', 'amount': 0, 'qty': 4.5, 'rate': 520, 'disc': 100},
          {'work': 'Oil filter', 'type': 'Warranty', 'amount': 0, 'qty': 1, 'rate': 350, 'disc': 0},
          {'work': 'Car wash', 'type': 'FOC', 'amount': 0, 'qty': 1, 'rate': 250, 'disc': 0},
          {'work': 'CGST 9%', 'type': 'Paid', 'amount': 210.6, 'disc': 0},
          {'work': 'SGST 9%', 'type': 'Paid', 'amount': 210.6, 'disc': 0},
          {'work': 'Round off', 'type': 'Paid', 'amount': -0.2, 'disc': 0},
        ],
        'insurance': {'company': ins, 'claimNo': 'CLM-168', 'paid': 2000}};
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Maintenance');
    await net(t);
    await t.tap(find.byKey(const Key('mt-add')));
    await net(t);
    // no car picked: the bill's number gives it
    await tapK(t, 'att-pdf');
    await net(t);
    await tapK(t, 'mf-read');
    await net(t);
    String box(String k) => (t.widget(find.byKey(Key(k))) as TextBox).controller.text;
    PickField kind(int i) => t.widget(find.byKey(Key('mf-t-$i'))) as PickField;
    String txt(String k) => '${(t.widget(find.byKey(Key(k))) as dynamic).data}';
    expect(find.descendant(of: find.byKey(const Key('mf-car')), matching: find.textContaining('MH-12-HO-2163')), findsOneWidget, reason: 'the car of the bill\'s vehicle number');
    expect([for (var i = 0; i < 8; i++) kind(i).value], ['Paid', 'Paid', 'Service Plan', 'Warranty', 'FOC', 'Paid', 'Paid', 'Paid']);
    expect(kind(0).items, ['Paid', 'By Insurance', 'Warranty', 'FOC', 'Service Plan']);
    expect(kind(0).labels, {'Paid': 'RCL', 'By Insurance': 'Insurance'}, reason: '(3.51.0) "Paid by": RCL / Insurance shown, the kinds kept');
    expect([box('mf-q-1'), box('mf-r-1'), box('mf-d-1'), box('mf-a-1')], ['1', '600', '10', '540']);
    expect([box('mf-q-2'), box('mf-r-2'), box('mf-d-2'), box('mf-a-2')], ['4.5', '520', '100', '0']);
    expect([for (final i in [2, 3, 4]) (t.widget(find.byKey(Key('mf-a-$i'))) as TextBox).enabled], [false, false, false], reason: 'a free line is ₹ 0 – not typed');
    expect([for (final i in [2, 3, 4]) txt('mf-worth-$i')], ['worth ₹2,340', 'worth ₹350', 'worth ₹250']);
    expect([box('mf-a-5'), box('mf-q-5'), box('mf-r-5')], ['210.6', '', '']);
    expect([txt('mf-total'), txt('mf-free'), txt('mf-wepaid')], ['₹ 2,761', '₹ 2,940', '₹ 761']);
    expect((t.widget(find.byKey(const Key('mf-ins'))) as SwitchListTile).value, true);
    expect([box('mf-insco'), box('mf-insclaim'), box('mf-inspaid')], [ins, 'CLM-168', '2000']);
    expect(find.byWidgetPredicate((w) => w is AiBox && w.on), findsNWidgets(17), reason: 'the car, garage, bill no., KM, Service, the 8 lines and the insurance (its switch, company, claim no., ₹) – blue; '
        'the date not: a user\'s bill is dated today (3.62.1, update-188 – the bill says 13-10-2026)');
    expect(find.textContaining('Read by the AI (blue) – check every value before saving.'), findsOneWidget);
    expect(find.textContaining('check the car'), findsNothing);
    await seen(t, find.byKey(const Key('mf-a-1')));
    await settle(t, 300);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/65_mnt_bill_lines.png'));
    // typed: Disc % of line 2 → 0 – its ₹ from 1 × 600; the totals with it
    await t.enterText(find.byKey(const Key('mf-d-1')), '0');
    await settle(t, 300);
    expect(box('mf-a-1'), '600');
    expect([txt('mf-total'), txt('mf-wepaid')], ['₹ 2,821', '₹ 821']);
    // "Car wash" FOC → Paid: ₹ 250 from 1 × 250, to be typed; back to FOC: ₹ 0
    Future<void> pick(int i, String v) async {
      await tapK(t, 'mf-t-$i');
      await settle(t, 600);
      await t.tap(find.text(v).last);
      await settle(t, 600);
    }
    await pick(4, 'RCL');      // (3.51.0: "Paid by" – RCL)
    expect([kind(4).value, box('mf-a-4'), (t.widget(find.byKey(const Key('mf-a-4'))) as TextBox).enabled, txt('mf-total'), txt('mf-free')], ['Paid', '250', true, '₹ 3,071', '₹ 2,690']);
    expect(find.byKey(const Key('mf-worth-4')), findsNothing);
    await pick(4, 'FOC');
    expect([kind(4).value, box('mf-a-4'), txt('mf-worth-4'), txt('mf-total')], ['FOC', '0', 'worth ₹250', '₹ 2,821']);
    // (3.50.0, update-170) a line's Uom typed
    await seen(t, find.byKey(const Key('mf-u-2')));
    await t.enterText(find.byKey(const Key('mf-u-2')), 'Ltr');
    await settle(t, 300);
    await seen(t, find.byKey(const Key('mf-wepaid')));
    await settle(t, 300);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/66_mnt_bill_insurance.png'));
    await tapK(t, 'mf-save');
    await net(t);
    final x = Map<String, dynamic>.from(srv.maintCalls.lastWhere((c) => c['fn'] == 'saveMaint')['x'] as Map);
    final ls = [for (final l in x['lines'] as List) Map<String, dynamic>.from(l as Map)];
    expect(x['no'], 'MH-12-HO-2163');
    expect([for (final l in ls) l['type']], ['Paid', 'Paid', 'Service Plan', 'Warranty', 'FOC', 'Paid', 'Paid', 'Paid']);
    expect(ls[1], {'work': 'Wheel alignment', 'type': 'Paid', 'qty': 1, 'uom': '', 'rate': 600, 'disc': 0, 'amount': 600, 'gst': '', 'gstAmt': ''});
    expect(ls[2], {'work': 'Engine oil', 'type': 'Service Plan', 'qty': 4.5, 'uom': 'Ltr', 'rate': 520, 'disc': 100, 'amount': 0, 'gst': '', 'gstAmt': ''}, reason: '(3.50.0) the Uom typed');
    expect(ls[5], {'work': 'CGST 9%', 'type': 'Paid', 'qty': '', 'uom': '', 'rate': '', 'disc': 0, 'amount': 210.6, 'gst': '', 'gstAmt': ''});
    expect(x['insurance'], {'company': ins, 'claimNo': 'CLM-168', 'paid': 2000});
    expect(find.textContaining('(We paid ₹821 of ₹2,821.)'), findsOneWidget, reason: 'the message says what we paid of the bill');
    // the list: what we paid, the bill and the insurance, the free lines' worth
    expect(find.descendant(of: find.byKey(const Key('mt-r-MT-000003')), matching: find.text('₹ 821')), findsOneWidget);
    expect(txt('mt-note-MT-000003'), 'bill ₹2,821 · insurance ₹2,000 ($ins) · free worth ₹2,940');
    expect(find.descendant(of: find.byKey(const Key('mt-r-MT-000003')), matching: find.textContaining('Engine oil (Service Plan); Oil filter (Warranty); Car wash (FOC)')), findsOneWidget);
    // the sheet
    await tapK(t, 'mt-r-MT-000003');
    await settle(t, 800);
    expect(find.text('Service Plan · worth ₹2,340'), findsOneWidget);
    expect(find.text('₹ 600 · 1 × 600 · RCL'), findsOneWidget);
    expect(find.text('− ₹ 2,000 · $ins · Claim no. CLM-168'), findsOneWidget);
    expect(find.text('We paid'), findsOneWidget);
    expect(find.text('₹ 2,940'), findsOneWidget, reason: 'the free lines\' worth');
    // Change: everything back; saved as it is
    await tapK(t, 'mt-edit');
    await net(t);
    expect([for (var i = 0; i < 8; i++) kind(i).value], ['Paid', 'Paid', 'Service Plan', 'Warranty', 'FOC', 'Paid', 'Paid', 'Paid']);
    expect([(t.widget(find.byKey(const Key('mf-ins'))) as SwitchListTile).value, box('mf-insco'), box('mf-insclaim'), box('mf-inspaid'), txt('mf-wepaid')], [true, ins, 'CLM-168', '2000', '₹ 821']);
    expect(find.byWidgetPredicate((w) => w is AiBox && w.on), findsNothing, reason: 'a bill opened to change: nothing blue');
    // the kinds in मराठी – shown in Marathi, their English values kept and sent
    await Lang.i.set('mr', read: (p) async => p.endsWith('web_mr.json') ? jsonEncode({'Service Plan': 'सर्व्हिस प्लॅन', 'Warranty': 'वॉरंटी', 'Kind': 'प्रकार'}) : '{}');
    await settle(t, 600);
    expect(find.text('सर्व्हिस प्लॅन'), findsWidgets);
    expect(kind(2).value, 'Service Plan');
    await tapK(t, 'mf-save');
    await net(t);
    final u = Map<String, dynamic>.from(srv.maintCalls.lastWhere((c) => c['fn'] == 'updateMaint')['x'] as Map);
    expect([for (final l in u['lines'] as List) (l as Map)['type']], ['Paid', 'Paid', 'Service Plan', 'Warranty', 'FOC', 'Paid', 'Paid', 'Paid']);
    expect(u['insurance'], {'company': ins, 'claimNo': 'CLM-168', 'paid': 2000});
    await Lang.i.set('');
    await settle(t, 300);
    // the car's log book: "we paid" with the bills and the insurance, the free lines' worth (as the web)
    srv.maintLogAnswer = {'title': 'Maintenance Log Book – MH-12-HO-2163', 'from': '2026-10-01', 'to': '2026-10-14', 'generated': '14-10-2026 10:00', 'company': 'Rachana Construction Limited',
      'machine': {'id': 'MH-12-HO-2163', 'name': 'Innova', 'type': 'Car', 'fuel': 'Petrol', 'unit': 'Ltr', 'meter': 'KM'}, 'card': false,
      'lines': [{'date': '2026-10-13', 'kind': 'Maintenance', 'id': 'MT-000003', 'no': 'MH-12-HO-2163', 'garage': 'Test Toyota', 'party': 'Test Toyota', 'billNo': '07668, 02040', 'km': 61234, 'amount': 821, 'total': 821, 'billTotal': 2821, 'free': 2940,
        'insurance': {'company': ins, 'claimNo': 'CLM-168', 'paid': 2000}, 'service': true, 'files': 1, 'lines': [{'work': 'Wheel alignment', 'type': 'Paid', 'amount': 600}, {'work': 'Oil filter', 'type': 'Warranty', 'amount': 0, 'qty': 1, 'rate': 350}]}],
      'total': {'fuel': {'qty': 0, 'amount': 0, 'card': 0, 'cash': 0, 'fills': 0}, 'maint': {'amount': 821, 'bills': 1, 'billTotal': 2821, 'insurance': 2000, 'free': 2940}, 'all': 821, 'km': 0, 'perKm': null,
        'byWork': [{'work': 'Wheel alignment', 'amount': 600, 'n': 1}]},
      'lastService': {'date': '2026-10-13', 'km': 61234, 'id': 'MT-000003'}};
    await tapK(t, 'mt-car');
    await settle(t, 800);
    await t.tap(find.text('MH-12-HO-2163').last);
    await net(t);
    await reach(t, 'mt-log', 'mt-list');      // (3.53.0: the page is longer – the import, Fetch outward, Start to end)
    await tapK(t, 'mt-log');
    await net(t);
    expect(srv.maintCalls.lastWhere((x) => x['fn'] == 'maintLog')['x'], {'from': '2026-10-01', 'to': '2026-10-14', 'no': 'MH-12-HO-2163'});
    // (3.50.0, update-170) his format: the bill's lines, the free one with its kind, the insurance's row, the total of the lines; by work: we paid
    // (3.52.0) a line's name without its kind after it – Paid by is its column
    for (final w in ['Test Toyota · Bill 07668, 02040', 'Wheel alignment', 'Oil filter', 'Warranty', 'Paid by the insurance – $ins (claim no. CLM-168)', 'Total – 1 bill(s)', 'Free lines (warranty / FOC / service plan) – not paid, worth']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
    expect(find.text('Oil filter (Warranty)'), findsNothing);
    expect(find.textContaining('Fuel – '), findsNothing, reason: 'not a site on fuel cards here: no fuel table');
    for (final w in ['Paid lines of the bills', 'Paid by the insurance', 'We paid']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
  }, tags: ['golden']);

  testWidgets('(3.51.0 – Mechanical update-171) each line its GST % (CGST and SGST half each) and its Paid by (RCL / Insurance / …); lines paid by the insurance make the claim; the log book: the GST rates in its heading, Paid by, Insurance claim and Service on each line', (t) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Maintenance': 'Edit'})
      ..card = true;      // (the pretend server's cars are at its site on fuel cards)
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Maintenance');
    await net(t);
    await t.tap(find.byKey(const Key('mt-add')));
    await net(t);
    String box(String k) => (t.widget(find.byKey(Key(k))) as TextBox).controller.text;
    String txt(String k) => '${(t.widget(find.byKey(Key(k))) as dynamic).data}';
    Future<void> type(String k, String v) async {
      await seen(t, find.byKey(Key(k)));
      await settle(t, 200);
      await t.enterText(find.byKey(Key(k)), v);
      await settle(t, 200);
    }
    await t.tap(find.byKey(const Key('mf-car')));
    await settle(t, 800);
    await t.tap(find.text('MH-12-HO-1163').last);
    await settle(t, 600);
    await type('mf-garage', 'Test Garage');
    // a line of RCL: 1 × 1,000 at 18 % – GST ₹180 (CGST 90 + SGST 90), ₹1,180 with it
    await type('mf-w-0', 'Battery');
    await type('mf-q-0', '1');
    await type('mf-r-0', '1000');
    await type('mf-g-0', '18');
    expect([box('mf-a-0'), txt('mf-gv-0'), txt('mf-total')], ['1000', 'GST ₹180 · With GST ₹1,180', '₹ 1,180']);
    expect((t.widget(find.byKey(const Key('mf-ins'))) as SwitchListTile).value, false);
    // a line paid by the insurance: the claim is on by itself, "Paid by the insurance" its ₹ with GST – not typed
    await seen(t, find.byKey(const Key('mf-addl')));
    await tapK(t, 'mf-addl');
    await settle(t, 300);
    await type('mf-w-1', 'Bumper');
    await type('mf-q-1', '1');
    await type('mf-r-1', '10000');
    await type('mf-g-1', '18');
    await settle(t, 300);
    await seen(t, find.byKey(const Key('mf-t-1')));
    await tapK(t, 'mf-t-1');
    await settle(t, 600);
    await t.tap(find.text('Insurance').last);
    await settle(t, 600);
    expect((t.widget(find.byKey(const Key('mf-t-1'))) as PickField).value, 'By Insurance');
    expect([txt('mf-gv-1'), txt('mf-total')], ['GST ₹1,800 · With GST ₹11,800', '₹ 12,980']);
    final sw = t.widget(find.byKey(const Key('mf-ins'))) as SwitchListTile;
    expect([sw.value, sw.onChanged == null], [true, true], reason: 'the claim stays on while a line is paid by the insurance');
    expect([box('mf-inspaid'), (t.widget(find.byKey(const Key('mf-inspaid'))) as TextBox).enabled, txt('mf-wepaid')], ['11800', false, '₹ 1,180']);
    await type('mf-insco', 'Test Insurance');
    await seen(t, find.byKey(const Key('mf-save')));
    await tapK(t, 'mf-save');
    await net(t);
    final x = Map<String, dynamic>.from(srv.maintCalls.lastWhere((c) => c['fn'] == 'saveMaint')['x'] as Map);
    expect(x['lines'], [
      {'work': 'Battery', 'type': 'Paid', 'qty': 1, 'uom': '', 'rate': 1000, 'disc': '', 'amount': 1000, 'gst': 18, 'gstAmt': ''},
      {'work': 'Bumper', 'type': 'By Insurance', 'qty': 1, 'uom': '', 'rate': 10000, 'disc': '', 'amount': 10000, 'gst': 18, 'gstAmt': ''},
    ]);
    expect(x['insurance'], {'company': 'Test Insurance', 'claimNo': '', 'paid': 11800});
    expect(find.textContaining('(We paid ₹1,180 of ₹12,980.)'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('mt-r-MT-000003')), matching: find.textContaining('Battery ₹1,180; Bumper ₹11,800 (Insurance)')), findsOneWidget);
    // the sheet: each line with GST and who paid it
    await tapK(t, 'mt-r-MT-000003');
    await settle(t, 800);
    expect(find.text('₹ 1,180 · 1 × 1,000 · GST 18 % · RCL'), findsOneWidget);
    expect(find.text('₹ 11,800 · 1 × 10,000 · GST 18 % · Insurance'), findsOneWidget);
    await t.tapAt(const Offset(200, 40));
    await settle(t, 800);
    // the log book: one GST % → CGST 9 % and SGST 9 % in the heading, the GST column "GST 18%"; each line its Paid by, the bill's claim and service
    srv.maintLogAnswer = {'title': 'Maintenance Log Book – MH-12-HO-1163', 'from': '2026-10-01', 'to': '2026-10-14', 'generated': '14-10-2026 10:00', 'company': 'Rachana Construction Limited',
      'machine': {'id': 'MH-12-HO-1163', 'name': 'Roller', 'type': 'Roller', 'fuel': 'Diesel', 'unit': 'Ltr', 'meter': 'Hrs'}, 'card': false,
      'lines': [{'date': '2026-10-13', 'kind': 'Maintenance', 'id': 'MT-000003', 'no': 'MH-12-HO-1163', 'garage': 'Test Garage', 'party': 'Test Garage', 'billNo': '', 'km': '', 'amount': 1180, 'total': 1180, 'billTotal': 12980, 'free': 0,
        'insurance': {'company': 'Test Insurance', 'claimNo': '', 'paid': 11800}, 'service': false, 'files': 0, 'lines': x['lines']}],
      'total': {'fuel': {'qty': 0, 'amount': 0, 'card': 0, 'cash': 0, 'fills': 0}, 'maint': {'amount': 1180, 'bills': 1, 'billTotal': 12980, 'insurance': 11800, 'free': 0}, 'all': 1180, 'km': 0, 'perKm': null,
        'byWork': [{'work': 'Battery', 'amount': 1180, 'n': 1}]},
      'lastService': null};
    await tapK(t, 'mt-car');
    await settle(t, 800);
    await t.tap(find.text('MH-12-HO-1163').last);
    await net(t);
    await reach(t, 'mt-log', 'mt-list');      // (3.53.0: the page is longer – the import, Fetch outward, Start to end)
    await tapK(t, 'mt-log');
    await net(t);
    for (final w in ['CGST 9%', 'SGST 9%', 'GST 18%', 'Amount With GST', 'Paid by', 'Insurance claim', 'Service', 'RCL', 'Insurance', 'Yes', 'No', '90.00', '900.00', '1,800.00', '11,800.00', '990.00', '1,980.00', '-11,800.00']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
    expect(find.text('GST Amount'), findsNothing, reason: 'one GST % – its rate in the heading');
  });

  testWidgets('(3.14.0) My settings: Log Book list shows, the page to open after sign-in, my last sign-ins, back to the usual settings', (t) async {
    phone(t);
    final srv = FakeServer();
    srv.prefs['photo'] = '';
    srv.prefs['mobile'] = '9800000000';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-me')));
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
    await seen(t, find.text('Administration'));
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
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    await t.tap(find.text('My settings'));
    await net(t);
    await t.scrollUntilVisible(find.text('Daily summary when I open the app'), 200, scrollable: find.byType(Scrollable).last);
    await seen(t, find.text('Daily summary when I open the app'));
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
      {'parts': [{'functionCall': {'name': 'diesel_issues', 'args': {'from': '2026-10-14', 'to': '2026-10-14'}}}], 'model': 'claude-sonnet-5-5'},
      {'parts': [{'text': 'Kobelco Sk 220 and MH-25-AJ-2169 took the most today: **80 L** each. [[open:diesel|Diesel Issue]]'}], 'model': 'claude-sonnet-5-5'},
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
    await t.tap(find.byKey(const Key('tab-home')));
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
    // Admin: which model answers – (3.48.0) no key on the server: it names the Claude key
    await tapK(t, 'ai-test');
    await net(t);
    expect(find.textContaining('No key on the server (ANTHROPIC_API_KEY for Claude).'), findsOneWidget);
    srv.aiOn = true;
    await tapK(t, 'ai-test');
    await net(t);
    // (3.48.0, Mechanical update-167) the server's AI is Claude: the service named, each model with its time or what it said
    expect(find.textContaining('Service: Claude'), findsOneWidget);
    expect(find.textContaining('✓ claude-sonnet-5-5 – answered in 1.2 s'), findsOneWidget);
    expect(find.textContaining('✗ claude-haiku-5-5 – 529: Overloaded'), findsOneWidget);
    expect(find.textContaining('At least one model answers'), findsOneWidget);
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
    await t.tap(find.byKey(const Key('tab-reports')));
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
    srv.aiScript.add({'parts': [{'text': 'Pick the machinery from the list – type part of its number.'}], 'model': 'claude-sonnet-5-5'});
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
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    await tapK(t, 'me-super'); // (3.31.0) his role is also on Me now
    await net(t);
    return srv;
  }

  /// A choice of a row of choices (a role, a page): brought into view, then tapped.
  Future<void> tapIn(WidgetTester t, String key, String text) async {
    final f = find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
    FocusManager.instance.primaryFocus?.unfocus();
    await seen(t, f);
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
    // (3.64.0, Mechanical update-189) Diesel Issue – a page with a date: Admin (its entries of an earlier day); the Log Book here offers no Admin
    expect(find.descendant(of: find.byKey(const Key('sa-pg-log')), matching: find.text('Admin')), findsNothing);
    await tapIn(t, 'sa-pg-diesel', 'Admin');
    await t.pump();
    await tapK(t, 'sa-pg-save');
    await net(t);
    expect(saves(srv).last, {'action': 'mechPagesSave', 'site': 'S1', 'email': 'amol@rcl.test', 'perms': {'diesel': 'Admin', 'log': 'Edit', 'reports': 'None'}});
    expect(find.text('Pages saved in Mechanical.'), findsOneWidget);
    // the Store: he is its Admin now – every page; (3.55.0, the Store's step 2) only who approves and Store Purchase are given to him
    await tapK(t, 'sa-pages-store');
    await net(t);
    expect(find.textContaining('Store Admin has every page'), findsOneWidget);
    expect(find.byKey(const Key('sa-spg-items')), findsNothing, reason: 'an Admin has the pages');
    expect(find.byKey(const Key('sa-spg-purchase')), findsOneWidget);
    // (3.62.0, the Store's step 5) and who approves its purchase orders – the Portal's note says what it does (read at the top: 3.71.0's
    // longer note and more pages – scrolled to a page further down, the note is no longer built)
    expect(find.textContaining('Approves purchase orders: a PO of this site is taken in (GRN) only after one of them approves it'), findsOneWidget);
    await tapK(t, 'sa-spg-approve');
    await settle(t, 600);
    await t.tap(find.text('Level 2').last);
    await settle(t, 400);
    await tapIn(t, 'sa-spg-poapprove', 'Yes');
    await tapK(t, 'sa-spg-save');
    await net(t);
    // (3.71.0) and who verifies each work, who approves the GRN / the issues (not given: None)
    expect(saves(srv).last, {'action': 'storePagesSave', 'site': 'S1', 'email': 'amol@rcl.test', 'pages': {'vreq': 'None', 'approve': 'L2', 'purchase': 'None', 'vpo': 'None', 'poapprove': 'Yes', 'vgrn': 'None', 'agrn': 'None', 'viss': 'None', 'aiss': 'None'}});
    expect(find.text('Store pages saved.'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.70.0) Super Admin – Sites: a site\'s address and contact (the Store\'s papers – the PO\'s Shipping Address and Site Contact, a requirement\'s contact), saved with the site', (t) async {
    phone(t);
    final srv = await openConsole(t);
    await t.tap(find.byKey(const Key('sa-t-sites')));
    await net(t);
    await tapK(t, 'sa-st-S1');
    await net(t);
    for (final (k, v) in [('sa-st-addr', 'Site office, Valshind, NH 848'), ('sa-st-cname', 'Ramesh Patil'), ('sa-st-cphone', '98765 43210')]) {
      await seen(t, find.byKey(Key(k)));
      await t.enterText(find.byKey(Key(k)), v);
    }
    await settle(t, 300);
    await tapK(t, 'sa-st-save');
    await net(t);
    final x = saves(srv).lastWhere((y) => y['action'] == 'siteSave');
    expect([x['code'], x['address'], x['contact_name'], x['contact_phone']], ['S1', 'Site office, Valshind, NH 848', 'Ramesh Patil', '98765 43210']);
    expect(srv.saSites.firstWhere((y) => y['code'] == 'S1')['contact_name'], 'Ramesh Patil');
  });

  testWidgets('(3.71.0) Super Admin – Workflow: a site\'s Store – who verifies and approves each work (given in Users & Access), and once approved, Head Office Yes / No; saved – the Store told; before the Portal\'s step 6 said so', (t) async {
    phone(t);
    final srv = await openConsole(t);
    (srv.saAccess.firstWhere((a) => a['email'] == 'amol@rcl.test' && a['module'] == 'store'))['pages'] = {'dashboard': 'View', 'vreq': 'Yes', 'approve': 'L1', 'vgrn': 'Yes'};
    await tapK(t, 'sa-reload');
    await net(t);
    await tapK(t, 'sa-t-wf');
    await net(t);
    Finder inK(String k, String text) => find.descendant(of: find.byKey(Key(k)), matching: find.text(text));
    expect(inK('sa-wf-req', 'Verifies: Amol Patil'), findsOneWidget);
    expect(inK('sa-wf-req', 'Approves: Level 1: Amol Patil'), findsOneWidget);
    expect(inK('sa-wf-po', 'Verifies: nobody – no verification'), findsOneWidget);
    expect(inK('sa-wf-po', 'Approves: nobody – approved when made'), findsOneWidget);
    expect(inK('sa-wf-grn', 'Verifies: Amol Patil'), findsOneWidget);
    expect(inK('sa-wf-grn', 'Approves: nobody – no approval'), findsOneWidget);
    // not set yet: the requirements to Head Office, the GRNs and the issues stay at the site
    // (each card brought into view first – the list builds only what is near the screen)
    Future<List<bool>> sel() async {
      final r = <bool>[];
      for (final k in ['req', 'grn', 'iss']) {
        await reach(t, 'sa-wf-ho-$k', 'sa-wf');
        r.add(t.widget<SegmentedButton<bool>>(find.byKey(Key('sa-wf-ho-$k'))).selected.single);
      }
      return r;
    }
    expect(await sel(), [true, false, false]);
    await reach(t, 'sa-wf-ho-req', 'sa-wf');
    await tapIn(t, 'sa-wf-ho-req', 'No');
    await settle(t, 300);
    expect(inK('sa-wf-req', 'the site buys it itself (its Store Admin makes the PO)'), findsOneWidget);
    await reach(t, 'sa-wf-ho-grn', 'sa-wf');
    await tapIn(t, 'sa-wf-ho-grn', 'Yes');
    await settle(t, 300);
    expect(inK('sa-wf-grn', 'HO Purchase sees each bill (checked with its PO) and checks it'), findsOneWidget);
    await reach(t, 'sa-wf-save', 'sa-wf');
    await tapK(t, 'sa-wf-save');
    await net(t);
    expect(saves(srv).last, {'action': 'rulesSave', 'site': 'S1', 'ho': {'req': false, 'grn': true, 'iss': false}});
    expect(find.text('Saved – the Store of S1 is told.'), findsOneWidget);
    expect(srv.saHo['S1'], {'req': false, 'grn': true, 'iss': false});
    expect(await sel(), [false, true, false], reason: 'as saved (read again)');
    expect(srv.saAudit.first['action'], 'Workflow');
    await settle(t, 4200);
    // before the Portal's step 6: no Save – what to run said
    srv.portalStep6 = false;
    await tapK(t, 'sa-reload');
    await net(t);
    await t.drag(find.byKey(const Key('sa-wf')), const Offset(0, -2000));
    await settle(t, 400);
    expect(find.byKey(const Key('sa-wf-save')), findsNothing);
    expect(find.textContaining('The Head Office choices need the Portal\'s database step 6 first'), findsOneWidget);
  });

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
    // (3.76.0, Mechanical update-203) Day & tank check: the hour the day starts; a tank check every N days (Rental 7, one machinery 3)
    await tapK(t, 'sa-st-rules');
    await net(t);
    expect(saves(srv).last, {'action': 'siteRulesGet', 'site': 'S1'});
    expect(find.text('Now for 0 of 2 machinery · not for: 1 no Tank Capacity.'), findsOneWidget);
    await tapK(t, 'sr-g-Rental-on');
    await tapK(t, 'sr-add');
    await settle(t, 300);
    await tapK(t, 'sr-m-0-no');
    await settle(t, 800);
    await t.tap(find.text('MH-25-AJ-2169 · Tipper · Rental'));
    await settle(t, 800);
    await t.enterText(find.descendant(of: find.byKey(const Key('sr-m-0-days')), matching: find.byType(TextField)), '3');
    await tapK(t, 'sr-save');
    await net(t);
    expect(saves(srv).last, {
      'action': 'siteRulesSave', 'site': 'S1', 'dayStart': '06:00',
      'tank': {'groups': {'Own': '', 'Rental': '7', 'Hired': ''}, 'machines': [{'no': 'MH-25-AJ-2169', 'on': true, 'days': '3'}]},
    });
    expect(find.text('Day & tank check of S1 saved: the day starts at 06:00.'), findsOneWidget);
    expect(find.textContaining('On since 14-10-2026.'), findsOneWidget);
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
    await seen(t, find.byKey(const Key('ns-step-ready')));
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
    await tapK(t, 'sa-t-companies'); // (3.71.0: six tabs now – brought into view first)
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
    await tapK(t, 'sa-t-modules'); // (3.71.0: six tabs now – brought into view first)
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
    await tapK(t, 'sa-t-audit'); // (3.71.0: six tabs now – brought into view first)
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

  // (3.92.0 – Mechanical update-217, asked 09-11-2026: "user online asla ki bas zal call lawta yeil mgg to kuthe pn aso") a user of another site
  testWidgets('(3.92.0) Call: a user of another site ("Kiran Far (18B)") is on the list once he is at the app – and is called as any other', (t) async {
    phone(t);
    final kit = FakeKit();
    Session.callKit = () => kit;
    addTearDown(() => Session.callKit = null);
    final srv = FakeServer()..rtcPeople.add({'uid': 'u-kiran', 'name': 'Kiran Far (18B)', 'admin': false, 'far': true, 'site': '18B'});
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    final rtc = s.rtc!;
    var clock = DateTime(2026, 10, 14, 10, 30).millisecondsSinceEpoch;
    rtc.now = () => clock;
    await t.tap(find.byKey(const Key('home-menu')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('home-call')));
    await net(t);
    await settle(t, 1600);
    expect(rtc.users.firstWhere((u) => u.uid == 'u-kiran').far, true);
    expect(find.byKey(const Key('call-u-u-kiran')), findsNothing, reason: 'not at the app: not on the list');
    expect(find.byKey(const Key('call-u-u-office')), findsOneWidget, reason: 'his own site\'s people: as before');
    expect(find.text('Users of the other sites are shown here while they are at the app.'), findsOneWidget);
    rtc.inbox({'r': 41, 'top': 41, 'm': [rtcNote('h2', 'here', 'u-kiran', 'Kiran Far (18B)', '', {'busy': false, 'share': false, 'dev': 'dK'})]});
    clock += 3000;
    await settle(t, 1200);
    expect(find.byKey(const Key('call-u-u-kiran')), findsOneWidget);
    expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('call-st-u-kiran')), matching: find.byType(Text))).data, 'at the app now');
    await tapK(t, 'call-u-u-kiran');
    await settle(t, 300);
    expect(find.text('Call Kiran Far (18B)'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/55b_call_far.png'));
    await t.tap(find.byKey(const Key('call-go')));
    await net(t);
    expect(srv.rtcSent.lastWhere((m) => m['t'] == 'ring')['to'], ['u-kiran']);
    rtc.end(quiet: true);
    await settle(t, 600);
  }, tags: ['golden']);

  // (3.93.0, rcl-engineering "Engineering 2A", asked 09-11-2026: "aple app la banwayla chalu kr … enginnering modual") the app's own Engineering screens
  testWidgets('(3.93.0) Engineering: Home → Engineering – RFI (asked, the IE\'s answer), Hindrances (added), PPC; a User: no IE\'s answer, no PPC', (t) async {
    phone(t);
    final srv = FakeServer()..engSite = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await seen(t, find.text('Engineering'));
    await settle(t, 400);
    await t.tap(find.text('Engineering'));
    await net(t);
    expect(find.byKey(const Key('eng-home')), findsOneWidget);
    expect(find.textContaining('1 waiting for the IE'), findsOneWidget);
    expect(find.textContaining('1 still on'), findsOneWidget);
    expect(find.byKey(const Key('eng-ppc')), findsOneWidget, reason: 'the Admin: PPC');
    expect([for (final x in srv.engSent) x['fn'] ?? x['action']].take(4).toList(), ['sso', 'init', 'rfiList', 'hindList'], reason: 'its own sign-in (a ticket of the Portal), then the same actions as the web');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9t_eng_home.png'));
    // ---- RFI: the waiting ones, then all; one asked here; the IE's answer recorded
    await t.tap(find.byKey(const Key('eng-rfi')));
    await net(t);
    expect(find.byKey(const Key('erf-row-RFI-0002')), findsOneWidget);
    expect(find.byKey(const Key('erf-row-RFI-0001')), findsNothing, reason: 'Waiting only');
    await t.tap(find.byKey(const Key('erf-st-')));
    await net(t);
    expect(find.byKey(const Key('erf-row-RFI-0001')), findsOneWidget);
    expect(find.textContaining('IE: 11-10-2026 · Mr IE · RFI/18B/42'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9u_eng_rfi.png'));
    await t.tap(find.byKey(const Key('erf-new')));
    await net(t);
    expect(find.byKey(const Key('erf-form')), findsOneWidget);
    await t.tap(find.byKey(const Key('erf-save')));
    await net(t);
    expect(find.textContaining('give the chainage from and to'), findsOneWidget, reason: 'the server\'s refusal, said on the form');
    await t.enterText(find.descendant(of: find.byKey(const Key('erf-from')), matching: find.byType(TextField)), '40+400');
    await t.enterText(find.descendant(of: find.byKey(const Key('erf-to')), matching: find.byType(TextField)), '40+500');
    await t.enterText(find.descendant(of: find.byKey(const Key('erf-note')), matching: find.byType(TextField)), 'ready for the IE');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9v_eng_rfi_ask.png'));
    await t.tap(find.byKey(const Key('erf-save')));
    await net(t);
    final asked = srv.engSent.lastWhere((x) => x['action'] == 'rfiSave');
    expect([asked['day'], asked['work'], asked['layer'], asked['side'], asked['from'], asked['to'], asked['note']], ['2026-10-14', 'W-001', 'L1', 'LHS', '40+400', '40+500', 'ready for the IE']);
    expect(find.byKey(const Key('erf-row-RFI-0003')), findsOneWidget, reason: 'back on the list');
    await t.tap(find.byKey(const Key('erf-dec-RFI-0002')));
    await net(t);
    await t.enterText(find.descendant(of: find.byKey(const Key('erd-name')), matching: find.byType(TextField)), 'Mr IE');
    await t.tap(find.byKey(const Key('erd-save')));
    await net(t);
    final dec = srv.engSent.lastWhere((x) => x['action'] == 'rfiDecide');
    expect([dec['no'], dec['ver'], dec['status'], dec['ie_day'], dec['ie_name']], ['RFI-0002', 1, 'Approved', '2026-10-14', 'Mr IE']);
    expect(srv.engRfi.firstWhere((x) => x['no'] == 'RFI-0002')['status'], 'Approved');
    await t.pageBack();
    await net(t);
    // ---- Hindrances: the list; one added
    await t.tap(find.byKey(const Key('eng-hind')));
    await net(t);
    expect(find.byKey(const Key('ehd-row-H-0001')), findsOneWidget);
    expect(find.text('Land not handed over'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9w_eng_hindrances.png'));
    await t.tap(find.byKey(const Key('ehd-new')));
    await net(t);
    await t.enterText(find.descendant(of: find.byKey(const Key('ehd-kind')), matching: find.byType(TextField)), 'Utility shifting');
    await t.enterText(find.descendant(of: find.byKey(const Key('ehd-cf')), matching: find.byType(TextField)), '44+000');
    await t.enterText(find.descendant(of: find.byKey(const Key('ehd-ct')), matching: find.byType(TextField)), '44+200');
    await seen(t, find.byKey(const Key('ehd-w-W-002')));
    await t.tap(find.byKey(const Key('ehd-w-W-002')));
    await settle(t, 300);
    await seen(t, find.byKey(const Key('ehd-save')));
    await t.tap(find.byKey(const Key('ehd-save')));
    await net(t);
    final h = srv.engSent.lastWhere((x) => x['action'] == 'hindSave');
    expect([h['from_day'], h['to_day'], h['ch_from'], h['ch_to'], h['works'], h['kind']], ['2026-10-14', '', '44+000', '44+200', ['W-002'], 'Utility shifting']);
    expect(find.byKey(const Key('ehd-row-H-0002')), findsOneWidget);
    await t.pageBack();
    await net(t);
    // ---- PPC
    await t.tap(find.byKey(const Key('eng-ppc')));
    await net(t);
    expect(find.text('71%'), findsOneWidget);
    expect(find.textContaining('17 of 24 plan lines done as planned'), findsOneWidget);
    expect(find.text('Water tanker late · Engineer One'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9x_eng_ppc.png'));
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // ---- a User: no PPC; no "IE's answer"
    srv.engRole = 'user';
    await t.tap(find.text('Engineering'));
    await net(t);
    expect(find.byKey(const Key('eng-ppc')), findsNothing);
    await t.tap(find.byKey(const Key('eng-rfi')));
    await net(t);
    expect(find.byKey(const Key('erf-row-RFI-0003')), findsOneWidget);
    expect(find.byKey(const Key('erf-dec-RFI-0003')), findsNothing);
  }, tags: ['golden']);

  // (3.94.0, rcl-purchase "Purchase Phase 1", asked 09-11-2026: "ek sath enginnering modual purchase modual banwayla surwat kr") the app's own Purchase screens
  testWidgets('(3.94.0) Purchase: Inbox → enquiry (2 suppliers) → sent → a quotation; a CS approved from "Waiting for my approval"; a supplier added, one blocked; the CS limit (Super Admin); a User', (t) async {
    phone(t);
    final srv = FakeServer()..purSite = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    Future<void> openPurchase() async {
      await seen(t, find.text('Purchase'));
      await settle(t, 400);
      await t.tap(find.text('Purchase'));
      await net(t);
    }

    Future<void> card(String key) async {
      // (a long screen builds what is near the view only: scrolled to it first)
      if (find.byKey(Key(key)).evaluate().isEmpty) await t.scrollUntilVisible(find.byKey(Key(key)), 250, scrollable: find.byType(Scrollable).first);
      await seen(t, find.byKey(Key(key)));
      await settle(t, 300);
      await t.tap(find.byKey(Key(key)));
      await net(t);
    }

    Future<void> type(String key, String v) => t.enterText(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)), v);
    await openPurchase();
    expect(find.byKey(const Key('pur-inbox')), findsOneWidget);
    expect(find.byKey(const Key('pur-approve')), findsOneWidget, reason: 'a Purchase Admin: Waiting for my approval');
    expect(find.byKey(const Key('pur-settings')), findsNothing, reason: 'the CS limit: the Super Admin only');
    expect([for (final x in srv.purSent) x['fn'] ?? x['action']], ['sso'], reason: 'the cards ask nothing until opened');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9y_pur_home.png'));
    // ---- the Inbox: a line already in an enquiry cannot be ticked; two free lines (two sites) → a new enquiry with two suppliers
    await card('pur-inbox');
    expect(find.text('RFQ-0001 · Quotes in'), findsWidgets, reason: 'a line already in an enquiry: shown with it');
    await t.tap(find.byKey(const Key('pin-S1:7:1')));
    await settle(t, 300);
    expect(find.byKey(const Key('pin-make')), findsNothing, reason: 'the taken line is not ticked');
    await t.tap(find.byKey(const Key('pin-S1:7:2')));
    await settle(t, 300);
    await seen(t, find.byKey(const Key('pin-T2:3:1')));
    await t.tap(find.byKey(const Key('pin-T2:3:1')));
    await settle(t, 300);
    expect(find.text('2 lines ticked'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9z_pur_inbox.png'));
    await t.tap(find.byKey(const Key('pin-make')));
    await net(t);
    expect(find.byKey(const Key('prf-form')), findsOneWidget);
    expect(find.byKey(const Key('prf-v-3')), findsNothing, reason: 'a Blocked supplier is not asked');
    await card('prf-v-1');
    await card('prf-v-2');
    await card('prf-save');
    final made = srv.purSent.lastWhere((x) => x['action'] == 'rfqSave');
    expect(made['lines'], [{'site': 'S1', 'req_no': 7, 'req_line': 2, 'qty': '40'}, {'site': 'T2', 'req_no': 3, 'req_line': 1, 'qty': '4'}]);
    expect([made['date'], made['need_by'], made['vendors']], ['2026-10-14', '2026-10-18', [1, 2]], reason: 'the earliest need-by of its lines');
    expect(find.byKey(const Key('prv-view')), findsOneWidget, reason: 'the new enquiry opened');
    // ---- marked as sent; Asha's quotation typed as she gave it
    await card('prv-send');
    await t.tap(find.text('Mark as sent').last);
    await net(t);
    expect([srv.purRfqs.last['no'], srv.purRfqs.last['status']], [2, 'Sent']);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9za_pur_rfq.png'));
    await card('prv-q-1');
    expect(find.byKey(const Key('pqf-form')), findsOneWidget);
    await type('pqf-rate-1', '120');
    await type('pqf-gst-1', '18');
    await type('pqf-rate-2', '850');
    await type('pqf-disc-2', '5');
    await seen(t, find.byKey(const Key('pqf-fr')));
    await type('pqf-fr', '300');
    await settle(t, 300);
    await seen(t, find.byKey(const Key('pqf-sum')));
    expect(find.text('₹8,330.00 without GST'), findsOneWidget, reason: '40 × 120 + 4 × 850 less 5 % + freight 300');
    expect(find.text('GST beside: ₹864.00'), findsOneWidget);
    await card('pqf-save');
    final qs = srv.purSent.lastWhere((x) => x['action'] == 'quoteSave');
    expect([qs['rfq'], qs['vendor'], qs['freight'], (qs['lines'] as List).first, (qs['lines'] as List).last], [2, 1, '300', {'line': 1, 'rate': '120', 'disc': '', 'gst': '18', 'days': ''}, {'line': 2, 'rate': '850', 'disc': '5', 'gst': '', 'days': ''}]);
    expect(find.byKey(const Key('prv-view')), findsOneWidget, reason: 'back on the enquiry');
    expect(find.textContaining('Quotation entered'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // ---- Waiting for my approval → CS-0001 (Purchase One's, up to the limit): approved
    await card('pur-approve');
    expect(find.byKey(const Key('pap-row-1')), findsOneWidget);
    await card('pap-row-1');
    expect(find.byKey(const Key('pcs-view')), findsOneWidget);
    expect(find.textContaining('a Purchase Admin of S1'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('pcs-c-1-1'), skipOffstage: false), matching: find.text('L1', skipOffstage: false), skipOffstage: false), findsOneWidget, reason: 'L1 marked: line 1 – Asha');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9zb_pur_cs.png'));
    await card('pcs-ok');
    await t.tap(find.text('Approve').last);
    await net(t);
    final dec = srv.purSent.lastWhere((x) => x['action'] == 'csDecide');
    expect([dec['no'], dec['version'], dec['act']], [1, 2, 'approve']);
    expect(srv.purCs[1]!['status'], 'Approved');
    expect(find.byKey(const Key('pcs-ok')), findsNothing, reason: 'decided once');
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // ---- Suppliers: one added (his PAN from the GST no.), Asha blocked with a reason
    await card('pur-vendors');
    expect(find.byKey(const Key('pvn-row-3')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9zc_pur_suppliers.png'));
    await t.tap(find.byKey(const Key('pvn-new')));
    await net(t);
    await type('pvf-name', 'Deepak Cement');
    await type('pvf-gst', '27PQRST6789K1Z2');
    await type('pvf-phone', '9890011122');
    await type('pvf-sup', 'Cement, Sand');
    await card('pvf-save');
    final vs = srv.purSent.lastWhere((x) => x['action'] == 'vendorSave');
    expect([vs['name'], vs['gstin'], vs['pan'], vs['supplies']], ['Deepak Cement', '27PQRST6789K1Z2', 'PQRST6789K', 'Cement, Sand']);
    expect([srv.purVendors.length, find.byKey(const Key('pvf-form')).evaluate().isEmpty], [4, true], reason: 'saved; back on the list');
    await card('pvn-st-1');
    await t.enterText(find.byKey(const Key('note-box')), 'Wrong bills');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    final st = srv.purSent.lastWhere((x) => x['action'] == 'vendorStatus');
    expect([st['id'], st['ver'], st['status'], st['why']], [1, 1, 'Blocked', 'Wrong bills']);
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // ---- the Super Admin: the CS limit
    srv.purRole = 'super';
    await openPurchase();
    await card('pur-settings');
    expect(find.text('₹2,00,000.00'), findsOneWidget);
    await type('pse-lim', '250000');
    await card('pse-save');
    expect(srv.purSent.lastWhere((x) => x['action'] == 'settingsSave')['limit'], '250000');
    expect(find.text('₹2,50,000.00'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // ---- a Purchase User: no approval, no limit
    srv.purRole = 'user';
    await openPurchase();
    expect(find.byKey(const Key('pur-inbox')), findsOneWidget);
    expect(find.byKey(const Key('pur-approve')), findsNothing);
    expect(find.byKey(const Key('pur-settings')), findsNothing);
  }, tags: ['golden']);

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

  // (3.92.0, asked 09-11-2026: "iphone madhe finer nahi face login aste … face login haway") an iPhone with Face ID: its own words
  testWidgets('(3.92.0) The app lock on an iPhone with Face ID: "Use Face ID or the iPhone\'s passcode." and "Unlock with Face ID"', (t) async {
    phone(t);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final srv = FakeServer();
      final s = await ready(t, srv);
      final g = FakeGate()
        ..has = 'face'
        ..answers.add(const LockAnswer(LockOutcome.no));
      await t.pumpWidget(RclApp(session: s, lock: AppLock(g)));
      await net(t);
      expect(g.kinds, 1);
      expect(find.byKey(const Key('lock-screen')), findsOneWidget);
      expect(find.text("Use Face ID or the iPhone's passcode."), findsOneWidget);
      expect(find.text('Unlock with Face ID'), findsOneWidget);
      expect(find.byIcon(Icons.face_rounded), findsOneWidget);
      await pics(t);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/58b_lock_faceid.png'));
      await t.tap(find.byKey(const Key('lock-unlock')));
      await settle(t, 600);
      expect(find.byKey(const Key('lock-screen')), findsNothing);
      await t.pumpWidget(const SizedBox());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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

  // (3.62.1, urgent 29-10-2026: "tyach phone madhun keleli entry disat nahi") a half-filled entry of an EARLIER day brought back
  testWidgets('(3.62.1) a half-filled Diesel Issue kept on an earlier day comes back with TODAY\'s date (its old day no longer comes back unseen – the entries went to that day); one typed today keeps the date picked', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    final key = 'draft|S1|${s.email}|issue';
    await t.runAsync(() => s.api.keep.write(key, jsonEncode({'date': '2026-10-11', 'shift': 'Night', 'no': 'Sany 210 (No.1)', 'qty': '45', 'at': DateTime(2026, 10, 11, 18).toUtc().toIso8601String()})));
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-plus')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('plus-Diesel Issue')));
    await net(t);
    expect(find.byKey(const Key('draft-back')), findsOneWidget, reason: 'what he typed is brought back');
    expect(find.text('Sany 210 (No.1)'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('14-10-2026'), findsOneWidget, reason: 'today\'s date');
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('11-10-2026'), findsNothing, reason: 'not the day it was typed');
    await t.binding.handlePopRoute();
    await net(t);
    // typed today with an earlier date picked on purpose (the app closed by the camera): a user – today (update-187: he dates only
    // today); the Admin – that date comes back
    final draft = jsonEncode({'date': '2026-10-12', 'shift': 'Day', 'no': 'Sany 210 (No.1)', 'qty': '30', 'at': DateTime(2026, 10, 14, 9).toUtc().toIso8601String()});
    for (final adm in [false, true]) {
      s.admin = adm;
      await t.runAsync(() => s.api.keep.write(key, draft));
      await t.tap(find.byKey(const Key('tab-plus')));
      await settle(t, 600);
      await t.tap(find.byKey(const Key('plus-Diesel Issue')));
      await net(t);
      expect(find.byKey(const Key('draft-back')), findsOneWidget);
      expect(find.text('12-10-2026'), adm ? findsOneWidget : findsNothing, reason: adm ? 'the Admin: the day he picked' : 'a user: only today');
      expect(find.text('Today'), adm ? findsNothing : findsOneWidget);
      await t.binding.handlePopRoute();
      await net(t);
    }
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
    // (3.84.0) ≡ → Share app: the phone's share with the app's own page (the latest version; he installs it and signs in)
    final shared = <String>[], was = appShare;
    addTearDown(() => appShare = was);
    appShare = (text) async {
      shared.add(text);
      return true;
    };
    await t.tap(find.byKey(const Key('home-menu')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('menu-share')));
    await settle(t, 600);
    expect(shared.single, startsWith('RCL ERP app – https://oneclicksolution-erp.vercel.app/app\n'));
    expect(find.byKey(const Key('menu-share')), findsNothing, reason: 'the menu closed first');
    // a phone / computer that cannot share: the link copied, said
    appShare = (text) async => false;
    await t.tap(find.byKey(const Key('home-menu')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('menu-share')));
    await settle(t, 900);
    expect(find.text('The app\'s link is copied – paste it in WhatsApp or a message.'), findsOneWidget);
    gooClear();
    await settle(t, 100);
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
    await t.tap(find.byKey(const Key('tab-entries')));
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
    await t.tap(find.byKey(const Key('tab-reports')));
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
    await seen(t, find.byKey(const Key('att-gal')));
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
    await seen(t, find.byKey(const Key('att-tile-1')));
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

  /// (3.56.0) a car's Maintenance Log Book opened as the test of 3.46.0 does it (a site on fuel cards; Fuel Cards: the Entries tab)
  Future<FakeServer> mlogOpen(WidgetTester t, String perm, {bool admin = false}) async {
    phone(t);
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Maintenance': perm})
      ..card = true
      ..superAdmin = admin;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Maintenance');
    await net(t);
    await tapK(t, 'mt-car');
    await settle(t, 800);
    await t.tap(find.text('MH-12-HO-1163').last);
    await net(t);
    await reach(t, 'mt-log', 'mt-list');
    await tapK(t, 'mt-log');
    await net(t);
    return srv;
  }

  testWidgets('(3.56.0 – Mechanical update-180) the Maintenance Log Book with Maintenance View only: no Edit / Delete of a line', (t) async {
    await mlogOpen(t, 'View');
    expect(find.text('Maintenance Log Book – MH-12-HO-1163'), findsWidgets);
    expect(find.byKey(const Key('mlog-lines')), findsNothing);
    expect(find.byKey(const Key('mlog-delall')), findsNothing, reason: '(3.58.0) Delete this log book: the Admin / Super Admin only');
  });

  testWidgets('(3.58.0 – Mechanical update-182) "Delete this log book": not for a user with Maintenance Edit; the Admin / Super Admin – asked with its bills, ₹ and dates, the machinery number typed: a wrong one – nothing deleted; the right one (typed another way) – deleteMaintLog with the dates shown and the count; the log book shown again', (t) async {
    final srv = await mlogOpen(t, 'Edit', admin: true);
    await tapK(t, 'mlog-delall');
    await settle(t, 800);
    expect(find.text('Delete the log book of MH-12-HO-1163?'), findsOneWidget);
    expect((t.widget(find.byKey(const Key('mlog-delall-say'))) as dynamic).data,
        'All 1 maintenance bill(s) of MH-12-HO-1163 01-10-2026 to 14-10-2026 – ₹2,360.00 – are deleted. What the RCL Store issued and the fuel stay. Each bill is written in the Activity Log.');
    expect(find.text('This cannot be undone – press "Export to Excel" first to keep a copy.'), findsOneWidget);
    expect(find.text('Type MH-12-HO-1163 to confirm'), findsOneWidget);
    await t.enterText(find.byKey(const Key('note-box')), 'MH-12-HO-1164');
    await tapK(t, 'note-ok');
    await net(t);
    expect(find.textContaining('Not deleted – type the machinery number as it is (MH-12-HO-1163).'), findsOneWidget);
    expect(srv.maintCalls.where((x) => x['fn'] == 'deleteMaintLog'), isEmpty, reason: 'nothing sent');
    await settle(t, 4000);
    await tapK(t, 'mlog-delall');
    await settle(t, 800);
    await t.enterText(find.byKey(const Key('note-box')), 'mh 12 ho 1163');
    await tapK(t, 'note-ok');
    await net(t);
    expect(srv.maintCalls.lastWhere((x) => x['fn'] == 'deleteMaintLog'), {'fn': 'deleteMaintLog', 'x': {'no': 'MH-12-HO-1163', 'from': '2026-10-01', 'to': '2026-10-14', 'count': 1}});
    expect(find.textContaining('1 bill(s) of MH-12-HO-1163 deleted.'), findsOneWidget);
    expect(srv.maintCalls.where((x) => x['fn'] == 'maintLog').length, greaterThanOrEqualTo(2), reason: 'the log book read again');
    expect(find.byKey(const Key('mlog-delall')), findsNothing, reason: 'no maintenance bill left in it');
  });

  testWidgets('(3.56.0 – Mechanical update-180) the Maintenance Log Book of a machinery: each line of a bill on its own – Edit (its box, its ₹ from Qty × Rate) and Delete, the rest of the bill as it is; changed meanwhile: said in the box; the only line: the whole bill (said first)', (t) async {
    final srv = await mlogOpen(t, 'Edit');
    expect(find.byKey(const Key('mlog-delall')), findsNothing, reason: '(3.58.0) Delete this log book: not for a user (not the Admin)');
    await tapK(t, 'mlog-lines');
    await net(t);
    expect(find.text('Edit / delete a line – MH-12-HO-1163'), findsOneWidget);
    expect([for (var i = 0; i < 5; i++) find.byKey(Key('ml-e-MT-000001-$i')).evaluate().length], [1, 1, 1, 1, 0], reason: 'each line of the bill (its 4) its Edit; the fills are not bills');
    expect(find.byKey(const Key('ml-d-MT-000001-0')), findsOneWidget);
    // Edit of the oil filter: its box; Qty 2 × Rate 175 → its ₹ 350; saved – only that line
    await tapK(t, 'ml-e-MT-000001-1');
    await net(t);
    expect(find.text('Change this line – MH-12-HO-1163'), findsOneWidget);
    expect(find.text('Bill MT-000001 · 05-10-2026 · Toyota Service · bill no. TS-101 – line 2 of 4. The other lines of the bill stay as they are.'), findsOneWidget);
    expect([for (final k in ['mlf-w', 'mlf-q', 'mlf-r', 'mlf-a', 'mlf-g']) (t.widget(find.byKey(Key(k))) as TextBox).controller.text], ['Oil filter', '', '', '300', '']);
    await t.enterText(find.byKey(const Key('mlf-q')), '2');
    await t.enterText(find.byKey(const Key('mlf-r')), '175');
    await t.enterText(find.byKey(const Key('mlf-g')), '18');
    await settle(t, 400);
    expect((t.widget(find.byKey(const Key('mlf-a'))) as TextBox).controller.text, '350', reason: 'Qty × Rate');
    expect((t.widget(find.byKey(const Key('mlf-sum'))) as dynamic).data, 'GST ₹63.00 · Amount with GST ₹413.00');
    await tapK(t, 'mlf-save');
    await net(t);
    expect(srv.maintCalls.lastWhere((x) => x['fn'] == 'updateMaintLine'), {
      'fn': 'updateMaintLine', 'id': 'MT-000001',
      'x': {'i': 1, 'date': '2026-10-05', 'was': {'work': 'Oil filter', 'amount': 300}, 'line': {'work': 'Oil filter', 'type': 'Paid', 'qty': 2, 'uom': '', 'rate': 175, 'disc': '', 'amount': 350, 'gst': 18, 'gstAmt': ''}},
    });
    expect(find.byKey(const Key('mlf-save')), findsNothing, reason: 'back on the lines');
    expect(find.text('2 × 175 · GST 18 % · RCL'), findsOneWidget, reason: 'the log book read again');
    expect(srv.mlogLines.map((l) => '${l['work']}:${l['amount']}').toList(), ['Engine oil:1200', 'Oil filter:350', 'Labour:500', 'GST 18%:360']);
    // a line changed by someone else meanwhile: said in the box, nothing saved
    srv.mlogLines[0]['amount'] = 1250;
    await tapK(t, 'ml-e-MT-000001-0');
    await net(t);
    await tapK(t, 'mlf-save');
    await net(t);
    expect(find.textContaining('Bill MT-000001 was changed meanwhile – show the log book again, then change its line.'), findsOneWidget);
    expect(find.byKey(const Key('mlf-save')), findsOneWidget, reason: 'the box stays');
    await t.pageBack();
    await net(t);
    // a line deleted (asked first)
    await tapK(t, 'ml-d-MT-000001-2');
    await settle(t, 800);
    expect(find.text('Delete this line?'), findsOneWidget);
    expect(find.textContaining('Labour – ₹ 500'), findsOneWidget);
    await t.tap(find.text('Delete').last);
    await net(t);
    expect(srv.maintCalls.lastWhere((x) => x['fn'] == 'deleteMaintLine'), {'fn': 'deleteMaintLine', 'id': 'MT-000001', 'x': {'i': 2, 'date': '2026-10-05', 'was': {'work': 'Labour', 'amount': 500}}});
    expect([for (var i = 0; i < 4; i++) find.byKey(Key('ml-e-MT-000001-$i')).evaluate().length], [1, 1, 1, 0], reason: 'the other lines as they were');
    // the only line of a bill: the whole bill (said first)
    srv.mlogLines.removeRange(1, srv.mlogLines.length);
    await t.pageBack();
    await net(t);
    await tapK(t, 'mlog-lines');
    await net(t);
    await tapK(t, 'ml-d-MT-000001-0');
    await settle(t, 800);
    expect(find.text('Delete bill MT-000001?'), findsOneWidget);
    expect(find.textContaining('"Engine oil" is the only line of this bill – the whole bill is deleted.'), findsOneWidget);
    await t.tap(find.text('Delete the bill'));
    await net(t);
    expect(srv.maintCalls.where((x) => x['fn'] == 'deleteMaint').map((x) => x['id']).toList(), ['MT-000001']);
    expect(srv.maintCalls.where((x) => x['fn'] == 'deleteMaintLine').length, 1, reason: 'not a line: the bill');
  });


  // ---------------- (3.59.0 – Mechanical update-183 / update-184) ----------------
  /// (3.59.0) the Maintenance screen at a site on fuel cards (as the 3.51.0 test)
  Future<FakeServer> mtOpen59(WidgetTester t, FakeServer srv) async {
    phone(t);
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await tapK(t, 'entries-Maintenance');
    await net(t);
    return srv;
  }

  testWidgets('(3.59.0 – Mechanical update-183, "old import tyat tr ajibat karu nko as it is rahude") a bill of the old log book keeps each line\'s GST ₹ as in the file: the list, the bill, its form ("GST ₹ as in the old log book") – saved with it (gstAmt); a GST % typed takes its place', (t) async {
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Maintenance': 'Edit'})
      ..card = true;
    srv.maint.insert(0, {'id': 'MT-000003', 'date': '2026-10-13', 'no': 'MH-12-HO-1163', 'garage': 'Store', 'billNo': '', 'km': 500, 'total': 1561.4, 'billTotal': 1561.4, 'service': false, 'remark': '', 'enteredBy': 'Sujit Mule', 'updatedBy': '',
      'lines': [{'work': 'AD BLUE', 'type': 'Paid', 'qty': 20, 'uom': 'Ltr', 'rate': 59, 'amount': 1180, 'gstAmt': 212.4}, {'work': 'BULB', 'type': 'Paid', 'qty': 4, 'uom': 'Nos', 'rate': 40, 'amount': 160, 'gstAmt': 9}], 'files': []});
    await mtOpen59(t, srv);
    String txt(String k) => '${(t.widget(find.byKey(Key(k))) as dynamic).data}';
    await reach(t, 'mt-r-MT-000003', 'mt-list');
    expect(find.descendant(of: find.byKey(const Key('mt-r-MT-000003')), matching: find.textContaining('AD BLUE ₹1,392.4; BULB ₹169')), findsOneWidget, reason: 'each line with its GST ₹ as in the file');
    await tapK(t, 'mt-r-MT-000003');
    await settle(t, 800);
    expect(find.text('₹ 1,392.4 · 20 Ltr × 59 · GST ₹212.4 · RCL'), findsOneWidget, reason: 'no GST % made from it');
    await tapK(t, 'mt-edit');
    await net(t);
    expect([find.byKey(const Key('mf-ga-0')).evaluate().length, find.byKey(const Key('mf-ga-1')).evaluate().length], [1, 1]);
    expect([txt('mf-gv-0'), txt('mf-gv-1'), txt('mf-total')], ['GST ₹212.4 · With GST ₹1,392.4', 'GST ₹9 · With GST ₹169', '₹ 1,561.4']);
    await seen(t, find.byKey(const Key('mf-save')));
    await tapK(t, 'mf-save');
    await net(t);
    var x = srv.maintCalls.lastWhere((c) => c['fn'] == 'updateMaint')['x'] as Map;
    expect(x['lines'], [
      {'work': 'AD BLUE', 'type': 'Paid', 'qty': 20, 'uom': 'Ltr', 'rate': 59, 'disc': '', 'amount': 1180, 'gst': '', 'gstAmt': 212.4},
      {'work': 'BULB', 'type': 'Paid', 'qty': 4, 'uom': 'Nos', 'rate': 40, 'disc': '', 'amount': 160, 'gst': '', 'gstAmt': 9},
    ], reason: 'each line keeps its GST ₹ (the server refuses a change that does not send it)');
    // a GST % typed on BULB: its GST from the % – no more the GST ₹ of the old log book
    await reach(t, 'mt-r-MT-000003', 'mt-list');
    await tapK(t, 'mt-r-MT-000003');
    await settle(t, 800);
    await tapK(t, 'mt-edit');
    await net(t);
    await seen(t, find.byKey(const Key('mf-g-1')));
    await t.enterText(find.byKey(const Key('mf-g-1')), '18');
    await settle(t, 400);
    expect(find.byKey(const Key('mf-ga-1')), findsNothing);
    expect([txt('mf-gv-1'), txt('mf-total')], ['GST ₹28.8 · With GST ₹188.8', '₹ 1,581.2']);
    await seen(t, find.byKey(const Key('mf-save')));
    await tapK(t, 'mf-save');
    await net(t);
    x = srv.maintCalls.lastWhere((c) => c['fn'] == 'updateMaint')['x'] as Map;
    expect([for (final l in x['lines'] as List) '${l['work']}:${l['gst']}:${l['gstAmt']}'], ['AD BLUE::212.4', 'BULB:18:']);
  });

  testWidgets('(3.59.0 – Mechanical update-183) the Maintenance Log Book of the old log book: "GST Amount" – no CGST / SGST % for it; a line\'s Edit: "GST ₹ (as in the old log book)" kept, changed only by typing it, a GST % takes its place; "Hide log book"', (t) async {
    final srv = FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Maintenance': 'Edit'})
      ..card = true;
    srv.mlogLines
      ..clear()
      ..addAll([
        {'work': 'AD BLUE', 'qty': 20, 'uom': 'Ltr', 'rate': 59, 'amount': 1180, 'gstAmt': 212.4},
        {'work': 'BULB', 'qty': 4, 'uom': 'Nos', 'rate': 40, 'amount': 160, 'gstAmt': 9},
      ]);
    await mtOpen59(t, srv);
    String txt(String k) => '${(t.widget(find.byKey(Key(k))) as dynamic).data}';
    await tapK(t, 'mt-car');
    await settle(t, 800);
    await t.tap(find.text('MH-12-HO-1163').last);
    await net(t);
    await reach(t, 'mt-log', 'mt-list');
    await tapK(t, 'mt-log');
    await net(t);
    expect(find.text('GST Amount'), findsWidgets, reason: 'the GST ₹ of each line in "GST Amount"');
    expect(find.textContaining('CGST'), findsNothing, reason: 'no GST % made – no rate column for it');
    for (final w in ['212.40', '1,392.40', '9.00', '169.00', '221.40', '1,561.40']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
    await tapK(t, 'mlog-lines');
    await net(t);
    expect(find.text('20 Ltr × 59 · GST ₹212.4 · RCL'), findsOneWidget);
    await tapK(t, 'ml-e-MT-000001-0');
    await net(t);
    expect((t.widget(find.byKey(const Key('mlf-ga'))) as TextBox).controller.text, '212.4');
    expect(txt('mlf-sum'), 'GST ₹212.40 · Amount with GST ₹1,392.40');
    await t.enterText(find.byKey(const Key('mlf-ga')), '213');
    await settle(t, 400);
    expect(txt('mlf-sum'), 'GST ₹213.00 · Amount with GST ₹1,393.00');
    await tapK(t, 'mlf-save');
    await net(t);
    expect((srv.maintCalls.lastWhere((x) => x['fn'] == 'updateMaintLine')['x'] as Map)['line'], {'work': 'AD BLUE', 'type': 'Paid', 'qty': 20, 'uom': 'Ltr', 'rate': 59, 'disc': '', 'amount': 1180, 'gst': '', 'gstAmt': 213});
    expect(find.text('20 Ltr × 59 · GST ₹213 · RCL'), findsOneWidget, reason: 'the log book read again');
    // BULB: a GST % typed – its GST ₹ box off, the GST from the %
    await tapK(t, 'ml-e-MT-000001-1');
    await net(t);
    await t.enterText(find.byKey(const Key('mlf-g')), '18');
    await settle(t, 400);
    expect((t.widget(find.byKey(const Key('mlf-ga'))) as TextBox).enabled, false);
    expect(txt('mlf-sum'), 'GST ₹28.80 · Amount with GST ₹188.80');
    await tapK(t, 'mlf-save');
    await net(t);
    expect((srv.maintCalls.lastWhere((x) => x['fn'] == 'updateMaintLine')['x'] as Map)['line'], {'work': 'BULB', 'type': 'Paid', 'qty': 4, 'uom': 'Nos', 'rate': 40, 'disc': '', 'amount': 160, 'gst': 18, 'gstAmt': ''});
    expect(find.text('4 Nos × 40 · GST 18 % · RCL'), findsOneWidget);
    await t.pageBack();
    await net(t);
    // "Hide log book": the log book shown hidden again – the filters to show it again
    await tapK(t, 'mlog-hide');
    await settle(t, 600);
    expect(find.byKey(const Key('mlog-hide')), findsNothing);
    expect(find.text('GST Amount'), findsNothing);
    expect(find.byKey(const Key('rep-go')), findsOneWidget);
  });

  testWidgets('(3.59.0 – Mechanical update-183, "kadhi kadhi ai service slow asa pn error ywto te pn fix krun de") a PDF page read in parts (25 rows, then after the last row given); the AI busy – asked again by itself (the quicker model, after 8 s and 20 s); still busy: stopped – "Continue reading (from page 2)" goes on there, the pages before kept; the names asked again by itself', (t) async {
    final srv = await mliOpen(t);
    final p0 = pickAttFiles;
    addTearDown(() => pickAttFiles = p0);
    pickAttFiles = (how, room) async => [(name: 'Old log book.pdf', bytes: Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF\n')))];
    final web = jsonDecode(File('test/fixtures/sheets/maint_logbook.json').readAsStringSync()) as Map<String, dynamic>, tb = web['aiTables'] as List;
    final last = ((tb[0] as Map)['rows'] as List).last;
    srv
      ..mliNames = {'fixes': []}
      ..mliNamesBusy = 1
      ..mliPages.addAll([
        {'pages': 2, 'tables': [tb[0]], 'more': true, 'last': last},
        {'pages': 2, 'tables': [tb[1]]},
        'busy', 'busy', 'busy', 'busy',
      ]);
    String txt(String k) => '${(t.widget(find.byKey(Key(k))) as dynamic).data}';
    await mliChoose(t, 'pdf');
    await net(t);
    expect(txt('mli-reading'), 'The AI service is slow – page 2 asked again in 8 s…');
    await settle(t, 8500);
    await net(t);
    expect(txt('mli-reading'), 'The AI service is slow – page 2 asked again in 20 s…');
    await settle(t, 20500);
    await net(t);
    final rc = srv.maintCalls.where((x) => x['fn'] == 'readMaintLog').toList();
    expect([for (final x in rc) '${x['from']}/${x['max']}/${x['fast']}/${x['after'] != null}'], ['1/25/0/false', '1/25/0/true', '2/25/0/false', '2/25/1/false', '2/25/1/false', '2/25/1/false'],
        reason: 'page 1 in two parts (the second after the last row given); page 2 busy: asked again of the quicker model, then after 8 s and 20 s');
    expect(rc[1]['after'], last);
    expect(txt('mli-read-err'), 'The AI service is busy now – the log book – try again in a minute. – the pages before page 2 are read and kept: press "Continue reading" to go on from page 2.');
    expect(find.text('Continue reading (from page 2)'), findsOneWidget);
    expect(find.byKey(const Key('mli-retry')), findsNothing);
    expect(srv.maintCalls.where((x) => x['fn'] == 'maintImportNames'), isEmpty, reason: 'not read yet – no names asked');
    // "Continue reading": page 2 now – the pages before kept; the names: too slow once – asked again by itself (the quicker model)
    srv.mliPages.add({'pages': 2, 'tables': [tb[2]]});
    await tapK(t, 'mli-more');
    await net(t);
    expect(srv.maintCalls.where((x) => x['fn'] == 'readMaintLog').skip(6).map((x) => '${x['from']}').toList(), ['2'], reason: 'from page 2 – page 1 not asked again');
    await settle(t, 6500);
    await net(t);
    final nq = srv.maintCalls.where((x) => x['fn'] == 'maintImportNames').toList();
    expect([nq.length, (nq.last['x'] as Map)['fast']], [2, true]);
    expect(find.text('Old log book.pdf – 2 sheet(s)'), findsOneWidget, reason: 'the roller (page 1, two parts) and the car (page 2)');
    await mliSee(t, 'mlf-state');
    expect(txt('mlf-state'), '✓ The AI found no name written in more than one way.');
  });

  testWidgets('(3.59.0 – Mechanical update-183, "konte vichle / asset ch maintanace log book add aahe kadhi prynt updeted aahe konte ch baki aahe") Log book status: every Own machinery – not added yet first, the others up to their last bill (a rented one without bills not listed); Show: Not added yet / Added; a machinery opens its log book Start to end', (t) async {
    final srv = await mtOpen59(t, FakeServer()
      ..perms.addAll({'Fuel Cards': 'Edit', 'Maintenance': 'Edit'})
      ..card = true);
    await reach(t, 'mt-status', 'mt-list');
    await tapK(t, 'mt-status');
    await net(t);
    String txt(String k) => '${(t.widget(find.byKey(Key(k))) as dynamic).data}';
    expect(srv.maintCalls.last, {'fn': 'maintStatus'});
    expect(txt('mst-sum'), '2 added · 3 not added yet (Own machinery of the Asset Master)');
    expect([txt('mst-st-MH-12-HO-3163'), txt('mst-st-MH-12-HO-1163'), txt('mst-st-MH-12-HO-2163')], ['Not added yet', '✓ Up to 05-10-2026', '✓ Up to 12-10-2026']);
    expect(find.byKey(const Key('mst-MH-25-AJ-2169')), findsNothing, reason: 'rented, no bill');
    expect(t.getTopLeft(find.byKey(const Key('mst-MH-12-HO-3163'))).dy < t.getTopLeft(find.byKey(const Key('mst-MH-12-HO-1163'))).dy, true, reason: 'not added yet first');
    expect(find.textContaining('(not on the site now)'), findsOneWidget, reason: 'OLD-9');
    await tapK(t, 'mst-f-none');
    await settle(t, 400);
    expect([find.byKey(const Key('mst-MH-12-HO-3163')).evaluate().length, find.byKey(const Key('mst-MH-12-HO-1163')).evaluate().length], [1, 0]);
    await tapK(t, 'mst-f-added');
    await settle(t, 400);
    expect([find.byKey(const Key('mst-MH-12-HO-3163')).evaluate().length, find.byKey(const Key('mst-MH-12-HO-2163')).evaluate().length], [0, 1]);
    await tapK(t, 'mst-MH-12-HO-2163');
    await net(t);
    final f = srv.maintCalls.lastWhere((x) => x['fn'] == 'maintLog')['x'] as Map;
    expect([f['no'], f['all']], ['MH-12-HO-2163', true], reason: 'its log book Start to end');
    expect(find.text('Maintenance Log Book – MH-12-HO-2163'), findsWidgets);
  });

  testWidgets('(3.59.0 – Mechanical update-184) Vendor Master: the Company Name and its Owner Name; a site without step 1zj – said what to run, the vendor saved as before; with it – each kind its documents (a PDF) sent with vendorDoc and saved with the vendor; the list: Documents (1) – opened, printed, downloaded', (t) async {
    phone(t);
    final p0 = pickAttFiles, c0 = attCompute;
    attCompute = <M, R>(ComputeCallback<M, R> cb, M m, {String? debugLabel}) async => await cb(m);
    addTearDown(() {
      pickAttFiles = p0;
      attCompute = c0;
    });
    final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'));
    pickAttFiles = (how, room) async => [(name: 'pan card.pdf', bytes: pdf)];
    final srv = editor();
    final s = await ready(t, srv);
    await openMaster(t, s, 'Vendor Master');
    expect(srv.calls.contains('mech:getBoqs'), true, reason: 'whether the site keeps the Owner Name and the documents (vdocsOn)');
    // step 1zj not run: "Company Name", no Owner Name, the documents say what to run (no Add); the vendor saved as before
    await t.tap(find.byKey(const Key('v-new')));
    await net(t);
    expect(find.text('Company Name *'), findsOneWidget);
    expect(find.byKey(const Key('vf-owner')), findsNothing);
    await seen(t, find.byKey(const Key('vf-docs-note')));
    expect(find.textContaining('sql/supabase_step1zj_vendor_papers.sql'), findsOneWidget);
    expect([find.byKey(const Key('vfd-PAN')).evaluate().length, find.byKey(const Key('vfd-a-PAN')).evaluate().length], [1, 0]);
    await t.enterText(box('vf-name'), 'Before 1zj Traders');
    await settle(t, 600);      // (the box's "show the caret" scroll done first)
    await tapK(t, 'vf-save');
    await net(t);
    var v = srv.masterCalls.lastWhere((c) => c['fn'] == 'saveVendor')['v'] as Map;
    expect([v['name'], v.containsKey('owner'), v.containsKey('docs')], ['Before 1zj Traders', false, false]);
    // step 1zj run: the Owner Name; the PAN added (a PDF) – sent first (vendorDoc), saved with the vendor with its kind
    srv.vdocsOn = true;
    await t.pageBack();      // (the Vendor Master opened again: it asks again whether the site keeps them)
    await net(t);
    await t.tap(find.byKey(const Key('mp-Vendor Master')));
    await net(t);
    await t.tap(find.byKey(const Key('v-new')));
    await net(t);
    await t.enterText(box('vf-name'), 'Test Earthmovers');
    await t.enterText(box('vf-owner'), 'Ramesh Patil');
    await settle(t, 600);
    await tapK(t, 'vfd-a-PAN');
    await net(t);
    await tapK(t, 'att-pdf');
    await net(t);
    expect(find.text('pan card.pdf'), findsOneWidget);
    await tapK(t, 'vfk-done');
    await settle(t, 800);
    expect('${(t.widget(find.byKey(const Key('vfd-n-PAN'))) as dynamic).data}', '1 file(s)');
    expect('${(t.widget(find.byKey(const Key('vfd-n-Aadhaar'))) as dynamic).data}', 'none');
    await tapK(t, 'vf-save');
    await net(t);
    final up = srv.masterCalls.indexWhere((c) => c['fn'] == 'vendorDoc'), sv = srv.masterCalls.lastIndexWhere((c) => c['fn'] == 'saveVendor');
    expect([srv.masterCalls[up]['name'], up < sv], ['pan card.pdf', true], reason: 'the document sent first, then the vendor');
    v = srv.masterCalls[sv]['v'] as Map;
    expect([v['name'], v['owner'], (v['docs'] as List).length, (v['docs'] as List).single['kind'], '${(v['docs'] as List).single['sha']}'.length], ['Test Earthmovers', 'Ramesh Patil', 1, 'PAN', 64]);
    // the list: Documents (1) – its window: the Owner Name, PAN; Download – the file itself
    await t.enterText(find.byKey(const Key('v-search')), 'Test Earth');
    await settle(t, 600);
    expect(find.text('Documents (1)'), findsOneWidget);
    await tapK(t, 'vdocs-Test Earthmovers');
    await net(t);
    expect(srv.masterCalls.last, {'fn': 'getVendorDocs', 'name': 'Test Earthmovers'});
    expect(find.text('Documents – Test Earthmovers'), findsOneWidget);
    expect(find.text('Ramesh Patil'), findsOneWidget);
    expect(find.text('pan card.pdf'), findsOneWidget);
    final sha = '${(v['docs'] as List).single['sha']}';
    expect([for (final w in ['open', 'print', 'download']) find.byKey(Key('vdv-$w-$sha')).evaluate().length], [1, 1, 1]);
    final files = catchFiles();
    await tapK(t, 'vdv-download-$sha');
    await net(t);
    expect(srv.fileGets, ['https://files.test/$sha']);
    expect([files.single.$1, files.single.$2], ['pan card.pdf', pdf]);
  });

  testWidgets('(3.59.0 – Mechanical update-184, "papers fkt own mhanje rachana che") Vehicle Compliance: only Own machinery – no ownership choice; the import says which machinery were left out (not Own)', (t) async {
    phone(t);
    final srv = editor()..cmpSkipped = ['MH-04-J-9844', 'JCB-173'];
    final s = await ready(t, srv);
    await openMaster(t, s, 'Vehicle Compliance');
    expect(find.byKey(const Key('cp-own')), findsNothing);
    expect(find.textContaining('of every active Own machinery.'), findsOneWidget);
    pickThis('papers.csv', utf8.encode('Machinery No,Type,PUC Valid Upto,Permit,Status (not imported)\nMH-25-AJ-2169,Tipper,30-09-2027,NA,Expired\n,,,,\n'));
    await t.tap(find.byKey(const Key('cp-menu')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('cp-import')));
    await net(t);
    expect(find.text('• 2 machinery left out – not Own (papers are kept only for Own machinery): MH-04-J-9844, JCB-173'), findsOneWidget);
  });

  testWidgets('(3.59.0 – Mechanical update-185) Ask: a look-up the app does not run itself (maintenance bills …) goes to the server (aiLookup) and its answer back to the AI; a refusal goes back as its error; "Looked up" says what, with the machinery / vendor', (t) async {
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
    await tapK(t, 'home-ask');
    await net(t);
    srv.aiScript.addAll([
      {'parts': [{'functionCall': {'name': 'maintenance_bills', 'args': {'from': '2026-10-01', 'to': '2026-10-14', 'machinery': 'MH-12-HO-1163'}}}, {'functionCall': {'name': 'vendor_ledger', 'args': {'vendor': 'Nobody Traders'}}}], 'model': 'claude-sonnet-5-5'},
      {'parts': [{'text': 'One maintenance bill this month: **₹2,360**.'}], 'model': 'claude-sonnet-5-5'},
    ]);
    await t.enterText(find.byKey(const Key('ai-in')), 'maintenance of MH-12-HO-1163 this month and the ledger of Nobody Traders');
    await tapK(t, 'ai-send');
    await net(t);
    await net(t);
    expect(srv.aiLookups, [
      {'name': 'maintenance_bills', 'args': {'from': '2026-10-01', 'to': '2026-10-14', 'machinery': 'MH-12-HO-1163'}},
      {'name': 'vendor_ledger', 'args': {'vendor': 'Nobody Traders'}},
    ]);
    final back = (srv.aiAsked.last['contents'] as List).last as Map;
    final rs = [for (final p in back['parts'] as List) (p as Map)['functionResponse'] as Map];
    expect([rs[0]['name'], rs[0]['response'], rs[1]['name'], rs[1]['response']],
        ['maintenance_bills', srv.aiLookupAnswers['maintenance_bills'], 'vendor_ledger', {'error': '"Nobody Traders" is not a vendor of this site – say which one.'}]);
    expect(find.text('Looked up:'), findsOneWidget);
    expect(find.text('Maintenance bills 01-10-2026 to 14-10-2026 · MH-12-HO-1163'), findsOneWidget);
    expect(find.text('Vendor Ledger · Nobody Traders'), findsOneWidget);
    expect(find.textContaining('One maintenance bill this month: ₹2,360.'), findsOneWidget);
  });

  testWidgets('(3.59.0 – Mechanical update-185) Ask: a look-up of the Store (store_…) is asked of the Store itself (api/work aiLook) and one of Engineering (eng_…) of Engineering (api/eng aiLook – its sign-in by a Portal ticket, again once when it ended); no Engineering for him at this site: said so', (t) async {
    phone(t);
    forgetChat();
    final srv = FakeServer()
      ..superAdmin = true
      ..aiOn = true
      ..engSite = true
      ..engEnded = true;
    srv.prefs['brief'] = false;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await net(t);
    await tapK(t, 'home-ask');
    await net(t);
    srv.aiScript.addAll([
      {'parts': [{'functionCall': {'name': 'store_stock', 'args': {'item': 'oil'}}}, {'functionCall': {'name': 'eng_dashboard', 'args': {'date': '2026-10-13'}}}], 'model': 'claude-sonnet-5-5'},
      {'parts': [{'text': 'Engine oil: **120 Ltr** in the Store; PQC 83 % done.'}], 'model': 'claude-sonnet-5-5'},
    ]);
    await t.enterText(find.byKey(const Key('ai-in')), 'engine oil in the store and the PQC yesterday');
    await tapK(t, 'ai-send');
    await net(t);
    await net(t);
    expect(srv.storeWork.where((b) => b['action'] == 'aiLook').toList(), [{'action': 'aiLook', 'name': 'store_stock', 'args': {'item': 'oil'}}]);
    expect([for (final e in srv.engSent) e['fn'] ?? e['action']], ['sso', 'aiLook', 'sso', 'aiLook'], reason: 'its sign-in ended: a new one once, then asked again');
    expect(srv.engSent.last['name'], 'eng_dashboard');
    expect(srv.calls.where((c) => c == 'portal:go:engineering:S1').length, 2, reason: 'a Portal ticket for Engineering each time');
    final back = (srv.aiAsked.last['contents'] as List).last as Map;
    final rs = [for (final p in back['parts'] as List) (p as Map)['functionResponse'] as Map];
    expect([rs[0]['name'], rs[0]['response'], rs[1]['name'], (rs[1]['response'] as Map)['works']],
        ['store_stock', {'asOf': '14-10-2026 10:30', 'items': [{'code': 'ITM-0001', 'name': 'Engine Oil 15W40', 'unit': 'Ltr', 'stock': 120}], 'page': 'store'}, 'eng_dashboard', [{'name': 'PQC', 'unit': 'm', 'planned': 120, 'done': 100, 'pct': 83}]]);
    expect((rs[1]['response'] as Map).containsKey('ok'), false);
    expect(find.text('Store – stock'), findsOneWidget);
    expect(find.text('Engineering – dashboard 13-10-2026'), findsOneWidget);
    // no Engineering for him at this site: said so (nothing asked of Engineering) – what the AI is sent back as its error
    srv.engSite = false;
    final n = srv.engSent.length;
    final s2 = await ready(t, srv);
    Object? err;
    await t.runAsync(() async {
      try {
        await moduleLook(s2, 'engineering', 'eng_progress', const {});
      } catch (e) {
        err = e;
      }
    });
    expect('$err', 'You have no access to Engineering at this site – the Super Admin gives it in the Portal.');
    expect(srv.engSent.length, n);
  });

  /* (3.61.0 – Mechanical update-186) THE ASSISTANT LIVE: the answer word by word (api/ai), said while it is written in a talk; its own
   * memory and his chats (History, Memory) – only his, only this site. */
  FakeServer liveSrv() {
    final srv = FakeServer()
      ..superAdmin = true
      ..aiOn = true
      ..aiStream = true;
    srv.prefs['brief'] = false;
    srv.aiLookupAnswers['remember'] = {'remembered': true, 'id': 3, 'note': 'He wants the answers short.'};
    srv.aiMemory.addAll([
      {'id': 2, 'note': 'He calls the Dispenser "the pump".', 'at': '2026-10-13T06:00:00Z'},
      {'id': 3, 'note': 'He wants the answers short.', 'at': '2026-10-14T05:00:00Z'},
    ]);
    srv.aiChats['Cmgold00abc123'] = {
      'id': 'Cmgold00abc123', 'title': 'diesel of yesterday', 'n': 1, 'at': '2026-10-13T09:00:00Z',
      'msgs': [{'r': 'me', 't': 'diesel of yesterday'}, {'r': 'src', 't': 'Looked up: · Diesel issues 13-10-2026'}, {'r': 'bot', 't': '180 L yesterday.'}],
    };
    return srv;
  }

  Future<void> askLive(WidgetTester t, FakeServer srv) async {
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await net(t);
    await tapK(t, 'home-ask');
    await net(t);
    srv.aiScript.addAll([
      {'parts': [{'functionCall': {'name': 'remember', 'args': {'note': 'He wants the answers short.'}}}], 'model': 'claude-sonnet-5-5'},
      {'parts': [{'text': 'Noted – I will keep my answers **short**.'}], 'model': 'claude-sonnet-5-5'},
    ]);
    await t.enterText(find.byKey(const Key('ai-in')), 'remember that I want the answers short');
    await tapK(t, 'ai-send');
    await net(t);
    await net(t);
  }

  testWidgets('(3.61.0 – Mechanical update-186) Ask word by word (api/ai): every step asked there, not in one piece, no "Thinking…", the Admin\'s "first words"; "remember …" – Memory – kept, the note shown with "Take it out"; the chat kept after the answer (aiChatSave); History – newest first, one opened again goes on as the same chat; Memory – his notes, × takes one out; a site without step 1zk says so', (t) async {
    phone(t);
    forgetChat();
    final srv = liveSrv();
    await askLive(t, srv);
    expect(srv.aiStreamed.length, 2, reason: 'each step asked word by word');
    expect(srv.calls.where((c) => c == 'mech:getAiReply'), isEmpty, reason: 'nothing asked in one piece');
    expect(srv.aiLookups, [{'name': 'remember', 'args': {'note': 'He wants the answers short.'}}]);
    expect(find.text('Memory – kept'), findsOneWidget);
    expect(find.textContaining('Noted – I will keep my answers short.'), findsOneWidget);
    expect(find.textContaining('first words'), findsOneWidget, reason: 'the Admin sees when its first words came');
    expect(find.text('Thinking…'), findsNothing);
    expect(find.textContaining('what the server sends after the end'), findsNothing, reason: 'read no further than the last line');
    expect(find.text('Kept in memory: He wants the answers short.'), findsOneWidget);
    // kept after the answer – as he saw it
    final id = srv.aiChats.keys.singleWhere((k) => k != 'Cmgold00abc123');
    expect(RegExp(r'^C[0-9a-z]{6,30}$').hasMatch(id), true);
    final kept = srv.aiChats[id]!, km = kept['msgs'] as List;
    expect([kept['title'], kept['n'], km.first, km.last, km.length],
        ['remember that I want the answers short', 1, {'r': 'me', 't': 'remember that I want the answers short'}, {'r': 'bot', 't': 'Noted – I will keep my answers short.'}, 3]);
    expect('${(km[1] as Map)['t']}', startsWith('Looked up: · Memory – kept · claude-sonnet-5-5 · '));
    // "Take it out" under the answer
    await tapK(t, 'ai-unkeep-3');
    await net(t);
    expect(srv.aiMemory.map((m) => m['id']), [2]);
    expect(find.text('Memory मधून काढले.'), findsOneWidget);
    expect(find.byKey(const Key('ai-unkeep-3')), findsNothing);
    // History: the newest first; one opened again goes on as the same chat
    await tapK(t, 'ai-hist');
    await net(t);
    expect(find.byType(AiHistoryScreen), findsOneWidget);
    expect(find.text('तुमच्या chats'), findsOneWidget);
    expect(find.text('हे फक्त तुम्हालाच दिसते – आणि फक्त या site चे.'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('ai-chat-0')), matching: find.text('remember that I want the answers short')), findsOneWidget, reason: 'the newest first');
    expect(find.descendant(of: find.byKey(const Key('ai-chat-1')), matching: find.text('diesel of yesterday')), findsOneWidget);
    expect(find.textContaining('· 1 प्रश्न'), findsNWidgets(2));
    await tapK(t, 'ai-chat-1');
    await net(t);
    expect(find.byType(AiHistoryScreen), findsNothing);
    expect(find.textContaining('History मधून उघडली ('), findsOneWidget);
    expect(find.textContaining('180 L yesterday.'), findsOneWidget);
    expect(find.text('Diesel issues 13-10-2026'), findsOneWidget);
    expect(find.textContaining('Noted – I will keep'), findsNothing);
    srv.aiScript.add({'parts': [{'text': 'Yesterday **180 L** – more because of the night shift.'}], 'model': 'claude-sonnet-5-5'});
    await t.enterText(find.byKey(const Key('ai-in')), 'why was it so much');
    await tapK(t, 'ai-send');
    await net(t);
    await net(t);
    expect(srv.aiStreamed.last['contents'], [
      {'role': 'user', 'parts': [{'text': 'diesel of yesterday'}]},
      {'role': 'model', 'parts': [{'text': '180 L yesterday.'}]},
      {'role': 'user', 'parts': [{'text': 'why was it so much'}]},
    ], reason: 'the chat goes on from its questions and answers');
    final old = srv.aiChats['Cmgold00abc123']!;
    expect([old['n'], [for (final m in old['msgs'] as List) (m as Map)['r']], srv.aiChats.length], [2, ['me', 'src', 'bot', 'me', 'src', 'bot'], 2]);
    expect((old['msgs'] as List).any((m) => '${(m as Map)['t']}'.contains('History')), false, reason: 'its note is not kept');
    // Memory: his notes, × takes one out (a save, with its number)
    await tapK(t, 'ai-mem');
    await net(t);
    expect(find.byType(AiMemoryScreen), findsOneWidget);
    expect(find.text('He calls the Dispenser "the pump".'), findsOneWidget);
    expect(find.byKey(const Key('ai-note-3')), findsNothing, reason: 'taken out under the answer');
    expect(find.text('नवीन नोंदीसाठी "लक्षात ठेव …" असे सांगा; × ने काढा.'), findsOneWidget);
    await tapK(t, 'ai-forget-2');
    await net(t);
    expect(srv.aiMemory, isEmpty);
    expect(srv.calls.where((c) => c == 'mech:aiMemoryDel+rid').length, 2);
    expect(find.byKey(const Key('ai-mem-none')), findsOneWidget);
    // a site without step 1zk: said so
    srv.aiStep = false;
    await t.pageBack();
    await net(t);
    await tapK(t, 'ai-hist');
    await net(t);
    expect(find.byKey(const Key('ai-hist-off')), findsOneWidget);
    expect(find.textContaining('supabase_step1zk_ai_memory.sql'), findsOneWidget);
  });

  testWidgets('(3.61.0 – Mechanical update-186) Ask word by word – the way back: the stream cut after words → asked once more in one piece (its words gone); the service\'s own answer before a word (no credit, busy) → said, not asked twice', (t) async {
    phone(t);
    forgetChat();
    final srv = liveSrv()..aiStreamHow.addAll(['busy', 'credit', 'busy0']);
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await net(t);
    await tapK(t, 'home-ask');
    await net(t);
    srv.aiScript.add({'parts': [{'text': 'In one piece after the cut.'}], 'model': 'claude-haiku-5-5'});
    Future<void> ask(String q) async {
      await t.enterText(find.byKey(const Key('ai-in')), q);
      await tapK(t, 'ai-send');
      await net(t);
      await net(t);
    }

    await ask('who took the most diesel today and why');
    expect(srv.calls.where((c) => c == 'mech:getAiReply').length, 1);
    expect(find.textContaining('In one piece after the cut.'), findsOneWidget);
    expect(find.textContaining('The first words of'), findsNothing);
    await ask('why so much diesel today');
    expect(find.textContaining('The AI service has no credit left (Claude'), findsWidgets);
    await ask('why so much diesel yesterday');
    expect(find.textContaining('The AI service is busy right now (529) – that is on its side'), findsWidgets);
    expect(srv.calls.where((c) => c == 'mech:getAiReply').length, 1, reason: 'the service\'s own answer is not asked twice');
    expect(srv.aiStreamed.length, 3);
  });

  testWidgets('(3.61.0 – Mechanical update-186) Talk: each sentence said while the answer is written; 🎙 while it speaks – it stops at once and listens (the talk goes on, the rest of that answer not said); then it listens again by itself; 3 silences end it', (t) async {
    phone(t);
    forgetChat();
    final srv = FakeServer()
      ..aiOn = true
      ..aiStream = true;
    srv.prefs['brief'] = false;
    final s = await ready(t, srv);
    final heard = <String>['why so much diesel today', 'why so much diesel yesterday', '', '', ''];
    final said = <String>[];
    var stops = 0;
    final oL = voice.listenOnce, oS = voice.sayAloud, oSL = voice.stopListening, oSS = voice.stopSaying;
    addTearDown(() {
      voice.listenOnce = oL;
      voice.sayAloud = oS;
      voice.stopListening = oSL;
      voice.stopSaying = oSS;
    });
    voice.listenOnce = (lang, h) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final w = heard.isEmpty ? '' : heard.removeAt(0);
      h(w);
      return w;
    };
    voice.sayAloud = (text, lang) async {
      said.add(text);
      await Future<void>.delayed(const Duration(milliseconds: 400)); // (a sentence takes a while to say)
    };
    voice.stopListening = () async {};
    voice.stopSaying = () async => stops++;
    srv.aiScript.addAll([
      {'parts': [{'text': 'Diesel today: 240 L in 4 entries. The most went to MH-25-AJ-2169: 80 L.'}], 'model': 'claude-sonnet-5-5'},
      {'parts': [{'text': 'Yesterday 180 L.'}], 'model': 'claude-sonnet-5-5'},
    ]);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await tapK(t, 'home-ask');
    await net(t);
    await t.tap(find.byKey(const Key('ai-mic')));
    // heard → asked word by word → its first sentence said (each sentence on its own)
    for (var i = 0; i < 60 && said.isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(said, ['Diesel today: 240 L in 4 entries.']);
    expect(find.descendant(of: find.byKey(const Key('ai-live-text')), matching: find.textContaining('🎙')), findsOneWidget, reason: 'it tells him he can speak now');
    // he presses the microphone while it speaks: it stops and listens at once
    final n = stops;
    await t.tap(find.byKey(const Key('ai-mic')));
    await t.pump();
    expect(stops, greaterThan(n));
    for (var i = 0; i < 6; i++) {
      await net(t);
    }
    expect(srv.aiStreamed.length, 2, reason: 'the talk went on: the next question heard and asked');
    expect(said, ['Diesel today: 240 L in 4 entries.', 'Yesterday 180 L.'], reason: 'the rest of the first answer was not said');
    expect(heard, isEmpty);
    expect(find.byKey(const Key('ai-live')), findsNothing, reason: '3 silences: the talk ends');
    expect(srv.calls.where((c) => c == 'mech:getAiReply'), isEmpty);
  });

  testWidgets('(3.61.0 – Mechanical update-186) pictures: the note it kept, with "Take it out"; History; Memory', (t) async {
    phone(t);
    forgetChat();
    final srv = liveSrv();
    await askLive(t, srv);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/70_ai_kept.png'));
    await tapK(t, 'ai-hist');
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/71_ai_history.png'));
    await t.pageBack();
    await net(t);
    await tapK(t, 'ai-mem');
    await net(t);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/72_ai_memory.png'));
  }, tags: ['golden']);

  // (3.95.0, with rcl-purchase "Purchase Phase 2" and rcl-store step 10) Purchase Orders – the master in Purchase, its copy at the site (D-2)
  testWidgets('(3.95.0) Purchase Orders: an approved CS → Make PO (the GST % the supplier did not give typed) → at the site; the PO list; cancelled with why', (t) async {
    phone(t);
    final srv = FakeServer()..purSite = true;
    srv.purCs[1]!['status'] = 'Approved';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    Future<void> card(String key, {bool tap = true}) async {
      if (find.byKey(Key(key)).evaluate().isEmpty) await t.scrollUntilVisible(find.byKey(Key(key)), 250, scrollable: find.byType(Scrollable).first);
      await seen(t, find.byKey(Key(key)));
      await settle(t, 300);
      if (!tap) return;
      await t.tap(find.byKey(Key(key)));
      await net(t);
    }

    Future<void> type(String key, String v) => t.enterText(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)), v);
    await seen(t, find.text('Purchase'));
    await settle(t, 400);
    await t.tap(find.text('Purchase'));
    await net(t);
    expect(find.byKey(const Key('pur-po')), findsOneWidget, reason: 'the Purchase Orders card');
    await card('pur-cs');
    await card('prq-row-1');
    expect(find.byKey(const Key('pcs-view')), findsOneWidget);
    await card('pcs-po-make-2-S1');
    expect(find.byKey(const Key('ppf-form')), findsOneWidget);
    expect([for (final x in srv.purSent) x['action']].where((a) => a == 'poNew').length, 1);
    await card('ppf-gst-2', tap: false);
    await type('ppf-gst-2', '18');
    await settle(t, 300);
    await card('ppf-sum', tap: false);
    expect(find.text('₹1,30,800.00'), findsOneWidget, reason: '2 × 55,000 + GST 18 % + freight 1,000');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9zd_pur_po_form.png'));
    await card('ppf-save');
    await t.tap(find.text('Make the PO').last);
    await net(t);
    final mk = srv.purSent.lastWhere((x) => x['action'] == 'poMake');
    expect([mk['cs'], mk['vendor'], mk['site'], mk['date'], mk['need_by'], mk['pay_terms'], mk['gst']], [1, 2, 'S1', '2026-10-14', '2026-10-20', 'Advance', {'2': '18'}]);
    expect(find.byKey(const Key('ppv-view')), findsOneWidget, reason: 'the PO opened');
    expect(find.textContaining('At the site in its Store as PO 21'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9ze_pur_po.png'));
    await t.pageBack();
    await net(t);
    expect(srv.purPos.length, 1);
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // ---- the PO list → the PO → cancelled with why (no GRN yet)
    await card('pur-po');
    expect(find.byKey(const Key('ppo-row-1')), findsOneWidget);
    await card('ppo-row-1');
    await card('ppv-cancel');
    await t.enterText(find.byKey(const Key('note-box')), 'Wrong rate');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    final cn = srv.purSent.lastWhere((x) => x['action'] == 'poCancel');
    expect([cn['no'], cn['ver'], cn['why']], [1, 1, 'Wrong rate']);
    expect(find.textContaining('Cancelled by Sujit Mule'), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.95.0) Store: a PO of the Purchase Department is read-only at the site – "From Purchase", no Change / Cancel / Delete / Close', (t) async {
    phone(t);
    final srv = FakeServer()
      ..storeWf = true
      ..storePurPo = true
      ..storePages = {...FakeServer().storePages, 'purchase': 'Edit'};
    await openStoreWork(t, server: srv);
    await reach(t, 'sw-po', 'st-work');
    await tapK(t, 'sw-po');
    await net(t);
    expect(find.byKey(const Key('po-pur-S1-21'), skipOffstage: false), findsOneWidget);
    expect(find.text('From Purchase – PO-0001', skipOffstage: false), findsOneWidget);
    for (final k in ['po-edit-S1-21', 'po-cancel-S1-21', 'po-del-S1-21', 'po-close-S1-21', 'po-ok-S1-21']) {
      expect(find.byKey(Key(k), skipOffstage: false), findsNothing, reason: k);
    }
    expect(find.byKey(const Key('po-edit-S1-1'), skipOffstage: false), findsOneWidget, reason: 'the site\'s own PO as before');
  });

  // (3.95.0, with rcl-engineering "Engineering 2B") the Measurement Book
  testWidgets('(3.95.0) Engineering: the Measurement Book – another\'s page check-measured; a new page from the reports (a width corrected, a stretch not approved by the IE left out); the abstract', (t) async {
    phone(t);
    final srv = FakeServer()..engSite = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    Future<void> card(String key, {bool tap = true}) async {
      if (find.byKey(Key(key)).evaluate().isEmpty) await t.scrollUntilVisible(find.byKey(Key(key)), 250, scrollable: find.byType(Scrollable).first);
      await seen(t, find.byKey(Key(key)));
      await settle(t, 300);
      if (!tap) return;
      await t.tap(find.byKey(Key(key)));
      await net(t);
    }

    Future<void> type(String key, String v) => t.enterText(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)), v);
    await seen(t, find.text('Engineering'));
    await settle(t, 400);
    await t.tap(find.text('Engineering'));
    await net(t);
    await card('eng-mb');
    expect(find.byKey(const Key('emb-row-MB-0001')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9zf_eng_mb.png'));
    // ---- Engineer One's page: check-measured (never one's own)
    await card('emb-row-MB-0001');
    expect(find.byKey(const Key('emb-view')), findsOneWidget);
    await card('emb-ok');
    await t.tap(find.byKey(const Key('emb-chk-ok')));
    await net(t);
    final ck = srv.engSent.lastWhere((x) => x['action'] == 'mbCheck');
    expect([ck['no'], ck['ver'], ck['chk_day']], ['MB-0001', 1, '2026-10-14']);
    expect(srv.engMb.first['status'], 'Check-measured');
    expect(find.byKey(const Key('emb-ok')), findsNothing, reason: 'locked once check-measured');
    await t.pageBack();
    await net(t);
    // ---- a new MB page: the work of the last 7 days not measured
    await t.tap(find.byKey(const Key('emb-new')));
    await net(t);
    await card('emb-find');
    final of = srv.engSent.lastWhere((x) => x['action'] == 'mbOffer');
    expect([of['work'], of['layer'], of['side'], of['from'], of['to']], ['W-001', 'L1', '', '2026-10-08', '2026-10-14']);
    await card('emb-w-k1', tap: false);
    await type('emb-w-k1', '7.9');
    await type('emb-rem-k1', 'measured 7.9 m');
    await settle(t, 300);
    await card('emb-l-k3', tap: false);
    expect(find.descendant(of: find.byKey(const Key('emb-l-k3')), matching: find.textContaining('Not approved by the IE – not finished')), findsOneWidget, reason: 'the stretch the IE did not approve: left out');
    await card('emb-tot', tap: false);
    expect(find.text('2 lines ticked · 1,161 cum'), findsOneWidget, reason: '300 × 7.9 × 0.3 + 200 × 7.5 × 0.3');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9zg_eng_mb_new.png'));
    await card('emb-save');
    final sv = srv.engSent.lastWhere((x) => x['action'] == 'mbSave');
    expect([sv['work'], sv['layer'], sv['mb_day'], (sv['lines'] as List).length, (sv['lines'] as List).first],
        ['W-001', 'L1', '2026-10-14', 2, {'key': 'k1', 'w': '7.9', 'mm': '300', 'remark': 'measured 7.9 m', 'skip': ''}]);
    expect(find.byKey(const Key('emb-view')), findsOneWidget, reason: 'the new page opened');
    await t.pageBack();
    await net(t);
    // ---- the abstract for the RA bill
    await t.tap(find.byKey(const Key('emb-t-abs')));
    await net(t);
    expect(find.text('2,487.5 cum', skipOffstage: false), findsOneWidget);
  }, tags: ['golden']);

  // (3.103.0, rcl-hr – asked 12-11-2026: "PURN HR MODUAL … WEB AND APP") the app's own attendance screen
  testWidgets('(3.103.0) HR – my attendance: inside → selfie → IN; outside, a poor reading, Developer Options, a made-up location: nothing sent; no network: kept on the phone and sent later as the same punch; another phone; my month; "My HR"', (t) async {
    phone(t);
    final kit = FakeAttendKit();
    AttendKit.kit = kit;
    final selfie = Uint8List.fromList(img.encodeJpg(img.Image(width: 64, height: 48)));
    attendSelfieForTest = (_) async => selfie;
    addTearDown(() {
      attendSelfieForTest = null;
      AttendKit.kit = AttendKit();
    });
    final srv = FakeServer()..hrSite = true;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    Future<void> openHr() async {
      await seen(t, find.text('HR'));
      await settle(t, 400);
      await t.tap(find.text('HR'));
      await net(t);
    }

    Future<void> tapKey(String key) async {
      if (find.byKey(Key(key)).evaluate().isEmpty) await t.scrollUntilVisible(find.byKey(Key(key)), 250, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.byKey(Key(key)));
      await settle(t, 300);
      await t.tap(find.byKey(Key(key)));
      await net(t);
    }

    // (a long page builds only what is near the view: scrolled down to it first)
    Future<void> shown(Finder f) async {
      if (f.evaluate().isEmpty) await t.scrollUntilVisible(f, 250, scrollable: find.byType(Scrollable).first);
      await settle(t, 300);
    }

    // (what was asked of HR – without the quiet look for his team's requests after every reading)
    List<String> acts() => [for (final x in srv.hrSent) if (x['action'] != 'teamRegs' && x['action'] != 'teamLeaves') '${x['fn'] ?? x['action']}'];
    await openHr();
    expect(acts(), ['sso', 'myAttend']);
    expect(srv.calls.where((c) => c.startsWith('portal:go:hr:')).length, 1, reason: 'a ticket of the Portal for the module hr');
    expect(srv.hrSent.lastWhere((x) => x['action'] == 'myAttend')['device_id'], 'and-test-phone-1');
    expect(find.textContaining('Not marked yet'), findsOneWidget);
    expect(find.textContaining('Site office'), findsWidgets);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9z_att_home.png'));
    // ---- outside: said with the metres, nothing sent, no selfie asked
    kit.lat = 18.53;
    await tapKey('att-punch');
    expect(find.textContaining('outside your work place'), findsOneWidget);
    expect(find.textContaining('Outside –'), findsOneWidget);
    expect(acts(), ['sso', 'myAttend']);
    expect(kit.files.keys.where((k) => k.contains('_q_')), isEmpty);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9z_att_outside.png'));
    kit.lat = 18.52;
    // ---- a poor reading, a made-up location, Developer Options: nothing sent
    kit.acc = 400;
    await tapKey('att-punch');
    expect(find.textContaining('not exact enough yet (400 m)'), findsOneWidget);
    kit.acc = 12;
    kit.mocked = true;
    await tapKey('att-punch');
    expect(find.textContaining('made-up location'), findsOneWidget);
    kit.mocked = false;
    kit.dev = true;
    await tapKey('att-punch');
    expect(find.byKey(const Key('att-dev')), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const Key('att-punch'))).onPressed, null, reason: 'Developer Options ON: the button is off');
    expect(acts(), ['sso', 'myAttend']);
    kit.dev = false;
    await t.tap(find.byTooltip('Refresh'));      // (back from Settings: read again)
    await net(t);
    expect(find.byKey(const Key('att-dev')), findsNothing);
    // ---- inside: the selfie, then IN – the photo to its place, the punch with this phone's number, the server's clock
    await tapKey('att-punch');
    final pin = srv.hrSent.lastWhere((x) => x['action'] == 'punch');
    expect([pin['kind'], pin['lat'], pin['accuracy_m'], pin['dev_options'], pin['mock'], (pin['device'] as Map)['id'], pin.containsKey('offline')], ['in', 18.52, 12, false, false, 'and-test-phone-1', false]);
    expect(srv.hrPhotos.keys.toList(), [pin['client_id']]);
    expect(srv.hrPhotos.values.first > 100, true);
    expect(find.textContaining('IN marked at 10:30'), findsOneWidget);
    expect(find.text('IN 10:30'), findsOneWidget);
    expect(kit.files.keys.where((k) => k.contains('_q_')), isEmpty, reason: 'sent: nothing stays on the phone');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9z_att_in.png'));
    // ---- no network: OUT is kept on the phone as taken (place, clocks, photo) – and shown
    srv.hrNet = false;
    kit.counter = 5000000 + 600000;
    kit.clock += 600000;
    await tapKey('att-punch');
    expect(find.textContaining('your OUT of 10:40 is kept on the phone'), findsOneWidget);
    await shown(find.byKey(const Key('att-kept-out')));
    expect(find.byKey(const Key('att-kept-out')), findsOneWidget);
    expect(kit.files.keys.where((k) => k.contains('_q_')).length, 2, reason: 'the punch and its photo');
    expect(srv.hrPunches.length, 1);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9z_att_kept.png'));
    // (the app closed and opened again with no network: what was read last, and what is kept)
    await t.pageBack();
    await net(t);
    await openHr();
    expect(find.byKey(const Key('att-offline')), findsOneWidget);
    await shown(find.byKey(const Key('att-kept-out')));
    expect(find.byKey(const Key('att-kept-out')), findsOneWidget);
    // ---- the network is back: the SAME punch goes – its own number, its own place and moment, the phone's counters
    kit.lat = 19.9;      // (he has gone home meanwhile: the punch is not made again from where he is now)
    srv.hrNet = true;
    await tapKey('att-send');
    final pout = srv.hrSent.lastWhere((x) => x['action'] == 'punch');
    expect([pout['kind'], pout['offline'], pout['lat'], pout['elapsed'], pout['anchor_elapsed'], pout['anchor_server'], pout['at_device']],
        ['out', true, 18.52, 5600000, 5000000, DateTime.utc(2026, 10, 14, 5).millisecondsSinceEpoch, DateTime.utc(2026, 10, 14, 5, 10).toIso8601String()]);
    expect(srv.hrPunches.length, 2);
    expect(find.byKey(const Key('att-kept-out')), findsNothing);
    expect(kit.files.keys.where((k) => k.contains('_q_')), isEmpty);
    await shown(find.textContaining('Sent later'));
    expect(find.textContaining('Sent later'), findsOneWidget);
    kit.lat = 18.52;
    // ---- my month: each day with what it counts as, the month's count; a day gone is asked to be set right
    await tapKey('att-month');
    expect(find.text('Oct 2026'), findsOneWidget);
    expect(find.byKey(const Key('att-m-paid')), findsOneWidget);
    expect(find.textContaining('working days so far'), findsOneWidget);
    for (final e in {'P': '1', 'HD': '0', 'A': '1', 'L': '0'}.entries) {
      expect(find.descendant(of: find.byKey(Key('att-t-${e.key}')), matching: find.text(e.value)), findsOneWidget, reason: 'the month\'s count: ${e.key}');
    }
    expect(find.byKey(const Key('att-d-2026-10-12')), findsOneWidget);
    expect(find.byKey(const Key('att-d-2026-10-13')), findsOneWidget);
    expect(find.byKey(const Key('att-d-2026-10-14')), findsOneWidget);
    expect(find.byKey(const Key('att-d-2026-10-15')), findsNothing, reason: 'a day to come is not listed');
    expect(find.textContaining('Absent'), findsWidgets);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9z_att_month.png'));
    // (3.107.0) the month is a calendar: a day is opened under it by a touch; a day gone has "Ask to set right"
    expect(find.byKey(const Key('att-day')), findsNothing);
    await tapKey('att-d-2026-10-14');
    expect(find.byKey(const Key('att-day')), findsOneWidget);
    expect(find.byKey(const Key('att-ask')), findsNothing, reason: 'today is marked with the phone – not asked for');
    await tapKey('att-d-2026-10-12');
    expect(find.byKey(const Key('reg-send')), findsNothing, reason: 'the day is opened first');
    await tapKey('att-ask');
    // (3.108.0) the form is a page of its own: "Set a day right" – the day, what it counts as now, IN, OUT, the reason
    expect(find.byKey(const Key('reg-send')), findsOneWidget);
    expect(find.textContaining('12-10-2026 · Monday'), findsOneWidget);
    expect(find.textContaining('no punch – absent'), findsOneWidget);
    await t.enterText(find.byKey(const Key('reg-in')), '09:05');
    await t.enterText(find.byKey(const Key('reg-out')), '18:10');
    await t.enterText(find.byKey(const Key('reg-why')), 'x');
    await t.ensureVisible(find.byKey(const Key('reg-send')));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('reg-send')));
    await net(t);
    expect(find.textContaining('at least 5 letters'), findsOneWidget, reason: 'the server\'s refusal is shown in the form');
    await t.enterText(find.byKey(const Key('reg-why')), 'Phone was dead');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9z_att_request.png'));
    await t.ensureVisible(find.byKey(const Key('reg-send')));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('reg-send')));
    await net(t);
    final rq = srv.hrSent.lastWhere((x) => x['action'] == 'regAsk');
    expect([rq['day'], rq['in_time'], rq['out_time'], rq['out_next_day'], rq['reason']], ['2026-10-12', '09:05', '18:10', false, 'Phone was dead']);
    expect(find.byKey(const Key('reg-send')), findsNothing);
    await settle(t, 4000);      // (the message goes)
    await tapKey('att-m-next');
    expect(find.text('Oct 2026'), findsOneWidget, reason: 'not a month to come');
    await tapKey('att-m-prev');
    expect(find.text('Sep 2026'), findsOneWidget);
    expect(find.textContaining('No punch in this month'), findsOneWidget);
    await t.pageBack();
    await net(t);
    // ---- (3.108.0) "Requests": his own, the newest first – where each stands
    await tapKey('att-reqs');
    expect(find.byKey(const Key('regs-new')), findsOneWidget);
    expect(find.byKey(const Key('reg-1')), findsOneWidget);
    expect(find.textContaining('12 Oct · IN 09:05 · OUT 18:10'), findsOneWidget);
    expect(find.textContaining('waits for HR office'), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);
    expect(find.byKey(const Key('regs-team')), findsNothing, reason: 'nobody reports to him: nothing to approve');
    await t.pageBack();
    await net(t);
    // ---- (3.108.0) Leave: the balance, this month, used; "+ Apply for leave" – the form; the request waits; taken back by a touch
    await tapKey('att-leave');
    expect(find.descendant(of: find.byKey(const Key('leave-page')), matching: find.text('My requests')), findsOneWidget);
    expect([for (final k in ['bal', 'add', 'used']) t.widget<Text>(find.byKey(Key('leave-$k'))).data], ['3', '4', '1']);
    expect(find.textContaining('4 leaves are added every month'), findsOneWidget, reason: 'said from the site\'s policy');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9z_att_leave.png'));
    await tapKey('leave-new');
    expect(find.textContaining('14-10-2026'), findsNWidgets(2), reason: 'from and to: today');
    expect(find.textContaining('balance 3 → 2 after approval'), findsOneWidget);
    await t.tap(find.byKey(const Key('leave-part-first')));
    await settle(t, 300);
    expect(find.textContaining('balance 3 → 2.5 after approval'), findsOneWidget);
    await t.tap(find.byKey(const Key('leave-send')));
    await net(t);
    expect(find.textContaining('at least 3 letters'), findsOneWidget, reason: 'the server\'s refusal is shown in the form');
    await t.enterText(find.byKey(const Key('leave-why')), 'Family function');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9z_att_leave_ask.png'));
    await t.tap(find.byKey(const Key('leave-send')));
    await net(t);
    final lq = srv.hrSent.lastWhere((x) => x['action'] == 'leaveAsk');
    expect([lq['from'], lq['to'], lq['part'], lq['reason']], ['2026-10-14', '2026-10-14', 'first', 'Family function']);
    expect(find.byKey(const Key('leave-send')), findsNothing);
    expect(find.byKey(const Key('lv-1')), findsOneWidget);
    expect(find.textContaining('14 Oct · half day'), findsOneWidget);
    await settle(t, 4000);      // (the message goes)
    await tapKey('lv-back-1');
    await t.tap(find.text('Take back'));
    await net(t);
    expect(srv.hrSent.lastWhere((x) => x['action'] == 'leaveCancel')['id'], 1);
    expect(find.text('Taken back'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // ---- a person others report to: their requests wait for him first – passed on to the HR office, or refused with the reason
    srv.hrTeam = 2;
    srv.hrRegs.addAll([
      {'id': 11, 'code': 'E00020', 'name': 'Ravi Patil', 'day': '2026-10-10', 'in_time': '08:55', 'out_time': '', 'out_next_day': false, 'reason': 'Forgot IN', 'status': 'pending', 'level': 1, 'steps': []},
      {'id': 12, 'code': 'E00021', 'name': 'Asha More', 'day': '2026-10-11', 'in_time': '', 'out_time': '18:30', 'out_next_day': false, 'reason': 'No network', 'status': 'pending', 'level': 1, 'steps': []},
    ]);
    srv.hrLeaves.add({'id': 21, 'code': 'E00020', 'name': 'Ravi Patil', 'from': '2026-10-20', 'to': '2026-10-21', 'part': 'full', 'days': 2, 'reason': 'Village fair', 'status': 'pending', 'level': 1, 'steps': [], 'note': ''});
    await openHr();
    await tapKey('att-reqs');
    expect(find.byKey(const Key('regs-team')), findsOneWidget);
    expect(find.byKey(const Key('reg-11')), findsOneWidget);
    expect(find.byKey(const Key('reg-12')), findsOneWidget);
    expect(find.byKey(const Key('team-yes-1')), findsNothing, reason: 'his own request is not his to decide');
    expect(find.textContaining('Ravi Patil · Leave 20 – 21 Oct · 2 days'), findsOneWidget, reason: 'his team\'s leave waits for him too');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9z_att_team.png'));
    await tapKey('team-yes-11');
    expect(srv.hrSent.lastWhere((x) => x['action'] == 'teamRegDecide')['decision'], 'approved');
    expect(find.byKey(const Key('reg-11')), findsNothing);
    await settle(t, 4000);
    await tapKey('team-no-12');
    await t.tap(find.byKey(const Key('note-ok')));
    await settle(t, 400);
    expect(srv.hrSent.where((x) => x['action'] == 'teamRegDecide').length, 1, reason: 'no reason, not sent');
    await t.enterText(find.byKey(const Key('note-box')), 'He was not at site');
    await t.tap(find.byKey(const Key('note-ok')));
    await net(t);
    final no12 = srv.hrSent.lastWhere((x) => x['action'] == 'teamRegDecide');
    expect([no12['id'], no12['decision'], no12['note']], [12, 'refused', 'He was not at site']);
    expect(find.byKey(const Key('reg-12')), findsNothing);
    await settle(t, 6500);
    await tapKey('tl-yes-21');
    expect(srv.hrSent.lastWhere((x) => x['action'] == 'teamLeaveDecide')['decision'], 'approved');
    expect(find.byKey(const Key('lv-21')), findsNothing);
    await settle(t, 4000);
    await t.pageBack();
    await net(t);
    await t.pageBack();
    await net(t);
    // ---- his attendance is tied to another phone: said, the button off
    srv.hrBound = 'and-old-phone';
    await openHr();
    expect(find.byKey(const Key('att-other')), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const Key('att-punch'))).onPressed, null);
    await t.pageBack();
    await net(t);
  }, tags: ['golden']);

  testWidgets('(3.103.0) HR: "My HR" (hrme) opens the same screen with its own ticket', (t) async {
    phone(t);
    AttendKit.kit = FakeAttendKit();
    addTearDown(() => AttendKit.kit = AttendKit());
    final srv = FakeServer()
      ..hrSite = true
      ..hrKey = 'hrme';
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await seen(t, find.text('HR'));
    await settle(t, 400);
    await t.tap(find.text('HR'));
    await net(t);
    expect(srv.calls.where((c) => c.startsWith('portal:go:hrme:')).length, 1);
    expect(find.byKey(const Key('att-punch')), findsOneWidget);
  });

  /* (3.108.0) A PERSON WITH HR ONLY (no Mechanical at his site): the app's own pages – Home, Attendance, Leave, Me. */
  testWidgets('(3.108.0) HR only: Home (his day, this week, four tiles, "For you"), the slide marks IN; Me – my details, my documents (he attaches one), salary slips, my phone, the language', (t) async {
    phone(t);
    final kit = FakeAttendKit();
    AttendKit.kit = kit;
    final selfie = Uint8List.fromList(img.encodeJpg(img.Image(width: 64, height: 48)));
    attendSelfieForTest = (_) async => selfie;
    final pickWas = pickAttFiles;
    final asked = <String>[];
    pickAttFiles = (how, room) async {
      asked.add('$how:$room');
      return [(name: 'pan.jpg', bytes: selfie)];
    };
    addTearDown(() {
      attendSelfieForTest = null;
      AttendKit.kit = AttendKit();
      pickAttFiles = pickWas;
    });
    final srv = FakeServer()
      ..hrSite = true
      ..hrKey = 'hrme'
      ..hrOnlyUser = true;
    // (the words of a language come from the app's own files – here from the test, as in lang_test: a file is not read inside a screen test)
    final s = Session(Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: srv.client), langRead: (p) async => '{}')..clock = () => DateTime(2026, 10, 14, 10, 30);
    await t.runAsync(() => s.signIn('sujit@rcl.test', 'Nashik#Road848!'));
    expect([s.hrOnly, s.sites.length, s.stage], [true, 1, Stage.ready]);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await net(t);
    Future<void> tapKey(String key) async {
      if (find.byKey(Key(key)).evaluate().isEmpty) await t.scrollUntilVisible(find.byKey(Key(key)), 250, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.byKey(Key(key)));
      await settle(t, 300);
      await t.tap(find.byKey(Key(key)));
      await net(t);
    }

    // ---- Home: nothing of Mechanical is asked; his name, his day, the tiles, what waits
    expect(find.byKey(const Key('hr-home')), findsOneWidget);
    expect(srv.calls.where((c) => c.startsWith('mech:')), isEmpty, reason: 'nothing of Mechanical');
    expect(srv.calls.where((c) => c.startsWith('portal:go:hrme:')).length, 1, reason: 'one "My HR" sign-in for the whole Home');
    expect(t.widget<Text>(find.byKey(const Key('hh-name'))).data, 'Sujit Mule');
    expect(t.widget<Text>(find.byKey(const Key('hh-big'))).data, 'Not marked yet');
    expect(find.textContaining('Slide to mark IN'), findsOneWidget);
    expect([for (final k in ['hh-leave-sub', 'hh-docs-sub']) t.widget<Text>(find.byKey(Key(k))).data], ['3 left', '4 missing']);
    expect(find.byKey(const Key('hh-w-2026-10-13')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('hh-w-2026-10-13')), matching: find.text('P')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('hh-n-day-2026-10-12')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('12 Oct has no punch'), findsOneWidget);
    expect(find.byKey(const Key('hh-dot')), findsOneWidget, reason: 'something waits');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9x_hr_home.png'));
    // ---- the slide: My attendance opens to mark – IN; said big, then Home again by itself: on duty
    await tapKey('hh-slide');
    expect(find.byKey(const Key('att-punch')), findsOneWidget);
    await t.tap(find.byKey(const Key('att-punch')));
    await net(t);
    expect(find.byKey(const Key('att-ok-page')), findsOneWidget);
    await settle(t, 3200);
    await net(t);
    expect(find.byKey(const Key('att-punch')), findsNothing, reason: 'Home again');
    expect(srv.hrPunches.length, 1);
    expect(t.widget<Text>(find.byKey(const Key('hh-big'))).data, '10:30');
    expect(find.textContaining('On duty since'), findsOneWidget);
    expect(find.textContaining('Slide to mark OUT'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9x_hr_home_duty.png'));
    // ---- the bar: Attendance and Leave open as pages; Me is the second tab
    await tapKey('nav-att');
    expect(find.byKey(const Key('att-page')), findsOneWidget);
    await t.pageBack();
    await net(t);
    await tapKey('nav-leave');
    expect(find.byKey(const Key('leave-page')), findsOneWidget);
    await t.pageBack();
    await net(t);
    await tapKey('nav-me');
    expect(find.byKey(const Key('me-page')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('me-role'))).data, 'E00012 · Site Engineer');
    expect(t.widget<Text>(find.byKey(const Key('me-pct'))).data, '64%');
    expect(find.textContaining('4 still missing'), findsOneWidget);
    expect(find.textContaining('Registered for attendance'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9x_hr_me.png'));
    // ---- my details: to read – the account number comes masked
    await tapKey('me-details');
    expect(find.byKey(const Key('det-page')), findsOneWidget);
    expect(find.text('XXXX9012'), findsOneWidget);
    expect(find.textContaining('Still needed: Blood group'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9x_hr_details.png'));
    await t.pageBack();
    await net(t);
    // ---- my documents: he attaches his PAN card himself – a photo from the gallery; sent to its place, then listed
    await tapKey('me-docs');
    expect(find.byKey(const Key('docs-page')), findsOneWidget);
    expect(find.text('Missing'), findsNWidgets(4));
    await tapKey('doc-add-pan');
    await t.tap(find.byKey(const Key('doc-gallery')));
    await net(t);
    expect(asked, ['gallery:1']);
    expect(srv.hrDocFiles.values.toList(), ['image/jpeg']);
    final da = srv.hrSent.lastWhere((x) => x['action'] == 'myDocAdd');
    expect([da['kind'], da['path'], da.containsKey('id')], ['pan', 'emp12/f1.jpg', false], reason: 'no employee id is sent – the server knows who he is');
    expect(find.text('Attached'), findsOneWidget);
    expect(find.text('Missing'), findsNWidgets(3));
    expect(find.byKey(const Key('doc-open-doc1')), findsOneWidget);
    await settle(t, 4000);      // (the message goes)
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9x_hr_docs.png'));
    await t.pageBack();
    await net(t);
    expect(find.textContaining('3 still missing'), findsOneWidget, reason: 'Me is read again');
    // ---- salary slips: nothing made up before payroll; my phone
    await tapKey('me-slips');
    expect(find.textContaining('No salary slip yet'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await tapKey('me-phone');
    expect(t.widget<Text>(find.byKey(const Key('phone-model'))).data, 'Test Phone');
    await t.pageBack();
    await net(t);
    // ---- (3.109.0) my photo: he sets his own profile picture – kept as his paper "Photo"; Me is read again and shows it
    expect(find.byKey(const Key('face-pic')), findsNothing, reason: 'no photo yet: his letters');
    await tapKey('me-photo');
    await t.tap(find.byKey(const Key('photo-gallery')));
    await net(t);
    expect(asked.last, 'gallery:1');
    final ph = srv.hrSent.lastWhere((x) => x['action'] == 'myDocAdd');
    expect([ph['kind'], ph.containsKey('id')], ['photo', false]);
    expect(srv.hrDocs.where((d) => d['kind'] == 'photo').length, 1);
    expect(find.byKey(const Key('face-pic')), findsOneWidget, reason: 'his photo is asked for on Me');
    expect(find.textContaining('Set – touch to change'), findsOneWidget);
    await settle(t, 4000);      // (the message goes)
    // ---- the language: the whole app in one – kept on this phone (he has no settings at Mechanical)
    await tapKey('me-lang');
    expect(find.byKey(const Key('lang-page')), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9x_hr_lang.png'));
    await t.tap(find.byKey(const Key('lang-mr')));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('lang-save')));
    await net(t);
    expect(Lang.i.code, 'mr');
    expect(find.byKey(const Key('lang-page')), findsNothing);
    expect(find.text('भाषा'), findsOneWidget);
    expect(find.text('माझी कागदपत्रे'), findsOneWidget);
    expect(srv.calls.where((c) => c.startsWith('mech:')), isEmpty, reason: 'still nothing of Mechanical');
    await tapKey('me-lang');
    await t.tap(find.byKey(const Key('lang-en')));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('lang-save')));
    await net(t);
    expect(Lang.i.code, 'en');
    expect(find.text('Language'), findsOneWidget);
    // ---- e-mail and password: his user ID, change password
    await tapKey('me-account');
    expect(find.byKey(const Key('acc-pw')), findsOneWidget);
    expect(find.text('sujit@rcl.test'), findsOneWidget);
    await t.pageBack();
    await net(t);
    await tapKey('nav-home');
    expect(find.byKey(const Key('hr-home')), findsOneWidget);
  }, tags: ['golden']);

  testWidgets('(3.108.0) a person with Mechanical keeps the app exactly as it was – HR only is for a person nobody gave Mechanical', (t) async {
    phone(t);
    final srv = FakeServer()..hrSite = true;
    final s = await ready(t, srv);
    expect(s.hrOnly, false);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.byKey(const Key('hr-home')), findsNothing);
    expect(find.byKey(const Key('hr-nav')), findsNothing);
  });

  /* (3.104.0) TWO WAYS TO SIGN IN and "VERIFY MY E-MAIL" (the Portal's steps 10 / 11; his rules of 12-11-2026). */
  testWidgets('(3.104.0) "Login with Email OTP" is not there while the Portal has it switched off – the sign-in exactly as before', (t) async {
    phone(t);
    final off = FakeServer(), s0 = make(off);
    await t.runAsync(s0.start);
    await t.pumpWidget(RclApp(session: s0));
    await net(t);
    expect(off.calls, contains('portal:options'), reason: 'the sign-in screen asks the Portal');
    expect(find.byKey(const Key('login-otp')), findsNothing, reason: 'switched off: the sign-in exactly as before');
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('(3.104.0) switched on: the second button under "Sign in"; it turns the card, "Continue with Password" turns it back; the password way as ever', (t) async {
    phone(t);
    final srv = FakeServer()..otpOn = true;
    final s = make(srv);
    await t.runAsync(s.start);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.byKey(const Key('login-otp')), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget, reason: 'the password way stays the first one');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/1c_two_ways_in.png'));
    await t.enterText(find.byType(TextField).at(0), 'sujit.own@rcl.test');
    await tapK(t, 'login-otp');
    await settle(t, 600);
    expect(find.byKey(const Key('login-otp-mail')), findsOneWidget);
    expect(t.widget<TextField>(find.byKey(const Key('login-otp-mail'))).controller!.text, 'sujit.own@rcl.test', reason: 'the e-mail typed is carried over');
    expect(find.byKey(const Key('login-otp-code')), findsNothing, reason: 'first "Send code"');
    await tapK(t, 'login-otp-back');
    await settle(t, 600);
    expect(find.byKey(const Key('login-otp-mail')), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2), reason: 'the e-mail and the password again');
    // the password way works as ever
    await t.enterText(find.byType(TextField).at(0), 'sujit@rcl.test');
    await t.enterText(find.byType(TextField).at(1), 'Nashik#Road848!');
    await t.tap(find.text('Sign in'));
    await net(t);
    expect(s.stage, Stage.pickSite);
    expect(srv.calls, isNot(contains('portal:otpSend')));
  }, tags: ['golden']);

  testWidgets('(3.104.0) sign-in with a code: "Send code", a wrong code is said, "Send again" waits 60 seconds, the right code signs in', (t) async {
    phone(t);
    final srv = FakeServer()..otpOn = true;
    final s = make(srv);
    await t.runAsync(s.start);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.enterText(find.byType(TextField).at(0), 'sujit.own@rcl.test');
    await tapK(t, 'login-otp');
    await settle(t, 600);
    await seen(t, find.text('Send code'));
    await t.tap(find.text('Send code'));
    await net(t);
    expect(srv.codesTo, ['sujit.own@rcl.test']);
    expect(find.byKey(const Key('login-otp-code')), findsOneWidget);
    expect(find.textContaining('Send again ('), findsOneWidget);
    expect(t.widget<TextButton>(find.byKey(const Key('login-otp-again'))).onPressed, isNull, reason: 'the 60 seconds between two codes');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/1d_code_by_email.png'));
    // too short, then wrong
    await t.enterText(find.byKey(const Key('login-otp-code')), '12');
    await seen(t, find.text('Sign in'));
    await t.tap(find.text('Sign in'));
    await settle(t, 600);
    expect(find.textContaining('Type the 6-digit code'), findsOneWidget);
    expect(srv.calls, isNot(contains('portal:otpLogin')), reason: 'not sent to the Portal');
    await t.enterText(find.byKey(const Key('login-otp-code')), '111111');
    await settle(t, 300);
    await seen(t, find.text('Sign in'));
    await t.tap(find.text('Sign in'));
    await net(t);
    expect(find.textContaining('The code is wrong or has expired.'), findsOneWidget);
    expect(s.stage, Stage.signedOut);
    expect(find.byKey(const Key('login-otp-code')), findsOneWidget, reason: 'still on the code');
    // after the 60 seconds another code can be asked
    await settle(t, 61000);
    expect(t.widget<TextButton>(find.byKey(const Key('login-otp-again'))).onPressed, isNotNull);
    expect(find.text('Send again'), findsOneWidget);
    await tapK(t, 'login-otp-again');
    await net(t);
    expect(srv.codesTo.length, 2);
    // the right code: the same sign-in as with the password
    await t.enterText(find.byKey(const Key('login-otp-code')), '482913');
    await settle(t, 300);
    await seen(t, find.text('Sign in'));
    await t.tap(find.text('Sign in'));
    await net(t);
    expect(s.stage, Stage.pickSite);
    expect(s.email, 'sujit@rcl.test', reason: 'his account – the user ID every module knows');
    expect(srv.calls, containsAllInOrder(['portal:options', 'portal:otpSend', 'portal:otpLogin', 'portal:otpSend', 'portal:otpLogin', 'portal:me']));
    expect(srv.calls, isNot(contains('portal:login')));
  }, tags: ['golden']);

  testWidgets('(3.104.0) e-mail not verified: the strip on Home, "Verify my e-mail" on Me – his own e-mail, the code, verified; then no strip', (t) async {
    phone(t);
    final srv = FakeServer()..mailInfo = {'verified': false, 'canVerify': true, 'remind': true};
    srv.prefs['brief'] = false;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(s.mailRemind, true);
    expect(find.byKey(const Key('mail-strip')), findsOneWidget, reason: 'asked of the Portal when Home opens');
    expect(find.byKey(const Key('mail-strip-go')), findsOneWidget);
    expect(srv.alerts, 1);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/2m_verify_strip.png'));
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    expect(find.byKey(const Key('me-verified')), findsNothing);
    await tapK(t, 'me-verify');
    await net(t);
    expect(find.byKey(const Key('ve-mail')), findsOneWidget);
    expect(t.widget<TextField>(find.byKey(const Key('ve-mail'))).controller!.text, 'sujit@rcl.test', reason: 'his user ID is filled in – he types his own e-mail over it');
    expect(find.byKey(const Key('ve-code')), findsNothing);
    // another user's e-mail is refused by the Portal
    await t.enterText(find.byKey(const Key('ve-mail')), 'taken@rcl.test');
    await settle(t, 300);
    await t.tap(find.byKey(const Key('ve-go')));
    await net(t);
    expect(find.textContaining('already another user'), findsOneWidget);
    expect(find.byKey(const Key('ve-code')), findsNothing);
    // his own e-mail: the code goes there
    await t.enterText(find.byKey(const Key('ve-mail')), 'sujit.real@rcl.test');
    await settle(t, 300);
    expect(find.byKey(const Key('ve-err')), findsNothing);
    await t.tap(find.byKey(const Key('ve-go')));
    await net(t);
    expect(srv.codesTo, ['sujit.real@rcl.test']);
    expect(find.byKey(const Key('ve-code')), findsOneWidget);
    expect(t.widget<TextButton>(find.byKey(const Key('ve-again'))).onPressed, isNull);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/2n_verify_email.png'));
    await t.enterText(find.byKey(const Key('ve-code')), '000000');
    await settle(t, 300);
    await t.tap(find.byKey(const Key('ve-go')));
    await net(t);
    expect(find.textContaining('The code is wrong or has expired.'), findsOneWidget);
    expect(s.mailVerified, false);
    await t.enterText(find.byKey(const Key('ve-code')), '482913');
    await settle(t, 300);
    await t.tap(find.byKey(const Key('ve-go')));
    await net(t);
    expect(find.byKey(const Key('ve-ok')), findsOneWidget, reason: 'told once which e-mail signs in from now on');
    expect(s.mailVerified, true);
    expect(s.mailLogin, 'sujit.real@rcl.test');
    expect(s.email, 'sujit@rcl.test', reason: 'the user ID is not touched');
    await t.tap(find.byKey(const Key('ve-ok')));
    await net(t);
    expect(find.byKey(const Key('ve-mail')), findsNothing, reason: 'back on Me');
    expect(find.byKey(const Key('me-verified')), findsOneWidget);
    expect(find.byKey(const Key('me-verify')), findsNothing);
    await t.tap(find.byKey(const Key('tab-home')));
    await net(t);
    expect(find.byKey(const Key('mail-strip')), findsNothing);
    expect(srv.alerts, 1, reason: 'a verified person is not reminded');
  }, tags: ['golden']);

  testWidgets('(3.104.0) nothing of it for a person the Portal says nothing about (the Super Admin, the steps not run) or with the reminder off', (t) async {
    phone(t);
    final srv = FakeServer();
    srv.prefs['brief'] = false;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(s.mail, isNull);
    expect(find.byKey(const Key('mail-strip')), findsNothing);
    expect(srv.calls, isNot(contains('portal:emailAlert')));
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    expect(find.byKey(const Key('me-verify')), findsNothing);
    expect(find.byKey(const Key('me-verified')), findsNothing);
  });

  testWidgets('(3.104.0) not verified and the reminder switched off: no strip, nothing asked – but he can verify from Me', (t) async {
    phone(t);
    final srv2 = FakeServer()..mailInfo = {'verified': false, 'canVerify': true, 'remind': false};
    srv2.prefs['brief'] = false;
    final s2 = await ready(t, srv2);
    await t.pumpWidget(RclApp(session: s2));
    await net(t);
    expect(find.byKey(const Key('mail-strip')), findsNothing);
    expect(srv2.calls, isNot(contains('portal:emailAlert')));
    await t.tap(find.byKey(const Key('tab-me')));
    await net(t);
    expect(find.byKey(const Key('me-verify')), findsOneWidget);
  });

  /* (3.105.0 – approved 12-11-2026: the strip on Home, the attendance page it opens, the "marked" screen) */
  testWidgets('(3.105.0) attendance from Home: the strip (dawn – "Slide to mark IN") opens the page – sky, place, phone, one button; IN → said big, back on Home by itself, the strip says "On duty"; then OUT → "done"', (t) async {
    phone(t);
    final kit = FakeAttendKit();
    AttendKit.kit = kit;
    final selfie = Uint8List.fromList(img.encodeJpg(img.Image(width: 64, height: 48)));
    attendSelfieForTest = (_) async => selfie;
    addTearDown(() {
      attendSelfieForTest = null;
      AttendKit.kit = AttendKit();
    });
    final srv = FakeServer()..hrSite = true;
    srv.prefs['brief'] = false;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.byKey(const Key('att-strip')), findsOneWidget, reason: 'he has HR on this site');
    expect(find.textContaining('Slide to mark IN'), findsOneWidget);
    expect(srv.hrSent, isEmpty, reason: 'Home asks nothing of the HR server – the strip shows what this phone kept');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9y_att_strip_in.png'));
    // a tap (or the sun slid across) opens the attendance page
    await t.tap(find.byKey(const Key('att-strip')));
    await net(t);
    expect(find.textContaining('Not marked yet'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const Key('att-punch'))).onPressed, isNotNull);
    expect(find.textContaining('Slide to mark IN'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9y_att_page_in.png'));
    // IN: the place is read, the selfie taken, the server takes it – said big, once
    await t.tap(find.byKey(const Key('att-punch')));
    await net(t);
    expect(find.byKey(const Key('att-ok-page')), findsOneWidget);
    expect(find.text('10:30'), findsOneWidget);
    expect(srv.hrPunches.length, 1);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9y_att_marked.png'));
    // … and back on Home by itself: the strip has turned
    await settle(t, 3200);
    await net(t);
    expect(find.byKey(const Key('att-ok-page')), findsNothing);
    expect(find.byKey(const Key('att-punch')), findsNothing, reason: 'Home again');
    expect(find.textContaining('On duty'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9y_att_strip_out.png'));
    // the sun slid back opens the page again: OUT
    await t.drag(find.byKey(const Key('att-strip-knob')), const Offset(-260, 0));
    await net(t);
    expect(find.textContaining('Slide to mark OUT'), findsOneWidget);
    expect(find.byKey(const Key('att-phone')), findsOneWidget, reason: 'this phone is now the one his attendance is tied to');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/9y_att_page_out.png'));
    await t.tap(find.byKey(const Key('att-punch')));
    await net(t);
    expect(find.byKey(const Key('att-ok-page')), findsOneWidget);
    await t.tap(find.byKey(const Key('att-ok')));
    await net(t);
    expect(srv.hrPunches.length, 2);
    expect(find.textContaining('Attendance done today'), findsOneWidget);
    expect(find.byKey(const Key('att-punch')), findsNothing);
  }, tags: ['golden']);

  testWidgets('(3.110.0) the site\'s rule "once a day": after the day\'s IN and OUT the bar is off and says so; a day closed by itself (OUT forgotten) is said with its time', (t) async {
    phone(t);
    AttendKit.kit = FakeAttendKit();
    addTearDown(() => AttendKit.kit = AttendKit());
    final srv = FakeServer()
      ..hrSite = true
      ..hrOnce = true
      ..hrBound = 'and-test-phone-1';
    srv.prefs['brief'] = false;
    srv.hrPunches.addAll([
      {'id': 'pn1', 'client_id': 'c1', 'kind': 'in', 'at': '2026-10-14T03:00:00.000Z', 'time': '08:30', 'place_id': 'pl1', 'offline': false, 'status': 'ok'},
      {'id': 'pn2', 'client_id': 'c2', 'kind': 'out', 'at': '2026-10-14T04:30:00.000Z', 'time': '10:00', 'place_id': 'pl1', 'offline': false, 'status': 'ok'},
    ]);
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await seen(t, find.text('HR'));
    await settle(t, 400);
    await t.tap(find.text('HR'));
    await net(t);
    expect(find.byKey(const Key('att-once')), findsOneWidget);
    expect(find.byKey(const Key('att-closed')), findsNothing);
    expect(t.widget<FilledButton>(find.byKey(const Key('att-punch'))).onPressed, null, reason: 'nothing more today');
    expect(find.descendant(of: find.byKey(const Key('att-punch')), matching: find.textContaining('attendance is done')), findsOneWidget);
    expect(srv.hrSent.where((x) => x['action'] == 'punch'), isEmpty);
    await t.pageBack();
    await net(t);
    // he forgot OUT: the shift's time has passed – closed by itself, absent; he is told what to do
    srv.hrPunches.removeLast();
    srv.hrClosed = '23:50';
    await t.tap(find.text('HR'));
    await net(t);
    expect(find.byKey(const Key('att-closed')), findsOneWidget);
    expect(find.textContaining('closed by itself at 23:50'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const Key('att-punch'))).onPressed, null);
  });

  testWidgets('(3.105.0) no HR on the site: no strip on Home', (t) async {
    phone(t);
    final srv = FakeServer();
    srv.prefs['brief'] = false;
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    expect(find.byKey(const Key('att-strip')), findsNothing);
  });

  /* (3.106.0 – asked 12-11-2026: "All" first among the dates; the photos small, each beside the box it fills) */
  testWidgets('(3.106.0) the entries list opens on "All dates" – the newest of every date; a tap on a day: that day only; "All" again', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-entries')));
    await net(t);
    await t.tap(find.byKey(const Key('entries-Diesel Issue')));
    await net(t);
    expect(find.byKey(const Key('day-all')), findsOneWidget);
    expect(find.byKey(const Key('en-all-head')), findsOneWidget, reason: 'all dates is the one chosen');
    expect(srv.listAsked.last, {'fn': 'getDieselIssues', 'from': '', 'to': ''}, reason: 'no dates asked – the newest of all');
    expect(find.text('Sany 210 (No.1)'), findsOneWidget);
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/5c_entries_all.png'));
    await t.tap(find.byKey(const Key('day-2026-10-13')));
    await net(t);
    expect(find.byKey(const Key('en-all-head')), findsNothing);
    expect(find.text('13-10-2026, Tue'), findsOneWidget);
    expect([srv.listAsked.last['from'], srv.listAsked.last['to'], srv.listAsked.last['all']], ['2026-10-13', '2026-10-13', true]);
    await t.tap(find.byKey(const Key('day-all')));
    await net(t);
    expect(find.byKey(const Key('en-all-head')), findsOneWidget);
    expect(srv.listAsked.last['from'], '');
  }, tags: ['golden']);

  testWidgets('(3.106.0) a new Diesel Issue: the date and the shift on one line; each photo small, beside the box it fills – the dispenser\'s beside the litres', (t) async {
    phone(t);
    final srv = FakeServer();
    final s = await ready(t, srv);
    await t.pumpWidget(RclApp(session: s));
    await net(t);
    await t.tap(find.byKey(const Key('tab-plus')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('plus-Diesel Issue')));
    await net(t);
    expect(find.byKey(const Key('photo-first')), findsOneWidget);
    for (final k in ['dash', 'pump', 'veh', 'reg']) {
      expect(find.byKey(Key('photo-$k')), findsOneWidget, reason: 'the $k photo can be taken');
    }
    final shot = t.getRect(find.byKey(const Key('photo-pump'))), box = t.getRect(find.byKey(const Key('d-qty')));
    expect(shot.right, lessThan(box.left), reason: 'the photo on the left of its box');
    expect((shot.center.dy - box.center.dy).abs(), lessThan(30), reason: 'on the same line');
    expect(shot.width, lessThan(90), reason: 'small');
    final day = t.getRect(find.text('14-10-2026')), shift = t.getRect(find.text('Night'));
    expect((day.center.dy - shift.center.dy).abs(), lessThan(30), reason: 'the date and the shift on one line');
    await pics(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/6c_issue_photos_beside.png'));
  }, tags: ['golden']);
}
