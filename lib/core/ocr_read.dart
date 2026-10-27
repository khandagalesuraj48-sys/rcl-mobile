/* THE PHONE READS THE PHOTO (3.28.0, asked 20-10-2026: "ata aplela app madhe ocr jodaych aahe mhanje google gemini api nahi ani
 * te ocr khup fast asawi"; his choices: the Diesel Issue photos – dashboard → KM / Hrs, dispenser → litres – and the bill of a
 * Diesel Inward – Bill No., litres, rate; the web keeps its Gemini).
 * The text itself is read ON THE PHONE (ocr.dart – Google ML Kit: no internet, nothing paid, a fraction of a second). This file
 * only understands the lines it gives, so the tests run it without a phone:
 *   meterFrom – the KM / hour meter: the number that fits the machinery's last reading, as the server's pickReading_ – not below
 *               it, not more than it can run since then (KM 800 a day, at least 300; Hrs 24 a day, at least 30); the tenth digit of
 *               a meter in another colour (451734 → 45173.4) is tried too. Without a last reading: only one clear long number.
 *   pumpFrom  – the litres of the fill: three numbers with litres × rate = amount (a diesel rate of ₹ 50–200) are the surest;
 *               else the number by the word Litre / Volume / Qty; else amount ÷ rate.
 *   billFrom  – the bill number (by Bill / Invoice / Receipt / Memo … No), the litres and the rate (litres × rate = amount;
 *               KL and ₹ per KL become litres), else by their words.
 * A number that does not fit is not taken: the box stays empty and the person types it. A box the phone filled is blue (check it). */
import 'dart:math' as math;

/// One line of text the phone read, with where it is on the picture (pixels).
class OcrLine {
  const OcrLine(this.text, {this.left = 0, this.top = 0, this.width = 0, this.height = 0, this.seven = false});
  final String text;
  final double left, top, width, height;
  /// (3.30.0) its number read again by its segments (seven.dart) – a display's digits read clearly
  final bool seven;
  double get cy => top + height / 2;
}

/// A number found on a line ([whole] = its digits before the point).
class OcrNum {
  const OcrNum(this.value, this.line, this.whole, [this.frac = 0]);
  final double value;
  final int line;
  final int whole;
  /// (3.30.0) its digits after the point
  final int frac;
}

double _r2(double x) => (x * 100).roundToDouble() / 100;

// letters the reader often gives for digits (also the segments of an LED / LCD display: 0 → D / Q, 6 → G / b, 9 → g / q, 7 → T) –
// changed only inside a word that is a number already (it has a digit)
const _like = {'O': '0', 'o': '0', 'D': '0', 'Q': '0', 'I': '1', 'l': '1', '|': '1', 'S': '5', 's': '5', 'B': '8', 'b': '6', 'G': '6', 'g': '9', 'q': '9', 'Z': '2', 'z': '2', 'T': '7'};
final _digitish = RegExp(r'^[0-9OoDQIl|SsBbGgqZzT.,]+$');
final _dates = RegExp(r'\b\d{1,2}\s?[/.\-]\s?\d{1,2}\s?[/.\-]\s?\d{2,4}\b|\b\d{1,2}[\s\-/]?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s\-/,]*\d{2,4}\b', caseSensitive: false);
final _times = RegExp(r'\b\d{1,2}:\d{2}(:\d{2})?\s*(am|pm)?\b', caseSensitive: false);
final _percent = RegExp(r'\d+(\.\d+)?\s*%');
final _num = RegExp(r'\d+(?:\.\d+)?');

/// A line made ready for its numbers: dates, times and percents out; O → 0 … inside numbers; 1,23,456.50 → 123456.50; 45,6 → 45.6.
String cleanLine(String text) {
  final s = text.replaceAll(_dates, ' ').replaceAll(_times, ' ').replaceAll(_percent, ' ').trim();
  final words = s.split(RegExp(r'\s+')).map((w) {
    if (!_digitish.hasMatch(w) || !RegExp(r'\d').hasMatch(w)) return w;
    var t = w.split('').map((c) => _like[c] ?? c).join();
    if (RegExp(r'^\d{1,3}(?:(?:,\d{2})*,\d{3}|(?:,\d{3})+)(?:\.\d+)?$').hasMatch(t)) {
      t = t.replaceAll(',', ''); // 1,23,456.50 (grouping)
    } else if (RegExp(r'^\d+,\d{1,2}$').hasMatch(t)) {
      t = t.replaceAll(',', '.'); // 45,60 (a point read as a comma)
    }
    return t;
  });
  return words.join(' ');
}

