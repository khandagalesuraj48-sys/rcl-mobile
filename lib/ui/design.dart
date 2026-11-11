/* (3.97.0, his designs of 11-11-2026 – "all designs approved aahet te banwayla chalu kar") THE NEW LOOK'S PIECES, in one place.
 * Look only: nothing here decides what a button does, what is asked of a server or what it answers.
 *  - moduleBar / toneBar (design 2): the band at the top of a module's screens in the module's own colour (Tone, theme.dart) –
 *    moduleBar with the module's 3D picture in a white disc, its name (English / मराठी) and a line (site · role); toneBar the same
 *    band for the module's other screens, with their own title, actions and tabs (white on the colour);
 *  - ChipTabs (design 1): a screen's tabs as round chips, the chosen one filled in the module's colour;
 *  - Striped / stateLook (design 9): a coloured strip on the left of a list card by its state – waiting yellow, done green,
 *    refused red – and the state's chip in English / मराठी;
 *  - SkeletonList (design 10): grey shapes while the real answer is coming – only while it comes, never a made-up wait;
 *  - StepBar (design 7): the steps of an entry form – done ✓, now (in colour), next (grey). */
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import 't.dart';
import 'theme.dart';
import 'widgets.dart';

/// The look of a band in a module's colour: white title, white icons and buttons, white tabs.
ThemeData bandTheme(ThemeData t) => t.copyWith(
      appBarTheme: t.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: t.appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.white)),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Colors.white)),
      tabBarTheme: const TabBarThemeData(labelColor: Colors.white, unselectedLabelColor: Color(0xCCFFFFFF), indicatorColor: Colors.white, dividerColor: Colors.transparent),
    );

/// The band's colour box (a module's colour, rounded at the bottom) – for a screen that draws its own top.
BoxDecoration bandBox(Tone tone) => BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tone.a, tone.b]),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      boxShadow: [BoxShadow(color: tone.b.withValues(alpha: .22), blurRadius: 14, offset: const Offset(0, 5))],
    );

/// The band in the module's colour, as an AppBar (the same title, actions, tabs and back button as the screen had).
PreferredSizeWidget toneBar(Tone tone, {Key? key, Widget? title, List<Widget>? actions, PreferredSizeWidget? bottom, Widget? leading, bool automaticallyImplyLeading = true, double? titleSpacing, bool? centerTitle, double? toolbarHeight}) {
  final bar = AppBar(
    key: key,
    title: title,
    actions: actions,
    bottom: bottom,
    leading: leading,
    automaticallyImplyLeading: automaticallyImplyLeading,
    titleSpacing: titleSpacing,
    centerTitle: centerTitle,
    toolbarHeight: toolbarHeight,
    flexibleSpace: DecoratedBox(decoration: bandBox(tone)),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
  );
  return PreferredSize(preferredSize: bar.preferredSize, child: Builder(builder: (c) => Theme(data: bandTheme(Theme.of(c)), child: bar)));
}

/// A module's 3D picture in a white disc – on a band.
class PicDisc extends StatelessWidget {
  const PicDisc(this.pic, {super.key, this.size = 40});
  final String pic;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .95), borderRadius: BorderRadius.circular(size * .33)),
        alignment: Alignment.center,
        child: Pic(pic, size: size * .68),
      );
}

/// A module's main screen: its 3D picture in a white disc, its name (English / मराठी), a line under it (site · role).
PreferredSizeWidget moduleBar(BuildContext context, Tone tone, {Key? key, required String en, required String mr, required String pic, String line = '', List<Widget>? actions, PreferredSizeWidget? bottom}) {
  final k = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.7);
  final lineH = line.isEmpty ? 0.0 : 18 + 20 * k;
  return toneBar(
    tone,
    key: key,
    toolbarHeight: math.max(64.0, 48 * k + 14),
    titleSpacing: 0,
    title: Row(children: [
      PicDisc(pic, size: 42),
      const SizedBox(width: 10),
      Expanded(child: TwoLang(en, mr, color: Colors.white, size: 21, weight: FontWeight.w700)),
    ]),
    actions: actions,
    bottom: bottom ??
        (line.isEmpty
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(lineH),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Sp.edge, 0, Sp.edge, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withValues(alpha: .3))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.location_on_rounded, size: 15, color: Colors.white),
                        const SizedBox(width: 5),
                        Flexible(child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w500))),
                      ]),
                    ),
                  ),
                ),
              )),
  );
}

/// (design 1) A screen's tabs as round chips – the chosen one filled in the module's colour. Works with the screen's
/// DefaultTabController (a tap goes to its page, a swipe of the page moves the chip).
class ChipTabs extends StatelessWidget {
  const ChipTabs({super.key, required this.labels, required this.tone, this.keys = const [], this.padding = const EdgeInsets.fromLTRB(Sp.edge, 12, Sp.edge, 4)});
  final List<String> labels;
  final List<Key?> keys;
  final Tone tone;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final c = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(children: [
          for (final (i, l) in labels.indexed)
            Padding(
              padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
              child: _Chip(key: i < keys.length ? keys[i] : null, label: l, on: c.index == i, tone: tone, onTap: () => c.animateTo(i)),
            ),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.on, required this.tone, required this.onTap});
  final String label;
  final bool on;
  final Tone tone;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        selected: on,
        button: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: on ? tone.b : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: on ? tone.b : C.line, width: 1.5),
            boxShadow: on ? [BoxShadow(color: tone.b.withValues(alpha: .25), blurRadius: 8, offset: const Offset(0, 3))] : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Text(label, maxLines: 1, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: on ? Colors.white : C.ink)),
              ),
            ),
          ),
        ),
      );
}

