import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';

/// Провайдер стану для симуляції трансферу Booking.com.
/// Синхронізує свій стан через локальний JSON файл для підтримки мульти-віконного режиму.
class TransferSimulationProvider extends ChangeNotifier {
  String _status = 'NONE';
  
  final String bookingId = 'B-77291';
  final String source = 'Booking.com';
  final String pickupAddress = "Міжнародний аеропорт 'Львів' ім. Д. Галицького";
  final String dropoffAddress = "Готель Nobilis (вул. Фредра, 7)";
  final String passengerName = "Тимофій Горак";
  final String passengerPhone = "+380971234567";
  final String pickupTime = "Сьогодні о 14:30";
  final double price = 450.0;
  final String carClass = "Комфорт";

  // Інформація про призначеного водія
  String _driverName = '';
  String _driverPhone = '';
  double _driverRating = 4.9;
  String _carModel = '';
  String _carNumber = '';

  // Оцінка пасажира після поїздки
  int _passengerRating = 0;
  String _passengerComment = '';

  // Прапорець для авто-розподілу (хто перший забере)
  bool _autoAssign = false;

  // Поточні координати водія під час руху
  double? _driverLat;
  double? _driverLng;
  int _currentRouteIndex = 0;

  // ID замовлення на бекенді для збереження історії та оцінки
  String? _backendOrderId;

  String get status => _status;
  String get driverName => _driverName;
  String get driverPhone => _driverPhone;
  double get driverRating => _driverRating;
  String get carModel => _carModel;
  String get carNumber => _carNumber;
  int get passengerRating => _passengerRating;
  String get passengerComment => _passengerComment;
  bool get autoAssign => _autoAssign;
  double? get driverLat => _driverLat;
  double? get driverLng => _driverLng;
  int get currentRouteIndex => _currentRouteIndex;
  String? get backendOrderId => _backendOrderId;

  // Файл для синхронізації між процесами (вікнами)
  static const String _syncPath = '/Users/tohqa/Боско/Diploma/clix_app/transfer_simulation_state.json';
  Timer? _syncTimer;
  bool _isSaving = false;

