/* THE SEARCH OF THE WHOLE APP (3.14.0) – the web's Ctrl + K (App.html "GLOBAL SEARCH", update-83): one matcher for everything,
 * the same as the server's (globalSearch_): every word typed must be found – as a whole word, the start of a word, inside a word,
 * without dashes / spaces, or (4 letters and more) with one spelling mistake (two from 7 letters; two letters the other way round
 * count as one) – and the word it was taken for is suggested ("did you mean …"); a number is found as the same number
 * (3714.5 = 3714.50), as the start of a number or inside an ID. Exact first; a spelling mistake only when nothing is found.
 * The Store module's own search (rcl-store: sFind) is here too. Proven against the web's own code: test/gsearch_test.dart. */
import 'dart:math' as math;

const _deva = 'ऀ-ॿ';
final _tokSplit = RegExp('[^A-Z0-9.$_deva]+');
final _notAlnum = RegExp('[^A-Z0-9$_deva]');
final _edge = RegExp('^[^A-Z0-9$_deva]+|[^A-Z0-9$_deva]+\$');
final _num = RegExp(r'^\d+(\.\d+)?$');
final _letter = RegExp('[A-Z$_deva]');

String gsNorm(Object? v) => (v == null ? '' : '$v').toUpperCase();

List<String> gsToks(Object? v) => [
      for (final t in gsNorm(v).split(_tokSplit))
        if (t.replaceAll(RegExp(r'^\.+|\.+$'), '').isNotEmpty) t.replaceAll(RegExp(r'^\.+|\.+$'), ''),
    ];

num? gsNum(String t) => _num.hasMatch(t) ? num.parse(t) : null;

/// Edit distance with two letters swapped as one mistake; more than [max] = max + 1 (stops early).
int gsDist(String a, String b, int max) {
  if ((a.length - b.length).abs() > max) return max + 1;
  List<int>? p2;
  var p1 = [for (var j = 0; j <= b.length; j++) j];
  for (var i = 1; i <= a.length; i++) {
    final cur = <int>[i];
    var low = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = math.min(math.min(p1[j] + 1, cur[j - 1] + 1), p1[j - 1] + cost);
      if (p2 != null && i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) v = math.min(v, p2[j - 2] + 1);
      cur.add(v);
      if (v < low) low = v;
    }
    if (low > max) return max + 1;
    p2 = p1;
    p1 = cur;
  }
  return p1[b.length];
}

class GsField {
  GsField(this.label, Object? value)
      : value = value == null ? '' : '$value',
        text = gsNorm(value),
        toks = gsToks(value) {
    flat = text.replaceAll(_notAlnum, '');
    nums = [for (final t in toks) if (gsNum(t) != null) gsNum(t)!];
  }
  final String label, value, text;
  final List<String> toks;
  late final String flat;
  late final List<num> nums;
}

/// One word in one field: its score, and the word it was taken for (a spelling mistake) – null = not found.
({double s, String? fix})? gsWordHit(String w, GsField f, bool fuzzy) {
  if (f.text.isEmpty) return null;
  final wn = gsNum(w);
  if (wn != null) {
    if (f.nums.any((n) => (n - wn).abs() < 1e-9)) return (s: 5, fix: null);
    if (w.length >= 3 && f.toks.any((t) => t.startsWith(w))) return (s: 3, fix: null);
    if (w.length >= 3 && f.flat.contains(w.replaceAll('.', ''))) return (s: 2, fix: null);
    return null;
  }
  if (f.toks.contains(w)) return (s: 5, fix: null);
  if (f.toks.any((t) => t.startsWith(w))) return (s: 4, fix: null);
  if (f.text.contains(w)) return (s: 3, fix: null);
  final sw = w.replaceAll(_notAlnum, '');
  if (sw.length >= 2 && f.flat.contains(sw)) return (s: 3, fix: null);
  if (fuzzy && w.length >= 4 && _letter.hasMatch(w)) {
    final max = w.length >= 7 ? 2 : 1;
    ({int d, String t})? best;
    for (final t in f.toks) {
      if (gsNum(t) != null || t.length < 3) continue;
      var d = gsDist(w, t, max);
      if (d > max && t.length > w.length + 1) d = math.min(gsDist(w, t.substring(0, w.length), max), gsDist(w, t.substring(0, w.length + 1), max));
      if (d <= max && (best == null || d < best.d)) best = (d: d, t: t);
    }
    if (best != null) return (s: best.d == 1 ? 1.5 : 1, fix: best.t);
  }
  return null;
}

