// (15-10-2026) The language of the app: the words turned exactly or by pattern, the app's own Marathi words used for Marathi,
// "English · मराठी" as before when nothing is chosen; the choice kept with his account and on the phone; the real files read.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/lang.dart';
import 'package:rcl_mobile/core/session.dart';

import 'fake_server.dart';

Future<String> Function(String) files(Map<String, Map<String, String>> d) => (p) async {
      final k = p.split('/').last.replaceAll('.json', '');
      if (!d.containsKey(k)) throw Exception('no $p');
      return jsonEncode(d[k]);
    };

void main() {
  tearDown(() => Lang.i.set(''));

  test('a text exactly, a pattern with the app\'s parts, an English ending left out, each line on its own', () async {
    await Lang.i.set('mr', read: files({
      'web_mr': {'Saved.': 'सेव्ह झाले.', 'Machinery {0} is inactive.': 'मशिनरी {0} बंद आहे.', 'Day': 'दिवस', 'in {0} day{1}': '{0} दिवस{1} मध्ये'},
      'app_mr': {'{0} {1} · {2} worked': '{0} {1} · {2} काम', 'Saved.': 'जतन झाले.'},
    }));
    expect(Lang.i.code, 'mr');
    expect(tr('  Saved. '), '  जतन झाले. ', reason: 'the app\'s own words win over the web\'s');
    expect(tr('Machinery JCB-07 is inactive.'), 'मशिनरी JCB-07 बंद आहे.');
    expect(tr('in 1 day'), '1 दिवस मध्ये');
    expect(tr('in 4 days'), '4 दिवस मध्ये');
    expect(tr('3 Day · 5 hr worked'), '3 दिवस · 5 hr काम', reason: 'a word the app put in is turned too when it is known');
    expect(tr('Saved.\nMachinery X is inactive.'), 'जतन झाले.\nमशिनरी X बंद आहे.');
    expect(tr('MH-04-AB-1234'), 'MH-04-AB-1234', reason: 'data stays as it is');
    expect(tr('Something new'), 'Something new');
    expect(Lang.i.pair('Log Book saved', 'नोंद झाली'), 'नोंद झाली', reason: 'Marathi: the app\'s own words');
    expect(bi('This cannot be undone.', 'हे परत आणता येणार नाही.'), 'हे परत आणता येणार नाही.');
  });

  test('nothing chosen: the app as before (English · मराठी); English chosen: English only; Hindi from the words', () async {
    await Lang.i.set('');
    expect(bi('This cannot be undone.', 'हे परत आणता येणार नाही.'), 'This cannot be undone. · हे परत आणता येणार नाही.');
    expect(tr('Saved.'), 'Saved.');
    await Lang.i.set('en');
    expect(Lang.i.chosen, true);
    expect(bi('This cannot be undone.', 'हे परत आणता येणार नाही.'), 'This cannot be undone.');
    expect(tr('Saved.'), 'Saved.');
    await Lang.i.set('hi', read: files({'web_hi': {'This cannot be undone.': 'यह वापस नहीं हो सकता।'}, 'app_hi': {}}));
    expect(bi('This cannot be undone.', 'हे परत आणता येणार नाही.'), 'यह वापस नहीं हो सकता।', reason: 'Hindi: not the Marathi words');
    await Lang.i.set('xx');
    expect(Lang.i.code, '');
  });

  test('the app\'s real language files: every {0} kept, the words of the screens there', () async {
    for (final l in ['mr', 'hi']) {
      for (final f in ['web', 'app']) {
        final d = (jsonDecode(File('assets/i18n/${f}_$l.json').readAsStringSync()) as Map).cast<String, dynamic>();
        expect(d.length, greaterThan(f == 'web' ? 4000 : 200));
        d.forEach((k, v) {
          List<String> ph(String s) => RegExp(r'\{\d+\}').allMatches(s).map((m) => m.group(0)!).toList()..sort();
          expect(ph('$v'), ph(k), reason: '$l/$f: $k');
        });
      }
    }
    await Lang.i.set('mr', read: (p) => File(p).readAsString());
    expect(hasDeva(tr('My settings')), true);
    expect(hasDeva(tr('Sign in')), true);
    expect(hasDeva(tr('Current password is wrong.')), true, reason: 'the Portal\'s messages too');
  });

  test('chosen in the app: kept with his account (and the help follows), on the phone for the next start', () async {
    final srv = FakeServer(), keep = MemoryKeep();
    final rd = files({'web_mr': {'Sign in': 'साइन इन'}, 'app_mr': {}, 'web_hi': {}, 'app_hi': {}});
    final s = Session(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client), langRead: rd);
    await s.start();
    await s.signIn('sujit@rcl.test', 'Nashik#Road848!');
    await s.chooseSite('S1');
    await s.setLanguage('mr');
    expect(srv.prefs['appLang'], 'mr');
    expect(srv.prefs['lang'], 'mr');
    expect(Lang.i.code, 'mr');
    expect(keep.data[Session.kLang], 'mr');
    await s.setLanguage('en');
    expect(srv.prefs['lang'], 'en');
    expect(Lang.i.code, 'en');
    // chosen on the web (or at his other site): the app takes it when it reads his settings
    srv.prefs['appLang'] = 'mr';
    await s.loadPrefs();
    expect(Lang.i.code, 'mr');
    // the app opened again (even signed out): the kept language at once
    await Lang.i.set('');
    final s2 = Session(Api(portalUrl: 'https://erp.test/portal', keep: keep, client: srv.client), langRead: rd);
    await s2.start();
    expect(Lang.i.code, 'mr');
  });
}
