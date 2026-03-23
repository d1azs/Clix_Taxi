import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import 'passenger_home_screen.dart';

/// Головний екран пасажира з нижньою навігацією.
class PassengerMainScreen extends StatefulWidget {
  const PassengerMainScreen({super.key});

  @override
  State<PassengerMainScreen> createState() => _PassengerMainScreenState();
}

class _PassengerMainScreenState extends State<PassengerMainScreen> {
  int _currentIndex = 0;

  final _pages = const [
    PassengerHomeScreen(),
    _HistoryPage(),
    _ScheduledPage(),
    _ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: CLIXTheme.primary.withValues(alpha: 0.08),
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
                _navItem(Icons.map_outlined, Icons.map, 'Карта', 0),
                _navItem(Icons.history_outlined, Icons.history, 'Історія', 1),
                _navItem(
                  Icons.schedule_outlined,
                  Icons.schedule,
                  'Заплановані',
                  2,
                ),
                _navItem(Icons.person_outline, Icons.person, 'Профіль', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? CLIXTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(CLIXTheme.radiusFull),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? CLIXTheme.primary : CLIXTheme.textHint,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? CLIXTheme.primary : CLIXTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Сторінка історії поїздок
class _HistoryPage extends StatefulWidget {
  const _HistoryPage();

  @override
  State<_HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage> {
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
      backgroundColor: CLIXTheme.surface,
      appBar: AppBar(
        title: const Text('Історія поїздок'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: CLIXTheme.textHint.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ще немає поїздок',
                    style: TextStyle(color: CLIXTheme.textHint, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ваші завершені поїздки будуть тут',
                    style: TextStyle(color: CLIXTheme.textHint, fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (_, i) => _HistoryCard(order: _orders[i]),
              ),
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final OrderModel order;
  const _HistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    color: _statusColor.withValues(alpha: 0.12),
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
                      color: CLIXTheme.primary,
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
                    style: const TextStyle(fontSize: 13),
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
                    style: const TextStyle(fontSize: 13),
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
        return CLIXTheme.primary;
    }
  }
}

/// Сторінка запланованих поїздок
class _ScheduledPage extends StatelessWidget {
  const _ScheduledPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLIXTheme.surface,
      appBar: AppBar(
        title: const Text('Заплановані поїздки'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              size: 64,
              color: CLIXTheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'Немає запланованих',
              style: TextStyle(color: CLIXTheme.textHint, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Заплановані поїздки з\'являться тут',
              style: TextStyle(color: CLIXTheme.textHint, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Сторінка профілю
class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: CLIXTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Аватар
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [CLIXTheme.primary, CLIXTheme.primaryDark],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (user?.firstName.isNotEmpty == true)
                        ? user!.firstName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                user?.firstName ?? 'Пасажир',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.phoneNumber ?? '',
                style: const TextStyle(
                  color: CLIXTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),

              // Меню
              _profileTile(
                icon: Icons.edit_outlined,
                label: 'Редагувати профіль',
                onTap: () {},
              ),
              _profileTile(
                icon: Icons.payment_outlined,
                label: 'Спосіб оплати',
                onTap: () {},
              ),
              _profileTile(
                icon: Icons.star_outline,
                label: 'Мої оцінки',
                onTap: () {},
              ),
              _profileTile(
                icon: Icons.help_outline,
                label: 'Підтримка',
                onTap: () {},
              ),
              if (auth.user?.hasMultipleRoles ?? false)
                _profileTile(
                  icon: Icons.swap_horiz,
                  label: 'Режим водія',
                  color: CLIXTheme.primary,
                  onTap: () => auth.switchRole('DRIVER'),
                ),
              const Divider(height: 32),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color ?? CLIXTheme.textSecondary),
        title: Text(
          label,
          style: TextStyle(
            color: color ?? CLIXTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: color ?? CLIXTheme.textHint,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}
