// (3.121.0) Leave under the Rule Book of HR (rcl-hr step 13): ONE balance (Paid leave + Comp-off) with its ledger, and the papers of
// a request. The server's answers are given here as it sends them; a server without step 13 sends none of the new parts.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/screens/leave.dart';

Future<void> settle(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  Map<String, dynamic> leave({required bool book}) => {
        'ok': true,
        'today': '2026-10-14',
        'policy': book ? null : {'valid_from': '2026-10-01', 'per_month': 4, 'carry': true, 'auto_absent': true, 'levels': 2},
        'balance': book ? 3.5 : 3,
        'booked': 0,
        'pending': 1,
        'available': book ? 2.5 : 2,
        'month': {'credit': 2, 'added': 0, 'used': 1},
        'requests': [
          {'id': 7, 'from': '2026-10-20', 'to': '2026-10-20', 'part': 'full', 'days': 1, 'reason': 'Family function', 'status': 'pending', 'level': 2, 'steps': [], if (book) 'files': 1},
        ],
        if (book) ...{
          'book': true,
          'paid': 2,
          'comp': 1.5,
          'ledger': [
            {'day': '2026-10-05', 'bucket': 'comp', 'days': 1.5, 'source': 'compoff', 'text': 'Worked on a day off (04-10-2026)'},
            {'day': '2026-10-03', 'bucket': 'paid', 'days': -1, 'source': 'leave', 'text': 'Leave'},
            {'day': '2026-10-01', 'bucket': 'paid', 'days': 2, 'source': 'month', 'text': 'Leave of the month'},
          ],
        },
      };

  testWidgets('a server without the Rule Book: the leave screen is the one of before – no ledger, no papers', (t) async {
    final sent = <String>[];
    await t.pumpWidget(MaterialApp(home: LeaveScreen(ask: (b) async {
      sent.add('${b['action']}');
      return leave(book: false);
    })));
    await settle(t, 1500);
    expect(find.byKey(const Key('leave-mine')), findsOneWidget);
    expect(find.byKey(const Key('leave-ledger')), findsNothing);
    expect(find.byKey(const Key('lv-files-7')), findsNothing);
    expect(find.textContaining('4 leaves are added every month'), findsOneWidget);
    expect(sent, ['myLeave']);
  });

  testWidgets('with the Rule Book: one balance of Paid leave and Comp-off, the ledger, and the papers of a request – opened, removed', (t) async {
    final sent = <Map<String, dynamic>>[];
    final files = <Map<String, dynamic>>[
      {'id': 31, 'name': 'doctor note.pdf', 'mime': 'application/pdf', 'size': 2048, 'added_by': 'me@rcl.test', 'added_at': '2026-10-14T05:00:00.000Z', 'canRemove': true},
      {'id': 32, 'name': '', 'mime': 'image/jpeg', 'size': 9000, 'added_by': 'hr@rcl.test', 'added_at': '2026-10-14T06:00:00.000Z', 'canRemove': false},
    ];
    await t.pumpWidget(MaterialApp(home: LeaveScreen(ask: (b) async {
      sent.add(b);
      switch ('${b['action']}') {
        case 'myLeaveFiles':
          return {'ok': true, 'request': 7, 'max': 5, 'maxMb': 10, 'canAdd': true, 'files': List.of(files)};
        case 'myLeaveFileRemove':
          files.removeWhere((f) => f['id'] == b['file']);
          return {'ok': true};
        default:
          return leave(book: true);
      }
    })));
    await settle(t, 1500);
    expect(t.widget<Text>(find.byKey(const Key('leave-bal'))).data, '3.5', reason: 'the one balance: paid 2 + comp-off 1.5');
    await t.scrollUntilVisible(find.byKey(const Key('leave-ledger')), 200, scrollable: find.descendant(of: find.byKey(const Key('leave-page')), matching: find.byType(Scrollable)).first);
    expect(find.textContaining('Paid leave 2 · Comp-off 1.5'), findsOneWidget);
    expect(find.text('Worked on a day off (04-10-2026)'), findsOneWidget);
    expect(find.text('+1.5'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
    expect(find.textContaining('one balance'), findsWidgets, reason: 'said in words too');
    // the papers of the request
    await t.scrollUntilVisible(find.byKey(const Key('lv-files-7')), -200, scrollable: find.descendant(of: find.byKey(const Key('leave-page')), matching: find.byType(Scrollable)).first);
    expect(find.descendant(of: find.byKey(const Key('lv-files-7')), matching: find.textContaining('Papers 1')), findsOneWidget);
    await t.tap(find.byKey(const Key('lv-files-7')));
    await settle(t, 900);
    expect(find.byKey(const Key('lf-page')), findsOneWidget);
    expect(find.text('doctor note.pdf'), findsOneWidget);
    expect(find.byKey(const Key('lf-add')), findsOneWidget, reason: 'two of five: one more can be attached');
    expect(find.byKey(const Key('lf-rm-31')), findsOneWidget, reason: 'his own, while the request waits');
    expect(find.byKey(const Key('lf-rm-32')), findsNothing, reason: 'the HR office\'s paper is only opened');
    await t.tap(find.byKey(const Key('lf-rm-31')));
    await settle(t, 600);
    await t.tap(find.text('Remove').last);
    await settle(t, 900);
    expect(sent.where((b) => b['action'] == 'myLeaveFileRemove').single['file'], 31);
    expect(find.text('doctor note.pdf'), findsNothing);
    expect(find.byKey(const Key('lf-32')), findsOneWidget);
  });
}
