import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// Проста обгортка: спочатку пробує Keychain, якщо не працює — пам'ять.
class _TokenStorage {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final Map<String, String> _mem = {};
  bool _useMemory = false;

  Future<String?> read({required String key}) async {
    if (_useMemory) return _mem[key];
    try {
      return await _secure.read(key: key);
    } catch (_) {
      _useMemory = true;
      debugPrint('⚠️ Keychain недоступний, токени зберігаються в пам\'яті');
      return _mem[key];
    }
  }

  Future<void> write({required String key, required String value}) async {
    if (_useMemory) {
      _mem[key] = value;
      return;
    }
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {
      _useMemory = true;
      _mem[key] = value;
      debugPrint('⚠️ Keychain недоступний, токени зберігаються в пам\'яті');
    }
  }

  Future<void> delete({required String key}) async {
    _mem.remove(key);
    if (!_useMemory) {
      try {
        await _secure.delete(key: key);
      } catch (_) {}
    }
  }
}

/// Сервіс для HTTP-запитів до CLIX API.
/// Автоматично додає JWT-токен у заголовки.
class ApiService {
  late final Dio _dio;
  final _TokenStorage _storage = _TokenStorage();

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Interceptor: автоматично додаємо JWT-токен
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Якщо 401 — спробуємо оновити токен
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Повторюємо оригінальний запит
              final token = await _storage.read(key: 'access_token');
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  // ── Авторизація ──

  /// Логін: повертає JWT-токени + ролі
  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await _dio.post(
      ApiConfig.login,
      data: {'phone_number': phone, 'password': password},
    );
    final data = response.data;
    // Зберігаємо токени
    await _storage.write(key: 'access_token', value: data['access']);
    await _storage.write(key: 'refresh_token', value: data['refresh']);
    return data;
  }

  /// GET-запит до довільного URL (наприклад Nominatim reverse geocoding)
  Future<Map<String, dynamic>?> rawGet(String url) async {
    try {
      final resp = await Dio().get<Map<String, dynamic>>(
        url,
        options: Options(headers: {'User-Agent': 'CLIX-App/1.0'}),
      );
      return resp.data;
    } catch (_) {
      return null;
    }
  }

  /// Реєстрація
  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    String? firstName,
    String? lastName,
    List<String> roles = const ['PASSENGER'],
  }) async {
    final response = await _dio.post(
      ApiConfig.register,
      data: {
        'phone_number': phone,
        'password': password,
        'first_name': firstName ?? '',
        'last_name': lastName ?? '',
        'roles': roles,
      },
    );
    return response.data;
  }

  /// Оновлення JWT-токена
  Future<bool> _refreshToken() async {
    try {
      final refresh = await _storage.read(key: 'refresh_token');
      if (refresh == null) return false;

      final response = await Dio(
        BaseOptions(baseUrl: ApiConfig.baseUrl),
      ).post(ApiConfig.tokenRefresh, data: {'refresh': refresh});

      await _storage.write(key: 'access_token', value: response.data['access']);
      if (response.data['refresh'] != null) {
        await _storage.write(
          key: 'refresh_token',
          value: response.data['refresh'],
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Вийти з системи
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  /// Перевірка наявності збереженого токена
  Future<bool> hasToken() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  // ── Профіль ──

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get(ApiConfig.me);
    return response.data;
  }

  // ── Водій ──

  Future<Map<String, dynamic>> getDriverStatus() async {
    final response = await _dio.get(ApiConfig.driverStatus);
    return response.data;
  }

  Future<Map<String, dynamic>> updateDriverStatus(
    String status, {
    double? lat,
    double? lng,
  }) async {
    final data = <String, dynamic>{'status': status};
    if (lat != null) data['lat'] = lat;
    if (lng != null) data['lng'] = lng;
    final response = await _dio.patch(ApiConfig.driverStatus, data: data);
    return response.data;
  }

  Future<void> updateDriverLocation(double lat, double lng) async {
    await _dio.post(ApiConfig.driverLocation, data: {'lat': lat, 'lng': lng});
  }

  // ── Замовлення (пасажир) ──

  Future<Map<String, dynamic>> createPassengerOrder({
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required String pickupTime,
    String requiredClass = 'ECONOMY',
    double? estimatedPrice,
  }) async {
    final response = await _dio.post(
      ApiConfig.passengerCreateOrder,
      data: {
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'pickup_time': pickupTime,
        'required_class': requiredClass,
        'estimated_price': estimatedPrice,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>?> getActiveOrder() async {
    try {
      final response = await _dio.get(ApiConfig.passengerActiveOrder);
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Замовлення (водій) ──

  Future<List<dynamic>> getAvailableOrders() async {
    final response = await _dio.get(ApiConfig.availableOrders);
    return response.data['results'] ?? response.data;
  }

  Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    final response = await _dio.post(ApiConfig.acceptOrder(orderId));
    return response.data;
  }

  /// Активне замовлення водія (відновлення стану після перемикання ролей)
  Future<Map<String, dynamic>?> getDriverActiveOrder() async {
    try {
      final response = await _dio.get(ApiConfig.driverActiveOrder);
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> rejectOrder(String orderId) async {
    await _dio.post(ApiConfig.rejectOrder(orderId));
  }

  Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status,
  ) async {
    final response = await _dio.patch(
      ApiConfig.updateOrderStatus(orderId),
      data: {'status': status},
    );
    return response.data;
  }

  // ── Відгуки ──

  Future<void> createReview({
    required String orderId,
    required int rating,
    String comment = '',
    bool isComplaint = false,
  }) async {
    await _dio.post(
      ApiConfig.createReview(orderId),
      data: {'rating': rating, 'comment': comment, 'is_complaint': isComplaint},
    );
  }

  // ── Історія ──

  Future<List<dynamic>> getOrderHistory() async {
    final response = await _dio.get(ApiConfig.ordersHistory);
    return response.data['results'] ?? response.data;
  }

  // ── Диспетчер ──

  Future<List<dynamic>> getDispatcherOrders() async {
    final response = await _dio.get(ApiConfig.dispatcherOrderList);
    return response.data['results'] ?? response.data;
  }

  Future<List<dynamic>> getComplaints() async {
    final response = await _dio.get(ApiConfig.dispatcherComplaints);
    return response.data['results'] ?? response.data;
  }

  Future<Map<String, dynamic>> createDispatcherOrder({
    required String passengerPhone,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required String pickupTime,
    String requiredClass = 'ECONOMY',
  }) async {
    final response = await _dio.post(
      ApiConfig.dispatcherCreateOrder,
      data: {
        'passenger_phone': passengerPhone,
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'pickup_time': pickupTime,
        'required_class': requiredClass,
      },
    );
    return response.data;
  }
}
