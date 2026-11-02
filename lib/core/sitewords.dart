/* (3.74.0, Mechanical update-201 – asked 02-11-2026: "jewa mi voice typing krtoy … mi bolalo Arihant City tr apla system tyala
 * Aaryan City tr kadhi Aryna Nagar as karte"; his choice: the site's word list) THE SITE'S OWN WORDS FOR VOICE TYPING – the web's
 * SW (App.html "SPEAK INTO A BOX"), line by line. The phone's speech (Google's / Apple's) does not know the site's names and writes
 * the nearest word it knows. What it heard is put right with the site's words (the server's getVoiceWords: Asset Master, Vendor
 * Master, the places and works of the Log Book, the Super Admin's words) and the corrections people made by hand after speaking:
 *   1. a correction learned ("aaryan city" → "Arihant City") – that text is replaced;
 *   2. a site word said the same – kept; said nearly so (sounding alike: the same first sound, 80 % alike – one word 85 %, at least
 *      5 letters; never a word with digits) – written as the site writes it;
 *   3. of the speech's guesses (up to 5) the one that fits the site's words best is taken (the first when none does). */

/// One text put right: the text, how well it fits the site, what was changed ({from, to, at} – at: where "to" stands in the text).
class SwFix {
  SwFix(this.text, this.score, this.changes, {this.alt = 0, this.raw = ''});
  final String text;
  final num score;
  final List<Map<String, Object>> changes;
  final int alt;
  final String raw;
}

class _W {
  _W(this.w, this.k, this.p);
  final String w, p;
  final List<String> k;
}

class _F {
  _F(this.h, this.f);
  final List<String> h;
  final String f;
}

class _C {
  _C(this.i, this.m, this.x, this.s, this.o);
  final int i, m, o;
  final _W x;
  final num s;
}

int _lev(String a, String b) {
  if (a == b) return 0;
  var p = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final q = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final x = p[j] + 1, y = q[j - 1] + 1, z = p[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      q[j] = x < y ? (x < z ? x : z) : (y < z ? y : z);
    }
    p = q;
  }
  return p[b.length];
}

final _deva = RegExp(r'[ऀ-ॿ]');

/// How a word sounds (Indian names in English letters): aspiration and doubled letters dropped, y = i, w = v, z = j, c = k / s …
String swPhon(String w) {
  final x = w.toLowerCase();
  if (_deva.hasMatch(x)) return x.replaceAll(RegExp(r'[^ऀ-ॿ]'), '');
  return x
      .replaceAll(RegExp(r'[^a-z0-9]'), '')
      .replaceAll('ph', 'f')
      .replaceAll('ck', 'k')
      .replaceAll('q', 'k')
      .replaceAll('x', 'ks')
      .replaceAll(RegExp(r'c(?=[eiy])'), 's')
      .replaceAll('c', 'k')
      .replaceAll('z', 'j')
      .replaceAll('w', 'v')
      .replaceAll('y', 'i')
      .replaceAll('h', '')
      .replaceAll(RegExp(r'ee|ea'), 'i')
      .replaceAll(RegExp(r'oo|ou'), 'u')
      .replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
}

List<String> _toks(String t) => t.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
String _bare(String w) => w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9ऀ-ॿ]'), '');

class SiteWords {
  /// The app's one list (given after sign-in: Session).
  static final SiteWords i = SiteWords();

  List<_W> _list = [];
  List<_F> _fixes = [];

  /// A correction made by hand right after speaking – kept for the site (Session: saveVoiceFix).
  void Function(String heard, String fixed)? onLearn;

  int get words => _list.length;
  int get fixes => _fixes.length;

