/* (3.29.0) THE LIVE READING – its rules, without the camera (the tests run them):
 *   Votes     – a reading is taken only when the camera has seen the same number again and again (2 times when it fits the last
 *               reading / litres × rate = amount agreed, else 3 times) – one wrong look of the reader is never taken;
 *               the tenth digit seen on one look is kept (1234 and 1234.5 → 1234.5);
 *   inGuide   – only the text inside the box on the screen is read (the clock, the trip meter … around it are left out);
 *   blurLuma  – a softer copy of the picture for every other look: the segments of an LED / LCD digit join, so the reader sees a
 *               digit and not 7 strokes. */
import 'dart:math' as math;
import 'dart:typed_data';

import 'ocr_read.dart';
import 'seven.dart';

/// One look of the camera: the number read, and whether it is sure (it fits the last reading / the three numbers agreed).
class ScanRead {
  const ScanRead(this.value, {this.sure = false, this.check = ''});
  final double? value;
  final bool sure;
  final String check;
}

class Votes {
  Votes({this.keep = 8});
  final int keep;
  final _seen = <ScanRead>[];

  /// A new look; → the agreed reading, or null (not yet).
  double? add(ScanRead r) {
    final v = r.value;
    if (v == null) return null;
    _seen.add(r);
    while (_seen.length > keep) {
      _seen.removeAt(0);
    }
    final same = _seen.where((x) => x.value!.truncate() == v.truncate()).toList();
    final need = same.any((x) => x.sure) ? 2 : 3;
    return same.length >= need ? _finest(same) : null;
  }

  /// The best guess so far (the reading seen most often; at least twice), for the shutter pressed before the camera agreed.
  double? get best {
    if (_seen.isEmpty) return null;
    final groups = <int, List<ScanRead>>{};
    for (final x in _seen) {
      groups.putIfAbsent(x.value!.truncate(), () => []).add(x);
    }
    final top = groups.values.reduce((a, b) => b.length > a.length ? b : a);
    return top.length >= 2 ? _finest(top) : null;
  }

  /// What the last look said ('' = nothing to say).
  String get check => _seen.isEmpty ? '' : _seen.last.check;

  void clear() => _seen.clear();

  // among looks of the same whole number: the one with its tenth digit (seen most often), else the whole number
  static double _finest(List<ScanRead> same) {
    final count = <double, int>{};
    for (final x in same) {
      count[x.value!] = (count[x.value!] ?? 0) + 1;
    }
    final withPoint = count.keys.where((v) => v != v.truncateToDouble()).toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
    if (withPoint.isNotEmpty) return withPoint.first;
    return count.keys.reduce((a, b) => count[b]! > count[a]! ? b : a);
  }
}

/// A box on the picture, as parts of its width and height (0 … 1).
class Guide {
  const Guide(this.left, this.top, this.width, this.height);
  final double left, top, width, height;
}

/* (3.31.3) THE PHONE TURNED SIDEWAYS (asked 23-10-2026: "jewa user landscap madhe rotate krto tewa pn ha box rotate hoyla hawa"):
 * the scanner's screen stays upright on the phone, and the box turns with the phone – across the meter as the person sees it.
 *   turnOf        – how the phone is held, from its accelerometer (m/s², Android's way; sensors_plus gives the iPhone's the same way);
 *   guideFor      – the box for that way: upright as before; sideways a box as wide as the long side of the picture, in its middle;
 *   guideOnScreen – where that box is drawn on the (upright) screen;
 *   readTurn      – the turn the reader gives the camera's picture so the digits stand upright for the person;
 *   uprightTurn   – the clockwise turn that makes the photo (taken upright on the phone) stand as the person saw it. */

/// How the phone is held: 0 upright, 90 turned to the left (its top to the left – counter-clockwise), 270 turned to the right.
/// [x], [y] = the accelerometer across and along the phone; lying flat or between two ways, [was] is kept (the box does not flicker).
int turnOf(double x, double y, int was) {
  const g = 6.0, margin = 2.0;
  if (x.abs() >= g && x.abs() > y.abs() + margin) return x > 0 ? 90 : 270;
  if (y >= g && y > x.abs() + margin) return 0;
  return was;
}

/// The box for the way the phone is held ([wide] = a dispenser's display). As parts of the picture AS THE PERSON SEES IT.
Guide guideFor(int turn, {bool wide = false}) => turn % 180 == 0
    ? (wide ? const Guide(.06, .24, .88, .46) : const Guide(.07, .36, .86, .2))
    : (wide ? const Guide(.05, .14, .90, .72) : const Guide(.08, .30, .84, .40));

/// Where the box [g] (of the picture as the person sees it) is on the upright screen [w] × [h] when the phone is held [turn].
({double left, double top, double width, double height}) guideOnScreen(Guide g, double w, double h, int turn) {
  if (turn % 180 == 0) return (left: g.left * w, top: g.top * h, width: g.width * w, height: g.height * h);
  // sideways the person sees the screen h wide and w high
  final u0 = g.left * h, u1 = (g.left + g.width) * h, v0 = g.top * w, v1 = (g.top + g.height) * w;
  return turn == 90 ? (left: w - v1, top: u0, width: v1 - v0, height: u1 - u0) : (left: v0, top: h - u1, width: v1 - v0, height: u1 - u0);
}

