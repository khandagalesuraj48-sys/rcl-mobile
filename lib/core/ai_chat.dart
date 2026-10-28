/* THE CONVERSATION WITH THE ASSISTANT (3.15.0) – the web's aiAsk / aiReady / aiPrepare / aiDo / aiReset / aiTest, step by step:
 *   0. an entry waits for its yes / no ("हो" saves it, "नाही" cancels it); or the words are a command – or complete one that was
 *      half said ("60 लिटर" after "For which machinery? … 8511") → the entry is SHOWN with Save / Open in the form / Cancel;
 *   1. the app understands the question for sure → answered by the app (⚡);
 *   2. otherwise the AI service (getAiReply) with the snapshot of the day and the machinery of the question; the look-ups it asks
 *      for run here, side by side, with his own sign-in; at most 7 steps;
 *   3. the AI service fails or is not set up → the app answers as well as it can (its loose reading, or the guide of the page that
 *      fits) and says so; an error only when nothing at all can be said – with "Ask again".
 * The assistant never saves by itself: only his Save (or "हो") sends the entry, through the app's own save and its checks. */
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'assistant.dart';
import 'web_help.dart';

enum AiKind { me, bot, err, src, wait, card, warn }

/// One message of the conversation.
class AiMsg {
  AiMsg(this.kind, this.text, {this.draft, this.retry = '', this.chips = const [], this.say = '', this.small = '', this.note = false, this.keptId = 0, this.button = ''});
  final AiKind kind;

  /// (3.61.0, Mechanical update-186) a note it just kept in its memory (the line "Kept in memory: …" with "Take it out"): the note's
  /// number; below 0 while it is being taken out; 0 – none (or taken out)
  int keptId;

  /// (3.61.0) the words of its button ("Take it out" – in the question's language)
  final String button;

  /// (3.61.0) a waiting bubble whose answer is being written into it, word by word
  bool writing = false;

  /// (3.61.0) a line of the screen itself ("Opened from History …") – not kept with the chat
  final bool note;

  /// The words (an answer: with **bold** and [[open:page|Label]]).
  String text;

  /// A prepared entry (Save / Open in the form / Cancel).
  final AiDraft? draft;

  /// Its buttons still work (a card or a "check the reading" message).
  bool live = true;

  /// An error: "Ask again" asks these words again.
  final String retry;

  /// Under an answer: what was looked up ("Looked up: …").
  final List<String> chips;

  /// What is said aloud for it ('' = its own words).
  final String say;

  /// An error: the line under it.
  final String small;
}

class AiChat extends ChangeNotifier {
  AiChat(this.a, {this.aiOn = false, this.admin = false, this.onForm, this.onSaved, this.pageTitle = 'Dashboard'});
  final Assistant a;

  /// The AI service is set up on the server (getInit → ai.on).
  bool aiOn;
  bool admin;

  /// "Open in the form": the screen opens the app's own form with the entry in it.
  void Function(AiDraft d)? onForm;

  /// An entry was saved (the screens learn of it: the stock, the lists).
  void Function(Map r)? onSaved;
  String pageTitle;

  final msgs = <AiMsg>[];
  final turns = <Map<String, Object?>>[];
  bool busy = false;

  /// (3.61.0, Mechanical update-186) the answer word by word (false once the server said it has none – AI_NO_STREAM: Gemini, an older
  /// server – for the rest of this conversation)
  bool streamOn = true;

  /// (3.61.0) this chat's own number: kept after every answer (aiChatSave), opened again from History; a new one at New chat
  String chatId = newChatId();

  /// (3.61.0) a talk (the screen sets it): each finished sentence is handed to [sayPart] while the answer is still being written;
  /// [sayStop] stops what is being said
  bool talking = false;
  void Function(String words, String lang)? sayPart;
  void Function()? sayStop;
  final say = SayQueue();

  /// (3.61.0) he pressed the microphone while it spoke, during this question: nothing more of it is said
  bool hush = false;
  AiDraft? pending;
  AiCmd? partial;
  String lastAnswer = '', lastLang = '';

  AiMsg _add(AiMsg m) {
    msgs.add(m);
    notifyListeners();
    return m;
  }

