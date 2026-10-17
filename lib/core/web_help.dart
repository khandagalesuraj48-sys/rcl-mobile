/* THE WEB'S OWN HELP (3.15.0), the same words in the app: what every page is for and what the app checks (the web's PAGE_GUIDE /
 * REPORT_GUIDE, its "?" button) and help for every error message – what is wrong and what to do (FIX_RULES, the card under a
 * red message) – in English, मराठी and हिंदी. Taken out of App.html as they are (tool/web_help.js → assets/help/web_help.json),
 * so the app says exactly what the web says; when the web's help changes, the file is made again. */
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

typedef HelpText = Map<String, List<String>>; // {en: [what, how], mr: […], hi: […]}

class FixRule {
  FixRule(this.re, this.text);
  final RegExp re;
  final HelpText text;
}

class WebHelp {
  WebHelp.fromJson(Map<String, dynamic> j)
      : fix = [
          for (final r in (j['fix'] as List).whereType<Map>())
            FixRule(RegExp('${r['re']}', caseSensitive: !'${r['flags']}'.contains('i')), _lang(r)),
        ],
        fixAny = _lang(j['fixAny'] as Map),
        pages = {for (final e in (j['pages'] as Map).entries) '${e.key}': _lang(e.value as Map)},
        reports = {for (final e in (j['reports'] as Map).entries) '${e.key}': _lang(e.value as Map)},
        fixW = _words(j['fixW']),
        guideW = _words(j['guideW']);

  final List<FixRule> fix;
  final HelpText fixAny;
  final Map<String, HelpText> pages, reports;
  final Map<String, Map<String, String>> fixW, guideW;

  static HelpText _lang(Map m) => {for (final l in const ['en', 'mr', 'hi']) if (m[l] is List) l: [for (final x in m[l] as List) '$x']};
  static Map<String, Map<String, String>> _words(Object? m) =>
      m is Map ? {for (final e in m.entries) '${e.key}': {for (final w in (e.value as Map).entries) '${w.key}': '${w.value}'}} : {};

  static WebHelp? _i;
  static Future<WebHelp>? _loading;

  /// The help, read once from the app's file.
  static Future<WebHelp> load() async {
    if (_i != null) return _i!;
    _loading ??= rootBundle.loadString('assets/help/web_help.json').then((t) => _i = WebHelp.fromJson((jsonDecode(t) as Map).cast<String, dynamic>()));
    return _loading!;
  }

  /// (tests) the help given directly.
  static void use(WebHelp h) => _i = h;
  static WebHelp? get now => _i;

  /// The web's fixRules: the first three rules that know the message, else the general one.
  List<HelpText> fixRules(String text) {
    final hit = fix.where((r) => r.re.hasMatch(text)).take(3).map((r) => r.text).toList();
    return hit.isEmpty ? [fixAny] : hit;
  }

  /// The web's guideOf: a report page (rp-…) or a page.
  HelpText? guideOf(String tab) => tab.startsWith('rp-') ? reports[tab.substring(3)] : pages[tab];
}
