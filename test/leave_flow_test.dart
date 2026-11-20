// (3.147.0, rcl-hr of 19-11-2026) LEAVE WITH A SERVER THAT ASKS A PAPER: the form is not sent without it; a request says where it
// stands and WHO it waits for, with its history; Delete while it waits; Change days – longer: the extra days with their reason and
// paper. The server's answers are given here as it sends them.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/screens/attach_box.dart' show pickAttFiles;
import 'package:rcl_mobile/screens/leave.dart';

Future<void> settle(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final pdf = Uint8List.fromList('%PDF-1.4 a doctor note'.codeUnits);
  final uploads = <String>[];
  setUp(() {
    uploads.clear();
    leaveUploadForTest = (url, bytes, type) async => uploads.add('$url $type ${bytes.length}');
    pickAttFiles = (how, room) async => [(name: 'note.pdf', bytes: pdf)];
  });
  tearDown(() => leaveUploadForTest = null);

  final waiting = <String, dynamic>{
    'id': 7, 'from': '2026-10-20', 'to': '2026-10-22', 'part': 'full', 'days': 3, 'reason': 'Family function', 'status': 'pending', 'level': 1, 'steps': [], 'files': 1, 'note': '',
    'can': {'delete': true, 'change': true},
    'waits': {'stage': 'verify', 'who': [{'role': 'reporting', 'name': 'Ravi Patil'}], 'text': 'Waits for verify: Ravi Patil (Reporting person)'},
    'history': [
      {'kind': 'asked', 'by': 'Sujit Mule', 'at': '2026-10-14T04:30:00.000Z', 'from': '2026-10-20', 'to': '2026-10-23', 'days': 4, 'note': 'Family function'},
      {'kind': 'shortened', 'by': 'Sujit Mule', 'self': true, 'at': '2026-10-14T05:00:00.000Z', 'from': '2026-10-20', 'to': '2026-10-22', 'days': 3, 'was': {'from': '2026-10-20', 'to': '2026-10-23', 'days': 4}},
    ],
  };
  final approved = <String, dynamic>{
    'id': 8, 'from': '2026-10-25', 'to': '2026-10-26', 'part': 'full', 'days': 2, 'reason': 'Wedding', 'status': 'approved', 'level': 2, 'steps': [], 'files': 1, 'note': '',
    'can': {'delete': false, 'change': true},
    'history': [
      {'kind': 'asked', 'by': 'Sujit Mule', 'at': '2026-10-10T04:30:00.000Z', 'from': '2026-10-25', 'to': '2026-10-26', 'days': 2},
      {'kind': 'approved', 'by': 'Priya Shinde', 'at': '2026-10-11T04:30:00.000Z', 'note': ''},
    ],
  };
  Map<String, dynamic> leave() => {
        'ok': true, 'today': '2026-10-14', 'paper': true, 'book': true, 'policy': null, 'balance': 6, 'paid': 6, 'comp': 0, 'booked': 2, 'pending': 3, 'available': 1,
        'month': {'credit': 1, 'added': 0, 'used': 0}, 'ledger': const [], 'requests': [Map.of(waiting), Map.of(approved)],
      };

  testWidgets('the form: no paper – not sent; a paper chosen goes to its place first, then the request with it', (t) async {
    final sent = <Map<String, dynamic>>[];
    await t.pumpWidget(MaterialApp(home: LeaveScreen(ask: (b) async {
      sent.add(b);
      switch ('${b['action']}') {
        case 'myLeavePaperUrl':
          return {'ok': true, 'path': 'leave/e1/${'a' * 24}.pdf', 'url': 'https://files.test/up', 'type': b['type']};
        default:
          return leave();
      }
    })));
    await settle(t, 1500);
    await t.tap(find.byKey(const Key('leave-new')));
    await settle(t, 900);
    expect(find.byKey(const Key('lp-add')), findsOneWidget, reason: 'the paper is asked in the form');
    await t.enterText(find.byKey(const Key('leave-why')), 'Fever');
    await t.ensureVisible(find.byKey(const Key('leave-send')));
    await t.tap(find.byKey(const Key('leave-send')));
    await settle(t, 600);
    expect(find.descendant(of: find.byKey(const Key('leave-err')), matching: find.textContaining('Attach a paper')), findsOneWidget);
    expect(sent.where((b) => b['action'] == 'leaveAsk'), isEmpty, reason: 'nothing is sent without the paper');
    await t.ensureVisible(find.byKey(const Key('lp-add')));
    await t.tap(find.byKey(const Key('lp-add')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('lp-pdf')));
    await settle(t, 600);
    expect(find.text('note.pdf'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('leave-send')));
    await t.tap(find.byKey(const Key('leave-send')));
    await settle(t, 1200);
    final url = sent.firstWhere((b) => b['action'] == 'myLeavePaperUrl'), ask = sent.lastWhere((b) => b['action'] == 'leaveAsk');
    expect([url['type'], url['bytes']], ['application/pdf', pdf.length]);
    expect(uploads, ['https://files.test/up application/pdf ${pdf.length}']);
    expect(ask['files'], [
      {'path': 'leave/e1/${'a' * 24}.pdf', 'name': 'note.pdf', 'bytes': pdf.length}
    ]);
    expect(find.byKey(const Key('leave-send')), findsNothing, reason: 'sent: back on his leave');
  });

  testWidgets('a request opened: who it waits for, its history; Delete while it waits', (t) async {
    final sent = <Map<String, dynamic>>[];
    await t.pumpWidget(MaterialApp(home: LeaveScreen(ask: (b) async {
      sent.add(b);
      return leave();
    })));
    await settle(t, 1500);
    // (3.155.0) the road of each request, and in words who it is with
    expect(find.descendant(of: find.byKey(const Key('lv-7')), matching: find.text('In verification')), findsOneWidget, reason: 'on the list too');
    expect(find.descendant(of: find.byKey(const Key('lv-7')), matching: find.text('with Ravi Patil (Reporting person)')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('lv-7')), matching: find.text('Verification')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('lv-8')), matching: find.text('by Priya Shinde')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('lv-8')), matching: find.text('Verification')), findsNothing, reason: 'it had no verification step: Sent → Approval');
    final r7 = leaveRoad(waiting), r8 = leaveRoad(approved);
    expect([for (final x in r7.steps) '${x.name}:${x.state}:${x.who}'], ['Sent:done:You', 'Verification:now:Ravi Patil (Reporting person)', 'Approval:todo:']);
    expect([r7.title, r7.sub, r7.tone, r7.holder], ['In verification', 'with Ravi Patil (Reporting person)', 'w', 'Ravi Patil (Reporting person)']);
    expect([for (final x in r8.steps) '${x.name}:${x.state}:${x.who}'], ['Sent:done:You', 'Approval:done:Priya Shinde']);
    expect([r8.title, r8.sub, r8.far], ['Approved', 'by Priya Shinde', 1]);
    // verified, now with the approver; refused at the approval with the reason
    final r9 = leaveRoad({...waiting, 'level': 2, 'waits': {'stage': 'approve', 'who': [{'role': 'person', 'name': 'Amit Patil'}]}, 'history': [...waiting['history'] as List, {'kind': 'verified', 'by': 'Ravi Patil', 'at': '2026-10-14T06:00:00.000Z'}]});
    expect([for (final x in r9.steps) '${x.name}:${x.state}:${x.who}'], ['Sent:done:You', 'Verification:done:Ravi Patil', 'Approval:now:Amit Patil']);
    expect([r9.title, r9.sub], ['Pending approval', 'with Amit Patil']);
    final r10 = leaveRoad({...waiting, 'status': 'refused', 'level': 2, 'note': 'Site work that week', 'waits': null, 'history': [...waiting['history'] as List, {'kind': 'verified', 'by': 'Ravi Patil', 'at': '2026-10-14T06:00:00.000Z'}, {'kind': 'refused', 'by': 'Amit Patil', 'at': '2026-10-14T07:00:00.000Z'}]});
    expect([for (final x in r10.steps) '${x.name}:${x.state}:${x.who}'], ['Sent:done:You', 'Verification:done:Ravi Patil', 'Approval:bad:Amit Patil']);
    expect([r10.title, r10.sub, r10.tone], ['Rejected', 'by Amit Patil – “Site work that week”', 'x']);
    await t.tap(find.byKey(const Key('lv-open-7')));
    await settle(t, 900);
    expect(find.byKey(const Key('lvd-page')), findsOneWidget);
    expect([for (final k in ['lvd-state', 'lvd-waits']) t.widget<Text>(find.byKey(Key(k))).data], ['IN VERIFICATION', 'With Ravi Patil (Reporting person)']);
    expect(find.byKey(const Key('lvd-road')), findsOneWidget);
    await t.scrollUntilVisible(find.text('Made shorter'), 150, scrollable: find.descendant(of: find.byKey(const Key('lvd-page')), matching: find.byType(Scrollable)).first); // (the full history is further down the page)
    expect(find.text('Asked'), findsOneWidget);
    expect(find.text('Made shorter'), findsOneWidget);
    expect(find.textContaining('you · 14-10-2026 10:30 · 20-10-2026 – 23-10-2026 (4) → 20-10-2026 – 22-10-2026 (3)'), findsOneWidget, reason: 'what he changed, with when');
    expect(find.byKey(const Key('lvd-change')), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('lvd-delete')));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('lvd-delete')));
    await settle(t, 600);
    await t.tap(find.text('Delete'));
    await settle(t, 1500);
    expect(sent.lastWhere((b) => b['action'] == 'leaveCancel')['id'], 7);
    expect(find.byKey(const Key('lvd-page')), findsNothing);
  });

  testWidgets('an approved leave: no Delete (the HR office deletes it); longer – the extra days with their reason and paper', (t) async {
    final sent = <Map<String, dynamic>>[];
    await t.pumpWidget(MaterialApp(home: LeaveScreen(ask: (b) async {
      sent.add(b);
      switch ('${b['action']}') {
        case 'myLeavePaperUrl':
          return {'ok': true, 'path': 'leave/e1/${'b' * 24}.pdf', 'url': 'https://files.test/up2', 'type': b['type']};
        case 'leaveChange':
          return {...leave(), 'changed': {'kind': 'longer', 'id': 8, 'request': 12, 'from': '2026-10-27', 'to': '2026-10-28', 'days': 2}};
        default:
          return leave();
      }
    })));
    await settle(t, 1500);
    await t.tap(find.byKey(const Key('lv-open-8')));
    await settle(t, 900);
    await t.scrollUntilVisible(find.text('An approved leave is deleted by the HR office.'), 150, scrollable: find.descendant(of: find.byKey(const Key('lvd-page')), matching: find.byType(Scrollable)).first);
    expect(find.byKey(const Key('lvd-delete')), findsNothing);
    expect(find.text('An approved leave is deleted by the HR office.'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('lvd-change')));
    await settle(t, 300);
    await t.tap(find.byKey(const Key('lvd-change')));
    await settle(t, 900);
    expect(find.byKey(const Key('lc-page')), findsOneWidget);
    expect(find.byKey(const Key('lc-back')), findsNothing, reason: 'it has not begun: nothing to take off for today');
    // To: 28-10-2026 – two days more
    await t.tap(find.byKey(const Key('lc-to')));
    await settle(t, 900);
    await t.tap(find.text('28'));
    await t.tap(find.text('OK'));
    await settle(t, 900);
    expect(find.textContaining('Longer – the extra days 27-10-2026 – 28-10-2026 are a new request'), findsOneWidget);
    expect(find.byKey(const Key('lc-why')), findsOneWidget);
    await t.enterText(find.byKey(const Key('lc-why')), 'The function goes on');
    await t.ensureVisible(find.byKey(const Key('lc-save')));
    await t.tap(find.byKey(const Key('lc-save')));
    await settle(t, 600);
    expect(find.descendant(of: find.byKey(const Key('lc-err')), matching: find.textContaining('Attach a paper')), findsOneWidget, reason: 'the extra days need their paper');
    await t.ensureVisible(find.byKey(const Key('lp-add')));
    await t.tap(find.byKey(const Key('lp-add')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('lp-pdf')));
    await settle(t, 600);
    await t.ensureVisible(find.byKey(const Key('lc-save')));
    await t.tap(find.byKey(const Key('lc-save')));
    await settle(t, 1500);
    final ch = sent.lastWhere((b) => b['action'] == 'leaveChange');
    expect([ch['id'], ch['from'], ch['to'], ch['reason'], (ch['files'] as List).length], [8, '2026-10-25', '2026-10-28', 'The function goes on', 1]);
    expect(find.byKey(const Key('lc-page')), findsNothing);
    expect(find.byKey(const Key('lvd-page')), findsNothing, reason: 'back on his leave');
  });
}
