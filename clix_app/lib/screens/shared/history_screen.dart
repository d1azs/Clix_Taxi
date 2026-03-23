import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

/// Екран історії поїздок — спільний для всіх ролей.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = ApiService();
  List<OrderModel> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getOrderHistory();
      if (mounted) {
        setState(() {
          _orders = data.map((e) => OrderModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLIXTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Історія поїздок'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: CLIXTheme.textHint.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Поїздок ще не було',
                    style: TextStyle(color: CLIXTheme.textHint),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  return _HistoryCard(order: _orders[index]);
                },
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
    final isCompleted = order.status == 'COMPLETED';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.cancel,
                  size: 20,
                  color: isCompleted ? CLIXTheme.success : CLIXTheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  order.statusDisplay,
                  style: TextStyle(
                    color: isCompleted ? CLIXTheme.success : CLIXTheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  order.classDisplay,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CLIXTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${order.pickupAddress} → ${order.dropoffAddress}',
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (order.estimatedPrice != null)
                  Text(
                    '${order.estimatedPrice!.toStringAsFixed(0)} Kč',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: CLIXTheme.primary,
                    ),
                  ),
                const Spacer(),
                Text(
                  _formatDate(order.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: CLIXTheme.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
