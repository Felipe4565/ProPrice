import 'package:flutter/material.dart';

/// Palette de tons pour ProPrice.
/// Chaque ramp va de 50 (le plus clair) à 900 (le plus foncé).
/// Usage :
///  - 50/100  → fonds de badges, chips, cartes très légères
///  - 200/300 → bordures, états désactivés, icônes secondaires
///  - 400     → accents, liens, éléments interactifs secondaires
///  - 500     → couleur de marque (celle que vous utilisiez déjà)
///  - 600/700 → texte sur fond clair, boutons pressés (hover/active)
///  - 800/900 → texte à fort contraste, mode sombre
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------
  // FOREST — couleur primaire (identité verte de l'app)
  // ---------------------------------------------------------------------
  static const forest50 = Color(0xFFEAF3EC);
  static const forest100 = Color(0xFFC9E3D1);
  static const forest200 = Color(0xFF96C7A4);
  static const forest300 = Color(0xFF5FA374);
  static const forest400 = Color(0xFF397C52);
  static const forest500 = Color(0xFF1B4332); // = votre forestGreen d'origine
  static const forest600 = Color(0xFF163829);
  static const forest700 = Color(0xFF112B20);
  static const forest800 = Color(0xFF0C1F17);
  static const forest900 = Color(0xFF081410);

  // ---------------------------------------------------------------------
  // TERRACOTTA — accent chaud (remplace l'orange générique pour les CTA,
  // favoris, badges "Pro", alertes de prix)
  // ---------------------------------------------------------------------
  static const terracotta50 = Color(0xFFFBF0E7);
  static const terracotta100 = Color(0xFFF3D5BC);
  static const terracotta200 = Color(0xFFE8AF83);
  static const terracotta300 = Color(0xFFD98A52);
  static const terracotta400 = Color(0xFFC86A2E);
  static const terracotta500 = Color(0xFFB0501B); // accent de marque
  static const terracotta600 = Color(0xFF8E3F15);
  static const terracotta700 = Color(0xFF6C2F10);
  static const terracotta800 = Color(0xFF4A1F0A);
  static const terracotta900 = Color(0xFF2E1306);

  // ---------------------------------------------------------------------
  // NEUTRAL — fond crème et surfaces (remplace le backgroundCream unique)
  // ---------------------------------------------------------------------
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF8F6F1);
  static const neutral100 = Color(0xFFF2EFE9); // = votre backgroundCream d'origine
  static const neutral200 = Color(0xFFE8E3D9);
  static const neutral300 = Color(0xFFD8D1C2);

  // ---------------------------------------------------------------------
  // SÉMANTIQUE — variations de prix, statuts d'alerte
  // ---------------------------------------------------------------------
  static const priceUp = Color(0xFF2E7D4F);   // hausse (vert distinct du forest, plus vif)
  static const priceDown = Color(0xFFC44536); // baisse (rouge chaud, cohérent avec la palette)
  static const warning = Color(0xFFD98A52);   // = terracotta300, pour badges "attention"
  static const danger = Color(0xFFB3261E);

  // ---------------------------------------------------------------------
  // Helpers pratiques (raccourcis vers les tons les plus utilisés)
  // ---------------------------------------------------------------------
  static const primary = forest500;
  static const primaryDark = forest700;
  static const accent = terracotta500;
  static const background = neutral100;
  static const surface = neutral0;
}