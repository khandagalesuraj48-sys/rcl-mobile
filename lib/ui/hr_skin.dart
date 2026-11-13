/* THE TWO LOOKS OF THE ATTENDANCE APP (3.114.0 – his approval of 12-11-2026: "ok he final 2 ni thew user je haw te switch kru
 * shakel"): "Pearl" (light, white and gold) and "Midnight Gold" (dark, glass and gold). The person chooses his own in Me → Look;
 * it is kept on this phone. Only for a person with HR only (the attendance app – "fkt attendance app che boloty mi baki konache
 * design changes nahit"): everybody else keeps the HR pages exactly as they were ([Sk.classic]).
 * Only the colours and the shapes are here – what may be done is decided where it always was (the HR server). */
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/attend.dart' show AttendKit;
import 'theme.dart';

/// One look: its colours. Every HR page asks [sk] for them.
class Sk {
  const Sk({
    required this.name,
    required this.classic,
    required this.dark,
    required this.bg,
    required this.bgTop,
    required this.card,
    required this.cardLine,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.hair,
    required this.blank,
    required this.blankInk,
    required this.accent,
    required this.onAccent,
    required this.link,
    required this.shadowColor,
  });
  final String name;
  final bool classic, dark;
  final Color bg, bgTop, card, ink, muted, faint, line, hair, blank, blankInk, accent, onAccent, link, shadowColor;
  final Color? cardLine;

  /// The HR pages as they were before the two looks (a person with the full app).
  static const classicLook = Sk(
    name: 'classic',
    classic: true,
    dark: false,
    bg: C.bg,
    bgTop: C.bg,
    card: Colors.white,
    cardLine: null,
    ink: C.ink,
    muted: C.muted,
    faint: C.faint,
    line: C.line,
    hair: Color(0xFFF3F5FA),
    blank: Color(0xFFF3F5FA),
    blankInk: Color(0xFFB3B9C9),
    accent: Color(0xFF0F1F3D),
    onAccent: Colors.white,
    link: C.blue,
    shadowColor: Color(0x12141E3C),
  );

  static const pearl = Sk(
    name: 'pearl',
    classic: false,
    dark: false,
    bg: Color(0xFFF2F4FA),
    bgTop: Color(0xFFFBF5E6),
    card: Colors.white,
    cardLine: Color(0xFFE8EBF3),
    ink: Color(0xFF0F1830),
    muted: Color(0xFF59647E),
    faint: Color(0xFF98A1B8),
    line: Color(0xFFE1E5EF),
    hair: Color(0xFFEEF1F7),
    blank: Color(0xFFF1F3F9),
    blankInk: Color(0xFFAEB5C8),
    accent: Color(0xFF0F1F3D),
    onAccent: Colors.white,
    link: Color(0xFFA9741A),
    shadowColor: Color(0x14141E3C),
  );

  static const gold = Sk(
    name: 'gold',
    classic: false,
    dark: true,
    bg: Color(0xFF070B1C),
    bgTop: Color(0xFF16215A),
    card: Color(0xFF141A30),
    cardLine: Color(0xFF283152),
    ink: Color(0xFFF4F6FC),
    muted: Color(0xFFA7B0CA),
    faint: Color(0xFF727B9A),
    line: Color(0xFF2B3454),
    hair: Color(0xFF222A45),
    blank: Color(0xFF1B2240),
    blankInk: Color(0xFF5E6788),
    accent: Color(0xFFE6B94E),
    onAccent: Color(0xFF2A1D00),
    link: Color(0xFFE6B94E),
    shadowColor: Color(0x66000000),
  );

  /// The gold of the main button and of IN; the red of OUT.
  static const goldFill = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF7DE8E), Color(0xFFDDAD40), Color(0xFFB07C19)], stops: <double>[0, .55, 1]);
  static const redFill = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF8E84), Color(0xFFE5484D), Color(0xFFAE241D)], stops: <double>[0, .55, 1]);
  static const goldInk = Color(0xFF2A1D00);

  List<BoxShadow> get shadow => [BoxShadow(color: shadowColor, blurRadius: dark ? 18 : 12, offset: Offset(0, dark ? 8 : 3))];

  /// A card of this look.
  BoxDecoration box({double radius = 20, Color? color}) => BoxDecoration(color: color ?? card, borderRadius: BorderRadius.circular(radius), border: cardLine == null ? null : Border.all(color: cardLine!), boxShadow: shadow);

  /// A coloured sign with its soft tile: as given on a light look; on the dark one the colour is made lighter and its tile is
  /// the same colour, thin.
  (Color, Color) tint(Color c, Color soft) => dark ? (Color.lerp(c, Colors.white, c.computeLuminance() < .12 ? .62 : .42)!, c.withValues(alpha: .26)) : (c, soft);

  /// What is written on the head of a page: white on the old sky, the page's own ink on the two looks.
  Color get onHead => classic ? Colors.white : ink;
  Color get onHeadSoft => classic ? Colors.white.withValues(alpha: .95) : muted;

  /// A small box on the head (the pill, a balance box).
  Color get headGlass => classic ? Colors.white.withValues(alpha: .2) : card;
  Color get headGlassLine => classic ? Colors.white.withValues(alpha: .4) : (cardLine ?? line);

  /// The page behind everything: plain on the old pages; a soft glow from the top on the two looks.
  Gradient get pageFill => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bgTop, bg, bg], stops: const <double>[0, .42, 1]);
}

/// The look of the HR pages.
Sk get sk => HrSkin.i.now;

