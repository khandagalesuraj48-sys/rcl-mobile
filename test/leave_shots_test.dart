// (3.147.0) PICTURES of the leave screens with a server that asks a paper (rcl-hr of 19-11-2026) – for looking at, in the build's
// files (test/goldens/): his list (who each waits for), the form with its paper, a request opened (its history), Change days –
// "Back at work today" and longer with the reason and paper. The server's answers are given here as it sends them.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/screens/attach_box.dart' show pickAttFiles;
import 'package:rcl_mobile/screens/leave.dart';
import 'package:rcl_mobile/ui/hr_skin.dart';
import 'package:rcl_mobile/ui/theme.dart';

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

Future<void> settle(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(loadFonts);
  final pdf = Uint8List.fromList('%PDF-1.4 a doctor note'.codeUnits);
  setUp(() {
    leaveUploadForTest = (url, bytes, type) async {};
    pickAttFiles = (how, room) async => [(name: 'doctor note.pdf', bytes: pdf)];
  });

  final waiting = <String, dynamic>{
    'id': 7, 'from': '2026-10-20', 'to': '2026-10-22', 'part': 'full', 'days': 3, 'reason': 'Family function', 'status': 'pending', 'level': 2, 'steps': [], 'files': 1, 'note': '',
    'can': {'delete': true, 'change': true},
    'waits': {'stage': 'approve', 'who': [{'role': 'site_hr', 'name': ''}, {'role': 'ho_hr', 'name': ''}], 'text': 'Waits for approval: Site HR Admin / HO HR'},
    'history': [
      {'kind': 'asked', 'by': 'Sujit Mule', 'at': '2026-10-13T04:30:00.000Z', 'from': '2026-10-20', 'to': '2026-10-23', 'days': 4, 'note': 'Family function'},
      {'kind': 'verified', 'by': 'Ravi Patil', 'at': '2026-10-13T08:10:00.000Z', 'note': ''},
      {'kind': 'shortened', 'by': 'Sujit Mule', 'self': true, 'at': '2026-10-14T05:00:00.000Z', 'from': '2026-10-20', 'to': '2026-10-22', 'days': 3, 'was': {'from': '2026-10-20', 'to': '2026-10-23', 'days': 4}},
    ],
  };
  final onNow = <String, dynamic>{
    'id': 9, 'from': '2026-10-12', 'to': '2026-10-16', 'part': 'full', 'days': 5, 'reason': 'Native place', 'status': 'approved', 'level': 2, 'steps': [], 'files': 1, 'note': '',
    'can': {'delete': false, 'change': true},
    'history': [
      {'kind': 'asked', 'by': 'Sujit Mule', 'at': '2026-10-01T04:30:00.000Z', 'from': '2026-10-12', 'to': '2026-10-16', 'days': 5},
      {'kind': 'approved', 'by': 'Priya Shinde', 'at': '2026-10-02T06:00:00.000Z', 'note': ''},
    ],
  };
  final later = <String, dynamic>{
    'id': 8, 'from': '2026-10-25', 'to': '2026-10-26', 'part': 'full', 'days': 2, 'reason': 'Wedding', 'status': 'approved', 'level': 2, 'steps': [], 'files': 1, 'note': '',
    'can': {'delete': false, 'change': true},
    'history': [
      {'kind': 'asked', 'by': 'Sujit Mule', 'at': '2026-10-10T04:30:00.000Z', 'from': '2026-10-25', 'to': '2026-10-26', 'days': 2},
      {'kind': 'approved', 'by': 'Priya Shinde', 'at': '2026-10-11T04:30:00.000Z', 'note': ''},
    ],
  };
  final gone = <String, dynamic>{
    'id': 5, 'from': '2026-10-05', 'to': '2026-10-05', 'part': 'full', 'days': 1, 'reason': 'Bank work', 'status': 'cancelled', 'level': 2, 'steps': [], 'files': 1, 'note': '',
    'can': {'delete': false, 'change': false},
    'history': [
      {'kind': 'asked', 'by': 'Sujit Mule', 'at': '2026-10-01T04:30:00.000Z', 'from': '2026-10-05', 'to': '2026-10-05', 'days': 1},
      {'kind': 'deleted', 'by': 'Sujit Mule', 'self': true, 'at': '2026-10-02T04:30:00.000Z'},
    ],
  };
  Map<String, dynamic> leave() => {
        'ok': true, 'today': '2026-10-14', 'paper': true, 'book': true, 'policy': null, 'balance': 8, 'paid': 8, 'comp': 0, 'booked': 4, 'pending': 3, 'available': 1,
        'month': {'credit': 1, 'added': 0, 'used': 2}, 'ledger': const [], 'requests': [Map.of(waiting), Map.of(later), Map.of(onNow), Map.of(gone)],
      };
  Future<Map<String, dynamic>> ask(Map<String, dynamic> b) async {
    switch ('${b['action']}') {
      case 'myLeavePaperUrl':
        return {'ok': true, 'path': 'leave/e1/${'a' * 24}.pdf', 'url': 'https://files.test/up', 'type': b['type']};
      default:
        return leave();
    }
  }

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: hrTheme(sk, appTheme()), home: HrLook(child: LeaveScreen(ask: ask))));
    await settle(t, 1500);
  }

  Future<void> shot(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

  testWidgets('pictures: the list, the form with its paper, a request opened, Change days', (t) async {
    await open(t);
    await shot('9z_lv_1_list');
    // the form, its paper attached
    await t.tap(find.byKey(const Key('leave-new')));
    await settle(t, 900);
    await t.enterText(find.byKey(const Key('leave-why')), 'Fever – the doctor said three days rest');
    await t.ensureVisible(find.byKey(const Key('lp-add')));
    await t.tap(find.byKey(const Key('lp-add')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('lp-pdf')));
    await settle(t, 900);
    await shot('9z_lv_2_form_paper');
    await t.pageBack();
    await settle(t, 900);
    // a waiting request opened: who it waits for, its history, Change days, Delete
    await t.tap(find.byKey(const Key('lv-open-7')));
    await settle(t, 900);
    await shot('9z_lv_3_waiting');
    await t.pageBack();
    await settle(t, 900);
    // his approved leave of today: "Back at work today"
    await t.ensureVisible(find.byKey(const Key('lv-open-9')));
    await t.tap(find.byKey(const Key('lv-open-9')));
    await settle(t, 900);
    await shot('9z_lv_4_approved');
    await t.tap(find.byKey(const Key('lvd-change')));
    await settle(t, 900);
    await t.tap(find.byKey(const Key('lc-back')));
    await settle(t, 600);
    await shot('9z_lv_5_back_today');
    await t.pageBack();
    await settle(t, 900);
    await t.pageBack();
    await settle(t, 900);
    // an approved leave to come: longer – the extra days with their reason and paper
    await t.ensureVisible(find.byKey(const Key('lv-open-8')));
    await t.tap(find.byKey(const Key('lv-open-8')));
    await settle(t, 900);
    await t.tap(find.byKey(const Key('lvd-change')));
    await settle(t, 900);
    await t.tap(find.byKey(const Key('lc-to')));
    await settle(t, 900);
    await t.tap(find.text('28'));
    await t.tap(find.text('OK'));
    await settle(t, 900);
    await t.enterText(find.byKey(const Key('lc-why')), 'The function goes on two days more');
    await t.ensureVisible(find.byKey(const Key('lp-add')));
    await t.tap(find.byKey(const Key('lp-add')));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('lp-pdf')));
    await settle(t, 900);
    await t.drag(find.byKey(const Key('lc-page')), const Offset(0, 600));
    await settle(t, 600);
    await shot('9z_lv_6_longer');
  }, tags: ['golden']);
}