/// Every number of every line.
List<OcrNum> numbersOf(List<OcrLine> lines) {
  final out = <OcrNum>[];
  for (var i = 0; i < lines.length; i++) {
    for (final m in _num.allMatches(cleanLine(lines[i].text))) {
      final t = m.group(0)!, v = double.tryParse(t);
      if (v == null) continue;
      final pt = t.split('.');
      out.add(OcrNum(v, i, pt.first.length, pt.length > 1 ? pt[1].length : 0));
    }
  }
  return out;
}

// ---------------------------------------------------------------- the meter ----------------------------------------------------

class LastReading {
  const LastReading(this.value, this.date);
  final double value;
  final String date; // yyyy-mm-dd
}

class MeterRead {
  const MeterRead(this.km, this.hr, this.check);
  final double? km, hr;
  final String check;
}

int _days(String from, String to) {
  final a = DateTime.tryParse(from), b = DateTime.tryParse(to);
  if (a == null || b == null) return 1;
  return math.max(1, b.difference(a).inDays);
}

/// The readings a dashboard may show, in three rounds: two numbers side by side read as one ("45173 4" → 45173.4 and 451734 –
/// a tenth digit in another colour; also when the reader gave that digit as a line of its own just right of the number); every
/// number of 2 digits or more as it is, and the pieces of a number read apart ("45 173" → 45173); the same numbers with the
/// point moved one or two places (the tenth digit read as one more digit).
List<List<double>> meterCandidates(List<OcrLine> lines) {
  final pairs = <double>{}, plain = <double>{}, moved = <double>{};
  void pair(String a, String b) {
    pairs.add(double.parse('$a.$b'));
    pairs.add(double.parse('$a$b'));
  }

  final cleaned = [for (final l in lines) cleanLine(l.text)];
  for (var i = 0; i < lines.length; i++) {
    for (final m in RegExp(r'(\d{3,})\s+(\d)(?!\d)').allMatches(cleaned[i])) {
      pair(m.group(1)!, m.group(2)!);
    }
    // the pieces of one number read apart, side by side on the line
    final toks = cleaned[i].split(' ');
    for (var a = 0; a < toks.length; a++) {
      var joined = '';
      for (var b = a; b < toks.length && b < a + 4 && RegExp(r'^\d+$').hasMatch(toks[b]); b++) {
        joined += toks[b];
        if (b > a && joined.length >= 3) plain.add(double.parse(joined));
      }
    }
    // the tenth digit as a line of its own, just right of the number on the same row
    final l = lines[i], last = RegExp(r'(\d{3,})$').firstMatch(cleaned[i]);
    if (last == null || l.height <= 0) continue;
    for (var j = 0; j < lines.length; j++) {
      final d = lines[j];
      if (j == i || !RegExp(r'^\d$').hasMatch(cleaned[j]) || (d.cy - l.cy).abs() > l.height * .6) continue;
      final gap = d.left - (l.left + l.width);
      if (d.left >= l.left + l.width * .8 && gap < l.height * 1.5) pair(last.group(1)!, cleaned[j]);
    }
  }
  for (final n in numbersOf(lines)) {
    if (n.whole < 2) continue;
    plain.add(n.value);
    moved.addAll([_r2(n.value / 10), _r2(n.value / 100)]);
    // (3.30.0) the point taken out (7087.0 → 70870): a machinery whose readings were always kept without the tenth digit's point
    if (n.frac > 0 && n.frac <= 2) moved.add((n.value * math.pow(10, n.frac)).roundToDouble());
  }
  plain.removeAll(pairs);
  moved
    ..removeAll(pairs)
    ..removeAll(plain);
  return [pairs.toList()..sort(), plain.toList()..sort(), moved.toList()..sort()];
}

