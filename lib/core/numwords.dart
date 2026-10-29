/* (3.67.0, 29-10-2026) A NUMBER SAID IN WORDS → the number – English, हिंदी, मराठी (and the three mixed, as people speak) – the web's
 * RclNum (voice.js of the Store / Engineering / Portal, inline in Mechanical): the same words, the same steps, the same cases tested.
 *   "twelve point five", "बारा पॉइंट पाच", "साडे तीन हजार", "दीडशे", "डेढ़ सौ", "एक लाख वीस हजार", "1 lakh 20 thousand", "१२.५"
 *   → "12.5", "12.5", "3500", "150", "150", "120000", "120000", "12.5". Units and other words around it are left out ("बारा लिटर" →
 *   "12"); '' = no number heard. digits: a phone number said digit by digit ("नऊ आठ दोन…" → "982…"). */

final Map<String, num> _w = _words();

Map<String, num> _words() {
  final w = <String, num>{};
  void add(num v, List<String> ws) {
    for (final x in ws) {
      w[x] = v;
    }
  }

  for (final (i, x) in 'zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen'.split(' ').indexed) {
    w[x] = i;
  }
  for (final (i, x) in 'twenty thirty forty fifty sixty seventy eighty ninety'.split(' ').indexed) {
    w[x] = 20 + 10 * i;
  }
  add(40, ['fourty']);
  for (final (i, x) in ('शून्य एक दोन तीन चार पाच सहा सात आठ नऊ दहा अकरा बारा तेरा चौदा पंधरा सोळा सतरा अठरा एकोणीस वीस एकवीस बावीस तेवीस चोवीस पंचवीस सव्वीस सत्तावीस अठ्ठावीस एकोणतीस तीस एकतीस बत्तीस तेहेतीस चौतीस पस्तीस छत्तीस सदतीस अडतीस एकोणचाळीस चाळीस एक्केचाळीस बेचाळीस त्रेचाळीस चव्वेचाळीस पंचेचाळीस सेहेचाळीस सत्तेचाळीस अठ्ठेचाळीस एकोणपन्नास पन्नास एक्कावन्न बावन्न त्रेपन्न चोपन्न पंचावन्न छप्पन्न सत्तावन्न अठ्ठावन्न एकोणसाठ साठ एकसष्ठ बासष्ठ त्रेसष्ठ चौसष्ठ पासष्ठ सहासष्ठ सदुसष्ठ अडुसष्ठ एकोणसत्तर सत्तर एकाहत्तर बाहत्तर त्र्याहत्तर चौर्याहत्तर पंच्याहत्तर शहात्तर सत्याहत्तर अठ्ठ्याहत्तर एकोणऐंशी ऐंशी एक्याऐंशी ब्याऐंशी त्र्याऐंशी चौर्याऐंशी पंच्याऐंशी शहाऐंशी सत्त्याऐंशी अठ्ठ्याऐंशी एकोणनव्वद नव्वद एक्याण्णव ब्याण्णव त्र्याण्णव चौर्याण्णव पंच्याण्णव शहाण्णव सत्त्याण्णव अठ्ठ्याण्णव नव्व्याण्णव').split(' ').indexed) {
    w[x] = i;
  }
  add(33, ['तेहतीस']);
  add(41, ['एकेचाळीस', 'एक्केचाळिस']);
  add(44, ['चव्वेचाळिस']);
  add(46, ['सेहेचाळिस', 'शेहेचाळीस']);
  add(51, ['एक्कावन', 'एकावन्न']);
  add(56, ['छप्पन']);
  add(58, ['अठ्ठावन']);
  add(76, ['शहात्तर', 'शहाहत्तर']);
  add(99, ['नव्याण्णव']);
  add(75, ['पंचाहत्तर', 'पंचात्तर']);
  add(71, ['एक्याहत्तर']);
  add(73, ['त्र्याहात्तर']);
  add(85, ['पंचाऐंशी']);
  add(95, ['पंचाण्णव']);
  add(65, ['पासष्ट']);
  add(64, ['चौसष्ट']);
  add(6, ['साहा']);
  add(9, ['नौ']);
  add(100, ['शंभर']);
  for (final (i, x) in ('शून्य एक दो तीन चार पांच छह सात आठ नौ दस ग्यारह बारह तेरह चौदह पंद्रह सोलह सत्रह अठारह उन्नीस बीस इक्कीस बाईस तेईस चौबीस पच्चीस छब्बीस सत्ताईस अट्ठाईस उनतीस तीस इकतीस बत्तीस तैंतीस चौंतीस पैंतीस छत्तीस सैंतीस अडतीस उनतालीस चालीस इकतालीस बयालीस तैंतालीस चवालीस पैंतालीस छियालीस सैंतालीस अडतालीस उनचास पचास इक्यावन बावन तिरेपन चौवन पचपन छप्पन सत्तावन अट्ठावन उनसठ साठ इकसठ बासठ तिरेसठ चौंसठ पैंसठ छियासठ सडसठ अडसठ उनहत्तर सत्तर इकहत्तर बहत्तर तिहत्तर चौहत्तर पचहत्तर छिहत्तर सतहत्तर अठहत्तर उन्यासी अस्सी इक्यासी बयासी तिरासी चौरासी पचासी छियासी सत्तासी अट्ठासी नवासी नब्बे इक्यानवे बानवे तिरानवे चौरानवे पचानवे छियानवे सत्तानवे अट्ठानवे निन्यानवे').split(' ').indexed) {
    w[x] = i;
  }
  add(5, ['पाँच', 'पाच']);
  add(6, ['छः', 'छै', 'छे']);
  add(15, ['पन्द्रह']);
  add(79, ['उनासी', 'उन्नासी']);
  add(2, ['दोन']);
  add(53, ['तिरपन']);
  add(63, ['तिरसठ']);
  return w;
}

