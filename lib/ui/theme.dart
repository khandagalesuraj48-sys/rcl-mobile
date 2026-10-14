/* THE APP'S LOOK – premium phone design (asked 14-10-2026, with three pictures): white cards on a soft green-white page, deep
 * green for the main things, a soft colour for each kind of work (diesel green, store amber, machines blue, Log Book purple,
 * maintenance orange), 3D pictures, Rubik with Marathi under the English. */
import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFFF4F7F3);
  static const card = Colors.white;
  static const ink = Color(0xFF111B14);
  static const muted = Color(0xFF5F6E63);
  static const faint = Color(0xFF8D9A90);
  static const line = Color(0xFFE2E9E3);
  static const green = Color(0xFF17803D);
  static const greenDark = Color(0xFF0E5A2A);
  static const greenDeep = Color(0xFF0A3D1E);
  static const greenSoft = Color(0xFFE6F4E8);
  static const greenChip = Color(0xFFD5EDD9);
  static const blue = Color(0xFF1E63D6);
  static const blueSoft = Color(0xFFE7EFFC);
  static const purple = Color(0xFF7B3FD0);
  static const purpleSoft = Color(0xFFF0E9FB);
  static const amber = Color(0xFFB66A00);
  static const amberSoft = Color(0xFFFFF3DF);
  static const orange = Color(0xFFE0592A);
  static const orangeSoft = Color(0xFFFDEDE5);
  static const slate = Color(0xFF475467);
  static const slateSoft = Color(0xFFEEF1F5);
  static const red = Color(0xFFC62828);
  static const redSoft = Color(0xFFFDECEA);
  static const brandRed = Color(0xFFE30613); // the red of the Rachana mark
}

const kFonts = ['NotoDeva']; // Marathi / Hindi letters come from Noto Sans Devanagari

/// A soft shadow under the white cards.
List<BoxShadow> softShadow([double a = .07]) => [BoxShadow(color: const Color(0xFF0E3B1C).withValues(alpha: a), blurRadius: 22, offset: const Offset(0, 8))];

ThemeData appTheme() {
  final base = ThemeData(useMaterial3: true, fontFamily: 'Rubik', colorScheme: ColorScheme.fromSeed(seedColor: C.green, surface: C.bg, primary: C.green));
  TextStyle t(double s, FontWeight w, [Color c = C.ink]) => TextStyle(fontFamily: 'Rubik', fontFamilyFallback: kFonts, fontSize: s, fontWeight: w, color: c, height: 1.25);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    splashFactory: InkSparkle.splashFactory,
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
    appBarTheme: AppBarTheme(backgroundColor: C.bg, surfaceTintColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, foregroundColor: C.ink, titleTextStyle: t(21, FontWeight.w700), centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.green, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.red)),
      labelStyle: t(15, FontWeight.w400, C.muted),
      hintStyle: t(15, FontWeight.w400, C.faint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(58), shape: const StadiumBorder(), textStyle: t(17, FontWeight.w600, Colors.white)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: C.ink, minimumSize: const Size.fromHeight(52), shape: const StadiumBorder(), side: const BorderSide(color: C.line), textStyle: t(16, FontWeight.w600)),
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
