/* THE APP'S LOOK – premium phone design (asked 14-10-2026, with three pictures): white cards on a soft green-white page, deep
 * green for the main things, a soft colour for each kind of work (diesel green, store amber, machines blue, Log Book purple,
 * maintenance orange), 3D pictures, Rubik with Marathi under the English.
 * (3.31.0, asked 20-10-2026 with his picture: "HE BGH SAME AS IT IS HAW AAHE" – "TAS DARK EKDAM NKO") a forest green that is not
 * too dark, a warm cream page, gold for the + and the links; one spacing for every screen (Sp).
 * (3.31.1, asked 20-10-2026: "COLOUR THODE DIM DISAT AAHE APP THODI ENHANCE KR") the same colours a little brighter and fuller: the
 * greens and the gold stronger, the cream page lighter, the soft tiles fuller, the grey words darker (easier to read). */
import 'package:flutter/material.dart';

import 'motion.dart';

class C {
  static const bg = Color(0xFFFAF8F2);
  static const card = Colors.white;
  static const ink = Color(0xFF18221C);
  static const muted = Color(0xFF5A675F);
  static const faint = Color(0xFF8F9993);
  static const line = Color(0xFFECE6D9);
  static const green = Color(0xFF277E55);
  static const greenDark = Color(0xFF1E5A40);
  static const greenDeep = Color(0xFF184833);
  static const greenSoft = Color(0xFFDCF2E4);
  static const greenChip = Color(0xFFCAEAD6);
  static const blue = Color(0xFF1E63D6);
  static const blueSoft = Color(0xFFE1EBFB);
  static const purple = Color(0xFF7B3FD0);
  static const purpleSoft = Color(0xFFEAE3F8);
  static const amber = Color(0xFFB66A00);
  static const amberSoft = Color(0xFFFDEFD5);
  static const orange = Color(0xFFE0592A);
  static const orangeSoft = Color(0xFFFDE7DD);
  static const slate = Color(0xFF475467);
  static const slateSoft = Color(0xFFEAEEF4);
  static const red = Color(0xFFC62828);
  static const redSoft = Color(0xFFFCE4E0);
  static const brandRed = Color(0xFFE30613); // the red of the Rachana mark
  // (3.31.0) his picture: the lighter green, gold and the green of the bar at the bottom
  static const greenLight = Color(0xFF37A16B);
  static const gold = Color(0xFFD99E39);
  static const goldLight = Color(0xFFECBF62);
  static const goldSoft = Color(0xFFFDEFD5);
  static const bar = Color(0xFF26744F);
  static const barDeep = Color(0xFF216447);
  // (3.31.1) the green at the end of the green cards (Home's stock, Me's top) and of the Sign in button
  static const greenEnd = Color(0xFF216F4C);
  static const greenBright = Color(0xFF177C56);
  // (3.31.1) gold for words (View All, Forgot password?, the count on Me): deeper than the + so it is easy to read on the cream page
  static const goldInk = Color(0xFFB07A1E);
}

/// (3.97.0, his design 2 of 11-11-2026 – "all designs approved") EACH MODULE'S OWN COLOUR: the band at the top of its screens
/// ([a] → [b]) and its tile on Home ([soft]) – a screen tells at a glance which module it is.
class Tone {
  const Tone(this.a, this.b, this.soft);
  final Color a, b, soft;
  static const machinery = Tone(Color(0xFF2E8B5E), Color(0xFF1E5A40), C.greenSoft);
  static const logbook = Tone(Color(0xFF8A4FDC), Color(0xFF5E2BAA), C.purpleSoft);
  static const diesel = Tone(Color(0xFFD9443A), Color(0xFFA61E1E), C.redSoft);
  static const store = Tone(Color(0xFFC98114), Color(0xFFA65E00), C.amberSoft);
  static const engineering = Tone(Color(0xFF139AA5), Color(0xFF0B6870), Color(0xFFDDF2F3));
  static const purchase = Tone(Color(0xFF3B7BE6), Color(0xFF1A4FB0), C.blueSoft);
  static const hr = Tone(Color(0xFFD9508A), Color(0xFF9C1F55), Color(0xFFFCE4EE)); // (3.103.0) HR – attendance
  static const maintenance = Tone(Color(0xFFEA6A3C), Color(0xFFC0461A), C.orangeSoft);
  static const billing = Tone(Color(0xFF6A5AE0), Color(0xFF4535B0), Color(0xFFE8E5FB));
  static const reports = Tone(Color(0xFF5A6B85), Color(0xFF344054), C.slateSoft);
  static const admin = Tone(Color(0xFF5A6B85), Color(0xFF344054), C.slateSoft);
}