const _mul = <String, num>{'hundred': 100, 'सौ': 100, 'शे': 100, 'thousand': 1e3, 'हजार': 1e3, 'lakh': 1e5, 'lakhs': 1e5, 'lac': 1e5, 'lacs': 1e5, 'लाख': 1e5, 'crore': 1e7, 'crores': 1e7, 'करोड': 1e7, 'कोटी': 1e7, 'million': 1e6};
const _pre = <String, num>{'साडे': .5, 'साढे': .5, 'सव्वा': .25, 'सवा': .25, 'पावणे': -.25, 'पौने': -.25};
const _alone = <String, num>{'दीड': 1.5, 'डेढ': 1.5, 'अडीच': 2.5, 'ढाई': 2.5, 'अर्धा': .5, 'अर्धे': .5, 'आधा': .5, 'पाव': .25, 'half': .5, 'quarter': .25};
const _point = {'point', 'पॉइंट', 'पॉईंट', 'पॉंईट', 'पाइंट', 'पॉइन्ट', 'प्वाइंट', 'दशांश', 'दशमलव', '.', 'dot', 'डॉट'};
const _skip = {'and', 'a', 'an', 'व', 'आणि', 'और'};

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[‌‍]'), '')
    .replaceAll('़', '')
    .replaceAll('ऱ', 'र')
    .replaceAllMapped(RegExp('[०-९]'), (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0x966 + 48))
    .replaceAllMapped(RegExp(r'(\d),(?=\d)'), (m) => m[1]!)
    .replaceAll('₹', ' ');

class _Wd {
  _Wd({this.v, this.d, this.m, this.p, this.pt = false, this.pre, this.then});
  final num? v, m, p, pre, then;
  final String? d;
  final bool pt;
}

