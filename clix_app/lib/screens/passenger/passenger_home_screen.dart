import 'dart:async';
import 'dart:math' show cos, Random;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/pricing_service.dart';
import '../../services/routing_service.dart';
import '../../models/models.dart';

/// Головний екран пасажира — карта + bottom sheet з вибором маршруту та класу авто.
class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  final _api = ApiService();
  final _geocoding = GeocodingService();
  final _routing = RoutingService();
  String _selectedClass = 'ECONOMY';
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  OrderModel? _activeOrder;
  bool _isLoading = false;

  // Поллінг замовлення
  Timer? _orderTimer;
  String? _lastStatus; // для детекції зміни статусу
  LatLng? _driverLocation; // поточна позиція водія
  int _etaMinutes = 0; // орієнтовний час прибуття

  // ── DEMO анімація руху водія ──
  Timer? _demoAnimationTimer;
  List<LatLng> _demoWaypoints = []; // точки маршруту для анімації
  int _demoWaypointIndex = 0;
  bool _demoAnimationActive = false;

  // Рейтинг після поїздки
  OrderModel? _completedOrder;
  bool _ratingSheetShown = false;
  // Замовлення, для яких пасажир натиснув "Пропустити" (в рамках сесії)
  static final Set<String> _skippedOrderIds = {};

  // Пошук адрес
  List<AddressSuggestion> _pickupSuggestions = [];
  List<AddressSuggestion> _dropoffSuggestions = [];
  AddressSuggestion? _selectedPickup;
  AddressSuggestion? _selectedDropoff;
  Timer? _debounce;
  bool _showPickupSuggestions = false;
  bool _showDropoffSuggestions = false;
  DateTime? _scheduledTime;

  // Карта
  final MapController _mapController = MapController();
  static const _lvivCenter = LatLng(49.8397, 24.0297);
  LatLng? _userLocation;
  bool _followUser = false;
  int _mapStyleIndex = 0; // 0 = light, 1 = dark, 2 = satellite-style

  // Маршрут
  List<LatLng> _routePoints = []; // повний маршрут (pickup -> dropoff)
  List<LatLng> _demoRouteToDriver = []; // маршрут до водія (ACCEPTED фаза)
  List<LatLng> _visibleRoute = []; // поточна видима частина маршруту

  static const _mapStyles = [
    {
      'url':
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
      'label': 'Світла',
    },
    {
      'url': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
      'label': 'Темна',
    },
    {'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', 'label': 'OSM'},
  ];

  @override
  void initState() {
    super.initState();
    _checkActiveOrder();
    _initGeolocation();
  }

  void _startOrderPolling() {
    _orderTimer?.cancel();
    _orderTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _activeOrder == null) return;
      try {
        final data = await _api.getActiveOrder();
        if (!mounted) return;
        if (data == null) {
          _stopDemoAnimation();
          setState(() {
            _activeOrder = null;
            _driverLocation = null;
            _visibleRoute = [];
            _demoRouteToDriver = [];
          });
          _orderTimer?.cancel();
          return;
        }
        final updated = OrderModel.fromJson(data);
        final newStatus = updated.status;
        final bool statusChanged = (_lastStatus != null && newStatus != _lastStatus);

        setState(() {
          _activeOrder = updated;
          _lastStatus = newStatus;
        });

        if (statusChanged) {
          _showStatusSnackbar(newStatus);
          // Запускаємо/змінюємо DEMO анімацію при зміні статусу
          _onStatusChangedDemo(newStatus, updated);
        }

        if (newStatus == 'COMPLETED' && !_ratingSheetShown) {
          _showStatusSnackbar(newStatus);
        }
      } catch (_) {}
    });
  }

  // ── DEMO: реакція на зміну статусу ──
  void _onStatusChangedDemo(String newStatus, OrderModel order) {
    switch (newStatus) {
      case 'ACCEPTED':
        _startDemoApproach(order);
        break;
      case 'EN_ROUTE':
        // Водій натиснув "прибув" — телепортуємо машину до пасажира
        _stopDemoAnimation();
        setState(() {
          _driverLocation = LatLng(order.pickupLat, order.pickupLng);
          _etaMinutes = 0;
          // Повністю зберігаємо маршрут pickup→dropoff (ще не їхали)
          _visibleRoute = List.from(_routePoints);
          _demoRouteToDriver = [];
        });
        break;
      case 'IN_PROGRESS':
        _startDemoTrip(order);
        break;
      default:
        _stopDemoAnimation();
        setState(() {
          _driverLocation = null;
          _visibleRoute = [];
          _demoRouteToDriver = [];
        });
    }
  }

  // ── DEMO: водій їде до пасажира (ACCEPTED) по реальному OSRMмаршруту ──
  void _startDemoApproach(OrderModel order) async {
    _stopDemoAnimation();
    final pickup = LatLng(order.pickupLat, order.pickupLng);
    // Стартова точка — ~0.6 км від pickup
    final rng = Random();
    final angleRad = rng.nextDouble() * 6.28318;
    final startPt = LatLng(
      pickup.latitude + 0.005 * cos(angleRad),
      pickup.longitude + 0.008 * cos(angleRad + 1.2),
    );

    // Запитуємо OSRM маршрут start → pickup
    final route = await _routing.getRoute(startPt, pickup);
    final waypoints = route ?? _interpolateWaypoints(startPt, pickup, 14);

    if (!mounted || !_demoAnimationActive && _activeOrder?.status != 'ACCEPTED') return;

    setState(() {
      _demoWaypoints = waypoints;
      _demoWaypointIndex = 0;
      _driverLocation = waypoints.first;
      _etaMinutes = 4;
      // Показуємо додаткову лінію start→pickup
      _demoRouteToDriver = List.from(waypoints);
      _visibleRoute = List.from(_routePoints); // pickup→dropoff
    });
    _demoAnimationActive = true;

    _demoAnimationTimer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
      if (!mounted || !_demoAnimationActive) { t.cancel(); return; }
      if (_demoWaypointIndex < _demoWaypoints.length - 1) {
        _demoWaypointIndex++;
        final remaining = _demoWaypoints.length - 1 - _demoWaypointIndex;
        // Лінія до водія зменшується
        setState(() {
          _driverLocation = _demoWaypoints[_demoWaypointIndex];
          _etaMinutes = (remaining * 0.32).ceil().clamp(0, 10);
          _demoRouteToDriver = _demoWaypoints.sublist(_demoWaypointIndex);
        });
      } else {
        t.cancel();
      }
    });
  }

  // ── DEMO: водій везе пасажира (IN_PROGRESS) по OSRM маршруту ──
  void _startDemoTrip(OrderModel order) async {
    _stopDemoAnimation();
    final from = LatLng(order.pickupLat, order.pickupLng);
    final to = LatLng(order.dropoffLat, order.dropoffLng);

    // Використовуємо вже збудований маршрут або запитуємо OSRM
    final waypoints = _routePoints.isNotEmpty
        ? _routePoints
        : (await _routing.getRoute(from, to)) ?? _interpolateWaypoints(from, to, 20);

    if (!mounted) return;

    setState(() {
      _demoWaypoints = waypoints;
      _demoWaypointIndex = 0;
      _driverLocation = waypoints.first;
      _etaMinutes = 8;
      _visibleRoute = List.from(waypoints); // повний маршрут
      _demoRouteToDriver = [];
    });
    _demoAnimationActive = true;

    _demoAnimationTimer = Timer.periodic(const Duration(milliseconds: 1600), (t) {
      if (!mounted || !_demoAnimationActive) { t.cancel(); return; }
      if (_demoWaypointIndex < _demoWaypoints.length - 1) {
        _demoWaypointIndex++;
        final remaining = _demoWaypoints.length - 1 - _demoWaypointIndex;
        setState(() {
          _driverLocation = _demoWaypoints[_demoWaypointIndex];
          _etaMinutes = (remaining * 0.38).ceil().clamp(0, 15);
          // Та частина маршруту що попереду — залишаємо
          _visibleRoute = _demoWaypoints.sublist(_demoWaypointIndex);
        });
      } else {
        t.cancel();
      }
    });
  }

  void _stopDemoAnimation() {
    _demoAnimationTimer?.cancel();
    _demoAnimationActive = false;
  }

  /// Генерує список точок між start і end (рівномірно) — fallback якщо OSRM недоступний
  List<LatLng> _interpolateWaypoints(LatLng start, LatLng end, int count) {
    final pts = <LatLng>[];
    for (int i = 0; i <= count; i++) {
      final t = i / count;
      pts.add(LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t,
      ));
    }
    return pts;
  }

  void _showStatusSnackbar(String status) {
    String msg;
    IconData icon;
    Color color;
    switch (status) {
      case 'ACCEPTED':
        msg = 'Водій прийняв замовлення! Іде до вас...';
        icon = Icons.directions_car;
        color = CLIXTheme.primary;
        break;
      case 'EN_ROUTE':
        msg = 'Водій прибув! Забирає вас... 🚗';
        icon = Icons.person_pin_circle;
        color = CLIXTheme.success;
        break;
      case 'IN_PROGRESS':
        msg = 'Поїздка розпочалась! Рухаємось!';
        icon = Icons.navigation;
        color = CLIXTheme.warning;
        break;
      case 'COMPLETED':
        if (_ratingSheetShown) return;
        _ratingSheetShown = true;
        _orderTimer?.cancel();
        
        msg = 'Поїздка завершена! 🎉';
        icon = Icons.check_circle;
        color = CLIXTheme.success;
        _completedOrder = _activeOrder;
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _activeOrder = null;
              _routePoints = [];
            });
            _showRatingDialog(_completedOrder!);
          }
        });
        break;
      default:
        return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _initGeolocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
        _mapController.move(_userLocation!, 15.0);
      }
    } catch (_) {}
  }

  void _goToMyLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        final loc = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _userLocation = loc;
          _followUser = true;
        });
        _mapController.move(loc, 16.0);
      }
    } catch (_) {}
  }

  Future<void> _setPickupFromLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Дозволь доступ до геолокації в налаштуваннях'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Показати лоадер
      if (mounted) setState(() => _isLoading = true);

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Reverse geocoding через Nominatim
      final url =
          'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json&accept-language=uk';
      final resp = await _api.rawGet(url);
      String displayName = 'Моє місцезнаходження';
      String shortName = 'Моє місцезнаходження';

      if (resp != null) {
        final address = resp['address'] as Map<String, dynamic>? ?? {};
        final road = address['road'] ?? address['pedestrian'] ?? '';
        final houseNumber = address['house_number'] ?? '';
        final city =
            address['city'] ?? address['town'] ?? address['village'] ?? '';
        if (road.isNotEmpty) {
          shortName = houseNumber.isNotEmpty ? '$road, $houseNumber' : road;
          displayName = city.isNotEmpty ? '$shortName, $city' : shortName;
        } else {
          displayName = resp['display_name'] ?? displayName;
          shortName = displayName.split(',').first.trim();
        }
      }

      final suggestion = AddressSuggestion(
        displayName: displayName,
        shortName: shortName,
        lat: pos.latitude,
        lng: pos.longitude,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedPickup = suggestion;
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
        _pickupController.text = shortName;
        _mapController.move(LatLng(pos.latitude, pos.longitude), 16.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не вдалося отримати геолокацію'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// ═══ Діалог рейтингу після поїздки ═══
  void _showRatingDialog(OrderModel order) {
    int selectedRating = 0;
    final commentController = TextEditingController();
    bool isComplaint = false;
    bool isSubmitting = false;

    final driver = order.driverInfo;
    final driverName = driver != null
        ? '${driver.firstName} ${driver.lastName}'.trim()
        : 'Водій';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F7FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ручка
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Заголовок
                const Text(
                  'Як пройшла поїздка?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Оцініть $driverName',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                // Ціна і маршрут
                if (order.estimatedPrice != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: CLIXTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          color: CLIXTheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${order.estimatedPrice!.toStringAsFixed(0)} ₴',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CLIXTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                // Зірки
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return GestureDetector(
                      onTap: () =>
                          setModalState(() => selectedRating = starIndex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          starIndex <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: starIndex <= selectedRating ? 50 : 44,
                          color: starIndex <= selectedRating
                              ? const Color(0xFFFFBB00)
                              : Colors.grey.shade300,
                        ),
                      ),
                    );
                  }),
                ),
                if (selectedRating > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [
                        '',
                        'Жахливо 😤',
                        'Погано 😕',
                        'Нормально 😐',
                        'Добре 😊',
                        'Чудово! 🤩',
                      ][selectedRating],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CLIXTheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Коментар
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Залиш відгук (необов\'язково)...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: CLIXTheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 12),
                // Скарга
                Material(
                  color: isComplaint ? Colors.red.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  child: CheckboxListTile(
                    value: isComplaint,
                    onChanged: (v) =>
                        setModalState(() => isComplaint = v ?? false),
                    title: const Text(
                      '⚠️  Залишити скаргу',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Поїздка порушила правила чи стандарти',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    activeColor: Colors.red,
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(height: 20),
                // Кнопки
                Row(
                  children: [
                    // Пропустити
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              _skippedOrderIds.add(order.id);
                              Navigator.pop(ctx);
                              setState(() => _ratingSheetShown = false);
                              // fire-and-forget — назавжди на сервері
                              _api.dismissRating(order.id);
                            },

                      child: Text(
                        'Пропустити',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Відправити
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (selectedRating == 0 || isSubmitting)
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                try {
                                  await _api.createReview(
                                    orderId: order.id,
                                    rating: selectedRating,
                                    comment: commentController.text.trim(),
                                    isComplaint: isComplaint,
                                  );
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    setState(() => _ratingSheetShown = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Дякуємо за відгук! ⭐',
                                        ),
                                        backgroundColor: CLIXTheme.success,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  setModalState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Помилка відправки відгуку',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CLIXTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor: Colors.grey.shade200,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Відправити',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _checkActiveOrder() async {
    try {
      final data = await _api.getActiveOrder();
      if (data != null && mounted) {
        final order = OrderModel.fromJson(data);

        if (order.status == 'COMPLETED') {
          // Бекенд повертає COMPLETED тільки якщо відгука ще немає.
          // Не показуємо якщо:
          //   1) вже показали в цій сесії
          //   2) користувач натиснув "Пропустити"
          if (!_ratingSheetShown && !_skippedOrderIds.contains(order.id)) {
            _ratingSheetShown = true;
            _completedOrder = order;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showRatingDialog(order);
            });
          }
          return;
        }

        setState(() {
          _activeOrder = order;
          _lastStatus = order.status;
        });
        _startOrderPolling();
        _buildOrderRoute(order);
        // Запускаємо DEMO анімацію для вже активного замовлення
        _onStatusChangedDemo(order.status, order);
        Future.delayed(const Duration(milliseconds: 500), () {
          _mapController.move(LatLng(order.pickupLat, order.pickupLng), 15.0);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _orderTimer?.cancel();
    _debounce?.cancel();
    _demoAnimationTimer?.cancel();
    _pickupController.dispose();
    _dropoffController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Пошук адрес з debounce (150мс)
  void _onSearchChanged(String query, {required bool isPickup}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      if (query.trim().length < 2) {
        setState(() {
          if (isPickup) {
            _pickupSuggestions = [];
            _showPickupSuggestions = false;
          } else {
            _dropoffSuggestions = [];
            _showDropoffSuggestions = false;
          }
        });
        return;
      }
      final results = await _geocoding.searchAddress(query);
      if (mounted) {
        setState(() {
          if (isPickup) {
            _pickupSuggestions = results;
            _showPickupSuggestions = results.isNotEmpty;
          } else {
            _dropoffSuggestions = results;
            _showDropoffSuggestions = results.isNotEmpty;
          }
        });
      }
    });
  }

  void _selectAddress(AddressSuggestion addr, {required bool isPickup}) {
    setState(() {
      if (isPickup) {
        _selectedPickup = addr;
        _pickupController.text = addr.shortName;
        _pickupSuggestions = [];
        _showPickupSuggestions = false;
      } else {
        _selectedDropoff = addr;
        _dropoffController.text = addr.shortName;
        _dropoffSuggestions = [];
        _showDropoffSuggestions = false;
      }
    });
    // Переміщуємо карту до вибраної точки
    _mapController.move(LatLng(addr.lat, addr.lng), 15.0);
    // Будуємо маршрут якщо обидві точки вибрані
    _tryBuildRoute();
  }

  /// Побудувати маршрут між pickup і dropoff.
  Future<void> _tryBuildRoute() async {
    if (_selectedPickup == null || _selectedDropoff == null) return;
    final from = LatLng(_selectedPickup!.lat, _selectedPickup!.lng);
    final to = LatLng(_selectedDropoff!.lat, _selectedDropoff!.lng);
    final points = await _routing.getRoute(from, to);
    if (points != null && mounted) {
      setState(() => _routePoints = points);
      // Zoom щоб маршрут повністю помістився
      _fitRouteOnMap();
    }
  }

  /// Побудувати маршрут для активного замовлення з координат.
  Future<void> _buildOrderRoute(OrderModel order) async {
    final from = LatLng(order.pickupLat, order.pickupLng);
    final to = LatLng(order.dropoffLat, order.dropoffLng);
    final points = await _routing.getRoute(from, to);
    if (points != null && mounted) {
      setState(() => _routePoints = points);
    }
  }

  /// Автоматичний зум щоб весь маршрут був видний.
  void _fitRouteOnMap() {
    if (_routePoints.isEmpty) return;
    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;
    for (final p in _routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  void _cancelOrder() async {
    if (_activeOrder == null) return;
    try {
      await _api.cancelPassengerOrder(_activeOrder!.id);
      setState(() {
        _activeOrder = null;
        _routePoints = [];
        _lastStatus = null;
      });
      _orderTimer?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cancel_outlined, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Замовлення скасовано'),
              ],
            ),
            backgroundColor: Colors.grey.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Карта ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? _lvivCenter,
              initialZoom: 14.0,
              onPositionChanged: (_, __) {
                if (_followUser) setState(() => _followUser = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _mapStyles[_mapStyleIndex]['url']!,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.clix.app',
              ),
              // ── Маршрут (polyline) ──
              // Фаза ACCEPTED: лінія до пасажира (звужується)
              if (_demoRouteToDriver.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _demoRouteToDriver,
                      strokeWidth: 4.0,
                      color: CLIXTheme.primary.withValues(alpha: 0.55),
                      borderStrokeWidth: 1.5,
                      borderColor: CLIXTheme.primary.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              // Основний маршрут pickup→dropoff (зменшується по ходу IN_PROGRESS)
              if (_visibleRoute.length >= 2 && _activeOrder != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _visibleRoute,
                      strokeWidth: 5.0,
                      color: CLIXTheme.primary,
                      borderStrokeWidth: 2.0,
                      borderColor: CLIXTheme.primary.withValues(alpha: 0.3),
                    ),
                  ],
                )
              else if (_routePoints.isNotEmpty && _activeOrder == null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: CLIXTheme.primary,
                      borderStrokeWidth: 2.0,
                      borderColor: CLIXTheme.primary.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Моя локація — прибираємо коли вже в машині
                  if (_userLocation != null &&
                      _activeOrder?.status != 'IN_PROGRESS' &&
                      _activeOrder?.status != 'EN_ROUTE')
                    Marker(
                      point: _userLocation!,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: CLIXTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: CLIXTheme.primary.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Маркер водія (DEMO анімація)
                  if (_driverLocation != null)
                    Marker(
                      point: _driverLocation!,
                      width: 54,
                      height: 54,
                      child: _DemoDriverMarker(),
                    ),
                  // Точка підбору — прибираємо коли водій вже взяв пасажира
                  if (_selectedPickup != null &&
                      _activeOrder?.status != 'IN_PROGRESS' &&
                      _activeOrder?.status != 'EN_ROUTE')
                    Marker(
                      point: LatLng(_selectedPickup!.lat, _selectedPickup!.lng),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.radio_button_checked,
                        color: Color(0xFF10B981),
                        size: 28,
                      ),
                    ),
                  // Точка призначення
                  if (_selectedDropoff != null)
                    Marker(
                      point: LatLng(
                        _selectedDropoff!.lat,
                        _selectedDropoff!.lng,
                      ),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFEF4444),
                        size: 32,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Верхня панель ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Spacer(),
                  if (auth.user?.hasMultipleRoles ?? false)
                    _buildPillButton(
                      label: 'Водій',
                      icon: Icons.swap_horiz,
                      onTap: () => auth.switchRole('DRIVER'),
                    ),
                ],
              ),
            ),
          ),

          // ── Контролі карти (правий бік) ──
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.45 + 16,
            child: Column(
              children: [
                // Стиль карти
                _mapControlButton(
                  icon: Icons.layers_outlined,
                  onTap: () => setState(
                    () => _mapStyleIndex =
                        (_mapStyleIndex + 1) % _mapStyles.length,
                  ),
                  tooltip: _mapStyles[_mapStyleIndex]['label']!,
                ),
                const SizedBox(height: 8),
                // Компас
                _mapControlButton(
                  icon: Icons.explore_outlined,
                  onTap: () => _mapController.rotate(0),
                ),
                const SizedBox(height: 8),
                // Моя локація
                _mapControlButton(
                  icon: _followUser
                      ? Icons.my_location
                      : Icons.location_searching,
                  onTap: _goToMyLocation,
                  active: _followUser,
                ),
              ],
            ),
          ),

          // ── Bottom Sheet ──
          _activeOrder != null
              ? _buildActiveTripSheet()
              : _buildNewOrderSheet(),
        ],
      ),
    );
  }

  // ── Кнопка контролю карти ──
  Widget _mapControlButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool active = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? CLIXTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: active ? Colors.white : CLIXTheme.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ── Пілюля-кнопка ──
  Widget _buildPillButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CLIXTheme.radiusFull),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: CLIXTheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: CLIXTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Нове замовлення (DraggableScrollableSheet) ──
  Widget _buildNewOrderSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.08,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.12, 0.45, 0.75],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: CLIXTheme.primary.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              // Ручка
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CLIXTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Заголовок-превью (видно коли згорнуто)
              const Text(
                'Куди їдемо?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: CLIXTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Адреса подачі
              Text(
                'Звідки',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CLIXTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _pickupController,
                onChanged: (q) => _onSearchChanged(q, isPickup: true),
                decoration: InputDecoration(
                  hintText: 'Моя локація',
                  prefixIcon: const Icon(
                    Icons.radio_button_checked,
                    color: CLIXTheme.success,
                    size: 18,
                  ),
                  suffixIcon: _pickupController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _pickupController.clear();
                            setState(() {
                              _selectedPickup = null;
                              _showPickupSuggestions = false;
                            });
                          },
                        )
                      : Tooltip(
                          message: 'Використати мою локацію',
                          child: IconButton(
                            icon: const Icon(
                              Icons.my_location,
                              color: CLIXTheme.primary,
                              size: 20,
                            ),
                            onPressed: _setPickupFromLocation,
                          ),
                        ),
                ),
              ),
              if (_showPickupSuggestions)
                _buildSuggestionsList(_pickupSuggestions, isPickup: true),
              const SizedBox(height: 12),

              // Адреса прибуття
              Text(
                'Куди',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CLIXTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _dropoffController,
                onChanged: (q) => _onSearchChanged(q, isPickup: false),
                decoration: InputDecoration(
                  hintText: 'Адреса призначення',
                  prefixIcon: const Icon(
                    Icons.location_on,
                    color: CLIXTheme.error,
                    size: 18,
                  ),
                  suffixIcon: _dropoffController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _dropoffController.clear();
                            setState(() {
                              _selectedDropoff = null;
                              _showDropoffSuggestions = false;
                            });
                          },
                        )
                      : null,
                ),
              ),
              if (_showDropoffSuggestions)
                _buildSuggestionsList(_dropoffSuggestions, isPickup: false),
              const SizedBox(height: 20),

              // Клас авто
              Text(
                'Клас авто',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CLIXTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: PricingService.carClasses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final cc = PricingService.carClasses[index];
                    final isSelected = _selectedClass == cc.id;
                    final price = _getEstimatedPrice(cc);
                    return _CarClassCard(
                      carClass: cc,
                      price: price,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedClass = cc.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Відкласти поїздку
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    initialDate: now.add(const Duration(hours: 1)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 7)),
                  );
                  if (date == null || !mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                      now.add(const Duration(hours: 1)),
                    ),
                  );
                  if (time == null || !mounted) return;
                  setState(() {
                    _scheduledTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _scheduledTime != null
                        ? CLIXTheme.primary.withValues(alpha: 0.1)
                        : CLIXTheme.surface,
                    borderRadius: BorderRadius.circular(CLIXTheme.radiusMd),
                    border: Border.all(
                      color: _scheduledTime != null
                          ? CLIXTheme.primary
                          : CLIXTheme.divider,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 20,
                        color: _scheduledTime != null
                            ? CLIXTheme.primary
                            : CLIXTheme.textHint,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _scheduledTime != null
                            ? 'Заплановано: ${_scheduledTime!.day}.${_scheduledTime!.month} о ${_scheduledTime!.hour}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'
                            : 'Відкласти поїздку',
                        style: TextStyle(
                          fontSize: 13,
                          color: _scheduledTime != null
                              ? CLIXTheme.primary
                              : CLIXTheme.textSecondary,
                          fontWeight: _scheduledTime != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      if (_scheduledTime != null)
                        GestureDetector(
                          onTap: () => setState(() => _scheduledTime = null),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: CLIXTheme.textHint,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Кнопка виклику
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createOrder,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _scheduledTime != null
                              ? 'Запланувати таксі'
                              : 'Викликати таксі!',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ── Активне замовлення (знизу) ──
  Widget _buildActiveTripSheet() {
    final order = _activeOrder!;
    final driver = order.driverInfo;

    // Поетапи поїздки
    final stages = [
      ('ACCEPTED', 'Прийнято', Icons.check),
      ('EN_ROUTE', 'Прибув', Icons.place),
      ('IN_PROGRESS', 'В дорозі', Icons.navigation),
      ('COMPLETED', 'Завершено', Icons.flag),
    ];
    final statusOrder = [
      'PENDING',
      'ACCEPTED',
      'EN_ROUTE',
      'IN_PROGRESS',
      'COMPLETED',
    ];
    final currentIdx = statusOrder.indexOf(order.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.15,
      maxChildSize: 0.7,
      snap: true,
      snapSizes: const [0.38, 0.7],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              // Ручка
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CLIXTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Прогрес-бар етапів
              Row(
                  children: stages.map((stage) {
                    final stageIdx = statusOrder.indexOf(stage.$1);
                    final isDone = currentIdx >= stageIdx;
                    final isActive = order.status == stage.$1;
                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 3,
                            color: isDone
                                ? CLIXTheme.primary
                                : CLIXTheme.divider,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? CLIXTheme.primary
                                  : CLIXTheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDone
                                    ? CLIXTheme.primary
                                    : CLIXTheme.divider,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              stage.$3,
                              size: 14,
                              color: isDone ? Colors.white : CLIXTheme.textHint,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stage.$2,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isDone
                                  ? CLIXTheme.primary
                                  : CLIXTheme.textHint,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

              // ETA банер
              if ((order.status == 'ACCEPTED' ||
                      order.status == 'EN_ROUTE' ||
                      order.status == 'IN_PROGRESS') &&
                  _etaMinutes > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [CLIXTheme.primary, CLIXTheme.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.status == 'IN_PROGRESS'
                                ? 'Орієнтовно до призначення'
                                : order.status == 'EN_ROUTE'
                                    ? 'Забираю вас...'
                                    : 'Водій буде через',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '$_etaMinutes хв.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (order.estimatedPrice != null)
                        Text(
                          '${order.estimatedPrice!.toStringAsFixed(0)} ₴',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                    ],
                  ),
                ),

              // Картка водія
              if (driver != null && order.status != 'PENDING') ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CLIXTheme.surface,
                    borderRadius: BorderRadius.circular(CLIXTheme.radiusMd),
                    border: Border.all(color: CLIXTheme.divider),
                  ),
                  child: Row(
                    children: [
                      // Аватар
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: CLIXTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            driver.firstName.isNotEmpty
                                ? driver.firstName[0].toUpperCase()
                                : 'В',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.fullName.isNotEmpty
                                  ? driver.fullName
                                  : 'Ваш водій',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (driver.rating > 0) ...[
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: Color(0xFFFBBF24),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    driver.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CLIXTheme.textSecondary,
                                    ),
                                  ),
                                ] else
                                  const Text(
                                    'Новий водій',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: CLIXTheme.textSecondary,
                                    ),
                                  ),
                                if (driver.totalTrips > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${driver.totalTrips} поїздок',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CLIXTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Телефон
                      if (driver.phoneNumber.isNotEmpty)
                        Material(
                          color: CLIXTheme.primary.withValues(alpha: 0.1),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {},
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.phone,
                                color: CLIXTheme.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Почекаємо водія (PENDING)
              if (order.status == 'PENDING') ...[
                const _SearchingDriverAnimation(),
                const SizedBox(height: 16),
              ],

              // Адреси
              Row(
                children: [
                  const Icon(
                    Icons.radio_button_checked,
                    color: CLIXTheme.success,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.pickupAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 7),
                child: SizedBox(
                  width: 2,
                  height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: CLIXTheme.divider),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: CLIXTheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.dropoffAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Скасувати (тільки PENDING)
              if (order.status == 'PENDING')
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _cancelOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CLIXTheme.error,
                      side: const BorderSide(color: CLIXTheme.error),
                    ),
                    child: const Text('Скасувати замовлення'),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // ── Список підказок адрес ──
  Widget _buildSuggestionsList(
    List<AddressSuggestion> suggestions, {
    required bool isPickup,
  }) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CLIXTheme.radiusMd),
        border: Border.all(color: CLIXTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final s = suggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.place,
              color: CLIXTheme.primary,
              size: 20,
            ),
            title: Text(
              s.shortName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              s.displayName,
              style: const TextStyle(fontSize: 11, color: CLIXTheme.textHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectAddress(s, isPickup: isPickup),
          );
        },
      ),
    );
  }

  /// Розрахунок орієнтовної ціни для заданого класу авто.
  double _getEstimatedPrice(CarClass cc) {
    final pickupLat = _selectedPickup?.lat ?? 49.8397;
    final pickupLng = _selectedPickup?.lng ?? 24.0297;
    final dropoffLat = _selectedDropoff?.lat ?? 49.8429;
    final dropoffLng = _selectedDropoff?.lng ?? 24.0315;
    return PricingService.calculatePriceByCoords(
      carClass: cc,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
    );
  }

  Future<void> _createOrder() async {
    if (_dropoffController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вкажіть адресу призначення')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final pickupLat = _selectedPickup?.lat ?? 49.8397;
    final pickupLng = _selectedPickup?.lng ?? 24.0297;
    final dropoffLat = _selectedDropoff?.lat ?? 49.8429;
    final dropoffLng = _selectedDropoff?.lng ?? 24.0315;
    final pickupAddr = _pickupController.text.trim().isNotEmpty
        ? _pickupController.text.trim()
        : 'Моя локація';
    final pickupTime = _scheduledTime ?? DateTime.now();

    try {
      final data = await _api.createPassengerOrder(
        pickupAddress: pickupAddr,
        dropoffAddress: _dropoffController.text.trim(),
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        pickupTime: pickupTime.toIso8601String(),
        requiredClass: _selectedClass,
        estimatedPrice: _getEstimatedPrice(
          PricingService.getClassById(_selectedClass),
        ).roundToDouble(),
      );
      if (mounted) {
        final order = OrderModel.fromJson(data);
        setState(() {
          _activeOrder = order;
          _lastStatus = order.status;
          _isLoading = false;
        });
        // ── Запускаємо поллінг і DEMO анімацію одразу після створення ──
        _startOrderPolling();
        _buildOrderRoute(order);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }
}

// ── Класова картка авто з SVG ──
class _CarClassCard extends StatelessWidget {
  final CarClass carClass;
  final double price;
  final bool isSelected;
  final VoidCallback onTap;

  const _CarClassCard({
    required this.carClass,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? CLIXTheme.primary.withValues(alpha: 0.08)
              : CLIXTheme.surface,
          borderRadius: BorderRadius.circular(CLIXTheme.radiusMd),
          border: Border.all(
            color: isSelected ? CLIXTheme.primary : CLIXTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SvgPicture.asset(carClass.svgAsset, width: 44, height: 26),
            const SizedBox(height: 4),
            Text(
              carClass.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected ? CLIXTheme.primary : CLIXTheme.textPrimary,
              ),
            ),
            Text(
              '${price.round()} ₴',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? CLIXTheme.primary : CLIXTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Анімація пошуку водія ──
class _SearchingDriverAnimation extends StatefulWidget {
  const _SearchingDriverAnimation();

  @override
  State<_SearchingDriverAnimation> createState() => _SearchingDriverAnimationState();
}

class _SearchingDriverAnimationState extends State<_SearchingDriverAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: CLIXTheme.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(CLIXTheme.radiusLg),
            border: Border.all(
              color: CLIXTheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Пульсуючі кола
                  for (int i = 0; i < 3; i++)
                    Opacity(
                      opacity: (1.0 - ((_controller.value + i / 3.0) % 1.0)).clamp(0.0, 1.0),
                      child: Container(
                        width: 44 + 60 * ((_controller.value + i / 3.0) % 1.0),
                        height: 44 + 60 * ((_controller.value + i / 3.0) % 1.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CLIXTheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  // Центральна іконка
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CLIXTheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: CLIXTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Шукаємо найкращого водія...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CLIXTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Зазвичай це займає близько хвилини',
                style: TextStyle(
                  fontSize: 13,
                  color: CLIXTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── DEMO: фіолетова пульсуюча іконка машини на карті ──
class _DemoDriverMarker extends StatefulWidget {
  const _DemoDriverMarker();

  @override
  State<_DemoDriverMarker> createState() => _DemoDriverMarkerState();
}

class _DemoDriverMarkerState extends State<_DemoDriverMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: _pulse.value,
        child: child,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Зовнішнє пульсуюче коло
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CLIXTheme.primary.withValues(alpha: 0.22),
            ),
          ),
          // Основний контейнер (фіолетовий)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CLIXTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: CLIXTheme.primary.withValues(alpha: 0.6),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