  TransferSimulationProvider() {
    _loadStateFromFile();
    // Періодично зчитуємо стан (кожні 0.5 секунди) для швидкої синхронізації вікон
    _syncTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_isSaving) {
        _loadStateFromFile();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  // Зберегти поточний стан у файл JSON
  void _saveStateToFile() {
    _isSaving = true;
    try {
      final file = File(_syncPath);
      final data = {
        'status': _status,
        'driverName': _driverName,
        'driverPhone': _driverPhone,
        'driverRating': _driverRating,
        'carModel': _carModel,
        'carNumber': _carNumber,
        'passengerRating': _passengerRating,
        'passengerComment': _passengerComment,
        'autoAssign': _autoAssign,
        'driverLat': _driverLat,
        'driverLng': _driverLng,
        'currentRouteIndex': _currentRouteIndex,
        'backendOrderId': _backendOrderId,
      };
      file.writeAsStringSync(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving simulation state: $e');
    } finally {
      _isSaving = false;
    }
  }

  // Зчитати стан з файлу JSON
  void _loadStateFromFile() {
    try {
      final file = File(_syncPath);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      if (content.isEmpty) return;

      final data = jsonDecode(content) as Map<String, dynamic>;
      
      final newStatus = data['status'] ?? 'NONE';
      final newDriverName = data['driverName'] ?? '';
      final newDriverPhone = data['driverPhone'] ?? '';
      final newDriverRating = (data['driverRating'] ?? 4.9).toDouble();
      final newCarModel = data['carModel'] ?? '';
      final newCarNumber = data['carNumber'] ?? '';
      final newPassengerRating = data['passengerRating'] ?? 0;
      final newPassengerComment = data['passengerComment'] ?? '';
      final newAutoAssign = data['autoAssign'] ?? false;
      final newDriverLat = data['driverLat'] != null ? (data['driverLat'] as num).toDouble() : null;
      final newDriverLng = data['driverLng'] != null ? (data['driverLng'] as num).toDouble() : null;
      final newCurrentRouteIndex = data['currentRouteIndex'] ?? 0;
      final newBackendOrderId = data['backendOrderId'] as String?;

      // Перевіряємо, чи змінилися дані
      if (_status != newStatus ||
          _driverName != newDriverName ||
          _driverPhone != newDriverPhone ||
          _driverRating != newDriverRating ||
          _carModel != newCarModel ||
          _carNumber != newCarNumber ||
          _passengerRating != newPassengerRating ||
          _passengerComment != newPassengerComment ||
          _autoAssign != newAutoAssign ||
          _driverLat != newDriverLat ||
          _driverLng != newDriverLng ||
          _currentRouteIndex != newCurrentRouteIndex ||
          _backendOrderId != newBackendOrderId) {
        
        _status = newStatus;
        _driverName = newDriverName;
        _driverPhone = newDriverPhone;
        _driverRating = newDriverRating;
        _carModel = newCarModel;
        _carNumber = newCarNumber;
        _passengerRating = newPassengerRating;
        _passengerComment = newPassengerComment;
        _autoAssign = newAutoAssign;
        _driverLat = newDriverLat;
        _driverLng = newDriverLng;
        _currentRouteIndex = newCurrentRouteIndex;
        _backendOrderId = newBackendOrderId;
        
        notifyListeners();
      }
    } catch (e) {
      // Ігноруємо помилки зчитування, якщо файл ще записується
    }
  }

  // Координати маршруту (Аеропорт "Львів" ➔ Готель Nobilis)
  final List<LatLng> routePoints = const [
    LatLng(49.8125, 23.9561), // Аеропорт
    LatLng(49.8145, 23.9595),
    LatLng(49.8210, 23.9720), // Любінська (Виговського)
    LatLng(49.8245, 23.9850), // Любінська (Окружна)
    LatLng(49.8290, 23.9995), // Любінська / Бандери
    LatLng(49.8340, 24.0040), // пл. Кропивницького
    LatLng(49.8355, 24.0080), // Бандери / Шевченка
    LatLng(49.8348, 24.0125), // Бандери / Коперника
    LatLng(49.8385, 24.0245), // Коперника
    LatLng(49.8400, 24.0225), // Словацького
    LatLng(49.8410, 24.0270), // Дорошенка
    LatLng(49.8418, 24.0300), // пр. Свободи
    LatLng(49.8398, 24.0315), // пл. Галицька
    LatLng(49.8375, 24.0326), // Готель Nobilis
  ];

  // Координати підходу водія до аеропорту
  final List<LatLng> approachPoints = const [
    LatLng(49.8220, 23.9740),
    LatLng(49.8190, 23.9690),
    LatLng(49.8165, 23.9630),
    LatLng(49.8140, 23.9590),
    LatLng(49.8125, 23.9561), // Аеропорт (pickup)
  ];

  // Оновити координати та індекс під час симуляції
  void updateDriverProgress({required double lat, required double lng, required int index}) {
    _driverLat = lat;
    _driverLng = lng;
    _currentRouteIndex = index;
    _saveStateToFile();
    notifyListeners();
  }

  /// Ініціювати запит на трансфер (стає PENDING)
  void initiateTransfer() {
    _status = 'PENDING';
    _driverName = '';
    _driverPhone = '';
    _carModel = '';
    _carNumber = '';
    _passengerRating = 0;
    _passengerComment = '';
    _autoAssign = false;
    _driverLat = null;
    _driverLng = null;
    _currentRouteIndex = 0;
    _saveStateToFile();
    notifyListeners();
  }

  /// Ініціювати авто-розподіл (стає PENDING та autoAssign = true)
  void initiateAutoAssign() {
    _status = 'PENDING';
    _driverName = '';
    _driverPhone = '';
    _carModel = '';
    _carNumber = '';
    _passengerRating = 0;
    _passengerComment = '';
    _autoAssign = true;
    _driverLat = null;
    _driverLng = null;
    _currentRouteIndex = 0;
    _saveStateToFile();
    notifyListeners();
  }

  /// Підтвердити трансфер та призначити водія (стає CONFIRMED)
  void assignDriver({
    required String name,
    required String phone,
    required String car,
    required String number,
    double rating = 4.9,
    String? driverProfileId,
  }) async {
    String? orderId;

    // 1. Створюємо замовлення на бекенді через спеціальний ендпоінт для симуляції
    try {
      final api = ApiService();
      final orderData = await api.createSimulatedTransfer(
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        pickupLat: routePoints.first.latitude,
        pickupLng: routePoints.first.longitude,
        dropoffLat: routePoints.last.latitude,
        dropoffLng: routePoints.last.longitude,
        estimatedPrice: price,
        passengerPhone: passengerPhone,
      );
      orderId = orderData['id'] as String?;

      // Переводимо замовлення в EN_ROUTE (ACCEPTED → EN_ROUTE)
      if (orderId != null) {
        await api.updateOrderStatus(orderId, 'EN_ROUTE');
      }
    } catch (e) {
      debugPrint('Error creating simulated transfer order: $e');
    }

    // 2. Лише після цього оновлюємо локальний стан, щоб уникнути race condition з іншими вікнами
    _driverName = name;
    _driverPhone = phone;
    _carModel = car;
    _carNumber = number;
    _driverRating = rating;
    _status = 'CONFIRMED';
    _autoAssign = false; // Вимикаємо авто-розподіл, бо водія призначено
    _driverLat = approachPoints.first.latitude;
    _driverLng = approachPoints.first.longitude;
    _currentRouteIndex = 0;
    _backendOrderId = orderId;
    _saveStateToFile();
    notifyListeners();
  }

  /// Позначити, що водій прибув до місця посадки (стає ARRIVED)
  void arriveAtPickup() async {
    if (_status == 'CONFIRMED') {
      _status = 'ARRIVED';
      _driverLat = routePoints.first.latitude;
      _driverLng = routePoints.first.longitude;
      _currentRouteIndex = 0;
      _saveStateToFile();
      notifyListeners();

      if (_backendOrderId != null) {
        try {
          final api = ApiService();
          await api.updateOrderStatus(_backendOrderId!, 'IN_PROGRESS');
        } catch (e) {
          debugPrint('Error updating backend order to IN_PROGRESS: $e');
        }
      }
    }
  }

  /// Розпочати симуляцію поїздки на мапі (стає LIVE_RIDE)
  void startRide() {
    if (_status == 'CONFIRMED' || _status == 'ARRIVED') {
      _status = 'LIVE_RIDE';
      _driverLat = routePoints.first.latitude;
      _driverLng = routePoints.first.longitude;
      _currentRouteIndex = 0;
      _saveStateToFile();
      notifyListeners();
    }
  }

  /// Завершити симуляцію поїздки (стає COMPLETED)
  void completeRide() async {
    if (_status == 'LIVE_RIDE') {
      _status = 'COMPLETED';
      _saveStateToFile();
      notifyListeners();

      if (_backendOrderId != null) {
        try {
          final api = ApiService();
          await api.updateOrderStatus(_backendOrderId!, 'COMPLETED');
        } catch (e) {
          debugPrint('Error completing backend order: $e');
        }
      }
    }
  }

  /// Оцінити трансфер та скинути до початкового стану
  void submitReview(int rating, String comment) async {
    _passengerRating = rating;
    _passengerComment = comment;
    
    final orderId = _backendOrderId;

    // Одразу скидаємо в NONE після успішного збереження відгуку
    _status = 'NONE';
    _autoAssign = false;
    _driverLat = null;
    _driverLng = null;
    _currentRouteIndex = 0;
    _backendOrderId = null;
    _saveStateToFile();
    notifyListeners();

    if (orderId != null) {
      try {
        final api = ApiService();
        await api.createReview(
          orderId: orderId,
          rating: rating,
          comment: comment,
        );
      } catch (e) {
        debugPrint('Error submitting backend review: $e');
      }
    }
  }

  /// Повністю скинути симуляцію
  void resetSimulation() {
    _status = 'NONE';
    _driverName = '';
    _driverPhone = '';
    _carModel = '';
    _carNumber = '';
    _passengerRating = 0;
    _passengerComment = '';
    _autoAssign = false;
    _driverLat = null;
    _driverLng = null;
    _currentRouteIndex = 0;
    _backendOrderId = null;
    _saveStateToFile();
    notifyListeners();
  }
}
