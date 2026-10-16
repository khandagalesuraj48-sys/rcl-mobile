/* Small pieces every screen uses: the 3D pictures, a card that sinks a little when pressed, a section title, a pill, empty /
 * error states, the loading shimmer, toast and "Are you sure?". */
import 'package:flutter/material.dart' hide Text;

import '../core/api.dart';
import 'help.dart';
import 'theme.dart';
import 't.dart';

/// A 3D picture from assets/icons3d (Microsoft Fluent Emoji, MIT).
class Pic extends StatelessWidget {
  const Pic(this.name, {super.key, this.size = 40});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset('assets/icons3d/$name.png', width: size, height: size, filterQuality: FilterQuality.medium, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported_outlined, size: size * .6, color: C.faint));
}

/// English with the Marathi under it.
class TwoLang extends StatelessWidget {
  const TwoLang(this.en, this.mr, {super.key, this.color = C.ink, this.size = 16, this.weight = FontWeight.w600, this.align = CrossAxisAlignment.start});
  final String en, mr;
  final Color color;
  final double size;
  final FontWeight weight;
  final CrossAxisAlignment align;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: align, mainAxisSize: MainAxisSize.min, children: [
        Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.2)),
        if (mr.isNotEmpty) MrLine(mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'NotoDeva', fontSize: size - 3, color: color.withValues(alpha: .72), height: 1.3)),
      ]);
}

/// A card that sinks a little under the finger.
class Press extends StatefulWidget {
  const Press({super.key, required this.child, this.onTap, this.radius = 22, this.color = Colors.white, this.border, this.shadow = true, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color color;
  final Color? border;
  final bool shadow;
  final EdgeInsetsGeometry? padding;
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _down ? .97 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: widget.border ?? C.line.withValues(alpha: .7)),
            boxShadow: widget.shadow ? softShadow(.05) : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.radius),
              onTap: widget.onTap,
              onHighlightChanged: widget.onTap == null ? null : (v) => setState(() => _down = v),
              child: Padding(padding: widget.padding ?? EdgeInsets.zero, child: widget.child),
            ),
          ),
        ),
      );
}

/// "Modules ………… View All ›"
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.en, {super.key, this.mr = '', this.action, this.onAction, this.trailing});
  final String en, mr;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: TwoLang(en, mr, size: 20, weight: FontWeight.w700)),
          if (trailing != null) trailing!,
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: C.greenDark, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Text(action!, style: const TextStyle(fontWeight: FontWeight.w600)), const Icon(Icons.chevron_right_rounded, size: 22)]),
            ),
        ]),
      );
}

/// A small rounded label (60 L, Day, Admin …).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = C.greenDark, this.bg = C.greenSoft, this.icon, this.big = false});
  final String text;
  final Color color, bg;
  final IconData? icon;
  final bool big;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: big ? 14 : 10, vertical: big ? 8 : 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: big ? 18 : 14, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: big ? 18 : 12.5, fontWeight: big ? FontWeight.w700 : FontWeight.w600, color: color)),
        ]),
      );
}

/// Nothing to show (yet).
class EmptyState extends StatelessWidget {
  const EmptyState(this.title, this.sub, {super.key, this.pic = 'clipboard', this.action, this.onAction});
  final String title, sub, pic;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(children: [
          Opacity(opacity: .9, child: Pic(pic, size: 76)),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: C.muted, height: 1.35)),
          if (action != null) ...[const SizedBox(height: 16), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(160, 48)), onPressed: onAction, child: Text(action!))],
        ]),
      );
}

/// A line on a coloured strip (stock after this issue, a server refusal).
class InfoLine extends StatelessWidget {
  const InfoLine(this.text, {super.key, this.bad = false, this.icon, this.help = true});
  final String text;
  final bool bad;
  final IconData? icon;

  /// (3.16.0) a red message has "Help": what is wrong and what to do (the web's help in every "Nothing saved" box).
  final bool help;
  @override
  Widget build(BuildContext context) {
    final sent = this.bad && Api.isGood(text.split('\n').first);      // (update-114) sent for verification: green, not an error
    final bad = this.bad && !sent;
    return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: EdgeInsets.fromLTRB(14, 12, 14, bad && help ? 2 : 12),
        decoration: BoxDecoration(color: bad ? C.redSoft : C.greenSoft, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(sent ? Icons.hourglass_top_rounded : icon ?? (bad ? Icons.error_outline_rounded : Icons.local_gas_station_outlined), size: 20, color: bad ? C.red : C.greenDark),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, height: 1.35, color: bad ? C.red : C.greenDark, fontWeight: FontWeight.w500))),
          ]),
          if (bad && help) FixHelpLink(text),
        ]),
      );
  }
}

