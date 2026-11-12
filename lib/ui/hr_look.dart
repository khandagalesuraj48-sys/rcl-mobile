/* THE LOOK OF THE HR PAGES OF THE APP (3.108.0 – the eight screens he sent back on 12-11-2026: "mala same as it is screen hawe
 * aahet ya sagle leave chi pn screen"): a page's head is a sky with its title, a small pill on the right and what the page says
 * under it; white cards; a dark-blue main button; small state chips. One language at a time: English while none is chosen, the
 * app's own Marathi words when Marathi is (Text's `mr`). Only the look – what may be done is decided by the HR server.
 * (3.114.0) every colour is asked of the look in use (ui/hr_skin.dart): these pages as they were for a person with the full app;
 * "Pearl" or "Midnight Gold" – a plain head, cards of the look, a gold main button – in the attendance app. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import 'attend_look.dart';
import 'hr_skin.dart';
import 't.dart';
import 'theme.dart';

const kNavy = Color(0xFF0F1F3D);
const kPurple = Color(0xFF7A3B6E);
const kLeaveSky = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3B2A63), Color(0xFF7A3B6E), Color(0xFFC55A4E)], stops: <double>[0, .7, 1]);
const kAskSky = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7A4A00), Color(0xFFD9902B), Color(0xFFF6C667)], stops: <double>[0, .75, 1]);
final kDaySky = skyDown(Sky.day);
const kSoftShadow = [BoxShadow(color: Color(0x12141E3C), blurRadius: 12, offset: Offset(0, 3))];

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Nov 2026" of yyyy-MM (or a day).
String monthName(String ym) => ym.length < 7 ? ym : '${_mon[(int.tryParse(ym.substring(5, 7)) ?? 1) - 1]} ${ym.substring(0, 4)}';

/// "10 Nov" of yyyy-MM-dd; with [week]: "Tue 10 Nov".
String dayName(String ymd, {bool week = false}) {
  final d = DateTime.tryParse('${ymd}T00:00:00Z');
  if (d == null) return ymd;
  return '${week ? '${_wd[d.weekday - 1]} ' : ''}${d.day} ${_mon[d.month - 1]}';
}

/// The head of an HR page: its sky, the back arrow, the title, [pill] on the right, [below] under it. Taller than what it holds;
/// with very big letters the lowest line is cut, nothing overflows.
/// (3.114.0) in the attendance app: no sky – the page's own soft glow, the way back in a small box, the title in the page's ink.
/// [back] false: a page that is a tab of the attendance app (nothing to go back to).
PreferredSizeWidget hrHead(BuildContext context, {required Gradient sky, required String title, String mr = '', Widget? pill, List<Widget> below = const [], required double height, bool back = true}) {
  final s = sk;
  return PreferredSize(
    preferredSize: Size.fromHeight(height),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: s.classic ? BoxDecoration(gradient: sky, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))) : BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [s.bgTop, s.bg])),
      child: SafeArea(
        bottom: false,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxHeight: double.infinity,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (s.classic)
                  IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white))
                else if (back)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                    child: hrIconBox(Icons.arrow_back_ios_new_rounded, key: const Key('hr-back'), size: 40, icon: 17, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.of(context).maybePop()),
                  )
                else
                  const SizedBox(width: 18, height: 48),
                Expanded(child: Text(title, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: s.classic ? 19 : 21, fontWeight: FontWeight.w800, color: s.onHead))),
                if (pill != null) Padding(padding: EdgeInsets.only(right: s.classic ? 14 : 16), child: pill),
              ]),
              if (below.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: below)),
            ]),
          ),
        ),
      ),
    ),
  );
}

/// (3.114.0) A small square box with a sign in it (the way back, the bell, refresh) – a card of the look.
Widget hrIconBox(IconData sign, {Key? key, double size = 42, double icon = 21, String? tooltip, VoidCallback? onTap, bool dot = false}) {
  final s = sk;
  final box = GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: s.box(radius: size * .33),
      child: Stack(children: [
        Center(child: Icon(sign, size: icon, color: s.ink)),
        if (dot) Positioned(right: size * .2, top: size * .2, child: Container(key: const Key('hh-dot'), width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle))),
      ]),
    ),
  );
  return tooltip == null ? box : Tooltip(message: tooltip, child: box);
}

/// The small pill of a head ("Nov 2026").
Widget headPill(String text, {Key? key}) => Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: sk.classic ? Colors.white.withValues(alpha: .22) : sk.headGlass, borderRadius: BorderRadius.circular(14), border: sk.classic ? null : Border.all(color: sk.headGlassLine)),
      child: m.Text(text, maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sk.onHead)),
    );

/// A card of the look (white with a soft shadow; dark glass with a thin line).
Widget hrCard(List<Widget> children, {Key? key, EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 14, 16, 12)}) => Container(
      key: key,
      width: double.infinity,
      padding: padding,
      decoration: sk.box(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
    );

/// A card's title (and a small word on its right).
Widget hrTitle(String en, String mr, {String side = ''}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink))),
        if (side.isNotEmpty) m.Text(side, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sk.link)),
      ]),
    );

/// The main button of a page: dark blue as it was; gold in the attendance app.
Widget hrButton(String en, String mr, {required Key key, required VoidCallback? onTap, bool busy = false}) {
  final s = sk, ink = s.classic ? Colors.white : Sk.goldInk;
  final btn = FilledButton(
    key: key,
    style: FilledButton.styleFrom(
        backgroundColor: s.classic ? kNavy : Colors.transparent,
        disabledBackgroundColor: s.classic ? C.slateSoft : Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    onPressed: busy ? null : onTap,
    child: busy
        ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: ink, strokeWidth: 3))
        : FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink))),
  );
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: s.classic ? btn : DecoratedBox(decoration: BoxDecoration(gradient: Sk.goldFill, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x55C8962B), blurRadius: 16, offset: Offset(0, 6))]), child: btn),
  );
}

/// A small state chip: w – waiting (blue), a – approved (green), x – refused (red), s – other (grey).
Widget stateChip(String text, String kind, {Key? key, VoidCallback? onTap}) {
  final c = switch (kind) { 'a' => sk.tint(C.greenDark, C.greenSoft), 'x' => sk.tint(C.red, C.redSoft), 'w' => sk.tint(C.blue, C.blueSoft), _ => sk.tint(C.slate, C.slateSoft) };
  final box = Container(
    key: onTap == null ? key : null,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: c.$2, borderRadius: BorderRadius.circular(10)),
    child: Text(text, maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.$1)),
  );
  return onTap == null ? box : GestureDetector(key: key, behavior: HitTestBehavior.opaque, onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: box));
}

/// One request in a card: its main line, a small line under it, its chips on the right.
Widget reqRow({required Key key, required String main, required String small, required List<Widget> chips, bool last = false}) => Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: sk.hair))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            m.Text(main, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sk.ink, height: 1.25)),
            if (small.isNotEmpty) m.Text(small, style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.3)),
          ]),
        ),
        for (final c in chips) Padding(padding: const EdgeInsets.only(left: 6), child: c),
      ]),
    );

/// A field's small label over its box.
Widget hrField(String en, String mr, Widget box) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.only(left: 2, bottom: 5), child: Text(en, mr: mr, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sk.muted))),
      box,
    ]);

InputDecoration hrInput({String hint = '', Widget? suffix}) => InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: sk.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: sk.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: sk.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: sk.accent, width: 2)),
    );

/// A soft note under a form (yellow: [warm]; blue otherwise).
Widget hrNote(String text, {bool warm = true, Key? key}) {
  final (Color ink, Color bg) = sk.dark
      ? (warm ? const Color(0xFFF3D98F) : const Color(0xFFB9D2FF), warm ? const Color(0x33DDAD40) : const Color(0x333B7BE6))
      : (warm ? const Color(0xFF5B4A14) : const Color(0xFF0B3A6B), warm ? const Color(0xFFFFF3D1) : C.blueSoft);
  return Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
    child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.35, color: ink)),
  );
}

/// A pale glass box on a sky (a button there).
Widget hrGlass(Widget child) => Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .4))),
      child: child,
    );
