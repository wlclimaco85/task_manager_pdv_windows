import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PdvColors {
  PdvColors._();

  // Fundo principal escuro de alta performance (sem cansaço visual)
  static const Color background = Color(0xFF0F172A);      // Slate 900
  static const Color surface = Color(0xFF1E293B);         // Slate 800
  static const Color surfaceLight = Color(0xFF334155);    // Slate 700
  static const Color surfaceDark = Color(0xFF0B0F19);

  // Bobina térmica eletrônica
  static const Color bobinaBackground = Color(0xFF182234);
  static const Color bobinaRowEven = Color(0xFF1E293B);
  static const Color bobinaRowOdd = Color(0xFF162032);
  static const Color bobinaBorder = Color(0xFF334155);

  // Destaques e Acentos
  static const Color primary = Color(0xFF3B82F6);         // Azul vibrante
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color accent = Color(0xFF06B6D4);          // Ciano

  // Indicadores de status
  static const Color success = Color(0xFF10B981);         // Verde Esmeralda (Total / Venda / Online)
  static const Color warning = Color(0xFFF59E0B);         // Âmbar (Atenção / Contingência)
  static const Color error = Color(0xFFEF4444);           // Vermelho (Cancelamento / Erro)
  static const Color cancelled = Color(0xFF7F1D1D);       // Fundo de item cancelado

  // Textos
  static const Color textPrimary = Color(0xFFF8FAFC);     // Quase branco
  static const Color textSecondary = Color(0xFF94A3B8);   // Cinza suave
  static const Color textMuted = Color(0xFF64748B);       // Cinza escuro
  static const Color totalHighlight = Color(0xFF34D399);  // Verde neon de alta visibilidade
}

class PdvTheme {
  PdvTheme._();

  static ThemeData get theme {
    final baseText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PdvColors.background,
      colorScheme: const ColorScheme.dark(
        primary: PdvColors.primary,
        secondary: PdvColors.accent,
        surface: PdvColors.surface,
        error: PdvColors.error,
        onPrimary: Colors.white,
        onSurface: PdvColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: baseText.copyWith(
        displayLarge: GoogleFonts.robotoMono(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: PdvColors.totalHighlight,
        ),
        displayMedium: GoogleFonts.robotoMono(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: PdvColors.totalHighlight,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: PdvColors.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PdvColors.surfaceLight,
        labelStyle: const TextStyle(color: PdvColors.textSecondary),
        hintStyle: const TextStyle(color: PdvColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: PdvColors.surfaceLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: PdvColors.surfaceLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: PdvColors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PdvColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}
