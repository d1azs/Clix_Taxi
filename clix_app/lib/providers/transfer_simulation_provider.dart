import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

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

  String get status => _status;
  String get driverName => _driverName;
  String get driverPhone => _driverPhone;
  double get driverRating => _driverRating;
  String get carModel => _carModel;
  String get carNumber => _carNumber;
  int get passengerRating => _passengerRating;
  String get passengerComment => _passengerComment;
  bool get autoAssign => _autoAssign;

  // Файл для синхронізації між процесами (вікнами)
  static const String _syncPath = '/Users/tohqa/Боско/Diploma/clix_app/transfer_simulation_state.json';
  Timer? _syncTimer;
  bool _isSaving = false;

  TransferSimulationProvider() {
    _loadStateFromFile();
    // Періодично зчитуємо стан (кожні 1.2 секунди) для швидкої синхронізації вікон
    _syncTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
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

      // Перевіряємо, чи змінилися дані
      if (_status != newStatus ||
          _driverName != newDriverName ||
          _driverPhone != newDriverPhone ||
          _driverRating != newDriverRating ||
          _carModel != newCarModel ||
          _carNumber != newCarNumber ||
          _passengerRating != newPassengerRating ||
          _passengerComment != newPassengerComment ||
          _autoAssign != newAutoAssign) {
        
        _status = newStatus;
        _driverName = newDriverName;
        _driverPhone = newDriverPhone;
        _driverRating = newDriverRating;
        _carModel = newCarModel;
        _carNumber = newCarNumber;
        _passengerRating = newPassengerRating;
        _passengerComment = newPassengerComment;
        _autoAssign = newAutoAssign;
        
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
  }) {
    _driverName = name;
    _driverPhone = phone;
    _carModel = car;
    _carNumber = number;
    _driverRating = rating;
    _status = 'CONFIRMED';
    _autoAssign = false; // Вимикаємо авто-розподіл, бо водія призначено
    _saveStateToFile();
    notifyListeners();
  }

  /// Розпочати симуляцію поїздки на мапі (стає LIVE_RIDE)
  void startRide() {
    if (_status == 'CONFIRMED') {
      _status = 'LIVE_RIDE';
      _saveStateToFile();
      notifyListeners();
    }
  }

  /// Завершити симуляцію поїздки (стає COMPLETED)
  void completeRide() {
    if (_status == 'LIVE_RIDE') {
      _status = 'COMPLETED';
      _saveStateToFile();
      notifyListeners();
    }
  }

  /// Оцінити трансфер та скинути до початкового стану
  void submitReview(int rating, String comment) {
    _passengerRating = rating;
    _passengerComment = comment;
    // Одразу скидаємо в NONE після успішного збереження відгуку
    _status = 'NONE';
    _autoAssign = false;
    _saveStateToFile();
    notifyListeners();
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
    _saveStateToFile();
    notifyListeners();
  }
}
