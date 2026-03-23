import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/routing_service.dart';
import '../../models/models.dart';

/// Головний екран водія — карта + список замовлень + прогрес поїздки.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  final _routing = RoutingService();
  bool _isOnline = false;
  double _todayEarnings = 0;
  int _todayTrips = 0;
  List<OrderModel> _availableOrders = [];
  OrderModel? _currentOrder;
  Timer? _pollTimer;

  // Прогрес поїздки (0.0 → 1.0)
  double _tripProgress = 0.0;
  Timer? _progressTimer;
  String _tripStageLabel = '';

  // Анімація пульсу радара
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // DraggableScrollableController для bottom sheet
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Карта та геолокація
  final MapController _driverMapController = MapController();
  LatLng? _userLocation;
  bool _followUser = false;
  int _mapStyleIndex = 0;

  // Маршрут
  List<LatLng> _routePoints = [];

  static const _mapStyles = [
    {
      'url': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
      'label': 'Темна',
    },
    {
      'url':
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
      'label': 'Світла',
    },
    {'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', 'label': 'OSM'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadDriverInfo();
    _initGeolocation();
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
        _driverMapController.move(_userLocation!, 15.0);
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
        _driverMapController.move(loc, 16.0);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _progressTimer?.cancel();
    _pulseController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverInfo() async {
    try {
      final data = await _api.getDriverStatus();
      if (mounted) {
        setState(() {
          _isOnline = data['status'] == 'ONLINE';
          _todayEarnings =
              double.tryParse(data['total_earnings']?.toString() ?? '0') ?? 0;
          _todayTrips = data['total_trips'] ?? 0;
        });
        // Відновлюємо активне замовлення (якщо було, наприклад після перемикання ролей)
        final activeOrderData = await _api.getDriverActiveOrder();
        if (activeOrderData != null && mounted) {
          final order = OrderModel.fromJson(activeOrderData);
          setState(() => _currentOrder = order);
          _stopPolling();
          _startTripProgress(order.status);
          _buildOrderRoute(order);
        } else if (_isOnline) {
          _startPolling();
        }
      }
    } catch (_) {}
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchAvailableOrders();
    });
    _fetchAvailableOrders();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    setState(() => _availableOrders = []);
  }

  Future<void> _fetchAvailableOrders() async {
    if (!_isOnline) return;
    try {
      final data = await _api.getAvailableOrders();
      if (mounted) {
        setState(() {
          _availableOrders = (data).map((e) => OrderModel.fromJson(e)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleOnline() async {
    final newStatus = _isOnline ? 'OFFLINE' : 'ONLINE';
    try {
      await _api.updateDriverStatus(newStatus);
      setState(() => _isOnline = !_isOnline);
      if (_isOnline) {
        _startPolling();
      } else {
        _stopPolling();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  Future<void> _acceptOrder(OrderModel order) async {
    try {
      final data = await _api.acceptOrder(order.id);
      setState(() {
        _currentOrder = OrderModel.fromJson(data);
        _availableOrders.clear();
      });
      _stopPolling();
      _startTripProgress('ACCEPTED');
      // Будуємо маршрут
      _buildOrderRoute(_currentOrder!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Замовлення вже зайняте іншим водієм')),
        );
        _fetchAvailableOrders();
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_currentOrder == null) return;
    try {
      final data = await _api.updateOrderStatus(_currentOrder!.id, newStatus);
      if (newStatus == 'COMPLETED') {
        // Додаємо заробіток
        final earned = _currentOrder!.estimatedPrice ?? 0;
        setState(() {
          _currentOrder = null;
          _todayTrips += 1;
          _todayEarnings += earned;
          _tripProgress = 0;
          _routePoints = [];
        });
        _progressTimer?.cancel();
        _startPolling();
      } else {
        setState(() => _currentOrder = OrderModel.fromJson(data));
        _startTripProgress(newStatus);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  /// Побудувати маршрут для замовлення.
  Future<void> _buildOrderRoute(OrderModel order) async {
    final from = LatLng(order.pickupLat, order.pickupLng);
    final to = LatLng(order.dropoffLat, order.dropoffLng);
    final points = await _routing.getRoute(from, to);
    if (points != null && mounted) {
      setState(() => _routePoints = points);
      // Авто-зум щоб маршрут помістився
      _fitRouteOnMap();
    }
  }

  /// Авто-зум карти щоб маршрут повністю був видний.
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
    _driverMapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  /// Запуск прогрес-бару для етапу поїздки.
  void _startTripProgress(String status) {
    _progressTimer?.cancel();

    double targetProgress;
    int durationSeconds;

    switch (status) {
      case 'ACCEPTED':
        // Прибуваємо до клієнта — ~30 секунд
        targetProgress = 0.33;
        durationSeconds = 30;
        _tripStageLabel = 'Прибуваємо до клієнта…';
        break;
      case 'EN_ROUTE':
        // Забираємо клієнта — ~10 секунд затримка
        targetProgress = 0.5;
        durationSeconds = 10;
        _tripStageLabel = 'Клієнт сідає…';
        break;
      case 'IN_PROGRESS':
        // Їдемо до точки — ~45 секунд
        targetProgress = 1.0;
        durationSeconds = 45;
        _tripStageLabel = 'Їдемо до місця призначення…';
        break;
      default:
        return;
    }

    final startProgress = _tripProgress;
    final delta = targetProgress - startProgress;
    const fps = 30;
    final totalFrames = durationSeconds * fps;
    int frame = 0;

    _progressTimer = Timer.periodic(Duration(milliseconds: 1000 ~/ fps), (
      timer,
    ) {
      frame++;
      if (frame >= totalFrames) {
        timer.cancel();
        setState(() => _tripProgress = targetProgress);
      } else {
        setState(() {
          _tripProgress = startProgress + (delta * frame / totalFrames);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Theme(
      data: CLIXTheme.darkTheme,
      child: Scaffold(
        backgroundColor: CLIXTheme.driverBg,
        body: Stack(
          children: [
            // ── Фон: карта Львова (тайли) ──
            _buildMapBackground(),

            // ── Верхня панель ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Переключення ролі
                        if (auth.user?.hasMultipleRoles ?? false)
                          Material(
                            color: CLIXTheme.driverCard,
                            borderRadius: BorderRadius.circular(
                              CLIXTheme.radiusFull,
                            ),
                            child: InkWell(
                              onTap: () => auth.switchRole('PASSENGER'),
                              borderRadius: BorderRadius.circular(
                                CLIXTheme.radiusFull,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.swap_horiz,
                                      size: 16,
                                      color: CLIXTheme.primaryLight,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Пасажир',
                                      style: TextStyle(
                                        color: CLIXTheme.primaryLight,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const Spacer(),
                        // Заробіток (тільки якщо > 0)
                        if (_todayEarnings > 0 || _todayTrips > 0)
                          _buildEarningsBadge(),
                        if (_todayEarnings > 0 || _todayTrips > 0)
                          const SizedBox(width: 10),
                        // Онлайн/Офлайн
                        _buildOnlineToggle(),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Контролі карти (правий бік) ──
            Positioned(
              right: 16,
              bottom: 180 + bottomPadding,
              child: Column(
                children: [
                  _mapControlButton(
                    icon: Icons.layers_outlined,
                    tooltip: _mapStyles[_mapStyleIndex]['label']!,
                    onTap: () => setState(
                      () => _mapStyleIndex =
                          (_mapStyleIndex + 1) % _mapStyles.length,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _mapControlButton(
                    icon: Icons.explore_outlined,
                    onTap: () => _driverMapController.rotate(0),
                  ),
                  const SizedBox(height: 8),
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

            // ── Контент знизу ──
            if (_currentOrder != null)
              _buildActiveTripSheet(bottomPadding)
            else if (_isOnline && _availableOrders.isNotEmpty)
              _buildOrdersListSheet(bottomPadding)
            else if (_isOnline && _availableOrders.isEmpty)
              _buildWaitingOverlay(),
          ],
        ),
      ),
    );
  }

  // ── Фон-карта (OpenStreetMap) ──
  Widget _buildMapBackground() {
    return FlutterMap(
      mapController: _driverMapController,
      options: MapOptions(
        initialCenter: _userLocation ?? const LatLng(49.8397, 24.0297),
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
        if (_routePoints.isNotEmpty)
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
            // Моя локація
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: CLIXTheme.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: CLIXTheme.primaryLight.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            // Маркери поточного замовлення
            if (_currentOrder != null) ...[
              Marker(
                point: LatLng(
                  _currentOrder!.pickupLat,
                  _currentOrder!.pickupLng,
                ),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.radio_button_checked,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              Marker(
                point: LatLng(
                  _currentOrder!.dropoffLat,
                  _currentOrder!.dropoffLng,
                ),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 32,
                ),
              ),
            ],
          ],
        ),
      ],
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
            color: active ? CLIXTheme.primary : CLIXTheme.driverCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: active ? Colors.white : CLIXTheme.primaryLight,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ── Бейдж заробітку ──
  Widget _buildEarningsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: CLIXTheme.driverCard,
        borderRadius: BorderRadius.circular(CLIXTheme.radiusFull),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet,
            size: 16,
            color: CLIXTheme.primaryLight,
          ),
          const SizedBox(width: 6),
          Text(
            '${_todayEarnings.toStringAsFixed(0)} ₴',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            ' • $_todayTrips',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Перемикач Онлайн/Офлайн ──
  Widget _buildOnlineToggle() {
    return GestureDetector(
      onTap: _toggleOnline,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _isOnline ? CLIXTheme.success : CLIXTheme.driverCard,
          borderRadius: BorderRadius.circular(CLIXTheme.radiusFull),
          border: Border.all(
            color: _isOnline ? CLIXTheme.success : Colors.white24,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isOnline
                  ? CLIXTheme.success.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isOnline ? Colors.white : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _isOnline ? 'Онлайн' : 'Офлайн',
              style: TextStyle(
                color: _isOnline ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Очікування замовлень (радар) ──
  Widget _buildWaitingOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 160 * _pulseAnimation.value,
                height: 160 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CLIXTheme.primary.withValues(
                      alpha: 0.3 / _pulseAnimation.value,
                    ),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CLIXTheme.primary.withValues(alpha: 0.15),
                      border: Border.all(color: CLIXTheme.primary, width: 2),
                    ),
                    child: const Icon(
                      Icons.wifi_tethering,
                      color: CLIXTheme.primary,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Шукаємо замовлення…',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Список доступних замовлень (DraggableScrollableSheet) ──
  Widget _buildOrdersListSheet(double bottomPadding) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.15,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: CLIXTheme.driverCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: CLIXTheme.primary.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Ручка
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Заголовок
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Доступні замовлення',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: CLIXTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_availableOrders.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Список замовлень
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: bottomPadding + 16,
                  ),
                  itemCount: _availableOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _buildOrderCard(_availableOrders[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Картка замовлення ──
  Widget _buildOrderCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLIXTheme.driverBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Адреси
          _DarkAddressRow(
            icon: Icons.radio_button_checked,
            iconColor: CLIXTheme.success,
            text: order.pickupAddress,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(width: 1, height: 16, color: Colors.white24),
          ),
          _DarkAddressRow(
            icon: Icons.location_on,
            iconColor: CLIXTheme.error,
            text: order.dropoffAddress,
          ),
          const SizedBox(height: 12),
          // Клас + Ціна
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: CLIXTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.classDisplay,
                  style: const TextStyle(
                    color: CLIXTheme.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (order.estimatedPrice != null)
                Text(
                  '${order.estimatedPrice!.toStringAsFixed(0)} ₴',
                  style: const TextStyle(
                    color: CLIXTheme.primaryLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Кнопки
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _availableOrders.remove(order));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(CLIXTheme.radiusMd),
                      ),
                    ),
                    child: const Text('Пропустити'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _acceptOrder(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CLIXTheme.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(CLIXTheme.radiusMd),
                      ),
                    ),
                    child: const Text('Прийняти'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Активна поїздка (Bottom Sheet з прогрес-баром) ──
  Widget _buildActiveTripSheet(double bottomPadding) {
    final order = _currentOrder!;
    String nextStatusLabel;
    String? nextStatus;
    IconData nextIcon;

    switch (order.status) {
      case 'ACCEPTED':
        nextStatusLabel = 'Я на місці';
        nextStatus = 'EN_ROUTE';
        nextIcon = Icons.place;
        break;
      case 'EN_ROUTE':
        nextStatusLabel = 'Розпочати поїздку';
        nextStatus = 'IN_PROGRESS';
        nextIcon = Icons.directions_car;
        break;
      case 'IN_PROGRESS':
        nextStatusLabel = 'Завершити поїздку';
        nextStatus = 'COMPLETED';
        nextIcon = Icons.check_circle;
        break;
      default:
        nextStatusLabel = '';
        nextStatus = null;
        nextIcon = Icons.check;
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
        decoration: BoxDecoration(
          color: CLIXTheme.driverCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: CLIXTheme.primary.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ручка
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Прогрес-бар етапів
            _buildTripProgressBar(order.status),
            const SizedBox(height: 16),

            // Статус-лейбл
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _statusProgressColor(
                  order.status,
                ).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusProgressIcon(order.status),
                    color: _statusProgressColor(order.status),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _tripStageLabel.isNotEmpty
                        ? _tripStageLabel
                        : order.statusDisplay,
                    style: TextStyle(
                      color: _statusProgressColor(order.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Адреси
            _DarkAddressRow(
              icon: Icons.radio_button_checked,
              iconColor: CLIXTheme.success,
              text: order.pickupAddress,
            ),
            const SizedBox(height: 8),
            _DarkAddressRow(
              icon: Icons.location_on,
              iconColor: CLIXTheme.error,
              text: order.dropoffAddress,
            ),

            // Телефон пасажира
            if (order.passengerPhone != null) ...[
              const SizedBox(height: 8),
              _DarkAddressRow(
                icon: Icons.phone,
                iconColor: CLIXTheme.primaryLight,
                text: order.passengerPhone!,
              ),
            ],

            // Ціна
            if (order.estimatedPrice != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${order.estimatedPrice!.toStringAsFixed(0)} ₴',
                    style: const TextStyle(
                      color: CLIXTheme.primaryLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Кнопка наступного кроку
            if (nextStatus != null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(nextStatus!),
                  icon: Icon(nextIcon, size: 20),
                  label: Text(
                    nextStatusLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nextStatus == 'COMPLETED'
                        ? CLIXTheme.success
                        : CLIXTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CLIXTheme.radiusMd),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Прогрес-бар поїздки (3 етапи) ──
  Widget _buildTripProgressBar(String status) {
    final stages = [
      _TripStage('Прибуття', 'ACCEPTED', Icons.navigation),
      _TripStage('Забираю', 'EN_ROUTE', Icons.person_pin_circle),
      _TripStage('В дорозі', 'IN_PROGRESS', Icons.directions_car),
      _TripStage('Готово', 'COMPLETED', Icons.check_circle),
    ];

    final currentIndex = stages.indexWhere((s) => s.statusKey == status);

    return Column(
      children: [
        // Лінійний прогрес
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _tripProgress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              _statusProgressColor(status),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        // Етапи
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stages.asMap().entries.map((entry) {
            final i = entry.key;
            final stage = entry.value;
            final isActive = i <= currentIndex;
            final isCurrent = i == currentIndex;

            return Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _statusProgressColor(
                            status,
                          ).withValues(alpha: isCurrent ? 1 : 0.4)
                        : Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    stage.icon,
                    size: 16,
                    color: isActive ? Colors.white : Colors.white38,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stage.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? Colors.white70 : Colors.white30,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _statusProgressColor(String status) {
    switch (status) {
      case 'ACCEPTED':
        return CLIXTheme.warning;
      case 'EN_ROUTE':
        return CLIXTheme.primary;
      case 'IN_PROGRESS':
        return CLIXTheme.success;
      default:
        return CLIXTheme.primaryLight;
    }
  }

  IconData _statusProgressIcon(String status) {
    switch (status) {
      case 'ACCEPTED':
        return Icons.navigation;
      case 'EN_ROUTE':
        return Icons.person_pin_circle;
      case 'IN_PROGRESS':
        return Icons.directions_car;
      default:
        return Icons.check_circle;
    }
  }
}

// ── Етапи подорожі ──
class _TripStage {
  final String label;
  final String statusKey;
  final IconData icon;

  const _TripStage(this.label, this.statusKey, this.icon);
}

// ── Рядок адреси (темна тема) ──
class _DarkAddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _DarkAddressRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
