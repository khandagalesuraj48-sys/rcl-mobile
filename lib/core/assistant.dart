/* THE ASSISTANT (3.15.0) – the web's "Ask" (App.html "THE ASSISTANT: ASK THE APP IN YOUR OWN WORDS", asked 04/05-10-2026), its
 * working ported line by line – the same words in English, मराठी and हिंदी:
 *   – the ⚡ READY questions answered by the app itself (the daily summary, pending Log Book, yesterday's / today's diesel, the
 *     stock, those over the standard) – offered for the page he is on (AI_READY / aiReadyFor);
 *   – a TYPED question the app understands by itself (aiLocal: diesel, pending, stock, average, work, the last reading – the
 *     machinery found in the words, the dates from "today / काल / last month / September / 02-10-2026 …");
 *   – an ENTRY made from words (aiCommand / aiDraft: "8511 ला 60 लिटर diesel दे, reading 148200", "EX-200 आज idle") – never
 *     saved by itself: shown, then saved only by his Save / "हो", through the app's own save and checks (ai_chat.dart);
 *   – the look-ups the AI service asks for (AI_RUN) run here with his own sign-in; the snapshot of the day; the daily summary
 *     (getBrief) and what is said aloud (aiSpeakable).
 * Proven against the web's own code: test/assistant_test.dart (fixtures/ai/web_ai.json – the web's functions run in node). */
import 'format.dart' show asNum, showDate;
import 'rdoc.dart' show fmt, money;
import 'sheet_read.dart' show jsS, jsTrue;
import 'web_help.dart';

/// One action of Mechanical with his sign-in ([save]: it changes data).
typedef AiCall = Future<dynamic> Function(String fn, List<dynamic> args, {bool save});

