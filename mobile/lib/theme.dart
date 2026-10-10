// Sajag design system — ported from the team's InstaJob DESIGN_SYSTEM.md:
// white canvas, #FAFAFA modules, 1px #EDEDED borders, #111 pill CTAs, 24/16/12 radii, painterly art accents,
// no heavy shadows, no neon. Nepali text falls back to Mukta so Devanagari is shaped and sized well.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const canvas = Color(0xFFFFFFFF);
  static const module = Color(0xFFFAFAFA);
  static const raised = Color(0xFFFFFFFF);
  static const border = Color(0xFFEDEDED);
  static const borderHover = Color(0xFFCCCCCC);
  static const ink = Color(0xFF111111);
  static const ink2 = Color(0xFF555555);
  static const muted = Color(0xFF888888);
  static const pill = Color(0xFFEFEFEF);

  // Risk colours: earthy, not neon.
  static const high = Color(0xFFB42318);
  static const highBg = Color(0xFFFDF0EE);
  static const caution = Color(0xFF9A5B0B);
  static const cautionBg = Color(0xFFFFF5E6);
  static const low = Color(0xFF2F6B3E);
  static const lowBg = Color(0xFFEEF5EF);
  static const info = Color(0xFF3B5B7A);
  static const infoBg = Color(0xFFEEF2F6);
  static const sage = Color(0xFF6E7F63);
}

class R {
  static const section = 24.0;
  static const card = 16.0;
  static const field = 12.0;
}

TextStyle _base() => GoogleFonts.inter().copyWith(
      fontFamilyFallback: [GoogleFonts.mukta().fontFamily!],
      color: C.ink,
    );

class T {
  static TextStyle hero = _base().copyWith(fontSize: 34, fontWeight: FontWeight.w700, height: 1.08, letterSpacing: -1.0);
  static TextStyle h1 = _base().copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.6);
  static TextStyle h2 = _base().copyWith(fontSize: 19, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.2);
  static TextStyle h3 = _base().copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3);
  static TextStyle body = _base().copyWith(fontSize: 15, height: 1.55, color: C.ink2);
  static TextStyle bodyInk = _base().copyWith(fontSize: 15, height: 1.55);
  static TextStyle small = _base().copyWith(fontSize: 13, height: 1.45, color: C.ink2);
  static TextStyle meta = _base().copyWith(fontSize: 12, height: 1.4, color: C.muted);
  static TextStyle label = _base().copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: C.ink2, letterSpacing: 0.2);
  static TextStyle pill = _base().copyWith(fontSize: 12, fontWeight: FontWeight.w600);
}

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, colorSchemeSeed: C.ink, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: C.canvas,
    textTheme: base.textTheme.apply(fontFamily: GoogleFonts.inter().fontFamily, bodyColor: C.ink, displayColor: C.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: C.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: C.ink,
      titleTextStyle: T.h3,
    ),
    dividerColor: C.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.module,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: T.small.copyWith(color: C.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.field), borderSide: const BorderSide(color: C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.field), borderSide: const BorderSide(color: C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.field), borderSide: const BorderSide(color: C.ink)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.ink,
      contentTextStyle: T.small.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.field)),
    ),
  );
}

/// Colour pair for a risk level string from the API.
({Color fg, Color bg}) levelColors(String level) => switch (level) {
      'high' => (fg: C.high, bg: C.highBg),
      'caution' => (fg: C.caution, bg: C.cautionBg),
      'low' => (fg: C.low, bg: C.lowBg),
      _ => (fg: C.info, bg: C.infoBg),
    };

({Color fg, Color bg}) severityColors(String severity) => switch (severity) {
      'high' => (fg: C.high, bg: C.highBg),
      'medium' => (fg: C.caution, bg: C.cautionBg),
      _ => (fg: C.info, bg: C.infoBg),
    };
