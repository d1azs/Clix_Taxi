import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import 'driver_home_screen.dart';
import 'kyc_screen.dart'; // NEW

/// Головний екран водія з нижньою навігацією.
class DriverMainScreen extends StatefulWidget {
  const DriverMainScreen({super.key});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  int _currentIndex = 0;
  Timer? _kycPollTimer;
  final _historyKey = GlobalKey<_DriverHistoryPageState>();
  final _earningsKey = GlobalKey<_DriverEarningsPageState>();

  @override
  void initState() {
    super.initState();
    // Start polling KYC status if not yet approved
    _startKycPolling();
  }

  @override
  void dispose() {
    _kycPollTimer?.cancel();
    super.dispose();
  }

  void _startKycPolling() {
    _kycPollTimer?.cancel();
    _kycPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final auth = context.read<AuthProvider>();
      final status = auth.user?.kycStatus ?? 'NOT_SUBMITTED';
      if (status == 'APPROVED') {
        _kycPollTimer?.cancel();
        return;
      }
      await auth.refreshKycStatus();
    });
  }

  Widget _getRadarPage(String kycStatus) {
    if (kycStatus == 'APPROVED') {
      return const DriverHomeScreen();
    }
    if (kycStatus == 'PENDING') {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.orangeAccent),
            SizedBox(height: 16),
            Text('Ваші документи на перевірці',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            SizedBox(height: 8),
            Text('Очікуйте підтвердження диспетчера',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    // NOT_SUBMITTED or REJECTED
    return KYCScreen(
      onUploadSuccess: () async {
        // Refresh user profile from backend to get the real KYC status
        final auth = context.read<AuthProvider>();
        await auth.refreshKycStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Документи успішно відправлені!')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final kycStatus = auth.user?.kycStatus ?? 'NOT_SUBMITTED';

    final pages = [
      _getRadarPage(kycStatus),
      _DriverHistoryPage(key: _historyKey),
      _DriverEarningsPage(key: _earningsKey),
      const _DriverProfilePage(),
    ];

    return Theme(
      data: CLIXTheme.darkTheme,
      child: Scaffold(
        backgroundColor: CLIXTheme.driverBg,
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: CLIXTheme.driverCard,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   _navItem(Icons.map_outlined, Icons.map, 'Радар / KYC', 0),
                  _navItem(Icons.history_outlined, Icons.history, 'Історія', 1),
                  _navItem(
                    Icons.account_balance_wallet_outlined,
                    Icons.account_balance_wallet,
                    'Заробіток',
                    2,
                  ),
                  _navItem(Icons.person_outline, Icons.person, 'Профіль', 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        // Reload data when switching tabs
        if (index == 1) {
          _historyKey.currentState?._load();
        } else if (index == 2) {
          _earningsKey.currentState?._load();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? CLIXTheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(CLIXTheme.radiusFull),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? CLIXTheme.primaryLight : Colors.white38,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? CLIXTheme.primaryLight : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Історія поїздок водія
class _DriverHistoryPage extends StatefulWidget {
  const _DriverHistoryPage({super.key});
  @override
  State<_DriverHistoryPage> createState() => _DriverHistoryPageState();
}

class _DriverHistoryPageState extends State<_DriverHistoryPage> {
  final _api = ApiService();
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getOrderHistory();
      if (mounted) {
        setState(() {
          _orders = data.map((e) => OrderModel.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLIXTheme.driverBg,
      appBar: AppBar(
        title: const Text('Історія поїздок'),
        centerTitle: true,
        backgroundColor: CLIXTheme.driverCard,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: CLIXTheme.primaryLight),
            )
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ще немає поїздок',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Виконані поїздки будуть тут',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (_, i) => _DriverHistoryCard(order: _orders[i]),
              ),
            ),
    );
  }
}

class _DriverHistoryCard extends StatelessWidget {
  final OrderModel order;
  const _DriverHistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CLIXTheme.driverCard,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(CLIXTheme.radiusFull),
                  ),
                  child: Text(
                    order.statusDisplay,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (order.estimatedPrice != null)
                  Text(
                    '${order.estimatedPrice!.toStringAsFixed(0)} ₴',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: CLIXTheme.primaryLight,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.radio_button_checked,
                  size: 14,
                  color: CLIXTheme.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.pickupAddress,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: CLIXTheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.dropoffAddress,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (order.status) {
      case 'COMPLETED':
        return CLIXTheme.success;
      case 'CANCELLED':
        return CLIXTheme.error;
      default:
        return CLIXTheme.primaryLight;
    }
  }
}

/// Сторінка заробітку
class _DriverEarningsPage extends StatefulWidget {
  const _DriverEarningsPage({super.key});
  @override
  State<_DriverEarningsPage> createState() => _DriverEarningsPageState();
}

class _DriverEarningsPageState extends State<_DriverEarningsPage> {
  final _api = ApiService();
  double _totalEarnings = 0;
  int _totalTrips = 0;
  double _rating = 5.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getDriverStatus();
      if (mounted) {
        setState(() {
          _totalEarnings =
              double.tryParse(data['total_earnings']?.toString() ?? '0') ?? 0;
          _totalTrips = data['total_trips'] ?? 0;
          _rating = double.tryParse(data['rating']?.toString() ?? '5.0') ?? 5.0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLIXTheme.driverBg,
      appBar: AppBar(
        title: const Text('Заробіток та Статистика'),
        centerTitle: true,
        backgroundColor: CLIXTheme.driverCard,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),
            // Головна картка
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [CLIXTheme.primary, CLIXTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: CLIXTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Загальний заробіток',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          '${_totalEarnings.toStringAsFixed(0)} ₴',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_totalTrips поїздок',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Статистика
            Row(
              children: [
                _statCard(
                  'Середня варт.',
                  _totalTrips > 0
                      ? '${(_totalEarnings / _totalTrips).toStringAsFixed(0)} ₴'
                      : '0 ₴',
                  Icons.trending_up,
                ),
                const SizedBox(width: 12),
                _statCard(
                  'Рейтинг',
                  '${_rating.toStringAsFixed(1)} / 5',
                  Icons.star_rounded,
                  iconColor: Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, {Color? iconColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CLIXTheme.driverCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor ?? CLIXTheme.primaryLight, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
} // End of DriverEarningsPage

/// Профіль водія
class _DriverProfilePage extends StatelessWidget {
  const _DriverProfilePage();

  String _initials(UserModel? user) {
    if (user == null) return '?';
    final first = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final last = user.lastName.isNotEmpty ? user.lastName[0] : '';
    final initials = (first + last).toUpperCase().trim();
    return initials.isNotEmpty ? initials : '?';
  }

  Future<void> _showEditDialog(BuildContext context, UserModel user) async {
    final firstCtrl = TextEditingController(text: user.firstName);
    final lastCtrl = TextEditingController(text: user.lastName);
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: CLIXTheme.driverCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Редагувати профіль',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Ім'я",
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon:
                      const Icon(Icons.person_outline, color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: CLIXTheme.primaryLight, width: 2),
                  ),
                  filled: true,
                  fillColor: CLIXTheme.driverBg,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Прізвище',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon:
                      const Icon(Icons.person_outline, color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: CLIXTheme.primaryLight, width: 2),
                  ),
                  filled: true,
                  fillColor: CLIXTheme.driverBg,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text('Скасувати',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CLIXTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      setDlg(() => saving = true);
                      final auth = context.read<AuthProvider>();
                      final ok = await auth.updateProfile(
                        firstName: firstCtrl.text.trim(),
                        lastName: lastCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  ok ? Icons.check_circle_outline : Icons.error_outline,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  ok ? 'Профіль збережено' : 'Помилка збереження',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            backgroundColor:
                                ok ? CLIXTheme.success : CLIXTheme.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Зберегти'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyCarDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CLIXTheme.driverCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Моє авто', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.directions_car, color: Colors.white),
              title: const Text('Toyota Corolla', style: TextStyle(color: Colors.white)),
              subtitle: const Text('BC 1234 AB • Економ', style: TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.check_circle, color: CLIXTheme.success),
              tileColor: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CLIXTheme.primaryLight,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрити'),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showPayoutsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CLIXTheme.driverCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Способи виплат', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.white),
              title: const Text('Картка ПриватБанк', style: TextStyle(color: Colors.white)),
              subtitle: const Text('**** **** **** 1234', style: TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.check_circle, color: CLIXTheme.success),
              tileColor: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.white),
              title: const Text('Додати картку', style: TextStyle(color: Colors.white)),
              tileColor: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {},
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CLIXTheme.primaryLight,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрити'),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showMyRatingsDialog(BuildContext context) async {
    final api = ApiService();
    double rating = 5.0;
    int totalTrips = 0;
    try {
      final data = await api.getDriverStatus();
      rating = double.tryParse(data['rating']?.toString() ?? '5.0') ?? 5.0;
      totalTrips = data['total_trips'] ?? 0;
    } catch (_) {}

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CLIXTheme.driverCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Мої оцінки', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 5 зірок з відображенням рейтингу
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starVal = i + 1;
                if (rating >= starVal) {
                  return const Icon(Icons.star, size: 36, color: Colors.amber);
                } else if (rating >= starVal - 0.5) {
                  return const Icon(Icons.star_half, size: 36, color: Colors.amber);
                } else {
                  return Icon(Icons.star_border, size: 36, color: Colors.amber.shade200);
                }
              }),
            ),
            const SizedBox(height: 12),
            Text(
              '${rating.toStringAsFixed(2)} / 5.0',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'На основі $totalTrips поїздок',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              rating >= 4.5 ? 'Ви чудовий водій, так тримати!' :
              rating >= 3.5 ? 'Гарний результат, продовжуйте!' :
              'Покращуйте якість обслуговування',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CLIXTheme.primaryLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрити'),
          )
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CLIXTheme.driverCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Підтримка водіїв', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(
              leading: Icon(Icons.email_outlined, color: CLIXTheme.primaryLight),
              title: Text('drivers-support@clix.taxi', style: TextStyle(color: Colors.white)),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: Icon(Icons.phone_outlined, color: CLIXTheme.primaryLight),
              title: Text('+380 800 123 456', style: TextStyle(color: Colors.white)),
              contentPadding: EdgeInsets.zero,
            ),
            SizedBox(height: 12),
            Text('Лінія підтримки водіїв працює 24/7. Ми завжди на зв\'язку.',
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрити', style: TextStyle(color: CLIXTheme.primaryLight)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final initials = _initials(user);
    final fullName =
        user?.fullName.isNotEmpty == true ? user!.fullName : 'Водій';

    return Scaffold(
      backgroundColor: CLIXTheme.driverBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Аватар з ініціалами
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [CLIXTheme.primary, CLIXTheme.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: CLIXTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: user != null
                        ? () => _showEditDialog(context, user)
                        : null,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: CLIXTheme.driverCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: CLIXTheme.primaryLight.withValues(alpha: 0.3),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.edit,
                          size: 14, color: CLIXTheme.primaryLight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.phoneNumber ?? '',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),

              _profileTile(
                icon: Icons.edit_outlined,
                label: 'Редагувати профіль',
                onTap: () {
                  if (user != null) _showEditDialog(context, user);
                },
              ),
              _profileTile(
                icon: Icons.directions_car_outlined,
                label: 'Моє авто',
                onTap: () => _showMyCarDialog(context),
              ),
              _profileTile(
                icon: Icons.payment_outlined,
                label: 'Виплати',
                onTap: () => _showPayoutsDialog(context),
              ),
              _profileTile(
                icon: Icons.star_outline,
                label: 'Мої оцінки',
                onTap: () => _showMyRatingsDialog(context),
              ),
              _profileTile(
                icon: Icons.help_outline,
                label: 'Підтримка',
                onTap: () => _showSupportDialog(context),
              ),
              if (auth.user?.hasMultipleRoles ?? false)
                _profileTile(
                  icon: Icons.swap_horiz,
                  label: 'Режим пасажира',
                  color: CLIXTheme.primaryLight,
                  onTap: () => auth.switchRole('PASSENGER'),
                ),
              const Divider(color: Colors.white10, height: 32),
              _profileTile(
                icon: Icons.logout,
                label: 'Вийти',
                color: CLIXTheme.error,
                onTap: () => auth.logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      color: CLIXTheme.driverCard,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.white54),
        title: Text(
          label,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: color ?? Colors.white24,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}

