/// Сервіс маршрутизації через OSRM (безкоштовний).
/// Повертає список точок маршруту для малювання polyline на карті.
library;
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'User-Agent': 'CLIX-App/1.0'},
    ),
  );

  /// Отримати маршрут між двома точками.
  /// Повертає список LatLng для polyline або null при помилці.
  Future<List<LatLng>?> getRoute(LatLng from, LatLng to) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=polyline';

      final resp = await _dio.get(url);
      final data = resp.data;

      if (data['code'] != 'Ok' ||
          data['routes'] == null ||
          data['routes'].isEmpty) {
        return null;
      }

      final geometry = data['routes'][0]['geometry'] as String;
      return _decodePolyline(geometry);
    } catch (e) {
      print('⚠️ Routing error: $e');
      return null;
    }
  }

  /// Отримати маршрут + тривалість/відстань.
  Future<RouteInfo?> getRouteInfo(LatLng from, LatLng to) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=polyline';

      final resp = await _dio.get(url);
      final data = resp.data;

      if (data['code'] != 'Ok' ||
          data['routes'] == null ||
          data['routes'].isEmpty) {
        return null;
      }

      final route = data['routes'][0];
      final geometry = route['geometry'] as String;
      final durationSec = (route['duration'] as num).toDouble();
      final distanceM = (route['distance'] as num).toDouble();

      return RouteInfo(
        points: _decodePolyline(geometry),
        durationMinutes: (durationSec / 60).ceil(),
        distanceKm: distanceM / 1000,
      );
    } catch (e) {
      print('⚠️ Routing error: $e');
      return null;
    }
  }

  /// Декодування Google-формату polyline у список LatLng.
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

/// Інформація про маршрут: точки, час, відстань.
class RouteInfo {
  final List<LatLng> points;
  final int durationMinutes;
  final double distanceKm;

  RouteInfo({
    required this.points,
    required this.durationMinutes,
    required this.distanceKm,
  });
}
