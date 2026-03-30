import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Стан авторизації та активної ролі користувача.
/// Використовується як глобальний ChangeNotifier.
class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  UserModel? _user;
  String? _activeRole; // PASSENGER, DRIVER, DISPATCHER
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  String? get activeRole => _activeRole;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  /// Спроба відновити сесію при запуску
  Future<bool> tryRestoreSession() async {
    final hasToken = await _api.hasToken();
    if (!hasToken) return false;
    try {
      final data = await _api.getMe();
      _user = UserModel.fromJson(data);
      _activeRole ??= _user!.roles.first;
      notifyListeners();
      return true;
    } catch (_) {
      await _api.logout();
      return false;
    }
  }

  /// Логін за номером телефону та паролем
  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.login(phone, password);
      // Завантажуємо повний профіль з іменем/прізвищем
      final me = await _api.getMe();
      _user = UserModel.fromJson(me);
      _activeRole = _user!.roles.first;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ LOGIN ERROR: $e');
      _error = 'Невірний номер або пароль';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Реєстрація
  Future<bool> register({
    required String phone,
    required String password,
    String? firstName,
    String? lastName,
    List<String> roles = const ['PASSENGER'],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.register(
        phone: phone,
        password: password,
        firstName: firstName,
        lastName: lastName,
        roles: roles,
      );
      // Після реєстрації автоматично логінимось
      return await login(phone, password);
    } catch (e) {
      _error = 'Помилка реєстрації. Перевірте дані.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Перемикання активної ролі
  void switchRole(String role) {
    if (_user != null && _user!.roles.contains(role)) {
      _activeRole = role;
      notifyListeners();
    }
  }

  /// Оновлення профілю (ім'я та прізвище)
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    try {
      await _api.updateProfile(firstName: firstName, lastName: lastName);
      _user = UserModel(
        id: _user!.id,
        phoneNumber: _user!.phoneNumber,
        firstName: firstName,
        lastName: lastName,
        roles: _user!.roles,
      );
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Вихід
  Future<void> logout() async {
    await _api.logout();
    _user = null;
    _activeRole = null;
    notifyListeners();
  }
}
