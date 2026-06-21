import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_lock.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate({String reason = 'Authentification requise'}) async {

    final now = DateTime.now();

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