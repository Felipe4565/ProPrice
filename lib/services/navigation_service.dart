import 'package:flutter/material.dart';

/// Clé globale pour naviguer depuis n'importe où (par exemple au tap sur
/// une notification push), même hors d'un widget avec context.
final navigatorKey = GlobalKey<NavigatorState>();

/// Clé globale pour afficher un SnackBar depuis n'importe où (services,
/// classes non-UI, etc.) sans avoir besoin de transmettre un BuildContext
/// à chaque appel. Utilisée notamment par BiometricService.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();