/// The KM / Hrs on the dashboard photo. [today] = the entry's date (yyyy-mm-dd).
MeterRead meterFrom(List<OcrLine> lines, {bool wantKm = true, bool wantHr = false, LastReading? lastKm, LastReading? lastHr, String today = ''}) {
  final cands = meterCandidates(lines), checks = <String>[];
  double? fit(LastReading last, bool km, Set<double> taken) {
    final days = _days(last.date, today);
    final max = km ? math.max(300, days * 800) : math.max(30, days * 24);
    for (final round in cands) {
      for (final x in round) {
        if (!taken.contains(x) && x >= last.value && x <= last.value + max) return x; // the nearest above the last one
      }
    }
    return null;
  }

  // no earlier reading: one clear long number only (an odometer 4 digits or more, an hour meter 3 or more)
  double? alone(bool km) {
    final ns = numbersOf(lines).where((n) => n.whole >= (km ? 4 : 3)).toList();
    if (ns.isEmpty) return null;
    final most = ns.map((n) => n.whole).reduce(math.max);
    final top = ns.where((n) => n.whole == most).map((n) => n.value).toSet();
    return top.length == 1 ? top.first : null;
  }

  double? km, hr;
  final taken = <double>{};
  if (wantKm) {
    if (lastKm != null) {
      km = fit(lastKm, true, taken);
    } else if (!wantHr) {
      km = alone(true);
      if (km != null) checks.add('KM: no earlier reading to compare');
    }
    if (km != null) taken.add(km);
  }
  if (wantHr) {
    if (lastHr != null) {
      hr = fit(lastHr, false, taken);
    } else if (!wantKm) {
      hr = alone(false);
      if (hr != null) checks.add('Hrs: no earlier reading to compare');
    }
  }
  return MeterRead(km, hr, checks.join('; '));
}

// ---------------------------------------------------------------- litres, rate, amount -----------------------------------------

final _litreWord = RegExp(r'\b(lit(re|er)s?|ltrs?|vol(ume)?|qty|quantity|kl)\b|\(\s*l\s*\)', caseSensitive: false);
final _rateWord = RegExp(r'\b(rate|price|unit\s*price)\b|/\s*(l|ltr|litre|liter|kl)\b|per\s*(l|ltr|lit)', caseSensitive: false);
final _amountWord = RegExp(r'\b(amount|amt|sale|total|net|payable|value)\b', caseSensitive: false);
final _counterWord = RegExp(r'totali[sz]er|totaliser|cumulative', caseSensitive: false);

class Triple {
  const Triple(this.qty, this.rate, this.amount, [this.moved = 0]);
  final double qty, rate, amount;
  /// how many of the three had their point put back
  final int moved;
}

class _V {
  const _V(this.n, this.value, this.moved, [this.places = 0]);
  final OcrNum n;
  final double value;
  final int moved; // 1 = its point was put back (the reader did not see it)
  final int places; // how many places it was put back (2 – paise and two decimals – is the usual on a display)
}

/// Three numbers with qty × rate = amount (within half a percent): the surest way to know which is which. A display's point is
/// often not seen ("472500" for 4725.00): a whole number of 3 digits or more is also tried with its point put back 1, 2 or 3
/// places – the product must still agree, so a wrong place does not pass.
Triple? tripleOf(List<OcrLine> lines, List<OcrNum> ns, {required double rateMin, required double rateMax, required double qtyMax}) {
  Triple? best;
  var bestScore = -1e9;
  // the words of each line, looked at once (the loops below are many)
  final isCounter = [for (final l in lines) _counterWord.hasMatch(l.text)], isRate = [for (final l in lines) _rateWord.hasMatch(l.text)],
      isLitre = [for (final l in lines) _litreWord.hasMatch(l.text)], isAmount = [for (final l in lines) _amountWord.hasMatch(l.text)];
  bool word(OcrNum n, RegExp w) => (identical(w, _counterWord) ? isCounter : identical(w, _rateWord) ? isRate : identical(w, _litreWord) ? isLitre : isAmount)[n.line];
  // the numbers by the words Rate and Litre (also on the row beside them or the line under them)
  final rw = byWord(lines, ns, _rateWord, min: rateMin, max: rateMax), lw = byWord(lines, ns, _litreWord, min: .5, max: qtyMax, not: _counterWord);
  final vs = <_V>[
    for (final n in ns.take(40)) ...[
      _V(n, n.value, 0),
      if (n.value == n.value.truncateToDouble() && n.whole >= 3)
        for (var d = 1; d <= 3; d++) _V(n, n.value / math.pow(10, d), 1, d),
    ],
  ];
  for (final q in vs) {
    if (q.value < .5 || q.value > qtyMax || word(q.n, _counterWord)) continue;
    for (final r in vs) {
      if (identical(r.n, q.n) || r.value < rateMin || r.value > rateMax) continue;
      for (final a in vs) {
        if (identical(a.n, q.n) || identical(a.n, r.n) || a.value <= q.value || a.value <= r.value || word(a.n, _counterWord)) continue;
        final err = (q.value * r.value - a.value).abs();
        if (err > math.max(.6, a.value * .005)) continue;
        // which is which: the words by them first, then a usual diesel rate, then the smaller error, then the bigger amount
        var score = 0.0;
        if (word(r.n, _rateWord) || (r.moved == 0 && r.value == rw)) score += 4;
        if (word(q.n, _litreWord) || (q.moved == 0 && q.value == lw)) score += 4;
        if (word(a.n, _amountWord)) score += 2;
        if (word(q.n, _rateWord) || word(r.n, _litreWord)) score -= 4;
        if ((r.value >= 80 && r.value <= 115) || (r.value >= 80000 && r.value <= 115000)) score += 1;
        score -= 1.5 * (q.moved + r.moved + a.moved) + .5 * [q, r, a].where((x) => x.moved > 0 && x.places != 2).length;
        score -= err / math.max(1, a.value) * 100;
        score += a.value / 1e9;
        if (score > bestScore) {
          bestScore = score;
          best = Triple(q.value, r.value, a.value, q.moved + r.moved + a.moved);
        }
      }
    }
  }
  return best;
}

