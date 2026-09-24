import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Thème global de ProPrice construit sur AppColors.
/// À brancher dans main.dart : MaterialApp(theme: AppTheme.light, ...)
///
/// Typographie : Manrope pour les titres/prix (impact, chiffres nets),
/// Inter pour le texte courant (lisibilité). Les deux sont chargées et
/// mises en cache par google_fonts au premier lancement.
class AppTheme {
  AppTheme._();

  /// TextTheme de base : Inter partout, puis on réhausse les styles
  /// "titres" avec Manrope pour créer une vraie hiérarchie visuelle.
  static TextTheme get _textTheme {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.manrope(fontWeight: FontWeight.w900),
      displayMedium: GoogleFonts.manrope(fontWeight: FontWeight.w800),
      displaySmall: GoogleFonts.manrope(fontWeight: FontWeight.w800),
      headlineLarge: GoogleFonts.manrope(fontWeight: FontWeight.w800),
      headlineMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w600),
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,

      // Police par défaut de TOUT le texte qui n'a pas de fontFamily
      // explicite (donc la quasi-totalité des Text() existants dans
      // l'appli) : Inter, sans avoir à toucher chaque écran.
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: _textTheme,
      primaryTextTheme: _textTheme,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.forest500,
        primary: AppColors.forest500,
        secondary: AppColors.terracotta500,
        surface: AppColors.surface,
        error: AppColors.danger,
        brightness: Brightness.light,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.forest700,
        titleTextStyle: GoogleFonts.manrope(
          color: AppColors.forest700,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
        iconTheme: const IconThemeData(color: AppColors.forest700),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forest500,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.forest200,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.forest600,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
              ? AppColors.forest500
              : AppColors.neutral0,
        ),
        trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
              ? AppColors.forest300
              : AppColors.neutral300,
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
              ? AppColors.forest500
              : AppColors.neutral300,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral100,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.forest500, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
      ),

      // Barre de navigation basse (Material 3) : indicateur "pill" animé
      // derrière l'icône sélectionnée, plutôt que le BottomNavigationBar
      // classique (icônes + labels statiques) utilisé auparavant.
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.forest500.withValues(alpha: 0.12),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            color: selected
                ? AppColors.forest600
                : AppColors.forest500.withValues(alpha: 0.4),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? AppColors.forest600
                : AppColors.forest500.withValues(alpha: 0.4),
            size: 24,
          );
        }),
      ),
    );
  }

  /// Ombre teintée à utiliser à la place de Colors.black.withOpacity(0.06).
  static List<BoxShadow> softShadow([Color? tint]) => [
    BoxShadow(
      color: (tint ?? AppColors.forest500).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  /// Style "chiffre héros" (gros prix, montants) : toujours Manrope,
  /// quel que soit le poids/la taille demandés. À utiliser à la place
  /// d'un TextStyle brut partout où un prix est affiché en grand.
  static TextStyle priceStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w900,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.manrope(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// Style "titre de marque" (ex. "PROPRICE" sur l'écran de connexion).
  static TextStyle brandTitle({
    required double fontSize,
    Color? color,
    double letterSpacing = 1.5,
  }) => GoogleFonts.manrope(
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: letterSpacing,
  );
}