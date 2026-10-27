/* (3.15.0) The assistant – the same as the web's own code (fixtures/ai/web_ai.json: App.html's assistant run in node on a fixed day
 * 16-10-2026 09:30 with a Master and the server's answers – the scratchpad's ai/gen.js): the language of a question, its dates, its
 * machinery, the readings said, a command, the app's own answers (strict and loose) with the look-ups they made, the entry prepared
 * from words, the ⚡ questions, the daily summary and what is said aloud – in English, मराठी and हिंदी. And the web's help
 * (assets/help/web_help.json: tool/web_help.js) – the same rule for every message of the server (fixtures/help/web_fix.json). */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/ai_chat.dart';
import 'package:rcl_mobile/core/assistant.dart';
import 'package:rcl_mobile/core/web_help.dart';

final fx = jsonDecode(File('test/fixtures/ai/web_ai.json').readAsStringSync()) as Map<String, dynamic>;
List<Map<String, dynamic>> get master => [for (final m in fx['master'] as List) (m as Map).cast<String, dynamic>()];
final issues = [for (final m in fx['issues'] as List) m as Map];
final logs = [for (final m in fx['logs'] as List) m as Map];

/// The server of gen.js (the same answers).
dynamic server(String fn, List args, Map? brief) {
  final f = args.isNotEmpty && args[0] is Map ? args[0] as Map : const {};
  bool blank(Object? v) => v == null || v == '';
  bool inR(Map r) => (blank(f['from']) || '${r['date']}'.compareTo('${f['from']}') >= 0) && (blank(f['to']) || '${r['date']}'.compareTo('${f['to']}') <= 0) && (blank(f['no']) || r['no'] == f['no']);
  switch (fn) {
    case 'getDieselIssues':
      return {'rows': issues.where(inR).toList()};
    case 'getLogBookList':
      return {'rows': logs.where(inR).toList()};
    case 'logPending':
      return {
        'items': [['MH-25-AJ-8511', '2026-10-14'], ['EX-200', '2026-10-16'], ['JCB-3DX', '2026-10-16'], ['MH-12-SY-6216', '2026-10-16'], ['EX-200', '2026-10-15']],
        'from': '2026-10-01', 'asOf': '2026-10-16', 'total': 5,
      };
    case 'getStock':
      return {'stock': 1234.5, 'byLoc': {'Dispenser': 1000, 'VTR Store': 234.5}, 'inward': 50000, 'issued': 48765.5};
    case 'rptAverage':
      return {
        'groups': [
          {
            'rows': [
              {'no': 'MH-25-AJ-8511', 'type': 'Tipper', 'owner': 'Anand Earthmovers', 'ownership': 'Rental', 'unit': 'KM', 'km': 4000, 'hr': 0, 'used': 1300, 'expected': 1142.86, 'excess': 157.14, 'pct': 13.75, 'actual': '3.08 km/L', 'std': '3.5 km/L', 'status': 'More diesel', 'statusCode': 'more'},
              {'no': 'EX-200', 'type': 'Excavator', 'owner': 'Patil', 'ownership': 'Rental', 'unit': 'Hrs', 'km': 0, 'hr': 100, 'used': 1500, 'expected': 1200, 'excess': 300, 'pct': 25, 'actual': '15 L/hr', 'std': '12 L/hr', 'status': 'Bad', 'statusCode': 'bad'},
              {'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'owner': 'RCL', 'ownership': 'Own', 'unit': 'Hrs', 'km': 0, 'hr': 0, 'used': 120.5, 'expected': 0, 'excess': 0, 'pct': '', 'actual': '', 'std': '14 L/hr', 'status': 'No reading', 'statusCode': 'na'},
            ]
          }
        ]
      };
    case 'getLogRowPrefill':
      return args[0] == 'JCB-3DX'
          ? {'openingKm': 9100, 'openingHr': 1500, 'lastMode': 'KM + Hrs', 'firstKm': false, 'firstHr': false, 'problem': ''}
          : args[0] == 'EX-200'
              ? {'openingKm': '', 'openingHr': 2210, 'lastMode': 'Hrs', 'firstKm': false, 'firstHr': true, 'problem': ''}
              : {'openingKm': 148130, 'openingHr': '', 'lastMode': 'KM', 'firstKm': false, 'firstHr': false, 'problem': ''};
    case 'getBrief':
      return brief;
  }
  throw Exception('no $fn');
}

/// The assistant as the web's page was in gen.js: help language [lang], Edit on Diesel Issue and Log Book, two diesel places.
(Assistant, List<List>) make(String lang, {Map? brief}) {
  final calls = <List>[];
  final a = Assistant(
    call: (fn, args, {save = false}) async {
      calls.add([fn, ...args]);
      return jsonDecode(jsonEncode(server(fn, args, brief ?? (fx['briefs'] as List).first['brief'] as Map)));
    },
    today: '2026-10-16',
    master: master,
    locations: const ['Dispenser', 'VTR Store'],
    prefs: const {'loc': '', 'shift': ''},
    canEdit: (m) => m == 'Diesel Issue' || m == 'Log Book',
    helpLang: lang,
    now: () => DateTime(2026, 10, 16, 9, 30),
  );
  return (a, calls);
}

Map<String, Object?> draftJson(AiDraft d) => d.error.isNotEmpty
    ? {'error': d.error}
    : d.need.isNotEmpty
        ? {'need': d.need, 'partial': {'kind': d.partial!.kind, 'a': d.partial!.a}}
        : {'kind': d.kind, 'tab': d.tab, 'title': d.title, 'data': d.data, 'notes': d.notes, 'lines': [for (final l in d.lines) [l.$1, l.$2]], 'say': d.say};

void main() {
  test('The language, the dates, the machinery and the readings of a question – as the web reads them', () {
    final (a, _) = make('en');
    for (final e in (fx['langs'] as Map).entries) {
      expect(a.aiLangOf(e.key), e.value, reason: e.key);
    }
    for (final p in fx['periods'] as List) {
      final q = '${p[0]}';
      expect(a.aiPeriod(q, 'today').toJson(), p[1], reason: 'today: $q');
      expect(a.aiPeriod(q, 'month').toJson(), p[2], reason: 'month: $q');
      expect(a.aiPeriod(q, '').toJson(), p[3], reason: '30 days: $q');
    }
    for (final m in fx['machs'] as List) {
      expect(a.aiFindMach('${m[0]}')?['id'], m[1], reason: '${m[0]}');
    }
    for (final r in fx['readings'] as List) {
      expect(Assistant.aiReadings('${r[0]}'), r[1], reason: '${r[0]}');
    }
  });

  test('A command from words (diesel / Log Book) – or not a command', () {
    final (a, _) = make('en');
    for (final c in fx['commands'] as List) {
      final cmd = a.aiCommand('${c[0]}');
      expect(cmd == null ? null : {'kind': cmd.kind, 'a': cmd.a}, c[1], reason: '${c[0]}');
    }
  });

  test('The app\'s own answers to typed questions (strict and loose), with the look-ups they made – en / मराठी / हिंदी', () async {
    for (final c in fx['local'] as List) {
      final (a, calls) = make('${c['L']}');
      a.lang = a.aiLangOf('${c['q']}');
      final r = a.aiLocal('${c['q']}', c['loose'] == true);
      String? text, err;
      if (r != null) {
        try {
          text = await r();
        } catch (e) {
          err = aiErr(e);
        }
      }
      a.lang = '';
      final why = '${c['L']} ${c['loose'] == true ? 'loose' : 'strict'}: ${c['q']}';
      expect(text, c['answer'], reason: why);
      expect(err, c['err'], reason: why);
      expect(calls, c['calls'], reason: why);
    }
  });

  test('The entry prepared from words: every field, the notes, what is said – or what is missing / wrong', () async {
    for (final c in fx['drafts'] as List) {
      final (a, calls) = make('${c['L']}');
      final cmd = a.aiCommand('${c['q']}')!;
      expect({'kind': cmd.kind, 'a': cmd.a}, c['cmd'], reason: '${c['q']}');
      a.lang = a.aiLangOf('${c['q']}');
      final d = await a.aiDraft(cmd.kind, cmd.a);
      a.lang = '';
      expect(draftJson(d), c['d'], reason: '${c['L']}: ${c['q']}');
      expect(calls, c['calls'], reason: '${c['L']}: ${c['q']}');
    }
  });

  test('(3.43.0, the web\'s aiOwnSource_) his own diesel sources: no source named → his own; a source he names stays (the server says it is not his)', () async {
    final (a, _) = make('en');
    a.ownSources = ['VTR Store'];
    var cmd = a.aiCommand('8511 la 60 litre diesel de, reading 148200')!;
    expect((await a.aiDraft(cmd.kind, cmd.a)).data['source'], 'VTR Store');
    cmd = a.aiCommand('8511 la 60 litre diesel de Dispenser madhun, reading 148200')!;
    expect(cmd.a['source'], 'Dispenser');
    expect((await a.aiDraft(cmd.kind, cmd.a)).data['source'], 'Dispenser');
    a.ownSources = null;
    cmd = a.aiCommand('8511 la 60 litre diesel de, reading 148200')!;
    expect((await a.aiDraft(cmd.kind, cmd.a)).data['source'], 'Dispenser', reason: 'nothing chosen for him: as before');
  });

  test('(3.44.0, Mechanical update-163) the diesel entry of a Petrol car takes a Petrol place; an Electric car gets no fuel; a site of Diesel only as before', () async {
    final (a, _) = make('en');
    final m0 = a.master.firstWhere((m) => '${m['id']}'.contains('8511'));
    a.locations = ['Dispenser', 'VTR Store'];
    a.placeFuels = {'Dispenser': 'Diesel', 'VTR Store': 'Petrol'};
    a.master = [for (final m in a.master) identical(m, m0) ? {...m, 'fuel': 'Petrol'} : m];
    var cmd = a.aiCommand('8511 la 60 litre diesel de, reading 148200')!;
    expect((await a.aiDraft(cmd.kind, cmd.a)).data['source'], 'VTR Store', reason: 'the Petrol place');
    a.master = [for (final m in a.master) '${m['id']}' == '${m0['id']}' ? {...m, 'fuel': 'Electric'} : m];
    cmd = a.aiCommand('8511 la 60 litre diesel de, reading 148200')!;
    expect((await a.aiDraft(cmd.kind, cmd.a)).error, contains('runs on Electric – no fuel is issued to it'));
    a.master = [for (final m in a.master) '${m['id']}' == '${m0['id']}' ? {...m, 'fuel': 'Diesel'} : m];
    a.placeFuels = const {};
    cmd = a.aiCommand('8511 la 60 litre diesel de, reading 148200')!;
    expect((await a.aiDraft(cmd.kind, cmd.a)).data['source'], 'Dispenser', reason: 'all Diesel: as before');
  });

  test('(3.45.0, Mechanical update-164) a site on fuel cards: a fill is made in its form (its card or Cash, its ₹, the photos); the stock question gives the cards\' balances', () async {
    final (a, _) = make('en');
    a.cardSite = true;
    final cmd = a.aiCommand('8511 la 60 litre diesel de, reading 148200')!;
    expect((await a.aiDraft(cmd.kind, cmd.a)).error, 'At this site a fill is entered in the Diesel Issue form – with its card or Cash, the Amount (₹) and the photos. [[open:diesel|Diesel Issue]]');
    final r = a.readyOf('stock');
    expect(r.q(), 'How much is on the fuel cards now?');
    expect(await r.run(), 'This site is on fuel cards – no diesel stock. The cards now:\n–\n[[open:cards|Fuel Cards]]');
    a.cardSite = false;
    expect(r.q(), 'How much diesel is in stock now?', reason: 'any other site: as before');
  });

  test('The ⚡ questions on the Dashboard and the daily summary', () async {
    for (final c in fx['ready'] as List) {
      if (c['id'] == 'page') continue; // (the web's page guide was left out in node – its own test below)
      final (a, _) = make('${c['L']}');
      final r = a.readyOf('${c['id']}');
      expect(r.q(), c['q'], reason: '${c['L']} ${c['id']}');
      expect(await r.run(), c['answer'], reason: '${c['L']} ${c['id']}');
    }
    for (final b in fx['briefs'] as List) {
      final (a, _) = make('${b['L']}', brief: b['brief'] as Map);
      expect(await a.briefText(), b['text'], reason: '${b['L']} ${jsonEncode(b['brief']).substring(0, 40)}');
    }
    final (a, _) = make('mr');
    expect([for (final r in a.readyFor()) r.id], ['brief', 'pending', 'dieselY', 'dieselT', 'stock'], reason: 'the Dashboard: five, the summary first');
    a.page = 'log';
    a.picked = 'EX-200';
    expect([for (final r in a.readyFor()) r.id], ['pending', 'machPending', 'page', 'brief', 'dieselY'], reason: 'the Log Book with a machinery picked');
  });

  test('What is said aloud', () {
    for (final s in fx['speak'] as List) {
      expect(aiSpeakable('${s[1]}', '${s[0]}'), s[2], reason: '${s[0]}: ${s[1]}');
    }
  });

  test('The web\'s help: every server message gets the same help rule as on the web; the guide of a page', () {
    final help = WebHelp.fromJson((jsonDecode(File('assets/help/web_help.json').readAsStringSync()) as Map).cast<String, dynamic>());
    final fix = jsonDecode(File('test/fixtures/help/web_fix.json').readAsStringSync()) as List;
    for (final c in fix) {
      final hit = [for (final (i, r) in help.fix.indexed) if (r.re.hasMatch('${c['msg']}')) i].take(3).toList();
      expect(hit, c['rules'], reason: '${c['msg']}');
      expect(help.fixRules('${c['msg']}').length, hit.isEmpty ? 1 : hit.length);
    }
    expect(help.fixRules('something the app does not know'), [help.fixAny]);
    for (final l in ['en', 'mr', 'hi']) {
      expect(help.guideOf('dash')![l]!.length, 2, reason: 'dash $l');
      expect(help.guideOf('rp-ledger')![l]!.length, 2, reason: 'rp-ledger $l');
      expect(help.fixW['what']![l], isNotEmpty);
    }
    expect(help.guideOf('rp-nothing'), isNull);
  });

  test('The conversation: a command → the card → "हो" saves it through the app\'s save; half said → completed; a refused line is not "Saved"', () async {
    WebHelp.use(WebHelp.fromJson((jsonDecode(File('assets/help/web_help.json').readAsStringSync()) as Map).cast<String, dynamic>()));
    final saves = <List>[];
    var logAnswer = <String, dynamic>{'ok': true, 'count': 1};
    final a = Assistant(
      call: (fn, args, {save = false}) async {
        if (save) {
          saves.add([fn, ...args]);
          return fn == 'saveDieselIssue' ? {'id': 'DI-000777'} : logAnswer;
        }
        return jsonDecode(jsonEncode(server(fn, args, (fx['briefs'] as List).first['brief'] as Map)));
      },
      today: '2026-10-16',
      master: master,
      locations: const ['Dispenser', 'VTR Store'],
      canEdit: (_) => true,
      helpLang: 'mr',
      tabs: const [('diesel', 'Diesel Issue'), ('log', 'Log Book')],
      now: () => DateTime(2026, 10, 16, 9, 30),
    );
    final chat = AiChat(a)..reset();
    expect(chat.msgs.single.text, contains('AI key'), reason: 'not set up: said in the welcome');

    await chat.ask('8511 diesel de');
    expect(chat.msgs.last.text, 'MH-25-AJ-8511 ला किती लिटर?');
    expect(chat.partial, isNotNull);
    await chat.ask('६० लिटर'); // the next words complete it (Marathi digits)
    final card = chat.msgs.last;
    expect(card.kind, AiKind.card);
    expect(card.draft!.data['qty'], 60);
    expect(saves, isEmpty, reason: 'nothing is saved by itself');
    await chat.ask('हो');
    expect(saves.single[0], 'saveDieselIssue');
    expect(chat.msgs.last.text, startsWith('Save झाले ✔ Diesel Issue DI-000777 – MH-25-AJ-8511'));
    expect(chat.plain(chat.msgs.last.text), contains('Diesel Issue →'), reason: 'the page he can open: a button');
    expect(card.live, isFalse);

    await chat.ask('8511 log book close 148200');
    expect(chat.msgs.last.kind, AiKind.card);
    logAnswer = {'ok': false, 'errors': [{'row': 1, 'msg': 'MH-25-AJ-8511 already has a Log Book entry for 16-10-2026 Full Day.'}]};
    await chat.act('save');
    expect(chat.msgs.last.kind, AiKind.err);
    expect(chat.msgs.last.text, contains('already has a Log Book entry'));
    expect(chat.pending, isNotNull, reason: 'not saved: the card can still be saved or cancelled');
    await chat.ask('नाही');
    expect(chat.pending, isNull);
    expect(chat.msgs.last.text, 'रद्द केले; काही save झाले नाही.');

    await chat.ask('आजचा सारांश');
    expect(chat.msgs.last.text, startsWith('**सुप्रभात, Sujit.**'));
    expect(chat.msgs[chat.msgs.length - 2].text, '⚡ app कडून थेट, आत्ता');

    await chat.ask('why is EX-200 average bad'); // for the AI – not set up → the app's loose answer, said so
    expect(chat.msgs.last.kind, AiKind.bot);
    expect(chat.msgs[chat.msgs.length - 2].text, startsWith('⚡ The AI service is not set up – '));
    expect(chat.msgs.last.text, startsWith('**EX-200** – '));
  });
}