/// A message of the assistant itself that ends a step (the web's `throw new Error('…')`).
class AiStop implements Exception {
  AiStop(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The web's errMsg: the words of an error.
String aiErr(Object e) => '$e'.replaceFirst(RegExp(r'^(Error|Exception):\s*'), '');

/// "" or a number – a value really given (the web's aiN: nothing given stays "", never 0).
Object aiN(Object? v) {
  final t = v == null ? '' : jsS(v).replaceAll(',', '').trim();
  if (t.isEmpty) return '';
  final n = num.tryParse(t);
  return n == null || n.isNaN || n.isInfinite ? '' : n;
}

/// Number(v) || 0 of JavaScript.
num jsN(Object? v) {
  if (v is num) return v.isNaN ? 0 : v;
  if (v == null || v == false) return 0;
  if (v == true) return 1;
  final t = '$v'.trim();
  return t.isEmpty ? 0 : (num.tryParse(t) ?? 0);
}

/// The web's aiNum: Math.round(n × 100) / 100.
num aiNum(Object? v) {
  final r = (jsN(v) * 100 + 0.5).floor() / 100;
  return r == r.truncateToDouble() ? r.toInt() : r;
}

/// String(x) of JavaScript, for a value put in a text.
String js(Object? v) => v == null ? 'undefined' : jsS(v);

String noKey(Object? v) => (v == null ? '' : '$v').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

String addDay(String d, int n) {
  final t = DateTime.utc(int.parse(d.substring(0, 4)), int.parse(d.substring(5, 7)), int.parse(d.substring(8, 10)) + n);
  return _iso(t.year, t.month, t.day);
}

String _iso(int y, int m, int d) => '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

/// The keys of a JavaScript object in its own order: whole-number keys first (smallest first), then the rest as added.
List<String> jsKeys(Iterable<String> keys) {
  final idx = RegExp(r'^(0|[1-9]\d{0,8})$');
  final n = keys.where(idx.hasMatch).toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  return [...n, ...keys.where((k) => !idx.hasMatch(k))];
}

/// A period the question is about: {from, to, said}.
class AiPeriod {
  const AiPeriod(this.from, this.to, [this.said = false]);
  final String from, to;
  final bool said;
  Map<String, Object> toJson() => {'from': from, 'to': to, if (said) 'said': true};
}

const kAiMon = [
  ['jan', 'जानेवारी', 'जनवरी'], ['feb', 'फेब्रुवारी', 'फरवरी'], ['mar', 'मार्च'], ['apr', 'एप्रिल', 'अप्रैल'], ['may', 'मे '], ['jun', 'जून'], //
  ['jul', 'जुलै', 'जुलाई'], ['aug', 'ऑगस्ट', 'अगस्त'], ['sep', 'सप्टेंबर', 'सितंबर'], ['oct', 'ऑक्टोबर', 'अक्टूबर'], ['nov', 'नोव्हेंबर', 'नवंबर'], ['dec', 'डिसेंबर', 'दिसंबर'],
];

RegExp _ri(String s) => RegExp(s, caseSensitive: false);

/// The kinds of question the app answers itself (the web's AI_KIND; the phone's Marathi / Hindi listening writes English words
/// in Devanagari: स्टॉक, पेंडिंग, ॲव्हरेज, लॉग बुक …).
final kAiKind = <String, RegExp>{
  'brief': _ri(r'summary|saransh|सारांश|aadhava|आढावा|brief|overview|समरी'),
  'diesel': _ri(r'diesel|dizel|डिझेल|डीझेल|डीजल|डीज़ल|fuel|इंधन|ईंधन'),
  'pending': _ri(r'pending|पेंडिंग|पेन्डिंग|baki|baaki|बाकी|rahil|राहिल|remaining|not entered|entry nahi|entry नाही|एंट्री नाही'),
  'stock': _ri(r'stock|स्टॉक|स्टाक|स्टोक|साठा|shillak|शिल्लक|balance|बॅलन्स|बचा'),
  'average': _ri(r'average|avg\b|सरासरी|mileage|मायलेज|अॅव्हरेज|ॲव्हरेज|अ‍ॅव्हरेज|एव्हरेज|अवरेज|एवरेज|औसत|consumption'),
  'work': _ri(r'\bkm\b|kilomet|किमी|किलोमीटर|hours|\bhrs?\b|तास|घंटे|chalali|chalala|चालली|चालला|चालले|worked|work done|kam kel|काम केल|काम किती'),
  'reading': _ri(r'reading|रीडिंग|रिडिंग|meter|मीटर'),
};

/// Words that make a question one for the AI ("how much / how many" are plain questions; "का" only as a word of its own).
final kAiHard = _ri(
    r'\bwhy\b|\bhow\b(?!\s+(much|many))|explain|compare|versus|\bvs\b|difference|reason|kashamule|\bka\s+(ahe|aahe|zale|zala)|(^|\s)का(\s|\?|$)|कशामुळे|कसे|कसा|कशी|क्यों|कैसे|तुलना|फरक|कारण|solution|उपाय|who (changed|deleted|added|edited)|कोणी (बदल|काढ|delete)|किसने');
final kAiGive = _ri(r'\b(de|dya|issue|add|enter|bhar|bhara|tak|taka|nond)\b|(^|\s)(दे|द्या|भर|भरा|टाक|टाका|नोंद|नोंदव)(\s|$|[.!,])');
final kAiAskQ = _ri(r'\bkiti\b|किती|कितना|कितनी|how much|how many|\bkon\b|koni|कोण|कौन|किसने|\?|बाकी|pending|सारांश|summary|average|सरासरी');
final kAiDo = _ri(r'\b(de|dya|deun|dile|dila|issue|bhar|bhara|bharle|tak|taka|add|enter|save|nond|kar|kara|ghal|ghala|ghe)\b|दे|द्या|दिले|दिला|भर|टाक|नोंद|जोड|कर|घाल|घे');
final kAiYes = _ri(r'^(हो|होय|हा|हां|हाँ|जी|ho|hoy|haan|han|yes|ok|okay|save|sev|कर|करा|kar|kara|ठीक|ठीक आहे|thik|सेव्ह|सेव|सेव्ह कर|save कर)[\s.!।]*$');
final kAiNo = _ri(r'^(नाही|नको|नहीं|मत|no|nahi|nako|cancel|रद्द|रद्द कर|कॅन्सल|कैंसल)[\s.!।]*$');
final kAiStopWords = _ri(r'^(stop|थांब|थांबा|बस|बंद कर|बंद करा|रुको|रुक जाओ|thamb|bas)[.!।\s]*$');
final _rom = _ri(
    r'\b(kiti|kay|ahe|aahe|ghetle|ghetla|dile|dila|baki|kon|koni|konti|konta|chi|cha|che|sang|kitna|kitni|kya|hai|kaun|diya|liya|mahina|mahinyat|aaj|aajchi|aajcha|kal|la|de|dya|ne|madhe|sathi|kar|kara|taka|bhara|nond|ghal|karo|dalo)\b');

const kAiMonths = {
  'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
  'mr': ['जानेवारी', 'फेब्रुवारी', 'मार्च', 'एप्रिल', 'मे', 'जून', 'जुलै', 'ऑगस्ट', 'सप्टेंबर', 'ऑक्टोबर', 'नोव्हेंबर', 'डिसेंबर'],
  'hi': ['जनवरी', 'फरवरी', 'मार्च', 'अप्रैल', 'मई', 'जून', 'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'],
};

/// The voice of each language (the web's AI_SPEECH).
const kAiSpeech = {'mr': 'mr-IN', 'hi': 'hi-IN', 'en': 'en-IN'};

/// What is said aloud: the start of the answer (4 lines, ~420 letters), without marks; dates and units as words.
String aiSpeakable(String text, String l) {
  final t = text.replaceAll('🔊', '').replaceAll(RegExp(r'\[\[open:[^\]]*\]\]'), '').replaceAll(RegExp(r'[A-Za-z ]+ →'), '').replaceAll('**', '').replaceAll(RegExp('[•⚡✓]'), ' ');
  final lines = [for (final x in t.split('\n')) if (x.trim().isNotEmpty) x.trim()];
  var out = '', n = 0;
  for (final x in lines) {
    if (n >= 4 || out.length + x.length > 420) break;
    out += (out.isNotEmpty ? '. ' : '') + x;
    n++;
  }
  final more = lines.length > n;
  String w(Map<String, String> m) => m[l] ?? 'undefined';
  out = out
      .replaceAllMapped(RegExp(r'\b(\d{1,2})-(\d{2})-(\d{4})\b'), (m) => '${int.parse(m[1]!)} ${(kAiMonths[l] ?? kAiMonths['en']!)[int.parse(m[2]!) - 1]}')
      .replaceAllMapped(RegExp(r'(\d)\s*L\b'), (m) => '${m[1]} ${w(const {'en': 'litres', 'mr': 'लिटर', 'hi': 'लीटर'})}')
      .replaceAll(RegExp(r'\bkm\/L\b'), w(const {'en': 'kilometres per litre', 'mr': 'किलोमीटर प्रति लिटर', 'hi': 'किलोमीटर प्रति लीटर'}))
      .replaceAll(RegExp(r'\bL\/hr\b'), w(const {'en': 'litres per hour', 'mr': 'लिटर प्रति तास', 'hi': 'लीटर प्रति घंटा'}))
      .replaceAll(RegExp(r'\bkm\b'), w(const {'en': 'kilometres', 'mr': 'किलोमीटर', 'hi': 'किलोमीटर'}))
      .replaceAll(RegExp(r'\bhr\b'), w(const {'en': 'hours', 'mr': 'तास', 'hi': 'घंटे'}))
      .replaceAll(RegExp(r'₹\s?'), w(const {'en': 'rupees ', 'mr': 'रुपये ', 'hi': 'रुपये '}))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return out + (more ? ' ${w(const {'en': 'The rest is on the screen.', 'mr': 'बाकी screen वर आहे.', 'hi': 'बाकी screen पर है।'})}' : '');
}

/// One prepared entry (the web's aiDraft): what is shown, what is said, and what is sent when he presses Save.
class AiDraft {
  AiDraft({this.error = '', this.need = '', this.partial, this.kind = '', this.tab = '', this.title = '', this.data = const {}, this.notes = const [], this.lines = const [], this.say = ''});
  final String error, need, kind, tab, title, say;
  final AiCmd? partial;
  final Map<String, Object?> data;
  final List<String> notes;
  final List<(String, String)> lines;
  bool get ready => error.isEmpty && need.isEmpty;
}

/// A command understood from words: diesel / log, and what was said.
class AiCmd {
  AiCmd(this.kind, this.a);
  final String kind;
  final Map<String, Object?> a;
}

/// A ⚡ question (the web's AI_READY): the pages it is offered on, and its answer.
class AiReady {
  AiReady(this.id, this.pages, this.q, this.run, {this.always = false, this.when});
  final String id;
  final List<String> pages;
  final String Function() q;
  final Future<String> Function() run;
  final bool always;
  final bool Function()? when;
}

class Assistant {
  Assistant({
    required this.call,
    required this.today,
    required this.master,
    this.locations = const [],
    this.prefs = const {},
    required this.canEdit,
    this.helpLang = 'mr',
    this.onSite,
    this.tabs = const [],
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AiCall call;
  String today, helpLang;
  List<Map<String, dynamic>> master;
  List<String> locations;
  /// (3.43.0, Mechanical update-162) his own diesel sources for a Diesel Issue when the Super Admin gave him some (null = every place)
  List<String>? ownSources;
  /// (3.44.0, Mechanical update-163) the fuel of each diesel place: a fill is drafted from a place of the machinery's fuel
  Map<String, String> placeFuels = const {};
  /// (3.45.0, Mechanical update-164) a site on fuel cards (HO): no diesel stock – the cards' balances; a fill is made in its form
  bool cardSite = false;
  Map prefs;
  final bool Function(String module) canEdit;
  final bool Function(Map<String, dynamic> m)? onSite;
  final DateTime Function() now;

  /// The pages he can open (the web's aiTabs: tab, title) – for the guide and for the [[open:…]] buttons.
  List<(String, String)> tabs;

  /// The page the assistant was opened on, and what is picked on it (the web's S.curTab, aiPicked, aiDay).
  String page = 'dash', picked = '', pageDay = '';

  /// The language of the question being answered ('' = the help language) – the web's AI.lang.
  String lang = '';
  String get l => lang.isNotEmpty ? lang : helpLang;
  String aiL(Map<String, String> o) => o[l] ?? o['en']!;

  Map<String, dynamic>? findMachine(Object? no) {
    final k = noKey(no);
    if (k.isEmpty) return null;
    for (final m in master) {
      if (noKey(m['id']) == k) return m;
    }
    return null;
  }

  /* ---------------- the look-ups (AI_RUN) ---------------- */
  String aiMach(Object? q) {
    final s = (q == null ? '' : '$q').trim();
    if (s.isEmpty) return '';
    final m = findMachine(s);
    return m != null ? '${m['id']}' : s;
  }

  static List<Map<String, Object?>> aiCut(Object? rows, List<String> keys, int max) => [
        for (final r in (rows is List ? rows : const []).take(max))
          if (r is Map) {for (final k in keys) if (r[k] != '' && r[k] != null) k: r[k]} else <String, Object?>{},
      ];

  static List<Map<String, Object>> aiSplit(List rows, String key, String val, int top) {
    final m = <String, num>{};
    for (final r in rows) {
      final k = r is Map && jsTrue(r[key]) ? js(r[key]) : '(none)';
      m[k] = aiNum((m[k] ?? 0) + jsN(r is Map ? r[val] : null));
    }
    final l = [for (final (i, k) in jsKeys(m.keys).indexed) (i, k, m[k]!)]..sort((a, b) => b.$3 != a.$3 ? b.$3.compareTo(a.$3) : a.$1.compareTo(b.$1));
    return [for (final x in l.take(top)) {'name': x.$2, 'litres': x.$3}];
  }

  Future<Map> _call(String fn, [List<dynamic> args = const []]) async {
    final r = await call(fn, args);
    return r is Map ? r : {};
  }

  static List _rows(Map d) => d['rows'] is List ? d['rows'] as List : const [];
  static num _sum(List rows, String k) => aiNum(rows.fold<num>(0, (t, r) => t + jsN(r is Map ? r[k] : null)));

  Future<Map<String, Object?>> runDieselIssues(Map a) async {
    final no = aiMach(a['machinery']), d = await _call('getDieselIssues', [{'from': a['from'], 'to': a['to'], 'no': no, 'all': true}]), rows = _rows(d);
    return {
      'from': a['from'], 'to': a['to'], 'machinery': no.isEmpty ? 'all' : no, 'entries': rows.length, 'totalLitres': _sum(rows, 'qty'),
      'byMachinery': aiSplit(rows, 'no', 'qty', 25), 'byOwner': aiSplit(rows, 'owner', 'qty', 15),
      'rows': aiCut(rows, const ['date', 'shift', 'no', 'type', 'owner', 'qty', 'kmReading', 'hrReading', 'source', 'driver', 'enteredBy', 'remark'], 60),
      'note': rows.length > 60 ? 'only the first 60 entries are listed; the totals cover all ${rows.length}' : '', 'page': 'diesel',
    };
  }

  Future<Map<String, Object?>> runLogBook(Map a) async {
    final no = aiMach(a['machinery']), d = await _call('getLogBookList', [{'from': a['from'], 'to': a['to'], 'no': no, 'all': true}]), rows = _rows(d);
    return {
      'from': a['from'], 'to': a['to'], 'machinery': no.isEmpty ? 'all' : no, 'entries': rows.length, 'totalKm': _sum(rows, 'wkm'), 'totalHours': _sum(rows, 'whr'),
      'dieselIssuedLitres': _sum(rows, 'qty'),
      'rows': aiCut(rows, const ['date', 'shift', 'no', 'type', 'owner', 'unit', 'okm', 'ckm', 'wkm', 'ohr', 'chr', 'whr', 'trip', 'qty', 'stdUse', 'stock', 'avg', 'work', 'chainage', 'driver', 'remark', 'enteredBy'], 50),
      'note': rows.length > 50 ? 'only the first 50 entries are listed; the totals cover all ${rows.length}' : '', 'page': 'log',
    };
  }

  Future<Map<String, Object?>> runPending(Map a) async {
    final d = await _call('logPending'), items = [for (final x in (d['items'] is List ? d['items'] as List : const [])) if (x is List && x.length > 1) x], no = aiMach(a['machinery']);
    if (jsTrue(a['date'])) {
      final l = [for (final x in items) if (x[1] == a['date']) x[0]];
      return {'date': a['date'], 'machineryWithoutLogBook': l.length, 'machinery': l.take(120).toList(), 'page': 'log'};
    }
    if (no.isNotEmpty) {
      final l = [for (final x in items) if (noKey(x[0]) == noKey(no)) js(x[1])]..sort();
      return {'machinery': no, 'datesWithoutLogBook': l.length, 'dates': l.take(120).toList(), 'page': 'log'};
    }
    final by = <String, int>{};
    for (final x in items) {
      by[js(x[1])] = (by[js(x[1])] ?? 0) + 1;
    }
    final days = by.keys.toList()..sort();
    final last = days.length > 10 ? days.sublist(days.length - 10) : days;
    return {'from': d['from'], 'upTo': d['asOf'], 'pendingDaysInAll': d['total'], 'lastTenDays': [for (final k in last) {'date': k, 'machinery': by[k]}], 'page': 'log'};
  }

  Future<Map<String, Object?>> runStock() async {
    final d = await _call('getStock');
    if (cardSite) {
      return {'onFuelCards': true, 'noDieselStock': true, 'cards': [for (final c in (d['cards'] is List ? d['cards'] as List : const []).whereType<Map>()) {'card': c['name'], 'balanceRupees': c['balance'], 'active': c['active'], 'lastFill': c['lastFill'] ?? ''}], 'page': 'cards'};
    }
    return {'litresInStockNow': d['stock'], 'byLocation': d['byLoc'], 'receivedInAll': d['inward'], 'issuedInAll': d['issued'], 'page': 'dash'};
  }

  static const _avgKeys = ['no', 'type', 'owner', 'ownership', 'unit', 'km', 'hr', 'used', 'expected', 'excess', 'pct', 'actual', 'std', 'status'];

  Future<Map<String, Object?>> runAverage(Map a) async {
    final d = await _call('rptAverage', [{'from': a['from'], 'to': a['to']}]);
    var rows = [for (final g in (d['groups'] is List ? d['groups'] as List : const [])) if (g is Map && g['rows'] is List) ...(g['rows'] as List)].whereType<Map>().toList();
    final no = aiMach(a['machinery']);
    if (no.isNotEmpty) {
      rows = rows.where((r) => noKey(r['no']) == noKey(no)).toList();
      return {'from': a['from'], 'to': a['to'], 'machinery': aiCut(rows, _avgKeys, 5), 'meaning': 'used = diesel taken (L); expected = diesel the standard says the work needed (L); pct = % more (+) or less (−) than expected', 'page': 'rp-avg'};
    }
    final n = <String, int>{};
    for (final r in rows) {
      final k = jsTrue(r['statusCode']) ? js(r['statusCode']) : 'no status';
      n[k] = (n[k] ?? 0) + 1;
    }
    final over = [for (final (i, r) in rows.indexed) if (r['statusCode'] == 'bad' || r['statusCode'] == 'more') (i, r)]
      ..sort((x, y) {
        final c = jsN(y.$2['excess']).compareTo(jsN(x.$2['excess']));
        return c != 0 ? c : x.$1.compareTo(y.$1);
      });
    return {
      'from': a['from'], 'to': a['to'], 'machineryInAll': rows.length, 'counts': n, 'mostDieselOverTheStandard': aiCut([for (final x in over) x.$2], _avgKeys, 15),
      'toCheck': aiCut(rows.where((r) => r['statusCode'] == 'check').toList(), _avgKeys, 10),
      'meaning': 'used = diesel taken (L); expected = diesel the standard says the work needed (L); excess = used − expected', 'page': 'rp-avg',
    };
  }

  Future<Map<String, Object?>> runWatch(Map a) async {
    final d = await _call('rptWatch', [{'from': a['from'], 'to': a['to']}]);
    return {
      'from': a['from'], 'to': a['to'], 'total': d['total'], 'signs': aiCut(d['findings'], const ['no', 'type', 'owner', 'date', 'kind', 'litres', 'amount', 'text'], 20),
      'dieselThatCannotBeChecked': aiCut(d['unchecked'], const ['no', 'type', 'owner', 'ownership', 'fills', 'qty'], 15), 'note': 'signs are things to look at, not proof', 'page': 'rp-watch',
    };
  }

  Future<Map<String, Object?>> runActivity(Map a) async {
    final text = jsTrue(a['text']) ? a['text'] : '';
    final d = await _call('getActivity', [{'from': a['from'], 'to': a['to'], 'q': text}]);
    return {
      'from': a['from'], 'to': a['to'], 'lookedFor': text, 'entries': d['count'],
      'rows': [
        for (final r in aiCut(d['rows'], const ['when', 'name', 'action', 'module', 'record', 'summary', 'changes'], 60))
          {...r, if (jsTrue(r['changes'])) 'changes': js(r['changes']).length > 240 ? js(r['changes']).substring(0, 240) : js(r['changes'])},
      ],
      'page': 'activity',
    };
  }

  Map<String, Object?> runMachinery(Map a) {
    final q = (a['query'] == null ? '' : '${a['query']}').trim().toUpperCase();
    if (q.isEmpty) {
      final c = <String, int>{}, t = <String, int>{};
      for (final m in master) {
        final o = jsTrue(m['ownership']) ? '${m['ownership']}' : 'Other', ty = jsTrue(m['type']) ? '${m['type']}' : '(no type)';
        c[o] = (c[o] ?? 0) + 1;
        t[ty] = (t[ty] ?? 0) + 1;
      }
      return {'machineryInAll': master.length, 'active': master.where(onSite ?? (_) => true).length, 'byOwnership': c, 'byType': t, 'page': 'master'};
    }
    final hit = master.where((m) => [m['id'], m['name'], m['type'], m['owner']].any((v) => (v == null ? '' : '$v').toUpperCase().contains(q))).toList();
    return {'found': hit.length, 'machinery': aiCut(hit, const ['id', 'name', 'type', 'owner', 'ownership', 'unit', 'kmStd', 'hrStd', 'tankCap', 'status', 'supply', 'activeFrom'], 25), 'page': 'master'};
  }

  /// How the app works (the web's app_guide): the pages that fit the words, the help for a message, the pages he can open.
  Future<Map<String, Object?>> runGuide(Map a) async {
    final topic = a['topic'] == null ? '' : '${a['topic']}';
    final words = topic.toLowerCase().split(RegExp(r'[^a-z0-9ऀ-ॿ]+')).where((w) => w.length > 2).toList();
    final help = WebHelp.now ?? await WebHelp.load();
    final scored = <(int, (String, String), HelpText?, int)>[];
    for (final (i, t) in tabs.indexed) {
      final g = help.guideOf(t.$1);
      final text = '${t.$2} ${g != null ? '${(g['en'] ?? const []).join(' ')} ${(g['mr'] ?? const []).join(' ')} ${(g['hi'] ?? const []).join(' ')}' : ''}'.toLowerCase();
      final n = words.fold<int>(0, (k, w) => k + (text.contains(w) ? (t.$2.toLowerCase().contains(w) ? 3 : 1) : 0));
      if (n > 0) scored.add((i, t, g, n));
    }
    scored.sort((x, y) => y.$4 != x.$4 ? y.$4.compareTo(x.$4) : x.$1.compareTo(y.$1));
    final errs = help.fix.where((r) => r.re.hasMatch(topic)).take(3).map((r) => {'whatWentWrong': r.text['en']![0], 'whatToDo': r.text['en']![1]}).toList();
    return {
      'pagesThatFit': [
        for (final x in scored.take(5)) {'tab': x.$2.$1, 'title': x.$2.$2, 'whatItIsFor': x.$3 != null ? x.$3!['en']![0] : '', 'howToUseIt': x.$3 != null ? x.$3!['en']![1] : ''},
      ],
      'helpForThisMessage': errs,
      'allPagesThisUserCanOpen': [for (final t in tabs) {'tab': t.$1, 'title': t.$2}],
      // (the app's own buttons in place of the web page's keys)
      'keys': 'Home → the search button = search, the QR button = scan a machinery label, Back = back, the ? of a page = its guide',
    };
  }

  /// A look-up the AI service asked for, run here with his own sign-in (the web's AI_RUN; the two "prepare" ones are the chat's).
  Future<Map<String, Object?>> run(String name, Map a) => switch (name) {
        'diesel_issues' => runDieselIssues(a),
        'log_book' => runLogBook(a),
        'pending_log_book' => runPending(a),
        'diesel_stock' => runStock(),
        'machinery' => Future.value(runMachinery(a)),
        'diesel_average' => runAverage(a),
        'diesel_watch' => runWatch(a),
        'activity' => runActivity(a),
        'app_guide' => runGuide(a),
        _ => Future.value(<String, Object?>{'error': 'There is no such look-up.'}),
      };

  static const kAiNames = {
    'prepare_diesel_issue': 'Diesel Issue – prepared', 'prepare_log_entry': 'Log Book entry – prepared', 'diesel_issues': 'Diesel issues', 'log_book': 'Log Book',
    'pending_log_book': 'Pending Log Book', 'diesel_stock': 'Diesel stock', 'machinery': 'Asset Master', 'diesel_average': 'Actual vs standard average', 'diesel_watch': 'Diesel Watch',
    'activity': 'Activity Log', 'app_guide': 'The app\'s guide',
  };

  /// "Diesel issues 01-10-2026 to 16-10-2026 · 8511" – what was looked up (shown under the answer).
  static String aiWhat(String name, Map a) =>
      (kAiNames[name] ?? name) +
      (jsTrue(a['from'])
          ? ' ${showDate('${a['from']}')}${jsTrue(a['to']) && a['to'] != a['from'] ? ' to ${showDate('${a['to']}')}' : ''}'
          : jsTrue(a['date'])
              ? ' ${showDate('${a['date']}')}'
              : '') +
      (jsTrue(a['machinery']) || jsTrue(a['query']) || jsTrue(a['text']) ? ' · ${js(jsTrue(a['machinery']) ? a['machinery'] : jsTrue(a['query']) ? a['query'] : a['text'])}' : '');

  /* ---------------- words ---------------- */
  static String aiList(List a, int n) => a.take(n).map(js).join(', ') + (a.length > n ? ' … (+${a.length - n})' : '');
  static String aiTop(Object? a, int n) => [for (final x in (a is List ? a : const []).take(n)) if (x is Map) '${js(x['name'])} ${fmt(x['litres'])} L'].join(', ');

  /// The language of the answer: Devanagari, or Marathi / Hindi words in English letters → Marathi (Hindi if the help is Hindi).
  String aiLangOf(String text) => RegExp(r'[ऀ-ॿ]').hasMatch(text) || _rom.hasMatch(text) ? (helpLang == 'hi' ? 'hi' : 'mr') : 'en';

  /// The machinery named: its whole number (with or without dashes), its name, or four digits that only one machinery ends with.
  Map<String, dynamic>? aiFindMach(String text) {
    final k = noKey(text);
    if (k.isEmpty) return null;
    final byId = [for (final (i, m) in master.indexed) if (noKey(m['id']).length >= 5 && k.contains(noKey(m['id']))) (i, m)]
      ..sort((a, b) {
        final c = noKey(b.$2['id']).length.compareTo(noKey(a.$2['id']).length);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    Map<String, dynamic>? hit = byId.isEmpty ? null : byId.first.$2;
    hit ??= master.where((m) => jsTrue(m['name']) && m['name'] != m['id'] && noKey(m['name']).length >= 6 && k.contains(noKey(m['name']))).firstOrNull;
    if (hit == null) {
      for (final x in RegExp(r'\b\d{4}\b').allMatches(text).map((x) => x[0]!).where((x) => !RegExp(r'^20\d\d$').hasMatch(x))) {
        final c = master.where((m) => RegExp('$x\$').hasMatch(noKey(m['id']))).toList();
        if (c.length == 1) {
          hit = c.first;
          break;
        }
      }
    }
    return hit;
  }

  /// The dates the question is about (the web's aiPeriod); [def]: 'today' / 'month' / '' (the last 30 days).
  AiPeriod aiPeriod(String text, String def) {
    final t = ' ${text.toLowerCase()} ';
    final ds = <String>[
      for (final m in RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').allMatches(t)) '${m[1]}-${m[2]}-${m[3]}',
      for (final m in RegExp(r'\b(\d{1,2})[-\/.](\d{1,2})[-\/.](\d{4})\b').allMatches(t)) '${m[3]}-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}',
    ];
    if (ds.isNotEmpty) {
      final a = [...ds]..sort();
      return AiPeriod(a.first, a.last, true);
    }
    AiPeriod monthOf(int y, int m) => AiPeriod(_iso(y, m, 1), _iso(y, m, DateTime.utc(y, m + 1, 0).day), true);
    final y = int.parse(today.substring(0, 4)), mo = int.parse(today.substring(5, 7));
    bool has(String re) => RegExp(re).hasMatch(t);
    if (has(r'last month|previous month|magchya mahin|maghil mahin|gelya mahin|मागच्या महिन|मागील महिन|गेल्या महिन|pichhle mahine|पिछले मह')) {
      final d = DateTime.utc(y, mo - 1, 1);
      return monthOf(d.year, d.month);
    }
    if (has(r'this month|ya mahin|hya mahin|या महिन|ह्या महिन|चालू महिन|is mahine|इस मह')) return AiPeriod('${today.substring(0, 8)}01', today, true);
    if (has(r'last week|magchya aathavd|gelya aathavd|मागच्या आठवड|गेल्या आठवड|pichhle hafte|पिछले हफ्ते')) return AiPeriod(addDay(today, -13), addDay(today, -7), true);
    if (has(r'this week|ya aathavd|या आठवड|is hafte|इस हफ्ते|last 7 days|7 days|7 दिवस|7 दिन')) return AiPeriod(addDay(today, -6), today, true);
    if (has(r'day before yesterday|parva|परवा|parso|परसों')) return AiPeriod(addDay(today, -2), addDay(today, -2), true);
    if (has(r'yesterday|\bkal\b|\bkaal\b|काल|कल ')) return AiPeriod(addDay(today, -1), addDay(today, -1), true);
    if (has(r'today|\baaj\b|\baj\b|आज|\bnow\b|आत्ता|अभी')) return AiPeriod(today, today, true);
    for (var m = 0; m < 12; m++) {
      if (kAiMon[m].any((w) => t.contains(w) && (w.length > 3 || RegExp('\\b$w').hasMatch(t)))) return monthOf(m + 1 > mo ? y - 1 : y, m + 1);
    }
    return def == 'today'
        ? AiPeriod(today, today)
        : def == 'month'
            ? AiPeriod('${today.substring(0, 8)}01', today)
            : AiPeriod(addDay(today, -29), today);
  }

  static String aiSpan(AiPeriod p, String l) =>
      p.from == p.to ? showDate(p.from) : '${showDate(p.from)}${const {'en': ' to ', 'mr': ' ते ', 'hi': ' से '}[l] ?? 'undefined'}${showDate(p.to)}';

  /// Numbers said with their meter: "km 148200", "148200 km", "reading 148200", "hr 5095", "5095 तास".
  static Map<String, num> aiReadings(String text) {
    final t = text.replaceAllMapped(RegExp(r'(\d),(?=\d)'), (m) => m[1]!);
    final out = <String, num>{};
    final km = _ri(r'(?:\bkm|किमी|किलोमीटर)\s*(?:reading|रीडिंग|रिडिंग)?\s*[:=]?\s*(\d+(?:\.\d+)?)').firstMatch(t) ?? _ri(r'(\d+(?:\.\d+)?)\s*(?:km\b|किमी|किलोमीटर)(?!\s*\/)').firstMatch(t);
    final hr = _ri(r'(?:\bhrs?\b|\bhours?\b|तास|घंटे|घंटा)\s*(?:reading|रीडिंग|रिडिंग)?\s*[:=]?\s*(\d+(?:\.\d+)?)').firstMatch(t) ?? _ri(r'(\d+(?:\.\d+)?)\s*(?:hrs?\b|hours?\b|तास|घंटे)').firstMatch(t);
    final any = _ri(r'(?:reading|रीडिंग|रिडिंग|close|closing|क्लोज|क्लोजिंग)\s*(?:reading|रीडिंग|रिडिंग)?\s*[:=]?\s*(\d+(?:\.\d+)?)').firstMatch(t);
    if (km != null) out['km'] = num.parse(km[1]!);
    if (hr != null) out['hr'] = num.parse(hr[1]!);
    if (any != null && km == null && hr == null) out['any'] = num.parse(any[1]!);
    return out;
  }

  /// A plain command (the web's aiCommand); null = not a command.
  AiCmd? aiCommand(String text) {
    final t = text, m = aiFindMach(t);
    final qty = _ri(r'(\d+(?:\.\d+)?)\s*(?:l\b|ltr|litres?|liters?|लिटर|लीटर|लि\b)').firstMatch(t.replaceAllMapped(RegExp(r'(\d),(?=\d)'), (x) => x[1]!));
    final dieselWord = kAiKind['diesel']!.hasMatch(t);
    final status = _ri(r'\bidle\b|आयडल|आयडॉल|उभी|उभा|khadi|खड़ी').hasMatch(t)
        ? 'Idle'
        : _ri(r'holiday|सुट्टी|सुटी|छुट्टी').hasMatch(t)
            ? 'Holiday'
            : _ri(r'breakdown|ब्रेकडाउन|ब्रेक डाउन|बंद पडल|खराब').hasMatch(t)
                ? 'Breakdown'
                : '';
    final logWord = _ri(r'log ?book|लॉग ?बुक|\bentry\b|एंट्री|एन्ट्री|नोंद').hasMatch(t), rd = aiReadings(t), d = aiPeriod(t, 'today');
    if (kAiAskQ.hasMatch(t) && !_ri(r'^.*(कर|करा|दे|द्या|टाक|\bkar\b|\bde\b)\s*[.!]?$').hasMatch(t.trim())) return null; // a question, not a command
    final date = d.said && d.from == d.to ? d.from : '';
    final shift = _ri(r'night|रात्र|ratri|\braat\b|रात').hasMatch(t)
        ? 'Night'
        : _ri(r'full ?day|पूर्ण दिवस').hasMatch(t)
            ? 'Full Day'
            : _ri(r'\bday\b|दिवस पाळी|दिन की').hasMatch(t)
                ? 'Day'
                : '';
    final unit = m == null ? '' : '${m['unit'] ?? ''}';
    final kmOnly = unit.contains('KM') && !unit.contains('Hrs'), hrOnly = unit.contains('Hrs') && !unit.contains('KM');
    if (dieselWord && ((qty != null && (kAiDo.hasMatch(t) || m != null)) || (m != null && kAiGive.hasMatch(t)))) {
      final loc = locations.where((l) => t.toLowerCase().contains(l.toLowerCase())).firstOrNull ?? '';
      return AiCmd('diesel', {
        'machinery': m != null ? m['id'] : '', 'litres': qty != null ? num.parse(qty[1]!) : '', 'date': date, 'shift': shift == 'Full Day' ? '' : shift, 'source': loc,
        'km_reading': rd['km'] ?? (m != null && rd['any'] != null && kmOnly ? rd['any'] : ''),
        'hr_reading': rd['hr'] ?? (m != null && rd['any'] != null && hrOnly ? rd['any'] : ''),
      });
    }
    if (!dieselWord && m != null && (status.isNotEmpty || ((logWord || _ri(r'close|closing|क्लोज').hasMatch(t)) && (rd['km'] != null || rd['hr'] != null || rd['any'] != null)))) {
      return AiCmd('log', {
        'machinery': m['id'], 'date': date, 'shift': shift, 'status': status,
        'close_km': rd['km'] ?? (rd['any'] != null && kmOnly ? rd['any'] : ''),
        'close_hr': rd['hr'] ?? (rd['any'] != null && hrOnly ? rd['any'] : ''),
      });
    }
    return null;
  }

  /* ---------------- the ⚡ questions (AI_READY) ---------------- */
  String get aiDay => page == 'log' && pageDay.isNotEmpty ? pageDay : today;

  Future<String> dieselDay(String d) async {
    final r = await runDieselIssues({'from': d, 'to': d}), n = r['entries'] as int, sd = showDate(d), tl = fmt(r['totalLitres']);
    return (n > 0
            ? '${aiL({'en': '$sd: **$tl L** in $n entries.', 'mr': '$sd: **$tl L**, $n entries.', 'hi': '$sd: **$tl L**, $n entries।'})}\n'
                '${aiL(const {'en': 'By machinery: ', 'mr': 'गाडीनुसार: ', 'hi': 'गाड़ी के अनुसार: '})}${aiTop(r['byMachinery'], 12)}\n'
                '${aiL(const {'en': 'By owner: ', 'mr': 'मालकानुसार: ', 'hi': 'मालिक के अनुसार: '})}${aiTop(r['byOwner'], 8)}'
            : aiL({'en': 'No diesel was issued on $sd.', 'mr': '$sd ला diesel दिलेले नाही.', 'hi': '$sd को diesel नहीं दिया गया।'})) +
        '\n[[open:diesel|Diesel Issue]]';
  }

  late final List<AiReady> ready = [
    AiReady('brief', const ['dash'], () => aiL(const {'en': 'Summary: yesterday, and what needs a look today', 'mr': 'सारांश: काल काय झाले आणि आज कशाकडे लक्ष द्यायचे', 'hi': 'सारांश: कल क्या हुआ और आज किस पर ध्यान देना है'}), briefText,
        always: true),
    AiReady('pending', const ['log', 'dash', 'logedit', 'rp-pending'], () {
      final sd = showDate(aiDay);
      return aiL({'en': 'Which machinery have no Log Book entry for $sd?', 'mr': '$sd ला कोणत्या गाड्यांची Log Book entry बाकी आहे?', 'hi': '$sd को किन गाड़ियों की Log Book entry बाकी है?'});
    }, () async {
      final d = aiDay, r = await runPending({'date': d}), n = r['machineryWithoutLogBook'] as int, sd = showDate(d);
      return (n > 0
              ? '${aiL({'en': '**$n machinery** have no Log Book entry for $sd:', 'mr': '$sd साठी **$n गाड्यांची** Log Book entry बाकी आहे:', 'hi': '$sd के लिए **$n गाड़ियों की** Log Book entry बाकी है:'})}\n${aiList(r['machinery'] as List, 40)}'
              : aiL({'en': 'Every machinery that needs a Log Book has its entry for $sd. ✓', 'mr': '$sd साठी Log Book लागणाऱ्या सगळ्या गाड्यांची entry झाली आहे. ✓', 'hi': '$sd के लिए सभी गाड़ियों की Log Book entry हो चुकी है। ✓'})) +
          '\n[[open:log|Log Book]]';
    }),
    AiReady('machPending', const ['log'], () => aiL({'en': 'Which dates of $picked have no Log Book entry?', 'mr': '$picked च्या कोणत्या तारखांची Log Book entry बाकी आहे?', 'hi': '$picked की किन तारीखों की Log Book entry बाकी है?'}), () async {
      final no = picked, r = await runPending({'machinery': no}), n = (r['datesWithoutLogBook'] as int?) ?? 0;
      return n > 0
          ? '${aiL({'en': '**$no**: $n dates without a Log Book entry:', 'mr': '**$no**: $n तारखांची entry बाकी आहे:', 'hi': '**$no**: $n तारीखों की entry बाकी है:'})}\n${aiList([for (final d in r['dates'] as List) showDate('$d')], 40)}'
          : aiL({'en': '$no has its Log Book for every day. ✓', 'mr': '$no ची प्रत्येक दिवसाची Log Book entry झाली आहे. ✓', 'hi': '$no की हर दिन की Log Book entry हो चुकी है। ✓'});
    }, when: () => picked.isNotEmpty),
    AiReady('dieselY', const ['diesel', 'dash', 'inward', 'rp-daily'], () => aiL(const {'en': 'How much diesel was issued yesterday, and to whom?', 'mr': 'काल किती diesel दिले आणि कोणाला?', 'hi': 'कल कितना diesel दिया और किसे?'}),
        () => dieselDay(addDay(today, -1))),
    AiReady('dieselT', const ['diesel', 'dash'], () => aiL(const {'en': 'How much diesel was issued today, and to whom?', 'mr': 'आज किती diesel दिले आणि कोणाला?', 'hi': 'आज कितना diesel दिया और किसे?'}), () => dieselDay(today)),
    AiReady('stock', const ['dash', 'diesel', 'inward', 'transfer', 'cards'], () => cardSite ? aiL(const {'en': 'How much is on the fuel cards now?', 'mr': 'आत्ता fuel cards वर किती शिल्लक आहे?', 'hi': 'अभी fuel cards पर कितना बकाया है?'}) : aiL(const {'en': 'How much diesel is in stock now?', 'mr': 'आत्ता diesel stock किती आहे?', 'hi': 'अभी diesel stock कितना है?'}), () async {
      final r = await runStock(), bl = r['byLocation'], tl = fmt(r['litresInStockNow']);
      if (r['onFuelCards'] == true) {      // (3.45.0, update-164)
        final l = [for (final c in (r['cards'] as List).whereType<Map>()) if (c['active'] != false) '${c['card']} ₹${money(c['balanceRupees'])}'];
        return '${aiL(const {'en': 'This site is on fuel cards – no diesel stock. The cards now:', 'mr': 'ही site fuel cards वर आहे – diesel stock नाही. Cards ची शिल्लक:', 'hi': 'यह site fuel cards पर है – diesel stock नहीं। Cards का बकाया:'})}\n${l.isEmpty ? '–' : l.join(', ')}\n[[open:cards|Fuel Cards]]';
      }
      final by = bl is Map ? jsKeys(bl.keys.map((k) => '$k')).map((k) => '$k ${fmt(bl[k])} L').join(', ') : '';
      return aiL({'en': 'Diesel in stock now: **$tl L**', 'mr': 'आत्ता diesel stock: **$tl L**', 'hi': 'अभी diesel stock: **$tl L**'}) + (by.isNotEmpty ? '\n$by' : '') + '\n[[open:dash|Dashboard]]';
    }),
    AiReady('bad', const ['dash', 'rp-avg', 'ravg', 'rp-watch'],
        () => aiL(const {'en': 'Which machinery took more diesel than the standard this month?', 'mr': 'या महिन्यात कोणत्या गाड्यांनी standard पेक्षा जास्त diesel घेतले?', 'hi': 'इस महीने किन गाड़ियों ने standard से ज़्यादा diesel लिया?'}), () async {
      final from = '${today.substring(0, 8)}01', r = await runAverage({'from': from, 'to': today}), l = (r['mostDieselOverTheStandard'] as List?) ?? const [];
      final f = showDate(from), to = showDate(today), n = l.length;
      return (n > 0
              ? '${aiL({'en': '$f to $to – **$n machinery** over the standard (most litres first):', 'mr': '$f ते $to – **$n गाड्या** standard पेक्षा जास्त (जास्त लिटर आधी):', 'hi': '$f से $to – **$n गाड़ियाँ** standard से ज़्यादा (ज़्यादा लीटर पहले):'})}\n'
                  '${[for (final x in l.take(10)) if (x is Map) '• ${js(x['no'])}: ${js(x['actual'])} (std ${js(x['std'])}) – ${js(x['status'])}, +${fmt(x['excess'])} L'].join('\n')}'
              : aiL({
                  'en': 'No machinery is over the standard in $f to $to (where the Log Book has readings).',
                  'mr': '$f ते $to मध्ये कोणतीही गाडी standard पेक्षा जास्त नाही (जिथे Log Book readings आहेत).',
                  'hi': '$f से $to में कोई गाड़ी standard से ज़्यादा नहीं (जहाँ Log Book readings हैं)।'
                })) +
          '\n[[open:rp-avg|Actual vs Standard Average]]';
    }),
    AiReady('page', const ['*'], () => aiL(const {'en': 'What is this page for, and how do I use it?', 'mr': 'हे page कशासाठी आहे आणि कसे वापरायचे?', 'hi': 'यह page किसलिए है और कैसे इस्तेमाल करें?'}), () async {
      final g = (WebHelp.now ?? await WebHelp.load()).guideOf(page), title = tabs.where((t) => t.$1 == page).firstOrNull?.$2 ?? '';
      final h = g?[helpLang] ?? g?['en'];
      return h != null ? '**$title**\n${h[0]}\n\n${h[1]}' : aiL(const {'en': 'This page has no guide.', 'mr': 'या page चे मार्गदर्शन नाही.', 'hi': 'इस page की guide नहीं है।'});
    }),
  ];

  AiReady readyOf(String id) => ready.firstWhere((r) => r.id == id);

  /// The ⚡ questions offered on the page he is on (the web's aiReadyFor): the page's own first, then "this page", then the rest –
  /// five; the summary on every page.
  List<AiReady> readyFor() {
    bool when(AiReady r) => r.when == null || r.when!();
    final here = ready.where((r) => r.pages.contains(page) && when(r)).toList();
    final rest = ready.where((r) => !here.contains(r) && !r.pages.contains('*') && when(r));
    final list = [...here, ...ready.where((r) => r.pages.contains('*')), ...rest].take(5).toList();
    for (final r in ready.where((r) => r.always && !list.contains(r))) {
      list.add(r);
    }
    return list;
  }

  /* ---------------- a typed question the app understands by itself (aiLocal) ---------------- */
  /// [loose]: its best reading when the AI cannot answer. null = not one for the app.
  Future<String> Function()? aiLocal(String text, bool loose) {
    final kinds = [for (final e in kAiKind.entries) if (e.value.hasMatch(text)) e.key];
    var kind = '';
    if (kinds.contains('brief')) return briefText; // "the summary" – whatever else is said with it
    if (kinds.contains('stock') && !kinds.contains('pending') && !_ri(r'log ?book|लॉग ?बुक').hasMatch(text)) {
      kind = 'stock'; // "diesel stock" is a stock question
    } else if (kinds.contains('pending')) {
      kind = 'pending';
    } else if (kinds.length == 1) {
      kind = kinds.first;
    } else if (loose && kinds.isNotEmpty) {
      kind = const ['average', 'diesel', 'work', 'reading'].where(kinds.contains).firstOrNull ?? kinds.first;
    }
    if (kind.isEmpty || (!loose && kAiHard.hasMatch(text))) return null;
    final m = aiFindMach(text), lq = aiLangOf(text), no = m != null ? '${m['id']}' : '';
    if (!loose && m == null && _ri(r'\b[A-Z]{2}[- ]?\d{1,2}[- ]?[A-Z]{1,3}[- ]?\d{3,4}\b').hasMatch(text)) return null; // a number not in the Master: not for a guess
    if ((kind == 'average' || kind == 'work' || kind == 'reading') && m == null && !loose) return null; // these are about one machinery
    String t(Map<String, String> o) => o[lq] ?? o['en']!;
    if (kind == 'stock') return readyOf('stock').run;
    if (kind == 'pending') {
      return () async {
        if (m != null) {
          final r = await runPending({'machinery': no}), n = r['datesWithoutLogBook'] as int;
          return (n > 0
                  ? '${t({'en': '**$no**: $n dates without a Log Book entry:', 'mr': '**$no**: $n तारखांची Log Book entry बाकी आहे:', 'hi': '**$no**: $n तारीखों की Log Book entry बाकी है:'})}\n'
                      '${aiList([for (final d in r['dates'] as List) showDate('$d')], 40)}'
                  : t({'en': '$no has its Log Book for every day. ✓', 'mr': '$no ची प्रत्येक दिवसाची Log Book entry झाली आहे. ✓', 'hi': '$no की हर दिन की Log Book entry हो चुकी है। ✓'})) +
              '\n[[open:log|Log Book]]';
        }
        final d = aiPeriod(text, 'today').to, r = await runPending({'date': d}), n = r['machineryWithoutLogBook'] as int, sd = showDate(d);
        return (n > 0
                ? '${t({'en': '**$n machinery** have no Log Book entry for $sd:', 'mr': '$sd साठी **$n गाड्यांची** Log Book entry बाकी आहे:', 'hi': '$sd के लिए **$n गाड़ियों की** Log Book entry बाकी है:'})}\n${aiList(r['machinery'] as List, 40)}'
                : t({'en': 'Every machinery that needs a Log Book has its entry for $sd. ✓', 'mr': '$sd साठी सगळ्या गाड्यांची Log Book entry झाली आहे. ✓', 'hi': '$sd के लिए सभी गाड़ियों की Log Book entry हो चुकी है। ✓'})) +
            '\n[[open:log|Log Book]]';
      };
    }
    if (kind == 'diesel') {
      return () async {
        final p = aiPeriod(text, m != null ? 'month' : 'today'), r = await runDieselIssues({'from': p.from, 'to': p.to, 'machinery': no}), span = aiSpan(p, lq), n = r['entries'] as int;
        if (n == 0) {
          return '${t({'en': 'No diesel was issued${no.isNotEmpty ? ' to $no' : ''} in $span.', 'mr': '$span मध्ये ${no.isNotEmpty ? '$no ला ' : ''}diesel दिलेले नाही.', 'hi': '$span में ${no.isNotEmpty ? '$no को ' : ''}diesel नहीं दिया गया।'})}\n[[open:diesel|Diesel Issue]]';
        }
        final pre = no.isNotEmpty ? '**$no** – ' : '', tl = fmt(r['totalLitres']);
        final head = t({'en': '$pre$span: **$tl L** in $n entries.', 'mr': '$pre$span: **$tl L**, $n entries.', 'hi': '$pre$span: **$tl L**, $n entries।'});
        final rows = (r['rows'] as List).whereType<Map>().toList();
        final body = no.isNotEmpty
            ? [
                  for (final x in rows.take(15))
                    '• ${showDate('${x['date']}')}${jsTrue(x['shift']) ? ' ${js(x['shift'])}' : ''}: ${fmt(x['qty'])} L'
                        '${jsTrue(x['kmReading']) ? ' @ ${js(x['kmReading'])} km' : jsTrue(x['hrReading']) ? ' @ ${js(x['hrReading'])} hr' : ''}',
                ].join('\n') +
                (n > 15 ? '\n… (+${n - 15})' : '')
            : '${t(const {'en': 'By machinery: ', 'mr': 'गाडीनुसार: ', 'hi': 'गाड़ी के अनुसार: '})}${aiTop(r['byMachinery'], 12)}\n'
                '${t(const {'en': 'By owner: ', 'mr': 'मालकानुसार: ', 'hi': 'मालिक के अनुसार: '})}${aiTop(r['byOwner'], 8)}';
        return '$head\n$body\n[[open:${no.isNotEmpty ? 'rp-ledger' : 'diesel'}|${no.isNotEmpty ? 'Machinery Diesel Ledger' : 'Diesel Issue'}]]';
      };
    }
    if (m == null) return readyOf('bad').run; // (loose only) "average" with no machinery: the list of those over the standard
    if (kind == 'average') {
      return () async {
        final p = aiPeriod(text, 'month'), r = await runAverage({'from': p.from, 'to': p.to, 'machinery': no}), span = aiSpan(p, lq);
        final ms = (r['machinery'] as List?) ?? const [], x = ms.isEmpty ? null : ms.first as Map;
        if (x == null || !jsTrue(x['actual'])) {
          final used = x != null && jsTrue(x['used']), u = used ? fmt(x['used']) : '';
          return '${t({
            'en': '**$no** – $span: no average can be worked out${used ? ' ($u L of diesel, but no Log Book readings).' : ' (no diesel or no Log Book readings).'}',
            'mr': '**$no** – $span: average काढता येत नाही${used ? ' ($u L diesel आहे, पण Log Book readings नाहीत).' : ' (diesel किंवा Log Book readings नाहीत).'}',
            'hi': '**$no** – $span: average नहीं निकल सकता${used ? ' ($u L diesel है, पर Log Book readings नहीं).' : ' (diesel या Log Book readings नहीं).'}',
          })}\n[[open:rp-avg|Actual vs Standard Average]]';
        }
        final avg = 'Average: **${js(x['actual'])}** (standard ${js(x['std'])}) → ${js(x['status'])}';
        final work = [if (jsTrue(x['km'])) '${fmt(x['km'])} km', if (jsTrue(x['hr'])) '${fmt(x['hr'])} hr'].join(' + ');
        return '**$no** – $span\n${t({'en': avg, 'mr': avg, 'hi': avg})}\n'
            '${t(const {'en': 'Work: ', 'mr': 'काम: ', 'hi': 'काम: '})}$work · ${t(const {'en': 'diesel taken ', 'mr': 'घेतलेले diesel ', 'hi': 'लिया diesel '})}${fmt(x['used'])} L · '
            '${t(const {'en': 'the standard needs ', 'mr': 'standard प्रमाणे लागणारे ', 'hi': 'standard से लगने वाला '})}${fmt(x['expected'])} L\n[[open:rp-avg|Actual vs Standard Average]]';
      };
    }
    if (kind == 'work') {
      return () async {
        final p = aiPeriod(text, 'month'), r = await runLogBook({'from': p.from, 'to': p.to, 'machinery': no}), span = aiSpan(p, lq), n = r['entries'] as int;
        final work = [if (jsTrue(r['totalKm'])) '**${fmt(r['totalKm'])} km**', if (jsTrue(r['totalHours'])) '**${fmt(r['totalHours'])} hr**'].join(' + ');
        return '**$no** – $span: ${n > 0 ? '${t({'en': '$n Log Book entries', 'mr': '$n Log Book entries', 'hi': '$n Log Book entries'})} · $work · diesel ${fmt(r['dieselIssuedLitres'])} L' : t(const {'en': 'no Log Book entry.', 'mr': 'Log Book entry नाही.', 'hi': 'Log Book entry नहीं।'})}\n[[open:log|Log Book]]';
      };
    }
    return () async {
      final r = await runLogBook({'from': addDay(today, -60), 'to': today, 'machinery': no});
      // (the web sorts with "a.date < b.date ? 1 : -1": the newest first; of the same date the later row first)
      final rows = [for (final (i, z) in ((r['rows'] as List?) ?? const []).indexed) if (z is Map && (jsTrue(z['ckm']) || jsTrue(z['chr']))) (i, z)]
        ..sort((a, b) {
          final c = '${b.$2['date']}'.compareTo('${a.$2['date']}');
          return c != 0 ? c : b.$1.compareTo(a.$1);
        });
      if (rows.isEmpty) {
        return t({'en': '$no has no Log Book reading in the last 60 days.', 'mr': '$no ची गेल्या 60 दिवसांत Log Book reading नाही.', 'hi': '$no की पिछले 60 दिनों में Log Book reading नहीं।'});
      }
      final x = rows.first.$2, sd = showDate('${x['date']}');
      return '${t({'en': '**$no** – last reading on $sd: ', 'mr': '**$no** – शेवटची reading $sd ची: ', 'hi': '**$no** – आखिरी reading $sd की: '})}'
          '**${[if (jsTrue(x['ckm'])) '${fmt(x['ckm'])} km', if (jsTrue(x['chr'])) '${fmt(x['chr'])} hr'].join(' / ')}**\n[[open:log|Log Book]]';
    };
  }

  /* ---------------- an entry from words (aiDraft) ---------------- */
  /// The entry as it would be saved, or what is still missing.
  Future<AiDraft> aiDraft(String kind, Map<String, Object?> a) async {
    final mod = kind == 'diesel' ? 'Diesel Issue' : 'Log Book';
    if (!canEdit(mod)) return AiDraft(error: aiL({'en': 'You have no permission to make a $mod entry.', 'mr': '$mod entry करण्याची परवानगी तुम्हाला नाही.', 'hi': '$mod entry करने की अनुमति आपको नहीं है।'}));
    final m = jsTrue(a['machinery']) ? findMachine(a['machinery']) : null;
    if (m == null) {
      final g = jsTrue(a['machinery']) ? js(a['machinery']) : '';
      return AiDraft(
        need: aiL({
          'en': g.isNotEmpty ? '"$g" is not in the Master. Which machinery?' : 'For which machinery?',
          'mr': g.isNotEmpty ? '"$g" Master मध्ये नाही. कोणती गाडी?' : 'कोणत्या गाडीसाठी?',
          'hi': g.isNotEmpty ? '"$g" Master में नहीं है। कौन सी गाड़ी?' : 'किस गाड़ी के लिए?',
        }),
        partial: AiCmd(kind, a),
      );
    }
    final id = '${m['id']}', type = jsTrue(m['type']) ? ' · ${js(m['type'])}' : '';
    final date = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(a['date'] is String ? a['date'] as String : '') ? a['date'] as String : today;
    if (date.compareTo(today) > 0) return AiDraft(error: aiL(const {'en': 'An entry cannot be made for a date after today.', 'mr': 'आजच्या नंतरच्या तारखेची entry करता येत नाही.', 'hi': 'आज के बाद की तारीख की entry नहीं हो सकती।'}));
    final sd = showDate(date);
    if (kind == 'diesel') {
      // (3.45.0, update-164) a site on fuel cards: a fill needs its card or Cash, its ₹ and the photos – made in the form
      if (cardSite) {
        return AiDraft(error: '${aiL(const {'en': 'At this site a fill is entered in the Diesel Issue form – with its card or Cash, the Amount (₹) and the photos.', 'mr': 'या site वर fill Diesel Issue form मध्ये भरा – card किंवा Cash, Amount (₹) आणि photos सह.', 'hi': 'इस site पर fill Diesel Issue form में भरें – card या Cash, Amount (₹) और photos के साथ।'})} [[open:diesel|Diesel Issue]]');
      }
      final qty = aiN(a['litres']);
      if (!(qty is num && qty > 0)) return AiDraft(need: aiL({'en': 'How many litres for $id?', 'mr': '$id ला किती लिटर?', 'hi': '$id को कितने लीटर?'}), partial: AiCmd(kind, {...a, 'machinery': id}));
      final shift = _ri('night').hasMatch(a['shift'] == null ? '' : js(a['shift'])) ? 'Night' : 'Day';
      final src = a['source'] == null ? '' : js(a['source']).toLowerCase();
      // (3.43.0, the web's aiOwnSource_) a source he names stays as he said (the server then says it is not his); none named: his
      // usual place – of his own sources when he was given some
      // (3.44.0, update-163) of the places of its fuel (a site of Diesel only, a Diesel machinery: as before)
      final mf = const ['Diesel', 'Petrol', 'CNG', 'Electric'].contains('${m['fuel'] ?? ''}') ? '${m['fuel']}' : 'Diesel';
      if (mf == 'Electric') return AiDraft(error: aiL({'en': '$id runs on Electric – no fuel is issued to it (Asset Master → Fuel).', 'mr': '$id Electric वर चालते – तिला इंधन दिले जात नाही (Asset Master → Fuel).', 'hi': '$id Electric पर चलती है – उसे ईंधन नहीं दिया जाता (Asset Master → Fuel)।'}));
      final checks = mf != 'Diesel' || placeFuels.values.any((f) => f != 'Diesel');
      List<String> ofFuel(List<String> l) { final x = l.where((p) => (placeFuels[p] ?? 'Diesel') == mf).toList(); return x.isEmpty ? l : x; }
      final own = ownSources == null ? (checks ? ofFuel(locations) : null) : (checks ? ofFuel(ownSources!) : ownSources), usual = jsTrue(prefs['loc']) ? '${prefs['loc']}' : null;
      final source = locations.where((l) => l.toLowerCase() == src).firstOrNull ?? (own == null ? usual : (own.contains(usual) ? usual : own.firstOrNull)) ?? locations.firstOrNull ?? 'Dispenser';
      final km = aiN(a['km_reading']), hr = aiN(a['hr_reading']), debit = m['supply'] == 'Debit Basis', notes = <String>[];
      Object? stock = '';
      try {
        final s = await _call('getStock');
        stock = s['byLoc'] is Map ? (s['byLoc'] as Map)[source] : null;
      } catch (_) {
        stock = '';
      }
      if (stock is num && qty > stock) {
        final st = fmt(stock);
        notes.add(aiL({'en': '⚠ Only $st L in stock at $source.', 'mr': '⚠ $source मध्ये फक्त $st L stock आहे.', 'hi': '⚠ $source में सिर्फ $st L stock है।'}));
      }
      if (jsTrue(m['tankCap']) && qty > jsN(m['tankCap'])) {
        final cap = fmt(m['tankCap']);
        notes.add(aiL({'en': '⚠ The tank of $id holds $cap L.', 'mr': '⚠ $id ची tank $cap L ची आहे.', 'hi': '⚠ $id की tank $cap L की है।'}));
      }
      if (!debit && km == '' && hr == '') notes.add(aiL(const {'en': 'No meter reading given – it is saved without one.', 'mr': 'Meter reading दिलेली नाही; तिच्याशिवाय save होईल.', 'hi': 'Meter reading नहीं दी; उसके बिना save होगा।'}));
      final driver = (a['driver'] == null ? '' : js(a['driver'])).trim();
      final data = <String, Object?>{'date': date, 'shift': shift, 'source': source, 'no': id, 'qty': qty, 'kmReading': debit ? '' : km, 'hrReading': debit ? '' : hr, 'driver': driver, 'remark': ''};
      final reading = [if (km != '') '${fmt(km)} km', if (hr != '') '${fmt(hr)} hr'].join(' / '), q = js(qty);
      return AiDraft(
        kind: kind,
        tab: 'diesel',
        title: 'Diesel Issue',
        data: data,
        notes: notes,
        lines: [
          ('Machinery', '$id$type${jsTrue(m['owner']) ? ' · ${js(m['owner'])}' : ''}'),
          ('Date', '$sd · $shift'),
          ('Diesel', '${fmt(qty)} L  ←  $source'),
          ('Reading', reading.isEmpty ? '–' : reading),
          if (driver.isNotEmpty) ('Driver', driver),
        ],
        say: aiL({
          'en': '$id: $q litres of diesel from $source, $sd $shift. Shall I save?',
          'mr': '$id ला $q लिटर diesel, $source मधून, $sd $shift. Save करू का?',
          'hi': '$id को $q लीटर diesel, $source से, $sd $shift. Save करूँ?',
        }),
      );
    }
    final sh = a['shift'] == null ? '' : js(a['shift']);
    final shift = _ri('night').hasMatch(sh)
        ? 'Night'
        : _ri(r'^day$').hasMatch(sh.trim())
            ? 'Day'
            : (jsTrue(prefs['shift']) ? '${prefs['shift']}' : 'Full Day');
    final st = a['status'] == null ? '' : js(a['status']).toLowerCase();
    final status = const ['Idle', 'Holiday', 'Breakdown'].where((x) => x.toLowerCase() == st).firstOrNull ?? '';
    if (m['supply'] == 'Debit Basis') return AiDraft(error: aiL({'en': '$id is on debit basis – it keeps no Log Book.', 'mr': '$id debit basis वर आहे; तिची Log Book नसते.', 'hi': '$id debit basis पर है; उसकी Log Book नहीं होती।'}));
    Map pf;
    try {
      pf = await _call('getLogRowPrefill', [id, date, shift, {'add': 1}]);
    } catch (e) {
      return AiDraft(error: aiErr(e));
    }
    if (jsTrue(pf['problem'])) return AiDraft(error: js(pf['problem']));
    final ckm = aiN(a['close_km']), chr = aiN(a['close_hr']), notes = <String>[];
    // (3.31.2 – update-143, as the web) this date and shift is already saved: the work is added to that entry as its next work
    if (pf['addTo'] is Map) {
      final w = '${((asNum((pf['addTo'] as Map)['rows']) ?? 1) + 1).round()}';
      notes.add(aiL({'en': '${showDate(date)} ($shift) is already saved for $id – this work is added to that entry as work $w.', 'mr': '$id ची ${showDate(date)} ($shift) ची entry आधीच आहे; हे काम त्याच entry मध्ये work $w म्हणून जोडले जाईल.', 'hi': '$id की ${showDate(date)} ($shift) की entry पहले से है; यह काम उसी entry में work $w के रूप में जुड़ेगा।'}));
    }
    if (status.isNotEmpty) {
      return AiDraft(
        kind: kind,
        tab: 'log',
        title: 'Log Book entry',
        data: {'date': date, 'shift': shift, 'no': id, 'mode': status},
        notes: notes,
        lines: [('Machinery', '$id$type'), ('Date', '$sd · $shift'), ('Status', status)],
        say: aiL({'en': '$id, $sd: $status. Shall I save?', 'mr': '$id, $sd: $status. Save करू का?', 'hi': '$id, $sd: $status. Save करूँ?'}),
      );
    }
    final modes = [for (final x in (m['modes'] is List ? m['modes'] as List : const [])) if (x == 'KM' || x == 'Hrs' || x == 'KM + Hrs') '$x'];
    var mode = modes.length == 1
        ? modes.first
        : (ckm != '' && chr != '')
            ? 'KM + Hrs'
            : ckm != ''
                ? 'KM'
                : chr != ''
                    ? 'Hrs'
                    : (jsTrue(pf['lastMode']) ? js(pf['lastMode']) : (modes.isNotEmpty ? modes.first : ''));
    if (modes.isNotEmpty && !modes.contains(mode)) mode = modes.first;
    if (mode.isEmpty) {
      return AiDraft(
          error: '${aiL({
        'en': '$id is not measured by a meter reading – make its entry in the Log Book form.',
        'mr': '$id meter reading ने मोजली जात नाही; तिची entry Log Book form मध्ये करा.',
        'hi': '$id meter reading से नहीं नापी जाती; उसकी entry Log Book form में करें।'
      })} [[open:log|Log Book]]');
    }
    final needKm = mode.contains('KM'), needHr = mode.contains('Hrs');
    final oKm = jsN(pf['openingKm']), oHr = jsN(pf['openingHr']), sKm = fmt(pf['openingKm']), sHr = fmt(pf['openingHr']);
    if ((needKm && ckm == '') || (needHr && chr == '')) {
      final start = [if (needKm) '$sKm km', if (needHr) '$sHr hr'].join(' / ');
      List<String> miss(String k, String h) => [if (needKm && ckm == '') k, if (needHr && chr == '') h];
      return AiDraft(
        need: aiL({
          'en': '$id is measured by $mode. Tell me the closing ${miss('KM reading', 'hour reading').join(' and ')} (Start $start).',
          'mr': '$id $mode ने मोजली जाते. Closing ${miss('KM reading', 'तासांची reading').join(' आणि ')} सांगा (Start $start).',
          'hi': '$id $mode से नापी जाती है। Closing ${miss('KM reading', 'घंटों की reading').join(' और ')} बताएँ (Start $start).',
        }),
        partial: AiCmd(kind, {...a, 'machinery': id, 'date': date, 'shift': shift}),
      );
    }
    if (needKm && (ckm as num) < oKm) {
      final c = fmt(ckm);
      return AiDraft(
          error: aiL({
        'en': 'Close $c km is less than the Start $sKm km of $id. Say the right reading.',
        'mr': 'Close $c km हे $id च्या Start $sKm km पेक्षा कमी आहे. बरोबर reading सांगा.',
        'hi': 'Close $c km, $id के Start $sKm km से कम है। सही reading बताएँ।',
      }));
    }
    if (needHr && (chr as num) < oHr) {
      final c = fmt(chr);
      return AiDraft(
          error: aiL({
        'en': 'Close $c hr is less than the Start $sHr hr of $id.',
        'mr': 'Close $c hr हे $id च्या Start $sHr hr पेक्षा कमी आहे.',
        'hi': 'Close $c hr, $id के Start $sHr hr से कम है।',
      }));
    }
    if ((needKm && jsTrue(pf['firstKm'])) || (needHr && jsTrue(pf['firstHr']))) {
      final s0 = [if (needKm) sKm, if (needHr) sHr].join(' / ');
      notes.add(aiL({
        'en': 'First entry of this meter: the Start is taken as $s0 – if that is not right, use the form.',
        'mr': 'या meter ची पहिली entry: Start $s0 धरले आहे; ते बरोबर नसेल तर form वापरा.',
        'hi': 'इस meter की पहली entry: Start $s0 माना है; सही न हो तो form इस्तेमाल करें।',
      }));
    }
    final Object wk = needKm ? aiNum((ckm as num) - oKm) : '', wh = needHr ? aiNum((chr as num) - oHr) : '';
    if (needKm && (wk as num) > 600) notes.add(aiL({'en': '⚠ ${fmt(wk)} km in one entry – check the reading.', 'mr': '⚠ एका entry मध्ये ${fmt(wk)} km; reading तपासा.', 'hi': '⚠ एक entry में ${fmt(wk)} km; reading जाँचें।'}));
    if (needHr && (wh as num) > 24) notes.add(aiL({'en': '⚠ ${fmt(wh)} hours in one entry – check the reading.', 'mr': '⚠ एका entry मध्ये ${fmt(wh)} तास; reading तपासा.', 'hi': '⚠ एक entry में ${fmt(wh)} घंटे; reading जाँचें।'}));
    final work = jsTrue(a['work']) ? js(a['work']) : '';
    final row = <String, Object?>{
      'date': date, 'shift': shift, 'no': id, 'mode': mode,
      if (needKm) ...{'openingKm': pf['openingKm'], 'closingKm': ckm},
      if (needHr) ...{'openingHr': pf['openingHr'], 'closingHr': chr},
      if (work.isNotEmpty) 'work': work.length > 200 ? work.substring(0, 200) : work,
      if (pf['addTo'] is Map) 'add': 1,      // (3.31.2 – update-143) added to the saved entry of the shift, as the web
    };
    String said(String k, String h, String and) => [if (needKm) '${js(wk)} $k', if (needHr) '${js(wh)} $h'].join(and);
    return AiDraft(
      kind: kind,
      tab: 'log',
      title: 'Log Book entry',
      data: row,
      notes: notes,
      lines: [
        ('Machinery', '$id$type'),
        ('Date', '$sd · $shift · $mode'),
        if (needKm) ('KM', '$sKm → ${fmt(ckm)}  =  ${fmt(wk)} km'),
        if (needHr) ('Hrs', '$sHr → ${fmt(chr)}  =  ${fmt(wh)} hr'),
        if (work.isNotEmpty) ('Work', '${row['work']}'),
      ],
      say: aiL({
        'en': '$id, $sd: ${said('kilometres', 'hours', ' and ')}. Shall I save?',
        'mr': '$id, $sd: ${said('किलोमीटर', 'तास', ' आणि ')}. Save करू का?',
        'hi': '$id, $sd: ${said('किलोमीटर', 'घंटे', ' और ')}. Save करूँ?',
      }),
    );
  }

  /// Sends a prepared entry through the app's own save (his Save): the server's answer.
  Future<Map> saveDraft(AiDraft d, {bool force = false}) async {
    final r = d.kind == 'diesel'
        ? await call('saveDieselIssue', [{...d.data, if (force) 'force': true}], save: true)
        : await call('saveLogRows', [{'rows': [d.data]}], save: true);
    return r is Map ? r : {};
  }

  /* ---------------- the daily summary (getBrief) ---------------- */
  Future<String> briefText() async {
    final d = await _call('getBrief'), s2 = d['sections'] is Map ? d['sections'] as Map : const {}, hr = now().hour;
    final hello = hr < 12
        ? aiL(const {'en': 'Good morning', 'mr': 'सुप्रभात', 'hi': 'सुप्रभात'})
        : hr < 17
            ? aiL(const {'en': 'Good afternoon', 'mr': 'नमस्कार', 'hi': 'नमस्कार'})
            : aiL(const {'en': 'Good evening', 'mr': 'नमस्कार', 'hi': 'नमस्कार'});
    final a = <String>[], w = <String>[], go = <String>[];
    final day = showDate(d['day'] == null ? '' : '${d['day']}');
    a.add('**$hello${jsTrue(d['name']) ? ', ${js(d['name'])}' : ''}.** ${aiL({'en': 'Yesterday ($day):', 'mr': 'काल ($day):', 'hi': 'कल ($day):'})}');
    Map? sec(String k) => s2[k] is Map ? s2[k] as Map : null;
    final dsl = sec('diesel');
    if (dsl != null) {
      final top = dsl['top'] is List ? dsl['top'] as List : const [], n = dsl['entries'], lt = fmt(dsl['litres']), ne = js(n);
      final rec = sec('received');
      final rl = rec != null && jsTrue(rec['litres']) ? fmt(rec['litres']) : null;
      a.add('• Diesel: ${jsTrue(n) ? aiL({'en': '**$lt L** issued in $ne entries', 'mr': '**$lt L** दिले, $ne entries', 'hi': '**$lt L** दिया, $ne entries'}) + (top.isNotEmpty ? ' – ${aiTop(top, 3)}' : '') : aiL(const {'en': 'none issued', 'mr': 'दिलेले नाही', 'hi': 'नहीं दिया'})}'
          '${rl != null ? aiL({'en': '; received $rl L', 'mr': '; आले $rl L', 'hi': '; आया $rl L'}) : ''}.');
      go.add('[[open:diesel|Diesel Issue]]');
    }
    final stk = sec('stock');
    if (stk != null) {
      final by = stk['byLoc'] is Map ? stk['byLoc'] as Map : const {};
      a.add('• ${aiL(const {'en': 'Stock now: ', 'mr': 'आत्ता stock: ', 'hi': 'अभी stock: '})}**${fmt(stk['litres'])} L**'
          '${by.length > 1 ? ' (${jsKeys(by.keys.map((k) => '$k')).map((k) => '$k ${fmt(by[k])}').join(', ')})' : ''}.');
    }
    final lb = sec('logbook');
    if (lb != null) {
      final n = js(lb['entries']), p = lb['pending'];
      a.add('• Log Book: ${aiL({'en': '$n entries made', 'mr': '$n entries झाल्या', 'hi': '$n entries हुईं'})}'
          '${jsTrue(p) ? aiL({'en': '; **${js(p)} machinery still have none**: ', 'mr': '; **${js(p)} गाड्यांची बाकी**: ', 'hi': '; **${js(p)} गाड़ियों की बाकी**: '}) + aiList(lb['names'] is List ? lb['names'] as List : const [], 8) : aiL(const {'en': '; nothing pending ✓', 'mr': '; काही बाकी नाही ✓', 'hi': '; कुछ बाकी नहीं ✓'})}.');
      go.add('[[open:log|Log Book]]');
    }
    final wt = sec('watch');
    if (wt != null && jsTrue(wt['signs'])) {
      final top = wt['top'] is List ? wt['top'] as List : const [], s = js(wt['signs']), lt = fmt(wt['litres']);
      w.add('• ${aiL({'en': 'Diesel Watch, last 7 days: **$s signs**, $lt L do not fit', 'mr': 'Diesel Watch, गेले 7 दिवस: **$s चिन्हे**, $lt L जुळत नाहीत', 'hi': 'Diesel Watch, पिछले 7 दिन: **$s संकेत**, $lt L मेल नहीं खाते'})}'
          '${top.isNotEmpty ? ' – ${[for (final t in top) if (t is Map) '${js(t['no'])} ${fmt(t['litres'])} L'].join(', ')}' : ''}.');
      go.add('[[open:rp-watch|Diesel Watch]]');
    }
    final av = sec('average');
    if (av != null && (jsTrue(av['bad']) || jsTrue(av['more']) || jsTrue(av['check']))) {
      final worst = av['worst'] is List ? av['worst'] as List : const [];
      w.add('• ${aiL(const {'en': 'This month against the standard: ', 'mr': 'या महिन्यात standard च्या तुलनेत: ', 'hi': 'इस महीने standard की तुलना में: '})}'
          '${[if (jsTrue(av['bad'])) '**${js(av['bad'])} Bad**', if (jsTrue(av['more'])) '${js(av['more'])} More diesel', if (jsTrue(av['check'])) '${js(av['check'])} Check reading'].join(', ')}'
          '${worst.isNotEmpty ? ' – ${[for (final t in worst) if (t is Map) '${js(t['no'])} +${fmt(t['excess'])} L'].join(', ')}' : ''}.');
      go.add('[[open:rp-avg|Actual vs Standard Average]]');
    }
    final pp = sec('papers');
    if (pp != null && (jsTrue(pp['expired']) || jsTrue(pp['due']))) {
      final first = pp['first'] is List ? pp['first'] as List : const [], e = js(pp['expired']), du = js(pp['due']), sdy = js(pp['soonDays']);
      w.add('• ${aiL(const {'en': 'Vehicle papers: ', 'mr': 'गाड्यांचे कागद: ', 'hi': 'गाड़ियों के कागज़: '})}'
          '${[if (jsTrue(pp['expired'])) aiL({'en': '**$e expired**', 'mr': '**$e संपलेले**', 'hi': '**$e खत्म**'}), if (jsTrue(pp['due'])) aiL({'en': '$du due within $sdy days', 'mr': '$du $sdy दिवसांत संपणारे', 'hi': '$du $sdy दिन में खत्म होने वाले'})].join(', ')}'
          '${first.isNotEmpty ? ' – ${first.map(js).join(', ')}' : ''}.');
      go.add('[[open:compliance|Vehicle Compliance]]');
    }
    final bd = sec('breakdown');
    if (bd != null && jsTrue(bd['down'])) {
      final n = js(bd['down']);
      w.add('• ${aiL({'en': '**$n machinery** under breakdown.', 'mr': '**$n गाड्या** breakdown मध्ये.', 'hi': '**$n गाड़ियाँ** breakdown में।'})}');
    }
    final ad = sec('admin');
    if (ad != null && jsTrue(ad['faults'])) {
      final n = js(ad['faults']);
      w.add('• ${aiL({'en': 'Admin: $n fault(s) of the app since yesterday – see "Faults" at the top.', 'mr': 'Admin: कालपासून app चे $n बिघाड – वर "Faults" पाहा.', 'hi': 'Admin: कल से app की $n खराबी – ऊपर "Faults" देखें।'})}');
    }
    a.add('');
    a.add(w.isNotEmpty
        ? aiL(const {'en': '**To look at:**', 'mr': '**लक्ष द्या:**', 'hi': '**ध्यान दें:**'})
        : aiL(const {'en': 'Nothing else needs a look. ✓', 'mr': 'आणखी लक्ष देण्यासारखे काही नाही. ✓', 'hi': 'और कुछ ध्यान देने लायक नहीं। ✓'}));
    return [...a, ...w].join('\n') + (go.isNotEmpty ? '\n${go.join(' ')}' : '');
  }

  /* ---------------- what goes with a typed question to the AI service ---------------- */
  Future<Map<String, Object?>> _pick(Future<Map<String, Object?>> Function() f) async {
    try {
      return await f();
    } catch (e) {
      return {'notAllowed': aiErr(e)};
    }
  }

  /// The machinery of a question with its figures of this month (the web's aiAbout).
  Future<Map<String, Object?>?> about(String text) async {
    final m = aiFindMach(text);
    if (m == null) return null;
    final from = '${today.substring(0, 8)}01';
    final r = await Future.wait([_pick(() => runDieselIssues({'from': from, 'to': today, 'machinery': m['id']})), _pick(() => runAverage({'from': from, 'to': today, 'machinery': m['id']}))]);
    final d = r[0], av = r[1];
    return {
      'machinery': {for (final k in const ['id', 'name', 'type', 'owner', 'ownership', 'unit', 'kmStd', 'hrStd', 'tankCap', 'status']) k: m[k]},
      'thisMonth': {
        'from': from, 'to': today,
        'diesel': d['notAllowed'] == null ? {'entries': d['entries'], 'totalLitres': d['totalLitres'], 'rows': ((d['rows'] as List?) ?? const []).take(20).toList()} : d,
        'average': av['notAllowed'] == null ? ((av['machinery'] as List?) ?? const []).firstOrNull : av,
      },
    };
  }

  /// The day's figures that go with a typed question (the web's aiSnapBuild), at most 30 seconds old.
  Map<String, Object?>? _snap;
  DateTime? snapAt;
  Future<Map<String, Object?>> snapshot() async {
    final at = snapAt;
    if (_snap != null && at != null && now().difference(at).inSeconds < 30) return _snap!;
    final yest = addDay(today, -1);
    Map<String, Object?> slim(Map<String, Object?> d) => d['notAllowed'] != null
        ? d
        : {'entries': d['entries'], 'totalLitres': d['totalLitres'], 'byMachinery': ((d['byMachinery'] as List?) ?? const []).take(15).toList(), 'byOwner': ((d['byOwner'] as List?) ?? const []).take(10).toList()};
    final r = await Future.wait([
      _pick(() => runDieselIssues({'from': today, 'to': today})),
      _pick(() => runDieselIssues({'from': yest, 'to': yest})),
      _pick(() => runPending({'date': today})),
      _pick(runStock),
    ]);
    final t = now();
    String two(int v) => v.toString().padLeft(2, '0');
    snapAt = t;
    return _snap = {
      'asOf': '${two(t.hour)}:${two(t.minute)}:${two(t.second)}', 'today': today, 'yesterday': yest, 'dieselIssuedToday': slim(r[0]), 'dieselIssuedYesterday': slim(r[1]),
      'pendingLogBookToday': r[2]['notAllowed'] == null ? {'machinery': r[2]['machineryWithoutLogBook'], 'names': ((r[2]['machinery'] as List?) ?? const []).take(40).toList()} : r[2],
      'dieselStockNow': r[3]['notAllowed'] == null ? (r[3]['onFuelCards'] == true ? {'onFuelCards': true, 'cards': r[3]['cards']} : {'litres': r[3]['litresInStockNow'], 'byLocation': r[3]['byLocation']}) : r[3],
    };
  }

  /// Marathi / Hindi digits as a phone keyboard or the listening writes them (८५११ → 8511).
  static String westernDigits(String s) => s.replaceAllMapped(RegExp('[०-९]'), (m) => '${'०१२३४५६७८९'.indexOf(m[0]!)}');
}

