class AuthLock {
  static bool isAuthenticating = false;
  static DateTime? lastSuccess;
}