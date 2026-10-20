/* (3.30.0) THE SEVEN-SEGMENT READER (asked 20-10-2026, with the photo of a dashboard "7087.0" that the app read as 70820: "HE BGH
 * AS HOTE BARYA PAIKI FAST AAHE HE BUT AJUN PN PERFECT NAHI"). An LED / LCD display's digits are 7 bars (segments) and a dot – a
 * text reader (ML Kit) finds WHERE the number is, but it often reads such digits wrongly (a "7." became a "2") and loses the
 * point. This reads the digits by their segments, on the phone:
 *   – the picture of the number's line (brightness only) is split into on / off at a few thresholds (the plain one, and the ones
 *     between a glowing LED's core and its glow – or an LCD's digits and their shade);
 *   – the digits are found by their columns (the slant of italic digits taken off, a few slants tried; a tilted picture's line
 *     straightened), each digit's 7 segments looked at; a dot low down between two digits is the decimal point;
 *   – a digit counts only when its segments are clearly on or off (a printed digit has its strokes in between – it is not read
 *     here, ML Kit's reading stays);
 *   – the reading most of those looks agree on – with as many digits as ML Kit counted – is the one taken.
 * Plain Dart (no phone needed): the tests run it on pictures of displays (test/fixtures/seven). A JavaScript copy of the same
 * rules was checked on 19 pictures before (the photo of the "7087.0" among them). */
import 'dart:math' as math;
import 'dart:typed_data';

const _seg = {'0': 'abcdef', '1': 'bc', '2': 'abdeg', '3': 'abcdg', '4': 'bcfg', '5': 'acdfg', '6': 'acdefg', '7': 'abc', '8': 'abcdefg', '9': 'abcdfg'};
const _alt = [('7', 'abcf'), ('9', 'abcfg'), ('6', 'cdefg'), ('1', 'ef')];
final List<(String, List<int>)> _pats = [
  for (final e in _seg.entries) (e.key, [for (final c in 'abcdefg'.split('')) e.value.contains(c) ? 1 : 0]),
  for (final a in _alt) (a.$1, [for (final c in 'abcdefg'.split('')) a.$2.contains(c) ? 1 : 0]),
];
// where each segment is, as parts of the digit's width and height: x0, x1, y0, y1
const _reg = [
  [.28, .72, 0.0, .18], // a
  [.7, 1.0, .14, .4], // b
  [.7, 1.0, .6, .86], // c
  [.28, .72, .82, 1.0], // d
  [0.0, .3, .6, .86], // e
  [0.0, .3, .14, .4], // f
  [.28, .72, .41, .59], // g
];
const _slants = [0.0, .05, .1, .15, .2, .25];

int _round(double v) => (v + .5).floor(); // as JavaScript's Math.round (the checked copy)

/// The threshold that splits the brightness between [lo] and [hi] best (Otsu); -1 = none.
int otsu(Uint8List g, int lo, int hi) {
  final h = Int32List(256);
  var n = 0;
  for (final v in g) {
    if (v >= lo && v <= hi) {
      h[v]++;
      n++;
    }
  }
  if (n == 0) return -1;
  var sum = 0.0;
  for (var i = 0; i < 256; i++) {
    sum += i * h[i];
  }
  var sB = 0.0, wB = 0, best = -1.0, t = -1;
  for (var i = 0; i < 256; i++) {
    wB += h[i];
    if (wB == 0) continue;
    final wF = n - wB;
    if (wF == 0) break;
    sB += i * h[i];
    final mB = sB / wB, mF = (sum - sB) / wF, v = wB * wF * (mB - mF) * (mB - mF);
    if (v > best) {
      best = v;
      t = i;
    }
  }
  return t;
}

class _Part {
  _Part(this.px, this.x0, this.y0, this.x1, this.y1);
  final List<int> px;
  final int x0, y0, x1, y1;
  int get area => px.length;
}

