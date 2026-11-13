// (3.122.0, the two videos he approved on 14-11-2026) THE MOTION KIT (lib/ui/motion.dart): motion only – a screen, a page of a tab and
// a part of a screen keep everything they hold while they move, every motion ends by itself, a touch goes through to what is touched.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/ui/motion.dart';

Future<void> settle(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

int made = 0;

/// A thing that counts how often it is made anew and holds a number of its own.
class Holder extends StatefulWidget {
  const Holder({super.key, this.name = 'h'});
  final String name;
  @override
  State<Holder> createState() => _HolderState();
}

class _HolderState extends State<Holder> {
  int n = 0;
  @override
  void initState() {
    super.initState();
    made++;
  }

  @override
  Widget build(BuildContext context) => TextButton(key: Key('hold-${widget.name}'), onPressed: () => setState(() => n++), child: Text('${widget.name}:$n'));
}

void main() {
  setUp(() => made = 0);

  testWidgets('a new screen opens out of the touched place; the screen behind and the new one are made ONCE and keep what they hold; Back closes it', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(pageTransitionsTheme: appPageTransitions, platform: TargetPlatform.android),
      home: TapSpot(
        child: Builder(
          builder: (c) => Scaffold(
            body: Column(children: [
              const Holder(name: 'first'),
              TextButton(key: const Key('go'), onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Center(child: Holder(name: 'second'))))), child: const Text('Open')),
            ]),
          ),
        ),
      ),
    ));
    await t.tap(find.byKey(const Key('hold-first')));
    await t.pump();
    expect(find.text('first:1'), findsOneWidget);
    await t.tap(find.byKey(const Key('go')));
    expect(TapSpot.last, isNotNull, reason: 'the touched place is remembered');
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    expect(find.byType(ClipPath), findsWidgets, reason: 'half way: the new screen is a growing circle');
    await settle(t, 800);
    expect(find.text('second:0'), findsOneWidget);
    await t.tap(find.byKey(const Key('hold-second')));
    await settle(t, 200);
    expect(find.text('second:1'), findsOneWidget, reason: 'a touch reaches the screen at rest');
    expect(made, 2, reason: 'each screen was made once – the motion ending did not make one anew');
    Navigator.of(t.element(find.byKey(const Key('hold-second')))).pop();
    await settle(t, 800);
    expect(find.text('first:1'), findsOneWidget, reason: 'the screen behind kept its number');
    expect(find.byKey(const Key('hold-second')), findsNothing);
    expect(made, 2);
  });

  testWidgets('a part that rises, a page of a tab that slides, a button that bounces: what is inside is made once and a touch goes through', (t) async {
    var tab = 0;
    await t.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (c, set) => Scaffold(
          body: Column(children: [
            const Rise(order: 3, child: Holder(name: 'rise')),
            const Rise(order: 1, flip: true, child: Holder(name: 'flip')),
            const Bounce(child: Holder(name: 'bounce')),
            Expanded(child: TabSlide(index: tab, child: IndexedStack(index: tab, children: const [Holder(name: 'p0'), Holder(name: 'p1')]))),
            TextButton(key: const Key('tab'), onPressed: () => set(() => tab = 1 - tab), child: const Text('Tab')),
            Turn(on: tab == 1, child: const Icon(Icons.add)),
          ]),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 60));
    expect(t.widget<Opacity>(find.ancestor(of: find.byKey(const Key('hold-rise')), matching: find.byType(Opacity)).first).opacity, lessThan(1), reason: 'it has not come up yet');
    await settle(t, 1400);
    expect(t.widget<Opacity>(find.ancestor(of: find.byKey(const Key('hold-rise')), matching: find.byType(Opacity)).first).opacity, 1);
    for (final k in ['rise', 'flip', 'bounce', 'p0']) {
      await t.tap(find.byKey(Key('hold-$k')));
      await settle(t, 400);
      expect(find.text('$k:1'), findsOneWidget, reason: '$k takes the touch and keeps its number');
    }
    await t.tap(find.byKey(const Key('tab')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await settle(t, 600);
    await t.tap(find.byKey(const Key('tab')));
    await settle(t, 600);
    expect(find.text('p0:1'), findsOneWidget, reason: 'the page of the first tab kept its number through two changes');
    expect(made, 5, reason: 'nothing was made a second time');
  });

  testWidgets('a number counts up to its value and stops there; with "remove animations" everything stands still', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: CountUp(value: 1350, textKey: const Key('n'), text: (v) => '$v L'))));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.widget<Text>(find.byKey(const Key('n'))).data, isNot('1350 L'), reason: 'on its way');
    await settle(t, 1000);
    expect(t.widget<Text>(find.byKey(const Key('n'))).data, '1350 L');
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Column(children: [CountUp(value: 2.5, textKey: const Key('m'), text: (v) => '$v'), const Rise(order: 5, child: Text('still'))])),
      ),
    ));
    expect(t.widget<Text>(find.byKey(const Key('m'))).data, '2.5');
    expect(find.ancestor(of: find.text('still'), matching: find.byType(Opacity)), findsNothing, reason: 'no motion at all');
  });
}
