/* ASK – THE ASSISTANT (3.15.0), the web's "Ask" panel in the app's own screen: the conversation, the ⚡ questions the app answers
 * itself, a prepared entry with Save / Open in the form / Cancel, "check the reading – Save anyway", the page buttons of an answer
 * (each opens the app's own screen for that page), "New chat", the Admin's "Test the AI service", the daily summary once a day
 * (a red dot on Home's "Ask the app"). The working is the web's own (core/assistant.dart, core/ai_chat.dart); nothing is saved without
 * his Save. Opened from Home (the web's Dashboard). */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as mt show Text;
import 'package:flutter/services.dart';

import '../core/ai_chat.dart';
import '../core/assistant.dart';
import '../core/kinds.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
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

/// His help language (the web's fixLang: Settings → language; Marathi when none is set).
String helpLangOf(Session s) {
  final l = s.pref('lang');
  return l == 'en' || l == 'hi' ? l : 'mr';
}

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
    ));
  }
  final c = _chat!;
  c.a
    ..today = s.today
    ..master = [for (final m in s.machines) m.m]
    ..locations = s.locations
    ..prefs = s.prefs
    ..helpLang = helpLangOf(s)
    ..tabs = assistantTabs(s);
  c.aiOn = s.aiOn;
  return c;
}

/// (tests) a new conversation next time.
void forgetChat() {
  _chat = null;
  _chatOf = '';
}

Future<void> openAssistant(BuildContext context, {required ValueChanged<String> entries}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssistantScreen(entries: entries)));

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, required this.entries});

  /// Opens the Entries tab of a diesel page (issue / inward / transfer) – the assistant closes first.
  final ValueChanged<String> entries;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  AiChat? _c;
  AiChat get chat => _c!;
  final input = TextEditingController();
  final scroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final s = SessionScope.read(context);
    final c = _c = chatFor(s);
    c.admin = s.admin;
    c.onForm = _form;
    c.onSaved = (r) {
      if (r['stock'] != null) s.setStock(r['stock']);
    };
    c.addListener(_changed);
    if (c.msgs.isEmpty) c.reset();
    // the daily summary that waits on the Ask button (once a day)
    if (s.briefDue.value) {
      s.briefDue.value = false;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) c.ready('brief');
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bottom());
  }

  @override
  void dispose() {
    _c?.removeListener(_changed);
    if (_c?.onForm == _form) _c!.onForm = null;
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
    await chat.ask(t);
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
        return _bubble(_rich(m.text), border: C.line, key: Key('ai-bot-$i'));
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
          ]),
        );
      case AiKind.wait:
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
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(key: const Key('ai-save'), onPressed: m.live && !chat.busy ? () => chat.act('save') : null, child: const Text('Save')),
              OutlinedButton(key: const Key('ai-form'), onPressed: m.live && !chat.busy ? () => chat.act('form') : null, child: mt.Text(w(const {'en': 'Open in the form', 'mr': 'Form मध्ये उघडा', 'hi': 'Form में खोलें'}))),
              TextButton(key: const Key('ai-cancel'), onPressed: m.live && !chat.busy ? () => chat.act('cancel') : null, child: mt.Text(w(const {'en': 'Cancel', 'mr': 'रद्द', 'hi': 'रद्द'}))),
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
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: ready.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  key: Key('ai-ready-${ready[i].id}'),
                  backgroundColor: C.amberSoft,
                  side: const BorderSide(color: Color(0xFFF2D49A)),
                  label: mt.Text('⚡ ${ready[i].q()}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF6B4300))),
                  onPressed: () => c.ready(ready[i].id),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 10, offset: const Offset(0, -3))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
