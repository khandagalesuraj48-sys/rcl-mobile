// (3.42.0, asked 26-10-2026: "mala app war pratek gostich realtime notification jayla haw app band aso ki chalu app updet pasun te
// sagle kahi") The notifications through Firebase (lib/core/push.dart, push_fcm.dart): what each message of Mechanical shows, in the
// app's language; the approvals told once (the same numbers as the 15-minute check); a new version; the phone given at a site once
// a day and taken off at Sign out; what a pressed notification opens.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/alerts.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/lang.dart';
import 'package:rcl_mobile/core/push.dart';
import 'package:rcl_mobile/core/push_fcm.dart';
import 'package:rcl_mobile/core/session.dart';

import 'fake_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() async {
    Session.onReady = null;
    Session.onSignOut = null;
    await Lang.i.set('');
  });

  test('a ring: "<name> is calling", what he wants, the call channel (ringtone, Answer / Decline); its stop and its missed use the same number', () {
    final n = pushNoteOf({'t': 'ring', 'call': 'k1', 'name': 'Asha', 'from': 'u-asha', 'mode': 'voice', 'site': 'T2'})!;
    expect([n.title, n.body, n.channel, n.ring, n.id], ['Asha is calling', 'Voice call', 'rcl_calls', true, pushCallId('k1')]);
    expect(jsonDecode(n.payload), {'t': 'ring', 'site': 'T2', 'call': 'k1', 'from': 'u-asha'});
    expect(pushNoteOf({'t': 'ring', 'call': 'k2', 'name': 'Asha', 'mode': 'page', 'page': 'Log Book'})!.body, 'wants to show you a page of the app – Log Book');
    final done = pushNoteOf({'t': 'done', 'call': 'k1'})!;
    expect([done.id, done.cancel], [-1, pushCallId('k1')], reason: 'answered on another device: the ring stops, nothing new');
    final miss = pushNoteOf({'t': 'missed', 'call': 'k1', 'name': 'Asha', 'site': 'S1'})!;
    expect([miss.title, miss.cancel, miss.channel], ['Missed call from Asha.', pushCallId('k1'), 'rcl_calls_missed']);
    expect(pushNoteOf({'t': 'ring'}), isNull);
    expect(pushNoteOf({'t': 'something new'}), isNull, reason: 'a message the app does not know: nothing');
  });

  test('approvals: the same numbers as the 15-minute check – one thing is told once; the others their own number', () {
    final d = {
      'requests': [
        {'id': 'VF-1', 'summary': ['MH-12 50 L'], 'canDecide': true, 'task': 'Diesel Issue', 'by': 'Bala'},
        {'id': 'VF-2', 'summary': ['Log Book'], 'canAnswer': true, 'reverted': {'by': 'Asha', 'note': 'which date?'}},
      ]
    };
    final check = alertsFrom(d, <String, int>{}, 1000);
    final w = pushNoteOf({'t': 'cr', 'id': 'VF-1', 'title': 'Verification – Diesel Issue by Bala', 'body': 'MH-12 50 L', 'site': 'S1'})!;
    final b = pushNoteOf({'t': 'cr', 'id': 'VF-2', 'title': 'Sent back to you – Log Book', 'body': 'Asha: which date?'})!;
    final r = pushNoteOf({'t': 'cr', 'id': 'VF-1', 'title': 'Reminder from Bala – Diesel Issue waits for your approval', 'body': 'VF-1: MH-12 50 L'})!;
    final a = pushNoteOf({'t': 'cr', 'id': 'VF-1', 'title': 'Approved – saved: Diesel Issue', 'body': ''})!;
    expect([w.id, b.id], [check[0].$1, check[1].$1], reason: 'the same notification – replaced, never two');
    expect(r.id, ('VF-1'.hashCode ^ 0x2545f491) & 0x3fffffff, reason: 'a reminder: the number the check gives a reminder');
    expect([w.seen, b.seen, r.seen, a.seen], ['wVF-1', 'bVF-2', 'rVF-1', '']);
    expect([w.id == a.id, w.channel, jsonDecode(w.payload)], [false, 'rcl_approvals', {'t': 'cr', 'site': 'S1', 'id': 'VF-1'}]);
    // the check after Firebase has told it: nothing again
    expect(alertsFrom(d, {'wVF-1': 900, 'bVF-2': 990}, 1000), isEmpty);
  });

  test('a new version: told when it is newer than this app; in the app\'s language (Marathi / Hindi words of the app)', () async {
    expect(pushNoteOf({'t': 'upd', 'version': '3.42.0', 'build': '151'}, myBuild: 150)!.title, 'RCL ERP 3.42.0 is ready');
    expect(pushNoteOf({'t': 'upd', 'version': '3.42.0', 'build': '151'}, myBuild: 151), isNull, reason: 'this phone has it');
    await Lang.i.set('mr', read: (p) async => p.endsWith('app_mr.json') ? jsonEncode({'RCL ERP {0} is ready': 'RCL ERP {0} तयार आहे', 'Tap to update the app.': 'App update करण्यासाठी दाबा.', '{0} is calling': '{0} कॉल करत आहेत', 'Voice call': 'व्हॉइस कॉल'}) : '{}');
    final u = pushNoteOf({'t': 'upd', 'version': '3.42.0', 'build': '151'}, myBuild: 150)!;
    expect([u.title, u.body, u.channel], ['RCL ERP 3.42.0 तयार आहे', 'App update करण्यासाठी दाबा.', 'rcl_updates']);
    final n = pushNoteOf({'t': 'ring', 'call': 'k1', 'name': 'Asha', 'mode': 'voice'})!;
    expect([n.title, n.body], ['Asha कॉल करत आहेत', 'व्हॉइस कॉल']);
  });

  test('shown through Firebase: an approval is marked for the 15-minute check (not told again); a pressed notification: what it opens, Answer / Decline', () async {
    final keep = MemoryKeep();
    await Fcm.show({'t': 'cr', 'id': 'VF-7', 'title': 'Verification – Log Book by Bala', 'body': 'x'}, keep);
    final seen = (jsonDecode(await keep.read(kAlertsSeen) ?? '{}') as Map).cast<String, dynamic>();
    expect(seen.keys, ['wVF-7']);
    expect(alertsFrom({'requests': [{'id': 'VF-7', 'canDecide': true, 'task': 'Log Book', 'by': 'Bala'}]}, seen.map((k, v) => MapEntry(k, (v as num).toInt())), DateTime.now().millisecondsSinceEpoch), isEmpty);
    final t = PushTap.of(jsonEncode({'t': 'ring', 'site': 'T2', 'call': 'k1', 'from': 'u-asha'}), 'answer')!;
    expect([t.t, t.site, t.call, t.from, t.answer, t.decline], ['ring', 'T2', 'k1', 'u-asha', true, false]);
    expect(PushTap.of(jsonEncode({'t': 'ring', 'call': 'k1', 'from': 'u-asha'}), 'decline')!.decline, true);
    expect(PushTap.of(jsonEncode({'t': 'cr', 'site': 'S1', 'id': 'VF-7'}))!.id, 'VF-7');
    expect([PushTap.of(null), PushTap.of('not json')], [null, null]);
  });

  test('the phone at Mechanical: given at a site (once a day; again for another person or a new address); Sign out takes it off FIRST; a server without it: nothing breaks', () async {
    final srv = FakeServer(), keep = MemoryKeep();
    var tok = 'tok-A${'x' * 120}';
    final phone = PushPhone(() async => tok);
    var day = DateTime(2026, 10, 26, 9);
    phone.clock = () => day;
    Session.onReady = (x) => phone.give(x.api, x.email);
    Session.onSignOut = (x) => phone.takeOff(x.api);
    final s = Session(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client));
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('T2');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(srv.fcm, [['fcmSave', tok, 'T2']], reason: 'at the site he opened – Mechanical keeps it for every site');
    await phone.give(s.api, s.email);
    expect(srv.fcm.length, 1, reason: 'the same day: not again');
    day = DateTime(2026, 10, 27, 9);
    await phone.give(s.api, s.email);
    tok = 'tok-B${'y' * 120}';
    await phone.give(s.api, s.email);
    expect(srv.fcm.map((x) => x[1][4]).toList(), ['A', 'A', 'B'], reason: 'the next day, and a new address');
    srv.calls.clear();
    await s.signOut();
    expect(srv.fcm.last.sublist(0, 2), ['fcmOff', tok]);
    expect(srv.calls.indexOf('mech:fcmOff') < srv.calls.indexOf('mech:logout'), true, reason: 'taken off while the sign-in still works');
    expect(await keep.read(kPushSent), isNull);
    // a phone without Firebase (no address): nothing asked
    final none = PushPhone(() async => null);
    final n0 = srv.fcm.length;
    await none.give(s.api, 'sujit@rcl.test');
    expect(srv.fcm.length, n0);
  });
}
