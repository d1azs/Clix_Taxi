import 'dart:math';

/// Клас авто з коефіцієнтами і описом.
class CarClass {
  final String id;
  final String label;
  final String description;
  final String svgAsset;
  final double basePrice; // Базова ціна (₴)
  final double pricePerKm; // Ціна за кілометр (₴)
  final double pricePerMin; // Ціна за хвилину (₴)
  final double minPrice; // Мінімальна ціна поїздки (₴)

  const CarClass({
    required this.id,
    required this.label,
    required this.description,
    required this.svgAsset,
    required this.basePrice,
    required this.pricePerKm,
    required this.pricePerMin,
    required this.minPrice,
  });
}

/// Сервіс ціноутворення — розраховує ціну поїздки.
class PricingService {
  // Доступні класи авто
  static const List<CarClass> carClasses = [
    CarClass(
      id: 'ECONOMY',
      label: 'Економ',
      description: 'Доступна поїздка',
      svgAsset: 'assets/icons/car_economy.svg',
      basePrice: 35,
      pricePerKm: 8,
      pricePerMin: 2,
      minPrice: 55,
    ),
    CarClass(
      id: 'PREMIUM',
      label: 'Комфорт',
      description: 'Більше простору',
      svgAsset: 'assets/icons/car_comfort.svg',
      basePrice: 45,
      pricePerKm: 12,
      pricePerMin: 3,
      minPrice: 75,
    ),
    CarClass(
      id: 'BUSINESS',
      label: 'Бізнес',
      description: 'Преміум авто',
      svgAsset: 'assets/icons/car_business.svg',
      basePrice: 70,
      pricePerKm: 18,
      pricePerMin: 4,
      minPrice: 120,
    ),
    CarClass(
      id: 'MINIVAN',
      label: 'Мінівен',
      description: 'До 7 пасажирів',
      svgAsset: 'assets/icons/car_minivan.svg',
      basePrice: 55,
      pricePerKm: 14,
      pricePerMin: 3.5,
      minPrice: 90,
    ),
  ];

  /// Обчислення відстані між двома точками (км) за формулою Гаверсинуса.
  static double calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371.0; // Радіус Землі в км
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Приблизний час поїздки (хвилини) — 30 км/год середня швидкість у місті.
  static double estimateMinutes(double distanceKm) {
    return (distanceKm / 30.0) * 60.0;
  }

  /// Розрахунок ціни поїздки.
  static double calculatePrice({
    required CarClass carClass,
    required double distanceKm,
    double? durationMin,
  }) {
    final minutes = durationMin ?? estimateMinutes(distanceKm);
    final price =
        carClass.basePrice +
        (carClass.pricePerKm * distanceKm) +
        (carClass.pricePerMin * minutes);
    // Не менше мінимальної ціни
    return price < carClass.minPrice ? carClass.minPrice : price;
  }

  /// Розрахунок ціни за координатами для заданого класу.
  static double calculatePriceByCoords({
    required CarClass carClass,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) {
    final distanceKm = calculateDistanceKm(
      pickupLat,
      pickupLng,
      dropoffLat,
      dropoffLng,
    );
    return calculatePrice(carClass: carClass, distanceKm: distanceKm);
  }

  /// Знайти клас за id.
  static CarClass getClassById(String id) {
    return carClasses.firstWhere(
      (c) => c.id == id,
      orElse: () => carClasses.first,
    );
  }

  static double _toRad(double deg) => deg * pi / 180;
}
