import 'app_config.dart';

class ApiConstants {
  // Uses build-time environment variable if supplied (e.g. --dart-define=API_BASE_URL=http://192.168.132.26:5080),
  // otherwise defaults to http://localhost:5080.
  static const String serverUrl = AppConfig.apiBaseUrl;
  static String get baseUrl => '$serverUrl/api';

  static String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) {
      return '$serverUrl$path';
    }
    return '$serverUrl/$path';
  }

  // Sri Lankan Districts (matching web app)
  static const List<String> sriLankanDistricts = [
    'Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo',
    'Galle', 'Gampaha', 'Hambantota', 'Jaffna', 'Kalutara',
    'Kandy', 'Kegalle', 'Kilinochchi', 'Kurunegala', 'Mannar',
    'Matale', 'Matara', 'Monaragala', 'Mullaitivu', 'Nuwara Eliya',
    'Polonnaruwa', 'Puttalam', 'Ratnapura', 'Trincomalee', 'Vavuniya'
  ];
}
