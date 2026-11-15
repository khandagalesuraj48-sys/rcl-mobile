// (3.126.0, asked 15-11-2026: "app updet krtana je kahi new updet aley tech fkt updet hoil … pratek weli full app download krayla ka
// lawatoys") THE SMALL UPDATE (lib/core/apk_patch.dart, tool/apk_patch.py): the new app file is made from the one on the phone and a
// small file with only what changed – byte for byte the released one; a patch that is not one, is cut short or does not fit the
// file on the phone never passes; the release names the builds it has a small update for and the app takes only its own.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/apk_patch.dart';
import 'package:rcl_mobile/core/update.dart';

/// Bytes that look like nothing in particular – the same in tool/apk_patch.py's check (the fixture below was made from them).
Uint8List lcg(int n, int seed) {
  final out = Uint8List(n);
  var x = seed;
  for (var i = 0; i < n; i++) {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    out[i] = (x >> 16) & 255;
  }
  return out;
}

List<int> i64(int v) => (ByteData(8)..setInt64(0, v, Endian.little)).buffer.asUint8List();

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('rcl_patch'));
  tearDown(() => dir.deleteSync(recursive: true));
  String put(String name, List<int> b) => (File('${dir.path}/$name')..writeAsBytesSync(b)).path;
  List<int> got(String name) => File('${dir.path}/$name').readAsBytesSync();

  // the two "app files" the release's tool made the patch below from: python3 tool/apk_patch.py make old new patch
  final old = lcg(3000, 7);
  final neu = Uint8List.fromList([...old.sublist(0, 1200), ...ascii.encode('SKETCHLINE - only what changed'), ...old.sublist(1100, 3000), ...lcg(40, 99)]);
  for (final k in [5, 700, 2500]) {
    neu[k] = (neu[k] + 3) & 255;
  }
  final toolPatch = base64Decode('UkNMUDEKeNpL4mEAgw0sEFoOQjHM+Q8BYA4zwygYBUMOjCbbkQeCvV1DnD18PP1cFXQV8vNyKhXKMxJLFJIzEvPSU1Ny2CGqNEYDahSMglEwWj+OglFAV7Bh75IXnKE+'
      'r/ku51RkFKxSnLu/65tjcsX8OxOn2MzytP+7NTizYfGfme8AN3spUQ==');

  test('a patch made by the release\'s tool: the new file is byte for byte the released one (its fingerprint)', () {
    expect(sha256.convert(neu).toString(), 'ae6db7a11bf649ec1855a74c45b1bfbd249421e5b73a0c0fe923c00ef6c28fca', reason: 'the same files as the tool had');
    expect(toolPatch.length, lessThan(neu.length ~/ 10), reason: 'only what changed');
    applyPatch(put('old.apk', old), put('p.patch', toolPatch), '${dir.path}/new.apk');
    expect(got('new.apk'), neu);
  });

  test('a big file, in pieces: copied parts, changed bytes, new bytes, a jump back in the old file', () {
    final o = lcg(400000, 3), add1 = Uint8List(150000), add2 = Uint8List(200000), extra = lcg(70000, 11);
    add1[10] = 7;
    add1[149999] = 250;
    add2[65536] = 1;
    final plain = <int>[...i64(150000 + 70000 + 200000), ...i64(150000), ...i64(70000), ...i64(-100000), ...add1, ...extra, ...i64(200000), ...i64(0), ...i64(0), ...add2];
    final want = Uint8List(420000);
    for (var k = 0; k < 150000; k++) {
      want[k] = (o[k] + add1[k]) & 255;
    }
    want.setRange(150000, 220000, extra);
    for (var k = 0; k < 200000; k++) {
      want[220000 + k] = (o[50000 + k] + add2[k]) & 255; // the place in the old file: 150000 − 100000
    }
    applyPatch(put('old.apk', o), put('p.patch', [...ascii.encode('RCLP1\n'), ...zlib.encode(plain)]), '${dir.path}/new.apk');
    expect(sha256.convert(got('new.apk')), sha256.convert(want));
  });

  test('not a patch, cut short, or another app file on the phone: never a file that passes', () {
    final o = put('old.apk', old), out = '${dir.path}/new.apk';
    expect(() => applyPatch(o, put('a.patch', ascii.encode('<html>not found</html>')), out), throwsA(isA<PatchProblem>()));
    expect(() => applyPatch(o, put('b.patch', toolPatch.sublist(0, 4)), out), throwsA(isA<PatchProblem>()));
    expect(() => applyPatch(o, put('c.patch', toolPatch.sublist(0, toolPatch.length - 30)), out), throwsA(anything), reason: 'cut short');
    // a shorter app file (not the one the patch was made from): it does not fit
    expect(() => applyPatch(put('short.apk', old.sublist(0, 900)), put('p.patch', toolPatch), out), throwsA(isA<PatchProblem>()));
    // another app file of the same size: a file is made, but it is not the released one – its fingerprint says so (update.dart checks it)
    applyPatch(put('other.apk', lcg(3000, 8)), put('p.patch', toolPatch), out);
    expect(sha256.convert(got('new.apk')).toString(), isNot('ae6db7a11bf649ec1855a74c45b1bfbd249421e5b73a0c0fe923c00ef6c28fca'));
  });

  test('the release: a phone takes the small update of its OWN build only – listed and there; otherwise the whole file as before', () {
    final was = appAbi;
    appAbi = () => 'arm64-v8a';
    addTearDown(() => appAbi = was);
    String at(String f) => 'https://github.com/o/r/releases/download/v3.126.0-216/$f';
    Map<String, dynamic> rel(Object? patch) => {
          'name': 'Sketchline 3.126.0 (216)',
          'body': 'x\n<!-- rcl:${jsonEncode({'build': 216, 'version': '3.126.0', 'sha256': 'a' * 64, 'apk': {'arm64-v8a': 'b' * 64, 'armeabi-v7a': 'c' * 64}, if (patch != null) 'patch': patch})} -->',
          'assets': [
            for (final f in ['rcl-erp-3.126.0-216.apk', 'rcl-erp-3.126.0-216.arm64-v8a.from-215.patch', 'rcl-erp-3.126.0-216.armeabi-v7a.from-214.patch', 'rcl-erp-3.126.0-216.arm64-v8a.apk', 'rcl-erp-3.126.0-216.armeabi-v7a.apk'])
              {'name': f, 'browser_download_url': at(f)},
          ],
        };
    final list = {'arm64-v8a': [215, 214], 'armeabi-v7a': [214]};
    final u = parseRelease(rel(list), 215)!;
    expect([u.url, u.sha256, u.patch], [at('rcl-erp-3.126.0-216.arm64-v8a.apk'), 'b' * 64, at('rcl-erp-3.126.0-216.arm64-v8a.from-215.patch')]);
    expect(u.asMust().patch, u.patch);
    expect(parseRelease(rel(list), 214)!.patch, '', reason: 'listed, but the file is not in the release');
    expect(parseRelease(rel(list), 213)!.patch, '', reason: 'an older build: the whole file');
    expect(parseRelease(rel(null), 215)!.patch, '', reason: 'a release without small updates');
    expect(parseRelease(rel('x'), 215)!.url, at('rcl-erp-3.126.0-216.arm64-v8a.apk'));
    appAbi = () => 'armeabi-v7a';
    expect(parseRelease(rel(list), 214)!.patch, at('rcl-erp-3.126.0-216.armeabi-v7a.from-214.patch'));
    expect(parseRelease(rel(list), 215)!.patch, '');
  });
}