  void _drop(AiMsg m) {
    if (msgs.remove(m)) notifyListeners();
  }

  void _waitSays(AiMsg w, String t) {
    w.text = t;
    notifyListeners();
  }

  static Map<String, Object?> _user(String t) => {'role': 'user', 'parts': [{'text': t}]};
  static Map<String, Object?> _model(String t) => {'role': 'model', 'parts': [{'text': t}]};

  /// The words of an answer as they are read (the web's textContent: no marks, a page button as "Label →").
  String plain(String t) => t
      .trim()
      .replaceAllMapped(RegExp(r'\*\*([^*\n]+)\*\*'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'\[\[open:([a-z0-9-]+)\|([^\]\n]{1,60})\]\]', caseSensitive: false), (m) => a.tabs.any((x) => x.$1 == m[1]!.toLowerCase()) ? '${m[2]} →' : m[2]!);

  /// A new conversation (the web's aiReset). (The app also forgets an entry that was waiting for Save: its card is gone.)
  void reset() {
    _sayCut();
    chatId = newChatId();
    turns.clear();
    msgs.clear();
    pending = null;
    partial = null;
    _add(AiMsg(
        AiKind.bot,
        a.aiL(const {
              'en': 'Ask me anything about this app. The questions with ⚡ are answered by the app itself, at once.',
              'mr': 'या app बद्दल काहीही विचारा. ⚡ असलेल्या प्रश्नांची उत्तरे app स्वतः लगेच देते.',
              'hi': 'इस app के बारे में कुछ भी पूछें। ⚡ वाले सवालों के जवाब app खुद तुरंत देता है।',
            }) +
            (aiOn
                ? ''
                : ' ${a.aiL(const {
                    'en': '(Typed questions need the AI key – not set up yet.)',
                    'mr': '(टाइप केलेल्या प्रश्नांसाठी AI key लागते; ती अजून दिलेली नाही.)',
                    'hi': '(टाइप किए सवालों के लिए AI key चाहिए; वह अभी नहीं दी गई।)',
                  })}')));
  }

  String get _byApp => a.aiL(const {'en': 'from the app itself, now', 'mr': 'app कडून थेट, आत्ता', 'hi': 'app से सीधे, अभी'});

  /// A ⚡ question: answered by the app itself.
  Future<void> ready(String id) async {
    final r = a.ready.where((x) => x.id == id).firstOrNull;
    if (r == null || busy) return;
    final q = r.q();
    busy = true;
    _add(AiMsg(AiKind.me, q));
    final wait = _add(AiMsg(AiKind.wait, '…'));
    try {
      final t = await r.run();
      _drop(wait);
      _add(AiMsg(AiKind.src, '⚡ $_byApp'));
      _add(AiMsg(AiKind.bot, t));
      turns
        ..add(_user(q))
        ..add(_model(t)); // (so that a typed follow-up knows what was just said)
    } catch (e) {
      _drop(wait);
      _add(AiMsg(AiKind.err, aiErr(e)));
    } finally {
      busy = false;
      notifyListeners();
      keep();
    }
  }

  /// Shows what was prepared (or asks for what is missing); returns the words for the conversation.
  Future<Map<String, Object?>> prepare(String kind, Map<String, Object?> args) async {
    final d = await a.aiDraft(kind, args);
    if (d.error.isNotEmpty) {
      pending = null;
      _add(AiMsg(AiKind.bot, d.error));
      return {'error': d.error, 'text': d.error};
    }
    if (d.need.isNotEmpty) {
      partial = d.partial;
      _add(AiMsg(AiKind.bot, d.need));
      return {'askedThePersonFor': d.need, 'text': d.need};
    }
    partial = null;
    pending = d;
    _add(AiMsg(AiKind.card, d.title, draft: d, say: d.say));
    return {'shownToThePersonForSaveOrCancel': true, 'notSavedYet': true, 'entry': [for (final l in d.lines) '${l.$1}: ${l.$2}'], 'text': d.say};
  }

