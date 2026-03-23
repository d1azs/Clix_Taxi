import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфігурація середовища — читає ключі з .env файлу.
/// Використання: Env.googleMapsApiKey
class Env {
  /// Google Maps API ключ
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Перевірка: чи є ключ Google Maps
  static bool get hasGoogleMapsKey =>
      googleMapsApiKey.isNotEmpty && googleMapsApiKey != 'YOUR_API_KEY_HERE';
}
