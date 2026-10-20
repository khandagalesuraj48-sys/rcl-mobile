// (3.29.0) The live reading's rules (lib/core/scan_rules.dart): a number is taken only when the camera has seen it again and
// again; the tenth digit is kept; only the text in the box; a softer copy of the picture for LED / LCD digits.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/ocr_read.dart';
import 'package:rcl_mobile/core/scan_rules.dart';

void main() {
  test('a sure reading (it fits the last one) is taken when seen twice; one wrong look is never taken', () {
    final v = Votes();
    expect(v.add(const ScanRead(45178, sure: true)), null, reason: 'one look only');
    expect(v.add(const ScanRead(null)), null);
    expect(v.add(const ScanRead(45173, sure: true)), null);
    expect(v.add(const ScanRead(45173, sure: true)), 45173);
  });

  test('a reading that is not sure (no last reading, the word only) needs three looks', () {
    final v = Votes();
    expect(v.add(const ScanRead(45.2)), null);
    expect(v.add(const ScanRead(45.2)), null);
    expect(v.add(const ScanRead(45.2)), 45.2);
  });

  test('the tenth digit seen on one look is kept: 1234 and 1234.5 → 1234.5', () {
    final v = Votes();
    v.add(const ScanRead(1234, sure: true));
    expect(v.add(const ScanRead(1234.5, sure: true)), 1234.5);
  });

  test('the shutter before an agreement: the reading seen most often (twice at least), else none', () {
    final v = Votes();
    v.add(const ScanRead(50));
    expect(v.best, null);
    v.add(const ScanRead(500));
    v.add(const ScanRead(50));
    expect(v.best, 50);
  });

  test('only the text in the box (the upright picture); nothing in it → every line', () {
    const g = Guide(.1, .4, .8, .2);
    final lines = [const OcrLine('12:45', left: 10, top: 10, width: 100, height: 40), const OcrLine('45173', left: 300, top: 600, width: 200, height: 60)];
    expect(inGuide(lines, 720, 1280, g).map((l) => l.text), ['45173']);
    expect(inGuide([lines.first], 720, 1280, g).map((l) => l.text), ['12:45']);
  });

  test('the softer copy: the brightness is softened over 3 × 3, the colour part stays', () {
    const w = 4, h = 3;
    final nv = Uint8List(w * h + w * h ~/ 2);
    nv[1 * w + 1] = 90; // one bright point
    for (var i = w * h; i < nv.length; i++) {
      nv[i] = 128;
    }
    final out = blurLuma(nv, w, h);
    expect(out[1 * w + 1], 10, reason: '90 spread over 9 points');
    expect(out[1 * w + 2], 10);
    expect(out.sublist(w * h).every((b) => b == 128), true);
    expect(nv[1 * w + 1], 90, reason: 'the picture itself is not changed');
  });
}
