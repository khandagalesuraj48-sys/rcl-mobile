/* (3.61.0, Mechanical update-186) THE ASSISTANT LIVE – the answer word by word (POST <mechanical>/api/ai: lines of JSON, read as they
 * come and no further than the last one), the waiting bubble written as the words come, the answer in one piece as the way back
 * (AI_NO_STREAM, a stream cut after words, a line lost – the service's own answer is not asked twice), each finished sentence said
 * while the rest is written in a talk (the web's AI_SQ / aiSayFeed: fixtures/ai/web_say186.json – update-186's App.html code run in
 * node on the same answers), the chat kept after every answer (aiChatSave), History (aiChats / aiChatGet) and Memory (aiMemory /
 * aiMemoryDel), a note it just kept with "Take it out". */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rcl_mobile/core/ai_chat.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/assistant.dart';

typedef Line = Map<String, dynamic>;
typedef Hook = Future<Line?> Function(Map<String, dynamic> x, void Function(Line line) onLine);

/// The server's answers (as Mechanical's): getAiReply in one piece, the chats, the memory, the look-ups – and what was asked.
class Srv {
  final calls = <List<Object?>>[];
  final replies = <Map<String, dynamic>>[];
  Iterable<List<Object?>> of(String fn) => calls.where((c) => c[0] == fn);

  Future<dynamic> call(String fn, List<dynamic> args, {bool save = false}) async {
    calls.add([fn, ...args, if (save) 'save']);
    final x = args.isNotEmpty && args[0] is Map ? args[0] as Map : const {};
    switch (fn) {
      case 'getAiReply':
        return replies.isNotEmpty ? replies.removeAt(0) : {'parts': [{'text': 'In one piece.'}], 'model': 'claude-haiku-5-5'};
      case 'aiChatSave':
        return {'kept': true, 'id': x['id']};
      case 'aiChats':
        return {'on': true, 'chats': [{'id': 'Cmh9old00abc12', 'title': 'diesel of yesterday', 'n': 1, 'at': '2026-10-15T18:05:00'}]};
      case 'aiChatGet':
        return {
          'id': x['id'], 'title': 'diesel of yesterday', 'n': 1, 'at': '2026-10-15T18:05:00',
          'msgs': [
            {'r': 'me', 't': 'diesel of yesterday'},
            {'r': 'src', 't': 'Looked up: · Diesel issues 15-10-2026'},
            {'r': 'bot', 't': '180 L yesterday.'},
          ],
        };
      case 'aiMemory':
        return {'on': true, 'notes': [{'id': 7, 'note': 'He wants the answers short.', 'at': '2026-10-14T05:30:00'}]};
      case 'aiMemoryDel':
        return {'forgotten': true, 'id': x['id']};
      case 'aiLookup':
        final a = x['args'] is Map ? x['args'] as Map : const {};
        if (x['name'] == 'remember') return '${a['note']}'.contains('short') ? {'remembered': true, 'id': 8, 'note': '${a['note']}'} : {'remembered': true, 'id': 7, 'note': '${a['note']}', 'already': true};
        return {'error': 'There is no such look-up.'};
    }
    return <String, dynamic>{}; // the day's figures (none here)
  }
}

/// The assistant of the phone on a fixed day, the Admin (he sees the model and its times), the AI service set up.
AiChat chatOf(Srv srv, Hook? hook) => AiChat(
      Assistant(
        call: srv.call,
        today: '2026-10-16',
        master: const [],
        canEdit: (_) => false,
        helpLang: 'en',
        stream: hook,
        now: () => DateTime(2026, 10, 16, 9, 30),
      ),
      aiOn: true,
      admin: true,
    )..reset();

Line d(String x) => {'t': 'd', 'x': x};
Line endOf(List<Map<String, Object?>> parts, [String model = 'claude-sonnet-5-5']) => {'t': 'end', 'parts': parts, 'model': model, 'used': 100, 'ms': 900};
const kBusy = 'The AI service is busy right now (529) – that is on its side, not in the app. It was asked 1 time(s). Please ask again in a minute.';
const kCredit = 'The AI service has no credit left (Claude): the Admin has to add funds in Claude Console → Billing. The rest of the app works as always.';

Api apiOf(http.Client c) => Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep(), client: c)
  ..mechUrl = 'https://erp.test'
  ..token = 'tok-S1'
  ..site = 'S1';

