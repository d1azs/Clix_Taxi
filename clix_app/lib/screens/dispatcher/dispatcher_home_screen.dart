import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/geocoding_service.dart';
import '../../models/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// Екран диспетчера — повна CRM: замовлення, водії, KYC, статистика.
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
  List<dynamic> _drivers = [];
  List<dynamic> _pendingKyc = [];
  List<dynamic> _complaints = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadData();
    // Авто-оновлення кожні 15 секунд
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.getDispatcherOrders(),
        _api.getDispatcherDrivers(),
        _api.getPendingKyc(),
        _api.getComplaints(),
      ]);
      if (mounted) {
        setState(() {
          _orders = (results[0] as List).map((e) => OrderModel.fromJson(e)).toList();
          _drivers = results[1] as List;
          _pendingKyc = results[2] as List;
          _complaints = results[3] as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Dispatcher load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<OrderModel> get _activeOrders =>
      _orders.where((o) => !['COMPLETED', 'CANCELLED'].contains(o.status)).toList();

  List<dynamic> get _onlineDrivers =>
      _drivers.where((d) => d['status'] == 'ONLINE').toList();

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
              child: const Text('CLIX',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            const Text('Диспетчер', style: TextStyle(fontSize: 16, color: CLIXTheme.textPrimary)),
          ],
        ),
        actions: [
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
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: '📋 Замовлення (${_activeOrders.length})'),
            Tab(text: '👥 Водії (${_onlineDrivers.length})'),
            const Tab(text: '🗺️ Карта'),
            Tab(text: '🛡️ KYC (${_pendingKyc.length})'),
            const Tab(text: '📊 Стат.'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersTab(),
                _buildDriversTab(),
                _buildMapTab(),
                _buildKycTab(),
                _buildStatsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrderDialog(context),
        backgroundColor: CLIXTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Нове замовлення', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 1: Замовлення
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildOrdersTab() {
    if (_orders.isEmpty) return _emptyState(Icons.inbox_outlined, 'Замовлень ще немає');
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (_, i) => _buildOrderCard(_orders[i]),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: status + class + price
            Row(
              children: [
                _statusBadge(order.status, order.statusDisplay),
                const SizedBox(width: 8),
                Text(order.classDisplay,
                    style: const TextStyle(color: CLIXTheme.textSecondary, fontSize: 12)),
                const Spacer(),
                if (order.estimatedPrice != null)
                  Text('${order.estimatedPrice!.toStringAsFixed(0)} ₴',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: CLIXTheme.primary, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            // Addresses
            Row(children: [
              const Icon(Icons.radio_button_checked, size: 14, color: CLIXTheme.success),
              const SizedBox(width: 8),
              Expanded(child: Text(order.pickupAddress,
                  style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: CLIXTheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(order.dropoffAddress,
                  style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            // Passenger phone
            if (order.passengerPhone != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('📞 ${order.passengerPhone}',
                    style: const TextStyle(fontSize: 12, color: CLIXTheme.textHint)),
              ),
            // Driver info
            if (order.driverInfo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('🚗 ${order.driverInfo!.fullName} (★${order.driverInfo!.rating.toStringAsFixed(1)})',
                    style: const TextStyle(fontSize: 12, color: CLIXTheme.textSecondary)),
              ),
            const SizedBox(height: 8),
            Text('ID: ${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                style: const TextStyle(fontSize: 11, color: CLIXTheme.textHint)),
            // Action buttons
            if (!['COMPLETED', 'CANCELLED'].contains(order.status)) ...[
              const Divider(height: 20),
              Row(
                children: [
                  // Cancel button
                  OutlinedButton.icon(
                    onPressed: () => _cancelOrder(order.id),
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: CLIXTheme.error),
                    label: const Text('Скасувати',
                        style: TextStyle(fontSize: 12, color: CLIXTheme.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CLIXTheme.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Force-assign button
                  if (order.status == 'PENDING')
                    ElevatedButton.icon(
                      onPressed: () => _showForceAssignDialog(order),
                      icon: const Icon(Icons.person_add_alt_1, size: 16, color: Colors.white),
                      label: const Text('Призначити водія',
                          style: TextStyle(fontSize: 12, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CLIXTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Скасувати замовлення?'),
        content: const Text('Ця дія скасує замовлення назавжди.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ні')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Так, скасувати', style: TextStyle(color: CLIXTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.cancelDispatcherOrder(orderId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Замовлення скасовано')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Помилка: $e')));
      }
    }
  }

  void _showForceAssignDialog(OrderModel order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ForceAssignSheet(
        api: _api,
        drivers: _drivers.where((d) => d['status'] == 'ONLINE').toList(),
        orderId: order.id,
        onAssigned: () {
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 2: Водії
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildDriversTab() {
    if (_drivers.isEmpty) return _emptyState(Icons.people_outline, 'Водіїв ще немає');
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drivers.length,
        itemBuilder: (_, i) => _buildDriverCard(_drivers[i]),
      ),
    );
  }

  Widget _buildDriverCard(dynamic d) {
    final isOnline = d['status'] == 'ONLINE';
    final name = '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'.trim();
    final rating = double.tryParse(d['rating']?.toString() ?? '0') ?? 0;
    final trips = d['total_trips'] ?? 0;
    final phone = d['phone_number'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOnline
              ? CLIXTheme.success.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          child: Icon(
            isOnline ? Icons.local_taxi : Icons.taxi_alert_outlined,
            color: isOnline ? CLIXTheme.success : Colors.grey,
            size: 22,
          ),
        ),
        title: Text(
          name.isNotEmpty ? name : phone,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '📞 $phone  •  ★${rating.toStringAsFixed(1)}  •  $trips поїздок',
          style: const TextStyle(fontSize: 12, color: CLIXTheme.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline
                ? CLIXTheme.success.withValues(alpha: 0.12)
                : Colors.grey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isOnline ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isOnline ? CLIXTheme.success : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════════════
  // TAB MAP: Карта водіїв
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildMapTab() {
    final markers = _onlineDrivers.where((d) => d['current_lat'] != null && d['current_lng'] != null).map((d) {
      return Marker(
        point: latlong.LatLng((d['current_lat'] as num).toDouble(), (d['current_lng'] as num).toDouble()),
        width: 60,
        height: 60,
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'),
                content: Text('📞 ${d['phone_number']}\n★ ${d['rating']}\nПоїздок: ${d['total_trips']}'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ),
            );
          },
          child: const Icon(Icons.local_taxi, color: CLIXTheme.primary, size: 36),
        ),
      );
    }).toList();

    return FlutterMap(
      options: MapOptions(
        initialCenter: const latlong.LatLng(49.8397, 24.0297), // Lviv
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.clix.app',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 3: KYC
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildKycTab() {
    if (_pendingKyc.isEmpty) {
      return _emptyState(Icons.verified_user_outlined, 'Немає документів на перевірку');
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingKyc.length,
        itemBuilder: (_, i) => _buildKycCard(_pendingKyc[i]),
      ),
    );
  }

  Widget _buildKycCard(dynamic kyc) {
    final driverName = kyc['driver_name'] ?? 'Водій';
    final driverPhone = kyc['driver_phone'] ?? '';
    final kycId = kyc['id'] ?? '';
    final submittedAt = kyc['submitted_at'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: CLIXTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driverName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('📞 $driverPhone',
                          style: const TextStyle(fontSize: 12, color: CLIXTheme.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: CLIXTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('PENDING',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: CLIXTheme.warning)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Document links — tappable to preview
            Wrap(
              spacing: 12,
              children: [
                if (kyc['license'] != null)
                  _docChipTappable('Права', Icons.badge_outlined, kyc['license']),
                if (kyc['id_card'] != null)
                  _docChipTappable('Паспорт', Icons.credit_card, kyc['id_card']),
                if (kyc['registration'] != null)
                  _docChipTappable('Техпаспорт', Icons.directions_car_outlined, kyc['registration']),
              ],
            ),
            if (submittedAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Подано: ${_formatDate(submittedAt)}',
                    style: const TextStyle(fontSize: 11, color: CLIXTheme.textHint)),
              ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _reviewKyc(kycId, 'APPROVED'),
                    icon: const Icon(Icons.check_circle, size: 18, color: Colors.white),
                    label: const Text('Схвалити',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CLIXTheme.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reviewKyc(kycId, 'REJECTED'),
                    icon: const Icon(Icons.cancel, size: 18, color: CLIXTheme.error),
                    label: const Text('Відхилити',
                        style: TextStyle(color: CLIXTheme.error, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CLIXTheme.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _docChipTappable(String label, IconData icon, dynamic docPath) {
    return GestureDetector(
      onTap: () => _showDocumentViewer(label, docPath.toString()),
      child: Chip(
        avatar: Icon(icon, size: 16, color: CLIXTheme.primary),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new, size: 12, color: CLIXTheme.primary),
          ],
        ),
        backgroundColor: CLIXTheme.primary.withValues(alpha: 0.08),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _showDocumentViewer(String title, String path) {
    // Build full URL if it's a relative path
    final imageUrl = path.startsWith('http')
        ? path
        : '${ApiConfig.mediaUrl}/$path';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Image
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                          color: CLIXTheme.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 250,
                    color: const Color(0xFF1C1F2E),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.insert_drive_file, size: 64, color: CLIXTheme.primary),
                        const SizedBox(height: 16),
                        Text(title,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(path,
                            style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: CLIXTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('✅ Документ завантажений',
                              style: TextStyle(color: CLIXTheme.success, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewKyc(String kycId, String status) async {
    final action = status == 'APPROVED' ? 'схвалити' : 'відхилити';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${status == 'APPROVED' ? 'Схвалити' : 'Відхилити'} документи?'),
        content: Text('Ви дійсно хочете $action цього водія?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ні')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Так, $action',
                style: TextStyle(
                    color: status == 'APPROVED' ? CLIXTheme.success : CLIXTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.reviewKyc(kycId, status);
      _loadData();
      if (mounted) {
        final emoji = status == 'APPROVED' ? '✅' : '❌';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$emoji Статус KYC змінено на $status')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 4: Статистика
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildStatsTab() {
    final totalOrders = _orders.length;
    final activeCount = _activeOrders.length;
    final completedCount = _orders.where((o) => o.status == 'COMPLETED').length;
    final cancelledCount = _orders.where((o) => o.status == 'CANCELLED').length;
    final totalDrivers = _drivers.length;
    final onlineCount = _onlineDrivers.length;
    final pendingKycCount = _pendingKyc.length;
    final complaintsCount = _complaints.length;

    // Calculate total revenue
    double totalRevenue = 0;
    for (final o in _orders.where((o) => o.status == 'COMPLETED')) {
      totalRevenue += o.estimatedPrice ?? 0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Огляд системи',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CLIXTheme.textPrimary)),
          const SizedBox(height: 16),
          // Замовлення
          _sectionTitle('Замовлення'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statCard('Усього', '$totalOrders', Icons.receipt_long, CLIXTheme.primary)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Активних', '$activeCount', Icons.pending_actions, CLIXTheme.warning)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('Завершених', '$completedCount', Icons.check_circle_outline, CLIXTheme.success)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Скасованих', '$cancelledCount', Icons.cancel_outlined, CLIXTheme.error)),
            ],
          ),
          const SizedBox(height: 20),
          // Водії
          _sectionTitle('Водії'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statCard('Усього', '$totalDrivers', Icons.people, CLIXTheme.primary)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Онлайн', '$onlineCount', Icons.wifi, CLIXTheme.success)),
            ],
          ),
          const SizedBox(height: 20),
          // Безпека та Фінанси
          _sectionTitle('Безпека та Фінанси'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statCard('KYC очікується', '$pendingKycCount', Icons.shield_outlined, CLIXTheme.warning)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Скарг', '$complaintsCount', Icons.report_outlined, CLIXTheme.error)),
            ],
          ),
          const SizedBox(height: 12),
          _statCard('Загальна виручка', '${totalRevenue.toStringAsFixed(0)} ₴',
              Icons.account_balance_wallet, CLIXTheme.success),
          const SizedBox(height: 20),
          // Скарги
          if (_complaints.isNotEmpty) ...[
            _sectionTitle('Останні скарги'),
            const SizedBox(height: 8),
            ..._complaints.take(5).map((c) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: CLIXTheme.error),
                title: Text('Оцінка: ★${c['rating']}'),
                subtitle: Text(c['comment'] ?? 'Без коментаря',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: CLIXTheme.textSecondary));
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: color)),
                Text(label,
                    style: const TextStyle(fontSize: 11, color: CLIXTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════
  Widget _statusBadge(String status, String display) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(display,
          style: TextStyle(
              color: _statusColor(status), fontWeight: FontWeight.w600, fontSize: 12)),
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

  Widget _emptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: CLIXTheme.textHint.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: CLIXTheme.textHint)),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Create Order Dialog
  // ═══════════════════════════════════════════════════════════════════════
  void _showCreateOrderDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CreateOrderSheet(
        geocoding: _geocoding,
        api: _api,
        drivers: _drivers.where((d) => d['status'] == 'ONLINE').toList(),
        onCreated: _loadData,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Force-Assign Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════
class _ForceAssignSheet extends StatelessWidget {
  final ApiService api;
  final List<dynamic> drivers;
  final String orderId;
  final VoidCallback onAssigned;

  const _ForceAssignSheet({
    required this.api,
    required this.drivers,
    required this.orderId,
    required this.onAssigned,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Призначити водія',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Оберіть вільного водія для примусового призначення',
              style: TextStyle(fontSize: 13, color: CLIXTheme.textSecondary)),
          const SizedBox(height: 16),
          if (drivers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Немає водіїв онлайн',
                    style: TextStyle(color: CLIXTheme.textHint)),
              ),
            )
          else
            ...drivers.map((d) {
              final name = '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'.trim();
              final phone = d['phone_number'] ?? '';
              final rating = double.tryParse(d['rating']?.toString() ?? '0') ?? 0;
              final driverId = d['id'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.local_taxi, color: CLIXTheme.success),
                  ),
                  title: Text(name.isNotEmpty ? name : phone,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('★${rating.toStringAsFixed(1)}  •  $phone',
                      style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      try {
                        await api.forceAssignDriver(orderId, driverId);
                        onAssigned();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Помилка: $e')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CLIXTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Обрати', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Create Order Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════
class _CreateOrderSheet extends StatefulWidget {
  final GeocodingService geocoding;
  final ApiService api;
  final List<dynamic> drivers;
  final VoidCallback onCreated;

  const _CreateOrderSheet({
    required this.geocoding,
    required this.api,
    required this.drivers,
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
  Timer? _debounce;
  DateTime? _selectedTime;
  String? _selectedDriverId;

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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onSearch(String query, {required bool isPickup}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().length < 2) {
        setState(() {
          if (isPickup) _pickupSuggestions = [];
          else _dropoffSuggestions = [];
        });
        return;
      }
      final results = await widget.geocoding.searchAddress(query);
      if (mounted) {
        setState(() {
          if (isPickup) _pickupSuggestions = results;
          else _dropoffSuggestions = results;
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
    if (_pickupCtrl.text.trim().isEmpty || _dropoffCtrl.text.trim().isEmpty) return;
    setState(() => _isCreating = true);
    try {
      await widget.api.createDispatcherOrder(
        passengerPhone: _phoneCtrl.text.trim(),
        pickupAddress: _pickupCtrl.text.trim(),
        dropoffAddress: _dropoffCtrl.text.trim(),
        pickupLat: _selectedPickup?.lat ?? 49.8397,
        pickupLng: _selectedPickup?.lng ?? 24.0297,
        dropoffLat: _selectedDropoff?.lat ?? 49.8429,
        dropoffLng: _selectedDropoff?.lng ?? 24.0315,
        pickupTime: _selectedTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
        requiredClass: _selectedClass,
        assignedDriverId: _selectedDriverId,
      );
      if (mounted) Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Створити замовлення', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            // Phone
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Телефон клієнта',
                hintText: '+380 97 123 4567',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 12, right: 4),
                  child: Text('🇺🇦', style: TextStyle(fontSize: 18)),
                ),
                prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
              ),
            ),
            const SizedBox(height: 12),
            // Pickup
            TextField(
              controller: _pickupCtrl,
              onChanged: (q) => _onSearch(q, isPickup: true),
              decoration: const InputDecoration(
                labelText: 'Адреса подачі',
                hintText: 'вул. Шевченка, 10',
                prefixIcon: Icon(Icons.radio_button_checked, color: CLIXTheme.success, size: 18),
              ),
            ),
            if (_pickupSuggestions.isNotEmpty)
              _buildSuggestions(_pickupSuggestions, isPickup: true),
            const SizedBox(height: 12),
            // Dropoff
            TextField(
              controller: _dropoffCtrl,
              onChanged: (q) => _onSearch(q, isPickup: false),
              decoration: const InputDecoration(
                labelText: 'Адреса призначення',
                hintText: 'пр. Свободи, 28',
                prefixIcon: Icon(Icons.location_on, color: CLIXTheme.error, size: 18),
              ),
            ),
            if (_dropoffSuggestions.isNotEmpty)
              _buildSuggestions(_dropoffSuggestions, isPickup: false),
            const SizedBox(height: 14),
            
            // Date Time Picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time, color: CLIXTheme.primary),
              title: Text(_selectedTime == null ? 'Зараз (Рандом)' : 'На час: ${_selectedTime!.day}.${_selectedTime!.month} ${_selectedTime!.hour}:${_selectedTime!.minute}'),
              trailing: const Icon(Icons.edit, size: 16),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                if (date != null) {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (time != null) {
                    setState(() => _selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  }
                }
              },
            ),
            if (_selectedTime != null)
              TextButton(onPressed: () => setState(() => _selectedTime = null), child: const Text('Скинути час (Зараз)')),

            // Driver Assign
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Призначити водія (Опціонально)'),
              value: _selectedDriverId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Будь-який водій (Автоматично)')),
                ...widget.drivers.map((d) {
                  final name = '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'.trim();
                  final phone = d['phone_number'] ?? '';
                  final label = name.isNotEmpty ? '$name ($phone)' : phone;
                  return DropdownMenuItem(
                    value: d['id']?.toString(),
                    child: Text(label),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _selectedDriverId = val),
            ),
            const SizedBox(height: 12),

            // Car class
            const Text('Клас авто',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CLIXTheme.textPrimary)),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _create,
                child: _isCreating
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Створити замовлення',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
          color: sel ? CLIXTheme.primary.withValues(alpha: 0.12) : CLIXTheme.surface,
          borderRadius: BorderRadius.circular(CLIXTheme.radiusFull),
          border: Border.all(
              color: sel ? CLIXTheme.primary : CLIXTheme.divider, width: sel ? 2 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel ? CLIXTheme.primary : CLIXTheme.textSecondary)),
      ),
    );
  }

  Widget _buildSuggestions(List<AddressSuggestion> list, {required bool isPickup}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CLIXTheme.radiusMd),
        border: Border.all(color: CLIXTheme.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4)),
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
            leading: const Icon(Icons.place, color: CLIXTheme.primary, size: 18),
            title: Text(s.shortName, style: const TextStyle(fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(s.displayName,
                style: const TextStyle(fontSize: 11, color: CLIXTheme.textHint),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _selectAddr(s, isPickup: isPickup),
          );
        },
      ),
    );
  }
}