  /// His answer to a prepared entry: 'save' (force: "Save anyway"), 'form' or 'cancel'.
  Future<void> act(String what, {bool force = false}) async {
    final d = pending;
    if (d == null || busy) return;
    void off() {
      for (final m in msgs.where((m) => m.kind == AiKind.card || m.kind == AiKind.warn)) {
        m.live = false;
      }
    }

    if (what == 'cancel') {
      pending = null;
      off();
      final t = a.aiL(const {'en': 'Cancelled – nothing was saved.', 'mr': 'रद्द केले; काही save झाले नाही.', 'hi': 'रद्द किया; कुछ save नहीं हुआ।'});
      _add(AiMsg(AiKind.bot, t));
      lastAnswer = t;
      return;
    }
    if (what == 'form') {
      pending = null;
      off();
      notifyListeners();
      onForm?.call(d);
      return;
    }
    busy = true;
    final wait = _add(AiMsg(AiKind.wait, 'Saving…'));
    try {
      final r = await a.saveDraft(d, force: force);
      _drop(wait);
      if (r['warning'] != null) {
        for (final m in msgs.where((m) => m.kind == AiKind.warn)) {
          m.live = false;
        }
        _add(AiMsg(AiKind.warn, '${r['warning']}', say: '${r['warning']}'));
        lastAnswer = '${r['warning']}';
        return;
      }
      // (the app) a Log Book line the server refused ({ok: false, errors}) was NOT saved – it is never called "Saved"
      if (r['ok'] == false) {
        final errs = [for (final x in (r['errors'] is List ? r['errors'] as List : const [])) x is Map ? '${x['msg'] ?? ''}' : '$x'].where((x) => x.isNotEmpty).toList();
        throw AiStop(errs.isEmpty ? 'The entry was not saved.' : errs.join('\n'));
      }
      pending = null;
      off();
      a.snapAt = null;
      final t = '${a.aiL(const {'en': 'Saved ✔ ', 'mr': 'Save झाले ✔ ', 'hi': 'Save हो गया ✔ '})}${d.title}${r['id'] != null && '${r['id']}'.isNotEmpty ? ' ${r['id']}' : ''} – '
          '${d.lines.first.$2.split(' · ').first}\n[[open:${d.tab}|${d.kind == 'diesel' ? 'Diesel Issue' : 'Log Book'}]]';
      _add(AiMsg(AiKind.src, a.aiL(const {'en': 'saved by you, through the app\'s own save', 'mr': 'तुम्ही save केले; app च्या नेहमीच्या save मधून', 'hi': 'आपने save किया; app के अपने save से'})));
      _add(AiMsg(AiKind.bot, t));
      lastAnswer = t.split('\n').first;
      turns
        ..add(_user('I pressed Save.'))
        ..add(_model(t));
      onSaved?.call(r);
    } catch (e) {
      _drop(wait);
      final why = aiErr(e);
      _add(AiMsg(AiKind.err, why,
          small: a.aiL(const {
            'en': 'Nothing was saved. Say the corrected entry, or open it in the form.',
            'mr': 'काही save झाले नाही. दुरुस्त entry सांगा, किंवा form मध्ये उघडा.',
            'hi': 'कुछ save नहीं हुआ। सही entry बताएँ, या form में खोलें।',
          })));
      lastAnswer = why;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// A typed (or spoken) question. [onlyAi]: a question about an error message – always for the AI.
  Future<void> ask(String text0, {bool onlyAi = false}) async {
    final text = Assistant.westernDigits(text0).trim(); // (speech and Marathi keyboards write ८५११)
    if (text.isEmpty || busy) return;
    lastAnswer = '';
    lastLang = a.aiLangOf(text);
    busy = true;
    _sayCut(); // (3.61.0) a new question: what was being said stops
    a.lang = a.aiLangOf(text);
    final keep = turns.length, t0 = DateTime.now(), byApp = _byApp;
    _add(AiMsg(AiKind.me, text));
    turns.add(_user(text));
    final wait = _add(AiMsg(AiKind.wait, '…')), used = <String>[], kept = <Map>[]; // (3.61.0) kept: the notes it kept in this question
    void said(String t) => turns.add(_model(t));
    try {
      // 0. an entry is waiting for its yes / no; or these words are a command (or complete one that was half said)
      if (pending != null && kAiYes.hasMatch(text)) {
        _drop(wait);
        turns.removeLast();
        busy = false;
        await act('save');
        return;
      }
      if (pending != null && kAiNo.hasMatch(text)) {
        _drop(wait);
        turns.removeLast();
        busy = false;
        await act('cancel');
        return;
      }
      var cmd = onlyAi ? null : a.aiCommand(text);
      final part = partial;
      if (cmd == null && part != null && !onlyAi && a.aiLocal(text, false) == null) {
        final m2 = a.aiFindMach(text), rd = Assistant.aiReadings(text), pa = <String, Object?>{...part.a};
        final q2 = RegExp(r'(\d+(?:\.\d+)?)\s*(?:l\b|ltr|litres?|liters?|लिटर|लीटर)?', caseSensitive: false).firstMatch(text.replaceAllMapped(RegExp(r'(\d),(?=\d)'), (m) => m[1]!));
        if (m2 != null) pa['machinery'] = m2['id'];
        if (part.kind == 'diesel') {
          if (!(jsN(pa['litres']) > 0) && q2 != null && m2 == null) pa['litres'] = num.parse(q2[1]!);
        } else {
          if (rd['km'] != null) pa['close_km'] = rd['km'];
          if (rd['hr'] != null) pa['close_hr'] = rd['hr'];
          if (rd['km'] == null && rd['hr'] == null && q2 != null && m2 == null) {
            final mm = a.findMachine(pa['machinery']), u = '${mm?['unit'] ?? ''}';
            if (mm != null && u.contains('KM') && !u.contains('Hrs')) {
              pa['close_km'] = num.parse(q2[1]!);
            } else if (mm != null && u.contains('Hrs') && !u.contains('KM')) {
              pa['close_hr'] = num.parse(q2[1]!);
            }
          }
        }
        if (jsonEncode(pa) != jsonEncode(part.a)) cmd = AiCmd(part.kind, pa);
      }
      if (cmd != null) {
        _drop(wait);
        final r = await prepare(cmd.kind, cmd.a);
        said('${r['text'] ?? ''}');
        return;
      }
      // 1. the app understands it for sure
      final sure = onlyAi ? null : a.aiLocal(text, false);
      if (sure != null) {
        final t = await sure();
        _drop(wait);
        _add(AiMsg(AiKind.src, '⚡ $byApp'));
        _add(AiMsg(AiKind.bot, t));
        said(t);
        return;
      }
      // 2. the AI service
      if (!aiOn) throw AiStop('The assistant is not set up yet: the Admin has to put the AI key (ANTHROPIC_API_KEY – Claude) in the server\'s settings.');
      _waitSays(wait, '…'); // (3.61.0, update-186) no "Thinking…": its words come as they are written
      Map<String, Object?>? snap;
      try {
        snap = await a.snapshot();
      } catch (_) {
        snap = null;
      }
      final about = await a.about(text);
      final ctx = <String, Object?>{
        'page': {'tab': a.page, 'title': pageTitle, 'machineryPicked': a.picked, 'datePicked': a.page == 'log' ? a.aiDay : ''},
        ...?snap,
        if (about != null) 'aboutTheMachineryInTheQuestion': about,
      };
      for (var step = 0; step < 7; step++) {
        _sayStart();
        final r = await _step(ctx, wait);
        final parts = r['parts'] is List ? r['parts'] as List : const [];
        turns.add({'role': 'model', 'parts': r['parts']}); // exactly as it came (the service wants its own parts back)
        final calls = parts.whereType<Map>().where((p) => p['functionCall'] != null).toList();
        if (calls.isEmpty) {
          final t = parts.map((p) => p is Map && p['text'] != null ? '${p['text']}' : '').join().trim();
          _drop(wait);
          _sayFeed(t, true);
          final asOf = snap?['asOf'];
          _add(AiMsg(
            AiKind.src,
            used.isNotEmpty
                ? 'Looked up:'
                : a.aiL({'en': 'From the figures of ${asOf ?? 'now'}', 'mr': '${asOf ?? 'आत्ता'} च्या आकड्यांवरून', 'hi': '${asOf ?? 'अभी'} के आँकड़ों से'}),
            chips: [
              ...used,
              if (admin)
                '${r['model'] ?? ''} · ${js((DateTime.now().difference(t0).inMilliseconds / 100).round() / 10)} s${jsN(r['first']) > 0 ? ' · first words ${js((jsN(r['first']) / 100).round() / 10)} s' : ''}',
            ],
          ));
          _add(AiMsg(AiKind.bot, t.isEmpty ? '–' : t));
          // (3.61.0, update-186) what it just kept in its memory is shown, with "Take it out" – a note is never kept unseen (not kept
          // with the chat)
          for (final k in kept) {
            _add(AiMsg(AiKind.src, '${a.aiL(const {'en': 'Kept in memory: ', 'mr': 'Memory मध्ये ठेवले: ', 'hi': 'Memory में रखा: '})}${k['note'] ?? ''}',
                note: true, keptId: jsN(k['id']).toInt(), button: a.aiL(const {'en': 'Take it out', 'mr': 'काढा', 'hi': 'हटाएँ'})));
          }
          return;
        }
        // the look-ups it asks for run side by side (what it wrote before asking for them is not the answer: taken away, not said)
        _sayCut();
        _writingOff(wait);
        String nameOf(Map c) => '${(c['functionCall'] as Map)['name'] ?? ''}';
        Map argsOf(Map c) => (c['functionCall'] as Map)['args'] is Map ? (c['functionCall'] as Map)['args'] as Map : const {};
        _waitSays(wait, 'Looking up: ${calls.map((c) => Assistant.aiWhat(nameOf(c), argsOf(c))).join(', ')}…');
        final outs = await Future.wait(calls.map((c) async {
          final name = nameOf(c), args = argsOf(c);
          used.add(Assistant.aiWhat(name, args));
          Map<String, Object?> res;
          try {
            if (name == 'prepare_diesel_issue' || name == 'prepare_log_entry') {
              final p = await prepare(name == 'prepare_diesel_issue' ? 'diesel' : 'log', args.cast<String, Object?>());
              p.remove('text');
              res = p;
            } else {
              res = await a.run(name, args);
            }
          } catch (e) {
            res = {'error': aiErr(e)};
          }
          if (name == 'remember' && jsTrueS(res['remembered']) && !jsTrueS(res['already'])) kept.add(res);
          return <String, Object?>{'functionResponse': {'name': name, 'response': res}};
        }));
        turns.add({'role': 'user', 'parts': outs});
        _waitSays(wait, 'Writing the answer…');
      }
      throw AiStop('This question needed too many look-ups. Ask it in smaller parts.');
    } catch (e) {
      // 3. no answer from the AI service: the app answers as well as it can – an error is the last thing shown
      _drop(wait);
      while (turns.length > keep + 1) {
        turns.removeLast();
      }
      final why = aiErr(e), notSet = RegExp('not set up', caseSensitive: false).hasMatch(why);
      final short = notSet
          ? a.aiL(const {'en': 'The AI service is not set up', 'mr': 'AI सेवा अजून सुरू केलेली नाही', 'hi': 'AI सेवा अभी शुरू नहीं है'})
          : a.aiL(const {'en': 'The AI service did not answer', 'mr': 'AI सेवेने उत्तर दिले नाही', 'hi': 'AI सेवा ने जवाब नहीं दिया'});
      var done = false;
      try {
        final loose = a.aiLocal(text, true);
        if (loose != null) {
          final t = await loose();
          _add(AiMsg(AiKind.src, '⚡ $short – $byApp'));
          _add(AiMsg(AiKind.bot, t));
          said(t);
          done = true;
        } else {
          final fit = (await a.runGuide({'topic': text}))['pagesThatFit'] as List;
          final g = fit.isEmpty ? null : fit.first as Map;
          if (g != null) {
            final gd = (WebHelp.now ?? await WebHelp.load()).guideOf('${g['tab']}'), h = gd?[a.l];
            final t = '**${g['title']}**\n${h != null ? '${h[0]}\n\n${h[1]}' : g['whatItIsFor']}\n[[open:${g['tab']}|${g['title']}]]';
            _add(AiMsg(AiKind.src,
                '⚡ $short – ${a.aiL(const {'en': 'the app\'s guide that fits best', 'mr': 'app च्या मार्गदर्शनातले सर्वात जवळचे', 'hi': 'app की guide में सबसे नज़दीकी'})}'));
            _add(AiMsg(AiKind.bot, t));
            said(t);
            done = true;
          }
        }
      } catch (_) {
        done = false;
      }
      if (!done) {
        turns.removeLast();
        _add(AiMsg(AiKind.err, why,
            retry: text,
            small: a.aiL(const {
              'en': 'The ⚡ questions below are answered by the app itself and work now.',
              'mr': 'खालचे ⚡ प्रश्न app स्वतः उत्तरते; ते आत्ताही चालतात.',
              'hi': 'नीचे के ⚡ सवाल app खुद जवाब देता है; वे अभी भी चलते हैं।',
            })));
      } else if (admin && !notSet) {
        _add(AiMsg(AiKind.src, 'Admin: ${why.length > 110 ? why.substring(0, 110) : why}'));
      }
    } finally {
      a.lang = '';
      busy = false;
      final b = msgs.lastWhere((m) => m.kind == AiKind.bot || m.kind == AiKind.err || m.kind == AiKind.card || m.kind == AiKind.warn, orElse: () => AiMsg(AiKind.bot, ''));
      lastAnswer = b.say.isNotEmpty ? b.say : plain(b.text);
      notifyListeners();
      keep();
    }
  }

  /* ---------- (3.61.0, Mechanical update-186) LIVE, REMEMBERING, ITS CHATS KEPT – the web's aiStep / AI_SQ / aiKeep / aiChatOpen ---------- */

  /// One step of a question: word by word first – the words go into the waiting bubble as they come (about 15 pictures a second at
  /// most) and, in a talk, each finished sentence is said; the answer in one piece (getAiReply) is the way back: AI_NO_STREAM (for the
  /// rest of this conversation), the stream cut after some words ({t: 'err', cut: true} – asked once more), a line lost. The
  /// service's own refusal (busy before a word, no credit, a key it did not take …) is the answer, as getAiReply says it.
  Future<Map> _step(Map<String, Object?> ctx, AiMsg wait) async {
    final x = <String, dynamic>{'contents': turns, 'context': ctx}, f = a.stream;
    if (streamOn && f != null) {
      var text = '', first = 0;
      final t0 = DateTime.now();
      var drawn = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        final end = await f(x, (j) {
          if (j['t'] != 'd' || '${j['x'] ?? ''}'.isEmpty) return;
          final now = DateTime.now();
          if (first == 0) {
            first = max(1, now.difference(t0).inMilliseconds);
            wait.writing = true;
          }
          text += '${j['x']}';
          wait.text = text;
          _sayFeed(text, false);
          if (now.difference(drawn).inMilliseconds >= 66) {
            drawn = now;
            notifyListeners();
          }
        });
        if (end != null && end['t'] == 'end') {
          notifyListeners();
          return {...end, 'first': first};
        }
        // the service's own answer (busy before a word, no credit, a key it did not take …) – as getAiReply says it; cut after words
        // were already on the screen: asked once more in one piece
        if (end != null && end['t'] == 'err' && end['cut'] != true) {
          _writingOff(wait);
          _sayCut();
          throw AiStop('${end['e']}');
        }
      } on AiStop {
        rethrow;
      } catch (e) {
        if (aiErr(e).contains('AI_NO_STREAM')) streamOn = false;
      }
      _writingOff(wait);
      _sayCut();
    }
    final r0 = await a.call('getAiReply', [x]);
    return r0 is Map ? r0 : const {};
  }