// the parts (8-connected) of the picture at threshold t
List<_Part> _parts(Uint8List g, int w, int h, int t, bool bright) {
  final n = w * h, on = Uint8List(n);
  for (var i = 0; i < n; i++) {
    on[i] = bright ? (g[i] > t ? 1 : 0) : (g[i] <= t ? 1 : 0);
  }
  final lab = Int32List(n)..fillRange(0, n, -1);
  final out = <_Part>[], st = <int>[];
  for (var i = 0; i < n; i++) {
    if (on[i] == 0 || lab[i] >= 0) continue;
    final id = out.length, px = <int>[];
    var x0 = w, y0 = h, x1 = -1, y1 = -1;
    st.add(i);
    lab[i] = id;
    while (st.isNotEmpty) {
      final p = st.removeLast();
      px.add(p);
      final x = p % w, y = p ~/ w;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
      for (var dy = -1; dy <= 1; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx;
          if (nx < 0 || nx >= w) continue;
          final q = ny * w + nx;
          if (on[q] == 1 && lab[q] < 0) {
            lab[q] = id;
            st.add(q);
          }
        }
      }
    }
    out.add(_Part(px, x0, y0, x1, y1));
  }
  return out;
}

class _Glyph {
  _Glyph(this.ch, this.xa, this.xb, this.top, this.bottom, {this.exact = false, this.margin = 0});
  final String ch; // '' = not a digit (a word, a mark), '?' = not clear
  final int xa, xb;
  final double top, bottom;
  final bool exact;
  final double margin;
  bool dp = false;
  bool get digit => ch.isNotEmpty && ch != '?';
}

class _Row {
  _Row(this.text, this.ok, this.digits);
  final String text;
  final bool ok;
  final int digits;
}

// the digits of one row (points xs / ys) at slant k
List<_Glyph> _glyphs(List<int> xs, List<double> ys, double k) {
  var yb = -1e9, yt = 1e9;
  for (final y in ys) {
    if (y > yb) yb = y;
    if (y < yt) yt = y;
  }
  final hd = yb - yt + 1;
  double xd(int i) => xs[i] - k * (yb - ys[i]);
  final cols = <int>{};
  for (var i = 0; i < xs.length; i++) {
    if (ys[i] < yb - hd * .2) cols.add(_round(xd(i)));
  }
  final keys = cols.toList()..sort();
  final runs = <List<int>>[];
  for (final c in keys) {
    if (runs.isNotEmpty && c - runs.last[1] <= math.max(1, hd * .03)) {
      runs.last[1] = c;
    } else {
      runs.add([c, c]);
    }
  }
  final out = <_Glyph>[];
  for (final r in runs) {
    final xa = r[0], xb = r[1];
    final gp = <int>[];
    for (var i = 0; i < xs.length; i++) {
      final v = xd(i);
      if (v >= xa - .5 && v <= xb + .5) gp.add(i);
    }
    if (gp.isEmpty) continue;
    var t0 = 1e9, t1 = -1e9;
    for (final i in gp) {
      if (ys[i] < t0) t0 = ys[i];
      if (ys[i] > t1) t1 = ys[i];
    }
    final gy0 = t0.floor(), gy1 = t1.ceil(), gh = gy1 - gy0 + 1, gw = xb - xa + 1;
    if (gh < hd * .6) {
      out.add(_Glyph('', xa, xb, t0, t1));
      continue;
    }
    if (gw < gh * .3) {
      out.add(_Glyph('1', xa, xb, t0, t1, exact: true, margin: 1));
      continue;
    }
    final mw = gw + 2, mk = Uint8List(mw * gh);
    for (final i in gp) {
      final xx = _round(xd(i) - xa), yy = _round(ys[i] - gy0);
      if (xx >= 0 && xx < mw && yy >= 0 && yy < gh) mk[yy * mw + xx] = 1;
    }
    double frac(List<double> q) {
      var c = 0, s = 0;
      for (var yy = (q[2] * gh).floor(); yy < (q[3] * gh).ceil(); yy++) {
        for (var xx = (q[0] * gw).floor(); xx < (q[1] * gw).ceil(); xx++) {
          c++;
          s += mk[yy * mw + xx];
        }
      }
      return c == 0 ? 0 : s / c;
    }

    final fr = [for (final q in _reg) frac(q)], bb = [for (final v in fr) v > .3 ? 1 : 0];
    // how clearly each segment is on or off: a seven-segment digit is clear, a printed one has its strokes in between
    final ons = fr.where((v) => v > .3), offs = fr.where((v) => v <= .3);
    final margin = (ons.isEmpty ? 1.0 : ons.reduce(math.min)) - (offs.isEmpty ? 0.0 : offs.reduce(math.max));
    var ch = '?', bd = 9;
    for (final p in _pats) {
      var dd = 0;
      for (var i = 0; i < 7; i++) {
        if (p.$2[i] != bb[i]) dd++;
      }
      if (dd < bd) {
        bd = dd;
        ch = p.$1;
      }
    }
    out.add(_Glyph(bd <= 1 ? ch : '?', xa, xb, t0, t1, exact: bd == 0, margin: margin));
  }
  // the decimal point: a dot low down between two digits
  for (var i = 0; i + 1 < out.length; i++) {
    if (out[i].ch.isEmpty || out[i + 1].ch.isEmpty) continue;
    var c = 0;
    for (var j = 0; j < xs.length; j++) {
      final v = xd(j);
      if (ys[j] >= yb - hd * .25 && v > out[i].xb + .5 && v < out[i + 1].xa - .5) c++;
    }
    if (c >= math.max(3, hd * hd * .003)) {
      out[i].dp = true;
      break;
    }
  }
  return out;
}

