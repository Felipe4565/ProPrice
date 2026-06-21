class AuthManager {
  // Singleton
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  AuthManager._internal();

  bool isAuthenticating = false;

  bool hasCheckedBiometric = false;

  bool isSessionUnlocked = false;

  void resetSession() {
    isSessionUnlocked = false;
    hasCheckedBiometric = false;
  }
}