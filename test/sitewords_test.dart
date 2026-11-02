/* (3.74.0, Mechanical update-201) VOICE TYPING WRITES THE SITE'S OWN WORDS – the app's sitewords.dart against the web's OWN code
 * (App.html "SPEAK INTO A BOX": SW), run in node on the same words and texts (test/fixtures/voice/web_sitewords.json, made by the
 * scratch script u201/gen.js): "go to Aaryan City" → "go to Arihant City", the speech's guesses, a correction learned, nothing else
 * touched (a plural, a chainage, a word not of the site); a correction by hand learned only when it sounds like what was heard. */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/sitewords.dart';

final fx = jsonDecode(File('test/fixtures/voice/web_sitewords.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  setUp(() => SiteWords.i.set({'words': fx['words'], 'fixes': fx['fixes']}));
  tearDown(() => SiteWords.i.set(null));

  test('every text of the web\'s fixture: the same text and the same changes (where they stand) as the web', () {
    var n = 0;
    for (final c in (fx['cases'] as List).cast<Map>()) {
      final r = SiteWords.i.fix([for (final a in c['alts'] as List) '$a']);
      expect(r.text, c['text'], reason: '${c['alts']}');
      expect(jsonDecode(jsonEncode(r.changes)), c['changes'], reason: '${c['alts']}');
      n++;
    }
    expect(n, greaterThan(30));
  });

  test('the cases he met, and nothing else changed', () {
    String f(List<String> a) => SiteWords.i.fix(a).text;
    expect(f(['go to Aaryan City']), 'go to Arihant City');
    expect(f(['RCL camp to Aaryan City']), 'RCL camp to Arihant City');
    expect(f(['Aryna Nagar se camp tak']), 'Arihant City se camp tak', reason: 'a correction learned (the fixture\'s)');
    expect(f(['aryan city', 'arihant city']), 'arihant city', reason: 'of the speech\'s guesses the one that is the site\'s word');
    for (final t in ['sale', 'vada pav', 'the plaza is open', 'kaseli bridge 559 plus 250', 'the excavators', 'Arihant Nagar']) {
      expect(f([t]), t, reason: 'unchanged: $t');
    }
    expect(SiteWords.i.words, greaterThan(10));
    SiteWords.i.learn('aryna', 'Arihant');
    expect(f(['go to Aryna Nagar']), 'go to Arihant City', reason: 'the longer correction first');
    expect(f(['Aryna camp']), 'Arihant camp');
  });

  test('a correction by hand: sounds like what was heard – learned; a change of what was meant – not (the web\'s same)', () {
    for (final a in (fx['alike'] as List).cast<List>()) {
      expect(swAlike('${a[0]}', '${a[1]}'), a[2], reason: '${a[0]} → ${a[1]}');
    }
    // a site word put in, changed in part by hand: what was heard there is learned
    expect(swLearned('RCL camp to Arihant City', 'RCL camp to Arihant Nagar', 0, 24, [{'from': 'Aaryan City', 'to': 'Arihant City', 'at': 12}]), ('Aaryan City', 'Arihant Nagar'));
    // a word of what was heard corrected
    expect(swLearned('go to Aryna Nagar', 'go to Arihant Nagar', 0, 17, []), ('Aryna', 'Arihant'));
    // a change of what was meant; a change outside the spoken words; nothing changed
    expect(swLearned('two trips', 'three trips', 0, 9, []), isNull);
    expect(swLearned('MH09 go to Aryna', 'MH10 go to Aryna', 5, 11, []), isNull);
    expect(swLearned('Arihant City', 'Arihant City', 0, 12, [{'from': 'Aaryan City', 'to': 'Arihant City', 'at': 0}]), isNull);
    expect(swLearned('go to Aryna', 'go to 25', 0, 11, []), isNull, reason: 'no letter typed');
  });
}
