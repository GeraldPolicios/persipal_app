// lib/widgets/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // ─── Brand Colors ─────────────────────────────────────────────────────────
  static const cream = Color(0xFFFFE6CC);
  static const creamLight = Color(0xFFFFF5EE);
  static const salmon = Color(0xFFFF8C69);
  static const mauve = Color(0xFFD49BC0);
  static const lavender = Color(0xFF7B68EE);
  static const teal = Color(0xFF20B2AA);
  static const gold = Color(0xFFFFA500);
  static const softBrown = Color(0xFFAA7755);
  static const darkBrown = Color(0xFF6B3F2A);
  static const cardWhite = Color(0xFFFFFAF5);
  static const darkText = Color(0xFF7A3B1E);

  // ─── Text Styles ──────────────────────────────────────────────────────────
  static const TextStyle displayLg = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 1,
    color: darkBrown,
  );
  static const TextStyle displayMd = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: darkBrown,
  );
  static const TextStyle titleSm = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: darkBrown,
  );
  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: Color(0xFF7A5C45),
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: softBrown,
  );

  // ─── Theme Data ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(
          seedColor: salmon,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          elevation: 0,
          centerTitle: false,
          foregroundColor: darkBrown,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: salmon,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: creamLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: salmon.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: salmon, width: 1.5),
          ),
        ),
      );

  // ─── Decorations ──────────────────────────────────────────────────────────
  static BoxDecoration cardDecoration({
    Color? color,
    double radius = 20,
    List<BoxShadow>? shadows,
  }) =>
      BoxDecoration(
        color: color ?? cardWhite,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
      );

  static BoxDecoration gradientCard({double radius = 20}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD4B8), Color(0xFFFFBFA0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: salmon.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      );

  // ─── Stat bar colors ──────────────────────────────────────────────────────
  static Color statColor(String stat) {
    switch (stat) {
      case 'hunger':
        return Colors.redAccent;
      case 'happiness':
        return Colors.pinkAccent;
      case 'cleanliness':
        return Colors.teal;
      case 'energy':
        return Colors.amber;
      case 'health':
        return Colors.green;
      default:
        return salmon;
    }
  }

  // ─── Paw background ───────────────────────────────────────────────────────
  static Widget pawBackground({double opacity = 0.10}) => Positioned.fill(
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            'assets/images/paws_bg.png',
            fit: BoxFit.cover,
          ),
        ),
      );
}
