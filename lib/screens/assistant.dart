/* ASK – THE ASSISTANT (3.15.0), the web's "Ask" panel in the app's own screen: the conversation, the ⚡ questions the app answers
 * itself, a prepared entry with Save / Open in the form / Cancel, "check the reading – Save anyway", the page buttons of an answer
 * (each opens the app's own screen for that page), "New chat", the Admin's "Test the AI service", the daily summary once a day
 * (a red dot on Home's "Ask"). The working is the web's own (core/assistant.dart, core/ai_chat.dart); nothing is saved without
 * his Save. Opened from Home (the web's Dashboard). */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as mt show Text;
import 'package:flutter/services.dart';

import '../core/ai_chat.dart';
import '../core/api.dart' show ApiError;
import '../core/assistant.dart';
import '../core/kinds.dart';
import '../core/session.dart';
import '../core/voice.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/help.dart' show helpLangOf;
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'admin.dart' show ReadMeScreen;
import 'dashboard.dart' show openDashboard;
import 'forms.dart' show newEntry;
import 'home.dart' show reportsOf;
import 'logbook.dart' show LogForm;
import 'report_screen.dart' show openReport, reportOfPage;
import 'settings.dart' show SettingsScreen;
import 'start_page.dart' show openStartPage, startPagesFor;

/// The pages he can open (the web's aiTabs: the page's name and its title) – for the guide and the page buttons of an answer.
List<(String, String)> assistantTabs(Session s) {
  final out = <(String, String)>[];
  void add(String tab, String title) {
    if (!out.any((x) => x.$1 == tab)) out.add((tab, title));
  }

  for (final r in reportsOf(s).where((r) => r.$3 == 'dash')) {
    add(r.$3, r.$1);
  }
  for (final p in startPagesFor(s)) {
    add(p.$1, p.$2);
  }
  for (final r in reportsOf(s).where((r) => r.$3.startsWith('rp-'))) {
    add(r.$3, r.$1);
  }
  add('settings', 'My settings');
  if (s.admin) add('readme', 'Read Me');
  return out;
}

/// (3.16.0) The Entries tab of the app (the shell sets it): a page button of an answer for a diesel page opens it.
ValueChanged<String>? shellEntries;

/// (3.31.0) opens the Reports tab (set by the app's frame) – for the search of a page outside Home.
VoidCallback? shellReports;

AiChat? _chat;
String _chatOf = '';

/// The conversation of this person at this site – kept while the app is open (the web keeps its panel's conversation).
AiChat chatFor(Session s) {
  final key = '${identityHashCode(s)}|${s.email}|${s.site?.code ?? ''}';
  if (_chat == null || _chatOf != key) {
    _chatOf = key;
    _chat = AiChat(Assistant(
      call: (fn, args, {save = false}) => s.api.call(fn, args, save),
      today: s.today,
      master: const [],
      canEdit: s.canEdit,
      onSite: (m) => Machine(m).onSite(s.today),
      now: () => s.clock(),
      modLook: (module, name, args) => moduleLook(s, module, name, args),
      stream: (x, onLine) => s.api.aiStream(x, onLine), // (3.61.0, Mechanical update-186) the answer word by word
    ));
  }
  final c = _chat!;
  c.a
    ..today = s.today
    ..master = [for (final m in s.machines) m.m]
    ..locations = s.locations
    ..ownSources = s.ownSources('Diesel Issue') ? s.mySources('Diesel Issue') : null
    ..placeFuels = s.placeFuels      // (3.44.0)
    ..cardSite = s.cardSite      // (3.45.0)
    ..prefs = s.prefs
    ..helpLang = helpLangOf(s)
    ..tabs = assistantTabs(s);
  c.aiOn = s.aiOn;
  return c;
}

/// (3.59.0, Mechanical update-185) a look-up of the Store / Engineering of the site he is on, asked of that module with his own sign-in
/// there (the Store: api/work; Engineering: api/eng – action aiLook) – the web's aiModLook; no such module for him here: said so
Future<Map<String, dynamic>> moduleLook(Session s, String module, String name, Map args) async {
  final site = s.site, m = site?.module(module), label = module == 'store' ? 'the Store' : 'Engineering';
  if (site == null || m == null || m.url.isEmpty) throw ApiError('You have no access to $label at this site – the Super Admin gives it in the Portal.');
  final body = <String, dynamic>{'action': 'aiLook', 'name': name, 'args': args};
  return module == 'store' ? s.api.store(site.code, m.url, body, path: 'work') : s.api.eng(site.code, m.url, body);
}

