/// Конфігурація API для CLIX
class ApiConfig {
  // Базова URL-адреса бекенду (змінити для продакшну)
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Ендпоінти авторизації
  static const String login = '/auth/login/';
  static const String register = '/auth/register/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String me = '/users/me/';

  // Ендпоінти водія
  static const String driverStatus = '/driver/status/';
  static const String driverLocation = '/driver/location/';
  static const String driverVehicles = '/driver/vehicles/';
  static const String driverActiveOrder = '/driver/orders/active/';

  // Ендпоінти пасажира
  static const String passengerCreateOrder = '/passenger/orders/';
  static const String passengerActiveOrder = '/passenger/orders/active/';

  // Ендпоінти замовлень
  static const String availableOrders = '/orders/available/';
  static const String ordersHistory = '/orders/history/';
  static String acceptOrder(String id) => '/orders/$id/accept/';
  static String rejectOrder(String id) => '/orders/$id/reject/';
  static String updateOrderStatus(String id) => '/orders/$id/status/';
  static String createReview(String id) => '/orders/$id/review/';

  // Ендпоінти диспетчера
  static const String dispatcherCreateOrder = '/dispatcher/orders/';
  static const String dispatcherOrderList = '/dispatcher/orders/list/';
  static const String dispatcherComplaints = '/dispatcher/complaints/';
  static String dispatcherOrderDetail(String id) => '/dispatcher/orders/$id/';
}