  /// The server's getVoiceWords: { words: [..], fixes: [{h, f}] }.
  void set(Map? d) {
    _list = [
      for (final w in (d?['words'] as List? ?? const []))
        (() {
          final k = _toks('$w').map(_bare).where((x) => x.isNotEmpty).toList();
          return _W('$w'.trim(), k, k.map(swPhon).join());
        })(),
    ].where((x) => x.k.isNotEmpty && x.k.length <= 5 && !RegExp(r'\d').hasMatch(x.k.join()) && x.p.length >= 4).toList();
    _fixes = [];
    for (final x in (d?['fixes'] as List? ?? const [])) {
      if (x is Map) learn('${x['h'] ?? ''}', '${x['f'] ?? ''}');
    }
  }

  void learn(String h, String f) {
    final k = _toks(h).map(_bare).where((x) => x.isNotEmpty).toList(), t = f.trim();
    if (k.isEmpty || t.isEmpty) return;
    _fixes = [..._fixes.where((x) => x.h.join(' ') != k.join(' ')), _F(k, t)]..sort((a, b) => b.h.length - a.h.length);
  }

  /// One text heard → the text put right.
  SwFix fix1(String text) {
    final w = _toks(text);
    if (w.isEmpty) return SwFix('', 0, []);
    final out = <String?>[...w], lock = List<bool>.filled(w.length, false), changes = <Map<String, Object>>[];
    num score = 0;
    for (final fx in _fixes) {
      final n = fx.h.length;
      for (var i = 0; i + n <= w.length; i++) {
        var hit = true;
        for (var j = 0; j < n; j++) {
          if (lock[i + j] || _bare(w[i + j]) != fx.h[j]) hit = false;
        }
        if (!hit) continue;
        changes.add({'from': w.sublist(i, i + n).join(' '), 'to': fx.f, 'at': i});
        out[i] = fx.f;
        for (var j = 0; j < n; j++) {
          lock[i + j] = true;
          if (j > 0) out[i + j] = null;
        }
        score += n;
      }
    }
    final cand = <_C>[];
    for (final x in _list) {
      final n = x.k.length;
      for (var m = n - 1 < 1 ? 1 : n - 1; m <= n + 1; m++) {
        for (var i = 0; i + m <= w.length; i++) {
          final seg = w.sublist(i, i + m).map(_bare).toList();
          if (seg.any((t) => t.isEmpty)) continue;
          final sj = seg.join(' '), kj = x.k.join(' '); // said as the site writes it (its plural too: "excavators") – kept
          if (m == n && (sj == kj || sj == '${kj}s' || sj == '${kj}es')) {
            cand.add(_C(i, m, x, 1.01, cand.length));
            continue;
          }
          if (RegExp(r'\d').hasMatch(seg.join())) continue;
          final p = seg.map(swPhon).join();
          if (p.isEmpty || p[0] != x.p[0]) continue;
          final sc = 1 - _lev(p, x.p) / (p.length > x.p.length ? p.length : x.p.length);
          if (n > 1 ? sc >= 0.8 : sc >= 0.85 && x.p.length >= 5) cand.add(_C(i, m, x, sc, cand.length));
        }
      }
    }
    cand.sort((a, b) {
      final d = b.s.compareTo(a.s);
      if (d != 0) return d;
      if (b.x.k.length != a.x.k.length) return b.x.k.length - a.x.k.length;
      if (a.i != b.i) return a.i - b.i;
      return a.o - b.o; // (the web's sort keeps the order they were found in)
    });
    for (final c in cand) {
      var free = true;
      for (var j = c.i; j < c.i + c.m; j++) {
        if (lock[j]) free = false;
      }
      if (!free) continue;
      for (var j = c.i; j < c.i + c.m; j++) {
        lock[j] = true;
      }
      score += c.m * (c.s < 1 ? c.s : 1);
      if (c.s > 1) continue; // said as the site writes it: kept
      changes.add({'from': w.sublist(c.i, c.i + c.m).join(' '), 'to': c.x.w, 'at': c.i});
      out[c.i] = c.x.w;
      for (var j = c.i + 1; j < c.i + c.m; j++) {
        out[j] = null;
      }
    }
    final pos = <int>[];
    var at = 0;
    for (final t in out) {
      pos.add(at);
      if (t != null) at += t.length + 1;
    }
    for (final c in changes) {
      c['at'] = pos[c['at'] as int];
    }
    return SwFix(out.whereType<String>().join(' '), score, changes);
  }