/// (tests) a new conversation next time.
void forgetChat() {
  _chat = null;
  _chatOf = '';
}

/// The assistant; [question]: asked at once, of the AI service (a red message's "Ask the assistant about this").
Future<void> openAssistant(BuildContext context, {ValueChanged<String>? entries, String question = ''}) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => AssistantScreen(entries: entries ?? shellEntries ?? (_) {}, question: question)));

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, required this.entries, this.question = ''});

  /// Opens the Entries tab of a diesel page (issue / inward / transfer) – the assistant closes first.
  final ValueChanged<String> entries;

  /// Asked at once, of the AI service (the web's "Ask the assistant about this" of a help card).
  final String question;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  AiChat? _c;
  AiChat get chat => _c!;
  final input = TextEditingController();
  final scroll = ScrollController();

  // the talk (the web's aiLiveStart / aiListen): he speaks, it answers aloud, it listens again – until Stop, "थांब" or 3 silences
  bool live = false, saying = false;
  String liveState = ''; // hear · think · say
  int silent = 0, sayingMsg = -1;

  // (3.61.0, Mechanical update-186) the answer said while it is written: its parts one after another ([_sayGen] drops what is still
  // queued, [_pending] – not said yet); [_sayWait] ends when all is said – or when the speech is cut (the microphone pressed to speak,
  // New chat, a chat opened again, another question): the talk goes on – it listens again once nothing is asked or said ([_resume])
  Future<void> _sayChain = Future.value();
  int _sayGen = 0, _pending = 0;
  bool _rec = false; // listening now
  Completer<void>? _sayWait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final s = SessionScope.read(context);
    final c = _c = chatFor(s);
    c.admin = s.admin;
    c.sayPart = _part;
    c.sayStop = _partsStop;
    c.talking = false;
    c.onForm = _form;
    c.onSaved = (r) {
      if (r['stock'] != null) s.setStock(r['stock']);
    };
    c.addListener(_changed);
    if (c.msgs.isEmpty) c.reset();
    if (widget.question.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.ask(widget.question, onlyAi: true);
      });
    } else if (s.briefDue.value) {
      // the daily summary that waits on Ask (once a day) – after this first picture (the dot on Home goes then)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        s.briefDue.value = false;
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) c.ready('brief');
        });
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bottom());
  }

  @override
  void dispose() {
    if (live || saying) {
      live = false;
      stopListening();
      stopSaying();
    }
    _c?.removeListener(_changed);
    if (_c?.onForm == _form) _c!.onForm = null;
    if (_c?.sayPart == _part) {
      _c!
        ..sayPart = null
        ..sayStop = null
        ..talking = false;
    }
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _bottom());
  }

  void _bottom() {
    if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  Future<void> _send() async {
    final t = input.text;
    if (t.trim().isEmpty || chat.busy) return;
    input.clear();
    HapticFeedback.selectionClick();
    // (3.61.0) a question typed during a talk: said while it is written, as a spoken one; after its answer the talk listens again
    final talk = live;
    chat.talking = talk && SessionScope.read(context).prefs['voiceOut'] != false;
    await chat.ask(t);
    chat.talking = false;
    if (!talk || !mounted || !live) return;
    chat.hush = false;
    await _saidThen();
    _resume();
  }

  String get _help => chat.a.helpLang;

  /// (3.61.0, Mechanical update-186) History: his chats (only his, this site) – one opened again goes on.
  Future<void> _history() async {
    if (chat.busy) return;
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => AiHistoryScreen(chat: chat)));
    if (id == null || !mounted) return;
    try {
      await chat.openChat(id);
    } catch (e) {
      chat.note(aiErr(e));
    }
  }

  /// (3.61.0) "Take it out" of a note it just kept.
  Future<void> _unkeep(AiMsg m) async {
    try {
      await chat.unkeep(m);
    } catch (e) {
      if (mounted) toast(context, aiErr(e), bad: true);
    }
  }

  /// (3.61.0) Memory: what the assistant remembers about him – × takes a note out.
  Future<void> _memory() async {
    if (chat.busy) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AiMemoryScreen(chat: chat)));
  }

  /// 🔊 of an answer: said aloud in its language (Devanagari: Marathi – Hindi when his help is Hindi); pressed again: stops.
  Future<void> _sayMsg(int i) async {
    if (saying) {
      await stopSaying();
      if (mounted) setState(() => saying = false);
      if (sayingMsg == i) return;
    }
    final t = chat.plain(chat.msgs[i].text);
    setState(() {
      saying = true;
      sayingMsg = i;
    });
    await sayAloud(t, RegExp(r'[\u0900-\u097F]').hasMatch(t) ? (_help == 'hi' ? 'hi' : 'mr') : 'en');
    if (mounted && sayingMsg == i) setState(() => saying = false);
  }

  void _liveShow(String st) {
    if (mounted) setState(() => liveState = st);
  }

  /// A finished sentence of the answer being written: said after the ones before it.
  void _part(String words, String lang) {
    final g = _sayGen;
    _pending++;
    if (live) {
      saying = true;
      _liveShow('say');
    }
    _sayChain = _sayChain.then((_) async {
      if (g != _sayGen) return;
      try {
        await sayAloud(words, lang);
      } catch (_) {/* a phone that says nothing: the answer is on the screen */}
      if (g == _sayGen) _pending--;
    });
  }

  /// What is being said (and what is queued) stops; what waited for its end goes on.
  void _partsStop() {
    _sayGen++;
    _pending = 0;
    _sayChain = Future.value();
    stopSaying();
    final w = _sayWait;
    if (w != null && !w.isCompleted) w.complete();
    if (mounted && live && saying) setState(() => saying = false);
  }

  /// Until all that is being said is said – or the speech is cut.
  Future<void> _untilSaid() {
    if (_pending == 0) return Future.value();
    final c = _sayWait = Completer<void>();
    _sayChain.whenComplete(() {
      if (!c.isCompleted) c.complete();
    }).ignore();
    return c.future;
  }

  /// What is still to be said of the answer, then on.
  Future<void> _saidThen() async {
    await _untilSaid();
    if (mounted && saying) setState(() => saying = false);
  }

  /// (3.61.0) a talk goes on: it listens again when nothing is being asked or said.
  void _resume() {
    if (!mounted || !live || chat.busy || saying || _rec) return;
    _liveShow('hear');
    Future.delayed(const Duration(milliseconds: 300), _listen);
  }

  /// (3.61.0) he speaks while it speaks: it stops at once and listens (the talk goes on); while the question is still being answered,
  /// nothing more of it is said ("Finding the answer…") – it listens once the answer is there.
  void _interrupt() {
    HapticFeedback.selectionClick();
    chat.hush = chat.busy;
    chat.say.stop();
    _partsStop();
    setState(() => saying = false);
    if (chat.hush) {
      _liveShow('think');
    } else {
      Future.delayed(const Duration(milliseconds: 150), _resume);
    }
  }

  Future<void> _liveStart() async {
    if (live) return _liveStop();
    if (chat.busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      live = true;
      silent = 0;
    });
    await _listen();
  }

  Future<void> _liveStop([String msg = '']) async {
    final was = live || saying;
    chat.talking = false;
    chat.hush = false;
    chat.say.stop();
    _sayGen++;
    _pending = 0;
    _sayChain = Future.value();
    final w = _sayWait;
    if (w != null && !w.isCompleted) w.complete();
    setState(() {
      live = false;
      saying = false;
      liveState = '';
    });
    if (was) {
      await stopListening();
      await stopSaying();
    }
    if (msg.isNotEmpty) chat.note(msg);
  }

  Future<void> _listen() async {
    if (!mounted || !live || chat.busy || saying || _rec) return;
    _liveShow('hear');
    String said;
    _rec = true;
    try {
      said = (await listenOnce(_help, (w) => input.text = w)).trim();
    } on VoiceError catch (e) {
      _rec = false;
      final a = chat.a;
      await _liveStop(e.code == 'mic'
          ? a.aiL(const {
              'en': 'The microphone is not allowed for this app. Allow it in the phone\'s Settings → Apps → RCL ERP → Permissions, and press the microphone again.',
              'mr': 'या app ला microphone ची परवानगी नाही. फोनच्या Settings → Apps → RCL ERP → Permissions मध्ये microphone ला परवानगी द्या आणि mic बटण पुन्हा दाबा.',
              'hi': 'इस app को microphone की अनुमति नहीं है। फ़ोन की Settings → Apps → RCL ERP → Permissions में microphone की अनुमति दें और mic बटन फिर दबाएँ।',
            })
          : a.aiL(const {'en': 'This phone cannot listen (it has no speech recognition).', 'mr': 'हा फोन ऐकू शकत नाही (त्यावर speech recognition नाही).', 'hi': 'यह फ़ोन सुन नहीं सकता (उस पर speech recognition नहीं है)।'}));
      return;
    } finally {
      _rec = false;
    }
    input.clear();
    if (!mounted || !live) return;
    if (chat.busy) return; // (a question typed meanwhile: after its answer the talk listens again)
    if (said.isEmpty) {
      silent++;
      if (silent >= 3) return _liveStop();
      await Future.delayed(const Duration(milliseconds: 250));
      return _listen();
    }
    silent = 0;
    if (kAiStopWords.hasMatch(said)) return _liveStop();
    _liveShow('think');
    final s = SessionScope.read(context);
    chat.talking = s.prefs['voiceOut'] != false; // (3.61.0) each sentence said while the answer is written
    await chat.ask(said);
    chat.talking = false;
    if (!mounted || !live) return;
    if (chat.hush) {
      // he pressed the microphone while it spoke: listening now (nothing more of this answer is said)
      chat.hush = false;
      chat.say.stop();
      _partsStop();
    } else if (s.prefs['voiceOut'] != false) {
      // an answer of the app itself, or one that came in one piece: said now, as before (else: said while it was written)
      if (chat.say.parts == 0) _part(chat.lastAnswer, chat.lastLang.isNotEmpty ? chat.lastLang : _help);
      if (_pending > 0) {
        saying = true;
        _liveShow('say');
      }
      await _saidThen();
    }
    _resume();
  }


  /// "Open in the form": the app's own form with the entry in it (the web puts the date, shift, machinery and litres in the form).
  Future<void> _form(AiDraft d) async {
    if (!mounted) return;
    if (d.kind == 'diesel') {
      await newEntry(context, kKinds.firstWhere((k) => k.key == 'issue'), no: '${d.data['no']}', preset: {'date': d.data['date'], 'shift': d.data['shift'], 'qty': d.data['qty']});
    } else {
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LogForm(date: '${d.data['date'] ?? ''}', no: '${d.data['no'] ?? ''}')));
    }
  }

  /// A page button of an answer: the app's own screen for that page of the web.
  Future<void> _go(String tab) async {
    final s = SessionScope.read(context);
    HapticFeedback.selectionClick();
    void entries(String k) {
      Navigator.of(context).pop();
      widget.entries(k);
    }

    switch (tab) {
      case 'dash':
        await openDashboard(context);
      case 'settings':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      case 'readme':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReadMeScreen()));
      default:
        final d = tab.startsWith('rp-') ? reportOfPage(tab) : null;
        if (d != null) {
          await openReport(context, d);
        } else {
          await openStartPage(context, s, tab, entries: entries);
        }
    }
  }

  bool _open(String tab) => chat.a.tabs.any((t) => t.$1 == tab);

  /// An answer as it is shown (the web's aiHtml): **bold**, and [[open:page|Label]] as a button to that page when he can open it.
  Widget _rich(String text, {Color color = C.ink}) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*([^*\n]+)\*\*|\[\[open:([a-z0-9-]+)\|([^\]\n]{1,60})\]\]', caseSensitive: false);
    final t = text.trim();
    var at = 0;
    for (final m in re.allMatches(t)) {
      if (m.start > at) spans.add(TextSpan(text: t.substring(at, m.start)));
      if (m[1] != null) {
        spans.add(TextSpan(text: m[1], style: const TextStyle(fontWeight: FontWeight.w700)));
      } else {
        final tab = m[2]!.toLowerCase(), label = m[3]!;
        spans.add(_open(tab)
            ? WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, right: 6),
                  child: Material(
                    color: C.greenSoft,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      key: Key('ai-go-$tab'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _go(tab),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        child: mt.Text('$label →', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.greenDark)),
                      ),
                    ),
                  ),
                ),
              )
            : TextSpan(text: label));
      }
      at = m.end;
    }
    if (at < t.length) spans.add(TextSpan(text: t.substring(at)));
    return mt.Text.rich(TextSpan(children: spans), style: TextStyle(fontSize: 15.5, height: 1.42, color: color));
  }

  Widget _bubble(Widget child, {Color color = Colors.white, Color? border, bool right = false, Key? key}) => Align(
        key: key,
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (right ? .82 : .92)),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            color: color,
            border: border == null ? null : Border.all(color: border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(right ? 18 : 6),
              bottomRight: Radius.circular(right ? 6 : 18),
            ),
            boxShadow: right ? null : softShadow(.04),
          ),
          child: child,
        ),
      );

  Widget _msg(int i) {
    final m = chat.msgs[i], a = chat.a;
    switch (m.kind) {
      case AiKind.me:
        return _bubble(mt.Text(m.text, style: const TextStyle(fontSize: 15.5, color: Colors.white, height: 1.35)), color: C.green, right: true, key: Key('ai-me-$i'));
      case AiKind.bot:
        return _bubble(
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _rich(m.text)),
            SizedBox(
              width: 34,
              height: 30,
              child: IconButton(
                key: Key('ai-say-$i'),
                padding: EdgeInsets.zero,
                iconSize: 20,
                tooltip: tr('Listen'),
                onPressed: () => _sayMsg(i),
                icon: Icon(saying && sayingMsg == i ? Icons.stop_circle_outlined : Icons.volume_up_rounded, color: C.faint),
              ),
            ),
          ]),
          border: C.line,
          key: Key('ai-bot-$i'),
        );
      case AiKind.src:
        return Padding(
          key: Key('ai-src-$i'),
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            mt.Text(m.text, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
            for (final c in m.chips)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: C.slateSoft, borderRadius: BorderRadius.circular(10)),
                child: mt.Text(c, style: const TextStyle(fontSize: 12, color: C.slate)),
              ),
            // (3.61.0, Mechanical update-186) a note it just kept in its memory: taken out at once if he does not want it
            if (m.keptId != 0)
              OutlinedButton(
                key: Key('ai-unkeep-${m.keptId.abs()}'),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 12), foregroundColor: C.red),
                onPressed: m.keptId > 0 ? () => _unkeep(m) : null,
                child: mt.Text(m.button, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
          ]),
        );
      case AiKind.wait:
        // (3.61.0) the answer being written into it, word by word
        if (m.writing) {
          return _bubble(_rich('${m.text} ▍'), border: C.line, key: const Key('ai-writing'));
        }
        return Padding(
          key: const Key('ai-wait'),
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 12),
          child: Row(children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2)),
            const SizedBox(width: 10),
            Expanded(child: Text(m.text, style: const TextStyle(fontSize: 14, color: C.muted))),
          ]),
        );
      case AiKind.err:
        return _bubble(
          key: Key('ai-err-$i'),
          color: C.redSoft,
          border: const Color(0xFFF5C2BE),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            mt.Text(m.text, style: const TextStyle(fontSize: 15, color: C.red, fontWeight: FontWeight.w600, height: 1.35)),
            if (m.retry.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OutlinedButton(key: const Key('ai-retry'), onPressed: chat.busy ? null : () => chat.retry(m), child: const Text('Ask again')),
              ),
            if (m.small.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: mt.Text(m.small, style: const TextStyle(fontSize: 12.5, color: C.muted))),
          ]),
        );
      case AiKind.card:
        final d = m.draft!;
        String w(Map<String, String> o) => a.aiL(o);
        return Container(
          key: Key('ai-card-$i'),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: m.live ? C.green : C.line, width: m.live ? 1.6 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            mt.Text.rich(TextSpan(children: [
              TextSpan(text: d.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' – ${w(const {'en': 'check, then Save', 'mr': 'तपासा, मग Save', 'hi': 'जाँचें, फिर Save'})}'),
            ]), style: const TextStyle(fontSize: 15.5, color: C.ink)),
            const SizedBox(height: 8),
            for (final l in d.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 92, child: mt.Text(l.$1, style: const TextStyle(fontSize: 13.5, color: C.muted))),
                  Expanded(child: mt.Text(l.$2, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
                ]),
              ),
            for (final n in d.notes)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(10)),
                child: mt.Text(n, style: const TextStyle(fontSize: 13.5, color: Color(0xFF7A4A00))),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(key: const Key('ai-save'), onPressed: m.live && !chat.busy ? () => chat.act('save') : null, child: const Text('Save')),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('ai-form'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: m.live && !chat.busy ? () => chat.act('form') : null,
                  child: mt.Text(w(const {'en': 'Open in the form', 'mr': 'Form मध्ये उघडा', 'hi': 'Form में खोलें'}), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  key: const Key('ai-cancel'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: m.live && !chat.busy ? () => chat.act('cancel') : null,
                  child: mt.Text(w(const {'en': 'Cancel', 'mr': 'रद्द', 'hi': 'रद्द'})),
                ),
              ),
            ]),
          ]),
        );
      case AiKind.warn:
        String ww(Map<String, String> o) => a.aiL(o);
        return _bubble(
          key: Key('ai-warn-$i'),
          color: C.amberSoft,
          border: const Color(0xFFF2D49A),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            mt.Text(m.text, style: const TextStyle(fontSize: 15, height: 1.35, color: Color(0xFF7A4A00), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton(key: const Key('ai-force'), onPressed: m.live && !chat.busy ? () => chat.act('save', force: true) : null, child: mt.Text(ww(const {'en': 'Save anyway', 'mr': 'तरीही Save', 'hi': 'फिर भी Save'}))),
              TextButton(key: const Key('ai-warn-cancel'), onPressed: m.live && !chat.busy ? () => chat.act('cancel') : null, child: mt.Text(ww(const {'en': 'Cancel', 'mr': 'रद्द', 'hi': 'रद्द'}))),
            ]),
          ]),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = chat, s = SessionScope.of(context);
    final ready = c.busy ? const <AiReady>[] : c.a.readyFor();
    return Scaffold(
      appBar: AppBar(
        title: const TwoLang('Assistant', 'सहाय्यक', size: 20, weight: FontWeight.w700),
        actions: [
          // (3.61.0, Mechanical update-186) his chats and what it remembers about him – only his, only this site
          IconButton(key: const Key('ai-hist'), tooltip: tr('History'), onPressed: c.busy ? null : _history, icon: const Icon(Icons.history_rounded)),
          IconButton(key: const Key('ai-mem'), tooltip: tr('Memory'), onPressed: c.busy ? null : _memory, icon: const Icon(Icons.psychology_alt_outlined)),
          TextButton.icon(key: const Key('ai-new'), onPressed: c.busy ? null : () => c.reset(), icon: const Icon(Icons.add_comment_outlined, size: 20), label: const Text('New chat')),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              key: const Key('ai-list'),
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: c.msgs.length + 1,
              itemBuilder: (_, i) => i == 0
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('answers from this app\'s data only', style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600)),
                        Text(
                            '⚡ questions are answered by the app itself. A typed question and the figures it needs go to the AI service. The assistant saves nothing by itself – an entry it prepares is saved only when you press Save.',
                            style: const TextStyle(fontSize: 12, color: C.faint)),
                      ]),
                    )
                  : _msg(i - 1),
            ),
          ),
          if (ready.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView.separated(
                key: const Key('ai-ready'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: ready.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  key: Key('ai-ready-${ready[i].id}'),
                  backgroundColor: C.amberSoft,
                  side: const BorderSide(color: Color(0xFFF2D49A)),
                  label: mt.Text('⚡ ${ready[i].q()}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF6B4300))),
                  onPressed: () async {
                    await c.ready(ready[i].id);
                    _resume(); // (3.61.0) in a talk: it listens again once nothing is asked or said
                  },
                ),
              ),
            ),
          if (live)
            Container(
              key: const Key('ai-live'),
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(color: liveState == 'say' ? C.blueSoft : C.greenSoft, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(liveState == 'say' ? Icons.volume_up_rounded : liveState == 'think' ? Icons.hourglass_top_rounded : Icons.mic_rounded, color: liveState == 'say' ? C.blue : C.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    key: const Key('ai-live-text'),
                    onTap: liveState == 'say' && saying ? _interrupt : null, // (3.61.0) a tap while it speaks: it listens now
                    child: mt.Text(
                      c.a.aiL(liveState == 'say'
                          ? const {
                              'en': 'Speaking… tap here or 🎙 to speak now · Stop ends the talk',
                              'mr': 'बोलतो आहे… आत्ता बोलायला इथे किंवा 🎙 दाबा · Stop ने बंद',
                              'hi': 'बोल रहा हूँ… अभी बोलने के लिए यहाँ या 🎙 दबाएँ · Stop से बंद',
                            }
                          : liveState == 'think'
                              ? const {'en': 'Finding the answer…', 'mr': 'उत्तर शोधतो आहे…', 'hi': 'जवाब ढूँढ रहा हूँ…'}
                              : const {'en': 'Listening… speak now', 'mr': 'ऐकतो आहे… बोला', 'hi': 'सुन रहा हूँ… बोलिए'}),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
                TextButton(key: const Key('ai-live-stop'), onPressed: () => _liveStop(), child: const Text('Stop')),
              ]),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 10, offset: const Offset(0, -3))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                // the talk: he speaks, it answers aloud (the web's microphone button)
                IconButton.filledTonal(
                  key: const Key('ai-mic'),
                  tooltip: tr('Talk'),
                  style: IconButton.styleFrom(backgroundColor: live ? C.green : C.greenSoft, foregroundColor: live ? Colors.white : C.green, minimumSize: const Size(48, 48)),
                  onPressed: live && saying ? _interrupt : (c.busy && !live ? null : _liveStart), // (3.61.0) while it speaks: he speaks
                  icon: Icon(live ? Icons.mic_rounded : Icons.mic_none_rounded),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    key: const Key('ai-in'),
                    controller: input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(hintText: tr('Ask anything about this app…'), counterText: '', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(key: const Key('ai-send'), onPressed: c.busy ? null : _send, style: FilledButton.styleFrom(minimumSize: const Size(72, 50)), child: const Text('Ask')),
              ]),
              if (s.admin && c.aiOn)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(key: const Key('ai-test'), onPressed: c.busy ? null : c.test, child: const Text('Test the AI service', style: TextStyle(fontSize: 13))),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}


/* ======================== (3.61.0, Mechanical update-186) HISTORY AND MEMORY – only his, only this site ======================== */
const _kOnly = {'en': 'Only you see this – and only at this site.', 'mr': 'हे फक्त तुम्हालाच दिसते – आणि फक्त या site चे.', 'hi': 'यह सिर्फ़ आपको दिखता है – और सिर्फ़ इस site का।'};

/// His chats with the assistant, the newest first – a tap opens one again (its id is given back).
class AiHistoryScreen extends StatefulWidget {
  const AiHistoryScreen({super.key, required this.chat});
  final AiChat chat;
  @override
  State<AiHistoryScreen> createState() => _AiHistoryScreenState();
}

class _AiHistoryScreenState extends State<AiHistoryScreen> {
  Map? r;
  String err = '';

  @override
  void initState() {
    super.initState();
    widget.chat.chatList().then((v) {
      if (mounted) setState(() => r = v);
    }, onError: (Object e) {
      if (mounted) setState(() => err = aiErr(e));
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.chat.a, chats = (r?['chats'] is List ? r!['chats'] as List : const []).whereType<Map>().toList();
    return Scaffold(
      appBar: AppBar(title: mt.Text(a.aiL(const {'en': 'Your chats', 'mr': 'तुमच्या chats', 'hi': 'आपकी chats'}))),
      body: ListView(key: const Key('ai-hist-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        mt.Text(a.aiL(_kOnly), style: const TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 10),
        if (err.isNotEmpty) mt.Text(err, style: const TextStyle(color: C.red, fontWeight: FontWeight.w600)),
        if (r == null && err.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        if (r != null && r!['on'] == false) mt.Text('${r!['msg'] ?? ''}', key: const Key('ai-hist-off'), style: const TextStyle(fontSize: 14, color: C.amber, fontWeight: FontWeight.w600)),
        if (r != null && r!['on'] != false && chats.isEmpty) mt.Text(a.aiL(const {'en': 'No chat kept yet.', 'mr': 'अजून कोणतीही chat नाही.', 'hi': 'अभी कोई chat नहीं।'}), style: const TextStyle(color: C.muted)),
        for (final (i, c) in chats.indexed)
          Card(
            key: Key('ai-chat-$i'),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: mt.Text('${c['title'] ?? ''}'.isEmpty ? '–' : '${c['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: mt.Text('${aiWhen('${c['at'] ?? ''}')} · ${c['n'] ?? 0} ${a.aiL(const {'en': 'question(s)', 'mr': 'प्रश्न', 'hi': 'सवाल'})}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pop('${c['id']}'),
            ),
          ),
      ]),
    );
  }
}

/// What the assistant remembers about him – × takes a note out (from the database too).
class AiMemoryScreen extends StatefulWidget {
  const AiMemoryScreen({super.key, required this.chat});
  final AiChat chat;
  @override
  State<AiMemoryScreen> createState() => _AiMemoryScreenState();
}

class _AiMemoryScreenState extends State<AiMemoryScreen> {
  Map? r;
  String err = '';
  int busyId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await widget.chat.memory();
      if (mounted) setState(() => r = v);
    } catch (e) {
      if (mounted) setState(() => err = aiErr(e));
    }
  }

  Future<void> _forget(int id) async {
    setState(() => busyId = id);
    try {
      await widget.chat.forget(id);
      await _load();
    } catch (e) {
      if (mounted) setState(() => err = aiErr(e));
    } finally {
      if (mounted) setState(() => busyId = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.chat.a, notes = (r?['notes'] is List ? r!['notes'] as List : const []).whereType<Map>().toList();
    return Scaffold(
      appBar: AppBar(title: mt.Text(a.aiL(const {'en': 'What the assistant remembers about you', 'mr': 'Assistant ला तुमच्याबद्दल काय लक्षात आहे', 'hi': 'Assistant को आपके बारे में क्या याद है'}), maxLines: 2)),
      body: ListView(key: const Key('ai-mem-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        mt.Text(a.aiL(_kOnly), style: const TextStyle(fontSize: 13, color: C.muted)),
        mt.Text(a.aiL(const {'en': 'Tell it "remember …" to add a note; × takes one out.', 'mr': 'नवीन नोंदीसाठी "लक्षात ठेव …" असे सांगा; × ने काढा.', 'hi': 'नई बात के लिए "याद रखो …" कहें; × से हटाएँ।'}), style: const TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 10),
        if (err.isNotEmpty) mt.Text(err, style: const TextStyle(color: C.red, fontWeight: FontWeight.w600)),
        if (r == null && err.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        if (r != null && r!['on'] == false) mt.Text('${r!['msg'] ?? ''}', key: const Key('ai-mem-off'), style: const TextStyle(fontSize: 14, color: C.amber, fontWeight: FontWeight.w600)),
        if (r != null && r!['on'] != false && notes.isEmpty) mt.Text(a.aiL(const {'en': 'Nothing yet.', 'mr': 'अजून काही नाही.', 'hi': 'अभी कुछ नहीं।'}), key: const Key('ai-mem-none'), style: const TextStyle(color: C.muted)),
        for (final n in notes)
          Card(
            key: Key('ai-note-${n['id']}'),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: mt.Text('${n['note'] ?? ''}', style: const TextStyle(fontSize: 15)),
              trailing: IconButton(
                key: Key('ai-forget-${n['id']}'),
                tooltip: tr('Take this out'),
                onPressed: busyId != 0 ? null : () => _forget((n['id'] as num).toInt()),
                icon: const Icon(Icons.close_rounded, color: C.red),
              ),
            ),
          ),
      ]),
    );
  }
}
