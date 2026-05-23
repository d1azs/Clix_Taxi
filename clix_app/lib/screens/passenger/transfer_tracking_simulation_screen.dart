import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/transfer_simulation_provider.dart';

class TransferTrackingSimulationScreen extends StatefulWidget {
  const TransferTrackingSimulationScreen({super.key});

  @override
  State<TransferTrackingSimulationScreen> createState() => _TransferTrackingSimulationScreenState();
}

class _TransferTrackingSimulationScreenState extends State<TransferTrackingSimulationScreen> {
  final MapController _mapController = MapController();
  Timer? _timer;
  int _currentIndex = 0;
  bool _arrived = false;

  // Рецензування поїздки
  int _selectedStars = 5;
  final TextEditingController _reviewController = TextEditingController();

  // Навігаційні статуси відповідно до точок маршруту
  final List<String> _navigationStages = [
    "Посадка в аеропорту ім. Данила Галицького...",
    "Виїзд з території аеропорту...",
    "Рух по вулиці Любінській (біля вул. Виговського)...",
    "Проїжджаємо перехрестя з вул. Окружною...",
    "Рух по вул. Любінській у напрямку центру...",
    "Проїжджаємо площу Кропивницького...",
    "Повертаємо на вулицю Степана Бандери...",
    "Рух по вул. Бандери біля собору...",
    "Повертаємо на вулицю Коперника...",
    "Проїжджаємо біля Палацу Потоцьких...",
    "Рух по вулиці Словацького...",
    "Виїжджаємо на проспект Свободи...",
    "Проїжджаємо площу Галицьку...",
    "Прибуття до готелю Nobilis (вул. Фредра, 7)!"
  ];

  @override
  void initState() {
    super.initState();
    // Починаємо рух машинки через 2 секунди після відкриття екрану
    Future.delayed(const Duration(seconds: 2), _startSimulation);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reviewController.dispose();
    super.dispose();
  }

  void _startSimulation() {
    if (!mounted) return;
    
    final simulation = context.read<TransferSimulationProvider>();
    final points = simulation.routePoints;

    _timer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (_currentIndex < points.length - 1) {
        setState(() {
          _currentIndex++;
        });
        
        // Плавно переміщуємо карту слідом за машиною
        _mapController.move(points[_currentIndex], 15.5);
      } else {
        t.cancel();
        setState(() {
          _arrived = true;
        });
        // Викликаємо метод провайдера для завершення
        context.read<TransferSimulationProvider>().completeRide();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final simulation = context.watch<TransferSimulationProvider>();
    final points = simulation.routePoints;
    final currentPos = points[_currentIndex];

    // Розрахунок очікуваного часу прибуття (ЕТА)
    final int etaMinutes = _arrived ? 0 : ((points.length - _currentIndex) * 1.2).ceil();

    return Scaffold(
      body: Stack(
        children: [
          // ── КАРТА ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: points[0],
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.clix.app',
              ),
              // Малюємо лінію маршруту
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 5.0,
                    color: Colors.blue.shade600,
                    borderStrokeWidth: 2.0,
                    borderColor: Colors.blue.shade900.withValues(alpha: 0.3),
                  ),
                ],
              ),
              // Маркер автомобіля таксі
              MarkerLayer(
                markers: [
                  Marker(
                    point: currentPos,
                    width: 50.0,
                    height: 50.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(color: Colors.blue.shade600, width: 2.5),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_taxi,
                          color: Colors.black87,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── ВЕРХНЯ ПАНЕЛЬ: ДЕТАЛІ ВОДІЯ ──
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.shade100, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.airport_shuttle, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'BOOKING.COM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Трансфер #${simulation.bookingId}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CLIXTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            simulation.driverName.isNotEmpty ? simulation.driverName : 'Пошук водія...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: CLIXTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${simulation.carModel} • ${simulation.carNumber}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CLIXTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            simulation.driverRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── НИЖНЯ ПАНЕЛЬ: СТАТУС РУХУ ──
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _arrived ? "Ви прибули!" : "Прибуття через $etaMinutes хв",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _arrived ? Colors.green.shade700 : CLIXTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${simulation.price.toStringAsFixed(0)} ₴',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _arrived ? Icons.check_circle : Icons.navigation,
                          color: _arrived ? Colors.green : Colors.blue.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _navigationStages[_currentIndex],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: CLIXTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Індикатор прогресу симуляції
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _currentIndex / (points.length - 1),
                        backgroundColor: Colors.grey.shade100,
                        color: Colors.blue.shade600,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── ВІКНО ОЦІНКИ ТА ВІДГУКУ (ПРИБУТТЯ) ──
          if (_arrived)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Card(
                          color: Colors.white,
                          elevation: 12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.done_all_rounded,
                                    color: Colors.green,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Трансфер завершено!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: CLIXTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Ви прибули до готелю Nobilis.\nБудь ласка, оцініть поїздку з ${simulation.driverName}.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: CLIXTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Вибір зірочок
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    final int ratingVal = index + 1;
                                    return IconButton(
                                      icon: Icon(
                                        Icons.star,
                                        size: 36,
                                        color: ratingVal <= _selectedStars
                                            ? Colors.amber
                                            : Colors.grey.shade300,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedStars = ratingVal;
                                        });
                                      },
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                // Поле коментаря
                                TextField(
                                  controller: _reviewController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText: 'Залиште свій відгук (необов\'язково)...',
                                    hintStyle: const TextStyle(fontSize: 13),
                                    fillColor: Colors.grey.shade50,
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Надіслати відгук та закрити
                                      simulation.submitReview(
                                        _selectedStars,
                                        _reviewController.text.trim(),
                                      );
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: CLIXTheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Надіслати відгук та закрити',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}