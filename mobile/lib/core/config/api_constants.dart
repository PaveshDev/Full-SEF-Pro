class ApiConstants {
  // When using USB debugging with `adb reverse tcp:5080 tcp:5080`,
  // the phone communicates with the host machine via localhost:5080.
  // For standard Android Emulator without adb reverse, use 10.0.2.2:5080.
  static const String baseUrl = 'http://localhost:5080/api';
  static const String serverUrl = 'http://localhost:5080';

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
