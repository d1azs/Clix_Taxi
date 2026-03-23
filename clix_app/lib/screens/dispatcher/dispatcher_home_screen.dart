import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/geocoding_service.dart';
import '../../models/models.dart';

/// Екран диспетчера — моніторинг та створення замовлень.
class DispatcherHomeScreen extends StatefulWidget {
  const DispatcherHomeScreen({super.key});

  @override
  State<DispatcherHomeScreen> createState() => _DispatcherHomeScreenState();
}

class _DispatcherHomeScreenState extends State<DispatcherHomeScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _geocoding = GeocodingService();
  late TabController _tabController;
  List<OrderModel> _orders = [];
  List<dynamic> _complaints = [];
  bool _isLoading = true;

  String _selectedCity = 'Львів';
  static const _cities = [
    'Львів',
    'Київ',
    'Одеса',
    'Харків',
    'Дніпро',
    'Запоріжжя',
    'Вінниця',
    'Івано-Франківськ',
    'Тернопіль',
    'Чернівці',
    'Рівне',
    'Луцьк',
    'Ужгород',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final ordersData = await _api.getDispatcherOrders();
      final complaintsData = await _api.getComplaints();
      if (mounted) {
        setState(() {
          _orders = ordersData.map((e) => OrderModel.fromJson(e)).toList();
          _complaints = complaintsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: CLIXTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CLIXTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'CLIX',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Диспетчер',
                style: TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          _buildCityDropdown(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.logout, color: CLIXTheme.error),
            onPressed: () => auth.logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: CLIXTheme.primary,
          unselectedLabelColor: CLIXTheme.textSecondary,
          indicatorColor: CLIXTheme.primary,
          tabs: [
            Tab(text: 'Активні (${_activeOrders.length})'),
            Tab(text: 'Всі (${_orders.length})'),
            Tab(text: 'Скарги (${_complaints.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(_activeOrders),
                _buildOrderList(_orders),
                _buildComplaintsList(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrderDialog(context),
        backgroundColor: CLIXTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Нове замовлення',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: CLIXTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CLIXTheme.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCity,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: CLIXTheme.primary,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CLIXTheme.textPrimary,
          ),
          items: _cities
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_city,
                        size: 14,
                        color: CLIXTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(c),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedCity = v);
          },
        ),
      ),
    );
  }

  List<OrderModel> get _activeOrders => _orders
      .where((o) => !['COMPLETED', 'CANCELLED'].contains(o.status))
      .toList();

  Widget _buildOrderList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: CLIXTheme.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Немає замовлень',
              style: TextStyle(color: CLIXTheme.textHint),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (_, i) => _OrderCard(order: orders[i]),
      ),
    );
  }

  Widget _buildComplaintsList() {
    if (_complaints.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: CLIXTheme.success.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Скарг немає',
              style: TextStyle(color: CLIXTheme.textHint),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _complaints.length,
      itemBuilder: (_, i) {
        final c = _complaints[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.warning_amber, color: CLIXTheme.error),
            title: Text('Скарга: ★${c['rating']}'),
            subtitle: Text(c['comment'] ?? 'Без коментаря'),
          ),
        );
      },
    );
  }

  /// Діалог створення замовлення з адресним пошуком
  void _showCreateOrderDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateOrderSheet(
        geocoding: _geocoding,
        api: _api,
        city: _selectedCity,
        onCreated: _loadData,
      ),
    );
  }
}

/// Окремий StatefulWidget для форми створення замовлення
class _CreateOrderSheet extends StatefulWidget {
  final GeocodingService geocoding;
  final ApiService api;
  final String city;
  final VoidCallback onCreated;

  const _CreateOrderSheet({
    required this.geocoding,
    required this.api,
    required this.city,
    required this.onCreated,
  });