double _median(List<double> a) {
  final b = [...a]..sort();
  return b.isEmpty ? 0 : b[b.length ~/ 2];
}

// one look: the main row of digits at slant k (ok: every digit exactly a digit's segments, and clearly so)
_Row? _readRow(List<_Part> parts, int w, int h, double k) {
  final big = parts.where((c) => c.area >= 4 && (c.y1 - c.y0) < h * .97 && (c.x1 - c.x0) < w * .97).toList();
  if (big.isEmpty) return null;
  // the rows: bands of lines with parts; a gap smaller than a third of a band (the middle of a "1") does not split one
  final rowOn = Int32List(h);
  for (final c in big) {
    for (var y = c.y0; y <= c.y1; y++) {
      rowOn[y]++;
    }
  }
  final bands = <List<int>>[];
  var y = 0;
  while (y < h) {
    if (rowOn[y] == 0) {
      y++;
      continue;
    }
    var e = y;
    while (e + 1 < h && rowOn[e + 1] > 0) {
      e++;
    }
    if (bands.isNotEmpty && y - bands.last[1] - 1 <= math.max(2, math.max(bands.last[1] - bands.last[0] + 1, e - y + 1) * .35)) {
      bands.last[1] = e;
    } else {
      bands.add([y, e]);
    }
    y = e + 1;
  }
  _Row? best;
  for (final b in bands) {
    final inRow = big.where((c) {
      final cy = (c.y0 + c.y1) / 2;
      return cy >= b[0] && cy <= b[1];
    }).toList();
    if (inRow.isEmpty) continue;
    final h0 = inRow.map((c) => c.y1).reduce(math.max) - inRow.map((c) => c.y0).reduce(math.min) + 1;
    if (h0 < 8) continue;
    final xs = <int>[], ys = <double>[];
    for (final c in inRow) {
      if (c.area < math.max(4, h0 * h0 * .002)) continue;
      for (final p in c.px) {
        xs.add(p % w);
        ys.add((p ~/ w).toDouble());
      }
    }
    if (xs.isEmpty) continue;
    var out = _glyphs(xs, ys, k);
    // a tilted picture: the line through the digits' tops and bottoms, taken off (then the digits once more)
    final tall = out.where((o) => o.digit).toList();
    if (tall.length >= 3) {
      double fit(double Function(_Glyph) sel) {
        final gx = [for (final o in tall) (o.xa + o.xb) / 2], gy = [for (final o in tall) sel(o)];
        final n = gx.length, mx = gx.reduce((a, b) => a + b) / n, my = gy.reduce((a, b) => a + b) / n;
        var a = 0.0, bb = 0.0;
        for (var i = 0; i < n; i++) {
          a += (gx[i] - mx) * (gy[i] - my);
          bb += (gx[i] - mx) * (gx[i] - mx);
        }
        return bb == 0 ? 0 : a / bb;
      }

      final m = (fit((o) => o.bottom) + fit((o) => o.top)) / 2;
      if (m.abs() >= .015 && m.abs() <= .25) {
        final x0 = xs.reduce(math.min);
        for (var i = 0; i < xs.length; i++) {
          ys[i] = ys[i] - m * (xs[i] - x0);
        }
        out = _glyphs(xs, ys, k);
      }
    }
    // the longest run of digits – a mark at the side (a needle, a word) is left out
    var bi = 0, bl = 0;
    for (var i = 0; i < out.length; i++) {
      var j = i;
      while (j < out.length && out[j].digit) {
        j++;
      }
      if (j - i > bl) {
        bl = j - i;
        bi = i;
      }
      i = j;
    }
    if (bl == 0) continue;
    final run = out.sublist(bi, bi + bl);
    final text = StringBuffer();
    for (var i = 0; i < run.length; i++) {
      text.write(run[i].ch);
      if (run[i].dp && i < run.length - 1) text.write('.');
    }
    final ms = [for (final o in run) o.margin];
    final r = _Row(text.toString(), run.every((o) => o.exact) && _median(ms) >= .35 && ms.reduce(math.min) >= .12, bl);
    if (best == null || r.digits > best.digits) best = r;
  }
  return best;
}