/// (design 9) How a state looks: the strip's colour, the chip's colours and its Marathi word. Waiting yellow, done green,
/// refused / cancelled red, anything else grey.
({Color strip, Color fg, Color bg, String mr}) stateLook(String status) {
  final s = status.trim().toLowerCase();
  if (s.isEmpty) return (strip: const Color(0xFFB9C0BB), fg: C.slate, bg: C.slateSoft, mr: '');
  if (RegExp(r'reject|refus|cancel|sent back|returned|not ok|fail|lapsed|expired').hasMatch(s)) {
    return (strip: const Color(0xFFD9443A), fg: const Color(0xFFA61E1E), bg: C.redSoft, mr: s.contains('cancel') ? 'रद्द' : (s.contains('back') || s.contains('return') ? 'परत पाठवले' : 'नाकारले'));
  }
  if (RegExp(r'pend|wait|verif(y|ication)|to approve|to order|sent|open|draft|asked|in progress|on$|still').hasMatch(s) && !RegExp(r'verified').hasMatch(s)) {
    return (strip: const Color(0xFFE9A23B), fg: const Color(0xFF8A5200), bg: C.amberSoft, mr: s.contains('draft') ? 'मसुदा' : 'थांबलेले');
  }
  if (RegExp(r'approv|verified|done|closed|complete|received|issued|accept|ok$|saved|passed|award').hasMatch(s)) {
    return (strip: const Color(0xFF2E8B5E), fg: C.greenDark, bg: C.greenSoft, mr: s.contains('closed') ? 'बंद' : 'मंजूर');
  }
  return (strip: const Color(0xFFB9C0BB), fg: C.slate, bg: C.slateSoft, mr: '');
}

/// (design 9) A list card with a coloured strip on its left edge (its state). The card itself is as it was.
class Striped extends StatelessWidget {
  const Striped({super.key, required this.status, required this.child, this.radius = 18, this.color});
  final String status;
  final Widget child;
  final double radius;
  /// a colour of its own instead of the state's
  final Color? color;
  @override
  Widget build(BuildContext context) => Stack(children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              width: 5,
              decoration: BoxDecoration(color: color ?? stateLook(status).strip, borderRadius: BorderRadius.horizontal(left: Radius.circular(radius))),
            ),
          ),
        ),
      ]);
}

/// (design 9) The state's chip: "Waiting · थांबलेले" (the Marathi word while no language is chosen).
class StateChip extends StatelessWidget {
  const StateChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final l = stateLook(status);
    final mr = Lang.i.code.isEmpty && l.mr.isNotEmpty ? ' · ${l.mr}' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: l.bg, borderRadius: BorderRadius.circular(30)),
      child: Text('${tr(status)}$mr', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: l.fg)),
    );
  }
}

/// (design 10) Grey shapes while the real answer comes – [tiles] figure tiles (a dashboard) above [rows] list rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key = const Key('skeleton'), this.tiles = 0, this.rows = 5});
  final int tiles, rows;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, b) {
          final half = math.max(0.0, (b.maxWidth - Sp.edge * 2 - 10) / 2);
          return ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Sp.edge, 12, Sp.edge, 16),
            children: [
              if (tiles > 0) ...[
                Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < tiles; i++) Shimmer(height: 92, radius: 18, width: half)]),
                const SizedBox(height: 14),
              ],
              for (var i = 0; i < rows; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: Shimmer(height: 72, radius: 18)),
            ],
          );
        },
      );
}

/// (design 7) The steps of an entry form: [done] of them are done (✓ green), the next one is "now" (in [color]), the rest grey.
class StepBar extends StatelessWidget {
  const StepBar({super.key = const Key('step-bar'), required this.steps, required this.done, this.color = C.red});
  final List<(String, String)> steps;
  final int done;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final mrOn = Lang.i.code.isEmpty;
    Widget dot(int i) {
      final ok = i < done, now = i == done;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ok ? C.green : (now ? Colors.white : const Color(0xFFEEEAE0)),
          border: now ? Border.all(color: color, width: 3) : null,
        ),
        alignment: Alignment.center,
        child: ok ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : Text('${i + 1}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: now ? color : const Color(0xFF9AA29D))),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: softShadow(.05)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, st) in steps.indexed)
          Expanded(
            child: Column(children: [
              Row(children: [
                Expanded(child: i == 0 ? const SizedBox() : Container(height: 3, decoration: BoxDecoration(color: i <= done ? C.green : const Color(0xFFE5E0D4), borderRadius: BorderRadius.circular(2)))),
                dot(i),
                Expanded(child: i == steps.length - 1 ? const SizedBox() : Container(height: 3, decoration: BoxDecoration(color: i < done ? C.green : const Color(0xFFE5E0D4), borderRadius: BorderRadius.circular(2)))),
              ]),
              const SizedBox(height: 4),
              Text(st.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: i < done ? C.green : (i == done ? color : const Color(0xFF9AA29D)))),
              if (mrOn) Text(st.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'NotoDeva', fontSize: 10.5, color: C.faint)),
            ]),
          ),
      ]),
    );
  }
}