  /// The speech's guesses → the one that fits the site best (the first when none does better).
  SwFix fix(List<String> alts) {
    SwFix? best;
    var i = 0;
    for (final t0 in alts.map((t) => t.trim()).where((t) => t.isNotEmpty)) {
      final r = fix1(t0);
      if (best == null || r.score > best.score + 1e-6) best = SwFix(r.text, r.score, r.changes, alt: i, raw: t0);
      i++;
    }
    return best ?? SwFix('', 0, []);
  }
}

/// A correction by hand is learned only when it sounds like what was heard (the same first sound, 40 % alike): "Aryna Nagar" →
/// "Arihant City" is; "two" → "three", "city" → "Nagar", "loading" → "unloading" are a change of what was meant – not learned.
bool swAlike(String h, String f) {
  final a = _toks(h).map(swPhon).join(), b = _toks(f).map(swPhon).join();
  return a.isNotEmpty && b.isNotEmpty && a[0] == b[0] && 1 - _lev(a, b) / (a.length > b.length ? a.length : b.length) >= 0.4;
}

/// (the web's learnFrom) the box's text after the spoken words were put in ([was]) and now ([now]); [start] / [len] = where the
/// spoken words stand; [changes] = the site words put in (where they stand). → (heard, typed) to learn, or null. Where a site word
/// had been put (even changed in part: "Arihant City" → "Arihant Nagar"), what was heard there is learned.
(String, String)? swLearned(String was, String now, int start, int len, List<Map<String, Object>> changes) {
  if (now == was) return null;
  var a = 0;
  while (a < now.length && a < was.length && now[a] == was[a]) {
    a++;
  }
  var b = 0;
  while (b < now.length - a && b < was.length - a && now[now.length - 1 - b] == was[was.length - 1 - b]) {
    b++;
  }
  final sp = RegExp(r'\S');
  int ws(String x, int i) {
    while (i > 0 && sp.hasMatch(x[i - 1])) {
      i--;
    }
    return i;
  }

  int we(String x, int i) {
    while (i < x.length && sp.hasMatch(x[i])) {
      i++;
    }
    return i;
  }

  var oa = ws(was, a), ob = we(was, was.length - b);
  if (oa < start || ob > start + len) return null; // not in what was spoken
  final parts = [
    for (final c in changes)
      if (c['at'] is int && start + (c['at'] as int) + '${c['to']}'.length <= was.length && was.substring(start + (c['at'] as int), start + (c['at'] as int) + '${c['to']}'.length) == '${c['to']}')
        (s: start + (c['at'] as int), e: start + (c['at'] as int) + '${c['to']}'.length, from: '${c['from']}'),
  ];
  for (final p in parts) {
    if (p.s < ob && p.e > oa) {
      oa = oa < p.s ? oa : p.s; // a site word put in: the whole of it
      ob = ob > p.e ? ob : p.e;
    }
  }
  var w0 = was.substring(oa, ob);
  final is0 = now.substring(oa, now.length - (was.length - ob)).trim(); // (the text before / after is the same)
  final inside = parts.where((p) => p.s >= oa && p.e <= ob).toList()..sort((x, y) => y.s - x.s);
  for (final p in inside) {
    w0 = w0.substring(0, p.s - oa) + p.from + w0.substring(p.e - oa);
  }
  final h = w0.trim();
  if (h.isEmpty || is0.isEmpty || _toks(h).length > 5 || _toks(is0).length > 5 || !RegExp(r'[A-Za-zऀ-ॿ]').hasMatch(is0)) return null;
  if (h.toLowerCase() == is0.toLowerCase() || !swAlike(h, is0)) return null;
  return (h, is0);
}