/// For a page that is not HR's own (the e-mail check): the look inside the attendance app, the app's own colours elsewhere.
Sk get skApp => HrSkin.i.on ? sk : Sk.classicLook;

/// (3.115.0) An HR page opened in the full app: the look's theme around it (its dialogs, pickers and fields follow), while the
/// rest of the app keeps its own. In the attendance app the whole app already has it.
class HrLook extends StatefulWidget {
  const HrLook({super.key, required this.child});
  final Widget child;
  @override
  State<HrLook> createState() => _HrLookState();
}

class _HrLookState extends State<HrLook> {
  @override
  void initState() {
    super.initState();
    HrSkin.i.addListener(_changed);
    HrSkin.i.load();
  }

  @override
  void dispose() {
    HrSkin.i.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Theme(data: hrTheme(sk, Theme.of(context)), child: widget.child);
}

/// The way to an HR page: always under its look.
MaterialPageRoute<T> hrRoute<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => HrLook(child: page));

class HrSkin extends ChangeNotifier {
  HrSkin._();
  static final HrSkin i = HrSkin._();
  static const _file = 'hr_look.txt';

  /// 'pearl' or 'gold' – his choice (Pearl until he chooses).
  String look = 'pearl';

  /// true while the attendance app (a person with HR only) is on the screen.
  bool get on => _users > 0;
  int _users = 0; // (two for a moment while one site's pages give way to another's)

  /// (3.115.0, his word of 13-11-2026: a person with the ERP and attendance "tyala pn hi new screen disayla pahije") the HR
  /// pages are in the look for everybody now – Pearl until he chooses.
  Sk get now => look == 'gold' ? Sk.gold : Sk.pearl;

  bool _read = false;

  /// The look kept on this phone, read once (a person with the full app opens an HR page).
  Future<void> load() async {
    if (_read) return;
    _read = true;
    var t = '';
    try {
      t = ((await AttendKit.kit.readText(_file)) ?? '').trim();
    } catch (_) {}
    if (t == 'gold' && look != 'gold') {
      look = 'gold';
      notifyListeners();
    }
  }

  /// The attendance app opens: its look from this phone (Pearl until he chooses).
  Future<void> enter() async {
    _users++;
    var t = '';
    try {
      t = ((await AttendKit.kit.readText(_file)) ?? '').trim();
    } catch (_) {}
    look = t == 'gold' ? 'gold' : 'pearl';
    if (on) notifyListeners();
  }

  /// The attendance app is closed (signed out, or he was given the full app). Said a moment later: never while the pages
  /// are being taken away.
  void leave() {
    if (_users > 0) _users--;
    scheduleMicrotask(notifyListeners);
  }

  Future<void> choose(String v) async {
    if (v != 'gold' && v != 'pearl') return;
    look = v;
    notifyListeners();
    try {
      await AttendKit.kit.writeText(_file, v);
    } catch (_) {}
  }
}

/// The app's theme under a look (dialogs, pickers, fields and plain words follow it).
ThemeData hrTheme(Sk s, ThemeData base) {
  TextStyle t(double size, FontWeight w, [Color? c]) => TextStyle(fontFamily: 'Rubik', fontFamilyFallback: kFonts, fontSize: size, fontWeight: w, color: c ?? s.ink, height: 1.25);
  final scheme = ColorScheme.fromSeed(seedColor: s.dark ? const Color(0xFFDDAD40) : const Color(0xFF0F1F3D), brightness: s.dark ? Brightness.dark : Brightness.light).copyWith(primary: s.accent, onPrimary: s.onAccent, surface: s.card, onSurface: s.ink);
  final fresh = ThemeData(useMaterial3: true, fontFamily: 'Rubik', colorScheme: scheme);
  OutlineInputBorder edge(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c, width: w));
  return fresh.copyWith(
    scaffoldBackgroundColor: s.bg,
    splashFactory: base.splashFactory,
    pageTransitionsTheme: base.pageTransitionsTheme,
    textTheme: fresh.textTheme.copyWith(
      headlineMedium: t(26, FontWeight.w700),
      headlineSmall: t(22, FontWeight.w700),
      titleLarge: t(19, FontWeight.w600),
      titleMedium: t(16, FontWeight.w600),
      bodyLarge: t(16, FontWeight.w400),
      bodyMedium: t(14.5, FontWeight.w400),
      bodySmall: t(12.5, FontWeight.w400, s.muted),
      labelLarge: t(15, FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(backgroundColor: s.bg, surfaceTintColor: Colors.transparent, elevation: 0, foregroundColor: s.ink, titleTextStyle: t(21, FontWeight.w700), centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: edge(s.line),
      enabledBorder: edge(s.line),
      focusedBorder: edge(s.accent, 2),
      errorBorder: edge(C.red),
      labelStyle: t(15, FontWeight.w400, s.muted),
      hintStyle: t(15, FontWeight.w400, s.faint),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: s.accent, foregroundColor: s.onAccent, minimumSize: const Size.fromHeight(58), shape: const StadiumBorder(), textStyle: t(17, FontWeight.w600, s.onAccent))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: s.ink, minimumSize: const Size.fromHeight(52), shape: const StadiumBorder(), side: BorderSide(color: s.line), textStyle: t(16, FontWeight.w600))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: s.link)),
    dividerColor: s.line,
    snackBarTheme: base.snackBarTheme,
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: s.card, surfaceTintColor: Colors.transparent, showDragHandle: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
    dialogTheme: DialogThemeData(backgroundColor: s.card, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
    datePickerTheme: DatePickerThemeData(backgroundColor: s.card, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
  );
}
