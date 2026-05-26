import 'dart:async';
import 'dart:math' show cos, Random;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transfer_simulation_provider.dart';
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
  double _driverRating = 4.9;
  String? _driverProfileId;
  String? _lastGlobalSimStatus;
  String _driverCar = 'Skoda Octavia';
  String _driverPlate = 'BC 1234 AA';
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
  List<LatLng> _visibleRoute = []; // поточна видима частина маршруту

  // ── DEMO анімація руху машини водія ──
  LatLng? _demoCarLocation; // поточна позиція машини на карті
  Timer? _demoCarTimer;
  List<LatLng> _demoCarWaypoints = [];
  int _demoCarIndex = 0;
  bool _demoCarActive = false;
  String? _lastSimStatus;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final simulation = Provider.of<TransferSimulationProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    if (_lastGlobalSimStatus != simulation.status) {
      final oldGlobal = _lastGlobalSimStatus;
      _lastGlobalSimStatus = simulation.status;
      if (simulation.status == 'NONE' && oldGlobal == 'COMPLETED') {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _loadDriverInfo();
          }
        });
      }
    }

    final isSimActive = (simulation.status == 'CONFIRMED' || simulation.status == 'ARRIVED' || simulation.status == 'LIVE_RIDE') &&
        simulation.driverPhone == auth.user?.phoneNumber;

    if (isSimActive) {
      if (_lastSimStatus != simulation.status) {
        final oldStatus = _lastSimStatus;
        _lastSimStatus = simulation.status;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _onSimStatusChanged(simulation.status, oldStatus, simulation);
          }
        });
      }
    } else {
      if (_lastSimStatus != null) {
        final wasLive = _lastSimStatus == 'LIVE_RIDE';
        _lastSimStatus = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _stopSimTransfer();
            // Після завершення трансферу оновлюємо статистику
            if (wasLive) {
              _loadDriverInfo();
            }
          }
        });
      }
    }
  }

  void _onSimStatusChanged(String newStatus, String? oldStatus, TransferSimulationProvider simulation) {
    if (newStatus == 'CONFIRMED') {
      _startSimApproach(simulation);
    } else if (newStatus == 'ARRIVED') {
      _stopSimTransfer();
      setState(() {
        _demoCarLocation = simulation.routePoints.first;
        _routePoints = simulation.routePoints;
        _visibleRoute = List.from(simulation.routePoints);
      });
      simulation.updateDriverProgress(
        lat: _demoCarLocation!.latitude,
        lng: _demoCarLocation!.longitude,
        index: 0,
      );
      _api.updateDriverLocation(_demoCarLocation!.latitude, _demoCarLocation!.longitude).catchError((_) {});
      _fitRouteOnMap();
    } else if (newStatus == 'LIVE_RIDE') {
      _startSimTrip(simulation);
    }
  }

  void _startSimApproach(TransferSimulationProvider simulation) {
    _stopSimTransfer();
    final waypoints = simulation.approachPoints;
    setState(() {
      _routePoints = waypoints;
      _visibleRoute = List.from(waypoints);
      _demoCarLocation = waypoints.first;
    });
    _fitRouteOnMap();

    int index = 0;
    simulation.updateDriverProgress(
      lat: _demoCarLocation!.latitude,
      lng: _demoCarLocation!.longitude,
      index: index,
    );
    _api.updateDriverLocation(_demoCarLocation!.latitude, _demoCarLocation!.longitude).catchError((_) {});

    _demoCarActive = true;
    _demoCarTimer = Timer.periodic(const Duration(milliseconds: 3000), (t) {
      if (!mounted || !_demoCarActive) {
        t.cancel();
        return;
      }
      if (index < waypoints.length - 1) {
        index++;
        setState(() {
          _demoCarLocation = waypoints[index];
          _visibleRoute = waypoints.sublist(index);
        });
        simulation.updateDriverProgress(
          lat: _demoCarLocation!.latitude,
          lng: _demoCarLocation!.longitude,
          index: index,
        );
        _api.updateDriverLocation(_demoCarLocation!.latitude, _demoCarLocation!.longitude).catchError((_) {});
      } else {
        t.cancel();
        simulation.arriveAtPickup();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Ви прибули на місце посадки!'),
              backgroundColor: CLIXTheme.success,
            ),
          );
        }
      }
    });
  }

  void _startSimTrip(TransferSimulationProvider simulation) {
    _stopSimTransfer();
    final waypoints = simulation.routePoints;
    setState(() {
      _routePoints = waypoints;
      _visibleRoute = List.from(waypoints);
      _demoCarLocation = waypoints.first;
    });
    _fitRouteOnMap();

    int index = 0;
    simulation.updateDriverProgress(
      lat: _demoCarLocation!.latitude,
      lng: _demoCarLocation!.longitude,
      index: index,
    );
    _api.updateDriverLocation(_demoCarLocation!.latitude, _demoCarLocation!.longitude).catchError((_) {});

    _demoCarActive = true;
    _demoCarTimer = Timer.periodic(const Duration(milliseconds: 3000), (t) {
      if (!mounted || !_demoCarActive) {
        t.cancel();
        return;
      }
      if (index < waypoints.length - 1) {
        index++;
        setState(() {
          _demoCarLocation = waypoints[index];
          _visibleRoute = waypoints.sublist(index);
        });
        simulation.updateDriverProgress(
          lat: _demoCarLocation!.latitude,
          lng: _demoCarLocation!.longitude,
          index: index,
        );
        _api.updateDriverLocation(_demoCarLocation!.latitude, _demoCarLocation!.longitude).catchError((_) {});
      } else {
        t.cancel();
        simulation.completeRide();
      }
    });
  }

  void _stopSimTransfer() {
    _demoCarTimer?.cancel();
    _demoCarActive = false;
    if (_currentOrder == null) {
      setState(() {
        _demoCarLocation = null;
        _routePoints = [];
        _visibleRoute = [];
      });
    }
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
    _demoCarTimer?.cancel();
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
          _driverRating = double.tryParse(data['rating']?.toString() ?? '4.9') ?? 4.9;
          _driverProfileId = data['id']?.toString();
          final v = data['vehicle'];
          if (v != null) {
            _driverCar = v['make_model'] ?? 'Skoda Octavia';
            _driverPlate = v['license_plate'] ?? 'BC 1234 AA';
          }
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
      if (newStatus == 'ONLINE') {
        double? lat = _userLocation?.latitude;
        double? lng = _userLocation?.longitude;
        if (lat == null || lng == null) {
          // Дефолтні координати Львова (Скнилівська розв'язка), щоб водій з'явився
          lat = 49.8220;
          lng = 23.9740;
        }
        await _api.updateDriverStatus(newStatus, lat: lat, lng: lng);
      } else {
        await _api.updateDriverStatus(newStatus);
      }
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
      final acceptedOrder = OrderModel.fromJson(data);
      setState(() {
        _currentOrder = acceptedOrder;
        _availableOrders.clear();
      });
      _stopPolling();
      _startTripProgress('ACCEPTED');
      _buildOrderRoute(acceptedOrder);
      // DEMO: починаємо рух до пасажира
      _startDemoCarToPickup(acceptedOrder);
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
        final earned = _currentOrder!.estimatedPrice ?? 0;
        setState(() {
          _currentOrder = null;
          _todayTrips += 1;
          _todayEarnings += earned;
          _tripProgress = 0;
          _routePoints = [];
          _visibleRoute = [];
          _demoCarLocation = null;
        });
        _stopDemoCar();
        _progressTimer?.cancel();
        _startPolling();
      } else {
        final updatedOrder = OrderModel.fromJson(data);
        setState(() => _currentOrder = updatedOrder);
        _startTripProgress(newStatus);
        // DEMO: запускаємо анімацію по зміні статусу
        if (newStatus == 'EN_ROUTE') {
          // водій "прибув" — машина стає біля пасажира
          _stopDemoCar();
          setState(() {
            _demoCarLocation = LatLng(updatedOrder.pickupLat, updatedOrder.pickupLng);
          });
        } else if (newStatus == 'IN_PROGRESS') {
          _startDemoCarTrip(updatedOrder);
        }
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
      setState(() {
        _routePoints = points;
        _visibleRoute = List.from(points);
      });
      // Авто-зум щоб маршрут помістився
      _fitRouteOnMap();
    }
  }

  // ── DEMO: водій рухається до пасажира (ACCEPTED/EN_ROUTE) ──
  void _startDemoCarToPickup(OrderModel order) async {
    _stopDemoCar();
    final pickup = LatLng(order.pickupLat, order.pickupLng);
    // Старт ~ 0.5 км від pickup (фактична позиція водія до прийняття)
    final rng = Random();
    final angleRad = rng.nextDouble() * 6.28318;
    final startPt = LatLng(
      pickup.latitude + 0.004 * cos(angleRad),
      pickup.longitude + 0.007 * cos(angleRad + 1.1),
    );
    final route = await _routing.getRoute(startPt, pickup);
    final waypoints = route ?? _interpolateWaypoints(startPt, pickup, 16);
    if (!mounted) return;
    setState(() {
      _demoCarWaypoints = waypoints;
      _demoCarIndex = 0;
      _demoCarLocation = waypoints.first;
    });
    _demoCarActive = true;
    _demoCarTimer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
      if (!mounted || !_demoCarActive) { t.cancel(); return; }
      if (_demoCarIndex < _demoCarWaypoints.length - 1) {
        _demoCarIndex++;
        setState(() {
          _demoCarLocation = _demoCarWaypoints[_demoCarIndex];
        });
      } else {
        t.cancel();
      }
    });
  }

  // ── DEMO: водій везе пасажира до призначення (IN_PROGRESS) по OSRMмаршруту ──
  void _startDemoCarTrip(OrderModel order) async {
    _stopDemoCar();
    final from = LatLng(order.pickupLat, order.pickupLng);
    final waypoints = _routePoints.isNotEmpty
        ? _routePoints
        : (await _routing.getRoute(from, LatLng(order.dropoffLat, order.dropoffLng)))
            ?? _interpolateWaypoints(from, LatLng(order.dropoffLat, order.dropoffLng), 20);
    if (!mounted) return;
    setState(() {
      _demoCarWaypoints = waypoints;
      _demoCarIndex = 0;
      _demoCarLocation = waypoints.first;
      _visibleRoute = List.from(waypoints);
    });
    _demoCarActive = true;
    _demoCarTimer = Timer.periodic(const Duration(milliseconds: 1600), (t) {
      if (!mounted || !_demoCarActive) { t.cancel(); return; }
      if (_demoCarIndex < _demoCarWaypoints.length - 1) {
        _demoCarIndex++;
        setState(() {
          _demoCarLocation = _demoCarWaypoints[_demoCarIndex];
          _visibleRoute = _demoCarWaypoints.sublist(_demoCarIndex);
        });
      } else {
        t.cancel();
      }
    });
  }

  void _stopDemoCar() {
    _demoCarTimer?.cancel();
    _demoCarActive = false;
  }

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
    final simulation = context.watch<TransferSimulationProvider>();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final isSimActive = (simulation.status == 'CONFIRMED' || simulation.status == 'ARRIVED' || simulation.status == 'LIVE_RIDE') &&
        simulation.driverPhone == auth.user?.phoneNumber;

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
            if (isSimActive)
              _buildSimulatedActiveTripSheet(bottomPadding, simulation)
            else if (_currentOrder != null)
              _buildActiveTripSheet(bottomPadding)
            else if (_isOnline && simulation.status == 'PENDING' && simulation.autoAssign)
              _buildSimulatedTransferOfferSheet(bottomPadding, simulation)
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
                points: _visibleRoute.isNotEmpty ? _visibleRoute : _routePoints,
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
            // DEMO: машина водія
            if (_demoCarLocation != null)
              Marker(
                point: _demoCarLocation!,
                width: 54,
                height: 54,
                child: const _DriverCarMarker(),
              ),
            // Маркери поточного замовлення
            if (_currentOrder != null) ...[
              // Точка підбору — прибираємо коли пасажир вже в машині
              if (_currentOrder!.status != 'IN_PROGRESS')
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
  // ── Симуляція: Пропозиція трансферу Booking.com (хто перший забере) ──
  Widget _buildSimulatedTransferOfferSheet(double bottomPadding, TransferSimulationProvider simulation) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: 16 + bottomPadding, left: 16, right: 16),
        child: Card(
          color: CLIXTheme.driverCard,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.airport_shuttle, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'BOOKING.COM ТРАНСФЕР',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${simulation.price.toStringAsFixed(0)} ₴',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Нове замовлення! Хто перший забере',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Divider(height: 20, color: Colors.white24),
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        simulation.pickupAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        simulation.dropoffAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => simulation.resetSimulation(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Відхилити', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final auth = context.read<AuthProvider>();
                          final name = auth.user?.fullName ?? 'Олександр Мельник';
                          final phone = auth.user?.phoneNumber ?? '+380661234567';
                          
                          simulation.assignDriver(
                            name: name,
                            phone: phone,
                            car: _driverCar,
                            number: _driverPlate,
                            rating: _driverRating,
                            driverProfileId: _driverProfileId,
                          );
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Ви успішно прийняли трансфер Booking.com!'),
                              backgroundColor: CLIXTheme.success,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CLIXTheme.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text(
                          'ПРИЙНЯТИ',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Симуляція: Активний екран поїздки водія Booking.com ──
  Widget _buildSimulatedActiveTripSheet(double bottomPadding, TransferSimulationProvider simulation) {
    final status = simulation.status;
    final isConfirmed = status == 'CONFIRMED';
    final isArrived = status == 'ARRIVED';
    final isLive = status == 'LIVE_RIDE';

    String statusLabel = '';
    String buttonLabel = '';
    IconData? buttonIcon;
    VoidCallback? onButtonPressed;
    Color buttonColor = CLIXTheme.primary;

    if (isConfirmed) {
      statusLabel = 'Водій прямує до аеропорту (Прийнято)';
      buttonLabel = 'Я на місці';
      buttonIcon = Icons.place;
      onButtonPressed = () {
        simulation.arriveAtPickup();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ви прибули в аеропорт! Очікуйте пасажира.')),
        );
      };
    } else if (isArrived) {
      statusLabel = 'Очікування посадки пасажира (Прибув)';
      buttonLabel = 'Розпочати поїздку';
      buttonIcon = Icons.directions_car;
      onButtonPressed = () {
        simulation.startRide();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Поїздку розпочато! Відкрийте карту у пасажира для відстеження.')),
        );
      };
    } else if (isLive) {
      statusLabel = 'Поїздка в процесі симуляції на мапі...';
      buttonLabel = 'Завершити поїздку';
      buttonIcon = Icons.check_circle;
      buttonColor = CLIXTheme.success;
      onButtonPressed = () {
        simulation.completeRide();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Трансфер успішно завершено!')),
        );
      };
    } else if (status == 'COMPLETED') {
      statusLabel = 'Трансфер завершено!';
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: 16 + bottomPadding, left: 16, right: 16),
        child: Card(
          color: CLIXTheme.driverCard,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.blue.shade400, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'АКТИВНИЙ ТРАНСФЕР (BOOKING)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${simulation.price.toStringAsFixed(0)} ₴',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Прогрес-бар симуляції
                _buildSimulatedTripProgressBar(status),
                const SizedBox(height: 16),

                // Статус-опис
                if (statusLabel.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _PulsingStatusIcon(
                          icon: isLive ? Icons.navigation : (isArrived ? Icons.place : Icons.check_circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.person, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          simulation.passengerName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          simulation.passengerPhone,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white24),
                if (onButtonPressed != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onButtonPressed,
                      icon: Icon(buttonIcon, color: Colors.white, size: 20),
                      label: Text(
                        buttonLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () {
                      simulation.resetSimulation();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Трансфер скасовано.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Скасувати трансфер', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Прогрес-бар симуляції трансферу (4 етапи) ──
  Widget _buildSimulatedTripProgressBar(String status) {
    final stages = [
      const _TripStage('Прийнято', 'CONFIRMED', Icons.check_circle),
      const _TripStage('Прибув', 'ARRIVED', Icons.place),
      const _TripStage('В дорозі', 'LIVE_RIDE', Icons.directions_car),
      const _TripStage('Готово', 'COMPLETED', Icons.flag),
    ];

    final currentIndex = stages.indexWhere((s) => s.statusKey == status);
    
    double progress = 0.0;
    if (status == 'CONFIRMED') progress = 0.25;
    else if (status == 'ARRIVED') progress = 0.5;
    else if (status == 'LIVE_RIDE') progress = 0.75;
    else if (status == 'COMPLETED') progress = 1.0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Colors.blue,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stages.asMap().entries.map((entry) {
            final i = entry.key;
            final stage = entry.value;
            final isActive = i <= currentIndex || (status == 'COMPLETED');
            final isCurrent = stage.statusKey == status;

            return Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.blue.withValues(alpha: isCurrent ? 1.0 : 0.4)
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

// ── DEMO: фіолетова пульсуюча іконка машини водія на карті ──
class _DriverCarMarker extends StatefulWidget {
  const _DriverCarMarker();

  @override
  State<_DriverCarMarker> createState() => _DriverCarMarkerState();
}

class _DriverCarMarkerState extends State<_DriverCarMarker>
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
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CLIXTheme.primary.withValues(alpha: 0.22),
            ),
          ),
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

// ── Пульсуючий індикатор статусу для водія ──
class _PulsingStatusIcon extends StatefulWidget {
  final IconData icon;
  const _PulsingStatusIcon({required this.icon});

  @override
  State<_PulsingStatusIcon> createState() => _PulsingStatusIconState();
}

class _PulsingStatusIconState extends State<_PulsingStatusIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.2).animate(
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
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withValues(alpha: 0.2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          widget.icon,
          color: Colors.blue,
          size: 16,
        ),
      ),
    );
  }
}
