/* HELP FOR EVERY ERROR AND EVERY PAGE (3.16.0) – the web's own help in the app's own sheets (asked 02-10-2026 on the web: "the
 * app must explain everything itself … in English, मराठी and हिंदी"; the words: core/web_help.dart, taken out of the web page):
 *   – every red message (a toast, a "Nothing saved" box, a refused entry) has **Help**: what is wrong and what to do, the first
 *     three rules of the web that know the message (else the general one), and "Ask the assistant about this" when the AI
 *     service is set up – the web's help card (fixCard / fixHtml);
 *   – the **?** of a page: what the page is for and what the app checks / how its figures come (the web's guide, PAGE_GUIDE /
 *     REPORT_GUIDE);
 *   – English / मराठी / हिंदी in each, the choice kept while the app is open (the web keeps it on the device). */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as mt show Text;

import '../core/session.dart';
import '../core/web_help.dart';
import '../screens/assistant.dart' show assistantTabs, openAssistant;
import 'scope.dart';
import 't.dart';
import 'theme.dart';

/// The help's language picked in a help sheet (null: his settings' language).
String? helpPicked;

/// The language of the help and of the assistant (the web's fixLang): picked in a help sheet, else his settings' language –
/// Marathi when none is set.
String helpLangOf(Session s) {
  final p = helpPicked;
  if (p != null) return p;
  final l = s.pref('lang');
  return l == 'en' || l == 'hi' ? l : 'mr';
}

/// The pages on the screen with a "?" (the last one is the page he is on) – for "Ask the assistant about this".
final _pages = <String>[];
String get pageNow => _pages.isEmpty ? 'dash' : _pages.last;

/// The "?" of a page (the web's page guide): what it is for, and what the app checks.
class GuideButton extends StatefulWidget {
  const GuideButton(this.tab, {super.key, this.color});

  /// The web's name of the page (diesel, log, master, rp-ledger …).
  final String tab;
  final Color? color;
  @override
  State<GuideButton> createState() => _GuideButtonState();
}

class _GuideButtonState extends State<GuideButton> {
  @override
  void initState() {
    super.initState();
    _pages.add(widget.tab);
  }

  @override
  void dispose() {
    final i = _pages.lastIndexOf(widget.tab);
    if (i >= 0) _pages.removeAt(i);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
        key: Key('guide-${widget.tab}'),
        tooltip: tr('About this page'),
        icon: Icon(Icons.help_outline_rounded, color: widget.color),
        onPressed: () => showGuide(context, widget.tab),
      );
}

const _langs = [('en', 'English'), ('mr', 'मराठी'), ('hi', 'हिंदी')];

/// What the page is for (the web's guideShow).
Future<void> showGuide(BuildContext context, String tab) async {
  final help = await WebHelp.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _HelpSheet(help: help, tab: tab));
}

/// Help for a red message (the web's fixCard): what is wrong and what to do; "Ask the assistant about this".
Future<void> showFixHelp(BuildContext context, String msg) async {
  final help = await WebHelp.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _HelpSheet(help: help, msg: msg));
}

/// A red message's "Help" link (in a box or a dialog).
class FixHelpLink extends StatelessWidget {
  const FixHelpLink(this.msg, {super.key, this.color = C.red});
  final String msg;
  final Color color;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const Key('fix-help'),
          style: TextButton.styleFrom(foregroundColor: color, minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 10), visualDensity: VisualDensity.compact),
          onPressed: () => showFixHelp(context, msg),
          icon: const Icon(Icons.help_outline_rounded, size: 18),
          label: const Text('Help'),
        ),
      );
}

/// The web's rule for a box that reports something refused: help for "Nothing … / Not … / Fix …" and for a question that says
/// "anyway", "has entries" or "Check the".
bool askNeedsHelp(String words) => RegExp(r'anyway|has entries|Check the', caseSensitive: false).hasMatch(words);

class _HelpSheet extends StatefulWidget {
  const _HelpSheet({required this.help, this.tab = '', this.msg = ''});
  final WebHelp help;
  final String tab, msg;
  @override
  State<_HelpSheet> createState() => _HelpSheetState();
}

class _HelpSheetState extends State<_HelpSheet> {
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), l = helpLangOf(s), h = widget.help;
    String w(Map<String, Map<String, String>> m, String k) => m[k]?[l] ?? m[k]?['en'] ?? k;
    final guide = widget.msg.isEmpty;
    final g = guide ? h.guideOf(widget.tab) : null;
    final rules = guide ? const <HelpText>[] : h.fixRules(widget.msg);
    Widget para(String head, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: mt.Text.rich(
            TextSpan(children: [TextSpan(text: '$head: ', style: const TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: body)]),
            style: const TextStyle(fontSize: 15.5, height: 1.45, color: C.ink),
          ),
        );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .82),
        child: ListView(key: Key(guide ? 'guide-sheet' : 'fix-sheet'), shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Row(children: [
            Icon(guide ? Icons.menu_book_rounded : Icons.support_rounded, color: C.green),
            const SizedBox(width: 10),
            Expanded(child: mt.Text(guide ? w(h.guideW, 'head') : w(h.fixW, 'head'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final x in _langs)
              ChoiceChip(
                key: Key('help-lang-${x.$1}'),
                label: mt.Text(x.$2),
                selected: x.$1 == l,
                onSelected: (_) => setState(() => helpPicked = x.$1),
              ),
          ]),
          const SizedBox(height: 14),
          if (!guide)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(14)),
              child: mt.Text(widget.msg.length > 600 ? widget.msg.substring(0, 600) : widget.msg, style: const TextStyle(fontSize: 14, color: C.red, fontWeight: FontWeight.w600, height: 1.35)),
            ),
          if (guide && g == null)
            mt.Text(const {'en': 'This page has no guide.', 'mr': 'या page चे मार्गदर्शन नाही.', 'hi': 'इस page की guide नहीं है।'}[l]!, style: const TextStyle(fontSize: 15.5, color: C.muted)),
          if (guide && g != null) ...[
            para(w(h.guideW, 'what'), (g[l] ?? g['en']!)[0]),
            para(w(h.guideW, 'how'), (g[l] ?? g['en']!)[1]),
          ],
          for (final r in rules)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                para(w(h.fixW, 'what'), (r[l] ?? r['en']!)[0]),
                para(w(h.fixW, 'todo'), (r[l] ?? r['en']!)[1]),
              ]),
            ),
          if (!guide && s.aiOn)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                key: const Key('fix-ai'),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: mt.Text(const {'en': 'Ask the assistant about this', 'mr': 'याबद्दल Assistant ला विचारा', 'hi': 'इस बारे में Assistant से पूछें'}[l]!),
                onPressed: () {
                  final title = assistantTabs(s).where((t) => t.$1 == pageNow).firstOrNull?.$2 ?? 'Dashboard';
                  final m = widget.msg.length > 600 ? widget.msg.substring(0, 600) : widget.msg;
                  final q = {
                    'en': 'On the page "$title" I got this message: "$m". What went wrong, and what should I do?',
                    'mr': '"$title" या page वर हा संदेश आला: "$m". काय चुकले आणि मी काय करू?',
                    'hi': '"$title" page पर यह संदेश आया: "$m". क्या गलत हुआ और मैं क्या करूँ?',
                  }[l]!;
                  final nav = Navigator.of(context);
                  nav.pop();
                  openAssistant(nav.context, question: q);
                },
              ),
            ),
        ]),
      ),
    );
  }
}
