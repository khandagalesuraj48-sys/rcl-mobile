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
}
