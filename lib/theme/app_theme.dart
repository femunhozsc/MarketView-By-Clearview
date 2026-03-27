import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color black = Color(0xFF0A0A0A);
  static const Color blackCard = Color(0xFF141414);
  static const Color blackLight = Color(0xFF1E1E1E);
  static const Color blackBorder = Color(0xFF2A2A2A);

  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color facebookBlueLight = Color(0xFF4B8EF2);
  static const Color facebookBlueDark = Color(0xFF0A5ED8);

  static const Color gold = facebookBlue;
  static const Color goldLight = facebookBlueLight;
  static const Color goldDark = facebookBlueDark;

  static const Color white = Color(0xFFFFFFFF);
  static const Color whiteSecondary = Color(0xFFB0B0B0);
  static const Color whiteMuted = Color(0xFF6B6B6B);
  static const Color error = Color(0xFFFF4444);
  static const Color success = Color(0xFF44CC88);

  // Fundo claro estilo marketplace
  static const Color lightBg = Color(0xFFF0F2F5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE0E0E0);

  static TextStyle outfit({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.black,
    double? height,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: facebookBlue,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: facebookBlue,
        secondary: facebookBlueLight,
        surface: lightCard,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black87,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: facebookBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: facebookBlue, width: 1.5),
        ),
      ),
      dividerColor: lightBorder,
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      primaryColor: gold,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: goldLight,
        surface: blackCard,
        error: error,
        onPrimary: white,
        onSecondary: white,
        onSurface: white,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: white,
        displayColor: white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        elevation: 0,
        iconTheme: IconThemeData(color: white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: blackLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: blackBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: blackBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
      ),
      dividerColor: blackBorder,
      useMaterial3: true,
    );
  }
}