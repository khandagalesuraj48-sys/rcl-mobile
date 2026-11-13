// (3.83.0, asked 03-11-2026 with the preview he OK'd) The app's three motions: the gooey-drop message (ui/goo_toast.dart), the menu
// behind the page (ui/push_back.dart) and the tab bar's ripple fill (screens/shell.dart – in screens_test with the whole app).
// The pictures (tag golden) are made for looking at, in the build's files.
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/ui/done_pop.dart';
import 'package:rcl_mobile/ui/goo_toast.dart';
import 'package:rcl_mobile/ui/push_back.dart';
import 'package:rcl_mobile/ui/t.dart';

Future<void> settle(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// A screen with a button at the top (under where the message comes) and one that shows a message.
Widget host({required void Function(BuildContext) say, required VoidCallback underTap}) => MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFAF8F2),
        body: Builder(
          builder: (c) => Column(children: [
            SizedBox(width: double.infinity, height: 110, child: TextButton(key: const Key('under'), onPressed: underTap, child: const Text('Under the message'))),
            const Spacer(),
            TextButton(key: const Key('say'), onPressed: () => say(c), child: const Text('Say')),
            const SizedBox(height: 60),
          ]),
        ),
      ),
    );

void main() {
  testWidgets('the message: a drop at the top that spreads into it; the words there from the start; a tap goes through it; its action works; gone after its time', (t) async {
    var under = 0, helped = 0;
    await t.pumpWidget(host(say: (c) => gooToast(c, 'KM reading is lower than the last one.', color: const Color(0xFFC62828), stay: const Duration(seconds: 6), action: 'Help', onAction: () => helped++), underTap: () => under++));
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    expect(find.text('KM reading is lower than the last one.'), findsOneWidget, reason: 'the words are there at once (they come into sight when it has spread)');
    expect(find.byType(ImageFiltered), findsOneWidget, reason: 'the gooey drop: blurred and made sharp again');
    await settle(t, 1200);
    // a tap on the words goes through to the button under them
    await t.tapAt(t.getCenter(find.text('KM reading is lower than the last one.')));
    await t.pump();
    expect(under, 1, reason: 'the message does not catch taps – only its action');
    await t.tap(find.text('Help'));
    await t.pump();
    expect(helped, 1);
    expect(find.text('KM reading is lower than the last one.'), findsNothing, reason: 'pressing its action takes the message away');
    // a message goes by itself after its time (3 s + its coming and going)
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    gooClear();
    await t.pump();
    expect(find.text('KM reading is lower than the last one.'), findsNothing, reason: 'gooClear takes it away at once');
  });

  testWidgets('one at a time; it goes by itself; "reduce motion": no drop, only the message', (t) async {
    var n = 0;
    await t.pumpWidget(host(say: (c) => gooToast(c, 'Saved ${++n}', stay: const Duration(seconds: 3)), underTap: () {}));
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    await settle(t, 500);
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    expect(find.text('Saved 1'), findsNothing, reason: 'the new one takes the place of the one on the screen');
    expect(find.text('Saved 2'), findsOneWidget);
    await settle(t, 3000);
    expect(find.text('Saved 2'), findsOneWidget, reason: 'still there at 3 s');
    await settle(t, 1500);
    expect(find.text('Saved 2'), findsNothing, reason: 'gone after its 3 s and its coming and going');
    // reduce motion (the phone's setting)
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.pumpWidget(host(say: (c) => gooToast(c, 'Plain', stay: const Duration(seconds: 3)), underTap: () {}));
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    await settle(t, 400);
    expect(find.text('Plain'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing, reason: 'no drop with "reduce motion"');
    await settle(t, 4000);
  });

  testWidgets('the menu behind the page: open – the page shrinks back and moves right, the menu behind it; a tap on the page closes; a swipe to the left closes; a drag from closed opens', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final pb = GlobalKey<PushBackState>();
    var menuTaps = 0;
    final menu = Material(type: MaterialType.transparency, child: SafeArea(child: ListTile(key: const Key('m-row'), title: const Text('Approvals'), onTap: () => menuTaps++)));
    await t.pumpWidget(MaterialApp(home: PushBack(key: pb, child: const Scaffold(body: Center(child: Text('THE PAGE', key: Key('page')))))));
    final at0 = t.getTopLeft(find.byKey(const Key('page')));
    pb.currentState!.open(menu);
    await settle(t, 600);
    expect(pb.currentState!.isOpen, isTrue);
    final at1 = t.getTopLeft(find.byKey(const Key('page')));
    expect(at1.dx, greaterThan(at0.dx + 200), reason: 'the page moved to the right');
    final r = t.getRect(find.byKey(const Key('page')));
    expect(r.width, lessThan(t.getSize(find.byKey(const Key('page'))).width), reason: 'and is smaller on the screen');
    await t.tap(find.byKey(const Key('m-row')));
    expect(menuTaps, 1, reason: 'the menu behind it is pressed');
    // a tap on the page closes
    await t.tapAt(const Offset(330, 420));
    await settle(t, 600);
    expect(pb.currentState!.isOpen, isFalse);
    expect(find.byKey(const Key('m-row')), findsNothing);
    expect(t.getTopLeft(find.byKey(const Key('page'))), at0, reason: 'the page is back on the whole screen');
    // a swipe to the left closes; a drag from closed opens it
    pb.currentState!.open(menu);
    await settle(t, 600);
    await t.dragFrom(const Offset(330, 420), const Offset(-200, 0));
    await settle(t, 600);
    expect(pb.currentState!.isOpen, isFalse);
    for (var i = 0; i < 10; i++) {
      pb.currentState!.drag(menu, 24);
      await t.pump(const Duration(milliseconds: 16));
    }
    pb.currentState!.dragEnd(0);
    await settle(t, 600);
    expect(pb.currentState!.isOpen, isTrue, reason: 'past the half: it stays open');
    pb.currentState!.close();
    await settle(t, 600);
  });

  testWidgets('(3.120.0) a thing that went well: a card in the MIDDLE of the screen with its words; a tap goes through it; one at a time; gone after its time; "reduce motion" still shows it', (t) async {
    var under = 0, n = 0;
    await t.pumpWidget(host(say: (c) => donePop(c, 'Leave request sent ${++n}', detail: 'It counts when it is approved.'), underTap: () => under++));
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    expect(find.byKey(const Key('done-pop')), findsOneWidget);
    expect(find.text('Leave request sent 1'), findsOneWidget, reason: 'the words are there at once (they come into sight after the tick)');
    expect(find.text('It counts when it is approved.'), findsOneWidget);
    await settle(t, 1100);
    // in the middle of the screen – not at the bottom, not at the top
    final box = t.getRect(find.byKey(const Key('done-pop'))), screen = t.getRect(find.byType(MaterialApp));
    expect((box.center.dy - screen.center.dy).abs() < 2, isTrue, reason: 'its middle is the screen\'s middle');
    expect((box.center.dx - screen.center.dx).abs() < 2, isTrue);
    // it never catches a tap
    await t.tap(find.byKey(const Key('under')));
    await t.pump();
    expect(under, 1, reason: 'the button under the dimmed screen is pressed through it');
    // one at a time
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    expect(find.text('Leave request sent 1'), findsNothing);
    expect(find.text('Leave request sent 2'), findsOneWidget);
    await settle(t, 3000);
    expect(find.byKey(const Key('done-pop')), findsOneWidget, reason: 'still there at 3 s');
    await settle(t, 1000);
    expect(find.byKey(const Key('done-pop')), findsNothing, reason: 'gone by itself after its time');
    // doneClear takes it away at once
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    doneClear();
    await t.pump();
    expect(find.byKey(const Key('done-pop')), findsNothing);
    // reduce motion (the phone's setting): it is still shown, and still goes
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.pumpWidget(host(say: (c) => donePop(c, 'Saved'), underTap: () {}));
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    await settle(t, 400);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing, reason: 'no blur with "reduce motion"');
    await settle(t, 3600);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('pictures: the pop-up of a thing that went well – as the tick draws itself, and when it is there', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(host(say: (c) => donePop(c, 'Leave request sent', detail: 'It counts when it is approved.'), underTap: () {}));
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    await settle(t, 550);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/m5_done_drawing.png'));
    await settle(t, 700);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/m6_done.png'));
    doneClear();
    await t.pump();
  }, tags: ['golden']);

  testWidgets('pictures: the message as it spreads and when it has; the menu behind the page', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(host(say: (c) => gooToast(c, 'Saved – Diesel Issue MH-12-AB-1234, 120 L', stay: const Duration(seconds: 3)), underTap: () {}));
    await t.tap(find.byKey(const Key('say')));
    await t.pump();
    await settle(t, 300);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/m1_drop_falling.png'));
    await settle(t, 300);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/m2_drop_spreading.png'));
    await settle(t, 700);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/m3_message.png'));
    gooClear();
    final pb = GlobalKey<PushBackState>();
    await t.pumpWidget(MaterialApp(home: PushBack(key: pb, child: const Scaffold(backgroundColor: Color(0xFFDCF2E4), body: Center(child: Text('THE PAGE'))))));
    pb.currentState!.open(const Material(type: MaterialType.transparency, child: SafeArea(child: Column(children: [ListTile(title: Text('Diesel')), ListTile(title: Text('Log Book')), ListTile(title: Text('Approvals'))]))));
    await settle(t, 600);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/m4_menu_behind.png'));
  }, tags: ['golden']);
}
