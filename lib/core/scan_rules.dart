/* (3.29.0) THE LIVE READING – its rules, without the camera (the tests run them):
 *   Votes     – a reading is taken only when the camera has seen the same number again and again (2 times when it fits the last
 *               reading / litres × rate = amount agreed, else 3 times) – one wrong look of the reader is never taken;
 *               the tenth digit seen on one look is kept (1234 and 1234.5 → 1234.5);
 *   inGuide   – only the text inside the box on the screen is read (the clock, the trip meter … around it are left out);
 *   blurLuma  – a softer copy of the picture for every other look: the segments of an LED / LCD digit join, so the reader sees a
 *               digit and not 7 strokes. */
import 'dart:typed_data';

import 'ocr_read.dart';

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
