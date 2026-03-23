import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Результат пошуку адреси
class AddressSuggestion {
  final String displayName;
  final String shortName;
  final double lat;
  final double lng;

  AddressSuggestion({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lng,
  });

  factory AddressSuggestion.fromNominatim(Map<String, dynamic> json) {
    final display = json['display_name'] ?? '';
    // Скорочуємо назву: беремо перші 2-3 частини
    final parts = display.split(', ');
    final short = parts.take(3).join(', ');

    return AddressSuggestion(
      displayName: display,
      shortName: short,
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0,
      lng: double.tryParse(json['lon']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Сервіс пошуку адрес через Nominatim (OpenStreetMap).
/// Безкоштовний, без API-ключа. Обмеження: 1 запит/секунду.
class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'User-Agent': 'CLIX-Taxi-App/1.0',
        'Accept-Language': 'uk,cs,en',
      },
    ),
  );

  // Місто за замовчуванням — Львів
  static const String _defaultCity = 'Львів';
  static const String _defaultCountry = 'ua';

  // Обмежуємо пошук регіоном Львова (viewbox)
  static const String _viewbox = '23.90,49.90,24.15,49.78';

  GeocodingService._internal();

  /// Пошук адрес за текстом (автокомпліт)
  Future<List<AddressSuggestion>> searchAddress(String query) async {
    if (query.trim().length < 2) return [];

    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {
          'q': '$query, $_defaultCity',
          'format': 'json',
          'addressdetails': '1',
          'limit': '5',
          'countrycodes': _defaultCountry,
          'viewbox': _viewbox,
          'bounded': '1',
        },
      );

      final List results = response.data;
      return results.map((r) => AddressSuggestion.fromNominatim(r)).toList();
    } catch (e) {
      debugPrint('⚠️ Geocoding error: $e');
      return [];
    }
  }

  /// Зворотнє геокодування: координати → адреса
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        '/reverse',
        queryParameters: {
          'lat': lat.toString(),
          'lon': lng.toString(),
          'format': 'json',
        },
      );
      return response.data['display_name'];
    } catch (e) {
      debugPrint('⚠️ Reverse geocoding error: $e');
      return null;
    }
  }
}