  void _writingOff(AiMsg w) {
    if (!w.writing) return;
    w.writing = false;
    w.text = '…';
    notifyListeners();
  }

  void _sayStart() {
    _sayCut();
    say.start(talking && !hush && sayPart != null, lastLang.isNotEmpty ? lastLang : a.helpLang);
  }

  void _sayCut() {
    if (say.parts > 0) sayStop?.call();
    say.stop();
  }

  void _sayFeed(String text, bool last) {
    for (final p in say.feed(text, last)) {
      sayPart?.call(p, say.lang);
    }
  }

  /// The chat kept after every answer – as he saw it (his questions, the answers, what was looked up; only his, only this site).
  void keep() {
    final out = <Map<String, String>>[];
    var me = false;
    for (final m in msgs) {
      if (m.note) continue;
      if (m.kind == AiKind.me) {
        me = true;
        out.add({'r': 'me', 't': m.text});
      } else if (!me) {
        continue;
      } else if (m.kind == AiKind.bot) {
        out.add({'r': 'bot', 't': plain(m.text)});
      } else if (m.kind == AiKind.src) {
        out.add({'r': 'src', 't': [m.text, ...m.chips].join(' · ')});
      }
    }
    if (!out.any((m) => m['r'] == 'bot')) return;
    a.call('aiChatSave', [{'id': chatId, 'msgs': out}]).then((_) {}, onError: (_) {}); // (kept with the next answer)
  }