/// Every word found in one of the fields ([label, value] pairs): the score and the spellings taken – else null.
({double score, List<(String, String)> fixes})? gsRecord(List<String> words, List<(String, Object?)> pairs, {bool fuzzy = false}) {
  final fields = [for (final p in pairs) GsField(p.$1, p.$2)];
  var score = 0.0;
  final fixes = <(String, String)>[];
  for (final w in words) {
    ({double s, String? fix})? best;
    for (final f in fields) {
      final h = gsWordHit(w, f, fuzzy);
      if (h != null && (best == null || h.s > best.s)) best = h;
    }
    if (best == null) return null;
    score += best.s;
    if (best.fix != null) fixes.add((w, best.fix!));
  }
  return (score: score, fixes: fixes);
}

/// The words of what is typed (at most 8; the marks around a word left out).
List<String> gsWords(String q) => [
      for (final w in gsNorm(q).trim().split(RegExp(r'\s+')))
        if (w.replaceAll(_edge, '').isNotEmpty) w.replaceAll(_edge, ''),
    ].take(8).toList();

/// The ones found, the best first (an even score keeps the list's order – the web's stable sort); the spellings taken are
/// added to [fixes].
List<T> gsRank<T>(List<String> words, List<T> list, List<(String, Object?)> Function(T) pairsOf, List<(String, String)> fixes, {bool fuzzy = false}) {
  final hits = <(int, T, double, List<(String, String)>)>[];
  for (final (i, x) in list.indexed) {
    final m = gsRecord(words, pairsOf(x), fuzzy: fuzzy);
    if (m != null) hits.add((i, x, m.score, m.fixes));
  }
  hits.sort((a, b) => b.$3 != a.$3 ? b.$3.compareTo(a.$3) : a.$1.compareTo(b.$1));
  for (final h in hits) {
    fixes.addAll(h.$4);
  }
  return [for (final h in hits) h.$2];
}

/// "Did you mean …": each word that was found only as another word, by the spelling found most often ('' = nothing to say).
String gsBetter(List<String> words, List<(String, String)> fixes, bool anyFound) {
  final fixOf = <String, Map<String, int>>{};
  for (final f in fixes) {
    final m = fixOf.putIfAbsent(f.$1, () => {});
    m[f.$2] = (m[f.$2] ?? 0) + 1;
  }
  final sure = anyFound && words.any(fixOf.containsKey);
  if (!sure) return '';
  final better = [
    for (final w in words)
      if (fixOf[w] != null)
        () {
          final e = fixOf[w]!.entries.toList();
          // the most found first; an even count keeps the first one found (the web's stable sort)
          var top = e.first;
          for (final x in e) {
            if (x.value > top.value) top = x;
          }
          return top.key;
        }()
      else
        w,
  ].join(' ');
  return better == words.join(' ') ? '' : better.toLowerCase();
}

/* ---------------- the Store module's own search (rcl-store public/index.html sFind) ---------------- */

String _sNorm(Object? v) => (v == null ? '' : '$v').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// The Store's items found for [q] (at most 8): exact words first; with nothing found, one spelling mistake per word (4 letters
/// or more; two from 7 letters); its own order – the item code typed, the name starting with the first word, an active item.
List<Map> storeFind(String q, List<Map> items) {
  final words = _sNorm(q).split(' ').where((w) => w.isNotEmpty).take(8).toList();
  if (words.isEmpty) return [];
  final rows = [for (final (k, i) in items.indexed) (k, i, _sNorm([i['code'], i['name'], i['category'], i['hsn'], i['unit'], i['status']].map((v) => v ?? '').join(' ')))];
  bool hit((int, Map, String) t, String w, bool fz) {
    if (t.$3.contains(w)) return true;
    if (!fz || w.length < 4) return false;
    final max = w.length >= 7 ? 2 : 1;
    return t.$3.split(RegExp(r'[^a-z0-9]+')).any((x) => x.length >= 3 && gsDist(w, x, max) <= max);
  }

  var found = rows.where((t) => words.every((w) => hit(t, w, false))).toList();
  if (found.isEmpty) found = rows.where((t) => words.every((w) => hit(t, w, true))).toList();
  int score((int, Map, String) t) => (_sNorm(t.$2['code']) == words.join(' ') ? 10 : 0) + (_sNorm(t.$2['name']).startsWith(words.first) ? 3 : 0) + (t.$2['status'] == 'Active' ? 1 : 0);
  found.sort((a, b) => score(b) != score(a) ? score(b).compareTo(score(a)) : a.$1.compareTo(b.$1));
  return [for (final t in found.take(8)) t.$2];
}
