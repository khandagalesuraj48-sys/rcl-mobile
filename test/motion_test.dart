// (3.96.0) the app's motion: the Scale Pop box (ask …) and the page transitions – visual only, the answers exactly as before.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/ui/motion.dart';
import 'package:rcl_mobile/ui/theme.dart';
import 'package:rcl_mobile/ui/widgets.dart';

Widget host(Widget child, {bool still = false}) => MaterialApp(
      theme: appTheme(),
      home: Builder(builder: (c) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: still), child: Scaffold(body: Center(child: child)))),
    );

void main() {
  testWidgets('ask(): the box pops in from 72 % (a small overshoot), answers Yes / Cancel exactly as before, a tap outside = Cancel', (t) async {
    bool? got;
    await t.pumpWidget(host(Builder(builder: (c) => ElevatedButton(onPressed: () async => got = await ask(c, 'Delete this entry?', 'Test only.', yes: 'Delete', danger: true), child: const Text('go')))));
    await t.tap(find.text('go'));
    await t.pump();      // the first frame: the box is there (small, coming in)
    expect(find.text('Delete this entry?'), findsOneWidget);
    double scale() => t.widget<Transform>(find.ancestor(of: find.byType(AlertDialog), matching: find.byType(Transform)).first).transform.getMaxScaleOnAxis();
    expect(scale(), closeTo(.72, .02), reason: 'starts at 72 %');
    await t.pump(const Duration(milliseconds: 160));
    expect(scale(), greaterThan(1.0), reason: 'the small overshoot');
    await t.pumpAndSettle();
    expect(scale(), closeTo(1.0, .001));
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(got, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(5, 5));      // outside the box
    await t.pumpAndSettle();
    expect(got, isFalse, reason: 'a tap outside = Cancel, as with showDialog');
  });

  testWidgets('the phone asks for no animations: the box is there at once, full size', (t) async {
    await t.pumpWidget(host(Builder(builder: (c) => ElevatedButton(onPressed: () => ask(c, 'Q', 'B'), child: const Text('go'))), still: true));
    await t.tap(find.text('go'));
    await t.pump();
    expect(find.text('Q'), findsOneWidget);
    expect(find.ancestor(of: find.byType(AlertDialog), matching: find.byType(Transform)), findsNothing, reason: 'no movement');
  });

  testWidgets('popDialog(barrierDismissible: false): a tap outside does not close it', (t) async {
    await t.pumpWidget(host(Builder(builder: (c) => ElevatedButton(
        onPressed: () => popDialog<void>(context: c, barrierDismissible: false, builder: (d) => AlertDialog(title: const Text('Stay'), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))])),
        child: const Text('go')))));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(find.text('Stay'), findsOneWidget);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Stay'), findsNothing);
  });

  test('every new screen: zoom on Android, the iPhone keeps its own slide (and its swipe back)', () {
    final p = appTheme().pageTransitionsTheme.builders;
    expect(p[TargetPlatform.android], isA<ZoomPageTransitionsBuilder>());
    expect(p[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
  });
}