http.StreamedResponse ndjson(Stream<List<int>> body) => http.StreamedResponse(body, 200, headers: {'content-type': 'application/x-ndjson; charset=utf-8'});

void main() {
  group('Api.aiStream – the lines of /api/ai', () {
    test('each line is handed on as soon as it is whole (pieces of 5 bytes – a line and a Devanagari letter cut in two); an empty or broken line is left out; nothing after the last line is read', () async {
      final lines = [jsonEncode(d('आज ')), jsonEncode(d('240 L')), '', '{broken', jsonEncode(endOf([{'text': 'आज 240 L'}])), jsonEncode(d('after the end'))];
      final bytes = utf8.encode('${lines.join('\n')}\n');
      final ctl = StreamController<List<int>>();
      late Uri url;
      late Map sent;
      final c = MockClient.streaming((rq, body) async {
        url = rq.url;
        sent = jsonDecode(await body.bytesToString()) as Map;
        return ndjson(ctl.stream);
      });
      final got = <Line>[];
      final f = apiOf(c).aiStream({'contents': const [], 'context': const {'page': {'tab': 'dash'}}}, got.add);
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      // the lines handed on once k new lines have come: d, d, (empty), (broken), end, (after the end – not read)
      const handed = [0, 1, 2, 2, 2, 3, 3];
      final seen = <int>[], whole = <int>[];
      var piece = 0;
      for (var i = 0; i < bytes.length; i += 5) {
        final upto = min(i + 5, bytes.length);
        ctl.add(bytes.sublist(i, upto));
        await Future<void>.delayed(Duration.zero);
        piece++;
        seen.add(got.length);
        whole.add(handed[bytes.sublist(0, upto).where((b) => b == 10).length]);
      }
      final end = await f.timeout(const Duration(seconds: 5));
      unawaited(ctl.close());
      expect(piece, greaterThan(20));
      expect(seen, whole, reason: 'a line is handed on when its new line came – not before, not later');
      expect(got, [d('आज '), d('240 L'), endOf([{'text': 'आज 240 L'}])], reason: 'the empty and the broken line left out; the line after the end not read');
      expect(end, endOf([{'text': 'आज 240 L'}]));
      expect(url.toString(), 'https://erp.test/api/ai');
      expect(sent, {'token': 'tok-S1', 'x': {'contents': [], 'context': {'page': {'tab': 'dash'}}}, 'site': 'S1'});
    });

    test('the service\'s err line is the last one (cut or not); a stream lost before its end gives null (what came was handed on)', () async {
      Future<(Line?, List<Line>)> run(Stream<List<int>> body) async {
        final got = <Line>[];
        final r = await apiOf(MockClient.streaming((_, __) async => ndjson(body))).aiStream({}, got.add);
        return (r, got);
      }

      final err = {'t': 'err', 'e': kBusy, 'cut': true};
      final (r1, g1) = await run(Stream.value(utf8.encode('${jsonEncode(d('The first '))}\n${jsonEncode(err)}\n')));
      expect(r1, err);
      expect(g1, [d('The first '), err]);
      final lost = StreamController<List<int>>();
      final f = run(lost.stream);
      lost.add(utf8.encode('${jsonEncode(d('Half '))}\n'));
      lost.addError(const SocketException('Connection reset by peer'));
      unawaited(lost.close());
      final (r2, g2) = await f;
      expect(r2, isNull);
      expect(g2, [d('Half ')]);
    });

    test('before the first line: the app\'s own refusal as JSON {error} is thrown; AI_NO_STREAM (no Claude key – Gemini) and an older server without /api/ai (404) both say AI_NO_STREAM; not signed in – nothing is sent', () async {
      Future<ApiError> fails(int code, String body, String type) async {
        try {
          await apiOf(MockClient.streaming((_, __) async => http.StreamedResponse(Stream.value(utf8.encode(body)), code, headers: {'content-type': type}))).aiStream({}, (_) {});
        } on ApiError catch (e) {
          return e;
        }
        fail('no error');
      }

      expect((await fails(200, '{"error":"AI_NO_STREAM"}', 'application/json; charset=utf-8')).message, 'AI_NO_STREAM');
      expect((await fails(404, '<!doctype html><title>404</title>', 'text/html')).message, 'AI_NO_STREAM');
      final ended = await fails(401, '{"error":"SESSION_EXPIRED"}', 'application/json');
      expect(ended.sessionEnded, true);
      expect((await fails(429, '{"error":"You asked the assistant 60 times in the last hour – ask again a little later."}', 'application/json')).message,
          'You asked the assistant 60 times in the last hour – ask again a little later.');
      var asked = 0;
      final api = apiOf(MockClient.streaming((_, __) async {
        asked++;
        return ndjson(const Stream.empty());
      }))
        ..token = null;
      await expectLater(api.aiStream({}, (_) {}), throwsA(isA<ApiError>().having((e) => e.sessionEnded, 'sign-in ended', true)));
      expect(asked, 0);
    });
  });

  group('SayQueue – the web\'s AI_SQ / aiSayFeed (said while written)', () {
    final fx = jsonDecode(File('test/fixtures/ai/web_say186.json').readAsStringSync()) as Map<String, dynamic>;
    for (final (n, c0) in (fx['cases'] as List).indexed) {
      final c = c0 as Map<String, dynamic>;
      test('case ${n + 1} (${c['lang']}): the same parts as the web, the same ones while it is written', () {
        final q = SayQueue()..start(true, '${c['lang']}');
        final full = '${c['full']}', step = c['step'] as int, said = <String>[];
        for (var i = step; i < full.length; i += step) {
          said.addAll(q.feed(full.substring(0, i), false));
        }
        final whileWritten = said.length;
        said.addAll(q.feed(full, true));
        expect(said, [for (final s in c['said'] as List) '$s']);
        expect(whileWritten, c['saidWhileWritten']);
        expect(q.parts, said.length);
      });
    }

    test('leading spaces and new lines do not count (streamed and whole alike); not in a talk – nothing; stopped – nothing more', () {
      final q = SayQueue()..start(true, 'mr');
      expect(q.feed('\n  आज 240 लिटर. काल', false), ['आज 240 लिटर.']);
      expect(q.feed('आज 240 लिटर. काल 180 लिटर.', true), ['काल 180 लिटर.'], reason: 'the whole answer (trimmed) counted from the same place');
      final off = SayQueue()..start(false, 'en');
      expect(off.feed('One. Two. ', false), isEmpty);
      expect(off.feed('One. Two.', true), isEmpty);
      final s = SayQueue()..start(true, 'en');
      expect(s.feed('One. Two', false), ['One.']);
      s.stop();
      expect(s.feed('One. Two. Three.', true), isEmpty);
      expect(s.parts, 0);
    });
  });

  group('AiChat – each step word by word', () {
    test('the words go into the waiting bubble as they come (no "Thinking…"); the screen is told at most about 15 times a second; the answer from its parts; the Admin\'s "first words"; nothing asked in one piece; the chat kept after the answer', () async {
      final srv = Srv();
      late AiChat chat;
      final seen = <String>[];
      var told = 0;
      chat = chatOf(srv, (x, on) async {
        expect((x['contents'] as List).last, {'role': 'user', 'parts': [{'text': 'how is the diesel going today'}]});
        expect((x['context'] as Map)['asOf'], '09:30:00', reason: 'the day\'s figures go with it');
        expect(chat.msgs.last.text, '…', reason: 'no "Thinking…"');
        expect(chat.msgs.last.writing, false);
        final t0 = told;
        for (final w in ['Diesel ', 'today: ', '**240 L**', ' in 4 entries.']) {
          on(d(w));
          final m = chat.msgs.last;
          expect([m.kind, m.writing], [AiKind.wait, true], reason: 'the bubble is being written');
          seen.add(m.text);
        }
        expect(told - t0, 1, reason: 'four lines at once: drawn once');
        await Future<void>.delayed(const Duration(milliseconds: 80));
        on(d(' ✓'));
        expect(told - t0, 2, reason: 'after 66 ms: drawn again');
        final e = endOf([{'text': 'Diesel today: **240 L** in 4 entries. ✓'}]);
        on(e);
        return e;
      });
      chat.addListener(() => told++);
      await chat.ask('how is the diesel going today', onlyAi: true);
      expect(seen, ['Diesel ', 'Diesel today: ', 'Diesel today: **240 L**', 'Diesel today: **240 L** in 4 entries.']);
      expect(chat.msgs.where((m) => m.kind == AiKind.wait), isEmpty);
      expect(chat.msgs.last.kind, AiKind.bot);
      expect(chat.msgs.last.text, 'Diesel today: **240 L** in 4 entries. ✓');
      final src = chat.msgs[chat.msgs.length - 2];
      expect(src.text, 'From the figures of 09:30:00');
      expect(src.chips.single, matches(RegExp(r'^claude-sonnet-5-5 · [\d.]+ s · first words [\d.]+ s$')));
      expect(srv.of('getAiReply'), isEmpty);
      expect(chat.turns.last, {'role': 'model', 'parts': [{'text': 'Diesel today: **240 L** in 4 entries. ✓'}]});
      final kept = srv.of('aiChatSave').single[1] as Map;
      expect(kept['id'], chat.chatId);
      expect(RegExp(r'^C[0-9a-z]{6,30}$').hasMatch(chat.chatId), true, reason: 'the server\'s rule for a chat\'s number');
      expect((kept['msgs'] as List).first, {'r': 'me', 't': 'how is the diesel going today'});
      expect('${((kept['msgs'] as List)[1] as Map)['t']}', startsWith('From the figures of 09:30:00 · claude-sonnet-5-5 · '));
      expect((kept['msgs'] as List).last, {'r': 'bot', 't': 'Diesel today: 240 L in 4 entries. ✓'}, reason: 'the answer as plain words');
      expect((kept['msgs'] as List).length, 3, reason: 'the welcome before his first question is not kept');
    });

    test('a step that asks for look-ups: what it wrote before them is taken away (not kept, not said); "remember" goes to the server (Memory – kept) and the note is shown with "Take it out" – not kept with the chat; one it already had is not shown again', () async {
      final srv = Srv();
      late AiChat chat;
      final said = <String>[];
      var step = 0;
      chat = chatOf(srv, (x, on) async {
        step++;
        if (step == 1) {
          on(d('Let me keep that'));
          expect(chat.msgs.last.writing, true);
          return endOf([{'text': 'Let me keep that'}, {'functionCall': {'name': 'remember', 'args': {'note': 'He wants the answers short.'}}}, {'functionCall': {'name': 'remember', 'args': {'note': 'He calls the Dispenser the pump.'}}}]);
        }
        expect(chat.msgs.last.text, 'Writing the answer…', reason: 'the words of the look-up\'s step are gone');
        expect(chat.msgs.last.writing, false);
        final back = ((x['contents'] as List).last as Map)['parts'] as List;
        expect(((back.first as Map)['functionResponse'] as Map)['response'], {'remembered': true, 'id': 8, 'note': 'He wants the answers short.'});
        on(d('Kept: short answers from now on.'));
        return endOf([{'text': 'Kept: short answers from now on.'}]);
      });
      chat.talking = true;
      chat.sayPart = (w, l) => said.add(w);
      chat.sayStop = () {};
      await chat.ask('remember that I want the answers short', onlyAi: true);
      expect(srv.of('aiLookup').map((c) => c[1]), [
        {'name': 'remember', 'args': {'note': 'He wants the answers short.'}},
        {'name': 'remember', 'args': {'note': 'He calls the Dispenser the pump.'}},
      ]);
      expect(chat.msgs.where((m) => m.text.contains('Let me keep that')), isEmpty);
      expect(said, ['Kept: short answers from now on.'], reason: 'the look-up\'s words never said');
      final i = chat.msgs.indexWhere((m) => m.kind == AiKind.bot && m.text == 'Kept: short answers from now on.');
      expect(chat.msgs[i - 1].text, 'Looked up:');
      expect(chat.msgs[i - 1].chips.take(2), ['Memory – kept', 'Memory – kept']);
      final k = chat.msgs.last;
      expect([i, k.kind, k.text, k.note, k.keptId, k.button], [chat.msgs.length - 2, AiKind.src, 'Kept in memory: He wants the answers short.', true, 8, 'Take it out'],
          reason: 'only the new note (the other one it had already)');
      expect(((srv.of('aiChatSave').single[1] as Map)['msgs'] as List).where((m) => '${(m as Map)['t']}'.contains('Kept in memory')), isEmpty);
      // "Take it out": out of its memory (a save – sent with its number), the line says so
      await chat.unkeep(k);
      expect(srv.calls.last, ['aiMemoryDel', {'id': 8}, 'save']);
      expect([k.keptId, k.text], [0, 'Taken out of the memory.']);
      await chat.unkeep(k);
      expect(srv.of('aiMemoryDel').length, 1, reason: 'once');
    });

    test('the way back – in one piece (getAiReply), as the web: AI_NO_STREAM (for the rest of the chat); cut after words (asked once more); a line lost; no connection – and the service\'s own answer (busy before a word, no credit) is said, not asked twice', () async {
      Future<(Srv, AiChat, int)> run(List<Hook> steps, String q) async {
        final srv = Srv();
        var n = 0;
        final chat = chatOf(srv, (x, on) {
          return steps[min(n++, steps.length - 1)](x, on);
        });
        await chat.ask(q, onlyAi: true);
        return (srv, chat, n);
      }

      // Gemini / an older server
      final (s1, c1, n1) = await run([(x, on) async => throw ApiError('AI_NO_STREAM')], 'how is the diesel going today');
      expect([n1, s1.of('getAiReply').length, c1.streamOn, c1.msgs.last.text], [1, 1, false, 'In one piece.']);
      await c1.ask('and yesterday then', onlyAi: true);
      expect(s1.of('getAiReply').length, 2, reason: 'no stream for the rest of the chat');
      // the stream cut after words: asked once more in one piece – the words that came are gone
      final (s2, c2, _) = await run([
        (x, on) async {
          on(d('The first words of '));
          return {'t': 'err', 'e': kBusy, 'cut': true};
        },
      ], 'how is the diesel going today');
      expect([s2.of('getAiReply').length, c2.streamOn, c2.msgs.last.text], [1, true, 'In one piece.']);
      expect(c2.msgs.where((m) => m.text.contains('The first words')), isEmpty);
      // a line lost before the end; no connection: in one piece too
      for (final h in <Hook>[
        (x, on) async {
          on(d('Half '));
          return null;
        },
        (x, on) async => throw ApiError('No connection – check the internet and try again.', code: 'net'),
      ]) {
        final (s, c, _) = await run([h], 'how is the diesel going today');
        expect([s.of('getAiReply').length, c.streamOn, c.msgs.last.text], [1, true, 'In one piece.']);
      }
      // the service's own answer: not asked in one piece – said as getAiReply says it
      for (final e in [kBusy, kCredit]) {
        final (s, c, _) = await run([(x, on) async => {'t': 'err', 'e': e, 'cut': false}], 'write me a poem');
        expect(s.of('getAiReply'), isEmpty);
        expect(c.msgs.any((m) => m.text.contains(e.substring(0, 40))), true, reason: e);
      }
    });
  });

  group('AiChat – a talk: said while it is written', () {
    test('each finished sentence is handed on while the rest is still written (a number\'s point is no end, a page button not said), the rest at the end; his microphone while it speaks: nothing more of this question is said; a new question cuts what was being said', () async {
      final srv = Srv();
      late AiChat chat;
      final said = <String>[];
      var stops = 0, q = 0;
      chat = chatOf(srv, (x, on) async {
        q++;
        if (q == 1) {
          on(d('Diesel today: 240 L. '));
          expect(said, ['en:Diesel today: 240 L.'], reason: 'said while the rest is still to come');
          on(d('The average is 3.08 km/L'));
          expect(said.length, 1, reason: '3.08 – no end of a sentence');
          on(d(' – good.\n[[open:diesel|Diesel Issue]]'));
          expect(said.last, 'en:The average is 3.08 km/L – good.');
          return endOf([{'text': 'Diesel today: 240 L. The average is 3.08 km/L – good.\n[[open:diesel|Diesel Issue]]'}]);
        }
        if (q == 2) {
          on(d('One. '));
          expect(said.last, 'en:One.');
          chat.hush = true; // (the screen: the microphone pressed while it speaks)
          chat.say.stop();
          on(d('Two. '));
          return endOf([{'text': 'One. Two. Three.'}]);
        }
        on(d('Not said. '));
        return endOf([{'text': 'Not said. At all.'}]);
      });
      chat.talking = true;
      chat.sayPart = (w, l) => said.add('$l:$w');
      chat.sayStop = () => stops++;
      await chat.ask('how is the diesel going today', onlyAi: true);
      expect(said, ['en:Diesel today: 240 L.', 'en:The average is 3.08 km/L – good.'], reason: 'nothing more at the end: the page button is not said');
      expect(stops, 0);
      await chat.ask('and the next', onlyAi: true);
      expect(stops, 1, reason: 'the new question: what was being said stops');
      expect(said.last, 'en:One.', reason: 'after his microphone: nothing more of this question');
      chat.hush = false;
      // not in a talk: nothing said
      chat.talking = false;
      final n = said.length;
      await chat.ask('how is the diesel going today', onlyAi: true);
      expect(said.length, n);
    });
  });

  group('AiChat – his chats and its memory', () {
    test('kept only once there is an answer, as he saw it (questions, answers as plain words, "Looked up"; the screen\'s own notes left out); New chat – a new number; History opens a chat again: its turns, the note, the same number', () async {
      final srv = Srv();
      final chat = chatOf(srv, null);
      chat.keepChat();
      chat.msgs.add(AiMsg(AiKind.me, 'diesel of yesterday'));
      chat.keepChat();
      expect(srv.of('aiChatSave'), isEmpty, reason: 'no answer yet');
      chat.msgs
        ..add(AiMsg(AiKind.src, 'Looked up:', chips: const ['Diesel issues 15-10-2026']))
        ..add(AiMsg(AiKind.bot, '**180 L** yesterday. [[open:diesel|Diesel Issue]]'))
        ..add(AiMsg(AiKind.src, 'Kept in memory: x', note: true, keptId: 3))
        ..add(AiMsg(AiKind.err, 'The AI service did not answer'));
      chat.keepChat();
      expect(srv.of('aiChatSave').single[1], {
        'id': chat.chatId,
        'msgs': [
          {'r': 'me', 't': 'diesel of yesterday'},
          {'r': 'src', 't': 'Looked up: · Diesel issues 15-10-2026'},
          {'r': 'bot', 't': '180 L yesterday. Diesel Issue'},
        ],
      });
      final first = chat.chatId;
      chat.reset();
      expect(chat.chatId, isNot(first));
      expect(RegExp(r'^C[0-9a-z]{6,30}$').hasMatch(chat.chatId), true);
      expect(newChatId(Random(1)), matches(RegExp(r'^C[0-9a-z]{8,9}[0-9a-z]{6}$')));
      expect((await chat.chatList())['chats'], [{'id': 'Cmh9old00abc12', 'title': 'diesel of yesterday', 'n': 1, 'at': '2026-10-15T18:05:00'}]);
      await chat.openChat('Cmh9old00abc12');
      expect(srv.calls.last, ['aiChatGet', {'id': 'Cmh9old00abc12'}]);
      expect(chat.chatId, 'Cmh9old00abc12');
      expect([for (final m in chat.msgs) [m.kind, m.text, ...m.chips]], [
        [AiKind.me, 'diesel of yesterday'],
        [AiKind.src, 'Looked up:', 'Diesel issues 15-10-2026'],
        [AiKind.bot, '180 L yesterday.'],
        [AiKind.src, 'Opened from History (15-10-2026, 18:05) – ask on; the figures are looked up again.'],
      ]);
      expect(chat.msgs.last.note, true);
      expect(chat.turns, [
        {'role': 'user', 'parts': [{'text': 'diesel of yesterday'}]},
        {'role': 'model', 'parts': [{'text': '180 L yesterday.'}]},
      ]);
      chat.keepChat();
      final again = srv.of('aiChatSave').last[1] as Map;
      expect(again['id'], 'Cmh9old00abc12', reason: 'it goes on as the same chat');
      expect((again['msgs'] as List).length, 3, reason: 'the note "Opened from History" is not kept');
      expect(aiWhen('2026-10-14T05:30:00'), '14-10-2026, 05:30');
      expect(aiWhen(''), '');
    });

    test('Memory: his notes (aiMemory); × – aiMemoryDel {id} as a save; "remember" / "forget" are named in "Looked up"', () async {
      final srv = Srv();
      final chat = chatOf(srv, null);
      expect((await chat.memory())['notes'], [{'id': 7, 'note': 'He wants the answers short.', 'at': '2026-10-14T05:30:00'}]);
      await chat.forget(7);
      expect(srv.calls.last, ['aiMemoryDel', {'id': 7}, 'save']);
      expect(Assistant.aiWhat('remember', const {'note': 'x'}), 'Memory – kept');
      expect(Assistant.aiWhat('forget', const {'id': 7}), 'Memory – taken out');
    });
  });
}
