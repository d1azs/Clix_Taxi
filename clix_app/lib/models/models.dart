/// Модель користувача CLIX
class UserModel {
  final String id;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final List<String> roles;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.roles,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['user_id'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      roles: List<String>.from(json['roles'] ?? []),
    );
  }

  bool get isPassenger => roles.contains('PASSENGER');
  bool get isDriver => roles.contains('DRIVER');
  bool get isDispatcher => roles.contains('DISPATCHER');
  bool get hasMultipleRoles => roles.length > 1;

  String get fullName => '$firstName $lastName'.trim();
}

/// Модель замовлення
class OrderModel {
  final String id;
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String status;
  final String statusDisplay;
  final String requiredClass;
  final String classDisplay;
  final double? estimatedPrice;
  final String? passengerPhone;
  final DriverInfo? driverInfo;
  final String? routePolyline;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.status,
    required this.statusDisplay,
    required this.requiredClass,
    required this.classDisplay,
    this.estimatedPrice,
    this.passengerPhone,
    this.driverInfo,
    this.routePolyline,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      pickupAddress: json['pickup_address'] ?? '',
      dropoffAddress: json['dropoff_address'] ?? '',
      pickupLat: (json['pickup_lat'] ?? 0).toDouble(),
      pickupLng: (json['pickup_lng'] ?? 0).toDouble(),
      dropoffLat: (json['dropoff_lat'] ?? 0).toDouble(),
      dropoffLng: (json['dropoff_lng'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      statusDisplay: json['status_display'] ?? '',
      requiredClass: json['required_class'] ?? '',
      classDisplay: json['class_display'] ?? '',
      estimatedPrice: json['estimated_price'] != null
          ? double.tryParse(json['estimated_price'].toString())
          : null,
      passengerPhone: json['passenger_phone'],
      driverInfo: json['driver_info'] != null
          ? DriverInfo.fromJson(json['driver_info'])
          : null,
      routePolyline: json['route_polyline'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Інформація про водія
class DriverInfo {
  final String id;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String status;
  final double rating;
  final int totalTrips;
  final double? currentLat;
  final double? currentLng;

  DriverInfo({
    required this.id,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.rating,
    required this.totalTrips,
    this.currentLat,
    this.currentLng,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      id: json['id'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      status: json['status'] ?? 'OFFLINE',
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      totalTrips: json['total_trips'] ?? 0,
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble(),
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}