  @override
  State<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends State<_CreateOrderSheet> {
  final _phoneCtrl = TextEditingController(text: '+380');
  final _pickupCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  String _selectedClass = 'ECONOMY';
  DateTime? _scheduledTime;
  Timer? _debounce;

  List<AddressSuggestion> _pickupSuggestions = [];
  List<AddressSuggestion> _dropoffSuggestions = [];
  AddressSuggestion? _selectedPickup;
  AddressSuggestion? _selectedDropoff;
  bool _isCreating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _phoneCtrl.dispose();
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query, {required bool isPickup}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (query.trim().length < 2) {
        setState(() {
          if (isPickup) {
            _pickupSuggestions = [];
          } else {
            _dropoffSuggestions = [];
          }
        });
        return;
      }
      final results = await widget.geocoding.searchAddress(query);
      if (mounted) {
        setState(() {
          if (isPickup) {
            _pickupSuggestions = results;
          } else {
            _dropoffSuggestions = results;
          }
        });
      }
    });
  }

  void _selectAddr(AddressSuggestion addr, {required bool isPickup}) {
    setState(() {
      if (isPickup) {
        _selectedPickup = addr;
        _pickupCtrl.text = addr.shortName;
        _pickupSuggestions = [];
      } else {
        _selectedDropoff = addr;
        _dropoffCtrl.text = addr.shortName;
        _dropoffSuggestions = [];
      }
    });
  }

  Future<void> _create() async {
    if (_pickupCtrl.text.trim().isEmpty || _dropoffCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _isCreating = true);
    final pickupLat = _selectedPickup?.lat ?? 49.8397;
    final pickupLng = _selectedPickup?.lng ?? 24.0297;
    final dropoffLat = _selectedDropoff?.lat ?? 49.8429;
    final dropoffLng = _selectedDropoff?.lng ?? 24.0315;
    final pickupTime = _scheduledTime ?? DateTime.now();

    try {
      await widget.api.createDispatcherOrder(
        passengerPhone: _phoneCtrl.text.trim(),
        pickupAddress: _pickupCtrl.text.trim(),
        dropoffAddress: _dropoffCtrl.text.trim(),
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        pickupTime: pickupTime.toIso8601String(),
        requiredClass: _selectedClass,
      );
      if (mounted) Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Створити замовлення',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Місто: ${widget.city}',
              style: const TextStyle(
                color: CLIXTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),

            // Телефон
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Телефон клієнта',
                hintText: '+380 97 123 4567',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12, right: 4),
                  child: Text('🇺🇦', style: TextStyle(fontSize: 18)),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Адреса подачі + підказки
            TextField(
              controller: _pickupCtrl,
              onChanged: (q) => _onSearch(q, isPickup: true),
              decoration: const InputDecoration(
                labelText: 'Адреса подачі',
                hintText: 'вул. Шевченка, 10',
                prefixIcon: Icon(
                  Icons.radio_button_checked,
                  color: CLIXTheme.success,
                  size: 18,
                ),
              ),
            ),
            if (_pickupSuggestions.isNotEmpty)
              _buildSuggestions(_pickupSuggestions, isPickup: true),
            const SizedBox(height: 12),

            // Адреса призначення + підказки
            TextField(
              controller: _dropoffCtrl,
              onChanged: (q) => _onSearch(q, isPickup: false),
              decoration: const InputDecoration(
                labelText: 'Адреса призначення',
                hintText: 'пр. Свободи, 28',
                prefixIcon: Icon(
                  Icons.location_on,
                  color: CLIXTheme.error,
                  size: 18,
                ),
              ),
            ),
            if (_dropoffSuggestions.isNotEmpty)
              _buildSuggestions(_dropoffSuggestions, isPickup: false),
            const SizedBox(height: 14),

            // Клас авто
            const Text(
              'Клас авто',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CLIXTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('ECONOMY', 'Економ'),
                _chip('PREMIUM', 'Комфорт'),
                _chip('BUSINESS', 'Бізнес'),
                _chip('MINIVAN', 'Мінівен'),
              ],
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
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _create,
                child: _isCreating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _scheduledTime != null
                            ? 'Запланувати'
                            : 'Створити замовлення',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final sel = value == _selectedClass;
    return GestureDetector(
      onTap: () => setState(() => _selectedClass = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel
              ? CLIXTheme.primary.withValues(alpha: 0.12)
              : CLIXTheme.surface,
          borderRadius: BorderRadius.circular(CLIXTheme.radiusFull),
          border: Border.all(
            color: sel ? CLIXTheme.primary : CLIXTheme.divider,
            width: sel ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? CLIXTheme.primary : CLIXTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(
    List<AddressSuggestion> list, {
    required bool isPickup,
  }) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
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
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final s = list[i];
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.place,
              color: CLIXTheme.primary,
              size: 18,
            ),
            title: Text(
              s.shortName,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              s.displayName,
              style: const TextStyle(fontSize: 11, color: CLIXTheme.textHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectAddr(s, isPickup: isPickup),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(CLIXTheme.radiusFull),
                  ),
                  child: Text(
                    order.statusDisplay,
                    style: TextStyle(
                      color: _statusColor(order.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  order.classDisplay,
                  style: const TextStyle(
                    color: CLIXTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (order.estimatedPrice != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${order.estimatedPrice!.toStringAsFixed(0)} ₴',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: CLIXTheme.primary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 8),
            Text(
              'ID: ${order.id.substring(0, 8)}',
              style: const TextStyle(fontSize: 11, color: CLIXTheme.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return CLIXTheme.warning;
      case 'ACCEPTED':
      case 'EN_ROUTE':
        return CLIXTheme.primary;
      case 'IN_PROGRESS':
      case 'COMPLETED':
        return CLIXTheme.success;
      case 'CANCELLED':
        return CLIXTheme.error;
      default:
        return CLIXTheme.textSecondary;
    }
  }
}