/// The number by a word (on its line, else on the same row to its right, else on the line under it), between [min] and [max].
double? byWord(List<OcrLine> lines, List<OcrNum> ns, RegExp w, {double min = 0, double max = double.infinity, RegExp? not}) {
  bool ok(OcrNum n) => n.value >= min && n.value <= max;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (!w.hasMatch(l.text) || (not != null && not.hasMatch(l.text))) continue;
    // on its own line: the first number after the word, else the last one before it
    final c = cleanLine(l.text), at = w.firstMatch(c);
    if (at != null) {
      final after = _num.allMatches(c, at.end).map((m) => double.tryParse(m.group(0)!)).whereType<double>().where((v) => v >= min && v <= max);
      if (after.isNotEmpty) return after.first;
      final before = _num.allMatches(c.substring(0, at.start)).map((m) => double.tryParse(m.group(0)!)).whereType<double>().where((v) => v >= min && v <= max);
      if (before.isNotEmpty) return before.last;
    } else {
      final same = ns.where((n) => n.line == i && ok(n)).toList();
      if (same.isNotEmpty) return same.last.value;
    }
    if (l.height <= 0) continue; // no places known (a test without them): only the line itself
    final row = ns.where((n) => n.line != i && ok(n) && (lines[n.line].cy - l.cy).abs() < l.height * .8 && lines[n.line].left > l.left).toList()
      ..sort((a, b) => lines[a.line].left.compareTo(lines[b.line].left));
    if (row.isNotEmpty) return row.first.value;
    final under = ns.where((n) => n.line != i && ok(n) && lines[n.line].top > l.top && lines[n.line].top - l.top < l.height * 3).toList()
      ..sort((a, b) => lines[a.line].top.compareTo(lines[b.line].top));
    if (under.isNotEmpty) return under.first.value;
  }
  return null;
}

class PumpRead {
  const PumpRead(this.litres, this.check, {this.sure = false, this.amount});
  final double? litres;
  /// (3.45.0, Mechanical update-164) the ₹ of the fill on the display (a site on fuel cards puts it in its Amount box)
  final double? amount;
  final String check;
  /// (3.29.0) litres × rate = amount agreed: the surest read
  final bool sure;
}

/// The litres given in this fill, on the dispenser's display.
PumpRead pumpFrom(List<OcrLine> lines) {
  final ns = numbersOf(lines);
  final t = tripleOf(lines, ns, rateMin: 50, rateMax: 200, qtyMax: 2000);
  if (t != null) return PumpRead(_r2(t.qty), '', sure: true, amount: _r2(t.amount));
  final l = byWord(lines, ns, _litreWord, min: .1, max: 2000, not: _counterWord);
  final r = byWord(lines, ns, _rateWord, min: 50, max: 200), a = byWord(lines, ns, _amountWord, min: 1, not: _counterWord);
  if (l != null) return PumpRead(_r2(l), '', amount: a == null ? null : _r2(a));
  if (r != null && a != null && a > r) {
    final q = _r2(a / r);
    if (q > 0 && q <= 2000) return PumpRead(q, '', amount: _r2(a));
  }
  return const PumpRead(null, '');
}

