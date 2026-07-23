class AuthLock {
  static bool isAuthenticating = false;
  static DateTime? lastSuccess;
  static bool isFullScreenActive = false;
  static DateTime? skipUntil; 
}