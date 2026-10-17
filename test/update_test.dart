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
}