// ---------------------------------------------------------------- the bill of an inward ----------------------------------------

class BillRead {
  const BillRead({this.billNo = '', this.qty, this.rate, this.amount});
  final String billNo;
  final double? qty, rate, amount;
  bool get any => billNo.isNotEmpty || qty != null || rate != null;
}

final _billWord = RegExp(r'\b(bill|invoice|inv|receipt|rcpt|memo|txn|transaction|trans|token|slip)\b\.?\s*((?:number|num|no)\b|#)?\.?\s*[:#\-.]?\s*([A-Za-z0-9][A-Za-z0-9/\-]{0,24})?', caseSensitive: false);
final _noWord = RegExp(r'^(date|dt|time|to|of|amount|amt|qty|rate|type|copy|cum|details?|for|no)$', caseSensitive: false);

String _value(String? v) {
  final s = (v ?? '').replaceAll(RegExp(r'[.\-/]+$'), '');
  if (s.isEmpty || _noWord.hasMatch(s) || !RegExp(r'\d').hasMatch(s) || _dates.hasMatch(s)) return '';
  return s.toUpperCase();
}

/// The bill number: the value by Bill / Invoice / Receipt / Memo … No (on its line, else the first word with a digit on the
/// line under it).
String billNoFrom(List<OcrLine> lines) {
  for (var i = 0; i < lines.length; i++) {
    for (final m in _billWord.allMatches(lines[i].text)) {
      final v = _value(m.group(3));
      if (v.isNotEmpty) return v;
      if (m.group(2) == null && m.group(3) != null) continue; // "Bill Date", "Invoice To" …: not the number's word
      // the word alone at the end of its line: the number is under it
      if (m.end >= lines[i].text.trimRight().length - 1 && i + 1 < lines.length) {
        for (final w in lines[i + 1].text.split(RegExp(r'\s+'))) {
          final v2 = _value(w.replaceAll(RegExp(r'^[:#]+'), ''));
          if (v2.isNotEmpty) return v2;
        }
      }
    }
  }
  return '';
}

/// Bill No., litres, rate (and the amount that checks them) on a picture of the bill.
BillRead billFrom(List<OcrLine> lines) {
  final no = billNoFrom(lines);
  // the bill number's own digits are not litres, a rate or an amount
  final noParts = RegExp(r'\d{3,}').allMatches(no).map((m) => double.parse(m.group(0)!)).toSet();
  final ns = numbersOf(lines).where((n) => !noParts.contains(n.value)).toList();
  final t = tripleOf(lines, ns, rateMin: 50, rateMax: 200, qtyMax: 100000);
  final k = tripleOf(lines, ns, rateMin: 50000, rateMax: 200000, qtyMax: 100); // a tanker's bill: KL and ₹ per KL
  // the one that needed fewer points put back (a KL bill read as it is beats litres made by moving its points)
  if (k != null && (t == null || k.moved < t.moved)) return BillRead(billNo: no, qty: _r2(k.qty * 1000), rate: _r2(k.rate / 1000), amount: _r2(k.amount));
  if (t != null) return BillRead(billNo: no, qty: _r2(t.qty), rate: _r2(t.rate), amount: _r2(t.amount));
  var q = byWord(lines, ns, _litreWord, min: .01, max: 100000);
  if (q != null && q <= 100 && lines.any((l) => RegExp(r'\bkl\b', caseSensitive: false).hasMatch(l.text))) q = q * 1000;
  var r = byWord(lines, ns, _rateWord, min: 50, max: 200);
  final a = byWord(lines, ns, _amountWord, min: 1);
  if (q == null && a != null && r != null) q = a / r;
  if (r == null && a != null && q != null && q > 0) {
    final x = a / q;
    if (x >= 50 && x <= 200) r = x;
  }
  return BillRead(billNo: no, qty: q == null ? null : _r2(q), rate: r == null ? null : _r2(r), amount: a == null ? null : _r2(a));
}
