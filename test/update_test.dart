import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/update.dart';

void main() {
  final sha = 'a' * 64;
  Map<String, dynamic> rel({String body = '', List<Map<String, dynamic>>? assets, bool draft = false}) => {
        'name': 'RCL ERP 1.0.1 (102)',
        'draft': draft,
        'prerelease': false,
        'body': body,
        'assets': assets ?? [{'name': 'rcl-erp-1.0.1-102.apk', 'browser_download_url': 'https://github.com/khandagalesuraj48-sys/rcl-mobile/releases/download/v1.0.1-102/rcl-erp-1.0.1-102.apk'}],
      };
  final meta = '<!-- rcl:{"build":102,"version":"1.0.1","sha256":"$sha"} -->';

  test('a newer release: its version, file and fingerprint', () {
    final u = parseRelease(rel(body: 'New: faster lists.\n\n$meta'), 101)!;
    expect(u.build, 102);
    expect(u.version, '1.0.1');
    expect(u.sha256, sha);
    expect(u.url, endsWith('/rcl-erp-1.0.1-102.apk'));
  });
  test('nothing to do: the same or an older build', () {
    expect(parseRelease(rel(body: meta), 102), isNull);
    expect(parseRelease(rel(body: meta), 150), isNull);
  });
  test('not taken: no data line, a wrong fingerprint, a draft, no APK, a file from another site', () {
    expect(parseRelease(rel(body: 'no data'), 1), isNull);
    expect(parseRelease(rel(body: '<!-- rcl:{"build":102,"version":"1.0.1","sha256":"abc"} -->'), 1), isNull);
    expect(parseRelease(rel(body: meta, draft: true), 1), isNull);
    expect(parseRelease(rel(body: meta, assets: [{'name': 'notes.txt', 'browser_download_url': 'https://github.com/x/notes.txt'}]), 1), isNull);
    expect(parseRelease(rel(body: meta, assets: [{'name': 'rcl.apk', 'browser_download_url': 'https://evil.example/rcl.apk'}]), 1), isNull);
  });

  group('(3.19.1) a phone downloads only its own processor\'s file', () {
    final a64 = 'b' * 64, a32 = 'c' * 64, win = 'd' * 64;
    const base = 'https://github.com/khandagalesuraj48-sys/rcl-mobile/releases/download/v3.19.1-123/';
    // the order of the files as GitHub may give it: here a one-processor file comes first
    final files = [
      {'name': 'rcl-erp-3.19.1-123.arm64-v8a.apk', 'browser_download_url': '${base}rcl-erp-3.19.1-123.arm64-v8a.apk'},
      {'name': 'rcl-erp-3.19.1-123.armeabi-v7a.apk', 'browser_download_url': '${base}rcl-erp-3.19.1-123.armeabi-v7a.apk'},
      {'name': 'rcl-erp-3.19.1-123.apk', 'browser_download_url': '${base}rcl-erp-3.19.1-123.apk'},
      {'name': 'RCL-ERP-Setup-3.19.1-123.exe', 'browser_download_url': '${base}RCL-ERP-Setup-3.19.1-123.exe'},
    ];
    final meta = '<!-- rcl:{"build":123,"version":"3.19.1","sha256":"$sha","win":"$win","apk":{"arm64-v8a":"$a64","armeabi-v7a":"$a32"}} -->';
    tearDown(() => appAbi = () => '');
    AppUpdate? on(String abi, {String? body, List<Map<String, dynamic>>? assets}) {
      appAbi = () => abi;
      return parseRelease(rel(body: body ?? meta, assets: assets ?? files), 122);
    }

    test('a 64-bit phone: its own file and fingerprint', () {
      final u = on('arm64-v8a')!;
      expect(u.url, endsWith('/rcl-erp-3.19.1-123.arm64-v8a.apk'));
      expect(u.sha256, a64);
      expect(u.build, 123);
    });
    test('a 32-bit phone: its own file and fingerprint', () {
      final u = on('armeabi-v7a')!;
      expect(u.url, endsWith('/rcl-erp-3.19.1-123.armeabi-v7a.apk'));
      expect(u.sha256, a32);
    });
    test('a processor not known: the file for every phone – never a one-processor file, whatever the order', () {
      final u = on('')!;
      expect(u.url, endsWith('/rcl-erp-3.19.1-123.apk'));
      expect(u.sha256, sha);
    });
    test('a release of before (no one-processor files): the file for every phone, as before', () {
      final u = on('arm64-v8a', body: '<!-- rcl:{"build":123,"version":"3.19.1","sha256":"$sha"} -->', assets: [files[2]])!;
      expect(u.url, endsWith('/rcl-erp-3.19.1-123.apk'));
      expect(u.sha256, sha);
    });
    test('its own file missing or from another site, or its fingerprint wrong: the file for every phone', () {
      expect(on('arm64-v8a', assets: [files[1], files[2]])!.url, endsWith('/rcl-erp-3.19.1-123.apk'));
      expect(on('arm64-v8a', assets: [{'name': 'rcl-erp-3.19.1-123.arm64-v8a.apk', 'browser_download_url': 'https://evil.example/x.apk'}, files[2]])!.url, endsWith('/rcl-erp-3.19.1-123.apk'));
      expect(on('arm64-v8a', body: meta.replaceFirst(a64, 'xyz'))!.sha256, sha);
    });
    test('a computer still takes its setup', () {
      appAbi = () => 'arm64-v8a';
      final u = parseRelease(rel(body: meta, assets: files), 122, computer: true)!;
      expect(u.url, endsWith('/RCL-ERP-Setup-3.19.1-123.exe'));
      expect(u.sha256, win);
    });
  });
  group('(02-11-2026) the beta channel: a tester takes a beta version too; everybody else only the stable one', () {
    const base = 'https://github.com/khandagalesuraj48-sys/rcl-mobile/releases/download/';
    Map<String, dynamic> r(int build, {bool pre = false, bool app = true}) => {
          'name': 'RCL ERP 3.80.0 ($build)',
          'draft': false,
          'prerelease': pre,
          'body': '<!-- rcl-new -->\nNew: X\n<!-- /rcl-new -->\n<!-- rcl:{"build":$build,"version":"3.80.0",${app ? '"sha256":"$sha",' : ''}"web":{"rclerp":"${'1' * 40}"},"app":"${'2' * 40}"} -->',
          'assets': app ? [{'name': 'rcl-erp-3.80.0-$build.apk', 'browser_download_url': '${base}v3.80.0-$build/rcl-erp-3.80.0-$build.apk'}] : <Map<String, dynamic>>[],
        };
    test('a beta version (pre-release): not for everybody, taken by a tester', () {
      expect(parseRelease(r(201, pre: true), 200), isNull);
      final u = parseRelease(r(201, pre: true), 200, beta: true)!;
      expect(u.build, 201);
      expect(u.notes, 'New: X');
    });
    test('a tester: the newest with an app of the list – a version of the web only (no app) is never taken', () {
      final list = [r(204, pre: true, app: false), r(203, pre: true), r(202), r(201, pre: true)];
      expect(newestOf(list, 200)!.build, 203);
      expect(newestOf(list, 203), isNull);
      expect(newestOf([r(205, pre: true, app: false)], 200), isNull);
      expect(newestOf(const [], 200), isNull);
    });
    test('a stable version made from a beta one (no longer a pre-release): everybody takes it', () {
      expect(parseRelease(r(203), 202)!.build, 203);
    });
    test('(3.122.0) the update that MUST be taken: a newer stable version – never a beta one, not one marked "optional"', () {
      expect(parseRelease(r(203), 202)!.must, true, reason: 'a newer stable version is compulsory');
      expect(parseRelease(r(203), 150)!.must, true, reason: 'from far behind: straight to the newest');
      expect(parseRelease(r(203), 203), isNull, reason: 'the same version: nothing to take, nothing closed');
      expect(parseRelease(r(203, pre: true), 202, beta: true)!.must, false, reason: 'a beta version is tried, never forced');
      final free = r(203)..['body'] = (r(203)['body'] as String).replaceFirst('"build":203,', '"build":203,"optional":true,');
      expect(parseRelease(free, 202)!.must, false, reason: 'a release left free by its line');
      // a tester: a newer STABLE one in the list makes it compulsory – he moves on to the newest he may take
      final t = newestOf([r(205, pre: true), r(204), r(203, pre: true)], 203)!;
      expect([t.build, t.must], [205, true]);
      final only = newestOf([r(205, pre: true), r(203)], 203)!;
      expect([only.build, only.must], [205, false], reason: 'only beta versions are newer: his choice');
      expect(newestOf([r(205, pre: true), r(204)], 205), isNull, reason: 'a tester ahead of the stable one is not held');
    });
    testWidgets('(3.122.0) the wall of a compulsory update: one screen, what is new, "Update now"; Back does not close it', (t) async {
      final u = parseRelease(r(203), 202)!;
      await t.pumpWidget(MaterialApp(home: UpdateWall(update: u)));
      await t.pump();
      expect(find.byKey(const Key('update-wall')), findsOneWidget);
      expect(find.byKey(const Key('update-wall-go')), findsOneWidget);
      expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('update-wall-notes')), matching: find.byType(Text))).data, 'New: X');
      expect(t.widget<PopScope>(find.byType(PopScope)).canPop, false);
    });
  });
}