/// One reading of the display and how many looks gave it.
class SevenRead {
  const SevenRead(this.text, this.votes);
  final String text;
  final int votes;
}

/// The readings of many looks (a few thresholds × a few slants), most votes first. [gray] = brightness, w × h.
List<SevenRead> sevenLooks(Uint8List gray, int w, int h) {
  final t1 = otsu(gray, 0, 255);
  if (t1 < 0 || w < 8 || h < 8) return const [];
  var above = 0;
  for (final v in gray) {
    if (v > t1) above++;
  }
  final bright = above <= gray.length / 2, t2 = bright ? otsu(gray, t1 + 1, 255) : otsu(gray, 0, t1 - 1);
  final ts = t2 < 0 ? [t1] : [t1, _round(t1 * .67 + t2 * .33), _round(t1 * .33 + t2 * .67), t2];
  final votes = <String, int>{};
  for (final t in ts) {
    final ps = _parts(gray, w, h, t, bright);
    for (final k in _slants) {
      final r = _readRow(ps, w, h, k);
      if (r == null || !r.ok || r.digits < 2) continue;
      votes[r.text] = (votes[r.text] ?? 0) + 1;
    }
  }
  return [for (final e in votes.entries) SevenRead(e.key, e.value)]..sort((a, b) => b.votes.compareTo(a.votes));
}

/// The reading: with [want] digits when the other reader (ML Kit) counted them (it counts well; it reads LED digits badly), else
/// the one most looks support – a shorter reading inside a longer one supports the longer (a digit lost at one threshold). At
/// least 3 looks must give it; null = none.
SevenRead? pickSeven(List<SevenRead> cands, {int want = 0}) {
  String dig(String t) => t.replaceAll('.', '');
  final groups = <String, List<SevenRead>>{};
  for (final c in cands) {
    groups.putIfAbsent(dig(c.text), () => []).add(c);
  }
  int own(String d) => groups[d]!.fold(0, (a, c) => a + c.votes);
  var keys = groups.keys.toList();
  if (want > 0) {
    final w = keys.where((d) => d.length == want).toList();
    if (w.isNotEmpty) keys = w;
  }
  int support(String d) => own(d) + groups.keys.where((o) => o != d && o.length < d.length && d.contains(o)).fold(0, (a, o) => a + own(o));
  int score(String d) => own(d) >= 3 ? support(d) : own(d);
  keys.sort((a, b) {
    final s = score(b).compareTo(score(a));
    return s != 0 ? s : b.length.compareTo(a.length);
  });
  if (keys.isEmpty || own(keys.first) < 3) return null;
  final d = keys.first, n = own(d);
  final withPoint = groups[d]!.where((f) => f.text.contains('.')).toList()..sort((a, b) => b.votes.compareTo(a.votes));
  final pv = withPoint.fold(0, (a, f) => a + f.votes);
  return SevenRead(pv >= n * .3 && withPoint.isNotEmpty ? withPoint.first.text : d, n);
}

/// The display's number, read by its segments ([want] = the digits ML Kit counted, 0 = not known); null = not a clear reading.
SevenRead? readSeven(Uint8List gray, int w, int h, {int want = 0}) => pickSeven(sevenLooks(gray, w, h), want: want);

/// (for an isolate) Many lines' pictures at once: each [bytes, w, h, want] → its reading, or null.
List<String?> sevenAll(List<List<Object>> jobs) => [
      for (final j in jobs) readSeven(j[0] as Uint8List, j[1] as int, j[2] as int, want: j[3] as int)?.text,
    ];
