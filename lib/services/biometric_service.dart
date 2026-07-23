import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_lock.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

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
    } finally {
      AuthLock.isAuthenticating = false;
    }
  }
}