/// (3.31.0, asked 20-10-2026: "kuthe kuthe tabs button che pudhe maghe space aahe") one spacing for every screen: the page's edge,
/// a name and its box, one part and the next, buttons side by side and their rows.
class Sp {
  static const edge = 16.0; // from the side of the screen
  static const label = 8.0; // a name and its box
  static const block = 16.0; // one part and the next
  static const chips = 10.0; // buttons side by side, and their rows
}

const kFonts = ['NotoDeva']; // Marathi / Hindi letters come from Noto Sans Devanagari

/// A soft shadow under the white cards.
List<BoxShadow> softShadow([double a = .07]) => [BoxShadow(color: const Color(0xFF3A3020).withValues(alpha: a), blurRadius: 22, offset: const Offset(0, 8))];

/// The app's look. [site]: (3.97.0, his design 12) SITE MODE – for the sun at a site: thicker lines round the boxes, bigger
/// buttons and chips (the letters are made bigger in main.dart, on top of his "Size of the text").
ThemeData appTheme({bool site = false}) {
  final base = ThemeData(useMaterial3: true, fontFamily: 'Rubik', colorScheme: ColorScheme.fromSeed(seedColor: C.green, surface: C.bg, primary: C.green));
  TextStyle t(double s, FontWeight w, [Color c = C.ink]) => TextStyle(fontFamily: 'Rubik', fontFamilyFallback: kFonts, fontSize: s, fontWeight: w, color: c, height: 1.25);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: appPageTransitions,      // (3.96.0) every new screen: zoom in / out on Android, the iPhone's own slide
    textTheme: base.textTheme.copyWith(
      headlineMedium: t(26, FontWeight.w700),
      headlineSmall: t(22, FontWeight.w700),
      titleLarge: t(19, FontWeight.w600),
      titleMedium: t(16, FontWeight.w600),
      bodyLarge: t(16, FontWeight.w400),
      bodyMedium: t(14.5, FontWeight.w400),
      bodySmall: t(12.5, FontWeight.w400, C.muted),
      labelLarge: t(15, FontWeight.w600),
    ),
    // (3.31.0) a thin line under the bar while the page goes under it (the page no longer looks cut)
    appBarTheme: AppBarTheme(backgroundColor: C.bg, surfaceTintColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 1, shadowColor: const Color(0x33000000), foregroundColor: C.ink, titleTextStyle: t(21, FontWeight.w700), centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: site ? 21 : 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: site ? BorderSide(color: C.ink.withValues(alpha: .6), width: 2) : const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: C.green, width: site ? 3 : 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.red)),
      labelStyle: t(15, FontWeight.w400, C.muted),
      hintStyle: t(15, FontWeight.w400, C.faint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, minimumSize: Size.fromHeight(site ? 68 : 58), shape: const StadiumBorder(), textStyle: t(site ? 19 : 17, site ? FontWeight.w700 : FontWeight.w600, Colors.white)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: C.ink, minimumSize: Size.fromHeight(site ? 60 : 52), shape: const StadiumBorder(), side: site ? BorderSide(color: C.ink.withValues(alpha: .55), width: 2) : const BorderSide(color: C.line), textStyle: t(site ? 17 : 16, site ? FontWeight.w700 : FontWeight.w600)),
    ),
    // (3.31.0) every chip the same pill, the same height – side by side and in rows the same gap (Sp.chips)
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: site ? BorderSide(color: C.ink.withValues(alpha: .5), width: 2) : const BorderSide(color: C.line)),
      side: site ? BorderSide(color: C.ink.withValues(alpha: .5), width: 2) : const BorderSide(color: C.line),
      backgroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: site ? 14 : 10, vertical: site ? 12 : 9),
      labelStyle: t(site ? 15.5 : 14, site ? FontWeight.w700 : FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: C.ink, contentTextStyle: t(14.5, FontWeight.w500, Colors.white), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, showDragHandle: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
    dialogTheme: DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
    datePickerTheme: DatePickerThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: C.greenChip,
      surfaceTintColor: Colors.transparent,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => t(12.5, s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500, s.contains(WidgetState.selected) ? C.greenDark : C.muted)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 26, color: s.contains(WidgetState.selected) ? C.greenDark : C.muted)),
    ),
  );
}
