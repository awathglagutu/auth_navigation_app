class ApiConfig {
  // For Android emulator local development, use http://10.0.2.2:8000.
  // Replace with your PHP server's reachable address or hosted HTTPS URL.
  static const String baseUrl = 'http://10.19.1.21:5173';

  static String get register => '$baseUrl/register.php';
  static String get login => '$baseUrl/login.php';
  static String get profile => '$baseUrl/profile.php';
  static String get logout => '$baseUrl/logout.php';
}
