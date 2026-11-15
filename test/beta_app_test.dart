// (15-11-2026, his decisions: "Beta testing must use a separate Test Database"; "Beta Testers must also receive every Stable release";
// "beta eligibility is additional access") TWO APPS from the same code: Sketchline (everybody, testers too) and Sketchline Beta (the
// testers' app – the Portal gives it only the modules' beta copies on the Beta TEST database). Here: what the app itself does.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/config.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/push.dart' show betaTopic;
import 'package:rcl_mobile/core/session.dart';
import 'package:rcl_mobile/ui/beta_mark.dart';

import 'fake_server.dart';

void main() {
  late FakeServer srv;
  Session make({required bool beta}) => Session(Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: srv.client, beta: beta));
  setUp(() => srv = FakeServer());

  test('the Sketchline app (built without RCL_CHANNEL): says nothing of a channel – a tester gets his stable links, as everybody', () async {
    expect(kBetaApp, false, reason: 'only beta.yml builds the Beta app');
    srv.tester = true;
    final s = make(beta: false);
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    expect(s.stage, Stage.ready);
    expect(srv.channels.toSet(), {''});
  });

  test('the Sketchline Beta app: every Portal call says "beta" (the sign-in, its sites, the tickets); a tester opens his site', () async {
    srv.tester = true;
    final s = make(beta: true);
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    expect(s.stage, Stage.ready);
    expect(srv.calls, containsAllInOrder(['portal:login', 'portal:me', 'portal:go:mechanical:S1']));
    expect(srv.channels.toSet(), {'beta'});
  });

  test('the Sketchline Beta app of somebody who is not a tester: nothing opens, he is told to use Sketchline', () async {
    final s = make(beta: true);
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    expect(s.stage, Stage.signedOut);
    expect(s.error, contains('Sketchline Beta is only for testers'));
    expect(srv.calls, isNot(contains(startsWith('portal:go'))), reason: 'no ticket for any module');
  });

  test('the beta versions are told only to the Beta app of a tester – a tester\'s Sketchline app takes the stable ones like everybody', () {
    expect([betaTopic(true), betaTopic(true, betaApp: true), betaTopic(false, betaApp: true), betaTopic(false)], [false, true, false, false]);
  });

  testWidgets('the Beta app: a BETA ribbon over every screen and its own name; Sketchline: none', (t) async {
    await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: betaMark(const SizedBox.expand(), on: true)));
    expect(find.byKey(const Key('beta-mark')), findsOneWidget);
    expect(t.widget<Banner>(find.byType(Banner)).message, 'BETA');
    await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: betaMark(const SizedBox.expand())));
    expect(find.byType(Banner), findsNothing);
    expect([appTitle(), appTitle(beta: true)], ['Sketchline', 'Sketchline Beta']);
  });

  test('only beta.yml builds the Beta app: its own id and name, the BETA icon, "rclb", the SQL steps; release.yml builds the stable one from the tested commit', () {
    final b = File('.github/workflows/beta.yml').readAsStringSync(), r = File('.github/workflows/release.yml').readAsStringSync();
    expect(b, contains('RCL_CHANNEL: beta'));
    expect(RegExp('--dart-define=RCL_CHANNEL=beta').allMatches(b).length, 2, reason: 'the file for every phone and each processor\'s');
    expect(b, contains('python3 tool/beta_icon.py'));
    expect(b, contains("package: name='in.rachana.rcl.rcl_mobile.beta'"));
    expect(b, contains(r'printf "\n<!-- rclb:%s -->\n" "$META"'));
    expect(b, isNot(contains(r'<!-- rcl:%s -->')));
    expect(b, contains('rcl-engineering rcl-hr; do'));
    expect(b, contains('RCL_APP=beta timeout 1800 python3 tool/release_patches.py'));
    expect(r, isNot(contains('RCL_CHANNEL')), reason: 'the stable app never with the beta id');
    expect(r, contains('main (%s) is not the commit the testers had'));
    expect(File('tool/release_patches.py').readAsStringSync(), contains("mine = '<!-- rclb:' if os.environ.get('RCL_APP') == 'beta' else '<!-- rcl:'"));
  });
}
