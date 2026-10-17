/* (3.14.0) The search of the whole app – the same matcher as the web's own (fixtures/gs/web_gs.json: App.html's gsDistP /
 * gsWords / gsRecordP run in node on records and words typed – spelling mistakes, numbers, Marathi) and the Store's own search
 * (rcl-store sFind). The scratchpad's gs/gen.js. */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/gsearch.dart';

void main() {
  final fx = jsonDecode(File('test/fixtures/gs/web_gs.json').readAsStringSync()) as Map<String, dynamic>;
  final recs = [
    for (final r in fx['recs'] as List) [for (final p in r as List) ('${(p as List)[0]}', p[1])],
  ];

  test('The distance of two words (a letter more, less, other, or two the other way round)', () {
    for (final d in fx['dist'] as List) {
      expect(gsDist('${d[0]}', '${d[1]}', d[2] as int), d[3], reason: '$d');
    }
  });

  test('The words of what is typed', () {
    for (final w in fx['words'] as List) {
      expect(gsWords('${w[0]}'), w[1], reason: '"${w[0]}"');
    }
  });

  test('Every record and every search: found or not, its score and the spelling taken – exact and allowing a mistake', () {
    var n = 0;
    for (final h in fx['hits'] as List) {
      final m = gsRecord(gsWords('${h['q']}'), recs[h['rec'] as int], fuzzy: h['fuzzy'] == true);
      final want = h['m'] as Map?;
      final why = '"${h['q']}" in record ${h['rec']} (fuzzy ${h['fuzzy']})';
      if (want == null) {
        expect(m, isNull, reason: why);
      } else {
        expect(m, isNotNull, reason: why);
        expect(m!.score, want['score'], reason: why);
        expect([for (final f in m.fixes) [f.$1, f.$2]], want['fixes'], reason: why);
        n++;
      }
    }
    expect(n, greaterThan(40));
  });

  test('"Did you mean": the spelling found most often', () {
    expect(gsBetter(['ANAD', 'EARTH'], [('ANAD', 'ANAND'), ('ANAD', 'ANANT'), ('ANAD', 'ANAND')], true), 'anand earth');
    expect(gsBetter(['ANAD'], [('ANAD', 'ANAND')], false), '', reason: 'nothing found: nothing to suggest');
    expect(gsBetter(['ANAND'], [], true), '');
  });

  test('The Store\'s own search of its items', () {
    final items = [for (final i in fx['items'] as List) i as Map];
    for (final s in fx['store'] as List) {
      expect([for (final i in storeFind('${s[0]}', items)) i['code']], s[1], reason: '"${s[0]}"');
    }
  });
}
