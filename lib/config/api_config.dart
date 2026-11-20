import 'package:flutter/foundation.dart';

/// Central API configuration.
///
/// HOW TO SWITCH ENVIRONMENTS
/// ──────────────────────────
/// Set [_env] to one of the [_Env] values and do a FULL RESTART (not hot reload).
///
///   • [_Env.studentWebHost]  → StudentWebHost at http://10.19.5.233:8088
///                              PHP files are inside /adam_haris_amran/backend/
///
///   • [_Env.androidEmulator] → Android emulator loopback http://10.0.2.2:5173
///                              Run: php -S 0.0.0.0:5173 -t backend
///
///   • [_Env.localWifi]       → Physical device over LAN — set [_lanIp] to your
///                              PC's local IP (run `ipconfig` on Windows).
///                              Run: php -S 0.0.0.0:5173 -t backend
///
/// IMPORTANT: Every URL is printed to the debug console on startup.
/// Confirm the register/login URLs look correct before testing.

enum _Env { studentWebHost, androidEmulator, localWifi, localhost }

// ─── Change this one constant to switch environments ───────────────────────
// Set to _Env.androidEmulator (for Android Emulator)
// or _Env.localWifi (for physical device over Wi-Fi)
// or _Env.localhost (for Chrome / Desktop / Web)
const _Env _env = _Env.androidEmulator;

/// LAN IP of your PC when using [_Env.localWifi].
/// Current PC Wi-Fi IP is '10.117.142.49' (run `ipconfig` on Windows to check).
const String _lanIp = '10.117.142.49';
// ───────────────────────────────────────────────────────────────────────────

class ApiConfig {
  ApiConfig._();

  static const String _studentHost   = 'http://10.19.5.233:8088';
  static const String _studentFolder = '/adam_haris_amran/backend';

  static String get _base {
    switch (_env) {
      case _Env.studentWebHost:
        // Verified working: curl returns HTTP 405 application/json at this path.
        // http://10.19.5.233:8088/adam_haris_amran/backend/register.php → 405 ✓
        return '$_studentHost$_studentFolder';
      case _Env.androidEmulator:
        // php -S 0.0.0.0:5173 -t backend  →  emulator reaches host via 10.0.2.2
        return 'http://10.0.2.2:5173';
      case _Env.localWifi:
        // php -S 0.0.0.0:5173 -t backend  →  device on same Wi-Fi
        return 'http://$_lanIp:5173';
      case _Env.localhost:
        // For Chrome or desktop app
        return 'http://127.0.0.1:5173';
    }
  }

  /// Builds an endpoint URL with exactly one slash between base and filename.
  static String _ep(String file) {
    final base = _base.endsWith('/') ? _base : '$_base/';
    final f    = file.startsWith('/') ? file.substring(1) : file;
    return '$base$f';
  }

  static String get baseUrl    => _base;
  static String get register   => _ep('register.php');
  static String get login      => _ep('login.php');
  static String get profile    => _ep('profile.php');
  static String get logout     => _ep('logout.php');

  /// Health-check: a GET without a token returns 401 JSON, proving the server
  /// and PHP pipeline are working end-to-end.
  static String get healthCheck => _ep('profile.php');

  /// Logs every endpoint URL to the debug console on startup.
  /// Watch for these lines after a full restart to confirm URLs are correct.
  static void debugPrintConfig() {
    if (!kDebugMode) return;
    debugPrint('=== ApiConfig (env: $_env) ===');
    debugPrint('  baseUrl  : $baseUrl');
    debugPrint('  register : $register');
    debugPrint('  login    : $login');
    debugPrint('  profile  : $profile');
    debugPrint('  logout   : $logout');
    debugPrint('==============================');
  }
}
