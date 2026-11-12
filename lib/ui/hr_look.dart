/* THE LOOK OF THE HR PAGES OF THE APP (3.108.0 – the eight screens he sent back on 12-11-2026: "mala same as it is screen hawe
 * aahet ya sagle leave chi pn screen"): a page's head is a sky with its title, a small pill on the right and what the page says
 * under it; white cards; a dark-blue main button; small state chips. One language at a time: English while none is chosen, the
 * app's own Marathi words when Marathi is (Text's `mr`). Only the look – what may be done is decided by the HR server. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import 'attend_look.dart';
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
PreferredSizeWidget hrHead(BuildContext context, {required Gradient sky, required String title, String mr = '', Widget? pill, List<Widget> below = const [], required double height}) => PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(gradient: sky, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
        child: SafeArea(
          bottom: false,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxHeight: double.infinity,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                  Expanded(child: Text(title, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white))),
                  if (pill != null) Padding(padding: const EdgeInsets.only(right: 14), child: pill),
                ]),
                if (below.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: below)),
              ]),
            ),
          ),
        ),
      ),
    );

/// The small pill of a head ("Nov 2026").
Widget headPill(String text, {Key? key}) => Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(14)),
      child: m.Text(text, maxLines: 1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
    );

/// A white card with a thin line.
Widget hrCard(List<Widget> children, {Key? key, EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 14, 16, 12)}) => Container(
      key: key,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: kSoftShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
    );

/// A card's title (and a small word on its right).
Widget hrTitle(String en, String mr, {String side = ''}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: C.ink))),
        if (side.isNotEmpty) m.Text(side, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.blue)),
      ]),
    );

/// The dark-blue main button of a page.
Widget hrButton(String en, String mr, {required Key key, required VoidCallback? onTap, bool busy = false}) => SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        key: key,
        style: FilledButton.styleFrom(backgroundColor: kNavy, disabledBackgroundColor: C.slateSoft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: busy ? null : onTap,
        child: busy
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
      ),
    );

/// A small state chip: w – waiting (blue), a – approved (green), x – refused (red), s – other (grey).
Widget stateChip(String text, String kind, {Key? key, VoidCallback? onTap}) {
  final c = switch (kind) { 'a' => (C.greenDark, C.greenSoft), 'x' => (C.red, C.redSoft), 'w' => (C.blue, C.blueSoft), _ => (C.slate, C.slateSoft) };
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
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F5FA)))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            m.Text(main, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.ink, height: 1.25)),
            if (small.isNotEmpty) m.Text(small, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.3)),
          ]),
        ),
        for (final c in chips) Padding(padding: const EdgeInsets.only(left: 6), child: c),
      ]),
    );

/// A field's small label over its white box.
Widget hrField(String en, String mr, Widget box) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.only(left: 2, bottom: 5), child: Text(en, mr: mr, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.muted))),
      box,
    ]);

InputDecoration hrInput({String hint = '', Widget? suffix}) => InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kNavy, width: 2)),
    );

/// A soft note under a form (yellow: [warm]; blue otherwise).
Widget hrNote(String text, {bool warm = true, Key? key}) => Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: warm ? const Color(0xFFFFF3D1) : C.blueSoft, borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.35, color: warm ? const Color(0xFF5B4A14) : const Color(0xFF0B3A6B))),
    );

/// A pale glass box on a sky (a button there).
Widget hrGlass(Widget child) => Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .4))),
      child: child,
    );