/// The turn the reader gives the back camera's picture ([sensor] = the camera's own turn) when the phone is held [turn]
/// (Google ML Kit's way: the camera's turn less the phone's).
int readTurn(int sensor, int turn) => ((sensor - turn) % 360 + 360) % 360;

/// The clockwise turn that makes a photo taken upright on the phone stand as the person saw it when the phone was held [turn].
int uprightTurn(int turn) => (360 - turn % 360) % 360;

/// The lines inside the box ([w] × [h] = the upright picture). None inside (the box was missed, or the picture is turned another
/// way on this phone): every line, so the reading still works.
List<OcrLine> inGuide(List<OcrLine> lines, double w, double h, Guide g) {
  if (w <= 0 || h <= 0) return lines;
  final x0 = g.left * w, y0 = g.top * h, x1 = (g.left + g.width) * w, y1 = (g.top + g.height) * h;
  final inside = lines.where((l) {
    final cx = l.left + l.width / 2, cy = l.top + l.height / 2;
    return cx >= x0 && cx <= x1 && cy >= y0 && cy <= y1;
  }).toList();
  return inside.isEmpty ? lines : inside;
}

/// A copy of an NV21 picture ([w] × [h], rows of [w] bytes) whose brightness (the first w × h bytes) is softened over 3 × 3
/// points; the colour part stays as it is.
Uint8List blurLuma(Uint8List nv21, int w, int h) {
  final out = Uint8List.fromList(nv21), tmp = Uint8List(w * h);
  if (w < 3 || h < 3 || nv21.length < w * h) return out;
  for (var y = 0; y < h; y++) {
    final row = y * w;
    tmp[row] = nv21[row];
    tmp[row + w - 1] = nv21[row + w - 1];
    for (var x = 1; x < w - 1; x++) {
      tmp[row + x] = (nv21[row + x - 1] + nv21[row + x] + nv21[row + x + 1]) ~/ 3;
    }
  }
  for (var y = 1; y < h - 1; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      out[row + x] = (tmp[row - w + x] + tmp[row + x] + tmp[row + w + x]) ~/ 3;
    }
  }
  return out;
}

/// (3.30.0) A part of a picture as its brightness, [w] × [h].
class Gray {
  const Gray(this.bytes, this.w, this.h);
  final Uint8List bytes;
  final int w, h;
}

/// The part of the picture to read a line's number from: its box a little bigger (the decimal point, the digits' edges).
({double left, double top, double width, double height}) roiOf(OcrLine l) =>
    (left: l.left - l.height * .15, top: l.top - l.height * .25, width: l.width + l.height * .6, height: l.height * 1.5);

/// (3.30.0) The lines with a number: read again by its segments (seven.dart). ML Kit finds WHERE the number is and counts its
/// digits well; when the segments give a clear reading with as many digits, that reading is the line's (marked [OcrLine.seven]);
/// else ML Kit's stays. [crop] gives the brightness of a part of the picture (the coordinates of the lines), or null.
List<OcrLine> sevenLines(List<OcrLine> lines, Gray? Function(double left, double top, double width, double height) crop) => [
      for (final l in lines) _sevenLine(l, crop) ?? l,
    ];

/// How many digits ML Kit read on a line.
int digitsIn(String text) => RegExp(r'\d').allMatches(cleanLine(text)).length;

/// A line with its number as the segments read it ([text] null = ML Kit's stays).
OcrLine withSeven(OcrLine l, String? text) => text == null ? l : OcrLine(text, left: l.left, top: l.top, width: l.width, height: l.height, seven: true);

OcrLine? _sevenLine(OcrLine l, Gray? Function(double left, double top, double width, double height) crop) {
  final want = digitsIn(l.text);
  if (want < 2 || l.height < 8) return null;
  final r = roiOf(l), g = crop(r.left, r.top, r.width, r.height);
  if (g == null) return null;
  final s = readSeven(g.bytes, g.w, g.h, want: want);
  if (s == null) return null;
  return OcrLine(s.text, left: l.left, top: l.top, width: l.width, height: l.height, seven: true);
}

/// A part of an upright picture of [uw] × [uh] whose brightness is [at] (x, y) – made at most about 100 points high (the reader
/// needs no more; it is quicker).
Gray? cropOf(int uw, int uh, int Function(int x, int y) at, double left, double top, double width, double height) {
  final x0 = math.max(0, left.floor()), y0 = math.max(0, top.floor()), x1 = math.min(uw, (left + width).ceil()), y1 = math.min(uh, (top + height).ceil());
  final cw = x1 - x0, ch = y1 - y0;
  if (cw < 8 || ch < 8) return null;
  final f = math.max(1, (ch / 100).ceil()), ow = cw ~/ f, oh = ch ~/ f;
  if (ow < 8 || oh < 8) return null;
  final out = Uint8List(ow * oh);
  for (var j = 0; j < oh; j++) {
    for (var i = 0; i < ow; i++) {
      out[j * ow + i] = at(x0 + i * f, y0 + j * f);
    }
  }
  return Gray(out, ow, oh);
}
