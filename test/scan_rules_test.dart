// (3.29.0) The live reading's rules (lib/core/scan_rules.dart): a number is taken only when the camera has seen it again and
// again; the tenth digit is kept; only the text in the box; a softer copy of the picture for LED / LCD digits.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as pic;
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

  // ---------- (3.31.3) the phone held sideways: the box turns with the phone ----------
  test('(3.31.3) how the phone is held, from its accelerometer: upright, to the left, to the right; flat or in between – as it was', () {
    expect(turnOf(0.2, 9.8, 90), 0, reason: 'upright');
    expect(turnOf(9.8, 0.3, 0), 90, reason: 'its top to the left (counter-clockwise)');
    expect(turnOf(-9.7, 0.5, 0), 270, reason: 'its top to the right');
    expect(turnOf(0.3, 0.2, 90), 90, reason: 'lying flat: kept');
    expect(turnOf(7, 6.5, 0), 0, reason: 'between two ways: kept – no flicker');
    expect(turnOf(7, 6.5, 270), 270);
    expect(turnOf(0.1, -9.8, 0), 0, reason: 'upside down: kept');
  });

  test('(3.31.3) the box: upright as before; sideways it lies across the screen as the person sees it, inside the picture, the same both ways', () {
    for (final wide in [false, true]) {
      final up = guideFor(0, wide: wide), was = wide ? const Guide(.06, .24, .88, .46) : const Guide(.07, .36, .86, .2);
      expect([up.left, up.top, up.width, up.height], [was.left, was.top, was.width, was.height], reason: 'upright: the box of before');
      final s0 = guideOnScreen(up, 360, 640, 0);
      expect([s0.left, s0.top, s0.width, s0.height], [was.left * 360, was.top * 640, was.width * 360, was.height * 640]);
      final g = guideFor(90, wide: wide);
      expect(g.width > g.height, true, reason: 'wide across the meter as the person sees it');
      final a = guideOnScreen(g, 360, 640, 90), b = guideOnScreen(g, 360, 640, 270);
      expect(a.height > a.width, true, reason: 'on the upright screen it stands – it turned with the phone');
      expect(a.left >= 0 && a.top >= 0 && a.left + a.width <= 360.001 && a.top + a.height <= 640.001, true, reason: 'inside the picture');
      expect([a.left, a.top, a.width, a.height].map((v) => v.toStringAsFixed(3)).toList(), [b.left, b.top, b.width, b.height].map((v) => v.toStringAsFixed(3)).toList(),
          reason: 'turned left or right: the same place (the box is in the middle)');
      // as the person sees it (the screen turned back): the box's own parts of the picture
      expect((a.height / 640).toStringAsFixed(3), g.width.toStringAsFixed(3));
      expect((a.width / 360).toStringAsFixed(3), g.height.toStringAsFixed(3));
    }
  });

  test('(3.31.3) a point of the box as the person sees it is on the screen where the box is drawn (turned left and right)', () {
    const w = 360.0, h = 640.0;
    final g = guideFor(90);
    // the person's picture is h wide and w high; its point (u, v) is on the screen at: left turn (w − v, u), right turn (v, h − u)
    for (final t in [90, 270]) {
      final box = guideOnScreen(g, w, h, t);
      for (final p in [(g.left + .01, g.top + .01), (g.left + g.width - .01, g.top + g.height - .01), (g.left + g.width / 2, g.top + g.height / 2)]) {
        final u = p.$1 * h, v = p.$2 * w;
        final x = t == 90 ? w - v : v, y = t == 90 ? u : h - u;
        expect(x >= box.left && x <= box.left + box.width && y >= box.top && y <= box.top + box.height, true, reason: 'turn $t, point $p');
      }
    }
  });

  test('(3.31.3) the reader stands the picture up the way the phone is held; the photo is turned the same way', () {
    expect(readTurn(90, 0), 90, reason: 'upright: the camera\'s own turn, as before');
    expect(readTurn(90, 90), 0, reason: 'turned to the left: the camera\'s picture is already upright for the person');
    expect(readTurn(90, 270), 180);
    expect(readTurn(270, 0), 270);
    expect(readTurn(270, 90), 180);
    expect(uprightTurn(0), 0);
    expect(uprightTurn(90), 270, reason: 'top to the left: the photo turned back a quarter (counter-clockwise)');
    expect(uprightTurn(270), 90);
    // the same turn both ways: the reader's turn of the camera's picture = the camera's turn, then the photo's turn
    for (final s in [90, 270]) {
      for (final t in [0, 90, 270]) {
        expect(readTurn(s, t), (s + uprightTurn(t)) % 360, reason: 'sensor $s, phone $t');
      }
    }
  });

  test('(3.31.3) the photo of a phone held to the left: what was at its right (the meter\'s top as the person saw it) comes to the top', () {
    // the phone's top to the left: the person's "up" is the right side of the photo the camera keeps upright on the phone
    final im = pic.Image(width: 4, height: 6); // upright on the phone: 4 wide, 6 high
    for (var y = 0; y < 6; y++) {
      im.setPixelRgb(3, y, 255, 255, 255); // its right column white
    }
    final up = pic.copyRotate(im, angle: uprightTurn(90));
    expect([up.width, up.height], [6, 4], reason: 'as the person saw it: wide');
    expect(List.generate(6, (x) => up.getPixel(x, 0).r.toInt()), List.filled(6, 255), reason: 'the white side is on top');
    expect(List.generate(6, (x) => up.getPixel(x, 3).r.toInt()), List.filled(6, 0));
    // to the right: the left side comes to the top
    final im2 = pic.Image(width: 4, height: 6);
    for (var y = 0; y < 6; y++) {
      im2.setPixelRgb(0, y, 255, 255, 255);
    }
    final up2 = pic.copyRotate(im2, angle: uprightTurn(270));
    expect(List.generate(6, (x) => up2.getPixel(x, 0).r.toInt()), List.filled(6, 255));
  });
}
