import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_lock.dart';
import 'navigation_service.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Mots-clés présents dans les erreurs natives quand l'appareil n'a
  /// AUCUN verrouillage d'écran configuré (ni PIN, ni schéma, ni empreinte,
  /// ni Face ID). Ce n'est pas un bug : le système refuse de proposer la
  /// biométrie tant qu'il n'y a rien à vérifier.
  /// - Android : "noCredentialsSet", "NotEnrolled"
  /// - iOS     : "PasscodeNotSet"
  static const _noCredentialsKeywords = [
    'noCredentialsSet',
    'NotEnrolled',
    'PasscodeNotSet',
  ];

  Future<bool> authenticate({String reason = 'Authentification requise'}) async {
    if (AuthLock.isFullScreenActive) {
      return false;
    }

    final now = DateTime.now();

    // 🛡️ Ignore la demande si on sort tout juste du plein écran (transitions de rotation)
    if (AuthLock.skipUntil != null && now.isBefore(AuthLock.skipUntil!)) {
      return false;
    }

    // 🔥 GLOBAL LOCK
    if (AuthLock.isAuthenticating) return false;

    if (AuthLock.lastSuccess != null &&
        now.difference(AuthLock.lastSuccess!).inSeconds < 3) {
      return false;
    }

    AuthLock.isAuthenticating = true;

    try {
      final result = await _auth.authenticate(
        localizedReason: reason,
      );

      if (result) {
        AuthLock.lastSuccess = DateTime.now();
        HapticFeedback.mediumImpact();
      }

      return result;
    } catch (e) {
      final errorText = e.toString();
      final isNoCredentialsError =
      _noCredentialsKeywords.any((keyword) => errorText.contains(keyword));

      if (isNoCredentialsError) {
        debugPrint('[Biometric] Aucun verrouillage configuré sur l\'appareil : $errorText');
        _showNoCredentialsMessage();
        return false;
      }

      // Autre erreur inattendue (capteur défaillant, permission refusée, etc.)
      // : on log et on échoue proprement plutôt que de crasher l'app.
      debugPrint('[Biometric] Erreur inattendue lors de l\'authentification : $errorText');
      return false;
    } finally {
      AuthLock.isAuthenticating = false;
    }
  }

  void _showNoCredentialsMessage() {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Configura un bloqueo de pantalla (PIN, patrón o huella) en tu teléfono para activar esta función.',
        ),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}