import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/transfer_simulation_provider.dart';

/// Плаваючий віджет симулятора для демонстрації дипломної роботи.
/// Дозволяє ініціювати та скидати трансфер від Booking.com на будь-якому екрані.
class SimulationControlsWidget extends StatelessWidget {
  const SimulationControlsWidget({super.key});

  void _showSimulationBottomSheet(BuildContext context) {
    final simulation = context.read<TransferSimulationProvider>();
    final currentStatus = simulation.status;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.airport_shuttle, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Панель симуляції трансферів',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: CLIXTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Дипломна робота: інтеграція Booking.com',
                            style: TextStyle(
                              fontSize: 12,
                              color: CLIXTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: CLIXTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CLIXTheme.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Поточний статус:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      _buildStatusBadge(currentStatus),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (currentStatus == 'NONE')
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Захоплюємо messenger ДО async-розриву
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        Future.microtask(() {
                          simulation.initiateTransfer();
                          _showSnack(messenger, '📥 Отримано запит на трансфер від Booking.com!');
                        });
                      },
                      icon: const Icon(Icons.add_to_home_screen, color: Colors.white),
                      label: const Text(
                        'Ініціювати трансфер від Booking.com',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (currentStatus != 'NONE') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        Future.microtask(() {
                          simulation.resetSimulation();
                          _showSnack(messenger, '🔄 Симуляцію трансферу скинуто.');
                        });
                      },
                      icon: const Icon(Icons.refresh, color: CLIXTheme.error),
                      label: const Text(
                        'Скинути симуляцію',
                        style: TextStyle(color: CLIXTheme.error, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: CLIXTheme.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'PENDING':
        bg = Colors.amber.shade50;
        text = Colors.amber.shade800;
        label = 'ОЧІКУЄ ПІДТВЕРДЖЕННЯ';
        break;
      case 'CONFIRMED':
        bg = Colors.green.shade50;
        text = Colors.green.shade800;
        label = 'ПІДТВЕРДЖЕНО';
        break;
      case 'ARRIVED':
        bg = Colors.teal.shade50;
        text = Colors.teal.shade800;
        label = 'ВОДІЙ НА МІСЦІ';
        break;
      case 'LIVE_RIDE':
        bg = Colors.purple.shade50;
        text = Colors.purple.shade800;
        label = 'У ДОРОЗІ';
        break;
      case 'COMPLETED':
        bg = Colors.grey.shade100;
        text = Colors.grey.shade700;
        label = 'ЗАВЕРШЕНО';
        break;
      default:
        bg = Colors.grey.shade50;
        text = Colors.grey.shade500;
        label = 'АКТИВНИХ НЕМАЄ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  void _showSnack(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: CLIXTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 84, // Трохи вище за навігаційну панель пасажира
      child: FloatingActionButton(
        mini: true,
        heroTag: 'sim_fab',
        backgroundColor: Colors.blue.shade600,
        elevation: 6,
        shape: const CircleBorder(),
        onPressed: () => _showSimulationBottomSheet(context),
        child: const Icon(
          Icons.construction_outlined,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
