// (3.30.0) The seven-segment reader (lib/core/seven.dart) on pictures of LED / LCD displays (test/fixtures/seven): red, green
// and LCD digits, italic and upright, blurred, shaded, tilted, with the decimal point – and the real dashboard photo that ML Kit
// read as 70820 (it shows 7087.0). Printed digits (not a display) are NOT read here (ML Kit's reading stays).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rcl_mobile/core/ocr_read.dart';
import 'package:rcl_mobile/core/scan_rules.dart';
import 'package:rcl_mobile/core/seven.dart';

(Uint8List, int, int) gray(String name) {
  final im = img.decodePng(File('test/fixtures/seven/$name.png').readAsBytesSync())!;
  final g = Uint8List(im.width * im.height);
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      g[y * im.width + x] = im.getPixel(x, y).r.toInt();
    }
  }
  return (g, im.width, im.height);
}

String? read(String name, {int want = 0}) {
  final (g, w, h) = gray(name);
  return readSeven(g, w, h, want: want)?.text;
}

void main() {
  test('displays of every kind: the digits and the decimal point', () {
    const cases = {
      'trip_red': '7087.0', 'odo_red': '45173.4', 'hrs_lcd': '01234.5', 'rate_green': '94.50', 'amount_lcd': '4725.00', 'litre_red': '50.00',
      'all_red': '2468013579', 'small_lcd': '369.12', 'seven_f': '7.7', 'h_blur': '8826.3', 'h_ones': '1111.1', 'h_persp': '3746.8',
      'h_shade': '5072.9', 'h_zeros': '0000.0',
    };
    cases.forEach((name, want) => expect(read(name, want: want.replaceAll('.', '').length), want, reason: name));
  });

  test('the real dashboard photo (ML Kit read 70820 – five digits): 7087.0', () {
    expect(read('real_tight', want: 5), '7087.0');
  });

  test('printed digits are not a display: nothing is read (ML Kit\'s reading stays)', () {
    expect(read('n_font', want: 6), null);
    expect(read('n_font2', want: 4), null);
  });

  test('a word right after the digits ("km") spoils most looks: with ML Kit\'s count nothing doubtful is given', () {
    expect(read('h_km', want: 6), anyOf(isNull, equals('45173.4')));
  });

  test('the choice among the looks: the count ML Kit gave, a point most looks saw, a lost digit supports the longer reading', () {
    expect(pickSeven(const [SevenRead('70870', 3), SevenRead('7087.0', 4), SevenRead('88', 6)], want: 5)?.text, '7087.0');
    expect(pickSeven(const [SevenRead('45173', 10), SevenRead('451734', 3)])?.text, '451734');
    expect(pickSeven(const [SevenRead('45173', 2)]), null, reason: 'fewer than 3 looks');
  });

  test('a line ML Kit read as 70820 gets the segments\' 7087.0 (marked); a printed line stays as ML Kit read it', () {
    final (g, w, h) = gray('real_tight');
    final lines = sevenLines([const OcrLine('70820', left: 20, top: 15, width: 100, height: 30)], (l, t, ww, hh) => Gray(g, w, h));
    expect(lines.single.text, '7087.0');
    expect(lines.single.seven, true);
    expect(meterFrom(lines).km, 7087, reason: 'no earlier reading: the one clear number, with its point');
    final (g2, w2, h2) = gray('n_font2');
    final keep = sevenLines([const OcrLine('1234', left: 0, top: 0, width: 300, height: 70)], (l, t, ww, hh) => Gray(g2, w2, h2));
    expect(keep.single.text, '1234');
    expect(keep.single.seven, false);
  });

  test('the part of the picture for a line: inside the picture, at most about 100 points high', () {
    final g = cropOf(400, 300, (x, y) => (x + y) % 256, -10, 20, 200, 250);
    expect(g!.w * g.h, g.bytes.length);
    expect(g.h <= 100, true);
    expect(g.bytes.first, 20, reason: 'starts at x 0 (not -10), y 20');
    expect(cropOf(400, 300, (x, y) => 0, 395, 10, 50, 50), null, reason: 'too little of it inside');
  });
}
