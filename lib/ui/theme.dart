/* DESIGN 6 – "Big Tiles" (chosen 14-10-2026): big coloured squares with Marathi names, soft green surfaces, Rubik. */
import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFFF3F7F2);
  static const card = Colors.white;
  static const ink = Color(0xFF17251A);
  static const muted = Color(0xFF5C6D60);
  static const line = Color(0xFFD5E0D6);
  static const green = Color(0xFF2E7D32);
  static const greenDark = Color(0xFF1B5E20);
  static const greenSoft = Color(0xFFDDEFD9);
  static const greenChip = Color(0xFFCDE8C8);
  static const blue = Color(0xFF1565C0);
  static const blueSoft = Color(0xFFDCE8F8);
  static const purple = Color(0xFF6A1B9A);
  static const purpleSoft = Color(0xFFEDE0F5);
  static const red = Color(0xFFC62828);
  static const redSoft = Color(0xFFFDECEA);
  static const amber = Color(0xFFB26A00);
  static const amberSoft = Color(0xFFFFF3D6);
}

const kFonts = ['NotoDeva']; // Marathi / Hindi letters come from Noto Sans Devanagari

ThemeData appTheme() {
  final base = ThemeData(useMaterial3: true, fontFamily: 'Rubik', colorScheme: ColorScheme.fromSeed(seedColor: C.green, surface: C.bg, primary: C.green));
  TextStyle t(double s, FontWeight w, [Color c = C.ink]) => TextStyle(fontFamily: 'Rubik', fontFamilyFallback: kFonts, fontSize: s, fontWeight: w, color: c, height: 1.25);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
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
    appBarTheme: AppBarTheme(backgroundColor: C.bg, surfaceTintColor: Colors.transparent, elevation: 0, foregroundColor: C.ink, titleTextStyle: t(21, FontWeight.w700), centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.green, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.red)),
      labelStyle: t(15, FontWeight.w400, C.muted),
      hintStyle: t(15, FontWeight.w400, C.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(58), shape: const StadiumBorder(), textStyle: t(17, FontWeight.w600, Colors.white)),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: C.ink, contentTextStyle: t(14.5, FontWeight.w500, Colors.white), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: C.greenChip,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => t(12, s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500, s.contains(WidgetState.selected) ? C.greenDark : C.muted)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? C.greenDark : C.muted)),
    ),
  );
}
