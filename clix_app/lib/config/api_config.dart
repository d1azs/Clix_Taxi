/// Конфігурація API для CLIX
class ApiConfig {
  // Базова URL-адреса бекенду з косою рискою в кінці
  static const String baseUrl = 'https://clix-taxi.onrender.com/api/';
  static const String mediaUrl = 'https://clix-taxi.onrender.com/media/';

  // Ендпоінти авторизації (відносні шляхи без косої риски на початку)
  static const String login = 'auth/login/';
  static const String register = 'auth/register/';
  static const String tokenRefresh = 'auth/token/refresh/';
  static const String me = 'users/me/';

  // Ендпоінти водія
  static const String driverStatus = 'driver/status/';
  static const String driverLocation = 'driver/location/';
  static const String driverVehicles = 'driver/vehicles/';
  static const String driverActiveOrder = 'driver/orders/active/';
  static const String nearbyDrivers = 'drivers/nearby/';

  // Ендпоінти пасажира
  static const String passengerCreateOrder = 'passenger/orders/';
  static const String passengerActiveOrder = 'passenger/orders/active/';
  static String cancelPassengerOrder(String id) => 'passenger/orders/$id/cancel/';

  // Ендпоінти замовлень
  static const String availableOrders = 'orders/available/';
  static const String ordersHistory = 'orders/history/';
  static String acceptOrder(String id) => 'orders/$id/accept/';
  static String rejectOrder(String id) => 'orders/$id/reject/';
  static String updateOrderStatus(String id) => 'orders/$id/status/';
  static String createReview(String id) => 'orders/$id/review/';
  static const String simulatedTransfer = 'orders/simulated-transfer/';

  // Ендпоінти диспетчера
  static const String dispatcherCreateOrder = 'dispatcher/orders/';
  static const String dispatcherOrderList = 'dispatcher/orders/list/';
  static const String dispatcherComplaints = 'dispatcher/complaints/';
  static const String dispatcherDrivers = 'dispatcher/drivers/';
  static const String dispatcherKycPending = 'dispatcher/kyc/pending/';
  static String dispatcherOrderDetail(String id) => 'dispatcher/orders/$id/';
  static String dispatcherForceAssign(String id) => 'dispatcher/orders/$id/force-assign/';
  static String dispatcherKycReview(String id) => 'dispatcher/kyc/$id/review/';

  // KYC
  static const String kycUpload = 'driver/kyc/upload';
  static const String kycStatus = 'driver/kyc/status';
}