  /// His chats (History): the newest first – {on, chats: [{id, title, n, at}], msg}
  Future<Map> chatList() async {
    final r = await a.call('aiChats', const []);
    return r is Map ? r : const {};
  }

  /// A chat opened again: its questions and answers on the screen, the conversation goes on from them (the same chat).
  Future<void> openChat(String id) async {
    if (busy) return;
    final c0 = await a.call('aiChatGet', [{'id': id}]);
    if (busy) return; // (a question asked meanwhile: not mixed up)
    final c = c0 is Map ? c0 : const {};
    _sayCut();
    chatId = '${c['id'] ?? id}';
    turns.clear();
    msgs.clear();
    pending = null;
    partial = null;
    for (final m in (c['msgs'] is List ? c['msgs'] as List : const []).whereType<Map>()) {
      final t = '${m['t'] ?? ''}';
      if (m['r'] == 'me') {
        msgs.add(AiMsg(AiKind.me, t));
        turns.add(_user(t));
      } else if (m['r'] == 'bot') {
        msgs.add(AiMsg(AiKind.bot, t));
        if (turns.isNotEmpty) turns.add(_model(t));
      } else if (m['r'] == 'src') {
        final p = t.split(' · ');
        msgs.add(AiMsg(AiKind.src, p.first, chips: p.skip(1).toList()));
      }
    }
    final at = aiWhen('${c['at'] ?? ''}');
    msgs.add(AiMsg(
        AiKind.src,
        a.aiL({
          'en': 'Opened from History ($at) – ask on; the figures are looked up again.',
          'mr': 'History मधून उघडली ($at) – पुढे विचारा; आकडे पुन्हा पाहिले जातील.',
          'hi': 'History से खोली ($at) – आगे पूछें; आँकड़े फिर से देखे जाएँगे।',
        }),
        note: true));
    notifyListeners();
  }

