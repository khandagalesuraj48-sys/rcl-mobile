/* THE LANGUAGE OF THE APP (asked 15-10-2026: "app madhe mala language change ha option hawa aahe all site user sathi hindi
 * marathi english … jya language madhe selection asel purn app tyach language madhe asel error suggestions pn tyach language
 * madhe"). Me → My settings → App language: मराठी / हिंदी / English – kept with his account (the web ERP's "Language of the app"
 * is the same setting, and it is the same at all his sites).
 *   ''  – not chosen yet: the app as before (English with the Marathi line under it);
 *   'en' – English only;  'mr' – मराठी only;  'hi' – हिंदी only.
 * The app's code stays English. What is shown is turned here, from the web's words (assets/i18n/web_<lang>.json – the same
 * file the web uses, with the server's messages) and the app's own (assets/i18n/app_<lang>.json): a text exactly, or a pattern
 * whose {0}, {1}… are filled by the app (a machinery, a date, a number). Where the app already has its own Marathi words (the
 * second line of a title), Marathi uses those. A text without a translation stays English. */
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final _deva = RegExp(r'[ऀ-ॿ]');
bool hasDeva(String s) => _deva.hasMatch(s);

class _Tpl {
  _Tpl(this.re, this.ids, this.ends, this.to, this.n);
  final RegExp re;
  final List<String> ids, ends;
  final String to;
  final int n;
}

class Lang extends ChangeNotifier {
  Lang._();
  static final Lang i = Lang._();

  /// '', 'en', 'mr' or 'hi' (see above)
  String code = '';
  Map<String, String> _map = {};
  Map<String, List<_Tpl>> _tpl = {};
  final Map<String, String?> _seen = {};

  bool get chosen => code.isNotEmpty;
  bool get turning => code == 'mr' || code == 'hi';

  /// Loads the words of [c] (from the app's own files) and turns the app into it. [read] – for the tests.
  Future<void> set(String c, {Future<String> Function(String path)? read}) async {
    c = (c == 'mr' || c == 'hi' || c == 'en') ? c : '';
    if (c == code) return;
    if (c == 'mr' || c == 'hi') {
      final rd = read ?? rootBundle.loadString;
      final d = <String, String>{};
      for (final f in ['web', 'app']) {
        try {
          final j = jsonDecode(await rd('assets/i18n/${f}_$c.json'));
          if (j is Map) j.forEach((k, v) => d['$k'] = '$v');
        } catch (_) {/* a file missing: the other still turns what it knows */}
      }
      _index(d);
    } else {
      _map = {};
      _tpl = {};
    }
    _seen.clear();
    code = c;
    notifyListeners();
  }

  static String _word(String w) => w.replaceAll(RegExp(r"[^A-Za-z0-9'-]"), '').toLowerCase();

  void _index(Map<String, String> d) {
    final map = <String, String>{}, tpl = <String, List<_Tpl>>{};
    final ph = RegExp(r'(\{\d+\})');
    d.forEach((k, v) {
      if (!ph.hasMatch(k)) {
        map[k] = v;
        return;
      }
      final parts = <String>[];
      var last = 0;
      for (final m in ph.allMatches(k)) {
        parts.add(k.substring(last, m.start));
        parts.add(m.group(0)!);
        last = m.end;
      }
      parts.add(k.substring(last));
      final lits = [for (var i = 0; i < parts.length; i += 2) parts[i]];
      String? first;
      for (final l in lits) {
        for (final w in l.trim().split(RegExp(r'\s+'))) {
          final x = _word(w);
          if (RegExp(r'[a-z]{2}').hasMatch(x)) {
            first = x;
            break;
          }
        }
        if (first != null) break;
      }
      if (first == null) return;
      // a part put right after a word: an English ending ("entr" + "y" / "ies", "day" + "" / "s" – left out) and / or more words
      bool end(int i) => RegExp(r'[A-Za-z]$').hasMatch(parts[i - 1]) && !(i + 1 < parts.length && RegExp(r'^[A-Za-z]').hasMatch(parts[i + 1]));
      final b = StringBuffer('^');
      final ids = <String>[], ends = <String>[];
      for (var i = 0; i < parts.length; i++) {
        if (i.isOdd) {
          final id = parts[i].substring(1, parts[i].length - 1);
          ids.add(id);
          if (end(i)) {
            ends.add(id);
            b.write(r'((?:ies|es|s|y)?(?:[^A-Za-z][\s\S]*?)?)');
          } else {
            b.write(r'([\s\S]+?)');
          }
        } else {
          b.write(RegExp.escape(parts[i]));
        }
      }
      b.write(r'$');
      RegExp re;
      try {
        re = RegExp(b.toString());
      } catch (_) {
        return;
      }
      (tpl[first] ??= []).add(_Tpl(re, ids, ends, v, lits.join().length));
    });
    for (final l in tpl.values) {
      l.sort((a, b) => b.n - a.n); // the longest pattern first (the most exact)
    }
    _map = map;
    _tpl = tpl;
  }

  String? _one(String t) {
    final hit = _map[t];
    if (hit != null) return hit;
    if (_seen.containsKey(t)) return _seen[t];
    String? v;
    final tried = <String>{};
    final words = t.split(RegExp(r'\s+'));
    for (final w0 in words.take(10)) {
      final w = _word(w0);
      if (w.isEmpty || !tried.add(w)) continue;
      final l = _tpl[w];
      if (l == null) continue;
      for (final x in l) {
        final m = x.re.firstMatch(t);
        if (m == null) continue;
        v = x.to.replaceAllMapped(RegExp(r'\{(\d+)\}'), (g) {
          final j = x.ids.indexOf(g.group(1)!);
          if (j < 0) return g.group(0)!;
          final got = m.group(j + 1) ?? '';
          if (x.ends.contains(g.group(1))) return got.replaceFirst(RegExp(r'^(ies|es|s|y)'), '');
          return _map[got.trim()] ?? got; // a word the app put in ("Day", "entries") – its translation when there is one
        });
        break;
      }
      if (v != null) break;
    }
    if (_seen.length > 20000) _seen.clear();
    _seen[t] = v;
    return v;
  }

  /// One text in the chosen language (English when there is no translation). Each line on its own.
  String tr(String s) {
    if (!turning || s.isEmpty) return s;
    if (s.contains('\n')) return s.split('\n').map(tr).join('\n');
    final t = s.trim();
    if (t.isEmpty || t.length > 3000 || !RegExp(r'[A-Za-z]{2}').hasMatch(t)) return s;
    final v = _one(t);
    if (v == null || v == t) return s;
    final at = s.indexOf(t);
    return s.substring(0, at) + v + s.substring(at + t.length);
  }

  /// A title with the app's own Marathi words: the chosen language's line (Marathi = the app's own words).
  String pair(String en, String mr) {
    if (code == 'mr' && mr.isNotEmpty) return mr;
    return tr(en);
  }

  /// A message written in both ("English · मराठी"): as before when no language is chosen, else the chosen one.
  String bi(String en, String mr, [String sep = ' · ']) {
    if (!chosen) return mr.isEmpty ? en : '$en$sep$mr';
    return pair(en, mr);
  }
}

/// The chosen language's text (the app's code writes English).
String tr(String s) => Lang.i.tr(s);

/// "English · मराठी" as before, or only the chosen language.
String bi(String en, String mr, [String sep = ' · ']) => Lang.i.bi(en, mr, sep);