_Wd? _word(String t) {
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(t) || RegExp(r'^\.\d+$').hasMatch(t)) return _Wd(v: num.parse(t.startsWith('.') ? '0$t' : t), d: t);
  if (_point.contains(t)) return _Wd(pt: true);
  if (_mul.containsKey(t)) return _Wd(m: _mul[t]);
  if (_alone.containsKey(t)) return _Wd(v: _alone[t]);
  if (_w.containsKey(t)) return _Wd(v: _w[t], d: '${_w[t]}');
  if (_pre.containsKey(t)) return _Wd(p: _pre[t]);
  // मराठी joined: साडेतीन, पावणेदोन, सव्वाशे; दोनशे, दीडशे, साडेतीनशे; एकशेवीस (120)
  for (final k in _pre.keys) {
    if (t.length > k.length && t.startsWith(k)) {
      final r = _word(t.substring(k.length));
      if (r != null && (r.v != null || r.m != null)) return _Wd(v: r.v, d: r.d, m: r.m, then: r.then, pre: _pre[k]! + (r.pre ?? 0));
    }
  }
  if (t.endsWith('शे') && t.length > 2) {
    final r = _word(t.substring(0, t.length - 2));
    if (r != null && r.v != null) return _Wd(v: r.v, pre: r.pre, then: 100);
  }
  final m = RegExp(r'^(.+?)शे(.+)$').firstMatch(t);
  if (m != null) {
    final a = _word(m[1]!), b = _word(m[2]!);
    if (a != null && a.v != null && b != null && b.v != null) return _Wd(v: a.v! * 100 + b.v!);
  }
  return null;
}

/// The number in [text] ('' = none heard); [digits]: the digits said one by one (a phone number, a code).
String spokenNumber(String text, {bool digits = false}) {
  final toks = _norm(text)
      .replaceAllMapped(RegExp(r'(\d)\s*\.\s*(\d)'), (m) => '${m[1]}.${m[2]}')
      .split(RegExp(r'[\s\-–,;:/]+|(?<=[^\d.])(?=\d)|(?<=\d)(?=[^\d.])'))
      .map((x) => x.trim())
      .where((x) => x.isNotEmpty)
      .toList();
  if (digits) {
    final out = StringBuffer();
    for (final t in toks) {
      final w = _word(t);
      if (w != null && w.d != null) out.write(w.d);
    }
    return '$out';
  }
  num total = 0, cur = 0, pre = 0;
  num? last; // the value just before – "twenty five" goes on; "बारा पंधरा" is two numbers: the first
  var seen = false, done = false;
  String? frac;
  for (final t in toks) {
    if (done) break;
    if (_skip.contains(t)) continue;
    final w = _word(t);
    if (w == null) {
      if (seen && (frac != null || cur != 0 || total != 0)) done = true; // (a unit or another word after the number: the end)
      last = null;
      continue;
    }
    if (w.pt) {
      if (frac == null) {
        frac = '';
        seen = true;
      }
      continue;
    }
    if (frac != null) {
      if (w.d != null) {
        frac += w.d!.replaceAll('.', '');
      } else {
        done = true;
      }
      continue;
    }
    seen = true;
    if (w.p != null && w.v == null && w.m == null) {
      pre += w.p!;
      continue;
    }
    if (w.m != null && w.v == null) {
      last = null;
      final base = (cur == 0 ? 1 : cur) + (w.pre ?? 0) + pre;
      pre = 0;
      if (w.m == 100) {
        cur = base * 100;
      } else {
        total += base * w.m!;
        cur = 0;
      }
      continue;
    }
    final l = last;
    if (l != null && w.v! >= 1 && (l % 10 != 0 || l >= 100 || w.v! >= 10 || l != l.truncate())) break; // (a half / a quarter may follow)
    final v = w.v! + (w.pre ?? 0) + pre;
    pre = 0;
    if (w.then != null) {
      cur += v * w.then!;
      last = null;
      continue;
    }
    cur += v;
    last = v;
  }
  if (!seen) return '';
  num n = total + cur + pre;
  if (frac != null && frac.isNotEmpty) n = n.truncate() + double.parse('0.$frac') + (n - n.truncate());
  if (!n.isFinite) return '';
  final r = (n * 1000).round() / 1000;
  return r == r.truncate() ? '${r.truncate()}' : '$r';
}
