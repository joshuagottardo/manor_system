import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- PALETTE COLORI PREMIUM ---
  
  // Sfondo: Nero assoluto per OLED
  static const Color background = Color(0xFF000000); 
  
  // Surface: Un grigio scurissimo, quasi nero, per distinguere le card
  static const Color surface = Color(0xFF141414);
  
  // Accento: Un "Electric Blue" o "Cyber Mint" per indicare l'azione
  // (Puoi cambiarlo in Gold 0xFFD4AF37 se vuoi un look "Hotel 5 Stelle")
  static const Color primary = Color(0xFF2196F3); 
  static const Color accent = Color(0xFF00E676); // Verde acceso per "ON"

  // Testi
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);

  // --- CONFIGURAZIONE TEMA ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      
      // Definiamo il font OUTFIT globalmente
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),

      // AppBar minimalista
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // Card Theme base
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      
      // Color Scheme per i componenti standard
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        surfaceTint: Colors.transparent,
        onSurface: textPrimary,
      ),
    );
  }
}