/// (update-114) The server sent the entry for verification (it is saved when it is approved).
bool isSent(Object e) => e is ApiError && e.code == 'sent';

/// (3.1.7) A NEW entry that got no answer (no network): may it be kept on the phone and sent by itself later? true = yes.
Future<bool> offerKeep(BuildContext context, Object e) async {
  if (e is! ApiError || !e.noConnection || e.rid.isEmpty) return false;
  return ask(context, 'No network', bi('Keep this entry on this phone? It is sent by itself when the network is back – you see it in Me → Waiting on this phone until then.',
      'ही एन्ट्री फोनवर ठेवायची? नेटवर्क आल्यावर ती आपोआप पाठवली जाईल – तोपर्यंत Me → Waiting on this phone मध्ये दिसेल.'), yes: 'Keep it');
}

/// Grey boxes that shine while the numbers are coming.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.height = 80, this.radius = 20, this.width});
  final double height, radius;
  final double? width;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _c.value * 3, 0),
              end: Alignment(-.5 + _c.value * 3, 0),
              colors: const [Color(0xFFE9EEEA), Color(0xFFF6F8F6), Color(0xFFE9EEEA)],
            ),
          ),
        ),
      );
}

/// A short message at the bottom of the screen.
void toast(BuildContext context, String msg, {bool bad = false}) {
  if (Api.isGood(msg)) bad = false;      // (14-10-2026 / update-114) sent for approval / verification: not a fault
  // (3.16.0) a red message has "Help" – what is wrong and what to do (the web's help card under every red message)
  final nav = bad ? Navigator.maybeOf(context, rootNavigator: true) : null;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: bad ? C.red : C.ink,
      duration: Duration(seconds: bad ? 6 : 3),
      persist: false,
      action: nav == null
          ? null
          : SnackBarAction(
              label: tr('Help'),
              textColor: Colors.white,
              onPressed: () {
                if (nav.mounted) showFixHelp(nav.context, msg);
              },
            ),
    ));
}

String errText(Object e) => e is ApiError ? e.toString() : 'Something went wrong – please try again.';

/// "Are you sure?" – Yes returns true.
Future<bool> ask(BuildContext context, String title, String body, {String yes = 'Yes', String no = 'Cancel', bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(body, style: const TextStyle(fontSize: 15, height: 1.4)),
          if (askNeedsHelp('$title $yes $body')) FixHelpLink(body, color: C.green), // (3.16.0) the web's help in such a question
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(no)),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(110, 46), backgroundColor: danger ? C.red : C.green), onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    ) ??
    false;

/// (3.2.0) A question with a box to write in (a remark, a reason, an answer) – null when Cancel. [needed]: it must be written
/// ([neededMsg] is said when it is empty). [body]: what the question is about, shown above the box.
Future<String?> askNote(BuildContext context, String title, {List<Widget> body = const [], String label = '', String ok = 'OK', bool needed = true, String neededMsg = 'Write it first.', bool danger = false, int max = 300}) {
  final c = TextEditingController();
  String err = '';
  return showDialog<String>(
    context: context,
    builder: (dc) => StatefulBuilder(
      builder: (dc, set) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ...body,
          if (body.isNotEmpty) const SizedBox(height: 12),
          if (label.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
          TextField(key: const Key('note-box'), controller: c, maxLines: 3, minLines: 2, maxLength: max, autofocus: true, decoration: InputDecoration(errorText: err.isEmpty ? null : tr(err))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
          FilledButton(
            key: const Key('note-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 46), backgroundColor: danger ? C.red : C.green),
            onPressed: () {
              final v = c.text.trim();
              if (needed && v.isEmpty) {
                set(() => err = neededMsg);
                return;
              }
              Navigator.pop(dc, v);
            },
            child: Text(ok),
          ),
        ],
      ),
    ),
  );
}

/// (3.2.0) "Are you sure?" with what it is about as lines (Yes returns true).
Future<bool> askLines(BuildContext context, String title, List<String> lines, {String note = '', String yes = 'Yes', bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $l', style: const TextStyle(fontSize: 14.5, height: 1.35))),
          if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(note, style: const TextStyle(fontSize: 14, color: C.muted, height: 1.4))),
          if (askNeedsHelp('$title $yes ${lines.join(' ')} $note')) FixHelpLink([...lines, note].where((x) => x.isNotEmpty).join('\n'), color: C.green),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(key: const Key('ask-yes'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46), backgroundColor: danger ? C.red : C.green), onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    ) ??
    false;