  /// What the assistant remembers about him (Memory): {on, notes: [{id, note, at}], msg}
  Future<Map> memory() async {
    final r = await a.call('aiMemory', const []);
    return r is Map ? r : const {};
  }

  /// A note taken out of its memory (×).
  Future<void> forget(int id) async {
    await a.call('aiMemoryDel', [{'id': id}], save: true);
  }

  /// (3.61.0) "Take it out" under an answer: the note it just kept goes out of its memory; the line says so.
  Future<void> unkeep(AiMsg m) async {
    final id = m.keptId;
    if (id <= 0) return;
    m.keptId = -id;
    notifyListeners();
    try {
      await forget(id);
      m.keptId = 0;
      m.text = a.aiL(const {'en': 'Taken out of the memory.', 'mr': 'Memory मधून काढले.', 'hi': 'Memory से हटाया।'});
    } catch (_) {
      m.keptId = id;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// A message of the screen itself (the microphone not allowed …) – shown as an error.
  void note(String t) => _add(AiMsg(AiKind.err, t));

  /// "Ask again" of an error: the error goes, the words are asked again.
  Future<void> retry(AiMsg m) async {
    if (busy) return;
    msgs.remove(m);
    await ask(m.retry);
  }

  /// Admin: which model answers, how fast, and what the service says (to see why the assistant does not answer).
  Future<void> test() async {
    if (busy) return;
    busy = true;
    final wait = _add(AiMsg(AiKind.wait, 'Testing the AI service – a tiny question to each model…'));
    try {
      final d0 = await a.call('getAiCheck', const []), d = d0 is Map ? d0 : const {};
      _drop(wait);
      final tests = (d['tests'] is List ? d['tests'] as List : const []).whereType<Map>().toList();
      // (3.48.0, Mechanical update-167) the service (Claude / Gemini) said, and what to look at when no model answers
      final service = '${d['service'] ?? ''}';
      final body = d['key'] != true
          ? 'No key on the server (ANTHROPIC_API_KEY for Claude).'
          : '${d['listError'] ?? ''}'.isNotEmpty
              ? '${d['listError']}'
              : '${service.isNotEmpty ? 'Service: $service\n' : ''}'
                  '${'${d['fixedModel'] ?? ''}'.isNotEmpty ? 'Model fixed in the settings: ${d['fixedModel']}\n' : 'Models offered to this key, in the order they are asked:\n'}'
                  '${tests.map((t) => '${t['ok'] == true ? '✓ ' : '✗ '}${t['model']} – ${t['ok'] == true ? 'answered in ${js((jsN(t['ms']) / 100).round() / 10)} s' : '${jsTrueS(t['code']) ? t['code'] : 'no connection'}: ${t['said'] ?? ''}'}').join('\n')}\n'
                  '${tests.any((t) => t['ok'] == true) ? 'At least one model answers: typed questions can work now.' : service == 'Claude' ? 'No model answered. Check in Claude Console that the key is active and the account has credit (Billing).' : 'No model answered. If they all say "high demand" / 503 or 429, the free limit of this key is the cause: turn on billing in Google AI Studio.'}';
      _add(AiMsg(AiKind.bot, '**AI service test**\n$body'));
    } catch (e) {
      _drop(wait);
      _add(AiMsg(AiKind.err, aiErr(e)));
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

bool jsTrueS(Object? v) => !(v == null || v == false || v == '' || v == 0);

/// (3.61.0) a chat's own number, as the web's: C + the time in base 36 + 6 random letters / digits
String newChatId([Random? r]) {
  final rnd = r ?? Random();
  const al = '0123456789abcdefghijklmnopqrstuvwxyz';
  return 'C${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${List.generate(6, (_) => al[rnd.nextInt(36)]).join()}';
}

/// (3.61.0) a time of the server as the web shows it: dd-mm-yyyy, hh:mm (on this phone's clock)
String aiWhen(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

/// (3.61.0, Mechanical update-186 – the web's AI_SQ / aiSayFeed) THE ANSWER SAID WHILE IT IS WRITTEN (a talk): each finished sentence
/// once – a sentence ends at . ! ? । before a space, or at a new line (a number's point is no end; a page button is not said; the
/// answer's leading spaces do not count) – about the first 650 characters, then "The rest is on the screen." once.
class SayQueue {
  bool on = false, cut = false;
  int said = 0, n = 0, parts = 0;
  String lang = 'en';
  static const kRest = {'en': 'The rest is on the screen.', 'mr': 'बाकी screen वर आहे.', 'hi': 'बाकी screen पर है।'};

  void start(bool on0, String l) {
    on = on0;
    said = 0;
    n = 0;
    parts = 0;
    cut = false;
    lang = l;
  }

  void stop() {
    on = false;
    parts = 0;
  }

  /// the parts to say now (all of what is left when [last])
  List<String> feed(String text, bool last) {
    if (!on) return const [];
    // (the same text whether streamed or whole: its leading spaces and new lines left out first)
    final t = text.replaceFirst(RegExp(r'^\s+'), '').replaceAll(RegExp(r'\[\[open:[^\]]*\]\]'), '').replaceAll(RegExp(r'\[\[[^\]]*$'), '');
    var upto = t.length;
    if (!last) {
      final ms = RegExp(r'[.!?।](?=\s)|\n').allMatches(t).toList();
      upto = ms.isEmpty ? 0 : ms.last.end;
    }
    if (upto <= said) return const [];
    final part = t.substring(said, upto).trim();
    said = upto;
    if (part.isEmpty || cut) return const [];
    if (n > 0 && n + part.length > 650) {
      cut = true;
      parts++;
      return [kRest[lang] ?? kRest['en']!];
    }
    n += part.length;
    parts++;
    return [part];
  }
}
